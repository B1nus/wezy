pub const std = @import("std");

pub const Tokenizer = struct {
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

    pub fn init(source: [:0]const u8) Tokenizer {
        var self = Tokenizer{ .source = source, .offset = 0, .current = undefined, .peek = undefined };

        // Fill current and peek with the first two tokens
        self.current = self.next_token();
        self.peek = self.next_token();

        return self;
    }

    pub fn next_token(self: *Tokenizer) Token {
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
    pub fn token_source(self: Tokenizer, token: Token) []const u8 {
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
};

pub const Parser = struct {
    tokenizer: *Tokenizer,
    assignments: std.ArrayList(Assignment),
    expressions: std.ArrayList(Expression),

    pub const ExpressionIndex = usize;

    pub const Precedence = enum {
        zero,
        sum,
    };

    pub const Token = Tokenizer.Token;

    pub const Assignment = struct {
        identifier: []const u8,
        expression: Expression,
    };

    pub const Expression = union(enum) {
        integer: []const u8,
        addition: [2]ExpressionIndex,
        identifier: []const u8,
    };

    pub fn init(tokenizer: *Tokenizer, allocator: std.mem.Allocator) Parser {
        return Parser{
            .tokenizer = tokenizer,
            .assignments = std.ArrayList(Assignment).init(allocator),
            .expressions = std.ArrayList(Expression).init(allocator),
        };
    }

    pub fn deinit(self: Parser) void {
        self.assignments.deinit();
        self.expressions.deinit();
    }

    pub fn parse_program(self: *Parser) void {
        while (self.tokenizer.current.tag != .eof) {
            self.assignments.append(self.parse_assignment()) catch unreachable;
        }
    }

    pub fn parse_assignment(self: *Parser) Assignment {
        while (self.tokenizer.current.tag != .identifier) {
            self.advance();
        }
        const identifier = self.tokenizer.token_source(self.tokenizer.current);
        self.advance();
        self.advance_if(Token.Tag.equal);
        const expression = self.parse_expression(Precedence.zero);
        return Assignment{ .identifier = identifier, .expression = expression };
    }

    pub fn parse_expression(self: *Parser, precedence: Precedence) Expression {
        var lhs = self.parse_prefix();
        self.advance();

        while (!tag_is_end_of_line(self.tokenizer.peek.tag) and @intFromEnum(precedence) < @intFromEnum(get_precedence(self.tokenizer.current.tag))) {
            lhs = self.parse_infix(lhs);
        }

        return lhs;
    }

    pub fn tag_is_end_of_line(token_tag: Token.Tag) bool {
        return token_tag == .newline or token_tag == .eof;
    }

    pub fn parse_prefix(self: *Parser) Expression {
        switch (self.tokenizer.current.tag) {
            .integer => {
                return Expression{ .integer = self.tokenizer.token_source(self.tokenizer.current) };
            },
            .identifier => {
                return Expression{ .identifier = self.tokenizer.token_source(self.tokenizer.current) };
            },
            else => unreachable,
        }
    }

    pub fn parse_infix(self: *Parser, lhs: Expression) Expression {
        switch (self.tokenizer.current.tag) {
            .plus => {
                self.advance();
                const rhs = self.parse_expression(get_precedence(self.tokenizer.current.tag));
                const lhs_index = self.append_expression(lhs);
                const rhs_index = self.append_expression(rhs);
                return Expression{ .addition = .{ lhs_index, rhs_index } };
            },
            else => unreachable,
        }
    }

    pub inline fn get_precedence(token_tag: Token.Tag) Precedence {
        return switch (token_tag) {
            .plus => Precedence.sum,
            .integer => Precedence.zero,
            else => unreachable,
        };
    }

    pub fn append_expression(self: *Parser, expression: Expression) ExpressionIndex {
        self.expressions.append(expression) catch unreachable;
        return self.expressions.items.len - 1;
    }

    pub fn advance(self: *Parser) void {
        self.tokenizer.current = self.tokenizer.peek;
        self.tokenizer.peek = self.tokenizer.next_token();
    }

    pub fn advance_if(self: *Parser, token_tag: Token.Tag) void {
        if (token_tag == self.tokenizer.current.tag) {
            self.advance();
        } else {
            unreachable;
        }
    }
};

pub const expect = std.testing.expect;
test "assign tokens" {
    // The indentation is encoded here. The first tokens position is the indentation
    // of the new line. It does not get easier than this.
    const source = "z= 5 +4  ";
    var tokenizer = Tokenizer.init(source);
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

test "assign parsing" {
    const source = "z = 5 + 4";
    var tokenizer = Tokenizer.init(source);
    var parser = Parser.init(&tokenizer, std.testing.allocator);
    defer parser.deinit();
    const assignment = parser.parse_assignment();
    try expect(std.mem.eql(u8, assignment.identifier, "z"));
    try expect(std.mem.eql(u8, parser.expressions.items[assignment.expression.addition[0]].integer, "5"));
    try expect(std.mem.eql(u8, parser.expressions.items[assignment.expression.addition[1]].integer, "4"));
}

test "many assign expressions" {
    const source =
        \\z = 1 + 1
        \\
        \\x = z + 2
    ;
    var tokenizer = Tokenizer.init(source);
    var parser = Parser.init(&tokenizer, std.testing.allocator);
    defer parser.deinit();

    parser.parse_program();
    try expect(std.mem.eql(u8, parser.assignments.items[0].identifier, "z"));
    try expect(std.mem.eql(u8, parser.expressions.items[parser.assignments.items[0].expression.addition[0]].integer, "1"));
    try expect(std.mem.eql(u8, parser.expressions.items[parser.assignments.items[0].expression.addition[1]].integer, "1"));

    try expect(std.mem.eql(u8, parser.assignments.items[1].identifier, "x"));
    try expect(std.mem.eql(u8, parser.expressions.items[parser.assignments.items[1].expression.addition[0]].identifier, "z"));
    try expect(std.mem.eql(u8, parser.expressions.items[parser.assignments.items[1].expression.addition[1]].integer, "2"));
}
