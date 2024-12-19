source: [:0]const u8,
offset: SourceIndex,
current: Token,
peek: Token,

pub const SourceIndex = usize;

pub const Token = struct {
    pos: SourceIndex,
    tag: Tag,

    pub const Tag = enum {
        identifier,
        equal,
        integer,
        plus,
        newline,
        eof,
    };
};

pub fn init(source: [:0]const u8) @This() {
    var self = @This(){ .source = source, .offset = 0, .current = undefined, .peek = undefined };

    // Fill current and peek with the first two tokens
    self.current = self.next_token();
    self.peek = self.next_token();

    return self;
}

pub fn next_token(self: *@This()) Token {
    const State = enum {
        start,
        integer,
        identifier,
    };

    var token = Token{ .pos = self.offset, .tag = undefined };
    state: switch (State.start) {
        .start => {
            switch (self.source[self.offset]) {
                0 => return Token{ .pos = self.source.len, .tag = .eof },
                '=' => token.tag = .equal,
                '+' => token.tag = .plus,
                '\n' => token.tag = .newline,
                'a'...'z' => continue :state .identifier,
                '0'...'9' => continue :state .integer,
                ' ', '\t' => {
                    token.pos += 1;
                    self.offset += 1;
                    continue :state .start;
                },
                else => unreachable,
            }

            // For single character tokens, we need to move offset past them.
            self.offset += 1;
        },
        .integer => {
            self.offset += 1;
            switch (self.source[self.offset]) {
                '0'...'9' => continue :state .integer,
                else => token.tag = .integer,
            }
        },
        .identifier => {
            self.offset += 1;
            switch (self.source[self.offset]) {
                'a'...'z' => continue :state .identifier,
                else => token.tag = .identifier,
            }
        },
    }

    return token;
}

// The source code for a token. for an identifier, this is the identifier as a string.
pub fn token_source(self: @This(), token: Token) []const u8 {
    switch (token.tag) {
        .integer => {
            var end: SourceIndex = token.pos + 1;
            while (self.source[end] >= '0' and self.source[end] <= '9') {
                end += 1;
            }
            return self.source[token.pos..end];
        },
        .identifier => {
            var end: SourceIndex = token.pos + 1;
            while (self.source[end] >= 'a' and self.source[end] <= 'z') {
                end += 1;
            }
            return self.source[token.pos..end];
        },
        else => unreachable,
    }
}

pub const expect = @import("std").testing.expect;
test "assign tokens" {
    // The indentation is encoded here. The first tokens position is the indentation
    // of the new line. It does not get easier than this.
    const source = "z= 5 +4  ";
    var tokenizer = @This().init(source);
    try expect(tokenizer.current.tag == .identifier);
    try expect(tokenizer.current.pos == 0);
    try expect(tokenizer.peek.tag == .equal);
    try expect(tokenizer.peek.pos == 1);
    const token_5 = tokenizer.next_token();
    const token_plus = tokenizer.next_token();
    const token_4 = tokenizer.next_token();
    const token_eof = tokenizer.next_token();
    try expect(token_5.tag == .integer);
    try expect(token_5.pos == 3);
    try expect(token_plus.tag == .plus);
    try expect(token_plus.pos == 5);
    try expect(token_4.tag == .integer);
    try expect(token_4.pos == 6);
    try expect(token_eof.tag == .eof);
    try expect(token_eof.pos == 9);
}
