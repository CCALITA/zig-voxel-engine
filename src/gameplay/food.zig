/// Food item system.
/// Maps item IDs to hunger/saturation restore values.
/// Non-block item IDs start at 256 to avoid collision with BlockId (u8).

const std = @import("std");

pub const ItemId = u16;

pub const FoodDef = struct {
    hunger_restore: f32,
    saturation_restore: f32,
    eat_duration: f32 = 1.6, // seconds to consume (vanilla default)
};

// Non-block food item IDs (starting at 256 to avoid block ID overlap)
pub const APPLE: ItemId = 256;
pub const BREAD: ItemId = 257;
pub const COOKED_PORKCHOP: ItemId = 258;
pub const RAW_PORKCHOP: ItemId = 259;
pub const COOKED_BEEF: ItemId = 260;
pub const RAW_BEEF: ItemId = 261;
pub const COOKED_CHICKEN: ItemId = 262;
pub const RAW_CHICKEN: ItemId = 263;
pub const GOLDEN_APPLE: ItemId = 264;
pub const COOKED_FISH: ItemId = 265;
pub const RAW_FISH: ItemId = 266;
pub const MELON_SLICE: ItemId = 267;
pub const COOKIE: ItemId = 268;
pub const CARROT: ItemId = 269;
pub const POTATO: ItemId = 270;
pub const BAKED_POTATO: ItemId = 271;

/// Returns the food definition for a food item, or null if the item is not food.
pub fn getFood(item_id: ItemId) ?FoodDef {
    return switch (item_id) {
        APPLE => .{ .hunger_restore = 4.0, .saturation_restore = 2.4 },
        BREAD => .{ .hunger_restore = 5.0, .saturation_restore = 6.0 },
        COOKED_PORKCHOP => .{ .hunger_restore = 8.0, .saturation_restore = 12.8 },
        RAW_PORKCHOP => .{ .hunger_restore = 3.0, .saturation_restore = 1.8 },
        COOKED_BEEF => .{ .hunger_restore = 8.0, .saturation_restore = 12.8 },
        RAW_BEEF => .{ .hunger_restore = 3.0, .saturation_restore = 1.8 },
        COOKED_CHICKEN => .{ .hunger_restore = 6.0, .saturation_restore = 7.2 },
        RAW_CHICKEN => .{ .hunger_restore = 2.0, .saturation_restore = 1.2 },
        GOLDEN_APPLE => .{ .hunger_restore = 4.0, .saturation_restore = 9.6 },
        COOKED_FISH => .{ .hunger_restore = 5.0, .saturation_restore = 6.0 },
        RAW_FISH => .{ .hunger_restore = 2.0, .saturation_restore = 0.4 },
        MELON_SLICE => .{ .hunger_restore = 2.0, .saturation_restore = 1.2 },
        COOKIE => .{ .hunger_restore = 2.0, .saturation_restore = 0.4 },
        CARROT => .{ .hunger_restore = 3.0, .saturation_restore = 3.6 },
        POTATO => .{ .hunger_restore = 1.0, .saturation_restore = 0.6 },
        BAKED_POTATO => .{ .hunger_restore = 5.0, .saturation_restore = 6.0 },
        else => null,
    };
}

/// Returns true if the item can be eaten.
pub fn isFood(item_id: ItemId) bool {
    return getFood(item_id) != null;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "isFood returns true for food items" {
    try std.testing.expect(isFood(APPLE));
    try std.testing.expect(isFood(BREAD));
    try std.testing.expect(isFood(COOKED_BEEF));
    try std.testing.expect(isFood(GOLDEN_APPLE));
}

test "isFood returns false for non-food items" {
    try std.testing.expect(!isFood(0)); // air
    try std.testing.expect(!isFood(1)); // stone
    try std.testing.expect(!isFood(999)); // unknown
}

test "getFood returns correct values for apple" {
    const apple = getFood(APPLE).?;
    try std.testing.expectEqual(@as(f32, 4.0), apple.hunger_restore);
    try std.testing.expectEqual(@as(f32, 2.4), apple.saturation_restore);
    try std.testing.expectEqual(@as(f32, 1.6), apple.eat_duration);
}

test "getFood returns correct values for cooked beef" {
    const beef = getFood(COOKED_BEEF).?;
    try std.testing.expectEqual(@as(f32, 8.0), beef.hunger_restore);
    try std.testing.expectEqual(@as(f32, 12.8), beef.saturation_restore);
}

test "getFood returns null for non-food" {
    try std.testing.expectEqual(@as(?FoodDef, null), getFood(0));
    try std.testing.expectEqual(@as(?FoodDef, null), getFood(1));
}

test "golden apple has high saturation" {
    const golden = getFood(GOLDEN_APPLE).?;
    try std.testing.expectEqual(@as(f32, 9.6), golden.saturation_restore);
}

test "all food items have positive hunger restore" {
    const food_ids = [_]ItemId{
        APPLE,         BREAD,      COOKED_PORKCHOP, RAW_PORKCHOP,
        COOKED_BEEF,   RAW_BEEF,   COOKED_CHICKEN,  RAW_CHICKEN,
        GOLDEN_APPLE,  COOKED_FISH, RAW_FISH,       MELON_SLICE,
        COOKIE,        CARROT,     POTATO,           BAKED_POTATO,
    };
    for (food_ids) |id| {
        const def = getFood(id).?;
        try std.testing.expect(def.hunger_restore > 0);
        try std.testing.expect(def.saturation_restore >= 0);
        try std.testing.expect(def.eat_duration > 0);
    }
}
