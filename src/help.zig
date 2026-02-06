const CLI = @import("io/cli.zig").CLI;

pub fn printHelp() !void {
    try CLI.printlns(&[_][]const u8{
        "\n",
        "--------------------",
        "\n",
        "Tendrils (preview)\n",
        "  Usage",
        "   tendrils init",
        "\n",
        "  Commands:",
        "    init    Initialize tendrils in the current folder",
        "\n",
        "--------------------",
        "\n",
    });
}