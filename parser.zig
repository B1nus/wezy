pub const std = @import("std");
pub const tokenizer = @import("tokenizer.zig");

pub const TokenIndex = u32;
pub const SourceIndex = u32;

pub const ParserError = struct {
    pos: SourceIndex,
    end: SourceIndex,
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
        missing_parameter_type, // "Specify the type for you parameter. [insert specific example with i32 as type].
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

        // Idea:
        // If a user gets the same error more than once. Show a more detailed error. For example if a 
        // user is writing functions like in javascrtipt:
        //
        // function do_something(x, y)
        //
        // The first error will probably say something like "function is not a valid return type".
        //
        // Then if the user still has that same error again we instead show details about the syntax of functions.
    };
};

pub const Statement = union(enum) {
    binding: BindingStatement,
    assignment: AssignmentStatement,
    @"return": Expression,
    expression: Expression,
};

// Top level statements can have functions.
pub const TopLevelStatement = union(enum) {
    function: FunctionStatement,
    binding: BindingStatement,
    assignment: AssignmentStatement,
    expression: Expression,
    // use: UseStatement,

    pub fn deinit(self: TopLevelStatement) void {
        if (self == TopLevelStatement.function) {
            self.function.contents.deinit();
            self.function.parameters.deinit();
        }
    }
};

pub const Program = struct {
    contents: std.ArrayList(TopLevelStatement),
    errors: std.ArrayList(ParserError),

    pub fn deinit(self: Program) void {
        for (self.contents.items) |top_level_statement| {
            top_level_statement.deinit();
        }
        self.contents.deinit();
        self.errors.deinit();
    }
};

pub const BlockStatement = std.ArrayList(Statement); // Used in functions, if statements and loops

pub const TypeToken = union(enum) {
    integer: u32, // The number corresponds to a power of two. x = 8 * 2 ^ n.  0 => 8, 1 => 16, 2 => 32 etc...
    // f32,
    // f64,
    // list: TypeToken,
};

pub const FunctionStatement = struct {
    identifier: []const u8,
    parameters: std.StringHashMap(TypeToken),
    contents: BlockStatement,
};

pub const Expression = union(enum) {
    binary: BinaryExpression,
    // unary: UnaryExpression,
    call: CallExpression,
};

pub const BinaryExpression = struct {
    lhs: Expression,
    rhs: Expression,
    operator: BinaryOperatorType,
};

pub const BinaryOperatorType = enum {
    addition,
    // subtractions,
    // multiplication,
    // division,
    // power,
};

// pub const UnaryExpression = ...

// pub const UnaryOperatorType = ...

pub const CallExpression = struct {
    identifier: []const u8,
    parameters: std.ArrayList(Expression),
};

// Note: we need to keep track of the environment variables to know if something is an binding or assignment.
pub const BindingStatement = struct {
    explicit_type: ?TypeToken,
    identifier: []const u8,
    expression: Expression,
};

pub const AssignmentStatement = struct {
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
// Shadowing/Rebinding when using explicit type
// Bitwise ops cannot be named and, not, or which are keywords. use bitwise_or(x,y) or bit_or(x,y) instead. It's more clear this way so it's a good change.
// Present errors simply. do not include details and technical words such as parser, tokenizer etc...

pub fn parse(tokens: []tokenizer.Token, allocator: std.mem.Allocator) !Program {
    var errors = std.ArrayList(ParserError).init(allocator);
    var top_level_statements = std.ArrayList(TopLevelStatement).init(allocator);
    var offset: TokenIndex = 0;
    var next_top_level_statement = parse_next_top_level_statement(tokens, offset);

    while (next_top_level_statement) |next_top_level| {
        if (next_top_level) |statement| {
            top_level_statements.append(statement);
        } else |e| {
            try errors.append(e);
        }
    }

    for (tokens.items) |token| {
        switch (token.tag) {
            .invalid => try errors.append(ParserError { .pos=token.pos, .end=token.end, .tag=.invalid_token }),
            .unexpected_indentation => try errors.append(ParserError {.pos=token.pos, .end = token.end, .tag=.unexpected_indentation}),
        }
    }

    return Program {
        .contents = top_level_statements,
        .errors = errors,
    };
}

pub fn parse_next_top_level_statement(tokens: []tokenizer.Token, offset: TokenIndex) ?ParserError!TopLevelStatement {
}

const expect = std.testing.expect;
test "simple add function" {
    const source = 
        \\i32 add(i32 x, i32 y)
        \\  return x + y
        \\
        \\add(-8,9)
    ;
    const tokens = try tokenizer.tokenize(source, std.testing.allocator);
    defer tokens.deinit();

    const program = try parse(tokens.items, std.testing.allocator);
    defer program.deinit();

    try expect(program.contents.items.len == 2);
    try expect(program.contents.items[0] == TopLevelStatement.function);
}
