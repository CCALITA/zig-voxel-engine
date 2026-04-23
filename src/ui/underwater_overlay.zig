/// Underwater overlay renderer.
/// Produces a full-screen blue tint that darkens with depth, plus small white
/// bubble particles that drift upward. The overlay uses untextured quads
/// (u = -1, v = -1) so the fragment shader takes the solid-colour branch.
///
/// `depth` ranges from 0.0 (surface) to 1.0 (deep ocean). At the surface the
/// tint is barely visible (alpha 0.1); at maximum depth it is prominent
/// (alpha 0.5). The bottom of the screen is always darker than the top to
/// simulate light attenuation through the water column.
const std = @import("std");

// ── Vertex type (mirrors ui_pipeline.UiVertex) ──────────────────────────

pub const UiVertex = extern struct {
    pos_x: f32,
    pos_y: f32,
    r: f32,
    g: f32,
    b: f32,
    a: f32,
    u: f32,
    v: f32,
};

// ── Overlay constants ───────────────────────────────────────────────────

/// Base water tint colour (deep blue).
const tint_r: f32 = 0.1;
const tint_g: f32 = 0.15;
const tint_b: f32 = 0.4;

/// Alpha at surface (depth = 0) and at maximum depth (depth = 1).
const alpha_surface: f32 = 0.1;
const alpha_deep: f32 = 0.5;

/// Extra alpha added to the bottom half of the screen for the depth gradient.
const bottom_extra_alpha: f32 = 0.15;

/// Number of horizontal gradient bands that approximate the vertical gradient.
const gradient_bands: u32 = 4;

// ── Bubble constants ────────────────────────────────────────────────────

/// Bubble particles rendered as small quad "circles".
const bubble_count: u32 = 5;

/// Each bubble is defined by a deterministic seed that controls its horizontal
/// position and vertical phase so it appears to drift upward.
const BubbleSeed = struct {
    /// Horizontal position as a fraction of screen width [0..1].
    x_frac: f32,
    /// Vertical phase offset [0..1] so bubbles start at different heights.
    phase: f32,
    /// Size in pixels.
    size: f32,
};

const bubble_seeds = [bubble_count]BubbleSeed{
    .{ .x_frac = 0.15, .phase = 0.0, .size = 4.0 },
    .{ .x_frac = 0.35, .phase = 0.25, .size = 3.0 },
    .{ .x_frac = 0.55, .phase = 0.5, .size = 5.0 },
    .{ .x_frac = 0.75, .phase = 0.75, .size = 3.5 },
    .{ .x_frac = 0.90, .phase = 0.4, .size = 4.5 },
};

/// Bubble colour (white, semi-transparent).
const bubble_col = [4]f32{ 1.0, 1.0, 1.0, 0.35 };

// ── Quad helper ─────────────────────────────────────────────────────────

/// Emit a solid-colour quad (2 triangles, 6 vertices). UV = -1 (untextured).
fn addQuad(
    verts: []UiVertex,
    start: u32,
    x: f32,
    y: f32,
    w: f32,
    h: f32,
    r: f32,
    g: f32,
    b: f32,
    a: f32,
) u32 {
    if (start + 6 > verts.len) return start;
    const x1 = x + w;
    const y1 = y + h;

    verts[start + 0] = .{ .pos_x = x, .pos_y = y, .r = r, .g = g, .b = b, .a = a, .u = -1, .v = -1 };
    verts[start + 1] = .{ .pos_x = x1, .pos_y = y, .r = r, .g = g, .b = b, .a = a, .u = -1, .v = -1 };
    verts[start + 2] = .{ .pos_x = x1, .pos_y = y1, .r = r, .g = g, .b = b, .a = a, .u = -1, .v = -1 };
    verts[start + 3] = .{ .pos_x = x, .pos_y = y, .r = r, .g = g, .b = b, .a = a, .u = -1, .v = -1 };
    verts[start + 4] = .{ .pos_x = x1, .pos_y = y1, .r = r, .g = g, .b = b, .a = a, .u = -1, .v = -1 };
    verts[start + 5] = .{ .pos_x = x, .pos_y = y1, .r = r, .g = g, .b = b, .a = a, .u = -1, .v = -1 };

    return start + 6;
}

// ── Alpha helpers ───────────────────────────────────────────────────────

/// Compute the base overlay alpha from depth, linearly interpolated between
/// `alpha_surface` and `alpha_deep`.  Caller must clamp depth to [0, 1].
fn baseAlpha(depth: f32) f32 {
    return alpha_surface + (alpha_deep - alpha_surface) * depth;
}

/// Compute the alpha for a given vertical band.  Bands closer to the bottom
/// of the screen receive additional alpha to simulate light falloff.
fn bandAlpha(base: f32, band_index: u32, total_bands: u32) f32 {
    const t = @as(f32, @floatFromInt(band_index)) / @as(f32, @floatFromInt(total_bands));
    return base + bottom_extra_alpha * t;
}

// ── Bubble helpers ──────────────────────────────────────────────────────

/// Compute a bubble's vertical position.  `depth` controls how many bubbles
/// are visible and their spread — deeper water shows more bubbles rising
/// from lower on the screen.
fn bubbleY(seed: BubbleSeed, sh: f32, depth: f32) f32 {
    // At low depth bubbles cluster near the top; at high depth they span
    // the full screen height.  The phase shifts each bubble so they are
    // staggered vertically.
    const span = 0.3 + 0.7 * depth;
    const raw = seed.phase * span;
    return sh * (1.0 - raw) - seed.size;
}

/// Determine how many bubbles to render based on depth.
/// depth < 0.2 → 3, depth < 0.6 → 4, else 5.
fn activeBubbleCount(depth: f32) u32 {
    const d = std.math.clamp(depth, 0.0, 1.0);
    if (d < 0.2) return 3;
    if (d < 0.6) return 4;
    return 5;
}

// ── Public render entry point ───────────────────────────────────────────

/// Render the underwater overlay into the vertex buffer.
/// Returns the final vertex index (vertices written from `start` to return
/// value).
///
/// * `depth` — 0.0 at the water surface, 1.0 at maximum depth.
pub fn render(verts: []UiVertex, start: u32, sw: f32, sh: f32, depth: f32) u32 {
    var c = start;
    const d = std.math.clamp(depth, 0.0, 1.0);
    const base = baseAlpha(d);

    // ── Gradient tint bands (top → bottom, progressively darker) ────
    const band_h = sh / @as(f32, @floatFromInt(gradient_bands));
    var band: u32 = 0;
    while (band < gradient_bands) : (band += 1) {
        const y = @as(f32, @floatFromInt(band)) * band_h;
        const a = bandAlpha(base, band, gradient_bands);
        c = addQuad(verts, c, 0, y, sw, band_h, tint_r, tint_g, tint_b, a);
    }

    // ── Bubble particles ────────────────────────────────────────────
    const count = activeBubbleCount(d);
    const ba = bubble_col[3] * (0.5 + 0.5 * d);
    var i: u32 = 0;
    while (i < count) : (i += 1) {
        const seed = bubble_seeds[i];
        const bx = seed.x_frac * sw;
        const by = bubbleY(seed, sh, d);
        c = addQuad(verts, c, bx, by, seed.size, seed.size, bubble_col[0], bubble_col[1], bubble_col[2], ba);
    }

    return c;
}

// ── Tests ───────────────────────────────────────────────────────────────

const testing = std.testing;

test "UiVertex layout is 32 bytes (8 x f32)" {
    try testing.expectEqual(@as(usize, 32), @sizeOf(UiVertex));
}

test "render returns vertices in multiples of 6" {
    var buf: [1024]UiVertex = undefined;
    const c = render(&buf, 0, 800.0, 600.0, 0.5);
    try testing.expect(c > 0);
    try testing.expect(c % 6 == 0);
}

test "render at surface (depth=0) produces lower alpha than deep (depth=1)" {
    var buf_surface: [1024]UiVertex = undefined;
    _ = render(&buf_surface, 0, 800.0, 600.0, 0.0);

    var buf_deep: [1024]UiVertex = undefined;
    _ = render(&buf_deep, 0, 800.0, 600.0, 1.0);

    // First quad top-left vertex alpha: surface should be less than deep
    try testing.expect(buf_surface[0].a < buf_deep[0].a);
}

test "bottom band is darker than top band" {
    var buf: [1024]UiVertex = undefined;
    _ = render(&buf, 0, 800.0, 600.0, 0.5);

    // First band (top) starts at vertex index 0, last band starts at
    // (gradient_bands - 1) * 6.  Compare alpha of their first vertices.
    const top_alpha = buf[0].a;
    const bottom_alpha = buf[(gradient_bands - 1) * 6].a;
    try testing.expect(bottom_alpha > top_alpha);
}

test "deeper water shows more bubbles (more vertices)" {
    var buf_shallow: [1024]UiVertex = undefined;
    const c_shallow = render(&buf_shallow, 0, 800.0, 600.0, 0.0);

    var buf_deep: [1024]UiVertex = undefined;
    const c_deep = render(&buf_deep, 0, 800.0, 600.0, 1.0);

    // Deep water has 5 bubbles; surface has 3 → 2 extra quads (12 verts).
    try testing.expect(c_deep > c_shallow);
}

test "all quads use untextured UV (-1, -1)" {
    var buf: [1024]UiVertex = undefined;
    const c = render(&buf, 0, 800.0, 600.0, 0.7);
    var i: u32 = 0;
    while (i < c) : (i += 1) {
        try testing.expectApproxEqAbs(@as(f32, -1.0), buf[i].u, 0.001);
        try testing.expectApproxEqAbs(@as(f32, -1.0), buf[i].v, 0.001);
    }
}

test "render respects start offset and produces whole quads from it" {
    var buf: [1024]UiVertex = undefined;
    const offset: u32 = 42;
    const c = render(&buf, offset, 1920.0, 1080.0, 0.3);
    try testing.expect(c >= offset);
    try testing.expect((c - offset) % 6 == 0);
}

test "render does not overflow a tiny buffer" {
    var buf: [6]UiVertex = undefined;
    const c = render(&buf, 0, 800.0, 600.0, 1.0);
    try testing.expect(c <= 6);
}

test "baseAlpha interpolates between surface and deep" {
    try testing.expectApproxEqAbs(alpha_surface, baseAlpha(0.0), 0.001);
    try testing.expectApproxEqAbs(alpha_deep, baseAlpha(1.0), 0.001);
    // Midpoint
    try testing.expectApproxEqAbs((alpha_surface + alpha_deep) / 2.0, baseAlpha(0.5), 0.001);
}

test "activeBubbleCount returns 3 at surface, 5 at depth" {
    try testing.expectEqual(@as(u32, 3), activeBubbleCount(0.0));
    try testing.expectEqual(@as(u32, 4), activeBubbleCount(0.3));
    try testing.expectEqual(@as(u32, 5), activeBubbleCount(1.0));
}

test "overlay colour matches tint constants" {
    var buf: [1024]UiVertex = undefined;
    _ = render(&buf, 0, 800.0, 600.0, 0.5);
    // First vertex of the first band should carry the tint colour
    try testing.expectApproxEqAbs(tint_r, buf[0].r, 0.001);
    try testing.expectApproxEqAbs(tint_g, buf[0].g, 0.001);
    try testing.expectApproxEqAbs(tint_b, buf[0].b, 0.001);
}

test "addQuad guards against buffer overflow" {
    var buf: [3]UiVertex = undefined;
    const c = addQuad(&buf, 0, 0, 0, 1, 1, 0, 0, 0, 1);
    try testing.expectEqual(@as(u32, 0), c);
}
