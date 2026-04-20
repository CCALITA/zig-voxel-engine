const std = @import("std");

pub const StrongholdRoom = enum {
    portal_room,
    library,
    corridor,
    staircase,
    prison,
    fountain,
    storage,
};

pub const RoomPlacement = struct {
    room: StrongholdRoom,
    x: i8,
    y: i8,
    z: i8,
    rotation: u2,
};

pub const StrongholdLayout = struct {
    rooms: [32]?RoomPlacement,
    room_count: u8,
    portal_room_index: u8,
    has_library: bool,
};

pub const Position = struct {
    x: i32,
    z: i32,
};

pub const PortalFrame = struct {
    dx: i8,
    dz: i8,
    facing: u2,
};

pub const LootEntry = struct {
    item: u16,
    count: u8,
};

pub fn generateLayout(seed: u64) StrongholdLayout {
    var layout = StrongholdLayout{
        .rooms = [_]?RoomPlacement{null} ** 32,
        .room_count = 0,
        .portal_room_index = 0,
        .has_library = true,
    };

    var rng = seed;

    layout.rooms[0] = RoomPlacement{
        .room = .portal_room,
        .x = 0,
        .y = 0,
        .z = 0,
        .rotation = @truncate(rng & 0x3),
    };
    layout.room_count = 1;
    rng = xorshift(rng);

    layout.rooms[1] = RoomPlacement{
        .room = .library,
        .x = @intCast(@as(u7, @truncate(rng >> 8)) % 12),
        .y = 0,
        .z = @intCast(@as(u7, @truncate(rng >> 16)) % 12),
        .rotation = @truncate((rng >> 24) & 0x3),
    };
    layout.room_count = 2;
    rng = xorshift(rng);

    const room_types = [_]StrongholdRoom{ .corridor, .staircase, .prison, .fountain, .storage, .library, .corridor, .staircase };
    var i: u8 = 2;
    while (i < 20) : (i += 1) {
        rng = xorshift(rng);
        layout.rooms[i] = RoomPlacement{
            .room = room_types[@as(usize, @truncate(rng & 0x7))],
            .x = @bitCast(@as(u8, @truncate(rng >> 8)) % 24),
            .y = @as(i8, @intCast(i % 3)) - 1,
            .z = @bitCast(@as(u8, @truncate(rng >> 16)) % 24),
            .rotation = @truncate((rng >> 24) & 0x3),
        };
        layout.room_count += 1;
    }

    return layout;
}

pub fn getStrongholdPositions(world_seed: u64) [3]Position {
    const ring_min = [_]i32{ 1408, 4480, 7552 };
    const ring_max = [_]i32{ 2688, 5760, 8832 };

    var positions: [3]Position = undefined;
    var rng = world_seed;

    for (0..3) |i| {
        rng = xorshift(rng);
        const range: u32 = @intCast(ring_max[i] - ring_min[i]);
        const dist: i32 = ring_min[i] + @as(i32, @intCast(@as(u32, @truncate(rng)) % (range + 1)));

        rng = xorshift(rng);
        const angle_deg: u32 = @as(u32, @truncate(rng)) % 360;
        const rad: f64 = @as(f64, @floatFromInt(angle_deg)) * std.math.pi / 180.0;
        const dist_f: f64 = @floatFromInt(dist);

        positions[i] = Position{
            .x = @intFromFloat(dist_f * @cos(rad)),
            .z = @intFromFloat(dist_f * @sin(rad)),
        };
    }

    return positions;
}

pub fn getPortalFramePositions() [12]PortalFrame {
    // 12 frames in a 5x5 ring, 3 per side, facing inward
    // facing: 0=south(+z), 1=west(-x), 2=north(-z), 3=east(+x)
    return [12]PortalFrame{
        .{ .dx = -1, .dz = -2, .facing = 0 },
        .{ .dx = 0, .dz = -2, .facing = 0 },
        .{ .dx = 1, .dz = -2, .facing = 0 },
        .{ .dx = -1, .dz = 2, .facing = 2 },
        .{ .dx = 0, .dz = 2, .facing = 2 },
        .{ .dx = 1, .dz = 2, .facing = 2 },
        .{ .dx = 2, .dz = -1, .facing = 1 },
        .{ .dx = 2, .dz = 0, .facing = 1 },
        .{ .dx = 2, .dz = 1, .facing = 1 },
        .{ .dx = -2, .dz = -1, .facing = 3 },
        .{ .dx = -2, .dz = 0, .facing = 3 },
        .{ .dx = -2, .dz = 1, .facing = 3 },
    };
}

pub fn getLibraryLoot(seed: u64, two_floors: bool) [8]?LootEntry {
    var loot = [_]?LootEntry{null} ** 8;
    var rng = seed;

    const base_items = [_]u16{ 340, 339, 288, 287, 346, 345 };
    const bonus_items = [_]u16{ 322, 388, 116 };
    const item_count: u8 = if (two_floors) 8 else 5;

    var i: u8 = 0;
    while (i < item_count) : (i += 1) {
        rng = xorshift(rng);
        const item_idx: usize = @truncate(rng);
        rng = xorshift(rng);
        if (i < 5) {
            loot[i] = LootEntry{
                .item = base_items[item_idx % base_items.len],
                .count = (@as(u8, @truncate(rng >> 4)) % 3) + 1,
            };
        } else {
            loot[i] = LootEntry{
                .item = bonus_items[item_idx % bonus_items.len],
                .count = (@as(u8, @truncate(rng >> 4)) % 2) + 1,
            };
        }
    }

    return loot;
}

fn xorshift(state: u64) u64 {
    var s = state;
    s ^= s << 13;
    s ^= s >> 7;
    s ^= s << 17;
    return s;
}

test "generateLayout always has portal room" {
    const layout = generateLayout(12345);
    var has_portal = false;
    for (layout.rooms) |maybe_room| {
        if (maybe_room) |room| {
            if (room.room == .portal_room) {
                has_portal = true;
                break;
            }
        }
    }
    try std.testing.expect(has_portal);
    try std.testing.expectEqual(StrongholdRoom.portal_room, layout.rooms[layout.portal_room_index].?.room);
}

test "generateLayout always has library" {
    const seeds = [_]u64{ 1, 42, 9999, 0xDEADBEEF, 0 };
    for (seeds) |seed| {
        const layout = generateLayout(seed);
        try std.testing.expect(layout.has_library);
    }
}

test "getStrongholdPositions returns 3 positions at correct distances" {
    const positions = getStrongholdPositions(42);
    const ring_min = [_]i32{ 1408, 4480, 7552 };
    const ring_max = [_]i32{ 2688, 5760, 8832 };

    for (positions, 0..) |pos, i| {
        const dx: f64 = @floatFromInt(pos.x);
        const dz: f64 = @floatFromInt(pos.z);
        const dist: f64 = @sqrt(dx * dx + dz * dz);
        const min_f: f64 = @floatFromInt(ring_min[i]);
        const max_f: f64 = @floatFromInt(ring_max[i]);
        try std.testing.expect(dist >= min_f - 1.0);
        try std.testing.expect(dist <= max_f + 1.0);
    }
}

test "getPortalFramePositions returns 12 frames" {
    const frames = getPortalFramePositions();
    try std.testing.expectEqual(@as(usize, 12), frames.len);

    var facing_counts = [_]u8{ 0, 0, 0, 0 };
    for (frames) |frame| {
        facing_counts[frame.facing] += 1;
    }
    for (facing_counts) |count| {
        try std.testing.expectEqual(@as(u8, 3), count);
    }
}

test "getLibraryLoot produces items" {
    const loot_single = getLibraryLoot(777, false);
    var count_single: u8 = 0;
    for (loot_single) |maybe_item| {
        if (maybe_item != null) count_single += 1;
    }
    try std.testing.expectEqual(@as(u8, 5), count_single);

    const loot_double = getLibraryLoot(777, true);
    var count_double: u8 = 0;
    for (loot_double) |maybe_item| {
        if (maybe_item != null) count_double += 1;
    }
    try std.testing.expectEqual(@as(u8, 8), count_double);
}
