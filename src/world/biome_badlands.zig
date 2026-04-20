const std = @import("std");

pub const TERRACOTTA_BANDS: [6]u8 = .{ 60, 61, 62, 63, 64, 65 };

pub const BadlandsFeatures = struct {
    base_height: f64 = 10.0,
    height_scale: f64 = 2.0,
    temperature: f32 = 2.0,
    surface_block: u8 = 6,
    has_gold_above_32: bool = true,
    no_rain: bool = true,
};

pub const BadlandsColumn = struct {
    heights: [16]u8,
    layers: [16][64]u8,
};

pub fn getTerracottaLayer(y: u8) u8 {
    return TERRACOTTA_BANDS[y % 6];
}

pub fn generateTerrain(column_x: i32, column_z: i32, seed: u64) BadlandsColumn {
    var column: BadlandsColumn = undefined;
    const mixed = seed ^ @as(u64, @bitCast(@as(i64, column_x) *% 31)) ^ @as(u64, @bitCast(@as(i64, column_z) *% 17));

    for (0..16) |x| {
        const noise_input = mixed +% @as(u64, x) *% 7;
        const height: u8 = @intCast(48 + @as(u8, @truncate(noise_input % 16)));
        column.heights[x] = height;

        for (0..64) |y| {
            column.layers[x][y] = if (y <= height) getTerracottaLayer(@intCast(y)) else 0;
        }
    }

    return column;
}

pub fn getSurfaceMineshaftChance() f32 {
    return 0.04;
}

pub fn getGoldOreRange() struct { min_y: u8, max_y: u8 } {
    return .{ .min_y = 0, .max_y = 79 };
}

test "terracotta band cycling" {
    try std.testing.expectEqual(@as(u8, 60), getTerracottaLayer(0));
    try std.testing.expectEqual(@as(u8, 61), getTerracottaLayer(1));
    try std.testing.expectEqual(@as(u8, 62), getTerracottaLayer(2));
    try std.testing.expectEqual(@as(u8, 63), getTerracottaLayer(3));
    try std.testing.expectEqual(@as(u8, 64), getTerracottaLayer(4));
    try std.testing.expectEqual(@as(u8, 65), getTerracottaLayer(5));
    try std.testing.expectEqual(@as(u8, 60), getTerracottaLayer(6));
    try std.testing.expectEqual(@as(u8, 61), getTerracottaLayer(7));
    try std.testing.expectEqual(@as(u8, 62), getTerracottaLayer(14));
    try std.testing.expectEqual(@as(u8, 60), getTerracottaLayer(12));
}

test "no rain flag" {
    const features = BadlandsFeatures{};
    try std.testing.expect(features.no_rain);
    try std.testing.expectEqual(@as(f32, 2.0), features.temperature);
}

test "gold ore range" {
    const range = getGoldOreRange();
    try std.testing.expectEqual(@as(u8, 0), range.min_y);
    try std.testing.expectEqual(@as(u8, 79), range.max_y);
    try std.testing.expect(range.max_y > 31);
}

test "surface mineshaft chance higher than normal" {
    const chance = getSurfaceMineshaftChance();
    try std.testing.expect(chance > 0.01);
}
