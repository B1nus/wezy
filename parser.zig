const std = @import("std");
const List = std.ArrayList;
const Number = usize;
const assert = std.debug.assert;

const Token = struct {
    start: Number,
    end: Number,
    type: TokenType,
};

const TokenType = enum {
    equals, // do we really need a double equals?
    number,
    keyword_number,
    keyword_bool,
    plus,
    minus,
    slash,
    caret,
    percent,
    asterix,
    eof,
    indentation,
    dedentation,
    newline,
    left_parenthesis,
    right_parenthesis,
    left_bracket,
    right_bracket,
    left_brace,
    right_brace,
    comment,
    comma,
    dot,
    keyword_if,
    keyword_else,
    keyword_true,
    keyword_false,
    keyword_return,
    keyword_bundle,
    keyword_choice,
    type_identifier,
    identifier,
    string, // do we really need a char type?
};

const keywords = std.StaticStringMap(TokenType).initComptime(.{
    .{ "if", .keyword_if },
    .{ "else", .keyword_else },
    .{ "return", .keyword_return },
    .{ "bundle", .keyword_bundle },
    .{ "choice", .keyword_choice },
    .{ "true", .keyword_true },
    .{ "false", .keyword_false },
    .{ "Number", .keyword_number },
    .{ "Bool", .keyword_bool },
});

const TokenParserState = enum {
    start,
    type_identifier,
    identifier,
    start_integer,
    indentation,
    integer,
    float,
    slash,
    comment,
    string,
};

const Tokenizer = struct {
    source: []const u8,
    index: Number,
    indentation_stack: *List(Number),
};

pub fn new_tokenizer(source: []const u8) Tokenizer {
    var indentation_stack = List(Number).init(std.heap.page_allocator);
    indentation_stack.append(0) catch unreachable;
    return Tokenizer {
        .source= source,
        .index = 0,
        .indentation_stack = indentation_stack,
    };
}

pub fn next_token(tokenizer: *Tokenizer) Token {
    var token_start: Number = tokenizer.index.*;
    var token_type: ?TokenType = null;
    var state = TokenParserState.start;

    while (token_type == null) {
        if (tokenizer.index >= tokenizer.source.len) {
            return Token{ .start = token_start, .end = token_start, .type = .eof };
        }
        const c = tokenizer.source[tokenizer.index];
        switch (state) {
            .start => switch (c) {
                '\"' => state = .string,
                ' ', '\r', '\t' => token_start += 1,
                '\n' => state = .indentation,
                'A'...'Z' => state = .type_identifier, // CamelCase
                'a'...'z' => state = .identifier, // snake_case
                '_' => unreachable,
                '0' => state = .start_integer, // 0x0fb or 0b001
                '1'...'9' => state = .integer,
                '=' => token_type = .equals,
                '+' => token_type = .plus,
                '-' => token_type = .minus,
                '/' => state = .slash,
                '*' => token_type = .asterix,
                '^' => token_type = .caret,
                '%' => token_type = .percent,
                ',' => token_type = .comma,
                '.' => token_type = .dot,
                '(' => token_type = .left_parenthesis,
                ')' => token_type = .right_parenthesis,
                '[' => token_type = .left_bracket,
                ']' => token_type = .right_bracket,
                '{' => token_type = .left_brace,
                '}' => token_type = .right_brace,
                else => unreachable,
            },
            .slash => switch (c) {
                '/' => state = .comment,
                else => {
                    token_type = .slash;
                    continue;
                },
            },
            .comment => switch (c) {
                '\n' => {
                    // token_type = .comment;
                    // continue;
                    
                    state = .start;
                    token_start = tokenizer.index;
                },
                else => {},
            },
            .start_integer => switch (c) {
                'x', 'b', 'o' => state = .integer,
                else => {
                    token_type = .number;
                    continue;
                },
            },
            .integer => switch (c) {
                '0'...'9' => {},
                '.' => state = .float,
                else => {
                    token_type = .number;
                    continue;
                },
            },
            .float => switch (c) {
                '0'...'9' => {},
                '.' => unreachable,
                else => {
                    token_type = .number;
                    continue;
                },
            },
            .identifier => switch (c) {
                'a'...'z', '0'...'9', '_' => {},
                'A'...'Z' => unreachable,
                else => {
                    if (keywords.get(tokenizer.source[token_start..tokenizer.index])) |keyword| {
                        token_type = keyword;
                    } else {
                        token_type = .identifier;
                    }
                    continue;
                },
            },
            .type_identifier => switch (c) {
                'A'...'Z', 'a'...'z' => {},
                '0'...'9' => unreachable,
                else => {
                    if (keywords.get(tokenizer.source[token_start..tokenizer.index])) |keyword| {
                        token_type = keyword;
                    } else {
                        token_type = .type_identifier;
                    }
                    continue;
                },
            },
            .string => switch (c) {
                '\"' => token_type = .string,
                else => {},
            },
            .indentation => switch (c) {
                ' ', '\r', '\t' => {},
                '\n' => token_start = tokenizer.index,
                else => {
                    var last_indentation = tokenizer.indentation_stack.getLast();
                    const indentation = tokenizer.index - token_start - 1;

                    if (indentation > last_indentation) {
                        tokenizer.indentation_stack.append(indentation) catch unreachable;
                        token_type = .indentation;
                    } else if (indentation < last_indentation) {
                        _ = tokenizer.indentation_stack.pop();
                        last_indentation = tokenizer.indentation_stack.getLast();
                        if (indentation < last_indentation) {
                            tokenizer.index = token_start;
                        } else {
                            assert(indentation == last_indentation);
                        }
                        token_type = .dedentation;
                    } else {
                        token_type = .newline;
                    }
                    continue;
                },
            },
        }
        tokenizer.index += 1;
    }

    return Token{ .start = token_start, .end = tokenizer.index, .type = token_type.? };
}

pub fn peek_next_token(tokenizer: *Tokenizer) Token {
    const mem = tokenizer.index;
    const token = next_token(tokenizer);
    tokenizer.index = mem;
    return token;
}

pub const Type = enum(Number) {
    empty, // Type
    identifier, // Type, TokenStart, TokenEnd

    binding, // Type, TypeExp, String, Exp, NextStmt
    assignment, // Type, String, Exp, NextStmt
    call, // Type, String, Length, Expression, Expression, ..., NextStmt
    function, // Type, TypeExp, String, Length, TypeExp, String, TypeExp, String, ..., NextStmt
    @"return", // Type, Exp,
    @"if", // Type, Exp, SuccessStmt, FailureStmt
    choice, // Type, String, Length, String, String, ...
    bundle, // Type, String, Length, TypeExp, String, TypeExp, String, ...

    list, // Type, Length, Exp, Exp, ...
    string, // Type, String
    character, // Type, String
    map, // Type, Length, Exp, Exp, Exp, Exp, ...
    set, // Type, Length, Exp, Exp, Exp, ...
    number, // Type, String
    true, // Type
    false, // Type
    negate, // Type, Exp,
    add, // Type, Exp, Exp,
    subtract, // Type, Exp, Exp,
    multiply, // Type, Exp, Exp,
    divide, // Type, Exp, Exp,
    power, // Type, Exp, Exp,
    modulus, // Type, Exp, Exp,
    equality, // Type, Exp, Exp,
    inequality, // Type, Exp, Exp,
    less_or_equals, // Type, Exp, Exp,
    less, // Type, Exp, Exp,
    greater_or_equals, // Type, Exp, Exp,
    greater, // Type, Exp, Exp,

    number_type, // Type
    bool_type, // Type
    list_type, // Type, Length, TypeExp, TypeExp, ...
    map_type, // Type, Length, TypeExp, TypeExp, TypeExp, TypeExp, ...
    set_type, // Type, Length, TypeExp, TypeExp, ...
};

pub fn parse_statement(tokenizer: *Tokenizer, data: *List(Number)) Number {
    var token = peek_next_token(tokenizer);
    switch (token.tag) {
        .left_bracket, .left_brace, .type_identifier, .keyword_number, .keyword_bool => {
            const type_index = parse_type_expression(tokenizer, data);
        },
        .identifier => {

        },
        .keyword_if => {},
        .keyword_return => {},
        .keyword_bundle => {
            token = next_token(tokenizer);
            const type_identifier_start = token.start;
            const type_identifier_end = token.end;
        },
        .keyword_choice => {},
    }
}

pub fn parse_expression(tokenizer: *Tokenizer, data: *List(Number)) Number {

}

pub fn parse_infix_expression(tokenizer: *Tokenizer, data: *List(Number)) Number {

}

pub fn parse_prefix_expression(tokenizer: *Tokenizer, data: *List(Number)) Number {

}

pub fn parse_type_expression(tokenizer: *Tokenizer, data: *List(Number)) Number {
    const token = next_token(tokenizer);
    const index = data.items.len;

    switch (token.tag) {
        .number => {
            data.append(@intFromEnum(Type.number)) catch unreachable;
            data.append(token.start) catch unreachable;
            data.append(token.end) catch unreachable;
        },
        .keyword_true => data.append(@intFromEnum(Type.true)) catch unreachable,
        .keyword_false => data.append(@intFromEnum(Type.false)) catch unreachable,
        .left_bracket => {

        },
    }

    return index;
}

test "tokens" {
    const source =
        \\Hello no
        \\// Balls
        \\  at all
        \\    double indentation
        \\      triple indentation
        \\  double dedentation
        \\
        \\end
    ;
    var tokenizer = new_tokenizer(source);
    var token = next_token(&tokenizer);

    while (token.type != .eof) {
        std.debug.print("{any} \"{s}\"\n", .{ token.type, source[token.start..token.end] });
        token = next_token(&tokenizer);
    }

    indentation_stack.deinit();
}
