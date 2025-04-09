const std = @import("std");
const Inst = @import("inst.zig").Inst;
const instBytes = @import("inst.zig").bytes;

// pub fn compileToken(reader: std.io.Reader, buffer: []u8) ![]u8 {
//     var index: usize = 0;
//
//     switch
// }

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    const reader = (try std.fs.cwd().openFile("crs", .{})).reader();
    var buffer: [100]u8 = undefined;
    var index: usize = 0;

    while (reader.readByte()) |byte| {
        switch (byte) {
            '\n', ' ', '\t' => if (index > 0) {
                try stdout.writeByte(try std.fmt.parseInt(u8, buffer[0..index], 16));
                index = 0;
            },
            else => {
                buffer[index] = byte;
                index += 1;
            }
        }
    } else |_| { }
}
