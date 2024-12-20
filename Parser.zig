pub const Tokenizer = @import("Tokenizer.zig");
pub const Token = Tokenizer.Token;
pub const std = @import("std");

tokenizer: *Tokenizer,
assignments: std.ArrayList(Assignment),
expressions: std.ArrayList(Expression),

pub const ExpressionIndex = usize;

pub const Precedence = enum {
    lowest,
    sum,
};

pub const Assignment = struct {
    identifier: []const u8,
    expression: Expression,
};

pub const Expression = union(enum) {
    integer: []const u8,
    addition: [2]ExpressionIndex,
    identifier: []const u8,
};

pub fn init(tokenizer: *Tokenizer, allocator: std.mem.Allocator) @This() {
    return @This(){
        .tokenizer = tokenizer,
        .assignments = std.ArrayList(Assignment).init(allocator),
        .expressions = std.ArrayList(Expression).init(allocator),
    };
}

pub fn deinit(self: @This()) void {
    self.assignments.deinit();
    self.expressions.deinit();
}

pub fn parse_assignment(self: *@This()) Assignment {
    while (self.tokenizer.current.tag == .newline) {
        self.advance();
    }
    const identifier = self.tokenizer.token_source(self.tokenizer.current);
    self.advance();
    self.advance_if(Token.Tag.equal);
    const expression = self.parse_expression(Precedence.lowest);
    self.advance();
    return Assignment{ .identifier = identifier, .expression = expression };
}

pub fn parse_expression(self: *@This(), precedence: Precedence) Expression {
    var lhs = self.parse_prefix();
    self.advance();

    while (!tag_is_end_of_line(self.tokenizer.current.tag) and !tag_is_end_of_line(self.tokenizer.peek.tag) and @intFromEnum(precedence) < @intFromEnum(get_precedence(self.tokenizer.current.tag))) {
        lhs = self.parse_infix(lhs);
    }

    return lhs;
}

pub fn tag_is_end_of_line(token_tag: Token.Tag) bool {
    return token_tag == .newline or token_tag == .eof;
}

pub fn parse_prefix(self: *@This()) Expression {
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

pub fn parse_infix(self: *@This(), lhs: Expression) Expression {
    switch (self.tokenizer.current.tag) {
        .plus => {
            const precedence = get_precedence(self.tokenizer.current.tag);
            self.advance();
            const lhs_index = self.append_expression(lhs);
            const rhs_index = self.append_expression(self.parse_expression(precedence));
            return Expression{ .addition = .{ lhs_index, rhs_index } };
        },
        else => unreachable,
    }
}

pub inline fn get_precedence(token_tag: Token.Tag) Precedence {
    return switch (token_tag) {
        .plus => Precedence.sum,
        else => unreachable,
    };
}

pub fn append_expression(self: *@This(), expression: Expression) ExpressionIndex {
    self.expressions.append(expression) catch unreachable;
    return self.expressions.items.len - 1;
}

pub fn advance(self: *@This()) void {
    self.tokenizer.current = self.tokenizer.peek;
    self.tokenizer.peek = self.tokenizer.next_token();
}

pub fn advance_if(self: *@This(), token_tag: Token.Tag) void {
    if (token_tag == self.tokenizer.current.tag) {
        self.advance();
    } else {
        unreachable;
    }
}

pub const expect = std.testing.expect;
test "assign parsing" {
    const source = "z = 5 + 4";
    var tokenizer = Tokenizer.init(source);
    var parser = @This().init(&tokenizer, std.testing.allocator);
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
        \\    
        \\   
        \\x = z + 2
    ;
    var tokenizer = Tokenizer.init(source);
    var parser = @This().init(&tokenizer, std.testing.allocator);
    defer parser.deinit();

    try parser.assignments.append(parser.parse_assignment());
    try parser.assignments.append(parser.parse_assignment());
    try expect(std.mem.eql(u8, parser.assignments.items[0].identifier, "z"));
    try expect(std.mem.eql(u8, parser.expressions.items[parser.assignments.items[0].expression.addition[0]].integer, "1"));
    try expect(std.mem.eql(u8, parser.expressions.items[parser.assignments.items[0].expression.addition[1]].integer, "1"));

    try expect(std.mem.eql(u8, parser.assignments.items[1].identifier, "x"));
    try expect(std.mem.eql(u8, parser.expressions.items[parser.assignments.items[1].expression.addition[0]].identifier, "z"));
    try expect(std.mem.eql(u8, parser.expressions.items[parser.assignments.items[1].expression.addition[1]].integer, "2"));
}

test "pratt parsing" {
    const source = "1 + 2 + 3";
    var tokenizer = Tokenizer.init(source);
    var parser = @This().init(&tokenizer, std.testing.allocator);
    defer parser.deinit();

    const expression = parser.parse_expression(@This().Precedence.lowest);
    try expect(std.mem.eql(u8, parser.expressions.items[parser.expressions.items[expression.addition[0]].addition[0]].integer, "1"));
    try expect(std.mem.eql(u8, parser.expressions.items[parser.expressions.items[expression.addition[0]].addition[1]].integer, "2"));
    try expect(std.mem.eql(u8, parser.expressions.items[expression.addition[1]].integer, "3"));
}

test "integer literal assignments" {
    const source =
        \\x = 1
        \\z = 6
        \\z = 9
    ;
    var tokenizer = Tokenizer.init(source);
    var parser = @This().init(&tokenizer, std.testing.allocator);
    defer parser.deinit();

    while (parser.tokenizer.current.tag != .eof) {
        try parser.assignments.append(parser.parse_assignment());
    }
}
