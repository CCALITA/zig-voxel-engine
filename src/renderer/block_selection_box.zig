const std = @import("std");

/// Vertex for selection wireframe and break-progress overlays.
pub const SelectionVertex = struct {
    x: f32,
    y: f32,
    z: f32,
    r: f32,
    g: f32,
    b: f32,
    a: f32,
};

const WireframeResult = struct {
    verts: [96]SelectionVertex,
    count: u32,
};

const BreakOverlayResult = struct {
    verts: [24]SelectionVertex,
    count: u32,
};

// Wireframe colour: black at 40% opacity.
const wire_r: f32 = 0.0;
const wire_g: f32 = 0.0;
const wire_b: f32 = 0.0;
const wire_a: f32 = 0.4;

// Half-thickness of each wireframe edge quad (0.01 width total).
const half_t: f32 = 0.005;

// Outset to prevent z-fighting with the block face.
const outset: f32 = 0.001;

/// A single edge described by its two endpoints and the axis-aligned
/// expansion direction used to give the line-segment visible width.
const Edge = struct {
    ax: f32,
    ay: f32,
    az: f32,
    bx: f32,
    by: f32,
    bz: f32,
    ex: f32,
    ey: f32,
    ez: f32,
};

/// The 12 edges of a unit cube, each with an expansion direction
/// perpendicular to the edge so the quad faces outward.
const edges = [12]Edge{
    // 4 edges along X
    .{ .ax = 0, .ay = 0, .az = 0, .bx = 1, .by = 0, .bz = 0, .ex = 0, .ey = 0, .ez = -1 },
    .{ .ax = 0, .ay = 0, .az = 1, .bx = 1, .by = 0, .bz = 1, .ex = 0, .ey = 0, .ez = 1 },
    .{ .ax = 0, .ay = 1, .az = 0, .bx = 1, .by = 1, .bz = 0, .ex = 0, .ey = 0, .ez = -1 },
    .{ .ax = 0, .ay = 1, .az = 1, .bx = 1, .by = 1, .bz = 1, .ex = 0, .ey = 0, .ez = 1 },
    // 4 edges along Y
    .{ .ax = 0, .ay = 0, .az = 0, .bx = 0, .by = 1, .bz = 0, .ex = -1, .ey = 0, .ez = 0 },
    .{ .ax = 1, .ay = 0, .az = 0, .bx = 1, .by = 1, .bz = 0, .ex = 1, .ey = 0, .ez = 0 },
    .{ .ax = 0, .ay = 0, .az = 1, .bx = 0, .by = 1, .bz = 1, .ex = -1, .ey = 0, .ez = 0 },
    .{ .ax = 1, .ay = 0, .az = 1, .bx = 1, .by = 1, .bz = 1, .ex = 1, .ey = 0, .ez = 0 },
    // 4 edges along Z
    .{ .ax = 0, .ay = 0, .az = 0, .bx = 0, .by = 0, .bz = 1, .ex = -1, .ey = 0, .ez = 0 },
    .{ .ax = 1, .ay = 0, .az = 0, .bx = 1, .by = 0, .bz = 1, .ex = 1, .ey = 0, .ez = 0 },
    .{ .ax = 0, .ay = 1, .az = 0, .bx = 0, .by = 1, .bz = 1, .ex = -1, .ey = 0, .ez = 0 },
    .{ .ax = 1, .ay = 1, .az = 0, .bx = 1, .by = 1, .bz = 1, .ex = 1, .ey = 0, .ez = 0 },
};

fn makeVert(x: f32, y: f32, z: f32, r: f32, g: f32, b: f32, a: f32) SelectionVertex {
    return .{ .x = x, .y = y, .z = z, .r = r, .g = g, .b = b, .a = a };
}

fn lerp(a: f32, b: f32, t: f32) f32 {
    return a + (b - a) * t;
}

/// Generate a wireframe selection box (12 edges as thin quads) around the
/// block whose minimum corner is at (bx, by, bz).
///
/// Each edge is a quad with 0.01 total width, outset 0.001 from the block
/// surface. Colour is black at alpha 0.4.
///
/// Returns 96 vertices (12 edges x 8 verts: two triangles per quad).
pub fn generateWireframe(bx: f32, by: f32, bz: f32) WireframeResult {
    const lo: f32 = -outset;
    const hi: f32 = 1.0 + outset;

    var result: WireframeResult = undefined;
    result.count = 96;

    for (edges, 0..) |e, i| {
        const base = i * 8;

        const x0 = bx + lerp(lo, hi, e.ax);
        const y0 = by + lerp(lo, hi, e.ay);
        const z0 = bz + lerp(lo, hi, e.az);
        const x1 = bx + lerp(lo, hi, e.bx);
        const y1 = by + lerp(lo, hi, e.by);
        const z1 = bz + lerp(lo, hi, e.bz);

        const dx = e.ex * half_t;
        const dy = e.ey * half_t;
        const dz = e.ez * half_t;

        const c0 = makeVert(x0 + dx, y0 + dy, z0 + dz, wire_r, wire_g, wire_b, wire_a);
        const c1 = makeVert(x1 + dx, y1 + dy, z1 + dz, wire_r, wire_g, wire_b, wire_a);
        const c2 = makeVert(x0 - dx, y0 - dy, z0 - dz, wire_r, wire_g, wire_b, wire_a);
        const c3 = makeVert(x1 - dx, y1 - dy, z1 - dz, wire_r, wire_g, wire_b, wire_a);

        // Triangle 1: c0, c1, c2
        result.verts[base + 0] = c0;
        result.verts[base + 1] = c1;
        result.verts[base + 2] = c2;
        result.verts[base + 3] = c2;
        // Triangle 2: c1, c3, c2
        result.verts[base + 4] = c1;
        result.verts[base + 5] = c3;
        result.verts[base + 6] = c2;
        result.verts[base + 7] = c2;
    }
    return result;
}

/// Face definition for the break-progress overlay.
const Face = struct {
    corners: [4][3]f32,
    normal: [3]f32,
};

const faces = [6]Face{
    // -Y (bottom)
    .{ .corners = .{ .{ 0, 0, 0 }, .{ 1, 0, 0 }, .{ 1, 0, 1 }, .{ 0, 0, 1 } }, .normal = .{ 0, -1, 0 } },
    // +Y (top)
    .{ .corners = .{ .{ 0, 1, 0 }, .{ 1, 1, 0 }, .{ 1, 1, 1 }, .{ 0, 1, 1 } }, .normal = .{ 0, 1, 0 } },
    // -Z (front)
    .{ .corners = .{ .{ 0, 0, 0 }, .{ 1, 0, 0 }, .{ 1, 1, 0 }, .{ 0, 1, 0 } }, .normal = .{ 0, 0, -1 } },
    // +Z (back)
    .{ .corners = .{ .{ 0, 0, 1 }, .{ 1, 0, 1 }, .{ 1, 1, 1 }, .{ 0, 1, 1 } }, .normal = .{ 0, 0, 1 } },
    // -X (left)
    .{ .corners = .{ .{ 0, 0, 0 }, .{ 0, 0, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 0 } }, .normal = .{ -1, 0, 0 } },
    // +X (right)
    .{ .corners = .{ .{ 1, 0, 0 }, .{ 1, 0, 1 }, .{ 1, 1, 1 }, .{ 1, 1, 0 } }, .normal = .{ 1, 0, 0 } },
};

/// Generate 6 face overlays that darken with block-breaking progress.
///
/// Each face is a translucent dark quad whose opacity increases with
/// `progress` (0.0 = barely visible, 1.0 = fully dark).
///
/// Returns 24 vertices (6 faces x 4 verts).
pub fn generateBreakOverlay(bx: f32, by: f32, bz: f32, progress: f32) BreakOverlayResult {
    const clamped = std.math.clamp(progress, 0.0, 1.0);

    const base_alpha: f32 = 0.15;
    const alpha = base_alpha + (0.55 * clamped);
    const shade = 0.2 * (1.0 - clamped);

    var result: BreakOverlayResult = undefined;
    result.count = 24;

    for (faces, 0..) |face, fi| {
        const base = fi * 4;
        const offset_x = face.normal[0] * outset;
        const offset_y = face.normal[1] * outset;
        const offset_z = face.normal[2] * outset;
        for (0..4) |ci| {
            result.verts[base + ci] = makeVert(
                bx + face.corners[ci][0] + offset_x,
                by + face.corners[ci][1] + offset_y,
                bz + face.corners[ci][2] + offset_z,
                shade,
                shade,
                shade,
                alpha,
            );
        }
    }

    return result;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "generateWireframe returns 96 vertices" {
    const wf = generateWireframe(0, 0, 0);
    try std.testing.expectEqual(@as(u32, 96), wf.count);
}

test "wireframe vertices use black colour with 0.4 alpha" {
    const wf = generateWireframe(5.0, 10.0, 3.0);
    for (0..wf.count) |i| {
        const v = wf.verts[i];
        try std.testing.expectApproxEqAbs(@as(f32, 0.0), v.r, 0.001);
        try std.testing.expectApproxEqAbs(@as(f32, 0.0), v.g, 0.001);
        try std.testing.expectApproxEqAbs(@as(f32, 0.0), v.b, 0.001);
        try std.testing.expectApproxEqAbs(@as(f32, 0.4), v.a, 0.001);
    }
}

test "wireframe vertices stay within outset bounds" {
    const bx: f32 = 7.0;
    const by: f32 = 64.0;
    const bz: f32 = -3.0;
    const margin: f32 = 0.01;
    const wf = generateWireframe(bx, by, bz);
    for (0..wf.count) |i| {
        const v = wf.verts[i];
        try std.testing.expect(v.x >= bx - margin and v.x <= bx + 1.0 + margin);
        try std.testing.expect(v.y >= by - margin and v.y <= by + 1.0 + margin);
        try std.testing.expect(v.z >= bz - margin and v.z <= bz + 1.0 + margin);
    }
}

test "wireframe at origin has vertices near zero and one" {
    const wf = generateWireframe(0, 0, 0);
    var has_near_zero = false;
    var has_near_one = false;
    for (0..wf.count) |i| {
        if (wf.verts[i].x < 0.01) has_near_zero = true;
        if (wf.verts[i].x > 0.99) has_near_one = true;
    }
    try std.testing.expect(has_near_zero);
    try std.testing.expect(has_near_one);
}

test "wireframe produces 12 distinct edge quads" {
    const wf = generateWireframe(0, 0, 0);
    // 12 edges x 8 verts = 96 total; verify each group of 8 forms two triangles
    for (0..12) |edge_idx| {
        const base = edge_idx * 8;
        // Triangle 1 degenerate vertex equals c2
        try std.testing.expectApproxEqAbs(wf.verts[base + 2].x, wf.verts[base + 3].x, 0.0001);
        try std.testing.expectApproxEqAbs(wf.verts[base + 2].y, wf.verts[base + 3].y, 0.0001);
        try std.testing.expectApproxEqAbs(wf.verts[base + 2].z, wf.verts[base + 3].z, 0.0001);
        // Triangle 2 degenerate vertex equals c2
        try std.testing.expectApproxEqAbs(wf.verts[base + 6].x, wf.verts[base + 7].x, 0.0001);
        try std.testing.expectApproxEqAbs(wf.verts[base + 6].y, wf.verts[base + 7].y, 0.0001);
        try std.testing.expectApproxEqAbs(wf.verts[base + 6].z, wf.verts[base + 7].z, 0.0001);
    }
}

test "wireframe offset shifts all vertices by block position" {
    const wf_origin = generateWireframe(0, 0, 0);
    const wf_offset = generateWireframe(10.0, 20.0, 30.0);
    for (0..wf_origin.count) |i| {
        try std.testing.expectApproxEqAbs(wf_origin.verts[i].x + 10.0, wf_offset.verts[i].x, 0.0001);
        try std.testing.expectApproxEqAbs(wf_origin.verts[i].y + 20.0, wf_offset.verts[i].y, 0.0001);
        try std.testing.expectApproxEqAbs(wf_origin.verts[i].z + 30.0, wf_offset.verts[i].z, 0.0001);
    }
}

test "generateBreakOverlay returns 24 vertices" {
    const bo = generateBreakOverlay(0, 0, 0, 0.5);
    try std.testing.expectEqual(@as(u32, 24), bo.count);
}

test "break overlay alpha increases with progress" {
    const bo_lo = generateBreakOverlay(0, 0, 0, 0.0);
    const bo_hi = generateBreakOverlay(0, 0, 0, 1.0);
    try std.testing.expect(bo_hi.verts[0].a > bo_lo.verts[0].a);
}

test "break overlay clamps out-of-range progress" {
    const bo_neg = generateBreakOverlay(0, 0, 0, -5.0);
    const bo_zero = generateBreakOverlay(0, 0, 0, 0.0);
    try std.testing.expectApproxEqAbs(bo_zero.verts[0].a, bo_neg.verts[0].a, 0.001);

    const bo_over = generateBreakOverlay(0, 0, 0, 10.0);
    const bo_one = generateBreakOverlay(0, 0, 0, 1.0);
    try std.testing.expectApproxEqAbs(bo_one.verts[0].a, bo_over.verts[0].a, 0.001);
}

test "break overlay shade darkens toward full destruction" {
    const bo_start = generateBreakOverlay(0, 0, 0, 0.0);
    const bo_end = generateBreakOverlay(0, 0, 0, 1.0);
    try std.testing.expect(bo_start.verts[0].r > bo_end.verts[0].r);
}

test "break overlay covers all six faces" {
    const bo = generateBreakOverlay(0, 0, 0, 0.5);
    // Each face has 4 verts; verify we have distinct face groups
    // by checking that not all vertices share the same position.
    var unique_positions: u32 = 0;
    for (0..6) |fi| {
        const base = fi * 4;
        const v0 = bo.verts[base];
        const v1 = bo.verts[base + 1];
        if (@abs(v0.x - v1.x) > 0.001 or @abs(v0.y - v1.y) > 0.001 or @abs(v0.z - v1.z) > 0.001) {
            unique_positions += 1;
        }
    }
    try std.testing.expect(unique_positions == 6);
}

test "break overlay at half progress has intermediate alpha" {
    const bo = generateBreakOverlay(0, 0, 0, 0.5);
    const alpha = bo.verts[0].a;
    // Expected: 0.15 + 0.55 * 0.5 = 0.425
    try std.testing.expectApproxEqAbs(@as(f32, 0.425), alpha, 0.01);
}

test "break overlay vertices offset by block position" {
    const bo_origin = generateBreakOverlay(0, 0, 0, 0.5);
    const bo_offset = generateBreakOverlay(5.0, 10.0, 15.0, 0.5);
    for (0..bo_origin.count) |i| {
        try std.testing.expectApproxEqAbs(bo_origin.verts[i].x + 5.0, bo_offset.verts[i].x, 0.01);
        try std.testing.expectApproxEqAbs(bo_origin.verts[i].y + 10.0, bo_offset.verts[i].y, 0.01);
        try std.testing.expectApproxEqAbs(bo_origin.verts[i].z + 15.0, bo_offset.verts[i].z, 0.01);
    }
}
