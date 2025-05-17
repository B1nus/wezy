const std = @import("std");
const expect = std.testing.expect;
const eql = std.mem.eql;

source: []const u8,
start_index: usize,
end_index: usize,
line_number: usize,
line_start: usize,

pub fn init(source: []const u8) @This() {
    return .{
        .source = source,
        .start_index = 0,
        .end_index = 0,
        .line_number = 1,
        .line_start = 0,
    };
}

pub const Thing = union(enum) {
    number: Number,
    identifier: []const u8,
    string: []const u8,
    indentation: usize,
    invalid,
    end,
};

pub fn nextThing(this: *@This()) Thing {
    var thing: Thing = .end;
    if (this.end_index < this.source.len) {
        const c = this.source[this.end_index];

        if (isNewline(c)) {
            return .{ .indentation = this.nextIndentation() };
        } else if (isSeparator(c)) {
            this.skipWhile(isSeparator);
            return this.nextThing();
        } else if (isDecimal(c) or isSign(c)) {
            this.start_index = this.end_index;
            thing = .{ .number = this.nextNumber() };
        } else if (isIdentifier(c)) {
            this.start_index = this.end_index;
            thing = .{ .identifier = this.nextIdentifier() };
        } else if (c == '\"') {
            this.start_index = this.end_index;
            thing = .{ .string = this.nextString() };
        } else {
            this.start_index = this.end_index;
            this.skipUntil(isWhitespace);
            thing = .invalid;
        }
    }

    this.skipWhile(isSeparator);
    return thing;
}

pub fn nextIndentation(this: *@This()) usize {
    while (this.end_index < this.source.len and isNewline(this.source[this.end_index])) {
        this.end_index += 1;
        this.start_index = this.end_index;
        this.skipWhile(isSeparator);
    }

    return this.end_index - this.start_index;
}

pub fn nextIdentifier(this: *@This()) []const u8 {
    this.skipWhile(isIdentifier);
    return this.source[this.start_index..this.end_index];
}

pub fn nextString(this: *@This()) []const u8 {
    this.end_index += 1;
    while (this.end_index < this.source.len) {
        if (this.source[this.end_index] == '\"' and this.source[this.end_index - 1] != '\\') {
            break;
        }
        this.end_index += 1;
    }
    this.end_index = @min(this.source.len, this.end_index + 1);
    return this.source[this.start_index..this.end_index];
}

pub fn isNewline(byte: u8) bool {
    return byte == '\n' or byte == '\r';
}

pub fn isSeparator(byte: u8) bool {
    return byte == '\t' or byte == ' ';
}

pub fn isWhitespace(byte: u8) bool {
    return isNewline(byte) or isSeparator(byte);
}

pub fn isLetter(byte: u8) bool {
    return byte >= 'a' and byte <= 'z';
}

pub fn isIdentifier(byte: u8) bool {
    return byte == '_' or byte == '-' or byte == '[' or byte == ']' or byte == '.' or isLetter(byte) or isDecimal(byte);
}

pub fn isBinary(byte: u8) bool {
    return byte == '0' or byte == '1';
}

pub fn isDecimal(byte: u8) bool {
    return byte >= '0' and byte <= '9';
}

pub fn isOctal(byte: u8) bool {
    return byte >= '0' and byte <= '7';
}

pub fn isHex(byte: u8) bool {
    return isDecimal(byte) or (byte >= 'a' and byte <= 'f') or (byte >= 'A' and byte <= 'F');
}

pub fn isSign(byte: u8) bool {
    return byte == '+' or byte == '-';
}

pub fn skipWhile(this: *@This(), condition: fn(u8) bool) void {
    while (this.end_index < this.source.len and condition(this.source[this.end_index])) {
        this.end_index += 1;
    }
}

pub fn skipUntil(this: *@This(), condition: fn(u8) bool) void {
    while (this.end_index < this.source.len and !condition(this.source[this.end_index])) {
        this.end_index += 1;
    }
}

const Number = struct {
    literal: []const u8,
    sign: Sign,
    prefix: Prefix,
    type: Type,

    const Prefix = enum {
        hex,
        bin,
        oct,
        none,
    };

    const Type = enum {
        float,
        integer,
    };

    pub const Sign = enum {
        positive,
        negative,
    };
};

pub fn nextSign(this: *@This()) Number.Sign {
    if (this.end_index < this.source.len) {
        const c = this.source[this.end_index];
        if (isSign(c)) {
            this.end_index += 1;
        }

        if (c == '-') {
            return .negative;
        }
    }

    return .positive;
}

pub fn nextNumberPrefix(this: *@This()) Number.Prefix {
    if (this.end_index + 2 <= this.source.len and this.source[this.end_index] == '0') {
        switch (this.source[this.end_index + 1]) {
            'b' => {
                this.end_index += 2;
                return .bin;
            },
            'x' => {
                this.end_index += 2;
                return .hex;
            },
            'o' => {
                this.end_index += 2;
                return .oct;
            },
            else => {},
        }
    }

    return .none;
}

pub fn skipWhileDigit(this: *@This(), prefix: Number.Prefix) void {
    switch (prefix) {
        .bin => this.skipWhile(isBinary),
        .oct => this.skipWhile(isOctal),
        .hex => this.skipWhile(isHex),
        .none => this.skipWhile(isDecimal),
    }
}

pub fn nextNumber(this: *@This()) Number {
    const sign = this.nextSign();
    const prefix = this.nextNumberPrefix();

    this.start_index = this.end_index;
    this.skipWhileDigit(prefix);

    const has_decimal_point = this.end_index < this.source.len and this.source[this.end_index] == '.';

    if (has_decimal_point) {
        this.end_index += 1;
        this.skipWhileDigit(prefix);

    }

    return .{
        .literal = this.source[this.start_index..this.end_index],
        .sign = sign,
        .prefix = prefix,
        .type = if (has_decimal_point) .float else .integer,
    };
}

