const std = @import("std");

pub const CLI = struct {
    pub fn print(message: []const u8) !void {
        var out_buf: [2048]u8 = undefined;
        var out = std.fs.File.stdout().writer(&out_buf);
        try out.interface.print("{s}", .{message});
        try out.interface.flush();
    }

    pub fn println(message: []const u8) !void {
        var out_buf: [2048]u8 = undefined;
        var out = std.fs.File.stdout().writer(&out_buf);
        try out.interface.print("{s}\n", .{message});
        try out.interface.flush();
    }

    pub fn printlns(messages: []const []const u8) !void {
        for (messages) |message| {
            try CLI.println(message);
        }
    }
};