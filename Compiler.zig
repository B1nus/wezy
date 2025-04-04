pub const std = @import("std");
pub const Inst = @import("wasm.zig").Instructions;
pub const Type = @import("wasm.zig").Types;

pub const Function = struct {
    dependencies: []const Dependency,
    params: []const Type,
    results: []const Type,
    locals: []const Local,
    code: []const u8,
};

pub const Local = struct {
    type: Type,
    amount: usize,
};

pub const Dependency = struct {
    name: []const u8,
    tag: Tag,

    const Tag = enum {
        wasi,
        std,
    };
};

pub const exp = Function {
    .dependencies = .{
        Dependency { .name = "assert", .tag = .std },
    },
    .params = .{
        Type.@"f64",
    },
    .results = .{
        Type.@"f64",
    },
    .locals = .{
        .{ Type.@"i32", 2 },
    },
    .code = .{
        Inst.@"i32.const",
        0,
        Inst.@"i32.eqz",
        Inst.@"call",
        0,
    },
};
