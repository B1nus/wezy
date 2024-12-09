const std = @import("std");
const ally = std.heap.page_allocator;

pub const Error = struct {
    line: u32,
    start: u32,
    end: u32,
    tag: Tag,

    pub const Tag = enum {
        IncorrectIndentation,
    };
};

pub const Token = struct {
    start: u32,
    end: u32, // Inclusive
    tag: Tag,

    pub const keywords = std.StaticStringMap(Tag).initComptime(.{
        .{ "if", .keyword_if },
        .{ "else", .keyword_else },
        .{ "return", .keyword_return },
        // etc...
    });

    pub const Tag = enum {
        // Predefined contents
        newline,
        comma,
        identifier,
        keyword_if,
        keyword_else,
        keyword_return,
        // For float and integer type literals. I.E. i64, i128, ... and f32, f64. I don't quite know how to do this yet.
        // keyword_integer_type
        // keyword_float_type
        dot,
        minus,
        equal,
        slash,
        // I want to try this out, it might be a total failure. but there is only one way to find out.
        // double_equal,

        // No content
        eof,
        // No interesting content
        indentation,
        dedentation,

        // Different contents
        integer,
        float,
        invalid,
        comment,
        string,
        // hexadicmal_integer,
        // binary_integer,
        // etc...

        // Some tokens should ideally have no size, how about separating these two groups? It might be considered overengineering though. Let's keep thins simple for now.
    };
};

// Super simple compiler. Compiles line by line directly into Webassembly. A onepass compiler.

pub fn main() !void {
    const path = std.mem.span(std.os.argv[1]);
    const file = try std.fs.cwd().openFile(path, .{});
    const data = try file.readToEndAllocOptions(ally, 0xFFFFFFFF, null, 8, 0);
    std.debug.print("{s}\n", .{data});
    std.debug.print("{d}\n", .{data[data.len]});
    var indent_stack = std.ArrayList(u32).init(ally);
    try indent_stack.append(0);
    // var errors = std.ArrayList(Error).init(ally);

    // var line_number: u32 = 0;
    // while (lines.next()) |line_| : (line_number += 1) {
    //     // The tokens on this line
    //     var tokens = std.ArrayList(Token).init(ally);
    //     defer tokens.deinit();
    //
    //     // Indentation Logic
    //     std.debug.print("indentation for \"{s}\"", .{line_});
    //     const indent = indentation(line_);
    //     std.debug.print(" is {d}\n", .{indent});
    //     if (indent > indent_stack.getLast()) {
    //         try tokens.append(Token{ .start = indent_stack.getLast(), .end = indent, .tag = Token.Tag.indentation });
    //         try indent_stack.append(indent);
    //     } else {
    //         while (indent < indent_stack.getLast()) {
    //             _ = indent_stack.pop();
    //             try tokens.append(Token{ .start = 0, .end = 0, .tag = Token.Tag.dedentation });
    //         }
    //         if (indent != indent_stack.getLast()) {
    //             try errors.append(Error{ .line = line_number, .start = 0, .end = indent - 1, .tag = Error.Tag.IncorrectIndentation });
    //             try indent_stack.append(indent);
    //         }
    //     }
    //
    //     const line = std.mem.trimRight(u8, line_[indent..], "\n\r\t ");
    //     var token = next_token(line, 0, State.start);
    //     var index: u32 = token.end + 1;
    //     while (token.tag != Token.Tag.newline) {
    //         if (token)
    //         try tokens.append(token);
    //         token = next_token(line, index);
    //         index = token.end + 1;
    //     }
    //     std.debug.print("The line gives these tokens: ", .{});
    //     print_tokens_pretty(tokens.items);
    // }
}

fn print_tokens_pretty(tokens: []Token) void {
    for (tokens) |token| {
        std.debug.print("{s}({d}..{d}) ", .{ @tagName(token.tag), token.start, token.end });
    }
    std.debug.print("\n", .{});
}

const State = enum {
    start,
    slash,
    minus,
    float,
    integer,
    identifier,
    invalid,
    string,
    indentation,
};

// Returns a newline token when done. Can only handle ascii currently but is planned to support utf-8 soon.
pub fn next_token(buffer: [:0]const u8, index_: u32, indentation_stack: std.ArrayList(u32)) Token {
    var index = index_;
    var token = Token{ .start = index, .end = index, .tag = undefined };
    if (index_ == 0 or buffer[index_ - 1] == '\n') {
        // TODO: Calculate indentation here.
        unreachable;
    }
    state: switch (State.start) {
        .start => {
            if (index >= line.len) {
                token.tag = Token.Tag.newline;
                index = @intCast(line.len + 1); // Needs to match the index of the other cases.
            } else {
                switch (line[index]) {
                    ' ', '\t', '\r' => {
                        index += 1;
                        continue :state .start;
                    },
                    // The ... syntax is usefull. but crust has 0 < x < 10 which is even better. A no brainer really.
                    //
                    // Add capital letters later. But I think it's better without them.
                    // There's less to argue about if the language forces you to do it a certain way.
                    // Programmers can waste less time discussing code asthetics. Something which
                    // does not matter yet we seem to speak about it a lot.
                    'a'...'z', '_' => continue :state .identifier,
                    // add underscores, and hexadecimal and binary later.
                    // floats starting with only a decimal point is not allowed
                    '0'...'9' => continue :state .integer,
                    ',' => token.tag = Token.Tag.comma,
                    '.' => token.tag = Token.Tag.dot, // NOTE: .0 is not a valid float.
                    '=' => token.tag = Token.Tag.equal,
                    '-' => continue :state .minus,
                    '/' => continue :state .slash,
                    '\n' => token.tag = Token.Tag.newline,
                    '\"' => continue :state .string,
                    else => continue :state .invalid,
                }
                index += 1; // Adding one to match with the other states. We always finish with the index pointing at the next byte.
            }
        },
        .string => {
            index += 1;
            switch (line[index]) {
                0 => {
                    token.tag = invalid;

                }
            }
            if (line[index] == 0) {
                index -= 1;
                continue :state .invalid;
            } else if (line) {
                
            }
        },
        // Notice the lack of capital letters.
        .identifier => {
            index += 1;
            switch (line[index]) {
                'a'...'z', '_', '0'...'9' => continue :state .identifier,
                else => if (Token.keywords.get(line[token.start..index])) |keyword| {
                    // TODO: Check for types. I.E. i64, i128, i256 ... f64, f32, [any], {any:any} etc...
                    token.tag = keyword;
                } else {
                    token.tag = Token.Tag.identifier;
                },
            }
        },
        .minus => {
            index += 1;
            switch (line[index]) {
                '0'...'9' => continue :state .integer,
                else => token.tag = .minus,
            }
        },
        .slash => {
            index += 1;
            switch (line[index]) {
                '/' => {
                    // The rest of this line is a comment
                    index = @intCast(line.len); // make the index point at the end. All other cases do this already.
                    token.tag = Token.Tag.comment;
                },
                else => token.tag = Token.Tag.slash,
            }
        },
        .integer => {
            index += 1;
            switch (line[index]) {
                '0'...'9' => continue :state .integer,
                '.' => continue :state .float,
                else => token.tag = .integer,
            }
        },
        .float => {
            index += 1;
            switch (line[index]) {
                '0'...'9' => continue :state .float,
                else => token.tag = Token.Tag.float,
            }
        },
        .invalid => {
            token.tag = Token.Tag.invalid;
            index += 1;
            if (line[index] == 0 or line[index] == '\n') break :state; 
            continue :state .invalid;
        },
    }
    token.end = index - 1;
    return token;
}

// Don't forget these design decisions:
// One indexed
// Inclusive Ranges. 1..5 = [1,2,3,4,5]
// Chained booleans. 0 < x < 10
// Only snake_case
// No float shorthand. Write: 0.0 not: .0
// Single equals for comparisons. if x = 5
// Utf-8 for everything. no exceptions.

// Indentation means ( in wat
// Dedentation means ) in wat

pub fn indentation(line: []const u8) u32 {
    for (line, 0..) |c, i| {
        switch (c) {
            ' ', '\t', '\r' => continue,
            else => return @intCast(i),
        }
    }
    return 0;
}
