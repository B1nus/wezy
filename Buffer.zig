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

        pub fn writeUleb128(self: *@This(), number: anytype) !void {
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

        pub fn slice(self: *@This()) []const u8 {
            return self.array[0..self.len];
        }
    };
}

test "Buffer" {
    var buffer = Buffer(10).init();
    try buffer.append(0);
    try buffer.appendSlice(&.{ 0, 60, 0 });
    try expect(eql(u8, buffer.array[0..buffer.len], buffer.slice()));

    buffer.len = 0;
    try buffer.writeUleb128(128);
    try expect(buffer.array[0] == 0x80);
    try expect(buffer.array[1] == 0x01);
}
