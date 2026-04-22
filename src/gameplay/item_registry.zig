/// Comprehensive item registry for the crafting system.
/// Maps item IDs to metadata: name, stack size, durability, tool/armor stats, and
/// miscellaneous properties.  All values follow vanilla Minecraft conventions.
/// Block items (0-110) mirror src/world/block.zig IDs.

const std = @import("std");

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

pub const ItemId = u16;

pub const ToolType = enum { none, pickaxe, axe, shovel, hoe, sword };
pub const ToolTier = enum { none, wood, stone, iron, gold, diamond, netherite };
pub const ArmorSlot = enum { none, helmet, chestplate, leggings, boots };

pub const ItemInfo = struct {
    id: u16,
    name: []const u8,
    stack_max: u8 = 64,
    durability: u16 = 0,
    tool_type: ToolType = .none,
    tool_tier: ToolTier = .none,
    armor_slot: ArmorSlot = .none,
    armor_defense: u8 = 0,
    is_placeable: bool = false,
    is_fuel: bool = false,
    fuel_ticks: u16 = 0,
    attack_damage: f32 = 1.0,
    mining_speed: f32 = 1.0,
};

// ---------------------------------------------------------------------------
// Block name table (0-110, mirrors src/world/block.zig)
// ---------------------------------------------------------------------------

const BLOCK_NAMES = [_][]const u8{
    "air", // 0
    "stone", // 1
    "dirt", // 2
    "grass", // 3
    "cobblestone", // 4
    "oak_planks", // 5
    "sand", // 6
    "gravel", // 7
    "oak_log", // 8
    "oak_leaves", // 9
    "water", // 10
    "bedrock", // 11
    "coal_ore", // 12
    "iron_ore", // 13
    "gold_ore", // 14
    "diamond_ore", // 15
    "redstone_ore", // 16
    "glass", // 17
    "brick", // 18
    "obsidian", // 19
    "tnt", // 20
    "bookshelf", // 21
    "mossy_cobblestone", // 22
    "ice", // 23
    "snow", // 24
    "clay", // 25
    "cactus", // 26
    "pumpkin", // 27
    "melon", // 28
    "glowstone", // 29
    "netherrack", // 30
    "soul_sand", // 31
    "lava", // 32
    "redstone_wire", // 33
    "redstone_torch", // 34
    "lever", // 35
    "button", // 36
    "piston", // 37
    "repeater", // 38
    "furnace", // 39
    "door", // 40
    "bed", // 41
    "ladder", // 42
    "chest", // 43
    "trapdoor", // 44
    "end_stone", // 45
    "anvil", // 46
    "beacon", // 47
    "brewing_stand", // 48
    "jukebox", // 49
    "note_block", // 50
    "piston_base", // 51
    "sticky_piston_base", // 52
    "piston_head", // 53
    "hopper", // 54
    "dropper", // 55
    "dispenser", // 56
    "enchanting_table", // 57
    "end_portal_frame", // 58
    "end_portal", // 59
    "rail", // 60
    "powered_rail", // 61
    "detector_rail", // 62
    "activator_rail", // 63
    "farmland", // 64
    "wheat_crop", // 65
    "carrots_crop", // 66
    "potatoes_crop", // 67
    "melon_block", // 68
    "jack_o_lantern", // 69
    "hay_bale", // 70
    "white_wool", // 71
    "orange_wool", // 72
    "magenta_wool", // 73
    "light_blue_wool", // 74
    "yellow_wool", // 75
    "lime_wool", // 76
    "pink_wool", // 77
    "gray_wool", // 78
    "light_gray_wool", // 79
    "cyan_wool", // 80
    "purple_wool", // 81
    "blue_wool", // 82
    "brown_wool", // 83
    "green_wool", // 84
    "red_wool", // 85
    "black_wool", // 86
    "white_terracotta", // 87
    "orange_terracotta", // 88
    "red_terracotta", // 89
    "black_terracotta", // 90
    "white_concrete", // 91
    "orange_concrete", // 92
    "red_concrete", // 93
    "black_concrete", // 94
    "copper_block", // 95
    "exposed_copper", // 96
    "weathered_copper", // 97
    "oxidized_copper", // 98
    "smoker", // 99
    "blast_furnace", // 100
    "barrel", // 101
    "grindstone", // 102
    "stonecutter", // 103
    "smithing_table", // 104
    "loom_block", // 105
    "cartography_table", // 106
    "composter", // 107
    "lectern", // 108
    "ender_chest", // 109
    "crafting_table", // 110
};

const BLOCK_COUNT = BLOCK_NAMES.len; // 111

// ---------------------------------------------------------------------------
// Fuel blocks (wood-based blocks that burn in a furnace)
// ---------------------------------------------------------------------------

fn isWoodBlock(id: u16) bool {
    return id == 5 or // oak_planks
        id == 8 or // oak_log
        id == 21 or // bookshelf
        id == 43 or // chest
        id == 101 or // barrel
        id == 108 or // lectern
        id == 110; // crafting_table
}

const WOOD_FUEL_TICKS: u16 = 300; // 15 seconds

// ---------------------------------------------------------------------------
// Tool definitions: 5 tiers x 5 types = 25 items (IDs 257-281)
// ---------------------------------------------------------------------------

const TOOL_TIERS = [_]ToolTier{ .wood, .stone, .iron, .gold, .diamond };
const TOOL_TYPES = [_]ToolType{ .pickaxe, .axe, .shovel, .hoe, .sword };

const TIER_NAMES = [_][]const u8{ "wooden", "stone", "iron", "golden", "diamond" };
const TYPE_NAMES = [_][]const u8{ "pickaxe", "axe", "shovel", "hoe", "sword" };

const TIER_DURABILITIES = [_]u16{ 59, 131, 250, 32, 1561 };

/// Base attack damage per tool type: pickaxe, axe, shovel, hoe, sword.
const TYPE_BASE_ATTACK = [_]f32{ 3.0, 5.0, 2.5, 1.0, 6.0 };

/// Attack damage bonus per tier: wood, stone, iron, gold, diamond.
const TIER_ATTACK_BONUS = [_]f32{ 0.0, 1.0, 2.0, 0.0, 3.0 };

/// Mining speed multiplier per tier.
const TIER_MINING_SPEED = [_]f32{ 2.0, 4.0, 6.0, 12.0, 8.0 };

const TOOL_START_ID: u16 = 257;

fn toolName(tier_idx: usize, type_idx: usize) []const u8 {
    const names = comptime blk: {
        var result: [25][]const u8 = undefined;
        for (0..5) |ti| {
            for (0..5) |ty| {
                result[ti * 5 + ty] = TIER_NAMES[ti] ++ "_" ++ TYPE_NAMES[ty];
            }
        }
        break :blk result;
    };
    return names[tier_idx * 5 + type_idx];
}

fn toolInfo(comptime tier_idx: usize, comptime type_idx: usize) ItemInfo {
    const id = TOOL_START_ID + @as(u16, tier_idx * 5 + type_idx);
    return .{
        .id = id,
        .name = toolName(tier_idx, type_idx),
        .stack_max = 1,
        .durability = TIER_DURABILITIES[tier_idx],
        .tool_type = TOOL_TYPES[type_idx],
        .tool_tier = TOOL_TIERS[tier_idx],
        .attack_damage = TYPE_BASE_ATTACK[type_idx] + TIER_ATTACK_BONUS[tier_idx],
        .mining_speed = TIER_MINING_SPEED[tier_idx],
        .is_fuel = (tier_idx == 0), // wooden tools burn
        .fuel_ticks = if (tier_idx == 0) 200 else 0,
    };
}

// ---------------------------------------------------------------------------
// Armor definitions: 5 tiers x 4 slots = 20 items (IDs 282-301)
// ---------------------------------------------------------------------------

const ARMOR_TIERS = [_]ToolTier{ .wood, .stone, .iron, .gold, .diamond };
const ARMOR_SLOTS = [_]ArmorSlot{ .helmet, .chestplate, .leggings, .boots };

const ARMOR_TIER_NAMES = [_][]const u8{ "leather", "chainmail", "iron", "golden", "diamond" };
const ARMOR_SLOT_NAMES = [_][]const u8{ "helmet", "chestplate", "leggings", "boots" };

/// Durability base per slot: helmet, chestplate, leggings, boots.
const SLOT_DUR_BASE = [_]u16{ 11, 16, 15, 13 };

/// Durability multiplier per tier: leather, chainmail, iron, gold, diamond.
const TIER_DUR_MULT = [_]u16{ 5, 5, 15, 7, 33 };

/// Defense points [tier][slot]: helmet, chestplate, leggings, boots.
const ARMOR_DEFENSE = [5][4]u8{
    .{ 1, 3, 2, 1 }, // leather
    .{ 2, 5, 4, 1 }, // chainmail
    .{ 2, 6, 5, 2 }, // iron
    .{ 2, 5, 3, 1 }, // gold
    .{ 3, 8, 6, 3 }, // diamond
};

const ARMOR_START_ID: u16 = 282;

fn armorName(tier_idx: usize, slot_idx: usize) []const u8 {
    const names = comptime blk: {
        var result: [20][]const u8 = undefined;
        for (0..5) |ti| {
            for (0..4) |si| {
                result[ti * 4 + si] = ARMOR_TIER_NAMES[ti] ++ "_" ++ ARMOR_SLOT_NAMES[si];
            }
        }
        break :blk result;
    };
    return names[tier_idx * 4 + slot_idx];
}

fn armorInfo(comptime tier_idx: usize, comptime slot_idx: usize) ItemInfo {
    const id = ARMOR_START_ID + @as(u16, tier_idx * 4 + slot_idx);
    return .{
        .id = id,
        .name = armorName(tier_idx, slot_idx),
        .stack_max = 1,
        .durability = SLOT_DUR_BASE[slot_idx] * TIER_DUR_MULT[tier_idx],
        .armor_slot = ARMOR_SLOTS[slot_idx],
        .armor_defense = ARMOR_DEFENSE[tier_idx][slot_idx],
        .tool_tier = ARMOR_TIERS[tier_idx],
    };
}

// ---------------------------------------------------------------------------
// Miscellaneous items (IDs 302-327)
// ---------------------------------------------------------------------------

const MISC_ITEMS = [_]ItemInfo{
    .{ .id = 302, .name = "bowl", .stack_max = 64 },
    .{ .id = 303, .name = "bucket", .stack_max = 16 },
    .{ .id = 304, .name = "compass", .stack_max = 64 },
    .{ .id = 305, .name = "clock", .stack_max = 64 },
    .{ .id = 306, .name = "map", .stack_max = 64 },
    .{ .id = 307, .name = "shears", .stack_max = 1, .durability = 238, .attack_damage = 1.0, .mining_speed = 1.5 },
    .{ .id = 308, .name = "flint_and_steel", .stack_max = 1, .durability = 64 },
    .{ .id = 309, .name = "fishing_rod", .stack_max = 1, .durability = 384 },
    .{ .id = 310, .name = "lead", .stack_max = 64 },
    .{ .id = 311, .name = "name_tag", .stack_max = 64 },
    .{ .id = 312, .name = "saddle", .stack_max = 1 },
    .{ .id = 313, .name = "bone", .stack_max = 64 },
    .{ .id = 314, .name = "arrow", .stack_max = 64 },
    .{ .id = 315, .name = "string", .stack_max = 64 },
    .{ .id = 316, .name = "feather", .stack_max = 64 },
    .{ .id = 317, .name = "gunpowder", .stack_max = 64 },
    .{ .id = 318, .name = "blaze_rod", .stack_max = 64, .is_fuel = true, .fuel_ticks = 2400 },
    .{ .id = 319, .name = "ender_pearl", .stack_max = 16 },
    .{ .id = 320, .name = "blaze_powder", .stack_max = 64 },
    .{ .id = 321, .name = "coal", .stack_max = 64, .is_fuel = true, .fuel_ticks = 1600 },
    .{ .id = 322, .name = "iron_ingot", .stack_max = 64 },
    .{ .id = 323, .name = "gold_ingot", .stack_max = 64 },
    .{ .id = 324, .name = "diamond_gem", .stack_max = 64 },
    .{ .id = 325, .name = "emerald", .stack_max = 64 },
    .{ .id = 326, .name = "nether_star", .stack_max = 64 },
    .{ .id = 327, .name = "netherite_ingot", .stack_max = 64 },
};

// ---------------------------------------------------------------------------
// Comptime ITEMS array  (block items + stick + tools + armor + misc)
// ---------------------------------------------------------------------------

const STICK_ID: u16 = 256;

const TOTAL_ITEMS = BLOCK_COUNT + 1 + 25 + 20 + MISC_ITEMS.len; // 111 + 1 + 25 + 20 + 26 = 183

pub const ITEMS: [TOTAL_ITEMS]ItemInfo = blk: {
    @setEvalBranchQuota(10000);
    var items: [TOTAL_ITEMS]ItemInfo = undefined;
    var idx: usize = 0;

    // Block items (0-110)
    for (0..BLOCK_COUNT) |i| {
        const bid: u16 = @intCast(i);
        const is_wood = isWoodBlock(bid);
        items[idx] = .{
            .id = bid,
            .name = BLOCK_NAMES[i],
            .stack_max = 64,
            .is_placeable = true,
            .is_fuel = is_wood,
            .fuel_ticks = if (is_wood) WOOD_FUEL_TICKS else 0,
        };
        idx += 1;
    }

    // Stick (256)
    items[idx] = .{
        .id = STICK_ID,
        .name = "stick",
        .stack_max = 64,
        .is_fuel = true,
        .fuel_ticks = 100,
    };
    idx += 1;

    // Tools (257-281): 5 tiers x 5 types
    for (0..5) |ti| {
        for (0..5) |ty| {
            items[idx] = toolInfo(ti, ty);
            idx += 1;
        }
    }

    // Armor (282-301): 5 tiers x 4 slots
    for (0..5) |ti| {
        for (0..4) |si| {
            items[idx] = armorInfo(ti, si);
            idx += 1;
        }
    }

    // Misc items (302-327)
    for (MISC_ITEMS) |item| {
        items[idx] = item;
        idx += 1;
    }

    break :blk items;
};

// ---------------------------------------------------------------------------
// Lookup helpers (binary search on sorted IDs -- items are inserted in order)
// ---------------------------------------------------------------------------

const DEFAULT_INFO = ItemInfo{ .id = 0, .name = "unknown" };

/// Returns ItemInfo for any item ID.  Unknown IDs yield a default entry.
pub fn getInfo(id: u16) ItemInfo {
    // Fast path: block items are contiguous starting at 0.
    if (id < BLOCK_COUNT) return ITEMS[id];

    // Binary search the remaining entries.
    var lo: usize = BLOCK_COUNT;
    var hi: usize = ITEMS.len;
    while (lo < hi) {
        const mid = lo + (hi - lo) / 2;
        if (ITEMS[mid].id == id) return ITEMS[mid];
        if (ITEMS[mid].id < id) {
            lo = mid + 1;
        } else {
            hi = mid;
        }
    }
    return DEFAULT_INFO;
}

/// Maximum stack size for the given item ID.
pub fn getStackMax(id: u16) u8 {
    return getInfo(id).stack_max;
}

/// True when the item is a tool (pickaxe, axe, shovel, hoe, or sword).
pub fn isTool(id: u16) bool {
    return getInfo(id).tool_type != .none;
}

/// True when the item occupies an armor slot.
pub fn isArmor(id: u16) bool {
    return getInfo(id).armor_slot != .none;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "block items are placeable" {
    const stone = getInfo(1);
    try std.testing.expectEqualStrings("stone", stone.name);
    try std.testing.expect(stone.is_placeable);
    try std.testing.expectEqual(@as(u8, 64), stone.stack_max);
}

test "air block exists at id 0" {
    const air = getInfo(0);
    try std.testing.expectEqualStrings("air", air.name);
    try std.testing.expect(air.is_placeable);
}

test "crafting_table block at id 110" {
    const ct = getInfo(110);
    try std.testing.expectEqualStrings("crafting_table", ct.name);
    try std.testing.expect(ct.is_placeable);
    try std.testing.expect(ct.is_fuel);
}

test "stick properties" {
    const stick = getInfo(256);
    try std.testing.expectEqualStrings("stick", stick.name);
    try std.testing.expectEqual(@as(u8, 64), stick.stack_max);
    try std.testing.expect(stick.is_fuel);
    try std.testing.expectEqual(@as(u16, 100), stick.fuel_ticks);
    try std.testing.expect(!stick.is_placeable);
}

test "wooden pickaxe tool stats" {
    const wpick = getInfo(257);
    try std.testing.expectEqualStrings("wooden_pickaxe", wpick.name);
    try std.testing.expectEqual(@as(u8, 1), wpick.stack_max);
    try std.testing.expectEqual(@as(u16, 59), wpick.durability);
    try std.testing.expectEqual(ToolType.pickaxe, wpick.tool_type);
    try std.testing.expectEqual(ToolTier.wood, wpick.tool_tier);
    try std.testing.expect(isTool(257));
}

test "diamond sword has highest attack" {
    const dsword = getInfo(281); // diamond tier (idx 4) * 5 + sword (idx 4) = 24 + 257 = 281
    try std.testing.expectEqualStrings("diamond_sword", dsword.name);
    try std.testing.expectEqual(@as(u16, 1561), dsword.durability);
    try std.testing.expectEqual(ToolType.sword, dsword.tool_type);
    try std.testing.expectEqual(ToolTier.diamond, dsword.tool_tier);
    // sword base 6.0 + diamond bonus 3.0 = 9.0
    try std.testing.expectApproxEqAbs(@as(f32, 9.0), dsword.attack_damage, 0.01);
}

test "iron chestplate armor stats" {
    // iron (tier idx 2) * 4 + chestplate (slot idx 1) = 9 + 282 = 291
    const ichest = getInfo(291);
    try std.testing.expectEqualStrings("iron_chestplate", ichest.name);
    try std.testing.expectEqual(@as(u8, 1), ichest.stack_max);
    try std.testing.expectEqual(ArmorSlot.chestplate, ichest.armor_slot);
    try std.testing.expectEqual(@as(u8, 6), ichest.armor_defense);
    try std.testing.expect(isArmor(291));
    try std.testing.expect(!isTool(291));
}

test "diamond boots armor" {
    // diamond (tier idx 4) * 4 + boots (slot idx 3) = 19 + 282 = 301
    const dboots = getInfo(301);
    try std.testing.expectEqualStrings("diamond_boots", dboots.name);
    try std.testing.expectEqual(@as(u8, 3), dboots.armor_defense);
    try std.testing.expectEqual(ArmorSlot.boots, dboots.armor_slot);
}

test "misc items: coal is fuel" {
    const coal = getInfo(321);
    try std.testing.expectEqualStrings("coal", coal.name);
    try std.testing.expect(coal.is_fuel);
    try std.testing.expectEqual(@as(u16, 1600), coal.fuel_ticks);
    try std.testing.expectEqual(@as(u8, 64), coal.stack_max);
}

test "misc items: ender pearl stack 16" {
    const ep = getInfo(319);
    try std.testing.expectEqualStrings("ender_pearl", ep.name);
    try std.testing.expectEqual(@as(u8, 16), ep.stack_max);
}

test "unknown item returns default" {
    const unknown = getInfo(9999);
    try std.testing.expectEqualStrings("unknown", unknown.name);
    try std.testing.expectEqual(@as(u8, 64), unknown.stack_max);
    try std.testing.expect(!unknown.is_placeable);
}

test "gold tools have low durability" {
    // gold (tier idx 3) * 5 + pickaxe (type idx 0) = 15 + 257 = 272
    const gpick = getInfo(272);
    try std.testing.expectEqualStrings("golden_pickaxe", gpick.name);
    try std.testing.expectEqual(@as(u16, 32), gpick.durability);
    try std.testing.expectEqual(ToolTier.gold, gpick.tool_tier);
    // gold has highest mining speed
    try std.testing.expectApproxEqAbs(@as(f32, 12.0), gpick.mining_speed, 0.01);
}

test "getStackMax helper" {
    try std.testing.expectEqual(@as(u8, 64), getStackMax(1)); // stone
    try std.testing.expectEqual(@as(u8, 1), getStackMax(257)); // wooden pickaxe
    try std.testing.expectEqual(@as(u8, 16), getStackMax(319)); // ender pearl
}

test "leather helmet is first armor" {
    const lhelm = getInfo(282);
    try std.testing.expectEqualStrings("leather_helmet", lhelm.name);
    try std.testing.expectEqual(ArmorSlot.helmet, lhelm.armor_slot);
    try std.testing.expectEqual(@as(u8, 1), lhelm.armor_defense);
    try std.testing.expectEqual(@as(u16, 55), lhelm.durability); // 11 * 5
}

test "ITEMS array length" {
    try std.testing.expectEqual(@as(usize, 183), ITEMS.len);
}
