const std = @import("std");
const decorations = @import("decorations.zig");

pub const PaintingSize = decorations.PaintingSize;

const PaintingEntry = struct {
    name: [24]u8,
    name_len: u8,
    width: u8,
    height: u8,
};

fn makeEntry(comptime n: []const u8, comptime w: u8, comptime h: u8) PaintingEntry {
    var buf: [24]u8 = [_]u8{0} ** 24;
    for (n, 0..) |c, i| {
        buf[i] = c;
    }
    return .{
        .name = buf,
        .name_len = n.len,
        .width = w,
        .height = h,
    };
}

pub const PAINTING_CATALOG: [26]PaintingEntry = .{
    makeEntry("kebab", 1, 1),
    makeEntry("aztec", 1, 1),
    makeEntry("alban", 1, 1),
    makeEntry("aztec2", 1, 1),
    makeEntry("bomb", 1, 1),
    makeEntry("plant", 1, 1),
    makeEntry("wasteland", 1, 1),
    makeEntry("pool", 2, 1),
    makeEntry("courbet", 2, 1),
    makeEntry("sea", 2, 1),
    makeEntry("sunset", 2, 1),
    makeEntry("creebet", 2, 1),
    makeEntry("wanderer", 1, 2),
    makeEntry("graham", 1, 2),
    makeEntry("match", 2, 2),
    makeEntry("bust", 2, 2),
    makeEntry("stage", 2, 2),
    makeEntry("void_p", 2, 2),
    makeEntry("skull_and_roses", 2, 2),
    makeEntry("wither", 2, 2),
    makeEntry("fighters", 4, 2),
    makeEntry("pointer", 4, 4),
    makeEntry("pigscene", 4, 4),
    makeEntry("burning_skull", 4, 4),
    makeEntry("skeleton", 4, 3),
    makeEntry("donkey_kong", 4, 3),
};

pub const FittingResult = struct {
    indices: [26]u8,
    count: u8,
};

pub fn getPaintingDef(index: u8) ?struct { name: []const u8, width: u8, height: u8 } {
    if (index >= PAINTING_CATALOG.len) return null;
    const entry = PAINTING_CATALOG[index];
    return .{
        .name = entry.name[0..entry.name_len],
        .width = entry.width,
        .height = entry.height,
    };
}

pub fn findFittingPaintings(wall_width: u8, wall_height: u8) FittingResult {
    var result = FittingResult{
        .indices = [_]u8{0} ** 26,
        .count = 0,
    };
    for (PAINTING_CATALOG, 0..) |entry, i| {
        if (entry.width <= wall_width and entry.height <= wall_height) {
            result.indices[result.count] = @intCast(i);
            result.count += 1;
        }
    }
    return result;
}

pub fn selectRandomPainting(fitting: FittingResult, seed: u64) u8 {
    if (fitting.count == 0) return 0;
    const index: u8 = @intCast(seed % fitting.count);
    return fitting.indices[index];
}

test "catalog has 26 entries" {
    try std.testing.expectEqual(@as(usize, 26), PAINTING_CATALOG.len);
}

test "1x1 fits anywhere" {
    const result = findFittingPaintings(1, 1);
    try std.testing.expect(result.count >= 7);
    for (result.indices[0..result.count]) |idx| {
        const def = getPaintingDef(idx).?;
        try std.testing.expect(def.width <= 1);
        try std.testing.expect(def.height <= 1);
    }
}

test "4x4 needs large wall" {
    const small = findFittingPaintings(2, 2);
    for (small.indices[0..small.count]) |idx| {
        const def = getPaintingDef(idx).?;
        try std.testing.expect(def.width <= 2);
        try std.testing.expect(def.height <= 2);
    }

    const large = findFittingPaintings(4, 4);
    try std.testing.expect(large.count > small.count);

    var has_4x4 = false;
    for (large.indices[0..large.count]) |idx| {
        const def = getPaintingDef(idx).?;
        if (def.width == 4 and def.height == 4) {
            has_4x4 = true;
            break;
        }
    }
    try std.testing.expect(has_4x4);
}

test "selection from valid set" {
    const fitting = findFittingPaintings(4, 4);
    try std.testing.expect(fitting.count > 0);

    const selected = selectRandomPainting(fitting, 42);
    try std.testing.expect(selected < PAINTING_CATALOG.len);

    var found = false;
    for (fitting.indices[0..fitting.count]) |idx| {
        if (idx == selected) {
            found = true;
            break;
        }
    }
    try std.testing.expect(found);
}

test "getPaintingDef returns null for out of range" {
    try std.testing.expectEqual(getPaintingDef(26), null);
    try std.testing.expectEqual(getPaintingDef(255), null);
}

test "getPaintingDef returns correct data" {
    const kebab = getPaintingDef(0).?;
    try std.testing.expectEqualStrings("kebab", kebab.name);
    try std.testing.expectEqual(@as(u8, 1), kebab.width);
    try std.testing.expectEqual(@as(u8, 1), kebab.height);

    const donkey_kong = getPaintingDef(25).?;
    try std.testing.expectEqualStrings("donkey_kong", donkey_kong.name);
    try std.testing.expectEqual(@as(u8, 4), donkey_kong.width);
    try std.testing.expectEqual(@as(u8, 3), donkey_kong.height);
}

test "findFittingPaintings returns all for large wall" {
    const result = findFittingPaintings(255, 255);
    try std.testing.expectEqual(@as(u8, 26), result.count);
}

test "selectRandomPainting with different seeds" {
    const fitting = findFittingPaintings(4, 4);
    const a = selectRandomPainting(fitting, 0);
    const b = selectRandomPainting(fitting, 1);
    try std.testing.expect(a < PAINTING_CATALOG.len);
    try std.testing.expect(b < PAINTING_CATALOG.len);
}
