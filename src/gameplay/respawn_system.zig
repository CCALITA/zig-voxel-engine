const std = @import("std");

/// Action returned by the respawn system describing how to reset a player.
pub const RespawnAction = struct {
    x: f32,
    y: f32,
    z: f32,
    health: u8 = 20,
    hunger: u8 = 20,
    clear_effects: bool = true,
    reset_fall: bool = true,
};

const block_offset: f32 = 0.5;

pub const BlockPos = struct { x: i32, y: i32, z: i32 };

fn toRespawnAction(pos: BlockPos) RespawnAction {
    return .{
        .x = @as(f32, @floatFromInt(pos.x)) + block_offset,
        .y = @as(f32, @floatFromInt(pos.y)),
        .z = @as(f32, @floatFromInt(pos.z)) + block_offset,
    };
}

/// Determines where a player should respawn and returns the corresponding action.
/// Prefers the bed spawn point when available; falls back to world spawn.
pub fn getRespawnPoint(bed_spawn: ?BlockPos, world_spawn: BlockPos) RespawnAction {
    return toRespawnAction(bed_spawn orelse world_spawn);
}

/// Maximum XP that can be dropped on death.
const max_xp_drop: u32 = 100;

/// Calculates how much XP a player drops on death.
/// Drops min(level * 7, 100) capped to total_xp.
pub fn calculateXPDrop(total_xp: u32, level: u32) u32 {
    const raw = @min(level * 7, max_xp_drop);
    return @min(raw, total_xp);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "getRespawnPoint uses bed spawn when present" {
    const action = getRespawnPoint(
        .{ .x = 10, .y = 64, .z = -20 },
        .{ .x = 0, .y = 70, .z = 0 },
    );
    try std.testing.expectApproxEqAbs(@as(f32, 10.5), action.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 64.0), action.y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, -19.5), action.z, 0.001);
}

test "getRespawnPoint falls back to world spawn when bed is null" {
    const action = getRespawnPoint(null, .{ .x = 0, .y = 70, .z = 0 });
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), action.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 70.0), action.y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), action.z, 0.001);
}

test "getRespawnPoint defaults health to 20" {
    const action = getRespawnPoint(null, .{ .x = 0, .y = 64, .z = 0 });
    try std.testing.expectEqual(@as(u8, 20), action.health);
}

test "getRespawnPoint defaults hunger to 20" {
    const action = getRespawnPoint(null, .{ .x = 0, .y = 64, .z = 0 });
    try std.testing.expectEqual(@as(u8, 20), action.hunger);
}

test "getRespawnPoint defaults clear_effects to true" {
    const action = getRespawnPoint(null, .{ .x = 0, .y = 64, .z = 0 });
    try std.testing.expect(action.clear_effects);
}

test "getRespawnPoint defaults reset_fall to true" {
    const action = getRespawnPoint(null, .{ .x = 0, .y = 64, .z = 0 });
    try std.testing.expect(action.reset_fall);
}

test "getRespawnPoint handles negative coordinates" {
    const action = getRespawnPoint(
        .{ .x = -100, .y = 5, .z = -200 },
        .{ .x = 0, .y = 70, .z = 0 },
    );
    try std.testing.expectApproxEqAbs(@as(f32, -99.5), action.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), action.y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, -199.5), action.z, 0.001);
}

test "calculateXPDrop basic formula" {
    // level 5 => 5*7 = 35, total_xp 1000 => drop 35
    try std.testing.expectEqual(@as(u32, 35), calculateXPDrop(1000, 5));
}

test "calculateXPDrop caps at 100" {
    // level 20 => 20*7 = 140, capped to 100
    try std.testing.expectEqual(@as(u32, 100), calculateXPDrop(500, 20));
}

test "calculateXPDrop capped by total_xp" {
    // level 10 => 10*7 = 70, but only 30 XP available
    try std.testing.expectEqual(@as(u32, 30), calculateXPDrop(30, 10));
}

test "calculateXPDrop at level zero" {
    try std.testing.expectEqual(@as(u32, 0), calculateXPDrop(100, 0));
}

test "calculateXPDrop with zero total_xp" {
    try std.testing.expectEqual(@as(u32, 0), calculateXPDrop(0, 10));
}

test "calculateXPDrop at exact cap boundary" {
    // level ~14 => 14*7 = 98 (under cap), level 15 => 105 (over cap)
    try std.testing.expectEqual(@as(u32, 98), calculateXPDrop(200, 14));
    try std.testing.expectEqual(@as(u32, 100), calculateXPDrop(200, 15));
}
