const Module = @import("Module.zig");
const std = @import("std");
const expect = std.testing.expect;
const eql = std.mem.eql;

pub fn main() !void {
    var args = std.process.args();
    _ = args.next();

    const source_file = if (args.next()) |source_path| try std.fs.cwd().openFile(source_path, .{}) else std.io.getStdIn();
    var buffer: [0x10000]u8 = undefined;
    const source = buffer[0..try source_file.reader().readAll(&buffer)];

    var module = Module.init(source);
    if (module.compile()) |out_buffer| {
        const out_file = if (args.next()) |out_path| try std.fs.cwd().createFile(out_path, .{ .truncate = true }) else std.io.getStdOut();
        const writer = out_file.writer();

        try writer.writeAll(&.{ 0, 'a', 's', 'm', 1, 0, 0, 0 });
        try writer.writeAll(out_buffer.slice());
    } else |compiler_error| {
        const stdErr = std.io.getStdErr();
        const writer = stdErr.writer();

        const column = module.scanner.start - module.scanner.line_start;
        const column_end = module.scanner.end - module.scanner.line_start;

        try writer.print("\x1b[37m{d}:{d}\x1b[0m \x1b[31m{s}\x1b[0m\n{s}\n\x1b[32m", .{
            module.scanner.line,
            column + 1,
            @errorName(compiler_error),
            module.scanner.currentLine(),
        });

        for (0..column) |_| {
            try writer.writeByte(' ');
        }

        try writer.writeByte('^');

        if (column_end > column + 1) {
            for (0..column_end - column - 1) |_| {
                try writer.writeByte('~');
            }
        }

        try writer.writeAll("\x1b[0m\n");

        return;
    }
}
