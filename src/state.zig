const std = @import("std");
const CLI = @import("io/cli.zig").CLI;
const OS = @import("os/mod.zig").OS;

pub const StateMode = enum { Help, Init };

pub const State = struct {
    mode: StateMode,
    os: OS,

    pub fn init(allocator: std.mem.Allocator) !State {
        const args = try std.process.argsAlloc(allocator);
        defer std.process.argsFree(allocator, args);

        var mode: StateMode = .Help;

        if (args.len > 1) {
            const cmd = args[1];

            if (std.mem.eql(u8, cmd, "help") or std.mem.eql(u8, cmd, "--help") or std.mem.eql(u8, cmd, "-h")) {
                mode = .Help;
            } else if (std.mem.eql(u8, cmd, "init")) {
                mode = .Init;
            } else {
                try CLI.println("\ntendrils: Unknown command");
                std.debug.print("Unknown command: {s}\n\n", .{cmd});
                mode = .Help;
            }
        }

        return State{
            .mode = mode,
            .os = try OS.init(),
        };
    }
};
