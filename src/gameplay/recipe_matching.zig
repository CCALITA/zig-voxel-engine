/// Recipe matching system with pattern normalization, horizontal mirroring,
/// ingredient group tags, and shifted matching.
///
/// Uses u16 for ItemId; 0 represents an empty cell.

const std = @import("std");

// ---------------------------------------------------------------------------
// Ingredient group tags (wildcards)
// ---------------------------------------------------------------------------

pub const ANY_PLANKS: u16 = 0xF001;
pub const ANY_LOG: u16 = 0xF002;
pub const ANY_WOOL: u16 = 0xF003;
pub const ANY_STONE: u16 = 0xF004;

// Concrete block IDs used by tag groups.
const oak_planks: u16 = 5;
const spruce_planks: u16 = 134;
const birch_planks: u16 = 135;
const jungle_planks: u16 = 136;
const acacia_planks: u16 = 163;
const dark_oak_planks: u16 = 164;

const oak_log: u16 = 8;
const spruce_log: u16 = 137;
const birch_log: u16 = 138;
const jungle_log: u16 = 139;

const white_wool: u16 = 35;
const orange_wool: u16 = 36;
const magenta_wool: u16 = 37;
const light_blue_wool: u16 = 38;

const stone: u16 = 1;
const cobblestone: u16 = 4;
const granite: u16 = 140;
const diorite: u16 = 141;
const andesite: u16 = 142;

// ---------------------------------------------------------------------------
// ShapedRecipe
// ---------------------------------------------------------------------------

pub const ShapedRecipe = struct {
    pattern: [3][3]u16, // 0 = empty cell, item IDs for ingredients
    result_item: u16,
    result_count: u8,
};

// ---------------------------------------------------------------------------
// Grid helpers
// ---------------------------------------------------------------------------

const Grid = [3][3]u16;

const empty_grid: Grid = .{
    .{ 0, 0, 0 },
    .{ 0, 0, 0 },
    .{ 0, 0, 0 },
};

/// Shift non-empty content to the top-left corner of the 3x3 grid.
pub fn normalizeGrid(grid: Grid) Grid {
    var min_row: usize = 3;
    var min_col: usize = 3;
    var max_row: usize = 0;
    var max_col: usize = 0;

    for (0..3) |r| {
        for (0..3) |c| {
            if (grid[r][c] != 0) {
                if (r < min_row) min_row = r;
                if (r > max_row) max_row = r;
                if (c < min_col) min_col = c;
                if (c > max_col) max_col = c;
            }
        }
    }

    // No non-zero cells found (min_row stayed at sentinel value 3).
    if (min_row > max_row) return empty_grid;

    var result = empty_grid;
    for (min_row..max_row + 1) |r| {
        for (min_col..max_col + 1) |c| {
            result[r - min_row][c - min_col] = grid[r][c];
        }
    }
    return result;
}

/// Horizontal mirror (flip left-right). Column 0 <-> 2, column 1 stays.
pub fn mirrorGrid(grid: Grid) Grid {
    var result: Grid = undefined;
    for (0..3) |r| {
        result[r][0] = grid[r][2];
        result[r][1] = grid[r][1];
        result[r][2] = grid[r][0];
    }
    return result;
}

// ---------------------------------------------------------------------------
// Cell matching (with tag wildcards)
// ---------------------------------------------------------------------------

fn cellsMatch(pattern_cell: u16, grid_cell: u16) bool {
    if (pattern_cell == 0 and grid_cell == 0) return true;
    if (pattern_cell == 0 or grid_cell == 0) return false;

    if (pattern_cell >= 0xF000) {
        return isInGroup(pattern_cell, grid_cell);
    }
    return pattern_cell == grid_cell;
}

fn isInGroup(tag: u16, id: u16) bool {
    return switch (tag) {
        ANY_PLANKS => id == oak_planks or id == spruce_planks or id == birch_planks or id == jungle_planks or id == acacia_planks or id == dark_oak_planks,
        ANY_LOG => id == oak_log or id == spruce_log or id == birch_log or id == jungle_log,
        ANY_WOOL => id == white_wool or id == orange_wool or id == magenta_wool or id == light_blue_wool,
        ANY_STONE => id == stone or id == cobblestone or id == granite or id == diorite or id == andesite,
        else => false,
    };
}

fn gridsMatch(pattern: Grid, grid: Grid) bool {
    for (0..3) |r| {
        for (0..3) |c| {
            if (!cellsMatch(pattern[r][c], grid[r][c])) return false;
        }
    }
    return true;
}

// ---------------------------------------------------------------------------
// Recipe matching
// ---------------------------------------------------------------------------

/// Normalize the input grid, then compare against each recipe's normalized
/// pattern. If no match, try the mirrored grid. Returns the first match or null.
pub fn matchRecipe(grid: Grid, recipes: []const ShapedRecipe) ?ShapedRecipe {
    const norm = normalizeGrid(grid);
    const mirrored = normalizeGrid(mirrorGrid(grid));

    for (recipes) |recipe| {
        const norm_pattern = normalizeGrid(recipe.pattern);
        if (gridsMatch(norm_pattern, norm)) return recipe;
        if (gridsMatch(norm_pattern, mirrored)) return recipe;
    }
    return null;
}

/// Try matching at all 9 possible shift positions (0-2 rows, 0-2 cols),
/// plus mirrored at each position.
pub fn matchRecipeShifted(grid: Grid, recipes: []const ShapedRecipe) ?ShapedRecipe {
    for (0..3) |dr| {
        for (0..3) |dc| {
            const shifted = shiftGrid(grid, dr, dc);
            const norm = normalizeGrid(shifted);
            const mirrored = normalizeGrid(mirrorGrid(shifted));

            for (recipes) |recipe| {
                // normalizeGrid is pure and cheap on a 3x3 grid, but hoist
                // if the recipe list grows large in the future.
                const norm_pattern = normalizeGrid(recipe.pattern);
                if (gridsMatch(norm_pattern, norm)) return recipe;
                if (gridsMatch(norm_pattern, mirrored)) return recipe;
            }
        }
    }
    return null;
}

fn shiftGrid(grid: Grid, dr: usize, dc: usize) Grid {
    var result = empty_grid;
    for (0..3) |r| {
        for (0..3) |c| {
            if (r + dr < 3 and c + dc < 3) {
                result[r][c] = grid[r + dr][c + dc];
            }
        }
    }
    return result;
}

// ===========================================================================
// Tests
// ===========================================================================

test "normalizeGrid - empty grid returns empty" {
    const result = normalizeGrid(empty_grid);
    try std.testing.expectEqual(empty_grid, result);
}

test "normalizeGrid - already top-left stays unchanged" {
    const grid: Grid = .{
        .{ 1, 2, 0 },
        .{ 3, 0, 0 },
        .{ 0, 0, 0 },
    };
    try std.testing.expectEqual(grid, normalizeGrid(grid));
}

test "normalizeGrid - shifts bottom-right content to top-left" {
    const grid: Grid = .{
        .{ 0, 0, 0 },
        .{ 0, 0, 5 },
        .{ 0, 0, 8 },
    };
    const expected: Grid = .{
        .{ 5, 0, 0 },
        .{ 8, 0, 0 },
        .{ 0, 0, 0 },
    };
    try std.testing.expectEqual(expected, normalizeGrid(grid));
}

test "normalizeGrid - center block shifts to top-left" {
    const grid: Grid = .{
        .{ 0, 0, 0 },
        .{ 0, 7, 0 },
        .{ 0, 0, 0 },
    };
    const expected: Grid = .{
        .{ 7, 0, 0 },
        .{ 0, 0, 0 },
        .{ 0, 0, 0 },
    };
    try std.testing.expectEqual(expected, normalizeGrid(grid));
}

test "mirrorGrid - flips columns 0 and 2" {
    const grid: Grid = .{
        .{ 1, 2, 3 },
        .{ 4, 5, 6 },
        .{ 7, 8, 9 },
    };
    const expected: Grid = .{
        .{ 3, 2, 1 },
        .{ 6, 5, 4 },
        .{ 9, 8, 7 },
    };
    try std.testing.expectEqual(expected, mirrorGrid(grid));
}

test "mirrorGrid - empty grid stays empty" {
    try std.testing.expectEqual(empty_grid, mirrorGrid(empty_grid));
}

test "matchRecipe - empty grid returns null" {
    const recipes = [_]ShapedRecipe{.{
        .pattern = .{ .{ 5, 5, 0 }, .{ 5, 5, 0 }, .{ 0, 0, 0 } },
        .result_item = 110,
        .result_count = 1,
    }};
    try std.testing.expectEqual(@as(?ShapedRecipe, null), matchRecipe(empty_grid, &recipes));
}

test "matchRecipe - exact match works" {
    const recipe = ShapedRecipe{
        .pattern = .{ .{ 5, 5, 0 }, .{ 5, 5, 0 }, .{ 0, 0, 0 } },
        .result_item = 110,
        .result_count = 1,
    };
    const recipes = [_]ShapedRecipe{recipe};
    const grid: Grid = .{ .{ 5, 5, 0 }, .{ 5, 5, 0 }, .{ 0, 0, 0 } };
    const result = matchRecipe(grid, &recipes);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(u16, 110), result.?.result_item);
}

test "matchRecipe - shifted input matches after normalization" {
    const recipe = ShapedRecipe{
        .pattern = .{ .{ 5, 0, 0 }, .{ 5, 0, 0 }, .{ 0, 0, 0 } },
        .result_item = 256,
        .result_count = 4,
    };
    const recipes = [_]ShapedRecipe{recipe};
    // Place sticks in column 2 instead of column 0
    const grid: Grid = .{ .{ 0, 0, 5 }, .{ 0, 0, 5 }, .{ 0, 0, 0 } };
    const result = matchRecipe(grid, &recipes);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(u16, 256), result.?.result_item);
}

test "matchRecipe - mirrored match works" {
    const recipe = ShapedRecipe{
        .pattern = .{ .{ 5, 8, 0 }, .{ 0, 0, 0 }, .{ 0, 0, 0 } },
        .result_item = 99,
        .result_count = 1,
    };
    const recipes = [_]ShapedRecipe{recipe};
    // Mirrored: 8, 5 in row 0
    const grid: Grid = .{ .{ 8, 5, 0 }, .{ 0, 0, 0 }, .{ 0, 0, 0 } };
    const result = matchRecipe(grid, &recipes);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(u16, 99), result.?.result_item);
}

test "matchRecipe - no false positives" {
    const recipe = ShapedRecipe{
        .pattern = .{ .{ 5, 5, 0 }, .{ 5, 5, 0 }, .{ 0, 0, 0 } },
        .result_item = 110,
        .result_count = 1,
    };
    const recipes = [_]ShapedRecipe{recipe};
    // Only 3 planks instead of 4
    const grid: Grid = .{ .{ 5, 5, 0 }, .{ 5, 0, 0 }, .{ 0, 0, 0 } };
    try std.testing.expectEqual(@as(?ShapedRecipe, null), matchRecipe(grid, &recipes));
}

test "matchRecipe - wrong item is not matched" {
    const recipe = ShapedRecipe{
        .pattern = .{ .{ 5, 0, 0 }, .{ 0, 0, 0 }, .{ 0, 0, 0 } },
        .result_item = 10,
        .result_count = 1,
    };
    const recipes = [_]ShapedRecipe{recipe};
    const grid: Grid = .{ .{ 8, 0, 0 }, .{ 0, 0, 0 }, .{ 0, 0, 0 } };
    try std.testing.expectEqual(@as(?ShapedRecipe, null), matchRecipe(grid, &recipes));
}

test "cellsMatch - ANY_PLANKS matches oak_planks" {
    try std.testing.expect(cellsMatch(ANY_PLANKS, oak_planks));
}

test "cellsMatch - ANY_PLANKS matches spruce_planks" {
    try std.testing.expect(cellsMatch(ANY_PLANKS, spruce_planks));
}

test "cellsMatch - ANY_LOG matches oak_log" {
    try std.testing.expect(cellsMatch(ANY_LOG, oak_log));
}

test "cellsMatch - ANY_STONE matches cobblestone" {
    try std.testing.expect(cellsMatch(ANY_STONE, cobblestone));
}

test "cellsMatch - ANY_WOOL matches white_wool" {
    try std.testing.expect(cellsMatch(ANY_WOOL, white_wool));
}

test "cellsMatch - tag does not match unrelated item" {
    try std.testing.expect(!cellsMatch(ANY_PLANKS, oak_log));
}

test "matchRecipe - wildcard tag recipe matches variant" {
    const recipe = ShapedRecipe{
        .pattern = .{ .{ ANY_PLANKS, ANY_PLANKS, 0 }, .{ ANY_PLANKS, ANY_PLANKS, 0 }, .{ 0, 0, 0 } },
        .result_item = 110,
        .result_count = 1,
    };
    const recipes = [_]ShapedRecipe{recipe};
    // Use spruce planks
    const grid: Grid = .{ .{ spruce_planks, spruce_planks, 0 }, .{ spruce_planks, spruce_planks, 0 }, .{ 0, 0, 0 } };
    const result = matchRecipe(grid, &recipes);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(u16, 110), result.?.result_item);
}

test "matchRecipeShifted - matches pattern placed in bottom-right" {
    const recipe = ShapedRecipe{
        .pattern = .{ .{ 5, 5, 0 }, .{ 0, 0, 0 }, .{ 0, 0, 0 } },
        .result_item = 50,
        .result_count = 1,
    };
    const recipes = [_]ShapedRecipe{recipe};
    // Place in bottom-right corner
    const grid: Grid = .{ .{ 0, 0, 0 }, .{ 0, 0, 0 }, .{ 0, 5, 5 } };
    const result = matchRecipeShifted(grid, &recipes);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(u16, 50), result.?.result_item);
}

test "matchRecipeShifted - mirrored at shifted position" {
    const recipe = ShapedRecipe{
        .pattern = .{ .{ 5, 8, 0 }, .{ 0, 0, 0 }, .{ 0, 0, 0 } },
        .result_item = 77,
        .result_count = 1,
    };
    const recipes = [_]ShapedRecipe{recipe};
    // Mirror of (5,8) is (8,5), placed at row 2
    const grid: Grid = .{ .{ 0, 0, 0 }, .{ 0, 0, 0 }, .{ 8, 5, 0 } };
    const result = matchRecipeShifted(grid, &recipes);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(u16, 77), result.?.result_item);
}

test "matchRecipeShifted - no false positive with partial overlap" {
    const recipe = ShapedRecipe{
        .pattern = .{ .{ 5, 5, 5 }, .{ 0, 0, 0 }, .{ 0, 0, 0 } },
        .result_item = 60,
        .result_count = 1,
    };
    const recipes = [_]ShapedRecipe{recipe};
    // Only 2 planks
    const grid: Grid = .{ .{ 0, 0, 0 }, .{ 0, 5, 5 }, .{ 0, 0, 0 } };
    try std.testing.expectEqual(@as(?ShapedRecipe, null), matchRecipeShifted(grid, &recipes));
}
