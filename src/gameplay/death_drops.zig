/// Death drop system: scatters player inventory and armor as item drops on death,
/// determines keep-inventory rules, and calculates mob XP drops.

const std = @import("std");

// ---------------------------------------------------------------------------
// Core types
// ---------------------------------------------------------------------------

pub const Slot = struct {
    item: u16,
    count: u8,

    pub const empty = Slot{ .item = 0, .count = 0 };

    pub fn isEmpty(s: Slot) bool {
        return s.count == 0;
    }
};

pub const ItemDrop = struct {
    x: f32,
    y: f32,
    z: f32,
    item: u16,
    count: u8,
};

// ---------------------------------------------------------------------------
// Mob type constants
// ---------------------------------------------------------------------------

pub const MOB_ZOMBIE: u8 = 0;
pub const MOB_SKELETON: u8 = 1;
pub const MOB_CREEPER: u8 = 2;
pub const MOB_SPIDER: u8 = 3;
pub const MOB_ENDERMAN: u8 = 4;
pub const MOB_BLAZE: u8 = 5;
pub const MOB_WITCH: u8 = 6;
pub const MOB_SLIME: u8 = 7;
pub const MOB_GUARDIAN: u8 = 8;
pub const MOB_WITHER_SKELETON: u8 = 9;
pub const MOB_PIGLIN: u8 = 10;
pub const MOB_ENDER_DRAGON: u8 = 11;
pub const MOB_WITHER: u8 = 12;

// ---------------------------------------------------------------------------
// Offset generation
// ---------------------------------------------------------------------------

/// Produces a deterministic pseudo-random offset in [-0.5, 0.5) for scatter.
/// Uses a simple hash of the slot index to give each slot a unique spread.
fn scatterOffset(index: u32, axis: u32) f32 {
    const seed = index *% 2654435761 +% axis *% 340573321;
    const bits: u32 = seed ^ (seed >> 16);
    // Map to [0, 1) then shift to [-0.5, 0.5)
    return @as(f32, @floatFromInt(bits % 1000)) / 1000.0 - 0.5;
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Build an ItemDrop from a non-empty slot with a deterministic scatter offset.
fn makeDrop(slot: Slot, global_index: u32, x: f32, y: f32, z: f32) ItemDrop {
    return .{
        .x = x + scatterOffset(global_index, 0),
        .y = y + scatterOffset(global_index, 1),
        .z = z + scatterOffset(global_index, 2),
        .item = slot.item,
        .count = slot.count,
    };
}

/// Scatter all non-empty inventory and armor slots as item drops around
/// the given position. Returns one optional drop per combined slot (36
/// inventory + 4 armor = 40). Empty slots produce `null`.
pub fn scatterInventory(
    inv: [36]Slot,
    armor: [4]Slot,
    x: f32,
    y: f32,
    z: f32,
) [40]?ItemDrop {
    var drops: [40]?ItemDrop = .{null} ** 40;

    for (inv, 0..) |slot, i| {
        if (!slot.isEmpty()) {
            drops[i] = makeDrop(slot, @intCast(i), x, y, z);
        }
    }

    for (armor, 0..) |slot, i| {
        if (!slot.isEmpty()) {
            drops[i + 36] = makeDrop(slot, @intCast(i + 36), x, y, z);
        }
    }

    return drops;
}

/// Determine whether a player keeps their inventory on death.
/// Creative mode always keeps inventory; the keep-inventory game rule
/// overrides survival/adventure behaviour.
pub fn shouldKeepInventory(is_creative: bool, keep_inv_rule: bool) bool {
    return is_creative or keep_inv_rule;
}

/// Calculate XP dropped when a mob of the given type is killed.
/// Returns 0 for unrecognised mob types.
pub fn calculateMobDropXP(mob_type: u8) u16 {
    return switch (mob_type) {
        MOB_ZOMBIE => 5,
        MOB_SKELETON => 5,
        MOB_CREEPER => 5,
        MOB_SPIDER => 5,
        MOB_ENDERMAN => 5,
        MOB_BLAZE => 10,
        MOB_WITCH => 5,
        MOB_SLIME => 4,
        MOB_GUARDIAN => 10,
        MOB_WITHER_SKELETON => 5,
        MOB_PIGLIN => 5,
        MOB_ENDER_DRAGON => 12000,
        MOB_WITHER => 50,
        else => 0,
    };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "Slot.empty is empty" {
    const slot = Slot.empty;
    try std.testing.expect(slot.isEmpty());
    try std.testing.expectEqual(@as(u16, 0), slot.item);
    try std.testing.expectEqual(@as(u8, 0), slot.count);
}

test "Slot with items is not empty" {
    const slot = Slot{ .item = 42, .count = 3 };
    try std.testing.expect(!slot.isEmpty());
}

test "scatterInventory returns null for all-empty slots" {
    const inv = [_]Slot{Slot.empty} ** 36;
    const armor = [_]Slot{Slot.empty} ** 4;
    const drops = scatterInventory(inv, armor, 0.0, 64.0, 0.0);

    for (drops) |maybe_drop| {
        try std.testing.expect(maybe_drop == null);
    }
}

test "scatterInventory creates drops for non-empty inventory slots" {
    var inv = [_]Slot{Slot.empty} ** 36;
    inv[0] = Slot{ .item = 1, .count = 10 };
    inv[35] = Slot{ .item = 2, .count = 5 };
    const armor = [_]Slot{Slot.empty} ** 4;

    const drops = scatterInventory(inv, armor, 100.0, 64.0, 200.0);

    // Slot 0 should have a drop
    try std.testing.expect(drops[0] != null);
    try std.testing.expectEqual(@as(u16, 1), drops[0].?.item);
    try std.testing.expectEqual(@as(u8, 10), drops[0].?.count);

    // Slot 35 should have a drop
    try std.testing.expect(drops[35] != null);
    try std.testing.expectEqual(@as(u16, 2), drops[35].?.item);
    try std.testing.expectEqual(@as(u8, 5), drops[35].?.count);

    // All other inventory slots should be null
    for (1..35) |i| {
        try std.testing.expect(drops[i] == null);
    }
}

test "scatterInventory creates drops for non-empty armor slots" {
    const inv = [_]Slot{Slot.empty} ** 36;
    var armor = [_]Slot{Slot.empty} ** 4;
    armor[0] = Slot{ .item = 100, .count = 1 };
    armor[3] = Slot{ .item = 103, .count = 1 };

    const drops = scatterInventory(inv, armor, 0.0, 64.0, 0.0);

    // Armor slots map to indices 36..39
    try std.testing.expect(drops[36] != null);
    try std.testing.expectEqual(@as(u16, 100), drops[36].?.item);
    try std.testing.expect(drops[37] == null);
    try std.testing.expect(drops[38] == null);
    try std.testing.expect(drops[39] != null);
    try std.testing.expectEqual(@as(u16, 103), drops[39].?.item);
}

test "scatterInventory offsets are near the death position" {
    var inv = [_]Slot{Slot.empty} ** 36;
    inv[0] = Slot{ .item = 7, .count = 1 };
    const armor = [_]Slot{Slot.empty} ** 4;

    const drops = scatterInventory(inv, armor, 50.0, 64.0, 50.0);
    const drop = drops[0].?;

    // Offsets are in [-0.5, 0.5), so drops should be within 1 block
    try std.testing.expect(@abs(drop.x - 50.0) < 1.0);
    try std.testing.expect(@abs(drop.y - 64.0) < 1.0);
    try std.testing.expect(@abs(drop.z - 50.0) < 1.0);
}

test "scatterInventory different slots get different offsets" {
    var inv = [_]Slot{Slot.empty} ** 36;
    inv[0] = Slot{ .item = 1, .count = 1 };
    inv[1] = Slot{ .item = 2, .count = 1 };
    const armor = [_]Slot{Slot.empty} ** 4;

    const drops = scatterInventory(inv, armor, 0.0, 0.0, 0.0);
    const d0 = drops[0].?;
    const d1 = drops[1].?;

    // At least one axis should differ between two adjacent slots
    const same = (d0.x == d1.x) and (d0.y == d1.y) and (d0.z == d1.z);
    try std.testing.expect(!same);
}

test "shouldKeepInventory returns true in creative mode" {
    try std.testing.expect(shouldKeepInventory(true, false));
}

test "shouldKeepInventory returns true with keep-inventory rule" {
    try std.testing.expect(shouldKeepInventory(false, true));
}

test "shouldKeepInventory returns false in survival without rule" {
    try std.testing.expect(!shouldKeepInventory(false, false));
}

test "shouldKeepInventory returns true when both flags set" {
    try std.testing.expect(shouldKeepInventory(true, true));
}

test "calculateMobDropXP returns expected values for known mobs" {
    try std.testing.expectEqual(@as(u16, 5), calculateMobDropXP(MOB_ZOMBIE));
    try std.testing.expectEqual(@as(u16, 5), calculateMobDropXP(MOB_SKELETON));
    try std.testing.expectEqual(@as(u16, 5), calculateMobDropXP(MOB_CREEPER));
    try std.testing.expectEqual(@as(u16, 10), calculateMobDropXP(MOB_BLAZE));
    try std.testing.expectEqual(@as(u16, 10), calculateMobDropXP(MOB_GUARDIAN));
    try std.testing.expectEqual(@as(u16, 4), calculateMobDropXP(MOB_SLIME));
    try std.testing.expectEqual(@as(u16, 12000), calculateMobDropXP(MOB_ENDER_DRAGON));
    try std.testing.expectEqual(@as(u16, 50), calculateMobDropXP(MOB_WITHER));
}

test "calculateMobDropXP returns 0 for unknown mob type" {
    try std.testing.expectEqual(@as(u16, 0), calculateMobDropXP(255));
    try std.testing.expectEqual(@as(u16, 0), calculateMobDropXP(200));
}

test "scatterInventory full inventory produces 40 drops" {
    const inv = [_]Slot{Slot{ .item = 1, .count = 1 }} ** 36;
    const armor = [_]Slot{Slot{ .item = 2, .count = 1 }} ** 4;

    const drops = scatterInventory(inv, armor, 0.0, 64.0, 0.0);

    var count: usize = 0;
    for (drops) |maybe_drop| {
        if (maybe_drop != null) count += 1;
    }
    try std.testing.expectEqual(@as(usize, 40), count);
}
