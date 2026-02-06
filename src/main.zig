const std = @import("std");
const builtin = @import("builtin");
const printHelp = @import("help.zig").printHelp;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        try printHelp();
        return;
    }

    const cmd = args[1];
    if (std.mem.eql(u8, cmd, "init")) {
        try initProject(allocator);
        return;
    }

    if (std.mem.eql(u8, cmd, "--help") or std.mem.eql(u8, cmd, "-h")) {
        try printHelp();
        return;
    }

    std.debug.print("Unknown command: {s}\n\n", .{cmd});
    try printHelp();
}

fn initProject(allocator: std.mem.Allocator) !void {
    var out_buf: [2048]u8 = undefined;
    var out = std.fs.File.stdout().writer(&out_buf);
    const dev_mode = builtin.mode == .Debug;
    const target_label = if (dev_mode) "demo-output" else "current folder";
    try out.interface.print("Initializing Tendrils in {s}...\n", .{target_label});
    try out.interface.flush();

    const os_tag = builtin.os.tag;
    const os_name = @tagName(os_tag);

    if (os_tag == .windows) {
        try out.interface.print("Windows support is currently limited; proceeding with file setup only.\n", .{});
        try out.interface.flush();
    }

    try checkPrereqs(allocator, os_tag);

    try createLayout(allocator, os_name, dev_mode);

    try out.interface.print("Initialization complete.\n", .{});
    try out.interface.flush();
}

fn checkPrereqs(allocator: std.mem.Allocator, os_tag: std.Target.Os.Tag) !void {
    var out_buf: [2048]u8 = undefined;
    var out = std.fs.File.stdout().writer(&out_buf);

    if (os_tag == .macos) {
        const has_brew = try hasCommand(allocator, "brew");
        if (!has_brew) {
            if (try confirm("Homebrew not found. Install? [y/N] ")) {
                try out.interface.print("Please install Homebrew: https://brew.sh/\n", .{});
                try out.interface.flush();
            }
        }
    }

    if (os_tag != .windows) {
        const has_ssh = try hasCommand(allocator, "ssh");
        const has_ssh_keygen = try hasCommand(allocator, "ssh-keygen");
        if (!has_ssh or !has_ssh_keygen) {
            if (try confirm("OpenSSH tools not found. Install? [y/N] ")) {
                switch (os_tag) {
                    .macos => {
                        if (try hasCommand(allocator, "brew")) {
                            try out.interface.print("Run: brew install openssh\n", .{});
                            try out.interface.flush();
                        } else {
                            try out.interface.print("Install Homebrew first, then: brew install openssh\n", .{});
                            try out.interface.flush();
                        }
                    },
                    .linux => {
                        if (try isDebianLike()) {
                            try out.interface.print("Run: sudo apt-get update && sudo apt-get install -y openssh-client openssh-server\n", .{});
                            try out.interface.flush();
                        } else {
                            try out.interface.print("Install OpenSSH via your distro package manager.\n", .{});
                            try out.interface.flush();
                        }
                    },
                    else => {
                        try out.interface.print("Install OpenSSH via your system package manager.\n", .{});
                        try out.interface.flush();
                    },
                }
            }
        }
    }
}

fn createLayout(allocator: std.mem.Allocator, os_name: []const u8, dev_mode: bool) !void {
    const cwd = std.fs.cwd();
    const base_path = if (dev_mode) "demo-output" else ".";

    if (dev_mode) {
        try cwd.makePath(base_path);
    }

    var base_dir = try cwd.openDir(base_path, .{});
    defer base_dir.close();

    try base_dir.makePath("profiles/default/scripts");

    const tendrils_json = try std.fmt.allocPrint(
        allocator,
        "{{\n  \"profile\": \"default\",\n  \"platform\": {{ \"os\": \"{s}\" }}\n}}\n",
        .{os_name},
    );
    defer allocator.free(tendrils_json);

    try writeFileIfMissing(base_dir, "tendrils.json", tendrils_json);
    try writeFileIfMissing(base_dir, "hosts.json", "{\n  \"local\": [\"localhost\"]\n}\n");
    try writeFileIfMissing(base_dir, "profiles/default/software_declarations.json",
        "{\n" ++
            "  \"software\": {\n" ++
            "    \"git\": \"latest\"\n" ++
            "  },\n" ++
            "  \"linux\": {\n" ++
            "    \"debian\": {\n" ++
            "      \"match\": [{\n" ++
            "        \"cmd\": \"/etc/os-release\",\n" ++
            "        \"match\": \"ID=debian\"\n" ++
            "      }]\n" ++
            "    }\n" ++
            "  },\n" ++
            "  \"macos\": { \"use\": \"homebrew\" },\n" ++
            "  \"windows\": { \"use\": \"chocolatey\" }\n" ++
            "}\n");
}

fn writeFileIfMissing(cwd: std.fs.Dir, path: []const u8, contents: []const u8) !void {
    var out_buf: [2048]u8 = undefined;
    var out = std.fs.File.stdout().writer(&out_buf);
    if (cwd.createFile(path, .{ .exclusive = true })) |file| {
        defer file.close();
        try file.writeAll(contents);
        try out.interface.print("Created {s}\n", .{path});
        try out.interface.flush();
    } else |err| switch (err) {
        error.PathAlreadyExists => {
            try out.interface.print("Exists  {s}\n", .{path});
            try out.interface.flush();
        },
        else => return err,
    }
}

fn confirm(prompt: []const u8) !bool {
    var out_buf: [2048]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&out_buf);
    try stdout.interface.print("{s}", .{prompt});
    try stdout.interface.flush();

    var in_buf: [256]u8 = undefined;
    var in_reader = std.fs.File.stdin().reader(&in_buf);
    var line_buf: [16]u8 = undefined;
    const n = try in_reader.read(&line_buf);
    if (n == 0) return false;
    var slice = line_buf[0..n];
    if (std.mem.indexOfScalar(u8, slice, '\n')) |idx| {
        slice = slice[0..idx];
    }
    const trimmed = std.mem.trim(u8, slice, " \t\r\n");
    if (trimmed.len == 0) return false;
    return std.ascii.toLower(trimmed[0]) == 'y';
}


fn hasCommand(allocator: std.mem.Allocator, name: []const u8) !bool {
    if (builtin.os.tag == .windows) return false;

    if (std.mem.indexOfScalar(u8, name, '/')) |_| {
        return isExecutable(name);
    }

    const path_env = std.process.getEnvVarOwned(allocator, "PATH") catch |err| switch (err) {
        error.EnvironmentVariableNotFound => return false,
        else => return err,
    };
    defer allocator.free(path_env);

    var it = std.mem.splitScalar(u8, path_env, ':');
    while (it.next()) |dir| {
        if (dir.len == 0) continue;
        const full = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ dir, name });
        defer allocator.free(full);
        if (try isExecutable(full)) return true;
    }

    return false;
}

fn isExecutable(path: []const u8) !bool {
    if (builtin.os.tag == .windows) return false;
    std.posix.access(path, std.posix.X_OK) catch |err| switch (err) {
        error.FileNotFound => return false,
        error.AccessDenied => return false,
        else => return err,
    };
    return true;
}

fn isDebianLike() !bool {
    const cwd = std.fs.cwd();
    if (cwd.openFile("/etc/debian_version", .{})) |file| {
        file.close();
        return true;
    } else |err| switch (err) {
        error.FileNotFound => return false,
        else => return err,
    }
}
