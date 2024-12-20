pub const std = @import("std");
pub const Parser = @import("Parser.zig");

// Plan
//
// 1. Get simple expressions working
// 2. Get print working
//
// 3. Get error handling to work well
//
// 4. Collect ideas in old attemps and clean up a bit

// Some WASM instructions.
pub const i32_ = 0x7F;
pub const i32_const = 0x41;
pub const i32_add = 0x6A;
pub const local_get = 0x20;
pub const local_set = 0x21;
pub const end = 0x0B;

parser: *Parser,
locals: std.StringHashMap(usize),
code: std.ArrayList(u8),

pub fn init(parser: *Parser, allocator: std.mem.Allocator) @This() {
    const code = std.ArrayList(u8).init(allocator);
    const locals = std.StringHashMap(usize).init(allocator);

    return @This(){
        .parser = parser,
        .locals = locals,
        .code = code,
    };
}

pub fn deinit(self: *@This()) void {
    self.locals.deinit();
    self.code.deinit();
    self.parser.deinit();
}

// Compile an expression by appending it to the Compilers code bytes
pub fn compile_expression(self: *@This(), expression: Parser.Expression) !void {
    switch (expression) {
        .integer => |integer| {
            const value = try std.fmt.parseInt(u32, integer, 10); // TODO Error handling
            try self.code.append(i32_const);
            try std.leb.writeUleb128(self.code.writer(), value);
        },
        .identifier => |identifier| {
            try self.code.append(local_get);
            try std.leb.writeUleb128(self.code.writer(), self.locals.get(identifier).?); // TODO Error handling
        },
        .addition => |indicies| {
            try self.compile_expression(self.parser.expressions.items[indicies[0]]);
            try self.compile_expression(self.parser.expressions.items[indicies[1]]);
            try self.code.append(i32_add);
        },
    }
}

// Compile the assignment and append to the code
pub fn compile_assignment(self: *@This(), assignment: Parser.Assignment) !void {
    try self.compile_expression(assignment.expression);
    // The value is now on the stack.
    try self.code.append(local_set);
    if (self.locals.get(assignment.identifier)) |local_index| {
        try std.leb.writeUleb128(self.code.writer(), local_index);
    } else {
        const local_index = self.locals.count();
        try self.locals.put(assignment.identifier, local_index);
        try std.leb.writeUleb128(self.code.writer(), local_index);
    }
}

// This compiles the entire code. NOTE! This does not include the local variable declaration.
pub fn compile_code(self: *@This()) !void {
    while (self.parser.tokenizer.current.tag != .eof) {
        try self.compile_assignment(self.parser.parse_assignment());
    }
    try self.code.append(end);
}

pub fn compile(self: *@This(), allocator: std.mem.Allocator) !std.ArrayList(u8) {
    var wasm_bytes = std.ArrayList(u8).init(allocator);
    try wasm_bytes.appendSlice(&.{ 0, 'a', 's', 'm', 1, 0, 0, 0, 1, 4, 1, 0x60, 0, 0, 3, 2, 1, 0 }); // Magic number, And Function Type Declaration

    // Start of code section
    try wasm_bytes.append(0x0A);
    try self.compile_code();
    // Local declaration
    var code_bytes = std.ArrayList(u8).init(allocator);
    try code_bytes.append(1);
    try std.leb.writeUleb128(code_bytes.writer(), self.locals.count());
    try code_bytes.append(i32_);
    // Code
    try code_bytes.appendSlice(self.code.items);
    // Add to wasm
    try std.leb.writeUleb128(wasm_bytes.writer(), code_bytes.items.len + 2);
    try wasm_bytes.append(1);
    try std.leb.writeUleb128(wasm_bytes.writer(), code_bytes.items.len);
    try wasm_bytes.appendSlice(code_bytes.items);
    code_bytes.deinit();

    return wasm_bytes;
}

test "single assign statement" {
    const source = "x = 16 + 13";
    var tokenizer = @import("Tokenizer.zig").init(source);
    var parser = Parser.init(&tokenizer, std.testing.allocator);
    var compiler = @This().init(&parser, std.testing.allocator);
    defer compiler.deinit();
    const bytes = try compiler.compile(std.testing.allocator);
    defer bytes.deinit();
    std.debug.print("{x}\n", .{bytes.items});
}
