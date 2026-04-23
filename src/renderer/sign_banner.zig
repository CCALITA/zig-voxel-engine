const std = @import("std");

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

pub const SignVertex = struct {
    x: f32,
    y: f32,
    z: f32,
    u: f32,
    v: f32,
    r: f32,
    g: f32,
    b: f32,
};

pub const SignType = enum {
    standing,
    wall,
};

// ---------------------------------------------------------------------------
// Facing helpers
// ---------------------------------------------------------------------------

/// Return (cos, sin) for the four cardinal directions encoded by a u2.
/// 0 = south (+Z), 1 = west (+X), 2 = north (-Z), 3 = east (-X).
fn facingCosSin(facing: u2) struct { cos: f32, sin: f32 } {
    const angles = [4]f32{
        0.0,                        // south
        std.math.pi * 0.5,         // west
        std.math.pi,               // north
        std.math.pi * 1.5,         // east
    };
    const angle = angles[facing];
    return .{ .cos = @cos(angle), .sin = @sin(angle) };
}

// ---------------------------------------------------------------------------
// Quad builder
// ---------------------------------------------------------------------------

/// Write two-triangle (6-vertex) quad into `out` starting at `start`.
/// Vertices are in CCW order when viewed from the front.
fn writeQuad(
    out: []SignVertex,
    start: u32,
    corners: [4][3]f32,
    uvs: [4][2]f32,
    r: f32,
    g: f32,
    b: f32,
) u32 {
    const indices = [6]u8{ 0, 1, 2, 2, 3, 0 };
    var idx = start;
    for (indices) |ci| {
        const c = corners[ci];
        const uv = uvs[ci];
        out[idx] = .{
            .x = c[0],
            .y = c[1],
            .z = c[2],
            .u = uv[0],
            .v = uv[1],
            .r = r,
            .g = g,
            .b = b,
        };
        idx += 1;
    }
    return idx;
}

// ---------------------------------------------------------------------------
// Sign generation
// ---------------------------------------------------------------------------

/// Sign dimensions in blocks (pixel counts / 16).
const sign_board_w: f32 = 16.0 / 16.0; // 1.0
const sign_board_h: f32 = 12.0 / 16.0; // 0.75
const sign_board_d: f32 = 2.0 / 16.0; // 0.125
const sign_stick_w: f32 = 2.0 / 16.0;

/// Default UV coordinates for a quad (shared by all quads).
const default_uvs = [4][2]f32{ .{ 0, 0 }, .{ 1, 0 }, .{ 1, 1 }, .{ 0, 1 } };

const SignResult = struct { verts: [32]SignVertex, count: u32 };

/// Generate vertices for a sign (flat board on a stick).
/// Standing signs rest on the ground; wall signs are flush against a wall.
/// Returns a fixed-size array with the actual vertex count in `count`.
///
/// Standing layout (bottom up):
///   stick: from y to y+0.5, centred on block
///   board: from y+0.5 to y+1.25, centred on block
///
/// Wall layout:
///   board only, centred at (x, y+0.5, z), offset towards the wall face.
pub fn generateSign(x: f32, y: f32, z: f32, facing: u2, sign_type: SignType) SignResult {
    var result = SignResult{
        .verts = undefined,
        .count = 0,
    };
    const out: []SignVertex = &result.verts;

    const cs = facingCosSin(facing);
    const board_r: f32 = 0.55;
    const board_g: f32 = 0.35;
    const board_b: f32 = 0.15;
    const stick_r: f32 = 0.45;
    const stick_g: f32 = 0.30;
    const stick_b: f32 = 0.12;

    var idx: u32 = 0;

    switch (sign_type) {
        .standing => {
            // Stick: centred horizontally, from y to y+0.5
            const stick_h: f32 = 0.5;
            const stick_cy: f32 = y + stick_h * 0.5;
            if (idx + 6 <= out.len) {
                const shw = sign_stick_w * 0.5;
                const shh = stick_h * 0.5;
                const corners = rotateQuadCorners(
                    .{ -shw, stick_cy - shh, 0 },
                    .{ shw, stick_cy - shh, 0 },
                    .{ shw, stick_cy + shh, 0 },
                    .{ -shw, stick_cy + shh, 0 },
                    cs.cos,
                    cs.sin,
                    x,
                    z,
                );
                idx = writeQuad(out, idx, corners, default_uvs, stick_r, stick_g, stick_b);
            }
            // Board front and back faces share half-widths and centre Y.
            const bhw = sign_board_w * 0.5;
            const bhh = sign_board_h * 0.5;
            const board_cy: f32 = y + 0.5 + sign_board_h * 0.5;
            // Board front face
            if (idx + 6 <= out.len) {
                const corners = rotateQuadCorners(
                    .{ -bhw, board_cy - bhh, 0 },
                    .{ bhw, board_cy - bhh, 0 },
                    .{ bhw, board_cy + bhh, 0 },
                    .{ -bhw, board_cy + bhh, 0 },
                    cs.cos,
                    cs.sin,
                    x,
                    z,
                );
                idx = writeQuad(out, idx, corners, default_uvs, board_r, board_g, board_b);
            }
            // Board back face
            if (idx + 6 <= out.len) {
                const corners = rotateQuadCorners(
                    .{ bhw, board_cy - bhh, sign_board_d },
                    .{ -bhw, board_cy - bhh, sign_board_d },
                    .{ -bhw, board_cy + bhh, sign_board_d },
                    .{ bhw, board_cy + bhh, sign_board_d },
                    cs.cos,
                    cs.sin,
                    x,
                    z,
                );
                idx = writeQuad(out, idx, corners, default_uvs, board_r * 0.85, board_g * 0.85, board_b * 0.85);
            }
        },
        .wall => {
            // Wall-mounted: board only, offset toward the wall face.
            const wall_offset: f32 = -(0.5 - sign_board_d * 0.5);
            const board_cy: f32 = y + 0.5;
            const bhw = sign_board_w * 0.5;
            const bhh = sign_board_h * 0.5;
            // Front face
            if (idx + 6 <= out.len) {
                const corners = rotateQuadCorners(
                    .{ -bhw, board_cy - bhh, wall_offset },
                    .{ bhw, board_cy - bhh, wall_offset },
                    .{ bhw, board_cy + bhh, wall_offset },
                    .{ -bhw, board_cy + bhh, wall_offset },
                    cs.cos,
                    cs.sin,
                    x,
                    z,
                );
                idx = writeQuad(out, idx, corners, default_uvs, board_r, board_g, board_b);
            }
            // Back face
            if (idx + 6 <= out.len) {
                const back_z = wall_offset + sign_board_d;
                const corners = rotateQuadCorners(
                    .{ bhw, board_cy - bhh, back_z },
                    .{ -bhw, board_cy - bhh, back_z },
                    .{ -bhw, board_cy + bhh, back_z },
                    .{ bhw, board_cy + bhh, back_z },
                    cs.cos,
                    cs.sin,
                    x,
                    z,
                );
                idx = writeQuad(out, idx, corners, default_uvs, board_r * 0.85, board_g * 0.85, board_b * 0.85);
            }
        },
    }

    result.count = idx;
    return result;
}

// ---------------------------------------------------------------------------
// Banner generation
// ---------------------------------------------------------------------------

/// Banner cloth dimensions in blocks (pixel counts / 16).
const banner_cloth_w: f32 = 20.0 / 16.0; // 1.25
const banner_cloth_h: f32 = 40.0 / 16.0; // 2.5
const banner_stick_h: f32 = 0.5;

/// Dye colour palette (16 colours indexed by u4).
const dye_colors = [16][3]f32{
    .{ 1.0, 1.0, 1.0 }, // 0  white
    .{ 0.85, 0.52, 0.15 }, // 1  orange
    .{ 0.70, 0.30, 0.70 }, // 2  magenta
    .{ 0.40, 0.60, 0.85 }, // 3  light blue
    .{ 0.90, 0.90, 0.20 }, // 4  yellow
    .{ 0.50, 0.80, 0.10 }, // 5  lime
    .{ 0.85, 0.55, 0.65 }, // 6  pink
    .{ 0.30, 0.30, 0.30 }, // 7  gray
    .{ 0.60, 0.60, 0.60 }, // 8  light gray
    .{ 0.15, 0.60, 0.60 }, // 9  cyan
    .{ 0.50, 0.25, 0.70 }, // 10 purple
    .{ 0.20, 0.30, 0.70 }, // 11 blue
    .{ 0.40, 0.25, 0.15 }, // 12 brown
    .{ 0.30, 0.50, 0.10 }, // 13 green
    .{ 0.70, 0.20, 0.20 }, // 14 red
    .{ 0.10, 0.10, 0.10 }, // 15 black
};

const BannerResult = struct { verts: [16]SignVertex, count: u32 };

/// Generate vertices for a banner (tall coloured cloth on a stick).
/// The cloth is a single quad with a slight wave (sinusoidal x-offset).
/// `color` is a dye index (0..15).
pub fn generateBanner(x: f32, y: f32, z: f32, facing: u2, color: u4) BannerResult {
    var result = BannerResult{
        .verts = undefined,
        .count = 0,
    };
    const out: []SignVertex = &result.verts;

    const cs = facingCosSin(facing);
    const rgb = dye_colors[color];

    var idx: u32 = 0;

    // Stick quad (simplified front face)
    const stick_top: f32 = y + banner_stick_h + banner_cloth_h;
    const stick_bot: f32 = y + banner_cloth_h;
    if (idx + 6 <= out.len) {
        const shw: f32 = sign_stick_w * 0.5;
        const corners = rotateQuadCorners(
            .{ -shw, stick_bot, 0 },
            .{ shw, stick_bot, 0 },
            .{ shw, stick_top, 0 },
            .{ -shw, stick_top, 0 },
            cs.cos,
            cs.sin,
            x,
            z,
        );
        idx = writeQuad(out, idx, corners, default_uvs, 0.45, 0.30, 0.12);
    }

    // Cloth quad with slight wave: bottom corners offset in Z by a small amount.
    const cloth_top: f32 = y + banner_cloth_h;
    const cloth_bot: f32 = y;
    const chw: f32 = banner_cloth_w * 0.5;
    const wave: f32 = 0.06; // slight wave offset on bottom corners

    if (idx + 6 <= out.len) {
        const corners = rotateQuadCorners(
            .{ -chw, cloth_bot, wave },
            .{ chw, cloth_bot, -wave },
            .{ chw, cloth_top, 0 },
            .{ -chw, cloth_top, 0 },
            cs.cos,
            cs.sin,
            x,
            z,
        );
        idx = writeQuad(out, idx, corners, default_uvs, rgb[0], rgb[1], rgb[2]);
    }

    result.count = idx;
    return result;
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/// Rotate four local-space corners around Y and translate to world XZ.
fn rotateQuadCorners(
    c0: [3]f32,
    c1: [3]f32,
    c2: [3]f32,
    c3: [3]f32,
    cos_a: f32,
    sin_a: f32,
    wx: f32,
    wz: f32,
) [4][3]f32 {
    const raw = [4][3]f32{ c0, c1, c2, c3 };
    var result: [4][3]f32 = undefined;
    for (raw, 0..) |pt, i| {
        const rx = pt[0] * cos_a - pt[2] * sin_a;
        const rz = pt[0] * sin_a + pt[2] * cos_a;
        result[i] = .{ wx + rx, pt[1], wz + rz };
    }
    return result;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "generateSign standing produces expected vertex count" {
    const result = generateSign(0, 0, 0, 0, .standing);
    // Standing sign: stick front (6) + board front (6) + board back (6) = 18
    try std.testing.expectEqual(@as(u32, 18), result.count);
}

test "generateSign wall produces expected vertex count" {
    const result = generateSign(0, 0, 0, 0, .wall);
    // Wall sign: board front (6) + board back (6) = 12
    try std.testing.expectEqual(@as(u32, 12), result.count);
}

test "generateBanner produces expected vertex count" {
    const result = generateBanner(0, 0, 0, 0, 0);
    // Banner: stick quad (6) + cloth quad (6) = 12
    try std.testing.expectEqual(@as(u32, 12), result.count);
}

test "generateSign positions offset by world coordinates" {
    const origin = generateSign(0, 0, 0, 0, .standing);
    const shifted = generateSign(10, 20, 30, 0, .standing);

    for (origin.verts[0..origin.count], shifted.verts[0..shifted.count]) |v0, v1| {
        try std.testing.expectApproxEqAbs(v0.x + 10.0, v1.x, 0.001);
        try std.testing.expectApproxEqAbs(v0.y + 20.0, v1.y, 0.001);
        try std.testing.expectApproxEqAbs(v0.z + 30.0, v1.z, 0.001);
    }
}

test "generateBanner positions offset by world coordinates" {
    const origin = generateBanner(0, 0, 0, 0, 5);
    const shifted = generateBanner(10, 20, 30, 0, 5);

    for (origin.verts[0..origin.count], shifted.verts[0..shifted.count]) |v0, v1| {
        try std.testing.expectApproxEqAbs(v0.x + 10.0, v1.x, 0.001);
        try std.testing.expectApproxEqAbs(v0.y + 20.0, v1.y, 0.001);
        try std.testing.expectApproxEqAbs(v0.z + 30.0, v1.z, 0.001);
    }
}

test "facing rotates sign XZ coordinates" {
    const south = generateSign(0, 0, 0, 0, .standing);
    const west = generateSign(0, 0, 0, 1, .standing);

    // Y should be the same, but at least some XZ should differ
    var xz_differs = false;
    for (south.verts[0..south.count], west.verts[0..west.count]) |v0, v1| {
        try std.testing.expectApproxEqAbs(v0.y, v1.y, 0.001);
        if (@abs(v0.x - v1.x) > 0.001 or @abs(v0.z - v1.z) > 0.001) {
            xz_differs = true;
        }
    }
    try std.testing.expect(xz_differs);
}

test "banner colour matches dye index" {
    // Red banner (index 14) should have r=0.7, g=0.2, b=0.2 on cloth vertices
    const result = generateBanner(0, 0, 0, 0, 14);
    // Cloth quad starts at vertex index 6 (after stick quad)
    const cloth_start: u32 = 6;
    for (result.verts[cloth_start..result.count]) |v| {
        try std.testing.expectApproxEqAbs(@as(f32, 0.70), v.r, 0.001);
        try std.testing.expectApproxEqAbs(@as(f32, 0.20), v.g, 0.001);
        try std.testing.expectApproxEqAbs(@as(f32, 0.20), v.b, 0.001);
    }
}

test "banner wave offsets bottom corners in Z" {
    // Generate banner facing south (0) so Z is not rotated.
    const result = generateBanner(0, 0, 0, 0, 0);
    // Cloth quad is vertices 6..11. The quad corners are:
    //   [0] bottom-left, [1] bottom-right, [2] top-right, [3] top-left
    // Mapped through triangle indices: 0,1,2, 2,3,0
    // So verts[6]=c0, verts[7]=c1, verts[8]=c2(top-right), verts[9]=c2(dup), verts[10]=c3(top-left), verts[11]=c0(dup)
    const bl = result.verts[6]; // bottom-left
    const br = result.verts[7]; // bottom-right
    const tr = result.verts[8]; // top-right

    // Bottom corners should have non-zero Z offset (wave), top should be 0.
    try std.testing.expect(@abs(bl.z) > 0.01);
    try std.testing.expect(@abs(br.z) > 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), tr.z, 0.001);
}
