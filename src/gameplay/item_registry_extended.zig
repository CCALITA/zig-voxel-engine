/// Extended item registry covering weapons, tools, food, potions, transport,
/// utility items, music discs, and spawn eggs that are not present in the base
/// item_registry.zig.  All IDs start at 200 to avoid collisions with the base
/// registry (0-327).
///
/// Design: every value is comptime-known.  Lookup helpers use linear scans over
/// a fixed-size array (acceptable for ~120 items that never change at runtime).

const std = @import("std");

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

pub const Rarity = enum {
    common,
    uncommon,
    rare,
    epic,
};

pub const ExtendedItemInfo = struct {
    id: u16,
    name: []const u8,
    max_stack: u8 = 64,
    durability: u16 = 0,
    is_tool: bool = false,
    is_weapon: bool = false,
    is_food: bool = false,
    is_music_disc: bool = false,
    rarity: Rarity = .common,
};

// ---------------------------------------------------------------------------
// Music disc helpers (comptime)
// ---------------------------------------------------------------------------

const DISC_NAMES = [_][]const u8{
    "music_disc_13",
    "music_disc_cat",
    "music_disc_blocks",
    "music_disc_chirp",
    "music_disc_far",
    "music_disc_mall",
    "music_disc_mellohi",
    "music_disc_stal",
    "music_disc_strad",
    "music_disc_ward",
    "music_disc_11",
    "music_disc_wait",
    "music_disc_pigstep",
    "music_disc_otherside",
    "music_disc_5",
    "music_disc_relic",
};

const DISC_START_ID: u16 = 700;
const DISC_COUNT = DISC_NAMES.len; // 16

fn discRarity(idx: usize) Rarity {
    return switch (idx) {
        12 => .rare, // pigstep
        13 => .rare, // otherside
        14 => .rare, // 5
        15 => .rare, // relic
        else => .common,
    };
}

// ---------------------------------------------------------------------------
// Spawn egg helpers (comptime)
// ---------------------------------------------------------------------------

const SPAWN_EGG_NAMES = [_][]const u8{
    "spawn_egg_zombie",
    "spawn_egg_skeleton",
    "spawn_egg_creeper",
    "spawn_egg_spider",
    "spawn_egg_enderman",
    "spawn_egg_slime",
    "spawn_egg_pig",
    "spawn_egg_cow",
    "spawn_egg_sheep",
    "spawn_egg_chicken",
    "spawn_egg_wolf",
    "spawn_egg_villager",
    "spawn_egg_blaze",
    "spawn_egg_ghast",
    "spawn_egg_witch",
    "spawn_egg_guardian",
    "spawn_egg_rabbit",
    "spawn_egg_phantom",
    "spawn_egg_drowned",
    "spawn_egg_bee",
};

const SPAWN_EGG_START_ID: u16 = 800;
const SPAWN_EGG_COUNT = SPAWN_EGG_NAMES.len; // 20

// ---------------------------------------------------------------------------
// Explicit item tables
// ---------------------------------------------------------------------------

const WEAPON_ITEMS = [_]ExtendedItemInfo{
    .{ .id = 200, .name = "bow", .max_stack = 1, .durability = 385, .is_weapon = true },
    .{ .id = 201, .name = "crossbow", .max_stack = 1, .durability = 465, .is_weapon = true },
    .{ .id = 202, .name = "trident", .max_stack = 1, .durability = 250, .is_weapon = true, .rarity = .rare },
    .{ .id = 203, .name = "shield", .max_stack = 1, .durability = 336, .is_tool = true },
};

const TOOL_ITEMS = [_]ExtendedItemInfo{
    .{ .id = 210, .name = "spyglass", .max_stack = 1, .is_tool = true },
    .{ .id = 211, .name = "brush", .max_stack = 1, .durability = 64, .is_tool = true },
    .{ .id = 212, .name = "shears", .max_stack = 1, .durability = 238, .is_tool = true },
    .{ .id = 213, .name = "flint_and_steel", .max_stack = 1, .durability = 64, .is_tool = true },
    .{ .id = 214, .name = "fishing_rod", .max_stack = 1, .durability = 64, .is_tool = true },
    .{ .id = 215, .name = "lead", .is_tool = true },
    .{ .id = 216, .name = "name_tag", .is_tool = true },
    .{ .id = 217, .name = "warped_fungus_on_a_stick", .max_stack = 1, .durability = 100, .is_tool = true },
    .{ .id = 218, .name = "carrot_on_a_stick", .max_stack = 1, .durability = 25, .is_tool = true },
};

const FOOD_ITEMS = [_]ExtendedItemInfo{
    .{ .id = 230, .name = "golden_carrot", .is_food = true, .rarity = .uncommon },
    .{ .id = 231, .name = "pumpkin_pie", .is_food = true },
    .{ .id = 232, .name = "cake", .max_stack = 1, .is_food = true },
    .{ .id = 233, .name = "cookie", .is_food = true },
    .{ .id = 234, .name = "dried_kelp", .is_food = true },
    .{ .id = 235, .name = "honey_bottle", .max_stack = 16, .is_food = true },
    .{ .id = 236, .name = "sweet_berries", .is_food = true },
    .{ .id = 237, .name = "glow_berries", .is_food = true },
    .{ .id = 238, .name = "golden_apple", .is_food = true, .rarity = .rare },
    .{ .id = 239, .name = "enchanted_golden_apple", .is_food = true, .rarity = .epic },
    .{ .id = 240, .name = "chorus_fruit", .is_food = true },
    .{ .id = 241, .name = "spider_eye", .is_food = true },
    .{ .id = 242, .name = "poisonous_potato", .is_food = true },
    .{ .id = 243, .name = "beetroot", .is_food = true },
    .{ .id = 244, .name = "beetroot_soup", .max_stack = 1, .is_food = true },
    .{ .id = 245, .name = "mushroom_stew", .max_stack = 1, .is_food = true },
    .{ .id = 246, .name = "rabbit_stew", .max_stack = 1, .is_food = true },
    .{ .id = 247, .name = "suspicious_stew", .max_stack = 1, .is_food = true },
    .{ .id = 248, .name = "cooked_mutton", .is_food = true },
    .{ .id = 249, .name = "cooked_rabbit", .is_food = true },
    .{ .id = 250, .name = "cooked_salmon", .is_food = true },
    .{ .id = 251, .name = "cooked_cod", .is_food = true },
    .{ .id = 252, .name = "tropical_fish", .is_food = true },
    .{ .id = 253, .name = "pufferfish", .is_food = true },
    .{ .id = 254, .name = "melon_slice", .is_food = true },
    .{ .id = 255, .name = "raw_beef", .is_food = true },
    .{ .id = 350, .name = "cooked_beef", .is_food = true },
    .{ .id = 351, .name = "raw_porkchop", .is_food = true },
    .{ .id = 352, .name = "cooked_porkchop", .is_food = true },
    .{ .id = 353, .name = "raw_chicken", .is_food = true },
    .{ .id = 354, .name = "cooked_chicken", .is_food = true },
    .{ .id = 355, .name = "bread", .is_food = true },
    .{ .id = 356, .name = "apple", .is_food = true },
    .{ .id = 357, .name = "baked_potato", .is_food = true },
    .{ .id = 358, .name = "raw_mutton", .is_food = true },
    .{ .id = 359, .name = "raw_rabbit", .is_food = true },
    .{ .id = 360, .name = "raw_salmon", .is_food = true },
    .{ .id = 361, .name = "raw_cod", .is_food = true },
    .{ .id = 362, .name = "rotten_flesh", .is_food = true },
};

const POTION_ITEMS = [_]ExtendedItemInfo{
    .{ .id = 370, .name = "potion", .max_stack = 1 },
    .{ .id = 371, .name = "splash_potion", .max_stack = 1 },
    .{ .id = 372, .name = "lingering_potion", .max_stack = 1 },
    .{ .id = 373, .name = "dragon_breath", .max_stack = 64, .rarity = .uncommon },
    .{ .id = 374, .name = "experience_bottle", .max_stack = 64 },
    .{ .id = 375, .name = "glass_bottle", .max_stack = 64 },
};

const TRANSPORT_ITEMS = [_]ExtendedItemInfo{
    .{ .id = 400, .name = "minecart", .max_stack = 1 },
    .{ .id = 401, .name = "elytra", .max_stack = 1, .durability = 432, .rarity = .epic },
    .{ .id = 402, .name = "oak_boat", .max_stack = 1 },
    .{ .id = 403, .name = "chest_minecart", .max_stack = 1 },
    .{ .id = 404, .name = "hopper_minecart", .max_stack = 1 },
    .{ .id = 405, .name = "tnt_minecart", .max_stack = 1 },
    .{ .id = 406, .name = "furnace_minecart", .max_stack = 1 },
    .{ .id = 407, .name = "birch_boat", .max_stack = 1 },
    .{ .id = 408, .name = "spruce_boat", .max_stack = 1 },
    .{ .id = 409, .name = "jungle_boat", .max_stack = 1 },
    .{ .id = 410, .name = "acacia_boat", .max_stack = 1 },
    .{ .id = 411, .name = "dark_oak_boat", .max_stack = 1 },
};

const UTILITY_ITEMS = [_]ExtendedItemInfo{
    .{ .id = 500, .name = "totem_of_undying", .max_stack = 1, .rarity = .uncommon },
    .{ .id = 501, .name = "end_crystal", .rarity = .rare },
    .{ .id = 502, .name = "eye_of_ender", .rarity = .uncommon },
    .{ .id = 503, .name = "ender_pearl", .max_stack = 16 },
    .{ .id = 504, .name = "compass", },
    .{ .id = 505, .name = "clock", },
    .{ .id = 506, .name = "map", },
    .{ .id = 507, .name = "writable_book", .max_stack = 1 },
    .{ .id = 508, .name = "written_book", .max_stack = 16, .rarity = .uncommon },
    .{ .id = 509, .name = "enchanted_book", .max_stack = 1, .rarity = .uncommon },
    .{ .id = 510, .name = "knowledge_book", .max_stack = 1, .rarity = .uncommon },
    .{ .id = 511, .name = "firework_rocket", },
    .{ .id = 512, .name = "firework_star", },
    .{ .id = 513, .name = "recovery_compass", .rarity = .uncommon },
    .{ .id = 514, .name = "echo_shard", .rarity = .uncommon },
    .{ .id = 515, .name = "disc_fragment_5", .rarity = .rare },
    .{ .id = 516, .name = "goat_horn", .max_stack = 1 },
    .{ .id = 517, .name = "painting", },
    .{ .id = 518, .name = "item_frame", },
    .{ .id = 519, .name = "glow_item_frame", },
    .{ .id = 520, .name = "armor_stand", .max_stack = 16 },
    .{ .id = 521, .name = "bucket", .max_stack = 16 },
    .{ .id = 522, .name = "water_bucket", .max_stack = 1 },
    .{ .id = 523, .name = "lava_bucket", .max_stack = 1 },
    .{ .id = 524, .name = "powder_snow_bucket", .max_stack = 1 },
    .{ .id = 525, .name = "milk_bucket", .max_stack = 1 },
    .{ .id = 526, .name = "saddle", .max_stack = 1 },
    .{ .id = 527, .name = "nether_star", .rarity = .uncommon },
    .{ .id = 528, .name = "heart_of_the_sea", .rarity = .uncommon },
    .{ .id = 529, .name = "nautilus_shell", },
    .{ .id = 530, .name = "phantom_membrane", },
    .{ .id = 531, .name = "scute", },
};

// ---------------------------------------------------------------------------
// Comptime EXTENDED_ITEMS array
// ---------------------------------------------------------------------------

const EXPLICIT_COUNT = WEAPON_ITEMS.len + TOOL_ITEMS.len + FOOD_ITEMS.len +
    POTION_ITEMS.len + TRANSPORT_ITEMS.len + UTILITY_ITEMS.len;
const TOTAL_ITEMS = EXPLICIT_COUNT + DISC_COUNT + SPAWN_EGG_COUNT;

pub const EXTENDED_ITEMS: [TOTAL_ITEMS]ExtendedItemInfo = blk: {
    @setEvalBranchQuota(10_000);
    var items: [TOTAL_ITEMS]ExtendedItemInfo = undefined;
    var idx: usize = 0;

    for (WEAPON_ITEMS) |item| {
        items[idx] = item;
        idx += 1;
    }
    for (TOOL_ITEMS) |item| {
        items[idx] = item;
        idx += 1;
    }
    for (FOOD_ITEMS) |item| {
        items[idx] = item;
        idx += 1;
    }
    for (POTION_ITEMS) |item| {
        items[idx] = item;
        idx += 1;
    }
    for (TRANSPORT_ITEMS) |item| {
        items[idx] = item;
        idx += 1;
    }
    for (UTILITY_ITEMS) |item| {
        items[idx] = item;
        idx += 1;
    }

    // Music discs (700-715)
    for (0..DISC_COUNT) |i| {
        items[idx] = .{
            .id = DISC_START_ID + @as(u16, @intCast(i)),
            .name = DISC_NAMES[i],
            .max_stack = 1,
            .is_music_disc = true,
            .rarity = discRarity(i),
        };
        idx += 1;
    }

    // Spawn eggs (800-819)
    for (0..SPAWN_EGG_COUNT) |i| {
        items[idx] = .{
            .id = SPAWN_EGG_START_ID + @as(u16, @intCast(i)),
            .name = SPAWN_EGG_NAMES[i],
        };
        idx += 1;
    }

    break :blk items;
};

// ---------------------------------------------------------------------------
// Lookup helpers
// ---------------------------------------------------------------------------

/// Look up an extended item by its numeric ID.
pub fn getExtendedItem(id: u16) ?ExtendedItemInfo {
    for (EXTENDED_ITEMS) |item| {
        if (item.id == id) return item;
    }
    return null;
}

/// Look up an extended item by its string name (case-sensitive).
pub fn getItemByName(name: []const u8) ?ExtendedItemInfo {
    for (EXTENDED_ITEMS) |item| {
        if (std.mem.eql(u8, item.name, name)) return item;
    }
    return null;
}

/// Returns true when the given ID corresponds to a music disc.
pub fn isMusicDisc(id: u16) bool {
    if (getExtendedItem(id)) |item| {
        return item.is_music_disc;
    }
    return false;
}

/// Returns true when the given ID corresponds to a spawn egg.
pub fn isSpawnEgg(id: u16) bool {
    return id >= SPAWN_EGG_START_ID and id < SPAWN_EGG_START_ID + SPAWN_EGG_COUNT;
}

/// Returns the comparator signal strength (1-15) that a jukebox emits for the
/// given music disc.  Non-disc IDs return null.  Only the first 15 discs
/// (indices 0-14) produce a valid signal; disc_relic (index 15) has no
/// defined comparator output and returns null.
pub fn getDiscSignal(id: u16) ?u4 {
    if (id < DISC_START_ID or id >= DISC_START_ID + DISC_COUNT) return null;
    const idx = id - DISC_START_ID;
    if (idx >= 15) return null;
    const signal: u4 = @intCast(idx + 1);
    return signal;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "bow properties" {
    const bow = getExtendedItem(200).?;
    try std.testing.expectEqualStrings("bow", bow.name);
    try std.testing.expectEqual(@as(u16, 385), bow.durability);
    try std.testing.expectEqual(@as(u8, 1), bow.max_stack);
    try std.testing.expect(bow.is_weapon);
    try std.testing.expect(!bow.is_tool);
}

test "crossbow durability" {
    const crossbow = getExtendedItem(201).?;
    try std.testing.expectEqualStrings("crossbow", crossbow.name);
    try std.testing.expectEqual(@as(u16, 465), crossbow.durability);
    try std.testing.expect(crossbow.is_weapon);
}

test "elytra durability and rarity" {
    const elytra = getExtendedItem(401).?;
    try std.testing.expectEqualStrings("elytra", elytra.name);
    try std.testing.expectEqual(@as(u16, 432), elytra.durability);
    try std.testing.expectEqual(Rarity.epic, elytra.rarity);
    try std.testing.expectEqual(@as(u8, 1), elytra.max_stack);
}

test "trident durability and rarity" {
    const trident = getExtendedItem(202).?;
    try std.testing.expectEqualStrings("trident", trident.name);
    try std.testing.expectEqual(@as(u16, 250), trident.durability);
    try std.testing.expectEqual(Rarity.rare, trident.rarity);
    try std.testing.expect(trident.is_weapon);
}

test "disc signals 1 through 15" {
    try std.testing.expectEqual(@as(?u4, 1), getDiscSignal(700)); // 13
    try std.testing.expectEqual(@as(?u4, 5), getDiscSignal(704)); // far
    try std.testing.expectEqual(@as(?u4, 13), getDiscSignal(712)); // pigstep
    try std.testing.expectEqual(@as(?u4, 15), getDiscSignal(714)); // 5
    try std.testing.expectEqual(@as(?u4, null), getDiscSignal(715)); // relic has no signal
    try std.testing.expectEqual(@as(?u4, null), getDiscSignal(200)); // non-disc
}

test "spawn egg check" {
    try std.testing.expect(isSpawnEgg(800)); // zombie
    try std.testing.expect(isSpawnEgg(819)); // bee
    try std.testing.expect(!isSpawnEgg(799));
    try std.testing.expect(!isSpawnEgg(820));
    try std.testing.expect(!isSpawnEgg(200)); // bow is not a spawn egg
}

test "stack sizes" {
    // cake stacks to 1
    const cake = getExtendedItem(232).?;
    try std.testing.expectEqual(@as(u8, 1), cake.max_stack);
    // honey bottle stacks to 16
    const honey = getExtendedItem(235).?;
    try std.testing.expectEqual(@as(u8, 16), honey.max_stack);
    // dragon breath stacks to 64
    const db = getExtendedItem(373).?;
    try std.testing.expectEqual(@as(u8, 64), db.max_stack);
    // ender pearl stacks to 16
    const ep = getExtendedItem(503).?;
    try std.testing.expectEqual(@as(u8, 16), ep.max_stack);
    // minecart stacks to 1
    const mc = getExtendedItem(400).?;
    try std.testing.expectEqual(@as(u8, 1), mc.max_stack);
}

test "rarity values" {
    // golden carrot is uncommon
    const gc = getExtendedItem(230).?;
    try std.testing.expectEqual(Rarity.uncommon, gc.rarity);
    // enchanted golden apple is epic
    const ega = getExtendedItem(239).?;
    try std.testing.expectEqual(Rarity.epic, ega.rarity);
    // totem of undying is uncommon
    const totem = getExtendedItem(500).?;
    try std.testing.expectEqual(Rarity.uncommon, totem.rarity);
    // regular cookie is common
    const cookie = getExtendedItem(233).?;
    try std.testing.expectEqual(Rarity.common, cookie.rarity);
}

test "name lookup" {
    const item = getItemByName("golden_carrot").?;
    try std.testing.expectEqual(@as(u16, 230), item.id);
    try std.testing.expect(item.is_food);

    const trident = getItemByName("trident").?;
    try std.testing.expectEqual(@as(u16, 202), trident.id);

    // Non-existent name
    try std.testing.expectEqual(@as(?ExtendedItemInfo, null), getItemByName("unobtanium"));
}

test "shield durability" {
    const shield = getExtendedItem(203).?;
    try std.testing.expectEqualStrings("shield", shield.name);
    try std.testing.expectEqual(@as(u16, 336), shield.durability);
    try std.testing.expect(shield.is_tool);
    try std.testing.expect(!shield.is_weapon);
}

test "music disc is_music_disc flag" {
    try std.testing.expect(isMusicDisc(700)); // 13
    try std.testing.expect(isMusicDisc(712)); // pigstep
    try std.testing.expect(isMusicDisc(715)); // relic
    try std.testing.expect(!isMusicDisc(200)); // bow
    try std.testing.expect(!isMusicDisc(9999)); // unknown
}

test "extended items total count at least 120" {
    try std.testing.expect(EXTENDED_ITEMS.len >= 120);
}

test "food items have is_food set" {
    const dried = getItemByName("dried_kelp").?;
    try std.testing.expect(dried.is_food);
    const bread = getItemByName("bread").?;
    try std.testing.expect(bread.is_food);
}

test "spawn egg names" {
    const zombie = getExtendedItem(800).?;
    try std.testing.expectEqualStrings("spawn_egg_zombie", zombie.name);
    const bee = getExtendedItem(819).?;
    try std.testing.expectEqualStrings("spawn_egg_bee", bee.name);
}
