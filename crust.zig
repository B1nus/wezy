const std = @import("std");
const Index = u64;

const Token = union(enum) {
    integer_type: u64,
    identifier: []u8,
    equals,
    decimal_integer: []u8,
    indentation: Index,
    plus,
    newline,
    eof,
};

pub fn next_token(source: []u8, index: *Index) Token {
    const State = enum {
        start,
        identifier,
        decimal_integer,
    };

    var state = State.start;
    const start_index = index.*;

    while (index < source.len) : (index.* += 1) {
        switch (source[index.*]) {
            
        }
    }

    return switch(state) {
        .start => .eof,
        .identifier => .identifier: source[start_index]
    };
    return .eof;
}

pub fn main() !void {
    var args = std.process.args();
    std.debug.assert(args.skip());
    const path = args.next().?;
    std.debug.print("{s}\n", .{path});
}
