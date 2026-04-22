/// Crafting recipe registry.
/// Recipes are 3x3 grids of ItemId values (0 = empty cell).
/// The registry supports exact-match lookup against a crafting grid.

const std = @import("std");

pub const ItemId = @import("inventory.zig").ItemId;

/// Block IDs re-exported for recipe registration convenience.
/// These mirror the values in world/block.zig.
const OAK_LOG: ItemId = 8;
const OAK_PLANKS: ItemId = 5;

/// Stick is a non-block item, assigned the first ID above the block range.
pub const STICK: ItemId = 256;
/// Crafting table — uses block ID so it can be placed in the world.
pub const CRAFTING_TABLE: ItemId = 110;

pub const Recipe = struct {
    pattern: [3][3]ItemId,
    result_item: ItemId,
    result_count: u8,
};

pub const CraftingRegistry = struct {
    recipes: std.ArrayList(Recipe),

    pub fn init() CraftingRegistry {
        return .{ .recipes = .empty };
    }

    pub fn deinit(self: *CraftingRegistry, allocator: std.mem.Allocator) void {
        self.recipes.deinit(allocator);
    }

    pub fn addRecipe(self: *CraftingRegistry, allocator: std.mem.Allocator, recipe: Recipe) !void {
        try self.recipes.append(allocator, recipe);
    }

    /// Find a recipe whose pattern exactly matches `grid`.
    /// Returns the matching Recipe or null.
    pub fn findMatch(self: *const CraftingRegistry, grid: [3][3]ItemId) ?Recipe {
        for (self.recipes.items) |recipe| {
            if (patternsEqual(recipe.pattern, grid)) {
                return recipe;
            }
        }
        return null;
    }

    fn patternsEqual(a: [3][3]ItemId, b: [3][3]ItemId) bool {
        for (0..3) |r| {
            for (0..3) |c| {
                if (a[r][c] != b[r][c]) return false;
            }
        }
        return true;
    }

    /// Register the starter recipes (planks, sticks, crafting table).
    pub fn registerDefaults(self: *CraftingRegistry, allocator: std.mem.Allocator) !void {
        // 1 oak log -> 4 oak planks (shapeless-ish: log in top-left)
        try self.addRecipe(allocator, .{
            .pattern = .{
                .{ OAK_LOG, 0, 0 },
                .{ 0, 0, 0 },
                .{ 0, 0, 0 },
            },
            .result_item = OAK_PLANKS,
            .result_count = 4,
        });

        // 2 planks (vertical) -> 4 sticks
        try self.addRecipe(allocator, .{
            .pattern = .{
                .{ OAK_PLANKS, 0, 0 },
                .{ OAK_PLANKS, 0, 0 },
                .{ 0, 0, 0 },
            },
            .result_item = STICK,
            .result_count = 4,
        });

        // 4 planks in a 2x2 -> 1 crafting table
        try self.addRecipe(allocator, .{
            .pattern = .{
                .{ OAK_PLANKS, OAK_PLANKS, 0 },
                .{ OAK_PLANKS, OAK_PLANKS, 0 },
                .{ 0, 0, 0 },
            },
            .result_item = CRAFTING_TABLE,
            .result_count = 1,
        });
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "match a known recipe (planks from log)" {
    const allocator = std.testing.allocator;
    var reg = CraftingRegistry.init();
    defer reg.deinit(allocator);

    try reg.registerDefaults(allocator);

    const grid: [3][3]ItemId = .{
        .{ OAK_LOG, 0, 0 },
        .{ 0, 0, 0 },
        .{ 0, 0, 0 },
    };

    const result = reg.findMatch(grid);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(OAK_PLANKS, result.?.result_item);
    try std.testing.expectEqual(@as(u8, 4), result.?.result_count);
}

test "no match returns null" {
    const allocator = std.testing.allocator;
    var reg = CraftingRegistry.init();
    defer reg.deinit(allocator);

    try reg.registerDefaults(allocator);

    // Random grid that matches nothing.
    const grid: [3][3]ItemId = .{
        .{ 99, 0, 0 },
        .{ 0, 99, 0 },
        .{ 0, 0, 99 },
    };

    try std.testing.expectEqual(@as(?Recipe, null), reg.findMatch(grid));
}

test "register and find custom recipe" {
    const allocator = std.testing.allocator;
    var reg = CraftingRegistry.init();
    defer reg.deinit(allocator);

    const custom = Recipe{
        .pattern = .{
            .{ 1, 1, 1 },
            .{ 0, 1, 0 },
            .{ 0, 1, 0 },
        },
        .result_item = 300,
        .result_count = 1,
    };
    try reg.addRecipe(allocator, custom);

    const found = reg.findMatch(custom.pattern);
    try std.testing.expect(found != null);
    try std.testing.expectEqual(@as(ItemId, 300), found.?.result_item);
}

test "sticks recipe matches" {
    const allocator = std.testing.allocator;
    var reg = CraftingRegistry.init();
    defer reg.deinit(allocator);

    try reg.registerDefaults(allocator);

    const grid: [3][3]ItemId = .{
        .{ OAK_PLANKS, 0, 0 },
        .{ OAK_PLANKS, 0, 0 },
        .{ 0, 0, 0 },
    };

    const result = reg.findMatch(grid);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(STICK, result.?.result_item);
    try std.testing.expectEqual(@as(u8, 4), result.?.result_count);
}

test "crafting table recipe matches" {
    const allocator = std.testing.allocator;
    var reg = CraftingRegistry.init();
    defer reg.deinit(allocator);

    try reg.registerDefaults(allocator);

    const grid: [3][3]ItemId = .{
        .{ OAK_PLANKS, OAK_PLANKS, 0 },
        .{ OAK_PLANKS, OAK_PLANKS, 0 },
        .{ 0, 0, 0 },
    };

    const result = reg.findMatch(grid);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(CRAFTING_TABLE, result.?.result_item);
    try std.testing.expectEqual(@as(u8, 1), result.?.result_count);
}
