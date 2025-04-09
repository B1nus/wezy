const std = @import("std");
const Inst = @import("wasm").Inst;

pub const Section = enum(u8) {
    custom,
    type,
    import,
    function,
    table,
    memory,
    global,
    @"export",
    start,
    element,
    code,
    data,
    datacount,
};

pub const ExportDesc = ImportDesc;
pub const ImportDesc = enum(u8) {
    func,
    table,
    mem,
    global,
};

pub const Vectype = enum(u8) {
    v128 = 0x7B,
};

pub const Reftype = enum(u8) {
    funcref = 0x70,
    externref = 0x6F,
};

pub const Numtype = enum(u8) {
    @"i32" = 0x7F,
    @"i64" = 0x7E,
    @"f32" = 0x7D,
    @"f64" = 0x7C,
};

pub const Blocktype = enum(u8) {
    none = 0x40,
};

pub const LimitType = enum {
    min = 0x00,
    range = 0x01,
};

pub const Mutability = enum {
    @"const" = 0x00,
    mut = 0x01,
};

pub const Compiler = struct {
    reader: std.io.Reader,
    writer: std.io.Writer,
    buffer: std.ArrayList(u8),
    byte: ?u8,

    pub fn init(allocator: std.mem.Allocator, reader: std.io.Reader, writer: std.io.Writer) @This() {
        var compiler = @This() {
            .reader = reader,
            .writer = writer,
            .buffer = std.ArrayList(u8).init(allocator),
            .byte = null,
        };
        compiler.readByte();
    }

    pub fn readByte(self: @This()) void {
        self.byte = if (self.reader.readByte()) |byte| byte else |_| null;
    }

    pub fn skipWhiteSpace(self: @This()) void {
        while (std.mem.containsAtLeastScalar(u8, "\n\t\r ", 1, self.byte)) {
            self.readByte();
        }
    }

    pub fn readNext(self: *@This()) !?[]u8 {
        self.buffer.clearRetainingCapacity();
        self.skipWhiteSpace();
        while (true) {
            switch (self.byte) {
                'a'...'z','.','-','_','0'...'9' => {
                    try self.buffer.append(self.byte);
                    self.readByte();
                },
                null => break,
                else => unreachable,
            }
        }
        return if (buffer.items.len == 0) null else buffer.items;
    }

    pub fn readString(self: *@This()) ![]u8 {
        self.buffer.clearRetatiningCapacity();
        self.skipWhiteSpace();

        while (true) {
            switch (self.byte) {
                '\"' => {
                    self.readByte();
                    break;
                },
                '\\' => {
                    self.readByte();
                    switch (self.byte) {
                        'n' => try self.buffer.append('\n'),
                        'r' => try self.buffer.append('\r'),
                        't' => try self.buffer.append('\t'),
                        '\\' => try self.buffer.append('\\'),
                        '0'...'9','a'...'f','A'...'F' => {
                            const first_letter = self.byte.?;
                            self.readByte();
                            const second_letter = self.byte.?;
                            const byte = try std.fmt.parseInt(u8, &.{ first_letter, second_letter }, 16);
                            try self.buffer.append(byte);
                        },
                    }
                },
                else => {
                    try self.buffer.append(self.byte);
                    self.readByte();
                },
            }
        }

        return self.buffer.items;
    }

    pub fn readInteger(self: *@This(), T: type) !T {
        const string = try self.readNext();
        const integer = try std.fmt.parseInt(T, string, 0);
        return integer;
    }

    pub fn readFloat(self: *@This(), T: type) !T {
        const string = try self.readNext();
        const float = try std.fmt.parseFloat(T, string);
        return float;
    }

    pub fn readEnum(self: *@This(), T: type) !?T {
        const string = try self.readNext();
        const val = std.meta.stringToEnum(T, string);
        return val;
    }

    pub fn readInst(self: *@This()) !?Inst {
        const string = try self.readNext();
        const inst = instructions.get(string);
        return inst;
    }

    pub fn readExpr(self: *@This(), delimiter: Inst) ![]u8 {
    }

    pub fn writeExpr(self: *@This(), delimiter: Inst) !void {
        const expr = try self.readExpr(delimiter);
        self.writer.write(expr);
    }

    pub fn writeInst(self: *@This()) !void {
        const inst = try self.readInst().?;
        const prefix, const opcode, const args = inst;
        try self.writeOpcode(prefix, opcode);
        try self.writeIntermediates(self: *@This(), args);
    }

    pub fn writeOpcode(self: *@This(), prefix: u32, opcode: u8) !void {
        if (opcode == 0) {
            try writer.writeByte(@intCast(prefix));
        } else {
            try writer.writeByte(opcode);
            try std.leb.writeUleb128(writer, prefix);
        }
    }

    pub fn writeIntermediates(self: *@This(), args: []const Arg) !void {
        for (0..args.len) |i| {
            try self.writeArg(args[0..]);
        }
    }

    pub fn writeArg(self: *@This(), args: []const Arg) !void {
        switch (arg[0]) {
            .@"i32" => try self.writeInteger(i32),
            .@"i64" => try self.writeInteger(i64),
            .@"f32" => try self.writeFloat(f32),
            .@"f64" => try self.writeFloat(f64),
            .@"if" => try self.writeExpr()
            .block => if (!(try self.writeEnum(&.{ Reftype, Numtype, Vectype, Blocktype }, u8))) {
                const index = try std.fmt.parseInt(u32, string, 10);
                try std.leb.writeUleb128(writer, index);
            },
            .index => try self.writeInteger(u32);
            .valtype => _ = try self.writeEnum(&.{ Reftype, Numtype, Vectype });
            .vector => {
                const count = try self.readInteger(u32);
                for (0..count) |_| {
                    try self.writeArg(elem, args[1..]);
                }
            },
            .reftype => try self.writeEnum(&.{ Reftype }),
            .byte => try self.writeInteger(u8);
        }
    }

    pub fn writeEnum(self: *@This(), Types: []const type, I: type) !bool {
        for (Types) |T| {
            if (self.readEnum(T)) |val| {
                const integer = @as(I, @intFromEnum(val));
                if (@typeInfo(T.int.bits <= 8) {
                    try self.writer.writeByte(integer);
                } else {
                    try std.leb.writeIleb128(self.writer, integer);
                }
                return true;
            }
        }

        return false;
    }

    pub fn writeInteger(self: *@This(), T: type) !void {
        const integer = try self.readInteger(T);
        if (@typeInfo(T.int.signedness == .signed) {
            try std.leb.writeUleb128(self.writer, integer);
        } else {
            try std.leb.writeIleb128(self.writer, integer);
        }
    }

    pub fn writeFloat(self: *@This(), T: type) !void {
        const float = try self.readFloat(T);
        try self.writer.writeAll(@bitCast(float));
    }
};

pub fn writeInstruction(instruction: Inst, writer: anytype) !void {
    const prefix, const opcode, _ = instruction;
    if (opcode == 0) {
        try writer.writeByte(@intCast(prefix));
    } else {
        try writer.writeByte(opcode);
        try std.leb.writeUleb128(writer, prefix);
    }
}

pub fn readNextExpression(reader: anytype, read_buffer: []u8, writer: anytype, end_inst: Inst) !void {
    const end_prefix, const end_opcode, _ = end_inst;
    var instruction = instructions.get(readNext(reader, read_buffer).?);

    while (instruction) |inst| {
        const prefix, const opcode, const args = inst;

        try writeInstruction(inst, writer);

        if (prefix == end_prefix and opcode == end_opcode) {
            break;
        }

        for (args) |arg| {
            switch (arg) {
                .@"i32", .@"i64" => {
                    const number = try readNextInteger(i65, reader, read_buffer);
                    try std.leb.writeIleb128(writer, number);
                },
                .@"f32" => {
                    const string = readNext(reader, read_buffer).?;
                    const float = try std.fmt.parseFloat(f32, string);
                    try std.leb.writeIleb128(writer, @as(u32, @bitCast(float)));
                },
                .@"f64" => {
                    const string = readNext(reader, read_buffer).?;
                    const float = try std.fmt.parseFloat(f64, string);
                    try std.leb.writeIleb128(writer, @as(u64, @bitCast(float)));
                },
                .block => {
                    const string = readNext(reader, read_buffer).?;

                    if (std.meta.stringToEnum(Valtype, string)) |valtype| {
                        try writer.writeByte(@intFromEnum(valtype));
                    } else {
                        const index = try std.fmt.parseInt(u32, string, 10);
                        try std.leb.writeUleb128(writer, index);
                    }

                    try readNextExpression(reader, read_buffer, writer, instructions.get("end").?);
                },
                .@"if" => {
                    try readNextExpression(reader, read_buffer, writer, instructions.get("else").?);
                },
                .index => {
                    const index = try readNextInteger(u32, reader, read_buffer);
                    try std.leb.writeUleb128(writer, index);
                },
                .index_vector => {
                    const count = try readNextInteger(u32, reader, read_buffer);
                    try std.leb.writeUleb128(writer, count);

                    for (0..count) |_| {
                        const index = try readNextInteger(u32, reader, read_buffer);
                        try std.leb.writeUleb128(writer, index);
                    }
                },
                .valtype => {
                    const valtype = readNextValtype(reader, read_buffer).?;
                    try writer.writeByte(@intFromEnum(valtype));
                },
                .valtype_vector => {
                    const count = try readNextInteger(u32, reader, read_buffer);
                    try std.leb.writeUleb128(writer, count);

                    for (0..count) |_| {
                        const valtype = readNextValtype(reader, read_buffer).?;
                        try writer.writeByte(@intFromEnum(valtype));
                    }
                },
                .reftype => {
                    const reftype = readNextReftype(reader, read_buffer).?;
                    try writer.writeByte(@intFromEnum(reftype));
                },
                .byte => {
                    const byte = try readNextInteger(u8, reader, read_buffer);
                    try writer.writeByte(byte);
                },
            }
        }

        instruction = instructions.get(readNext(reader, read_buffer).?);
    }
}

pub fn readNextString(reader: anytype, write_buffer: []u8) ![]u8 {
    const State = enum {
        normal,
        slash,
    };

    var stream = std.io.fixedBufferStream(write_buffer);
    const writer = stream.writer();

    var state = State.normal;
    _ = try reader.readByte();

    while (true) {
        const byte = try reader.readByte();
        switch (state) {
            .normal => switch (byte) {
                '\\' => state = .slash,
                '\"' => break,
                else => try writer.writeByte(byte),
            },
            .slash => switch (byte) {
                '\\', '\"' => {
                    try writer.writeByte(byte);
                    state = .normal;
                },
                '0'...'9', 'a'...'f', 'A'...'F' => {
                    const second_byte = try reader.readByte();
                    const number = try std.fmt.parseInt(u8, &.{byte, second_byte}, 16);
                    try writer.writeByte(number);
                    state = .normal;
                },
                'n' => {
                    try writer.writeByte('\n');
                    state = .normal;
                },
                't' => {
                    try writer.writeByte('\t');
                    state = .normal;
                },
                else => unreachable,
            },
        }
    }

    return stream.getWritten();
}

pub fn readNextSection(allocator: std.mem.Allocator, section: Section, reader: anytype, read_buffer: []u8, write_buffer: []u8) ![]u8 {
    var stream = std.io.fixedBufferStream(write_buffer);
    const writer = stream.writer();

    switch (section) {
        .custom => {
            const name = readNext(reader, read_buffer).?;
            try std.leb.writeUleb128(writer, name.len);
            try writer.writeAll(name);

            const string = try readNextString(reader, read_buffer);
            try writer.writeAll(string);
        },
        .type => {
            const number = try readNextInteger(u32, reader, read_buffer);
            try std.leb.writeUleb128(writer, number);

            for (0..number) |_| {
                try writer.writeByte(0x60);

                for (0..2) |_| {
                    const count = try readNextInteger(u32, reader, read_buffer);
                    try std.leb.writeUleb128(writer, count);

                    for (0..count) |_| {
                        const valtype = readNextValtype(reader, read_buffer).?;
                        try writer.writeByte(@intFromEnum(valtype));
                    }
                }
            }
        },
        .import => {
            const number = try readNextInteger(u32, reader, read_buffer);
            try std.leb.writeUleb128(writer, number);

            for (0..number) |_| {
                for (0..2) |_| {
                    const string = readNext(reader, read_buffer).?;
                    try std.leb.writeUleb128(writer, string.len);
                    try writer.writeAll(string);
                }

                const import_type = std.meta.stringToEnum(ImportDesc, readNext(reader, read_buffer).?).?;
                try writer.writeByte(@intFromEnum(import_type));
                switch (import_type) {
                    .func => {
                        const funcidx = try readNextInteger(u32, reader, read_buffer);
                        try std.leb.writeUleb128(writer, funcidx);
                    },
                    else => {},
                }
            }
        },
        .function => {
            const number = try readNextInteger(u32, reader, read_buffer);
            try std.leb.writeUleb128(writer, number);

            for (0..number) |_| {
                const typeidx = try readNextInteger(u32, reader, read_buffer);
                try std.leb.writeUleb128(writer, typeidx);
            }
        },
        .table => {
            const number = try readNextInteger(u32, reader, read_buffer);
            try std.leb.writeUleb128(writer, number);

            for (0..number) |_| {
                const reftype = readNextReftype(reader, read_buffer).?;
                try writer.writeByte(@intFromEnum(reftype));

                const limit_type = try readNextInteger(u8, reader, read_buffer);
                try writer.writeByte(limit_type);
                for (0..limit_type + 1) |_| {
                    const lim = try readNextInteger(u32, reader, read_buffer);
                    try std.leb.writeUleb128(writer, lim);
                }
            }
        },
        .memory => {
            const number = try readNextInteger(u32, reader, read_buffer);
            try std.leb.writeUleb128(writer, number);

            for (0..number) |_| {
                const limit_type = try readNextInteger(u8, reader, read_buffer);
                try writer.writeByte(limit_type);
                for (0..limit_type + 1) |_| {
                    const num= try readNextInteger(u32, reader, read_buffer);
                    try std.leb.writeUleb128(writer, num);
                }
            }
        },
        .global => {
            const number = try readNextInteger(u32, reader, read_buffer);
            try std.leb.writeUleb128(writer, number);

            for (0..number) |_| {
                const valtype = readNextValtype(reader, read_buffer).?;
                try writer.writeByte(@intFromEnum(valtype));

                const mut = try readNextInteger(u8, reader, read_buffer);
                try writer.writeByte(mut);
                
                try readNextExpression(reader, read_buffer, writer, instructions.get("end").?);
            }
        },
        .@"export" => {
            const number = try readNextInteger(u32, reader, read_buffer);
            try std.leb.writeUleb128(writer, number);

            for (0..number) |_| {
                const string = readNext(reader, read_buffer).?;
                try std.leb.writeUleb128(writer, string.len);
                try writer.writeAll(string);

                const export_type = std.meta.stringToEnum(ExportDesc, readNext(reader, read_buffer).?).?;
                try writer.writeByte(@intFromEnum(export_type));

                const idx = try readNextInteger(u32, reader, read_buffer);
                try std.leb.writeUleb128(writer, idx);
            }
        },
        .start => {
            const number = try readNextInteger(u32, reader, read_buffer);
            try std.leb.writeUleb128(writer, number);
        },
        .element => {
            const number = try readNextInteger(u32, reader, read_buffer);
            try std.leb.writeUleb128(writer, number);

            for (0..number) |_| {
                const id = try readNextInteger(u8, reader, read_buffer);
                try writer.writeByte(id);

                switch (id) {
                    0 => {

                    },
                }
            }
        },
        .code => {
            const number = try readNextInteger(u32, reader, read_buffer);
            try std.leb.writeUleb128(writer, number);
            var func = try std.ArrayList(u8).initCapacity(allocator, 0xFF);
            defer func.deinit();

            for (0..number) |_| {
                const locals = try readNextInteger(u32, reader, read_buffer);
                try std.leb.writeUleb128(func.writer(), locals);

                for (0..locals) |_| {
                    const count = try readNextInteger(u32, reader, read_buffer);
                    try std.leb.writeUleb128(func.writer(), count);

                    const valtype = readNextValtype(reader, read_buffer).?;
                    try func.append(@intFromEnum(valtype));
                }
                
                try readNextExpression(reader, read_buffer, func.writer(), instructions.get("end").?);

                try std.leb.writeUleb128(writer, func.items.len);
                try writer.writeAll(func.items);

                func.clearRetainingCapacity();
            }
        },
        .data => {
            const number = try readNextInteger(u32, reader, read_buffer);
            try std.leb.writeUleb128(writer, number);

            for (0..number) |_| {
                const id = try readNextInteger(u8, reader, read_buffer);
                try writer.writeByte(id);

                if (id == 2) {
                    const memidx = try readNextInteger(u32, reader, read_buffer);
                    try std.leb.writeUleb128(writer, memidx);
                }

                if (id == 0 or id == 2) {
                    try readNextExpression(reader, read_buffer, writer, instructions.get("end").?);
                }

                const string = try readNextString(reader, read_buffer);
                try std.leb.writeUleb128(writer, string.len);
                try writer.writeAll(string);
            }
        },
        .datacount => {
            const number = try readNextInteger(u32, reader, read_buffer);
            try std.leb.writeUleb128(writer, number);
        },
    }

    return stream.getWritten();
}

pub fn runWasm(wasm: []const u8) !void {
    var proc = std.process.Child.init(&[_][]const u8{"wasmtime", "-"}, std.heap.page_allocator);
    proc.stdin_behavior = .Pipe;
    try proc.spawn();
    
    if (proc.stdin) |*stdin| {
        try stdin.writeAll(wasm);
        stdin.close();
        proc.stdin = null;
    }
    
    _ = try proc.wait();
}

pub fn replace_extension(allocator: std.mem.Allocator, path: []const u8, new_extension: []const u8) []u8 {
    const extension = std.fs.path.extension(path);
    var new_path = allocator.alloc(u8, path.len - extension.len + new_extension.len) catch unreachable;
    std.mem.copyForwards(u8, new_path, path[0 .. path.len - extension.len]);
    std.mem.copyForwards(u8, new_path[new_path.len - new_extension.len ..], new_extension);

    return new_path;
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const stdout = std.io.getStdOut().writer();

    var args = std.process.args();
    _ = args.next();

    if (args.next()) |source_path| {
        const source_file = try std.fs.cwd().openFile(source_path, .{});
        defer source_file.close();

        var out = try std.ArrayList(u8).initCapacity(allocator, 0xFFFF);
        try out.appendSlice(&.{0,'a','s','m',1,0,0,0});

        const read_buffer = try allocator.alloc(u8, 0xFF);
        const write_buffer = try allocator.alloc(u8, 0xFFFF);

        while (readNextSectionVariant(source_file.reader(), read_buffer)) |section| {
            const content = try readNextSection(allocator, section, source_file.reader(), read_buffer, write_buffer);
            try out.append(@intFromEnum(section));
            try std.leb.writeUleb128(out.writer(), content.len);
            try out.appendSlice(content);
        }

        if (args.next()) |out_path| {
            const out_file = try std.fs.cwd().createFile(out_path, .{ .truncate = true });
            try out_file.writeAll(out.items);
            out_file.close();

            try stdout.print("crust has compiled {s}.\n", .{ out_path });
        } else {
            if (runWasm(out.items)) |_| {
                try stdout.print("crust is finnished running.\n", .{ });
            } else |e| switch (e) {
                error.FileNotFound => try stdout.print("crust needs you to install wasmtime first.\n", .{}),
                else => return e,
            }
        }
    } else {
        try stdout.print("crust needs a file path.\n", .{});
    }
}
