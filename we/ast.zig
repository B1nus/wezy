const std = @import("std");
const List = std.ArrayList;
const Index = u64;

pub fn init(allocator: std.mem.Allocator) Ast {
    return .{
        .statements = List(Statement).init(allocator),
        .values = List(Value).init(allocator),
        .types = List(Type).init(allocator),
    };
}

const Ast = struct {
    statements: List(Statement),
    values: List(Value),
    types: List(Type),
};

const Statement = union(enum) {
    init: Init,
    set: Set,
    function: Function,

    fn deinit(this: @This()) void {
        if (this == .function) {
            this.function.parameters.deinit();
            this.function.resutl.deinit();
            this.function.statements.deinit();
        } else if (this == .set) {
            this.set.variables.deinit();
        } else if (this == .init) {
            this.init.variables.deinit();
        }
    }

    const Init = struct {
        variables: List(Item),

        const Item = struct {
            name: []const u8,
            type: Type,
        };
    };

    const Set = struct {
        variables: List(?Item),
        value: Value,

        const Item = struct {
            name: []const u8,
            type: ?Type,
        };
    };

    const Function = struct {
        name: []const u8,
        parameters: List(Parameter),
        result: List(Type),
        statements: List(Statement),

        const Parameter = struct {
            name: []const u8,
            type: Type,
        };
    };
};

const Type = union(enum) {
    s8,
    s16,
    s32,
    s64,
    u8,
    u16,
    u32,
    u64,
    bool,
    list: Index,
    set: Index,
    map: [2]Index,
    function: Function,

    const Function = struct {
        parameters: List(Type),
        result: List(Type),
    };
};

const Value = union(enum) {
    integer: []const u8,
    float: []const u8,
    string: []const u8,
    char: []const u8,
    list: List(Value),
    set: List(Value),
    map: List(Value),
    call: Call,
    function: Function,

    const Call = struct {
        name: []const u8,
        arguments: List(Value),
    };

    const Function = struct {
        statements: List(Statement),
        parameters: List(Parameter),
        result: List(Type),

        const Parameter = struct {
            name: []const u8,
            type: Type,
        };
    };
};
