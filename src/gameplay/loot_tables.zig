/// Block, mob, and chest loot drop system.
/// Provides deterministic loot tables for block breaking, mob kills, and chest
/// generation. Fortune enchantment increases max drop counts for applicable ores.
/// All randomness is seed-based for reproducibility.

const std = @import("std");

// ── Block ID constants (mirrors src/world/block.zig) ───────────────────────
const STONE: u8 = 1;
const GRASS: u8 = 3;
const COBBLESTONE: u8 = 4;
const GRAVEL: u8 = 7;
const OAK_LEAVES: u8 = 9;
const COAL_ORE: u8 = 12;
const IRON_ORE: u8 = 13;
const DIAMOND_ORE: u8 = 15;
const GLASS: u8 = 17;

// ── Item ID constants ──────────────────────────────────────────────────────
const ITEM_COBBLESTONE: u16 = COBBLESTONE;
const ITEM_GRAVEL: u16 = GRAVEL;
const ITEM_COAL: u16 = 100;
const ITEM_RAW_IRON: u16 = 101;
const ITEM_DIAMOND: u16 = 102;
const ITEM_WHEAT_SEEDS: u16 = 103;
const ITEM_FLINT: u16 = 104;
const ITEM_SAPLING: u16 = 105;

const ITEM_ROTTEN_FLESH: u16 = 200;
const ITEM_BONE: u16 = 201;
const ITEM_ARROW: u16 = 202;
const ITEM_GUNPOWDER: u16 = 203;
const ITEM_RAW_PORK: u16 = 204;
const ITEM_RAW_BEEF: u16 = 205;
const ITEM_RAW_CHICKEN: u16 = 206;
const ITEM_FEATHER: u16 = 207;
const ITEM_WOOL: u16 = 208;
const ITEM_LEATHER: u16 = 210;
const ITEM_IRON_INGOT: u16 = 211;

// ── Chest type constants ───────────────────────────────────────────────────
pub const CHEST_DUNGEON: u8 = 0;
pub const CHEST_MINESHAFT: u8 = 1;
pub const CHEST_VILLAGE: u8 = 2;

// ── Public types ───────────────────────────────────────────────────────────

pub const LootEntry = struct {
    item_id: u16,
    min_count: u8,
    max_count: u8,
    weight: u16,
    fortune_bonus: u8,
};

pub const LootTable = struct {
    entries: []const LootEntry,
    xp_min: u8,
    xp_max: u8,
};

pub const ItemDrop = struct { id: u16, count: u8 };

pub const RollResult = struct {
    items: [8]?ItemDrop,
    item_count: u8,
    xp: u8,
};

// ── Block loot tables ──────────────────────────────────────────────────────

const stone_loot = [_]LootEntry{
    .{ .item_id = ITEM_COBBLESTONE, .min_count = 1, .max_count = 1, .weight = 1, .fortune_bonus = 0 },
};

const coal_ore_loot = [_]LootEntry{
    .{ .item_id = ITEM_COAL, .min_count = 1, .max_count = 1, .weight = 1, .fortune_bonus = 1 },
};

const iron_ore_loot = [_]LootEntry{
    .{ .item_id = ITEM_RAW_IRON, .min_count = 1, .max_count = 1, .weight = 1, .fortune_bonus = 0 },
};

const diamond_ore_loot = [_]LootEntry{
    .{ .item_id = ITEM_DIAMOND, .min_count = 1, .max_count = 1, .weight = 1, .fortune_bonus = 1 },
};

const grass_loot = [_]LootEntry{
    .{ .item_id = 0, .min_count = 0, .max_count = 0, .weight = 7, .fortune_bonus = 0 }, // nothing (87.5%)
    .{ .item_id = ITEM_WHEAT_SEEDS, .min_count = 1, .max_count = 1, .weight = 1, .fortune_bonus = 0 }, // seeds (12.5%)
};

const gravel_loot = [_]LootEntry{
    .{ .item_id = ITEM_GRAVEL, .min_count = 1, .max_count = 1, .weight = 9, .fortune_bonus = 0 }, // gravel (90%)
    .{ .item_id = ITEM_FLINT, .min_count = 1, .max_count = 1, .weight = 1, .fortune_bonus = 0 }, // flint (10%)
};

const leaves_loot = [_]LootEntry{
    .{ .item_id = 0, .min_count = 0, .max_count = 0, .weight = 19, .fortune_bonus = 0 }, // nothing (95%)
    .{ .item_id = ITEM_SAPLING, .min_count = 1, .max_count = 1, .weight = 1, .fortune_bonus = 0 }, // sapling (5%)
};

// Glass drops nothing (silk touch only, not implemented here).
const glass_loot = [_]LootEntry{
    .{ .item_id = 0, .min_count = 0, .max_count = 0, .weight = 1, .fortune_bonus = 0 },
};

const empty_table = LootTable{ .entries = &.{}, .xp_min = 0, .xp_max = 0 };

pub fn getBlockLoot(block_id: u8) LootTable {
    return switch (block_id) {
        STONE => .{ .entries = &stone_loot, .xp_min = 0, .xp_max = 0 },
        COAL_ORE => .{ .entries = &coal_ore_loot, .xp_min = 0, .xp_max = 2 },
        IRON_ORE => .{ .entries = &iron_ore_loot, .xp_min = 0, .xp_max = 0 },
        DIAMOND_ORE => .{ .entries = &diamond_ore_loot, .xp_min = 3, .xp_max = 7 },
        GRASS => .{ .entries = &grass_loot, .xp_min = 0, .xp_max = 0 },
        GRAVEL => .{ .entries = &gravel_loot, .xp_min = 0, .xp_max = 0 },
        OAK_LEAVES => .{ .entries = &leaves_loot, .xp_min = 0, .xp_max = 0 },
        GLASS => .{ .entries = &glass_loot, .xp_min = 0, .xp_max = 0 },
        else => empty_table,
    };
}

// ── Mob loot tables ────────────────────────────────────────────────────────

const ZOMBIE: u8 = 1;
const SKELETON: u8 = 2;
const CREEPER: u8 = 3;
const PIG: u8 = 4;
const COW: u8 = 5;
const CHICKEN: u8 = 6;
const SHEEP: u8 = 7;

const zombie_loot = [_]LootEntry{
    .{ .item_id = ITEM_ROTTEN_FLESH, .min_count = 1, .max_count = 2, .weight = 39, .fortune_bonus = 0 },
    .{ .item_id = ITEM_IRON_INGOT, .min_count = 1, .max_count = 1, .weight = 1, .fortune_bonus = 0 }, // 2.5%
};

const skeleton_loot = [_]LootEntry{
    .{ .item_id = ITEM_BONE, .min_count = 0, .max_count = 2, .weight = 1, .fortune_bonus = 0 },
    .{ .item_id = ITEM_ARROW, .min_count = 0, .max_count = 2, .weight = 1, .fortune_bonus = 0 },
};

const creeper_loot = [_]LootEntry{
    .{ .item_id = ITEM_GUNPOWDER, .min_count = 0, .max_count = 2, .weight = 1, .fortune_bonus = 0 },
};

const pig_loot = [_]LootEntry{
    .{ .item_id = ITEM_RAW_PORK, .min_count = 1, .max_count = 3, .weight = 1, .fortune_bonus = 0 },
};

const cow_loot = [_]LootEntry{
    .{ .item_id = ITEM_RAW_BEEF, .min_count = 1, .max_count = 3, .weight = 1, .fortune_bonus = 0 },
    .{ .item_id = ITEM_LEATHER, .min_count = 0, .max_count = 2, .weight = 1, .fortune_bonus = 0 },
};

const chicken_loot = [_]LootEntry{
    .{ .item_id = ITEM_RAW_CHICKEN, .min_count = 1, .max_count = 1, .weight = 1, .fortune_bonus = 0 },
    .{ .item_id = ITEM_FEATHER, .min_count = 0, .max_count = 2, .weight = 1, .fortune_bonus = 0 },
};

const sheep_loot = [_]LootEntry{
    .{ .item_id = ITEM_WOOL, .min_count = 1, .max_count = 1, .weight = 1, .fortune_bonus = 0 },
};

pub fn getMobLoot(entity_type: u8) LootTable {
    return switch (entity_type) {
        ZOMBIE => .{ .entries = &zombie_loot, .xp_min = 5, .xp_max = 5 },
        SKELETON => .{ .entries = &skeleton_loot, .xp_min = 5, .xp_max = 5 },
        CREEPER => .{ .entries = &creeper_loot, .xp_min = 5, .xp_max = 5 },
        PIG => .{ .entries = &pig_loot, .xp_min = 1, .xp_max = 3 },
        COW => .{ .entries = &cow_loot, .xp_min = 1, .xp_max = 3 },
        CHICKEN => .{ .entries = &chicken_loot, .xp_min = 1, .xp_max = 3 },
        SHEEP => .{ .entries = &sheep_loot, .xp_min = 1, .xp_max = 3 },
        else => empty_table,
    };
}

// ── Chest loot tables ──────────────────────────────────────────────────────

const dungeon_chest_loot = [_]LootEntry{
    .{ .item_id = ITEM_BONE, .min_count = 1, .max_count = 4, .weight = 4, .fortune_bonus = 0 },
    .{ .item_id = ITEM_GUNPOWDER, .min_count = 1, .max_count = 4, .weight = 3, .fortune_bonus = 0 },
    .{ .item_id = ITEM_IRON_INGOT, .min_count = 1, .max_count = 3, .weight = 2, .fortune_bonus = 0 },
    .{ .item_id = ITEM_DIAMOND, .min_count = 1, .max_count = 2, .weight = 1, .fortune_bonus = 0 },
};

const mineshaft_chest_loot = [_]LootEntry{
    .{ .item_id = ITEM_IRON_INGOT, .min_count = 1, .max_count = 3, .weight = 4, .fortune_bonus = 0 },
    .{ .item_id = ITEM_COAL, .min_count = 2, .max_count = 6, .weight = 5, .fortune_bonus = 0 },
    .{ .item_id = ITEM_DIAMOND, .min_count = 1, .max_count = 1, .weight = 1, .fortune_bonus = 0 },
};

const village_chest_loot = [_]LootEntry{
    .{ .item_id = ITEM_RAW_BEEF, .min_count = 1, .max_count = 3, .weight = 3, .fortune_bonus = 0 },
    .{ .item_id = ITEM_WHEAT_SEEDS, .min_count = 2, .max_count = 4, .weight = 4, .fortune_bonus = 0 },
    .{ .item_id = ITEM_IRON_INGOT, .min_count = 1, .max_count = 2, .weight = 2, .fortune_bonus = 0 },
    .{ .item_id = ITEM_COAL, .min_count = 1, .max_count = 3, .weight = 3, .fortune_bonus = 0 },
};

pub fn getChestLoot(chest_type: u8) LootTable {
    return switch (chest_type) {
        CHEST_DUNGEON => .{ .entries = &dungeon_chest_loot, .xp_min = 0, .xp_max = 0 },
        CHEST_MINESHAFT => .{ .entries = &mineshaft_chest_loot, .xp_min = 0, .xp_max = 0 },
        CHEST_VILLAGE => .{ .entries = &village_chest_loot, .xp_min = 0, .xp_max = 0 },
        else => empty_table,
    };
}

// ── Core roll logic ────────────────────────────────────────────────────────

/// Roll loot from a table using a deterministic seed.
/// Fortune increases max_count for entries with fortune_bonus > 0.
pub fn rollLoot(table: LootTable, fortune_level: u8, seed: u64) RollResult {
    var result = RollResult{
        .items = [_]?ItemDrop{null} ** 8,
        .item_count = 0,
        .xp = 0,
    };

    if (table.entries.len == 0) return result;

    var rng = std.Random.DefaultPrng.init(seed);
    const random = rng.random();

    // Roll XP.
    if (table.xp_max > table.xp_min) {
        result.xp = table.xp_min + random.intRangeAtMost(u8, 0, table.xp_max - table.xp_min);
    } else {
        result.xp = table.xp_min;
    }

    // Compute total weight to determine if this is a weighted-selection table
    // (grass, gravel, leaves) vs a multi-drop table (mobs, chests).
    const has_weighted_selection = hasWeightedSelection(table.entries);

    if (has_weighted_selection) {
        // Weighted selection: pick exactly one entry based on weight.
        const entry = selectWeighted(table.entries, random);
        appendEntry(&result, entry, fortune_level, random);
    } else {
        // Multi-drop: roll each entry independently.
        for (table.entries) |entry| {
            if (result.item_count >= 8) break;
            appendEntry(&result, entry, fortune_level, random);
        }
    }

    return result;
}

/// Returns true when entries have varying weights, indicating a weighted-selection
/// table (pick one) rather than a multi-drop table (roll all).
fn hasWeightedSelection(entries: []const LootEntry) bool {
    if (entries.len <= 1) return false;
    const first_weight = entries[0].weight;
    for (entries[1..]) |e| {
        if (e.weight != first_weight) return true;
    }
    return false;
}

fn selectWeighted(entries: []const LootEntry, random: std.Random) LootEntry {
    var total_weight: u32 = 0;
    for (entries) |e| {
        total_weight += e.weight;
    }
    if (total_weight == 0) return entries[0];

    var roll = random.intRangeLessThan(u32, 0, total_weight);
    for (entries) |e| {
        if (roll < e.weight) return e;
        roll -= e.weight;
    }
    return entries[entries.len - 1];
}

fn appendEntry(
    result: *RollResult,
    entry: LootEntry,
    fortune_level: u8,
    random: std.Random,
) void {
    if (entry.item_id == 0 and entry.max_count == 0) return; // "nothing" entry
    if (result.item_count >= 8) return;

    const effective_max = entry.max_count + entry.fortune_bonus * fortune_level;
    const count: u8 = if (effective_max > entry.min_count)
        entry.min_count + random.intRangeAtMost(u8, 0, effective_max - entry.min_count)
    else
        entry.min_count;

    if (count == 0) return;

    result.items[result.item_count] = .{ .id = entry.item_id, .count = count };
    result.item_count += 1;
}

// ── Tests ──────────────────────────────────────────────────────────────────

test "stone drops cobblestone" {
    const table = getBlockLoot(STONE);
    const result = rollLoot(table, 0, 12345);
    try std.testing.expectEqual(@as(u8, 1), result.item_count);
    const item = result.items[0].?;
    try std.testing.expectEqual(ITEM_COBBLESTONE, item.id);
    try std.testing.expectEqual(@as(u8, 1), item.count);
}

test "diamond ore drops diamond with fortune bonus" {
    const table = getBlockLoot(DIAMOND_ORE);

    // Without fortune: always exactly 1.
    const no_fortune = rollLoot(table, 0, 42);
    try std.testing.expectEqual(@as(u8, 1), no_fortune.item_count);
    try std.testing.expectEqual(ITEM_DIAMOND, no_fortune.items[0].?.id);
    try std.testing.expectEqual(@as(u8, 1), no_fortune.items[0].?.count);

    // With fortune 3: max becomes 1 + 1*3 = 4, so count in [1,4].
    // Try many seeds and verify count is always >= 1 and <= 4.
    var saw_above_one = false;
    for (0..100) |i| {
        const r = rollLoot(table, 3, @as(u64, i) * 7919);
        try std.testing.expectEqual(@as(u8, 1), r.item_count);
        const count = r.items[0].?.count;
        try std.testing.expect(count >= 1);
        try std.testing.expect(count <= 4);
        if (count > 1) saw_above_one = true;
    }
    // With 100 samples from [1,4], we should see at least one > 1.
    try std.testing.expect(saw_above_one);
}

test "diamond ore xp range" {
    const table = getBlockLoot(DIAMOND_ORE);
    try std.testing.expectEqual(@as(u8, 3), table.xp_min);
    try std.testing.expectEqual(@as(u8, 7), table.xp_max);

    var min_seen: u8 = 255;
    var max_seen: u8 = 0;
    for (0..200) |i| {
        const r = rollLoot(table, 0, @as(u64, i) * 6271);
        if (r.xp < min_seen) min_seen = r.xp;
        if (r.xp > max_seen) max_seen = r.xp;
    }
    try std.testing.expect(min_seen >= 3);
    try std.testing.expect(max_seen <= 7);
}

test "grass seed chance roughly 12.5 percent" {
    const table = getBlockLoot(GRASS);
    var seed_count: u32 = 0;
    const trials: u32 = 1000;
    for (0..trials) |i| {
        const r = rollLoot(table, 0, @as(u64, i) * 104729);
        if (r.item_count > 0) {
            if (r.items[0]) |item| {
                if (item.id == ITEM_WHEAT_SEEDS) seed_count += 1;
            }
        }
    }
    // Expected ~125 out of 1000. Allow wide margin (50..250).
    try std.testing.expect(seed_count > 50);
    try std.testing.expect(seed_count < 250);
}

test "gravel drops gravel or flint" {
    const table = getBlockLoot(GRAVEL);
    var flint_count: u32 = 0;
    const trials: u32 = 1000;
    for (0..trials) |i| {
        const r = rollLoot(table, 0, @as(u64, i) * 999983);
        try std.testing.expectEqual(@as(u8, 1), r.item_count);
        const item = r.items[0].?;
        try std.testing.expect(item.id == ITEM_GRAVEL or item.id == ITEM_FLINT);
        if (item.id == ITEM_FLINT) flint_count += 1;
    }
    // Expected ~100 out of 1000. Allow wide margin.
    try std.testing.expect(flint_count > 30);
    try std.testing.expect(flint_count < 200);
}

test "leaves mostly drop nothing" {
    const table = getBlockLoot(OAK_LEAVES);
    var sapling_count: u32 = 0;
    const trials: u32 = 1000;
    for (0..trials) |i| {
        const r = rollLoot(table, 0, @as(u64, i) * 7727);
        if (r.item_count > 0) {
            if (r.items[0]) |item| {
                if (item.id == ITEM_SAPLING) sapling_count += 1;
            }
        }
    }
    // Expected ~50 out of 1000 (5%). Allow margin.
    try std.testing.expect(sapling_count > 10);
    try std.testing.expect(sapling_count < 120);
}

test "glass drops nothing" {
    const table = getBlockLoot(GLASS);
    const result = rollLoot(table, 0, 42);
    try std.testing.expectEqual(@as(u8, 0), result.item_count);
}

test "zombie drops rotten flesh and rare iron" {
    const table = getMobLoot(ZOMBIE);
    try std.testing.expectEqual(@as(usize, 2), table.entries.len);
    try std.testing.expectEqual(ITEM_ROTTEN_FLESH, table.entries[0].item_id);
    try std.testing.expectEqual(ITEM_IRON_INGOT, table.entries[1].item_id);

    // Weighted selection: rotten_flesh weight 39, iron weight 1.
    var iron_count: u32 = 0;
    const trials: u32 = 1000;
    for (0..trials) |i| {
        const r = rollLoot(table, 0, @as(u64, i) * 3571);
        try std.testing.expectEqual(@as(u8, 1), r.item_count);
        if (r.items[0].?.id == ITEM_IRON_INGOT) iron_count += 1;
    }
    // Expected ~25 out of 1000 (2.5%). Allow margin.
    try std.testing.expect(iron_count > 5);
    try std.testing.expect(iron_count < 80);
}

test "skeleton drops bone and arrow" {
    const table = getMobLoot(SKELETON);
    try std.testing.expectEqual(@as(usize, 2), table.entries.len);

    // Equal weights => multi-drop, rolls both entries.
    const r = rollLoot(table, 0, 42);
    // Both entries have min_count=0, so either or both could be 0.
    // Verify item IDs when present.
    for (0..r.item_count) |i| {
        const item = r.items[i].?;
        try std.testing.expect(item.id == ITEM_BONE or item.id == ITEM_ARROW);
    }
}

test "creeper drops gunpowder" {
    const table = getMobLoot(CREEPER);
    try std.testing.expectEqual(@as(usize, 1), table.entries.len);
    try std.testing.expectEqual(ITEM_GUNPOWDER, table.entries[0].item_id);
}

test "pig drops raw pork 1-3" {
    const table = getMobLoot(PIG);
    var min_seen: u8 = 255;
    var max_seen: u8 = 0;
    for (0..100) |i| {
        const r = rollLoot(table, 0, @as(u64, i) * 9973);
        try std.testing.expectEqual(@as(u8, 1), r.item_count);
        try std.testing.expectEqual(ITEM_RAW_PORK, r.items[0].?.id);
        const c = r.items[0].?.count;
        if (c < min_seen) min_seen = c;
        if (c > max_seen) max_seen = c;
    }
    try std.testing.expect(min_seen >= 1);
    try std.testing.expect(max_seen <= 3);
}

test "cow drops beef and leather" {
    const table = getMobLoot(COW);
    try std.testing.expectEqual(@as(usize, 2), table.entries.len);
    try std.testing.expectEqual(ITEM_RAW_BEEF, table.entries[0].item_id);
    try std.testing.expectEqual(ITEM_LEATHER, table.entries[1].item_id);
}

test "chicken drops raw chicken and feather" {
    const table = getMobLoot(CHICKEN);
    try std.testing.expectEqual(@as(usize, 2), table.entries.len);
    try std.testing.expectEqual(ITEM_RAW_CHICKEN, table.entries[0].item_id);
    try std.testing.expectEqual(ITEM_FEATHER, table.entries[1].item_id);
}

test "sheep drops wool" {
    const table = getMobLoot(SHEEP);
    const r = rollLoot(table, 0, 1);
    try std.testing.expectEqual(@as(u8, 1), r.item_count);
    try std.testing.expectEqual(ITEM_WOOL, r.items[0].?.id);
    try std.testing.expectEqual(@as(u8, 1), r.items[0].?.count);
}

test "chest loot produces items" {
    const table = getChestLoot(CHEST_DUNGEON);
    try std.testing.expect(table.entries.len > 0);
    const r = rollLoot(table, 0, 555);
    try std.testing.expect(r.item_count > 0);
}

test "unknown block returns empty table" {
    const table = getBlockLoot(255);
    try std.testing.expectEqual(@as(usize, 0), table.entries.len);
    const r = rollLoot(table, 0, 1);
    try std.testing.expectEqual(@as(u8, 0), r.item_count);
    try std.testing.expectEqual(@as(u8, 0), r.xp);
}

test "unknown mob returns empty table" {
    const table = getMobLoot(255);
    try std.testing.expectEqual(@as(usize, 0), table.entries.len);
}

test "iron ore drops raw iron without fortune bonus" {
    const table = getBlockLoot(IRON_ORE);
    const r0 = rollLoot(table, 0, 1);
    const r3 = rollLoot(table, 3, 1);
    // fortune_bonus is 0, so count should be the same regardless of fortune level.
    try std.testing.expectEqual(@as(u8, 1), r0.items[0].?.count);
    try std.testing.expectEqual(@as(u8, 1), r3.items[0].?.count);
}

test "coal ore fortune increases max count" {
    const table = getBlockLoot(COAL_ORE);
    var saw_above_one = false;
    for (0..100) |i| {
        const r = rollLoot(table, 3, @as(u64, i) * 8111);
        const count = r.items[0].?.count;
        try std.testing.expect(count >= 1);
        try std.testing.expect(count <= 4); // 1 + 1*3
        if (count > 1) saw_above_one = true;
    }
    try std.testing.expect(saw_above_one);
}
