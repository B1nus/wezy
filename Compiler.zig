pub const std = @import("std");
pub const Inst = @import("wasm.zig").Instructions;
pub const Type = @import("wasm.zig").Types;

pub const function = [_]u8{
    Inst.@"local.get",
    0,
};

test {
    std.debug.print("{any}\n", .{@as(Inst, @enumFromInt(0x7E))});
}
