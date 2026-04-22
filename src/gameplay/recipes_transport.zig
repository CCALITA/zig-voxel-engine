/// Transport and utility crafting recipes.
/// Defines 20 shaped recipes for rails, vehicles, tools, and equipment.

const std = @import("std");

// ── Ingredient IDs ──────────────────────────────────────────────────────────

const E: u16 = 0; // empty cell

const COBBLE: u16 = 4;
const PLANKS: u16 = 5;
const OBSIDIAN: u16 = 20;
const STICK: u16 = 256;
const IRON: u16 = 322;
const GOLD: u16 = 323;
const STRING: u16 = 315;
const ENDER_PEARL: u16 = 319;
const REDSTONE: u16 = 330;
const SLIME: u16 = 332;
const TRIPWIRE: u16 = 337;
const IRON_NUGGET: u16 = 345;

// ── Result IDs ──────────────────────────────────────────────────────────────

const RAIL: u16 = 60;
const POWERED_RAIL: u16 = 61;
const DETECTOR_RAIL: u16 = 62;
const ACTIVATOR_RAIL: u16 = 63;
const MINECART: u16 = 346;
const BOAT: u16 = 347;
const BUCKET: u16 = 303;
const COMPASS: u16 = 304;
const CLOCK: u16 = 305;
const MAP: u16 = 306;
const SHEARS: u16 = 307;
const FLINT_STEEL: u16 = 308;
const FISHING_ROD: u16 = 309;
const LEAD: u16 = 310;
const ENDER_CHEST: u16 = 109;
const SHIELD: u16 = 348;
const BOW: u16 = 333;
const CROSSBOW: u16 = 349;
const SPYGLASS: u16 = 350;
const CHAIN: u16 = 351;

// ── Recipe type ─────────────────────────────────────────────────────────────

pub const ShapedRecipe = struct {
    pattern: [3][3]u16,
    result_item: u16,
    result_count: u8,
};

// ── Recipe table ────────────────────────────────────────────────────────────

pub const recipes = [20]ShapedRecipe{
    // 0  Rail (16)  I_I / ISI / I_I
    .{ .pattern = .{
        .{ IRON, E, IRON },
        .{ IRON, STICK, IRON },
        .{ IRON, E, IRON },
    }, .result_item = RAIL, .result_count = 16 },

    // 1  Powered Rail (6)  G_G / GSG / GRG
    .{ .pattern = .{
        .{ GOLD, E, GOLD },
        .{ GOLD, STICK, GOLD },
        .{ GOLD, REDSTONE, GOLD },
    }, .result_item = POWERED_RAIL, .result_count = 6 },

    // 2  Detector Rail (6)  I_I / ISI / IRI  (S = stone pressure plate = cobble)
    .{ .pattern = .{
        .{ IRON, E, IRON },
        .{ IRON, COBBLE, IRON },
        .{ IRON, REDSTONE, IRON },
    }, .result_item = DETECTOR_RAIL, .result_count = 6 },

    // 3  Activator Rail (6)  ISI / IRI / ISI
    .{ .pattern = .{
        .{ IRON, STICK, IRON },
        .{ IRON, REDSTONE, IRON },
        .{ IRON, STICK, IRON },
    }, .result_item = ACTIVATOR_RAIL, .result_count = 6 },

    // 4  Minecart (1)  ___ / I_I / III
    .{ .pattern = .{
        .{ E, E, E },
        .{ IRON, E, IRON },
        .{ IRON, IRON, IRON },
    }, .result_item = MINECART, .result_count = 1 },

    // 5  Boat (1)  ___ / P_P / PPP
    .{ .pattern = .{
        .{ E, E, E },
        .{ PLANKS, E, PLANKS },
        .{ PLANKS, PLANKS, PLANKS },
    }, .result_item = BOAT, .result_count = 1 },

    // 6  Bucket (1)  ___ / I_I / _I_
    .{ .pattern = .{
        .{ E, E, E },
        .{ IRON, E, IRON },
        .{ E, IRON, E },
    }, .result_item = BUCKET, .result_count = 1 },

    // 7  Compass (1)  _I_ / IRI / _I_
    .{ .pattern = .{
        .{ E, IRON, E },
        .{ IRON, REDSTONE, IRON },
        .{ E, IRON, E },
    }, .result_item = COMPASS, .result_count = 1 },

    // 8  Clock (1)  _G_ / GRG / _G_
    .{ .pattern = .{
        .{ E, GOLD, E },
        .{ GOLD, REDSTONE, GOLD },
        .{ E, GOLD, E },
    }, .result_item = CLOCK, .result_count = 1 },

    // 9  Map (1)  PPP / PCP / PPP  (C = compass)
    .{ .pattern = .{
        .{ PLANKS, PLANKS, PLANKS },
        .{ PLANKS, COMPASS, PLANKS },
        .{ PLANKS, PLANKS, PLANKS },
    }, .result_item = MAP, .result_count = 1 },

    // 10 Shears (1)  _I_ / I__ / ___
    .{ .pattern = .{
        .{ E, IRON, E },
        .{ IRON, E, E },
        .{ E, E, E },
    }, .result_item = SHEARS, .result_count = 1 },

    // 11 Flint & Steel (1)  ___ / IF_ / ___  (F = iron_nugget as flint)
    .{ .pattern = .{
        .{ E, E, E },
        .{ IRON, IRON_NUGGET, E },
        .{ E, E, E },
    }, .result_item = FLINT_STEEL, .result_count = 1 },

    // 12 Fishing Rod (1)  __S / __N / _SN  (N = string)
    .{ .pattern = .{
        .{ E, E, STICK },
        .{ E, E, STRING },
        .{ E, STICK, STRING },
    }, .result_item = FISHING_ROD, .result_count = 1 },

    // 13 Lead (2)  SS_ / SL_ / __S  (L = slime)
    .{ .pattern = .{
        .{ STRING, STRING, E },
        .{ STRING, SLIME, E },
        .{ E, E, STRING },
    }, .result_item = LEAD, .result_count = 2 },

    // 14 Ender Chest (1)  OOO / OPO / OOO  (P = ender_pearl)
    .{ .pattern = .{
        .{ OBSIDIAN, OBSIDIAN, OBSIDIAN },
        .{ OBSIDIAN, ENDER_PEARL, OBSIDIAN },
        .{ OBSIDIAN, OBSIDIAN, OBSIDIAN },
    }, .result_item = ENDER_CHEST, .result_count = 1 },

    // 15 Shield (1)  PIP / PPP / _P_
    .{ .pattern = .{
        .{ PLANKS, IRON, PLANKS },
        .{ PLANKS, PLANKS, PLANKS },
        .{ E, PLANKS, E },
    }, .result_item = SHIELD, .result_count = 1 },

    // 16 Bow (1)  _SP / S_P / _SP  (S = stick, P = string)
    .{ .pattern = .{
        .{ E, STICK, STRING },
        .{ STICK, E, STRING },
        .{ E, STICK, STRING },
    }, .result_item = BOW, .result_count = 1 },

    // 17 Crossbow (1)  SIS / TIT / _S_  (T = tripwire)
    .{ .pattern = .{
        .{ STICK, IRON, STICK },
        .{ TRIPWIRE, IRON, TRIPWIRE },
        .{ E, STICK, E },
    }, .result_item = CROSSBOW, .result_count = 1 },

    // 18 Spyglass (1)  _G_ / _N_ / _N_  (N = iron_nugget as copper)
    .{ .pattern = .{
        .{ E, GOLD, E },
        .{ E, IRON_NUGGET, E },
        .{ E, IRON_NUGGET, E },
    }, .result_item = SPYGLASS, .result_count = 1 },

    // 19 Chain (3)  _N_ / _I_ / _N_  (N = iron_nugget)
    .{ .pattern = .{
        .{ E, IRON_NUGGET, E },
        .{ E, IRON, E },
        .{ E, IRON_NUGGET, E },
    }, .result_item = CHAIN, .result_count = 3 },
};

// ── Tests ───────────────────────────────────────────────────────────────────

test "recipe count is 20" {
    try std.testing.expectEqual(@as(usize, 20), recipes.len);
}

test "all result counts are nonzero" {
    for (recipes) |r| {
        try std.testing.expect(r.result_count > 0);
    }
}

test "no recipe produces item 0 (air)" {
    for (recipes) |r| {
        try std.testing.expect(r.result_item != 0);
    }
}

test "every recipe has at least one nonempty cell" {
    for (recipes) |r| {
        var has_ingredient = false;
        for (r.pattern) |row| {
            for (row) |cell| {
                if (cell != 0) has_ingredient = true;
            }
        }
        try std.testing.expect(has_ingredient);
    }
}

test "no duplicate result items" {
    for (recipes, 0..) |a, i| {
        for (recipes[i + 1 ..]) |b| {
            try std.testing.expect(a.result_item != b.result_item);
        }
    }
}

test "rail recipe shape" {
    const rail = recipes[0];
    try std.testing.expectEqual(RAIL, rail.result_item);
    try std.testing.expectEqual(@as(u8, 16), rail.result_count);
    try std.testing.expectEqual(IRON, rail.pattern[0][0]);
    try std.testing.expectEqual(@as(u16, 0), rail.pattern[0][1]);
    try std.testing.expectEqual(IRON, rail.pattern[0][2]);
    try std.testing.expectEqual(STICK, rail.pattern[1][1]);
}

test "minecart recipe shape" {
    const mc = recipes[4];
    try std.testing.expectEqual(MINECART, mc.result_item);
    try std.testing.expectEqual(@as(u8, 1), mc.result_count);
    // top row empty
    for (mc.pattern[0]) |cell| {
        try std.testing.expectEqual(@as(u16, 0), cell);
    }
    // bottom row all iron
    for (mc.pattern[2]) |cell| {
        try std.testing.expectEqual(IRON, cell);
    }
}

test "compass recipe is symmetric" {
    const c = recipes[7];
    try std.testing.expectEqual(COMPASS, c.result_item);
    // top = _I_, bottom = _I_
    try std.testing.expectEqual(c.pattern[0][1], c.pattern[2][1]);
    try std.testing.expectEqual(@as(u16, 0), c.pattern[0][0]);
    try std.testing.expectEqual(@as(u16, 0), c.pattern[2][2]);
    // centre = redstone
    try std.testing.expectEqual(REDSTONE, c.pattern[1][1]);
}

test "chain recipe count is 3" {
    const ch = recipes[19];
    try std.testing.expectEqual(CHAIN, ch.result_item);
    try std.testing.expectEqual(@as(u8, 3), ch.result_count);
}

test "shield recipe shape" {
    const s = recipes[15];
    try std.testing.expectEqual(SHIELD, s.result_item);
    try std.testing.expectEqual(PLANKS, s.pattern[0][0]);
    try std.testing.expectEqual(IRON, s.pattern[0][1]);
    try std.testing.expectEqual(PLANKS, s.pattern[0][2]);
    try std.testing.expectEqual(@as(u16, 0), s.pattern[2][0]);
    try std.testing.expectEqual(PLANKS, s.pattern[2][1]);
    try std.testing.expectEqual(@as(u16, 0), s.pattern[2][2]);
}

test "bow uses stick and string" {
    const b = recipes[16];
    try std.testing.expectEqual(BOW, b.result_item);
    try std.testing.expectEqual(STICK, b.pattern[0][1]);
    try std.testing.expectEqual(STRING, b.pattern[0][2]);
    try std.testing.expectEqual(STICK, b.pattern[1][0]);
    try std.testing.expectEqual(@as(u16, 0), b.pattern[1][1]);
    try std.testing.expectEqual(STRING, b.pattern[1][2]);
}
