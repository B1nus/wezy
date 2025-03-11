const std = @import("std");
const Index = u64;

const Token = union(enum) {
    integer_type: u64,
    identifier: []u8,
    equals,
    decimal_integer: []u8,
    indentation: Index,
    plus,
    eof,
};

pub fn next_token(source: []u8, index: *Index) Token {
    const State = enum {
        start,
        identifier,
        decimal_integer,
        indentation,
        invalid,
    };

    var state = State.start;
    var start_index = index.*;

    while (index < source.len) : (index.* += 1) {
        switch (state) {
            .start => {
                state = switch (source[index.*]) {
                    '\n' => State.indentation,
                    ' ', '\r', '\t' => {
                        index.* += 1;
                        start_index.* = index.*;
                        State.start
                    }
                    '+' => State.plus,
                    'a'...'z' => 
                };
            }

        }
    }

    return switch(state) {
        .start => .eof,
        .identifier => .identifier: source[start_index..index.*],
        else => .eof,
    };
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var args = std.process.args();
    std.debug.assert(args.skip());
    const path = args.next().?;

    const file = try std.fs.cwd().openFile(path, .{});
    const source = try file.readToEndAlloc(allocator, std.math.maxInt(u64));

    var index: usize = 0;
    std.debug.print("{any}\n", .{next_token(source, &index)});
}
