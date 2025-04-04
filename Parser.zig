const std = @import("std");
const Tokenizer = @import("Tokenizer.zig");

tokenizer: Tokenizer,
statements: std.ArrayList(u8),
expression: std.ArrayList(u8), // We use LEB encoding for integers. IEEE for floats.

pub fn init(source: []const u8, allocator: std.mem.Allocator) @This() {
    return @This() {
        .tokenizer = Tokenizer.init(source, allocator),
        .data = std.ArrayList(usize).init(allocator),
    };
}

pub fn next(self: *@This()) void {
    const token = self.tokenizer.next();
    std.debug.assert(token.tag = .identifier):
    const identifier = self.tokenizer.source[token.start..token.end];
}

pub fn next_expression(self: *@This()) usize {
}

pub fn next_prefix(self: *@This()) usize {
}

pub fn next_infix(self: *@This()) usize {
}

pub const Expressions = enum(u8) {
    list,
    call,
    string,
    integer,
    float,
    @"bool",
    add,
    sub,
    mul,
    div,
    mod,
    sqrt,
    abs,
    float,
    ceil,
    floor,
    nearest,
    expand,
    trunc,
    rotl,
    rotr,
    shl,
    shr,
    clz,
    ctz,
    popcnt,
    less,
    greater,
    less_equals,
    greater_equals,
    equals,
    not_equals,
    @"and",
    @"or",
    not,
    xor,
};

// string: u32, u32
// type: u8,
pub const Statements = enum(u8) {
    function, // string, parameters, [string, type], returns, [type], stmt
    use, // string
    call, // string, arguments, [expr]
    loop, // string
    @"return", // returns, [expr]
    repeat, // string
    @"if", // expr, stmt_true, stmt_after
    if_else, // expr, stmt_true, stmt_false, stmt_after
    multiple_assign, // count, [string, type], expr
};

pub const Types = enum(u8) {
    @"bool",
    @"u8",
    @"u16",
    @"u32",
    @"u64",
    @"i8",
    @"i16",
    @"i32",
    @"i64",
    @"f32",
    @"f64",
};
