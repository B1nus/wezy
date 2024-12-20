pub const std = @import("std");
pub const Tokenizer = @import("Tokenizer.zig");
pub const Parser = @import("Parser.zig");
pub const Compiler = @import("Compiler.zig");
pub const stdout = std.io.getStdOut().writer();
pub const allocator = std.heap.page_allocator;

// TODO: ANSI for coloring and text styling. Make it pretty! :)
const usage =
    \\Usage:
    \\$ crust run file.crs        # Run program
    \\$ crust compile file.crs    # Compile to file.html
    \\$ crust unpack file.html    # Unpack file.html into index.html, index.js, index.css and index.wasm. Store in a folder called ./file/
    \\$ crust explain 13          # Explain compiler error 13
    \\$ crust test file.crs       # Run all tests in file.crs and imported files
    \\$ crust help                # Display this help message
    \\
;

pub const Command = union(enum) {
    // run: []const u8,
    compile: []const u8,
    // unpack: []const u8,
    // explain: CompilerError,
    // test_: []const u8,
    help,
    error_: Error,

    pub const Error = union(enum) {
        no_command,
        missing_compile_file,
        // unknown_error: CompilerError,
        unknown_commad: []const u8,
        not_implemented: []const u8,
        file_not_found: []const u8,
    };
};

pub fn parse_args(args: *std.process.ArgIterator) Command {
    if (!args.skip()) {
        unreachable;
    }

    if (args.next()) |command_str| {
        if (std.mem.eql(u8, command_str, "help")) {
            return Command.help;
        } else if (std.mem.eql(u8, command_str, "run")) {
            return Command{ .error_ = Command.Error{ .not_implemented = command_str } };
        } else if (std.mem.eql(u8, command_str, "compile")) {
            if (args.next()) |file_path| {
                return Command{ .compile = file_path };
            } else {
                return Command{ .error_ = Command.Error.missing_compile_file };
            }
        } else if (std.mem.eql(u8, command_str, "unpack")) {
            return Command{ .error_ = Command.Error{ .not_implemented = command_str } };
        } else if (std.mem.eql(u8, command_str, "test")) {
            return Command{ .error_ = Command.Error{ .not_implemented = command_str } };
        } else if (std.mem.eql(u8, command_str, "explain")) {
            return Command{ .error_ = Command.Error{ .not_implemented = command_str } };
        } else if (std.mem.eql(u8, command_str, "run")) {
            return Command{ .error_ = Command.Error{ .not_implemented = command_str } };
        } else {
            return Command{ .error_ = Command.Error{ .unknown_commad = command_str } };
        }
    } else {
        return Command{ .error_ = Command.Error.no_command };
    }
}

pub fn main() !void {
    var args = std.process.args();
    try state: switch (parse_args(&args)) {
        .help => stdout.print("\n{s}\n", .{usage}),
        .compile => |file_path| {
            if (std.fs.cwd().openFile(file_path, .{})) |file| {
                var source = std.ArrayList(u8).fromOwnedSlice(std.heap.page_allocator, try file.readToEndAlloc(std.heap.page_allocator, 0xFFFFFFFF));
                try source.append(0);
                const base_name = std.fs.path.basename(file_path);
                const dot_pos = std.mem.lastIndexOfScalar(u8, base_name, '.') orelse base_name.len;
                const name = try allocator.alloc(u8, dot_pos + 5);
                std.mem.copyForwards(u8, name, base_name);
                std.mem.copyForwards(u8, name[dot_pos..], ".wasm");

                // Compilation
                var tokenizer = Tokenizer.init(@ptrCast(source.items));
                var parser = Parser.init(&tokenizer, allocator);
                var compiler = Compiler.init(&parser, allocator);
                const wasm = try compiler.compile(allocator); // TODO Error handling
                defer compiler.deinit();
                defer source.deinit();
                defer wasm.deinit();

                // WARǸING. This overwrites the file
                //
                // TODO Let users change output filename
                const wasm_file = try std.fs.cwd().createFile(name, .{}); // TODO Error handling
                _ = try wasm_file.write(wasm.items);
            } else |file_open_error| {
                switch (file_open_error) {
                    std.fs.File.OpenError.FileNotFound => continue :state Command{ .error_ = Command.Error{ .file_not_found = file_path } },
                    else => unreachable, // TODO Error handling
                }
            }
        },
        .error_ => |command_error| {
            switch (command_error) {
                .file_not_found => |file| try stdout.print("crust could not find file: \"{s}\"\n", .{file}),
                .missing_compile_file => try stdout.print("Please provide a file to compile.\n", .{}),
                .not_implemented => |command| try stdout.print("\"{s}\" is not implemented yet. Sorry.\n", .{command}),
                .unknown_commad => |command| try stdout.print("crust does not know any command called \"{s}\"\n", .{command}),
                .no_command => try stdout.print("\nPlease consult the usage printout below:\n\n{s}\n", .{usage}),
            }
        },
    };
}
