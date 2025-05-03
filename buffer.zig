const std = @import("std");
const expect = std.testing.expect;
const eql = std.mem.eql;

pub fn Buffer(comptime N: usize) type {
    return struct {
        array: [N]u8,
        len: usize,

        pub fn init() @This() {
            return .{
                .array = undefined,
                .len = 0,
            };
        }

        pub fn append(self: *@This(), byte: u8) !void {
            if (self.len < N) {
                self.array[self.len] = byte;
                self.len += 1;
            } else {
                return error.OutOfSpace;
            }
        }

        pub fn appendSlice(self: *@This(), bytes: []const u8) !void {
            if (self.len + bytes.len <= N) {
                @memcpy(self.array[self.len .. self.len + bytes.len], bytes[0..]);
                self.len += bytes.len;
            } else {
                return error.OutOfSpace;
            }
        }

        pub fn appendUnsigned(self: *@This(), number: anytype) !void {
            var v: usize = number;
            while (true) {
                var byte: u8 = @intCast(v & 0x7F);
                v >>= 7;
                if (v != 0) {
                    byte |= 0x80; // set continuation bit
                }
                try self.append(byte);

                if (v == 0) break;
            }
        }

        pub fn appendSigned(self: *@This(), number: anytype) !void {
            var v: isize = number;
            var more = true;
            while (more) {
                var byte: u8 = @intCast(v & 0x7F);
                v >>= 7;

                if ((v == 0 and (byte & 0x40) == 0) or (v == -1 and (byte & 0x40) != 0)) {
                    more = false;
                } else {
                    byte |= 0x80;
                }

                try self.append(byte);
            }
        }

        pub fn slice(self: *@This()) []const u8 {
            return self.array[0..self.len];
        }
    };
}

test "obviously correct" {
    var buffer = Buffer(6).init();
    try buffer.appendSlice(&.{ 0, 1, 2, 3, 4, 5 });
    try expect(eql(u8, buffer.slice(), buffer.array[0..buffer.len]));
}

test "out of space" {
    var buffer = Buffer(3).init();
    try buffer.appendSlice(&.{ 0, 1, 2 });
    try expect(buffer.append(3) == error.OutOfSpace);
}

test "append" {
    var buffer = Buffer(6).init();
    try buffer.append(1);
    try buffer.append(2);
    try buffer.append(3);
    try buffer.append(4);
    try expect(eql(u8, buffer.slice(), &.{ 1, 2, 3, 4 }));
}

test "append slice" {
    var buffer = Buffer(6).init();
    try buffer.appendSlice(&.{ 0, 1, 2, 3, 4, 5 });
    try expect(eql(u8, buffer.slice(), &.{ 0, 1, 2, 3, 4, 5 }));
}

test "write unsigned leb 128" {
    var buffer = Buffer(4).init();
    try buffer.appendUnsigned(69);
    try buffer.appendUnsigned(237);
    try expect(eql(u8, buffer.slice(), &.{ 69, 237, 1 }));
}

test "write signed leb 128" {
    var buffer = Buffer(16).init();
    try buffer.appendSigned(69);
    try buffer.appendSigned(-237);
    try expect(eql(u8, buffer.slice(), &.{ 0xc5, 0, 0x93, 0x7e }));
}
