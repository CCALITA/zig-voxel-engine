const std = @import("std");

pub const MonumentRoom = enum {
    entrance,
    wing,
    penthouse,
    treasure,
    core,
    sponge_room,
    elder_room,
};

pub const MonumentRoomPlacement = struct {
    room: MonumentRoom,
    x: i8,
    y: i8,
    z: i8,
    rotation: u2,
};

pub const Pillar = struct {
    x: u8,
    z: u8,
};

pub const Position = struct {
    x: f32,
    y: f32,
    z: f32,
};

pub const MonumentLayout = struct {
    rooms: [32]?MonumentRoomPlacement,
    room_count: u8,
    size_x: u8 = 58,
    size_z: u8 = 58,
    pillars: [4]Pillar,

    pub fn init() MonumentLayout {
        return .{
            .rooms = [_]?MonumentRoomPlacement{null} ** 32,
            .room_count = 0,
            .pillars = [_]Pillar{.{ .x = 0, .z = 0 }} ** 4,
        };
    }
};

/// Splitmix64 step used for deterministic pseudo-random generation from a seed.
fn splitmix(seed: *u64) u64 {
    seed.* +%= 0x9e3779b97f4a7c15;
    var z = seed.*;
    z = (z ^ (z >> 30)) *% 0xbf58476d1ce4e5b9;
    z = (z ^ (z >> 27)) *% 0x94d049bb133111eb;
    return z ^ (z >> 31);
}

pub fn getSpongeRoomCount(seed: u64) u8 {
    var s = seed;
    const val = splitmix(&s);
    return @intCast(val % 5); // 0..4
}

pub fn generateLayout(seed: u64) MonumentLayout {
    var layout = MonumentLayout.init();
    var s = seed;

    const fixed_rooms = [_]MonumentRoomPlacement{
        .{ .room = .core, .x = 0, .y = 0, .z = 0, .rotation = 0 },
        .{ .room = .entrance, .x = 0, .y = 0, .z = 29, .rotation = 0 },
        .{ .room = .wing, .x = -20, .y = 0, .z = 0, .rotation = 0 },
        .{ .room = .wing, .x = 20, .y = 0, .z = 0, .rotation = 2 },
        .{ .room = .penthouse, .x = 0, .y = 8, .z = 0, .rotation = 0 },
        .{ .room = .treasure, .x = 0, .y = -4, .z = 0, .rotation = 0 },
        .{ .room = .elder_room, .x = -20, .y = 4, .z = 0, .rotation = 0 },
        .{ .room = .elder_room, .x = 20, .y = 4, .z = 0, .rotation = 2 },
        .{ .room = .elder_room, .x = 0, .y = 12, .z = 0, .rotation = 0 },
    };
    for (fixed_rooms, 0..) |room, i| {
        layout.rooms[i] = room;
    }
    layout.room_count = fixed_rooms.len;

    const sponge_count = getSpongeRoomCount(seed);
    const sponge_offsets = [4][2]i8{
        .{ -10, -10 },
        .{ 10, -10 },
        .{ -10, 10 },
        .{ 10, 10 },
    };
    for (0..sponge_count) |i| {
        const rotation: u2 = @intCast(splitmix(&s) % 4);
        layout.rooms[fixed_rooms.len + i] = .{
            .room = .sponge_room,
            .x = sponge_offsets[i][0],
            .y = 0,
            .z = sponge_offsets[i][1],
            .rotation = rotation,
        };
        layout.room_count += 1;
    }

    layout.pillars = .{
        .{ .x = 14, .z = 14 },
        .{ .x = 44, .z = 14 },
        .{ .x = 14, .z = 44 },
        .{ .x = 44, .z = 44 },
    };

    return layout;
}

/// Returns three elder guardian positions, one per wing and one for the penthouse.
pub fn getElderGuardianPositions() [3]Position {
    return .{
        .{ .x = 9.0, .y = 45.0, .z = 29.0 },  // left wing
        .{ .x = 49.0, .y = 45.0, .z = 29.0 }, // right wing
        .{ .x = 29.0, .y = 53.0, .z = 29.0 }, // penthouse
    };
}

/// Returns up to 16 potential guardian spawn positions derived from the layout.
pub fn getGuardianSpawnPositions(layout: MonumentLayout) [16]?Position {
    var positions = [_]?Position{null} ** 16;
    var count: u8 = 0;

    const half_x: f32 = @floatFromInt(layout.size_x >> 1);
    const half_z: f32 = @floatFromInt(layout.size_z >> 1);

    for (layout.rooms) |maybe_room| {
        if (count >= 16) break;
        const room = maybe_room orelse continue;

        positions[count] = .{
            .x = half_x + @as(f32, @floatFromInt(room.x)),
            .y = 40.0 + @as(f32, @floatFromInt(room.y)),
            .z = half_z + @as(f32, @floatFromInt(room.z)),
        };
        count += 1;
    }

    return positions;
}

test "layout has valid size" {
    const layout = generateLayout(12345);
    try std.testing.expect(layout.size_x == 58);
    try std.testing.expect(layout.size_z == 58);
    try std.testing.expect(layout.room_count >= 6);
    try std.testing.expect(layout.room_count <= 32);
}

test "three elder guardian positions" {
    const elders = getElderGuardianPositions();
    try std.testing.expect(elders.len == 3);
    // Each position should have positive coordinates
    for (elders) |pos| {
        try std.testing.expect(pos.x >= 0.0);
        try std.testing.expect(pos.y >= 0.0);
        try std.testing.expect(pos.z >= 0.0);
    }
}

test "guardian spawn positions from layout" {
    const layout = generateLayout(99999);
    const spawns = getGuardianSpawnPositions(layout);
    // At least as many non-null spawns as rooms
    var non_null: u8 = 0;
    for (spawns) |s| {
        if (s != null) non_null += 1;
    }
    try std.testing.expect(non_null == layout.room_count);
}

test "sponge room count is 0 to 4" {
    // Check a range of seeds to exercise the distribution
    var i: u64 = 0;
    while (i < 100) : (i += 1) {
        const count = getSpongeRoomCount(i);
        try std.testing.expect(count <= 4);
    }
}
