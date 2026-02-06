const std = @import("std");
const State = @import("state.zig").State;
const dispatch = @import("modes/mod.zig").dispatch;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const state = try State.init(allocator);
    try dispatch(allocator, state);
}
