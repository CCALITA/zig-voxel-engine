const std = @import("std");

pub const ShapedRecipe = struct {
    pattern: [3][3]u16,
    result_item: u16,
    result_count: u8,
};

const E: u16 = 0; // empty slot

// Item IDs
const WHEAT: u16 = 352;
const SUGAR_CANE: u16 = 344;
const EGG: u16 = 353;
const MILK: u16 = 354;
const PUMPKIN_BLOCK: u16 = 27;
const SUGAR: u16 = 355;
const COCOA: u16 = 356;
const APPLE: u16 = 357;
const GOLD_INGOT: u16 = 323;
const GOLD_NUGGET: u16 = 345;
const CARROT: u16 = 358;
const MUSHROOM_RED: u16 = 359;
const MUSHROOM_BROWN: u16 = 360;
const BOWL: u16 = 302;
const RABBIT_COOKED: u16 = 361;
const BEETROOT: u16 = 362;
const MELON_SLICE: u16 = 363;
const DRIED_KELP: u16 = 364;
const POTATO: u16 = 392;

// Result IDs
const PUMPKIN_SEEDS: u16 = 391;
const BREAD: u16 = 365;
const CAKE: u16 = 366;
const COOKIE: u16 = 367;
const PUMPKIN_PIE: u16 = 368;
const GOLDEN_APPLE: u16 = 369;
const GOLDEN_CARROT: u16 = 370;
const MUSHROOM_STEW: u16 = 371;
const RABBIT_STEW: u16 = 372;
const BEETROOT_SOUP: u16 = 373;
const SUGAR_ITEM: u16 = 355;
const MELON_BLOCK: u16 = 68;
const DRIED_KELP_BLOCK: u16 = 374;
const HAY_BALE_BLOCK: u16 = 70;

pub const recipes: [15]ShapedRecipe = .{
    // 0: Bread - ___/WWW/___
    .{ .pattern = .{ .{ E, E, E }, .{ WHEAT, WHEAT, WHEAT }, .{ E, E, E } }, .result_item = BREAD, .result_count = 1 },
    // 1: Cake - MMM/SES/WWW
    .{ .pattern = .{ .{ MILK, MILK, MILK }, .{ SUGAR, EGG, SUGAR }, .{ WHEAT, WHEAT, WHEAT } }, .result_item = CAKE, .result_count = 1 },
    // 2: Cookie - ___/WCW/___
    .{ .pattern = .{ .{ E, E, E }, .{ WHEAT, COCOA, WHEAT }, .{ E, E, E } }, .result_item = COOKIE, .result_count = 8 },
    // 3: Pumpkin pie - ___/PSE/___
    .{ .pattern = .{ .{ E, E, E }, .{ PUMPKIN_BLOCK, SUGAR, EGG }, .{ E, E, E } }, .result_item = PUMPKIN_PIE, .result_count = 1 },
    // 4: Golden apple - GGG/GAG/GGG
    .{ .pattern = .{ .{ GOLD_INGOT, GOLD_INGOT, GOLD_INGOT }, .{ GOLD_INGOT, APPLE, GOLD_INGOT }, .{ GOLD_INGOT, GOLD_INGOT, GOLD_INGOT } }, .result_item = GOLDEN_APPLE, .result_count = 1 },
    // 5: Golden carrot - GGG/GCG/GGG
    .{ .pattern = .{ .{ GOLD_NUGGET, GOLD_NUGGET, GOLD_NUGGET }, .{ GOLD_NUGGET, CARROT, GOLD_NUGGET }, .{ GOLD_NUGGET, GOLD_NUGGET, GOLD_NUGGET } }, .result_item = GOLDEN_CARROT, .result_count = 1 },
    // 6: Mushroom stew - _R_/_B_/_O_
    .{ .pattern = .{ .{ E, MUSHROOM_RED, E }, .{ E, MUSHROOM_BROWN, E }, .{ E, BOWL, E } }, .result_item = MUSHROOM_STEW, .result_count = 1 },
    // 7: Rabbit stew - _R_/CP_/_O_ (P=potato)
    .{ .pattern = .{ .{ E, RABBIT_COOKED, E }, .{ CARROT, POTATO, E }, .{ E, BOWL, E } }, .result_item = RABBIT_STEW, .result_count = 1 },
    // 8: Beetroot soup - shaped: BBB/BBB/_O_
    .{ .pattern = .{ .{ BEETROOT, BEETROOT, BEETROOT }, .{ BEETROOT, BEETROOT, BEETROOT }, .{ E, BOWL, E } }, .result_item = BEETROOT_SOUP, .result_count = 1 },
    // 9: Sugar - _S_/___/___
    .{ .pattern = .{ .{ E, SUGAR_CANE, E }, .{ E, E, E }, .{ E, E, E } }, .result_item = SUGAR_ITEM, .result_count = 1 },
    // 10: Melon block - MMM/MMM/MMM
    .{ .pattern = .{ .{ MELON_SLICE, MELON_SLICE, MELON_SLICE }, .{ MELON_SLICE, MELON_SLICE, MELON_SLICE }, .{ MELON_SLICE, MELON_SLICE, MELON_SLICE } }, .result_item = MELON_BLOCK, .result_count = 1 },
    // 11: Dried kelp block - KKK/KKK/KKK
    .{ .pattern = .{ .{ DRIED_KELP, DRIED_KELP, DRIED_KELP }, .{ DRIED_KELP, DRIED_KELP, DRIED_KELP }, .{ DRIED_KELP, DRIED_KELP, DRIED_KELP } }, .result_item = DRIED_KELP_BLOCK, .result_count = 1 },
    // 12: Hay bale - WWW/WWW/WWW
    .{ .pattern = .{ .{ WHEAT, WHEAT, WHEAT }, .{ WHEAT, WHEAT, WHEAT }, .{ WHEAT, WHEAT, WHEAT } }, .result_item = HAY_BALE_BLOCK, .result_count = 1 },
    // 13: Melon block alt - ___/MMM/MMM (6-slice variant)
    .{ .pattern = .{ .{ E, E, E }, .{ MELON_SLICE, MELON_SLICE, MELON_SLICE }, .{ MELON_SLICE, MELON_SLICE, MELON_SLICE } }, .result_item = MELON_BLOCK, .result_count = 1 },
    // 14: Pumpkin seeds - _P_/___/___
    .{ .pattern = .{ .{ E, PUMPKIN_BLOCK, E }, .{ E, E, E }, .{ E, E, E } }, .result_item = PUMPKIN_SEEDS, .result_count = 4 },
};

test "recipe count" {
    try std.testing.expectEqual(@as(usize, 15), recipes.len);
}

test "bread recipe" {
    const bread = recipes[0];
    try std.testing.expectEqual(BREAD, bread.result_item);
    try std.testing.expectEqual(@as(u8, 1), bread.result_count);
    try std.testing.expectEqual(WHEAT, bread.pattern[1][0]);
    try std.testing.expectEqual(WHEAT, bread.pattern[1][1]);
    try std.testing.expectEqual(WHEAT, bread.pattern[1][2]);
    try std.testing.expectEqual(E, bread.pattern[0][0]);
}

test "cake recipe" {
    const cake = recipes[1];
    try std.testing.expectEqual(CAKE, cake.result_item);
    try std.testing.expectEqual(MILK, cake.pattern[0][0]);
    try std.testing.expectEqual(SUGAR, cake.pattern[1][0]);
    try std.testing.expectEqual(EGG, cake.pattern[1][1]);
    try std.testing.expectEqual(WHEAT, cake.pattern[2][2]);
}

test "cookie yields 8" {
    const cookie = recipes[2];
    try std.testing.expectEqual(COOKIE, cookie.result_item);
    try std.testing.expectEqual(@as(u8, 8), cookie.result_count);
}

test "golden apple uses gold ingots" {
    const ga = recipes[4];
    try std.testing.expectEqual(GOLDEN_APPLE, ga.result_item);
    try std.testing.expectEqual(GOLD_INGOT, ga.pattern[0][0]);
    try std.testing.expectEqual(APPLE, ga.pattern[1][1]);
}

test "mushroom stew pattern" {
    const ms = recipes[6];
    try std.testing.expectEqual(MUSHROOM_STEW, ms.result_item);
    try std.testing.expectEqual(MUSHROOM_RED, ms.pattern[0][1]);
    try std.testing.expectEqual(MUSHROOM_BROWN, ms.pattern[1][1]);
    try std.testing.expectEqual(BOWL, ms.pattern[2][1]);
}

test "all recipes have nonzero result" {
    for (recipes) |r| {
        try std.testing.expect(r.result_item != 0);
        try std.testing.expect(r.result_count > 0);
    }
}
