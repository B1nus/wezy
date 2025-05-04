const std = @import("std");
const eql = std.mem.eql;
const expect = std.testing.expect;
const Inst = @import("opcodes.zig").Inst;
const instToBytes = @import("opcodes.zig").instToBytes;
const instParsingStrategy = @import("opcodes.zig").instParsingStrategy;
const ParsingStrategy = @import("opcodes.zig").ParsingStrategy;
const Scanner = @import("Scanner.zig");
const Buffer = @import("buffer.zig").Buffer(0x10000);
const ValueMap = @import("maps.zig").ValueMap(0x1000);
const NameMap = @import("maps.zig").NameMap(0x1000);

scanner: Scanner,
output: Buffer,

typeBuffer: Buffer,
importBuffer: Buffer,
functionBuffer: Buffer,
tableBuffer: Buffer,
memoryBuffer: Buffer,
globalBuffer: Buffer,
exportBuffer: Buffer,
elementBuffer: Buffer,
codeBuffer: Buffer,
dataBuffer: Buffer,

types: ValueMap,
funcNames: NameMap,
tableNames: NameMap,
memoryNames: NameMap,
globalNames: NameMap,
elementNames: NameMap,
dataNames: NameMap,
codeNames: NameMap,
importNames: NameMap,
exportNames: NameMap,

pub fn init(source: []const u8) @This() {
    return .{
        .scanner = Scanner.init(source),
        .output = undefined,

        .typeBuffer = Buffer.init(),
        .importBuffer = Buffer.init(),
        .functionBuffer = Buffer.init(),
        .tableBuffer = Buffer.init(),
        .memoryBuffer = Buffer.init(),
        .globalBuffer = Buffer.init(),
        .exportBuffer = Buffer.init(),
        .elementBuffer = Buffer.init(),
        .codeBuffer = Buffer.init(),
        .dataBuffer = Buffer.init(),

        .types = ValueMap.init(),
        .funcNames = NameMap.init(),
        .tableNames = NameMap.init(),
        .memoryNames = NameMap.init(),
        .globalNames = NameMap.init(),
        .elementNames = NameMap.init(),
        .dataNames = NameMap.init(),
        .codeNames = NameMap.init(),
        .importNames = NameMap.init(),
        .exportNames = NameMap.init(),
    };
}

pub fn compileValtypeList(self: *@This(), locals: ?*NameMap) !void {
    var buffer = Buffer.init();

    while (true) {
        if (locals) |localMap| {
            const start = self.scanner.next;
            if (self.scanner.word()) |word| {
                if (eql(u8, word, "result")) {
                    self.scanner.next = start;
                    break;
                }
                try localMap.define(word);
            } else {
                break;
            }
        }
        if (self.scanner.valtype()) |valtype| {
            try buffer.append(@intFromEnum(valtype));
        } else if (locals != null) {
            return error.ExpectedValtype;
        } else {
            break;
        }
    }

    if (buffer.len > 0) {
        try self.typeBuffer.appendUnsigned(buffer.len);
        try self.typeBuffer.appendSlice(buffer.slice());
    } else {
        return if (locals == null) error.ExpectedValtype else error.ExpectedParamName;
    }
}

pub fn compilePrefixedValtypeList(self: *@This(), prefix: []const u8, locals: ?*NameMap) !void {
    if (self.scanner.expect(prefix)) {
        try self.compileValtypeList(locals);
    } else {
        try self.typeBuffer.append(0);
    }
}

pub fn compileType(self: *@This(), locals: ?*NameMap) !usize {
    const start = self.typeBuffer.len;
    try self.typeBuffer.append(0x60);

    if (self.scanner.peek()) |peek| {
        if (!eql(u8, peek, "param") and !eql(u8, peek, "result") and !self.scanner.peekNewline()) {
            return error.ExpectedParamOrResult;
        }
    }

    try self.compilePrefixedValtypeList("param", locals);
    try self.compilePrefixedValtypeList("result", null);

    const parsedType = self.typeBuffer.slice()[start..];
    if (self.types.indexOf(parsedType)) |index| {
        self.typeBuffer.len = start;
        return index;
    } else {
        return try self.types.appendPos(parsedType, self.types.len);
    }
}

pub fn compileLimit(self: *@This(), buffer: *Buffer) !void {
    const min = self.scanner.integer(u32) orelse return error.ExpectedMin;
    if (self.scanner.integer(u32)) |max| {
        try buffer.append(1);
        try buffer.appendUnsigned(min);
        try buffer.appendUnsigned(max);
    } else {
        try buffer.append(0);
        try buffer.appendUnsigned(min);
    }
}

pub fn compileGlobalType(self: *@This(), buffer: *Buffer) !void {
    const mutable = self.scanner.expect("mut");

    if (self.scanner.valtype()) |valtype| {
        try buffer.append(@intFromEnum(valtype));
    } else {
        return error.ExpectedValtype;
    }

    try buffer.append(if (mutable) 1 else 0);
}

pub fn compileMemoryType(self: *@This(), buffer: *Buffer) !void {
    try self.compileLimit(buffer);
}

pub fn compileTableType(self: *@This(), buffer: *Buffer) !void {
    const valtype = self.scanner.valtype();
    if (valtype == .funcref or valtype == .externref) {
        try buffer.append(@intFromEnum(valtype.?));
        try self.compileLimit(buffer);
    } else {
        return error.ExpectedReftype;
    }
}

pub fn compileString(self: *@This()) !Buffer {
    var buffer = Buffer.init();
    const string = self.scanner.string() orelse return error.ExpectedString;
    var i: usize = 0;
    while (i < string.len) : (i += 1) {
        switch (string[i]) {
            '\\' => if (i + 1 < string.len) {
                i += 1;
                switch (string[i]) {
                    'n' => try buffer.append('\n'),
                    '0'...'9', 'a'...'f', 'A'...'F' => if (i + 1 < string.len) {
                        const hex = try std.fmt.parseInt(u8, string[i .. i + 2], 16);
                        try buffer.append(hex);
                        i += 1;
                    } else {
                        return error.ExpectedTwoDigitHex;
                    },
                    else => return error.UnknownEscapeCharacter,
                }
            } else {
                return error.ExpectedEscapeCharacter;
            },
            else => try buffer.append(string[i]),
        }
    }
    return buffer;
}

pub fn compileData(self: *@This()) !void {
    const name = self.scanner.word() orelse return error.ExpectedName;
    try self.dataNames.define(name);
    const data_mode = self.scanner.dataMode() orelse return error.ExpectedDataMode;

    switch (data_mode) {
        .passive => {
            try self.dataBuffer.append(1);
        },
        .active => {
            const memory_name = self.scanner.word() orelse return error.ExpectedMemory;
            const memory_index = try self.memoryNames.depend(memory_name);
            const inst = self.scanner.inst() orelse return error.ExpectedOffset;
            try self.dataBuffer.append(2);
            try self.dataBuffer.appendUnsigned(memory_index);
            try self.compileInst(&self.dataBuffer, inst);
            try self.dataBuffer.append(0x0b);
        },
        else => return error.ExpectedActiveOrPassive,
    }
    const string = try self.compileString();
    try self.dataBuffer.appendUnsigned(string.len);
    try self.dataBuffer.appendSlice(string.slice());
}

pub fn compileFunc(self: *@This(), codeBuffer: *Buffer, locals: *NameMap, indentation: usize) !void {
    const name = self.scanner.word() orelse return error.ExpectedName;
    try self.funcNames.define(name);
    try self.codeNames.define(name);
    const type_index = try self.compileType(locals);
    try self.functionBuffer.appendUnsigned(type_index);
    
    var labels = NameMap.init();

    if (self.scanner.expectIndentation(indentation)) {
        try self.compileLocals(codeBuffer, locals, indentation);
        if (self.scanner.expectSplit(indentation) or (locals.len == 0 and self.scanner.peek() != null)) {
            try self.compileInstructions(codeBuffer, locals, &labels, indentation);
        } else {
            try codeBuffer.appendSlice(&.{0x0b});
        }
    } else {
        try codeBuffer.appendSlice(&.{ 0, 0x0b });
    }
}

const ByteSet = struct {
    const N: usize = 100;
    array: [N]u8,
    len: usize,

    pub fn init() @This() {
        return .{
            .array = undefined,
            .len = 0,
        };
    }

    pub fn add(self: *@This(), byte: u8) bool {
        // too many types
        if (self.len >= N) {
            return false;
        }

        // already exists
        for (self.array[0..self.len]) |other| {
            if (byte == other) {
                return false;
            }
        }

        // append
        self.array[self.len] = byte;
        self.len += 1;
        return true;
    }
};

pub fn compileLocals(self: *@This(), codeBuffer: *Buffer, locals: *NameMap, indentation: usize) !void {
    var valtypes = ByteSet.init();
    var buffer = Buffer.init();
    while (self.scanner.valtype()) |valtype| {
        const valtypeByte = @intFromEnum(valtype);

        if (!valtypes.add(valtypeByte)) {
            return error.DuplicateValtype;
        }

        var count: usize = 0;
        while (self.scanner.word()) |word| : (count += 1) {
            try locals.define(word);
        }
        if (count == 0) {
            return error.ExpectedName;
        }
        try buffer.appendUnsigned(count);
        try buffer.append(valtypeByte);

        if (self.scanner.expectIndentation(indentation)) {
            continue;
        } else {
            break;
        }
    }
    try codeBuffer.appendUnsigned(valtypes.len);
    try codeBuffer.appendSlice(buffer.slice());
}

pub fn compileInstructions(self: *@This(), codeBuffer: *Buffer, locals: *const NameMap, labels: *NameMap, indentation: usize) !void {
    while (self.scanner.inst()) |inst| {
        try self.compileInstruction(codeBuffer, locals, labels, inst);
        if (!self.scanner.expectIndentation(indentation)) {
            try codeBuffer.appendSlice(instToBytes(.end));
            break;
        }
    }
}

pub fn compileInstruction(self: *@This(), codeBuffer: *Buffer, locals: *const NameMap, labels: *NameMap, inst: Inst) !void {
    try codeBuffer.appendSlice(instToBytes(inst));
    for (instParsingStrategy(inst)) |strategy| {
        try self.compileParsingStrategy(codeBuffer, locals, labels, strategy);
    }
}

pub fn compileInst(self: *@This(), codeBuffer: *Buffer, inst: Inst) !void {
    var locals = NameMap.init();
    var labels = NameMap.init();

    return self.compileInstruction(codeBuffer, &locals, &labels, inst);
}

pub fn compileParsingStrategy(self: *@This(), codeBuffer: *Buffer, locals: *const NameMap, labels: *NameMap, startegy: ParsingStrategy) !void {
    switch (startegy) {
        .i32 => {
            const integer = self.scanner.integer(i32) orelse return error.ExpectedInteger;
            try codeBuffer.appendSigned(integer);
        },
        .i64 => {
            const integer = self.scanner.integer(i64) orelse return error.ExpectedInteger;
            try codeBuffer.appendSigned(integer);
        },
        .f32 => {
            const float = self.scanner.float(f32) orelse return error.ExpectedFloat;
            try codeBuffer.appendUnsigned(@as(u32, @bitCast(float)));
        },
        .f64 => {
            const float = self.scanner.float(f64) orelse return error.ExpectedFloat;
            try codeBuffer.appendUnsigned(@as(u64, @bitCast(float)));
        },
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

pub fn parse(self: *@This()) !void {
    var prefixSet = ByteSet.init();
    const indentation = 2;

    section: while (self.scanner.peek()) |prefixStr| {
        const prefix = std.meta.stringToEnum(Scanner.Prefix, prefixStr) orelse return error.ExpectedPrefix;

        if (!prefixSet.add(@intFromEnum(prefix)))  {
            return error.SectionAlreadyDefined;
        }

        while (eql(u8, self.scanner.word() orelse return error.ExpectedPrefix, prefixStr)) {
            switch (prefix) {
                .import => {
                    const module = self.scanner.word() orelse return error.ExpectedName;
                    const name = self.scanner.word() orelse return error.ExpectedName;
                    const kind = self.scanner.importExportType() orelse return error.ExpectedType;
                    const alias = self.scanner.word() orelse return error.ExpectedName;

                    try self.importNames.define(alias);
                    try self.funcNames.define(alias);
                    
                    try self.importBuffer.appendUnsigned(module.len);
                    try self.importBuffer.appendSlice(module);
                    try self.importBuffer.appendUnsigned(name.len);
                    try self.importBuffer.appendSlice(name);
                    try self.importBuffer.append(@intFromEnum(kind));

                    switch (kind) {
                        .func => {
                            const type_index = try self.compileType(null);
                            try self.importBuffer.appendUnsigned(type_index);
                        },
                        .memory => try self.compileMemoryType(&self.memoryBuffer),
                        .global => try self.compileGlobalType(&self.globalBuffer),
                        .table => try self.compileTableType(&self.tableBuffer),
                    }
                },
                .func => {
                    var codeBuffer = Buffer.init();
                    var locals = NameMap.init();

                    try self.compileFunc(&codeBuffer, &locals, indentation);
                    try self.codeBuffer.appendUnsigned(codeBuffer.len);
                    try self.codeBuffer.appendSlice(codeBuffer.slice());

                    if (self.scanner.expectSplit(0)) {
                        continue;
                    } else {
                        break;
                    }
                },
                .@"export" => {
                    const alias = self.scanner.word() orelse return error.ExpectedName;
                    const kind = self.scanner.importExportType() orelse return error.ExpectedType;
                    const name = self.scanner.word() orelse return error.ExpectedName;

                    try self.exportNames.define(alias);

                    try self.exportBuffer.appendUnsigned(alias.len);
                    try self.exportBuffer.appendSlice(alias);
                    try self.exportBuffer.append(@intFromEnum(kind));

                    const index = switch (kind) {
                        .func => try self.funcNames.depend(name),
                        .memory => try self.memoryNames.depend(name),
                        .global => try self.globalNames.depend(name),
                        .table => try self.tableNames.depend(name),
                    };

                    try self.exportBuffer.appendUnsigned(index);
                },
                .memory => {
                    const name = self.scanner.word() orelse return error.ExpectedName;

                    try self.memoryNames.define(name);
                    try self.compileMemoryType(&self.memoryBuffer);
                },
                .global => {
                    const name = self.scanner.word() orelse return error.ExpectedName;

                    try self.globalNames.define(name);
                    try self.compileGlobalType(&self.globalBuffer);

                    const inst = self.scanner.inst() orelse return error.ExpectedValue;
                    try self.compileInst(&self.globalBuffer, inst);
                    try self.globalBuffer.append(0xb);
                },
                .data => try self.compileData(),
                .table => {
                    const name = self.scanner.word() orelse return error.ExpectedName;

                    try self.tableNames.define(name);
                    try self.compileTableType(&self.tableBuffer);
                },
                .elem => {
                    const name = self.scanner.word() orelse return error.ExpectedName;
                    const data_mode = self.scanner.dataMode() orelse return error.ExpectedDataMode;

                    try self.elementNames.define(name);

                    switch (data_mode) {
                        .active => {
                            const table = self.scanner.word() orelse return error.ExpectedTable;
                            const table_index = try self.tableNames.depend(table);
                            const inst = self.scanner.inst() orelse return error.ExpectedOffset;
                            try self.elementBuffer.append(6);
                            try self.elementBuffer.appendUnsigned(table_index);
                            try self.compileInst(&self.elementBuffer, inst);
                            try self.elementBuffer.append(0x0b);
                        },
                        .passive => try self.elementBuffer.append(5),
                        .declarative => try self.elementBuffer.append(7),
                    }

                    const valtype = self.scanner.valtype();
                    if (valtype == .funcref or valtype == .externref) {
                        try self.elementBuffer.append(@intFromEnum(valtype.?));
                        var buffer = Buffer.init();
                        while (self.scanner.inst()) |inst| {
                            try self.compileInst(&buffer, inst);
                            try buffer.append(0x0b);
                        }

                        if (buffer.len == 0) {
                            return error.ExpectedElement;
                        }

                        try self.elementBuffer.appendUnsigned(self.elementBuffer.len);
                        try self.elementBuffer.appendSlice(buffer.slice());
                    } else {
                        return error.ExpectedReftype;
                    }
                },
            }

            if (self.scanner.expectSplit(0)) {
                continue :section;
            } else if (self.scanner.expectIndentation(0)) {
                continue;
            }
        }

    }

    _ = self.scanner.newline();

    if (!self.scanner.endOfFile()) {
        return error.ExpectedEndOfFile;
    }
}

pub fn prefixCount(self: *@This(), slice: []const u8, count: usize) !void {
    var buffer = Buffer.init();
    try buffer.appendUnsigned(count);
    try buffer.appendSlice(slice);
    try self.output.appendUnsigned(buffer.len);
    try self.output.appendSlice(buffer.slice());
}

pub fn compileParsed(self: *@This()) !Buffer {
    self.output = Buffer.init();

    if (self.types.len > 0) {
        try self.output.append(1);
        try self.prefixCount(self.typeBuffer.slice(), self.types.len);
    }

    if (self.importNames.len > 0) {
        try self.output.append(2);
        try self.prefixCount(self.importBuffer.slice(), self.importNames.len);
    }

    if (self.codeNames.len > 0) {
        try self.output.append(3);
        try self.prefixCount(self.functionBuffer.slice(), self.codeNames.len);
    }

    if (self.tableNames.len > 0) {
        try self.output.append(4);
        try self.prefixCount(self.tableBuffer.slice(), self.tableNames.len);
    }

    if (self.memoryNames.len > 0) {
        try self.output.append(5);
        try self.prefixCount(self.memoryBuffer.slice(), self.memoryNames.len);
    }

    if (self.globalNames.len > 0) {
        try self.output.append(6);
        try self.prefixCount(self.globalBuffer.slice(), self.globalNames.len);
    }

    if (self.exportNames.len > 0) {
        try self.output.append(7);
        try self.prefixCount(self.exportBuffer.slice(), self.exportNames.len);
    }

    if (self.elementNames.len > 0) {
        try self.output.append(9);
        try self.prefixCount(self.elementBuffer.slice(), self.elementNames.len);
    }

    if (self.codeNames.len > 0) {
        try self.output.append(10);
        try self.prefixCount(self.codeBuffer.slice(), self.codeNames.len);
    }

    if (self.dataNames.len > 0) {
        try self.output.append(11);
        try self.prefixCount(self.dataBuffer.slice(), self.dataNames.len);
    }

    return self.output;
}

pub fn compile(self: *@This()) !Buffer {
    try self.parse();
    return self.compileParsed();
}

test "func type" {
    var mod = @This().init("param i32 i64 f32 f64 result i32 i64 f32 f64 param i32 i64 f32 f64 result i32 i64 f32 f64 param i32");
    try expect(try mod.compileType(null) == 0);
    try expect(try mod.compileType(null) == 0);
    try expect(try mod.compileType(null) == 1);
    try expect(try mod.compileType(null) == 2);
    try expect(eql(u8, mod.typeBuffer.slice(), &.{ 0x60, 4, 0x7f, 0x7e, 0x7d, 0x7c, 4, 0x7f, 0x7e, 0x7d, 0x7c, 0x60, 1, 0x7f, 0, 0x60, 0, 0 }));
}

test "func type with arg names" {
    var mod = @This().init("param x i32 y i64 < f32 z f64 result i32 i64 f32 f64");
    var locals = NameMap.init();
    try expect(try mod.compileType(&locals) == 0);
    try expect(eql(u8, mod.typeBuffer.slice(), &.{ 0x60, 4, 0x7f, 0x7e, 0x7d, 0x7c, 4, 0x7f, 0x7e, 0x7d, 0x7c }));
    try expect(eql(u8, locals.array[0], "x"));
    try expect(eql(u8, locals.array[1], "y"));
    try expect(eql(u8, locals.array[2], "<"));
    try expect(eql(u8, locals.array[3], "z"));
    try expect(locals.len == 4);
}

test "global type" {
    var mod = @This().init("mut i32 i32");
    var buffer = Buffer.init();
    try mod.compileGlobalType(&buffer);
    try mod.compileGlobalType(&buffer);
    try expect(eql(u8, buffer.slice(), &.{ 0x7f, 1, 0x7f, 0 }));
}

test "passive data" {
    var mod = @This().init("name passive hello!\\n");
    try mod.compileData();
    try expect(eql(u8, mod.dataBuffer.slice(), "\x01\x07hello!\n"));
}

test "active data" {
    var mod = @This().init("data1 active memory i32.const 0 hello!\\n\ndata2 active memory i32.const 1 hi!\\n");
    try mod.compileData();
    try expect(mod.scanner.newline());
    try mod.compileData();
    try expect(eql(u8, mod.dataBuffer.slice(), "\x02\x00\x41\x00\x0b\x07hello!\n\x02\x00\x41\x01\x0b\x04hi!\n"));
}

test "empty function" {
    var mod = @This().init("hello");
    var codeBuffer = Buffer.init();
    var locals = NameMap.init();
    try mod.compileFunc(&codeBuffer, &locals, 2);
    try expect(eql(u8, codeBuffer.slice(), &.{ 0, 0x0b }));
}

test "locals" {
    var mod = @This().init(
        \\i32 x y z
        \\  i64 w
    );
    var codeBuffer = Buffer.init();
    var locals = NameMap.init();
    try mod.compileLocals(&codeBuffer, &locals, 2);
    try expect(eql(u8, codeBuffer.slice(), &.{ 2, 3, 0x7f, 1, 0x7e }));
}

test "instructions" {
    var mod = @This().init(
        \\i32.const 2
        \\  local.set x
    );
    var codeBuffer = Buffer.init();
    var locals = NameMap.init();
    try locals.define("x");
    var labels = NameMap.init();
    try mod.compileInstructions(&codeBuffer, &locals, &labels, 2);
    try expect(locals.len == 1);
    try expect(eql(u8, locals.array[0], "x"));
    try expect(eql(u8, codeBuffer.slice(), &.{ 0x41, 2, 0x21, 0, 0xb }));
}

test "locals in function" {
    var mod = @This().init(
        \\hello param x i32 result i32
        \\  i32 y
        \\
        \\  i32.const 2
        \\  local.set y
        \\  local.get x
        \\  local.get y
        \\  i32.add
    );
    var codeBuffer = Buffer.init();
    var locals = NameMap.init();
    try mod.compileFunc(&codeBuffer, &locals, 2);
    try expect(eql(u8, codeBuffer.slice(), &.{ 1, 1, 0x7f, 0x41, 0x02, 0x21, 0x01, 0x20, 0x00, 0x20, 0x01, 0x6a, 0x0b }));
}

test "constant function" {
    var mod = @This().init(
        \\i32.const 0
    );
    var codeBuffer = Buffer.init();
    var locals = NameMap.init();
    var labels = NameMap.init();
    try mod.compileInstructions(&codeBuffer, &locals, &labels, 2);
    try expect(eql(u8, codeBuffer.slice(), &.{ 0x41, 0x00, 0x0b }));
}

test "integration" {
    var mod = @This().init(
        \\import wasi_snapshot_preview1 fd_write func fd_write param i32 i32 i32 i32 result i32
        \\
        \\memory memory 1
        \\
        \\data hi active memory i32.const 0 \08\00\00\00\04\00\00\00hi!\n
        \\
        \\export _start func start
        \\export memory memory memory
        \\
        \\func start
        \\  i32.const 1
        \\  i32.const 0
        \\  i32.const 1
        \\  i32.const 0
        \\  call fd_write
        \\  drop
    );
    const out = mod.compile() catch |err| {
        return try std.io.getStdErr().writer().print("{s}:\n{s}\n", .{@errorName(err), mod.scanner.currentLine()});
    };
    try expect(eql(u8, mod.typeBuffer.slice(), &.{ 0x60, 0x04, 0x7f, 0x7f, 0x7f, 0x7f, 0x01, 0x7f, 0x60, 0x00, 0x00 }));
    try expect(eql(u8, mod.importBuffer.slice(), "\x16wasi_snapshot_preview1\x08fd_write\x00\x00"));
    try expect(eql(u8, mod.functionBuffer.slice(), "\x01"));
    try expect(eql(u8, mod.memoryBuffer.slice(), "\x00\x01"));
    try expect(eql(u8, mod.exportBuffer.slice(), "\x06_start\x00\x01\x06memory\x02\x00"));
    try expect(eql(u8, mod.codeBuffer.slice(), &.{ 0x0d, 0x00, 0x41, 0x01, 0x41, 0x00, 0x41, 0x01, 0x41, 0x00, 0x10, 0x00, 0x1a, 0x0b }));
    try expect(eql(u8, mod.dataBuffer.slice(), &.{ 0x02, 0x00, 0x41, 0x00, 0x0b, 0x0c, 0x08, 0, 0, 0, 4, 0, 0, 0, 'h', 'i', '!', '\n' }));
    try expect(eql(u8, out.slice(), &.{ 0x01, 0x0c, 0x02, 0x60, 0x04, 0x7f, 0x7f, 0x7f, 0x7f, 0x01, 0x7f, 0x60, 0x00, 0x00, 0x02, 0x23, 0x01, 0x16, 0x77, 0x61, 0x73, 0x69, 0x5f, 0x73, 0x6e, 0x61, 0x70, 0x73, 0x68, 0x6f, 0x74, 0x5f, 0x70, 0x72, 0x65, 0x76, 0x69, 0x65, 0x77, 0x31, 0x08, 0x66, 0x64, 0x5f, 0x77, 0x72, 0x69, 0x74, 0x65, 0x00, 0x00, 0x03, 0x02, 0x01, 0x01, 0x05, 0x03, 0x01, 0x00, 0x01, 0x07, 0x13, 0x02, 0x06, 0x5f, 0x73, 0x74, 0x61, 0x72, 0x74, 0x00, 0x01, 0x06, 0x6d, 0x65, 0x6d, 0x6f, 0x72, 0x79, 0x02, 0x00, 0x0a, 0x0f, 0x01, 0x0d, 0x00, 0x41, 0x01, 0x41, 0x00, 0x41, 0x01, 0x41, 0x00, 0x10, 0x00, 0x1a, 0x0b, 0x0b, 0x13, 0x01, 0x02, 0x00, 0x41, 0x00, 0x0b, 0x0c, 0x08, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x68, 0x69, 0x21, 0x0a }));
}
