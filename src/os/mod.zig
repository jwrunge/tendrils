const std = @import("std");
const builtin = @import("builtin");
const Platform = enum { windows, macos, linux };
const CLI = @import("../io/cli.zig").CLI;

pub const Installable = struct {
    command: []const u8,
    prompt: []const u8,
    use_installer: ?bool,
    commands: ?[]const []const []const u8,
};

pub const OS = struct {
    platform: Platform,
    installer: ?[]const u8,

    pub fn init() !OS {
        const os_tag = builtin.os.tag;

        if (os_tag == .windows) {
            try CLI.println("Windows support is currently limited; proceeding with file setup only.");
        }

        return switch (os_tag) {
            .windows => OS{ .platform = .windows, .installer = null },
            .macos => OS{ .platform = .macos, .installer = "brew install" },
            .linux => OS{ .platform = .linux, .installer = "apt-get install" },
            else => OS{ .platform = .linux, .installer = "apt-get install" },
        };
    }

    pub fn isExecutable(self: *const OS, path: []const u8) !bool {
        if (self.platform == .windows) return false;
        const stat = std.fs.cwd().statFile(path) catch |err| switch (err) {
            error.FileNotFound => return false,
            error.AccessDenied => return false,
            else => return err,
        };
        if (stat.kind != .file) return false;

        std.posix.access(path, std.posix.X_OK) catch |err| switch (err) {
            error.FileNotFound => return false,
            error.AccessDenied => return false,
            else => return err,
        };
        return true;
    }

    pub fn hasCommand(self: *const OS, allocator: std.mem.Allocator, name: []const u8) !bool {
        if (self.platform == .windows) return false;

        if (std.mem.indexOfScalar(u8, name, '/')) |_| {
            return self.isExecutable(name);
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
            if (try self.isExecutable(full)) return true;
        }

        return false;
    }

    pub fn checkInstall(self: *const OS, allocator: std.mem.Allocator, installable: Installable) !void {
        const has_command = try self.hasCommand(allocator, installable.command);
        if (!has_command) {
            if (try CLI.confirm(installable.prompt)) {
                if (installable.use_installer orelse false) {
                    switch (self.platform) {
                        .macos => {
                            _ = try runCommand(allocator, &[_][]const u8{ "brew", "install", installable.command });
                        },
                        .linux => {
                            _ = try runCommand(allocator, &[_][]const u8{ "sudo", "apt-get", "install", "-y", installable.command });
                        },
                        else => {
                            const message = try std.fmt.allocPrint(allocator, "Please install {s} manually.", .{installable.command});
                            defer allocator.free(message);
                            try CLI.println(message);
                        },
                    }
                } else if (installable.commands) |commands| {
                    const terms = try runCommandsSequential(allocator, commands);
                    allocator.free(terms);
                } else {
                    const message = try std.fmt.allocPrint(allocator, "Please install {s} manually.", .{installable.command});
                    defer allocator.free(message);
                    try CLI.println(message);
                }
            } else {
                const message = try std.fmt.allocPrint(allocator, "{s} not installed.", .{installable.command});
                defer allocator.free(message);
                try CLI.println(message);
            }
        }
    }

    pub fn checkPrereqs(self: *const OS, allocator: std.mem.Allocator) !void {
        // Check for platform-specific prerequisites
        switch (self.platform) {
            .windows => {},
            .macos => {
                try self.checkInstall(allocator, .{
                    .command = "brew",
                    .prompt = "Homebrew not found. Install? [y/N] ",
                    .use_installer = null,
                    .commands = &[_][]const []const u8{
                        &[_][]const u8{
                            "/bin/bash",
                            "-c",
                            "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)",
                        },
                    },
                });
            },
            // linux
            else => {},
        }

        // Check SSH
        try self.checkInstall(allocator, .{ .command = "ssh", .prompt = "ssh not found. Install? [y/N] ", .use_installer = true, .commands = null });
        try self.checkInstall(allocator, .{ .command = "ssh-keygen", .prompt = "ssh-keygen not found. Install? [y/N] ", .use_installer = true, .commands = null });

        // Check SSH
        try self.checkInstall(allocator, .{ .command = "yazi", .prompt = "yazi not found. Install? [y/N] ", .use_installer = true, .commands = null });
    }
};

fn runCommand(allocator: std.mem.Allocator, argv: []const []const u8) !std.process.Child.Term {
    var child = std.process.Child.init(argv, allocator);
    child.stdin_behavior = .Inherit;
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;
    try child.spawn();
    return child.wait();
}

fn runCommandsSequential(allocator: std.mem.Allocator, commands: []const []const []const u8) ![]std.process.Child.Term {
    var terms = try allocator.alloc(std.process.Child.Term, commands.len);
    for (commands, 0..) |argv, i| {
        terms[i] = try runCommand(allocator, argv);
    }
    return terms;
}

fn runCommandsParallel(allocator: std.mem.Allocator, commands: []const []const []const u8) ![]std.process.Child.Term {
    var children = try allocator.alloc(std.process.Child, commands.len);
    var terms = try allocator.alloc(std.process.Child.Term, commands.len);

    var spawned: usize = 0;
    errdefer {
        var i: usize = 0;
        while (i < spawned) : (i += 1) {
            _ = children[i].wait() catch {};
        }
        allocator.free(children);
        allocator.free(terms);
    }

    for (commands, 0..) |argv, i| {
        children[i] = std.process.Child.init(argv, allocator);
        children[i].stdin_behavior = .Inherit;
        children[i].stdout_behavior = .Inherit;
        children[i].stderr_behavior = .Inherit;
        try children[i].spawn();
        spawned += 1;
    }

    for (children, 0..) |*child, i| {
        terms[i] = try child.wait();
    }

    allocator.free(children);
    return terms;
}

fn runSequentialCommandGroups(
    allocator: std.mem.Allocator,
    groups: []const []const []const []const u8,
) ![]std.process.Child.Term {
    var total: usize = 0;
    for (groups) |group| total += group.len;

    var terms = try allocator.alloc(std.process.Child.Term, total);
    var offset: usize = 0;

    for (groups) |group| {
        const group_terms = try runCommandsParallel(allocator, group);
        defer allocator.free(group_terms);
        std.mem.copy(std.process.Child.Term, terms[offset .. offset + group_terms.len], group_terms);
        offset += group_terms.len;
    }

    return terms;
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
