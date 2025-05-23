const std = @import("std");
const List = std.ArrayList;

pub const Block = List(Statement);

pub const Statement = union(enum) {
    function: Function,
    @"return": List(Value),
    @"continue": ?[]const u8,
    @"break": ?[]const u8,
    variant: Variant,
    record: Record,
    repeat: Repeat,
    assign: Assign,
    bind: Bind,
    use: Use,
    @"if": If,
};

pub const Function = struct {
    name: []const u8,
    parameters: List([]const u8),
    type: FunctionType,
    body: Block,
};

pub const Use = struct {
    path: []const u8,
    alias: ?[]const u8,
};

pub const Repeat = struct {
    label: ?[]const u8,
    value: ?Value, // Allow booleans for while loops?
    body: Block,
};

pub const If = struct {
    condition: Value,
    success: Block,
    failure: Block,
};

pub const Bind = struct {
    names: List([]const u8),
    type: Type,
};

pub const Assign = struct {
    names: List(Name),
    types: List(Type),
    values: List(Value),
};

pub const Record = struct {
    name: []const u8,
    fields: List([]const u8),
    values: List(Type),
};

pub const Variant = struct {
    name: []const u8,
    fields: List([]const u8),
    values: List(?Type),
};

pub const Name = struct {
    name: []const u8,
    field: List([]const u8),
};

pub const ListValue = List(Value);
pub const SetValue = List(Value);
pub const MapValue = List([2]Value);
pub const VariantValue = struct {
    variant: Name,
    field: []const u8,
    value: *Value,
};
pub const RecordValue = struct {
    record: Name,
    fields: List([]const u8),
    values: List(Value),
};
pub const BinaryValue = [2]*Value;
pub const UnaryValue = *Value;

pub const Value = union(enum) {
    integer: u64,
    float: f64,
    string: List(u8),
    char: u21,
    bool: bool,
    @"and": BinaryValue,
    @"or": BinaryValue,
    @"xor": BinaryValue,
    not: UnaryValue,
    negative: UnaryValue,
    positive: UnaryValue,
    addition: BinaryValue,
    subtraction: BinaryValue,
    multiplication: BinaryValue,
    division: BinaryValue,
    exponentiation: BinaryValue,
    remainder: BinaryValue,
    shift_left: BinaryValue,
    shift_right: BinaryValue,
    less: BinaryValue,
    more: BinaryValue,
    less_equal: BinaryValue,
    more_equal: BinaryValue,
    equal: BinaryValue,
    not_equal: BinaryValue,
    list: ListValue,
    set: SetValue,
    map: MapValue,
    name: Name,
    variant: VariantValue,
    record: RecordValue,
    invalid,
};

pub const ListType = *Type;
pub const SetType = *Type;
pub const MapType = [2]*Type;
pub const FunctionType = struct {
    this: ?[]const u8,
    parameters: List(Type),
    result: List(Type),
};

pub const Type = union(enum) {
    s8,
    s16,
    s32,
    s64,
    u8,
    u16,
    u32,
    u64,
    bool,
    set: SetType,
    map: MapType,
    list: ListType,
    name: Name,
    function: FunctionType,
};

test {
    const allocator = std.heap.c_allocator; // I don't care about leaks. fuck of
    var block = Block.init(allocator);

    var function = Function {
        .name = "do_thing",
        .parameters = List([]const u8).init(allocator),
        .type = FunctionType {
            .this = null,
            .parameters = List(Type).init(allocator),
            .result = List(Type).init(allocator),
        },
        .body = List(Statement).init(allocator),
    };

    const item_type = try allocator.create(Type);

    const list = Type { .list = item_type };
    try function.type.parameters.append(list);
    try function.type.parameters.append(Type { .function = function.type });

    try block.append(Statement { .function = function });
}
