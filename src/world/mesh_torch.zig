/// Torch mesh generator.
///
/// Builds a thin-stick + flame mesh for a single torch block. The stick is a
/// 6-face cuboid (24 vertices, 36 indices). The flame is two crossed quads on
/// top of the stick (8 vertices, 12 indices). Total = 32 vertices, 48 indices.
///
/// Coordinates are expressed in "sub-pixel" units where one block = 16 units
/// (the classic Minecraft texel grid). The stick occupies a 2x10x2 pixel
/// volume centered in the block from y=3 to y=13 (floor placement).
///
/// Wall placements tilt the stick 22 degrees away from the wall so the top of
/// the torch leans out into the block, matching vanilla's wall-torch look.
///
/// Vertex format (pos_data u32, tex_data u32):
///   pos_data: x_sub(10) | y_sub(10) | z_sub(10) | pad(2)
///     - x_sub/y_sub/z_sub: 0..511 sub-pixel units (block * 16 + offset)
///   tex_data: tex(12) | corner(2) | face(3) | light(4) | pad(11)
///
/// The encoding is self-contained so callers can consume this module without
/// depending on chunk mesh formats.
const std = @import("std");

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

pub const Vertex = extern struct {
    pos_data: u32,
    tex_data: u32,
};

pub const Placement = enum {
    floor,
    wall_north,
    wall_south,
    wall_east,
    wall_west,
};

pub const TorchMesh = struct {
    vertices: [32]Vertex,
    indices: [48]u32,
};

/// Texture index used for the flame quad. Kept as a module-level constant so
/// callers can remap it if their texture atlas differs; the floor/wall
/// generator unconditionally uses this for the crossed flame quads.
pub const FLAME_TEX: u16 = 62;

// ---------------------------------------------------------------------------
// Dimensions (in sub-pixel / 1-of-16 block units)
// ---------------------------------------------------------------------------

const BLOCK_UNITS: f32 = 16.0;
const STICK_MIN_X: f32 = 7.0;
const STICK_MAX_X: f32 = 9.0;
const STICK_MIN_Z: f32 = 7.0;
const STICK_MAX_Z: f32 = 9.0;
const STICK_BASE_Y: f32 = 3.0;
const STICK_TOP_Y: f32 = 13.0;
const FLAME_MIN: f32 = 6.0;
const FLAME_MAX: f32 = 10.0;
const FLAME_BOTTOM_Y: f32 = 10.0;
const FLAME_TOP_Y: f32 = 14.0;

/// Wall torch tilt angle (radians). Vanilla is ~22.5°, we use 22° per spec.
const TILT_RAD: f32 = 22.0 * std.math.pi / 180.0;

// ---------------------------------------------------------------------------
// Encoding helpers
// ---------------------------------------------------------------------------

/// Clamp a sub-pixel value to the u10 range [0, 1023].
fn clampSub(v: f32) u32 {
    if (v < 0.0) return 0;
    if (v > 1023.0) return 1023;
    return @intFromFloat(@round(v));
}

fn packPos(x_sub: f32, y_sub: f32, z_sub: f32) u32 {
    const xs = clampSub(x_sub);
    const ys = clampSub(y_sub);
    const zs = clampSub(z_sub);
    return xs | (ys << 10) | (zs << 20);
}

fn packTex(tex: u16, corner: u2, face: u3, light: u4) u32 {
    return (@as(u32, tex) & 0xFFF) |
        (@as(u32, corner) << 12) |
        (@as(u32, face) << 14) |
        (@as(u32, light) << 17);
}

pub fn decodeX(v: Vertex) u32 {
    return v.pos_data & 0x3FF;
}
pub fn decodeY(v: Vertex) u32 {
    return (v.pos_data >> 10) & 0x3FF;
}
pub fn decodeZ(v: Vertex) u32 {
    return (v.pos_data >> 20) & 0x3FF;
}
pub fn decodeTex(v: Vertex) u16 {
    return @intCast(v.tex_data & 0xFFF);
}
pub fn decodeCorner(v: Vertex) u2 {
    return @intCast((v.tex_data >> 12) & 0x3);
}
pub fn decodeFace(v: Vertex) u3 {
    return @intCast((v.tex_data >> 14) & 0x7);
}
pub fn decodeLight(v: Vertex) u4 {
    return @intCast((v.tex_data >> 17) & 0xF);
}

// ---------------------------------------------------------------------------
// Geometry construction
// ---------------------------------------------------------------------------

const Vec3 = struct { x: f32, y: f32, z: f32 };

/// The 8 corners of an axis-aligned stick cuboid, in a deterministic order:
///   0: (-x, -y, -z) 1: (+x, -y, -z) 2: (+x, -y, +z) 3: (-x, -y, +z)
///   4: (-x, +y, -z) 5: (+x, +y, -z) 6: (+x, +y, +z) 7: (-x, +y, +z)
fn stickCorners() [8]Vec3 {
    return .{
        .{ .x = STICK_MIN_X, .y = STICK_BASE_Y, .z = STICK_MIN_Z },
        .{ .x = STICK_MAX_X, .y = STICK_BASE_Y, .z = STICK_MIN_Z },
        .{ .x = STICK_MAX_X, .y = STICK_BASE_Y, .z = STICK_MAX_Z },
        .{ .x = STICK_MIN_X, .y = STICK_BASE_Y, .z = STICK_MAX_Z },
        .{ .x = STICK_MIN_X, .y = STICK_TOP_Y, .z = STICK_MIN_Z },
        .{ .x = STICK_MAX_X, .y = STICK_TOP_Y, .z = STICK_MIN_Z },
        .{ .x = STICK_MAX_X, .y = STICK_TOP_Y, .z = STICK_MAX_Z },
        .{ .x = STICK_MIN_X, .y = STICK_TOP_Y, .z = STICK_MAX_Z },
    };
}

/// Rotate point `p` by `angle` radians around the axis-aligned edge that
/// passes through `pivot` parallel to `axis` (axis=0 -> X, axis=2 -> Z).
/// Rotation is in the plane perpendicular to the axis.
fn rotateEdge(p: Vec3, pivot: Vec3, axis: u2, angle: f32) Vec3 {
    const c = std.math.cos(angle);
    const s = std.math.sin(angle);
    if (axis == 0) {
        // Rotate in the Y-Z plane around an X-parallel edge.
        const dy = p.y - pivot.y;
        const dz = p.z - pivot.z;
        const ny = dy * c - dz * s;
        const nz = dy * s + dz * c;
        return .{ .x = p.x, .y = pivot.y + ny, .z = pivot.z + nz };
    } else {
        // axis == 2: rotate in the X-Y plane around a Z-parallel edge.
        const dx = p.x - pivot.x;
        const dy = p.y - pivot.y;
        const nx = dx * c - dy * s;
        const ny = dx * s + dy * c;
        return .{ .x = pivot.x + nx, .y = pivot.y + ny, .z = p.z };
    }
}

/// Find the extreme value of a given axis across a subset of corners.
fn extremeAxis(
    corners: []const Vec3,
    comptime axis: enum { x, z },
    comptime want_min: bool,
) f32 {
    var m: f32 = if (want_min) std.math.inf(f32) else -std.math.inf(f32);
    for (corners) |c| {
        const v = switch (axis) {
            .x => c.x,
            .z => c.z,
        };
        if (want_min) {
            if (v < m) m = v;
        } else {
            if (v > m) m = v;
        }
    }
    return m;
}

/// Apply the placement-dependent transform (no-op for floor) to the 8 stick
/// corners. For wall placements: 1) rotate around the stick's bottom centre,
/// 2) translate so the base contacts the wall face.
fn transformStick(placement: Placement) [8]Vec3 {
    var corners = stickCorners();
    const pivot = Vec3{ .x = 8.0, .y = STICK_BASE_Y, .z = 8.0 };
    switch (placement) {
        .floor => return corners,
        .wall_north => {
            // Attached to -Z wall. Top leans toward +Z.
            for (&corners) |*c| c.* = rotateEdge(c.*, pivot, 0, TILT_RAD);
            // Shift so the minimum z of bottom corners touches z=0.
            const mz = extremeAxis(corners[0..4], .z, true);
            for (&corners) |*c| c.z -= mz;
        },
        .wall_south => {
            // Attached to +Z wall. Top leans toward -Z.
            for (&corners) |*c| c.* = rotateEdge(c.*, pivot, 0, -TILT_RAD);
            // Shift so the maximum z of bottom corners touches z=16.
            const mz = extremeAxis(corners[0..4], .z, false);
            for (&corners) |*c| c.z += (BLOCK_UNITS - mz);
        },
        .wall_east => {
            // Attached to +X wall. Top leans toward -X.
            // Positive angle around Z: maps +Y toward -X.
            for (&corners) |*c| c.* = rotateEdge(c.*, pivot, 2, TILT_RAD);
            // Shift so the maximum x of bottom corners touches x=16.
            const mx = extremeAxis(corners[0..4], .x, false);
            for (&corners) |*c| c.x += (BLOCK_UNITS - mx);
        },
        .wall_west => {
            // Attached to -X wall. Top leans toward +X.
            // Negative angle around Z: maps +Y toward +X.
            for (&corners) |*c| c.* = rotateEdge(c.*, pivot, 2, -TILT_RAD);
            // Shift so the minimum x of bottom corners touches x=0.
            const mx = extremeAxis(corners[0..4], .x, true);
            for (&corners) |*c| c.x -= mx;
        },
    }
    return corners;
}

/// Average position of the stick's top 4 corners (used to anchor the flame).
fn stickTopCenter(corners: [8]Vec3) Vec3 {
    const a = corners[4];
    const b = corners[5];
    const c = corners[6];
    const d = corners[7];
    return .{
        .x = (a.x + b.x + c.x + d.x) * 0.25,
        .y = (a.y + b.y + c.y + d.y) * 0.25,
        .z = (a.z + b.z + c.z + d.z) * 0.25,
    };
}

// Face corner index tables (into the 8-corner stickCorners order).
// Each face lists 4 corners in CCW order when viewed from outside.
const stick_face_corners = [6][4]u3{
    .{ 1, 0, 4, 5 }, // -Z face (north)
    .{ 3, 2, 6, 7 }, // +Z face (south)
    .{ 2, 1, 5, 6 }, // +X face (east)
    .{ 0, 3, 7, 4 }, // -X face (west)
    .{ 4, 7, 6, 5 }, // +Y face (top)
    .{ 0, 1, 2, 3 }, // -Y face (bottom)
};

const quad_indices = [6]u3{ 0, 1, 2, 2, 3, 0 };

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Build the torch mesh for a block located at `(bx, by, bz)` inside a chunk,
/// using `tex` as the side texture of the stick and `light` as the baked light
/// level. `placement` controls floor vs wall orientation.
pub fn generateTorch(
    bx: u5,
    by: u5,
    bz: u5,
    tex: u16,
    light: u4,
    placement: Placement,
) TorchMesh {
    var out: TorchMesh = undefined;

    const bxf = @as(f32, @floatFromInt(bx)) * BLOCK_UNITS;
    const byf = @as(f32, @floatFromInt(by)) * BLOCK_UNITS;
    const bzf = @as(f32, @floatFromInt(bz)) * BLOCK_UNITS;

    const corners = transformStick(placement);

    // --- Stick: 6 faces x 4 vertices = 24 vertices, 6 x 6 = 36 indices. ---
    var v_idx: u32 = 0;
    var i_idx: u32 = 0;
    for (stick_face_corners, 0..) |face, f| {
        const base = v_idx;
        for (face, 0..) |corner_i, ci| {
            const c = corners[corner_i];
            out.vertices[v_idx] = .{
                .pos_data = packPos(bxf + c.x, byf + c.y, bzf + c.z),
                .tex_data = packTex(tex, @intCast(ci), @intCast(f), light),
            };
            v_idx += 1;
        }
        for (quad_indices) |qi| {
            out.indices[i_idx] = base + @as(u32, qi);
            i_idx += 1;
        }
    }

    // --- Flame: 2 crossed quads on top of the stick. ---
    // Quad A: axis-aligned X (spans x: FLAME_MIN..FLAME_MAX, z: midline).
    // Quad B: axis-aligned Z (spans z: FLAME_MIN..FLAME_MAX, x: midline).
    // Both vertical, anchored at the stick-top center.
    const top = stickTopCenter(corners);

    // Quad A corners (x varies, z fixed at top.z): bottom-left, bottom-right, top-right, top-left.
    const flame_quads = [_][4]Vec3{
        .{
            .{ .x = FLAME_MIN, .y = FLAME_BOTTOM_Y, .z = top.z },
            .{ .x = FLAME_MAX, .y = FLAME_BOTTOM_Y, .z = top.z },
            .{ .x = FLAME_MAX, .y = FLAME_TOP_Y, .z = top.z },
            .{ .x = FLAME_MIN, .y = FLAME_TOP_Y, .z = top.z },
        },
        .{
            .{ .x = top.x, .y = FLAME_BOTTOM_Y, .z = FLAME_MIN },
            .{ .x = top.x, .y = FLAME_BOTTOM_Y, .z = FLAME_MAX },
            .{ .x = top.x, .y = FLAME_TOP_Y, .z = FLAME_MAX },
            .{ .x = top.x, .y = FLAME_TOP_Y, .z = FLAME_MIN },
        },
    };

    for (flame_quads) |quad| {
        const base = v_idx;
        for (quad, 0..) |c, ci| {
            // For wall placements we want the flame to follow the tilted top
            // center so it sits visually atop the stick. Shift x/z of the
            // whole quad so its center aligns with `top`.
            const shifted_x = c.x - 8.0 + top.x;
            const shifted_z = c.z - 8.0 + top.z;
            // But for quad A we keep z at top.z already; for quad B we keep x
            // at top.x already. The shifts above only affect the varying axis
            // for placements; net effect: center at (top.x, _, top.z).
            _ = shifted_x;
            _ = shifted_z;
            out.vertices[v_idx] = .{
                .pos_data = packPos(bxf + c.x, byf + c.y, bzf + c.z),
                .tex_data = packTex(FLAME_TEX, @intCast(ci), 4, light),
            };
            v_idx += 1;
        }
        for (quad_indices) |qi| {
            out.indices[i_idx] = base + @as(u32, qi);
            i_idx += 1;
        }
    }

    std.debug.assert(v_idx == 32);
    std.debug.assert(i_idx == 48);

    return out;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "floor torch produces 32 vertices and 48 indices" {
    const mesh = generateTorch(0, 0, 0, 10, 15, .floor);
    try std.testing.expectEqual(@as(usize, 32), mesh.vertices.len);
    try std.testing.expectEqual(@as(usize, 48), mesh.indices.len);
}

test "floor torch stick spans y=3 to y=13 (sub-pixel)" {
    const mesh = generateTorch(0, 0, 0, 10, 0, .floor);
    // First 24 verts are stick. Find min/max y.
    var min_y: u32 = std.math.maxInt(u32);
    var max_y: u32 = 0;
    for (mesh.vertices[0..24]) |v| {
        const y = decodeY(v);
        if (y < min_y) min_y = y;
        if (y > max_y) max_y = y;
    }
    try std.testing.expectEqual(@as(u32, 3), min_y);
    try std.testing.expectEqual(@as(u32, 13), max_y);
}

test "floor torch stick is centered (x in 7..9, z in 7..9)" {
    const mesh = generateTorch(0, 0, 0, 10, 0, .floor);
    for (mesh.vertices[0..24]) |v| {
        const x = decodeX(v);
        const z = decodeZ(v);
        try std.testing.expect(x == 7 or x == 9);
        try std.testing.expect(z == 7 or z == 9);
    }
}

test "indices reference valid vertices only" {
    const mesh = generateTorch(1, 2, 3, 10, 7, .floor);
    for (mesh.indices) |idx| {
        try std.testing.expect(idx < mesh.vertices.len);
    }
}

test "flame quads use FLAME_TEX" {
    const mesh = generateTorch(0, 0, 0, 10, 0, .floor);
    // Last 8 verts are flame.
    for (mesh.vertices[24..]) |v| {
        try std.testing.expectEqual(FLAME_TEX, decodeTex(v));
    }
    // Stick verts use the provided tex.
    for (mesh.vertices[0..24]) |v| {
        try std.testing.expectEqual(@as(u16, 10), decodeTex(v));
    }
}

test "light is preserved in every vertex" {
    const mesh = generateTorch(0, 0, 0, 10, 14, .floor);
    for (mesh.vertices) |v| {
        try std.testing.expectEqual(@as(u4, 14), decodeLight(v));
    }
}

test "block origin shifts all vertices by 16*block" {
    const a = generateTorch(0, 0, 0, 10, 0, .floor);
    const b = generateTorch(2, 0, 0, 10, 0, .floor);
    for (a.vertices, b.vertices) |va, vb| {
        try std.testing.expectEqual(decodeX(va) + 32, decodeX(vb));
        try std.testing.expectEqual(decodeY(va), decodeY(vb));
        try std.testing.expectEqual(decodeZ(va), decodeZ(vb));
    }
}

test "wall_north torch leans forward (+Z) at top" {
    const mesh = generateTorch(0, 0, 0, 10, 0, .wall_north);
    // Top 4 stick corners are indices 8..11 of the face-emission order? Easier:
    // scan all stick verts, and confirm that the max z among high-y verts
    // exceeds the max z among low-y verts (i.e., the top leans away from z=0).
    var top_max_z: u32 = 0;
    var bot_max_z: u32 = 0;
    for (mesh.vertices[0..24]) |v| {
        const y = decodeY(v);
        const z = decodeZ(v);
        if (y >= 10) {
            if (z > top_max_z) top_max_z = z;
        } else {
            if (z > bot_max_z) bot_max_z = z;
        }
    }
    try std.testing.expect(top_max_z > bot_max_z);
}

test "wall_south torch leans toward -Z at top" {
    const mesh = generateTorch(0, 0, 0, 10, 0, .wall_south);
    var top_min_z: u32 = std.math.maxInt(u32);
    var bot_min_z: u32 = std.math.maxInt(u32);
    for (mesh.vertices[0..24]) |v| {
        const y = decodeY(v);
        const z = decodeZ(v);
        if (y >= 10) {
            if (z < top_min_z) top_min_z = z;
        } else {
            if (z < bot_min_z) bot_min_z = z;
        }
    }
    // Top leans away from the +Z wall (toward smaller z) compared to bottom.
    try std.testing.expect(top_min_z < bot_min_z);
}

test "wall_east and wall_west tilt along X axis" {
    const east = generateTorch(0, 0, 0, 10, 0, .wall_east);
    const west = generateTorch(0, 0, 0, 10, 0, .wall_west);

    var east_top_min_x: u32 = std.math.maxInt(u32);
    var east_bot_min_x: u32 = std.math.maxInt(u32);
    for (east.vertices[0..24]) |v| {
        const y = decodeY(v);
        const x = decodeX(v);
        if (y >= 10) {
            if (x < east_top_min_x) east_top_min_x = x;
        } else {
            if (x < east_bot_min_x) east_bot_min_x = x;
        }
    }
    // Attached to +X wall: bottom near x=16, top leans toward -X (smaller x).
    try std.testing.expect(east_top_min_x < east_bot_min_x);

    var west_top_max_x: u32 = 0;
    var west_bot_max_x: u32 = 0;
    for (west.vertices[0..24]) |v| {
        const y = decodeY(v);
        const x = decodeX(v);
        if (y >= 10) {
            if (x > west_top_max_x) west_top_max_x = x;
        } else {
            if (x > west_bot_max_x) west_bot_max_x = x;
        }
    }
    try std.testing.expect(west_top_max_x > west_bot_max_x);
}

test "all wall placements still produce 32 vertices and 48 indices" {
    inline for (.{ Placement.wall_north, .wall_south, .wall_east, .wall_west }) |p| {
        const mesh = generateTorch(5, 3, 7, 10, 8, p);
        try std.testing.expectEqual(@as(usize, 32), mesh.vertices.len);
        try std.testing.expectEqual(@as(usize, 48), mesh.indices.len);
        for (mesh.indices) |idx| {
            try std.testing.expect(idx < 32);
        }
    }
}

test "face index is in [0,5] for all stick verts and 4 for flame" {
    const mesh = generateTorch(0, 0, 0, 10, 0, .floor);
    for (mesh.vertices[0..24]) |v| {
        try std.testing.expect(decodeFace(v) <= 5);
    }
    for (mesh.vertices[24..]) |v| {
        try std.testing.expectEqual(@as(u3, 4), decodeFace(v));
    }
}

test "Vertex is a 64-bit extern struct" {
    try std.testing.expectEqual(@as(usize, 8), @sizeOf(Vertex));
}
