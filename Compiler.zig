pub const std = @import("std");
pub const Parser = @import("Parser.zig");

// TODO Error handling
// TODO Clear and gather notes from previous attempts
// TODO Check if leb128 is fixed now

// Some WASM instructions.
pub const i32_ = 0x7F;
pub const i32_const = 0x41;
pub const i32_add = 0x6A;
pub const local_get = 0x20;
pub const local_set = 0x21;
pub const call = 0x10;
pub const end = 0x0B;

// Functions we import from our host environment javascript. This is needed
// to do input and output in webassembly, and that's is the only thing they
// are used for.
pub const Import = enum {
    log_i32,
    log_str, // This won't be in the language, but I need some practice
             // getting wasm memory to work. The concept of strings don't
             // exist in crust. There's only lists of bytes.
    // TODO make log_str into log_[i8]. And make all strings into mutable [i8].

    // draw_triangle,
    // draw_image,
};

parser: *Parser,
locals: std.StringHashMap(usize),
imports: std.AutoHashMap(Import, usize),

// TODO
// Compile into index.html
// Only compile js functions necessary
// Only compile wasm imports necessary
// Figure out memory

// Don't make string literals into constants. Keep them as lists of bytes
// "[i8]". So, the next thing to do is figure out allocation.

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
pub fn compile_expression(self: *@This(), code: *std.ArrayList(u8), expression: Parser.Expression) !void {
    switch (expression) {
        .integer => |integer| {
            const value = try std.fmt.parseInt(u32, integer, 10); // TODO Error handling
            try code.append(i32_const);
            try std.leb.writeIleb128(self.code.writer(), value);
        },
        .identifier => |identifier| {
            try code.append(local_get);
            try std.leb.writeIleb128(self.code.writer(), self.locals.get(identifier).?); // TODO Error handling
        },
        .addition => |indicies| {
            try self.compile_expression(self.parser.expressions.items[indicies[0]]);
            try self.compile_expression(self.parser.expressions.items[indicies[1]]);
            try code.append(i32_add);
        },
        .string => |_| {},
    }
}

// Compile the statement and append to the code
pub fn compile_statement(self: *@This(), code: *std.ArrayList(u8), statement: Parser.Statement) !void {
    switch (statement) {
        .assignment => |assignmnet| {
            const identifier, const expression = assignmnet;
            try self.compile_expression(expression);
            // The value is now on the stack.
            try code.append(local_set);
            if (self.locals.get(identifier)) |local_index| {
                try std.leb.writeIleb128(code.writer(), local_index);
            } else {
                const local_index = self.locals.count();
                try self.locals.put(identifier, local_index);
                try std.leb.writeIleb128(code.writer(), local_index);
            }
        },
        .function_call => |functions_call| {
            const identifier, const expression = functions_call;
            if (std.mem.eql(u8, identifier, "print")) {
                switch (expression) {
                    .integer, .addition => {
                        try self.compile_expression(code, expression);
                        try code.append(call);

                        if (self.host_functions.get(HostFunction.log_i32)) |index| {
                            try self.code.append(index);
                        } else {
                            const index = self.host_functions.count();
                            try self.host_functions.put(HostFunction.log_i32, index);
                            try code.append(index);
                        }
                    },
                    .string => {
                        // TODO Push the ptr and length to the stack

                        try code.append(call);
                        if (self.host_functions.get(HostFunction.log_list_i8)) |index| {
                            try code.append(index);
                        } else {
                            const index = self.host_functions.count();
                            try self.host_functions.put(HostFunction.log_list_i8, index);
                            try code.append(index);
                        }
                    },
                }
            } else {
                unreachable; // TODO User defined functions
            }
        },
    }
}

// This compiles the entire code. NOTE! This does not include the local variable declaration.
pub fn compile_code(self: *@This(), allocator: std.mem.Allocator) !std.ArrayList(u8) {
    var code = std.ArrayList(u8).init(allocator);
    while (self.parser.tokenizer.current.tag != .eof) {
        try self.compile_statement(&code, self.parser.parse_statement());
    }
    try self.code.append(end);
}

pub fn compile_imports(self: *@This()) !std.ArrayList(u8) {
}

pub fn compile_javascipr()

pub fn compile_wasm(self: *@This(), allocator: std.mem.Allocator) !std.ArrayList(u8) {
    var wasm_bytes = std.ArrayList(u8).init(allocator);
    try wasm_bytes.appendSlice(&.{ 0, 'a', 's', 'm', 1, 0, 0, 0 }); // Magic number, And Function Type Declaration

    // Compiling code and indexing imports
    try self.compile_code();
    try self.compile_host_functions();

    // Types
    try wasm_bytes.appendSlice(&.{ 1, 8, 2, 0x60, 1, i32_, 0, 0x60, 0, 0 });
    // Import "imports.log" function
    try wasm_bytes.appendSlice(&.{ 2, 0x0F, 1, 7, 'i', 'm', 'p', 'o', 'r', 't', 's', 3, 'l', 'o', 'g', 0, 0 });
    // Function section
    try wasm_bytes.appendSlice(&.{ 3, 2, 1, 1 });

    try wasm_bytes.appendSlice(&.{ 8, 1, 1 });

    // Start of code section
    try wasm_bytes.append(0x0A);
    // Local declaration
    var code_bytes = std.ArrayList(u8).init(allocator);
    try code_bytes.append(1);
    try std.leb.writeIleb128(code_bytes.writer(), self.locals.count());
    try code_bytes.append(i32_);
    // Code
    try code_bytes.appendSlice(self.code.items);
    // Add to wasm
    try std.leb.writeIleb128(wasm_bytes.writer(), code_bytes.items.len + 2);
    try wasm_bytes.append(1);
    try std.leb.writeIleb128(wasm_bytes.writer(), code_bytes.items.len);
    try wasm_bytes.appendSlice(code_bytes.items);
    code_bytes.deinit();

    return wasm_bytes;
}

pub const css

pub const UnpackingError = error {
    no_script,
    no_wasm,
};

// I just realized something. This system would be very prone
// to breaking with updates. How can I make sure this keeps working
// even as I update crust?
//
// It should work like normal right? The only hard part if finding
// the webassembly file. As long as I keep that consistent it should
// not be a problem.
//
// Otherwise I could just make unpacking an option while compiling.
// Yeah, that's probably a better idea...
pub const Unpacked = struct {
    html: []const u8,
    js: []const u8,
    wasm: []const u8,
    css: []const u8,
};

// Unpacks the html file into four different files. index.html
// index.js, index.wasm and index.css.
pub fn unpack(html: []const u8) UnpackingError!Unpacked {
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
