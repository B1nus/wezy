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
    assignment: Assignment,
    call: Call,

    const Binding = struct {
        type: TypeExpression,
        identifier: []u8,
        expression: Expression,
    };

    const Assignment = struct {
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
        assignment: []u8,
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
                .equals => state = State{ .assignment = identifier },
                else => unreachable,
            },
            .typed => |@"type"| switch (next_token(source, index)) {
                .identifier => |identifier| switch (next_token(source, index)) {
                    .equals => state = State{ .binding = .{ @"type", identifier } },
                    else => unreachable,
                },
                else => unreachable,
            },
            .assignment => |identifier| {
                const expression = next_expression(source, index, expressions, Precedence.none);
                _ = next_token(source, index);
                return Statement{ .assignment = Statement.Assignment{ .identifier = identifier, .expression = expression } };
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

// How to add debug info in debug calls (line number and expression)
// How to make a debug function in wasm. Should be able to debug any expression.
// TODO: add debug call to failed asserts.
// TODO: make sure only used functions are imported and included. (You're going to ned a StringHashMap from functions to indicies)

// Hmmm. How to make it easy to add std wasm functions?
// Hmmm. Let users add wasm code?

// One debug function per

pub fn write_i64_code(bytes: *std.ArrayList(u8), fd_write_index: u32) void {
    bytes.appendSlice(&[_]u8{ 0x01, 0x02, 0x7F, 0x41, 0xE8, 0x07, 0x21, 0x01, 0x41, 0x00, 0x21, 0x02, 0x03, 0x40, 0x20, 0x01, 0x20, 0x02, 0x6B, 0x20, 0x00, 0x42, 0x0A, 0x81, 0xA7, 0x41, 0x30, 0x6A, 0x3A, 0x00, 0x00, 0x20, 0x00, 0x42, 0x0A, 0x7F, 0x21, 0x00, 0x20, 0x02, 0x41, 0x01, 0x6A, 0x21, 0x02, 0x20, 0x00, 0x42, 0x00, 0x52, 0x0D, 0x00, 0x0B, 0x20, 0x01, 0x41, 0x01, 0x6a, 0x41, 0x0a, 0x3a, 0x00, 0x00, 0x20, 0x01, 0x41, 0x01, 0x6A, 0x20, 0x02, 0x6B, 0x21, 0x01, 0x41, 0x00, 0x20, 0x01, 0x36, 0x02, 0x00, 0x41, 0x04, 0x20, 0x02, 0x41, 0x01, 0x6a, 0x36, 0x02, 0x00, 0x41, 0x01, 0x41, 0x00, 0x41, 0x01, 0x41, 0xE4, 0x00, 0x10 }) catch unreachable;
    std.leb.writeIleb128(bytes.writer(), fd_write_index) catch unreachable;
    bytes.appendSlice(&[_]u8{ 0x1A, 0x0B }) catch unreachable;
}
const write_i64_type = [_]u8{ 0x60, 0x01, 0x7E, 0x00 };

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

    const file = try std.fs.cwd().openFile(path, .{});
    const source = try file.readToEndAlloc(allocator, std.math.maxInt(u64));

    var source_index: usize = 0;
    var expressions = std.ArrayList(Expression).init(allocator);
    var local_variables = std.StringHashMap(u64).init(allocator);

    var wasi_import_types = std.ArrayList(u8).init(allocator);
    var wasi_import_names = std.StringArrayHashMap(u32).init(allocator);

    var std_function_types = std.ArrayList(u8).init(allocator);
    var std_function_codes = std.ArrayList(u8).init(allocator);
    var std_function_names = std.StringArrayHashMap(u32).init(allocator);

    var start_function_code = std.ArrayList(u8).init(allocator);

    var std_uses = std.AutoArrayHashMap(u32, []const u8).init(allocator);

    while (next_statement(source, &source_index, &expressions)) |statement| {
        switch (statement) {
            .binding => |binding| {
                compile_expression(binding.expression, expressions.items, local_variables, &start_function_code);
                const local_variable_entry = local_variables.getOrPutValue(binding.identifier, local_variables.count()) catch unreachable;
                const local_variable_index = local_variable_entry.value_ptr.*;
                start_function_code.append(0x21) catch unreachable;
                std.leb.writeIleb128(start_function_code.writer(), local_variable_index) catch unreachable;
            },
            .assignment => |assignment| {
                compile_expression(assignment.expression, expressions.items, local_variables, &start_function_code);
                start_function_code.append(0x21) catch unreachable;
                std.leb.writeIleb128(start_function_code.writer(), local_variables.get(assignment.identifier).?) catch unreachable;
            },
            .call => |call| {
                compile_expression(call.expression, expressions.items, local_variables, &start_function_code);
                start_function_code.append(0x10) catch unreachable;

                const function = std.meta.stringToEnum(enum {
                    debug,
                    assert,
                }, call.identifier) orelse {
                    unreachable;
                };

                var function_index: u32 = undefined;
                switch (function) {
                    .debug => {
                        var fd_write_index: u32 = undefined;
                        if (wasi_import_names.get("fd_write")) |index| {
                            fd_write_index = @intCast(index);
                        } else {
                            fd_write_index = @intCast(wasi_import_names.count());
                            wasi_import_types.appendSlice(&[_]u8{ 0x60, 0x04, 0x7F, 0x7F, 0x7F, 0x7F, 0x01, 0x7F }) catch unreachable;
                            wasi_import_names.put("fd_write", fd_write_index) catch unreachable;
                        }

                        if (std_function_names.get("write_i64")) |index| {
                            function_index = @intCast(index);
                        } else {
                            var code = std.ArrayList(u8).init(allocator);
                            write_i64_code(&code, fd_write_index);
                            std.leb.writeIleb128(std_function_codes.writer(), code.items.len) catch unreachable;
                            std_function_codes.appendSlice(code.items) catch unreachable;
                            code.deinit();

                            function_index = @intCast(std_function_names.count());
                            std_function_types.appendSlice(&write_i64_type) catch unreachable;
                            std_function_names.put("write_i64", function_index) catch unreachable;
                        }

                        std_uses.put(@intCast(start_function_code.items.len), "write_i64") catch unreachable;
                    },
                    .assert => {
                        var proc_exit_index: u32 = undefined;
                        if (wasi_import_names.get("proc_exit")) |index| {
                            proc_exit_index = @intCast(index);
                        } else {
                            proc_exit_index = @intCast(wasi_import_names.count());
                            wasi_import_types.appendSlice(&[_]u8{ 0x60, 0x01, 0x7F, 0x00 }) catch unreachable;
                            wasi_import_names.put("proc_exit", proc_exit_index) catch unreachable;
                        }

                        if (std_function_names.get("crash")) |index| {
                            function_index = @intCast(index);
                        } else {
                            var code = std.ArrayList(u8).init(allocator);
                            try code.appendSlice(&.{ 0x00, 0x41, 0x00, 0x10 });
                            try std.leb.writeIleb128(code.writer(), proc_exit_index);
                            try code.append(0x0B);

                            std.leb.writeIleb128(std_function_codes.writer(), code.items.len) catch unreachable;
                            std_function_codes.appendSlice(code.items) catch unreachable;
                            code.deinit();

                            function_index = @intCast(std_function_names.count());
                            std_function_types.appendSlice(&write_i64_type) catch unreachable;
                            std_function_names.put("crash", function_index) catch unreachable;
                        }

                        std_uses.put(@intCast(start_function_code.items.len), "crash") catch unreachable;
                    },
                }
            },
        }
    }

    var new_start_function_code = std.ArrayList(u8).init(allocator);
    var std_uses_iterator = std_uses.iterator();
    var last: u32 = 0;
    while (std_uses_iterator.next()) |std_use| {
        try new_start_function_code.appendSlice(start_function_code.items[last..std_use.key_ptr.*]);
        last = std_use.key_ptr.*;
        try std.leb.writeIleb128(new_start_function_code.writer(), std_function_names.get(std_use.value_ptr.*).? + wasi_import_names.count());
    }
    try new_start_function_code.appendSlice(start_function_code.items[last..]);
    start_function_code = new_start_function_code;

    const output_path = args.next() orelse replace_extension(allocator, path, ".wasm");
    const output_file = try std.fs.cwd().createFile(output_path, .{ .truncate = true });

    var sections = std.AutoArrayHashMap(u8, []u8).init(allocator);

    var type_section = std.ArrayList(u8).init(allocator);
    try std.leb.writeIleb128(type_section.writer(), wasi_import_names.count() + std_function_names.count() + 1);
    try type_section.appendSlice(wasi_import_types.items);
    try type_section.appendSlice(std_function_types.items);
    try type_section.appendSlice(&.{ 0x60, 0x00, 0x00 });
    try sections.put(0x01, type_section.items);

    var import_section = std.ArrayList(u8).init(allocator);
    try std.leb.writeIleb128(import_section.writer(), wasi_import_names.count());
    var import_iterator = wasi_import_names.iterator();
    while (import_iterator.next()) |import_entry| {
        const import = import_entry.key_ptr.*;
        const i = import_entry.value_ptr.*;
        try import_section.appendSlice(&.{ 0x16, 0x77, 0x61, 0x73, 0x69, 0x5F, 0x73, 0x6E, 0x61, 0x70, 0x73, 0x68, 0x6F, 0x74, 0x5F, 0x70, 0x72, 0x65, 0x76, 0x69, 0x65, 0x77, 0x31 });
        try std.leb.writeIleb128(import_section.writer(), import.len);
        try import_section.appendSlice(import);
        try import_section.append(0x00);
        try std.leb.writeIleb128(import_section.writer(), i);
    }
    try sections.put(0x02, import_section.items);

    var function_section = std.ArrayList(u8).init(allocator);
    try std.leb.writeIleb128(function_section.writer(), std_function_names.count() + 1);
    for (0..std_function_names.count() + 1) |i| {
        try std.leb.writeIleb128(function_section.writer(), i + wasi_import_names.count());
    }
    try sections.put(0x03, function_section.items);

    var memory_section = std.ArrayList(u8).init(allocator);
    try memory_section.appendSlice(&.{ 0x01, 0x00, 0x01 });
    try sections.put(0x05, memory_section.items);

    var export_section = std.ArrayList(u8).init(allocator);
    try export_section.append(0x02);
    try std.leb.writeIleb128(export_section.writer(), "_start".len);
    try export_section.appendSlice("_start");
    try export_section.append(0x00);
    try std.leb.writeIleb128(export_section.writer(), std_function_names.count() + wasi_import_names.count());
    try std.leb.writeIleb128(export_section.writer(), "memory".len);
    try export_section.appendSlice("memory");
    try export_section.appendSlice(&.{ 0x02, 0x00 });
    try sections.put(0x07, export_section.items);

    var code_section = std.ArrayList(u8).init(allocator);
    try std.leb.writeIleb128(code_section.writer(), std_function_names.count() + 1);
    try code_section.appendSlice(std_function_codes.items);
    var start_function_locals = std.ArrayList(u8).init(allocator);
    try start_function_locals.append(0x01);
    try std.leb.writeIleb128(start_function_locals.writer(), local_variables.count());
    try start_function_locals.append(0x7E);
    try std.leb.writeIleb128(code_section.writer(), start_function_code.items.len + start_function_locals.items.len + 1);
    try code_section.appendSlice(start_function_locals.items);
    try code_section.appendSlice(start_function_code.items);
    try code_section.append(0x0B);
    try sections.put(0x0A, code_section.items);

    _ = try output_file.write(&.{ 0x00, 'a', 's', 'm', 0x01, 0x00, 0x00, 0x00 });
    var section_iterator = sections.iterator();
    while (section_iterator.next()) |section| {
        _ = try output_file.write(&.{section.key_ptr.*});
        try std.leb.writeIleb128(output_file.writer(), section.value_ptr.len);
        _ = try output_file.write(section.value_ptr.*);
    }
}

// // const proc_exit_type = [_]u8{ 0x60, 0x01, 0x7F, 0x00 };
// // const crash_code = [_]u8{ 0x00 } ++ [_]u8{  };
