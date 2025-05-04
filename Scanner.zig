const std = @import("std");
const assert = std.testing.expect;
const eql = std.mem.eql;

source: []const u8,
start: usize,
end: usize,
next: usize,
line: usize,
line_start: usize,

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

const DataMode = enum {
    declarative,
    passive,
    active,
};

pub fn init(source: []const u8) @This() {
    return .{
        .source = source,
        .next = 0,
        .start = undefined,
        .end = undefined,
        .line = 1,
        .line_start = 0,
    };
}

pub fn expect(self: *@This(), expected: []const u8) bool {
    const start = self.next;
    if (self.word()) |w| {
        if (eql(u8, expected, w)) {
            return true;
        } else {
            self.next = start;
            return false;
        }
    } else {
        return false;
    }
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
        self.line += 1;
        self.line_start = self.next;
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
    const start = self.next;
    if (self.word()) |w| {
        return std.fmt.parseInt(T, w, 0) catch {
            self.next = start;
            return null;
        };
    } else {
        return null;
    }
}

pub fn float(self: *@This(), T: type) ?T {
    const start = self.next;
    if (self.word()) |w| {
        return std.fmt.parseFloat(T, w) catch {
            self.next = start;
            return null;
        };
    } else {
        return null;
    }
}

pub fn variant(self: *@This(), E: type) ?E {
    const start = self.next;
    if (self.word()) |w| {
        if (std.meta.stringToEnum(E, w)) |v| {
            return v;
        } else {
            self.next = start;
            return null;
        }
    } else {
        return null;
    }
}

pub fn dataMode(self: *@This()) ?DataMode {
    return self.variant(DataMode);
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
    try assert(scanner.valtype().? == .f64);
    try assert(scanner.valtype().? == .i32);
    try assert(scanner.valtype().? == .funcref);
}

test "scan import export type" {
    var scanner = @This().init("global func memory table");
    try assert(scanner.importExportType().? == .global);
    try assert(scanner.importExportType().? == .func);
    try assert(scanner.importExportType().? == .memory);
    try assert(scanner.importExportType().? == .table);
}

test "scan prefix" {
    var scanner = @This().init("import func type global");
    try assert(scanner.prefix() == .import);
    try assert(scanner.prefix() == .func);
    try assert(scanner.prefix() == .type);
    try assert(scanner.prefix() == .global);
}

test "scan string" {
    var scanner = @This().init(" Hi!\\n \n");
    try assert(eql(u8, scanner.string().?, " Hi!\\n "));
}

test "scan word" {
    var scanner = @This().init("1 2  3");
    try assert(eql(u8, scanner.word().?, "1"));
    try assert(eql(u8, scanner.word().?, "2"));
    try assert(scanner.word() == null);
    try assert(scanner.indentation() == 1);
    try assert(eql(u8, scanner.word().?, "3"));
}

test "scan integer" {
    var scanner = @This().init("1234567");
    try assert(scanner.integer(i32).? == 1234567);
}

test "scan float" {
    var scanner = @This().init("1.25");
    try assert(scanner.float(f32).? == 1.25);
}

test "scan newline" {
    var scanner = @This().init("\n  ");
    try assert(scanner.newline());
}

test "indentation" {
    var scanner = @This().init("    ");
    try assert(scanner.indentation() == 4);
}

test "scan double newline" {
    var scanner = @This().init("\n\n   ");
    try assert(scanner.newline());
    try assert(scanner.newline());
}

test "integration" {
    const source =
        \\import hello world din mamma
        \\
        \\
        \\
        \\hi f32 func table
        \\  hello
    ;
    var scanner = @This().init(source);
    try assert(scanner.integer(i32) == null);
    try assert(scanner.importExportType() == null);
    try assert(scanner.prefix() == .import);
    try assert(eql(u8, scanner.word().?, "hello"));
    try assert(eql(u8, scanner.word().?, "world"));
    try assert(eql(u8, scanner.word().?, "din"));
    try assert(eql(u8, scanner.word().?, "mamma"));
    try assert(scanner.newline());
    try assert(scanner.newline());
    try assert(scanner.newline());
    try assert(scanner.newline());
    try assert(eql(u8, scanner.word().?, "hi"));
    try assert(scanner.valtype() == .f32);
    try assert(scanner.importExportType() == .func);
    try assert(scanner.prefix() == .table);
    try assert(scanner.newline());
    try assert(scanner.indentation() == 2);
    try assert(eql(u8, scanner.word().?, "hello"));
}
