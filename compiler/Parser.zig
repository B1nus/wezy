const std = @import("std");
const List = std.ArrayList;

source: []const u8,
current: Token,
next: Token,
stack: List(u64),
index: u64,

pub fn init(allocator: std.mem.Allocator, source: []const u8) @This() {
    return .{
        .source = source,
        .current = undefined,
        .next = undefined,
        .stack = List(u64).init(allocator),
        .index = 0,
    };
}

fn currentChar(this: @This()) u8 {
    if (this.index < this.source.len) {
        return this.source[this.index];
    } else {
        return 0;
    }
}

pub fn nextToken(this: *@This()) Token {
    const State = enum {
        start,
        less,
        more,
        equal,
        bang,
        char,
        float,
        string,
        integer,
        zero,
        hexadecimal,
        binary,
        octal,
        variable,
        newline,
        indentation,
    };

    state: switch (State.start) {
        .start => {
        },
    }
}

pub const Token = union(enum) {
    variable: Range,
    integer: Range,
    float: Range,
    string: Range,
    char: Range,
    special: Special,

    const Range = struct {
        start: u64,
        end: u64,
    };

    const Special = enum {
        left_parenthesis,
        right_parenthesis,
        left_bracket,
        right_bracket,
        left_brace,
        right_brace,
        comma,
        dot,
        plus,
        minus,
        slash,
        asterix,
        caret,
        percent,
        double_less,
        double_more,
        less,
        more,
        less_equal,
        more_equal,
        double_equal,
        bang_equal,
        newline,
        indentation,
        dedentation,
        end,
    }
}
