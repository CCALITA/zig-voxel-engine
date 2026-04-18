const std = @import("std");

pub const MansionRoom = enum(u4) {
    entrance_hall,
    staircase,
    kitchen,
    library,
    bedroom,
    arena,
    loot_room,
    balcony,
    attic,
    secret_room,
};

pub const MansionRoomPlacement = struct {
    room: MansionRoom,
    x: i8,
    z: i8,
    rotation: u2,
};

pub const MansionFloor = struct {
    rooms: [16]?MansionRoomPlacement,
    room_count: u8,

    pub fn init() MansionFloor {
        return .{
            .rooms = [_]?MansionRoomPlacement{null} ** 16,
            .room_count = 0,
        };
    }

    pub fn addRoom(self: MansionFloor, placement: MansionRoomPlacement) MansionFloor {
        var result = self;
        if (result.room_count < 16) {
            result.rooms[result.room_count] = placement;
            result.room_count += 1;
        }
        return result;
    }

    pub fn containsRoom(self: *const MansionFloor, room: MansionRoom) bool {
        for (self.rooms[0..self.room_count]) |maybe_placement| {
            if (maybe_placement) |placement| {
                if (placement.room == room) return true;
            }
        }
        return false;
    }
};

pub const MansionLayout = struct {
    floors: [3]MansionFloor,
    width: u8 = 32,
    depth: u8 = 32,

    pub fn floorCount(self: *const MansionLayout) u8 {
        var count: u8 = 0;
        for (self.floors) |floor| {
            if (floor.room_count > 0) count += 1;
        }
        return count;
    }

    pub fn totalRoomCount(self: *const MansionLayout) u8 {
        var count: u8 = 0;
        for (self.floors) |floor| {
            count += floor.room_count;
        }
        return count;
    }
};

pub const MobSpawnInfo = struct {
    vindicators: u8,
    evokers: u8,
};

pub fn getMobSpawns(room: MansionRoom) MobSpawnInfo {
    return switch (room) {
        .arena => .{ .vindicators = 4, .evokers = 1 },
        .bedroom => .{ .vindicators = 1, .evokers = 0 },
        .library => .{ .vindicators = 0, .evokers = 1 },
        .entrance_hall => .{ .vindicators = 2, .evokers = 0 },
        .kitchen => .{ .vindicators = 1, .evokers = 0 },
        .loot_room => .{ .vindicators = 2, .evokers = 1 },
        .secret_room => .{ .vindicators = 1, .evokers = 1 },
        .staircase, .balcony, .attic => .{ .vindicators = 0, .evokers = 0 },
    };
}

pub const LootItem = struct {
    item: u16,
    count: u8,
};

pub fn getSecretRoomLoot(seed: u64) [4]?LootItem {
    var rng = splitmix64(seed);

    var loot: [4]?LootItem = [_]?LootItem{null} ** 4;

    const possible_items = [_]u16{ 264, 388, 322, 49, 368, 263, 265, 266 };

    for (&loot) |*slot| {
        const roll = rng % 100;
        rng = splitmix64(rng);

        if (roll < 70) {
            const item_idx = rng % possible_items.len;
            rng = splitmix64(rng);

            const count_val = rng % 3 + 1;
            rng = splitmix64(rng);

            slot.* = .{
                .item = possible_items[item_idx],
                .count = @intCast(count_val),
            };
        }
    }

    return loot;
}

pub fn generateLayout(seed: u64) MansionLayout {
    var rng = splitmix64(seed);

    // Floor 1: main floor with entrance, kitchen, library, bedrooms
    var floor1 = MansionFloor.init();
    floor1 = floor1.addRoom(.{ .room = .entrance_hall, .x = 0, .z = 0, .rotation = 0 });

    rng = splitmix64(rng);
    floor1 = floor1.addRoom(.{ .room = .kitchen, .x = 8, .z = 0, .rotation = @intCast(rng % 4) });

    rng = splitmix64(rng);
    floor1 = floor1.addRoom(.{ .room = .library, .x = 0, .z = 8, .rotation = @intCast(rng % 4) });

    rng = splitmix64(rng);
    floor1 = floor1.addRoom(.{ .room = .staircase, .x = 16, .z = 0, .rotation = @intCast(rng % 4) });

    rng = splitmix64(rng);
    const floor1_bedrooms: u8 = @intCast(rng % 2 + 1);
    for (0..floor1_bedrooms) |i| {
        rng = splitmix64(rng);
        floor1 = floor1.addRoom(.{
            .room = .bedroom,
            .x = @intCast(16 + i * 8),
            .z = 8,
            .rotation = @intCast(rng % 4),
        });
    }

    // Floor 2: upper floor with arena, loot room, balcony
    var floor2 = MansionFloor.init();

    rng = splitmix64(rng);
    floor2 = floor2.addRoom(.{ .room = .staircase, .x = 16, .z = 0, .rotation = @intCast(rng % 4) });

    rng = splitmix64(rng);
    floor2 = floor2.addRoom(.{ .room = .arena, .x = 0, .z = 0, .rotation = @intCast(rng % 4) });

    rng = splitmix64(rng);
    floor2 = floor2.addRoom(.{ .room = .loot_room, .x = 8, .z = 0, .rotation = @intCast(rng % 4) });

    rng = splitmix64(rng);
    floor2 = floor2.addRoom(.{ .room = .balcony, .x = 0, .z = 8, .rotation = @intCast(rng % 4) });

    rng = splitmix64(rng);
    const has_bedroom_f2 = (rng % 3) > 0;
    if (has_bedroom_f2) {
        rng = splitmix64(rng);
        floor2 = floor2.addRoom(.{ .room = .bedroom, .x = 16, .z = 8, .rotation = @intCast(rng % 4) });
    }

    // Secret room on floor 2 (seeded probability)
    rng = splitmix64(rng);
    const has_secret = (rng % 4) != 0; // 75% chance
    if (has_secret) {
        rng = splitmix64(rng);
        const secret_x: i8 = @intCast(rng % 24);
        rng = splitmix64(rng);
        const secret_z: i8 = @intCast(rng % 24);
        rng = splitmix64(rng);
        floor2 = floor2.addRoom(.{ .room = .secret_room, .x = secret_x, .z = secret_z, .rotation = @intCast(rng % 4) });
    }

    // Floor 3 (attic): smaller, with attic room and optional secret room
    var floor3 = MansionFloor.init();

    rng = splitmix64(rng);
    floor3 = floor3.addRoom(.{ .room = .attic, .x = 0, .z = 0, .rotation = @intCast(rng % 4) });

    rng = splitmix64(rng);
    floor3 = floor3.addRoom(.{ .room = .loot_room, .x = 8, .z = 0, .rotation = @intCast(rng % 4) });

    rng = splitmix64(rng);
    const has_attic_secret = (rng % 3) == 0; // 33% chance
    if (has_attic_secret) {
        rng = splitmix64(rng);
        const attic_secret_x: i8 = @intCast(rng % 16);
        rng = splitmix64(rng);
        const attic_secret_z: i8 = @intCast(rng % 16);
        rng = splitmix64(rng);
        floor3 = floor3.addRoom(.{ .room = .secret_room, .x = attic_secret_x, .z = attic_secret_z, .rotation = @intCast(rng % 4) });
    }

    return .{
        .floors = .{ floor1, floor2, floor3 },
    };
}

fn splitmix64(state: u64) u64 {
    var s = state +% 0x9e3779b97f4a7c15;
    s = (s ^ (s >> 30)) *% 0xbf58476d1ce4e5b9;
    s = (s ^ (s >> 27)) *% 0x94d049bb133111eb;
    return s ^ (s >> 31);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "layout has 3 floors with rooms" {
    const layout = generateLayout(42);

    // All 3 floors should have at least one room
    try std.testing.expect(layout.floors[0].room_count > 0);
    try std.testing.expect(layout.floors[1].room_count > 0);
    try std.testing.expect(layout.floors[2].room_count > 0);
    try std.testing.expectEqual(@as(u8, 3), layout.floorCount());
}

test "floor 1 connects entrance to staircase" {
    const layout = generateLayout(42);
    const floor1 = layout.floors[0];

    try std.testing.expect(floor1.containsRoom(.entrance_hall));
    try std.testing.expect(floor1.containsRoom(.staircase));
}

test "floor 2 connects staircase to arena" {
    const layout = generateLayout(42);
    const floor2 = layout.floors[1];

    try std.testing.expect(floor2.containsRoom(.staircase));
    try std.testing.expect(floor2.containsRoom(.arena));
}

test "mob spawns per room" {
    const arena_spawns = getMobSpawns(.arena);
    try std.testing.expectEqual(@as(u8, 4), arena_spawns.vindicators);
    try std.testing.expectEqual(@as(u8, 1), arena_spawns.evokers);

    const bedroom_spawns = getMobSpawns(.bedroom);
    try std.testing.expectEqual(@as(u8, 1), bedroom_spawns.vindicators);
    try std.testing.expectEqual(@as(u8, 0), bedroom_spawns.evokers);

    const library_spawns = getMobSpawns(.library);
    try std.testing.expectEqual(@as(u8, 0), library_spawns.vindicators);
    try std.testing.expectEqual(@as(u8, 1), library_spawns.evokers);
}

test "secret rooms exist across multiple seeds" {
    var found_secret = false;
    for (0..20) |i| {
        const layout = generateLayout(i);
        for (layout.floors) |floor| {
            if (floor.containsRoom(.secret_room)) {
                found_secret = true;
                break;
            }
        }
        if (found_secret) break;
    }
    try std.testing.expect(found_secret);
}

test "secret room loot generation" {
    const loot = getSecretRoomLoot(12345);

    var has_item = false;
    for (loot) |maybe_item| {
        if (maybe_item) |item| {
            has_item = true;
            try std.testing.expect(item.count >= 1);
            try std.testing.expect(item.count <= 3);
            try std.testing.expect(item.item > 0);
        }
    }
    try std.testing.expect(has_item);
}

test "different seeds produce different layouts" {
    const layout_a = generateLayout(100);
    const layout_b = generateLayout(999);

    // At least one floor should differ in room count or placement
    var differ = false;
    for (0..3) |i| {
        if (layout_a.floors[i].room_count != layout_b.floors[i].room_count) {
            differ = true;
            break;
        }
    }
    try std.testing.expect(differ);
}

test "default mansion dimensions" {
    const layout = generateLayout(0);
    try std.testing.expectEqual(@as(u8, 32), layout.width);
    try std.testing.expectEqual(@as(u8, 32), layout.depth);
}

test "floor3 contains attic room" {
    const layout = generateLayout(42);
    try std.testing.expect(layout.floors[2].containsRoom(.attic));
}
