/// Recipe discovery system for the recipe book UI.
/// Tracks which recipes a player has unlocked via a compact bitset.
/// Recipes are discovered when the player picks up a relevant ingredient
/// or explicitly through creative mode / commands.

const std = @import("std");

const recipes_tools = @import("recipes_tools.zig");
const recipes_armor = @import("recipes_armor.zig");
const recipes_redstone = @import("recipes_redstone.zig");
const recipes_decorative = @import("recipes_decorative.zig");
const recipes_transport = @import("recipes_transport.zig");
const recipes_food = @import("recipes_food.zig");

pub const MAX_RECIPES: u16 = 512;

// Recipe ID assignment scheme (maps to recipe array indices):
pub const RECIPE_OFFSET_TOOLS: u16 = 0; // 25 recipes
pub const RECIPE_OFFSET_ARMOR: u16 = 25; // 20 recipes
pub const RECIPE_OFFSET_REDSTONE: u16 = 45; // 15 recipes
pub const RECIPE_OFFSET_DECORATIVE: u16 = 60; // 40 recipes
pub const RECIPE_OFFSET_TRANSPORT: u16 = 100; // 20 recipes
pub const RECIPE_OFFSET_FOOD: u16 = 120; // 15 recipes
pub const RECIPE_OFFSET_COLORED: u16 = 135; // 80 recipes
pub const RECIPE_OFFSET_WOOD: u16 = 215; // 60 recipes

const BITSET_LEN = MAX_RECIPES / 8;

pub const RecipeBook = struct {
    discovered: [BITSET_LEN]u8 = [_]u8{0} ** BITSET_LEN,
    total_discovered: u16 = 0,

    pub fn init() RecipeBook {
        return .{};
    }

    /// Set bit for recipe_id. Returns true if newly discovered (was not set before).
    pub fn discover(self: *RecipeBook, recipe_id: u16) bool {
        if (recipe_id >= MAX_RECIPES) return false;

        const byte_idx = recipe_id / 8;
        const bit_mask = @as(u8, 1) << @intCast(recipe_id % 8);

        if (self.discovered[byte_idx] & bit_mask != 0) {
            return false;
        }

        self.discovered[byte_idx] |= bit_mask;
        self.total_discovered += 1;
        return true;
    }

    /// Check whether a recipe has been discovered.
    pub fn isDiscovered(self: *const RecipeBook, recipe_id: u16) bool {
        if (recipe_id >= MAX_RECIPES) return false;

        const byte_idx = recipe_id / 8;
        const bit_mask = @as(u8, 1) << @intCast(recipe_id % 8);

        return (self.discovered[byte_idx] & bit_mask) != 0;
    }

    /// Creative mode: unlock every recipe slot.
    pub fn discoverAll(self: *RecipeBook) void {
        @memset(&self.discovered, 0xFF);
        self.total_discovered = MAX_RECIPES;
    }

    /// When a player picks up an item, discover all recipes that use it as input.
    /// Scans tool, armor, redstone, decorative, transport, and food recipe categories.
    /// Returns the number of newly discovered recipes.
    pub fn discoverByItem(self: *RecipeBook, item_id: u16) u16 {
        var newly_discovered: u16 = 0;

        const categories = .{
            .{ RECIPE_OFFSET_TOOLS, &recipes_tools.recipes },
            .{ RECIPE_OFFSET_ARMOR, &recipes_armor.recipes },
            .{ RECIPE_OFFSET_REDSTONE, &recipes_redstone.recipes },
            .{ RECIPE_OFFSET_DECORATIVE, &recipes_decorative.recipes },
            .{ RECIPE_OFFSET_TRANSPORT, &recipes_transport.recipes },
            .{ RECIPE_OFFSET_FOOD, &recipes_food.recipes },
        };

        inline for (categories) |cat| {
            newly_discovered += self.scanCategory(item_id, cat[0], cat[1]);
        }

        return newly_discovered;
    }

    pub fn getDiscoveredCount(self: *const RecipeBook) u16 {
        return self.total_discovered;
    }

    /// Reset all discoveries back to zero.
    pub fn reset(self: *RecipeBook) void {
        @memset(&self.discovered, 0);
        self.total_discovered = 0;
    }

    // -- Private helpers --

    /// Scan a slice of shaped recipes for any that contain `item_id` in their pattern.
    /// Discovers matching recipes and returns the count of newly discovered ones.
    fn scanCategory(
        self: *RecipeBook,
        item_id: u16,
        offset: u16,
        recipes: anytype,
    ) u16 {
        var count: u16 = 0;
        for (recipes, 0..) |recipe, i| {
            if (patternContainsItem(recipe.pattern, item_id)) {
                if (self.discover(offset + @as(u16, @intCast(i)))) {
                    count += 1;
                }
            }
        }
        return count;
    }
};

/// Check whether a 3x3 crafting pattern contains the given item_id in any cell.
fn patternContainsItem(pattern: [3][3]u16, item_id: u16) bool {
    for (0..3) |r| {
        for (0..3) |c| {
            if (pattern[r][c] == item_id) return true;
        }
    }
    return false;
}

// ===========================================================================
// Tests
// ===========================================================================

test "init creates empty recipe book" {
    const book = RecipeBook.init();
    try std.testing.expectEqual(@as(u16, 0), book.total_discovered);
    for (book.discovered) |byte| {
        try std.testing.expectEqual(@as(u8, 0), byte);
    }
}

test "discover sets bit and returns true for new recipe" {
    var book = RecipeBook.init();
    const newly = book.discover(0);
    try std.testing.expect(newly);
    try std.testing.expect(book.isDiscovered(0));
    try std.testing.expectEqual(@as(u16, 1), book.getDiscoveredCount());
}

test "discover returns false for already discovered recipe" {
    var book = RecipeBook.init();
    _ = book.discover(10);
    const second = book.discover(10);
    try std.testing.expect(!second);
    try std.testing.expectEqual(@as(u16, 1), book.getDiscoveredCount());
}

test "discover rejects out-of-range recipe_id" {
    var book = RecipeBook.init();
    const result = book.discover(MAX_RECIPES);
    try std.testing.expect(!result);
    try std.testing.expectEqual(@as(u16, 0), book.getDiscoveredCount());

    const result2 = book.discover(MAX_RECIPES + 100);
    try std.testing.expect(!result2);
}

test "isDiscovered returns false for undiscovered recipe" {
    const book = RecipeBook.init();
    try std.testing.expect(!book.isDiscovered(42));
}

test "isDiscovered rejects out-of-range recipe_id" {
    const book = RecipeBook.init();
    try std.testing.expect(!book.isDiscovered(MAX_RECIPES));
    try std.testing.expect(!book.isDiscovered(MAX_RECIPES + 1));
}

test "discoverAll unlocks every recipe" {
    var book = RecipeBook.init();
    book.discoverAll();
    try std.testing.expectEqual(MAX_RECIPES, book.getDiscoveredCount());
    try std.testing.expect(book.isDiscovered(0));
    try std.testing.expect(book.isDiscovered(MAX_RECIPES - 1));
    try std.testing.expect(book.isDiscovered(255));
}

test "reset clears all discoveries" {
    var book = RecipeBook.init();
    _ = book.discover(5);
    _ = book.discover(100);
    _ = book.discover(511);
    try std.testing.expectEqual(@as(u16, 3), book.getDiscoveredCount());

    book.reset();
    try std.testing.expectEqual(@as(u16, 0), book.getDiscoveredCount());
    try std.testing.expect(!book.isDiscovered(5));
    try std.testing.expect(!book.isDiscovered(100));
    try std.testing.expect(!book.isDiscovered(511));
}

test "discover multiple distinct recipes" {
    var book = RecipeBook.init();
    _ = book.discover(0);
    _ = book.discover(7);
    _ = book.discover(8);
    _ = book.discover(63);
    _ = book.discover(64);
    try std.testing.expectEqual(@as(u16, 5), book.getDiscoveredCount());
    try std.testing.expect(book.isDiscovered(0));
    try std.testing.expect(book.isDiscovered(7));
    try std.testing.expect(book.isDiscovered(8));
    try std.testing.expect(book.isDiscovered(63));
    try std.testing.expect(book.isDiscovered(64));
    try std.testing.expect(!book.isDiscovered(1));
}

test "discoverByItem finds tool recipes using stick" {
    var book = RecipeBook.init();
    // Stick (256) is used in all 25 tool recipes
    const count = book.discoverByItem(256);
    try std.testing.expect(count >= 25);
    // Verify a specific tool recipe was discovered (recipe 0 = wooden pickaxe)
    try std.testing.expect(book.isDiscovered(RECIPE_OFFSET_TOOLS));
}

test "discoverByItem returns zero for unknown item" {
    var book = RecipeBook.init();
    // item_id 9999 does not appear in any recipe pattern
    const count = book.discoverByItem(9999);
    try std.testing.expectEqual(@as(u16, 0), count);
    try std.testing.expectEqual(@as(u16, 0), book.getDiscoveredCount());
}

test "discoverByItem does not double-count already discovered" {
    var book = RecipeBook.init();
    const first = book.discoverByItem(256);
    const second = book.discoverByItem(256);
    try std.testing.expectEqual(@as(u16, 0), second);
    try std.testing.expect(first > 0);
}

test "patternContainsItem detects item in pattern" {
    const pattern: [3][3]u16 = .{
        .{ 0, 5, 0 },
        .{ 0, 256, 0 },
        .{ 0, 256, 0 },
    };
    try std.testing.expect(patternContainsItem(pattern, 5));
    try std.testing.expect(patternContainsItem(pattern, 256));
    try std.testing.expect(!patternContainsItem(pattern, 999));
    try std.testing.expect(!patternContainsItem(pattern, 1));
}

test "bitset boundary - first and last bits in each byte" {
    var book = RecipeBook.init();
    // Test bit 0 of byte 0
    _ = book.discover(0);
    try std.testing.expect(book.isDiscovered(0));
    // Test bit 7 of byte 0
    _ = book.discover(7);
    try std.testing.expect(book.isDiscovered(7));
    // Test bit 0 of byte 1
    _ = book.discover(8);
    try std.testing.expect(book.isDiscovered(8));
    // Test last valid recipe
    _ = book.discover(MAX_RECIPES - 1);
    try std.testing.expect(book.isDiscovered(MAX_RECIPES - 1));
    try std.testing.expectEqual(@as(u16, 4), book.getDiscoveredCount());
}
