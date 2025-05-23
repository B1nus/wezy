const std = @import("std");
const List = std.ArrayList;
const assert = std.debug.assert;

source: []const u8,
stack: List(u64),
index: u64,
indenting: bool,

pub fn init(allocator: std.mem.Allocator, source: []const u8) @This() {
    var stack = List(u64).init(allocator);
    stack.append(0) catch unreachable;

    return .{
        .source = source,
        .stack = stack,
        .indenting = false,
        .index = 0,
    };
}

fn currentByte(this: @This()) u8 {
    if (this.index < this.source.len) {
        return this.source[this.index];
    } else {
        return 0;
    }
}

pub fn nextToken(this: *@This()) Token {
    const Prefix = enum {
        none,
        hexadecimal,
        binary,
        octal,

        fn valid(prefix: @This(), byte: u8) bool {
            return switch (prefix) {
                .none => byte >= '0' and byte <= '9',
                .hexadecimal => (byte >= '0' and byte <= '9') or (byte >= 'a' and byte <= 'f') or (byte >= 'A' and byte <= 'F'),
                .binary => byte == '0' or byte == '1',
                .octal => byte >= '0' and byte <= '7',
            };
        }
    };

    const State = union(enum) {
        start,
        less,
        more,
        equal,
        bang,
        char,
        float: Prefix,
        string,
        integer: Prefix,
        zero,
        variable,
        newline,
        invalid,
        indentation,
    };

    var start: u64 = undefined;
    var tag: ?Token.Tag = null;
    var state: State = .start;
    var indentation: u64 = 0;

    while (true) {
        if (tag != null) {
            break;
        }

        switch (state) {
            .start => {
                start = this.index;
                switch (this.currentByte()) {
                    0 => {
                        assert(this.index == this.source.len);
                        tag = .end;
                        break;
                    },
                    '<' => state = .less,
                    '>' => state = .more,
                    '=' => state = .equal,
                    '!' => state = .bang,
                    '\'' => state = .char,
                    '\"' => state = .string,
                    '0' => state = .zero,
                    '1'...'9' => state = .{ .integer = .none },
                    '+' => tag = .plus,
                    '-' => tag = .minus,
                    '*' => tag = .asterix,
                    '/' => tag = .slash,
                    '%' => tag = .percent,
                    '^' => tag = .caret,
                    '(' => tag = .left_parenthesis,
                    ')' => tag = .right_parenthesis,
                    '{' => tag = .left_brace,
                    '}' => tag = .right_brace,
                    '[' => tag = .left_bracket,
                    ']' => tag = .right_bracket,
                    '.' => tag = .dot,
                    ',' => tag = .comma,
                    '\n', '\r' => state = .newline,
                    '\t', ' ' => state = .start,
                    'a'...'z' => state = .variable,
                    else => state = .invalid,
                }
            },
            .less => switch (this.currentByte()) {
                '<' => tag = .double_less,
                '=' => tag = .less_equal,
                else => {
                    tag = .less;
                    break;
                },
            },
            .more => switch (this.currentByte()) {
                '<' => tag = .double_more,
                '=' => tag = .more_equal,
                else => {
                    tag = .more;
                    break;
                },
            },
            .equal => if (this.currentByte() == '=') {
                tag = .double_equal;
            } else {
                tag = .equal;
                break;
            },
            .bang => if (this.currentByte() == '=') {
                tag = .bang_equal;
            } else {
                state = .invalid;
            },
            .invalid => switch (this.currentByte()) {
                0, '\n', '\r', '\t', ' ' => {
                    tag = .invalid;
                    break;
                },
                else => {},
            },
            .string => if (this.currentByte() == '\"' and this.source[this.index - 1] != '\\') {
                tag = .string;
            },
            .char => if (this.currentByte() == '\'' and this.source[this.index - 1] != '\\') {
                tag = .char;
            },
            .variable => switch (this.currentByte()) {
                'a'...'z', '_', '0'...'9' => {},
                else => if (this.source[this.index - 1] == '_') {
                    state = .invalid;
                } else {
                    tag = .variable;
                    break;
                },
            },
            .zero => switch (this.currentByte()) {
                '0'...'9', '_' => state = .{ .integer = .none },
                'x', 'X' => state = .{ .integer = .hexadecimal },
                'b', 'B' => state = .{ .integer = .binary },
                'o', 'O' => state = .{ .integer = .octal },
                '.' => state = .{ .float = .none },
                else => {
                    tag = .integer;
                    break;
                },
            },
            .integer => |pref| {
                const byte = this.currentByte();

                if (!pref.valid(byte)) {
                    if (!pref.valid(this.source[this.index - 1])) {
                        state = .invalid;
                        continue;
                    }
                    if (byte == '.') {
                        state = .{ .float = pref };
                    } else if (byte != '_') {
                        tag = switch (pref) {
                            .none => .integer,
                            .hexadecimal => .hexadecimal_integer,
                            .binary => .binary_integer,
                            .octal => .octal_integer,
                        };
                        break;
                    }
                }
            },
            .float => |pref| {
                const byte = this.currentByte();

                if (!pref.valid(byte)) {
                    if (!pref.valid(this.source[this.index - 1])) {
                        state = .invalid;
                        continue;
                    }

                    if (byte != '_') {
                        tag = switch (pref) {
                            .none => .float,
                            .hexadecimal => .hexadecimal_float,
                            .binary => .binary_float,
                            .octal => .octal_float,
                        };
                        break;
                    }
                }
            },
            .newline => switch (this.currentByte()) {
                0 => {
                    tag = .end;
                    break;
                },
                else => {
                    indentation = 0;
                    state = .indentation;
                    continue;
                },
            },
            .indentation => switch (this.currentByte()) {
                ' ' => indentation += 1,
                '\t' => {
                    const mod = indentation % 4;
                    if (mod == 0) {
                        indentation += 4;
                    } else {
                        indentation += 4 - mod;
                    }
                },
                '\n', '\r' => {
                    start = this.index;
                    state = .newline;
                },
                0 => {
                    tag = .end;
                    break;
                },
                else => {
                    var last = this.stack.getLast();
                    if (indentation == last) {
                        tag = .newline;
                        break;
                    } else if (indentation > last) {
                        if (!this.indenting) {
                            this.stack.append(indentation) catch unreachable;
                            tag = .indentation;
                        } else {
                            tag = .newline;
                        }
                        break;
                    } else {
                        _ = this.stack.pop();

                        last = this.stack.getLast();
                        if (indentation > last) {
                            this.indenting = true;
                        } else {
                            this.indenting = false;
                            if (indentation != last) {
                                this.index = start - 1;
                            }
                        }

                        tag = .dedentation;
                        break;
                    }
                },
            },
        }
        this.index += 1;
    }

    return .{ .start = start, .end = this.index, .tag = tag.? };
}

pub const Token = struct {
    start: u64,
    end: u64,
    tag: Tag,

    pub fn assert(this: @This(), tag: Tag, start: ?u64, end: ?u64, source_: ?struct { []const u8, []const u8 }) void {
        std.debug.assert(this.tag == tag);
        std.debug.assert(start == null or start == this.start);
        std.debug.assert(end == null or end == this.end);
        std.debug.assert(source_ == null or std.mem.eql(u8, source_.?.@"0"[this.start..this.end], source_.?.@"1"));
    }

    pub const Tag = enum {
        variable,
        integer,
        hexadecimal_integer,
        binary_integer,
        octal_integer,
        float,
        hexadecimal_float,
        binary_float,
        octal_float,
        string,
        char,
        left_parenthesis,
        right_parenthesis,
        left_bracket,
        right_bracket,
        left_brace,
        right_brace,
        comma,
        dot,
        plus,
        minus,
        slash,
        asterix,
        caret,
        percent,
        double_less,
        double_more,
        less,
        more,
        less_equal,
        more_equal,
        equal,
        double_equal,
        bang_equal,
        newline,
        indentation,
        dedentation,
        invalid,
        end,
    };
};

test "numbers" {
    var this = @This().init(
        std.heap.c_allocator,
        \\0x0 0x00 0x0.0 0b0 0b0.0 0b0.0 0o0 0o0.0 0_0 0.
    );
    this.nextToken().assert(.hexadecimal_integer, 0, 3, .{ this.source, "0x0" });
    this.nextToken().assert(.hexadecimal_integer, 4, 8, .{ this.source, "0x00" });
    this.nextToken().assert(.hexadecimal_float, 9, 14, .{ this.source, "0x0.0" });
    this.nextToken().assert(.binary_integer, 15, 18, .{ this.source, "0b0" });
    this.nextToken().assert(.binary_float, 19, 24, .{ this.source, "0b0.0" });
    this.nextToken().assert(.binary_float, 25, 30, .{ this.source, "0b0.0" });
    this.nextToken().assert(.octal_integer, 31, 34, .{ this.source, "0o0" });
    this.nextToken().assert(.octal_float, 35, 40, .{ this.source, "0o0.0" });
    this.nextToken().assert(.integer, 41, 44, .{ this.source, "0_0" });
    this.nextToken().assert(.invalid, 45, 47, .{ this.source, "0." });
}

test "indentation" {
    var this = @This().init(
        std.heap.c_allocator,
        \\hello
        \\   h
        \\  h
        \\ h
        \\ h
        \\h
    );
    this.nextToken().assert(.variable, 0, 5, .{ this.source, "hello" });
    this.nextToken().assert(.indentation, 5, 9, null);
    this.nextToken().assert(.variable, 9, 10, .{ this.source, "h" });
    this.nextToken().assert(.dedentation, 10, 13, null);
    this.nextToken().assert(.variable, 13, 14, .{ this.source, "h" });
    this.nextToken().assert(.newline, 14, 16, null);
    this.nextToken().assert(.variable, 16, 17, .{ this.source, "h" });
    this.nextToken().assert(.newline, 17, 19, null);
    this.nextToken().assert(.variable, 19, 20, .{ this.source, "h" });
    this.nextToken().assert(.newline, 20, 21, null);
    this.nextToken().assert(.variable, 21, 22, .{ this.source, "h" });
    this.nextToken().assert(.end, null, null, null);
}
