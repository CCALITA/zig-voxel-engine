const std = @import("std");

// ---------------------------------------------------------------------------
// Data types
// ---------------------------------------------------------------------------

pub const ItemEntityData = struct {
    x: f32,
    y: f32,
    z: f32,
    item_id: u16,
    time: f32,
};

pub const ItemVertex = struct {
    x: f32,
    y: f32,
    z: f32,
    r: f32,
    g: f32,
    b: f32,
};

/// Vertices per face (two triangles).
const verts_per_face: u32 = 6;
/// Number of faces on a cube.
const faces_per_cube: u32 = 6;
/// Total vertices for one cube.
pub const verts_per_cube: u32 = verts_per_face * faces_per_cube; // 36

// ---------------------------------------------------------------------------
// Animation helpers
// ---------------------------------------------------------------------------

/// Rotation speed in radians per second (one full turn every ~8 seconds).
const rotation_speed: f32 = std.math.pi * 0.25;

/// Return the Y-axis rotation angle (radians) for the given elapsed time.
pub fn getRotationAngle(time: f32) f32 {
    return @mod(time * rotation_speed, 2.0 * std.math.pi);
}

/// Vertical bob amplitude in world units.
const bob_amplitude: f32 = 0.1;
/// Bob frequency in radians per second.
const bob_frequency: f32 = 2.0;

/// Return the vertical offset for the bobbing animation at the given time.
/// Produces a sine wave oscillating between -0.1 and +0.1.
pub fn getBobOffset(time: f32) f32 {
    return bob_amplitude * @sin(time * bob_frequency);
}

// ---------------------------------------------------------------------------
// Scale
// ---------------------------------------------------------------------------

/// Dropped items render as small cubes at 30 % of a full block.
pub fn getItemScale() f32 {
    return 0.3;
}

// ---------------------------------------------------------------------------
// Color mapping
// ---------------------------------------------------------------------------

/// Maximum block ID for which we use the block color palette.
const max_block_id: u16 = 119;
/// Tool item IDs start at 300.
const tool_id_start: u16 = 300;

/// Map an item ID to an RGB color.
///
/// * Block IDs (0 -- 119): return a representative block color.
/// * Tool IDs (>= 300): return gray (tool metal).
/// * Everything else (food, misc): return a neutral brown.
pub fn getItemColor(item_id: u16) [3]f32 {
    if (item_id <= max_block_id) {
        return getBlockItemColor(item_id);
    }
    if (item_id >= tool_id_start) {
        return .{ 0.6, 0.6, 0.6 }; // gray for tools
    }
    return .{ 0.55, 0.40, 0.25 }; // brown for food / misc
}

/// Simplified block color palette (matches terrain.frag tones).
fn getBlockItemColor(id: u16) [3]f32 {
    return switch (id) {
        1 => .{ 0.50, 0.50, 0.50 }, // stone
        2 => .{ 0.55, 0.35, 0.20 }, // dirt
        3 => .{ 0.30, 0.65, 0.15 }, // grass
        4 => .{ 0.40, 0.40, 0.40 }, // cobblestone
        5 => .{ 0.70, 0.55, 0.30 }, // oak planks
        6 => .{ 0.85, 0.80, 0.55 }, // sand
        7 => .{ 0.55, 0.50, 0.45 }, // gravel
        8 => .{ 0.40, 0.30, 0.15 }, // oak log
        9 => .{ 0.20, 0.50, 0.10 }, // oak leaves
        10 => .{ 0.20, 0.35, 0.80 }, // water
        11 => .{ 0.25, 0.25, 0.25 }, // bedrock
        12 => .{ 0.35, 0.35, 0.35 }, // coal ore
        13 => .{ 0.55, 0.50, 0.45 }, // iron ore
        14 => .{ 0.65, 0.60, 0.30 }, // gold ore
        15 => .{ 0.40, 0.65, 0.65 }, // diamond ore
        16 => .{ 0.55, 0.25, 0.20 }, // redstone ore
        17 => .{ 0.75, 0.85, 0.90 }, // glass
        18 => .{ 0.60, 0.30, 0.25 }, // brick
        19 => .{ 0.10, 0.05, 0.15 }, // obsidian
        20 => .{ 0.75, 0.30, 0.25 }, // tnt
        else => .{ 0.50, 0.50, 0.50 }, // default gray
    };
}

// ---------------------------------------------------------------------------
// Cube geometry
// ---------------------------------------------------------------------------

/// Generate the 36 vertices of a coloured cube at an arbitrary position, with
/// uniform `scale` and Y-axis `rotation` (radians).
///
/// The cube is axis-aligned before rotation, centred at (`cx`, `cy`, `cz`).
/// Each face receives a slightly different shade for visual depth.
pub fn generateCubeVertices(
    buf: []ItemVertex,
    cx: f32,
    cy: f32,
    cz: f32,
    scale: f32,
    rotation: f32,
    color: [3]f32,
) u32 {
    if (buf.len < verts_per_cube) return 0;

    const half = scale * 0.5;
    const cos_r = @cos(rotation);
    const sin_r = @sin(rotation);

    // Eight local corners of a unit cube centred at origin.
    const local = [8][3]f32{
        .{ -half, -half, -half },
        .{ half, -half, -half },
        .{ half, half, -half },
        .{ -half, half, -half },
        .{ -half, -half, half },
        .{ half, -half, half },
        .{ half, half, half },
        .{ -half, half, half },
    };

    // Rotate around Y and translate.
    var corners: [8][3]f32 = undefined;
    for (local, 0..) |lc, i| {
        const rx = lc[0] * cos_r - lc[2] * sin_r;
        const rz = lc[0] * sin_r + lc[2] * cos_r;
        corners[i] = .{ cx + rx, cy + lc[1], cz + rz };
    }

    // Six faces (CCW winding when viewed from outside).
    const face_indices = [6][6]u8{
        .{ 0, 1, 2, 2, 3, 0 }, // front  (-Z)
        .{ 5, 4, 7, 7, 6, 5 }, // back   (+Z)
        .{ 4, 0, 3, 3, 7, 4 }, // left   (-X)
        .{ 1, 5, 6, 6, 2, 1 }, // right  (+X)
        .{ 3, 2, 6, 6, 7, 3 }, // top    (+Y)
        .{ 4, 5, 1, 1, 0, 4 }, // bottom (-Y)
    };

    const face_shade = [6]f32{ 0.90, 0.85, 0.80, 0.80, 1.00, 0.70 };

    var idx: u32 = 0;
    for (face_indices, 0..) |face, fi| {
        const shade = face_shade[fi];
        for (face) |ci| {
            const c = corners[ci];
            buf[idx] = .{
                .x = c[0],
                .y = c[1],
                .z = c[2],
                .r = color[0] * shade,
                .g = color[1] * shade,
                .b = color[2] * shade,
            };
            idx += 1;
        }
    }
    return idx;
}

/// Convenience wrapper: generate cube vertices for a dropped item entity,
/// applying spin, bob, scale, and colour automatically.
pub fn generateItemEntityVertices(
    buf: []ItemVertex,
    entity: ItemEntityData,
) u32 {
    const scale = getItemScale();
    const rotation = getRotationAngle(entity.time);
    const bob = getBobOffset(entity.time);
    const color = getItemColor(entity.item_id);
    return generateCubeVertices(
        buf,
        entity.x,
        entity.y + bob,
        entity.z,
        scale,
        rotation,
        color,
    );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "getRotationAngle wraps within 0..2pi" {
    // At time 0, angle should be 0.
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), getRotationAngle(0.0), 0.001);

    // After a very long time the angle should still be in [0, 2pi).
    const angle = getRotationAngle(10000.0);
    try std.testing.expect(angle >= 0.0);
    try std.testing.expect(angle < 2.0 * std.math.pi);
}

test "getBobOffset stays within +-0.1" {
    // Sample many time values.
    var t: f32 = 0.0;
    while (t < 20.0) : (t += 0.1) {
        const offset = getBobOffset(t);
        try std.testing.expect(offset >= -0.101 and offset <= 0.101);
    }
    // At time 0 the offset should be ~0.
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), getBobOffset(0.0), 0.001);
}

test "getItemScale returns 0.3" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.3), getItemScale(), 0.001);
}

test "getItemColor returns gray for tools" {
    const color = getItemColor(300); // WOOD_PICKAXE
    try std.testing.expectApproxEqAbs(@as(f32, 0.6), color[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.6), color[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.6), color[2], 0.001);

    // Another tool
    const color2 = getItemColor(319); // DIAMOND_SWORD
    try std.testing.expectApproxEqAbs(@as(f32, 0.6), color2[0], 0.001);
}

test "getItemColor returns block colours for block IDs" {
    // Stone (id 1) should be gray.
    const stone = getItemColor(1);
    try std.testing.expectApproxEqAbs(@as(f32, 0.50), stone[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.50), stone[1], 0.001);

    // Grass (id 3) should be green.
    const grass = getItemColor(3);
    try std.testing.expect(grass[1] > grass[0]); // green > red
}

test "getItemColor returns brown for food / misc IDs" {
    // ID 200 is in the food/misc range.
    const color = getItemColor(200);
    try std.testing.expectApproxEqAbs(@as(f32, 0.55), color[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.40), color[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.25), color[2], 0.001);
}

test "generateCubeVertices produces 36 vertices" {
    var buf: [36]ItemVertex = undefined;
    const count = generateCubeVertices(&buf, 0, 0, 0, 1.0, 0.0, .{ 1.0, 0.5, 0.2 });
    try std.testing.expectEqual(@as(u32, 36), count);
}

test "generateCubeVertices returns 0 when buffer too small" {
    var buf: [10]ItemVertex = undefined;
    const count = generateCubeVertices(&buf, 0, 0, 0, 1.0, 0.0, .{ 1.0, 1.0, 1.0 });
    try std.testing.expectEqual(@as(u32, 0), count);
}

test "generateCubeVertices positions offset by entity position" {
    var buf_origin: [36]ItemVertex = undefined;
    var buf_offset: [36]ItemVertex = undefined;

    _ = generateCubeVertices(&buf_origin, 0, 0, 0, 1.0, 0.0, .{ 1.0, 1.0, 1.0 });
    _ = generateCubeVertices(&buf_offset, 5, 10, 15, 1.0, 0.0, .{ 1.0, 1.0, 1.0 });

    for (buf_origin[0..36], buf_offset[0..36]) |v0, v1| {
        try std.testing.expectApproxEqAbs(v0.x + 5.0, v1.x, 0.001);
        try std.testing.expectApproxEqAbs(v0.y + 10.0, v1.y, 0.001);
        try std.testing.expectApproxEqAbs(v0.z + 15.0, v1.z, 0.001);
    }
}

test "generateCubeVertices face shading varies" {
    var buf: [36]ItemVertex = undefined;
    _ = generateCubeVertices(&buf, 0, 0, 0, 1.0, 0.0, .{ 1.0, 1.0, 1.0 });

    // The top face (vertices 24..30) should be brighter than the bottom (30..36).
    const top_r = buf[24].r;
    const bot_r = buf[30].r;
    try std.testing.expect(top_r > bot_r);
}

test "generateItemEntityVertices integrates all transforms" {
    var buf: [36]ItemVertex = undefined;
    const entity = ItemEntityData{
        .x = 10.0,
        .y = 20.0,
        .z = 30.0,
        .item_id = 3, // grass
        .time = 1.0,
    };
    const count = generateItemEntityVertices(&buf, entity);
    try std.testing.expectEqual(@as(u32, 36), count);

    // Verify that vertices are roughly centred on the entity position
    // (accounting for scale 0.3 and small bob offset).
    var avg_x: f32 = 0;
    var avg_y: f32 = 0;
    var avg_z: f32 = 0;
    for (buf[0..count]) |v| {
        avg_x += v.x;
        avg_y += v.y;
        avg_z += v.z;
    }
    const n: f32 = @floatFromInt(count);
    avg_x /= n;
    avg_y /= n;
    avg_z /= n;

    try std.testing.expectApproxEqAbs(@as(f32, 10.0), avg_x, 0.2);
    try std.testing.expectApproxEqAbs(@as(f32, 30.0), avg_z, 0.2);
    // Y should be close to 20 + bob offset
    const expected_y = 20.0 + getBobOffset(1.0);
    try std.testing.expectApproxEqAbs(expected_y, avg_y, 0.2);
}
