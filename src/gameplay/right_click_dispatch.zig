/// Right-click dispatch — determines which action to take when the player
/// right-clicks, based on the held item, target block, target entity, and
/// sneak state.  Priority order:
///   1. Sneaking + holding a block → place_block
///   2. Entity interaction (target_entity != null)
///   3. Station interaction (via station_router)
///   4. Held-item use (bucket / pearl / bone meal / flint & steel / shears /
///      fishing rod / food)
///   5. Interactable blocks (door, bed)
///   6. Fallback → place_block if holding a placeable item, else none

const std = @import("std");
const station_router = @import("station_router.zig");

// ── Right-click action enum ──────────────────────────────────────────────

pub const RightClickAction = enum {
    none,
    eat_food,
    use_bucket,
    throw_ender_pearl,
    place_block,
    interact_station,
    use_bone_meal,
    use_flint_steel,
    use_shears,
    open_door,
    sleep_in_bed,
    use_fishing_rod,
};

// ── Item IDs ─────────────────────────────────────────────────────────────

const ItemId = struct {
    // Buckets
    const EMPTY_BUCKET: u16 = 303;
    const WATER_BUCKET: u16 = 700;
    const LAVA_BUCKET: u16 = 701;
    const MILK_BUCKET: u16 = 702;

    // Tools / usables
    const SHEARS: u16 = 307;
    const FLINT_STEEL: u16 = 308;
    const FISHING_ROD: u16 = 309;
    const ENDER_PEARL: u16 = 319;
    const BONE_MEAL: u16 = 710;

    // Food items (non-block, starting at 256)
    const APPLE: u16 = 256;
    const BREAD: u16 = 257;
    const COOKED_PORKCHOP: u16 = 258;
    const RAW_PORKCHOP: u16 = 259;
    const COOKED_BEEF: u16 = 260;
    const RAW_BEEF: u16 = 261;
    const COOKED_CHICKEN: u16 = 262;
    const RAW_CHICKEN: u16 = 263;
    const GOLDEN_APPLE: u16 = 264;
    const COOKED_FISH: u16 = 265;
    const RAW_FISH: u16 = 266;
    const MELON_SLICE: u16 = 267;
    const COOKIE: u16 = 268;
    const CARROT: u16 = 269;
    const POTATO: u16 = 270;
    const BAKED_POTATO: u16 = 271;
};

// ── Block IDs ────────────────────────────────────────────────────────────

const BlockId = struct {
    const AIR: u16 = 0;
    const DOOR: u16 = 40;
    const BED: u16 = 41;
};

// ── Public API ───────────────────────────────────────────────────────────

/// Determine the right-click action given the current context.
///
/// Priority:
///   1. Sneaking while holding a placeable item → place_block
///   2. Entity present → entity-based interaction (shears, bucket, etc.)
///   3. Target block is a station → interact_station
///   4. Held-item use (bucket, pearl, bone meal, flint & steel, shears,
///      fishing rod, food)
///   5. Interactable block (door, bed)
///   6. Holding a placeable item → place_block
///   7. Otherwise → none
pub fn dispatch(
    held_item: u16,
    target_block: u16,
    target_entity: ?u8,
    is_sneaking: bool,
) RightClickAction {
    // 1. Sneaking with a block in hand → always place_block
    if (is_sneaking and isPlaceableItem(held_item)) {
        return .place_block;
    }

    // 2. Entity interaction takes priority when an entity is targeted
    if (target_entity != null) {
        if (held_item == ItemId.SHEARS) return .use_shears;
        if (isBucketItem(held_item)) return .use_bucket;
        // Generic entity interaction falls through to held-item use
    }

    // 3. Station interaction (crafting table, furnace, etc.)
    if (station_router.routeBlockInteraction(target_block) != null) {
        return .interact_station;
    }

    // 4. Held-item use
    if (isBucketItem(held_item)) return .use_bucket;
    if (held_item == ItemId.ENDER_PEARL) return .throw_ender_pearl;
    if (held_item == ItemId.BONE_MEAL) return .use_bone_meal;
    if (held_item == ItemId.FLINT_STEEL) return .use_flint_steel;
    if (held_item == ItemId.SHEARS) return .use_shears;
    if (held_item == ItemId.FISHING_ROD) return .use_fishing_rod;
    if (isFoodItem(held_item)) return .eat_food;

    // 5. Interactable blocks
    if (target_block == BlockId.DOOR) return .open_door;
    if (target_block == BlockId.BED) return .sleep_in_bed;

    // 6. Fallback: place_block if holding something placeable
    if (isPlaceableItem(held_item)) return .place_block;

    // 7. Nothing useful to do
    return .none;
}

/// Returns true if the item is a food item that can be eaten.
pub fn isFoodItem(item: u16) bool {
    return switch (item) {
        ItemId.APPLE,
        ItemId.BREAD,
        ItemId.COOKED_PORKCHOP,
        ItemId.RAW_PORKCHOP,
        ItemId.COOKED_BEEF,
        ItemId.RAW_BEEF,
        ItemId.COOKED_CHICKEN,
        ItemId.RAW_CHICKEN,
        ItemId.GOLDEN_APPLE,
        ItemId.COOKED_FISH,
        ItemId.RAW_FISH,
        ItemId.MELON_SLICE,
        ItemId.COOKIE,
        ItemId.CARROT,
        ItemId.POTATO,
        ItemId.BAKED_POTATO,
        => true,
        else => false,
    };
}

/// Returns true if the item can be actively used on right-click
/// (bucket, ender pearl, bone meal, flint & steel, shears, fishing rod,
/// or food).
pub fn isUsableItem(item: u16) bool {
    if (isFoodItem(item)) return true;
    return switch (item) {
        ItemId.EMPTY_BUCKET,
        ItemId.WATER_BUCKET,
        ItemId.LAVA_BUCKET,
        ItemId.MILK_BUCKET,
        ItemId.SHEARS,
        ItemId.FLINT_STEEL,
        ItemId.FISHING_ROD,
        ItemId.ENDER_PEARL,
        ItemId.BONE_MEAL,
        => true,
        else => false,
    };
}

// ── Helpers ──────────────────────────────────────────────────────────────

fn isBucketItem(item: u16) bool {
    return switch (item) {
        ItemId.EMPTY_BUCKET,
        ItemId.WATER_BUCKET,
        ItemId.LAVA_BUCKET,
        ItemId.MILK_BUCKET,
        => true,
        else => false,
    };
}

/// A very rough heuristic: any non-zero item that is not a "usable" tool /
/// consumable is considered placeable.  In a real implementation this would
/// consult a full item registry; here we keep it simple and self-contained.
fn isPlaceableItem(item: u16) bool {
    if (item == 0) return false;
    if (isUsableItem(item)) return false;
    return true;
}

// ── Tests ────────────────────────────────────────────────────────────────

test "sneaking with block places block" {
    const action = dispatch(1, BlockId.AIR, null, true);
    try std.testing.expectEqual(RightClickAction.place_block, action);
}

test "sneaking with block overrides station" {
    // Crafting table block ID = 110 (from station_router)
    const action = dispatch(1, 110, null, true);
    try std.testing.expectEqual(RightClickAction.place_block, action);
}

test "entity interaction with shears" {
    const action = dispatch(ItemId.SHEARS, BlockId.AIR, 91, false);
    try std.testing.expectEqual(RightClickAction.use_shears, action);
}

test "entity interaction with bucket" {
    const action = dispatch(ItemId.EMPTY_BUCKET, BlockId.AIR, 91, false);
    try std.testing.expectEqual(RightClickAction.use_bucket, action);
}

test "station interaction on crafting table" {
    const action = dispatch(0, 110, null, false);
    try std.testing.expectEqual(RightClickAction.interact_station, action);
}

test "station interaction on furnace" {
    const action = dispatch(0, 39, null, false);
    try std.testing.expectEqual(RightClickAction.interact_station, action);
}

test "held bucket use on air" {
    const action = dispatch(ItemId.WATER_BUCKET, BlockId.AIR, null, false);
    try std.testing.expectEqual(RightClickAction.use_bucket, action);
}

test "throw ender pearl" {
    const action = dispatch(ItemId.ENDER_PEARL, BlockId.AIR, null, false);
    try std.testing.expectEqual(RightClickAction.throw_ender_pearl, action);
}

test "use bone meal" {
    const action = dispatch(ItemId.BONE_MEAL, 65, null, false);
    try std.testing.expectEqual(RightClickAction.use_bone_meal, action);
}

test "use flint and steel" {
    const action = dispatch(ItemId.FLINT_STEEL, 1, null, false);
    try std.testing.expectEqual(RightClickAction.use_flint_steel, action);
}

test "use shears on block" {
    const action = dispatch(ItemId.SHEARS, BlockId.AIR, null, false);
    try std.testing.expectEqual(RightClickAction.use_shears, action);
}

test "use fishing rod" {
    const action = dispatch(ItemId.FISHING_ROD, BlockId.AIR, null, false);
    try std.testing.expectEqual(RightClickAction.use_fishing_rod, action);
}

test "eat food with apple" {
    const action = dispatch(ItemId.APPLE, BlockId.AIR, null, false);
    try std.testing.expectEqual(RightClickAction.eat_food, action);
}

test "open door" {
    const action = dispatch(0, BlockId.DOOR, null, false);
    try std.testing.expectEqual(RightClickAction.open_door, action);
}

test "sleep in bed" {
    const action = dispatch(0, BlockId.BED, null, false);
    try std.testing.expectEqual(RightClickAction.sleep_in_bed, action);
}

test "place block fallback with stone" {
    const action = dispatch(1, BlockId.AIR, null, false);
    try std.testing.expectEqual(RightClickAction.place_block, action);
}

test "empty hand on air returns none" {
    const action = dispatch(0, BlockId.AIR, null, false);
    try std.testing.expectEqual(RightClickAction.none, action);
}

test "isFoodItem returns true for all food items" {
    const food_ids = [_]u16{
        ItemId.APPLE,         ItemId.BREAD,          ItemId.COOKED_PORKCHOP,
        ItemId.RAW_PORKCHOP,  ItemId.COOKED_BEEF,    ItemId.RAW_BEEF,
        ItemId.COOKED_CHICKEN, ItemId.RAW_CHICKEN,   ItemId.GOLDEN_APPLE,
        ItemId.COOKED_FISH,   ItemId.RAW_FISH,       ItemId.MELON_SLICE,
        ItemId.COOKIE,        ItemId.CARROT,          ItemId.POTATO,
        ItemId.BAKED_POTATO,
    };
    for (food_ids) |id| {
        try std.testing.expect(isFoodItem(id));
    }
}

test "isFoodItem returns false for non-food items" {
    try std.testing.expect(!isFoodItem(0));
    try std.testing.expect(!isFoodItem(1));
    try std.testing.expect(!isFoodItem(ItemId.SHEARS));
    try std.testing.expect(!isFoodItem(ItemId.ENDER_PEARL));
}

test "isUsableItem covers all usable items" {
    try std.testing.expect(isUsableItem(ItemId.EMPTY_BUCKET));
    try std.testing.expect(isUsableItem(ItemId.WATER_BUCKET));
    try std.testing.expect(isUsableItem(ItemId.LAVA_BUCKET));
    try std.testing.expect(isUsableItem(ItemId.MILK_BUCKET));
    try std.testing.expect(isUsableItem(ItemId.SHEARS));
    try std.testing.expect(isUsableItem(ItemId.FLINT_STEEL));
    try std.testing.expect(isUsableItem(ItemId.FISHING_ROD));
    try std.testing.expect(isUsableItem(ItemId.ENDER_PEARL));
    try std.testing.expect(isUsableItem(ItemId.BONE_MEAL));
    try std.testing.expect(isUsableItem(ItemId.APPLE));
}

test "isUsableItem returns false for non-usable items" {
    try std.testing.expect(!isUsableItem(0));
    try std.testing.expect(!isUsableItem(1));
    try std.testing.expect(!isUsableItem(999));
}

test "station takes priority over door block" {
    // door block id 40 is not a station, so door interaction should fire
    const action = dispatch(0, BlockId.DOOR, null, false);
    try std.testing.expectEqual(RightClickAction.open_door, action);
}

test "held item use takes priority over door" {
    const action = dispatch(ItemId.ENDER_PEARL, BlockId.DOOR, null, false);
    try std.testing.expectEqual(RightClickAction.throw_ender_pearl, action);
}

test "sneaking with usable item does not place block" {
    // Usable items are not placeable, so sneaking should not trigger place_block
    const action = dispatch(ItemId.ENDER_PEARL, BlockId.AIR, null, true);
    try std.testing.expectEqual(RightClickAction.throw_ender_pearl, action);
}
