pub const std = @import("std");

source: []const u8,
offset: usize,
indentation: std.ArrayList(usize),

pub fn init(source: []const u8, allocator: std.mem.Allocator) @This() {
    var indentation = std.ArrayList(usize).init(allocator);
    indentation.append(0) catch unreachable;
    return @This() {
        .source = source,
        .offset = 0,
        .indentation = indentation,
    };
}

pub fn deinit(self: *@This()) void {
    self.indentation.deinit();
}

pub fn next(self: *@This()) Token {
    const State = enum {
        start,
        integer,
        float,
        identifier,
        equals,
        less,
        greater,
        bang,
        string,
        newline,
    };

    var state = State.start;
    var token_tag: Token.Tag = .eof;
    var token_start: usize = self.offset;

    while (token_tag == .eof) {
        const c = if (self.offset >= self.source.len) 0 else self.source[self.offset];

        switch (state) {
            .start => switch (c) {
                0 => break,
                '+' => token_tag = .plus,
                '-' => token_tag = .minus,
                '*' => token_tag = .asterix,
                '/' => token_tag = .slash,
                '%' => token_tag = .percent,
                '(' => token_tag = .left_parenthesis,
                ')' => token_tag = .right_parenthesis,
                ',' => token_tag = .comma,
                '<' => state = .less,
                '>' => state = .greater,
                '=' => state = .equals,
                '!' => state = .bang,
                '\n' => state = .newline,
                'a'...'z' => state = .identifier,
                '0'...'9' => state = .integer,
                ' ', '\t', '\r' => token_start += 1,
                else => unreachable,
            },
            .less => switch (c) {
                '=' => token_tag = .less_equals,
                else => {
                    token_tag = .less;
                    continue;
                },
                },
            .greater => switch (c) {
                '=' => token_tag = .greater_equals,
                else => {
                    token_tag = .greater;
                    continue;
                },
                },
            .equals => switch (c) {
                '=' => token_tag = .double_equals,
                else => {
                    token_tag = .equals;
                    continue;
                },
                },
            .bang => switch (c) {
                '=' => token_tag = .not_equals,
                else => unreachable,
            },
            .string => switch (c) {
                '\"' => token_tag = .string,
                else => {},
            },
            .identifier => switch (c) {
                'a'...'z', '0'...'9', '_' => {},
                else => {
                    token_tag = .identifier;
                    continue;
                },
                },
            .integer => switch (c) {
                '0'...'9' => {},
                '.' => state = .float,
                else => {
                    token_tag = .integer;
                    continue;
                },
                },
            .float => switch (c) {
                '0'...'9' => {},
                else => {
                    token_tag = .float;
                    continue;
                },
                },
            .newline => switch (c) {
                ' ', '\t', '\r' => {},
                '\n' => token_start = self.offset,
                else => {
                    const indentation = self.offset - token_start - 1;

                    if (indentation > self.indentation.getLast()) {
                        token_tag = .indentation;
                        self.indentation.append(indentation) catch unreachable;
                    } else if (indentation == self.indentation.getLast()) {
                        token_tag = .newline;
                    } else {
                        token_tag = .dedentation;

                        _ = self.indentation.pop();

                        if (indentation < self.indentation.getLast()) {
                            self.offset = token_start;
                            break;
                        }
                    }

                    continue;
                },
                },
            }

        self.offset += 1;
    }

    return Token {
        .start = token_start,
        .end = self.offset,
        .tag = token_tag,
    };
}
pub const Token = struct {
    start: usize,
    end: usize,
    tag: Tag,

    pub const Tag = enum {
        plus,
        minus,
        asterix,
        slash,
        percent,
        less,
        greater,
        less_equals,
        greater_equals,
        equals,
        double_equals,
        not_equals,
        left_parenthesis,
        right_parenthesis,
        comma,

        integer,
        float,
        string,

        identifier,
        indentation,
        dedentation,
        newline,
        eof,
    };
};


test "test" {
    const source = 
        \\hello
        \\  if
        \\    dude
        \\  else
        \\    dude2
        \\    if dude3
        \\      x
        \\
        \\
        \\
        \\hello
    ;
    std.debug.print("{s}\n", .{source});
    var tokenizer = @This().init(source, std.testing.allocator);
    defer tokenizer.deinit();
    var token = tokenizer.next();
    while (token.tag != .eof) {
        std.debug.print("{d}\n", .{tokenizer.indentation.items});
        std.debug.print("{any}\n", .{token.tag});
        std.debug.print("\"{s}\"\n", .{source[token.start..token.end]});
        token = tokenizer.next();
    }
}
