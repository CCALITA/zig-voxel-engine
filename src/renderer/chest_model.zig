const std = @import("std");

pub const ChestVertex = struct {
    x: f32,
    y: f32,
    z: f32,
    nx: f32,
    ny: f32,
    nz: f32,
    u: f32,
    v: f32,
};

pub const ChestType = enum {
    single,
    double_left,
    double_right,
    ender,
};

/// Vertices per face (two triangles).
const verts_per_face: u32 = 6;
/// Faces per box.
const faces_per_box: u32 = 6;
/// Total vertices per box part.
const verts_per_box: u32 = verts_per_face * faces_per_box; // 36

/// Maximum lid opening angle in radians (~45 degrees).
pub const max_lid_angle: f32 = std.math.pi / 4.0;

/// Single chest body dimensions in block units (14/16, 10/16, 14/16).
const single_body_w: f32 = 14.0 / 16.0;
const single_body_h: f32 = 10.0 / 16.0;
const single_body_d: f32 = 14.0 / 16.0;

/// Single chest lid dimensions (14/16, 5/16, 14/16).
const single_lid_w: f32 = 14.0 / 16.0;
const single_lid_h: f32 = 5.0 / 16.0;
const single_lid_d: f32 = 14.0 / 16.0;

/// Texture UV base offsets per chest type (row on a texture atlas).
const single_tex_v: f32 = 0.0;
const ender_tex_v: f32 = 0.25;
/// Lid texture U base offset (lid sits to the right of body on the atlas).
const lid_tex_u: f32 = 0.5;

/// Result of generateChestMesh: fixed-size vertex buffer with actual count.
pub const ChestMesh = struct {
    verts: [80]ChestVertex,
    count: u32,
};

/// Generate the complete mesh for a chest at world position (cx, cy, cz).
/// The lid rotates around its back edge (hinge at +Z top of body) by lid_angle
/// radians, clamped to [0, max_lid_angle].
///
/// Returns a ChestMesh with the vertex array and actual vertex count.
pub fn generateChestMesh(cx: f32, cy: f32, cz: f32, chest_type: ChestType, lid_angle: f32) ChestMesh {
    const clamped_angle = std.math.clamp(lid_angle, 0.0, max_lid_angle);

    const width_multiplier: f32 = switch (chest_type) {
        .double_left, .double_right => 2.0,
        else => 1.0,
    };

    const body_w = single_body_w * width_multiplier;
    const body_h = single_body_h;
    const body_d = single_body_d;

    const lid_w = single_lid_w * width_multiplier;
    const lid_h = single_lid_h;
    const lid_d = single_lid_d;

    // Texture V offset: ender chests use a different texture row.
    const tex_v_base: f32 = switch (chest_type) {
        .ender => ender_tex_v,
        else => single_tex_v,
    };

    // For double chests, offset so the pair aligns correctly.
    const x_offset: f32 = switch (chest_type) {
        .double_left => -single_body_w / 2.0,
        .double_right => single_body_w / 2.0,
        else => 0.0,
    };

    const base_x = cx + x_offset;

    var result: ChestMesh = .{
        .verts = undefined,
        .count = 0,
    };

    // --- Body box (sits on the ground plane) ---
    const body_min_x = base_x - body_w / 2.0;
    const body_min_y = cy;
    const body_min_z = cz - body_d / 2.0;
    const body_max_x = base_x + body_w / 2.0;
    const body_max_y = cy + body_h;
    const body_max_z = cz + body_d / 2.0;

    result.count = appendAxisAlignedBox(
        &result.verts,
        result.count,
        body_min_x,
        body_min_y,
        body_min_z,
        body_max_x,
        body_max_y,
        body_max_z,
        0.0, // u base
        tex_v_base,
    );

    // --- Lid box (hinged at the back-top edge of the body, i.e. max-Z, max-Y) ---
    // The hinge line runs along X at (cy + body_h, cz + body_d/2).
    // The lid is built in local space with the hinge at the origin, then
    // rotated by -clamped_angle around X (opening towards -Z / front),
    // then translated to world position.
    const hinge_y = cy + body_h;
    const hinge_z = cz + body_d / 2.0;

    // Local lid corners before rotation (hinge at origin, lid extends in -Z and +Y).
    const local_min_x = base_x - lid_w / 2.0;
    const local_max_x = base_x + lid_w / 2.0;
    // In local hinge space: y goes from 0 to lid_h, z goes from -lid_d to 0.
    const ly0: f32 = 0.0;
    const ly1: f32 = lid_h;
    const lz0: f32 = -lid_d;
    const lz1: f32 = 0.0;

    const cos_a = @cos(clamped_angle);
    const sin_a = @sin(clamped_angle);

    // Eight corners of the lid in local hinge-space, then rotated and translated.
    const local_yz = [4][2]f32{
        .{ ly0, lz0 }, // bottom-front
        .{ ly0, lz1 }, // bottom-back (hinge edge)
        .{ ly1, lz0 }, // top-front
        .{ ly1, lz1 }, // top-back
    };

    // Rotate around hinge (X-axis rotation): y' = y*cos - z*sin, z' = y*sin + z*cos
    var world_corners: [8][3]f32 = undefined;
    for (local_yz, 0..) |yz, i| {
        const ry = yz[0] * cos_a - yz[1] * sin_a;
        const rz = yz[0] * sin_a + yz[1] * cos_a;
        world_corners[i] = .{ local_min_x, hinge_y + ry, hinge_z + rz };
        world_corners[i + 4] = .{ local_max_x, hinge_y + ry, hinge_z + rz };
    }

    // Map corners to the standard box vertex order:
    // 0: min-x, min-y, min-z  (left-bottom-front)
    // 1: max-x, min-y, min-z  (right-bottom-front)
    // 2: max-x, max-y, min-z  (right-top-front)
    // 3: min-x, max-y, min-z  (left-top-front)
    // 4: min-x, min-y, max-z  (left-bottom-back)
    // 5: max-x, min-y, max-z  (right-bottom-back)
    // 6: max-x, max-y, max-z  (right-top-back)
    // 7: min-x, max-y, max-z  (left-top-back)
    //
    // Our local_yz indices: 0=bottom-front, 1=bottom-back, 2=top-front, 3=top-back
    // world_corners[0..3] are min-x, world_corners[4..7] are max-x.
    const ordered_corners = [8][3]f32{
        world_corners[0], // 0: min-x, bottom-front
        world_corners[4], // 1: max-x, bottom-front
        world_corners[6], // 2: max-x, top-front
        world_corners[2], // 3: min-x, top-front
        world_corners[1], // 4: min-x, bottom-back
        world_corners[5], // 5: max-x, bottom-back
        world_corners[7], // 6: max-x, top-back
        world_corners[3], // 7: min-x, top-back
    };

    result.count = appendRotatedBox(
        &result.verts,
        result.count,
        ordered_corners,
        lid_tex_u,
        tex_v_base,
    );

    return result;
}

// -------------------------------------------------------------------------
// Internal helpers
// -------------------------------------------------------------------------

/// Append 36 vertices for an axis-aligned box defined by min/max corners.
fn appendAxisAlignedBox(
    buf: []ChestVertex,
    start: u32,
    min_x: f32,
    min_y: f32,
    min_z: f32,
    max_x: f32,
    max_y: f32,
    max_z: f32,
    tex_u_base: f32,
    tex_v_base: f32,
) u32 {
    const corners = [8][3]f32{
        .{ min_x, min_y, min_z }, // 0: left-bottom-front
        .{ max_x, min_y, min_z }, // 1: right-bottom-front
        .{ max_x, max_y, min_z }, // 2: right-top-front
        .{ min_x, max_y, min_z }, // 3: left-top-front
        .{ min_x, min_y, max_z }, // 4: left-bottom-back
        .{ max_x, min_y, max_z }, // 5: right-bottom-back
        .{ max_x, max_y, max_z }, // 6: right-top-back
        .{ min_x, max_y, max_z }, // 7: left-top-back
    };

    return appendRotatedBox(buf, start, corners, tex_u_base, tex_v_base);
}

/// Append 36 vertices for a box defined by 8 arbitrary corners.
/// Corner ordering follows the standard convention (see generateChestMesh).
fn appendRotatedBox(
    buf: []ChestVertex,
    start: u32,
    corners: [8][3]f32,
    tex_u_base: f32,
    tex_v_base: f32,
) u32 {
    if (start + verts_per_box > buf.len) return start;

    // Six faces: indices into corners, normal direction, and UV offsets.
    const Face = struct {
        idx: [6]u8,
        nx: f32,
        ny: f32,
        nz: f32,
        u_off: f32,
        v_off: f32,
    };

    const faces = [faces_per_box]Face{
        // Front (-Z)
        .{ .idx = .{ 0, 1, 2, 2, 3, 0 }, .nx = 0, .ny = 0, .nz = -1, .u_off = 0.0, .v_off = 0.0 },
        // Back (+Z)
        .{ .idx = .{ 5, 4, 7, 7, 6, 5 }, .nx = 0, .ny = 0, .nz = 1, .u_off = 0.0, .v_off = 0.125 },
        // Left (-X)
        .{ .idx = .{ 4, 0, 3, 3, 7, 4 }, .nx = -1, .ny = 0, .nz = 0, .u_off = 0.125, .v_off = 0.0 },
        // Right (+X)
        .{ .idx = .{ 1, 5, 6, 6, 2, 1 }, .nx = 1, .ny = 0, .nz = 0, .u_off = 0.125, .v_off = 0.125 },
        // Top (+Y)
        .{ .idx = .{ 3, 2, 6, 6, 7, 3 }, .nx = 0, .ny = 1, .nz = 0, .u_off = 0.25, .v_off = 0.0 },
        // Bottom (-Y)
        .{ .idx = .{ 4, 5, 1, 1, 0, 4 }, .nx = 0, .ny = -1, .nz = 0, .u_off = 0.25, .v_off = 0.125 },
    };

    // Per-face corner UV coordinates (two triangles, matching face_indices winding).
    const face_uvs = [6][2]f32{
        .{ 0.0, 0.0 },
        .{ 1.0, 0.0 },
        .{ 1.0, 1.0 },
        .{ 1.0, 1.0 },
        .{ 0.0, 1.0 },
        .{ 0.0, 0.0 },
    };

    var idx = start;
    for (faces) |face| {
        for (face.idx, 0..) |ci, vi| {
            const c = corners[ci];
            const uv = face_uvs[vi];
            buf[idx] = .{
                .x = c[0],
                .y = c[1],
                .z = c[2],
                .nx = face.nx,
                .ny = face.ny,
                .nz = face.nz,
                .u = tex_u_base + face.u_off + uv[0] * 0.125,
                .v = tex_v_base + face.v_off + uv[1] * 0.125,
            };
            idx += 1;
        }
    }
    return idx;
}

// -------------------------------------------------------------------------
// Tests
// -------------------------------------------------------------------------

test "single chest produces 72 vertices (body + lid)" {
    const mesh = generateChestMesh(0, 0, 0, .single, 0);
    // 2 boxes * 36 verts = 72
    try std.testing.expectEqual(@as(u32, 72), mesh.count);
}

test "double chest produces 72 vertices" {
    const left = generateChestMesh(0, 0, 0, .double_left, 0);
    const right = generateChestMesh(0, 0, 0, .double_right, 0);
    try std.testing.expectEqual(@as(u32, 72), left.count);
    try std.testing.expectEqual(@as(u32, 72), right.count);
}

test "ender chest produces 72 vertices with different UVs" {
    const single = generateChestMesh(0, 0, 0, .single, 0);
    const ender = generateChestMesh(0, 0, 0, .ender, 0);
    try std.testing.expectEqual(single.count, ender.count);

    // At least some UV v-coordinates should differ (ender uses ender_tex_v offset).
    var uv_differs = false;
    for (single.verts[0..single.count], ender.verts[0..ender.count]) |sv, ev| {
        if (@abs(sv.v - ev.v) > 0.001) {
            uv_differs = true;
            break;
        }
    }
    try std.testing.expect(uv_differs);
}

test "lid angle zero keeps lid flat on body" {
    const mesh = generateChestMesh(0, 0, 0, .single, 0);
    // Lid vertices start after the body (index 36..71).
    // With angle=0 the lid top should be at body_h + lid_h = 10/16 + 5/16 = 15/16.
    const expected_top: f32 = single_body_h + single_lid_h;
    var found_top = false;
    for (mesh.verts[36..mesh.count]) |v| {
        if (@abs(v.y - expected_top) < 0.01) {
            found_top = true;
            break;
        }
    }
    try std.testing.expect(found_top);
}

test "lid angle is clamped to max_lid_angle" {
    // A huge angle should produce the same result as max_lid_angle.
    const clamped = generateChestMesh(5, 0, 5, .single, 999.0);
    const at_max = generateChestMesh(5, 0, 5, .single, max_lid_angle);
    try std.testing.expectEqual(clamped.count, at_max.count);

    for (clamped.verts[0..clamped.count], at_max.verts[0..at_max.count]) |cv, mv| {
        try std.testing.expectApproxEqAbs(cv.x, mv.x, 0.001);
        try std.testing.expectApproxEqAbs(cv.y, mv.y, 0.001);
        try std.testing.expectApproxEqAbs(cv.z, mv.z, 0.001);
    }
}

test "opening lid raises front edge above closed position" {
    const closed = generateChestMesh(0, 0, 0, .single, 0);
    const open = generateChestMesh(0, 0, 0, .single, max_lid_angle);

    // Find the maximum Y among lid vertices (indices 36..71).
    var closed_max_y: f32 = -999.0;
    var open_max_y: f32 = -999.0;
    for (closed.verts[36..closed.count]) |v| {
        if (v.y > closed_max_y) closed_max_y = v.y;
    }
    for (open.verts[36..open.count]) |v| {
        if (v.y > open_max_y) open_max_y = v.y;
    }

    // When open, the lid's top-front edge should be higher than when closed.
    try std.testing.expect(open_max_y > closed_max_y);
}

test "double chest is wider than single" {
    const single = generateChestMesh(0, 0, 0, .single, 0);
    const double = generateChestMesh(0, 0, 0, .double_left, 0);

    var single_min_x: f32 = 999.0;
    var single_max_x: f32 = -999.0;
    for (single.verts[0..single.count]) |v| {
        if (v.x < single_min_x) single_min_x = v.x;
        if (v.x > single_max_x) single_max_x = v.x;
    }

    var double_min_x: f32 = 999.0;
    var double_max_x: f32 = -999.0;
    for (double.verts[0..double.count]) |v| {
        if (v.x < double_min_x) double_min_x = v.x;
        if (v.x > double_max_x) double_max_x = v.x;
    }

    const single_width = single_max_x - single_min_x;
    const double_width = double_max_x - double_min_x;
    try std.testing.expect(double_width > single_width * 1.5);
}

test "world position offsets all vertices" {
    const at_origin = generateChestMesh(0, 0, 0, .single, 0);
    const at_offset = generateChestMesh(10, 20, 30, .single, 0);
    try std.testing.expectEqual(at_origin.count, at_offset.count);

    for (at_origin.verts[0..at_origin.count], at_offset.verts[0..at_offset.count]) |v0, v1| {
        try std.testing.expectApproxEqAbs(v0.x + 10.0, v1.x, 0.001);
        try std.testing.expectApproxEqAbs(v0.y + 20.0, v1.y, 0.001);
        try std.testing.expectApproxEqAbs(v0.z + 30.0, v1.z, 0.001);
    }
}

test "normals are unit length" {
    const mesh = generateChestMesh(0, 0, 0, .single, max_lid_angle / 2.0);
    for (mesh.verts[0..mesh.count]) |v| {
        const len = @sqrt(v.nx * v.nx + v.ny * v.ny + v.nz * v.nz);
        try std.testing.expectApproxEqAbs(@as(f32, 1.0), len, 0.001);
    }
}
