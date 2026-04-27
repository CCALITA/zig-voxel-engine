/// Mob type registry: enums, stats, and comptime lookup tables for all vanilla mob types.
const std = @import("std");

pub const MobCategory = enum(u8) {
    passive,
    neutral,
    hostile,
    boss,
    ambient,
    water_creature,
};

pub const DimensionFilter = enum(u8) {
    any,
    overworld_only,
    nether_only,
    end_only,
};

pub const MobId = enum(u16) {
    // Passive 0-19
    pig = 0,
    cow = 1,
    sheep = 2,
    chicken = 3,
    horse = 4,
    donkey = 5,
    mule = 6,
    rabbit = 7,
    mooshroom = 8,
    ocelot = 9,
    cat = 10,
    parrot = 11,
    fox = 12,
    panda = 13,
    bee = 14,
    turtle = 15,
    frog = 16,
    sniffer = 17,
    armadillo = 18,
    camel = 19,
    // Neutral 20-39
    wolf = 20,
    iron_golem = 21,
    snow_golem = 22,
    dolphin = 23,
    llama = 24,
    polar_bear = 25,
    goat = 26,
    enderman = 27,
    spider = 28,
    cave_spider = 29,
    zombified_piglin = 30,
    piglin = 31,
    // Hostile 40-79
    zombie = 40,
    skeleton = 41,
    creeper = 42,
    witch = 43,
    slime = 44,
    magma_cube = 45,
    phantom = 46,
    drowned = 47,
    husk = 48,
    stray = 49,
    wither_skeleton = 50,
    blaze = 51,
    ghast = 52,
    guardian = 53,
    elder_guardian = 54,
    shulker = 55,
    endermite = 56,
    silverfish = 57,
    vex = 58,
    pillager = 59,
    vindicator = 60,
    evoker = 61,
    ravager = 62,
    hoglin = 63,
    zoglin = 64,
    piglin_brute = 65,
    warden = 66,
    breeze = 67,
    // Boss 80-89
    ender_dragon = 80,
    wither = 81,
    // Ambient 90-99
    bat = 90,
    allay = 91,
    glow_squid = 92,
    squid = 93,
    // Water creature 100-109
    cod = 100,
    salmon = 101,
    tropical_fish = 102,
    pufferfish = 103,
    axolotl = 104,

    pub fn name(self: MobId) []const u8 {
        return @tagName(self);
    }
};

pub const MobInfo = struct {
    id: MobId,
    name: []const u8,
    category: MobCategory,
    max_health: f32,
    attack_damage: f32,
    base_speed: f32,
    spawn_weight: u16,
    spawn_min_group: u8,
    spawn_max_group: u8,
    is_undead: bool,
    is_arthropod: bool,
    burns_in_sunlight: bool,
    dimension: DimensionFilter,
};

fn m(
    id: MobId,
    cat: MobCategory,
    hp: f32,
    atk: f32,
    spd: f32,
    sw: u16,
    smin: u8,
    smax: u8,
    undead: bool,
    arthropod: bool,
    burns: bool,
    dim: DimensionFilter,
) MobInfo {
    return .{
        .id = id,
        .name = @tagName(id),
        .category = cat,
        .max_health = hp,
        .attack_damage = atk,
        .base_speed = spd,
        .spawn_weight = sw,
        .spawn_min_group = smin,
        .spawn_max_group = smax,
        .is_undead = undead,
        .is_arthropod = arthropod,
        .burns_in_sunlight = burns,
        .dimension = dim,
    };
}
const P = MobCategory.passive;
const N = MobCategory.neutral;
const H = MobCategory.hostile;
const B = MobCategory.boss;
const A = MobCategory.ambient;
const W = MobCategory.water_creature;
const ANY = DimensionFilter.any;
const OW = DimensionFilter.overworld_only;
const NE = DimensionFilter.nether_only;
const EN = DimensionFilter.end_only;

//                          id                    cat  hp     atk   spd   sw  mn mx  und  arth burn dim
pub const MOB_REGISTRY = [_]MobInfo{
    m(.pig,              P,  10,   0,    0.25, 10, 1, 3, false, false, false, OW),
    m(.cow,              P,  10,   0,    0.20, 8,  1, 3, false, false, false, OW),
    m(.sheep,            P,  8,    0,    0.23, 12, 1, 3, false, false, false, OW),
    m(.chicken,          P,  4,    0,    0.25, 10, 1, 3, false, false, false, OW),
    m(.horse,            P,  30,   0,    0.22, 5,  1, 3, false, false, false, OW),
    m(.donkey,           P,  30,   0,    0.17, 1,  1, 1, false, false, false, OW),
    m(.mule,             P,  30,   0,    0.17, 0,  1, 1, false, false, false, OW),
    m(.rabbit,           P,  3,    0,    0.30, 4,  1, 3, false, false, false, OW),
    m(.mooshroom,        P,  10,   0,    0.20, 8,  1, 3, false, false, false, OW),
    m(.ocelot,           P,  10,   0,    0.30, 2,  1, 1, false, false, false, OW),
    m(.cat,              P,  10,   0,    0.30, 0,  1, 1, false, false, false, OW),
    m(.parrot,           P,  6,    0,    0.20, 1,  1, 2, false, false, false, OW),
    m(.fox,              P,  10,   0,    0.30, 8,  1, 3, false, false, false, OW),
    m(.panda,            P,  20,   0,    0.15, 1,  1, 2, false, false, false, OW),
    m(.bee,              P,  10,   0,    0.30, 3,  1, 3, false, true,  false, OW),
    m(.turtle,           P,  30,   0,    0.10, 5,  1, 5, false, false, false, OW),
    m(.frog,             P,  10,   0,    0.25, 5,  1, 3, false, false, false, OW),
    m(.sniffer,          P,  14,   0,    0.10, 0,  1, 1, false, false, false, OW),
    m(.armadillo,        P,  12,   0,    0.14, 5,  1, 3, false, false, false, OW),
    m(.camel,            P,  32,   0,    0.09, 1,  1, 1, false, false, false, OW),
    // Neutral
    m(.wolf,             N,  8,    4,    0.30, 5,  1, 4, false, false, false, OW),
    m(.iron_golem,       N,  100,  15,   0.25, 0,  1, 1, false, false, false, OW),
    m(.snow_golem,       N,  4,    0,    0.20, 0,  1, 1, false, false, false, OW),
    m(.dolphin,          N,  10,   3,    0.30, 3,  1, 3, false, false, false, OW),
    m(.llama,            N,  22,   1,    0.17, 5,  1, 3, false, false, false, OW),
    m(.polar_bear,       N,  30,   6,    0.25, 1,  1, 2, false, false, false, OW),
    m(.goat,             N,  10,   2,    0.20, 5,  1, 3, false, false, false, OW),
    m(.enderman,         N,  40,   7,    0.30, 10, 1, 4, false, false, false, ANY),
    m(.spider,           N,  16,   2,    0.30, 100,1, 3, false, true,  false, OW),
    m(.cave_spider,      N,  12,   2,    0.30, 100,1, 3, false, true,  false, OW),
    m(.zombified_piglin, N,  20,   5,    0.23, 100,2, 4, true,  false, false, NE),
    m(.piglin,           N,  16,   5,    0.35, 15, 2, 4, false, false, false, NE),
    // Hostile
    m(.zombie,           H,  20,   3,    0.23, 100,1, 4, true,  false, true,  OW),
    m(.skeleton,         H,  20,   2,    0.25, 100,1, 4, true,  false, true,  OW),
    m(.creeper,          H,  20,   0,    0.25, 100,1, 1, false, false, false, OW),
    m(.witch,            H,  26,   0,    0.25, 5,  1, 1, false, false, false, OW),
    m(.slime,            H,  16,   4,    0.30, 10, 1, 4, false, false, false, OW),
    m(.magma_cube,       H,  16,   6,    0.30, 10, 1, 4, false, false, false, NE),
    m(.phantom,          H,  20,   6,    0.30, 0,  1, 1, true,  false, true,  OW),
    m(.drowned,          H,  20,   3,    0.23, 5,  1, 1, true,  false, true,  OW),
    m(.husk,             H,  20,   3,    0.23, 80, 1, 4, true,  false, false, OW),
    m(.stray,            H,  20,   2,    0.25, 80, 1, 4, true,  false, false, OW),
    m(.wither_skeleton,  H,  20,   8,    0.25, 10, 1, 5, true,  false, false, NE),
    m(.blaze,            H,  20,   6,    0.23, 10, 1, 3, false, false, false, NE),
    m(.ghast,            H,  10,   6,    0.20, 50, 1, 1, false, false, false, NE),
    m(.guardian,         H,  30,   6,    0.50, 10, 1, 4, false, false, false, OW),
    m(.elder_guardian,   H,  80,   8,    0.30, 0,  1, 1, false, false, false, OW),
    m(.shulker,          H,  30,   4,    0.00, 0,  1, 1, false, false, false, EN),
    m(.endermite,        H,  8,    2,    0.25, 0,  1, 1, false, true,  false, EN),
    m(.silverfish,       H,  8,    1,    0.25, 10, 1, 4, false, true,  false, OW),
    m(.vex,              H,  14,   9,    0.30, 0,  1, 3, false, false, false, OW),
    m(.pillager,         H,  24,   5,    0.35, 0,  1, 1, false, false, false, OW),
    m(.vindicator,       H,  24,   13,   0.35, 0,  1, 1, false, false, false, OW),
    m(.evoker,           H,  24,   6,    0.50, 0,  1, 1, false, false, false, OW),
    m(.ravager,          H,  100,  12,   0.30, 0,  1, 1, false, false, false, OW),
    m(.hoglin,           H,  40,   6,    0.30, 9,  1, 4, false, false, false, NE),
    m(.zoglin,           H,  40,   6,    0.30, 0,  1, 1, false, false, false, OW),
    m(.piglin_brute,     H,  50,   7,    0.35, 0,  1, 1, false, false, false, NE),
    m(.warden,           H,  500,  30,   0.30, 0,  1, 1, false, false, false, OW),
    m(.breeze,           H,  30,   3,    0.60, 0,  1, 1, false, false, false, OW),
    // Boss
    m(.ender_dragon,     B,  200,  10,   0.30, 0,  1, 1, false, false, false, EN),
    m(.wither,           B,  300,  8,    0.25, 0,  1, 1, true,  false, false, ANY),
    // Ambient
    m(.bat,              A,  6,    0,    0.10, 10, 1, 8, false, false, false, OW),
    m(.allay,            A,  20,   0,    0.10, 0,  1, 3, false, false, false, OW),
    m(.glow_squid,       A,  10,   0,    0.06, 10, 1, 4, false, false, false, OW),
    m(.squid,            A,  10,   0,    0.06, 10, 1, 4, false, false, false, OW),
    // Water creature
    m(.cod,              W,  3,    0,    0.12, 15, 3, 6, false, false, false, OW),
    m(.salmon,           W,  3,    0,    0.12, 15, 1, 5, false, false, false, OW),
    m(.tropical_fish,    W,  3,    0,    0.12, 25, 3, 5, false, false, false, OW),
    m(.pufferfish,       W,  3,    2,    0.12, 15, 1, 3, false, false, false, OW),
    m(.axolotl,          W,  14,   2,    0.10, 5,  1, 4, false, false, false, OW),
};

pub fn getMobInfo(id: MobId) ?MobInfo {
    for (MOB_REGISTRY) |info| {
        if (info.id == id) return info;
    }
    return null;
}

pub fn getMobByName(mob_name: []const u8) ?MobInfo {
    for (MOB_REGISTRY) |info| {
        if (std.mem.eql(u8, info.name, mob_name)) return info;
    }
    return null;
}

/// Returns true when `attacker` is inherently hostile toward players.
/// Hostile mobs and bosses are always hostile. Neutral mobs are not
/// (they only retaliate). Passive/ambient/water creatures are never hostile.
pub fn isHostileTo(attacker: MobId) bool {
    if (getMobInfo(attacker)) |info| {
        return info.category == .hostile or info.category == .boss;
    }
    return false;
}

// ── Tests ──────────────────────────────────────────────────────────────

test "zombie is undead and burns in sunlight" {
    const z = getMobInfo(.zombie).?;
    try std.testing.expect(z.is_undead);
    try std.testing.expect(z.burns_in_sunlight);
}

test "skeleton is undead" {
    const s = getMobInfo(.skeleton).?;
    try std.testing.expect(s.is_undead);
}

test "creeper is not undead" {
    const c = getMobInfo(.creeper).?;
    try std.testing.expect(!c.is_undead);
}

test "iron_golem is neutral" {
    const ig = getMobInfo(.iron_golem).?;
    try std.testing.expectEqual(MobCategory.neutral, ig.category);
}

test "ender_dragon is boss" {
    const d = getMobInfo(.ender_dragon).?;
    try std.testing.expectEqual(MobCategory.boss, d.category);
    try std.testing.expectEqual(DimensionFilter.end_only, d.dimension);
}

test "mob count per category" {
    var counts = [_]u32{0} ** 6;
    for (MOB_REGISTRY) |info| {
        counts[@intFromEnum(info.category)] += 1;
    }
    // passive=20, neutral=12, hostile=28, boss=2, ambient=4, water=5
    try std.testing.expectEqual(@as(u32, 20), counts[@intFromEnum(MobCategory.passive)]);
    try std.testing.expectEqual(@as(u32, 12), counts[@intFromEnum(MobCategory.neutral)]);
    try std.testing.expectEqual(@as(u32, 28), counts[@intFromEnum(MobCategory.hostile)]);
    try std.testing.expectEqual(@as(u32, 2), counts[@intFromEnum(MobCategory.boss)]);
    try std.testing.expectEqual(@as(u32, 4), counts[@intFromEnum(MobCategory.ambient)]);
    try std.testing.expectEqual(@as(u32, 5), counts[@intFromEnum(MobCategory.water_creature)]);
}

test "total mob count is 71" {
    try std.testing.expectEqual(@as(usize, 71), MOB_REGISTRY.len);
}

test "dimension filtering - nether mobs" {
    var nether_count: u32 = 0;
    for (MOB_REGISTRY) |info| {
        if (info.dimension == .nether_only) nether_count += 1;
    }
    try std.testing.expect(nether_count >= 5);
}

test "name lookup finds zombie" {
    const z = getMobByName("zombie").?;
    try std.testing.expectEqual(MobId.zombie, z.id);
}

test "name lookup returns null for unknown" {
    try std.testing.expectEqual(@as(?MobInfo, null), getMobByName("herobrine"));
}

test "spider is arthropod" {
    const s = getMobInfo(.spider).?;
    try std.testing.expect(s.is_arthropod);
    const cs = getMobInfo(.cave_spider).?;
    try std.testing.expect(cs.is_arthropod);
}

test "hostility checks" {
    try std.testing.expect(isHostileTo(.zombie));
    try std.testing.expect(isHostileTo(.ender_dragon));
    try std.testing.expect(!isHostileTo(.pig));
    try std.testing.expect(!isHostileTo(.iron_golem));
    try std.testing.expect(!isHostileTo(.cod));
}

test "wither is undead boss" {
    const w = getMobInfo(.wither).?;
    try std.testing.expectEqual(MobCategory.boss, w.category);
    try std.testing.expect(w.is_undead);
}
