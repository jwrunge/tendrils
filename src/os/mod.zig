const std = @import("std");
const builtin = @import("builtin");
const Platform = enum { windows, macos, linux };
const CLI = @import("../io/cli.zig").CLI;

pub const OS = struct {
    platform: Platform,

    pub fn init() !OS {
        const os_tag = builtin.os.tag;

        if (os_tag == .windows) {
            try CLI.println("Windows support is currently limited; proceeding with file setup only.");
        }

        return switch (os_tag) {
            .windows => OS{ .platform = .windows },
            .macos => OS{ .platform = .macos },
            .linux => OS{ .platform = .linux },
            else => OS{ .platform = .linux },
        };
    }

    pub fn isExecutable(self: *const OS, path: []const u8) !bool {
        if (self.platform == .windows) return false;
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

    pub fn checkPrereqs(self: *const OS, allocator: std.mem.Allocator) !void {
        switch (self.platform) {
            .windows => {},
            .macos => {
                const has_brew = try self.hasCommand(allocator, "brew");
                if (!has_brew) {
                    if (try CLI.confirm("Homebrew not found. Install? [y/N] ")) {
                        try CLI.println("Please install Homebrew: https://brew.sh/");
                    }
                }
            },
            else => {
                const has_ssh = try self.hasCommand(allocator, "ssh");
                const has_ssh_keygen = try self.hasCommand(allocator, "ssh-keygen");
                if (!has_ssh or !has_ssh_keygen) {
                    if (try CLI.confirm("OpenSSH tools not found. Install? [y/N] ")) {
                        switch (self.platform) {
                            .macos => {
                                if (try self.hasCommand(allocator, "brew")) {
                                    try CLI.println("Run: brew install openssh");
                                } else {
                                    try CLI.println("Install Homebrew first, then: brew install openssh");
                                }
                            },
                            .linux => {
                                if (try isDebianLike()) {
                                    try CLI.println("Run: sudo apt-get update && sudo apt-get install -y openssh-client openssh-server");
                                } else {
                                    try CLI.println("Install OpenSSH via your distro package manager.");
                                }
                            },
                            else => {
                                try CLI.println("Install OpenSSH via your system package manager.");
                            },
                        }
                    }
                }
            },
        }
    }
};

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
