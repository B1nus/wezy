const std = @import("std");
const Inst = @import("inst.zig").Inst;
const instBytes = @import("inst.zig").bytes;

const Section = enum(u8) {
    custom,
    @"type",
    import,
    function,
    table,
    memory,
    global,
    @"export",
    start,
    element,
    code,
    data,
    @"data count",
};

pub fn parseString(reader: anytype, writer: anytype) !void {
    loop: switch (false) {
        true => {
            const byte = try reader.readByte();
            try switch (byte) {
                'n' => writer.writeByte('\n'),
                't' => writer.writeByte('\t'),
                '\\' => writer.writeByte('\\'),
                '\"' => writer.writeByte('\"'),
                '0'...'9', 'a'...'f', 'A'...'F' => {
                    const next_byte = try reader.readByte();
                    const hex = try std.fmt.parseInt(u8, &.{ byte, next_byte }, 16);
                    try writer.writeByte(hex);
                },
                'u' => {
                    var buffer: [4]u8 = undefined;
                    std.debug.assert(try reader.readAll(&buffer) == 4);
                    const hex = try std.fmt.parseInt(u32, &buffer, 16);
                    try writer.writeInt(u32, hex, .big);
                },
                'U' => {
                    var buffer: [8]u8 = undefined;
                    std.debug.assert(try reader.readAll(&buffer) == 8);
                    const hex = try std.fmt.parseInt(u64, &buffer, 16);
                    try writer.writeInt(u64, hex, .big);
                },
                else => unreachable,
            };
            continue :loop false;
        },
        false => {
            const byte = try reader.readByte();
            switch (byte) {
                '\\' => continue :loop true,
                '\"' => return,
                else => {
                    try writer.writeByte(byte);
                    continue :loop false;
                },
            }
        },
    }
}

pub fn readByte(reader: anytype) ?u8 {
    if (reader.readByte()) |byte| {
        return byte;
    } else |_| {
        return null;
    }
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const final_writer std.io.getStdOut().writer();
    const reader = (try std.fs.cwd().openFile("hello.crs", .{})).reader();

    var buffer = std.ArrayList(u8).init(allocator);
    const writer = buffer.writer();

    var count_index_stack = std.ArrayList(usize).init(allocator);
    var list_index_stack = std.ArrayList(usize).init(allocator);
    var list_count_stack = std.ArrayList(usize).init(allocator);

    var byte = readByte(reader);
    while (byte) |b| {
        switch (b) {
            '\n', ' ' => continue,
            '[' => {
                try list_stack_idx.append(list_stack.items.len);
                try list_count.append(0);
            },
            '{' => {
                
            },
            'x' => {
                byte = readByte(reader);
                while (byte) ||
            },
        }
    }
}
