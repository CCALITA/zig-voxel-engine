const std = @import("std");

pub const RecipeType = enum { shaped, shapeless, smelting };

pub const ShapedRecipe = struct {
    pattern: [3][3]u16, // 0 = empty
    result_item: u16,
    result_count: u8,
};

pub const SmeltingRecipe = struct {
    input: u16,
    output: u16,
    xp: f32,
};

// Item ID constants (blocks use their block IDs, items start at 200)
pub const STICK: u16 = 210;
pub const WOODEN_PICKAXE: u16 = 211;
pub const STONE_PICKAXE: u16 = 212;
pub const IRON_PICKAXE: u16 = 213;
pub const DIAMOND_PICKAXE: u16 = 214;
pub const WOODEN_AXE: u16 = 215;
pub const WOODEN_SHOVEL: u16 = 216;
pub const WOODEN_SWORD: u16 = 217;
pub const STONE_AXE: u16 = 218;
pub const STONE_SHOVEL: u16 = 219;
pub const IRON_INGOT: u16 = 220;
pub const GOLD_INGOT: u16 = 221;
pub const DIAMOND: u16 = 222;
pub const COAL: u16 = 223;
pub const STONE_SWORD: u16 = 224;
pub const IRON_AXE: u16 = 225;
pub const IRON_SHOVEL: u16 = 226;
pub const IRON_SWORD: u16 = 227;
pub const DIAMOND_AXE: u16 = 228;
pub const DIAMOND_SHOVEL: u16 = 229;
pub const BUCKET: u16 = 230;
pub const BOW: u16 = 231;
pub const ARROW: u16 = 232;
pub const STRING: u16 = 233;
pub const PAPER: u16 = 234;
pub const BOOK: u16 = 235;
pub const DIAMOND_SWORD: u16 = 236;
pub const GOLD_PICKAXE: u16 = 237;
pub const GOLD_AXE: u16 = 238;
pub const GOLD_SHOVEL: u16 = 239;
pub const GOLD_SWORD: u16 = 240;
pub const LEATHER: u16 = 241;
pub const FLINT: u16 = 242;
pub const FEATHER: u16 = 243;
pub const IRON_HELMET: u16 = 250;
pub const IRON_CHESTPLATE: u16 = 251;
pub const IRON_LEGGINGS: u16 = 252;
pub const IRON_BOOTS: u16 = 253;
pub const DIAMOND_HELMET: u16 = 254;
pub const DIAMOND_CHESTPLATE: u16 = 255;
pub const DIAMOND_LEGGINGS: u16 = 256;
pub const DIAMOND_BOOTS: u16 = 257;
pub const SUGAR_CANE: u16 = 258;
pub const BRICK_ITEM: u16 = 259;
pub const CHARCOAL: u16 = 260;

// Block IDs used in recipes
const PLANKS: u16 = 5;
const COBBLE: u16 = 4;
const STONE: u16 = 1;
const LOG: u16 = 8;
const IRON_ORE: u16 = 13;
const GOLD_ORE: u16 = 14;
const SAND: u16 = 6;
const GLASS: u16 = 17;
const WOOL: u16 = 16;
const CLAY_BLOCK: u16 = 60;
const STONE_BRICKS: u16 = 61;
const BRICK_BLOCK: u16 = 62;
const SANDSTONE: u16 = 63;
const SNOW_BLOCK: u16 = 64;
const TORCH: u16 = 30;
const LADDER: u16 = 31;
const FENCE: u16 = 32;
const GLASS_PANE: u16 = 33;
const IRON_BARS: u16 = 34;
const STONE_SLAB: u16 = 35;
const BOOKSHELF: u16 = 36;
const TNT: u16 = 37;
const GUNPOWDER: u16 = 200;
const REDSTONE: u16 = 201;
const BED: u16 = 38;
const CRAFTING_TABLE: u16 = 3;
const FURNACE: u16 = 39;
const CHEST: u16 = 43;
const DOOR: u16 = 44;
const SIGN: u16 = 45;
const BOAT: u16 = 46;
const RAIL: u16 = 47;
const PISTON: u16 = 48;
const SLAB: u16 = 49;
const STAIRS: u16 = 50;
const WOODEN_PRESSURE_PLATE: u16 = 51;
const STONE_PRESSURE_PLATE: u16 = 52;
const LEVER: u16 = 53;
const BUTTON: u16 = 54;
const JUKEBOX: u16 = 55;
const NOTE_BLOCK: u16 = 56;
const DISPENSER: u16 = 57;
const SNOW_LAYER: u16 = 58;
const SNOWBALL: u16 = 202;

pub const shaped_recipes = [_]ShapedRecipe{
    // === Basic Materials ===
    // 1. Planks from log
    .{ .pattern = .{ .{ LOG, 0, 0 }, .{ 0, 0, 0 }, .{ 0, 0, 0 } }, .result_item = PLANKS, .result_count = 4 },
    // 2. Sticks from planks
    .{ .pattern = .{ .{ PLANKS, 0, 0 }, .{ PLANKS, 0, 0 }, .{ 0, 0, 0 } }, .result_item = STICK, .result_count = 4 },
    // 3. Torches
    .{ .pattern = .{ .{ COAL, 0, 0 }, .{ STICK, 0, 0 }, .{ 0, 0, 0 } }, .result_item = TORCH, .result_count = 4 },

    // === Workstations ===
    // 4. Crafting table
    .{ .pattern = .{ .{ PLANKS, PLANKS, 0 }, .{ PLANKS, PLANKS, 0 }, .{ 0, 0, 0 } }, .result_item = CRAFTING_TABLE, .result_count = 1 },
    // 5. Furnace
    .{ .pattern = .{ .{ COBBLE, COBBLE, COBBLE }, .{ COBBLE, 0, COBBLE }, .{ COBBLE, COBBLE, COBBLE } }, .result_item = FURNACE, .result_count = 1 },
    // 6. Chest
    .{ .pattern = .{ .{ PLANKS, PLANKS, PLANKS }, .{ PLANKS, 0, PLANKS }, .{ PLANKS, PLANKS, PLANKS } }, .result_item = CHEST, .result_count = 1 },

    // === Wooden Tools ===
    // 7. Wooden pickaxe
    .{ .pattern = .{ .{ PLANKS, PLANKS, PLANKS }, .{ 0, STICK, 0 }, .{ 0, STICK, 0 } }, .result_item = WOODEN_PICKAXE, .result_count = 1 },
    // 8. Wooden axe
    .{ .pattern = .{ .{ PLANKS, PLANKS, 0 }, .{ PLANKS, STICK, 0 }, .{ 0, STICK, 0 } }, .result_item = WOODEN_AXE, .result_count = 1 },
    // 9. Wooden shovel
    .{ .pattern = .{ .{ PLANKS, 0, 0 }, .{ STICK, 0, 0 }, .{ STICK, 0, 0 } }, .result_item = WOODEN_SHOVEL, .result_count = 1 },
    // 10. Wooden sword
    .{ .pattern = .{ .{ PLANKS, 0, 0 }, .{ PLANKS, 0, 0 }, .{ STICK, 0, 0 } }, .result_item = WOODEN_SWORD, .result_count = 1 },

    // === Stone Tools ===
    // 11. Stone pickaxe
    .{ .pattern = .{ .{ COBBLE, COBBLE, COBBLE }, .{ 0, STICK, 0 }, .{ 0, STICK, 0 } }, .result_item = STONE_PICKAXE, .result_count = 1 },
    // 12. Stone axe
    .{ .pattern = .{ .{ COBBLE, COBBLE, 0 }, .{ COBBLE, STICK, 0 }, .{ 0, STICK, 0 } }, .result_item = STONE_AXE, .result_count = 1 },
    // 13. Stone shovel
    .{ .pattern = .{ .{ COBBLE, 0, 0 }, .{ STICK, 0, 0 }, .{ STICK, 0, 0 } }, .result_item = STONE_SHOVEL, .result_count = 1 },
    // 14. Stone sword
    .{ .pattern = .{ .{ COBBLE, 0, 0 }, .{ COBBLE, 0, 0 }, .{ STICK, 0, 0 } }, .result_item = STONE_SWORD, .result_count = 1 },

    // === Iron Tools ===
    // 15. Iron pickaxe
    .{ .pattern = .{ .{ IRON_INGOT, IRON_INGOT, IRON_INGOT }, .{ 0, STICK, 0 }, .{ 0, STICK, 0 } }, .result_item = IRON_PICKAXE, .result_count = 1 },
    // 16. Iron axe
    .{ .pattern = .{ .{ IRON_INGOT, IRON_INGOT, 0 }, .{ IRON_INGOT, STICK, 0 }, .{ 0, STICK, 0 } }, .result_item = IRON_AXE, .result_count = 1 },
    // 17. Iron shovel
    .{ .pattern = .{ .{ IRON_INGOT, 0, 0 }, .{ STICK, 0, 0 }, .{ STICK, 0, 0 } }, .result_item = IRON_SHOVEL, .result_count = 1 },
    // 18. Iron sword
    .{ .pattern = .{ .{ IRON_INGOT, 0, 0 }, .{ IRON_INGOT, 0, 0 }, .{ STICK, 0, 0 } }, .result_item = IRON_SWORD, .result_count = 1 },

    // === Diamond Tools ===
    // 19. Diamond pickaxe
    .{ .pattern = .{ .{ DIAMOND, DIAMOND, DIAMOND }, .{ 0, STICK, 0 }, .{ 0, STICK, 0 } }, .result_item = DIAMOND_PICKAXE, .result_count = 1 },
    // 20. Diamond axe
    .{ .pattern = .{ .{ DIAMOND, DIAMOND, 0 }, .{ DIAMOND, STICK, 0 }, .{ 0, STICK, 0 } }, .result_item = DIAMOND_AXE, .result_count = 1 },
    // 21. Diamond shovel
    .{ .pattern = .{ .{ DIAMOND, 0, 0 }, .{ STICK, 0, 0 }, .{ STICK, 0, 0 } }, .result_item = DIAMOND_SHOVEL, .result_count = 1 },
    // 22. Diamond sword
    .{ .pattern = .{ .{ DIAMOND, 0, 0 }, .{ DIAMOND, 0, 0 }, .{ STICK, 0, 0 } }, .result_item = DIAMOND_SWORD, .result_count = 1 },

    // === Gold Tools ===
    // 23. Gold pickaxe
    .{ .pattern = .{ .{ GOLD_INGOT, GOLD_INGOT, GOLD_INGOT }, .{ 0, STICK, 0 }, .{ 0, STICK, 0 } }, .result_item = GOLD_PICKAXE, .result_count = 1 },
    // 24. Gold axe
    .{ .pattern = .{ .{ GOLD_INGOT, GOLD_INGOT, 0 }, .{ GOLD_INGOT, STICK, 0 }, .{ 0, STICK, 0 } }, .result_item = GOLD_AXE, .result_count = 1 },
    // 25. Gold shovel
    .{ .pattern = .{ .{ GOLD_INGOT, 0, 0 }, .{ STICK, 0, 0 }, .{ STICK, 0, 0 } }, .result_item = GOLD_SHOVEL, .result_count = 1 },
    // 26. Gold sword
    .{ .pattern = .{ .{ GOLD_INGOT, 0, 0 }, .{ GOLD_INGOT, 0, 0 }, .{ STICK, 0, 0 } }, .result_item = GOLD_SWORD, .result_count = 1 },

    // === Iron Armor ===
    // 27. Iron helmet
    .{ .pattern = .{ .{ IRON_INGOT, IRON_INGOT, IRON_INGOT }, .{ IRON_INGOT, 0, IRON_INGOT }, .{ 0, 0, 0 } }, .result_item = IRON_HELMET, .result_count = 1 },
    // 28. Iron chestplate
    .{ .pattern = .{ .{ IRON_INGOT, 0, IRON_INGOT }, .{ IRON_INGOT, IRON_INGOT, IRON_INGOT }, .{ IRON_INGOT, IRON_INGOT, IRON_INGOT } }, .result_item = IRON_CHESTPLATE, .result_count = 1 },
    // 29. Iron leggings
    .{ .pattern = .{ .{ IRON_INGOT, IRON_INGOT, IRON_INGOT }, .{ IRON_INGOT, 0, IRON_INGOT }, .{ IRON_INGOT, 0, IRON_INGOT } }, .result_item = IRON_LEGGINGS, .result_count = 1 },
    // 30. Iron boots
    .{ .pattern = .{ .{ IRON_INGOT, 0, IRON_INGOT }, .{ IRON_INGOT, 0, IRON_INGOT }, .{ 0, 0, 0 } }, .result_item = IRON_BOOTS, .result_count = 1 },

    // === Diamond Armor ===
    // 31. Diamond helmet
    .{ .pattern = .{ .{ DIAMOND, DIAMOND, DIAMOND }, .{ DIAMOND, 0, DIAMOND }, .{ 0, 0, 0 } }, .result_item = DIAMOND_HELMET, .result_count = 1 },
    // 32. Diamond chestplate
    .{ .pattern = .{ .{ DIAMOND, 0, DIAMOND }, .{ DIAMOND, DIAMOND, DIAMOND }, .{ DIAMOND, DIAMOND, DIAMOND } }, .result_item = DIAMOND_CHESTPLATE, .result_count = 1 },
    // 33. Diamond leggings
    .{ .pattern = .{ .{ DIAMOND, DIAMOND, DIAMOND }, .{ DIAMOND, 0, DIAMOND }, .{ DIAMOND, 0, DIAMOND } }, .result_item = DIAMOND_LEGGINGS, .result_count = 1 },
    // 34. Diamond boots
    .{ .pattern = .{ .{ DIAMOND, 0, DIAMOND }, .{ DIAMOND, 0, DIAMOND }, .{ 0, 0, 0 } }, .result_item = DIAMOND_BOOTS, .result_count = 1 },

    // === Ranged Weapons ===
    // 35. Bow
    .{ .pattern = .{ .{ 0, STICK, STRING }, .{ STICK, 0, STRING }, .{ 0, STICK, STRING } }, .result_item = BOW, .result_count = 1 },
    // 36. Arrow
    .{ .pattern = .{ .{ FLINT, 0, 0 }, .{ STICK, 0, 0 }, .{ FEATHER, 0, 0 } }, .result_item = ARROW, .result_count = 4 },

    // === Utility Items ===
    // 37. Bucket
    .{ .pattern = .{ .{ IRON_INGOT, 0, IRON_INGOT }, .{ 0, IRON_INGOT, 0 }, .{ 0, 0, 0 } }, .result_item = BUCKET, .result_count = 1 },
    // 38. Paper
    .{ .pattern = .{ .{ SUGAR_CANE, SUGAR_CANE, SUGAR_CANE }, .{ 0, 0, 0 }, .{ 0, 0, 0 } }, .result_item = PAPER, .result_count = 3 },
    // 39. Book
    .{ .pattern = .{ .{ PAPER, 0, 0 }, .{ PAPER, 0, 0 }, .{ PAPER, LEATHER, 0 } }, .result_item = BOOK, .result_count = 1 },
    // 40. Bookshelf
    .{ .pattern = .{ .{ PLANKS, PLANKS, PLANKS }, .{ BOOK, BOOK, BOOK }, .{ PLANKS, PLANKS, PLANKS } }, .result_item = BOOKSHELF, .result_count = 1 },

    // === Building Blocks ===
    // 41. Sandstone
    .{ .pattern = .{ .{ SAND, SAND, 0 }, .{ SAND, SAND, 0 }, .{ 0, 0, 0 } }, .result_item = SANDSTONE, .result_count = 1 },
    // 42. Stone bricks
    .{ .pattern = .{ .{ STONE, STONE, 0 }, .{ STONE, STONE, 0 }, .{ 0, 0, 0 } }, .result_item = STONE_BRICKS, .result_count = 4 },
    // 43. Snow block
    .{ .pattern = .{ .{ SNOWBALL, SNOWBALL, 0 }, .{ SNOWBALL, SNOWBALL, 0 }, .{ 0, 0, 0 } }, .result_item = SNOW_BLOCK, .result_count = 1 },

    // === Decorative / Functional Blocks ===
    // 44. Glass pane
    .{ .pattern = .{ .{ GLASS, GLASS, GLASS }, .{ GLASS, GLASS, GLASS }, .{ 0, 0, 0 } }, .result_item = GLASS_PANE, .result_count = 16 },
    // 45. Iron bars
    .{ .pattern = .{ .{ IRON_INGOT, IRON_INGOT, IRON_INGOT }, .{ IRON_INGOT, IRON_INGOT, IRON_INGOT }, .{ 0, 0, 0 } }, .result_item = IRON_BARS, .result_count = 16 },
    // 46. Ladder
    .{ .pattern = .{ .{ STICK, 0, STICK }, .{ STICK, STICK, STICK }, .{ STICK, 0, STICK } }, .result_item = LADDER, .result_count = 3 },
    // 47. Fence
    .{ .pattern = .{ .{ PLANKS, STICK, PLANKS }, .{ PLANKS, STICK, PLANKS }, .{ 0, 0, 0 } }, .result_item = FENCE, .result_count = 3 },

    // === Redstone / Mechanisms ===
    // 48. TNT
    .{ .pattern = .{ .{ GUNPOWDER, SAND, GUNPOWDER }, .{ SAND, GUNPOWDER, SAND }, .{ GUNPOWDER, SAND, GUNPOWDER } }, .result_item = TNT, .result_count = 1 },
    // 49. Lever
    .{ .pattern = .{ .{ STICK, 0, 0 }, .{ COBBLE, 0, 0 }, .{ 0, 0, 0 } }, .result_item = LEVER, .result_count = 1 },
    // 50. Stone button
    .{ .pattern = .{ .{ STONE, 0, 0 }, .{ 0, 0, 0 }, .{ 0, 0, 0 } }, .result_item = BUTTON, .result_count = 1 },
    // 51. Stone pressure plate
    .{ .pattern = .{ .{ STONE, STONE, 0 }, .{ 0, 0, 0 }, .{ 0, 0, 0 } }, .result_item = STONE_PRESSURE_PLATE, .result_count = 1 },
    // 52. Wooden pressure plate
    .{ .pattern = .{ .{ PLANKS, PLANKS, 0 }, .{ 0, 0, 0 }, .{ 0, 0, 0 } }, .result_item = WOODEN_PRESSURE_PLATE, .result_count = 1 },
};

pub const smelting_recipes = [_]SmeltingRecipe{
    .{ .input = IRON_ORE, .output = IRON_INGOT, .xp = 0.7 },
    .{ .input = GOLD_ORE, .output = GOLD_INGOT, .xp = 1.0 },
    .{ .input = SAND, .output = GLASS, .xp = 0.1 },
    .{ .input = COBBLE, .output = STONE, .xp = 0.1 },
    .{ .input = LOG, .output = CHARCOAL, .xp = 0.15 },
    .{ .input = CLAY_BLOCK, .output = BRICK_ITEM, .xp = 0.3 },
};

pub fn findShaped(grid: [3][3]u16) ?ShapedRecipe {
    for (shaped_recipes) |recipe| {
        if (matchesPattern(grid, recipe.pattern)) return recipe;
    }
    return null;
}

fn matchesPattern(grid: [3][3]u16, pattern: [3][3]u16) bool {
    for (0..3) |y| {
        for (0..3) |x| {
            if (grid[y][x] != pattern[y][x]) return false;
        }
    }
    return true;
}

pub fn findSmelting(input: u16) ?SmeltingRecipe {
    for (smelting_recipes) |recipe| {
        if (recipe.input == input) return recipe;
    }
    return null;
}

test "find planks recipe" {
    const grid = [3][3]u16{ .{ LOG, 0, 0 }, .{ 0, 0, 0 }, .{ 0, 0, 0 } };
    const result = findShaped(grid);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(u16, PLANKS), result.?.result_item);
    try std.testing.expectEqual(@as(u8, 4), result.?.result_count);
}

test "find wooden pickaxe recipe" {
    const grid = [3][3]u16{ .{ PLANKS, PLANKS, PLANKS }, .{ 0, STICK, 0 }, .{ 0, STICK, 0 } };
    const result = findShaped(grid);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(WOODEN_PICKAXE, result.?.result_item);
}

test "find diamond sword recipe" {
    const grid = [3][3]u16{ .{ DIAMOND, 0, 0 }, .{ DIAMOND, 0, 0 }, .{ STICK, 0, 0 } };
    const result = findShaped(grid);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(DIAMOND_SWORD, result.?.result_item);
}

test "find iron smelting" {
    const result = findSmelting(IRON_ORE);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(IRON_INGOT, result.?.output);
}

test "find gold smelting" {
    const result = findSmelting(GOLD_ORE);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(GOLD_INGOT, result.?.output);
}

test "no match returns null" {
    const grid = [3][3]u16{ .{ 99, 99, 99 }, .{ 99, 99, 99 }, .{ 99, 99, 99 } };
    try std.testing.expect(findShaped(grid) == null);
}

test "no smelting match returns null" {
    try std.testing.expect(findSmelting(999) == null);
}

test "recipe count at least 50 shaped" {
    try std.testing.expect(shaped_recipes.len >= 50);
}

test "smelting recipe count" {
    try std.testing.expect(smelting_recipes.len >= 5);
}
