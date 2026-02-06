const std = @import("std");

pub const CLI = struct {
    pub fn print(message: []const u8) !void {
        var out_buf: [2048]u8 = undefined;
        var out = std.fs.File.stdout().writer(&out_buf);
        try out.interface.print("{s}", .{message});
        try out.interface.flush();
    }

    pub fn prints(messages: []const []const u8) !void {
        for (messages) |message| {
            try CLI.print(message);
            try CLI.print(" ");
        }
    }

    pub fn println(message: []const u8) !void {
        try CLI.print(message);
        try CLI.print("\n");
    }

    pub fn printlns(messages: []const []const u8) !void {
        for (messages) |message| {
            try CLI.println(message);
        }
    }

    pub fn readln(prompt: []const u8) ![]const u8 {
        try CLI.print(prompt);

        var in_buf: [256]u8 = undefined;
        var in_reader = std.fs.File.stdin().reader(&in_buf);
        var line_buf: [16]u8 = undefined;
        const n = try in_reader.read(&line_buf);
        if (n == 0) return "";
        var slice = line_buf[0..n];
        if (std.mem.indexOfScalar(u8, slice, '\n')) |idx| {
            slice = slice[0..idx];
        }
        return std.mem.trim(u8, slice, " \t\r\n");
    }

    pub fn confirm(prompt: []const u8) !bool {
        const input = try CLI.readln(prompt);
        if (input.len == 0) return false;
        return std.ascii.toLower(input[0]) == 'y';
    }
};
