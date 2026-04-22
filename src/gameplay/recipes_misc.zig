/// Miscellaneous / niche crafting recipes that do not fit into tools, armor,
/// food, transport, redstone, or decorative categories.
/// Includes items such as the recovery compass, spyglass, lightning rod,
/// candle, brush, chains, nether-brick conversion, and flower pot.

const std = @import("std");

pub const ShapedRecipe = struct {
    pattern: [3][3]u16,
    result_item: u16,
    result_count: u8,
};

// ── Empty shorthand ──────────────────────────────────────────────────
const E: u16 = 0;

// ── Ingredient IDs ───────────────────────────────────────────────────
const BOWL: u16 = 302;
const MUSHROOM_RED: u16 = 359;
const MUSHROOM_BROWN: u16 = 360;
const FLOWER_DANDELION: u16 = 580;
const FLOWER_POPPY: u16 = 581;
const ARROW: u16 = 314;
const GLOWSTONE_DUST: u16 = 383;
const STRING: u16 = 315;
const HONEYCOMB: u16 = 584;
const FEATHER: u16 = 316;
const COPPER_INGOT: u16 = 586;
const STICK: u16 = 256;
const ECHO_SHARD: u16 = 588;
const COMPASS: u16 = 304;
const AMETHYST_SHARD: u16 = 590;
const IRON_NUGGET: u16 = 345;
const IRON_INGOT: u16 = 322;
const NETHER_BRICK_ITEM: u16 = 342;
const BRICK_ITEM: u16 = 341;
const OAK_PLANKS: u16 = 5;
const REDSTONE_DUST: u16 = 331;

// ── Result IDs ───────────────────────────────────────────────────────
const SUSPICIOUS_STEW: u16 = 582;
const SPECTRAL_ARROW: u16 = 583;
const CANDLE: u16 = 585;
const BRUSH: u16 = 587;
const RECOVERY_COMPASS: u16 = 589;
const SPYGLASS: u16 = 350;
const LIGHTNING_ROD: u16 = 591;
const CHAIN: u16 = 351;
const NETHER_BRICKS_BLOCK: u16 = 592;
const FLOWER_POT: u16 = 593;

// ── Recipes ──────────────────────────────────────────────────────────

pub const recipes = [_]ShapedRecipe{
    // 1. Suspicious stew — red mushroom, brown mushroom, flower, bowl
    .{
        .pattern = .{
            .{ MUSHROOM_RED, E, E },
            .{ MUSHROOM_BROWN, E, E },
            .{ FLOWER_DANDELION, BOWL, E },
        },
        .result_item = SUSPICIOUS_STEW,
        .result_count = 1,
    },
    // 2. Suspicious stew (poppy variant)
    .{
        .pattern = .{
            .{ MUSHROOM_RED, E, E },
            .{ MUSHROOM_BROWN, E, E },
            .{ FLOWER_POPPY, BOWL, E },
        },
        .result_item = SUSPICIOUS_STEW,
        .result_count = 1,
    },
    // 3. Spectral arrow — 4 glowstone dust around an arrow
    .{
        .pattern = .{
            .{ E, GLOWSTONE_DUST, E },
            .{ GLOWSTONE_DUST, ARROW, GLOWSTONE_DUST },
            .{ E, GLOWSTONE_DUST, E },
        },
        .result_item = SPECTRAL_ARROW,
        .result_count = 2,
    },
    // 4. Candle — string over honeycomb
    .{
        .pattern = .{
            .{ STRING, E, E },
            .{ HONEYCOMB, E, E },
            .{ E, E, E },
        },
        .result_item = CANDLE,
        .result_count = 1,
    },
    // 5. Brush — feather, copper ingot, stick vertical
    .{
        .pattern = .{
            .{ FEATHER, E, E },
            .{ COPPER_INGOT, E, E },
            .{ STICK, E, E },
        },
        .result_item = BRUSH,
        .result_count = 1,
    },
    // 6. Recovery compass — 8 echo shards surrounding a compass
    .{
        .pattern = .{
            .{ ECHO_SHARD, ECHO_SHARD, ECHO_SHARD },
            .{ ECHO_SHARD, COMPASS, ECHO_SHARD },
            .{ ECHO_SHARD, ECHO_SHARD, ECHO_SHARD },
        },
        .result_item = RECOVERY_COMPASS,
        .result_count = 1,
    },
    // 7. Spyglass — amethyst shard over 2 copper ingots
    .{
        .pattern = .{
            .{ AMETHYST_SHARD, E, E },
            .{ COPPER_INGOT, E, E },
            .{ COPPER_INGOT, E, E },
        },
        .result_item = SPYGLASS,
        .result_count = 1,
    },
    // 8. Lightning rod — 3 copper ingots vertical
    .{
        .pattern = .{
            .{ COPPER_INGOT, E, E },
            .{ COPPER_INGOT, E, E },
            .{ COPPER_INGOT, E, E },
        },
        .result_item = LIGHTNING_ROD,
        .result_count = 1,
    },
    // 9. Chain — iron nugget, iron ingot, iron nugget vertical
    .{
        .pattern = .{
            .{ IRON_NUGGET, E, E },
            .{ IRON_INGOT, E, E },
            .{ IRON_NUGGET, E, E },
        },
        .result_item = CHAIN,
        .result_count = 1,
    },
    // 10. Iron nuggets from ingot — single ingot yields 9 nuggets
    .{
        .pattern = .{
            .{ IRON_INGOT, E, E },
            .{ E, E, E },
            .{ E, E, E },
        },
        .result_item = IRON_NUGGET,
        .result_count = 9,
    },
    // 11. Iron ingot from nuggets — 3x3 nuggets yields 1 ingot
    .{
        .pattern = .{
            .{ IRON_NUGGET, IRON_NUGGET, IRON_NUGGET },
            .{ IRON_NUGGET, IRON_NUGGET, IRON_NUGGET },
            .{ IRON_NUGGET, IRON_NUGGET, IRON_NUGGET },
        },
        .result_item = IRON_INGOT,
        .result_count = 1,
    },
    // 12. Nether bricks block — 2x2 nether brick items
    .{
        .pattern = .{
            .{ NETHER_BRICK_ITEM, NETHER_BRICK_ITEM, E },
            .{ NETHER_BRICK_ITEM, NETHER_BRICK_ITEM, E },
            .{ E, E, E },
        },
        .result_item = NETHER_BRICKS_BLOCK,
        .result_count = 1,
    },
    // 13. Flower pot — 3 brick items in a V shape
    .{
        .pattern = .{
            .{ E, E, E },
            .{ BRICK_ITEM, E, BRICK_ITEM },
            .{ E, BRICK_ITEM, E },
        },
        .result_item = FLOWER_POT,
        .result_count = 1,
    },
    // 14. Bowl — 3 planks in a V shape
    .{
        .pattern = .{
            .{ E, E, E },
            .{ OAK_PLANKS, E, OAK_PLANKS },
            .{ E, OAK_PLANKS, E },
        },
        .result_item = BOWL,
        .result_count = 4,
    },
    // 15. Compass — 4 iron ingots around redstone dust (331)
    .{
        .pattern = .{
            .{ E, IRON_INGOT, E },
            .{ IRON_INGOT, REDSTONE_DUST, IRON_INGOT },
            .{ E, IRON_INGOT, E },
        },
        .result_item = COMPASS,
        .result_count = 1,
    },
};

// ── Lookup helper ────────────────────────────────────────────────────

/// Return the recipe that produces `item`, or null if none exists.
pub fn findByResult(item: u16) ?ShapedRecipe {
    for (recipes) |r| {
        if (r.result_item == item) return r;
    }
    return null;
}

// ── Tests ────────────────────────────────────────────────────────────

const testing = std.testing;

test "recipe count is 15" {
    try testing.expectEqual(@as(usize, 15), recipes.len);
}

test "spectral arrow yields 2 and has correct center" {
    const r = recipes[2];
    try testing.expectEqual(SPECTRAL_ARROW, r.result_item);
    try testing.expectEqual(@as(u8, 2), r.result_count);
    // Center cell must be the arrow
    try testing.expectEqual(ARROW, r.pattern[1][1]);
    // All four cardinal neighbours must be glowstone dust
    try testing.expectEqual(GLOWSTONE_DUST, r.pattern[0][1]);
    try testing.expectEqual(GLOWSTONE_DUST, r.pattern[1][0]);
    try testing.expectEqual(GLOWSTONE_DUST, r.pattern[1][2]);
    try testing.expectEqual(GLOWSTONE_DUST, r.pattern[2][1]);
}

test "recovery compass uses 8 echo shards around a compass" {
    const r = recipes[5];
    try testing.expectEqual(RECOVERY_COMPASS, r.result_item);
    try testing.expectEqual(COMPASS, r.pattern[1][1]);
    // Every non-center cell must be an echo shard
    for (0..3) |row| {
        for (0..3) |col| {
            if (row == 1 and col == 1) continue;
            try testing.expectEqual(ECHO_SHARD, r.pattern[row][col]);
        }
    }
}

test "iron nugget decomposition yields 9" {
    const r = recipes[9];
    try testing.expectEqual(IRON_NUGGET, r.result_item);
    try testing.expectEqual(@as(u8, 9), r.result_count);
    // Only the top-left cell is filled
    try testing.expectEqual(IRON_INGOT, r.pattern[0][0]);
    try testing.expectEqual(E, r.pattern[0][1]);
}

test "iron ingot recomposition from 9 nuggets" {
    const r = recipes[10];
    try testing.expectEqual(IRON_INGOT, r.result_item);
    try testing.expectEqual(@as(u8, 1), r.result_count);
    for (0..3) |row| {
        for (0..3) |col| {
            try testing.expectEqual(IRON_NUGGET, r.pattern[row][col]);
        }
    }
}

test "findByResult returns matching recipe" {
    const maybe = findByResult(LIGHTNING_ROD);
    try testing.expect(maybe != null);
    const r = maybe.?;
    try testing.expectEqual(LIGHTNING_ROD, r.result_item);
    try testing.expectEqual(@as(u8, 1), r.result_count);
    // Three vertical copper ingots
    try testing.expectEqual(COPPER_INGOT, r.pattern[0][0]);
    try testing.expectEqual(COPPER_INGOT, r.pattern[1][0]);
    try testing.expectEqual(COPPER_INGOT, r.pattern[2][0]);
}

test "findByResult returns null for unknown item" {
    try testing.expect(findByResult(9999) == null);
}

test "flower pot uses brick V pattern" {
    const r = recipes[12];
    try testing.expectEqual(FLOWER_POT, r.result_item);
    try testing.expectEqual(BRICK_ITEM, r.pattern[1][0]);
    try testing.expectEqual(E, r.pattern[1][1]);
    try testing.expectEqual(BRICK_ITEM, r.pattern[1][2]);
    try testing.expectEqual(BRICK_ITEM, r.pattern[2][1]);
}
