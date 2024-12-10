pub const std = @import("std");

// I would write pub const SourceIndex = u32. But let's consider that implicit. For other indicies in the ast I will make it explicit though.

pub const Token = struct {
    pos: u32,
    end: u32, // Not necessary for meny tokens. Maybe we can do better?
    tag: Tag,

    pub const Tag = enum {
        integer_literal,
        identifier,
        lparen,
        rparen,
        comma,
        keyword_return,
        keyword_integer_type, // Hmmm, should this be considered a keyword?
        plus,
        newline,
        eof,
        invalid,
    };
};

pub const keywords = std.StaticStringMap(Token.Tag).initComptime(.{
    .{ "return", .keyword_return },
});

pub fn get_keyword(identifier: []const u8) ?Token.Tag {
    if (keywords.get(identifier)) |keyword| {
        return keyword;
    }

    if (identifier.len <= 1) return null;
    switch (identifier[0]) {
        'i' => {
            const bits = std.fmt.parseInt(u32, identifier[1..], 10) catch {
                return null;
            };

            if (bits == 0) return null; // Disallow void types. Not needed when we have sets.

            return if (bits & (bits - 1) == 0) .keyword_integer_type else null;
        },
        else => return null,
    }
}

// Return all of the tokens from the next non-empty line along with indentation and errors.
// This does not return the indentation or dedentation tokens. Thos must be handled by the caller.
//
// TODO: Add a check for the weird magic values on top of the utf8 files.
pub fn next_token_line(source: [:0]const u8, offset: u32, tokens: *std.ArrayList(Token)) !u32 {
    var index = offset;
    var indent: u32 = 0;

    while (source[index] == ' ' or source[index] == '\t' or source[index] == '\r') { // Should \r be here?
        indent += 1;
        index += 1;
    }

    var token = next_token(source, index);

    // The line is empty. Skip to the next line.
    if (token.tag == .newline) {
        return next_token_line(source, index + 1, tokens);
    }

    while (token.tag != .eof and token.tag != .newline) {
        try tokens.append(token);
        index = token.end + 1;
        token = next_token(source, index);
    }

    return indent;
}

pub const State = enum {
    identifier,
    integer,
    start,
};

// Find the next token. This assumes that the line does not start with indentation and is not empty.
pub fn next_token(source: [:0]const u8, offset: u32) Token {
    var token = Token{ .pos = offset, .end = undefined, .tag = undefined };
    var index = offset;

    state: switch (State.start) {
        .start => {
            switch (source[index]) {
                0 => token.tag = .eof,
                ' ', '\r', '\t' => {
                    index += 1;
                    token.pos = index;
                    continue :state .start;
                },
                '-', '0'...'9' => continue :state .integer,
                'a'...'z', '_' => continue :state .identifier,
                '(' => token.tag = .lparen,
                ')' => token.tag = .rparen,
                ',' => token.tag = .comma,
                '+' => token.tag = .plus,
                '\n' => token.tag = .newline,
                else => token.tag = .invalid,
            }
            index += 1;
        },
        .identifier => {
            index += 1;
            switch (source[index]) {
                'a'...'z', '_', '0'...'9' => continue :state .identifier,
                else => {
                    if (get_keyword(source[token.pos..index])) |keyword| {
                        token.tag = keyword;
                    } else {
                        token.tag = .identifier;
                    }
                },
            }
        },
        .integer => {
            index += 1;
            switch (source[index]) {
                '0'...'9' => continue :state .integer,
                else => token.tag = .integer_literal,
            }
        },
    }

    token.end = index - 1;
    return token;
}

pub const expect = std.testing.expect;

test "simple add function" {
    const source =
        \\i32 add(i32 a, i32 b)
        \\  return a + b
        \\
        \\add(9,-8)
    ;
    var tokens = std.ArrayList(Token).init(std.testing.allocator);
    defer tokens.deinit();
    var indent = try next_token_line(source, 0, &tokens);
    try expect(indent == 0);
    try expect(tokens.items.len == 9);
    try expect(tokens.items[0].tag == .keyword_integer_type);
    try expect(tokens.items[0].pos == 0);
    try expect(tokens.items[0].end == 2);
    try expect(tokens.items[1].tag == .identifier);
    try expect(tokens.items[1].pos == 4);
    try expect(tokens.items[1].end == 6);
    try expect(tokens.items[2].tag == .lparen);
    try expect(tokens.items[2].pos == 7);
    try expect(tokens.items[2].end == 7);
    try expect(tokens.items[3].tag == .keyword_integer_type);
    try expect(tokens.items[3].pos == 8);
    try expect(tokens.items[3].end == 10);
    try expect(tokens.items[4].tag == .identifier);
    try expect(tokens.items[4].pos == 12);
    try expect(tokens.items[4].end == 12);
    try expect(tokens.items[5].tag == .comma);
    try expect(tokens.items[5].pos == 13);
    try expect(tokens.items[5].end == 13);
    try expect(tokens.items[6].tag == .keyword_integer_type);
    try expect(tokens.items[6].pos == 15);
    try expect(tokens.items[6].end == 17);
    try expect(tokens.items[7].tag == .identifier);
    try expect(tokens.items[7].pos == 19);
    try expect(tokens.items[7].end == 19);
    try expect(tokens.items[8].tag == .rparen);
    try expect(tokens.items[8].pos == 20);
    try expect(tokens.items[8].end == 20);
    var next_offset = tokens.getLast().end + 1;
    tokens.clearRetainingCapacity();
    indent = try next_token_line(source, next_offset, &tokens);
    try expect(indent == 2);
    try expect(tokens.items[0].tag == .keyword_return);
    try expect(tokens.items[0].pos == 24);
    try expect(tokens.items[0].end == 29);
    try expect(tokens.items[1].tag == .identifier);
    try expect(tokens.items[1].pos == 31);
    try expect(tokens.items[1].end == 31);
    try expect(tokens.items[2].tag == .plus);
    try expect(tokens.items[2].pos == 33);
    try expect(tokens.items[2].end == 33);
    try expect(tokens.items[3].tag == .identifier);
    try expect(tokens.items[3].pos == 35);
    try expect(tokens.items[3].end == 35);
    next_offset = tokens.getLast().end + 1;
    tokens.clearRetainingCapacity();
    indent = try next_token_line(source, next_offset, &tokens);
    try expect(indent == 0);
    try expect(tokens.items[0].tag == .identifier);
    try expect(tokens.items[0].pos == 38);
    try expect(tokens.items[0].end == 40);
    try expect(tokens.items[1].tag == .lparen);
    try expect(tokens.items[1].pos == 41);
    try expect(tokens.items[1].end == 41);
    try expect(tokens.items[2].tag == .integer_literal);
    try expect(tokens.items[2].pos == 42);
    try expect(tokens.items[2].end == 42);
    try expect(tokens.items[3].tag == .comma);
    try expect(tokens.items[3].pos == 43);
    try expect(tokens.items[3].end == 43);
    try expect(tokens.items[4].tag == .integer_literal);
    try expect(tokens.items[4].pos == 44);
    try expect(tokens.items[4].end == 45);
    try expect(tokens.items[5].tag == .rparen);
    try expect(tokens.items[5].pos == 46);
    try expect(tokens.items[5].end == 46);
}

test "get keyword" {
    try expect(get_keyword("i32").? == .keyword_integer_type);
    try expect(get_keyword("i16").? == .keyword_integer_type);
    try expect(get_keyword("i8").? == .keyword_integer_type);
    try expect(get_keyword("return").? == .keyword_return);
    try expect(get_keyword("i0") == null);
    try expect(get_keyword("i69") == null);
    try expect(get_keyword("hello") == null);
}
