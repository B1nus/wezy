const std = @import("std");
const eql = std.mem.eql;

pub fn NameMap(comptime N: usize) type {
    return struct {
        array: [N][]const u8,
        defined: [N]bool,
        len: usize,

        pub fn init() @This() {
            return .{
                .array = undefined,
                .defined = undefined,
                .len = 0,
            };
        }

        pub fn depend(self: *@This(), name: []const u8) !usize {
            for (self.array, 0..) |nameStr, index| {
                if (eql(u8, nameStr, name)) {
                    return index;
                }
            }
            if (self.len < N) {
                self.array[self.len] = name;
                self.defined[self.len] = false;
                self.len += 1;
                return self.len - 1;
            } else {
                return error.OutOfSpace;
            }
        }

        pub fn define(self: *@This(), name: []const u8) !void {
            const index = try self.depend(name);
            if (self.defined[index]) {
                return error.AlreadyDefined;
            } else {
                self.defined[index] = true;
            }
        }

        pub fn getUndefined(self: *@This()) ?[]const u8 {
            for (self.array[0..self.len], self.defined[0..self.len]) |value, defined| {
                if (!defined) {
                    return value;
                }
            }
            return null;
        }
    };
}

pub fn ValueMap(comptime N: usize) type {
    return struct {
        array: [N][]const u8,
        len: usize,

        pub fn init() @This() {
            return .{
                .array = undefined,
                .len = 0,
            };
        }

        pub fn indexOf(self: *@This(), value: []const u8) !usize {
            for (self.array, 0..) |nameStr, index| {
                if (eql(u8, nameStr, value)) {
                    return index;
                }
            }
            if (self.len < N) {
                self.array[self.len] = value;
                self.len += 1;
                return self.len - 1;
            } else {
                return error.OutOfSpace;
            }
        }

        pub fn slice(self: @This()) []const []const u8 {
            return self.array[0..self.len];
        }
    };
}

const expect = @import("std").testing.expect;

test "NameMap" {
    var nameMap = NameMap(10).init();
    try nameMap.define("hello");
    try nameMap.define("hello2");
    try expect(nameMap.define("hello") == error.AlreadyDefined);
    try expect(try nameMap.depend("hello2") == 1);
    try expect(try nameMap.depend("hello3") == 2);
    try expect(eql(u8, nameMap.getUndefined().?, "hello3"));
    try expect(try nameMap.depend("hello3") == 2);
    try expect(try nameMap.depend("hello3") == 2);
    try nameMap.define("hello3");
    try expect(nameMap.getUndefined() == null);
}

test "ValueMap" {
    var valueMap = ValueMap(10).init();
    var itemBuf = try std.BoundedArray(u8, 10).init(0);
    try itemBuf.appendSlice(&.{ 0, 1 });
    try expect(try valueMap.indexOf(itemBuf.slice()) == 0);
    try itemBuf.append(2);
    try expect(try valueMap.indexOf(itemBuf.slice()) == 1);
    itemBuf.len -= 1;
    try expect(try valueMap.indexOf(itemBuf.slice()) == 0);
    try expect(eql(u8, valueMap.slice()[0], &.{ 0, 1 }));
    try expect(eql(u8, valueMap.slice()[1], &.{ 0, 1, 2 }));
    try expect(valueMap.len == 2);
}
