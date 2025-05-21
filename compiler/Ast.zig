const std = @import("std");
const List = std.ArrayList;

pub fn init(allocator: std.mem.Allocator) @This() {
    return .{
        .main = List(u64).init(allocator),
        .statements = List(Statement).init(allocator),
        .values = List(Value).init(allocator),
        .types = List(Type).init(allocator),
    };
}

pub fn deinit(this: @This()) void {
    for (this.statements.items) |statement| {
        statement.deinit();
    }
    for (this.values.items) |value| {
        value.deinit();
    }
    for (this.types.items) |@"type"| {
        @"type".deinit();
    }
    this.main.deinit();
    this.statements.deinit();
    this.values.deinit();
    this.types.deinit();
}

main: List(u64),
statements: List(Statement),
values: List(Value),
types: List(Type),

pub fn addMainStatement(this: *@This(), statement: Statement) !void {
    const statement_index = try this.addStatement(statement);
    try this.main.append(statement_index);
}

pub fn addValue(this: *@This(), value: Value) !u64 {
    try this.values.append(value);
    return this.values.items.len - 1;
}

pub fn addStatement(this: *@This(), statement: Statement) !u64 {
    try this.statements.append(statement);
    return this.statements.items.len - 1;
}

pub fn addType(this: *@This(), @"type": Type) !u64 {
    try this.types.append(@"type");
    return this.types.items.len - 1;
}

pub fn render(this: @This(), writer: anytype) !void {
    for (this.main.items, 1..) |statement_index, i| {
        try this.statements.items[statement_index].render(this.statements.items, this.types.items, this.values.items, 0, writer);
        if (i < this.main.items.len) {
            try writer.print("\n", .{});
        }
    }
}

pub const Variable = struct {
    name: []const u8,
    fields: List([]const u8),

    pub fn render(this: @This(), writer: anytype) !void {
        try writer.writeAll(this.name);
        for (this.fields.items) |field| {
            try writer.writeByte('.');
            try writer.writeAll(field);
        }
    }

    pub fn init(allocator: std.mem.Allocator, name: []const u8) @This() {
        return .{
            .name = name,
            .fields = List([]const u8).init(allocator),
        };
    }

    pub fn deinit(this: @This()) void {
        this.fields.deinit();
    }
};

pub fn writeIndentation(indentation: usize, writer: anytype) !void {
    for (0..indentation) |_| {
        try writer.writeAll("    ");
    }
}

pub const Statement = union(enum) {
    function: Function,
    bind: Bind,
    assign: Assign,
    @"if": If,
    repeat: Repeat,
    @"break": ?[]const u8,
    @"continue": ?[]const u8,
    @"return": List(Value),
    use: Use,
    call: Call,
    variant: Variant,
    record: Record,

    pub fn render(this: @This(), statements: []Statement, types: []Type, values: []Value, indentation: usize, writer: anytype) !void {
        try writeIndentation(indentation, writer);
        if (this == .bind) {
            try this.bind.render(types, writer);
        } else if (this == .assign) {
            try this.assign.render(types, values, indentation, writer);
        } else if (this == .function) {
            try this.function.render(statements, types, values, indentation, writer);
        } else if (this == .@"if") {
            try this.@"if".render(statements, types, values, indentation, writer);
        } else if (this == .repeat) {
            try this.repeat.render(statements, types, values, indentation, writer);
        } else if (this == .@"break") {
            try writer.writeAll("break");
            if (this.@"break" != null) {
                try writer.print(" {s}", .{ this.@"break".? });
            }
        } else if (this == .@"continue") {
            try writer.writeAll("continue");
            if (this.@"break" != null) {
                try writer.print(" {s}", .{ this.@"continue".? });
            }
        } else if (this == .@"return") {
            try writer.writeAll("return");
            if (this.@"return".items.len > 0) {
                try writer.writeByte(' ');
                for (this.@"return".items, 1..) |value, i| {
                    try value.render(values, indentation, writer);
                    if (i < this.@"return".items.len) {
                        try writer.writeAll(", ");
                    }
                }
            }
        } else if (this == .use) {
            try this.use.render(writer);
        } else if (this == .call) {
            try this.call.render(values, indentation, writer);
        } else if (this == .record) {
            try this.record.render(statements, types, values, indentation, writer);
        } else if (this == .variant) {
            try this.variant.render(statements, types, values, indentation, writer);
        }
    }

    pub fn deinit(this: @This()) void {
        if (this == .function) {
            this.function.deinit();
        } else if (this == .bind) {
            this.bind.deinit();
        } else if (this == .assign) {
            this.assign.deinit();
        } else if (this == .repeat) {
            this.repeat.deinit();
        } else if (this == .call) {
            this.call.deinit();
        } else if (this == .variant) {
            this.variant.deinit();
        } else if (this == .record) {
            this.record.deinit();
        } else if (this == .@"if") {
            this.@"if".deinit();
        }
    }

    pub const Function = struct {
        name: []const u8,
        parameters: List(Parameter),
        result: List(Type),
        body: List(u64),

        pub fn render(this: @This(), statements: []Statement, types: []Type, values: []Value, indentation: u64, writer: anytype) anyerror!void {
            try writer.print("function {s}(", .{ this.name });
            for (this.parameters.items, 1..) |parameter, i| {
                try parameter.render(types, writer);
                if (i < this.parameters.items.len) {
                    try writer.writeAll(", ");
                }
            }
            try writer.writeByte(')');
            if (this.result.items.len > 0) {
                try writer.writeByte(' ');
                for (this.result.items, 1..) |result, i| {
                    try result.render(types, writer);
                    if (i < this.result.items.len) {
                        try writer.writeAll(", ");
                    }
                }
            }
            if (this.body.items.len > 0) {
                try writer.writeByte('\n');
                for (this.body.items, 1..) |statement_index, i| {
                    try statements[statement_index].render(statements, types, values, indentation + 1, writer);
                    if (i < this.body.items.len) {
                        try writer.print("\n", .{});
                    }
                }
            }
        }

        pub fn init(allocator: std.mem.Allocator, name: []const u8) @This() {
            return .{
                .name = name,
                .parameters = List(Parameter).init(allocator),
                .result = List(Type).init(allocator),
                .body = List(u64).init(allocator),
            };
        }

        pub fn deinit(this: @This()) void {
            this.parameters.deinit();
            this.result.deinit();
            this.body.deinit();
        }

        pub const Parameter = struct {
            name: []const u8,
            type: Type,

            pub fn render(this: @This(), types: []Type, writer: anytype) !void {
                try writer.print("{s} ", .{ this.name });
                try this.type.render(types, writer);
            }
        };
    };

    pub const Bind = struct {
        names: List([]const u8),
        type: Type,

        pub fn render(this: @This(), types: []Type, writer: anytype) !void {
            for (this.names.items, 1..) |name, i| {
                try writer.writeAll(name);
                if (i < this.names.items.len) {
                    try writer.writeAll(", ");
                }
            }
            try writer.writeByte(' ');
            try this.type.render(types, writer);
        }

        pub fn init(allocator: std.mem.Allocator, @"type": Type) @This() {
            return .{
                .names = List([]const u8).init(allocator),
                .type = @"type",
            };
        }

        pub fn deinit(this: @This()) void {
            this.names.deinit();
            this.type.deinit();
        }
    };

    pub const Assign = struct {
        assignables: List(Assignable),
        values: List(Value),

        pub const Assignable = struct {
            name: ?Variable,
            type: ?Type,
        };

        pub fn render(this: @This(), types: []Type, values: []Value, indentation: u64, writer: anytype) !void {
            for (this.assignables.items, 1..) |assignable, i| {
                if (assignable.name == null) {
                    try writer.writeByte('_');
                } else {
                    try assignable.name.?.render(writer);
                }

                if (assignable.type != null) {
                    try writer.writeByte(' ');
                    try assignable.type.?.render(types, writer);
                }

                if (i < this.assignables.items.len) {
                    try writer.writeAll(", ");
                }
            }

            try writer.writeAll(" = ");

            for (this.values.items, 1..) |value, i| {
                try value.render(values, indentation, writer);

                if (i < this.assignables.items.len) {
                    try writer.writeAll(", ");
                }
            }
        }

        pub fn init(allocator: std.mem.Allocator) @This() {
            return .{
                .assignables = List(Assignable).init(allocator),
                .values = List(Value).init(allocator),
            };
        }

        pub fn deinit(this: @This()) void {
            for (this.assignables.items) |assignable| {
                if (assignable.name != null) {
                    assignable.name.?.deinit();
                }
                if (assignable.type != null) {
                    assignable.type.?.deinit();
                }
            }
            for (this.values.items) |value| {
                value.deinit();
            }
            this.assignables.deinit();
            this.values.deinit();
        }
    };

    pub const If = struct {
        condition: Value,
        success: List(u64),
        failure: List(u64),

        pub fn render(this: @This(), statements: []Statement, types: []Type, values: []Value, indentation: u64, writer: anytype) anyerror!void {
            try writer.writeAll("if ");
            try this.condition.render(values, indentation, writer);
            if (this.success.items.len > 0) {
                try writer.writeByte('\n');
                for (this.success.items, 1..) |statement_index, i| {
                    try statements[statement_index].render(statements, types, values, indentation + 1, writer);
                    if (i < this.success.items.len) {
                        try writer.print("\n", .{});
                    }
                }
            }

            if (this.failure.items.len > 0) {
                try writer.writeByte('\n');
                for (this.failure.items, 1..) |statement_index, i| {
                    try statements[statement_index].render(statements, types, values, indentation + 1, writer);
                    if (i < this.failure.items.len) {
                        try writer.print("\n", .{});
                    }
                }
            }
        }

        pub fn init(allocator: std.mem.Allocator, condition: Value) @This() {
            return .{
                .condition = condition,
                .success = List(u64).init(allocator),
                .failure = List(u64).init(allocator),
            };
        }

        pub fn deinit(this: @This()) void {
            this.condition.deinit();
            this.success.deinit();
            this.failure.deinit();
        }
    };

    pub const Repeat = struct {
        label: ?[]const u8,
        times: ?Value,
        body: List(u64),

        pub fn render(this: @This(), statements: []Statement, types: []Type, values: []Value, indentation: u64, writer: anytype) anyerror!void {
            try writer.writeAll("repeat");
            if (this.times != null) {
                try writer.writeByte(' ');
                try this.times.?.render(values, indentation, writer);
            }
            if (this.label != null) {
                try writer.writeAll(" as ");
                try writer.writeAll(this.label.?);
            }
            if (this.body.items.len > 0) {
                try writer.writeByte('\n');
                for (this.body.items, 1..) |statement_index, i| {
                    try statements[statement_index].render(statements, types, values, indentation + 1, writer);
                    if (i < this.body.items.len) {
                        try writer.print("\n", .{});
                    }
                }
            }
        }

        pub fn init(allocator: std.mem.Allocator, label: ?[]const u8, times: ?Value) @This() {
            return .{
                .label = label,
                .times = times,
                .body = List(u64).init(allocator),
            };
        }

        pub fn deinit(this: @This()) void {
            this.body.deinit();
        }
    };

    pub const Use = struct {
        path: []const u8,
        alias: ?[]const u8,

        pub fn render(this: @This(), writer: anytype) !void {
            try writer.print("use \"{s}\"", .{ this.path });
            if (this.alias != null) {
                try writer.print(" {s}", .{ this.alias.? });
            }
        }
    };

    pub const Call = struct {
        function: Value,
        arguments: List(Value),

        pub fn render(this: @This(), values: []Value, indentation: u64, writer: anytype) !void {
            try this.function.render(values, indentation, writer);
            try writer.writeByte('(');
            for (this.arguments.items, 1..) |value, i| {
                try value.render(values, indentation, writer);
                if (i < this.arguments.items.len) {
                    try writer.writeAll(", ");
                }
            }
            try writer.writeByte(')');
        }

        pub fn init(allocator: std.mem.Allocator, function: Value) @This() {
            return .{
                .function = function,
                .arguments = List(Value).init(allocator),
            };
        }

        pub fn deinit(this: @This()) void {
            for (this.arguments.items) |argument| {
                argument.deinit();
            }
            this.arguments.deinit();
        }
    };

    pub const Variant = struct {
        name: []const u8,
        fields: List(Field),
        definitions: List(u64),

        pub fn render(this: @This(), statements: []Statement, types: []Type, values: []Value, indentation: usize, writer: anytype) anyerror!void {
            try writer.print("variant {s}", .{ this.name });

            for (this.fields.items) |field| {
                try writer.writeAll("\n");
                try writeIndentation(indentation + 1, writer);
                try field.render(types, writer);
            }

            for (this.definitions.items, 1..) |statement_index, i| {
                if (i < this.definitions.items.len) {
                    try writer.writeAll("\n");
                }
                try statements[statement_index].render(statements, types, values, indentation + 1, writer);
            }
        }

        pub fn init(allocator: std.mem.Allocator, name: []const u8) @This() {
            return .{
                .name = name,
                .fields = List(Field).init(allocator),
                .definitions = List(u64).init(allocator),
            };
        }

        pub fn deinit(this: @This()) void {
            for (this.fields.items) |field| {
                if (field.type != null) {
                    field.type.?.deinit();
                }
            }
            this.fields.deinit();
        }

        pub const Field = struct {
            name: []const u8,
            type: ?Type,

            pub fn render(this: @This(), types: []Type, writer: anytype) !void {
                try writer.writeAll(this.name);
                if (this.type != null) {
                    try writer.writeByte(' ');
                    try this.type.?.render(types, writer);
                }
            }
        };
    };

    pub const Record = struct {
        name: []const u8,
        fields: List(Field),
        definitions: List(u64),

        pub fn render(this: @This(), statements: []Statement, types: []Type, values: []Value, indentation: usize, writer: anytype) anyerror!void {
            try writer.print("record {s}", .{ this.name });

            for (this.fields.items) |field| {
                try writer.writeAll("\n");
                try writeIndentation(indentation + 1, writer);
                try field.render(types, writer);
            }

            for (this.definitions.items, 1..) |statement_index, i| {
                if (i < this.definitions.items.len) {
                    try writer.writeAll("\n");
                }
                try statements[statement_index].render(statements, types, values, indentation + 1, writer);
            }
        }

        pub fn init(allocator: std.mem.Allocator, name: []const u8) @This() {
            return .{
                .name = name,
                .fields = List(Field).init(allocator),
                .definitions = List(u64).init(allocator),
            };
        }

        pub fn deinit(this: @This()) void {
            for (this.fields.items) |field| {
                field.type.deinit();
            }
            this.fields.deinit();
        }

        pub const Field = struct {
            name: []const u8,
            type: Type,

            pub fn render(this: @This(), types: []Type, writer: anytype) !void {
                try writer.writeAll(this.name);
                try writer.writeByte(' ');
                try this.type.render(types, writer);
            }
        };
    };
};

pub const Value = union(enum) {
    integer: []const u8,
    float: []const u8,
    string: []const u8,
    char: []const u8,
    list: List(u64),
    map: List([2]u64),
    set: List(u64),
    binary: Binary,
    unary: Unary,
    variant_shorthand: []const u8,
    record: Record,
    variable: Variable,

    pub const Binary = struct {
        left: u64,
        right: u64,
        operator: Operator,

        pub const Operator = enum {
            add,
            sub,
            mul,
            div,
            rem,
            pow,
            shl,
            shr,
            @"and",
            xor,
            @"or",

            pub fn render(this: @This(), writer: anytype) !void {
                if (this == .add) {
                    try writer.writeByte('+');
                } else if (this == .sub) {
                    try writer.writeByte('-');
                } else if (this == .mul) {
                    try writer.writeByte('*');
                } else if (this == .div) {
                    try writer.writeByte('/');
                } else if (this == .rem) {
                    try writer.writeByte('%');
                } else if (this == .pow) {
                    try writer.writeByte('^');
                } else if (this == .shl) {
                    try writer.writeAll("<<");
                } else if (this == .shr) {
                    try writer.writeAll(">>");
                } else if (this == .@"and") {
                    try writer.writeByte('&');
                } else if (this == .xor) {
                    try writer.writeByte('^');
                } else if (this == .@"or") {
                    try writer.writeByte('|');
                }
            }
        };
    };

    pub const Unary = struct {
        right: u64,
        operator: Operator,

        pub const Operator = enum {
            minus,
            plus,
            not,

            pub fn render(this: @This(), writer: anytype) !void {
                if (this == .minus) {
                    try writer.writeByte('-');
                } else if (this == .plus) {
                    try writer.writeByte('+');
                } else if (this == .not) {
                    try writer.writeAll("not");
                }
            }
        };
    };

    pub fn render(this: @This(), values: []Value, indentation: u64, writer: anytype) !void {
        if (this == .integer) {
            try writer.writeAll(this.integer);
        } else if (this == .float) {
            try writer.writeAll(this.float);
        } else if (this == .string) {
            try writer.print("\"{s}\"", .{ this.string });
        } else if (this == .char) {
            try writer.print("'{s}'", .{ this.char });
        } else if (this == .list) {
            try writer.writeByte('[');
            for (this.list.items, 1..) |value_index, i| {
                try values[value_index].render(values, indentation, writer);
                if (i < this.list.items.len) {
                    try writer.writeAll(", ");
                }
            }
            try writer.writeByte(']');
        } else if (this == .set) {
            try writer.writeByte('{');
            for (this.set.items, 1..) |value_index, i| {
                try values[value_index].render(values, indentation, writer);
                if (i < this.set.items.len) {
                    try writer.writeAll(", ");
                }
            }
            try writer.writeByte('}');
        } else if (this == .map) {
            try writer.writeByte('{');
            for (this.map.items, 1..) |value_indices, i| {
                try values[value_indices[0]].render(values, indentation, writer);
                try writer.writeAll(": ");
                try values[value_indices[1]].render(values, indentation, writer);
                if (i < this.map.items.len) {
                    try writer.writeAll(", ");
                }
            }
            try writer.writeByte('}');
        } else if (this == .binary) {
            try writer.writeByte('(');
            try values[this.binary.left].render(values, indentation, writer);
            try writer.writeByte(' ');
            try this.binary.operator.render(writer);
            try writer.writeByte(' ');
            try values[this.binary.right].render(values, indentation, writer);
            try writer.writeByte(')');
        } else if (this == .unary) {
            try this.binary.operator.render(writer);
            try writer.writeByte(' ');
            try values[this.unary.right].render(values, indentation, writer);
        } else if (this == .variant_shorthand) {
            try writer.writeByte('.');
            try writer.writeAll(this.variant_shorthand);
        } else if (this == .variable) {
            try this.variable.render(writer);
        } else if (this == .record) {
            try this.record.render(values, indentation, writer);
        }
    }

    pub fn deinit(this: @This()) void {
        if (this == .list) {
            this.list.deinit();
        } else if (this == .map) {
            this.map.deinit();
        } else if (this == .set) {
            this.set.deinit();
        } else if (this == .variable) {
            this.variable.deinit();
        } else if (this == .record) {
            this.record.deinit();
        }
    }

    pub const Record = struct {
        path: Variable,
        fields: List(Field),

        pub fn render(this: @This(), values: []Value, indentation: u64, writer: anytype) !void {
            try this.path.render(writer);
            for (this.fields.items) |field| {
                try writer.writeByte('\n');
                try writeIndentation(indentation + 1, writer);
                try field.render(values, indentation, writer);
            }
        }

        pub fn init(allocator: std.mem.Allocator, name: []const u8) @This() {
            return .{
                .path = Variable.init(allocator, name),
                .fields = List(Field).init(allocator),
            };
        }

        pub fn deinit(this: @This()) void {
            for (this.fields.items) |field| {
                field.value.deinit();
            }
            this.path.deinit();
            this.fields.deinit();
        }

        pub const Field = struct {
            name: []const u8,
            value: Value,

            pub fn render(this: @This(), values: []Value, indentation: usize, writer: anytype) anyerror!void {
                try writer.writeAll(this.name);
                try writer.writeByte(' ');
                try this.value.render(values, indentation, writer);
            }
        };
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
    bool,
    list: u64,
    set: u64,
    map: [2]u64,
    variable: Variable,
    function: Function,

    pub fn render(this: @This(), types: []Type, writer: anytype) !void {
        if (this == .list) {
            try writer.writeByte('[');
            try types[this.list].render(types, writer);
            try writer.writeByte(']');
        } else if (this == .set) {
            try writer.writeByte('{');
            try types[this.set].render(types, writer);
            try writer.writeByte('}');
        } else if (this == .map) {
            try writer.writeByte('{');
            try types[this.map[0]].render(types, writer);
            try writer.writeByte(':');
            try types[this.map[1]].render(types, writer);
            try writer.writeByte('}');
        } else if (this == .variable) {
            try this.variable.render(writer);
        } else if (this == .function) {
            try this.function.render(types, writer);
        } else {
            try writer.writeAll(@tagName(this));
        }
    }

    pub fn deinit(this: @This()) void {
        if (this == .function) {
            this.function.deinit();
        } else if (this == .variable) {
            this.variable.deinit();
        }
    }

    pub const Function = struct {
        parameters: List(u64),
        result: List(u64),

        pub fn render(this: @This(), types: []Type, writer: anytype) anyerror!void {
            try writer.writeAll("function(");
            for (this.parameters.items, 1..) |parameter_index, i| {
                try types[parameter_index].render(types, writer);
                if (i < this.parameters.items.len) {
                    try writer.writeAll(", ");
                }
            }
            try writer.writeByte(')');
            for (this.result.items, 1..) |result_index, i| {
                try types[result_index].render(types, writer);
                if (i < this.result.items.len) {
                    try writer.writeAll(", ");
                }
            }
        }

        pub fn init(allocator: std.mem.Allocator) @This() {
            return .{
                .parameters = List(u64).init(allocator),
                .result = List(u64).init(allocator),
            };
        }

        pub fn deinit(this: @This()) void {
            this.parameters.deinit();
            this.result.deinit();
        }
    };
};

const expect = std.testing.expect;

test "Building a simple ast" {
    const allocator = std.testing.allocator;
    var this = @This().init(allocator);
    const list_type = Type { .list = try this.addType(.u8) };
    var bind = Statement.Bind.init(allocator, list_type);
    try bind.names.append("x");
    try bind.names.append("y");
    try this.addMainStatement(Statement{ .bind = bind });

    var assign = Statement.Assign.init(allocator);

    try assign.assignables.append(.{ .name = Variable.init(allocator, "x"), .type = null });
    try assign.assignables.append(.{ .name = Variable.init(allocator, "y"), .type = null });
    try assign.values.append(Value { .integer = "5" });
    try assign.values.append(Value { .integer = "6" });
    try this.addMainStatement(Statement{ .assign = assign });

    var assign_inside_if = Statement.Assign.init(allocator);
    try assign_inside_if.assignables.append(.{ .name = Variable.init(allocator, "x"), .type = null });
    const x_value = try this.addValue(Value { .variable = Variable.init(allocator, "x") });
    const one = try this.addValue(Value { .integer = "1" });
    try assign_inside_if.values.append(Value { .binary = .{ .left = x_value, .right = one, .operator = .add } });
    const assign_inside_if_index = try this.addStatement(Statement { .assign = assign_inside_if });
    var if_statement = Statement.If.init(allocator, Value { .integer = "5" });
    try if_statement.success.append(assign_inside_if_index);
    try this.addMainStatement(Statement { .@"if" = if_statement });

    var buffer = List(u8).init(allocator);
    try this.render(buffer.writer());
    try expect(std.mem.eql(u8, buffer.items,
        \\x, y [u8]
        \\x, y = 5, 6
        \\if 5
        \\    x = (x + 1)
    ));


    buffer.deinit();
    this.deinit();
}
