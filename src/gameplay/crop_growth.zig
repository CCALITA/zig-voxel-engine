//! Crop growth mechanics: random-tick growth, bone meal, and harvest drops.
//!
//! Models Minecraft-style growth where each crop has 8 stages (0..7) and
//! advances probabilistically per random tick. Hydration doubles the chance
//! and crowded plantings (>2 same-type neighbors) halve it.

const std = @import("std");

pub const CropType = enum(u8) { wheat, carrot, potato, beetroot };
pub const MAX_STAGE: u8 = 7;

pub const CropState = struct {
    crop_type: CropType,
    stage: u8 = 0,
    x: i32,
    y: i32,
    z: i32,
};

/// Per-tick probability (0..1) of advancing one growth stage.
/// Returns 0 when light < 9.
pub fn getGrowthChance(hydrated: bool, light: u4, adjacent_same: u8) f32 {
    if (light < 9) return 0;
    var chance: f32 = 0.05;
    if (hydrated) chance *= 2.0;
    if (adjacent_same > 2) chance *= 0.5;
    return chance;
}

/// Try to advance the crop one stage. `rng` is an externally-supplied
/// pseudo-random word; the caller controls the seed.
pub fn tryGrow(crop: *CropState, hydrated: bool, light: u4, adjacent: u8, rng: u32) bool {
    if (crop.stage >= MAX_STAGE) return false;
    const chance = getGrowthChance(hydrated, light, adjacent);
    const roll = @as(f32, @floatFromInt(rng % 1000)) / 1000.0;
    if (roll < chance) {
        crop.stage += 1;
        return true;
    }
    return false;
}

/// Apply bone meal: instantly advance 1-3 stages (capped at MAX_STAGE).
/// Returns the number of stages actually added.
pub fn applyBoneMeal(crop: *CropState, rng: u32) u8 {
    if (crop.stage >= MAX_STAGE) return 0;
    const boost: u8 = @intCast(1 + rng % 3);
    const added = @min(boost, MAX_STAGE - crop.stage);
    crop.stage += added;
    return added;
}

pub const CropDrops = struct { item: u16, count: u8, seeds: u8 };

/// Drop table for a crop. Immature crops (stage < MAX) yield only one seed.
pub fn getDrops(crop: CropState) CropDrops {
    if (crop.stage < MAX_STAGE) return .{ .item = 0, .count = 0, .seeds = 1 };
    return switch (crop.crop_type) {
        .wheat => .{ .item = 352, .count = 1, .seeds = 1 + crop.stage % 3 },
        .carrot => .{ .item = 358, .count = 1 + crop.stage % 4, .seeds = 0 },
        .potato => .{ .item = 564, .count = 1 + crop.stage % 4, .seeds = 0 },
        .beetroot => .{ .item = 362, .count = 1, .seeds = 1 + crop.stage % 3 },
    };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

const testing = std.testing;

test "getGrowthChance returns 0 in low light" {
    try testing.expectEqual(@as(f32, 0), getGrowthChance(true, 8, 0));
    try testing.expectEqual(@as(f32, 0), getGrowthChance(false, 0, 0));
}

test "getGrowthChance baseline at sufficient light" {
    try testing.expectEqual(@as(f32, 0.05), getGrowthChance(false, 9, 0));
    try testing.expectEqual(@as(f32, 0.05), getGrowthChance(false, 15, 1));
}

test "getGrowthChance doubles when hydrated" {
    try testing.expectEqual(@as(f32, 0.10), getGrowthChance(true, 9, 0));
}

test "getGrowthChance halved when crowded" {
    try testing.expectEqual(@as(f32, 0.025), getGrowthChance(false, 9, 3));
    // hydrated + crowded: 0.05 * 2 * 0.5 = 0.05
    try testing.expectEqual(@as(f32, 0.05), getGrowthChance(true, 9, 5));
}

test "tryGrow advances stage when roll succeeds" {
    var crop = CropState{ .crop_type = .wheat, .x = 0, .y = 0, .z = 0 };
    // chance = 0.05, rng % 1000 = 10 -> 0.01 < 0.05 succeeds
    try testing.expect(tryGrow(&crop, false, 15, 0, 10));
    try testing.expectEqual(@as(u8, 1), crop.stage);
}

test "tryGrow fails when roll exceeds chance" {
    var crop = CropState{ .crop_type = .carrot, .x = 0, .y = 0, .z = 0 };
    // chance = 0.05, rng % 1000 = 500 -> 0.5 not < 0.05
    try testing.expect(!tryGrow(&crop, false, 15, 0, 500));
    try testing.expectEqual(@as(u8, 0), crop.stage);
}

test "tryGrow fails in low light regardless of rng" {
    var crop = CropState{ .crop_type = .potato, .x = 0, .y = 0, .z = 0 };
    try testing.expect(!tryGrow(&crop, true, 5, 0, 0));
    try testing.expectEqual(@as(u8, 0), crop.stage);
}

test "tryGrow returns false at MAX_STAGE" {
    var crop = CropState{ .crop_type = .wheat, .stage = MAX_STAGE, .x = 0, .y = 0, .z = 0 };
    try testing.expect(!tryGrow(&crop, true, 15, 0, 0));
    try testing.expectEqual(MAX_STAGE, crop.stage);
}

test "applyBoneMeal advances 1-3 stages" {
    var crop = CropState{ .crop_type = .beetroot, .x = 0, .y = 0, .z = 0 };
    const added = applyBoneMeal(&crop, 7);
    try testing.expect(added >= 1 and added <= 3);
    try testing.expectEqual(added, crop.stage);
}

test "applyBoneMeal caps at MAX_STAGE" {
    var crop = CropState{ .crop_type = .wheat, .stage = 6, .x = 0, .y = 0, .z = 0 };
    const added = applyBoneMeal(&crop, 5); // boost = 1 + 5%3 = 3, but cap = 1
    try testing.expectEqual(@as(u8, 1), added);
    try testing.expectEqual(MAX_STAGE, crop.stage);
}

test "applyBoneMeal does nothing when fully grown" {
    var crop = CropState{ .crop_type = .carrot, .stage = MAX_STAGE, .x = 0, .y = 0, .z = 0 };
    try testing.expectEqual(@as(u8, 0), applyBoneMeal(&crop, 12345));
    try testing.expectEqual(MAX_STAGE, crop.stage);
}

test "applyBoneMeal boost is deterministic from rng" {
    // rng % 3: 0 -> boost 1, 1 -> 2, 2 -> 3
    const cases = [_]struct { rng: u32, expect: u8 }{
        .{ .rng = 3, .expect = 1 },
        .{ .rng = 4, .expect = 2 },
        .{ .rng = 5, .expect = 3 },
    };
    for (cases) |c| {
        var crop = CropState{ .crop_type = .potato, .x = 0, .y = 0, .z = 0 };
        try testing.expectEqual(c.expect, applyBoneMeal(&crop, c.rng));
    }
}

test "getDrops for immature crop yields a seed only" {
    const crop = CropState{ .crop_type = .wheat, .stage = 3, .x = 0, .y = 0, .z = 0 };
    const drops = getDrops(crop);
    try testing.expectEqual(@as(u16, 0), drops.item);
    try testing.expectEqual(@as(u8, 0), drops.count);
    try testing.expectEqual(@as(u8, 1), drops.seeds);
}

test "getDrops wheat at maturity yields wheat + seeds" {
    const crop = CropState{ .crop_type = .wheat, .stage = MAX_STAGE, .x = 0, .y = 0, .z = 0 };
    const drops = getDrops(crop);
    try testing.expectEqual(@as(u16, 352), drops.item);
    try testing.expectEqual(@as(u8, 1), drops.count);
    // 1 + 7 % 3 = 1 + 1 = 2
    try testing.expectEqual(@as(u8, 2), drops.seeds);
}

test "getDrops carrot at maturity yields carrots, no seeds" {
    const crop = CropState{ .crop_type = .carrot, .stage = MAX_STAGE, .x = 0, .y = 0, .z = 0 };
    const drops = getDrops(crop);
    try testing.expectEqual(@as(u16, 358), drops.item);
    // 1 + 7 % 4 = 1 + 3 = 4
    try testing.expectEqual(@as(u8, 4), drops.count);
    try testing.expectEqual(@as(u8, 0), drops.seeds);
}

test "getDrops potato at maturity yields potatoes, no seeds" {
    const crop = CropState{ .crop_type = .potato, .stage = MAX_STAGE, .x = 0, .y = 0, .z = 0 };
    const drops = getDrops(crop);
    try testing.expectEqual(@as(u16, 564), drops.item);
    try testing.expectEqual(@as(u8, 4), drops.count);
    try testing.expectEqual(@as(u8, 0), drops.seeds);
}

test "getDrops beetroot at maturity yields beetroot + seeds" {
    const crop = CropState{ .crop_type = .beetroot, .stage = MAX_STAGE, .x = 0, .y = 0, .z = 0 };
    const drops = getDrops(crop);
    try testing.expectEqual(@as(u16, 362), drops.item);
    try testing.expectEqual(@as(u8, 1), drops.count);
    try testing.expectEqual(@as(u8, 2), drops.seeds);
}

test "MAX_STAGE constant" {
    try testing.expectEqual(@as(u8, 7), MAX_STAGE);
}

test "CropState defaults stage to 0" {
    const crop = CropState{ .crop_type = .wheat, .x = 1, .y = 2, .z = 3 };
    try testing.expectEqual(@as(u8, 0), crop.stage);
}
