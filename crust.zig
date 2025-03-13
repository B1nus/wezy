const std = @import("std");
const Precedence = enum {
    none,
    sum,
};

const Token = union(enum) {
    integer_type: u64,
    identifier: []u8,
    equals,
    decimal_integer: []u8,
    indentation: u64,
    left_parenthesis,
    right_parenthesis,
    plus,
    eof,
};

pub fn next_token(source: []u8, index: *u64) Token {
    const State = enum {
        start,
        identifier,
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
                '=' => token = .equals,
                '+' => token = .plus,
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

    const Index = u64;
};

const Expression = union(enum) {
    plus: [2]Index,
    decimal_integer: []u8,
    identifier: []u8,

    const Index = u64;
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
    std.debug.print("next_expression({s}, {d})\n", .{ source, index.* });
    var left = switch (next_token(source, index)) {
        .decimal_integer => |decimal_integer| Expression{ .decimal_integer = decimal_integer },
        .identifier => |identifier| Expression{ .identifier = identifier },
        else => unreachable,
    };

    while (true) {
        const mem = index.*;
        const token = next_token(source, index);

        std.debug.print("left: {any}\ntoken: {any}\n", .{ left, token });

        if (get_precedence(token)) |infix_precedence| {
            if (@intFromEnum(precedence) >= @intFromEnum(infix_precedence)) {
                break;
            }

            switch (token) {
                .plus => {
                    expressions.append(left) catch unreachable;
                    expressions.append(next_expression(source, index, expressions, infix_precedence)) catch unreachable;
                    left = Expression{ .plus = .{ expressions.items.len - 2, expressions.items.len - 1 } };
                },
                else => unreachable,
            }
        } else {
            index.* = mem;
            break;
        }
    }

    std.debug.print("{any}\n", .{left});

    return left;
}

pub fn get_precedence(token: Token) ?Precedence {
    return switch (token) {
        .plus => Precedence.sum,
        else => null,
    };
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var args = std.process.args();
    std.debug.assert(args.skip());
    const path = args.next().?;

    const file = try std.fs.cwd().openFile(path, .{});
    const source = try file.readToEndAlloc(allocator, std.math.maxInt(u64));

    var index: usize = 0;
    std.debug.print("{s}\n", .{source});
    var expressions = std.ArrayList(Expression).init(allocator);
    defer expressions.deinit();
    std.debug.print("{any}\n", .{next_statement(source, &index, &expressions)});
    std.debug.print("{any}\n", .{next_statement(source, &index, &expressions)});
    std.debug.print("{any}\n", .{next_statement(source, &index, &expressions)});
}
