const std = @import("std");

// ──────────────────────────────────────────────────────────────────────────────
// Food item definitions
// ──────────────────────────────────────────────────────────────────────────────

pub const default_eat_time: f32 = 1.6;

pub const FoodItem = struct {
    item_id: u16,
    name: []const u8,
    hunger_restore: f32,
    saturation_restore: f32,
    eat_time: f32 = default_eat_time,
};

pub const FoodResult = struct {
    item_id: u16,
    hunger_restore: f32,
    saturation_restore: f32,
};

// Item ID constants
pub const BREAD_ID: u16 = 297;
pub const APPLE_ID: u16 = 260;
pub const COOKED_PORKCHOP_ID: u16 = 320;
pub const STEAK_ID: u16 = 364;
pub const COOKED_CHICKEN_ID: u16 = 366;
pub const GOLDEN_APPLE_ID: u16 = 322;
pub const CARROT_ID: u16 = 391;
pub const BAKED_POTATO_ID: u16 = 393;
pub const BEETROOT_SOUP_ID: u16 = 436;

const food_table = [_]FoodItem{
    .{ .item_id = BREAD_ID, .name = "Bread", .hunger_restore = 5, .saturation_restore = 6 },
    .{ .item_id = APPLE_ID, .name = "Apple", .hunger_restore = 4, .saturation_restore = 2.4 },
    .{ .item_id = COOKED_PORKCHOP_ID, .name = "Cooked Porkchop", .hunger_restore = 8, .saturation_restore = 12.8 },
    .{ .item_id = STEAK_ID, .name = "Steak", .hunger_restore = 8, .saturation_restore = 12.8 },
    .{ .item_id = COOKED_CHICKEN_ID, .name = "Cooked Chicken", .hunger_restore = 6, .saturation_restore = 7.2 },
    .{ .item_id = GOLDEN_APPLE_ID, .name = "Golden Apple", .hunger_restore = 4, .saturation_restore = 9.6 },
    .{ .item_id = CARROT_ID, .name = "Carrot", .hunger_restore = 3, .saturation_restore = 3.6 },
    .{ .item_id = BAKED_POTATO_ID, .name = "Baked Potato", .hunger_restore = 5, .saturation_restore = 6 },
    .{ .item_id = BEETROOT_SOUP_ID, .name = "Beetroot Soup", .hunger_restore = 6, .saturation_restore = 7.2 },
};

pub fn getFood(item_id: u16) ?FoodItem {
    for (food_table) |food| {
        if (food.item_id == item_id) return food;
    }
    return null;
}

pub fn isFood(item_id: u16) bool {
    return getFood(item_id) != null;
}

// ──────────────────────────────────────────────────────────────────────────────
// Eating state machine
// ──────────────────────────────────────────────────────────────────────────────

pub const EatingState = struct {
    eating: bool = false,
    timer: f32 = 0.0,
    item: u16 = 0,
    eat_time: f32 = 0.0,

    pub fn startEating(self: *EatingState, item_id: u16) void {
        if (getFood(item_id)) |food| {
            self.eating = true;
            self.timer = 0.0;
            self.item = item_id;
            self.eat_time = food.eat_time;
        }
    }

    pub fn update(self: *EatingState, dt: f32) ?FoodResult {
        if (!self.eating) return null;

        self.timer += dt;
        if (self.timer >= self.eat_time) {
            const food = getFood(self.item) orelse {
                self.cancel();
                return null;
            };
            self.cancel();
            return FoodResult{
                .item_id = food.item_id,
                .hunger_restore = food.hunger_restore,
                .saturation_restore = food.saturation_restore,
            };
        }
        return null;
    }

    pub fn cancel(self: *EatingState) void {
        self.eating = false;
        self.timer = 0.0;
        self.item = 0;
        self.eat_time = 0.0;
    }
};

// ──────────────────────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────────────────────

test "getFood returns correct item for known IDs" {
    const bread = getFood(BREAD_ID).?;
    try std.testing.expectEqual(@as(u16, BREAD_ID), bread.item_id);
    try std.testing.expectEqual(@as(f32, 5), bread.hunger_restore);
    try std.testing.expectEqual(@as(f32, 6), bread.saturation_restore);
    try std.testing.expectEqualStrings("Bread", bread.name);

    const steak = getFood(STEAK_ID).?;
    try std.testing.expectEqual(@as(f32, 8), steak.hunger_restore);
    try std.testing.expectEqual(@as(f32, 12.8), steak.saturation_restore);
}

test "getFood returns null for unknown ID" {
    try std.testing.expectEqual(@as(?FoodItem, null), getFood(9999));
}

test "isFood identifies food and non-food items" {
    try std.testing.expect(isFood(BREAD_ID));
    try std.testing.expect(isFood(GOLDEN_APPLE_ID));
    try std.testing.expect(!isFood(1));
    try std.testing.expect(!isFood(0));
}

test "all food items have default eat time" {
    for (food_table) |food| {
        try std.testing.expectEqual(default_eat_time, food.eat_time);
    }
}

test "eating timer progresses and completes" {
    var state = EatingState{};
    state.startEating(BREAD_ID);
    try std.testing.expect(state.eating);

    // Partial update: not done yet
    const partial = state.update(0.5);
    try std.testing.expectEqual(@as(?FoodResult, null), partial);
    try std.testing.expect(state.eating);

    // Complete the eating
    const result = state.update(1.2);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(u16, BREAD_ID), result.?.item_id);
    try std.testing.expectEqual(@as(f32, 5), result.?.hunger_restore);
    try std.testing.expectEqual(@as(f32, 6), result.?.saturation_restore);
    try std.testing.expect(!state.eating);
}

test "eating cancel resets state" {
    var state = EatingState{};
    state.startEating(STEAK_ID);
    try std.testing.expect(state.eating);

    _ = state.update(0.5);
    state.cancel();

    try std.testing.expect(!state.eating);
    try std.testing.expectEqual(@as(f32, 0.0), state.timer);
    try std.testing.expectEqual(@as(u16, 0), state.item);
}

test "startEating with invalid item does nothing" {
    var state = EatingState{};
    state.startEating(9999);
    try std.testing.expect(!state.eating);
}

test "update returns null when not eating" {
    var state = EatingState{};
    try std.testing.expectEqual(@as(?FoodResult, null), state.update(1.0));
}

test "eating completion returns result at exact eat_time" {
    var state = EatingState{};
    state.startEating(APPLE_ID);

    // Advance exactly to eat_time
    const result = state.update(default_eat_time);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(u16, APPLE_ID), result.?.item_id);
    try std.testing.expectEqual(@as(f32, 4), result.?.hunger_restore);
    try std.testing.expectEqual(@as(f32, 2.4), result.?.saturation_restore);
}
