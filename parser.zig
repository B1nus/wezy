pub const std = @import("std");
pub const tokenizer = @import("tokenizer.zig");
pub const Token = tokenizer.Token;
pub const SourceIndex = tokenizer.SourceIndex;

pub const TokenIndex = u32;
pub const IntegerSize = u32;
pub const StatementIndex = u32;
pub const ExpressionIndex = u32;

// TODO: Error handling.

pub fn parse(source: [:0]const u8, allocator: std.mem.Allocator) !Parsed {
    var offset: SourceIndex = 0;
    var functions = std.StringHashMap(FunctionDeclaration).init(allocator);
    var statements = std.ArrayList(Statement).init(allocator);
    var expressions = std.ArrayList(Expression).init(allocator);
    var indent_stack = std.ArrayList(SourceIndex).init(allocator);
    defer indent_stack.deinit();
    try indent_stack.append(0);

    var tokens = std.ArrayList(Token).init(allocator);
    defer tokens.deinit();

    while (tokens.items.len == 0 or tokens.getLast().tag != .eof) {
        tokens.clearRetainingCapacity();
        try tokenizer.next_token_line(source, offset, &indent_stack, &tokens);
        offset = tokens.getLast().end + 1;
        switch (tokens.items[0].tag) {
            .keyword_integer_type => {
                const identifier = tokens.items[1].literal(source);
                var parameters = std.StringHashMap(IntegerSize).init(allocator);

                for (0..(tokens.items.len - 3) / 3) |i| {
                    const int_size = std.fmt.parseInt(IntegerSize, source[tokens.items[3 + i * 3].pos + 1..tokens.items[3 + i * 3].end + 1], 10) catch { unreachable; };
                    try parameters.put(source[tokens.items[4 + i * 3].pos..tokens.items[4 + i * 3].end + 1], int_size);
                }

                var functions_statements = std.ArrayList(Statement).init(allocator);
                tokens.clearRetainingCapacity();
                try tokenizer.next_token_line(source, offset, &indent_stack, &tokens);
                tokens.orderedRemove(0);
                while (tokenizer.next_token(source, offset) != .eof and tokenizer.next_token(source, offset) != .dedentation) {
                    switch (tokens.items[0].tag) {
                        .keyword_return => {
                            try statements.append(Statement { .return_statement = try parse_expression(source, tokens[1..], null, &expressions) });
                        },
                        else => unreachable,
                    }

                    tokens.clearRetainingCapacity();
                    try tokenizer.next_token_line(source, offset, &indent_stack, &tokens);
                    offset = tokens.getLast().end + 1;
                }

                if (tokenizer.next_token(source, offset).tag == .dedentation) {
                    offset += 1;
                }



            },
            .identifier => {
                const identifier = source[token.items[0].pos..tokens.items[0].end + 1];
            },
            else => unreachable,
        }
        try functions.put(undefined, undefined);
        try statements.append(undefined);
        try expressions.append(undefined);
    }

    return Parsed{
        .functions = functions,
        .statements = statements,
        .expressions = expressions,
    };
}

pub const LineParser = struct {
    source: [:0]const u8,
    token_line: []Token,
    offset: TokenIndex,
    expressions: *std.ArrayList(Expression),

    pub fn init(source: [:0]const u8, token_line: []Token, offset: TokenIndex, expressions: *std.ArrayList(Expression)) LineParser {
        return LineParser {
            .source = source,
            .token_line = token_line,
            .offset = offset,
            .expressions = expressions,
        };
    }

    // Add more functions here later. maybe. but not now. Just get the tests passing first.

    // pratt parsing for the expression starting at offset
    pub fn parse_expression(self: *LineParser, offset: TokenIndex) !Expression {
        self.offset = offset;
        self.parse_prefix();
    }

    pub fn parse_prefix(self: *LineParser) !Expression {
        switch (self.current_token().tag) {
            .integer_literal => {
                return Expression {.integer_literal = self.current_token().literal(self.source)};
            },
            .minus => {
                self.offset += 1;
                try self.expressions.append(try self.parse_prefix());
                const rhs_index = self.expressions.items.len - 1;
                return Expression {.negation = rhs_index};
            },
            .plus => {
                self.offset += 1;
                return self.parse_prefix();
            },
            .identifier => {
                const identifier = self.current_token().literal(self.source);
                self.offset += 1;
                switch (self.current_token().tag) {
                    .lparen => {
                        var expressions = std.ArrayList(ExpressionIndex).init(self.expressions.allocator);
                        var expression = try self.parse_expression(self.offset + 1);
                        while (self.current_token().tag != .rparen and self.offset < self.token_line.len - 1) {
                            try self.expressions.append(expression);
                            try expressions.append(self.expressions.items.len - 1);
                            expression = try self.parse_expression(self.offset + 1);
                        }
                        return Expression {.call = .{identifier, expressions}};
                    },
                    .dot => unreachable,
                    else => return Expression { .identifier = identifier },
                }
            },
            .lparen => {
                self.offset += 1;
                const exp = self.parse_expression();
                if (self.token_line[self.offset].tag == .rparen) {
                    return exp;
                } else {
                    unreachable;
                }
            },
            else => unreachable,
        }
    }

    pub fn parse_infix(self: *LineParser, left: Expression) !Expression {
        switch (self.current_token().tag) {
            .rparen, .comma => {
                return left;
            },
            .plus => {
            },
            .minus => {
            },
            .dot => unreachable, // method call?
        }
    }

    pub fn current_token(self: LineParser) Token {
        return self.token_line[self.offset];
    }

    pub fn next_token(self: LineParser) Token {
        self.offset += 1;
        return self.current_token();
    }
};

pub const Parsed = struct {
    functions: std.StringHashMap(FunctionDeclaration),
    statements: std.ArrayList(Statement),
    expressions: std.ArrayList(Expression),

    pub fn deinit(self: @This()) void {
        var func_it = self.functions.valueIterator();
        for (func_it.next()) |func| {
            func.parameters.deinit();
            func.statements.deinit();
        }
        self.functions.deinit();
        self.statements.deinit();
    }
};

pub const FunctionDeclaration = struct {
    parameters: std.StringHashMap(IntegerSize),
    statements: std.ArrayList(Statement),
};

pub const Statement = union(enum) {
    return_statement: Expression,
    assignment: struct { []const u8, Expression },
};

pub const Expression = union(enum) {
    integer_literal: []const u8,
    negation: ExpressionIndex,
    addition: [2]ExpressionIndex,
    identifier: []const u8,
    call: struct { []const u8, std.ArrayList(ExpressionIndex) },
};

pub const expect = std.testing.expect;

test "Simple Add function" {
    const source =
        \\i32 add(i32 a, i32 b)
        \\  return a + b
        \\
        \\z = add(8, - 5)
    ;
    const parsed = try parse(source, std.testing.allocator);
    defer parsed.deinit();

    try expect(parsed.statements.items.len == 1);
    try expect(parsed.expressions.items.len == 7);
    try expect(parsed.statements.items[0] == Statement.assignment);
    const assign_ident, const assign_expr = parsed.statements.items[0].assignment;
    // Call Expression
    try expect(std.mem.eql(u8, assign_ident, "z"));
    try expect(assign_expr == Expression.call);
    const call_ident, const call_expressions = assign_expr.call;
    try expect(std.mem.eql(u8, call_ident, "add"));
    try expect(call_expressions.items.len == 2);
    const call_arg1 = parsed.expressions.items[call_expressions.items[0]];
    const call_arg2 = parsed.expressions.items[call_expressions.items[1]];
    try expect(call_expressions.items[0] == 2);
    try expect(call_arg1 == .integer_literal);
    try expect(call_arg2 == .negation);
    const call_int2 = parsed.expressions.items[call_arg2.negation].integer_literal;
    try expect(std.mem.eql(u8, call_arg1.integer_literal, "8"));
    try expect(std.mem.eql(u8, call_int2, "8"));

    // Function Declaration
    try expect(parsed.functions.count() == 1);
    try expect(parsed.functions.get("add") != null);
    try expect(parsed.functions.get("add").?.parameters.count() == 2);
    try expect(parsed.functions.get("add").?.parameters.get("a") != null);
    try expect(parsed.functions.get("add").?.parameters.get("b") != null);
    try expect(parsed.functions.get("add").?.parameters.get("a").? == 32);
    try expect(parsed.functions.get("add").?.parameters.get("b").? == 32);
    try expect(parsed.functions.get("add").?.statements.items.len == 1);
    try expect(parsed.functions.get("add").?.statements.items[0] == Statement.return_statement);
    // Function Statement
    const function_statement = parsed.functions.get("add").?.statements.items[0].return_statement;
    try expect(function_statement == Expression.addition);
    try expect(parsed.expressions.items[function_statement.addition[0]] == Expression.identifier);
    try expect(parsed.expressions.items[function_statement.addition[1]] == Expression.identifier);
    const a = parsed.expressions.items[function_statement.addition[0]].identifier;
    const b = parsed.expressions.items[function_statement.addition[1]].identifier;
    try expect(std.mem.eql(u8, a, "a"));
    try expect(std.mem.eql(u8, b, "b"));
}
