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
    run: []const u8,
    compile: []const u8,
    // unpack: []const u8,
    // explain: CompilerError,
    // test_: []const u8,
    help,
    error_: Error,

    pub const Error = union(enum) {
        no_command,
        missing_compile_file,
        missing_run_file,
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
            if (args.next()) |file_path| {
                return Command{ .run = file_path };
            } else {
                return Command{ .error_ = Command.Error.missing_run_file };
            }
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

pub fn compile(source: [:0]const u8) !std.ArrayList(u8) {
    var tokenizer = Tokenizer.init(source);
    var parser = Parser.init(&tokenizer, allocator);
    var compiler = Compiler.init(&parser, allocator);
    const wasm_bytes = try compiler.compile(allocator); // TODO Error handling
    defer compiler.deinit();
    return wasm_bytes;
}

// Hard coded static files
pub const routes = std.StaticStringMap(struct { []const u8, std.http.Header }).initComptime(.{
    .{
        "/",
        .{
            \\<!DOCTYPE html>
            \\<html>
            \\<head>
            \\  <link rel="stylesheet" href="index.css">
            \\</head>
            \\<body>
            \\  <h1>Console</h1>
            \\  <div id="console"></div>
            \\  <script src="index.js"></script>
            \\</body>
            \\</html>
            ,
            std.http.Header{ .name = "Content-Type", .value = "text/html" },
        },
    },
    .{
        "/index.js",
        .{
            \\const imports = { imports: { log: arg => log(arg) } };
            \\
            \\const consoleDiv = document.getElementById('console');
            \\
            \\function log(message) {
            \\    const newLine = document.createElement('div');
            \\    newLine.textContent = message;
            \\    consoleDiv.appendChild(newLine);
            \\    consoleDiv.scrollTop = consoleDiv.scrollHeight; // Auto-scroll to bottom
            \\}
            \\
            \\log("Hello from crust!");
            \\
            \\// Fetch the WebAssembly file
            \\fetch('index.wasm')
            \\    .then(response => response.arrayBuffer()) // Get the binary data
            \\    .then(bytes => WebAssembly.instantiate(bytes, imports)) // Instantiate the WebAssembly module
            \\    .then(result => {
            \\        // The WebAssembly instance is available in `result.instance`
            \\        console.log("WASM Module Loaded:", result.instance);
            \\        // Call an exported function (if any)
            \\        result.instance.exports.START();
            \\    })
            \\.catch(err => {
            \\    console.error("Error loading WASM file:", err);
            \\});
            ,
            std.http.Header{ .name = "Content-Type", .value = "application/javascript" },
        },
    },
    .{ "/index.wasm", .{ "", std.http.Header{ .name = "Content-Type", .value = "application/wasm" } } },
    .{ "/index.css", .{ "div { color: white; background-color: black; height: 100%; }", std.http.Header{ .name = "Content-Type", .value = "text/css" } } },
});

pub fn run(wasm: []const u8, allocator_: std.mem.Allocator) !void {
    var listener = try (try std.net.Address.resolveIp("127.0.0.1", 3597)).listen(.{
        .reuse_address = true,
    });
    defer listener.deinit();
    try stdout.print("running on port http://127.0.0.1:{d}/\n\n", .{listener.listen_address.getPort()});

    while (true) {
        var server = try listener.accept();

        var handle = try std.Thread.spawn(.{ .allocator = allocator }, create_connection, .{ wasm, &server, allocator_ });
        handle.detach();
    }
}

pub fn create_connection(wasm: []const u8, Conn: *std.net.Server.Connection, allocator_: std.mem.Allocator) !void {
    outer: while (true) {
        var client_head_buffer: [1024]u8 = undefined;
        var http_server = std.http.Server.init(Conn.*, &client_head_buffer);

        while (http_server.state == .ready) {
            var request = http_server.receiveHead() catch |err| switch (err) {
                error.HttpHeadersInvalid => continue :outer,
                error.HttpConnectionClosing => continue,
                error.HttpHeadersUnreadable => continue,
                else => |e| return e,
            };
            const body = try (try request.reader()).readAllAlloc(allocator_, 8192);
            defer allocator_.free(body);

            if (routes.get(request.head.target)) |route| {
                const content, const header = route;
                if (std.mem.eql(u8, request.head.target, "/index.wasm")) {
                    try request.respond(wasm, .{ .status = .ok, .extra_headers = &.{header} });
                } else {
                    try request.respond(content, .{ .status = .ok, .extra_headers = &.{header} });
                }
            } else {
                try stdout.print("Could not find route \"{s}\"\n", .{request.head.target});
                try request.respond("It not workie\n", .{ .status = .bad_request });
            }
        }
    }
}

pub fn main() !void {
    var args = std.process.args();
    try state: switch (parse_args(&args)) {
        .help => stdout.print("\n{s}\n", .{usage}),
        .compile => |file_path| {
            if (std.fs.cwd().openFile(file_path, .{})) |file| {
                // Compilation
                const source = try file.readToEndAllocOptions(allocator, 0xFFFFFFFF, null, 8, 0); // TODO Error handling
                const wasm = try compile(source);
                defer wasm.deinit();

                // Construct output file name
                //
                // TODO Let users choose the output name
                const base_name = std.fs.path.basename(file_path);
                const dot_pos = std.mem.lastIndexOfScalar(u8, base_name, '.') orelse base_name.len;
                const name = try allocator.alloc(u8, dot_pos + 5);
                std.mem.copyForwards(u8, name, base_name);
                std.mem.copyForwards(u8, name[dot_pos..], ".wasm");

                // Write to file (OVERWRITES THE OLD FILE)
                const wasm_file = try std.fs.cwd().createFile(name, .{}); // TODO Error handling
                _ = try wasm_file.write(wasm.items);
            } else |file_open_error| {
                switch (file_open_error) {
                    std.fs.File.OpenError.FileNotFound => continue :state Command{ .error_ = Command.Error{ .file_not_found = file_path } },
                    else => unreachable, // TODO Error handling
                }
            }
        },
        .run => |file_path| {
            // There is so much repetition in this file. It hurts.
            if (std.fs.cwd().openFile(file_path, .{})) |file| {
                // Compilation
                const source = try file.readToEndAllocOptions(allocator, 0xFFFFFFFF, null, 8, 0); // TODO Error handling
                const wasm = try compile(source);
                defer wasm.deinit();

                try run(wasm.items, allocator);
            } else |file_open_error| {
                switch (file_open_error) {
                    std.fs.File.OpenError.FileNotFound => continue :state Command{ .error_ = Command.Error{ .file_not_found = file_path } },
                    else => unreachable, // TODO Error handling
                }
            }
        },
        .error_ => |command_error| {
            switch (command_error) {
                .file_not_found => |file| try stdout.print("crust could not find file \"{s}\"\n", .{file}),
                .missing_compile_file => try stdout.print("Please provide a file to compile.\n", .{}),
                .missing_run_file => try stdout.print("Please provide a file to run.\n", .{}),
                .not_implemented => |command| try stdout.print("\"{s}\" is not implemented yet. Sorry.\n", .{command}),
                .unknown_commad => |command| try stdout.print("crust does not know any command called \"{s}\"\n", .{command}),
                .no_command => try stdout.print("\nPlease consult the usage printout below:\n\n{s}\n", .{usage}),
            }
        },
    };
}
