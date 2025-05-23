const std = @import("std");
const List = std.ArrayList;
const assert = std.debug.assert;
const Tokenizer = @import("Tokenizer.zig");
const ast = @import("ast/we.zig");
const Block = ast.Block;
const Value = ast.Value;
const Type = ast.Type;
const Token = Tokenizer.Token;

pub const Error = union(enum) {
    large_integer: Token,
    invalid_token: Token,
    invalid_string: Token,
    invalid_utf8: Token,
    invalid_char: Token,
    invalid_hex: u64,
    invalid_escape: u64,
    expected_unicode_left_brace: u64,
    large_unicode: Range,
    invalid_unicode: Range,
    invalid_prefix,

    pub const Range = struct {
        start: u64,
        end: u64,
    };
};

tokenizer: Tokenizer,
allocator: std.mem.Allocator,
current_token: Token,
peek_token: Token,
source: []const u8,
block: Block,
// fixable_errors: List(FixableError),
errors: List(Error),

pub fn init(allocator: std.mem.Allocator, source: []const u8) @This() {
    var tokenizer = Tokenizer.init(allocator, source);
    const current_token = tokenizer.nextToken();
    const peek_token = tokenizer.nextToken();
    return .{
        .tokenizer = tokenizer,
        .current_token = current_token,
        .peek_token = peek_token,
        .allocator = allocator,
        .source = source,
        .block = Block.init(allocator),
        .errors = List(Error).init(allocator),
    };
}

pub fn advance(this: *@This()) void {
    if (this.current_token.tag == .invalid) {
        this.errors.append(.{ .invalid_token = this.current_token }) catch unreachable;
    }
    if (this.peek_token.tag == .invalid) {
        this.errors.append(.{ .invalid_token = this.peek_token }) catch unreachable;
    }
    this.current_token = this.peek_token;
    this.peek_token = this.tokenizer.nextToken();
}

pub fn isEndOfLine(tag: Token.Tag) bool {
    return switch (tag) {
        .indentation, .dedentation, .newline, .end => true,
        else => false,
    };
}

pub fn getPrecedence(tag: Token.Tag) ?u8 {
    return switch (tag) {
        .double_equal, .bang_equal => 1,
        .less, .more, .less_equal, .more_equal => 2,
        .double_less, .double_more => 3,
        .plus, .minus => 4,
        .asterix, .slash, .percent => 5,
        .caret => 6,
        else => null,
    };
}

pub fn parseStringLiteral(this: *@This()) Value {
    var bytes = List(u8).init(this.allocator);
    var invalid = false;

    const State = union(enum) {
        normal,
        slash,
        byte: u8,
        unicode_start,
        unicode: u21,
    };

    var state: State = .normal;
    var unicode_start: u64 = undefined;

    var i: u64 = this.current_token.start + 1;
    while (i < this.current_token.end - 1) {
        const char = this.source[i];
        switch (state) {
            .normal => switch (char) {
                '\\' => state = .slash,
                '\"' => unreachable,
                else => bytes.append(char) catch unreachable,
            },
            .slash => switch (char) {
                '\\', '\'', '\"' => {
                    bytes.append(char) catch unreachable;
                    state = .normal;
                },
                'n' => {
                    bytes.append('\n') catch unreachable;
                    state = .normal;
                },
                'r' => {
                    bytes.append('\r') catch unreachable;
                    state = .normal;
                },
                't' => {
                    bytes.append('\t') catch unreachable;
                    state = .normal;
                },
                '0' => {
                    bytes.append(0) catch unreachable;
                    state = .normal;
                },
                'x' => {
                    state = .{ .byte = 0 };
                },
                'u' => {
                    state = .unicode_start;
                    unicode_start = i;
                },
                else => {
                    this.errors.append(.{ .invalid_escape = i }) catch unreachable;
                    state = .normal;
                },
            },
            .byte => |*byte| {
                byte.* <<= 4;
                if (std.fmt.parseInt(u4, &.{ char }, 16)) |hex_digit| {
                    byte.* += hex_digit;
                    if (byte.* > 0xf) {
                        bytes.append(byte.*) catch unreachable;
                        state = .normal;
                    }
                } else |_| {
                    this.errors.append(Error { .invalid_hex = i }) catch unreachable;
                    if (byte.* == 0) {
                        i += 1;
                    }
                        invalid = true;

                    state = .normal;
                }
            },
            .unicode_start => if (char == '{') {
                unicode_start = i + 1;
                state = .{ .unicode = 0 };
            } else {
                invalid = true;
                this.errors.append(Error { .expected_unicode_left_brace = i }) catch unreachable;
                state = .normal;
                continue;
            },
            .unicode => |*codepoint| {
                if (i - unicode_start > 6) {
                    invalid = true;
                    this.errors.append(Error { .large_unicode = .{ .start = unicode_start, .end = i } }) catch unreachable;
                    state = .normal;
                }

                if (char == '}') {
                    var buffer: [4]u8 = undefined;
                    if (std.unicode.utf8Encode(codepoint.*, &buffer)) |written| {
                        bytes.appendSlice(buffer[0..written]) catch unreachable;
                    } else |_| {
                        this.errors.append(Error { .invalid_unicode = .{ .start = unicode_start, .end = i } }) catch unreachable;
                        invalid = true;
                    }
                    state = .normal;
                }
                codepoint.* <<= 4;
                if (std.fmt.parseInt(u4, &.{ char }, 16)) |hex_digit| {
                    codepoint.* += hex_digit;
                } else |_| {
                    this.errors.append(Error { .invalid_hex = i }) catch unreachable;
                    if (codepoint.* == 0) {
                        i += 1;
                    }

                    state = .normal;
                }
            },

        }
        i += 1;
    }

    if (invalid) {
        this.errors.append(Error { .invalid_string = this.current_token }) catch unreachable;
        return Value.invalid;
    } else {
        if (std.unicode.utf8ValidateSlice(bytes.items)) {
            return Value { .string = bytes };
        } else {
            this.errors.append(Error { .invalid_utf8 = this.current_token }) catch unreachable;
            return Value.invalid;
        }
    }
}

pub fn parseValue(this: *@This(), precedence: u8) Value {
    var left = this.parsePrefix();

    while (!isEndOfLine(this.peek_token.tag) and precedence < getPrecedence(this.peek_token.tag) orelse unreachable) {
        left = this.parseInfix(left);
    }

    return left;
}

pub fn parseInfix(this: *@This(), left: Value) Value {
    const infix_token = this.peek_token;

    const precedence = getPrecedence(infix_token.tag) orelse unreachable;

    this.advance();
    this.advance();

    const right = this.parseValue(precedence);

    const left_pointer = this.allocator.create(Value) catch unreachable;
    const right_pointer = this.allocator.create(Value) catch unreachable;

    left_pointer.* = left;
    right_pointer.* = right;

    const binary: [2]*Value = .{ left_pointer, right_pointer };

    return switch (infix_token.tag) {
        .plus => .{ .addition = binary },
        .asterix => .{ .multiplication = binary },
        else => unreachable,
    };
}

pub fn parsePrefix(this: *@This()) Value {
    var prefix_value: Value = undefined;

    switch (this.current_token.tag) {
        .hexadecimal_integer, .integer, .octal_integer, .binary_integer => {
            const base: u8 = switch (this.current_token.tag) {
                .hexadecimal_integer => 16,
                .integer => 10,
                .octal_integer => 8,
                .binary_integer => 2,
                else => unreachable,
            };

            const start = if (base == 10) this.current_token.start else this.current_token.start + 2;
            const source = this.source[start..this.current_token.end];
            const value = std.fmt.parseInt(u64, source, base) catch {
                this.errors.append(Error { .large_integer = this.current_token }) catch unreachable;
                return Value.invalid;
            };
            
            prefix_value = Value { .integer = value };
        },
        .float, .hexadecimal_float => {
            const source = this.source[this.current_token.start..this.current_token.end];
            const value = std.fmt.parseFloat(f64, source) catch unreachable;

            prefix_value = Value { .float = value };
        },
        .string => {
            prefix_value = this.parseStringLiteral();
        },
        .char => {
            const value = this.parseStringLiteral();

            if (value == .invalid) {
                return value;
            } else if (std.unicode.utf8CountCodepoints(value.string.items) catch unreachable != 1) {
                this.errors.append(Error { .invalid_char = this.current_token }) catch unreachable;
                return Value.invalid;
            } else {
                var bytes = [4]u8{0,0,0,0};
                std.mem.copyForwards(u8, bytes[0..4], value.string.items[0..4]);
                const code_point = std.unicode.utf8Decode4(bytes);
                prefix_value = Value { .char = code_point };
            }
        },
        else => {
            this.errors.append(Error.invalid_prefix) catch unreachable;
            return Value.invalid;
        },
    }

    return prefix_value;
}

test "integers" {
    var this = @This().init(std.heap.c_allocator, "2_2 0xff 0b1001 0o71");
    assert(this.parsePrefix().integer == 22);
    this.advance();
    assert(this.parsePrefix().integer == 0xff);
    this.advance();
    assert(this.parsePrefix().integer == 0b1001);
    this.advance();
    assert(this.parsePrefix().integer == 0o71);
}

test "pratt" {
    var this = @This().init(std.heap.c_allocator, "0x2.8 + 4 * 3 * 2");
    const value = this.parseValue(0);
    assert(value.addition[0].float == 0x2.8);
    assert(value.addition[1].multiplication[0].multiplication[0].integer == 4);
    assert(value.addition[1].multiplication[0].multiplication[1].integer == 3);
    assert(value.addition[1].multiplication[1].integer == 2);
}
