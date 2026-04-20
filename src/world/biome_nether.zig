/// Nether biomes: nether_wastes, soul_sand_valley, crimson_forest, warped_forest, basalt_deltas.
const std = @import("std");

pub const NetherBiome = enum(u8) {
    nether_wastes,
    soul_sand_valley,
    crimson_forest,
    warped_forest,
    basalt_deltas,
};

pub const BlockPalette = struct {
    floor: u8,
    ceiling: u8,
    walls: u8,
    accent: u8,
    ore1: u8,
    ore2: u8,
};

pub const SpawnWeight = struct {
    mob_type: MobType,
    weight: u16,
};

pub const MobType = enum(u8) {
    zombified_piglin, piglin, ghast, magma_cube, enderman,
    skeleton, blaze, wither_skeleton, hoglin, strider,
};

pub const ParticleType = enum(u8) { none, crimson_spore, warped_spore, soul_flame, white_ash };

pub fn getBiomeAt(x: i32, z: i32, seed: u64) NetherBiome {
    const hash = hashCoords(x, z, seed);
    const val = @as(f32, @floatFromInt(hash % 1000)) / 1000.0;
    if (val < 0.30) return .nether_wastes;
    if (val < 0.48) return .soul_sand_valley;
    if (val < 0.64) return .crimson_forest;
    if (val < 0.80) return .warped_forest;
    return .basalt_deltas;
}

pub fn getBlockPalette(biome: NetherBiome) BlockPalette {
    return switch (biome) {
        .nether_wastes => .{ .floor = 35, .ceiling = 35, .walls = 35, .accent = 34, .ore1 = 15, .ore2 = 0 },
        .soul_sand_valley => .{ .floor = 36, .ceiling = 35, .walls = 35, .accent = 12, .ore1 = 0, .ore2 = 0 },
        .crimson_forest => .{ .floor = 35, .ceiling = 35, .walls = 35, .accent = 35, .ore1 = 34, .ore2 = 0 },
        .warped_forest => .{ .floor = 35, .ceiling = 35, .walls = 35, .accent = 35, .ore1 = 34, .ore2 = 0 },
        .basalt_deltas => .{ .floor = 12, .ceiling = 12, .walls = 12, .accent = 37, .ore1 = 0, .ore2 = 0 },
    };
}

pub fn getFogColor(biome: NetherBiome) [3]f32 {
    return switch (biome) {
        .nether_wastes => .{ 0.20, 0.03, 0.03 },
        .soul_sand_valley => .{ 0.08, 0.16, 0.25 },
        .crimson_forest => .{ 0.25, 0.04, 0.04 },
        .warped_forest => .{ 0.08, 0.15, 0.18 },
        .basalt_deltas => .{ 0.25, 0.22, 0.27 },
    };
}

pub fn getAmbientLight(biome: NetherBiome) f32 {
    return switch (biome) {
        .nether_wastes => 0.1,
        .soul_sand_valley => 0.05,
        .crimson_forest => 0.08,
        .warped_forest => 0.08,
        .basalt_deltas => 0.06,
    };
}

pub fn getParticleType(biome: NetherBiome) ParticleType {
    return switch (biome) {
        .nether_wastes => .none,
        .soul_sand_valley => .soul_flame,
        .crimson_forest => .crimson_spore,
        .warped_forest => .warped_spore,
        .basalt_deltas => .white_ash,
    };
}

pub fn getMobSpawnWeights(biome: NetherBiome) []const SpawnWeight {
    return switch (biome) {
        .nether_wastes => &[_]SpawnWeight{
            .{ .mob_type = .zombified_piglin, .weight = 100 },
            .{ .mob_type = .piglin, .weight = 15 },
            .{ .mob_type = .ghast, .weight = 50 },
            .{ .mob_type = .magma_cube, .weight = 2 },
            .{ .mob_type = .enderman, .weight = 1 },
        },
        .soul_sand_valley => &[_]SpawnWeight{
            .{ .mob_type = .skeleton, .weight = 20 },
            .{ .mob_type = .ghast, .weight = 50 },
            .{ .mob_type = .enderman, .weight = 1 },
        },
        .crimson_forest => &[_]SpawnWeight{
            .{ .mob_type = .piglin, .weight = 5 },
            .{ .mob_type = .hoglin, .weight = 9 },
            .{ .mob_type = .zombified_piglin, .weight = 1 },
        },
        .warped_forest => &[_]SpawnWeight{
            .{ .mob_type = .enderman, .weight = 1 },
            .{ .mob_type = .strider, .weight = 60 },
        },
        .basalt_deltas => &[_]SpawnWeight{
            .{ .mob_type = .magma_cube, .weight = 100 },
            .{ .mob_type = .strider, .weight = 60 },
        },
    };
}

pub const DecorationConfig = struct {
    fungi_chance: f32,
    vine_chance: f32,
    pillar_chance: f32,
    glowstone_chance: f32,
    lava_pool_chance: f32,
};

pub fn getDecorationConfig(biome: NetherBiome) DecorationConfig {
    return switch (biome) {
        .nether_wastes => .{ .fungi_chance = 0.02, .vine_chance = 0.0, .pillar_chance = 0.0, .glowstone_chance = 0.05, .lava_pool_chance = 0.03 },
        .soul_sand_valley => .{ .fungi_chance = 0.0, .vine_chance = 0.0, .pillar_chance = 0.06, .glowstone_chance = 0.01, .lava_pool_chance = 0.0 },
        .crimson_forest => .{ .fungi_chance = 0.12, .vine_chance = 0.15, .pillar_chance = 0.0, .glowstone_chance = 0.02, .lava_pool_chance = 0.0 },
        .warped_forest => .{ .fungi_chance = 0.12, .vine_chance = 0.10, .pillar_chance = 0.0, .glowstone_chance = 0.02, .lava_pool_chance = 0.0 },
        .basalt_deltas => .{ .fungi_chance = 0.0, .vine_chance = 0.0, .pillar_chance = 0.0, .glowstone_chance = 0.0, .lava_pool_chance = 0.08 },
    };
}

fn hashCoords(x: i32, z: i32, seed: u64) u32 {
    var h = seed;
    h ^= @as(u64, @bitCast(@as(i64, x))) *% 0x9E3779B97F4A7C15;
    h ^= @as(u64, @bitCast(@as(i64, z))) *% 0x6C62272E07BB0142;
    h = (h ^ (h >> 30)) *% 0xBF58476D1CE4E5B9;
    h = (h ^ (h >> 27)) *% 0x94D049BB133111EB;
    return @truncate(h ^ (h >> 31));
}

test "biome distribution" {
    var counts = [_]u32{0} ** 5;
    for (0..100) |i| {
        const b = getBiomeAt(@intCast(i), 0, 12345);
        counts[@intFromEnum(b)] += 1;
    }
    // Each biome should appear at least once in 100 samples
    for (counts) |c| try std.testing.expect(c > 0);
}

test "fog colors valid" {
    inline for (std.enums.values(NetherBiome)) |b| {
        const fog = getFogColor(b);
        try std.testing.expect(fog[0] >= 0 and fog[0] <= 1);
    }
}
