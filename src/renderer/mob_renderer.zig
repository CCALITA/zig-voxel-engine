const std = @import("std");

pub const ModelVertex = struct {
    x: f32,
    y: f32,
    z: f32,
    r: f32,
    g: f32,
    b: f32,
};

pub const BodyPart = struct {
    offset_x: f32,
    offset_y: f32,
    offset_z: f32,
    width: f32,
    height: f32,
    depth: f32,
    r: f32,
    g: f32,
    b: f32,
};

/// Vertices per face (two triangles).
const verts_per_face: u32 = 6;
/// Faces per box.
const faces_per_box: u32 = 6;
/// Total vertices per body-part box.
pub const verts_per_part: u32 = verts_per_face * faces_per_box; // 36

// -------------------------------------------------------------------------
// Body-part definitions per entity type
// -------------------------------------------------------------------------

// Entity type IDs matching the spec.
pub const ZOMBIE: u8 = 0;
pub const SKELETON: u8 = 1;
pub const CREEPER: u8 = 2;
pub const PIG: u8 = 3;
pub const COW: u8 = 4;
pub const CHICKEN: u8 = 5;
pub const SHEEP: u8 = 6;

// -- Humanoid (zombie / skeleton) -----------------------------------------

const humanoid_parts = [_]BodyPart{
    // head
    .{ .offset_x = 0.0, .offset_y = 1.5, .offset_z = 0.0, .width = 0.5, .height = 0.5, .depth = 0.5, .r = 0, .g = 0, .b = 0 },
    // torso
    .{ .offset_x = 0.0, .offset_y = 0.75, .offset_z = 0.0, .width = 0.5, .height = 0.75, .depth = 0.25, .r = 0, .g = 0, .b = 0 },
    // left arm
    .{ .offset_x = -0.375, .offset_y = 0.75, .offset_z = 0.0, .width = 0.25, .height = 0.75, .depth = 0.25, .r = 0, .g = 0, .b = 0 },
    // right arm
    .{ .offset_x = 0.375, .offset_y = 0.75, .offset_z = 0.0, .width = 0.25, .height = 0.75, .depth = 0.25, .r = 0, .g = 0, .b = 0 },
    // left leg
    .{ .offset_x = -0.125, .offset_y = 0.0, .offset_z = 0.0, .width = 0.25, .height = 0.75, .depth = 0.25, .r = 0, .g = 0, .b = 0 },
    // right leg
    .{ .offset_x = 0.125, .offset_y = 0.0, .offset_z = 0.0, .width = 0.25, .height = 0.75, .depth = 0.25, .r = 0, .g = 0, .b = 0 },
};

fn colorHumanoid(comptime r: f32, comptime g: f32, comptime b: f32) [humanoid_parts.len]BodyPart {
    var parts: [humanoid_parts.len]BodyPart = humanoid_parts;
    for (&parts) |*p| {
        p.r = r;
        p.g = g;
        p.b = b;
    }
    return parts;
}

const zombie_parts = colorHumanoid(0.0, 0.6, 0.0);
const skeleton_parts = colorHumanoid(0.9, 0.9, 0.9);

// -- Creeper --------------------------------------------------------------

const creeper_parts = [_]BodyPart{
    // head
    .{ .offset_x = 0.0, .offset_y = 1.25, .offset_z = 0.0, .width = 0.5, .height = 0.5, .depth = 0.5, .r = 0.0, .g = 0.7, .b = 0.0 },
    // torso
    .{ .offset_x = 0.0, .offset_y = 0.5, .offset_z = 0.0, .width = 0.5, .height = 0.75, .depth = 0.25, .r = 0.0, .g = 0.7, .b = 0.0 },
    // front-left leg
    .{ .offset_x = -0.125, .offset_y = 0.0, .offset_z = -0.125, .width = 0.25, .height = 0.375, .depth = 0.25, .r = 0.0, .g = 0.6, .b = 0.0 },
    // front-right leg
    .{ .offset_x = 0.125, .offset_y = 0.0, .offset_z = -0.125, .width = 0.25, .height = 0.375, .depth = 0.25, .r = 0.0, .g = 0.6, .b = 0.0 },
    // back-left leg
    .{ .offset_x = -0.125, .offset_y = 0.0, .offset_z = 0.125, .width = 0.25, .height = 0.375, .depth = 0.25, .r = 0.0, .g = 0.6, .b = 0.0 },
    // back-right leg
    .{ .offset_x = 0.125, .offset_y = 0.0, .offset_z = 0.125, .width = 0.25, .height = 0.375, .depth = 0.25, .r = 0.0, .g = 0.6, .b = 0.0 },
};

// -- Pig ------------------------------------------------------------------

const pig_parts = [_]BodyPart{
    // head
    .{ .offset_x = 0.0, .offset_y = 0.625, .offset_z = -0.375, .width = 0.5, .height = 0.5, .depth = 0.5, .r = 0.9, .g = 0.6, .b = 0.6 },
    // body
    .{ .offset_x = 0.0, .offset_y = 0.5, .offset_z = 0.0, .width = 0.75, .height = 0.5, .depth = 0.5, .r = 0.9, .g = 0.6, .b = 0.6 },
    // front-left leg
    .{ .offset_x = -0.25, .offset_y = 0.0, .offset_z = -0.125, .width = 0.25, .height = 0.25, .depth = 0.25, .r = 0.9, .g = 0.6, .b = 0.6 },
    // front-right leg
    .{ .offset_x = 0.25, .offset_y = 0.0, .offset_z = -0.125, .width = 0.25, .height = 0.25, .depth = 0.25, .r = 0.9, .g = 0.6, .b = 0.6 },
    // back-left leg
    .{ .offset_x = -0.25, .offset_y = 0.0, .offset_z = 0.125, .width = 0.25, .height = 0.25, .depth = 0.25, .r = 0.9, .g = 0.6, .b = 0.6 },
    // back-right leg
    .{ .offset_x = 0.25, .offset_y = 0.0, .offset_z = 0.125, .width = 0.25, .height = 0.25, .depth = 0.25, .r = 0.9, .g = 0.6, .b = 0.6 },
};

// -- Cow ------------------------------------------------------------------

const cow_parts = [_]BodyPart{
    // head
    .{ .offset_x = 0.0, .offset_y = 0.875, .offset_z = -0.5, .width = 0.5, .height = 0.5, .depth = 0.5, .r = 0.4, .g = 0.25, .b = 0.1 },
    // body
    .{ .offset_x = 0.0, .offset_y = 0.65, .offset_z = 0.0, .width = 0.9, .height = 0.6, .depth = 0.6, .r = 0.9, .g = 0.9, .b = 0.9 },
    // front-left leg
    .{ .offset_x = -0.3, .offset_y = 0.0, .offset_z = -0.2, .width = 0.25, .height = 0.35, .depth = 0.25, .r = 0.4, .g = 0.25, .b = 0.1 },
    // front-right leg
    .{ .offset_x = 0.3, .offset_y = 0.0, .offset_z = -0.2, .width = 0.25, .height = 0.35, .depth = 0.25, .r = 0.4, .g = 0.25, .b = 0.1 },
    // back-left leg
    .{ .offset_x = -0.3, .offset_y = 0.0, .offset_z = 0.2, .width = 0.25, .height = 0.35, .depth = 0.25, .r = 0.4, .g = 0.25, .b = 0.1 },
    // back-right leg
    .{ .offset_x = 0.3, .offset_y = 0.0, .offset_z = 0.2, .width = 0.25, .height = 0.35, .depth = 0.25, .r = 0.4, .g = 0.25, .b = 0.1 },
};

// -- Chicken --------------------------------------------------------------

const chicken_parts = [_]BodyPart{
    // head
    .{ .offset_x = 0.0, .offset_y = 0.55, .offset_z = -0.15, .width = 0.2, .height = 0.2, .depth = 0.2, .r = 0.9, .g = 0.9, .b = 0.9 },
    // body
    .{ .offset_x = 0.0, .offset_y = 0.3, .offset_z = 0.0, .width = 0.35, .height = 0.3, .depth = 0.35, .r = 0.9, .g = 0.9, .b = 0.9 },
    // left leg
    .{ .offset_x = -0.1, .offset_y = 0.0, .offset_z = 0.0, .width = 0.1, .height = 0.15, .depth = 0.1, .r = 0.9, .g = 0.6, .b = 0.1 },
    // right leg
    .{ .offset_x = 0.1, .offset_y = 0.0, .offset_z = 0.0, .width = 0.1, .height = 0.15, .depth = 0.1, .r = 0.9, .g = 0.6, .b = 0.1 },
};

// -- Sheep ----------------------------------------------------------------

const sheep_parts = [_]BodyPart{
    // head
    .{ .offset_x = 0.0, .offset_y = 0.875, .offset_z = -0.4, .width = 0.4, .height = 0.4, .depth = 0.4, .r = 0.8, .g = 0.8, .b = 0.8 },
    // body (wool)
    .{ .offset_x = 0.0, .offset_y = 0.6, .offset_z = 0.0, .width = 0.8, .height = 0.55, .depth = 0.55, .r = 0.95, .g = 0.95, .b = 0.95 },
    // front-left leg
    .{ .offset_x = -0.25, .offset_y = 0.0, .offset_z = -0.15, .width = 0.2, .height = 0.35, .depth = 0.2, .r = 0.8, .g = 0.8, .b = 0.8 },
    // front-right leg
    .{ .offset_x = 0.25, .offset_y = 0.0, .offset_z = -0.15, .width = 0.2, .height = 0.35, .depth = 0.2, .r = 0.8, .g = 0.8, .b = 0.8 },
    // back-left leg
    .{ .offset_x = -0.25, .offset_y = 0.0, .offset_z = 0.15, .width = 0.2, .height = 0.35, .depth = 0.2, .r = 0.8, .g = 0.8, .b = 0.8 },
    // back-right leg
    .{ .offset_x = 0.25, .offset_y = 0.0, .offset_z = 0.15, .width = 0.2, .height = 0.35, .depth = 0.2, .r = 0.8, .g = 0.8, .b = 0.8 },
};

// -------------------------------------------------------------------------
// Public API
// -------------------------------------------------------------------------

/// Return the body-part list for the given entity type ID.
pub fn getBodyParts(entity_type: u8) []const BodyPart {
    return switch (entity_type) {
        ZOMBIE => &zombie_parts,
        SKELETON => &skeleton_parts,
        CREEPER => &creeper_parts,
        PIG => &pig_parts,
        COW => &cow_parts,
        CHICKEN => &chicken_parts,
        SHEEP => &sheep_parts,
        else => &[_]BodyPart{},
    };
}

/// Generate box-model vertices for a mob at world position (x, y, z) facing
/// `yaw` radians. Writes into `buf` and returns the number of vertices
/// written.
pub fn generateMobVertices(
    entity_type: u8,
    x: f32,
    y: f32,
    z: f32,
    yaw: f32,
    buf: []ModelVertex,
) u32 {
    const parts = getBodyParts(entity_type);
    const cos_yaw = @cos(yaw);
    const sin_yaw = @sin(yaw);
    var written: u32 = 0;

    for (parts) |part| {
        const needed = written + verts_per_part;
        if (needed > buf.len) break;
        written = appendBoxVertices(buf, written, part, x, y, z, cos_yaw, sin_yaw);
    }
    return written;
}

// -------------------------------------------------------------------------
// Internal helpers
// -------------------------------------------------------------------------

/// Append the 36 vertices for a single axis-aligned box (body part) into
/// `buf` starting at index `start`. The part's local offset is rotated
/// around Y by the pre-computed cos/sin, then translated to the entity
/// world position.
fn appendBoxVertices(
    buf: []ModelVertex,
    start: u32,
    part: BodyPart,
    wx: f32,
    wy: f32,
    wz: f32,
    cos_yaw: f32,
    sin_yaw: f32,
) u32 {
    const hw = part.width * 0.5;
    const hh = part.height * 0.5;
    const hd = part.depth * 0.5;

    // Eight corners of the local box centred on the part offset.
    const cx = part.offset_x;
    const cy = part.offset_y + hh; // offset_y is bottom; centre is half-height up
    const cz = part.offset_z;

    const local_corners = [8][3]f32{
        .{ cx - hw, cy - hh, cz - hd },
        .{ cx + hw, cy - hh, cz - hd },
        .{ cx + hw, cy + hh, cz - hd },
        .{ cx - hw, cy + hh, cz - hd },
        .{ cx - hw, cy - hh, cz + hd },
        .{ cx + hw, cy - hh, cz + hd },
        .{ cx + hw, cy + hh, cz + hd },
        .{ cx - hw, cy + hh, cz + hd },
    };

    // Rotate each corner around Y and translate to world position.
    var corners: [8][3]f32 = undefined;
    for (local_corners, 0..) |lc, i| {
        const rx = lc[0] * cos_yaw - lc[2] * sin_yaw;
        const rz = lc[0] * sin_yaw + lc[2] * cos_yaw;
        corners[i] = .{ wx + rx, wy + lc[1], wz + rz };
    }

    // Six faces, each as two triangles (CCW winding when viewed from outside).
    const face_indices = [6][6]u8{
        .{ 0, 1, 2, 2, 3, 0 }, // front  (-Z)
        .{ 5, 4, 7, 7, 6, 5 }, // back   (+Z)
        .{ 4, 0, 3, 3, 7, 4 }, // left   (-X)
        .{ 1, 5, 6, 6, 2, 1 }, // right  (+X)
        .{ 3, 2, 6, 6, 7, 3 }, // top    (+Y)
        .{ 4, 5, 1, 1, 0, 4 }, // bottom (-Y)
    };

    // Shade each face slightly differently for visual depth.
    const face_shade = [6]f32{ 0.9, 0.85, 0.8, 0.8, 1.0, 0.7 };

    var idx = start;
    for (face_indices, 0..) |face, fi| {
        const shade = face_shade[fi];
        for (face) |ci| {
            const c = corners[ci];
            buf[idx] = .{
                .x = c[0],
                .y = c[1],
                .z = c[2],
                .r = part.r * shade,
                .g = part.g * shade,
                .b = part.b * shade,
            };
            idx += 1;
        }
    }
    return idx;
}

// -------------------------------------------------------------------------
// Tests
// -------------------------------------------------------------------------

test "correct vertex count per type" {
    var buf: [512]ModelVertex = undefined;

    // Humanoid types: 6 parts * 36 = 216
    try std.testing.expectEqual(@as(u32, 216), generateMobVertices(ZOMBIE, 0, 0, 0, 0, &buf));
    try std.testing.expectEqual(@as(u32, 216), generateMobVertices(SKELETON, 0, 0, 0, 0, &buf));

    // Creeper: 6 parts * 36 = 216
    try std.testing.expectEqual(@as(u32, 216), generateMobVertices(CREEPER, 0, 0, 0, 0, &buf));

    // Pig: 6 parts * 36 = 216
    try std.testing.expectEqual(@as(u32, 216), generateMobVertices(PIG, 0, 0, 0, 0, &buf));

    // Cow: 6 parts * 36 = 216
    try std.testing.expectEqual(@as(u32, 216), generateMobVertices(COW, 0, 0, 0, 0, &buf));

    // Chicken: 4 parts * 36 = 144
    try std.testing.expectEqual(@as(u32, 144), generateMobVertices(CHICKEN, 0, 0, 0, 0, &buf));

    // Sheep: 6 parts * 36 = 216
    try std.testing.expectEqual(@as(u32, 216), generateMobVertices(SHEEP, 0, 0, 0, 0, &buf));

    // Unknown type: 0
    try std.testing.expectEqual(@as(u32, 0), generateMobVertices(255, 0, 0, 0, 0, &buf));
}

test "positions offset by entity position" {
    var buf_origin: [512]ModelVertex = undefined;
    var buf_offset: [512]ModelVertex = undefined;

    const n1 = generateMobVertices(PIG, 0, 0, 0, 0, &buf_origin);
    const n2 = generateMobVertices(PIG, 10, 20, 30, 0, &buf_offset);
    try std.testing.expectEqual(n1, n2);

    // Every vertex in the offset buffer should be shifted by (10, 20, 30).
    for (buf_origin[0..n1], buf_offset[0..n2]) |v0, v1| {
        try std.testing.expectApproxEqAbs(v0.x + 10.0, v1.x, 0.001);
        try std.testing.expectApproxEqAbs(v0.y + 20.0, v1.y, 0.001);
        try std.testing.expectApproxEqAbs(v0.z + 30.0, v1.z, 0.001);
    }
}

test "yaw rotates XZ coords" {
    var buf_zero: [512]ModelVertex = undefined;
    var buf_rot: [512]ModelVertex = undefined;

    const n0 = generateMobVertices(ZOMBIE, 0, 0, 0, 0, &buf_zero);
    const n1 = generateMobVertices(ZOMBIE, 0, 0, 0, std.math.pi / 2.0, &buf_rot);
    try std.testing.expectEqual(n0, n1);

    // Y coordinates should be unchanged; at least some XZ should differ.
    var xz_differs = false;
    for (buf_zero[0..n0], buf_rot[0..n1]) |v0, v1| {
        try std.testing.expectApproxEqAbs(v0.y, v1.y, 0.001);
        if (@abs(v0.x - v1.x) > 0.001 or @abs(v0.z - v1.z) > 0.001) {
            xz_differs = true;
        }
    }
    try std.testing.expect(xz_differs);
}

test "getBodyParts returns correct part count" {
    try std.testing.expectEqual(@as(usize, 6), getBodyParts(ZOMBIE).len);
    try std.testing.expectEqual(@as(usize, 6), getBodyParts(SKELETON).len);
    try std.testing.expectEqual(@as(usize, 6), getBodyParts(CREEPER).len);
    try std.testing.expectEqual(@as(usize, 6), getBodyParts(PIG).len);
    try std.testing.expectEqual(@as(usize, 6), getBodyParts(COW).len);
    try std.testing.expectEqual(@as(usize, 4), getBodyParts(CHICKEN).len);
    try std.testing.expectEqual(@as(usize, 6), getBodyParts(SHEEP).len);
    try std.testing.expectEqual(@as(usize, 0), getBodyParts(99).len);
}

test "zombie parts are green" {
    const parts = getBodyParts(ZOMBIE);
    for (parts) |p| {
        try std.testing.expectApproxEqAbs(@as(f32, 0.0), p.r, 0.001);
        try std.testing.expectApproxEqAbs(@as(f32, 0.6), p.g, 0.001);
        try std.testing.expectApproxEqAbs(@as(f32, 0.0), p.b, 0.001);
    }
}

test "skeleton parts are white" {
    const parts = getBodyParts(SKELETON);
    for (parts) |p| {
        try std.testing.expectApproxEqAbs(@as(f32, 0.9), p.r, 0.001);
        try std.testing.expectApproxEqAbs(@as(f32, 0.9), p.g, 0.001);
        try std.testing.expectApproxEqAbs(@as(f32, 0.9), p.b, 0.001);
    }
}

test "buffer too small truncates gracefully" {
    // Only room for 1 part (36 verts), zombie has 6 parts.
    var small_buf: [36]ModelVertex = undefined;
    const n = generateMobVertices(ZOMBIE, 0, 0, 0, 0, &small_buf);
    try std.testing.expectEqual(@as(u32, 36), n);
}

test "180-degree yaw flips XZ signs" {
    var buf_zero: [512]ModelVertex = undefined;
    var buf_pi: [512]ModelVertex = undefined;

    const n0 = generateMobVertices(PIG, 0, 0, 0, 0, &buf_zero);
    const n1 = generateMobVertices(PIG, 0, 0, 0, std.math.pi, &buf_pi);
    try std.testing.expectEqual(n0, n1);

    // For a 180-degree rotation: rotated_x ~ -original_x, rotated_z ~ -original_z.
    for (buf_zero[0..n0], buf_pi[0..n1]) |v0, v1| {
        try std.testing.expectApproxEqAbs(-v0.x, v1.x, 0.01);
        try std.testing.expectApproxEqAbs(v0.y, v1.y, 0.001);
        try std.testing.expectApproxEqAbs(-v0.z, v1.z, 0.01);
    }
}
