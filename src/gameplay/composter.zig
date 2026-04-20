const std = @import("std");

pub const CompostChance = enum {
    none,
    low,
    medium,
    high,
    guaranteed,
};

pub const ComposterState = struct {
    level: u3 = 0,

    pub fn addItem(self: *ComposterState, item_id: u16, seed: u64) bool {
        if (!self.canAddItem()) return false;

        const chance = getCompostChance(item_id);
        const percent = getChancePercent(chance);
        if (percent == 0) return false;

        var rng = std.Random.DefaultPrng.init(seed);
        const roll = rng.random().intRangeAtMost(u8, 1, 100);

        if (roll <= percent) {
            self.level +|= 1;
            return true;
        }
        return false;
    }

    pub fn harvest(self: *ComposterState) ?u16 {
        if (self.level != 7) return null;
        self.level = 0;
        return 856; // bone_meal item ID
    }

    pub fn getRedstoneOutput(self: ComposterState) u4 {
        const result: u8 = @as(u8, self.level) * 2;
        return if (result > 14) 14 else @intCast(result);
    }

    pub fn canAddItem(self: ComposterState) bool {
        return self.level < 7;
    }
};

pub fn getCompostChance(item_id: u16) CompostChance {
    return switch (item_id) {
        // Seeds and short grass (30%)
        295, 296, 298, 299, 300, 301, 31 => .low,
        // Flowers and leaves (65%)
        37, 38, 39, 40, 175, 176, 18, 161 => .medium,
        // Food and bread (85%)
        297, 350, 364, 366, 391, 392, 393, 396 => .high,
        // Cake and pumpkin pie (100%)
        354, 400 => .guaranteed,
        else => .none,
    };
}

pub fn getChancePercent(chance: CompostChance) u8 {
    return switch (chance) {
        .none => 0,
        .low => 30,
        .medium => 65,
        .high => 85,
        .guaranteed => 100,
    };
}

test "getChancePercent returns correct values" {
    try std.testing.expectEqual(@as(u8, 0), getChancePercent(.none));
    try std.testing.expectEqual(@as(u8, 30), getChancePercent(.low));
    try std.testing.expectEqual(@as(u8, 65), getChancePercent(.medium));
    try std.testing.expectEqual(@as(u8, 85), getChancePercent(.high));
    try std.testing.expectEqual(@as(u8, 100), getChancePercent(.guaranteed));
}

test "addItem with guaranteed chance always succeeds" {
    var state = ComposterState{};
    // cake = 354 (guaranteed)
    const result = state.addItem(354, 42);
    try std.testing.expect(result);
    try std.testing.expect(state.level > 0);
}

test "addItem with none chance always fails" {
    var state = ComposterState{};
    const result = state.addItem(9999, 42);
    try std.testing.expect(!result);
    try std.testing.expectEqual(@as(u3, 0), state.level);
}

test "harvest returns bone meal at level 7 and resets" {
    var state = ComposterState{ .level = 7 };
    const item = state.harvest();
    try std.testing.expect(item != null);
    try std.testing.expectEqual(@as(u16, 856), item.?);
    try std.testing.expectEqual(@as(u3, 0), state.level);
}

test "harvest returns null when level is not 7" {
    var state = ComposterState{ .level = 5 };
    const item = state.harvest();
    try std.testing.expect(item == null);
    try std.testing.expectEqual(@as(u3, 5), state.level);
}

test "canAddItem returns false at level 7" {
    const state = ComposterState{ .level = 7 };
    try std.testing.expect(!state.canAddItem());
}

test "canAddItem returns true below level 7" {
    const state = ComposterState{ .level = 6 };
    try std.testing.expect(state.canAddItem());
}

test "addItem rejected when level is 7" {
    var state = ComposterState{ .level = 7 };
    const result = state.addItem(354, 42);
    try std.testing.expect(!result);
    try std.testing.expectEqual(@as(u3, 7), state.level);
}

test "getRedstoneOutput returns level times 2" {
    try std.testing.expectEqual(@as(u4, 0), (ComposterState{ .level = 0 }).getRedstoneOutput());
    try std.testing.expectEqual(@as(u4, 6), (ComposterState{ .level = 3 }).getRedstoneOutput());
    try std.testing.expectEqual(@as(u4, 14), (ComposterState{ .level = 7 }).getRedstoneOutput());
}

test "getCompostChance returns correct categories" {
    // seeds = low
    try std.testing.expectEqual(CompostChance.low, getCompostChance(295));
    // flowers = medium
    try std.testing.expectEqual(CompostChance.medium, getCompostChance(37));
    // cake = guaranteed
    try std.testing.expectEqual(CompostChance.guaranteed, getCompostChance(354));
    // unknown = none
    try std.testing.expectEqual(CompostChance.none, getCompostChance(9999));
}
