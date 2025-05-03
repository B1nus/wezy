const std = @import("std");
const eql = std.mem.eql;
const expect = std.testing.expect;
const Scanner = @import("Scanner.zig");
const Buffer = @import("buffer.zig").Buffer(0x10000);
const ValueSet = @import("maps.zig").ValueSet(0x1000);
const NameMap = @import("maps.zig").NameMap(0x1000);

scanner: *Scanner,

typeBuffer: Buffer,
importBuffer: Buffer,
functionBuffer: Buffer,
tableBuffer: Buffer,
memoryBuffer: Buffer,
globalBuffer: Buffer,
exportBuffer: Buffer,
elementBuffer: Buffer,
codeBuffer: Buffer,
dataBuffer: Buffer,

types: ValueSet,
functionNames: NameMap,
tableNames: NameMap,
memoryNames: NameMap,
globalNames: NameMap,
elementNames: NameMap,
dataNames: NameMap,

pub fn init(source: []const u8) @This() {
    return .{
        .scanner = Scanner.init(source),

        .typeBuffer = Buffer.init(),
        .importBuffer = Buffer.init(),
        .functionBuffer = Buffer.init(),
        .tableBuffer = Buffer.init(),
        .memoryBuffer = Buffer.init(),
        .globalBuffer = Buffer.init(),
        .exportBuffer = Buffer.init(),
        .elementBuffer = Buffer.init(),
        .codeBuffer = Buffer.init(),
        .dataBuffer = Buffer.init(),

        .types = ValueSet.init(),
        .functionNames = NameMap.init(),
        .tableNames = NameMap.init(),
        .memoryNames = NameMap.init(),
        .globalNames = NameMap.init(),
        .elementNames = NameMap.init(),
        .dataNames = NameMap.init(),
    };
}

pub fn compile(self: *@This()) []u8 {
    // compile into the buffers.

}
