pub const std = @import("std");
pub const tokenizer = @import("tokenizer.zig");

pub const TokenIndex = u32;
pub const SourceIndex = u32;
pub const StatementIndex = u32;
pub const ExpressionIndex = u32;
pub const TypeExpressionIndex = u32;

pub const Parser = struct {
    source: [:0]const u8,
    tokens: []tokenizer.Token,
    offset: TokenIndex,

    // This is the ast.
    expressions: std.ArrayList(Expression),
    type_expressions: std.ArrayList(TypeExpression),
    statements: std.ArrayList(Statement),

    pub const Error = struct {
        pos: TokenIndex,
        end: TokenIndex,
        tag: Tag,

        pub const Tag = enum {
            invalid_parameter, // "Parameters are formated with a type and a name: `do_something(i32 a, i32 b)`". (If none of the more specific errors apply, this one is used)
            missing_equals_or_parenthesis, // "Use parenthesis to declare a function, use equals to declare a variable." (Anly applies in the top level where both functions and bindings are possible)
            missing_equals, // "Write [insert specific example by just inserting an equals sign after the identifier]" (Applies ouside of the top level wher functions are impossible)
            missing_expression, // Can't assign/bind/unary/binary without an expression.
            invalid_expression, // invalid token combinations in any kind of expression.
            unterminated_parenthesis, // A parenthesis must be closed on the same line. (before a indent/dedent/newline token, multiline strings don't count of course)
            invalid_token,
            unexpected_indentation,
            invalid_return_type, // "[insert invalid type] is not a valid return type for [insert function declaration]"

            // To help people with common errors. The compiler shows an example of how to fix the error.
            // Add more as you learn what errors users encounter.
            //
            // TODO: Figure out how to generate specific examples for the users code. In the same way rust does.
            missing_parameter_type, // "Parameter's need a type, like this: [insert specific example with i32 as type].
            missing_parameter_name, // "Give your parameter a name. [insert specific example with random names (a,b,c,d,e,f,g for example)]".
            parameter_order, // "Write [insert specific example] instead.
            parameter_order_and_colon, // "Write [insert specific example] instead.
            parameter_colon, // "Write [insert specific example] instead."
            double_equals, // "crust uses a single equals for comparison. Write [insert specific example] instead."
            missing_comma, // "parameters are separated by commas."
            multiple_return_types, // "Use a tuple to return multiple types: `[insert specific example of how they should write it]`".
            multiple_assign, // "Use tuple destructuring: [insert specific example]"
            multiple_bind, // "Use tuple desctructuring: [insert specific example]"
            multiple_typed_bind, // "Use a tuple: [insert specific example]"
            and_operator, // "Use the keyword 'and' instead: [insert specific example]"
            or_operator, // "Use the keyword 'or' instead: [insert specific example]"
            not_operator, // "Use the keyword 'not' instead: [insert specific example]"
            bitwise_and_operator, // "Use the function 'bitwise_and()' instead: [insert specific example]"
            bitwise_or_operator, // "Use the function 'bitwise_or()' instead: [insert specific example]"
            bitwise_not_operator, // "Use the function 'bitwise_not()' instead: [insert specific example]"
            expression_statement, // "Assign the expression to a variable: 'thing = [insert the statement expression]'"

            // TODO: crust explain #13 for an in deepth explaination. Use @intFromEnum and @enumFromInt to access their indicies. Place the longer explainations in a new file called compiler_errors.zig
        };
    };
};

// Size of an integer in bits.
pub const IntegerSize = u32;

pub const TypeExpression = union(enum) {
    integer: IntegerSize,
    // list: TypeExpressionIndex,
    // set: TypeExpressionIndex,
    // map: [2]TypeExpressionIndex,
    // tuple: std.ArrayList(TypeExpressionIndex),
};

pub const Expression = union(enum) {
    call: struct { []const u8, std.ArrayList(ExpressionIndex) },
    integer: []const u8,
    addition: [2]ExpressionIndex,
};

pub const Statement = union(enum) {
    // Only allow in top level:
    function: FunctionStatement,
    use: UseStatement,
    
    // Only allow in function bodies:
    @"return": ExpressionIndex,
    
    // Only allow in loops
    @"continue", // TODO: LABEL
    @"break", // TODO: LABEL

    // Allowed everywhere.
    assignment: AssignmentStatement, // This contains both assignments and bindings. The first occurence of an ident i a binding. Explicit type allows for shadowing. This might be confusing to newcommer.
    loop: std.ArrayList(StatementIndex),
    @"if": std.ArrayList(StatementIndex),
    if_else: [2]std.ArrayList(StatementIndex),
    // expression: Expression, // I don't want this. but it might help some users.
};

// Expressions for types, that is i32, f64, (f64, i32), [i32], {i64}, {i64:i32} etc...
pub const TypeExpression = union(enum) {
    integer: u32, // The number is the size in bits. The token "i32" giver: TypeExpression { .integer = 32 }.
    // f32,
    // f64,
    list: TypeExpression,
    set: TypeExpression,
    map: MapTypeExpression,
    tuple: TupleTypeExpression,
};
pub const MapTypeExpression = struct {
    key: TypeExpression,
    value: TypeExpression,
};
pub const TupleTypeExpression = std.ArrayList(TypeExpression);

pub const FunctionStatement = struct {
    identifier: []const u8,
    parameters: std.StringHashMap(TypeExpression),
    contents: std.ArrayList(FunctionStatement),
};

pub const Expression = union(enum) {
    binary: BinaryExpression,
    integer_literal: TokenIndex,
    unary: UnaryExpression,
    call: CallExpression,
    identifier: []const u8,
};

pub const BinaryExpression = struct {
    lhs: Expression,
    rhs: Expression,
    tag: Tag,

    pub const Tag = enum {
        addition,
        // subtractions,
        // multiplication,
        // division,
        // power,
        // equals,
        // and,
        // or,
    };
};

pub const UnaryExpression = struct {
    rhs: Expression,
    tag: Tag,

    pub const Tag = enum {
        not,
    };
};

pub const CallExpression = struct {
    identifier: []const u8,
    parameters: std.ArrayList(Expression),
};

// Note: we need to keep track of the environment variables to know if something is an binding or assignment. The ast only handles the semantics, not the meaning so this is
// something you handle in compiler.zig instead.
pub const AssignmentStatement = struct {
    explicit_type: ?TypeExpression,
    identifier: []const u8,
    expression: Expression,
};

// Remember:
// wasm drop
// wasm labels
// No function statements in functions
// No use statement in functions
// No return outside of functions
// No closures. functions only use their arguments
// Shadowing/Rebinding when using explicit type. This is in the compiler, not the parser
// Bitwise ops cannot be named and, not, or which are keywords. use bitwise_or(x,y) or bit_or(x,y) instead. It's more clear this way so it's a good change.
// Present errors simply. do not include details and technical words such as parser, tokenizer etc...
// Pratt parsing for type expressions

pub fn parse(source: [:0]const u8, tokens: []tokenizer.Token, allocator: std.mem.Allocator) !Program {
    var errors = std.ArrayList(ParserError).init(allocator);
    var top_level_statements = std.ArrayList(TopLevelStatement).init(allocator);
    var offset: TokenIndex = 0;
    var next_top_level_statement = parse_next_top_level_statement(source, tokens, &offset, allocator);

    while (next_top_level_statement) |next_top_level| {
        if (next_top_level) |statement| {
            top_level_statements.append(statement);
            offset += 1;
        } else |new_errors| {
            try errors.appendSlice(new_errors.items);
            new_errors.deinit();
            // Skip to the next line after error. TODO: Make this behaviour smarter.
            while (!is_line_end(tokens[offset])) {
                offset += 1;
            }
            if (tokens[offset].tag == .eof) {
                break;
            }
            offset += 1;
        }
        next_top_level_statement = parse_next_top_level_statement(source, tokens, &offset, allocator);
    }

    return Program{
        .contents = top_level_statements,
        .errors = errors,
    };
}

pub fn parse_next_top_level_statement(source: [:0]const u8, tokens: []tokenizer.Token, offset: *TokenIndex, allocator: std.mem.Allocator) ?std.ArrayList(ParserError)!TopLevelStatement {
    var errors = std.ArrayList(ParserError).init(allocator);

    const State = enum {
        start,
        identifier,
        starts_with_type,
        type_then_identifier,
        function,
        assignment,
    };
    state: switch (State.start) {
        .start => {
            switch (tokens[offset.*].tag) {
                .keyword_integer_type => continue :state .starts_with_type,
                .identifier => continue :state .identifier,
                // TODO: need more cases here for type parsing, we need pratt parsing for that.
                else => unreachable, // TODO: Nice error handling here.
            }
        },
        .starts_with_type => {
            offset.* += 1;
            switch (tokens[offset.*].tag) {
                .identifier => continue :state .first_type_then_identifier,
                else => unreachable, // TODO: Nice error handling here.
            }
        },
        .type_then_identifier, .identifier => {
            offset.* += 1;
            switch (tokens[offset.*].tag) {
                .lparen => continue :state .function,
                .equal => continue :state .assignment,
                else => unreachable, // TODO: Error handling
            }
        },
        .function => {
            offset.* += 1;
            const identifier = token_source(source, tokens[offset.* - 2]);
            var parameters = std.StringHashMap(TypeExpression).init(allocator);
            while (!is_line_end(tokens[offset.*]) and !(tokens[offset.*].tag == .rparen)) {
                if (tokens[offset.* + 1].tag == .identifier) {
                    switch (tokens[offset.*].tag) {
                        .integer_literal => {
                            const size_string = token_source(source, tokens[offset.*])[1..];
                            const bit_size = std.fmt.parseInt(u32, std.fmt.parseInt(u32, size_string, 10)) catch {
                                unreachable; // TODO: Return an error that the size is too large.
                            };

                            if (parameters.fetchPut(TypeExpression{ .integer = bit_size })) |_| {
                                unreachable; // TODO: Error about parameters having the same name.
                            }
                        },
                        else => unreachable, // TODO: Error handling
                    }
                } else {
                    unreachable; // TODO: Error Handling
                }
                offset.* += 2;
                switch (tokens[offset.*].tag) {
                    .comma => {
                        offset.* += 1; // Allows you toe write function(i32 x, i32 y,). Honestly not a problem. I don't care.
                    },
                    .rparen => break,
                    .keyword_integer_type => {
                        try errors.append(ParserError{ .pos = tokens[offset.*].pos, .end = tokens[offset.*].pos, .tag = .missing_comma });
                        // NOTE: It will keep trying to parse the parameters.
                    },
                    else => unreachable, // TODO: Error Handling.
                }
            }

            if (parse_function_contents(source, tokens, offset, allocator)) |function_contents| {
                if (errors.items.len > 0) {
                    return errors;
                } else {
                    return TopLevelStatement{ .function = FunctionStatement{ .identifier = identifier, .parameters = parameters, .contents = function_contents } };
                }
            } else |new_errors| {
                try errors.appendSlice(new_errors.items);
                new_errors.deinit();
                return errors;
            }
        },
    }
}

fn parse_function_contents(source: [:0]const u8, tokens: []tokenizer.Token, offset: *TokenIndex, allocator: std.mem.Allocator) std.ArrayList(ParserError)!std.ArrayList(FunctionContentStatement) {
    var block = std.ArrayList(FunctionStatement).init(allocator);
    var errors = std.ArrayList(ParserError).init(allocator);
    while (tokens[offset.*].tag != .dedentation and tokens[offset.*].tag != .eof) {
        if (parse_function_statement(source, tokens, offset, allocator)) |function_statement| {
            try block.append(function_statement);
        } else |new_errors| {
            try errors.appendSlice(new_errors);
            new_errors.deinit();
        }
    }
    if (errors.items.len > 0) {
        return errors;
    } else {
        return block;
    }
}

fn parse_function_statement(source: [:0]const u8, tokens: []tokenizer.Token, offset: *TokenIndex, allocator: std.mem.Allocator) std.ArrayList(ParserError)!FunctionContentStatement {
    switch (tokens[offset.*].tag) {
        .keyword_return => {
            // Parse return statement
            offset.* += 1;
            if (parse_expression(source, tokens, offset, allocator)) |return_expression| {
                return FunctionContentStatement{ .@"return" = return_expression };
            } else |errors| {
                return errors;
            }
        },
        else => return parse_statement(source, tokens, offset, allocator),
    }
}

fn parse_statement(source: [:0]const u8, tokens: []tokenizer.Token, offset: *TokenIndex, allocator: std.mem.Allocator) std.ArrayList(ParserError)!Statement {
    switch (tokens[offset.*].tag) {
        .identifier => {
            const identifier = source[tokens[offset.*].pos .. tokens[offset.*].end + 1];
            offset.* += 1;
            if (tokens[offset.*].tag != .equal) {
                unreachable;
            } // TODO
            offset.* += 1;
            if (parse_expression(source, tokens, offset, allocator)) |assign_expression| {
                return FunctionContentStatement{ .statement = Statement{ .assignment = AssignmentStatement{ .explicit_type = null, .identifier = identifier, .expression = assign_expression } } };
            } else |errors| {
                return errors;
            }
        },
        // TODO: explicit type.
        // TODO: tuple destructuring.
        else => unreachable, // TODO
    }
}

fn parse_expression(source: [:0]const u8, tokens: []tokenizer.Token, offset: *TokenIndex, left: ?Expression, allocator: std.mem.Allocator) std.ArrayList(ParserError)!Expression {
    switch (tokens[offset.*].tag) {
        .lparen => unreachable, // TODO.
        .integer_literal => {
            const integer = Expression{ .integer_literal = offset.* };
            offset.* += 1;
            return parse_expression(source, tokens, offset.*, integer, allocator);
        },
        .identifier => {
            const identifier = Expression{ .identifier = token_source(source, tokens[offset.*]) };
            offset.* += 1;
            return parse_expression(source, tokens, offset, identifier, allocator);
        },
        .lparen => {
            // Call expression
            if (left) |left_not_null| {
                if (left_not_null == Expression.identifier) {
                    offset.* += 1;
                    var errors = std.ArrayList(ParserError).init(allocator);
                    var parameters = std.ArrayList(Expression).init(allocator);
                    while (!is_line_end(tokens[offset.*]) and tokens[offset.*].tag != .rparen) {
                        if (parse_expression(source, tokens, offset, null, allocator)) |parameter| {
                            try parameters.append(parameter);
                            if (tokens[offset.*].tag == .comma) {
                                offset.* += 1;
                            }
                        } else |new_errors| {
                            try errors.appendSlice(new_errors.items);
                            new_errors.deinit();
                        }
                    }
                } else {
                    unreachable; // TODO
                }
            } else {
                unreachable;
            }
        },
        .plus => {
            if (left) |left_not_null| {
                offset.* += 1;
                if (parse_expression(source, tokens, offset, null, allocator)) |rhs| {
                    return Expression{ .binary = BinaryExpression{ .lhs = left_not_null, .rhs = rhs, .tag = .addition } };
                } else |errors| {
                    return errors;
                }
            } else {
                unreachable; // TODO
            }
        },
        .newline, .dedentation, .eof => {
            if (left) |left_not_null| {
                return left_not_null;
            } else {
                unreachable; // TODO:
            }
        },
    }
    // TODO
}

fn token_source(source: [:0]const u8, token: tokenizer.Token) []const u8 {
    return source[token.pos .. token.end + 1];
}

fn is_line_end(token: tokenizer.Token) bool {
    return switch (token.tag) {
        .eof, .newline, .indentation, .dedentation => true,
        else => false,
    };
}

const expect = std.testing.expect;
test "simple add function" {
    const source =
        \\i32 add(i32 x, i32 y)
        \\  return x + y
        \\
        \\z = add(-8,9)
    ;
    const tokens = try tokenizer.tokenize(source, std.testing.allocator);
    defer tokens.deinit();

    const program = try parse(source, tokens.items, std.testing.allocator);
    defer program.deinit();

    try expect(program.contents.items.len == 2);
    try expect(program.contents.items[0] == TopLevelStatement.function);
}
