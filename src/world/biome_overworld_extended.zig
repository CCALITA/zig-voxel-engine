/// Extended overworld biomes: flower_forest, birch_forest, dark_forest, swamp,
/// meadow, snowy_plains, ice_spikes, beach, snowy_beach, stony_shore.
const std = @import("std");

pub const ExtendedBiome = enum(u8) {
    flower_forest,
    birch_forest,
    old_growth_birch,
    dark_forest,
    swamp,
    meadow,
    snowy_plains,
    ice_spikes,
    beach,
    snowy_beach,
    stony_shore,
};

pub const BiomeBlocks = struct {
    top: u8,
    filler: u8,
    underwater: u8,
    stone: u8 = 0,
};

pub fn getBiomeBlocks(biome: ExtendedBiome) BiomeBlocks {
    return switch (biome) {
        .flower_forest => .{ .top = 2, .filler = 1, .underwater = 7 },
        .birch_forest, .old_growth_birch => .{ .top = 2, .filler = 1, .underwater = 7 },
        .dark_forest => .{ .top = 2, .filler = 1, .underwater = 7 },
        .swamp => .{ .top = 2, .filler = 1, .underwater = 27 }, // clay patches
        .meadow => .{ .top = 2, .filler = 1, .underwater = 7 },
        .snowy_plains => .{ .top = 26, .filler = 1, .underwater = 7 },
        .ice_spikes => .{ .top = 26, .filler = 25, .underwater = 25 }, // ice+snow
        .beach => .{ .top = 6, .filler = 6, .underwater = 6 },
        .snowy_beach => .{ .top = 26, .filler = 6, .underwater = 6 },
        .stony_shore => .{ .top = 0, .filler = 0, .underwater = 7 },
    };
}

pub const TreeType = enum(u8) { oak, birch, tall_birch, dark_oak, spruce, none };

pub const TreeConfig = struct {
    tree_type: TreeType,
    density: f32,
    min_height: u8,
    max_height: u8,
};

pub fn getTreeConfig(biome: ExtendedBiome) TreeConfig {
    return switch (biome) {
        .flower_forest => .{ .tree_type = .oak, .density = 0.06, .min_height = 4, .max_height = 7 },
        .birch_forest => .{ .tree_type = .birch, .density = 0.08, .min_height = 5, .max_height = 7 },
        .old_growth_birch => .{ .tree_type = .tall_birch, .density = 0.08, .min_height = 8, .max_height = 14 },
        .dark_forest => .{ .tree_type = .dark_oak, .density = 0.25, .min_height = 6, .max_height = 8 },
        .swamp => .{ .tree_type = .oak, .density = 0.04, .min_height = 5, .max_height = 8 },
        .meadow => .{ .tree_type = .oak, .density = 0.002, .min_height = 5, .max_height = 12 },
        .snowy_plains => .{ .tree_type = .spruce, .density = 0.005, .min_height = 5, .max_height = 8 },
        .ice_spikes => .{ .tree_type = .none, .density = 0, .min_height = 0, .max_height = 0 },
        .beach, .snowy_beach, .stony_shore => .{ .tree_type = .none, .density = 0, .min_height = 0, .max_height = 0 },
    };
}

pub const FlowerType = enum(u8) {
    poppy, dandelion, blue_orchid, allium, azure_bluet,
    tulip_red, tulip_orange, tulip_white, tulip_pink,
    oxeye_daisy, cornflower, lily_of_valley,
    sunflower, lilac, rose_bush, peony,
};

pub fn getFlowers(biome: ExtendedBiome) []const FlowerType {
    return switch (biome) {
        .flower_forest => &[_]FlowerType{
            .poppy, .dandelion, .allium, .azure_bluet,
            .tulip_red, .tulip_orange, .tulip_white, .tulip_pink,
            .oxeye_daisy, .cornflower, .lily_of_valley,
            .sunflower, .lilac, .rose_bush, .peony,
        },
        .swamp => &[_]FlowerType{.blue_orchid},
        .meadow => &[_]FlowerType{ .poppy, .dandelion, .oxeye_daisy, .cornflower },
        .birch_forest, .old_growth_birch => &[_]FlowerType{ .lily_of_valley, .poppy },
        else => &[_]FlowerType{},
    };
}

pub fn getFlowerDensity(biome: ExtendedBiome) f32 {
    return switch (biome) {
        .flower_forest => 0.25,
        .meadow => 0.15,
        .swamp => 0.03,
        else => 0.01,
    };
}

pub const SpawnEntry = struct {
    name: []const u8,
    weight: u16,
};

pub fn getMobSpawns(biome: ExtendedBiome) []const SpawnEntry {
    return switch (biome) {
        .flower_forest => &[_]SpawnEntry{
            .{ .name = "rabbit", .weight = 4 },
            .{ .name = "bee", .weight = 3 },
        },
        .dark_forest => &[_]SpawnEntry{
            .{ .name = "zombie", .weight = 100 },
            .{ .name = "skeleton", .weight = 100 },
        },
        .swamp => &[_]SpawnEntry{
            .{ .name = "slime", .weight = 1 },
            .{ .name = "frog", .weight = 5 },
        },
        .meadow => &[_]SpawnEntry{
            .{ .name = "rabbit", .weight = 4 },
            .{ .name = "bee", .weight = 2 },
        },
        .snowy_plains, .ice_spikes => &[_]SpawnEntry{
            .{ .name = "polar_bear", .weight = 1 },
            .{ .name = "rabbit", .weight = 4 },
            .{ .name = "stray", .weight = 80 },
        },
        .beach => &[_]SpawnEntry{
            .{ .name = "turtle", .weight = 5 },
        },
        else => &[_]SpawnEntry{},
    };
}

pub fn getTemperature(biome: ExtendedBiome) f32 {
    return switch (biome) {
        .flower_forest, .birch_forest, .old_growth_birch => 0.6,
        .dark_forest => 0.7,
        .swamp => 0.8,
        .meadow => 0.5,
        .snowy_plains, .ice_spikes, .snowy_beach => 0.0,
        .beach => 0.8,
        .stony_shore => 0.2,
    };
}

pub fn hasMushroomGeneration(biome: ExtendedBiome) bool {
    return biome == .dark_forest;
}

pub fn hasLilyPads(biome: ExtendedBiome) bool {
    return biome == .swamp;
}

pub fn hasVines(biome: ExtendedBiome) bool {
    return biome == .swamp;
}

pub fn canRain(biome: ExtendedBiome) bool {
    return switch (biome) {
        .ice_spikes, .snowy_plains, .snowy_beach => false,
        else => true,
    };
}

pub fn getIceSpikeChance() f32 {
    return 0.08;
}

pub fn getIceSpikeHeight(rng_val: u32) u8 {
    return @intCast(10 + rng_val % 41); // 10-50 blocks
}

pub const StructureChance = struct {
    igloo: f32 = 0,
    witch_hut: f32 = 0,
    pillager_outpost: f32 = 0,
    buried_treasure: f32 = 0,
    woodland_mansion: f32 = 0,
};

pub fn getStructureChances(biome: ExtendedBiome) StructureChance {
    return switch (biome) {
        .snowy_plains => .{ .igloo = 0.01 },
        .swamp => .{ .witch_hut = 0.005 },
        .meadow => .{ .pillager_outpost = 0.002 },
        .dark_forest => .{ .woodland_mansion = 0.0005 },
        .beach => .{ .buried_treasure = 0.02 },
        else => .{},
    };
}

test "biome blocks" {
    const b = getBiomeBlocks(.ice_spikes);
    try std.testing.expectEqual(@as(u8, 26), b.top); // snow
}

test "flower forest has many flowers" {
    try std.testing.expect(getFlowers(.flower_forest).len >= 10);
}

test "dark forest has hostile spawns" {
    try std.testing.expect(getMobSpawns(.dark_forest).len > 0);
}
