const std = @import("std");

const Token = union(enum) {
    integer_type: u64,
    identifier: []u8,
    equals,
    double_equals,
    decimal_integer: []u8,
    indentation: u64,
    left_parenthesis,
    right_parenthesis,
    plus,
    asterix,
    minus,
    eof,
};

pub fn next_token(source: []u8, index: *u64) Token {
    const State = enum {
        start,
        identifier,
        equals,
        integer,
        decimal_integer,
        integer_type,
        indentation,
    };

    var start_index = index.*;
    var state = State.start;
    var token: ?Token = null;

    while (true) {
        if (token) |_token| {
            return _token;
        }
        const c = if (index.* >= source.len) 0 else source[index.*];
        switch (state) {
            .start => switch (c) {
                0 => token = .eof,
                ' ', '\r' => start_index += 1,
                '\n' => state = .indentation,
                'i' => state = .integer_type,
                'a'...'i' - 1, 'i' + 1...'z' => state = .identifier,
                '0' => state = .integer,
                '1'...'9' => state = .decimal_integer,
                '=' => state = .equals,
                '+' => token = .plus,
                '-' => token = .minus,
                '*' => token = .asterix,
                '(' => token = .left_parenthesis,
                ')' => token = .right_parenthesis,
                else => unreachable,
            },
            .identifier => switch (c) {
                'a'...'z', '0'...'9', '_' => {},
                else => if (source[index.* - 1] == '_') {
                    unreachable;
                } else {
                    token = Token{ .identifier = source[start_index..index.*] };
                    continue;
                },
            },
            .indentation => switch (c) {
                '\t', ' ' => {},
                '\r', '\n' => start_index = index.*,
                0 => token = Token.eof,
                else => {
                    token = Token{ .indentation = index.* - start_index };
                    continue;
                },
            },
            .integer_type => switch (c) {
                '0'...'9' => {},
                'a'...'z', '_' => state = State.identifier,
                else => if (index.* - start_index == 1) {
                    state = State.identifier;
                    continue;
                } else {
                    token = Token{ .integer_type = std.fmt.parseInt(u64, source[start_index + 1 .. index.*], 10) catch unreachable };
                    continue;
                },
            },
            .equals => switch (c) {
                '=' => token = Token.double_equals,
                else => {
                    token = Token.equals;
                    continue;
                },
            },
            .integer => switch (c) {
                'x' => unreachable,
                'b' => unreachable,
                else => {
                    state = State.decimal_integer;
                    continue;
                },
            },
            .decimal_integer => switch (c) {
                '0'...'9' => {},
                else => {
                    token = Token{ .decimal_integer = source[start_index..index.*] };
                    continue;
                },
            },
        }
        index.* += 1;
    }
}

const Statement = union(enum) {
    binding: Binding,
    call: Call,

    const Binding = struct {
        type: TypeExpression,
        identifier: []u8,
        expression: Expression,
    };

    const Call = struct {
        identifier: []u8,
        expression: Expression,
    };
};

const TypeExpression = union(enum) {
    integer: u64,
};

const Expression = union(enum) {
    plus: [2]u64,
    minus: [2]u64,
    times: [2]u64,
    equals: [2]u64,
    negation: u64,
    decimal_integer: []u8,
    identifier: []u8,
};

pub fn next_statement(source: []u8, index: *u64, expressions: *std.ArrayList(Expression)) ?Statement {
    const State = union(enum) {
        start,
        identifier: []u8,
        typed: TypeExpression,
        binding: struct { TypeExpression, []u8 },
        call: []u8,
    };

    var state = State{ .start = {} };

    while (true) {
        switch (state) {
            .start => switch (next_token(source, index)) {
                .integer_type => |integer_type| state = State{ .typed = TypeExpression{ .integer = integer_type } },
                .identifier => |identifier| state = State{ .identifier = identifier },
                .eof => return null,
                else => unreachable,
            },
            .identifier => |identifier| switch (next_token(source, index)) {
                .left_parenthesis => state = State{ .call = identifier },
                else => unreachable,
            },
            .typed => |@"type"| switch (next_token(source, index)) {
                .identifier => |identifier| switch (next_token(source, index)) {
                    .equals => state = State{ .binding = .{ @"type", identifier } },
                    else => unreachable,
                },
                else => unreachable,
            },
            .binding => |binding| {
                const @"type", const identifier = binding;
                const expression = next_expression(source, index, expressions, Precedence.none);
                _ = next_token(source, index);
                return Statement{ .binding = Statement.Binding{ .type = @"type", .identifier = identifier, .expression = expression } };
            },
            .call => |identifier| {
                const expression = next_expression(source, index, expressions, Precedence.none);
                _ = next_token(source, index);
                _ = next_token(source, index);
                return Statement{ .call = Statement.Call{ .identifier = identifier, .expression = expression } };
            },
        }
    }
}

pub fn next_type_expression(source: []u8, index: *u64, type_expressions: *std.ArrayList(TypeExpression)) TypeExpression {
    _ = source;
    _ = index;
    _ = type_expressions;
    unreachable;
}

pub fn next_expression(source: []u8, index: *u64, expressions: *std.ArrayList(Expression), precedence: Precedence) Expression {
    var left: Expression = undefined;
    switch (next_token(source, index)) {
        .decimal_integer => |decimal_integer| left = Expression{ .decimal_integer = decimal_integer },
        .identifier => |identifier| left = Expression{ .identifier = identifier },
        .minus => {
            expressions.append(next_expression(source, index, expressions, Precedence.none)) catch unreachable;
            left = Expression{ .negation = expressions.items.len - 1 };
        },
        .left_parenthesis => {
            left = next_expression(source, index, expressions, Precedence.none);
            _ = next_token(source, index);
        },
        else => unreachable,
    }

    while (true) {
        const mem = index.*;
        const token = next_token(source, index);

        if (get_precedence(token)) |infix_precedence| {
            if (@intFromEnum(precedence) > @intFromEnum(infix_precedence)) {
                break;
            }

            switch (token) {
                .plus, .minus, .asterix, .double_equals => {
                    expressions.append(left) catch unreachable;
                    expressions.append(next_expression(source, index, expressions, infix_precedence)) catch unreachable;
                    const ids = .{ expressions.items.len - 2, expressions.items.len - 1 };
                    left = switch (token) {
                        .plus => Expression{ .plus = ids },
                        .minus => Expression{ .minus = ids },
                        .asterix => Expression{ .times = ids },
                        .double_equals => Expression{ .equals = ids },
                        else => unreachable,
                    };
                },
                else => unreachable,
            }
        } else {
            index.* = mem;
            break;
        }
    }

    return left;
}

const Precedence = enum {
    none,
    sum,
    product,
    equality,
};

pub fn get_precedence(token: Token) ?Precedence {
    return switch (token) {
        .plus => Precedence.sum,
        .minus => Precedence.sum,
        .asterix => Precedence.product,
        .double_equals => Precedence.equality,
        else => null,
    };
}

pub fn compile_expression(expression: Expression, expressions: []Expression, local_variables: std.StringHashMap(u64), bytes: *std.ArrayList(u8)) void {
    switch (expression) {
        .decimal_integer => |decimal_integer| {
            const parsed_integer = std.fmt.parseInt(u64, decimal_integer, 10) catch unreachable;
            bytes.append(0x42) catch unreachable;
            std.leb.writeIleb128(bytes.writer(), parsed_integer) catch unreachable;
        },
        .identifier => |identifier| {
            bytes.append(0x20) catch unreachable;
            std.leb.writeIleb128(bytes.writer(), local_variables.get(identifier).?) catch unreachable;
        },
        .plus => |expression_indicies| {
            compile_expression(expressions[expression_indicies[0]], expressions, local_variables, bytes);
            compile_expression(expressions[expression_indicies[1]], expressions, local_variables, bytes);
            bytes.append(0x7C) catch unreachable;
        },
        .minus => |expression_indicies| {
            compile_expression(expressions[expression_indicies[0]], expressions, local_variables, bytes);
            compile_expression(expressions[expression_indicies[1]], expressions, local_variables, bytes);
            bytes.append(0x7D) catch unreachable;
        },
        .times => |expression_indicies| {
            compile_expression(expressions[expression_indicies[0]], expressions, local_variables, bytes);
            compile_expression(expressions[expression_indicies[1]], expressions, local_variables, bytes);
            bytes.append(0x7E) catch unreachable;
        },
        .negation => |expression_index| {
            bytes.append(0x7E) catch unreachable;
            std.leb.writeIleb128(bytes.writer(), 0) catch unreachable;
            compile_expression(expressions[expression_index], expressions, local_variables, bytes);
            bytes.append(0x7E) catch unreachable;
        },
        else => unreachable,
    }
}

pub fn compile_statement(statement: Statement, expressions: []Expression, local_variables: *std.StringHashMap(u64), bytes: *std.ArrayList(u8)) void {
    switch (statement) {
        .binding => |binding| {
            compile_expression(binding.expression, expressions, local_variables.*, bytes);
            const local_variable_entry = local_variables.getOrPutValue(binding.identifier, local_variables.count()) catch unreachable;
            const local_variable_index = local_variable_entry.value_ptr.*;
            bytes.append(0x21) catch unreachable;
            std.leb.writeIleb128(bytes.writer(), local_variable_index) catch unreachable;
        },
        else => unreachable,
    }
}

// param i64 i32, result i32
// local i32
const write_i64_declaration_bytes = [_]u8{};
const write_i64_bytes = [_]u8{
    0x41, 0, 0x20, 0, // i32.const 0, local.set 0
    // loop
};

// How to print debug of integer
// How to crash a wasm program

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var args = std.process.args();
    std.debug.assert(args.skip());
    const path = args.next().?;

    const file = try std.fs.cwd().openFile(path, .{});
    const source = try file.readToEndAlloc(allocator, std.math.maxInt(u64));

    var index: usize = 0;
    var expressions = std.ArrayList(Expression).init(allocator);
    var bytes = std.ArrayList(u8).init(allocator);
    var local_variables = std.StringHashMap(u64).init(allocator);
    defer expressions.deinit();
    defer bytes.deinit();
    defer local_variables.deinit();

    while (next_statement(source, &index, &expressions)) |statement| {
        compile_statement(statement);
    }
    std.debug.print("{X}\n", .{bytes.items});
}
