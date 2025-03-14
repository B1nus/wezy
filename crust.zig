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

// pub fn compile_statement(statement: Statement, expressions: []Expression, local_variables: *std.StringHashMap(u64), imports: *std.ArrayList([]u8), import_types: *std.ArrayList(u8), function_types: *std.ArrayList([]u8), function_codes: *std.ArrayList([]u8), functions: *std.StringHashMap(u64), code_bytes: *std.ArrayList(u8)) void {
//     switch (statement) {
//         .binding => |binding| {
//             compile_expression(binding.expression, expressions, local_variables.*, code_bytes);
//             const local_variable_entry = local_variables.getOrPutValue(binding.identifier, local_variables.count()) catch unreachable;
//             const local_variable_index = local_variable_entry.value_ptr.*;
//             code_bytes.append(0x21) catch unreachable;
//             std.leb.writeIleb128(code_bytes.writer(), local_variable_index) catch unreachable;
//         },
//         .call => |call| {
//             compile_expression(call.expression, expressions, local_variables.*, code_bytes);
//             code_bytes.append(0x10) catch unreachable;
//
//             const function = std.meta.stringToEnum(Functions, call.identifier) orelse {
//                 unreachable;
//             };
//
//             var function_index = undefined;
//             switch (function) {
//                 .debug => {
//                     var fd_write_index = undefined;
//                     if (functions.get("fd_write")) |index| {
//                         fd_write_index = index;
//                     } else {
//                         imports.append([_]u8{ 0x16 } ++ "was_snapshot_preview1" ++ [_]u8{ 0x09 } ++ "fd_write") catch unreachable;
//                         import_types.append(function_types.items.len) catch unreachable;
//                         function_types.append([_]u8{ 0x60, 0x01, 0x7E, 0x00 }) catch unreachable;
//                         fd_write_index = functions.count();
//                         functions.put("fd_write", fd_write_index);
//                     }
//
//                     if (functions.get("write_i64")) |index| {
//                         function_index = index;
//                     } else {
//                         [_]u8{ 0x01, 0x02, 0x7F } ++ [_]u8{ 0x41, 0xE8, 0x07, 0x21, 0x01, 0x41, 0x00, 0x21, 0x02, 0x03, 0x40, 0x20, 0x01, 0x20, 0x02, 0x6B, 0x20, 0x00, 0x42, 0x0A, 0x81, 0xA7, 0x41, 0x30, 0x6A, 0x3A, 0x00, 0x00, 0x20, 0x00, 0x42, 0x0A, 0x7F, 0x21, 0x00, 0x20, 0x02, 0x41, 0x01, 0x6A, 0x21, 0x02, 0x20, 0x00, 0x42, 0x00, 0x52, 0x0D, 0x00, 0x0B, 0x20, 0x01, 0x41, 0x01, 0x6A, 0x20, 0x02, 0x6B, 0x21, 0x01, 0x41, 0x00, 0x20, 0x01, 0x36, 0x02, 0x00, 0x41, 0x04, 0x20, 0x02, 0x36, 0x02, 0x00, 0x41, 0x01, 0x41, 0x00, 0x41, 0x01, 0x41, 0xE4, 0x00, 0x10, undefined, 0x1A, 0x0B }
//                     }
//                 },
//                 .assert => unreachable,
//             }
//
//             std.leb.writeIleb128(code_bytes.writer(), function_index) catch unreachable;
//         },
//     }
// }
//
// const Functions = enum {
//     debug,
//     assert,
// };
//
// const fd_write_type = [_]u8{ 0x60, 0x04, 0x7F, 0x7F, 0x7F, 0x7F, 0x01, 0x7F };
// // const proc_exit_type = [_]u8{ 0x60, 0x01, 0x7F, 0x00 };
// // const proc_exit_import = [_]u8{ 0x16, 0x77, 0x61, 0x73, 0x69, 0x5F, 0x73, 0x6E, 0x61, 0x70, 0x73, 0x68, 0x6F, 0x74, 0x5F, 0x70, 0x72, 0x65, 0x76, 0x69, 0x65, 0x77, 0x31, 0x09, 0x70, 0x72, 0x6F, 0x63, 0x5F, 0x65, 0x78, 0x69, 0x74 };
// // const crash_type = [_]u8{ 0x60, 0x00, 0x00 };
// // const crash_code = [_]u8{ 0x00 } ++ [_]u8{  };
// const start_type = [_]u8{ 0x60, 0x00, 0x00 };
// const write_i64_code = ;

// How to add debug info in debug calls (line number and expression)
// How to make a debug function in wasm. Should be able to debug any expression.
// TODO: add debug call to failed asserts.
// TODO: make sure only used functions are imported and included. (You're going to ned a StringHashMap from functions to indicies)

// Hmmm. How to make it easy to add std wasm functions?
// Hmmm. Let users add wasm code?

pub fn replace_extension(allocator: std.mem.Allocator, path: []const u8, new_extension: []const u8) []u8 {
    const extension = std.fs.path.extension(path);
    var new_path = allocator.alloc(u8, path.len - extension.len + new_extension.len) catch unreachable;
    std.mem.copyForwards(u8, new_path, path[0 .. path.len - extension.len]);
    std.mem.copyForwards(u8, new_path[new_path.len - new_extension.len ..], new_extension);

    return new_path;
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var args = std.process.args();
    _ = args.skip();
    const path = args.next().?;

    // const file = try std.fs.cwd().openFile(path, .{});
    // const source = try file.readToEndAlloc(allocator, std.math.maxInt(u64));

    // var index: usize = 0;
    // var expressions = std.ArrayList(Expression).init(allocator);
    // var code_bytes = std.ArrayList(u8).init(allocator);
    // var local_variables = std.StringHashMap(u64).init(allocator);
    // var functions = std.StringHashMap(u64).init(allocator);
    // defer expressions.deinit();
    // defer code_bytes.deinit();
    // defer local_variables.deinit();

    // while (next_statement(source, &index, &expressions)) |statement| {
    //     compile_statement(statement, expressions.items, &local_variables, &code_bytes);
    // }

    const output_path = args.next() orelse replace_extension(allocator, path, ".wasm");
    const output_file = try std.fs.cwd().createFile(output_path, .{ .truncate = true });
    _ = try output_file.write(&.{ 0x00, 0x61, 0x73, 0x6D, 0x01, 0x00, 0x00, 0x00 });

    var function_types = std.ArrayList(u8).init(allocator);
    var import_count: u32 = 0;
    var imports = std.ArrayList(u8).init(allocator); // includes the type for imports
    var code_count: u32 = 0;
    var function_identifiers = std.StringHashMap(u32).init(allocator);
    var dependencies = std.HashMap(u32, []u8).init(allocator); // 
    var code = std.ArrayList(u8).init(allocator);
    var code_types = std.ArrayList(u32).init(allocator);

    for (dependencies.entries()) |dependency| {
        const pos, const identifier = dependency;
        code.items[pos] = function_identifiers.get(identifier).?;
    }
}
