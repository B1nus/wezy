const std = @import("std");
const eql = std.mem.eql;
const expect = std.testing.expect;
const instToBytes = @import("inst.zig").instToBytes;
const instParsingStrategy = @import("inst.zig").instParsingStrategy;
const ParsingStrategy = @import("inst.zig").ParsingStrategy;
const Scanner = @import("Scanner.zig");
const Buffer = @import("buffer.zig").Buffer(0x10000);
const ValueMap = @import("maps.zig").ValueMap(0x1000);
const NameMap = @import("maps.zig").NameMap(0x1000);

scanner: Scanner,

// Save import and export names for use in component model later.

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

pub fn init(source: []const u8) @This() {
    return .{
        .scanner = Scanner.init(source),

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
                        const hex = try std.fmt.parseInt(u8, string[i..i + 2], 16);
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
            const start = self.scanner.next;
            if (self.scanner.integer(u32)) |_| {
                try self.dataBuffer.append(0);
                self.scanner.next = start;
            } else {
                try self.dataBuffer.append(2);
                if (self.scanner.word()) |memory| {
                    try self.dataBuffer.appendUnsigned(try self.memoryNames.depend(memory));

                } else {
                    return error.ExpectedMemoryName;
                }
            }
            const offset = self.scanner.integer(u32) orelse return error.ExpectedOffset;
            try self.dataBuffer.append(0x41);
            try self.dataBuffer.appendSigned(offset);
            try self.dataBuffer.append(0x0b);
        },
        .declarative => return error.UnexpectedDeclarative,
    }
    const string = try self.compileString();
    try self.dataBuffer.appendUnsigned(string.len);
    try self.dataBuffer.appendSlice(string.slice());
}

pub fn compileFunc(self: *@This(), codeBuffer: *Buffer, locals: *NameMap, indentation: usize) !void {
    const name = self.scanner.word() orelse return error.ExpectedName;
    try self.funcNames.define(name);
    const type_index = try self.compileType(locals);
    try self.functionBuffer.appendUnsigned(type_index);

    if (self.scanner.expectIndentation(indentation)) {
        try self.compileLocals(codeBuffer, locals, indentation);
        if (self.scanner.expectSplit(indentation)) {
            try self.compileInstructions(codeBuffer, locals, indentation);
        } else {
            try codeBuffer.appendSlice(&.{ 0x0b });
        }
    } else {
        try codeBuffer.appendSlice(&.{ 0, 0x0b });
    }
}

const ByteSet = struct {
    const N: usize = 7;
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

pub fn compileInstructions(self: *@This(), codeBuffer: *Buffer, locals: *const NameMap, indentation: usize) !void {
    while (self.scanner.inst()) |inst| {
        // Don't forget special treatement for select instruction.
        try codeBuffer.appendSlice(instToBytes(inst));
        for (instParsingStrategy(inst)) |strategy| {
            try self.compileParsingStrategy(codeBuffer, locals, strategy);
        }
        if (!self.scanner.expectIndentation(indentation)) {
            try codeBuffer.appendSlice(instToBytes(.@"end"));
            break;
        }
    }
}

pub fn compileParsingStrategy(self: *@This(), codeBuffer: *Buffer, locals: *const NameMap, startegy: ParsingStrategy) !void {
    switch (startegy) {
        .i32 => {
            const integer = self.scanner.integer(i32) orelse return error.ExpectedInteger;
            try codeBuffer.appendSigned(integer);
        },
        .localIndex => {
            const index = locals.indexOf(self.scanner.word() orelse return error.ExpectedName) orelse return error.UndefinedName;
            try codeBuffer.appendUnsigned(index);
        },
        else => {},
    }
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
    try expect(eql(u8, buffer.slice(), &.{0x7f, 1, 0x7f, 0}));
}

test "passive data" {
    var mod = @This().init("name passive hello!\\n");
    try mod.compileData();
    try expect(eql(u8, mod.dataBuffer.slice(), "\x01\x07hello!\n"));
}

test "active data" {
    var mod = @This().init("data1 active memory 0 hello!\\n\ndata2 active 1 hi!\\n");
    try mod.compileData();
    try expect(mod.scanner.newline());
    try mod.compileData();
    try expect(eql(u8, mod.dataBuffer.slice(), "\x02\x00\x41\x00\x0b\x07hello!\n\x00\x41\x01\x0b\x04hi!\n"));
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
    try mod.compileInstructions(&codeBuffer, &locals, 2);
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
    try mod.compileInstructions(&codeBuffer, &locals, 2);
    try expect(eql(u8, codeBuffer.slice(), &.{ 0x41, 0x00, 0x0b }));
}
