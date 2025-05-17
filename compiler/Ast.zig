const std = @import("std");
const Inst = @import("opcodes.zig").Inst;

imports: std.StringHashMap(Import),
exports: std.StringHashMap(Export),
functions: std.StringHashMap(Function),
data: std.StringHashMap(Data),
tables: std.StringHashMap(Table),
elements: std.StringHashMap(Element),
globals: std.StringHashMap(Global),
memories: std.StringHashMap(Memory),

pub fn init(allocator: std.mem.Allocator) @This() {
    return .{
        .imports = std.StringHashMap(Import).init(allocator),
        .exports = std.StringHashMap(Export).init(allocator),
        .functions = std.StringHashMap(Function).init(allocator),
        .data = std.StringHashMap(Data).init(allocator),
        .tables = std.StringHashMap(Table).init(allocator),
        .elements = std.StringHashMap(Element).init(allocator),
        .globals = std.StringHashMap(Global).init(allocator),
        .memories = std.StringHashMap(Memory).init(allocator),
    };
}

pub fn deinit(this: *@This()) void {
    var functions = this.functions.valueIterator();
    while (functions.next()) |function| {
        function.deinit();
    }

    var imports = this.imports.valueIterator();
    while (imports.next()) |import| {
        import.deinit();
    }

    var data = this.data.valueIterator();
    while (data.next()) |data_item| {
        data_item.deinit();
    }

    this.imports.deinit();
    this.exports.deinit();
    this.functions.deinit();
    this.data.deinit();
    this.elements.deinit();
    this.globals.deinit();
    this.memories.deinit();
}

pub const Limits = struct {
    min: usize,
    max: ?usize,
};

pub const DescType = enum(u8) {
    function = 0,
    table = 1,
    memory = 2,
    global = 3,
};

pub const Import = struct {
    module: []const u8,
    name: []const u8,
    desc: Desc,

    pub fn deinit(this: *@This()) void {
        switch (this.desc) {
            .function => |*@"type"| @"type".deinit(),
            else => {},
        }
    }

    pub const Desc = union(DescType) {
        function: Type,
        table: Table,
        memory: Memory,
        global: Global,
    };
};

pub const Export = struct {
    desc_type: DescType,
    label: []const u8,
};

pub const Table = struct {
    reftype: Valtype,
    limits: Limits,
};

pub const Memory = struct {
    pages: Limits,
};

pub const Data = struct {
    memory: ?[]const u8,
    offset: ?Instruction,
    bytes: std.ArrayList(u8),

    pub fn deinit(this: *@This()) void {
        this.bytes.deinit();
    }
};

pub const Global = struct {
    valtype: Valtype,
    initial: Instruction,
    mutable: bool,
};

pub const Element = struct {
    active: ?ActiveElement,
    reftype: Valtype,
    items: std.ArrayList(Instruction),

    pub const ActiveElement = struct {
        offset: Instruction,
        table: ?[]const u8,
    };
};

pub const Function = struct {
    type: Type,
    params: std.ArrayList([]const u8),
    instructions: std.ArrayList(Instruction),

    pub fn deinit(this: *@This()) void {
        for (this.instructions.items) |*instruction| {
            instruction.deinit();
        }
        this.instructions.deinit();
        this.params.deinit();
        this.type.deinit();
    }
};

pub const Type = struct {
    params: std.ArrayList(Valtype),
    result: std.ArrayList(Valtype),

    pub fn init(allocator: std.mem.Allocator) @This() {
        return .{
            .params = std.ArrayList(Valtype).init(allocator),
            .result = std.ArrayList(Valtype).init(allocator),
        };
    }

    pub fn deinit(this: *@This()) void {
        this.params.deinit();
        this.result.deinit();
    }
};

pub const Valtype = enum(u8) {
    i32 = 0x7f,
    i64 = 0x7e,
    f32 = 0x7d,
    f64 = 0x7c,
    funcref = 0x70,
    externref = 0x6f,
    v128 = 0x7b,
};

pub const Instruction = struct {
    opcode: Inst,
    args: std.ArrayList(u8),

    pub fn init(opcode: Inst, allocator: std.mem.Allocator) @This() {
        return .{
            .opcode = opcode,
            .args = std.ArrayList(u8).init(allocator),
        };
    }

    pub fn deinit(this: *@This()) void {
        this.args.deinit();
    }
};
