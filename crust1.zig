const std = @import("std");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();
    var number: u8 = 0;
    var double: bool = false;

    while (stdin.readByte()) |byte| {
        switch (byte) {
            '0'...'9', 'a'...'f' => {
                number <<= 4;
                number += byte;
                number -= if (byte > '0') '0' else 'a' - 0xa;
                double = !double;
            },
            else => {},
        }

        if (double) {
            try stdout.writeByte(number);
        }
    } else |_| {}
}
