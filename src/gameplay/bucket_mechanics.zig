const std = @import("std");

// ---------------------------------------------------------------------------
// Item IDs
// ---------------------------------------------------------------------------

pub const EMPTY_BUCKET: u16 = 303;
pub const WATER_BUCKET: u16 = 700;
pub const LAVA_BUCKET: u16 = 701;
pub const MILK_BUCKET: u16 = 702;

// ---------------------------------------------------------------------------
// Block IDs (mirrors src/world/block.zig)
// ---------------------------------------------------------------------------

const WATER_BLOCK: u16 = 10;
const LAVA_BLOCK: u16 = 32;
const AIR_BLOCK: u16 = 0;

// ---------------------------------------------------------------------------
// Bucket action
// ---------------------------------------------------------------------------

pub const BucketAction = enum {
    none,
    pick_up_water,
    pick_up_lava,
    place_water,
    place_lava,
    milk_cow,
    drink_milk,
};

/// Determine what action a bucket interaction produces given the held item,
/// the block being targeted, and whether the target entity is a cow.
pub fn getBucketAction(held_item: u16, target_block: u16, target_is_cow: bool) BucketAction {
    if (held_item == MILK_BUCKET) return .drink_milk;

    if (held_item == EMPTY_BUCKET) {
        if (target_is_cow) return .milk_cow;
        if (target_block == WATER_BLOCK) return .pick_up_water;
        if (target_block == LAVA_BLOCK) return .pick_up_lava;
        return .none;
    }

    if (held_item == WATER_BUCKET) return .place_water;
    if (held_item == LAVA_BUCKET) return .place_lava;

    return .none;
}

/// Return the item the player ends up holding after performing the action.
pub fn getResultItem(action: BucketAction) u16 {
    return switch (action) {
        .pick_up_water => WATER_BUCKET,
        .pick_up_lava => LAVA_BUCKET,
        .milk_cow => MILK_BUCKET,
        .place_water, .place_lava => EMPTY_BUCKET,
        .drink_milk => EMPTY_BUCKET,
        .none => EMPTY_BUCKET,
    };
}

/// Return the block that should be placed in the world, or null when no block
/// placement is involved.
pub fn getPlacedBlock(action: BucketAction) ?u16 {
    return switch (action) {
        .place_water => WATER_BLOCK,
        .place_lava => LAVA_BLOCK,
        else => null,
    };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "empty bucket on water picks up water" {
    const action = getBucketAction(EMPTY_BUCKET, WATER_BLOCK, false);
    try std.testing.expectEqual(BucketAction.pick_up_water, action);
    try std.testing.expectEqual(WATER_BUCKET, getResultItem(action));
    try std.testing.expectEqual(@as(?u16, null), getPlacedBlock(action));
}

test "empty bucket on lava picks up lava" {
    const action = getBucketAction(EMPTY_BUCKET, LAVA_BLOCK, false);
    try std.testing.expectEqual(BucketAction.pick_up_lava, action);
    try std.testing.expectEqual(LAVA_BUCKET, getResultItem(action));
    try std.testing.expectEqual(@as(?u16, null), getPlacedBlock(action));
}

test "empty bucket on cow milks cow" {
    const action = getBucketAction(EMPTY_BUCKET, AIR_BLOCK, true);
    try std.testing.expectEqual(BucketAction.milk_cow, action);
    try std.testing.expectEqual(MILK_BUCKET, getResultItem(action));
    try std.testing.expectEqual(@as(?u16, null), getPlacedBlock(action));
}

test "water bucket places water" {
    const action = getBucketAction(WATER_BUCKET, AIR_BLOCK, false);
    try std.testing.expectEqual(BucketAction.place_water, action);
    try std.testing.expectEqual(EMPTY_BUCKET, getResultItem(action));
    try std.testing.expectEqual(@as(?u16, WATER_BLOCK), getPlacedBlock(action));
}

test "lava bucket places lava" {
    const action = getBucketAction(LAVA_BUCKET, AIR_BLOCK, false);
    try std.testing.expectEqual(BucketAction.place_lava, action);
    try std.testing.expectEqual(EMPTY_BUCKET, getResultItem(action));
    try std.testing.expectEqual(@as(?u16, LAVA_BLOCK), getPlacedBlock(action));
}

test "milk bucket triggers drink action" {
    const action = getBucketAction(MILK_BUCKET, AIR_BLOCK, false);
    try std.testing.expectEqual(BucketAction.drink_milk, action);
    try std.testing.expectEqual(EMPTY_BUCKET, getResultItem(action));
    try std.testing.expectEqual(@as(?u16, null), getPlacedBlock(action));
}

test "empty bucket on air does nothing" {
    const action = getBucketAction(EMPTY_BUCKET, AIR_BLOCK, false);
    try std.testing.expectEqual(BucketAction.none, action);
}

test "unknown item returns none" {
    const action = getBucketAction(999, AIR_BLOCK, false);
    try std.testing.expectEqual(BucketAction.none, action);
}

test "cow priority over water block for empty bucket" {
    // When targeting a cow standing in water, milking takes priority
    const action = getBucketAction(EMPTY_BUCKET, WATER_BLOCK, true);
    try std.testing.expectEqual(BucketAction.milk_cow, action);
}

test "milk bucket ignores cow and water targets" {
    // Drinking milk always happens regardless of what is targeted
    const action_cow = getBucketAction(MILK_BUCKET, AIR_BLOCK, true);
    try std.testing.expectEqual(BucketAction.drink_milk, action_cow);

    const action_water = getBucketAction(MILK_BUCKET, WATER_BLOCK, false);
    try std.testing.expectEqual(BucketAction.drink_milk, action_water);
}

test "getResultItem for none action returns empty bucket" {
    try std.testing.expectEqual(EMPTY_BUCKET, getResultItem(.none));
}

test "getPlacedBlock returns null for non-placement actions" {
    try std.testing.expectEqual(@as(?u16, null), getPlacedBlock(.pick_up_water));
    try std.testing.expectEqual(@as(?u16, null), getPlacedBlock(.pick_up_lava));
    try std.testing.expectEqual(@as(?u16, null), getPlacedBlock(.milk_cow));
    try std.testing.expectEqual(@as(?u16, null), getPlacedBlock(.drink_milk));
    try std.testing.expectEqual(@as(?u16, null), getPlacedBlock(.none));
}

test "water bucket places water even targeting lava" {
    const action = getBucketAction(WATER_BUCKET, LAVA_BLOCK, false);
    try std.testing.expectEqual(BucketAction.place_water, action);
    try std.testing.expectEqual(@as(?u16, WATER_BLOCK), getPlacedBlock(action));
}
