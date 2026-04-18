/// Biome-specific visual features: grass/foliage tint colors, water colors,
/// and ambient particle density per biome type.
/// Future: pass tint values to the fragment shader for biome-aware rendering.

const std = @import("std");

pub const BiomeTint = struct {
    grass_r: f32,
    grass_g: f32,
    grass_b: f32,
    foliage_r: f32,
    foliage_g: f32,
    foliage_b: f32,
    water_r: f32,
    water_g: f32,
    water_b: f32,
};

/// Biome type indices matching world/biome.zig BiomeType enum order.
pub fn getTint(biome_index: u8) BiomeTint {
    return switch (biome_index) {
        0 => .{ // plains
            .grass_r = 0.55, .grass_g = 0.75, .grass_b = 0.33,
            .foliage_r = 0.47, .foliage_g = 0.70, .foliage_b = 0.27,
            .water_r = 0.24, .water_g = 0.41, .water_b = 0.85,
        },
        1 => .{ // desert
            .grass_r = 0.75, .grass_g = 0.72, .grass_b = 0.42,
            .foliage_r = 0.68, .foliage_g = 0.65, .foliage_b = 0.38,
            .water_r = 0.24, .water_g = 0.41, .water_b = 0.85,
        },
        2 => .{ // forest
            .grass_r = 0.35, .grass_g = 0.65, .grass_b = 0.20,
            .foliage_r = 0.30, .foliage_g = 0.60, .foliage_b = 0.15,
            .water_r = 0.20, .water_g = 0.38, .water_b = 0.80,
        },
        3 => .{ // mountains
            .grass_r = 0.50, .grass_g = 0.65, .grass_b = 0.40,
            .foliage_r = 0.45, .foliage_g = 0.60, .foliage_b = 0.35,
            .water_r = 0.22, .water_g = 0.40, .water_b = 0.82,
        },
        4 => .{ // ocean
            .grass_r = 0.50, .grass_g = 0.70, .grass_b = 0.35,
            .foliage_r = 0.45, .foliage_g = 0.65, .foliage_b = 0.30,
            .water_r = 0.15, .water_g = 0.30, .water_b = 0.90,
        },
        5 => .{ // tundra
            .grass_r = 0.60, .grass_g = 0.70, .grass_b = 0.55,
            .foliage_r = 0.55, .foliage_g = 0.65, .foliage_b = 0.50,
            .water_r = 0.30, .water_g = 0.45, .water_b = 0.80,
        },
        else => .{ // fallback
            .grass_r = 0.50, .grass_g = 0.70, .grass_b = 0.30,
            .foliage_r = 0.45, .foliage_g = 0.65, .foliage_b = 0.25,
            .water_r = 0.24, .water_g = 0.41, .water_b = 0.85,
        },
    };
}

// ──────────────────────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────────────────────

test "plains tint has green grass" {
    const tint = getTint(0);
    try std.testing.expect(tint.grass_g > tint.grass_r);
    try std.testing.expect(tint.grass_g > tint.grass_b);
}

test "desert tint is yellower than forest" {
    const desert = getTint(1);
    const forest = getTint(2);
    try std.testing.expect(desert.grass_r > forest.grass_r);
}

test "all biomes have valid color ranges" {
    for (0..6) |i| {
        const tint = getTint(@intCast(i));
        try std.testing.expect(tint.grass_r >= 0.0 and tint.grass_r <= 1.0);
        try std.testing.expect(tint.grass_g >= 0.0 and tint.grass_g <= 1.0);
        try std.testing.expect(tint.grass_b >= 0.0 and tint.grass_b <= 1.0);
        try std.testing.expect(tint.water_r >= 0.0 and tint.water_r <= 1.0);
        try std.testing.expect(tint.water_g >= 0.0 and tint.water_g <= 1.0);
        try std.testing.expect(tint.water_b >= 0.0 and tint.water_b <= 1.0);
    }
}

test "unknown biome returns fallback" {
    const tint = getTint(255);
    try std.testing.expectApproxEqAbs(@as(f32, 0.50), tint.grass_r, 0.001);
}
