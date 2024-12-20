pub const std = @import("std");
pub const stdout = std.io.getStdOut().writer();

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
    // compile: []const u8,
    // unpack: []const u8,
    // explain: CompilerError,
    // test_: []const u8,
    help,
    error_: Error,

    pub const Error = union(enum) {
        no_command,
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
            return Command{ .error_ = Command.Error{ .not_implemented = command_str } };
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
    try switch (parse_args(&args)) {
        .help => stdout.print("\n{s}\n", .{usage}),
        .error_ => |command_error| {
            switch (command_error) {
                .file_not_found => |file| try stdout.print("crust could not find file: \"{s}\"\n", .{file}),
                .not_implemented => |command| try stdout.print("\"{s}\" is not implemented yet. Sorry.\n", .{command}),
                .unknown_commad => |command| try stdout.print("crust does not know any command called \"{s}\"\n", .{command}),
                .no_command => try stdout.print("\nPlease consult the usage printout below:\n\n{s}\n", .{usage}),
            }
        },
    };
}
