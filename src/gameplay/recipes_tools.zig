/// Tool crafting recipes for all 5 tiers (wood, stone, iron, gold, diamond)
/// and 5 tool types (pickaxe, axe, shovel, hoe, sword).
/// Compatible with the crafting registry in crafting.zig.

const std = @import("std");

pub const ShapedRecipe = struct {
    pattern: [3][3]u16,
    result_item: u16,
    result_count: u8,
};

// ---------------------------------------------------------------------------
// Materials
// ---------------------------------------------------------------------------

const OAK_PLANKS: u16 = 5;
const COBBLESTONE: u16 = 4;
const IRON_INGOT: u16 = 322;
const GOLD_INGOT: u16 = 323;
const DIAMOND: u16 = 324;
const STICK: u16 = 256;

const materials = [5]u16{ OAK_PLANKS, COBBLESTONE, IRON_INGOT, GOLD_INGOT, DIAMOND };

// ---------------------------------------------------------------------------
// Pattern templates (0 = empty, 1 = material, 2 = stick)
// ---------------------------------------------------------------------------

const pickaxe_template: [3][3]u2 = .{
    .{ 1, 1, 1 },
    .{ 0, 2, 0 },
    .{ 0, 2, 0 },
};

const axe_template: [3][3]u2 = .{
    .{ 1, 1, 0 },
    .{ 1, 2, 0 },
    .{ 0, 2, 0 },
};

const shovel_template: [3][3]u2 = .{
    .{ 0, 1, 0 },
    .{ 0, 2, 0 },
    .{ 0, 2, 0 },
};

const hoe_template: [3][3]u2 = .{
    .{ 1, 1, 0 },
    .{ 0, 2, 0 },
    .{ 0, 2, 0 },
};

const sword_template: [3][3]u2 = .{
    .{ 0, 1, 0 },
    .{ 0, 1, 0 },
    .{ 0, 2, 0 },
};

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

fn makeToolRecipe(comptime template: [3][3]u2, material: u16, result: u16) ShapedRecipe {
    var pattern: [3][3]u16 = undefined;
    for (0..3) |r| {
        for (0..3) |c| {
            pattern[r][c] = switch (template[r][c]) {
                0 => 0,
                1 => material,
                2 => STICK,
                3 => unreachable,
            };
        }
    }
    return .{
        .pattern = pattern,
        .result_item = result,
        .result_count = 1,
    };
}

// ---------------------------------------------------------------------------
// Tool base IDs: pickaxe 257, axe 262, shovel 267, hoe 272, sword 277
// ---------------------------------------------------------------------------

const tool_templates = [5][3][3]u2{
    pickaxe_template,
    axe_template,
    shovel_template,
    hoe_template,
    sword_template,
};

const tool_base_ids = [5]u16{ 257, 262, 267, 272, 277 };

pub const recipes: [25]ShapedRecipe = blk: {
    var r: [25]ShapedRecipe = undefined;
    for (tool_templates, tool_base_ids, 0..) |template, base_id, tool_idx| {
        for (materials, 0..) |mat, tier_idx| {
            r[tool_idx * 5 + tier_idx] = makeToolRecipe(template, mat, base_id + @as(u16, @intCast(tier_idx)));
        }
    }
    break :blk r;
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "recipe count is 25" {
    try std.testing.expectEqual(@as(usize, 25), recipes.len);
}

test "wooden pickaxe pattern" {
    const r = recipes[0]; // first recipe: wood pickaxe
    try std.testing.expectEqual(@as(u16, 257), r.result_item);
    try std.testing.expectEqual(@as(u8, 1), r.result_count);
    // Top row: PPP
    try std.testing.expectEqual(@as(u16, OAK_PLANKS), r.pattern[0][0]);
    try std.testing.expectEqual(@as(u16, OAK_PLANKS), r.pattern[0][1]);
    try std.testing.expectEqual(@as(u16, OAK_PLANKS), r.pattern[0][2]);
    // Middle row: _S_
    try std.testing.expectEqual(@as(u16, 0), r.pattern[1][0]);
    try std.testing.expectEqual(@as(u16, STICK), r.pattern[1][1]);
    try std.testing.expectEqual(@as(u16, 0), r.pattern[1][2]);
    // Bottom row: _S_
    try std.testing.expectEqual(@as(u16, 0), r.pattern[2][0]);
    try std.testing.expectEqual(@as(u16, STICK), r.pattern[2][1]);
    try std.testing.expectEqual(@as(u16, 0), r.pattern[2][2]);
}

test "diamond sword pattern and ID" {
    // sword base=277, diamond tier=4 -> ID 281
    const r = recipes[4 * 5 + 4]; // sword tool_idx=4, tier_idx=4
    try std.testing.expectEqual(@as(u16, 281), r.result_item);
    // _P_ / _P_ / _S_
    try std.testing.expectEqual(@as(u16, 0), r.pattern[0][0]);
    try std.testing.expectEqual(@as(u16, DIAMOND), r.pattern[0][1]);
    try std.testing.expectEqual(@as(u16, 0), r.pattern[0][2]);
    try std.testing.expectEqual(@as(u16, DIAMOND), r.pattern[1][1]);
    try std.testing.expectEqual(@as(u16, STICK), r.pattern[2][1]);
}

test "iron axe pattern and ID" {
    // axe base=262, iron tier=2 -> ID 264
    const r = recipes[1 * 5 + 2];
    try std.testing.expectEqual(@as(u16, 264), r.result_item);
    // PP_ / PS_ / _S_
    try std.testing.expectEqual(@as(u16, IRON_INGOT), r.pattern[0][0]);
    try std.testing.expectEqual(@as(u16, IRON_INGOT), r.pattern[0][1]);
    try std.testing.expectEqual(@as(u16, 0), r.pattern[0][2]);
    try std.testing.expectEqual(@as(u16, IRON_INGOT), r.pattern[1][0]);
    try std.testing.expectEqual(@as(u16, STICK), r.pattern[1][1]);
    try std.testing.expectEqual(@as(u16, 0), r.pattern[2][0]);
    try std.testing.expectEqual(@as(u16, STICK), r.pattern[2][1]);
}

test "gold hoe pattern and ID" {
    // hoe base=272, gold tier=3 -> ID 275
    const r = recipes[3 * 5 + 3];
    try std.testing.expectEqual(@as(u16, 275), r.result_item);
    // PP_ / _S_ / _S_
    try std.testing.expectEqual(@as(u16, GOLD_INGOT), r.pattern[0][0]);
    try std.testing.expectEqual(@as(u16, GOLD_INGOT), r.pattern[0][1]);
    try std.testing.expectEqual(@as(u16, 0), r.pattern[0][2]);
    try std.testing.expectEqual(@as(u16, 0), r.pattern[1][0]);
    try std.testing.expectEqual(@as(u16, STICK), r.pattern[1][1]);
}

test "stone shovel pattern and ID" {
    // shovel base=267, stone tier=1 -> ID 268
    const r = recipes[2 * 5 + 1];
    try std.testing.expectEqual(@as(u16, 268), r.result_item);
    // _P_ / _S_ / _S_
    try std.testing.expectEqual(@as(u16, 0), r.pattern[0][0]);
    try std.testing.expectEqual(@as(u16, COBBLESTONE), r.pattern[0][1]);
    try std.testing.expectEqual(@as(u16, 0), r.pattern[0][2]);
    try std.testing.expectEqual(@as(u16, STICK), r.pattern[1][1]);
    try std.testing.expectEqual(@as(u16, STICK), r.pattern[2][1]);
}

test "all recipes produce count of 1" {
    for (recipes) |r| {
        try std.testing.expectEqual(@as(u8, 1), r.result_count);
    }
}
