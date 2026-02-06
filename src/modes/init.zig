const std = @import("std");
const builtin = @import("builtin");
const CLI = @import("../io/cli.zig").CLI;
const File = @import("../io/file.zig").File;
const State = @import("../state.zig").State;

pub fn initProject(allocator: std.mem.Allocator, state: State) !void {
    const dev_mode = builtin.mode == .Debug;
    const target_label = if (dev_mode) "demo-output" else "current folder";

    try CLI.println("Initializing Tendrils in " ++ target_label);

    try state.os.checkPrereqs(allocator);
    try createLayout(dev_mode);
    try CLI.println("Initialization complete.");
}

fn createLayout(dev_mode: bool) !void {
    const cwd = std.fs.cwd();
    const base_path = if (dev_mode) "demo-output" else ".";

    if (dev_mode) {
        try cwd.makePath(base_path);
    }

    var base_dir = try cwd.openDir(base_path, .{});
    defer base_dir.close();

    try base_dir.makePath("profiles/default/scripts");

    try File.writeIfMissingFromFile(base_dir, "tendrils.json", "../defaults/tendrils.json");
    try File.writeIfMissingFromFile(base_dir, "hosts.json", "../defaults/hosts.json");
    try File.writeIfMissingFromFile(base_dir, "profiles/default/software_declarations.json", "../defaults/software_declarations.json");
}
