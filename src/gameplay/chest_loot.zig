const std = @import("std");

pub const ChestType = enum {
    dungeon,
    mineshaft,
    stronghold_corridor,
    stronghold_library,
    desert_temple,
    jungle_temple,
    bastion_treasure,
    end_city,
    nether_fortress,
    village_armorer,
    village_temple,
    buried_treasure,
};

pub const LootEntry = struct {
    item_id: u16,
    min_count: u8,
    max_count: u8,
    weight: u16,
};

pub const ChestSlot = struct {
    id: u16,
    count: u8,
};

pub const ChestContents = struct {
    items: [27]?ChestSlot,
    item_count: u8,
};

const ITEM = struct {
    const string: u16 = 287;
    const name_tag: u16 = 421;
    const golden_apple: u16 = 322;
    const music_disc_13: u16 = 2256;
    const music_disc_cat: u16 = 2257;
    const saddle: u16 = 329;
    const iron_ingot: u16 = 265;
    const gold_ingot: u16 = 266;
    const wheat: u16 = 296;
    const bread: u16 = 297;
    const redstone: u16 = 331;
    const coal: u16 = 263;
    const bone: u16 = 352;
    const diamond: u16 = 264;
    const emerald: u16 = 388;
    const enchanted_book: u16 = 403;
    const rotten_flesh: u16 = 367;
    const gunpowder: u16 = 289;
    const iron_horse_armor: u16 = 417;
    const gold_horse_armor: u16 = 418;
    const diamond_horse_armor: u16 = 419;
    const eye_of_ender: u16 = 381;
    const apple: u16 = 260;
    const book: u16 = 340;
    const ender_pearl: u16 = 368;
    const iron_pickaxe: u16 = 257;
    const elytra: u16 = 443;
    const diamond_sword: u16 = 276;
    const diamond_chestplate: u16 = 311;
    const diamond_leggings: u16 = 312;
    const iron_sword: u16 = 267;
    const gold_block: u16 = 41;
    const netherite_ingot: u16 = 750;
    const ancient_debris: u16 = 751;
    const snout_banner: u16 = 752;
    const crossbow: u16 = 471;
    const spectral_arrow: u16 = 439;
    const obsidian: u16 = 49;
    const blaze_rod: u16 = 369;
    const iron_nugget: u16 = 452;
    const nether_wart: u16 = 372;
    const flint_and_steel: u16 = 259;
    const iron_leggings: u16 = 308;
    const iron_chestplate: u16 = 307;
    const diamond_pickaxe: u16 = 278;
    const heart_of_sea: u16 = 467;
    const tnt: u16 = 46;
    const prismarine_crystals: u16 = 410;
    const cooked_cod: u16 = 350;
    const gold_nugget: u16 = 371;
    const bamboo: u16 = 472;
    const enchanted_golden_apple: u16 = 466;
    const lever: u16 = 69;
    const dispenser: u16 = 23;
    const beetroot_seeds: u16 = 458;
    const compass: u16 = 345;
};

const dungeon_loot = [_]LootEntry{
    .{ .item_id = ITEM.string, .min_count = 1, .max_count = 4, .weight = 20 },
    .{ .item_id = ITEM.name_tag, .min_count = 1, .max_count = 1, .weight = 10 },
    .{ .item_id = ITEM.golden_apple, .min_count = 1, .max_count = 1, .weight = 15 },
    .{ .item_id = ITEM.music_disc_13, .min_count = 1, .max_count = 1, .weight = 8 },
    .{ .item_id = ITEM.music_disc_cat, .min_count = 1, .max_count = 1, .weight = 8 },
    .{ .item_id = ITEM.saddle, .min_count = 1, .max_count = 1, .weight = 12 },
    .{ .item_id = ITEM.iron_ingot, .min_count = 1, .max_count = 4, .weight = 25 },
    .{ .item_id = ITEM.gold_ingot, .min_count = 1, .max_count = 4, .weight = 20 },
    .{ .item_id = ITEM.wheat, .min_count = 1, .max_count = 4, .weight = 25 },
    .{ .item_id = ITEM.bread, .min_count = 1, .max_count = 1, .weight = 20 },
    .{ .item_id = ITEM.redstone, .min_count = 1, .max_count = 4, .weight = 15 },
    .{ .item_id = ITEM.coal, .min_count = 1, .max_count = 4, .weight = 20 },
    .{ .item_id = ITEM.bone, .min_count = 1, .max_count = 8, .weight = 25 },
    .{ .item_id = ITEM.rotten_flesh, .min_count = 1, .max_count = 8, .weight = 25 },
    .{ .item_id = ITEM.iron_horse_armor, .min_count = 1, .max_count = 1, .weight = 8 },
};

const mineshaft_loot = [_]LootEntry{
    .{ .item_id = ITEM.iron_ingot, .min_count = 1, .max_count = 5, .weight = 25 },
    .{ .item_id = ITEM.gold_ingot, .min_count = 1, .max_count = 3, .weight = 15 },
    .{ .item_id = ITEM.redstone, .min_count = 4, .max_count = 9, .weight = 15 },
    .{ .item_id = ITEM.coal, .min_count = 3, .max_count = 8, .weight = 20 },
    .{ .item_id = ITEM.bread, .min_count = 1, .max_count = 3, .weight = 20 },
    .{ .item_id = ITEM.name_tag, .min_count = 1, .max_count = 1, .weight = 10 },
    .{ .item_id = ITEM.iron_pickaxe, .min_count = 1, .max_count = 1, .weight = 8 },
    .{ .item_id = ITEM.beetroot_seeds, .min_count = 2, .max_count = 4, .weight = 15 },
    .{ .item_id = ITEM.diamond, .min_count = 1, .max_count = 2, .weight = 5 },
    .{ .item_id = ITEM.golden_apple, .min_count = 1, .max_count = 1, .weight = 5 },
    .{ .item_id = ITEM.enchanted_book, .min_count = 1, .max_count = 1, .weight = 5 },
};

const stronghold_corridor_loot = [_]LootEntry{
    .{ .item_id = ITEM.eye_of_ender, .min_count = 1, .max_count = 1, .weight = 5 },
    .{ .item_id = ITEM.apple, .min_count = 1, .max_count = 3, .weight = 20 },
    .{ .item_id = ITEM.iron_ingot, .min_count = 1, .max_count = 5, .weight = 25 },
    .{ .item_id = ITEM.gold_ingot, .min_count = 1, .max_count = 3, .weight = 15 },
    .{ .item_id = ITEM.book, .min_count = 1, .max_count = 3, .weight = 20 },
    .{ .item_id = ITEM.ender_pearl, .min_count = 1, .max_count = 1, .weight = 8 },
    .{ .item_id = ITEM.iron_sword, .min_count = 1, .max_count = 1, .weight = 10 },
    .{ .item_id = ITEM.iron_pickaxe, .min_count = 1, .max_count = 1, .weight = 8 },
    .{ .item_id = ITEM.redstone, .min_count = 1, .max_count = 5, .weight = 15 },
    .{ .item_id = ITEM.bread, .min_count = 1, .max_count = 3, .weight = 20 },
    .{ .item_id = ITEM.coal, .min_count = 3, .max_count = 8, .weight = 15 },
};

const stronghold_library_loot = [_]LootEntry{
    .{ .item_id = ITEM.book, .min_count = 1, .max_count = 3, .weight = 40 },
    .{ .item_id = ITEM.enchanted_book, .min_count = 1, .max_count = 1, .weight = 15 },
    .{ .item_id = ITEM.eye_of_ender, .min_count = 1, .max_count = 1, .weight = 5 },
    .{ .item_id = ITEM.apple, .min_count = 1, .max_count = 2, .weight = 15 },
    .{ .item_id = ITEM.iron_ingot, .min_count = 1, .max_count = 3, .weight = 15 },
    .{ .item_id = ITEM.gold_ingot, .min_count = 1, .max_count = 2, .weight = 10 },
    .{ .item_id = ITEM.redstone, .min_count = 1, .max_count = 4, .weight = 10 },
    .{ .item_id = ITEM.compass, .min_count = 1, .max_count = 1, .weight = 8 },
};

const desert_temple_loot = [_]LootEntry{
    .{ .item_id = ITEM.diamond, .min_count = 1, .max_count = 3, .weight = 10 },
    .{ .item_id = ITEM.emerald, .min_count = 1, .max_count = 3, .weight = 12 },
    .{ .item_id = ITEM.gold_ingot, .min_count = 2, .max_count = 7, .weight = 20 },
    .{ .item_id = ITEM.iron_ingot, .min_count = 1, .max_count = 5, .weight = 20 },
    .{ .item_id = ITEM.enchanted_book, .min_count = 1, .max_count = 1, .weight = 12 },
    .{ .item_id = ITEM.golden_apple, .min_count = 1, .max_count = 1, .weight = 10 },
    .{ .item_id = ITEM.iron_horse_armor, .min_count = 1, .max_count = 1, .weight = 10 },
    .{ .item_id = ITEM.gold_horse_armor, .min_count = 1, .max_count = 1, .weight = 8 },
    .{ .item_id = ITEM.diamond_horse_armor, .min_count = 1, .max_count = 1, .weight = 5 },
    .{ .item_id = ITEM.saddle, .min_count = 1, .max_count = 1, .weight = 10 },
    .{ .item_id = ITEM.bone, .min_count = 4, .max_count = 6, .weight = 20 },
    .{ .item_id = ITEM.rotten_flesh, .min_count = 3, .max_count = 7, .weight = 20 },
    .{ .item_id = ITEM.gunpowder, .min_count = 1, .max_count = 8, .weight = 20 },
    .{ .item_id = ITEM.enchanted_golden_apple, .min_count = 1, .max_count = 1, .weight = 2 },
};

const jungle_temple_loot = [_]LootEntry{
    .{ .item_id = ITEM.diamond, .min_count = 1, .max_count = 3, .weight = 8 },
    .{ .item_id = ITEM.emerald, .min_count = 1, .max_count = 3, .weight = 10 },
    .{ .item_id = ITEM.gold_ingot, .min_count = 2, .max_count = 7, .weight = 18 },
    .{ .item_id = ITEM.iron_ingot, .min_count = 1, .max_count = 5, .weight = 20 },
    .{ .item_id = ITEM.enchanted_book, .min_count = 1, .max_count = 1, .weight = 8 },
    .{ .item_id = ITEM.saddle, .min_count = 1, .max_count = 1, .weight = 10 },
    .{ .item_id = ITEM.bone, .min_count = 4, .max_count = 6, .weight = 25 },
    .{ .item_id = ITEM.bamboo, .min_count = 1, .max_count = 3, .weight = 20 },
    .{ .item_id = ITEM.lever, .min_count = 1, .max_count = 3, .weight = 15 },
    .{ .item_id = ITEM.dispenser, .min_count = 1, .max_count = 2, .weight = 10 },
    .{ .item_id = ITEM.iron_horse_armor, .min_count = 1, .max_count = 1, .weight = 5 },
};

const bastion_treasure_loot = [_]LootEntry{
    .{ .item_id = ITEM.netherite_ingot, .min_count = 1, .max_count = 1, .weight = 5 },
    .{ .item_id = ITEM.ancient_debris, .min_count = 1, .max_count = 2, .weight = 8 },
    .{ .item_id = ITEM.gold_block, .min_count = 2, .max_count = 5, .weight = 15 },
    .{ .item_id = ITEM.gold_ingot, .min_count = 3, .max_count = 9, .weight = 20 },
    .{ .item_id = ITEM.iron_ingot, .min_count = 3, .max_count = 9, .weight = 20 },
    .{ .item_id = ITEM.diamond, .min_count = 1, .max_count = 3, .weight = 10 },
    .{ .item_id = ITEM.snout_banner, .min_count = 1, .max_count = 1, .weight = 12 },
    .{ .item_id = ITEM.crossbow, .min_count = 1, .max_count = 1, .weight = 10 },
    .{ .item_id = ITEM.spectral_arrow, .min_count = 6, .max_count = 12, .weight = 15 },
    .{ .item_id = ITEM.enchanted_golden_apple, .min_count = 1, .max_count = 1, .weight = 5 },
    .{ .item_id = ITEM.diamond_sword, .min_count = 1, .max_count = 1, .weight = 5 },
};

const end_city_loot = [_]LootEntry{
    .{ .item_id = ITEM.diamond, .min_count = 2, .max_count = 7, .weight = 15 },
    .{ .item_id = ITEM.elytra, .min_count = 1, .max_count = 1, .weight = 3 },
    .{ .item_id = ITEM.iron_ingot, .min_count = 4, .max_count = 8, .weight = 20 },
    .{ .item_id = ITEM.gold_ingot, .min_count = 2, .max_count = 7, .weight = 20 },
    .{ .item_id = ITEM.diamond_sword, .min_count = 1, .max_count = 1, .weight = 8 },
    .{ .item_id = ITEM.diamond_chestplate, .min_count = 1, .max_count = 1, .weight = 8 },
    .{ .item_id = ITEM.diamond_leggings, .min_count = 1, .max_count = 1, .weight = 8 },
    .{ .item_id = ITEM.diamond_pickaxe, .min_count = 1, .max_count = 1, .weight = 8 },
    .{ .item_id = ITEM.enchanted_book, .min_count = 1, .max_count = 1, .weight = 10 },
    .{ .item_id = ITEM.emerald, .min_count = 2, .max_count = 6, .weight = 12 },
    .{ .item_id = ITEM.iron_leggings, .min_count = 1, .max_count = 1, .weight = 10 },
    .{ .item_id = ITEM.iron_chestplate, .min_count = 1, .max_count = 1, .weight = 10 },
    .{ .item_id = ITEM.obsidian, .min_count = 2, .max_count = 4, .weight = 10 },
};

const nether_fortress_loot = [_]LootEntry{
    .{ .item_id = ITEM.diamond, .min_count = 1, .max_count = 3, .weight = 8 },
    .{ .item_id = ITEM.gold_ingot, .min_count = 1, .max_count = 3, .weight = 20 },
    .{ .item_id = ITEM.iron_ingot, .min_count = 1, .max_count = 5, .weight = 20 },
    .{ .item_id = ITEM.saddle, .min_count = 1, .max_count = 1, .weight = 12 },
    .{ .item_id = ITEM.gold_horse_armor, .min_count = 1, .max_count = 1, .weight = 8 },
    .{ .item_id = ITEM.iron_horse_armor, .min_count = 1, .max_count = 1, .weight = 10 },
    .{ .item_id = ITEM.nether_wart, .min_count = 3, .max_count = 7, .weight = 15 },
    .{ .item_id = ITEM.blaze_rod, .min_count = 1, .max_count = 3, .weight = 10 },
    .{ .item_id = ITEM.obsidian, .min_count = 2, .max_count = 4, .weight = 10 },
    .{ .item_id = ITEM.flint_and_steel, .min_count = 1, .max_count = 1, .weight = 10 },
    .{ .item_id = ITEM.bone, .min_count = 1, .max_count = 8, .weight = 20 },
};

const village_armorer_loot = [_]LootEntry{
    .{ .item_id = ITEM.iron_ingot, .min_count = 1, .max_count = 3, .weight = 25 },
    .{ .item_id = ITEM.iron_leggings, .min_count = 1, .max_count = 1, .weight = 10 },
    .{ .item_id = ITEM.iron_chestplate, .min_count = 1, .max_count = 1, .weight = 10 },
    .{ .item_id = ITEM.iron_sword, .min_count = 1, .max_count = 1, .weight = 10 },
    .{ .item_id = ITEM.iron_horse_armor, .min_count = 1, .max_count = 1, .weight = 8 },
    .{ .item_id = ITEM.bread, .min_count = 1, .max_count = 4, .weight = 20 },
    .{ .item_id = ITEM.emerald, .min_count = 1, .max_count = 1, .weight = 8 },
    .{ .item_id = ITEM.diamond, .min_count = 1, .max_count = 1, .weight = 3 },
    .{ .item_id = ITEM.coal, .min_count = 1, .max_count = 3, .weight = 20 },
    .{ .item_id = ITEM.saddle, .min_count = 1, .max_count = 1, .weight = 5 },
    .{ .item_id = ITEM.iron_nugget, .min_count = 1, .max_count = 5, .weight = 15 },
};

const village_temple_loot = [_]LootEntry{
    .{ .item_id = ITEM.redstone, .min_count = 1, .max_count = 4, .weight = 20 },
    .{ .item_id = ITEM.bread, .min_count = 1, .max_count = 4, .weight = 22 },
    .{ .item_id = ITEM.rotten_flesh, .min_count = 1, .max_count = 4, .weight = 20 },
    .{ .item_id = ITEM.gold_ingot, .min_count = 1, .max_count = 4, .weight = 10 },
    .{ .item_id = ITEM.emerald, .min_count = 1, .max_count = 4, .weight = 8 },
    .{ .item_id = ITEM.diamond, .min_count = 1, .max_count = 1, .weight = 3 },
    .{ .item_id = ITEM.golden_apple, .min_count = 1, .max_count = 1, .weight = 5 },
    .{ .item_id = ITEM.iron_ingot, .min_count = 1, .max_count = 4, .weight = 15 },
    .{ .item_id = ITEM.coal, .min_count = 1, .max_count = 4, .weight = 20 },
};

const buried_treasure_loot = [_]LootEntry{
    .{ .item_id = ITEM.heart_of_sea, .min_count = 1, .max_count = 1, .weight = 20 },
    .{ .item_id = ITEM.diamond, .min_count = 1, .max_count = 2, .weight = 15 },
    .{ .item_id = ITEM.emerald, .min_count = 4, .max_count = 8, .weight = 15 },
    .{ .item_id = ITEM.gold_ingot, .min_count = 1, .max_count = 4, .weight = 20 },
    .{ .item_id = ITEM.iron_ingot, .min_count = 3, .max_count = 5, .weight = 25 },
    .{ .item_id = ITEM.tnt, .min_count = 1, .max_count = 2, .weight = 12 },
    .{ .item_id = ITEM.prismarine_crystals, .min_count = 1, .max_count = 5, .weight = 15 },
    .{ .item_id = ITEM.cooked_cod, .min_count = 2, .max_count = 4, .weight = 20 },
    .{ .item_id = ITEM.iron_sword, .min_count = 1, .max_count = 1, .weight = 10 },
    .{ .item_id = ITEM.gold_nugget, .min_count = 1, .max_count = 10, .weight = 15 },
};

pub fn getLootTable(chest_type: ChestType) []const LootEntry {
    return switch (chest_type) {
        .dungeon => &dungeon_loot,
        .mineshaft => &mineshaft_loot,
        .stronghold_corridor => &stronghold_corridor_loot,
        .stronghold_library => &stronghold_library_loot,
        .desert_temple => &desert_temple_loot,
        .jungle_temple => &jungle_temple_loot,
        .bastion_treasure => &bastion_treasure_loot,
        .end_city => &end_city_loot,
        .nether_fortress => &nether_fortress_loot,
        .village_armorer => &village_armorer_loot,
        .village_temple => &village_temple_loot,
        .buried_treasure => &buried_treasure_loot,
    };
}

pub fn generateChestContents(chest_type: ChestType, seed: u64) ChestContents {
    const table = getLootTable(chest_type);
    var rng = SplitMix64.init(seed);

    // Determine number of items to place (4-8 items)
    const num_items: u8 = @intCast(4 + rng.next() % 5);

    var contents = ChestContents{
        .items = [_]?ChestSlot{null} ** 27,
        .item_count = 0,
    };

    var total_weight: u64 = 0;
    for (table) |entry| {
        total_weight += entry.weight;
    }

    if (total_weight == 0) return contents;

    var placed: u8 = 0;
    while (placed < num_items) {
        var roll = rng.next() % total_weight;
        var selected: ?*const LootEntry = null;
        for (table) |*entry| {
            if (roll < entry.weight) {
                selected = entry;
                break;
            }
            roll -= entry.weight;
        }

        const entry = selected orelse &table[table.len - 1];

        const range: u64 = @as(u64, entry.max_count - entry.min_count) + 1;
        const count: u8 = entry.min_count + @as(u8, @intCast(rng.next() % range));

        const slot_idx: usize = @intCast(rng.next() % 27);
        var target_slot: usize = slot_idx;
        var found_slot = false;
        for (0..27) |offset| {
            const check = (slot_idx + offset) % 27;
            if (contents.items[check] == null) {
                target_slot = check;
                found_slot = true;
                break;
            }
        }

        if (!found_slot) break;

        contents.items[target_slot] = ChestSlot{
            .id = entry.item_id,
            .count = count,
        };
        placed += 1;
    }

    contents.item_count = placed;
    return contents;
}

/// Simple SplitMix64 PRNG for deterministic chest generation.
const SplitMix64 = struct {
    state: u64,

    fn init(seed: u64) SplitMix64 {
        return .{ .state = seed };
    }

    fn next(self: *SplitMix64) u64 {
        self.state +%= 0x9e3779b97f4a7c15;
        var z = self.state;
        z = (z ^ (z >> 30)) *% 0xbf58476d1ce4e5b9;
        z = (z ^ (z >> 27)) *% 0x94d049bb133111eb;
        return z ^ (z >> 31);
    }
};

test "dungeon loot has items" {
    const contents = generateChestContents(.dungeon, 12345);
    try std.testing.expect(contents.item_count > 0);
    var found_any = false;
    for (contents.items) |slot| {
        if (slot != null) {
            found_any = true;
            break;
        }
    }
    try std.testing.expect(found_any);
}

test "desert temple has diamonds in loot table" {
    const table = getLootTable(.desert_temple);
    var has_diamond = false;
    for (table) |entry| {
        if (entry.item_id == ITEM.diamond) {
            has_diamond = true;
            break;
        }
    }
    try std.testing.expect(has_diamond);
}

test "end city has elytra chance" {
    const table = getLootTable(.end_city);
    var has_elytra = false;
    for (table) |entry| {
        if (entry.item_id == ITEM.elytra) {
            has_elytra = true;
            break;
        }
    }
    try std.testing.expect(has_elytra);
}

test "all chest types have non-empty loot tables" {
    inline for (std.meta.fields(ChestType)) |field| {
        const chest_type = @as(ChestType, @enumFromInt(field.value));
        const table = getLootTable(chest_type);
        try std.testing.expect(table.len > 0);
    }
}

test "generation is deterministic from seed" {
    const contents_a = generateChestContents(.dungeon, 99999);
    const contents_b = generateChestContents(.dungeon, 99999);

    try std.testing.expectEqual(contents_a.item_count, contents_b.item_count);
    for (0..27) |i| {
        if (contents_a.items[i]) |a| {
            const b = contents_b.items[i].?;
            try std.testing.expectEqual(a.id, b.id);
            try std.testing.expectEqual(a.count, b.count);
        } else {
            try std.testing.expectEqual(contents_b.items[i], null);
        }
    }
}
