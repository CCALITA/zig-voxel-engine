const std = @import("std");

/// XP values for common actions.
pub const XP_COAL_ORE: u32 = 1;
pub const XP_IRON_ORE: u32 = 2;
pub const XP_GOLD_ORE: u32 = 3;
pub const XP_DIAMOND_ORE: u32 = 7;
pub const XP_REDSTONE_ORE: u32 = 3;
pub const XP_MOB_KILL: u32 = 5;
pub const XP_SMELT: u32 = 1;

/// Returns the XP required to advance from `level` to `level + 1`.
/// Minecraft XP curve:
///   levels  0-16  =>  2*level + 7
///   levels 17-31  =>  5*level - 38
///   levels 32+    =>  9*level - 158
pub fn xpForLevel(level: u32) u32 {
    if (level < 17) {
        return 2 * level + 7;
    } else if (level < 32) {
        return 5 * level - 38;
    } else {
        return 9 * level - 158;
    }
}

/// Returns the cumulative XP needed to reach `level` from level 0.
pub fn totalXPForLevel(level: u32) u32 {
    var total: u32 = 0;
    for (0..level) |i| {
        total += xpForLevel(@intCast(i));
    }
    return total;
}

pub const ExperienceTracker = struct {
    total_xp: u32 = 0,
    level: u32 = 0,
    progress: f32 = 0.0,

    pub fn init() ExperienceTracker {
        return .{};
    }

    /// Adds XP and recalculates the current level and progress.
    pub fn addXP(self: *ExperienceTracker, amount: u32) void {
        self.total_xp += amount;
        self.recalculate();
    }

    pub fn getLevel(self: *const ExperienceTracker) u32 {
        return self.level;
    }

    pub fn getProgress(self: *const ExperienceTracker) f32 {
        return self.progress;
    }

    /// Returns true if the tracker has at least `levels` levels available to spend.
    pub fn canAfford(self: *const ExperienceTracker, levels: u32) bool {
        return self.level >= levels;
    }

    /// Spends `levels` levels (e.g. for enchanting), reducing total_xp accordingly.
    /// Returns false if the player cannot afford the cost.
    pub fn spendLevels(self: *ExperienceTracker, levels: u32) bool {
        if (!self.canAfford(levels)) return false;

        const target_level = self.level - levels;
        const target_xp = totalXPForLevel(target_level);
        self.total_xp = target_xp;
        self.recalculate();
        return true;
    }

    /// Derives level and progress from total_xp.
    fn recalculate(self: *ExperienceTracker) void {
        var remaining: u32 = self.total_xp;
        var lvl: u32 = 0;

        while (true) {
            const needed = xpForLevel(lvl);
            if (remaining < needed) break;
            remaining -= needed;
            lvl += 1;
        }

        self.level = lvl;
        const needed = xpForLevel(lvl);
        self.progress = @as(f32, @floatFromInt(remaining)) / @as(f32, @floatFromInt(needed));
    }
};

// ──────────────────────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────────────────────

test "xpForLevel follows Minecraft curve" {
    // Tier 1: 2*level + 7
    try std.testing.expectEqual(@as(u32, 7), xpForLevel(0));
    try std.testing.expectEqual(@as(u32, 9), xpForLevel(1));
    try std.testing.expectEqual(@as(u32, 39), xpForLevel(16));

    // Tier 2: 5*level - 38
    try std.testing.expectEqual(@as(u32, 47), xpForLevel(17));
    try std.testing.expectEqual(@as(u32, 117), xpForLevel(31));

    // Tier 3: 9*level - 158
    try std.testing.expectEqual(@as(u32, 130), xpForLevel(32));
    try std.testing.expectEqual(@as(u32, 292), xpForLevel(50));
}

test "totalXPForLevel is cumulative" {
    try std.testing.expectEqual(@as(u32, 0), totalXPForLevel(0));
    try std.testing.expectEqual(@as(u32, 7), totalXPForLevel(1)); // xpForLevel(0) = 7
    try std.testing.expectEqual(@as(u32, 16), totalXPForLevel(2)); // 7 + 9

    // Verify consistency: totalXPForLevel(n+1) = totalXPForLevel(n) + xpForLevel(n)
    for (0..50) |i| {
        const lvl: u32 = @intCast(i);
        try std.testing.expectEqual(totalXPForLevel(lvl) + xpForLevel(lvl), totalXPForLevel(lvl + 1));
    }
}

test "init returns zero state" {
    const tracker = ExperienceTracker.init();
    try std.testing.expectEqual(@as(u32, 0), tracker.total_xp);
    try std.testing.expectEqual(@as(u32, 0), tracker.getLevel());
    try std.testing.expectEqual(@as(f32, 0.0), tracker.getProgress());
}

test "addXP levels up correctly" {
    var tracker = ExperienceTracker.init();

    // Add exactly enough to reach level 1 (need 7 XP)
    tracker.addXP(7);
    try std.testing.expectEqual(@as(u32, 1), tracker.getLevel());
    try std.testing.expectEqual(@as(f32, 0.0), tracker.getProgress());

    // Add 4 more toward level 2 (need 9 to go from 1 to 2)
    tracker.addXP(4);
    try std.testing.expectEqual(@as(u32, 1), tracker.getLevel());
    // Progress should be 4/9
    try std.testing.expectApproxEqAbs(@as(f32, 4.0 / 9.0), tracker.getProgress(), 0.001);

    // Add 5 more to reach level 2
    tracker.addXP(5);
    try std.testing.expectEqual(@as(u32, 2), tracker.getLevel());
    try std.testing.expectEqual(@as(f32, 0.0), tracker.getProgress());
}

test "addXP handles large jumps" {
    var tracker = ExperienceTracker.init();

    // Add enough XP for level 16 in one go
    const xp_for_16 = totalXPForLevel(16);
    tracker.addXP(xp_for_16);
    try std.testing.expectEqual(@as(u32, 16), tracker.getLevel());
    try std.testing.expectEqual(@as(f32, 0.0), tracker.getProgress());
}

test "progress fraction is between 0 and 1" {
    var tracker = ExperienceTracker.init();

    // Accumulate XP in small increments, checking progress at each step
    for (0..100) |_| {
        tracker.addXP(1);
        try std.testing.expect(tracker.getProgress() >= 0.0);
        try std.testing.expect(tracker.getProgress() <= 1.0);
    }
}

test "canAfford checks level availability" {
    var tracker = ExperienceTracker.init();
    tracker.addXP(totalXPForLevel(10));

    try std.testing.expect(tracker.canAfford(10));
    try std.testing.expect(tracker.canAfford(5));
    try std.testing.expect(!tracker.canAfford(11));
}

test "spendLevels reduces level and XP" {
    var tracker = ExperienceTracker.init();
    tracker.addXP(totalXPForLevel(10));
    try std.testing.expectEqual(@as(u32, 10), tracker.getLevel());

    // Spend 3 levels: drops to level 7
    try std.testing.expect(tracker.spendLevels(3));
    try std.testing.expectEqual(@as(u32, 7), tracker.getLevel());
    try std.testing.expectEqual(@as(f32, 0.0), tracker.getProgress());
    try std.testing.expectEqual(totalXPForLevel(7), tracker.total_xp);
}

test "spendLevels fails when cannot afford" {
    var tracker = ExperienceTracker.init();
    tracker.addXP(totalXPForLevel(5));

    try std.testing.expect(!tracker.spendLevels(6));
    // State should be unchanged
    try std.testing.expectEqual(@as(u32, 5), tracker.getLevel());
}

test "spendLevels can spend all levels" {
    var tracker = ExperienceTracker.init();
    tracker.addXP(totalXPForLevel(5));

    try std.testing.expect(tracker.spendLevels(5));
    try std.testing.expectEqual(@as(u32, 0), tracker.getLevel());
    try std.testing.expectEqual(@as(u32, 0), tracker.total_xp);
}
