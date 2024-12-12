const std = @import("std");
// This is where we put everything together. We take an ast from parser.zig and turn it into webassembly bytecode.
//
// We handle errors not related to syntax, but the meaning of the code. For example type checks, and borrow checking.

pub const Error = struct {
    start: u32,
    end: u32,
    tag: Tag,

    pub const Tag = enum {
        UnexpectedIndentation,
        IncorrectDedentation,
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

    // Check if the string is a type. that is i32, i64, ...  f32, f64, [any] and {any:any}.
    //
    // Hmmm... should we include i0 as a void type? Or how about just not adding a void type.
    // I'd add it mostly to be able to make sets with my maps. Maybe it's better to just add
    // sets instead if I'm going to add a new abstraction anyway. I'm torn atm.
    pub fn is_type(literal: []const u8) ?Tag {
        if (literal.len < 2) return null;
        switch (literal[0]) {
            'i' => {
                const num = std.fmt.parseInt(u32, literal[1..], 10) catch {
                    return null;
                };
                // This include i0. I don't know if I want this yet.
                if (num & (num - 1) == 0) {
                    return .integer_type;
                } else {
                    return null;
                }
            },
            'f' => {
                if (literal.len == 3 and ((literal[1] == '3' and literal[2] == '2') or (literal[1] == '6' and literal[2] == '4'))) {
                    return .float_type;
                } else {
                    return null;
                }
            },
            else => return null,
        }
    }

    pub const Tag = enum {
        // Predefined contents
        newline,
        comma,
        identifier,
        keyword_if,
        keyword_else,
        keyword_return,
        // For float and integer type literals. I.E. i64, i128, ... and f32, f64. I don't quite know how to do this yet.
        dot,
        minus,
        equal,
        slash,
        lparen, // (
        rparen, // )
        lbrace, // {
        rbrace, // }
        lbracket, // [
        rbracket, // ]
        // I want to try this out, it might be a total failure. but there is only one way to find out.
        // double_equal,

        // No content
        eof,
        // No interesting content
        indentation,
        dedentation,

        // Different contents
        integer_type,
        float_type,
        integer,
        float,
        // NOTE: Picking between byte and utf8 literal is done in parsing.
        // Also note that errors in byte/utf8 literals are handled while parsing.
        utf8,
        invalid,
        comment,
        string,
        // hexadicmal_integer,
        // binary_integer,
        // etc...

        // Some tokens should ideally have no size, how about separating these two groups? It might be considered overengineering though. Let's keep thins simple for now.
    };
};

// A pretty standard compiler. First we turn source into tokens, and then into an abstract syntax tree and then into bytecode.
//
// A lofty goal would be to make this into a onepass compiler. It's technically possible. But I don't quite know how
// to achieve it. Hopefully, there is a way to make this compiler much simpler. But for now, I'm gonna make the
// compiler the only way I know how.

pub fn main() !void {
    const path = std.mem.span(std.os.argv[1]);
    const file = try std.fs.cwd().openFile(path, .{});
    const data = try file.readToEndAllocOptions(ally, 0xFFFFFFFF, null, 8, 0); // Zero terminated string
    const tokens, const errors = try get_tokens(data, ally);
    print_tokens_pretty(tokens.items);
    std.debug.print("{any}", .{errors.items});
    // var wasm_functions = std.StringHashMap(u32).init(ally);
    // var wasm_locals = std.StringHashMap(u32).init(ally);
    // var wasm_code =
}

// TODO: Add js host imports
// TODO: Add start function
// TODO: Add lots of missing features
pub fn compile(source: [:0]const u8, allocator: std.mem.Allocator) !struct { std.ArrayList(u8), std.ArrayList(Error) } {
    const tokens, var errors = get_tokens(source, allocator);
    const ast = parse(tokens, allocator, &errors);


    var wasm_bytes = std.ArrayList(u8).init(allocator);
    // Magic number and webassembly version 1
    try wasm_bytes.appendSlice("\x00asm\x01\x00\x00\x00");
    try errors.append(Error {.start=0,.end=0,.tag=.IncorrectDedentation});

    return .{ wasm_bytes, errors };
}

pub const Wasm = struct {

};

pub const TokenIndex = u32;
pub const NodeIndex = u32;

// This is not an efficient way to store the ast. But it's the easiest way.
pub const Node = union(enum) {
    integer_literal: TokenIndex,
    float_literal: TokenIndex,
    integer_type: TokenIndex,
    float_type: TokenIndex,
    identifier: TokenIndex,
    // list_literal: ListLiteral,
};

pub const Parameter = struct {
    identifier: NodeIndex,
    _type: NodeIndex,
};

pub const Function = struct {
    params_start: NodeIndex,
    params_amount: NodeIndex,
    return_type: NodeIndex,
};

pub const Block = struct {
    statements: std.ArrayList(Statement),
};

pub const TupleLiteral = struct {
    literals_start: NodeIndex,
    literals_amount: NodeIndex,
};

pub const TypleType = struct {
    type_start: NodeIndex,
    type_amount: NodeIndex,
};

pub const ArrayLiteral = struct {
};

pub const Ast = struct {
    tokens: []Token,
    lhs: std.ArrayList(u32),
    rhs: std.ArrayList(u32),
    token: std.ArrayList(u32),
    tag: std.ArrayList(Tag),
    extra_data: std.ArrayList(u32),

    pub const Tag = enum {
        function_decl, // lhs points to function_proto, rhs points to function body
        function_proto,
        function_body,
        set_type, // {any}
        map_type, // {any:any}
        list_type, // [any]
        integer_type, // i8, i16, i32, i64 etc..
        float_type, // f32 or f64
        integer, // integer literal
        float, // float literal
        function_call,
    };
};

pub fn parse(tokens: []Token, allocator: std.mem.Allocator, errors: *std.ArrayList(Error)) !Ast {
    return Ast {
        .tokens = tokens,
    };
}

pub fn get_tokens(source: [:0]const u8, allocator: std.mem.Allocator) !struct { std.ArrayList(Token), std.ArrayList(Error) } {
    var errors = std.ArrayList(Error).init(allocator);
    const start_indent = indentation(source);
    if (start_indent != 0) {
        // This behaviour is up to change in the future. But it probably won't. Why would you have indentation at the top level anyway?
        try errors.append(Error{ .start = 0, .end = start_indent - 1, .tag = .UnexpectedIndentation });
    }
    var token = next_token(source, start_indent);

    var indent_stack = std.ArrayList(u32).init(allocator);
    defer indent_stack.deinit();
    try indent_stack.append(0);

    var tokens = std.ArrayList(Token).init(allocator);

    while (token.tag != Token.Tag.eof) {
        state: switch (token.tag) {
            .newline => {
                const indent = indentation(source[token.end + 1 ..]);
                const indent_start = token.end + 1;

                const next_token_ = next_token(source, indent_start + indent);
                if (next_token_.tag == .newline) {
                    // TODO: Check if this actually skips empty lines.

                    token = next_token_;
                    continue :state .newline;
                }

                // TODO: Check if this skips newlines on indentation and dedentation.
                if (indent > indent_stack.getLast()) {
                    token = next_token(source, indent_start + indent);
                    try tokens.append(Token{ .start = token.start, .end = token.start + indent + 1, .tag = .indentation });
                } else if (indent < indent_stack.getLast()) {
                    token = next_token(source, indent_start + indent);
                    var top_indent = indent_stack.getLast();
                    while (top_indent > indent) {
                        top_indent = indent_stack.pop();
                        try tokens.append(Token{ .start = indent_stack.getLast(), .end = top_indent, .tag = .dedentation });
                    }
                    if (top_indent != indent) {
                        try errors.append(Error{ .start = indent_start, .end = indent_start + indent - 1, .tag = .IncorrectDedentation });
                    }
                } else {
                    if (tokens.getLastOrNull() != null and tokens.getLastOrNull().?.tag != .newline) {
                        try tokens.append(token);
                    }
                }
                token = next_token_;
            },
            else => {
                try tokens.append(token);
                token = next_token(source, token.end + 1);
            },
        }
    }

    return .{ tokens, errors };
}

fn print_tokens_pretty(tokens: []Token) void {
    for (tokens) |token| {
        std.debug.print("{s}({d}..{d})\n", .{ @tagName(token.tag), token.start, token.end });
    }
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
    comment,
    utf8,
};

// Returns a newline token when done. Can only handle ascii currently but is planned to support utf-8 soon.
//
pub fn next_token(buffer: [:0]const u8, index_: u32) Token {
    var index = index_;
    var token = Token{ .start = index, .end = index, .tag = undefined };
    state: switch (State.start) {
        .start => {
            switch (buffer[index]) {
                0 => {
                    token.tag = Token.Tag.eof;
                    return token;
                },
                ' ', '\t', '\r' => {
                    index += 1;
                    token.start += 1;
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
                '(' => token.tag = Token.Tag.lparen,
                ')' => token.tag = Token.Tag.rparen,
                '=' => token.tag = Token.Tag.equal,
                '-' => continue :state .minus,
                '/' => continue :state .slash,
                '\n' => token.tag = Token.Tag.newline,
                '\"' => continue :state .string,
                '\'' => continue :state .utf8,
                // '{' => continue :state lbrace,
                // '[' => continue :state lbracket,
                // Don't forget about type literals [any] and {any:any} and {any} <-- a set.
                else => continue :state .invalid,
            }
            index += 1; // Adding one to match with the other states. We always finish with the index pointing at the next byte.
        },
        .utf8 => {
            index += 1;
            switch (buffer[index]) {
                0 => continue :state .invalid,
                '\'' => {
                    index += 1;
                    token.tag = .utf8;
                },
                else => continue :state .utf8,
            }
        },
        .string => {
            index += 1;
            switch (buffer[index]) {
                0 => token.tag = .invalid,
                '\"' => {
                    token.tag = .string;
                    index += 1;
                },
                else => continue :state .string,
            }
        },
        .identifier => {
            index += 1;
            switch (buffer[index]) {
                'a'...'z', '_', '0'...'9' => continue :state .identifier,
                else => if (Token.keywords.get(buffer[token.start..index])) |keyword| {
                    token.tag = keyword;
                } else if (Token.is_type(buffer[token.start..index])) |_type| {
                    token.tag = _type;
                } else {
                    token.tag = .identifier;
                },
            }
        },
        .minus => {
            index += 1;
            switch (buffer[index]) {
                '0'...'9' => continue :state .integer,
                else => token.tag = .minus,
            }
        },
        .slash => {
            index += 1;
            switch (buffer[index]) {
                '/' => continue :state .comment,
                else => token.tag = .slash,
            }
        },
        .comment => {
            index += 1;
            switch (buffer[index]) {
                '\n', 0 => token.tag = .comment,
                else => continue :state .comment,
            }
        },
        // Should we add integer literals with types?
        // Should we add undescores to improve readability for large integers and floats?
        //
        // TODO: hexadecimal integer literals
        // TODO: binary integer literals
        .integer => {
            index += 1;
            switch (buffer[index]) {
                '0'...'9' => continue :state .integer,
                '.' => continue :state .float,
                else => token.tag = .integer,
            }
        },
        // Note: a float starting with '.' is not valid. 0.0 is valid and .0 is not.
        .float => {
            index += 1;
            switch (buffer[index]) {
                '0'...'9' => continue :state .float,
                else => token.tag = .float,
            }
        },
        .invalid => {
            token.tag = Token.Tag.invalid;
            index += 1;
            if (buffer[index] == 0 or buffer[index] == '\n') break :state;
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
// No structs, use SoA. Manual (MultiArrayList)
// Multiline strings
// Sets {any}
// Error message for single equals "crust uses a single equals sign for comparisons. Remove one equals sign here."

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

// Test driven development is perfect here. I know the exact input and output just not how to get there.

const assert = std.testing.expect;
const t_ally = std.testing.allocator;
test "no empty lines at start" {
    const tokens, const errors = try get_tokens("\n\nx = 5", t_ally);
    defer tokens.deinit();
    defer errors.deinit();
    try assert(tokens.items[0].tag == .identifier);
    try assert(tokens.items[0].start == 2);
    try assert(tokens.items[0].end == 2);
    try assert(tokens.items[1].tag == .equal);
    try assert(tokens.items[1].start == 4);
    try assert(tokens.items[1].end == 4);
    try assert(tokens.items[2].tag == .integer);
    try assert(tokens.items[2].start == 6);
    try assert(tokens.items[2].end == 6);
    try assert(errors.items.len == 0);
}

test "no empty lines at start + unexpected indentation" {
    const tokens, const errors = try get_tokens("  \n\nx = 5", t_ally);
    defer tokens.deinit();
    defer errors.deinit();
    try assert(tokens.items[0].tag == .identifier);
    try assert(tokens.items[0].start == 4);
    try assert(tokens.items[0].end == 4);
    try assert(tokens.items[1].tag == .equal);
    try assert(tokens.items[1].start == 6);
    try assert(tokens.items[1].end == 6);
    try assert(tokens.items[2].tag == .integer);
    try assert(tokens.items[2].start == 8);
    try assert(tokens.items[2].end == 8);
    try assert(errors.items.len == 1);
    try assert(errors.items[0].tag == .UnexpectedIndentation);
    try assert(errors.items[0].start == 0);
    try assert(errors.items[0].end == 1);
}

test "no empty lines" {
    const tokens, const errors = try get_tokens("\n\nx = 5\n\n\ny=10", t_ally);
    defer tokens.deinit();
    defer errors.deinit();
    try assert(tokens.items[0].tag == .identifier);
    try assert(tokens.items[0].start == 2);
    try assert(tokens.items[0].end == 2);
    try assert(tokens.items[1].tag == .equal);
    try assert(tokens.items[1].start == 4);
    try assert(tokens.items[1].end == 4);
    try assert(tokens.items[2].tag == .integer);
    try assert(tokens.items[2].start == 6);
    try assert(tokens.items[2].end == 6);
    try assert(tokens.items[3].tag == .newline);
    try assert(tokens.items[3].start == 9);
    try assert(tokens.items[3].end == 9);
    try assert(tokens.items[4].tag == .identifier);
    try assert(tokens.items[4].start == 10);
    try assert(tokens.items[4].end == 10);
    try assert(tokens.items[5].tag == .equal);
    try assert(tokens.items[5].start == 11);
    try assert(tokens.items[5].end == 11);
    try assert(tokens.items[6].tag == .integer);
    try assert(tokens.items[6].start == 12);
    try assert(tokens.items[6].end == 13);
    try assert(errors.items.len == 0);
}

test "unexpected indentation" {
    const tokens, const errors = try get_tokens("  y = 5\n\nx = 5", t_ally);
    defer tokens.deinit();
    defer errors.deinit();

    try assert(tokens.items[0].tag == .identifier);
    try assert(tokens.items[0].start == 2);
    try assert(tokens.items[0].end == 2);
    try assert(tokens.items[1].tag == .equal);
    try assert(tokens.items[1].start == 4);
    try assert(tokens.items[1].end == 4);
    try assert(tokens.items[2].tag == .integer);
    try assert(tokens.items[2].start == 6);
    try assert(tokens.items[2].end == 6);
    try assert(tokens.items[3].tag == .newline);
    try assert(tokens.items[3].start == 8);
    try assert(tokens.items[3].end == 8);
    try assert(tokens.items[4].tag == .identifier);
    try assert(tokens.items[4].start == 9);
    try assert(tokens.items[4].end == 9);
    try assert(tokens.items[5].tag == .equal);
    try assert(tokens.items[5].start == 11);
    try assert(tokens.items[5].end == 11);
    try assert(tokens.items[6].tag == .integer);
    try assert(tokens.items[6].start == 13);
    try assert(tokens.items[6].end == 13);
    try assert(errors.items.len == 1);
    try assert(errors.items[0].tag == .UnexpectedIndentation);
    try assert(errors.items[0].start == 0);
    try assert(errors.items[0].end == 1);
}

test "add i32 function" {
    const wasm, const errors = try compile("i32 add(i32 x, i32 y)\n return x+y\nadd(4,-4)", t_ally);
    try assert(std.mem.eql(u8, wasm.items[0..8], "\x00asm\x01\x00\x00\x00"));
    try assert(errors.items.len == 0);
}
