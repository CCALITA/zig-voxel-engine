const std = @import("std");
const crafting = @import("crafting.zig");

pub const ShapedRecipe = crafting.Recipe;

const Material = struct {
    id: u16,
    base_result: u16,
};

const materials = [_]Material{
    .{ .id = 328, .base_result = 282 }, // Leather
    .{ .id = 322, .base_result = 286 }, // Iron
    .{ .id = 323, .base_result = 290 }, // Gold
    .{ .id = 324, .base_result = 294 }, // Diamond
    .{ .id = 327, .base_result = 298 }, // Netherite
};

// Patterns: helmet, chestplate, leggings, boots
// P = 1 (material slot), _ = 0 (empty slot)
const piece_patterns = [4][3][3]u1{
    // Helmet: PPP / P_P / ___
    .{ .{ 1, 1, 1 }, .{ 1, 0, 1 }, .{ 0, 0, 0 } },
    // Chestplate: P_P / PPP / PPP
    .{ .{ 1, 0, 1 }, .{ 1, 1, 1 }, .{ 1, 1, 1 } },
    // Leggings: PPP / P_P / P_P
    .{ .{ 1, 1, 1 }, .{ 1, 0, 1 }, .{ 1, 0, 1 } },
    // Boots: ___ / P_P / P_P
    .{ .{ 0, 0, 0 }, .{ 1, 0, 1 }, .{ 1, 0, 1 } },
};

fn buildRecipe(mat: Material, piece_index: usize) ShapedRecipe {
    const mask = piece_patterns[piece_index];
    var pattern: [3][3]u16 = undefined;
    for (0..3) |row| {
        for (0..3) |col| {
            pattern[row][col] = if (mask[row][col] == 1) mat.id else 0;
        }
    }
    return .{
        .pattern = pattern,
        .result_item = mat.base_result + @as(u16, @intCast(piece_index)),
        .result_count = 1,
    };
}

fn generateRecipes() [20]ShapedRecipe {
    var result: [20]ShapedRecipe = undefined;
    var i: usize = 0;
    for (materials) |mat| {
        for (0..4) |piece| {
            result[i] = buildRecipe(mat, piece);
            i += 1;
        }
    }
    return result;
}

pub const recipes: [20]ShapedRecipe = generateRecipes();

test "recipe count" {
    try std.testing.expectEqual(@as(usize, 20), recipes.len);
}

test "leather helmet pattern" {
    const helmet = recipes[0];
    try std.testing.expectEqual(@as(u16, 282), helmet.result_item);
    try std.testing.expectEqual(@as(u8, 1), helmet.result_count);
    // Row 0: PPP
    try std.testing.expectEqual(@as(u16, 328), helmet.pattern[0][0]);
    try std.testing.expectEqual(@as(u16, 328), helmet.pattern[0][1]);
    try std.testing.expectEqual(@as(u16, 328), helmet.pattern[0][2]);
    // Row 1: P_P
    try std.testing.expectEqual(@as(u16, 328), helmet.pattern[1][0]);
    try std.testing.expectEqual(@as(u16, 0), helmet.pattern[1][1]);
    try std.testing.expectEqual(@as(u16, 328), helmet.pattern[1][2]);
    // Row 2: ___
    try std.testing.expectEqual(@as(u16, 0), helmet.pattern[2][0]);
    try std.testing.expectEqual(@as(u16, 0), helmet.pattern[2][1]);
    try std.testing.expectEqual(@as(u16, 0), helmet.pattern[2][2]);
}

test "diamond chestplate pattern" {
    const chestplate = recipes[13]; // Diamond is index 3, chestplate is piece 1 => 3*4+1=13
    try std.testing.expectEqual(@as(u16, 295), chestplate.result_item);
    // Row 0: P_P
    try std.testing.expectEqual(@as(u16, 324), chestplate.pattern[0][0]);
    try std.testing.expectEqual(@as(u16, 0), chestplate.pattern[0][1]);
    try std.testing.expectEqual(@as(u16, 324), chestplate.pattern[0][2]);
    // Row 1: PPP
    try std.testing.expectEqual(@as(u16, 324), chestplate.pattern[1][0]);
    try std.testing.expectEqual(@as(u16, 324), chestplate.pattern[1][1]);
    try std.testing.expectEqual(@as(u16, 324), chestplate.pattern[1][2]);
}

test "netherite boots pattern" {
    const boots = recipes[19]; // Netherite is index 4, boots is piece 3 => 4*4+3=19
    try std.testing.expectEqual(@as(u16, 301), boots.result_item);
    // Row 0: ___
    try std.testing.expectEqual(@as(u16, 0), boots.pattern[0][0]);
    // Row 1: P_P
    try std.testing.expectEqual(@as(u16, 327), boots.pattern[1][0]);
    try std.testing.expectEqual(@as(u16, 0), boots.pattern[1][1]);
    try std.testing.expectEqual(@as(u16, 327), boots.pattern[1][2]);
}

test "all result IDs are sequential" {
    for (recipes, 0..) |recipe, i| {
        try std.testing.expectEqual(@as(u16, 282 + @as(u16, @intCast(i))), recipe.result_item);
    }
}

test "all result counts are 1" {
    for (recipes) |recipe| {
        try std.testing.expectEqual(@as(u8, 1), recipe.result_count);
    }
}
