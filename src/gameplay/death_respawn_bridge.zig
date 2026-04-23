/// Bridge that combines death_drops and respawn_system into a single
/// `processPlayerDeath` call, returning drops, XP, and respawn coordinates.

const std = @import("std");
const dd = @import("death_drops.zig");
const rs = @import("respawn_system.zig");

// Re-export commonly used types so callers only need this module.
pub const Slot = dd.Slot;
pub const ItemDrop = dd.ItemDrop;
pub const BlockPos = rs.BlockPos;

/// Complete result of a player death: item drops, XP to scatter, and where the
/// player will respawn.
pub const DeathResult = struct {
    drops: [40]?dd.ItemDrop,
    xp_to_drop: u32,
    respawn_x: f32,
    respawn_y: f32,
    respawn_z: f32,
};

const empty_drops: [40]?dd.ItemDrop = .{null} ** 40;

/// Process a player death end-to-end.
///
/// 1. Decides whether the inventory should be kept (creative mode or
///    keepInventory game rule).
/// 2. If not kept, scatters inventory + armor as item drops around the
///    death position.
/// 3. Calculates XP to drop (0 when inventory is kept).
/// 4. Resolves the respawn point (bed spawn preferred, world spawn fallback).
pub fn processPlayerDeath(
    inv: [36]dd.Slot,
    armor: [4]dd.Slot,
    death_x: f32,
    death_y: f32,
    death_z: f32,
    xp: u32,
    level: u32,
    is_creative: bool,
    keep_inv: bool,
    bed_spawn: ?rs.BlockPos,
    world_spawn: rs.BlockPos,
) DeathResult {
    const keep = dd.shouldKeepInventory(is_creative, keep_inv);

    const drops = if (keep) empty_drops else dd.scatterInventory(inv, armor, death_x, death_y, death_z);
    const xp_to_drop = if (keep) @as(u32, 0) else rs.calculateXPDrop(xp, level);

    const respawn = rs.getRespawnPoint(bed_spawn, world_spawn);

    return .{
        .drops = drops,
        .xp_to_drop = xp_to_drop,
        .respawn_x = respawn.x,
        .respawn_y = respawn.y,
        .respawn_z = respawn.z,
    };
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

fn countDrops(drops: [40]?dd.ItemDrop) usize {
    var n: usize = 0;
    for (drops) |d| {
        if (d != null) n += 1;
    }
    return n;
}

fn makeInv(item: u16, count: u8) [36]dd.Slot {
    return .{dd.Slot{ .item = item, .count = count }} ** 36;
}

const empty_inv = [_]dd.Slot{dd.Slot.empty} ** 36;
const empty_armor = [_]dd.Slot{dd.Slot.empty} ** 4;
const default_world_spawn = rs.BlockPos{ .x = 0, .y = 64, .z = 0 };

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "survival death scatters full inventory" {
    const result = processPlayerDeath(
        makeInv(1, 1),
        .{dd.Slot{ .item = 2, .count = 1 }} ** 4,
        0.0,
        64.0,
        0.0,
        100,
        10,
        false,
        false,
        null,
        default_world_spawn,
    );

    try std.testing.expectEqual(@as(usize, 40), countDrops(result.drops));
    try std.testing.expect(result.xp_to_drop > 0);
}

test "creative mode keeps inventory and drops no XP" {
    const result = processPlayerDeath(
        makeInv(1, 1),
        .{dd.Slot{ .item = 2, .count = 1 }} ** 4,
        0.0,
        64.0,
        0.0,
        500,
        20,
        true,
        false,
        null,
        default_world_spawn,
    );

    try std.testing.expectEqual(@as(usize, 0), countDrops(result.drops));
    try std.testing.expectEqual(@as(u32, 0), result.xp_to_drop);
}

test "keepInventory rule keeps inventory and drops no XP" {
    const result = processPlayerDeath(
        makeInv(1, 1),
        .{dd.Slot{ .item = 2, .count = 1 }} ** 4,
        0.0,
        64.0,
        0.0,
        500,
        20,
        false,
        true,
        null,
        default_world_spawn,
    );

    try std.testing.expectEqual(@as(usize, 0), countDrops(result.drops));
    try std.testing.expectEqual(@as(u32, 0), result.xp_to_drop);
}

test "respawn at bed spawn when available" {
    const bed = rs.BlockPos{ .x = 100, .y = 70, .z = -50 };
    const result = processPlayerDeath(
        empty_inv,
        empty_armor,
        0.0,
        64.0,
        0.0,
        0,
        0,
        false,
        false,
        bed,
        default_world_spawn,
    );

    try std.testing.expectApproxEqAbs(@as(f32, 100.5), result.respawn_x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 70.0), result.respawn_y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, -49.5), result.respawn_z, 0.001);
}

test "respawn at world spawn when bed is null" {
    const result = processPlayerDeath(
        empty_inv,
        empty_armor,
        0.0,
        64.0,
        0.0,
        0,
        0,
        false,
        false,
        null,
        default_world_spawn,
    );

    try std.testing.expectApproxEqAbs(@as(f32, 0.5), result.respawn_x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 64.0), result.respawn_y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), result.respawn_z, 0.001);
}

test "XP drop uses level-based formula" {
    // level 5, 1000 xp => min(5*7, 100) = 35
    const result = processPlayerDeath(
        empty_inv,
        empty_armor,
        0.0,
        64.0,
        0.0,
        1000,
        5,
        false,
        false,
        null,
        default_world_spawn,
    );

    try std.testing.expectEqual(@as(u32, 35), result.xp_to_drop);
}

test "XP drop capped at 100" {
    // level 20 => 20*7 = 140, capped to 100
    const result = processPlayerDeath(
        empty_inv,
        empty_armor,
        0.0,
        64.0,
        0.0,
        500,
        20,
        false,
        false,
        null,
        default_world_spawn,
    );

    try std.testing.expectEqual(@as(u32, 100), result.xp_to_drop);
}

test "XP drop capped by total XP available" {
    // level 10 => 70, but only 30 xp total
    const result = processPlayerDeath(
        empty_inv,
        empty_armor,
        0.0,
        64.0,
        0.0,
        30,
        10,
        false,
        false,
        null,
        default_world_spawn,
    );

    try std.testing.expectEqual(@as(u32, 30), result.xp_to_drop);
}

test "empty inventory produces no drops" {
    const result = processPlayerDeath(
        empty_inv,
        empty_armor,
        50.0,
        100.0,
        50.0,
        0,
        0,
        false,
        false,
        null,
        default_world_spawn,
    );

    try std.testing.expectEqual(@as(usize, 0), countDrops(result.drops));
    try std.testing.expectEqual(@as(u32, 0), result.xp_to_drop);
}

test "drops are near death position" {
    var inv = empty_inv;
    inv[0] = dd.Slot{ .item = 42, .count = 1 };

    const result = processPlayerDeath(
        inv,
        empty_armor,
        200.0,
        80.0,
        -300.0,
        100,
        5,
        false,
        false,
        null,
        default_world_spawn,
    );

    const drop = result.drops[0].?;
    try std.testing.expect(@abs(drop.x - 200.0) < 1.0);
    try std.testing.expect(@abs(drop.y - 80.0) < 1.0);
    try std.testing.expect(@abs(drop.z - (-300.0)) < 1.0);
}

test "armor slots appear in drop indices 36-39" {
    var armor = empty_armor;
    armor[0] = dd.Slot{ .item = 300, .count = 1 };
    armor[3] = dd.Slot{ .item = 303, .count = 1 };

    const result = processPlayerDeath(
        empty_inv,
        armor,
        0.0,
        64.0,
        0.0,
        0,
        0,
        false,
        false,
        null,
        default_world_spawn,
    );

    try std.testing.expect(result.drops[36] != null);
    try std.testing.expectEqual(@as(u16, 300), result.drops[36].?.item);
    try std.testing.expect(result.drops[37] == null);
    try std.testing.expect(result.drops[38] == null);
    try std.testing.expect(result.drops[39] != null);
    try std.testing.expectEqual(@as(u16, 303), result.drops[39].?.item);
}

test "creative with both flags still keeps inventory" {
    const result = processPlayerDeath(
        makeInv(1, 1),
        .{dd.Slot{ .item = 2, .count = 1 }} ** 4,
        0.0,
        64.0,
        0.0,
        999,
        30,
        true,
        true,
        null,
        default_world_spawn,
    );

    try std.testing.expectEqual(@as(usize, 0), countDrops(result.drops));
    try std.testing.expectEqual(@as(u32, 0), result.xp_to_drop);
}

test "negative-coordinate bed spawn resolves correctly" {
    const bed = rs.BlockPos{ .x = -100, .y = 5, .z = -200 };
    const result = processPlayerDeath(
        empty_inv,
        empty_armor,
        0.0,
        0.0,
        0.0,
        0,
        0,
        false,
        false,
        bed,
        default_world_spawn,
    );

    try std.testing.expectApproxEqAbs(@as(f32, -99.5), result.respawn_x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), result.respawn_y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, -199.5), result.respawn_z, 0.001);
}
