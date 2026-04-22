/// Colored item crafting recipes.
/// 80 shaped recipes for carpets, dyed wool, concrete powder, stained glass,
/// and stained glass panes across all 16 dye colors.

const std = @import("std");

pub const ShapedRecipe = struct {
    pattern: [3][3]u16,
    result_item: u16,
    result_count: u8,
};

// ── Empty cell ───────────────────────────────────────────────────────
const E: u16 = 0;

// ── Material IDs ─────────────────────────────────────────────────────
const SAND: u16 = 6;
const GRAVEL: u16 = 7;
const GLASS: u16 = 17;
const WOOL_WHITE: u16 = 75;

// ── Dye IDs (420–435, sequential by color index) ─────────────────────
const DYE_BASE: u16 = 420;

// ── Wool IDs (75–90, matching block.zig) ─────────────────────────────
const WOOL_BASE: u16 = 75;

// ── Result base IDs ──────────────────────────────────────────────────
const CARPET_BASE: u16 = 460;
const CPOW_BASE: u16 = 480;
const SGLASS_BASE: u16 = 500;
const SPANE_BASE: u16 = 520;

// ── Color count ──────────────────────────────────────────────────────
const COLOR_COUNT = 16;

fn dyeId(color: u16) u16 {
    return DYE_BASE + color;
}

fn woolId(color: u16) u16 {
    return WOOL_BASE + color;
}

fn carpetId(color: u16) u16 {
    return CARPET_BASE + color;
}

fn cpowId(color: u16) u16 {
    return CPOW_BASE + color;
}

fn sglassId(color: u16) u16 {
    return SGLASS_BASE + color;
}

fn spaneId(color: u16) u16 {
    return SPANE_BASE + color;
}

// ── Recipe builders ──────────────────────────────────────────────────

/// Carpet: ___/WW_/___ (W = wool of matching color) → 3
fn carpetRecipe(color: u16) ShapedRecipe {
    const w = woolId(color);
    return .{
        .pattern = .{
            .{ E, E, E },
            .{ w, w, E },
            .{ E, E, E },
        },
        .result_item = carpetId(color),
        .result_count = 3,
    };
}

/// Colored wool: ___/_D_/_W_ (D = dye, W = white wool) → 1
fn coloredWoolRecipe(color: u16) ShapedRecipe {
    return .{
        .pattern = .{
            .{ E, E, E },
            .{ E, dyeId(color), E },
            .{ E, WOOL_WHITE, E },
        },
        .result_item = woolId(color),
        .result_count = 1,
    };
}

/// Concrete powder: DGG/GSG/GGS (D = dye, G = gravel, S = sand) → 8
fn concretePowderRecipe(color: u16) ShapedRecipe {
    return .{
        .pattern = .{
            .{ dyeId(color), GRAVEL, GRAVEL },
            .{ GRAVEL, SAND, GRAVEL },
            .{ GRAVEL, GRAVEL, SAND },
        },
        .result_item = cpowId(color),
        .result_count = 8,
    };
}

/// Stained glass: GGG/GDG/GGG (G = glass, D = dye) → 8
fn stainedGlassRecipe(color: u16) ShapedRecipe {
    const d = dyeId(color);
    return .{
        .pattern = .{
            .{ GLASS, GLASS, GLASS },
            .{ GLASS, d, GLASS },
            .{ GLASS, GLASS, GLASS },
        },
        .result_item = sglassId(color),
        .result_count = 8,
    };
}

/// Stained glass pane: ___/GGG/GGG (G = stained glass of matching color) → 16
fn stainedGlassPaneRecipe(color: u16) ShapedRecipe {
    const g = sglassId(color);
    return .{
        .pattern = .{
            .{ E, E, E },
            .{ g, g, g },
            .{ g, g, g },
        },
        .result_item = spaneId(color),
        .result_count = 16,
    };
}

// ── Generate all 80 recipes at comptime ──────────────────────────────

fn generateRecipes() [80]ShapedRecipe {
    var result: [80]ShapedRecipe = undefined;
    var i: usize = 0;
    for (0..COLOR_COUNT) |c| {
        const color: u16 = @intCast(c);
        result[i] = carpetRecipe(color);
        i += 1;
        result[i] = coloredWoolRecipe(color);
        i += 1;
        result[i] = concretePowderRecipe(color);
        i += 1;
        result[i] = stainedGlassRecipe(color);
        i += 1;
        result[i] = stainedGlassPaneRecipe(color);
        i += 1;
    }
    return result;
}

pub const recipes: [80]ShapedRecipe = generateRecipes();

// ── Tests ────────────────────────────────────────────────────────────

test "recipe count is exactly 80" {
    try std.testing.expectEqual(@as(usize, 80), recipes.len);
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

test "no duplicate patterns" {
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

test "white carpet recipe" {
    const r = recipes[0]; // color 0, first recipe type
    try std.testing.expectEqual(@as(u16, 460), r.result_item);
    try std.testing.expectEqual(@as(u8, 3), r.result_count);
    // Row 0: ___
    try std.testing.expectEqual(@as(u16, 0), r.pattern[0][0]);
    // Row 1: WW_
    try std.testing.expectEqual(@as(u16, 75), r.pattern[1][0]);
    try std.testing.expectEqual(@as(u16, 75), r.pattern[1][1]);
    try std.testing.expectEqual(@as(u16, 0), r.pattern[1][2]);
    // Row 2: ___
    try std.testing.expectEqual(@as(u16, 0), r.pattern[2][0]);
}

test "white colored wool recipe" {
    const r = recipes[1]; // color 0, second recipe type
    try std.testing.expectEqual(@as(u16, 75), r.result_item);
    try std.testing.expectEqual(@as(u8, 1), r.result_count);
    // ___/_D_/_W_
    try std.testing.expectEqual(@as(u16, 420), r.pattern[1][1]); // dye_white
    try std.testing.expectEqual(@as(u16, 75), r.pattern[2][1]); // white wool
}

test "black concrete powder recipe" {
    // color 15 (black), recipe offset 2 (concrete powder) => index 15*5+2 = 77
    const r = recipes[77];
    try std.testing.expectEqual(@as(u16, 495), r.result_item); // CPOW_BLACK
    try std.testing.expectEqual(@as(u8, 8), r.result_count);
    // DGG/GSG/GGS
    try std.testing.expectEqual(@as(u16, 435), r.pattern[0][0]); // dye_black
    try std.testing.expectEqual(@as(u16, 7), r.pattern[0][1]); // gravel
    try std.testing.expectEqual(@as(u16, 6), r.pattern[1][1]); // sand
}

test "orange stained glass recipe" {
    // color 1 (orange), recipe offset 3 (stained glass) => index 1*5+3 = 8
    const r = recipes[8];
    try std.testing.expectEqual(@as(u16, 501), r.result_item); // SGLASS_ORANGE
    try std.testing.expectEqual(@as(u8, 8), r.result_count);
    // GGG/GDG/GGG
    try std.testing.expectEqual(@as(u16, 17), r.pattern[0][0]); // glass
    try std.testing.expectEqual(@as(u16, 421), r.pattern[1][1]); // dye_orange
    try std.testing.expectEqual(@as(u16, 17), r.pattern[2][2]); // glass
}

test "red stained glass pane recipe" {
    // color 14 (red), recipe offset 4 (stained glass pane) => index 14*5+4 = 74
    const r = recipes[74];
    try std.testing.expectEqual(@as(u16, 534), r.result_item); // SPANE_RED
    try std.testing.expectEqual(@as(u8, 16), r.result_count);
    // ___/GGG/GGG where G = stained glass red (514)
    try std.testing.expectEqual(@as(u16, 0), r.pattern[0][0]);
    try std.testing.expectEqual(@as(u16, 514), r.pattern[1][0]);
    try std.testing.expectEqual(@as(u16, 514), r.pattern[2][2]);
}

test "carpet recipes all produce 3" {
    for (0..COLOR_COUNT) |c| {
        const r = recipes[c * 5]; // carpet is offset 0
        try std.testing.expectEqual(@as(u8, 3), r.result_count);
    }
}

test "colored wool recipes all produce 1" {
    for (0..COLOR_COUNT) |c| {
        const r = recipes[c * 5 + 1]; // wool is offset 1
        try std.testing.expectEqual(@as(u8, 1), r.result_count);
    }
}

test "concrete powder recipes all produce 8" {
    for (0..COLOR_COUNT) |c| {
        const r = recipes[c * 5 + 2]; // concrete powder is offset 2
        try std.testing.expectEqual(@as(u8, 8), r.result_count);
    }
}

test "stained glass recipes all produce 8" {
    for (0..COLOR_COUNT) |c| {
        const r = recipes[c * 5 + 3]; // stained glass is offset 3
        try std.testing.expectEqual(@as(u8, 8), r.result_count);
    }
}

test "stained glass pane recipes all produce 16" {
    for (0..COLOR_COUNT) |c| {
        const r = recipes[c * 5 + 4]; // stained glass pane is offset 4
        try std.testing.expectEqual(@as(u8, 16), r.result_count);
    }
}

test "result IDs span expected ranges" {
    // Verify carpet IDs are 460–475
    for (0..COLOR_COUNT) |c| {
        const r = recipes[c * 5];
        try std.testing.expectEqual(@as(u16, @intCast(460 + c)), r.result_item);
    }
    // Verify wool IDs are 75–90
    for (0..COLOR_COUNT) |c| {
        const r = recipes[c * 5 + 1];
        try std.testing.expectEqual(@as(u16, @intCast(75 + c)), r.result_item);
    }
    // Verify concrete powder IDs are 480–495
    for (0..COLOR_COUNT) |c| {
        const r = recipes[c * 5 + 2];
        try std.testing.expectEqual(@as(u16, @intCast(480 + c)), r.result_item);
    }
    // Verify stained glass IDs are 500–515
    for (0..COLOR_COUNT) |c| {
        const r = recipes[c * 5 + 3];
        try std.testing.expectEqual(@as(u16, @intCast(500 + c)), r.result_item);
    }
    // Verify stained glass pane IDs are 520–535
    for (0..COLOR_COUNT) |c| {
        const r = recipes[c * 5 + 4];
        try std.testing.expectEqual(@as(u16, @intCast(520 + c)), r.result_item);
    }
}
