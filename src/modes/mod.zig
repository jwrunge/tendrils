const std = @import("std");
const State = @import("../state.zig").State;
const printHelp = @import("./help.zig").printHelp;
const initProject = @import("./init.zig").initProject;

pub fn dispatch(allocator: std.mem.Allocator, state: State) !void {
    switch (state.mode) {
        .Help => {
            try printHelp();
            return;
        },
        .Init => {
            try initProject(allocator);
            return;
        },
    }
}
