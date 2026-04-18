const std = @import("std");

pub const BastionType = enum(u8) {
    housing,
    stables,
    bridge,
    treasure,
};

pub const BastionBlockType = enum(u8) {
    blackstone,
    gilded_blackstone,
    basalt,
    nether_bricks,
    gold_block,
    chest,
    spawner,
};

pub const BastionBlock = struct {
    dx: i8,
    dy: i8,
    dz: i8,
    block_type: BastionBlockType,
};

pub const BastionRoom = struct {
    room_type: BastionType,
    blocks: [256]?BastionBlock,
    block_count: u16,
    piglin_spawns: u8,
    hoglin_spawns: u8,
};

pub const RoomPlacement = struct {
    room: BastionRoom,
    x: i8,
    z: i8,
};

pub const BastionLayout = struct {
    bastion_type: BastionType,
    rooms: [8]?RoomPlacement,
    room_count: u8,
};

pub const LootEntry = struct {
    item: u16,
    count: u8,
};

const ITEM_NETHERITE_SCRAP: u16 = 750;
const ITEM_GOLD_INGOT: u16 = 266;
const ITEM_GOLD_BLOCK: u16 = 41;
const ITEM_ENCHANTED_GOLDEN_APPLE: u16 = 322;
const ITEM_ENCHANTED_CROSSBOW: u16 = 460;
const ITEM_ENCHANTED_IRON_SWORD: u16 = 267;
const ITEM_ENCHANTED_DIAMOND_PICKAXE: u16 = 278;
const ITEM_SNOUT_BANNER: u16 = 800;

const LOOT_ITEMS = [_]u16{
    ITEM_NETHERITE_SCRAP,
    ITEM_GOLD_INGOT,
    ITEM_GOLD_BLOCK,
    ITEM_ENCHANTED_GOLDEN_APPLE,
    ITEM_ENCHANTED_CROSSBOW,
    ITEM_ENCHANTED_IRON_SWORD,
    ITEM_ENCHANTED_DIAMOND_PICKAXE,
    ITEM_SNOUT_BANNER,
};

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

    fn boundedU8(self: *SplitMix64, max: u8) u8 {
        return @intCast(self.next() % @as(u64, max));
    }

    fn boundedI8(self: *SplitMix64, min: i8, max: i8) i8 {
        const range: u64 = @intCast(@as(i16, max) - @as(i16, min) + 1);
        const offset: i16 = @intCast(self.next() % range);
        return @intCast(@as(i16, min) + offset);
    }
};

fn blockPaletteForType(bastion_type: BastionType) [4]BastionBlockType {
    return switch (bastion_type) {
        .housing => .{ .blackstone, .nether_bricks, .gilded_blackstone, .basalt },
        .stables => .{ .blackstone, .basalt, .nether_bricks, .blackstone },
        .bridge => .{ .blackstone, .nether_bricks, .basalt, .gilded_blackstone },
        .treasure => .{ .gilded_blackstone, .gold_block, .blackstone, .nether_bricks },
    };
}

fn generateRoom(rng: *SplitMix64, room_type: BastionType) BastionRoom {
    var room = BastionRoom{
        .room_type = room_type,
        .blocks = [_]?BastionBlock{null} ** 256,
        .block_count = 0,
        .piglin_spawns = 0,
        .hoglin_spawns = 0,
    };

    const palette = blockPaletteForType(room_type);
    const count: u16 = 30 + @as(u16, rng.boundedU8(71));

    var i: u16 = 0;
    while (i < count) : (i += 1) {
        const btype_idx = rng.boundedU8(4);
        room.blocks[i] = BastionBlock{
            .dx = rng.boundedI8(-8, 8),
            .dy = rng.boundedI8(0, 12),
            .dz = rng.boundedI8(-8, 8),
            .block_type = palette[btype_idx],
        };
    }

    if (room_type == .treasure and count < 256) {
        room.blocks[count] = BastionBlock{
            .dx = rng.boundedI8(-4, 4),
            .dy = rng.boundedI8(0, 3),
            .dz = rng.boundedI8(-4, 4),
            .block_type = .chest,
        };
        room.block_count = count + 1;
    } else {
        room.block_count = count;
    }

    if ((room_type == .housing or room_type == .stables) and room.block_count < 256) {
        room.blocks[room.block_count] = BastionBlock{
            .dx = rng.boundedI8(-3, 3),
            .dy = rng.boundedI8(0, 2),
            .dz = rng.boundedI8(-3, 3),
            .block_type = .spawner,
        };
        room.block_count += 1;
    }

    room.piglin_spawns = 2 + rng.boundedU8(5);
    if (room_type == .stables) {
        room.hoglin_spawns = 1 + rng.boundedU8(4);
    }

    return room;
}

pub fn generateBastion(seed: u64) BastionLayout {
    var rng = SplitMix64.init(seed);

    const bastion_type: BastionType = @enumFromInt(rng.next() % 4);
    const room_count: u8 = 3 + @as(u8, @intCast(rng.next() % 6));

    var layout = BastionLayout{
        .bastion_type = bastion_type,
        .rooms = [_]?RoomPlacement{null} ** 8,
        .room_count = room_count,
    };

    var i: u8 = 0;
    while (i < room_count) : (i += 1) {
        const room_type: BastionType = if (i == 0)
            bastion_type
        else
            @enumFromInt(rng.next() % 4);

        layout.rooms[i] = RoomPlacement{
            .room = generateRoom(&rng, room_type),
            .x = rng.boundedI8(-32, 32),
            .z = rng.boundedI8(-32, 32),
        };
    }

    return layout;
}

pub fn getTreasureLoot(seed: u64) [8]?LootEntry {
    var rng = SplitMix64.init(seed ^ 0xdeadbeef_cafebabe);
    var loot = [_]?LootEntry{null} ** 8;

    const count: u8 = 3 + @as(u8, @intCast(rng.next() % 6));

    var i: u8 = 0;
    while (i < count) : (i += 1) {
        const item_idx = rng.boundedU8(@intCast(LOOT_ITEMS.len));
        const item_id = LOOT_ITEMS[item_idx];

        const max_count: u8 = switch (item_id) {
            ITEM_NETHERITE_SCRAP => 2,
            ITEM_ENCHANTED_GOLDEN_APPLE => 1,
            ITEM_GOLD_BLOCK => 4,
            ITEM_GOLD_INGOT => 12,
            else => 1,
        };
        const amount: u8 = 1 + rng.boundedU8(max_count);

        loot[i] = LootEntry{
            .item = item_id,
            .count = amount,
        };
    }

    return loot;
}

test "generate all four bastion types" {
    // Use different seeds to cover all 4 types
    var found = [_]bool{false} ** 4;
    var seed: u64 = 0;
    while (seed < 100) : (seed += 1) {
        const layout = generateBastion(seed);
        found[@intFromEnum(layout.bastion_type)] = true;

        // Validate room_count in range
        try std.testing.expect(layout.room_count >= 3);
        try std.testing.expect(layout.room_count <= 8);
    }

    // All 4 types should appear across 100 seeds
    for (found) |f| {
        try std.testing.expect(f);
    }
}

test "treasure loot contains valid items" {
    const loot = getTreasureLoot(42);
    var non_null_count: u8 = 0;

    for (loot) |entry| {
        if (entry) |e| {
            non_null_count += 1;
            try std.testing.expect(e.count >= 1);

            // Verify item is in the known loot table
            var found = false;
            for (LOOT_ITEMS) |valid_id| {
                if (e.item == valid_id) {
                    found = true;
                    break;
                }
            }
            try std.testing.expect(found);
        }
    }

    // Should have at least 3 loot entries
    try std.testing.expect(non_null_count >= 3);
    try std.testing.expect(non_null_count <= 8);
}

test "piglin spawns present in all rooms" {
    const layout = generateBastion(12345);
    var i: u8 = 0;
    while (i < layout.room_count) : (i += 1) {
        const placement = layout.rooms[i].?;
        try std.testing.expect(placement.room.piglin_spawns >= 2);
        try std.testing.expect(placement.room.piglin_spawns <= 6);
    }
}

test "hoglin spawns only in stables rooms" {
    // Generate many layouts and check hoglin constraint
    var seed: u64 = 0;
    while (seed < 50) : (seed += 1) {
        const layout = generateBastion(seed);
        var i: u8 = 0;
        while (i < layout.room_count) : (i += 1) {
            const placement = layout.rooms[i].?;
            if (placement.room.room_type != .stables) {
                try std.testing.expectEqual(@as(u8, 0), placement.room.hoglin_spawns);
            }
        }
    }
}

test "valid layout structure" {
    const layout = generateBastion(99999);

    // First room type matches bastion type
    const first = layout.rooms[0].?;
    try std.testing.expectEqual(layout.bastion_type, first.room.room_type);

    // All rooms within room_count are non-null, rest are null
    var i: u8 = 0;
    while (i < 8) : (i += 1) {
        if (i < layout.room_count) {
            try std.testing.expect(layout.rooms[i] != null);
            const p = layout.rooms[i].?;
            try std.testing.expect(p.room.block_count >= 30);
            try std.testing.expect(p.x >= -32 and p.x <= 32);
            try std.testing.expect(p.z >= -32 and p.z <= 32);
        } else {
            try std.testing.expectEqual(@as(?RoomPlacement, null), layout.rooms[i]);
        }
    }
}

test "deterministic generation" {
    const a = generateBastion(777);
    const b = generateBastion(777);
    try std.testing.expectEqual(a.bastion_type, b.bastion_type);
    try std.testing.expectEqual(a.room_count, b.room_count);

    const loot_a = getTreasureLoot(777);
    const loot_b = getTreasureLoot(777);
    for (loot_a, loot_b) |ea, eb| {
        if (ea) |a_entry| {
            const b_entry = eb.?;
            try std.testing.expectEqual(a_entry.item, b_entry.item);
            try std.testing.expectEqual(a_entry.count, b_entry.count);
        } else {
            try std.testing.expectEqual(@as(?LootEntry, null), eb);
        }
    }
}
