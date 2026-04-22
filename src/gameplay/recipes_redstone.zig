/// Redstone component crafting recipes.
/// Each recipe is a 3×3 grid of item IDs (0 = empty cell) that produces a redstone component.

const std = @import("std");

pub const ShapedRecipe = struct {
    pattern: [3][3]u16,
    result_item: u16,
    result_count: u8,
};

// Item / material IDs
const E: u16 = 0; // empty
const STONE: u16 = 1;
const COBBLE: u16 = 4;
const PLANKS: u16 = 5;
const SAND: u16 = 6;
const IRON_INGOT: u16 = 322;
const REDSTONE_DUST: u16 = 330;
const QUARTZ: u16 = 331;
const STICK: u16 = 256;
const STRING: u16 = 315;
const GUNPOWDER: u16 = 317;
const SLIME_BALL: u16 = 332;
const BOW_ITEM: u16 = 333;
const REDSTONE_TORCH: u16 = 34;
const CHEST: u16 = 43;
const PISTON: u16 = 37;
const GLASS: u16 = 17;
const SLAB: u16 = 44;

// Result block IDs
const REPEATER: u16 = 38;
const COMPARATOR: u16 = 335;
const STICKY_PISTON: u16 = 52;
const OBSERVER: u16 = 336;
const HOPPER: u16 = 54;
const DROPPER: u16 = 55;
const DISPENSER: u16 = 56;
const TNT: u16 = 20;
const LEVER: u16 = 35;
const BUTTON: u16 = 36;
const TRIPWIRE_HOOK: u16 = 337;
const DAYLIGHT_DETECTOR: u16 = 338;
const NOTE_BLOCK: u16 = 50;

fn p(row0: [3]u16, row1: [3]u16, row2: [3]u16) [3][3]u16 {
    return .{ row0, row1, row2 };
}

pub const recipes: [15]ShapedRecipe = .{
    // Repeater: ___/TRT/SSS  (T=redstone torch, R=redstone, S=stone)
    .{ .pattern = p(.{ E, E, E }, .{ REDSTONE_TORCH, REDSTONE_DUST, REDSTONE_TORCH }, .{ STONE, STONE, STONE }), .result_item = REPEATER, .result_count = 1 },
    // Comparator: _T_/TQT/SSS
    .{ .pattern = p(.{ E, REDSTONE_TORCH, E }, .{ REDSTONE_TORCH, QUARTZ, REDSTONE_TORCH }, .{ STONE, STONE, STONE }), .result_item = COMPARATOR, .result_count = 1 },
    // Piston: PPP/CIC/CRC
    .{ .pattern = p(.{ PLANKS, PLANKS, PLANKS }, .{ COBBLE, IRON_INGOT, COBBLE }, .{ COBBLE, REDSTONE_DUST, COBBLE }), .result_item = PISTON, .result_count = 1 },
    // Sticky piston: L__/T__/___
    .{ .pattern = p(.{ SLIME_BALL, E, E }, .{ PISTON, E, E }, .{ E, E, E }), .result_item = STICKY_PISTON, .result_count = 1 },
    // Observer: CCC/RRQ/CCC
    .{ .pattern = p(.{ COBBLE, COBBLE, COBBLE }, .{ REDSTONE_DUST, REDSTONE_DUST, QUARTZ }, .{ COBBLE, COBBLE, COBBLE }), .result_item = OBSERVER, .result_count = 1 },
    // Hopper: I_I/ICI/_I_
    .{ .pattern = p(.{ IRON_INGOT, E, IRON_INGOT }, .{ IRON_INGOT, CHEST, IRON_INGOT }, .{ E, IRON_INGOT, E }), .result_item = HOPPER, .result_count = 1 },
    // Dropper: CCC/C_C/CRC
    .{ .pattern = p(.{ COBBLE, COBBLE, COBBLE }, .{ COBBLE, E, COBBLE }, .{ COBBLE, REDSTONE_DUST, COBBLE }), .result_item = DROPPER, .result_count = 1 },
    // Dispenser: CCC/CBC/CRC
    .{ .pattern = p(.{ COBBLE, COBBLE, COBBLE }, .{ COBBLE, BOW_ITEM, COBBLE }, .{ COBBLE, REDSTONE_DUST, COBBLE }), .result_item = DISPENSER, .result_count = 1 },
    // TNT: GSG/SGS/GSG
    .{ .pattern = p(.{ GUNPOWDER, SAND, GUNPOWDER }, .{ SAND, GUNPOWDER, SAND }, .{ GUNPOWDER, SAND, GUNPOWDER }), .result_item = TNT, .result_count = 1 },
    // Lever: _S_/_C_/___
    .{ .pattern = p(.{ E, STICK, E }, .{ E, COBBLE, E }, .{ E, E, E }), .result_item = LEVER, .result_count = 1 },
    // Button: _S_/___/___
    .{ .pattern = p(.{ E, STONE, E }, .{ E, E, E }, .{ E, E, E }), .result_item = BUTTON, .result_count = 1 },
    // Redstone torch: _R_/_S_/___
    .{ .pattern = p(.{ E, REDSTONE_DUST, E }, .{ E, STICK, E }, .{ E, E, E }), .result_item = REDSTONE_TORCH, .result_count = 1 },
    // Tripwire hook: _I_/_S_/_P_
    .{ .pattern = p(.{ E, IRON_INGOT, E }, .{ E, STICK, E }, .{ E, PLANKS, E }), .result_item = TRIPWIRE_HOOK, .result_count = 2 },
    // Daylight detector: GGG/QQQ/SSS  (G=glass, Q=quartz, S=slab)
    .{ .pattern = p(.{ GLASS, GLASS, GLASS }, .{ QUARTZ, QUARTZ, QUARTZ }, .{ SLAB, SLAB, SLAB }), .result_item = DAYLIGHT_DETECTOR, .result_count = 1 },
    // Note block: PPP/PRP/PPP
    .{ .pattern = p(.{ PLANKS, PLANKS, PLANKS }, .{ PLANKS, REDSTONE_DUST, PLANKS }, .{ PLANKS, PLANKS, PLANKS }), .result_item = NOTE_BLOCK, .result_count = 1 },
};

test "recipe count" {
    try std.testing.expectEqual(@as(usize, 15), recipes.len);
}

test "repeater recipe has correct result" {
    const repeater = recipes[0];
    try std.testing.expectEqual(REPEATER, repeater.result_item);
    try std.testing.expectEqual(@as(u8, 1), repeater.result_count);
}

test "repeater pattern top row is empty" {
    const row = recipes[0].pattern[0];
    try std.testing.expectEqual([3]u16{ E, E, E }, row);
}

test "piston recipe pattern" {
    const piston_recipe = recipes[2];
    try std.testing.expectEqual(PISTON, piston_recipe.result_item);
    try std.testing.expectEqual([3]u16{ PLANKS, PLANKS, PLANKS }, piston_recipe.pattern[0]);
    try std.testing.expectEqual([3]u16{ COBBLE, IRON_INGOT, COBBLE }, piston_recipe.pattern[1]);
    try std.testing.expectEqual([3]u16{ COBBLE, REDSTONE_DUST, COBBLE }, piston_recipe.pattern[2]);
}

test "tnt recipe checkerboard pattern" {
    const tnt = recipes[8];
    try std.testing.expectEqual(TNT, tnt.result_item);
    try std.testing.expectEqual(GUNPOWDER, tnt.pattern[0][0]);
    try std.testing.expectEqual(SAND, tnt.pattern[0][1]);
    try std.testing.expectEqual(SAND, tnt.pattern[1][2]);
}

test "sticky piston uses piston and slime" {
    const sp = recipes[3];
    try std.testing.expectEqual(STICKY_PISTON, sp.result_item);
    try std.testing.expectEqual(SLIME_BALL, sp.pattern[0][0]);
    try std.testing.expectEqual(PISTON, sp.pattern[1][0]);
}

test "note block surrounds redstone with planks" {
    const nb = recipes[14];
    try std.testing.expectEqual(NOTE_BLOCK, nb.result_item);
    try std.testing.expectEqual(REDSTONE_DUST, nb.pattern[1][1]);
    try std.testing.expectEqual(PLANKS, nb.pattern[0][0]);
    try std.testing.expectEqual(PLANKS, nb.pattern[2][2]);
}

test "tripwire hook produces 2" {
    const th = recipes[12];
    try std.testing.expectEqual(TRIPWIRE_HOOK, th.result_item);
    try std.testing.expectEqual(@as(u8, 2), th.result_count);
}

test "all recipes have non-zero result item" {
    for (recipes) |recipe| {
        try std.testing.expect(recipe.result_item != 0);
        try std.testing.expect(recipe.result_count > 0);
    }
}

test "no duplicate result items" {
    for (0..recipes.len) |i| {
        for (i + 1..recipes.len) |j| {
            try std.testing.expect(recipes[i].result_item != recipes[j].result_item);
        }
    }
}

test "hopper uses 5 iron ingots" {
    const h = recipes[5];
    try std.testing.expectEqual(HOPPER, h.result_item);
    var iron_count: u8 = 0;
    for (h.pattern) |row| {
        for (row) |cell| {
            if (cell == IRON_INGOT) iron_count += 1;
        }
    }
    try std.testing.expectEqual(@as(u8, 5), iron_count);
}
