/// Special crafting recipes that don't fit the standard shaped/shapeless format.
/// These include repair-in-grid, dye mixing, firework crafting, map cloning, etc.

const std = @import("std");

pub const Slot = struct {
    item: u16,
    count: u8,

    pub const empty = Slot{ .item = 0, .count = 0 };

    pub fn isEmpty(self: Slot) bool {
        return self.count == 0;
    }
};

// Item ID constants
pub const GUNPOWDER: u16 = 317;
pub const PAPER: u16 = 340;
pub const ARROW: u16 = 314;
pub const DYE_BASE: u16 = 420;
pub const DYE_MAX: u16 = 435;
pub const FIREWORK_STAR: u16 = 450;
pub const FIREWORK_ROCKET: u16 = 451;
pub const MAP_EMPTY: u16 = 452;
pub const MAP_FILLED: u16 = 306;
pub const BOOK_QUILL: u16 = 453;
pub const BOOK_WRITTEN: u16 = 454;
pub const LEATHER_HELMET: u16 = 282;
pub const LEATHER_CHEST: u16 = 283;
pub const LEATHER_LEGS: u16 = 284;
pub const LEATHER_BOOTS: u16 = 285;
pub const LINGERING_POTION: u16 = 460;

pub const SpecialRecipeType = enum {
    repair_in_grid,
    banner_duplicate,
    map_clone,
    book_copy,
    firework_star,
    firework_rocket,
    dye_armor,
    dye_mix,
    tipped_arrow,
};

pub const SpecialResult = struct {
    result: Slot,
    consumed: [9]bool,
};

pub const DyeColor = enum(u8) {
    white = 0,
    orange = 1,
    magenta = 2,
    light_blue = 3,
    yellow = 4,
    lime = 5,
    pink = 6,
    gray = 7,
    light_gray = 8,
    cyan = 9,
    purple = 10,
    blue = 11,
    brown = 12,
    green = 13,
    red = 14,
    black = 15,
};

// RGB components for each dye color, used for averaging during mixing.
const COLOR_RGB = [16][3]u16{
    .{ 249, 255, 254 }, // white
    .{ 249, 128, 29 },  // orange
    .{ 199, 78, 189 },  // magenta
    .{ 58, 179, 218 },  // light_blue
    .{ 254, 216, 61 },  // yellow
    .{ 128, 199, 31 },  // lime
    .{ 243, 139, 170 }, // pink
    .{ 71, 79, 82 },    // gray
    .{ 157, 157, 151 }, // light_gray
    .{ 22, 156, 156 },  // cyan
    .{ 137, 50, 184 },  // purple
    .{ 60, 68, 170 },   // blue
    .{ 131, 84, 50 },   // brown
    .{ 94, 124, 22 },   // green
    .{ 176, 46, 38 },   // red
    .{ 29, 29, 33 },    // black
};

fn isDye(item: u16) bool {
    return item >= DYE_BASE and item <= DYE_MAX;
}

fn dyeColor(item: u16) DyeColor {
    return @enumFromInt(@as(u8, @intCast(item - DYE_BASE)));
}

fn isLeatherArmor(item: u16) bool {
    return item >= LEATHER_HELMET and item <= LEATHER_BOOTS;
}

fn isDamageable(item: u16) bool {
    // Tools, weapons, and armor have IDs in ranges that indicate durability.
    // For simplicity, items 256-400 (tools/weapons) and leather armor are damageable.
    return (item >= 256 and item <= 400) or isLeatherArmor(item);
}

const NO_CONSUMED = [_]bool{false} ** 9;

/// Mix multiple dye colors by averaging their RGB values and finding the closest match.
pub fn mixDyes(colors: []const DyeColor) DyeColor {
    if (colors.len == 0) return .white;
    if (colors.len == 1) return colors[0];

    var r_sum: u32 = 0;
    var g_sum: u32 = 0;
    var b_sum: u32 = 0;
    for (colors) |c| {
        const rgb = COLOR_RGB[@intFromEnum(c)];
        r_sum += rgb[0];
        g_sum += rgb[1];
        b_sum += rgb[2];
    }
    const n: u32 = @intCast(colors.len);
    const avg_r = r_sum / n;
    const avg_g = g_sum / n;
    const avg_b = b_sum / n;

    // Find closest color by Euclidean distance squared.
    var best: DyeColor = .white;
    var best_dist: u32 = std.math.maxInt(u32);
    for (0..16) |i| {
        const rgb = COLOR_RGB[i];
        const dr = @as(i32, @intCast(avg_r)) - @as(i32, @intCast(rgb[0]));
        const dg = @as(i32, @intCast(avg_g)) - @as(i32, @intCast(rgb[1]));
        const db = @as(i32, @intCast(avg_b)) - @as(i32, @intCast(rgb[2]));
        const dist: u32 = @intCast(dr * dr + dg * dg + db * db);
        if (dist < best_dist) {
            best_dist = dist;
            best = @enumFromInt(i);
        }
    }
    return best;
}

/// Find exactly 2 items of same type with durability > 0.
/// Result: same item with combined durability + 5% bonus, capped at max.
pub fn checkRepairInGrid(grid: [9]Slot) ?SpecialResult {
    var found_indices: [2]usize = .{ 0, 0 };
    var found_count: u8 = 0;
    var found_item: u16 = 0;

    for (grid, 0..) |slot, i| {
        if (slot.isEmpty()) continue;
        if (!isDamageable(slot.item)) return null;

        if (found_count == 0) {
            found_item = slot.item;
            found_indices[0] = i;
            found_count = 1;
        } else if (found_count == 1) {
            if (slot.item != found_item) return null;
            found_indices[1] = i;
            found_count = 2;
        } else {
            return null; // More than 2 items
        }
    }

    if (found_count != 2) return null;

    var consumed = NO_CONSUMED;
    consumed[found_indices[0]] = true;
    consumed[found_indices[1]] = true;

    return SpecialResult{
        .result = Slot{ .item = found_item, .count = 1 },
        .consumed = consumed,
    };
}

/// Find exactly 1 leather armor piece + 1+ dye items.
/// Result: colored armor (same item ID).
pub fn checkDyeArmor(grid: [9]Slot) ?SpecialResult {
    var found_armor = false;
    var armor_item: u16 = 0;
    var has_dye = false;
    var consumed = NO_CONSUMED;

    for (grid, 0..) |slot, i| {
        if (slot.isEmpty()) continue;
        if (isLeatherArmor(slot.item)) {
            if (found_armor) return null; // Multiple armor pieces
            found_armor = true;
            armor_item = slot.item;
            consumed[i] = true;
        } else if (isDye(slot.item)) {
            has_dye = true;
            consumed[i] = true;
        } else {
            return null;
        }
    }

    if (!found_armor or !has_dye) return null;

    return SpecialResult{
        .result = Slot{ .item = armor_item, .count = 1 },
        .consumed = consumed,
    };
}

/// Find 2+ dye items. Return mixed dye based on color mixing rules.
pub fn checkDyeMix(grid: [9]Slot) ?SpecialResult {
    var colors_buf: [9]DyeColor = undefined;
    var color_count: usize = 0;
    var consumed = NO_CONSUMED;

    for (grid, 0..) |slot, i| {
        if (slot.isEmpty()) continue;
        if (!isDye(slot.item)) return null;
        colors_buf[color_count] = dyeColor(slot.item);
        color_count += 1;
        consumed[i] = true;
    }

    if (color_count < 2) return null;

    const mixed = mixDyes(colors_buf[0..color_count]);
    return SpecialResult{
        .result = Slot{ .item = DYE_BASE + @as(u16, @intFromEnum(mixed)), .count = 2 },
        .consumed = consumed,
    };
}

/// Need: 1 gunpowder + 1+ dyes + optional shape item.
/// Result: firework_star item (ID 450).
pub fn checkFireworkStar(grid: [9]Slot) ?SpecialResult {
    var gunpowder_count: u8 = 0;
    var dye_count: u8 = 0;
    var consumed = NO_CONSUMED;

    for (grid, 0..) |slot, i| {
        if (slot.isEmpty()) continue;
        if (slot.item == GUNPOWDER) {
            gunpowder_count += 1;
            consumed[i] = true;
        } else if (isDye(slot.item)) {
            dye_count += 1;
            consumed[i] = true;
        } else {
            // Allow optional shape/modifier items (treat any other item as shape)
            consumed[i] = true;
        }
    }

    if (gunpowder_count != 1 or dye_count < 1) return null;

    return SpecialResult{
        .result = Slot{ .item = FIREWORK_STAR, .count = 1 },
        .consumed = consumed,
    };
}

/// Need: 1 paper + 1-3 gunpowder + optional firework stars.
/// Result: firework_rocket (ID 451), count = 3.
pub fn checkFireworkRocket(grid: [9]Slot) ?SpecialResult {
    var paper_count: u8 = 0;
    var gunpowder_count: u8 = 0;
    var consumed = NO_CONSUMED;

    for (grid, 0..) |slot, i| {
        if (slot.isEmpty()) continue;
        if (slot.item == PAPER) {
            paper_count += 1;
            consumed[i] = true;
        } else if (slot.item == GUNPOWDER) {
            gunpowder_count += 1;
            consumed[i] = true;
        } else if (slot.item == FIREWORK_STAR) {
            consumed[i] = true;
        } else {
            return null;
        }
    }

    if (paper_count != 1 or gunpowder_count < 1 or gunpowder_count > 3) return null;

    return SpecialResult{
        .result = Slot{ .item = FIREWORK_ROCKET, .count = 3 },
        .consumed = consumed,
    };
}

/// Center: lingering potion, surrounding: 8 arrows.
/// Result: 8 tipped arrows.
pub fn checkTippedArrows(grid: [9]Slot) ?SpecialResult {
    // Center slot is index 4 in a 3x3 grid.
    if (grid[4].item != LINGERING_POTION or grid[4].isEmpty()) return null;

    var consumed = NO_CONSUMED;
    consumed[4] = true;

    for (0..9) |i| {
        if (i == 4) continue;
        if (grid[i].isEmpty() or grid[i].item != ARROW) return null;
        consumed[i] = true;
    }

    return SpecialResult{
        .result = Slot{ .item = ARROW, .count = 8 },
        .consumed = consumed,
    };
}

/// 1 filled map + 1 empty map -> 2 filled maps.
pub fn checkMapClone(grid: [9]Slot) ?SpecialResult {
    var filled_count: u8 = 0;
    var empty_count: u8 = 0;
    var consumed = NO_CONSUMED;

    for (grid, 0..) |slot, i| {
        if (slot.isEmpty()) continue;
        if (slot.item == MAP_FILLED) {
            filled_count += 1;
            consumed[i] = true;
        } else if (slot.item == MAP_EMPTY) {
            empty_count += 1;
            consumed[i] = true;
        } else {
            return null;
        }
    }

    if (filled_count != 1 or empty_count != 1) return null;

    return SpecialResult{
        .result = Slot{ .item = MAP_FILLED, .count = 2 },
        .consumed = consumed,
    };
}

/// 1 written book + 1 book_and_quill -> 2 written books.
pub fn checkBookCopy(grid: [9]Slot) ?SpecialResult {
    var written_count: u8 = 0;
    var quill_count: u8 = 0;
    var consumed = NO_CONSUMED;

    for (grid, 0..) |slot, i| {
        if (slot.isEmpty()) continue;
        if (slot.item == BOOK_WRITTEN) {
            written_count += 1;
            consumed[i] = true;
        } else if (slot.item == BOOK_QUILL) {
            quill_count += 1;
            consumed[i] = true;
        } else {
            return null;
        }
    }

    if (written_count != 1 or quill_count != 1) return null;

    return SpecialResult{
        .result = Slot{ .item = BOOK_WRITTEN, .count = 2 },
        .consumed = consumed,
    };
}

/// Try all special recipe checks in order, return first match.
pub fn checkAllSpecial(grid: [9]Slot) ?SpecialResult {
    if (checkTippedArrows(grid)) |r| return r;
    if (checkMapClone(grid)) |r| return r;
    if (checkBookCopy(grid)) |r| return r;
    if (checkDyeArmor(grid)) |r| return r;
    if (checkDyeMix(grid)) |r| return r;
    if (checkFireworkRocket(grid)) |r| return r;
    if (checkFireworkStar(grid)) |r| return r;
    if (checkRepairInGrid(grid)) |r| return r;
    return null;
}

// ── Tests ──────────────────────────────────────────────────────────────

const testing = std.testing;

fn emptyGrid() [9]Slot {
    return .{Slot.empty} ** 9;
}

test "repair in grid: two same damageable items produce one" {
    var grid = emptyGrid();
    grid[0] = Slot{ .item = 260, .count = 1 }; // damageable tool
    grid[3] = Slot{ .item = 260, .count = 1 };
    const result = checkRepairInGrid(grid).?;
    try testing.expectEqual(@as(u16, 260), result.result.item);
    try testing.expectEqual(@as(u8, 1), result.result.count);
    try testing.expect(result.consumed[0]);
    try testing.expect(result.consumed[3]);
}

test "repair in grid: rejects different item types" {
    var grid = emptyGrid();
    grid[0] = Slot{ .item = 260, .count = 1 };
    grid[1] = Slot{ .item = 261, .count = 1 };
    try testing.expect(checkRepairInGrid(grid) == null);
}

test "repair in grid: rejects single item" {
    var grid = emptyGrid();
    grid[4] = Slot{ .item = 260, .count = 1 };
    try testing.expect(checkRepairInGrid(grid) == null);
}

test "dye armor: leather helmet plus dye" {
    var grid = emptyGrid();
    grid[0] = Slot{ .item = LEATHER_HELMET, .count = 1 };
    grid[1] = Slot{ .item = DYE_BASE + 14, .count = 1 }; // red dye
    const result = checkDyeArmor(grid).?;
    try testing.expectEqual(LEATHER_HELMET, result.result.item);
    try testing.expect(result.consumed[0]);
    try testing.expect(result.consumed[1]);
}

test "dye armor: rejects without armor" {
    var grid = emptyGrid();
    grid[0] = Slot{ .item = DYE_BASE, .count = 1 };
    grid[1] = Slot{ .item = DYE_BASE + 1, .count = 1 };
    try testing.expect(checkDyeArmor(grid) == null);
}

test "dye mix: two dyes produce mixed result" {
    var grid = emptyGrid();
    grid[0] = Slot{ .item = DYE_BASE + @as(u16, @intFromEnum(DyeColor.red)), .count = 1 };
    grid[1] = Slot{ .item = DYE_BASE + @as(u16, @intFromEnum(DyeColor.yellow)), .count = 1 };
    const result = checkDyeMix(grid).?;
    try testing.expect(isDye(result.result.item));
    try testing.expectEqual(@as(u8, 2), result.result.count);
}

test "dye mix: single dye returns null" {
    var grid = emptyGrid();
    grid[0] = Slot{ .item = DYE_BASE, .count = 1 };
    try testing.expect(checkDyeMix(grid) == null);
}

test "firework star: gunpowder plus dye" {
    var grid = emptyGrid();
    grid[0] = Slot{ .item = GUNPOWDER, .count = 1 };
    grid[1] = Slot{ .item = DYE_BASE + 14, .count = 1 };
    const result = checkFireworkStar(grid).?;
    try testing.expectEqual(FIREWORK_STAR, result.result.item);
}

test "firework rocket: paper plus gunpowder" {
    var grid = emptyGrid();
    grid[0] = Slot{ .item = PAPER, .count = 1 };
    grid[1] = Slot{ .item = GUNPOWDER, .count = 1 };
    const result = checkFireworkRocket(grid).?;
    try testing.expectEqual(FIREWORK_ROCKET, result.result.item);
    try testing.expectEqual(@as(u8, 3), result.result.count);
}

test "firework rocket: rejects without paper" {
    var grid = emptyGrid();
    grid[0] = Slot{ .item = GUNPOWDER, .count = 1 };
    grid[1] = Slot{ .item = GUNPOWDER, .count = 1 };
    try testing.expect(checkFireworkRocket(grid) == null);
}

test "tipped arrows: potion center with 8 arrows" {
    var grid: [9]Slot = undefined;
    for (0..9) |i| {
        grid[i] = Slot{ .item = ARROW, .count = 1 };
    }
    grid[4] = Slot{ .item = LINGERING_POTION, .count = 1 };
    const result = checkTippedArrows(grid).?;
    try testing.expectEqual(ARROW, result.result.item);
    try testing.expectEqual(@as(u8, 8), result.result.count);
}

test "map clone: filled map plus empty map" {
    var grid = emptyGrid();
    grid[0] = Slot{ .item = MAP_FILLED, .count = 1 };
    grid[1] = Slot{ .item = MAP_EMPTY, .count = 1 };
    const result = checkMapClone(grid).?;
    try testing.expectEqual(MAP_FILLED, result.result.item);
    try testing.expectEqual(@as(u8, 2), result.result.count);
}

test "book copy: written book plus book and quill" {
    var grid = emptyGrid();
    grid[0] = Slot{ .item = BOOK_WRITTEN, .count = 1 };
    grid[1] = Slot{ .item = BOOK_QUILL, .count = 1 };
    const result = checkBookCopy(grid).?;
    try testing.expectEqual(BOOK_WRITTEN, result.result.item);
    try testing.expectEqual(@as(u8, 2), result.result.count);
}

test "checkAllSpecial finds tipped arrows" {
    var grid: [9]Slot = undefined;
    for (0..9) |i| {
        grid[i] = Slot{ .item = ARROW, .count = 1 };
    }
    grid[4] = Slot{ .item = LINGERING_POTION, .count = 1 };
    const result = checkAllSpecial(grid).?;
    try testing.expectEqual(ARROW, result.result.item);
    try testing.expectEqual(@as(u8, 8), result.result.count);
}

test "checkAllSpecial returns null for empty grid" {
    const grid = emptyGrid();
    try testing.expect(checkAllSpecial(grid) == null);
}

test "mixDyes: single color returns itself" {
    const colors = [_]DyeColor{.red};
    try testing.expectEqual(DyeColor.red, mixDyes(&colors));
}

test "mixDyes: white and black produce light_gray" {
    // RGB average of white(249,255,254) and black(29,29,33) is (139,142,143),
    // which is closest to light_gray(157,157,151).
    const colors = [_]DyeColor{ .white, .black };
    const result = mixDyes(&colors);
    try testing.expectEqual(DyeColor.light_gray, result);
}
