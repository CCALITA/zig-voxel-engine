const std = @import("std");

/// Vertex for wireframe highlight and break-progress overlays.
pub const HighlightVertex = struct {
    x: f32,
    y: f32,
    z: f32,
    r: f32,
    g: f32,
    b: f32,
    a: f32,
};

const HighlightResult = struct {
    verts: [96]HighlightVertex,
    count: u32,
};

const BreakResult = struct {
    verts: [24]HighlightVertex,
    count: u32,
};

// Wireframe colour: black at 40% opacity.
const wire_r: f32 = 0.0;
const wire_g: f32 = 0.0;
const wire_b: f32 = 0.0;
const wire_a: f32 = 0.4;

// Half-thickness of each wireframe edge quad.
const half_t: f32 = 0.005;

/// A single edge described by its two endpoints and the axis-aligned
/// expansion direction used to give the line-segment visible width.
const Edge = struct {
    /// Start point.
    ax: f32,
    ay: f32,
    az: f32,
    /// End point.
    bx: f32,
    by: f32,
    bz: f32,
    /// Expansion axis (one of x/y/z).  The quad is extruded +/- half_t
    /// along this axis.
    ex: f32,
    ey: f32,
    ez: f32,
};

/// The 12 edges of a unit cube (0..1 in each axis), each with an
/// expansion direction perpendicular to both the edge direction and
/// one of the other two axes, chosen so the quad faces outward.
const edges = [12]Edge{
    // --- 4 edges along X (bottom-front, bottom-back, top-front, top-back) ---
    .{ .ax = 0, .ay = 0, .az = 0, .bx = 1, .by = 0, .bz = 0, .ex = 0, .ey = 0, .ez = -1 },
    .{ .ax = 0, .ay = 0, .az = 1, .bx = 1, .by = 0, .bz = 1, .ex = 0, .ey = 0, .ez = 1 },
    .{ .ax = 0, .ay = 1, .az = 0, .bx = 1, .by = 1, .bz = 0, .ex = 0, .ey = 0, .ez = -1 },
    .{ .ax = 0, .ay = 1, .az = 1, .bx = 1, .by = 1, .bz = 1, .ex = 0, .ey = 0, .ez = 1 },
    // --- 4 edges along Y (front-left, front-right, back-left, back-right) ---
    .{ .ax = 0, .ay = 0, .az = 0, .bx = 0, .by = 1, .bz = 0, .ex = -1, .ey = 0, .ez = 0 },
    .{ .ax = 1, .ay = 0, .az = 0, .bx = 1, .by = 1, .bz = 0, .ex = 1, .ey = 0, .ez = 0 },
    .{ .ax = 0, .ay = 0, .az = 1, .bx = 0, .by = 1, .bz = 1, .ex = -1, .ey = 0, .ez = 0 },
    .{ .ax = 1, .ay = 0, .az = 1, .bx = 1, .by = 1, .bz = 1, .ex = 1, .ey = 0, .ez = 0 },
    // --- 4 edges along Z (bottom-left, bottom-right, top-left, top-right) ---
    .{ .ax = 0, .ay = 0, .az = 0, .bx = 0, .by = 0, .bz = 1, .ex = -1, .ey = 0, .ez = 0 },
    .{ .ax = 1, .ay = 0, .az = 0, .bx = 1, .by = 0, .bz = 1, .ex = 1, .ey = 0, .ez = 0 },
    .{ .ax = 0, .ay = 1, .az = 0, .bx = 0, .by = 1, .bz = 1, .ex = -1, .ey = 0, .ez = 0 },
    .{ .ax = 1, .ay = 1, .az = 0, .bx = 1, .by = 1, .bz = 1, .ex = 1, .ey = 0, .ez = 0 },
};

fn makeVert(x: f32, y: f32, z: f32, r: f32, g: f32, b: f32, a: f32) HighlightVertex {
    return HighlightVertex{ .x = x, .y = y, .z = z, .r = r, .g = g, .b = b, .a = a };
}

/// Generate a wireframe highlight (12 edges as thin quads) around the
/// block whose minimum corner is at (bx, by, bz).
///
/// Returns 96 vertices (12 edges x 4 verts per quad, with 2 triangles
/// implied per quad via index reuse).
pub fn generateHighlight(bx: f32, by: f32, bz: f32) HighlightResult {
    // Slight outset so the wireframe does not z-fight with the block face.
    const outset: f32 = 0.001;
    const lo: f32 = -outset;
    const hi: f32 = 1.0 + outset;

    var result: HighlightResult = undefined;
    result.count = 96;

    for (edges, 0..) |e, i| {
        const base = i * 8;

        // Map 0..1 edge coordinates into the outset range.
        const x0 = bx + lerp(lo, hi, e.ax);
        const y0 = by + lerp(lo, hi, e.ay);
        const z0 = bz + lerp(lo, hi, e.az);
        const x1 = bx + lerp(lo, hi, e.bx);
        const y1 = by + lerp(lo, hi, e.by);
        const z1 = bz + lerp(lo, hi, e.bz);

        const dx = e.ex * half_t;
        const dy = e.ey * half_t;
        const dz = e.ez * half_t;

        // Quad corners:
        //  c0 --- c1       c0 = start + offset
        //  |       |       c1 = end   + offset
        //  c2 --- c3       c2 = start - offset
        //                  c3 = end   - offset
        const c0 = makeVert(x0 + dx, y0 + dy, z0 + dz, wire_r, wire_g, wire_b, wire_a);
        const c1 = makeVert(x1 + dx, y1 + dy, z1 + dz, wire_r, wire_g, wire_b, wire_a);
        const c2 = makeVert(x0 - dx, y0 - dy, z0 - dz, wire_r, wire_g, wire_b, wire_a);
        const c3 = makeVert(x1 - dx, y1 - dy, z1 - dz, wire_r, wire_g, wire_b, wire_a);

        // Triangle 1: c0, c1, c2
        result.verts[base + 0] = c0;
        result.verts[base + 1] = c1;
        result.verts[base + 2] = c2;
        // Degenerate fourth vertex (duplicates c2) to pad to 4 per triangle.
        result.verts[base + 3] = c2;

        // Triangle 2: c1, c3, c2
        result.verts[base + 4] = c1;
        result.verts[base + 5] = c3;
        result.verts[base + 6] = c2;
        // Degenerate fourth vertex (duplicates c2) to pad to 4 per triangle.
        result.verts[base + 7] = c2;
    }
    return result;
}

fn lerp(a: f32, b: f32, t: f32) f32 {
    return a + (b - a) * t;
}

/// Face definition for break-progress overlay.
const Face = struct {
    /// Four corner positions (unit cube 0..1, offset by block pos at runtime).
    corners: [4][3]f32,
    /// Outward face normal in {-1, 0, +1} components.
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

/// Generate 6 face overlays that visualize block-breaking progress.
///
/// Each face is rendered as a translucent dark quad whose alpha is
/// proportional to `progress` (0.0 = invisible, 1.0 = fully cracked).
/// The colour darkens toward black as progress increases, simulating
/// the crack pattern seen in Minecraft.
///
/// Returns 24 vertices (6 faces x 4 verts).
pub fn generateBreakProgress(bx: f32, by: f32, bz: f32, progress: f32) BreakResult {
    const clamped = std.math.clamp(progress, 0.0, 1.0);

    // Slight outset so the overlay sits just above the block face.
    const outset: f32 = 0.001;

    // Crack pattern: dark overlay that becomes more opaque as the block
    // approaches full destruction.
    const base_alpha: f32 = 0.15;
    const alpha = base_alpha + (0.55 * clamped); // 0.15 .. 0.70
    const shade = 0.2 * (1.0 - clamped); // lighter at start, darker at end

    var result: BreakResult = undefined;
    result.count = 24;

    for (faces, 0..) |face, fi| {
        const base = fi * 4;
        // Push quad slightly outward along the pre-computed face normal.
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

test "generateHighlight returns 96 vertices" {
    const hl = generateHighlight(0, 0, 0);
    try std.testing.expectEqual(@as(u32, 96), hl.count);
}

test "highlight vertices use black colour with 0.4 alpha" {
    const hl = generateHighlight(5.0, 10.0, 3.0);
    for (0..hl.count) |i| {
        const v = hl.verts[i];
        try std.testing.expectApproxEqAbs(@as(f32, 0.0), v.r, 0.001);
        try std.testing.expectApproxEqAbs(@as(f32, 0.0), v.g, 0.001);
        try std.testing.expectApproxEqAbs(@as(f32, 0.0), v.b, 0.001);
        try std.testing.expectApproxEqAbs(@as(f32, 0.4), v.a, 0.001);
    }
}

test "highlight vertices are near the target block" {
    const bx: f32 = 7.0;
    const by: f32 = 64.0;
    const bz: f32 = -3.0;
    const margin: f32 = 0.01; // outset (0.001) + half_t (0.005) < margin
    const hl = generateHighlight(bx, by, bz);
    for (0..hl.count) |i| {
        const v = hl.verts[i];
        try std.testing.expect(v.x >= bx - margin and v.x <= bx + 1.0 + margin);
        try std.testing.expect(v.y >= by - margin and v.y <= by + 1.0 + margin);
        try std.testing.expect(v.z >= bz - margin and v.z <= bz + 1.0 + margin);
    }
}

test "generateBreakProgress returns 24 vertices" {
    const bp = generateBreakProgress(0, 0, 0, 0.5);
    try std.testing.expectEqual(@as(u32, 24), bp.count);
}

test "break progress alpha increases with progress" {
    const bp_lo = generateBreakProgress(0, 0, 0, 0.0);
    const bp_hi = generateBreakProgress(0, 0, 0, 1.0);

    // Pick a representative vertex from each.
    const alpha_lo = bp_lo.verts[0].a;
    const alpha_hi = bp_hi.verts[0].a;
    try std.testing.expect(alpha_hi > alpha_lo);
}

test "break progress clamps out-of-range values" {
    // Progress below 0 should behave like 0.
    const bp_neg = generateBreakProgress(0, 0, 0, -5.0);
    const bp_zero = generateBreakProgress(0, 0, 0, 0.0);
    try std.testing.expectApproxEqAbs(bp_zero.verts[0].a, bp_neg.verts[0].a, 0.001);

    // Progress above 1 should behave like 1.
    const bp_over = generateBreakProgress(0, 0, 0, 10.0);
    const bp_one = generateBreakProgress(0, 0, 0, 1.0);
    try std.testing.expectApproxEqAbs(bp_one.verts[0].a, bp_over.verts[0].a, 0.001);
}

test "break progress shade darkens toward full destruction" {
    const bp_start = generateBreakProgress(0, 0, 0, 0.0);
    const bp_end = generateBreakProgress(0, 0, 0, 1.0);

    // At progress 0 the shade (r/g/b) should be lighter than at progress 1.
    try std.testing.expect(bp_start.verts[0].r > bp_end.verts[0].r);
}
