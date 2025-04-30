source: []const u8,
word: ?Word,
start: usize,
index: usize,

pub fn init(source: []const u8) @This() {
    return .{
        .source = source,
        .word = null,
        .start = 0,
        .index = 0,
    };
}

const Word = union(enum) {
    newline: usize,
    doubleNewline: usize,
    word: []const u8,
    endOfFile,
    beginningOfFile,
};

fn getByte(self: @This()) u8 {
    return if (self.index < self.source.len) self.source[self.index] else 0;
}

fn nextByte(self: *@This()) u8 {
    self.index += 1;
    return self.getByte();
}

fn getPreviousByte(self: @This()) u8 {
    return if (self.index > 0) self.source[self.index - 1] else 0;
}

pub fn previousWord(self: *@This()) !Word {
    if (self.index == 0) {
        return .beginningOfFile;
    }
    switch (self.getByte()) {
        0 => {
            self.skipBackwardUntil(" \n");
            if (self.getByte() == ' ') {
                self.index += 1;
            }
        },
        '\n' => {
            self.index -= 1;
            self.skipBackwardUntil(" \n");
            if (self.getByte() == ' ') {
                self.index += 1;
            }
        },
        else => {
            self.index -= 1;
            if (self.getPreviousByte() == ' ') {
                self.skipBackwardWhile(" \n");
                self.index += 1;
            } else {
                self.index -= 1;
                self.skipBackwardUntil(" \n");
                if (self.index != 0) {
                    self.index += 1;
                }
            }
        },
    }
    const mem_pos = self.index;
    const word = self.nextWord();
    self.index = mem_pos;
    return word;
}

pub fn skipUntil(self: *@This(), end: []const u8) void {
    while (self.nextByte() != 0 and std.mem.count(u8, end, &.{self.getByte()}) == 0) {}
}

fn readUntil(self: *@This(), end: []const u8) []const u8 {
    self.start = self.index;
    self.skipUntil(end);
    return self.source[self.start..self.index];
}

pub fn skipBackwardUntil(self: *@This(), end: []const u8) void {
    while (self.index > 0 and std.mem.count(u8, end, &.{self.getByte()}) == 0) {
        self.index -= 1;
    }
}

fn skipBackwardWhile(self: *@This(), bytes: []const u8) void {
    while (self.index > 0 and std.mem.count(u8, bytes, &.{self.getByte()}) > 0) {
        self.index -= 1;
    }
}

pub fn nextWord(self: *@This()) !Word {
    self.start = self.index;
    switch (self.getByte()) {
        0 => switch (self.getPreviousByte()) {
            '\n' => return error.TrailingNewline,
            ' ' => return error.TrailingSpace,
            else => return .endOfFile,
        },
        ' ' => return error.UnexpectedSpace,
        '\n' => switch (self.nextByte()) {
            0 => return error.TrailingNewline,
            '\n' => switch (self.nextByte()) {
                0 => return error.TrailingNewline,
                '\n' => return error.TooManyNewline,
                else => {
                    const n = self.count(' ');
                    if (self.getByte() == '\n') {
                        return error.UnusedIndentation;
                    } else {
                        return .{ .doubleNewline = n };
                    }
                },
            },
            else => {
                const n = self.count(' ');
                if (self.getByte() == '\n') {
                    return error.UnusedIndentation;
                } else {
                    return .{ .newline = n };
                }
            },
        },
        else => {
            const word = self.readUntil(" \n");
            if (self.getByte() == ' ') {
                _ = self.nextByte();
            }
            return .{ .word = word };
        },
    }
}

fn count(self: *@This(), byte: u8) usize {
    if (self.getByte() == byte) {
        var n: usize = 1;
        while (self.nextByte() == byte) {
            n += 1;
        }
        return n;
    } else {
        return 0;
    }
}

const std = @import("std");
const expect = std.testing.expect;

test "empty" {
    const source = "";
    var scanner = @This().init(source);
    try expect(try scanner.nextWord() == .endOfFile);
}

test "only space" {
    const source = " ";
    var scanner = @This().init(source);
    try expect(scanner.nextWord() == error.UnexpectedSpace);
}

test "one word" {
    const source = "hello";
    var scanner = @This().init(source);
    try expect(std.mem.eql(u8, (try scanner.nextWord()).word, "hello"));
}

test "trailing space at end" {
    const source = "hello ";
    var scanner = @This().init(source);
    _ = try scanner.nextWord();
    try expect(scanner.nextWord() == error.TrailingSpace);
}

test "trailing newline at end" {
    const source = "hello \n";
    var scanner = @This().init(source);
    _ = try scanner.nextWord();
    try expect(scanner.nextWord() == error.TrailingNewline);
}

test "double space" {
    const source = "hello   my friend";
    var scanner = @This().init(source);
    _ = try scanner.nextWord();
    try expect(scanner.nextWord() == error.UnexpectedSpace);
}

test "read rest of line" {
    const source = "hello   my friend";
    var scanner = @This().init(source);
    _ = try scanner.nextWord();
    try expect(std.mem.eql(u8, scanner.readUntil("\n"), "  my friend"));
}

test "newline" {
    const source = "\n  ";
    var scanner = @This().init(source);
    try expect((try scanner.nextWord()).newline == 2);
}

test "double newline" {
    const source = "\n\n    ";
    var scanner = @This().init(source);
    try expect((try scanner.nextWord()).doubleNewline == 4);
}

test "tripple newline" {
    const source = "\n\n\n    ";
    var scanner = @This().init(source);
    try expect(scanner.nextWord() == error.TooManyNewline);
}

test "unused indent" {
    const source = "\n  \n";
    var scanner = @This().init(source);
    try expect(scanner.nextWord() == error.UnusedIndentation);
}

test "previous word" {
    const source = "hello world\n\n  hello";
    var scanner = @This().init(source);
    const first_word = try scanner.nextWord();
    const second_word = try scanner.nextWord();
    const third_word = try scanner.nextWord();
    const fourth_word = try scanner.nextWord();
    try expect(std.mem.eql(u8, (try scanner.previousWord()).word, fourth_word.word));
    try expect((try scanner.previousWord()).doubleNewline == third_word.doubleNewline);
    try expect(std.mem.eql(u8, (try scanner.previousWord()).word, second_word.word));
    try expect(std.mem.eql(u8, (try scanner.previousWord()).word, first_word.word));
}

test "func result thingie" {
    const source = "func main param x i32 y i32 result i32 result i32 i32 i32";
    var scanner = @This().init(source);
    _ = scanner.readUntil("\n");
    try expect(std.mem.eql(u8, (try scanner.previousWord()).word, "i32"));
    try expect(std.mem.eql(u8, (try scanner.previousWord()).word, "i32"));
    try expect(std.mem.eql(u8, (try scanner.previousWord()).word, "i32"));
    try expect(std.mem.eql(u8, (try scanner.previousWord()).word, "result"));
    try expect(std.mem.eql(u8, (try scanner.previousWord()).word, "i32"));
    try expect(std.mem.eql(u8, (try scanner.previousWord()).word, "result"));
    try expect(std.mem.eql(u8, (try scanner.previousWord()).word, "i32"));
    try expect(std.mem.eql(u8, (try scanner.previousWord()).word, "y"));
    try expect(std.mem.eql(u8, (try scanner.previousWord()).word, "i32"));
    try expect(std.mem.eql(u8, (try scanner.previousWord()).word, "x"));
    try expect(std.mem.eql(u8, (try scanner.previousWord()).word, "param"));
    try expect(std.mem.eql(u8, (try scanner.previousWord()).word, "main"));
    try expect(std.mem.eql(u8, (try scanner.previousWord()).word, "func"));
    try expect(try scanner.previousWord() == .beginningOfFile);
}
