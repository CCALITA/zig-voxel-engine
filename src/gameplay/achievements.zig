/// Achievement / advancement tracking system.
/// Achievements form a tree: each achievement (except roots) has a parent prerequisite
/// that must be unlocked before the child can be earned.

const std = @import("std");

pub const AchievementId = enum(u32) {
    open_inventory = 0,
    mine_wood = 1,
    craft_planks = 2,
    craft_crafting_table = 3,
    craft_pickaxe = 4,
    mine_stone = 5,
    craft_furnace = 6,
    smelt_iron = 7,
    mine_diamond = 8,
    enter_nether = 9,
    kill_zombie = 10,
    eat_food = 11,
    breed_animals = 12,
    enchant_item = 13,
    brew_potion = 14,
    kill_dragon = 15,
};

pub const Achievement = struct {
    id: AchievementId,
    name: []const u8,
    description: []const u8,
    parent: ?AchievementId,
    hidden: bool,
};

pub const ACHIEVEMENTS = [_]Achievement{
    .{ .id = .open_inventory, .name = "Taking Inventory", .description = "Open your inventory", .parent = null, .hidden = false },
    .{ .id = .mine_wood, .name = "Getting Wood", .description = "Punch a tree", .parent = .open_inventory, .hidden = false },
    .{ .id = .craft_planks, .name = "Benchmaking", .description = "Craft wooden planks", .parent = .mine_wood, .hidden = false },
    .{ .id = .craft_crafting_table, .name = "Crafting Table", .description = "Craft a crafting table", .parent = .craft_planks, .hidden = false },
    .{ .id = .craft_pickaxe, .name = "Time to Mine!", .description = "Craft a wooden pickaxe", .parent = .craft_crafting_table, .hidden = false },
    .{ .id = .mine_stone, .name = "Stone Age", .description = "Mine stone with a pickaxe", .parent = .craft_pickaxe, .hidden = false },
    .{ .id = .craft_furnace, .name = "Hot Topic", .description = "Craft a furnace", .parent = .mine_stone, .hidden = false },
    .{ .id = .smelt_iron, .name = "Acquire Hardware", .description = "Smelt an iron ingot", .parent = .craft_furnace, .hidden = false },
    .{ .id = .mine_diamond, .name = "Diamonds!", .description = "Mine a diamond", .parent = .smelt_iron, .hidden = false },
    .{ .id = .enter_nether, .name = "We Need to Go Deeper", .description = "Enter the Nether", .parent = .mine_diamond, .hidden = false },
    .{ .id = .kill_zombie, .name = "Monster Hunter", .description = "Kill a zombie", .parent = .open_inventory, .hidden = false },
    .{ .id = .eat_food, .name = "Delicious Fish", .description = "Eat something", .parent = .open_inventory, .hidden = false },
    .{ .id = .breed_animals, .name = "Repopulation", .description = "Breed two animals", .parent = .eat_food, .hidden = false },
    .{ .id = .enchant_item, .name = "Enchanter", .description = "Enchant an item", .parent = .mine_diamond, .hidden = true },
    .{ .id = .brew_potion, .name = "Local Brewery", .description = "Brew a potion", .parent = .enter_nether, .hidden = true },
    .{ .id = .kill_dragon, .name = "The End.", .description = "Defeat the Ender Dragon", .parent = .enter_nether, .hidden = true },
};

pub const ACHIEVEMENT_COUNT: u32 = ACHIEVEMENTS.len;

pub const AchievementTracker = struct {
    unlocked: [ACHIEVEMENT_COUNT]bool,

    pub fn init() AchievementTracker {
        return .{ .unlocked = [_]bool{false} ** ACHIEVEMENT_COUNT };
    }

    /// Attempt to unlock an achievement. Returns true if it was newly unlocked,
    /// false if already unlocked or if the prerequisite parent is not yet unlocked.
    pub fn unlock(self: *AchievementTracker, id: AchievementId) bool {
        if (!self.canUnlock(id)) return false;

        const idx = @intFromEnum(id);
        if (self.unlocked[idx]) return false;

        self.unlocked[idx] = true;
        return true;
    }

    pub fn isUnlocked(self: *const AchievementTracker, id: AchievementId) bool {
        return self.unlocked[@intFromEnum(id)];
    }

    /// Returns true when the parent prerequisite (if any) is already unlocked.
    pub fn canUnlock(self: *const AchievementTracker, id: AchievementId) bool {
        const achievement = ACHIEVEMENTS[@intFromEnum(id)];
        if (achievement.parent) |parent| {
            return self.isUnlocked(parent);
        }
        return true;
    }

    pub fn unlockedCount(self: *const AchievementTracker) u32 {
        var count: u32 = 0;
        for (self.unlocked) |u| {
            if (u) count += 1;
        }
        return count;
    }

    pub fn totalCount() u32 {
        return ACHIEVEMENT_COUNT;
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "init: nothing unlocked" {
    const tracker = AchievementTracker.init();
    for (tracker.unlocked) |u| {
        try std.testing.expect(!u);
    }
    try std.testing.expectEqual(@as(u32, 0), tracker.unlockedCount());
}

test "unlock first (root) achievement" {
    var tracker = AchievementTracker.init();
    try std.testing.expect(tracker.canUnlock(.open_inventory));
    const newly = tracker.unlock(.open_inventory);
    try std.testing.expect(newly);
    try std.testing.expect(tracker.isUnlocked(.open_inventory));
    try std.testing.expectEqual(@as(u32, 1), tracker.unlockedCount());
}

test "cannot unlock child without parent" {
    var tracker = AchievementTracker.init();
    try std.testing.expect(!tracker.canUnlock(.mine_wood));
    const result = tracker.unlock(.mine_wood);
    try std.testing.expect(!result);
    try std.testing.expect(!tracker.isUnlocked(.mine_wood));
}

test "unlock chain: parent then child" {
    var tracker = AchievementTracker.init();

    // Unlock root
    try std.testing.expect(tracker.unlock(.open_inventory));
    // Now child is unlockable
    try std.testing.expect(tracker.canUnlock(.mine_wood));
    try std.testing.expect(tracker.unlock(.mine_wood));
    try std.testing.expect(tracker.isUnlocked(.mine_wood));

    // Continue the chain
    try std.testing.expect(tracker.unlock(.craft_planks));
    try std.testing.expect(tracker.unlock(.craft_crafting_table));
    try std.testing.expectEqual(@as(u32, 4), tracker.unlockedCount());
}

test "count tracking" {
    var tracker = AchievementTracker.init();
    try std.testing.expectEqual(@as(u32, 16), AchievementTracker.totalCount());
    try std.testing.expectEqual(@as(u32, 0), tracker.unlockedCount());

    _ = tracker.unlock(.open_inventory);
    try std.testing.expectEqual(@as(u32, 1), tracker.unlockedCount());

    _ = tracker.unlock(.mine_wood);
    try std.testing.expectEqual(@as(u32, 2), tracker.unlockedCount());

    _ = tracker.unlock(.kill_zombie);
    try std.testing.expectEqual(@as(u32, 3), tracker.unlockedCount());
}

test "double-unlock returns false" {
    var tracker = AchievementTracker.init();
    try std.testing.expect(tracker.unlock(.open_inventory));
    // Second unlock of same achievement returns false
    try std.testing.expect(!tracker.unlock(.open_inventory));
    // Still only counted once
    try std.testing.expectEqual(@as(u32, 1), tracker.unlockedCount());
}
