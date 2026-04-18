/// Recipe book: an extended recipe catalogue for quick-craft.
/// Supplements the CraftingRegistry with shapeless recipes and broader
/// coverage. Recipes here are checked when the grid-based CraftingRegistry
/// finds no match, providing a fallback for simple material-to-result
/// conversions (e.g. 1 iron ingot from 9 nuggets, slabs from planks).

const std = @import("std");
const block = @import("../world/block.zig");
const inventory_mod = @import("inventory.zig");

pub const ItemId = u16;
pub const Slot = inventory_mod.Slot;

/// A shapeless recipe: requires `inputs` items in any arrangement.
/// At most 4 distinct input stacks (covers 2x2 grid and common shapeless).
pub const MAX_INPUTS: usize = 4;

pub const RecipeInput = struct {
    item: ItemId,
    count: u8,
};

pub const ShapelessRecipe = struct {
    inputs: [MAX_INPUTS]?RecipeInput = .{ null, null, null, null },
    input_count: usize = 0,
    result_item: ItemId,
    result_count: u8,
};

/// Static recipe catalogue. Add entries here to expand quick-craft coverage.
pub const recipes = [_]ShapelessRecipe{
    // Planks from log (1 log -> 4 planks, shapeless)
    makeRecipe(&.{.{ .item = block.OAK_LOG, .count = 1 }}, block.OAK_PLANKS, 4),

    // Sand + Gravel -> Concrete powder placeholder (2 sand -> 1 white_concrete)
    makeRecipe(&.{
        .{ .item = block.SAND, .count = 4 },
        .{ .item = block.GRAVEL, .count = 4 },
    }, block.WHITE_CONCRETE, 1),

    // Snow blocks from snow layers (4 snow -> 1 snow block, placeholder)
    makeRecipe(&.{.{ .item = block.SNOW, .count = 4 }}, block.ICE, 1),

    // Brick block from clay (4 clay -> 1 brick)
    makeRecipe(&.{.{ .item = block.CLAY, .count = 4 }}, block.BRICK, 1),

    // Jack-o-lantern from pumpkin (1 pumpkin -> 1 jack-o-lantern)
    makeRecipe(&.{.{ .item = block.PUMPKIN, .count = 1 }}, block.JACK_O_LANTERN, 1),

    // Hay bale from wheat crop blocks (9 wheat -> 1 hay bale, placeholder)
    makeRecipe(&.{.{ .item = block.WHEAT_CROP, .count = 9 }}, block.HAY_BALE, 1),
};

/// Check if a recipe can be crafted given inventory slots directly.
pub fn canCraftFromSlots(recipe: *const ShapelessRecipe, slots: []const Slot) bool {
    for (0..recipe.input_count) |i| {
        if (recipe.inputs[i]) |input| {
            var have: u16 = 0;
            for (slots) |slot| {
                if (slot.item == input.item and slot.count > 0) {
                    have += slot.count;
                }
            }
            if (have < input.count) return false;
        }
    }
    return true;
}

/// Consume recipe inputs from a mutable slot array.
/// Caller must verify canCraftFromSlots() first; this skips re-verification.
pub fn consumeFromSlots(recipe: *const ShapelessRecipe, slots: []Slot) void {
    for (0..recipe.input_count) |i| {
        if (recipe.inputs[i]) |input| {
            var remaining: u16 = input.count;
            for (slots) |*slot| {
                if (remaining == 0) break;
                if (slot.item == input.item and slot.count > 0) {
                    const take = @min(slot.count, @as(u8, @intCast(@min(remaining, 255))));
                    slot.count -= take;
                    if (slot.count == 0) slot.item = 0;
                    remaining -= take;
                }
            }
        }
    }
}

/// Compile-time helper to build a ShapelessRecipe.
fn makeRecipe(inputs: []const RecipeInput, result_item: ItemId, result_count: u8) ShapelessRecipe {
    var r = ShapelessRecipe{
        .result_item = result_item,
        .result_count = result_count,
    };
    for (inputs, 0..) |input, i| {
        if (i >= MAX_INPUTS) break;
        r.inputs[i] = input;
        r.input_count = i + 1;
    }
    return r;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "planks recipe exists and is craftable" {
    try std.testing.expect(recipes.len > 0);
    const planks_recipe = recipes[0];
    try std.testing.expectEqual(@as(ItemId, block.OAK_PLANKS), planks_recipe.result_item);
    try std.testing.expectEqual(@as(u8, 4), planks_recipe.result_count);
}

test "canCraftFromSlots with sufficient materials" {
    const recipe = recipes[0]; // planks from log
    const slots = [_]Slot{
        .{ .item = block.OAK_LOG, .count = 5 },
        .{ .item = 0, .count = 0 },
    };
    try std.testing.expect(canCraftFromSlots(&recipe, &slots));
}

test "canCraftFromSlots fails with insufficient materials" {
    const recipe = recipes[0]; // planks from log
    const slots = [_]Slot{
        .{ .item = block.DIRT, .count = 64 },
        .{ .item = 0, .count = 0 },
    };
    try std.testing.expect(!canCraftFromSlots(&recipe, &slots));
}

test "consumeFromSlots removes correct amounts" {
    const recipe = recipes[0]; // 1 log -> 4 planks
    var slots = [_]Slot{
        .{ .item = block.OAK_LOG, .count = 3 },
        .{ .item = block.DIRT, .count = 10 },
    };
    try std.testing.expect(canCraftFromSlots(&recipe, &slots));
    consumeFromSlots(&recipe, &slots);
    try std.testing.expectEqual(@as(u8, 2), slots[0].count); // 3 - 1 = 2
    try std.testing.expectEqual(@as(u8, 10), slots[1].count); // untouched
}

test "consumeFromSlots is a no-op when items are missing" {
    const recipe = recipes[0];
    var slots = [_]Slot{
        .{ .item = block.DIRT, .count = 64 },
    };
    try std.testing.expect(!canCraftFromSlots(&recipe, &slots));
    // consumeFromSlots should not be called without canCraftFromSlots check,
    // but verify no items match means no mutation occurs
    const before = slots[0].count;
    consumeFromSlots(&recipe, &slots);
    try std.testing.expectEqual(before, slots[0].count);
}

test "concrete recipe requires both sand and gravel" {
    // Find the concrete recipe (sand + gravel)
    var concrete_recipe: ?ShapelessRecipe = null;
    for (&recipes) |*r| {
        if (r.result_item == block.WHITE_CONCRETE) {
            concrete_recipe = r.*;
            break;
        }
    }
    try std.testing.expect(concrete_recipe != null);
    const recipe = concrete_recipe.?;
    try std.testing.expectEqual(@as(usize, 2), recipe.input_count);

    // Should fail with only sand
    const sand_only = [_]Slot{.{ .item = block.SAND, .count = 64 }};
    try std.testing.expect(!canCraftFromSlots(&recipe, &sand_only));

    // Should succeed with both
    const both = [_]Slot{
        .{ .item = block.SAND, .count = 4 },
        .{ .item = block.GRAVEL, .count = 4 },
    };
    try std.testing.expect(canCraftFromSlots(&recipe, &both));
}

test "recipe book has expected number of entries" {
    try std.testing.expect(recipes.len >= 5);
}

test "all recipes have at least one input" {
    for (&recipes) |*recipe| {
        try std.testing.expect(recipe.input_count > 0);
        try std.testing.expect(recipe.inputs[0] != null);
    }
}
