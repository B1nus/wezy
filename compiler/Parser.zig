const std = @import("std");
const Inst = @import("opcodes.zig").Inst;
const instParsingStrategy = @import("opcodes.zig").instParsingStrategy;
const Scanner = @import("Scanner.zig");
const Ast = @import("Ast.zig");

allocator: std.mem.Allocator,
scanner: Scanner,
ast: Ast,

pub fn init(source: []const u8, allocator: std.mem.Allocator) @This() {
    return .{
        .allocator = allocator,
        .scanner = Scanner.init(source),
        .ast = Ast.init(allocator),
    };
}

pub fn deinit(this: *@This()) void {
    this.ast.deinit();
}

pub fn parseValtype(this: *@This()) ?Ast.Valtype {
    const mem = this.scanner.end_index;
    const identifier = this.scanner.nextIdentifier();
    std.debug.print("valtype: {s}\n", .{identifier});
    if (std.meta.stringToEnum(Ast.Valtype, identifier)) |valtype| {
        return valtype;
    } else {
        this.scanner.end_index = mem;
        return null;
    }
}

pub fn parseInteger(this: *@This(), T: type) !T {
    switch (this.nextThing()) {
        .number => |number| if (number.type == .integer) {
            const base = switch (number.prefix) {
                .hex => 16,
                .oct => 8,
                .bin => 2,
                .none => 10,
            };
            const unsigned = try std.fmt.parseInt(T, number.literal, base);
            return switch (number.sign) {
                .positive => unsigned,
                .negative => - unsigned,
            };
        } else {
            unreachable;
        },
        else => unreachable,
    }
}

pub fn parseFloat(this: *@This(), T: type) !T {
    return error.TODO;
}

pub fn parseInstructionArgs(this: *@This(), opcode: Inst) Ast.Instruction {
    for (instParsingStrategy(opcode)) |arg| {
        this.scanner.skipWhile(Scanner.isSeparator);
        this.scanner.start_index = this.scanner.end_index;

    }
    return Ast.Instruction.init(opcode, this.allocator);
}

pub fn parseInstructionArg(self: *@This(), arg: ParsingStrategy, out: anytype) !void {
    switch (startegy) {
        .i32 => try std.leb.writeIleb128(out, try this.parseInteger(i32)),
        .i64 => try std.leb.writeIleb128(out, try this.parseInteger(i64)),
        .f32 => try std.leb.writeIleb128(out, try this.parseFloat(f32)),
        .f64 => try std.leb.writeIleb128(out, try this.parseFloat(f64)),
        .localIndex, .funcIndex, .tableIndex, .labelIndex, .globalIndex, .elemIndex, .dataIndex => |index_type| {
            const word = self.scanner.word() orelse return error.ExpectedName;
            const index = switch (index_type) {
                .localIndex => locals.indexOf(word) orelse return error.UndefinedLocal,
                .funcIndex => try self.funcNames.depend(word),
                .tableIndex => try self.tableNames.depend(word),
                .globalIndex => try self.globalNames.depend(word),
                .elemIndex => try self.memoryNames.depend(word),
                .dataIndex => try self.dataNames.depend(word),
                .labelIndex => labels.indexOf(word) orelse return error.UndefinedLabel,
                else => unreachable,
            };
            try codeBuffer.appendUnsigned(index);
        },
        .memoryIndex => if (self.scanner.word()) |word| {
            try codeBuffer.appendUnsigned(try self.memoryNames.depend(word));
        } else {
            try codeBuffer.append(0);
        },
        .br_table => {
            var mem: usize = 0;
            var count: usize = 0;
            var buffer = Buffer.init();
            while (self.scanner.word()) |word| : (count += 1) {
                if (labels.indexOf(word)) |index| {
                    mem = buffer.len;
                    try buffer.appendUnsigned(index);
                } else {
                    return error.UndefinedLabel;
                }
            }
            if (count > 2) {
                return error.ExpectedMoreLabels;
            }
            try codeBuffer.appendUnsigned(count - 1);
            try codeBuffer.appendSlice(buffer.slice()[0..mem]);
            try codeBuffer.appendSlice(buffer.slice()[mem..]);
        },
        .reftype => {
            const reftype = self.scanner.valtype();
            if (reftype == .funcref or reftype == .externref) {
                try codeBuffer.append(@intFromEnum(reftype.?));
            } else {
                return error.ExpectedReftype;
            }
        },
        .type => {
            const type_index = try self.compileType(null);
            try codeBuffer.appendUnsigned(type_index);
        },
        .result => if (self.scanner.word()) |result| {
            if (eql(u8, result, "result")) {
                var buffer = Buffer.init();
                while (self.scanner.valtype()) |valtype| {
                    try buffer.append(@intFromEnum(valtype));
                }
                try codeBuffer.appendUnsigned(buffer.len);
                try codeBuffer.appendSlice(buffer.slice());
            } else {
                return error.ExpectedResult;
            }
        } else {
            try codeBuffer.append(0);
        },
        .label => if (self.scanner.word()) |label| {
            try labels.define(label);
        },
        .memarg_align_0, .memarg_align_1, .memarg_align_2, .memarg_align_3, .memarg_align_4 => |strat| {
            const default_align: u32 = switch (strat) {
                .memarg_align_0 => 0,
                .memarg_align_1 => 1,
                .memarg_align_2 => 2,
                .memarg_align_3 => 3,
                .memarg_align_4 => 4,
                else => unreachable,
            };
            const offset = self.scanner.integer(u32) orelse 0;
            const alignment = self.scanner.integer(u32) orelse default_align;
            try codeBuffer.appendUnsigned(alignment);
            try codeBuffer.appendUnsigned(offset);
        },
        .v128 => {
            const start = self.scanner.next;
            var count: usize = 0;
            while (self.scanner.integer(u64)) |_| {
                count += 1;
            }

            self.scanner.next = start;

            switch (count) {
                16 => for (0..count) |_| {
                    try codeBuffer.appendUnsigned(self.scanner.integer(u8).?);
                },                8 => for (0..count) |_| {
                    try codeBuffer.appendUnsigned(self.scanner.integer(u16).?);
                },
                4 => for (0..count) |_| {
                    try codeBuffer.appendUnsigned(self.scanner.integer(u32).?);
                },
                2 => for (0..count) |_| {
                    try codeBuffer.appendUnsigned(self.scanner.integer(u64).?);
                },
                else => return error.InvalidV128Constant,
            }
        },
        .byte => {
            const byte = self.scanner.integer(u8) orelse return error.ExpectedByte;
            try codeBuffer.append(byte);
        },
    }
}

pub fn parseFunction(this: *@This()) !Ast.Function {
    var @"type" = Ast.Type.init(this.allocator);
    var params = std.ArrayList([]const u8).init(this.allocator);
    var instructions = std.ArrayList(Ast.Instruction).init(this.allocator);

    var thing = this.scanner.nextIdentifier();
    if (std.mem.eql(u8, thing, "param")) {
        while (true) {
            this.scanner.skipWhile(Scanner.isSeparator);
            this.scanner.start_index = this.scanner.end_index;
            thing = this.scanner.nextIdentifier();
            this.scanner.skipWhile(Scanner.isSeparator);
            this.scanner.start_index = this.scanner.end_index;
            if (!std.mem.eql(u8, thing, "result") and thing.len > 0) {
                try params.append(thing);
                this.scanner.skipWhile(Scanner.isSeparator);
                this.scanner.start_index = this.scanner.end_index;
                try @"type".params.append(this.parseValtype().?);
                continue;
            } else {
                break;
            }
        }
    }

    if (std.mem.eql(u8, thing, "result")) {
        this.scanner.skipWhile(Scanner.isSeparator);
        this.scanner.start_index = this.scanner.end_index;
        while (this.parseValtype()) |valtype| {
            this.scanner.skipWhile(Scanner.isSeparator);
            this.scanner.start_index = this.scanner.end_index;
            try @"type".result.append(valtype);
        }
    }

    const indentation_len = this.scanner.nextIndentation();
    if (indentation_len > 0) {
        var current_indentation = indentation_len;
        this.scanner.skipWhile(Scanner.isSeparator);
        this.scanner.start_index = this.scanner.end_index;
        var instruction_string = this.scanner.nextIdentifier();
        while (instruction_string.len > 0) {
            std.debug.print("inst: \"{s}\"\n", .{instruction_string});
            const opcode = std.meta.stringToEnum(Inst, instruction_string).?;
            std.debug.print("inst: \"{any}\"\n", .{opcode});
            this.scanner.skipWhile(Scanner.isSeparator);
            this.scanner.start_index = this.scanner.end_index;
            const instruction = this.parseInstructionArgs(opcode);
            try instructions.append(instruction);
            this.scanner.skipUntil(Scanner.isNewline);
            this.scanner.start_index = this.scanner.end_index;
            const new_indentation = this.scanner.nextIndentation();
            this.scanner.start_index = this.scanner.end_index;
            std.debug.assert(new_indentation % indentation_len == 0);
            std.debug.assert(new_indentation <= current_indentation + indentation_len);
            if (new_indentation < current_indentation) {
                const dedentations = (current_indentation - new_indentation) / indentation_len;
                for (0..dedentations) |_| {
                    try instructions.append(Ast.Instruction.init(Inst.@"end", this.allocator));
                }
            }
            current_indentation = new_indentation;
            instruction_string = this.scanner.nextIdentifier();
        }
    }

    try instructions.append(Ast.Instruction.init(Inst.@"end", this.allocator));

    return .{
        .type = @"type",
        .params = params,
        .instructions = instructions,
    };
}

pub fn parse(this: *@This()) !void {
    const Prefix = enum {
        func,
    };

    while (true) {
        this.scanner.skipWhile(Scanner.isWhitespace);
        const prefix_string = this.scanner.nextIdentifier();

        if (std.meta.stringToEnum(Prefix, prefix_string)) |prefix| {
            switch (prefix) {
                .func => {
                    this.scanner.skipWhile(Scanner.isSeparator);
                    this.scanner.start_index = this.scanner.end_index;
                    const identifier = this.scanner.nextIdentifier();
                    this.scanner.skipWhile(Scanner.isSeparator);
                    this.scanner.start_index = this.scanner.end_index;
                    try this.ast.functions.put(identifier, try this.parseFunction());
                },
            }
        } else {
            break;
        }
    }
}

test "manually parse func" {
    var this = @This().init("func hello param x i32 y i32 z funcref result i32 i32\n  i32.const 0\n  i32.const 1", std.testing.allocator);
    try this.parse();
    std.debug.print("param types: {any}\n", .{this.ast.functions.get("hello").?.type.params.items});
    std.debug.print("result types: {any}\n", .{this.ast.functions.get("hello").?.type.result.items});
    std.debug.print("params: {any}\n", .{this.ast.functions.get("hello").?.params.items});
    std.debug.print("code: {any}\n", .{this.ast.functions.get("hello").?.instructions.items});
    this.deinit();
}
