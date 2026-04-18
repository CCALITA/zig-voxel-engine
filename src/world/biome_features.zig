/// Biome-specific visual features and mob spawn tables.
/// Provides color lookup for grass, foliage, water, and sky based on
/// temperature/humidity or biome type, plus per-biome mob spawn weights
/// and structure assignments. Only uses `std`.
const std = @import("std");

// ─────────────────────────────────────────────────────────────────────────────
// Biome type constants (mirrors biome.zig BiomeType enum ordinals)
// ─────────────────────────────────────────────────────────────────────────────

pub const biome_plains: u8 = 0;
pub const biome_desert: u8 = 1;
pub const biome_forest: u8 = 2;
pub const biome_mountains: u8 = 3;
pub const biome_ocean: u8 = 4;
pub const biome_tundra: u8 = 5;

// ─────────────────────────────────────────────────────────────────────────────
// Entity type constants (mirrors entity.zig EntityType enum ordinals)
// ─────────────────────────────────────────────────────────────────────────────

const entity_zombie: u8 = 1;
const entity_skeleton: u8 = 2;
const entity_creeper: u8 = 3;
const entity_pig: u8 = 4;
const entity_cow: u8 = 5;
const entity_chicken: u8 = 6;
const entity_sheep: u8 = 7;

// Stub entity types for biome-specific mobs not yet in EntityType
const entity_rabbit: u8 = 20;
const entity_ocelot: u8 = 21;
const entity_parrot: u8 = 22;
const entity_squid: u8 = 23;
const entity_dolphin: u8 = 24;
const entity_wolf: u8 = 25;
const entity_stray: u8 = 26;
const entity_husk: u8 = 27;
const entity_drowned: u8 = 28;

// ─────────────────────────────────────────────────────────────────────────────
// Structure type IDs
// ─────────────────────────────────────────────────────────────────────────────

pub const structure_village: u8 = 1;
pub const structure_desert_temple: u8 = 2;
pub const structure_desert_well: u8 = 3;
pub const structure_witch_hut: u8 = 4;
pub const structure_igloo: u8 = 5;
pub const structure_ocean_monument: u8 = 6;
pub const structure_shipwreck: u8 = 7;
pub const structure_mineshaft: u8 = 8;
pub const structure_dungeon: u8 = 9;

// ─────────────────────────────────────────────────────────────────────────────
// Color functions
// ─────────────────────────────────────────────────────────────────────────────

/// Compute grass color from temperature and humidity.
/// High temp + high humidity = dark green, low temp = blue-green tint,
/// desert-like (high temp, low humidity) = yellow-green.
pub fn getGrassColor(temperature: f32, humidity: f32) [3]f32 {
    const temp = clamp01(temperature);
    const humid = clamp01(humidity);

    const r = 0.25 + 0.45 * temp - 0.15 * humid;
    const g = 0.55 + 0.20 * humid + 0.05 * temp;
    const b = 0.15 + 0.30 * (1.0 - temp) * (1.0 - humid);

    return .{ clamp01(r), clamp01(g), clamp01(b) };
}

/// Compute foliage (leaf) color from temperature and humidity.
/// Similar gradient to grass but slightly darker and more saturated.
pub fn getFoliageColor(temperature: f32, humidity: f32) [3]f32 {
    const temp = clamp01(temperature);
    const humid = clamp01(humidity);

    const r = 0.20 + 0.40 * temp - 0.10 * humid;
    const g = 0.50 + 0.25 * humid;
    const b = 0.10 + 0.35 * (1.0 - temp) * (1.0 - humid);

    return .{ clamp01(r), clamp01(g), clamp01(b) };
}

/// Return water color for a given biome type.
/// Ocean = deep blue, swamp-like (tundra used as proxy) = dark green-blue,
/// default = standard blue.
pub fn getWaterColor(biome_type: u8) [3]f32 {
    return switch (biome_type) {
        biome_ocean => .{ 0.10, 0.15, 0.60 },
        biome_tundra => .{ 0.20, 0.35, 0.40 },
        biome_desert => .{ 0.25, 0.45, 0.70 },
        biome_forest => .{ 0.15, 0.35, 0.55 },
        else => .{ 0.20, 0.40, 0.65 },
    };
}

/// Return sky tint for a given biome type.
/// Desert = lighter/hazier, forest = standard blue, tundra/swamp = gray.
pub fn getSkyTint(biome_type: u8) [3]f32 {
    return switch (biome_type) {
        biome_desert => .{ 0.75, 0.80, 0.90 },
        biome_forest => .{ 0.50, 0.65, 0.90 },
        biome_ocean => .{ 0.55, 0.70, 0.95 },
        biome_tundra => .{ 0.60, 0.62, 0.65 },
        biome_mountains => .{ 0.55, 0.68, 0.92 },
        else => .{ 0.55, 0.70, 0.90 },
    };
}

// ─────────────────────────────────────────────────────────────────────────────
// Mob spawn tables
// ─────────────────────────────────────────────────────────────────────────────

pub const MobSpawn = struct {
    entity_type: u8,
    weight: u8,
    min_group: u8,
    max_group: u8,
};

pub const BiomeMobSpawns = struct {
    hostile: [8]?MobSpawn,
    passive: [8]?MobSpawn,
};

const empty_spawns: [8]?MobSpawn = .{null} ** 8;

/// Return the mob spawn table for a given biome type.
pub fn getMobSpawns(biome_type: u8) BiomeMobSpawns {
    return switch (biome_type) {
        biome_plains => plainsSpawns(),
        biome_desert => desertSpawns(),
        biome_forest => forestSpawns(),
        biome_mountains => mountainsSpawns(),
        biome_ocean => oceanSpawns(),
        biome_tundra => tundraSpawns(),
        else => .{ .hostile = empty_spawns, .passive = empty_spawns },
    };
}

fn plainsSpawns() BiomeMobSpawns {
    var hostile = empty_spawns;
    hostile[0] = .{ .entity_type = entity_zombie, .weight = 50, .min_group = 1, .max_group = 4 };
    hostile[1] = .{ .entity_type = entity_skeleton, .weight = 30, .min_group = 1, .max_group = 2 };
    hostile[2] = .{ .entity_type = entity_creeper, .weight = 20, .min_group = 1, .max_group = 1 };

    var passive = empty_spawns;
    passive[0] = .{ .entity_type = entity_pig, .weight = 30, .min_group = 2, .max_group = 4 };
    passive[1] = .{ .entity_type = entity_cow, .weight = 25, .min_group = 2, .max_group = 3 };
    passive[2] = .{ .entity_type = entity_sheep, .weight = 25, .min_group = 2, .max_group = 4 };
    passive[3] = .{ .entity_type = entity_chicken, .weight = 20, .min_group = 1, .max_group = 3 };

    return .{ .hostile = hostile, .passive = passive };
}

fn desertSpawns() BiomeMobSpawns {
    var hostile = empty_spawns;
    hostile[0] = .{ .entity_type = entity_husk, .weight = 50, .min_group = 1, .max_group = 4 };
    hostile[1] = .{ .entity_type = entity_skeleton, .weight = 30, .min_group = 1, .max_group = 2 };
    hostile[2] = .{ .entity_type = entity_creeper, .weight = 20, .min_group = 1, .max_group = 1 };

    // Desert: only rabbit as passive
    var passive = empty_spawns;
    passive[0] = .{ .entity_type = entity_rabbit, .weight = 100, .min_group = 1, .max_group = 3 };

    return .{ .hostile = hostile, .passive = passive };
}

fn forestSpawns() BiomeMobSpawns {
    var hostile = empty_spawns;
    hostile[0] = .{ .entity_type = entity_zombie, .weight = 40, .min_group = 1, .max_group = 4 };
    hostile[1] = .{ .entity_type = entity_skeleton, .weight = 30, .min_group = 1, .max_group = 2 };
    hostile[2] = .{ .entity_type = entity_creeper, .weight = 30, .min_group = 1, .max_group = 1 };

    // Forest: includes parrot and ocelot (jungle-like)
    var passive = empty_spawns;
    passive[0] = .{ .entity_type = entity_pig, .weight = 20, .min_group = 1, .max_group = 3 };
    passive[1] = .{ .entity_type = entity_chicken, .weight = 20, .min_group = 1, .max_group = 3 };
    passive[2] = .{ .entity_type = entity_wolf, .weight = 15, .min_group = 1, .max_group = 4 };
    passive[3] = .{ .entity_type = entity_parrot, .weight = 25, .min_group = 1, .max_group = 2 };
    passive[4] = .{ .entity_type = entity_ocelot, .weight = 20, .min_group = 1, .max_group = 2 };

    return .{ .hostile = hostile, .passive = passive };
}

fn mountainsSpawns() BiomeMobSpawns {
    var hostile = empty_spawns;
    hostile[0] = .{ .entity_type = entity_zombie, .weight = 40, .min_group = 1, .max_group = 3 };
    hostile[1] = .{ .entity_type = entity_skeleton, .weight = 35, .min_group = 1, .max_group = 2 };
    hostile[2] = .{ .entity_type = entity_creeper, .weight = 25, .min_group = 1, .max_group = 1 };

    var passive = empty_spawns;
    passive[0] = .{ .entity_type = entity_sheep, .weight = 40, .min_group = 2, .max_group = 4 };
    passive[1] = .{ .entity_type = entity_cow, .weight = 30, .min_group = 1, .max_group = 2 };
    passive[2] = .{ .entity_type = entity_rabbit, .weight = 30, .min_group = 1, .max_group = 3 };

    return .{ .hostile = hostile, .passive = passive };
}

fn oceanSpawns() BiomeMobSpawns {
    var hostile = empty_spawns;
    hostile[0] = .{ .entity_type = entity_drowned, .weight = 60, .min_group = 1, .max_group = 3 };
    hostile[1] = .{ .entity_type = entity_zombie, .weight = 25, .min_group = 1, .max_group = 2 };
    hostile[2] = .{ .entity_type = entity_skeleton, .weight = 15, .min_group = 1, .max_group = 1 };

    // Ocean: squid and dolphin stubs
    var passive = empty_spawns;
    passive[0] = .{ .entity_type = entity_squid, .weight = 60, .min_group = 1, .max_group = 4 };
    passive[1] = .{ .entity_type = entity_dolphin, .weight = 40, .min_group = 1, .max_group = 3 };

    return .{ .hostile = hostile, .passive = passive };
}

fn tundraSpawns() BiomeMobSpawns {
    var hostile = empty_spawns;
    hostile[0] = .{ .entity_type = entity_stray, .weight = 45, .min_group = 1, .max_group = 3 };
    hostile[1] = .{ .entity_type = entity_zombie, .weight = 30, .min_group = 1, .max_group = 3 };
    hostile[2] = .{ .entity_type = entity_skeleton, .weight = 25, .min_group = 1, .max_group = 2 };

    var passive = empty_spawns;
    passive[0] = .{ .entity_type = entity_rabbit, .weight = 40, .min_group = 1, .max_group = 3 };
    passive[1] = .{ .entity_type = entity_sheep, .weight = 30, .min_group = 1, .max_group = 3 };
    passive[2] = .{ .entity_type = entity_wolf, .weight = 30, .min_group = 1, .max_group = 4 };

    return .{ .hostile = hostile, .passive = passive };
}

// ─────────────────────────────────────────────────────────────────────────────
// Biome structures
// ─────────────────────────────────────────────────────────────────────────────

/// Return up to 4 structure type IDs that can generate in a given biome.
pub fn getBiomeStructures(biome_type: u8) [4]?u8 {
    return switch (biome_type) {
        biome_plains => .{ structure_village, structure_mineshaft, null, null },
        biome_desert => .{ structure_desert_temple, structure_desert_well, structure_village, structure_mineshaft },
        biome_forest => .{ structure_witch_hut, structure_dungeon, structure_mineshaft, null },
        biome_mountains => .{ structure_mineshaft, structure_dungeon, null, null },
        biome_ocean => .{ structure_ocean_monument, structure_shipwreck, structure_mineshaft, null },
        biome_tundra => .{ structure_igloo, structure_village, structure_mineshaft, null },
        else => .{ null, null, null, null },
    };
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

fn clamp01(v: f32) f32 {
    return @max(0.0, @min(1.0, v));
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

test "grass color varies with temperature" {
    const cold = getGrassColor(0.0, 0.5);
    const warm = getGrassColor(1.0, 0.5);

    // Warm grass should have more red (yellow-green shift)
    try std.testing.expect(warm[0] > cold[0]);
    // Cold grass should have more blue (blue-green tint)
    try std.testing.expect(cold[2] > warm[2]);
}

test "grass color varies with humidity" {
    const dry = getGrassColor(0.5, 0.0);
    const wet = getGrassColor(0.5, 1.0);

    // Wet grass should be darker green (higher green channel)
    try std.testing.expect(wet[1] > dry[1]);
}

test "grass color desert-like at high temp low humidity" {
    const desert = getGrassColor(1.0, 0.0);
    // Should be yellowish: high red, moderate green, low blue
    try std.testing.expect(desert[0] > 0.5);
    try std.testing.expect(desert[2] < 0.3);
}

test "grass color components are in 0-1 range" {
    const extremes = [_][2]f32{
        .{ 0.0, 0.0 },
        .{ 0.0, 1.0 },
        .{ 1.0, 0.0 },
        .{ 1.0, 1.0 },
        .{ 0.5, 0.5 },
        .{ -1.0, -1.0 },
        .{ 2.0, 2.0 },
    };
    for (extremes) |e| {
        const color = getGrassColor(e[0], e[1]);
        for (color) |c| {
            try std.testing.expect(c >= 0.0 and c <= 1.0);
        }
    }
}

test "foliage color varies with temperature" {
    const cold = getFoliageColor(0.0, 0.5);
    const warm = getFoliageColor(1.0, 0.5);
    try std.testing.expect(warm[0] > cold[0]);
    try std.testing.expect(cold[2] > warm[2]);
}

test "foliage color components are in 0-1 range" {
    const extremes = [_][2]f32{
        .{ 0.0, 0.0 },
        .{ 1.0, 1.0 },
        .{ -1.0, -1.0 },
        .{ 2.0, 2.0 },
    };
    for (extremes) |e| {
        const color = getFoliageColor(e[0], e[1]);
        for (color) |c| {
            try std.testing.expect(c >= 0.0 and c <= 1.0);
        }
    }
}

test "water color differs per biome" {
    const ocean_water = getWaterColor(biome_ocean);
    const default_water = getWaterColor(biome_plains);

    // Ocean water should be deeper blue (higher blue, lower green)
    try std.testing.expect(ocean_water[2] > default_water[2] - 0.1);
    try std.testing.expect(ocean_water[1] < default_water[1]);
}

test "water color ocean is deep blue" {
    const c = getWaterColor(biome_ocean);
    // Blue channel should dominate
    try std.testing.expect(c[2] > c[0]);
    try std.testing.expect(c[2] > c[1]);
}

test "water color tundra is dark green-blue" {
    const c = getWaterColor(biome_tundra);
    // Green and blue channels should be close, both above red
    try std.testing.expect(c[1] > c[0]);
    try std.testing.expect(c[2] > c[0]);
}

test "sky tint desert is lighter" {
    const desert_sky = getSkyTint(biome_desert);
    const forest_sky = getSkyTint(biome_forest);

    // Desert sky should be brighter overall
    const desert_avg = (desert_sky[0] + desert_sky[1] + desert_sky[2]) / 3.0;
    const forest_avg = (forest_sky[0] + forest_sky[1] + forest_sky[2]) / 3.0;
    try std.testing.expect(desert_avg > forest_avg);
}

test "sky tint tundra is grayish" {
    const tundra_sky = getSkyTint(biome_tundra);
    // Gray means channels are close together
    const range = @max(tundra_sky[0], @max(tundra_sky[1], tundra_sky[2])) -
        @min(tundra_sky[0], @min(tundra_sky[1], tundra_sky[2]));
    try std.testing.expect(range < 0.10);
}

test "desert mob spawns: only rabbit passive" {
    const spawns = getMobSpawns(biome_desert);

    // First passive entry must be rabbit
    const first = spawns.passive[0].?;
    try std.testing.expectEqual(entity_rabbit, first.entity_type);

    // Remaining passive slots must be null
    for (spawns.passive[1..]) |slot| {
        try std.testing.expect(slot == null);
    }
}

test "forest mob spawns: parrot and ocelot present" {
    const spawns = getMobSpawns(biome_forest);
    var found_parrot = false;
    var found_ocelot = false;
    for (spawns.passive) |slot| {
        if (slot) |s| {
            if (s.entity_type == entity_parrot) found_parrot = true;
            if (s.entity_type == entity_ocelot) found_ocelot = true;
        }
    }
    try std.testing.expect(found_parrot);
    try std.testing.expect(found_ocelot);
}

test "ocean mob spawns: squid and dolphin present" {
    const spawns = getMobSpawns(biome_ocean);
    var found_squid = false;
    var found_dolphin = false;
    for (spawns.passive) |slot| {
        if (slot) |s| {
            if (s.entity_type == entity_squid) found_squid = true;
            if (s.entity_type == entity_dolphin) found_dolphin = true;
        }
    }
    try std.testing.expect(found_squid);
    try std.testing.expect(found_dolphin);
}

test "plains mob spawns have hostile and passive entries" {
    const spawns = getMobSpawns(biome_plains);

    var hostile_count: usize = 0;
    var passive_count: usize = 0;
    for (spawns.hostile) |slot| {
        if (slot != null) hostile_count += 1;
    }
    for (spawns.passive) |slot| {
        if (slot != null) passive_count += 1;
    }
    try std.testing.expect(hostile_count >= 3);
    try std.testing.expect(passive_count >= 3);
}

test "all biome mob spawn weights sum to 100 for hostile" {
    const biomes = [_]u8{ biome_plains, biome_desert, biome_forest, biome_mountains, biome_ocean, biome_tundra };
    for (biomes) |b| {
        const spawns = getMobSpawns(b);
        var total: u32 = 0;
        for (spawns.hostile) |slot| {
            if (slot) |s| total += s.weight;
        }
        try std.testing.expectEqual(@as(u32, 100), total);
    }
}

test "unknown biome type returns empty spawns" {
    const spawns = getMobSpawns(255);
    for (spawns.hostile) |slot| {
        try std.testing.expect(slot == null);
    }
    for (spawns.passive) |slot| {
        try std.testing.expect(slot == null);
    }
}

test "biome structures: desert has temple and well" {
    const structures = getBiomeStructures(biome_desert);
    var found_temple = false;
    var found_well = false;
    for (structures) |s| {
        if (s) |id| {
            if (id == structure_desert_temple) found_temple = true;
            if (id == structure_desert_well) found_well = true;
        }
    }
    try std.testing.expect(found_temple);
    try std.testing.expect(found_well);
}

test "biome structures: ocean has monument and shipwreck" {
    const structures = getBiomeStructures(biome_ocean);
    var found_monument = false;
    var found_shipwreck = false;
    for (structures) |s| {
        if (s) |id| {
            if (id == structure_ocean_monument) found_monument = true;
            if (id == structure_shipwreck) found_shipwreck = true;
        }
    }
    try std.testing.expect(found_monument);
    try std.testing.expect(found_shipwreck);
}

test "biome structures: unknown biome returns all null" {
    const structures = getBiomeStructures(255);
    for (structures) |s| {
        try std.testing.expect(s == null);
    }
}

test "tundra mob spawns have stray as primary hostile" {
    const spawns = getMobSpawns(biome_tundra);
    const first_hostile = spawns.hostile[0].?;
    try std.testing.expectEqual(entity_stray, first_hostile.entity_type);
    try std.testing.expect(first_hostile.weight >= 40);
}

test "mob spawn group sizes are valid" {
    const biomes = [_]u8{ biome_plains, biome_desert, biome_forest, biome_mountains, biome_ocean, biome_tundra };
    for (biomes) |b| {
        const spawns = getMobSpawns(b);
        for (spawns.hostile) |slot| {
            if (slot) |s| {
                try std.testing.expect(s.min_group >= 1);
                try std.testing.expect(s.max_group >= s.min_group);
            }
        }
        for (spawns.passive) |slot| {
            if (slot) |s| {
                try std.testing.expect(s.min_group >= 1);
                try std.testing.expect(s.max_group >= s.min_group);
            }
        }
    }
}
