pub fn main() !void {
    const std = @import("std");
    std.debug.print("{}\n", .{@typeInfo(i32)});
}
