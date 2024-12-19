pub const std = @import("std");

pub const ExpressionIndex = usize;
pub const SourceIndex = usize;

pub const Expression = union(enum) {
    addition: [2]ExpressionIndex,
    subtraction: [2]ExpressionIndex,
    multiplication: [2]ExpressionIndex,
    negation: ExpressionIndex,
    integer: []const u8,
};

pub const Token = struct {
    pos: SourceIndex,
    tag: Tag,

    pub const Tag = enum {
        plus,
        minus,
        asterisk,
        integer,
        newline,
    };
};

pub const Parser = struct {
    source: [:0]const u8,
    offset: SourceIndex,

    current: Token,
    peek: Token,

    expressions: std.ArrayList(Expression),

    pub fn init(source: [:0]const u8, allocator: std.mem.Allocator) Parser {
        var parser = Parser{
            .source = source,
            .offset = 0,
            .expressions = std.ArrayList(Expression).init(allocator),
            .current = undefined,
            .peek = undefined,
        };

        // Fill current and peek with the first tokens
        parser.current = parser.next_token();
        parser.peek = parser.next_token();

        return parser;
    }

    pub fn parse_expression(self: *Parser, precedence: usize) Expression {
        var left = self.parse_prefix();
        self.advance();

        while (self.peek.tag != .newline and precedence < get_precedence(self.current.tag)) {
            left = self.parse_infix(left);
        }

        return left;
    }

    // After this function is called. Current points at the last token in the expression
    pub fn parse_infix(self: *Parser, left: Expression) Expression {
        switch (self.current.tag) {
            .plus, .minus, .asterisk => {
                const operator = self.current.tag;
                self.advance();
                const left_index = self.append_expression(left);
                const right_index = self.append_expression(self.parse_expression(1));
                return switch (operator) {
                    .plus => Expression{ .addition = .{ left_index, right_index } },
                    .minus => Expression{ .subtraction = .{ left_index, right_index } },
                    .asterisk => Expression{ .multiplication = .{ left_index, right_index } },
                    else => unreachable,
                };
            },
            else => unreachable,
        }
    }

    // Parse a prefix expressions. +4, -4 and 4 count as prefix expressions. After this function is called
    // the current token points at the last token in the prefix expression.
    pub fn parse_prefix(self: *Parser) Expression {
        switch (self.current.tag) {
            .plus => {
                self.advance_if(Token.Tag.integer);
                return self.parse_integer();
            },
            .integer => return self.parse_integer(),
            .minus => {
                self.advance_if(Token.Tag.integer);
                const index = self.append_expression(self.parse_integer());
                return Expression{ .negation = index };
            },
            else => unreachable,
        }
    }

    // Parse the current token as an integer. This does not modify the current or peek token.
    pub fn parse_integer(self: *Parser) Expression {
        const start = self.current.pos;
        var end = start;
        while (self.source[end] >= '0' and self.source[end] <= '9') {
            end += 1;
        }
        return Expression{ .integer = self.source[start..end] };
    }

    pub fn get_precedence(token_tag: Token.Tag) usize {
        return switch (token_tag) {
            .asterisk => 2,
            .plus, .minus => 1,
            .integer => 0,
            else => unreachable,
        };
    }

    pub fn advance_if(self: *Parser, token: Token.Tag) void {
        if (self.peek.tag == token) {
            self.advance();
        } else {
            unreachable;
        }
    }

    pub fn append_expression(self: *Parser, expression: Expression) ExpressionIndex {
        self.expressions.append(expression) catch unreachable;
        return self.expressions.items.len - 1;
    }

    pub fn advance(self: *Parser) void {
        self.current = self.peek;
        self.peek = self.next_token();
    }

    pub fn next_token(self: *Parser) Token {
        if (self.offset >= self.source.len) {
            return Token{ .pos = self.source.len, .tag = .newline };
        }
        var token = Token{ .pos = self.offset, .tag = undefined };
        switch (self.source[token.pos]) {
            '+' => token.tag = .plus,
            '-' => token.tag = .minus,
            '*' => token.tag = .asterisk,
            '0'...'9' => {
                while (self.source[self.offset] >= '0' and self.source[self.offset] <= '9') {
                    self.offset += 1;
                }
                self.offset -= 1;
                token.tag = .integer;
            },
            else => {
                self.offset += 1;
                return self.next_token();
            },
        }
        self.offset += 1;
        return token;
    }
};

pub fn render_expression(expression: Expression, expressions: []Expression) void {
    switch (expression) {
        .integer => |int| std.debug.print("{s}", .{int}),
        .addition => |ids| {
            const id1, const id2 = ids;
            std.debug.print("(", .{});
            render_expression(expressions[id1], expressions);
            std.debug.print(" + ", .{});
            render_expression(expressions[id2], expressions);
            std.debug.print(")", .{});
        },
        .subtraction => |ids| {
            const id1, const id2 = ids;
            std.debug.print("(", .{});
            render_expression(expressions[id1], expressions);
            std.debug.print(" - ", .{});
            render_expression(expressions[id2], expressions);
            std.debug.print(")", .{});
        },
        .multiplication => |ids| {
            const id1, const id2 = ids;
            std.debug.print("(", .{});
            render_expression(expressions[id1], expressions);
            std.debug.print(" * ", .{});
            render_expression(expressions[id2], expressions);
            std.debug.print(")", .{});
        },
        .negation => |id| {
            std.debug.print("-", .{});
            render_expression(expressions[id], expressions);
        },
    }
}

pub const expect = std.testing.expect;
test "parsing" {
    const source = "1 + 1 + 2";
    var parser = Parser.init(source, std.testing.allocator);
    defer parser.expressions.deinit();
    const expression = parser.parse_expression(0);
    render_expression(expression, parser.expressions.items);
    std.debug.print("\n", .{});
}

test "parsing weirdo expression" {
    const source = "4 + 5 -6 * -5";
    var parser = Parser.init(source, std.testing.allocator);
    defer parser.expressions.deinit();
    const expression = parser.parse_expression(0);
    render_expression(expression, parser.expressions.items);
    std.debug.print("\n", .{});
}

test "tokens" {
    const source = "4 + 5 -6 + -5";
    var parser = Parser.init(source, std.testing.allocator);
    defer parser.expressions.deinit();
    try expect(parser.current.tag == Token.Tag.integer);
    try expect(parser.peek.tag == Token.Tag.plus);
    try expect(parser.next_token().tag == Token.Tag.integer);
    try expect(parser.next_token().tag == Token.Tag.minus);
    try expect(parser.next_token().tag == Token.Tag.integer);
    try expect(parser.next_token().tag == Token.Tag.plus);
    try expect(parser.next_token().tag == Token.Tag.minus);
    try expect(parser.next_token().tag == Token.Tag.integer);
    try expect(parser.next_token().tag == Token.Tag.newline);
    try expect(parser.next_token().tag == Token.Tag.newline);
    try expect(parser.next_token().tag == Token.Tag.newline);
    try expect(parser.next_token().tag == Token.Tag.newline);
    try expect(parser.next_token().tag == Token.Tag.newline);
}
