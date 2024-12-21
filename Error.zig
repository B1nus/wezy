pub const TokenIndex = u32;

start: TokenIndex,
end: TokenIndex,
tag: Tag,

pub const Tag = enum {
    multiple_assign, // x, y = ...
    multiple_assign_no_comma, // x y = ...
    multiple_assign_tuple, // (x, y) = ...
    missing_rhs, // 5 + 6 +
    adjacent_infix, // 5 + + + 6
    missing_expression, // x =
    adjacent_intergers, // 6 + 5 7 + 4
    missing_end_parenthesis, // (6 + 5 + 4
    lonely_identifier, // x 6 + 5
};
