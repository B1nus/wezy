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
        indentation,
        dedentation,
        equal,
        eof,
        invalid,
        unexpected_indentation,
        invalid_dedentation,
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

// Return all tokens for a source file.
pub fn tokenize(source: [:0]const u8, allocator: std.mem.Allocator) !std.ArrayList(Token) {
    var tokens = std.ArrayList(Token).init(allocator);
    var indent_stack = std.ArrayList(u32).init(allocator);
    defer indent_stack.deinit();

    try indent_stack.append(0);
    var offset: u32 = 0;

    while (true) {
        try next_token_line(source, offset, &indent_stack, &tokens);
        if (tokens.getLast().tag == .eof) break;
        offset = tokens.getLast().end + 1;
    }

    return tokens;
}

// Return all of the tokens from the next non-empty line along with indentation
//
// TODO: Add a check for the weird magic values on top of the utf8 files.
pub fn next_token_line(source: [:0]const u8, offset: u32, indent_stack: *std.ArrayList(u32), tokens: *std.ArrayList(Token)) !void {
    var index = offset;
    var indent: u32 = 0;

    while (source[index] == ' ' or source[index] == '\t' or source[index] == '\r') { // Should \r be here?
        indent += 1;
        index += 1;
    }

    // The line is empty. Skip to the next line.
    if (source[index] == '\n') {
        return next_token_line(source, index + 1, indent_stack, tokens);
    }

    // Indentation token/dedentation tokens. This algorithm is my version of Pythons indentation parser. It's more or less the same as python's.
    //
    // Check that it is not the beginning of the file
    if (index != indent) {
        var top_of_stack = indent_stack.getLast();
        if (indent == top_of_stack) {
            try tokens.append(Token{ .pos = offset + index - indent - 1, .end = offset + index - indent - 1, .tag = .newline });
        } else if (indent > top_of_stack) {
            try indent_stack.append(indent);
            try tokens.append(Token{ .pos = offset + top_of_stack, .end = offset + indent - 1, .tag = .indentation });
        } else { // indent < top_of_stack
            _ = indent_stack.pop();
            while (indent < top_of_stack) {
                const prev = top_of_stack;
                top_of_stack = indent_stack.pop();
                try tokens.append(Token{ .pos = offset + top_of_stack, .end = offset + prev - 1, .tag = .dedentation }); // A dedentation having a position doesn't really make sense. But whatever.
            }
            if (indent != top_of_stack) {
                try indent_stack.append(indent);
                try tokens.append(Token{ .pos = offset + top_of_stack, .end = offset + indent - 1, .tag = .invalid_dedentation });
            }
        }
    } else {
        // Don't indent the top-level. But if they do, try to add it to the indentation and move on.
        if (indent != 0) {
            try tokens.append(Token{ .pos = 0, .end = indent - 1, .tag = .unexpected_indentation });
            try indent_stack.append(indent);
        }
    }

    var token = next_token(source, index);

    while (token.tag != .eof and token.tag != .newline) {
        try tokens.append(token);
        index = token.end + 1;
        token = next_token(source, index);
    }

    if (token.tag == .eof) {
        try tokens.append(token);
    }
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
                '=' => token.tag = .equal,
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
        \\z = add(9,-8)
    ;
    const tokens = try tokenize(source, std.testing.allocator);
    defer tokens.deinit();

    try expect(tokens.items.len == 24);
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
    try expect(tokens.items[9].tag == .indentation);
    try expect(tokens.items[9].pos == 22);
    try expect(tokens.items[9].end == 23);
    try expect(tokens.items[10].tag == .keyword_return);
    try expect(tokens.items[10].pos == 24);
    try expect(tokens.items[10].end == 29);
    try expect(tokens.items[11].tag == .identifier);
    try expect(tokens.items[11].pos == 31);
    try expect(tokens.items[11].end == 31);
    try expect(tokens.items[12].tag == .plus);
    try expect(tokens.items[12].pos == 33);
    try expect(tokens.items[12].end == 33);
    try expect(tokens.items[13].tag == .identifier);
    try expect(tokens.items[13].pos == 35);
    try expect(tokens.items[13].end == 35);
    try expect(tokens.items[14].tag == .dedentation);
    // Not testing dedentation position. because it doesn't matter.
    try expect(tokens.items[15].tag == .identifier);
    try expect(tokens.items[15].pos == 38);
    try expect(tokens.items[15].end == 38);
    try expect(tokens.items[16].tag == .equal);
    try expect(tokens.items[16].pos == 40);
    try expect(tokens.items[16].end == 40);
    try expect(tokens.items[17].tag == .identifier);
    try expect(tokens.items[17].pos == 42);
    try expect(tokens.items[17].end == 44);
    try expect(tokens.items[18].tag == .lparen);
    try expect(tokens.items[18].pos == 45);
    try expect(tokens.items[18].end == 45);
    try expect(tokens.items[19].tag == .integer_literal);
    try expect(tokens.items[19].pos == 46);
    try expect(tokens.items[19].end == 46);
    try expect(tokens.items[20].tag == .comma);
    try expect(tokens.items[20].pos == 47);
    try expect(tokens.items[20].end == 47);
    try expect(tokens.items[21].tag == .integer_literal);
    try expect(tokens.items[21].pos == 48);
    try expect(tokens.items[21].end == 49);
    try expect(tokens.items[22].tag == .rparen);
    try expect(tokens.items[22].pos == 50);
    try expect(tokens.items[22].end == 50);
    try expect(tokens.items[23].tag == .eof);
    try expect(tokens.items[23].pos == 51);
    try expect(tokens.items[23].end == 51);
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
