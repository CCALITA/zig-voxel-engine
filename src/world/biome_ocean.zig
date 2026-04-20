/// Ocean biome variants: warm, lukewarm, cold, frozen with deep counterparts.
const std = @import("std");

pub const OceanVariant = enum(u8) {
    warm,
    lukewarm,
    cold,
    frozen,
    deep_lukewarm,
    deep_cold,
    deep_frozen,
};

pub fn getOceanVariant(temperature: f32, is_deep: bool) OceanVariant {
    if (temperature > 0.8) return .warm; // warm has no deep variant
    if (temperature > 0.5) return if (is_deep) .deep_lukewarm else .lukewarm;
    if (temperature > 0.0) return if (is_deep) .deep_cold else .cold;
    return if (is_deep) .deep_frozen else .frozen;
}

pub fn getWaterColor(variant: OceanVariant) [3]f32 {
    return switch (variant) {
        .warm => .{ 0.26, 0.84, 0.93 },
        .lukewarm => .{ 0.27, 0.68, 0.95 },
        .deep_lukewarm => .{ 0.24, 0.62, 0.90 },
        .cold => .{ 0.25, 0.46, 0.89 },
        .deep_cold => .{ 0.22, 0.40, 0.82 },
        .frozen => .{ 0.22, 0.22, 0.79 },
        .deep_frozen => .{ 0.20, 0.20, 0.72 },
    };
}

pub fn getFloorBlock(variant: OceanVariant) u8 {
    return switch (variant) {
        .warm => 6, // sand
        .lukewarm => 6,
        .deep_lukewarm => 6,
        .cold => 7, // gravel
        .deep_cold => 7,
        .frozen => 7,
        .deep_frozen => 7,
    };
}

pub fn hasCoralReef(variant: OceanVariant) bool {
    return variant == .warm;
}

pub fn hasKelp(variant: OceanVariant) bool {
    return switch (variant) {
        .warm => false,
        .frozen, .deep_frozen => false,
        else => true,
    };
}

pub fn hasIce(variant: OceanVariant) bool {
    return variant == .frozen or variant == .deep_frozen;
}

pub fn hasIcebergs(variant: OceanVariant) bool {
    return variant == .deep_frozen;
}

pub fn getOceanDepth(variant: OceanVariant) i32 {
    return switch (variant) {
        .warm, .lukewarm, .cold, .frozen => 15,
        .deep_lukewarm, .deep_cold, .deep_frozen => 30,
    };
}

pub const CoralType = enum(u8) { tube, brain, bubble, fire, horn };

pub const CoralReef = struct {
    coral_type: CoralType,
    x: i32, y: i32, z: i32,
    size: u8,
};

pub fn generateCoralAt(x: i32, z: i32, sea_floor_y: i32, seed: u64) ?CoralReef {
    const h = hashCoords(x, z, seed);
    if (h % 100 > 15) return null; // 15% chance per column
    return CoralReef{
        .coral_type = @enumFromInt(@as(u8, @intCast(h % 5))),
        .x = x, .y = sea_floor_y, .z = z,
        .size = @intCast(1 + h % 4),
    };
}

pub const SpawnEntry = struct {
    name: []const u8,
    weight: u16,
};

pub fn getOceanMobSpawns(variant: OceanVariant) []const SpawnEntry {
    return switch (variant) {
        .warm => &[_]SpawnEntry{
            .{ .name = "tropical_fish", .weight = 25 },
            .{ .name = "pufferfish", .weight = 15 },
            .{ .name = "dolphin", .weight = 2 },
        },
        .lukewarm, .deep_lukewarm => &[_]SpawnEntry{
            .{ .name = "cod", .weight = 15 },
            .{ .name = "squid", .weight = 10 },
            .{ .name = "dolphin", .weight = 2 },
        },
        .cold, .deep_cold => &[_]SpawnEntry{
            .{ .name = "cod", .weight = 15 },
            .{ .name = "salmon", .weight = 15 },
            .{ .name = "squid", .weight = 10 },
        },
        .frozen, .deep_frozen => &[_]SpawnEntry{
            .{ .name = "salmon", .weight = 15 },
            .{ .name = "squid", .weight = 10 },
            .{ .name = "polar_bear", .weight = 1 },
        },
    };
}

pub fn hasOceanMonument(variant: OceanVariant) bool {
    return switch (variant) {
        .deep_lukewarm, .deep_cold, .deep_frozen => true,
        else => false,
    };
}

pub fn getRuinsType(variant: OceanVariant) enum { sandstone, stone } {
    return switch (variant) {
        .warm, .lukewarm, .deep_lukewarm => .sandstone,
        else => .stone,
    };
}

pub const IcebergConfig = struct {
    min_height: u8,
    max_height: u8,
    base_radius: u8,
    has_blue_ice: bool,
};

pub fn getIcebergConfig(variant: OceanVariant) ?IcebergConfig {
    return switch (variant) {
        .frozen => IcebergConfig{ .min_height = 5, .max_height = 15, .base_radius = 3, .has_blue_ice = false },
        .deep_frozen => IcebergConfig{ .min_height = 10, .max_height = 40, .base_radius = 6, .has_blue_ice = true },
        else => null,
    };
}

fn hashCoords(x: i32, z: i32, seed: u64) u32 {
    var h = seed;
    h ^= @as(u64, @bitCast(@as(i64, x))) *% 0x9E3779B97F4A7C15;
    h ^= @as(u64, @bitCast(@as(i64, z))) *% 0x6C62272E07BB0142;
    h = (h ^ (h >> 30)) *% 0xBF58476D1CE4E5B9;
    return @truncate(h ^ (h >> 27));
}

test "ocean variant selection" {
    try std.testing.expectEqual(OceanVariant.warm, getOceanVariant(0.9, false));
    try std.testing.expectEqual(OceanVariant.warm, getOceanVariant(0.9, true)); // warm has no deep
    try std.testing.expectEqual(OceanVariant.deep_frozen, getOceanVariant(-0.5, true));
}

test "coral only in warm" {
    try std.testing.expect(hasCoralReef(.warm));
    try std.testing.expect(!hasCoralReef(.cold));
}

test "water colors are valid RGB" {
    inline for (std.enums.values(OceanVariant)) |v| {
        const c = getWaterColor(v);
        try std.testing.expect(c[0] >= 0 and c[0] <= 1);
    }
}
