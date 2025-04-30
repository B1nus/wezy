const std = @import("std");
const max_core_module_len: usize = 0x100;
const max_source_len: usize = 0x100;

const Declaration = enum {
    import,
    @"export",
    memory,
    table,
    elem,
    global,
    data,
    func,
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

const ImportType = enum {
    func,
    table,
    memory,
    global,
};

const CompilerError = error{
    MissingDeclaration,
    UnknownDeclaration,
    EmptyImportDeclaration,
    MissingImportModName,
    MissingImportItemName,
    MissingImportAsKeyword,
    MissingImportType,
    UnknownImportType,
    ExpectedImportAsKeyword,
    MissingImportName,
    TooManySpaces,
    DeclarationIsTooLate,
    DeclarationCannotChange,
    ExpectedEndOfLine,
    TooManyNewlines,
    ExpectedKeywordParamOrResult,
    ExpectedKeywordResult,
    UnknownValtype,
    ExpectedAParamType,
    ExpectedAResultType,
    SpaceAtTheEndOfALine,
    MissingExportedName,
    MissingExportWithKeyword,
    ExpectedExportWithKeyword,
    MissingExportType,
    MissingExportName,
    UnknownExportType,
    MissingMemoryName,
    MissingMinPageCount,
    ExpectedMinPageCountToBePositiveInteger,
    ExpectedMaxPageCountToBePositiveInteger,
};

pub fn nextWord(source: []u8, index: *usize, target: u8, banned: ?u8) ![]u8 {
    const startIndex = index.*;
    if (source[index.*] == banned) {
        return error.BannedChar;
    }
    while (index.* < source.len and source[index.*] != target and source[index.*] != banned) : (index.* += 1) {}
    const word = source[startIndex..index.*];

    switch (skip(source, index, target)) {
        .No,
        .One,
        .EndOfFile,
        => return word,
        else => return error.TooManySeparators,
    }
}

const Skip = enum {
    No,
    One,
    Two,
    TooMany,
    EndOfFile,
};

pub fn skip(source: []u8, index: *usize, target: u8) Skip {
    const startIndex = index.*;
    while (index.* < source.len and source[index.*] == target) : (index.* += 1) {}
    if (index.* >= source.len) {
        return .EndOfFile;
    }
    return switch (index.* - startIndex) {
        0 => .No,
        1 => .One,
        2 => .Two,
        else => .TooMany,
    };
}

pub fn parseFuncType(source: []u8, index: *usize, typeWriter: anytype) !void {
    try typeWriter.writeByte(0x60);
    if (index.* >= source.len or source[index.*] == '\n') {} else {
        const word = nextWord(source, index, ' ', '\n') catch |err| switch (err) {
            error.TooManySeparators => return CompilerError.TooManySpaces,
            error.BannedChar => {
                try typeWriter.writeByte(0);
                try typeWriter.writeByte(0);
                return;
            },
        };
        if (std.mem.eql(u8, "param", word)) {
            var paramBuf = try std.BoundedArray(u8, 0x10).init(0);
            if (parseTypeList(source, index, paramBuf.writer()) catch |err| switch (err) {
                error.ExpectedValtype => return CompilerError.ExpectedAParamType,
                else => return err,
            }) |word2| {
                try std.leb.writeUleb128(typeWriter, paramBuf.len);
                try typeWriter.writeAll(paramBuf.slice());
                if (std.mem.eql(u8, "result", word2)) {
                    var resultBuf = try std.BoundedArray(u8, 0x10).init(0);
                    if (parseTypeList(source, index, resultBuf.writer()) catch |err| switch (err) {
                        error.ExpectedValtype => return CompilerError.ExpectedAResultType,
                        else => return err,
                    }) |_| {
                        return CompilerError.ExpectedEndOfLine;
                    } else {
                        try std.leb.writeUleb128(typeWriter, resultBuf.len);
                        try typeWriter.writeAll(resultBuf.slice());
                    }
                } else {
                    return CompilerError.ExpectedKeywordResult;
                }
            }
        } else if (std.mem.eql(u8, "result", word)) {
            var resultBuf = try std.BoundedArray(u8, 0x10).init(0);
            if (parseTypeList(source, index, resultBuf.writer()) catch |err| switch (err) {
                error.ExpectedValtype => return CompilerError.ExpectedAResultType,
                else => return err,
            }) |_| {
                return CompilerError.ExpectedEndOfLine;
            } else {
                try std.leb.writeUleb128(typeWriter, resultBuf.len);
                try typeWriter.writeAll(resultBuf.slice());
            }
        } else {
            return CompilerError.ExpectedKeywordParamOrResult;
        }
    }
}

pub fn parseTypeList(source: []u8, index: *usize, writer: anytype) !?[]u8 {
    var word = nextWord(source, index, ' ', '\n') catch |err| switch (err) {
        error.TooManySeparators => return CompilerError.TooManySpaces,
        error.BannedChar => {
            return error.ExpectedValtype;
        },
    };
    while (std.meta.stringToEnum(Valtype, word)) |valtype| {
        try writer.writeByte(@intFromEnum(valtype));
        word = nextWord(source, index, ' ', '\n') catch |err| switch (err) {
            error.TooManySeparators => return CompilerError.TooManySpaces,
            error.BannedChar => return null,
        };
    }
    return word;
}

pub fn findOrAppend(list: anytype, item: []u8) !usize {
    for (list.slice(), 0..) |cur, index| {
        if (std.mem.eql(u8, cur, item)) {
            return index;
        }
    }
    try list.append(item);
    return list.len - 1;
}

pub fn writeSection(writer: anytype, count: usize, content: []u8, sectionCode: u8) !void {
    try writer.writeByte(sectionCode);
    var countBuf = try std.BoundedArray(u8, 4).init(0);
    var sizeBuf = try std.BoundedArray(u8, 4).init(0);
    try std.leb.writeUleb128(countBuf.writer(), count);
    try std.leb.writeUleb128(sizeBuf.writer(), content.len + countBuf.len);
    try writer.writeAll(sizeBuf.slice());
    try writer.writeAll(countBuf.slice());
    try writer.writeAll(content);
}

pub fn compileCoreModule(source: []u8, index: *usize, writer: anytype) !void {
    var minDeclaration: usize = 0;
    var maxDeclaration: usize = 12;

    var types = try std.BoundedArray([]u8, 0x100).init(0);
    var funcs = try std.BoundedArray([]u8, 0x100).init(0);
    var imports = try std.BoundedArray([]u8, 0x100).init(0);
    var import = try std.BoundedArray(u8, 0x100).init(0);
    var exports: usize = 0;
    var @"export" = try std.BoundedArray(u8, 0x100).init(0);
    var memory = try std.BoundedArray(u8, 0x100).init(0);
    var memories = try std.BoundedArray([]u8, 0x100).init(0);

    while (index.* < source.len) {
        const startIndex = index.*;
        if (source.len > index.* + 2 and std.mem.eql(u8, source[index.*..index.*+2], "//")) {
            if (std.mem.indexOfScalarPos(u8, source, index.*, '\n')) |i| {
                index.* = i;
                _ = skip(source, index, ' ');
                _ = skip(source, index, '\n');
                continue;
            } else {
                break;
            }
        }
        const declarationSlice = nextWord(source, index, ' ', '\n') catch |err| switch (err) {
            error.TooManySeparators => return CompilerError.TooManySpaces,
            error.BannedChar => return CompilerError.MissingDeclaration,
        };
        if (std.meta.stringToEnum(Declaration, declarationSlice)) |declaration| {
            const declarationInt = @intFromEnum(declaration);
            if (declarationInt > maxDeclaration) {
                return CompilerError.DeclarationCannotChange;
            }
            if (declarationInt < minDeclaration) {
                return CompilerError.DeclarationIsTooLate;
            }
            switch (declaration) {
                .import => {
                    const modName = nextWord(source, index, ' ', '\n') catch |err| switch (err) {
                        error.TooManySeparators => return CompilerError.TooManySpaces,
                        error.BannedChar => return CompilerError.MissingImportModName,
                    };
                    const itemName = nextWord(source, index, ' ', '\n') catch |err| switch (err) {
                        error.TooManySeparators => return CompilerError.TooManySpaces,
                        error.BannedChar => return CompilerError.MissingImportItemName,
                    };
                    const as = nextWord(source, index, ' ', '\n') catch |err| switch (err) {
                        error.TooManySeparators => return CompilerError.TooManySpaces,
                        error.BannedChar => return CompilerError.MissingImportAsKeyword,
                    };
                    if (!std.mem.eql(u8, "as", as)) {
                        return CompilerError.ExpectedImportAsKeyword;
                    }
                    const typeStr = nextWord(source, index, ' ', '\n') catch |err| switch (err) {
                        error.TooManySeparators => return CompilerError.TooManySpaces,
                        error.BannedChar => return CompilerError.MissingImportType,
                    };
                    if (std.meta.stringToEnum(ImportType, typeStr)) |@"type"| {
                        const name = nextWord(source, index, ' ', '\n') catch |err| switch (err) {
                            error.TooManySeparators => return CompilerError.TooManySpaces,
                            error.BannedChar => return CompilerError.MissingImportName,
                        };
                        try std.leb.writeUleb128(import.writer(), modName.len);
                        try import.writer().writeAll(modName);
                        try std.leb.writeUleb128(import.writer(), itemName.len);
                        try import.writer().writeAll(itemName);
                        try import.writer().writeByte(@intCast(@intFromEnum(@"type")));

                        _ = try findOrAppend(&funcs, name);

                        switch (@"type") {
                            .func => {
                                var typeBuf = try std.BoundedArray(u8, 0x10).init(0);
                                try parseFuncType(source, index, typeBuf.writer());
                                const typeIdx = try findOrAppend(&types, typeBuf.slice());
                                try std.leb.writeUleb128(import.writer(), typeIdx);
                            },
                            else => unreachable,
                        }
                        try imports.append(name);
                    } else {
                        return CompilerError.UnknownImportType;
                    }
                },
                .@"export" => {
                    const exportedName = nextWord(source, index, ' ', '\n') catch |err| switch (err) {
                        error.TooManySeparators => return CompilerError.TooManySpaces,
                        error.BannedChar => return CompilerError.MissingExportedName,
                    };
                    const with = nextWord(source, index, ' ', '\n') catch |err| switch (err) {
                        error.TooManySeparators => return CompilerError.TooManySpaces,
                        error.BannedChar => return CompilerError.MissingExportWithKeyword,
                    };
                    if (!std.mem.eql(u8, "with", with)) {
                        return CompilerError.ExpectedExportWithKeyword;
                    }
                    const typeStr = nextWord(source, index, ' ', '\n') catch |err| switch (err) {
                        error.TooManySeparators => return CompilerError.TooManySpaces,
                        error.BannedChar => return CompilerError.MissingExportType,
                    };
                    if (std.meta.stringToEnum(ImportType, typeStr)) |@"type"| {
                        const name = nextWord(source, index, ' ', '\n') catch |err| switch (err) {
                            error.TooManySeparators => return CompilerError.TooManySpaces,
                            error.BannedChar => return CompilerError.MissingExportName,
                        };
                        try std.leb.writeUleb128(@"export".writer(), exportedName.len);
                        try @"export".writer().writeAll(exportedName);

                        const idx = switch (@"type") {
                            .func => try findOrAppend(&funcs, name),
                            .memory => try findOrAppend(&memories, name),
                            else => unreachable,
                        };
                        try @"export".writer().writeByte(@intCast(@intFromEnum(@"type")));
                        try std.leb.writeUleb128(@"export".writer(), idx);
                        exports += 1;
                    } else {
                        return CompilerError.UnknownExportType;
                    }
                },
                .memory => {
                    const name = nextWord(source, index, ' ', '\n') catch |err| switch (err) {
                        error.TooManySeparators => return CompilerError.TooManySpaces,
                        error.BannedChar => return CompilerError.MissingMemoryName,
                    };

                    const minStr = nextWord(source, index, ' ', '\n') catch |err| switch (err) {
                        error.TooManySeparators => return CompilerError.TooManySpaces,
                        error.BannedChar => return CompilerError.MissingMinPageCount,
                    };

                    const min = std.fmt.parseInt(usize, minStr, 10) catch {
                        return CompilerError.ExpectedMinPageCountToBePositiveInteger;
                    };

                    const maxStr: ?[]u8 = nextWord(source, index, ' ', '\n') catch |err| switch (err) {
                        error.TooManySeparators => return CompilerError.TooManySpaces,
                        error.BannedChar => null,
                    };

                    if (maxStr) |maxStr_| {
                        const max = std.fmt.parseInt(usize, maxStr_, 10) catch {
                            return CompilerError.ExpectedMaxPageCountToBePositiveInteger;
                        };

                        try memory.append(1);
                        try std.leb.writeUleb128(memory.writer(), min);
                        try std.leb.writeUleb128(memory.writer(), max);
                    } else {
                        try memory.append(0);
                        try std.leb.writeUleb128(memory.writer(), min);
                    }
                    _ = try findOrAppend(&memories, name);
                },
                else => unreachable,
            }

            switch (skip(source, index, ' ')) {
                .No, .EndOfFile => {},
                else => return CompilerError.SpaceAtTheEndOfALine,
            }
            switch (skip(source, index, '\n')) {
                .No => return CompilerError.ExpectedEndOfLine,
                .One => maxDeclaration = minDeclaration,
                .Two, .EndOfFile => {
                    minDeclaration += 1;
                    maxDeclaration = 12;
                },
                .TooMany => return CompilerError.TooManyNewlines,
            }
        } else {
            index.* = startIndex;
            return CompilerError.UnknownDeclaration;
        }
    }
    var typeSec = try std.BoundedArray(u8, 0x100).init(0);
    for (types.slice()) |@"type"| {
        try typeSec.appendSlice(@"type");
    }
    try writeSection(writer, types.len, typeSec.slice(), 1);
    try writeSection(writer, imports.len, import.slice(), 2);
    try writeSection(writer, memories.len, memory.slice(), 5);
    try writeSection(writer, exports, @"export".slice(), 7);
}

pub fn readFile(reader: anytype, buffer: []u8) ![]u8 {
    return buffer[0..try reader.readAll(buffer)];
}

pub fn indexOfBackwards(haystack: []u8, needle: u8) ?usize {
    if (haystack.len == 0) {
        return null;
    }
    var index: usize = haystack.len - 1;
    while (index > 0 and haystack[index] != needle) : (index -= 1) {}
    return if (index > 0) index else null;
}

pub fn main() !void {
    var buffer: [max_source_len]u8 = undefined;
    const source = try readFile(std.io.getStdIn().reader(), &buffer);

    var index: usize = 0;
    const writer = std.io.getStdOut().writer();
    try writer.writeAll(&.{ 0, 'a', 's', 'm', 1, 0, 0, 0 });
    const errWriter = std.io.getStdErr().writer();
    compileCoreModule(source, &index, writer) catch |err| {
        const startIndex = if (indexOfBackwards(source[0..index], '\n')) |i| i + 1 else 0;
        const endIndex = std.mem.indexOfScalarPos(u8, source, index, '\n') orelse source.len;
        const line = std.mem.count(u8, source[0..index], "\n");
        const column = index - startIndex;
        try errWriter.print("\x1b[1;31m{s}\x1b[0m at line \x1b[1;37m{d}\x1b[0m column \x1b[1;37m{d}\x1b[0m\n{s}\n", .{ @errorName(err), line + 1, column + 1, source[startIndex..endIndex] });
        for (0..column) |_| {
            try errWriter.writeByte(' ');
        }
        try errWriter.writeAll("\x1b[1;32m^");
        if (index < endIndex) {
            for (0..endIndex - index - 1) |_| {
                try errWriter.writeAll("~");
            }
        }
        try errWriter.writeAll("\x1b[0m\n");
    };
}
