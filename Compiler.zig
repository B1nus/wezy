pub const std = @import("std");
pub const Inst = @import("wasm.zig").Instructions;
pub const Type = @import("wasm.zig").Types;

pub const Function = struct {
    dependencies: []const Dependency,
    code: []const u8,
};

pub const Dependency = struct {
    name: []const u8,
    tag: Tag,

    const Tag = enum {
        wasi,
        std,
    };
};

pub const allocate = Function {
    .dependencies = .{
        Dependency { .name = "assert", .tag = .std },
    },
    .code = .{
        Inst.@"i32.const",
        0,
        Inst.@"i32.eqz",
        Inst.@"call",
        0,
    },
};
