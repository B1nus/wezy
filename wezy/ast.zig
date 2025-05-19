const std = @import("std");

pub const Ast = struct {
    statements: std.ArrayList(Statement),
    fields: std.ArrayList(Field),
    values: std.ArrayList(Value),
    types: std.ArrayList(Type),
};

pub fn init(allocator: std.mem.Allocator) Ast {
    return .{
        .statements = std.ArrayList(Statement).init(allocator),
        .fields = std.ArrayList(Field).init(allocator),
        .values = std.ArrayList(Value).init(allocator),
        .types = std.ArrayList(Type).init(allocator),
    };
}

pub fn deinit(this: @This()) void {
    this.statements.deinit();
    this.fields.deinit();
    this.values.deinit();
    this.types.deinit();
}

pub fn appendStatement(this: @This(), statement: Statement) !usize {
    try this.statements.append(statement);
    return this.statements.items.len - 1;
}

pub fn appendField(this: @This(), field: Field) !usize {
    try this.fields.append(field);
    return this.fields.items.len - 1;
}

pub fn appendValue(this: @This(), value: Value) !usize {
    try this.values.append(value);
    return this.values.items.len - 1;
}

pub fn appendType(this: @This(), @"type": Type) !usize {
    try this.types.append(@"type");
    return this.types.items.len - 1;
}

const Name = []const u8;
const Path = []const u8;

const Call = struct {
    name: Name,
    args: Value.List,
};

const Field = union(enum) {
    name: Name,
    type: ?Type,

    pub const Index = u64;

    pub const List = struct {
        start_index: Index,
        len: Index,
    };
};

pub const Statement = union(enum) {
    set: Set,
    init: Init,
    call: Call,
    func: Func,
    record: Record,
    variant: Variant,
    @"if": If,
    repeat: Repeat,
    @"break": ?Name,
    @"continue": ?Name,
    use: Use,

    pub const If = struct {
        condition: Value,
        success: List,
        failure: List,
    };

    pub const Repeat = struct {
        name: ?Name,
        times: ?Times,
        body: List,

        pub const Times = u64;
    };

    pub const Init = struct {
        name: Name,
        type: Type,
    };

    pub const Set = struct {
        name: Name,
        type: ?Type,
        value: Value,
    };

    pub const Func = struct {
        name: Name,
        params: Type.List,
        result: Type.List,
        body: List,
    };

    pub const Index = u64;
    
    pub const List = struct {
        start_index: Index,
        len: Index,
    };

    pub const Record = struct {
        name: Name,
        types: Field.List,
    };

    pub const Variant = struct {
        name: Name,
        types: Field.List ,
    };

    pub const Use = struct {
        path: Path,
        alias: Name,
    };
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
    f32,
    f64,
    bool,
    list: Index,
    set: Index,
    map: [2]Index,
    optional: Index,
    result: [2]Index,
    record: Name,
    variant: Name,

    const Index = u64;

    const List = struct {
        start_index: Index,
        len: Index,
    };
};

pub const Value = union(enum) {
    name: Name,
    integer: Integer,
    float: Float,
    bool: bool,
    string: String,
    list: List,
    set: List,
    map: List,
    add: [2]Index,
    sub: [2]Index,
    mul: [2]Index,
    div: [2]Index,
    rem: [2]Index,
    pow: [2]Index,
    lt: [2]Index,
    gt: [2]Index,
    le: [2]Index,
    ge: [2]Index,
    eq: [2]Index,
    ne: [2]Index,
    @"and": [2]Index,
    @"or": [2]Index,
    @"not": Index,
    call: Call,
    record: Record,
    variant: Variant,

    const Index = u64;

    const Integer = []const u8;
    const Float = []const u8;
    const String = []const u8;

    const List = struct {
        start_index: Index,
        len: Index,
    };

    const Record = struct {
        name: Name,
        values: List,
    };

    const Variant = struct {
        name: Name,
        value: Index,
    };
};
