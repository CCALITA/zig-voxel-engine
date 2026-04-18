const std = @import("std");

pub const DeepDarkFeatures = struct {
    min_y: i32 = -64,
    max_y: i32 = 0,
    sculk_density: f32 = 0.3,
    ancient_city_chance: f32 = 0.01,
    darkness_ambient: bool = true,
};

pub const SculkPatch = struct {
    center_x: i32,
    center_y: i32,
    center_z: i32,
    radius: u8,
    has_shrieker: bool,
    has_catalyst: bool,
};

pub const AncientCityRoom = enum {
    corridor,
    entrance,
    grand_hall,
    portal_room,
    redstone_lab,
    ice_box,
};

pub const AncientCityLayout = struct {
    pub const RoomEntry = struct {
        room: AncientCityRoom,
        x: i8,
        z: i8,
    };

    rooms: [16]?RoomEntry = [_]?RoomEntry{null} ** 16,
    room_count: u8 = 0,
};

pub fn generateSculkPatches(seed: u64, chunk_x: i32, chunk_z: i32) [8]?SculkPatch {
    var patches: [8]?SculkPatch = [_]?SculkPatch{null} ** 8;
    const features = DeepDarkFeatures{};

    var rng = std.Random.DefaultPrng.init(seed ^ @as(u64, @bitCast(@as(i64, chunk_x) * 341873128712 + @as(i64, chunk_z) * 132897987541)));
    var random = rng.random();

    const y_range: u32 = @intCast(features.max_y - features.min_y);
    for (0..8) |i| {
        if (random.float(f32) > features.sculk_density) continue;

        const base_x = chunk_x * 16 + random.intRangeAtMost(i32, 0, 15);
        const base_z = chunk_z * 16 + random.intRangeAtMost(i32, 0, 15);
        const base_y = features.min_y + @as(i32, @intCast(random.uintAtMost(u32, y_range)));
        const radius = random.intRangeAtMost(u8, 2, 6);
        const has_shrieker = random.float(f32) < 0.25;
        const has_catalyst = random.float(f32) < 0.4;

        patches[i] = SculkPatch{
            .center_x = base_x,
            .center_y = base_y,
            .center_z = base_z,
            .radius = radius,
            .has_shrieker = has_shrieker,
            .has_catalyst = has_catalyst,
        };
    }

    return patches;
}

pub fn generateCityLayout(seed: u64) AncientCityLayout {
    var layout = AncientCityLayout{};

    var rng = std.Random.DefaultPrng.init(seed);
    var random = rng.random();

    // Always start with an entrance
    layout.rooms[0] = .{ .room = .entrance, .x = 0, .z = 0 };
    layout.room_count = 1;

    const room_types = [_]AncientCityRoom{ .corridor, .grand_hall, .portal_room, .redstone_lab, .ice_box };
    const directions = [_][2]i8{ .{ 1, 0 }, .{ -1, 0 }, .{ 0, 1 }, .{ 0, -1 } };

    var attempts: u8 = 0;
    while (layout.room_count < 16 and attempts < 60) : (attempts += 1) {
        const parent_idx = random.uintAtMost(u8, layout.room_count - 1);
        const parent = layout.rooms[parent_idx].?;
        const dir = directions[random.uintAtMost(usize, directions.len - 1)];
        const new_x = parent.x +| dir[0];
        const new_z = parent.z +| dir[1];

        if (hasRoomAt(&layout, new_x, new_z)) continue;

        const room_type = room_types[random.uintAtMost(usize, room_types.len - 1)];
        layout.rooms[layout.room_count] = .{ .room = room_type, .x = new_x, .z = new_z };
        layout.room_count += 1;
    }

    return layout;
}

fn hasRoomAt(layout: *const AncientCityLayout, x: i8, z: i8) bool {
    for (layout.rooms[0..layout.room_count]) |maybe_room| {
        if (maybe_room) |room| {
            if (room.x == x and room.z == z) return true;
        }
    }
    return false;
}

pub fn getWardenSpawnConditions() struct { min_sculk_shriekers: u8, activation_count: u8 } {
    return .{ .min_sculk_shriekers = 3, .activation_count = 3 };
}

test "sculk patch generation produces patches within bounds" {
    const patches = generateSculkPatches(12345, 0, 0);
    const features = DeepDarkFeatures{};
    var found_any = false;

    for (patches) |maybe_patch| {
        if (maybe_patch) |patch| {
            found_any = true;
            try std.testing.expect(patch.center_y >= features.min_y);
            try std.testing.expect(patch.center_y <= features.max_y);
            try std.testing.expect(patch.center_x >= 0);
            try std.testing.expect(patch.center_x <= 15);
            try std.testing.expect(patch.center_z >= 0);
            try std.testing.expect(patch.center_z <= 15);
            try std.testing.expect(patch.radius >= 2);
            try std.testing.expect(patch.radius <= 6);
        }
    }
    try std.testing.expect(found_any);
}

test "sculk patch generation is deterministic" {
    const patches_a = generateSculkPatches(42, 3, -5);
    const patches_b = generateSculkPatches(42, 3, -5);

    for (patches_a, patches_b) |a, b| {
        if (a) |pa| {
            const pb = b.?;
            try std.testing.expectEqual(pa.center_x, pb.center_x);
            try std.testing.expectEqual(pa.center_y, pb.center_y);
            try std.testing.expectEqual(pa.center_z, pb.center_z);
            try std.testing.expectEqual(pa.radius, pb.radius);
            try std.testing.expectEqual(pa.has_shrieker, pb.has_shrieker);
            try std.testing.expectEqual(pa.has_catalyst, pb.has_catalyst);
        } else {
            try std.testing.expectEqual(b, null);
        }
    }
}

test "sculk patch generation varies by seed" {
    const patches_a = generateSculkPatches(100, 0, 0);
    const patches_b = generateSculkPatches(999, 0, 0);

    var differ = false;
    for (patches_a, patches_b) |a, b| {
        const a_null = (a == null);
        const b_null = (b == null);
        if (a_null != b_null) {
            differ = true;
            break;
        }
        if (a) |pa| {
            const pb = b.?;
            if (pa.center_x != pb.center_x or pa.center_y != pb.center_y or pa.center_z != pb.center_z) {
                differ = true;
                break;
            }
        }
    }
    try std.testing.expect(differ);
}

test "city layout always starts with entrance" {
    const layout = generateCityLayout(42);
    try std.testing.expect(layout.room_count >= 1);
    const first = layout.rooms[0].?;
    try std.testing.expectEqual(first.room, .entrance);
    try std.testing.expectEqual(first.x, 0);
    try std.testing.expectEqual(first.z, 0);
}

test "city layout produces multiple rooms" {
    const layout = generateCityLayout(12345);
    try std.testing.expect(layout.room_count > 1);
    try std.testing.expect(layout.room_count <= 16);

    // Verify room_count matches non-null entries
    var count: u8 = 0;
    for (layout.rooms) |maybe_room| {
        if (maybe_room != null) count += 1;
    }
    try std.testing.expectEqual(layout.room_count, count);
}

test "city layout has no overlapping positions" {
    const layout = generateCityLayout(42);

    for (0..layout.room_count) |i| {
        const room_i = layout.rooms[i].?;
        for ((i + 1)..layout.room_count) |j| {
            const room_j = layout.rooms[j].?;
            const same_pos = (room_i.x == room_j.x and room_i.z == room_j.z);
            try std.testing.expect(!same_pos);
        }
    }
}

test "city layout is deterministic" {
    const layout_a = generateCityLayout(77);
    const layout_b = generateCityLayout(77);

    try std.testing.expectEqual(layout_a.room_count, layout_b.room_count);
    for (layout_a.rooms, layout_b.rooms) |a, b| {
        if (a) |ra| {
            const rb = b.?;
            try std.testing.expectEqual(ra.room, rb.room);
            try std.testing.expectEqual(ra.x, rb.x);
            try std.testing.expectEqual(ra.z, rb.z);
        } else {
            try std.testing.expectEqual(b, null);
        }
    }
}

test "warden spawn conditions returns correct values" {
    const conditions = getWardenSpawnConditions();
    try std.testing.expectEqual(conditions.min_sculk_shriekers, 3);
    try std.testing.expectEqual(conditions.activation_count, 3);
}
