const std = @import("std");
const expect = std.testing.expect;
const eql = std.mem.eql;

source: []const u8,
start: usize,
end: usize,
next: usize,
line: usize,
lineStart: usize,

const ImportExportType = enum(u8) {
    func = 0,
    table = 1,
    memory = 2,
    global = 3,
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

const Prefix = enum(u8) {
    import,
    @"export",
    type,
    memory,
    data,
    global,
    table,
    elem,
    func,
};

pub fn init(source: []const u8) @This() {
    return .{
        .source = source,
        .next = 0,
        .start = undefined,
        .end = undefined,
        .line = 1,
        .lineStart = 0,
    };
}

pub fn word(self: *@This()) ?[]const u8 {
    self.start = self.next;
    self.end = self.start;

    while (true) : (self.end += 1) {
        if (self.end >= self.source.len) {
            self.end = self.source.len;
            self.next = if (self.end > self.start) self.source.len else return null;
        } else {
            switch (self.source[self.end]) {
                '\n' => if (self.end > self.start) {
                    self.next = self.end;
                } else {
                    return null;
                },
                ' ' => if (self.end > self.start) { self.next = self.end + 1; } else {return null;},
                else => continue,
            }
        }

        break;
    }

    return self.source[self.start..self.end];
}

pub fn string(self: *@This()) ?[]const u8 {
    self.start = self.next;
    self.end = self.start;

    while (self.end < self.source.len and self.source[self.end] != '\n') : (self.end += 1) { }

    self.next = if (self.end > self.start) self.end else return null;

    return self.source[self.start..self.end];
}

pub fn newline(self: *@This()) bool {
    if (self.next < self.source.len and self.source[self.next] == '\n') {
        self.next += 1;
        return true;
    } else {
        return false;
    }
}

pub fn indentation(self: *@This()) usize {
    self.start = self.next;
    self.end = self.start;

    while (self.end < self.source.len and self.source[self.end] == ' ') : (self.end += 1) { }

    self.next = self.end;

    return self.end - self.start;
}

pub fn endOfFile(self: *@This()) bool {
    return self.next >= self.source.len;
}

pub fn integer(self: *@This(), T: type) ?T {
    if (self.word()) |w| {
        return std.fmt.parseInt(T, w, 0) catch return null;
    } else {
        return null;
    }
}

pub fn float(self: *@This(), T: type) ?T {
    if (self.word()) |w| {
        return std.fmt.parseFloat(T, w) catch return null;
    } else {
        return null;
    }
}

pub fn variant(self: *@This(), E: type) ?E {
    if (self.word()) |w| {
        return std.meta.stringToEnum(E, w);
    } else {
        return null;
    }
}

pub fn valtype(self: *@This()) ?Valtype {
    return self.variant(Valtype);
}

pub fn prefix(self: *@This()) ?Prefix {
    return self.variant(Prefix);
}

pub fn importExportType(self: *@This()) ?ImportExportType {
    return self.variant(ImportExportType);
}

test "scan valtype" {
    var scanner = @This().init("f64 i32 funcref");
    try expect(scanner.valtype().? == .f64);
    try expect(scanner.valtype().? == .i32);
    try expect(scanner.valtype().? == .funcref);
}

test "scan import export type" {
    var scanner = @This().init("global func memory table");
    try expect(scanner.importExportType().? == .global);
    try expect(scanner.importExportType().? == .func);
    try expect(scanner.importExportType().? == .memory);
    try expect(scanner.importExportType().? == .table);
}

test "scan prefix" {
    var scanner = @This().init("import func type global");
    try expect(scanner.prefix() == .import);
    try expect(scanner.prefix() == .func);
    try expect(scanner.prefix() == .type);
    try expect(scanner.prefix() == .global);
}

test "scan string" {
    var scanner = @This().init(" Hi!\\n \n");
    try expect(eql(u8, scanner.string().?, " Hi!\\n "));
}

test "scan word" {
    var scanner = @This().init("1 2  3");
    try expect(eql(u8, scanner.word().?, "1"));
    try expect(eql(u8, scanner.word().?, "2"));
    try expect(scanner.word() == null);
    try expect(scanner.indentation() == 1);
    try expect(eql(u8, scanner.word().?, "3"));
}

test "scan integer" {
    var scanner = @This().init("1234567");
    try expect(scanner.integer(i32).? == 1234567);
}

test "scan float" {
    var scanner = @This().init("1.25");
    try expect(scanner.float(f32).? == 1.25);
}

test "scan newline" {
    var scanner = @This().init("\n  ");
    try expect(scanner.newline());
}

test "indentation" {
    var scanner = @This().init("    ");
    try expect(scanner.indentation() == 4);
}

test "scan double newline" {
    var scanner = @This().init("\n\n   ");
    try expect(scanner.newline());
    try expect(scanner.newline());
}
