pub const std = @import("std");
pub const Parser = @import("Parser.zig");
pub const Tokenizer = @import("Tokenizer.zig");

pub fn compile(source: [:0]const u8, allocator: std.mem.Allocator) std.ArrayList(u8) {
    var tokenizer = Tokenizer.init(source);
    var parser = Parser.init(&tokenizer, allocator);
    parser.parse_program();
    std.debug.print("After parse\n", .{});
    defer parser.deinit();

    var ident_map = std.StringHashMap(usize).init(allocator);
    defer ident_map.deinit();

    var module = std.ArrayList(u8).init(allocator);
    var locals = std.ArrayList(u8).init(allocator);
    var code = std.ArrayList(u8).init(allocator);

    for (parser.assignments.items) |assignment| {
        if (ident_map.get(assignment.identifier) == null) {
            ident_map.put(assignment.identifier, ident_map.count()) catch unreachable;
        }
        const int = std.fmt.parseInt(i32, assignment.expression.integer, 10) catch unreachable;
        code.append(0x41) catch unreachable; // i32.const
        std.leb.writeIleb128(code.writer(), int) catch unreachable;
        code.append(0x21) catch unreachable; // Local Set
        code.append(@intCast(ident_map.get(assignment.identifier).?)) catch unreachable;
    }
    code.append(0x0B) catch unreachable;

    locals.append(1) catch unreachable; // Amount of local types.
    std.leb.writeUleb128(locals.writer(), ident_map.count()) catch unreachable; // Amount of locals
    locals.append(0x7F) catch unreachable; // i32.

    locals.appendSlice(code.items) catch unreachable;
    code.clearRetainingCapacity();
    std.leb.writeUleb128(code.writer(), locals.items.len) catch unreachable;
    code.appendSlice(locals.items) catch unreachable;
    locals.deinit();

    module.appendSlice(&.{ 0, 'a', 's', 'm', 1, 0, 0, 0 }) catch unreachable; // Magic number
    module.appendSlice(&.{ 1, 4, 1, 0x60, 0, 0 }) catch unreachable; // Type
    module.appendSlice(&.{ 3, 2, 1, 0 }) catch unreachable; // Function

    // Code
    module.append(0x0a) catch unreachable;
    std.leb.writeUleb128(module.writer(), code.items.len + 1) catch unreachable;
    module.append(1) catch unreachable;
    module.appendSlice(code.items) catch unreachable;
    code.deinit();

    return module;
}

test "thing" {
    const bytes = compile("z = 1", std.testing.allocator);
    defer bytes.deinit();

    if (std.fs.cwd().createFile("out.wasm", .{})) |file| {
        _ = try file.write(bytes.items);
    } else |_| {
        unreachable;
    }
    std.debug.print("{x}\n", .{bytes.items});
}
