const std = @import("std");

pub const File = struct {
    pub fn write(cwd: std.fs.Dir, path: []const u8, contents: []const u8) !void {
        var out_buf: [2048]u8 = undefined;
        var out = std.fs.File.stdout().writer(&out_buf);

        const file = try cwd.createFile(path, .{ .truncate = true });
        defer file.close();
        try file.writeAll(contents);
        try out.interface.print("Wrote {s}\n", .{path});
        try out.interface.flush();
    }

    pub fn writeIfMissing(cwd: std.fs.Dir, path: []const u8, contents: []const u8) !void {
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

    pub fn writeIfMissingFromFile(cwd: std.fs.Dir, path: []const u8, comptime contentsPath: []const u8) !void {
        const contents = @embedFile(contentsPath);
        try File.writeIfMissing(cwd, path, contents);
    }

    pub fn exists(cwd: std.fs.Dir, path: []const u8) !bool {
        if (cwd.access(path, .{})) |_| {
            return true;
        } else |err| switch (err) {
            error.FileNotFound => return false,
            else => return err,
        }
    }

    pub fn read(cwd: std.fs.Dir, allocator: std.mem.Allocator, path: []const u8) ![]u8 {
        return try cwd.readFileAlloc(allocator, path, std.math.maxInt(usize));
    }

    pub fn readIntoBuffer(cwd: std.fs.Dir, path: []const u8, buffer: []u8) !usize {
        const file = try cwd.openFile(path, .{});
        defer file.close();
        return try file.readAll(buffer);
    }
};
