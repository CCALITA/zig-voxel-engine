/// Campfire UI managing 4 independent cooking slots with no fuel requirement.
/// Supports both regular and soul campfire variants.
/// Items placed on a campfire cook over 30 seconds and drop as cooked output.
/// Only depends on `std`.

const std = @import("std");

// ── Slot ──────────────────────────────────────────────────────────────────────

pub const Slot = struct {
    item: u16,
    count: u8,

    pub const empty = Slot{ .item = 0, .count = 0 };

    pub fn isEmpty(self: Slot) bool {
        return self.count == 0;
    }
};

// ── Cook Recipes ──────────────────────────────────────────────────────────────

pub const CookRecipe = struct {
    input: u16,
    output: u16,
};

pub const RECIPES = [_]CookRecipe{
    .{ .input = 550, .output = 551 }, // raw_porkchop -> cooked_porkchop
    .{ .input = 552, .output = 553 }, // raw_beef -> cooked_beef
    .{ .input = 554, .output = 555 }, // raw_chicken -> cooked_chicken
    .{ .input = 556, .output = 557 }, // raw_cod -> cooked_cod
    .{ .input = 558, .output = 559 }, // raw_salmon -> cooked_salmon
    .{ .input = 560, .output = 561 }, // raw_mutton -> cooked_mutton
    .{ .input = 562, .output = 563 }, // raw_rabbit -> cooked_rabbit
    .{ .input = 564, .output = 565 }, // potato -> baked_potato
    .{ .input = 566, .output = 567 }, // kelp -> dried_kelp
};

pub fn getRecipeOutput(item: u16) ?u16 {
    for (RECIPES) |r| {
        if (r.input == item) return r.output;
    }
    return null;
}

pub fn hasRecipe(item: u16) bool {
    return getRecipeOutput(item) != null;
}

// ── Campfire State ────────────────────────────────────────────────────────────

pub const CampfireState = struct {
    slots: [4]Slot = [_]Slot{Slot.empty} ** 4,
    cook_progress: [4]f32 = [_]f32{0} ** 4,
    cook_time: f32 = 30.0,
    is_soul: bool = false,

    pub fn init(soul: bool) CampfireState {
        return .{
            .is_soul = soul,
            .cook_time = 30.0,
        };
    }

    /// Find the first empty slot and place the item if it has a valid recipe.
    /// Returns the slot index used, or null if placement failed.
    pub fn placeItem(self: *CampfireState, item: Slot) ?u8 {
        if (item.isEmpty()) return null;
        if (!hasRecipe(item.item)) return null;

        for (&self.slots, 0..) |*slot, i| {
            if (slot.isEmpty()) {
                slot.* = .{ .item = item.item, .count = 1 };
                self.cook_progress[i] = 0;
                return @intCast(i);
            }
        }
        return null;
    }

    /// Advance cooking for all occupied slots by dt seconds.
    /// Returns an array where each element is the cooked output slot (to drop
    /// on the ground) if that slot finished cooking, or null otherwise.
    pub fn update(self: *CampfireState, dt: f32) [4]?Slot {
        var results = [_]?Slot{null} ** 4;
        if (dt <= 0) return results;

        for (&self.slots, 0..) |*slot, i| {
            if (slot.isEmpty()) continue;

            const output_id = getRecipeOutput(slot.item) orelse continue;

            self.cook_progress[i] += dt;
            if (self.cook_progress[i] >= self.cook_time) {
                results[i] = Slot{ .item = output_id, .count = 1 };
                slot.* = Slot.empty;
                self.cook_progress[i] = 0;
            }
        }
        return results;
    }

    /// Returns the cooking progress for a slot as a fraction in [0, 1].
    pub fn getProgress(self: *const CampfireState, slot: u8) f32 {
        if (slot >= 4) return 0;
        if (self.slots[slot].isEmpty()) return 0;
        if (self.cook_time <= 0) return 0;
        const ratio = self.cook_progress[slot] / self.cook_time;
        return @min(ratio, 1.0);
    }
};

// =============================================================================
// Tests
// =============================================================================

test "init creates empty campfire" {
    const c = CampfireState.init(false);
    for (c.slots) |slot| {
        try std.testing.expect(slot.isEmpty());
    }
    for (c.cook_progress) |p| {
        try std.testing.expectEqual(@as(f32, 0), p);
    }
    try std.testing.expectEqual(@as(f32, 30.0), c.cook_time);
    try std.testing.expect(!c.is_soul);
}

test "init soul campfire sets is_soul flag" {
    const c = CampfireState.init(true);
    try std.testing.expect(c.is_soul);
    try std.testing.expectEqual(@as(f32, 30.0), c.cook_time);
}

test "placeItem into first empty slot" {
    var c = CampfireState.init(false);
    const idx = c.placeItem(.{ .item = 550, .count = 1 });
    try std.testing.expectEqual(@as(?u8, 0), idx);
    try std.testing.expectEqual(@as(u16, 550), c.slots[0].item);
    try std.testing.expectEqual(@as(u8, 1), c.slots[0].count);
}

test "placeItem skips occupied slots" {
    var c = CampfireState.init(false);
    _ = c.placeItem(.{ .item = 550, .count = 1 });
    _ = c.placeItem(.{ .item = 552, .count = 1 });
    const idx = c.placeItem(.{ .item = 554, .count = 1 });
    try std.testing.expectEqual(@as(?u8, 2), idx);
}

test "placeItem returns null when all slots full" {
    var c = CampfireState.init(false);
    _ = c.placeItem(.{ .item = 550, .count = 1 });
    _ = c.placeItem(.{ .item = 552, .count = 1 });
    _ = c.placeItem(.{ .item = 554, .count = 1 });
    _ = c.placeItem(.{ .item = 556, .count = 1 });
    const idx = c.placeItem(.{ .item = 558, .count = 1 });
    try std.testing.expectEqual(@as(?u8, null), idx);
}

test "placeItem rejects items without recipe" {
    var c = CampfireState.init(false);
    const idx = c.placeItem(.{ .item = 999, .count = 1 });
    try std.testing.expectEqual(@as(?u8, null), idx);
    try std.testing.expect(c.slots[0].isEmpty());
}

test "placeItem rejects empty slot input" {
    var c = CampfireState.init(false);
    const idx = c.placeItem(Slot.empty);
    try std.testing.expectEqual(@as(?u8, null), idx);
}

test "update cooks item after 30 seconds" {
    var c = CampfireState.init(false);
    _ = c.placeItem(.{ .item = 550, .count = 1 });

    const r1 = c.update(29.9);
    try std.testing.expectEqual(@as(?Slot, null), r1[0]);
    try std.testing.expect(!c.slots[0].isEmpty());

    const r2 = c.update(0.1);
    try std.testing.expect(r2[0] != null);
    try std.testing.expectEqual(@as(u16, 551), r2[0].?.item);
    try std.testing.expectEqual(@as(u8, 1), r2[0].?.count);
    try std.testing.expect(c.slots[0].isEmpty());
}

test "update handles multiple slots independently" {
    var c = CampfireState.init(false);
    _ = c.placeItem(.{ .item = 550, .count = 1 }); // slot 0
    _ = c.update(15.0); // slot 0 at 15s

    _ = c.placeItem(.{ .item = 552, .count = 1 }); // slot 1 at 0s

    const r1 = c.update(15.0); // slot 0 at 30s, slot 1 at 15s
    try std.testing.expect(r1[0] != null);
    try std.testing.expectEqual(@as(u16, 551), r1[0].?.item);
    try std.testing.expectEqual(@as(?Slot, null), r1[1]);

    const r2 = c.update(15.0); // slot 1 at 30s
    try std.testing.expect(r2[1] != null);
    try std.testing.expectEqual(@as(u16, 553), r2[1].?.item);
}

test "update with zero or negative dt does nothing" {
    var c = CampfireState.init(false);
    _ = c.placeItem(.{ .item = 550, .count = 1 });
    const r = c.update(0);
    try std.testing.expectEqual(@as(?Slot, null), r[0]);
    try std.testing.expectEqual(@as(f32, 0), c.cook_progress[0]);
}

test "getProgress returns fraction of cook time" {
    var c = CampfireState.init(false);
    _ = c.placeItem(.{ .item = 550, .count = 1 });
    _ = c.update(15.0);
    const prog = c.getProgress(0);
    try std.testing.expectEqual(@as(f32, 0.5), prog);
}

test "getProgress returns 0 for empty slot" {
    const c = CampfireState.init(false);
    try std.testing.expectEqual(@as(f32, 0), c.getProgress(0));
}

test "getProgress returns 0 for out-of-bounds slot" {
    const c = CampfireState.init(false);
    try std.testing.expectEqual(@as(f32, 0), c.getProgress(4));
    try std.testing.expectEqual(@as(f32, 0), c.getProgress(255));
}

test "hasRecipe returns true for valid inputs" {
    try std.testing.expect(hasRecipe(550)); // raw_porkchop
    try std.testing.expect(hasRecipe(566)); // kelp
}

test "hasRecipe returns false for unknown items" {
    try std.testing.expect(!hasRecipe(0));
    try std.testing.expect(!hasRecipe(999));
    try std.testing.expect(!hasRecipe(551)); // cooked_porkchop (output, not input)
}

test "getRecipeOutput returns correct output" {
    try std.testing.expectEqual(@as(?u16, 551), getRecipeOutput(550));
    try std.testing.expectEqual(@as(?u16, 565), getRecipeOutput(564));
    try std.testing.expectEqual(@as(?u16, 567), getRecipeOutput(566));
}

test "getRecipeOutput returns null for unknown items" {
    try std.testing.expectEqual(@as(?u16, null), getRecipeOutput(0));
    try std.testing.expectEqual(@as(?u16, null), getRecipeOutput(999));
}

test "all 9 recipes produce correct outputs" {
    const expected = [_][2]u16{
        .{ 550, 551 },
        .{ 552, 553 },
        .{ 554, 555 },
        .{ 556, 557 },
        .{ 558, 559 },
        .{ 560, 561 },
        .{ 562, 563 },
        .{ 564, 565 },
        .{ 566, 567 },
    };
    for (expected) |pair| {
        try std.testing.expect(hasRecipe(pair[0]));
        try std.testing.expectEqual(@as(?u16, pair[1]), getRecipeOutput(pair[0]));
    }
}

test "slot clears after cooking completes" {
    var c = CampfireState.init(false);
    _ = c.placeItem(.{ .item = 552, .count = 1 });
    _ = c.update(30.0);
    try std.testing.expect(c.slots[0].isEmpty());
    try std.testing.expectEqual(@as(f32, 0), c.cook_progress[0]);
}
