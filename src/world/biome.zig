/// Biome system for terrain generation.
/// Uses temperature and humidity noise to assign biome types at world coordinates.
/// Each biome defines surface/filler blocks, terrain height parameters, and tree density.
const std = @import("std");
const block = @import("block.zig");
const noise = @import("noise.zig");

pub const BiomeType = enum {
    plains,
    desert,
    forest,
    mountains,
    ocean,
    tundra,
};

pub const BiomeDef = struct {
    surface_block: block.BlockId,
    filler_block: block.BlockId,
    base_height: f64,
    height_scale: f64,
    tree_density: f32,
};

const temp_scale: f64 = 0.003;
const humidity_scale: f64 = 0.004;
const humidity_seed_offset: u64 = 31337;

/// Pre-computed noise tables for biome lookup.
/// Build once per seed via `BiomeNoise.init(seed)` and reuse across many
/// `getBiomeAt` calls to avoid re-shuffling the permutation table each time.
pub const BiomeNoise = struct {
    temp_pt: noise.PermTable,
    humid_pt: noise.PermTable,

    pub fn init(seed: u64) BiomeNoise {
        return .{
            .temp_pt = noise.PermTable.init(seed),
            .humid_pt = noise.PermTable.init(seed +% humidity_seed_offset),
        };
    }

    /// Look up biome at the given world coordinates.
    pub fn getBiomeAt(self: *const BiomeNoise, world_x: f64, world_z: f64) BiomeType {
        const temp = noise.noise2d(&self.temp_pt, world_x * temp_scale, world_z * temp_scale);
        const humidity = noise.noise2d(&self.humid_pt, world_x * humidity_scale, world_z * humidity_scale);
        return classify(temp, humidity);
    }
};

/// Get the biome definition for a given biome type.
pub fn getDef(biome: BiomeType) BiomeDef {
    return switch (biome) {
        .plains => .{
            .surface_block = block.GRASS,
            .filler_block = block.DIRT,
            .base_height = 8,
            .height_scale = 1.0,
            .tree_density = 0.1,
        },
        .desert => .{
            .surface_block = block.SAND,
            .filler_block = block.SAND,
            .base_height = 7,
            .height_scale = 0.5,
            .tree_density = 0.0,
        },
        .forest => .{
            .surface_block = block.GRASS,
            .filler_block = block.DIRT,
            .base_height = 8,
            .height_scale = 1.2,
            .tree_density = 0.8,
        },
        .mountains => .{
            .surface_block = block.STONE,
            .filler_block = block.STONE,
            .base_height = 10,
            .height_scale = 3.0,
            .tree_density = 0.05,
        },
        .ocean => .{
            .surface_block = block.SAND,
            .filler_block = block.SAND,
            .base_height = 4,
            .height_scale = 0.3,
            .tree_density = 0.0,
        },
        .tundra => .{
            .surface_block = block.GRAVEL,
            .filler_block = block.DIRT,
            .base_height = 7,
            .height_scale = 0.8,
            .tree_density = 0.02,
        },
    };
}

/// Convenience: get biome at world coordinates from a seed.
/// Prefer `BiomeNoise.init` + `getBiomeAt` when sampling many positions
/// with the same seed to avoid rebuilding permutation tables each call.
pub fn getBiome(seed: u64, world_x: f64, world_z: f64) BiomeType {
    const bn = BiomeNoise.init(seed);
    return bn.getBiomeAt(world_x, world_z);
}

/// Map temperature and humidity (both in approximately [-1, 1]) to a biome type.
fn classify(temp: f64, humidity: f64) BiomeType {
    // Cold biomes
    if (temp < -0.3) {
        return if (humidity < 0.0) .tundra else .mountains;
    }
    // Hot biomes
    if (temp > 0.3) {
        return if (humidity < 0.0) .desert else .plains;
    }
    // Temperate biomes
    if (humidity < -0.3) {
        return .ocean;
    }
    return if (humidity > 0.2) .forest else .plains;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "deterministic biome at known coordinates" {
    const biome_a = getBiome(42, 100.0, 200.0);
    const biome_b = getBiome(42, 100.0, 200.0);
    try std.testing.expectEqual(biome_a, biome_b);
}

test "BiomeNoise matches convenience getBiome" {
    const bn = BiomeNoise.init(42);
    try std.testing.expectEqual(getBiome(42, 100.0, 200.0), bn.getBiomeAt(100.0, 200.0));
    try std.testing.expectEqual(getBiome(42, -500.0, 300.0), bn.getBiomeAt(-500.0, 300.0));
}

test "desert has SAND surface" {
    const def = getDef(.desert);
    try std.testing.expectEqual(block.SAND, def.surface_block);
    try std.testing.expectEqual(block.SAND, def.filler_block);
}

test "mountains have high height_scale" {
    const mtn = getDef(.mountains);
    const plains = getDef(.plains);
    try std.testing.expect(mtn.height_scale > plains.height_scale);
    try std.testing.expect(mtn.height_scale >= 3.0);
}

test "different seeds produce different biome maps" {
    var differ: u32 = 0;
    const coords = [_][2]f64{
        .{ 0, 0 },
        .{ 100, 100 },
        .{ -200, 300 },
        .{ 500, -500 },
        .{ 1000, 2000 },
        .{ -3000, 4000 },
        .{ 7777, 8888 },
        .{ 12345, 67890 },
    };
    for (coords) |c| {
        const a = getBiome(1, c[0], c[1]);
        const b = getBiome(9999, c[0], c[1]);
        if (a != b) differ += 1;
    }
    try std.testing.expect(differ > 0);
}

test "all biome types have valid block ids" {
    const biomes = [_]BiomeType{ .plains, .desert, .forest, .mountains, .ocean, .tundra };
    for (biomes) |b| {
        const def = getDef(b);
        try std.testing.expect(def.surface_block < block.BLOCKS.len);
        try std.testing.expect(def.filler_block < block.BLOCKS.len);
    }
}

test "classify covers expected biome assignments" {
    // Hot + dry -> desert
    try std.testing.expectEqual(BiomeType.desert, classify(0.5, -0.5));
    // Hot + wet -> plains
    try std.testing.expectEqual(BiomeType.plains, classify(0.5, 0.5));
    // Cold + dry -> tundra
    try std.testing.expectEqual(BiomeType.tundra, classify(-0.5, -0.5));
    // Cold + wet -> mountains
    try std.testing.expectEqual(BiomeType.mountains, classify(-0.5, 0.5));
    // Temperate + very dry -> ocean
    try std.testing.expectEqual(BiomeType.ocean, classify(0.0, -0.5));
    // Temperate + wet -> forest
    try std.testing.expectEqual(BiomeType.forest, classify(0.0, 0.5));
}

test "tundra has GRAVEL surface and DIRT filler" {
    const def = getDef(.tundra);
    try std.testing.expectEqual(block.GRAVEL, def.surface_block);
    try std.testing.expectEqual(block.DIRT, def.filler_block);
}

test "ocean has lowest base_height" {
    const ocean = getDef(.ocean);
    const biomes = [_]BiomeType{ .plains, .desert, .forest, .mountains, .tundra };
    for (biomes) |b| {
        const def = getDef(b);
        try std.testing.expect(ocean.base_height <= def.base_height);
    }
}
