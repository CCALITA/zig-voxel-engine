/// Complete enchantment registry covering all vanilla Minecraft enchantments.
/// Provides enchantment metadata, compatibility checks, anvil costs, rarity weights,
/// and slot applicability for all 39 enchantments.

const std = @import("std");

// ---------------------------------------------------------------------------
// Slot mask — which equipment slots an enchantment can apply to
// ---------------------------------------------------------------------------

pub const SlotMask = packed struct(u16) {
    helmet: bool = false,
    chestplate: bool = false,
    leggings: bool = false,
    boots: bool = false,
    sword: bool = false,
    axe: bool = false,
    pickaxe: bool = false,
    shovel: bool = false,
    hoe: bool = false,
    bow: bool = false,
    crossbow: bool = false,
    trident: bool = false,
    fishing_rod: bool = false,
    shears: bool = false,
    elytra: bool = false,
    _pad: bool = false,

    pub const all_armor: SlotMask = .{ .helmet = true, .chestplate = true, .leggings = true, .boots = true };
    pub const all_melee: SlotMask = .{ .sword = true, .axe = true };
    pub const all_tools: SlotMask = .{ .pickaxe = true, .shovel = true, .hoe = true, .axe = true };
    pub const boots_only: SlotMask = .{ .boots = true };
    pub const helmet_only: SlotMask = .{ .helmet = true };
    pub const leggings_only: SlotMask = .{ .leggings = true };
    pub const sword_only: SlotMask = .{ .sword = true };
    pub const bow_only: SlotMask = .{ .bow = true };
    pub const crossbow_only: SlotMask = .{ .crossbow = true };
    pub const trident_only: SlotMask = .{ .trident = true };
    pub const fishing_only: SlotMask = .{ .fishing_rod = true };

    pub const any: SlotMask = .{
        .helmet = true, .chestplate = true, .leggings = true, .boots = true,
        .sword = true, .axe = true, .pickaxe = true, .shovel = true, .hoe = true,
        .bow = true, .crossbow = true, .trident = true, .fishing_rod = true,
        .shears = true, .elytra = true,
    };

    pub const breakable: SlotMask = any; // alias for mending/unbreaking
};

// ---------------------------------------------------------------------------
// Slot type for canApplyTo queries
// ---------------------------------------------------------------------------

pub const SlotType = enum {
    helmet, chestplate, leggings, boots,
    sword, axe, pickaxe, shovel, hoe,
    bow, crossbow, trident, fishing_rod,
    shears, elytra,
};

// ---------------------------------------------------------------------------
// Rarity
// ---------------------------------------------------------------------------

pub const EnchantRarity = enum {
    common,
    uncommon,
    rare,
    very_rare,
};

// ---------------------------------------------------------------------------
// Enchantment id — all 39 vanilla enchantments
// ---------------------------------------------------------------------------

pub const EnchantId = enum(u8) {
    // Melee
    sharpness = 0,
    smite = 1,
    bane_of_arthropods = 2,
    knockback = 3,
    fire_aspect = 4,
    looting = 5,
    sweeping_edge = 6,
    // Armor
    protection = 7,
    fire_protection = 8,
    blast_protection = 9,
    projectile_protection = 10,
    thorns = 11,
    respiration = 12,
    aqua_affinity = 13,
    depth_strider = 14,
    frost_walker = 15,
    soul_speed = 16,
    swift_sneak = 17,
    feather_falling = 18,
    // Bow
    power = 19,
    punch = 20,
    flame = 21,
    infinity = 22,
    // Crossbow
    multishot = 23,
    quick_charge = 24,
    piercing = 25,
    // Trident
    loyalty = 26,
    riptide = 27,
    channeling = 28,
    impaling = 29,
    // Tool
    efficiency = 30,
    silk_touch = 31,
    fortune = 32,
    unbreaking = 33,
    // General
    mending = 34,
    curse_of_vanishing = 35,
    curse_of_binding = 36,
    // Fishing
    luck_of_the_sea = 37,
    lure = 38,
};

// ---------------------------------------------------------------------------
// Enchantment info struct
// ---------------------------------------------------------------------------

pub const EnchantInfo = struct {
    id: EnchantId,
    name: []const u8,
    max_level: u3,
    rarity: EnchantRarity,
    applicable_slots: SlotMask,
    is_curse: bool,
    is_treasure: bool,
};

// ---------------------------------------------------------------------------
// Complete enchantment table — all 39 entries
// ---------------------------------------------------------------------------

pub const ALL_ENCHANTS = [_]EnchantInfo{
    // Melee
    .{ .id = .sharpness,          .name = "Sharpness",            .max_level = 5, .rarity = .common,    .applicable_slots = SlotMask.all_melee,     .is_curse = false, .is_treasure = false },
    .{ .id = .smite,              .name = "Smite",                .max_level = 5, .rarity = .uncommon,  .applicable_slots = SlotMask.all_melee,     .is_curse = false, .is_treasure = false },
    .{ .id = .bane_of_arthropods, .name = "Bane of Arthropods",   .max_level = 5, .rarity = .uncommon,  .applicable_slots = SlotMask.all_melee,     .is_curse = false, .is_treasure = false },
    .{ .id = .knockback,          .name = "Knockback",            .max_level = 2, .rarity = .uncommon,  .applicable_slots = SlotMask.sword_only,    .is_curse = false, .is_treasure = false },
    .{ .id = .fire_aspect,        .name = "Fire Aspect",          .max_level = 2, .rarity = .rare,      .applicable_slots = SlotMask.sword_only,    .is_curse = false, .is_treasure = false },
    .{ .id = .looting,            .name = "Looting",              .max_level = 3, .rarity = .rare,      .applicable_slots = SlotMask.sword_only,    .is_curse = false, .is_treasure = false },
    .{ .id = .sweeping_edge,      .name = "Sweeping Edge",        .max_level = 3, .rarity = .rare,      .applicable_slots = SlotMask.sword_only,    .is_curse = false, .is_treasure = false },
    // Armor
    .{ .id = .protection,              .name = "Protection",              .max_level = 4, .rarity = .common,    .applicable_slots = SlotMask.all_armor,    .is_curse = false, .is_treasure = false },
    .{ .id = .fire_protection,         .name = "Fire Protection",         .max_level = 4, .rarity = .uncommon,  .applicable_slots = SlotMask.all_armor,    .is_curse = false, .is_treasure = false },
    .{ .id = .blast_protection,        .name = "Blast Protection",        .max_level = 4, .rarity = .rare,      .applicable_slots = SlotMask.all_armor,    .is_curse = false, .is_treasure = false },
    .{ .id = .projectile_protection,   .name = "Projectile Protection",   .max_level = 4, .rarity = .uncommon,  .applicable_slots = SlotMask.all_armor,    .is_curse = false, .is_treasure = false },
    .{ .id = .thorns,                  .name = "Thorns",                  .max_level = 3, .rarity = .very_rare, .applicable_slots = SlotMask.all_armor,    .is_curse = false, .is_treasure = false },
    .{ .id = .respiration,             .name = "Respiration",             .max_level = 3, .rarity = .rare,      .applicable_slots = SlotMask.helmet_only,  .is_curse = false, .is_treasure = false },
    .{ .id = .aqua_affinity,           .name = "Aqua Affinity",           .max_level = 1, .rarity = .rare,      .applicable_slots = SlotMask.helmet_only,  .is_curse = false, .is_treasure = false },
    .{ .id = .depth_strider,           .name = "Depth Strider",           .max_level = 3, .rarity = .rare,      .applicable_slots = SlotMask.boots_only,   .is_curse = false, .is_treasure = false },
    .{ .id = .frost_walker,            .name = "Frost Walker",            .max_level = 2, .rarity = .rare,      .applicable_slots = SlotMask.boots_only,   .is_curse = false, .is_treasure = true },
    .{ .id = .soul_speed,              .name = "Soul Speed",              .max_level = 3, .rarity = .very_rare, .applicable_slots = SlotMask.boots_only,   .is_curse = false, .is_treasure = true },
    .{ .id = .swift_sneak,             .name = "Swift Sneak",             .max_level = 3, .rarity = .very_rare, .applicable_slots = SlotMask.leggings_only,.is_curse = false, .is_treasure = true },
    .{ .id = .feather_falling,         .name = "Feather Falling",         .max_level = 4, .rarity = .uncommon,  .applicable_slots = SlotMask.boots_only,   .is_curse = false, .is_treasure = false },
    // Bow
    .{ .id = .power,    .name = "Power",    .max_level = 5, .rarity = .common,    .applicable_slots = SlotMask.bow_only,      .is_curse = false, .is_treasure = false },
    .{ .id = .punch,    .name = "Punch",    .max_level = 2, .rarity = .rare,      .applicable_slots = SlotMask.bow_only,      .is_curse = false, .is_treasure = false },
    .{ .id = .flame,    .name = "Flame",    .max_level = 1, .rarity = .rare,      .applicable_slots = SlotMask.bow_only,      .is_curse = false, .is_treasure = false },
    .{ .id = .infinity, .name = "Infinity", .max_level = 1, .rarity = .very_rare, .applicable_slots = SlotMask.bow_only,      .is_curse = false, .is_treasure = false },
    // Crossbow
    .{ .id = .multishot,    .name = "Multishot",    .max_level = 1, .rarity = .rare,     .applicable_slots = SlotMask.crossbow_only, .is_curse = false, .is_treasure = false },
    .{ .id = .quick_charge, .name = "Quick Charge", .max_level = 3, .rarity = .uncommon, .applicable_slots = SlotMask.crossbow_only, .is_curse = false, .is_treasure = false },
    .{ .id = .piercing,     .name = "Piercing",     .max_level = 4, .rarity = .common,   .applicable_slots = SlotMask.crossbow_only, .is_curse = false, .is_treasure = false },
    // Trident
    .{ .id = .loyalty,    .name = "Loyalty",    .max_level = 3, .rarity = .uncommon,  .applicable_slots = SlotMask.trident_only, .is_curse = false, .is_treasure = false },
    .{ .id = .riptide,    .name = "Riptide",    .max_level = 3, .rarity = .rare,      .applicable_slots = SlotMask.trident_only, .is_curse = false, .is_treasure = false },
    .{ .id = .channeling, .name = "Channeling", .max_level = 1, .rarity = .very_rare, .applicable_slots = SlotMask.trident_only, .is_curse = false, .is_treasure = false },
    .{ .id = .impaling,   .name = "Impaling",   .max_level = 5, .rarity = .rare,      .applicable_slots = SlotMask.trident_only, .is_curse = false, .is_treasure = false },
    // Tool
    .{ .id = .efficiency, .name = "Efficiency", .max_level = 5, .rarity = .common,    .applicable_slots = SlotMask.all_tools,    .is_curse = false, .is_treasure = false },
    .{ .id = .silk_touch, .name = "Silk Touch", .max_level = 1, .rarity = .very_rare, .applicable_slots = SlotMask.all_tools,    .is_curse = false, .is_treasure = false },
    .{ .id = .fortune,    .name = "Fortune",    .max_level = 3, .rarity = .rare,      .applicable_slots = SlotMask.all_tools,    .is_curse = false, .is_treasure = false },
    .{ .id = .unbreaking, .name = "Unbreaking", .max_level = 3, .rarity = .uncommon,  .applicable_slots = SlotMask.breakable,    .is_curse = false, .is_treasure = false },
    // General
    .{ .id = .mending,            .name = "Mending",            .max_level = 1, .rarity = .rare,      .applicable_slots = SlotMask.breakable, .is_curse = false, .is_treasure = true },
    .{ .id = .curse_of_vanishing, .name = "Curse of Vanishing", .max_level = 1, .rarity = .very_rare, .applicable_slots = SlotMask.any,       .is_curse = true,  .is_treasure = true },
    .{ .id = .curse_of_binding,   .name = "Curse of Binding",   .max_level = 1, .rarity = .very_rare, .applicable_slots = SlotMask.all_armor, .is_curse = true,  .is_treasure = true },
    // Fishing
    .{ .id = .luck_of_the_sea, .name = "Luck of the Sea", .max_level = 3, .rarity = .rare,     .applicable_slots = SlotMask.fishing_only, .is_curse = false, .is_treasure = false },
    .{ .id = .lure,            .name = "Lure",            .max_level = 3, .rarity = .rare,      .applicable_slots = SlotMask.fishing_only, .is_curse = false, .is_treasure = false },
};

/// Total number of enchantments in the registry.
pub const ENCHANT_COUNT = ALL_ENCHANTS.len; // 39

// ---------------------------------------------------------------------------
// Lookup helpers
// ---------------------------------------------------------------------------

/// Look up the EnchantInfo for a given id via direct index.
pub fn getInfo(id: EnchantId) EnchantInfo {
    return ALL_ENCHANTS[@intFromEnum(id)];
}

// ---------------------------------------------------------------------------
// Compatibility rules
// ---------------------------------------------------------------------------

/// Returns true if enchantments a and b can coexist on the same item.
pub fn areCompatible(a: EnchantId, b: EnchantId) bool {
    if (a == b) return false;

    // Helper: check if both are in a mutually exclusive group
    const sharp_group = [_]EnchantId{ .sharpness, .smite, .bane_of_arthropods };
    if (inGroup(&sharp_group, a) and inGroup(&sharp_group, b)) return false;

    const prot_group = [_]EnchantId{ .protection, .fire_protection, .blast_protection, .projectile_protection };
    if (inGroup(&prot_group, a) and inGroup(&prot_group, b)) return false;

    if (exclusivePair(a, b, .silk_touch, .fortune)) return false;
    if (exclusivePair(a, b, .infinity, .mending)) return false;
    if (exclusivePair(a, b, .multishot, .piercing)) return false;
    if (exclusivePair(a, b, .depth_strider, .frost_walker)) return false;

    // Riptide is incompatible with loyalty and channeling
    if (exclusivePair(a, b, .riptide, .loyalty)) return false;
    if (exclusivePair(a, b, .riptide, .channeling)) return false;

    return true;
}

fn inGroup(group: []const EnchantId, id: EnchantId) bool {
    for (group) |g| {
        if (g == id) return true;
    }
    return false;
}

fn exclusivePair(a: EnchantId, b: EnchantId, x: EnchantId, y: EnchantId) bool {
    return (a == x and b == y) or (a == y and b == x);
}

// ---------------------------------------------------------------------------
// Anvil XP cost
// ---------------------------------------------------------------------------

/// Returns the anvil XP cost for applying an enchantment at a given level.
pub fn getEnchantCost(id: EnchantId, level: u3) u8 {
    const info = getInfo(id);
    const clamped: u8 = @min(level, info.max_level);
    const base: u8 = switch (id) {
        .sharpness, .smite, .bane_of_arthropods => 1,
        .knockback, .punch => 2,
        .fire_aspect, .flame => 4,
        .looting, .fortune, .luck_of_the_sea => 4,
        .sweeping_edge => 2,
        .protection, .fire_protection, .blast_protection, .projectile_protection => 1,
        .feather_falling => 1,
        .thorns => 4,
        .respiration => 2,
        .aqua_affinity => 2,
        .depth_strider => 2,
        .frost_walker => 2,
        .soul_speed => 4,
        .swift_sneak => 4,
        .power => 1,
        .infinity => 8,
        .multishot => 4,
        .quick_charge => 2,
        .piercing => 1,
        .loyalty => 1,
        .riptide => 2,
        .channeling => 4,
        .impaling => 2,
        .efficiency => 1,
        .silk_touch => 8,
        .unbreaking => 1,
        .mending => 4,
        .curse_of_vanishing => 1,
        .curse_of_binding => 1,
        .lure => 2,
    };
    return base * clamped;
}

// ---------------------------------------------------------------------------
// Enchantment weight (for random selection)
// ---------------------------------------------------------------------------

/// Returns the weight used when randomly selecting enchantments from an enchanting table.
pub fn getEnchantWeight(id: EnchantId) u16 {
    const info = getInfo(id);
    return switch (info.rarity) {
        .common => 10,
        .uncommon => 5,
        .rare => 2,
        .very_rare => 1,
    };
}

// ---------------------------------------------------------------------------
// Slot applicability
// ---------------------------------------------------------------------------

/// Returns true if the enchantment can be applied to the given slot type.
pub fn canApplyTo(id: EnchantId, slot: SlotType) bool {
    const info = getInfo(id);
    const mask = info.applicable_slots;
    return switch (slot) {
        .helmet => mask.helmet,
        .chestplate => mask.chestplate,
        .leggings => mask.leggings,
        .boots => mask.boots,
        .sword => mask.sword,
        .axe => mask.axe,
        .pickaxe => mask.pickaxe,
        .shovel => mask.shovel,
        .hoe => mask.hoe,
        .bow => mask.bow,
        .crossbow => mask.crossbow,
        .trident => mask.trident,
        .fishing_rod => mask.fishing_rod,
        .shears => mask.shears,
        .elytra => mask.elytra,
    };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "all 39 enchantments are present" {
    try std.testing.expectEqual(@as(usize, 39), ALL_ENCHANTS.len);
}

test "sharpness max level is 5" {
    const info = getInfo(.sharpness);
    try std.testing.expectEqual(@as(u3, 5), info.max_level);
}

test "mending max level is 1" {
    const info = getInfo(.mending);
    try std.testing.expectEqual(@as(u3, 1), info.max_level);
}

test "efficiency max level is 5" {
    const info = getInfo(.efficiency);
    try std.testing.expectEqual(@as(u3, 5), info.max_level);
}

test "curses are identified correctly" {
    try std.testing.expect(getInfo(.curse_of_vanishing).is_curse);
    try std.testing.expect(getInfo(.curse_of_binding).is_curse);
    try std.testing.expect(!getInfo(.sharpness).is_curse);
    try std.testing.expect(!getInfo(.mending).is_curse);
}

test "treasure-only enchants identified" {
    try std.testing.expect(getInfo(.mending).is_treasure);
    try std.testing.expect(getInfo(.frost_walker).is_treasure);
    try std.testing.expect(getInfo(.soul_speed).is_treasure);
    try std.testing.expect(getInfo(.curse_of_vanishing).is_treasure);
    try std.testing.expect(!getInfo(.sharpness).is_treasure);
    try std.testing.expect(!getInfo(.efficiency).is_treasure);
}

test "sharpness/smite/bane mutually exclusive" {
    try std.testing.expect(!areCompatible(.sharpness, .smite));
    try std.testing.expect(!areCompatible(.smite, .bane_of_arthropods));
    try std.testing.expect(!areCompatible(.sharpness, .bane_of_arthropods));
}

test "protection types mutually exclusive" {
    try std.testing.expect(!areCompatible(.protection, .fire_protection));
    try std.testing.expect(!areCompatible(.protection, .blast_protection));
    try std.testing.expect(!areCompatible(.fire_protection, .projectile_protection));
}

test "silk touch and fortune exclusive" {
    try std.testing.expect(!areCompatible(.silk_touch, .fortune));
    try std.testing.expect(!areCompatible(.fortune, .silk_touch));
}

test "infinity and mending exclusive" {
    try std.testing.expect(!areCompatible(.infinity, .mending));
}

test "frost walker and depth strider exclusive" {
    try std.testing.expect(!areCompatible(.frost_walker, .depth_strider));
    try std.testing.expect(!areCompatible(.depth_strider, .frost_walker));
}

test "multishot and piercing exclusive" {
    try std.testing.expect(!areCompatible(.multishot, .piercing));
}

test "riptide incompatible with loyalty and channeling" {
    try std.testing.expect(!areCompatible(.riptide, .loyalty));
    try std.testing.expect(!areCompatible(.riptide, .channeling));
    // loyalty and channeling ARE compatible with each other
    try std.testing.expect(areCompatible(.loyalty, .channeling));
}

test "compatible enchants pass" {
    try std.testing.expect(areCompatible(.sharpness, .unbreaking));
    try std.testing.expect(areCompatible(.efficiency, .unbreaking));
    try std.testing.expect(areCompatible(.power, .flame));
    try std.testing.expect(areCompatible(.looting, .sharpness));
}

test "slot applicability" {
    try std.testing.expect(canApplyTo(.sharpness, .sword));
    try std.testing.expect(canApplyTo(.sharpness, .axe));
    try std.testing.expect(!canApplyTo(.sharpness, .bow));
    try std.testing.expect(canApplyTo(.protection, .helmet));
    try std.testing.expect(canApplyTo(.protection, .boots));
    try std.testing.expect(!canApplyTo(.protection, .sword));
    try std.testing.expect(canApplyTo(.efficiency, .pickaxe));
    try std.testing.expect(!canApplyTo(.efficiency, .sword));
    try std.testing.expect(canApplyTo(.mending, .sword));
    try std.testing.expect(canApplyTo(.mending, .boots));
    try std.testing.expect(canApplyTo(.frost_walker, .boots));
    try std.testing.expect(!canApplyTo(.frost_walker, .helmet));
}

test "enchant cost calculation" {
    // sharpness 5: base 1 * 5 = 5
    try std.testing.expectEqual(@as(u8, 5), getEnchantCost(.sharpness, 5));
    // silk touch 1: base 8 * 1 = 8
    try std.testing.expectEqual(@as(u8, 8), getEnchantCost(.silk_touch, 1));
    // infinity 1: base 8 * 1 = 8
    try std.testing.expectEqual(@as(u8, 8), getEnchantCost(.infinity, 1));
    // mending 1: base 4 * 1 = 4
    try std.testing.expectEqual(@as(u8, 4), getEnchantCost(.mending, 1));
    // protection 4: base 1 * 4 = 4
    try std.testing.expectEqual(@as(u8, 4), getEnchantCost(.protection, 4));
}

test "weight values match rarity" {
    try std.testing.expectEqual(@as(u16, 10), getEnchantWeight(.sharpness));   // common
    try std.testing.expectEqual(@as(u16, 5), getEnchantWeight(.unbreaking));   // uncommon
    try std.testing.expectEqual(@as(u16, 2), getEnchantWeight(.fortune));      // rare
    try std.testing.expectEqual(@as(u16, 1), getEnchantWeight(.silk_touch));   // very_rare
}

test "same enchantment is not compatible with itself" {
    try std.testing.expect(!areCompatible(.sharpness, .sharpness));
    try std.testing.expect(!areCompatible(.mending, .mending));
}
