const std = @import("std");
const max_core_module_len: usize = 0x100;
const max_source_len: usize = 0x100;

const Declaration = enum {
    import,
    @"export",
    memory,
    @"type",
    table,
    elem,
    global,
    data,
    func,
};

const ValType = enum(u8) {
    @"i32" = 0x7f,
    @"i64" = 0x7e,
    @"f32" = 0x7d,
    @"f64" = 0x7c,
    @"v128" = 0x7b,
    @"funcref" = 0x70,
    @"externref" = 0x6f,
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
    ExpectedEndOfDeclaration,
    TooManyNewlines,
    ExpectedKeywordParamOrResult,
    UnknownValType,
    ExepctedAParameterType,
    ExpectedAResultType,
    SpaceAtTheEndOfALine,
};

pub fn nextWord(source: []u8, index: *usize, target: u8, banned: ?u8) ![]u8 {
    const startIndex = index.*;
    if (banned != null and source[index.*] == banned) {
        return error.BannedChar;
    }
    while (index.* < source.len and source[index.*] != target) : (index.* += 1) { }
    const word = source[startIndex..index.*];

    switch (skip(source, index, target)) {
        .One, .EndOfFile, => return word,
        .No => unreachable,
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

pub fn parseFuncType(_: []u8, _: *usize, typeWriter: anytype) !void {
    try typeWriter.writeByte(0x60);
    try typeWriter.writeByte(0);
    try typeWriter.writeByte(0);
}

pub fn findOrAppendType(types: anytype, @"type": []u8) !usize {
    for (types.slice(), 0..) |curType, index| {
        if (std.mem.eql(u8, curType, @"type")) {
            return index;
        }
    }
    try types.append(@"type");
    return types.len - 1;
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
    var imports = try std.BoundedArray([]u8, 0x100).init(0);
    var import = try std.BoundedArray(u8, 0x100).init(0);

    while (index.* < source.len) : (index.* += 1) {
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

                        switch (@"type") {
                            .func => {
                                var typeBuf = try std.BoundedArray(u8, 0x10).init(0);
                                try parseFuncType(source, index, typeBuf.writer());
                                const typeIdx = try findOrAppendType(&types, typeBuf.slice());
                                try std.leb.writeUleb128(import.writer(), typeIdx);
                            },
                            else => unreachable,
                        }
                        try imports.append(name);
                    } else {
                        return CompilerError.UnknownImportType;
                    }
                },
                else => unreachable,
            }

            switch(skip(source, index, ' ')) {
                .No, .EndOfFile => {},
                else => return CompilerError.SpaceAtTheEndOfALine,
            }
            switch(skip(source, index, '\n')) {
                .No => return CompilerError.ExpectedEndOfDeclaration,
                .One => maxDeclaration = minDeclaration,
                .Two, .EndOfFile => {
                    minDeclaration += 1;
                    maxDeclaration = 12;
                },
                .TooMany => return CompilerError.TooManyNewlines,
            }
        } else {
            return CompilerError.UnknownDeclaration;
        }
    }
    var typeSec = try std.BoundedArray(u8, 0x100).init(0);
    for (types.slice()) |@"type"| {
        try typeSec.appendSlice(@"type");
    }
    try writeSection(writer, types.len, typeSec.slice(), 1);
    try writeSection(writer, imports.len, import.slice(), 2);
}

pub fn readFile(reader: anytype, buffer: []u8) ![]u8 {
    return buffer[0..try reader.readAll(buffer)];
}

pub fn indexOfBackwards(haystack: []u8, needle: u8) ?usize {
    var index: usize = haystack.len - 1;
    while (index > 0 and haystack[index] != needle) : (index -= 1) {}
    return if (index > 0) index else null;
}

pub fn main() !void {
    var buffer: [max_source_len]u8 = undefined;
    const source = try readFile(std.io.getStdIn().reader(), &buffer);

    var index: usize = 0;
    const writer = std.io.getStdOut().writer();
    try writer.writeAll(&.{0,'a','s','m',1,0,0,0});
    const errWriter = std.io.getStdErr().writer();
    compileCoreModule(source, &index, writer) catch |err| {
        const startIndex = indexOfBackwards(source[0..index], '\n') orelse 0;
        const endIndex = std.mem.indexOfScalarPos(u8, source, index, '\n') orelse source.len;
        const line = 1 + std.mem.count(u8, source[0..index], "\n");
        const column = index - startIndex + 1;
        try errWriter.print("\n\x1b[1;31m{s}\x1b[0m at line \x1b[1;37m{d}\x1b[0m column \x1b[1;37m{d}\x1b[0m\n{s}\n", .{@errorName(err), line, column, source[startIndex..endIndex]});
        for (0..column - 1) |_| {
            try errWriter.writeByte(' ');
        }
        try errWriter.writeAll("\x1b[1;32m^");
        for (0..endIndex - startIndex - column) |_| {
            try errWriter.writeAll("~");
        }
        try errWriter.writeAll("\x1b[0m\n");
    };
}
