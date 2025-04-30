const std = @import("std");
const eql = std.mem.eql;
const expect = std.testing.expect;
const writeUleb128 = std.leb.writeUleb128;
const writeIleb128 = std.leb.writeIleb128;
const stderr = std.io.getStdIn().writer();
const Inst = @import("inst.zig").Inst;
const instToBytes = @import("inst.zig").instToBytes;
const Scanner = @import("Scanner.zig");
const Buffer = @import("Buffer.zig").Buffer;
const NameMap = @import("maps.zig").NameMap;
const ValueMap = @import("maps.zig").ValueMap;

const Type = enum(u8) {
    func,
    table,
    memory,
    global,
};

const Valtype = enum(u8) {
    i32 = 0x7f,
    i64 = 0x7e,
    f32 = 0x7d,
    f64 = 0x7c,
    v128 = 0x7b,
    funcref = 0x70,
    externref = 0x6f,
};

pub fn compileFuncType(scanner: *Scanner, typeBuffer: anytype, types: anytype) !usize {
    const startLen = typeBuffer.len;
    try typeBuffer.append(0x60);

    switch (try scanner.nextWord()) {
        .word => |prefix| {
            var buffer = Buffer(10).init();
            if (eql(u8, prefix, "param")) {
                try compileTypesUntil(scanner, &buffer, "result");
                if (buffer.len == 0) {
                    return error.ExpectedParamType;
                }
            }
            try typeBuffer.writeUleb128(buffer.len);
            try typeBuffer.appendSlice(buffer.slice());
            buffer.len = 0;
            switch (scanner.word) {
                .word => |result| if (eql(u8, result, "result")) {
                    try compileTypesUntil(scanner, &buffer, null);
                },
                else => {},
            }
            try typeBuffer.writeUleb128(buffer.len);
            try typeBuffer.appendSlice(buffer.slice());
        },
        else => try typeBuffer.appendSlice(&.{ 0x60, 0, 0 }),
    }

    return try types.indexOf(typeBuffer.array[startLen..typeBuffer.len]);
}

pub fn compileTypesUntil(scanner: *Scanner, buffer: anytype, terminal: ?[]const u8) !void {
    while (true) {
        switch (try scanner.nextWord()) {
            .word => |valtypeStr| if (terminal != null and eql(u8, valtypeStr, terminal.?)) {
                break;
            } else if (std.meta.stringToEnum(Valtype, valtypeStr)) |valtype| {
                try buffer.append(@intFromEnum(valtype));
            } else {
                return error.UnknownValtype;
            },
            else => break,
        }
    }
}

pub fn compileImport(scanner: *Scanner, importBuffer: anytype, typeBuffer: anytype, funcNames: anytype, tableNames: anytype, memoryNames: anytype, globalNames: anytype, types: anytype) !void {
    const mod = switch (try scanner.nextWord()) {
        .word => |word| word,
        else => return error.ExpectedModule,
    };

    const name = switch (try scanner.nextWord()) {
        .word => |word| word,
        else => return error.ExpectedName,
    };

    const importTypeStr = switch (try scanner.nextWord()) {
        .word => |word| word,
        else => return error.ExpectedType,
    };

    const importType = std.meta.stringToEnum(Type, importTypeStr) orelse return error.UnknownType;

    const alias = switch (try scanner.nextWord()) {
        .word => |word| word,
        else => return error.ExpectedAlias,
    };

    try importBuffer.writeUleb128(mod.len);
    try importBuffer.appendSlice(mod);
    try importBuffer.writeUleb128(name.len);
    try importBuffer.appendSlice(name);
    try importBuffer.append(@intFromEnum(importType));

    switch (importType) {
        .func => {
            try funcNames.define(alias);
            const index = try compileFuncType(scanner, typeBuffer, types);
            try importBuffer.writeUleb128(index);
        },
        .table => {
            try tableNames.define(alias);
        },
        .memory => {
            try memoryNames.define(alias);
        },
        .global => {
            try globalNames.define(alias);
        },
    }
}

pub fn compileAllImports(scanner: *Scanner, importBuffer: anytype, typeBuffer: anytype, funcNames: anytype, tableNames: anytype, memoryNames: anytype, globalNames: anytype, types: anytype) !void {
    while (true) {
        try compileImport(scanner, importBuffer, typeBuffer, funcNames, tableNames, globalNames, memoryNames, types);
        switch (try scanner.nextWord()) {
            .word => return error.ExpectedEndOfLine,
            .newline => switch (try scanner.nextWord()) {
                .word => |import| if (eql(u8, import, "import")) {
                    continue;
                },
                else => unreachable,
            },
            else => return,
        }
    }
}

test "compile import" {
    var scanner = Scanner.init("import wasi fd_write func hello param i32 i32 f64 funcref result i32 i64\n\nimport");
    var typeBuffer = Buffer(100).init();
    var importBuffer = Buffer(100).init();
    var funcNames = NameMap(10).init();
    var tableNames = NameMap(10).init();
    var globalNames = NameMap(10).init();
    var memoryNames = NameMap(10).init();
    var types = ValueMap(10).init();
    try expect(eql(u8, (try scanner.nextWord()).word, "import"));
    compileAllImports(&scanner, &importBuffer, &typeBuffer, &funcNames, &tableNames, &globalNames, &memoryNames, &types) catch |err| {
        try displayError(&scanner, stderr, "filename", @errorName(err));
    };
}

pub fn displayError(scanner: *Scanner, writer: anytype, filename: []const u8, message: []const u8) !void {
    const startIndex = scanner.start;
    const endIndex = scanner.index;

    scanner.skipBackwardUntil("\n");
    const lineStart = scanner.index;
    scanner.skipUntil("\n");
    const lineEnd = scanner.index;
    const start = startIndex - lineStart;
    const end = endIndex - lineStart;

    const line = std.mem.count(u8, scanner.source[0..lineStart], "\n");

    try writer.print("\n\x1b[1;37m{s}:{d}:{d}\x1b[0m \x1b[1;31m{s}\x1b[0m\n{s}\x1b[1;32m\n", .{ filename, line, start, message, scanner.source[lineStart..lineEnd] });
    for (0..@max(start + 1, end)) |i| {
        if (i < start) {
            try writer.writeByte(' ');
        } else if (i == start or start == end) {
            try writer.writeByte('^');
        } else {
            try writer.writeByte('~');
        }
    }
    try writer.print("\x1b[0m\n\n", .{});
}

// const ParsingStrategy = enum {
//     byte,
//     v128,
//     memarg,
//     i32,
//     i64,
//     f32,
//     f64,
//     memoryIndex,
//     dataIndex,
//     elemIndex,
//     tableIndex,
//     globalIndex,
//     localIndex,
//     labelIndex,
//     br_table,
//     paramType,
//     resultType,
// };
//
// pub fn instParsingStrategy(inst: Inst) []const ParsingStrategy {
//     return switch (inst) {
//         .@"call_indirect name" => &.{ .paramType, .resultType },
//         .br_table, &.{.br_table}, .br_if, .br => &.{.labelIndex},
//         .@"ref.null" => &.{.reftype},
//         .call, .@"ref.func" => &.{.funcIndex},
//         .@"if", .block, .loop, .select => &.{.resultType},
//         .@"local.get", .@"local.set", .@"local.tee" => &.{.localIndex},
//         .@"global.get", .@"global.set" => &.{.globalIndex},
//         .@"table.get", .@"table.set", .@"table.drop", .@"table.grow", .@"table.size", .@"table.fill" => &.{.tableIndex},
//         .@"table.copy" => &.{ .tableIndex, .tableIndex },
//         .@"table.init" => &.{ .elemIndex, .tableIndex },
//         .@"data.drop" => &.{.dataIndex},
//         .@"memory.init" => &.{ .dataIndex, .memoryIndex },
//         .@"memory.size", .@"memory.grow", .@"memory.copy", .@"memory.fill" => &.{.memoryIndex},
//         .@"i32.const" => &.{.i32},
//         .@"i64.const" => &.{.i64},
//         .@"f32.const" => &.{.f32},
//         .@"f64.const" => &.{.f64},
//         .@"i32.load", .@"i64.load", .@"f32.load", .@"f64.load", .@"i32.load8_s", .@"i32.load8_u", .@"i32.load16_s", .@"i32.load16_u", .@"i64.load8_s", .@"i64.load8_u", .@"i64.load16_s", .@"i64.load16_u", .@"i64.load32_s", .@"i64.load32_u", .@"i32.store", .@"i64.store", .@"f32.store", .@"f64.store", .@"i32.store8", .@"i32.store16", .@"i64.store8", .@"i64.store16", .@"i64.store32", .@"128.load", .@"128.load8x8_s", .@"128.load8x8_u", .@"128.load16x4_s", .@"128.load16x4_u", .@"128.load32x2_s", .@"128.load32x2_u", .@"128.load8_splat", .@"128.load16_splat", .@"128.load32_splat", .@"128.load64_splat", .@"128.load32_zero", .@"128.load64_zero", .@"128.store" => &.{.memarg},
//         .@"v128.load8_lane", .@"v128.load16_lane", .@"v128.load32_lane", .@"v128.load64_lane", .@"v128.store8_lane", .@"v128.store16_lane", .@"v128.store32_lane", .@"v128.store64_lane" => &.{ .byte, .memarg },
//         .@"v128.const" => &.{.v128},
//         .@"i8x16.shuffle" => &(.{.byte} ** 16),
//         .@"i8x16.extract_lane_s", .@"i8x16.extract_lane_u", .@"i8x16.replace_lane", .@"i16x8.extract_lane_s", .@"i16x8.extract_lane_u", .@"i16x8.replace_lane", .@"i32x4.extract_lane", .@"i32x4.replace_lane", .@"i64x2.extract_lane", .@"i64x2.replace_lane", .@"f32x4.extract_lane", .@"f32x4.replace_lane", .@"f64x2.extract_lane", .@"f64x2.replace_lane" => &.{.byte},
//         else => &.{},
//     };
// }

// pub fn compileParsingStrategy(strategy: ParsingStrategy, output: anytype) !void {}

// const Prefix = enum(u8) {
//     import = 2,
//     @"export" = 7,
//     memory = 5,
//     table = 4,
//     elem = 9,
//     global = 6,
//     data = 11,
//     func = 10,
// };
//
//

// pub fn compileFuncType(scanner: *Scanner, output: anytype, locals: anytype) !void {
//     try output.append(0x60);
//     try compilePrefixedTypeList(scanner, output, "param", locals, "result");
//     try compilePrefixedTypeList(scanner, output, "result", locals, null);
// }
//
// pub fn compilePrefixedTypeList(scanner: *Scanner, output: anytype, prefix: []const u8, locals: anytype, end: ?[]const u8) !void {
//     if (scanner.next) |first| {
//         if (std.mem.eql(u8, prefix, first)) {
//             try compileTypeList(scanner, output, locals, end);
//         } else {
//             try output.append(0);
//         }
//     }
// }
//
// pub fn compileNamedParams(scanner: *Scanner, output: anytype, locals: anytype) !void {
//     var bufferBytes = WasmBytes(16).init();
//     while (try scanner.advance()) |next| {
//         if (std.mem.eql(u8, next, "result")) {
//             break;
//         } else {
//
//         }
//     }
// }
//
// pub fn compileTypeList(scanner: *Scanner, output: anytype, locals: anytype, end: ?[]const u8) !void {
//     var bufferBytes = WasmBytes(16).init();
//     while (try scanner.advance()) |next| {
//         if (end) |endStr| {
//             if (std.mem.eql(u8, next, endStr)) {
//                 break;
//             }
//         }
//         if (locals) |localMap| {
//             try localMap.append(next);
//             _ = try scanner.advance();
//         }
//         if (scanner.next) |next2| {
//             if (std.meta.stringToEnum(Type, next2)) |@"type"| {
//                 try bufferBytes.append(@intFromEnum(@"type"));
//             } else {
//                 break;
//             }
//         } else {
//             return error.ExpectedType;
//         }
//     }
//     if (bufferBytes.len == 0) {
//         return error.ExpectedType;
//     }
//     try output.writeUnsigned(bufferBytes.len);
//     try output.appendSlice(bufferBytes.slice());
// }
//
// pub fn WasmBytes(comptime N: usize) type {
//     return struct {
//         items: [N]u8,
//         len: usize,
//
//         pub fn init() @This() {
//             return .{
//                 .items = undefined,
//                 .len = 0,
//             };
//         }
//
//         pub fn append(self: *@This(), byte: u8) !void {
//             if (self.len < N) {
//                 self.items[self.len] = byte;
//                 self.len += 1;
//             } else {
//                 return error.OutOfBounds;
//             }
//         }
//
//         pub fn appendSlice(self: *@This(), sliceToAppend: []u8) !void {
//             if (self.len + sliceToAppend.len < N) {
//                 @memcpy(self.items[self.len .. self.len + sliceToAppend.len], sliceToAppend);
//             } else {
//                 return error.OutOfBounds;
//             }
//         }
//
//         pub fn slice(self: @This()) []u8 {
//             self.items[0..self.len];
//         }
//
//         pub fn writeUnsigned(self: *@This(), number: anytype) !void {
//             var val = number;
//             while (true) {
//                 var byte: u8 = @intCast(val & 0x7F);
//                 val >>= 7;
//                 if (val != 0) {
//                     byte |= 0x80;
//                 }
//                 try self.append(byte);
//                 if (val == 0) break;
//             }
//         }
//
//         pub fn writeVector(self: *@This(), content: []u8, count: ?usize) !void {
//             try self.writeUnsigned(if (count) |c| c else content.len);
//             try self.appendSlice(content);
//         }
//
//         pub fn writeSection(self: *@This(), content: []u8, sectionId: u8) !void {
//             try self.append(sectionId);
//             try self.writeVector(content);
//         }
//     };
// }
//
// pub fn BytesMap(comptime N: usize) type {
//     return struct {
//         items: [N][]u8,
//         len: usize,
//
//         pub fn init() @This() {
//             return .{
//                 .items = undefined,
//                 .len = 0,
//             };
//         }
//
//         pub fn append(self: *@This(), bytes: []u8) !void {
//             if (self.len < N) {
//                 self.items[self.len] = bytes;
//                 self.len += 1;
//             } else {
//                 return error.OutOfBounds;
//             }
//         }
//
//         pub fn getIndex(self: @This(), bytes: []u8) ?usize {
//             for (self.items, 0..) |item, index| {
//                 if (std.mem.eql(u8, bytes, item)) {
//                     return index;
//                 }
//             }
//             return null;
//         }
//
//         pub fn getName(self: @This(), index: usize) ?[]u8 {
//             if (index < self.len) {
//                 return self.items[index];
//             } else {
//                 return null;
//             }
//         }
//
//         pub fn getIndexOrAppend(self: *@This(), bytes: []u8) !usize {
//             if (self.getIndex(bytes)) |index| {
//                 return index;
//             } else {
//                 try self.append(bytes);
//                 return self.len - 1;
//             }
//         }
//     };
// }

// pub fn compileSectionBody(scanner: *Scanner, prefix: Prefix, funcTypes: anytype) !WasmBytes {
//     var output = WasmBytes(1000).init();
//     var count: usize = 0;
//     switch (prefix) {
//         .func => unreachable,
//         else => {
//             compileLine(scanner, prefix, &output);
//             count += 1;
//         },
//     }
//     var buffer = WasmBytes(1000).init();
//     try buffer.writeUnsigned(count);
//     try buffer.appendSlice(output.slice());
//     return buffer;
// }
//
// pub fn compileEndInstructions(scanner: *Scanner, currentIndentation: usize, output: anytype) !usize {
//     const indentStr = scanner.advance();
//     if (!std.mem.startsWith(u8, indentStr, "\n")) {
//         return error.ExpectedNewline;
//     }
//     if (std.mem.count(u8, indentStr, "\n") != 1) {
//         return error.TooManyNewlines;
//     }
//     const indentation = indentStr.len - 1;
//     if (indentation > currentIndentation) {
//         if (indentation - currentIndenation != 2) {
//             return error.ExpectedTwoSpacesAsIndentation;
//         }
//         return 0;
//     } else {
//         if (indentation % 2 != 0) {
//             return error.ExpectedTwoSpacesAsIndentation;
//         }
//         for (0..(currentIndentation - indentation) / 2) |_| {
//             try output.append(instToBytes(.end));
//         }
//         return indentation;
//     }
// }
//
// pub fn compileInstruction(scanner: *Scanner, output: anytype) !void {
//     const instStr = scanner.advance();
//     if (std.meta.stringToEnum(Inst, instStr)) |inst| {
//         try output.appendSlice(instToBytes(inst));
//         scanner.advance();
//         for (instParsingStrategy(inst)) |startegy| {
//             try compileParsingStrategy(scanner, output, startegy);
//         }
//     } else {
//         return error.UnknownInstruction;
//     }
// }
//
// pub fn compileLine(scanner: *Scanner, prefix: Prefix, output: anytype) !void {}
//
// pub fn compileCoreModule(scanner: *Scanner, output: anytype) !void {
//     scanner.advance();
//
//     var types = BytesMap(10).init();
//     var funcs = BytesMap(10).init();
//     var imports = BytesMap(10).init();
//     var memories = BytesMap(10).init();
//     var importBytes = WasmBytes(100).init();
//     var exportBytes = WasmBytes(100).init();
//     var memoryBytes = WasmBytes(100).init();
//     var exports: usize = 0;
//
//     while (scanner.next) |next| : (scanner.advance()) {
//         if (std.mem.startsWith(u8, next, "//")) {
//             scanner.skipUntil("\r\n");
//             continue;
//         }
//         if (std.meta.stringToEnum(Prefix, scanner.next)) |prefix| {
//             switch (prefix) {
//                 .import => {
//                     const module = scanner.advance() orelse return error.MissingModuleName;
//                     const item = scanner.advance() orelse return error.MissingName;
//                     const as = scanner.advance() orelse return error.MissingKeywordAs;
//                     if (!std.mem.eql(u8, "as", as)) {
//                         return error.ExpectedKeywordAs;
//                     }
//                     const importTypeStr = scanner.advance() orelse return error.MissingImportType;
//
//                     if (std.meta.stringToEnum(ImportType, importTypeStr)) |importType| {
//                         const name = scanner.advance() orelse return error.MissingName;
//                         try importBytes.writeVec(module);
//                         try importBytes.writeVec(item);
//                         try importBytes.append(@intFromEnum(importType));
//
//                         _ = try funcs.getIndexOrAppend(name);
//
//                         switch (importType) {
//                             .func => {
//                                 var typeBuf = WasmBytes(10).init();
//                                 try compileFuncType(&scanner, &typeBuf);
//                                 const index = try types.getIndexOrAppend(typeBuf.slice());
//                                 try importBytes.writeUnsigned(index);
//                             },
//                             else => unreachable,
//                         }
//                         try imports.append(name);
//                     } else {
//                         return error.UnknownType;
//                     }
//                 },
//                 .@"export" => {
//                     const alias = scanner.advance() catch {
//                         return error.MissingAlias;
//                     };
//                     const with = scanner.advance() catch {
//                         return error.MissingKeywordWith;
//                     };
//                     if (!std.mem.eql(u8, "with", with)) {
//                         return error.ExpectedKeywordWith;
//                     }
//                     const exportTypeStr = scanner.advance() catch {
//                         return error.MissingExportType;
//                     };
//
//                     if (std.meta.stringToEnum(ImportType, exportTypeStr)) |exportType| {
//                         const name = scanner.advance() catch {
//                             return error.MissingName;
//                         };
//                         try exportBytes.writeVec(alias);
//
//                         const idx = switch (@"type") {
//                             .func => try func.getIndexOrAppend(name),
//                             .memory => try memories.getIndexOrAppend(name),
//                             .global => try globals.getIndexOrAppend(name),
//                             .table => try tables.getIndexOrAppend(name),
//                             else => unreachable,
//                         };
//                         try exportBytes.append(@intFromEnum(exportType));
//                         try exportBytes.writeUnsigned(idx);
//                         exports += 1;
//                     } else {
//                         return CompilerError.UnknownExportType;
//                     }
//                 },
//                 .memory => {
//                     const name = nextWord(source, index, ' ', '\n') catch |err| switch (err) {
//                         error.TooManySeparators => return CompilerError.TooManySpaces,
//                         error.BannedChar => return CompilerError.MissingMemoryName,
//                     };
//
//                     const minStr = nextWord(source, index, ' ', '\n') catch |err| switch (err) {
//                         error.TooManySeparators => return CompilerError.TooManySpaces,
//                         error.BannedChar => return CompilerError.MissingMinPageCount,
//                     };
//
//                     const min = std.fmt.parseInt(usize, minStr, 10) catch {
//                         return CompilerError.ExpectedMinPageCountToBePositiveInteger;
//                     };
//
//                     const maxStr: ?[]u8 = nextWord(source, index, ' ', '\n') catch |err| switch (err) {
//                         error.TooManySeparators => return CompilerError.TooManySpaces,
//                         error.BannedChar => null,
//                     };
//
//                     if (maxStr) |maxStr_| {
//                         const max = std.fmt.parseInt(usize, maxStr_, 10) catch {
//                             return CompilerError.ExpectedMaxPageCountToBePositiveInteger;
//                         };
//
//                         try memory.append(1);
//                         try std.leb.writeUleb128(memory.writer(), min);
//                         try std.leb.writeUleb128(memory.writer(), max);
//                     } else {
//                         try memory.append(0);
//                         try std.leb.writeUleb128(memory.writer(), min);
//                     }
//                     _ = try findOrAppend(&memories, name);
//                 },
//                 else => unreachable,
//             }
//         } else {
//             return error.UnknownPrefix;
//         }
//         if (std.meta.stringToEnum(Declaration, declarationSlice)) |declaration| {
//             const declarationInt = @intFromEnum(declaration);
//             if (declarationInt > maxDeclaration) {
//                 return CompilerError.DeclarationCannotChange;
//             }
//             if (declarationInt < minDeclaration) {
//                 return CompilerError.DeclarationIsTooLate;
//             }
//             switch (declaration) {}
//
//             switch (skip(source, index, ' ')) {
//                 .No, .EndOfFile => {},
//                 else => return CompilerError.SpaceAtTheEndOfALine,
//             }
//             switch (skip(source, index, '\n')) {
//                 .No => return CompilerError.ExpectedEndOfLine,
//                 .One => maxDeclaration = minDeclaration,
//                 .Two, .EndOfFile => {
//                     minDeclaration += 1;
//                     maxDeclaration = 12;
//                 },
//                 .TooMany => return CompilerError.TooManyNewlines,
//             }
//         } else {
//             index.* = startIndex;
//             return CompilerError.UnknownDeclaration;
//         }
//     }
//     var typeSec = try std.BoundedArray(u8, 0x100).init(0);
//     for (types.slice()) |@"type"| {
//         try typeSec.appendSlice(@"type");
//     }
//     try writeSection(writer, types.len, typeSec.slice(), 1);
//     try writeSection(writer, imports.len, import.slice(), 2);
//     try writeSection(writer, memories.len, memory.slice(), 5);
//     try writeSection(writer, exports, @"export".slice(), 7);
// }
//
// pub fn main() !void {
//     const stdin = std.io.getStdIn().reader();
//     const stdout = std.io.getStdOut().writer();
//     const stderr = std.io.getStdErr().writer();
//
//     var buffer: [max_source_len]u8 = undefined;
//     const source = buffer[0..try stdin.readAll(&buffer)];
//
//     var scanner = Scanner.init(source);
//     var wasmBytes = WasmBytes(1000).init();
//     compileCoreModule(&scanner, &wasmBytes) catch |err| {
//         const start, const end = sourceLine(source, scanner.start);
//         const line = std.mem.count(u8, source[0..start], "\n");
//         const column = scanner.start - start;
//         try writeError(stderr, @errorName(err), "stdin", line, column, source[start..end], scanner.start - start, scanner.index - start);
//     };
//     try stdout.print("{x}\n", .{wasmBytes.slice()});
// }

// test "Compile Func Type" {
//     const source = "param i32 i32 i32 result i32 i32";
//     var scanner = Scanner.init(source);
//     var out = WasmBytes(100).init();
//     var locals = BytesMap(100).init();
//     try compileFuncType(&scanner, &out, null);
//     try compileFuncType(&scanner, &out, &locals);
// }
//
// test "Compile" {
//     const source = "func hello param x i32 y i32 z i32 result i32 result i32";
//     var scanner = Scanner.init(source);
//     var out = WasmBytes(100).init();
//     var locals = BytesMap(100).init();
// }
