const std = @import("std");
const engine = @import("engine");

pub fn main() !void {
    std.debug.print("zig-voxel-engine v0.1.0\n", .{});
    std.debug.print("Subsystems: {d}\n", .{engine.subsystem_count});
}

test "engine module is importable" {
    try std.testing.expectEqual(@as(u32, 0), engine.subsystem_count);
}
