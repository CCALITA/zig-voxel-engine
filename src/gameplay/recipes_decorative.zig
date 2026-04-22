/// Decorative block crafting recipes.
/// 40+ shaped recipes for stairs, slabs, fences, doors, lighting, and other decorative blocks.

const std = @import("std");

pub const ShapedRecipe = struct {
    pattern: [3][3]u16,
    result_item: u16,
    result_count: u8,
};

// ── Item / Block IDs ──────────────────────────────────────────────────
const E: u16 = 0; // empty cell
const PLANKS: u16 = 5;
const COBBLE: u16 = 4;
const STONE: u16 = 1;
const STICK: u16 = 256;
const IRON_INGOT: u16 = 322;
const LEATHER: u16 = 328;
const WOOL_WHITE: u16 = 75;
const GLASS: u16 = 17;
const BOOK_ITEM: u16 = 339;
const COAL: u16 = 321;
const PAPER: u16 = 340;
const BRICK_ITEM: u16 = 341;
const NETHER_BRICK_ITEM: u16 = 342;
const SUGAR_CANE: u16 = 344;

// ── Result block IDs ──────────────────────────────────────────────────
const STONE_STAIRS: u16 = 400;
const STONE_SLAB: u16 = 401;
const OAK_FENCE: u16 = 402;
const OAK_FENCE_GATE: u16 = 403;
const STONE_WALL: u16 = 404;
const OAK_DOOR: u16 = 405;
const OAK_TRAPDOOR: u16 = 406;
const SIGN: u16 = 407;
const BOOKSHELF: u16 = 408;
const BED: u16 = 409;
const TORCH: u16 = 410;
const LANTERN: u16 = 411;
const LADDER: u16 = 412;
const GLASS_PANE: u16 = 413;
const IRON_BARS: u16 = 414;
const CARPET: u16 = 415;
const BANNER: u16 = 416;
const FLOWER_POT: u16 = 417;
const ITEM_FRAME: u16 = 418;
const PAINTING: u16 = 419;
const CHEST: u16 = 420;
const BARREL: u16 = 421;

// Stair variants
const COBBLE_STAIRS: u16 = 430;
const OAK_STAIRS: u16 = 431;
const SANDSTONE_STAIRS: u16 = 432;
const BRICK_STAIRS: u16 = 433;
const NETHER_BRICK_STAIRS: u16 = 434;
const STONE_BRICK_STAIRS: u16 = 435;

// Slab variants
const COBBLE_SLAB: u16 = 440;
const OAK_SLAB: u16 = 441;
const SANDSTONE_SLAB: u16 = 442;
const BRICK_SLAB: u16 = 443;
const NETHER_BRICK_SLAB: u16 = 444;
const STONE_BRICK_SLAB: u16 = 445;

// Material blocks used as inputs for variant recipes
const SANDSTONE: u16 = 80;
const BRICKS: u16 = 81;
const NETHER_BRICKS: u16 = 82;
const STONE_BRICKS: u16 = 83;
const IRON_NUGGET: u16 = 345;

// Additional result block IDs
const COBBLE_WALL: u16 = 450;
const BRICK_WALL: u16 = 451;
const NETHER_BRICK_FENCE: u16 = 452;
const SANDSTONE_WALL: u16 = 453;

fn stairPattern(m: u16) [3][3]u16 {
    return .{
        .{ m, E, E },
        .{ m, m, E },
        .{ m, m, m },
    };
}

fn slabPattern(m: u16) [3][3]u16 {
    return .{
        .{ m, m, m },
        .{ E, E, E },
        .{ E, E, E },
    };
}

fn wallPattern(m: u16) [3][3]u16 {
    return .{
        .{ E, E, E },
        .{ m, m, m },
        .{ m, m, m },
    };
}

pub const recipes = [_]ShapedRecipe{
    // ── Stairs ────────────────────────────────────────────────────────
    .{ .pattern = stairPattern(STONE), .result_item = STONE_STAIRS, .result_count = 4 },
    .{ .pattern = stairPattern(COBBLE), .result_item = COBBLE_STAIRS, .result_count = 4 },
    .{ .pattern = stairPattern(PLANKS), .result_item = OAK_STAIRS, .result_count = 4 },
    .{ .pattern = stairPattern(SANDSTONE), .result_item = SANDSTONE_STAIRS, .result_count = 4 },
    .{ .pattern = stairPattern(BRICKS), .result_item = BRICK_STAIRS, .result_count = 4 },
    .{ .pattern = stairPattern(NETHER_BRICKS), .result_item = NETHER_BRICK_STAIRS, .result_count = 4 },
    .{ .pattern = stairPattern(STONE_BRICKS), .result_item = STONE_BRICK_STAIRS, .result_count = 4 },

    // ── Slabs ─────────────────────────────────────────────────────────
    .{ .pattern = slabPattern(STONE), .result_item = STONE_SLAB, .result_count = 6 },
    .{ .pattern = slabPattern(COBBLE), .result_item = COBBLE_SLAB, .result_count = 6 },
    .{ .pattern = slabPattern(PLANKS), .result_item = OAK_SLAB, .result_count = 6 },
    .{ .pattern = slabPattern(SANDSTONE), .result_item = SANDSTONE_SLAB, .result_count = 6 },
    .{ .pattern = slabPattern(BRICKS), .result_item = BRICK_SLAB, .result_count = 6 },
    .{ .pattern = slabPattern(NETHER_BRICKS), .result_item = NETHER_BRICK_SLAB, .result_count = 6 },
    .{ .pattern = slabPattern(STONE_BRICKS), .result_item = STONE_BRICK_SLAB, .result_count = 6 },

    // ── Fences & Gates ────────────────────────────────────────────────
    // Oak fence: PSP/PSP/___
    .{ .pattern = .{
        .{ PLANKS, STICK, PLANKS },
        .{ PLANKS, STICK, PLANKS },
        .{ E, E, E },
    }, .result_item = OAK_FENCE, .result_count = 3 },

    // Oak fence gate: SPS/SPS/___
    .{ .pattern = .{
        .{ STICK, PLANKS, STICK },
        .{ STICK, PLANKS, STICK },
        .{ E, E, E },
    }, .result_item = OAK_FENCE_GATE, .result_count = 1 },

    // ── Walls ─────────────────────────────────────────────────────────
    .{ .pattern = wallPattern(STONE), .result_item = STONE_WALL, .result_count = 6 },
    .{ .pattern = wallPattern(COBBLE), .result_item = COBBLE_WALL, .result_count = 6 },
    .{ .pattern = wallPattern(BRICKS), .result_item = BRICK_WALL, .result_count = 6 },
    .{ .pattern = wallPattern(SANDSTONE), .result_item = SANDSTONE_WALL, .result_count = 6 },

    // Nether brick fence: NBN/NBN/___ (NB=nether_brick_item)
    .{ .pattern = .{
        .{ NETHER_BRICK_ITEM, NETHER_BRICKS, NETHER_BRICK_ITEM },
        .{ NETHER_BRICK_ITEM, NETHER_BRICKS, NETHER_BRICK_ITEM },
        .{ E, E, E },
    }, .result_item = NETHER_BRICK_FENCE, .result_count = 6 },

    // ── Doors & Trapdoors ─────────────────────────────────────────────
    // Oak door: PP_/PP_/PP_
    .{ .pattern = .{
        .{ PLANKS, PLANKS, E },
        .{ PLANKS, PLANKS, E },
        .{ PLANKS, PLANKS, E },
    }, .result_item = OAK_DOOR, .result_count = 3 },

    // Oak trapdoor: PPP/PPP/___
    .{ .pattern = .{
        .{ PLANKS, PLANKS, PLANKS },
        .{ PLANKS, PLANKS, PLANKS },
        .{ E, E, E },
    }, .result_item = OAK_TRAPDOOR, .result_count = 2 },

    // ── Signs ─────────────────────────────────────────────────────────
    // Sign: PPP/PPP/_S_
    .{ .pattern = .{
        .{ PLANKS, PLANKS, PLANKS },
        .{ PLANKS, PLANKS, PLANKS },
        .{ E, STICK, E },
    }, .result_item = SIGN, .result_count = 3 },

    // ── Furniture & Storage ───────────────────────────────────────────
    // Bookshelf: PPP/BBB/PPP
    .{ .pattern = .{
        .{ PLANKS, PLANKS, PLANKS },
        .{ BOOK_ITEM, BOOK_ITEM, BOOK_ITEM },
        .{ PLANKS, PLANKS, PLANKS },
    }, .result_item = BOOKSHELF, .result_count = 1 },

    // Bed: ___/WWW/PPP
    .{ .pattern = .{
        .{ E, E, E },
        .{ WOOL_WHITE, WOOL_WHITE, WOOL_WHITE },
        .{ PLANKS, PLANKS, PLANKS },
    }, .result_item = BED, .result_count = 1 },

    // Chest: PPP/P_P/PPP
    .{ .pattern = .{
        .{ PLANKS, PLANKS, PLANKS },
        .{ PLANKS, E, PLANKS },
        .{ PLANKS, PLANKS, PLANKS },
    }, .result_item = CHEST, .result_count = 1 },

    // Barrel: PSP/P_P/PSP (S=slab)
    .{ .pattern = .{
        .{ PLANKS, OAK_SLAB, PLANKS },
        .{ PLANKS, E, PLANKS },
        .{ PLANKS, OAK_SLAB, PLANKS },
    }, .result_item = BARREL, .result_count = 1 },

    // ── Lighting ──────────────────────────────────────────────────────
    // Torch: _C_/_S_/___
    .{ .pattern = .{
        .{ E, COAL, E },
        .{ E, STICK, E },
        .{ E, E, E },
    }, .result_item = TORCH, .result_count = 4 },

    // Lantern: NNN/NTN/NNN (N=iron nugget, T=torch)
    .{ .pattern = .{
        .{ IRON_NUGGET, IRON_NUGGET, IRON_NUGGET },
        .{ IRON_NUGGET, TORCH, IRON_NUGGET },
        .{ IRON_NUGGET, IRON_NUGGET, IRON_NUGGET },
    }, .result_item = LANTERN, .result_count = 1 },

    // ── Ladders ───────────────────────────────────────────────────────
    // Ladder: S_S/SSS/S_S
    .{ .pattern = .{
        .{ STICK, E, STICK },
        .{ STICK, STICK, STICK },
        .{ STICK, E, STICK },
    }, .result_item = LADDER, .result_count = 3 },

    // ── Glass & Bars ──────────────────────────────────────────────────
    // Glass pane: ___/GGG/GGG
    .{ .pattern = .{
        .{ E, E, E },
        .{ GLASS, GLASS, GLASS },
        .{ GLASS, GLASS, GLASS },
    }, .result_item = GLASS_PANE, .result_count = 16 },

    // Iron bars: ___/III/III
    .{ .pattern = .{
        .{ E, E, E },
        .{ IRON_INGOT, IRON_INGOT, IRON_INGOT },
        .{ IRON_INGOT, IRON_INGOT, IRON_INGOT },
    }, .result_item = IRON_BARS, .result_count = 16 },

    // ── Textiles ──────────────────────────────────────────────────────
    // Carpet: ___/WW_/___
    .{ .pattern = .{
        .{ E, E, E },
        .{ WOOL_WHITE, WOOL_WHITE, E },
        .{ E, E, E },
    }, .result_item = CARPET, .result_count = 3 },

    // Banner: WWW/WWW/_S_
    .{ .pattern = .{
        .{ WOOL_WHITE, WOOL_WHITE, WOOL_WHITE },
        .{ WOOL_WHITE, WOOL_WHITE, WOOL_WHITE },
        .{ E, STICK, E },
    }, .result_item = BANNER, .result_count = 1 },

    // ── Decorative Items ──────────────────────────────────────────────
    // Flower pot: B_B/_B_/___ (B=brick)
    .{ .pattern = .{
        .{ BRICK_ITEM, E, BRICK_ITEM },
        .{ E, BRICK_ITEM, E },
        .{ E, E, E },
    }, .result_item = FLOWER_POT, .result_count = 1 },

    // Item frame: SSS/SLS/SSS (L=leather)
    .{ .pattern = .{
        .{ STICK, STICK, STICK },
        .{ STICK, LEATHER, STICK },
        .{ STICK, STICK, STICK },
    }, .result_item = ITEM_FRAME, .result_count = 1 },

    // Painting: SSS/SWS/SSS (W=wool)
    .{ .pattern = .{
        .{ STICK, STICK, STICK },
        .{ STICK, WOOL_WHITE, STICK },
        .{ STICK, STICK, STICK },
    }, .result_item = PAINTING, .result_count = 1 },

    // ── Paper & Books ─────────────────────────────────────────────────
    // Paper: ___/SSS/___ (S=sugar_cane)
    .{ .pattern = .{
        .{ E, E, E },
        .{ SUGAR_CANE, SUGAR_CANE, SUGAR_CANE },
        .{ E, E, E },
    }, .result_item = PAPER, .result_count = 3 },

    // Book: PP_/P__/___ (P=paper)
    .{ .pattern = .{
        .{ PAPER, PAPER, E },
        .{ PAPER, E, E },
        .{ E, E, E },
    }, .result_item = BOOK_ITEM, .result_count = 1 },
};

comptime {
    // Ensure we have 40+ recipes
    if (recipes.len < 40) {
        @compileError("Expected at least 40 decorative recipes, got " ++ std.fmt.comptimePrint("{d}", .{recipes.len}));
    }
}

// ── Tests ─────────────────────────────────────────────────────────────

test "recipe count is at least 40" {
    try std.testing.expect(recipes.len >= 40);
}

test "all recipes have non-zero result_count" {
    for (recipes) |r| {
        try std.testing.expect(r.result_count > 0);
    }
}

test "all recipes have a non-zero result_item" {
    for (recipes) |r| {
        try std.testing.expect(r.result_item != 0);
    }
}

test "all recipes have at least one non-empty input cell" {
    for (recipes) |r| {
        var has_input = false;
        for (r.pattern) |row| {
            for (row) |cell| {
                if (cell != 0) has_input = true;
            }
        }
        try std.testing.expect(has_input);
    }
}

test "no duplicate result_item and pattern combinations" {
    for (recipes, 0..) |a, i| {
        for (recipes[i + 1 ..]) |b| {
            var same = true;
            for (0..3) |r| {
                for (0..3) |c| {
                    if (a.pattern[r][c] != b.pattern[r][c]) same = false;
                }
            }
            try std.testing.expect(!same);
        }
    }
}

test "stone stairs recipe is correct" {
    const r = recipes[0];
    try std.testing.expectEqual(STONE_STAIRS, r.result_item);
    try std.testing.expectEqual(@as(u8, 4), r.result_count);
    try std.testing.expectEqual(STONE, r.pattern[0][0]);
    try std.testing.expectEqual(@as(u16, 0), r.pattern[0][1]);
    try std.testing.expectEqual(STONE, r.pattern[2][2]);
}

test "torch recipe is correct" {
    // Find torch recipe
    for (recipes) |r| {
        if (r.result_item == TORCH) {
            try std.testing.expectEqual(@as(u8, 4), r.result_count);
            try std.testing.expectEqual(COAL, r.pattern[0][1]);
            try std.testing.expectEqual(STICK, r.pattern[1][1]);
            return;
        }
    }
    return error.TestUnexpectedResult;
}

test "slab recipes produce 6 items" {
    for (recipes) |r| {
        if (r.result_item >= 440 and r.result_item <= 445) {
            try std.testing.expectEqual(@as(u8, 6), r.result_count);
        }
        if (r.result_item == STONE_SLAB) {
            try std.testing.expectEqual(@as(u8, 6), r.result_count);
        }
    }
}

test "stair recipes produce 4 items" {
    for (recipes) |r| {
        if (r.result_item >= 430 and r.result_item <= 435) {
            try std.testing.expectEqual(@as(u8, 4), r.result_count);
        }
        if (r.result_item == STONE_STAIRS) {
            try std.testing.expectEqual(@as(u8, 4), r.result_count);
        }
    }
}
