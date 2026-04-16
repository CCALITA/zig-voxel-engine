/// Core engine module for the voxel engine.
/// Exposes subsystem initialization and the main game loop.
pub const subsystem_count: u32 = 0;

test "subsystem count is valid" {
    const std = @import("std");
    try std.testing.expectEqual(@as(u32, 0), subsystem_count);
}
