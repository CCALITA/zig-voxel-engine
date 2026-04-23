/// Crosshair info overlay: block ID number below screen centre and an
/// attack-cooldown arc (8 quads) around the crosshair proportional to
/// cooldown_pct. All quads use u=-1, v=-1 (untextured solid colour).
const std = @import("std");
const bitmap_font = @import("../renderer/bitmap_font.zig");

// ── Vertex type (mirrors ui_pipeline.UiVertex) ─────────────────────────

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

// ── Layout constants ───────────────────────────────────────────────────

const pixel_scale: f32 = 1.5;
const digit_spacing: f32 = 1.0;
const id_offset_y: f32 = 12.0;

/// Arc ring geometry.
const arc_inner_radius: f32 = 10.0;
const arc_outer_radius: f32 = 14.0;
const arc_segments: u32 = 8;

// ── Colours ────────────────────────────────────────────────────────────

const text_col = [4]f32{ 1.0, 1.0, 1.0, 0.9 };
const arc_col = [4]f32{ 1.0, 1.0, 1.0, 0.85 };

// ── Precomputed trig tables (8 segments = 9 boundary angles) ──────────

const TrigPair = struct { cos: f32, sin: f32 };

const trig_table: [arc_segments + 1]TrigPair = blk: {
    var t: [arc_segments + 1]TrigPair = undefined;
    for (0..arc_segments + 1) |i| {
        const angle: f64 = @as(f64, @floatFromInt(i)) * (2.0 * std.math.pi / @as(f64, @floatFromInt(arc_segments)));
        t[i] = .{ .cos = @floatCast(@cos(angle)), .sin = @floatCast(@sin(angle)) };
    }
    break :blk t;
};

// ── Quad helper ────────────────────────────────────────────────────────

/// Emit a solid-colour axis-aligned quad (2 triangles, 6 vertices). UV = -1.
fn addQuad(verts: []UiVertex, start: u32, x: f32, y: f32, w: f32, h: f32, col: [4]f32) u32 {
    if (start + 6 > verts.len) return start;
    const x1 = x + w;
    const y1 = y + h;
    const r = col[0];
    const g = col[1];
    const b = col[2];
    const a = col[3];

    verts[start + 0] = .{ .pos_x = x, .pos_y = y, .r = r, .g = g, .b = b, .a = a, .u = -1, .v = -1 };
    verts[start + 1] = .{ .pos_x = x1, .pos_y = y, .r = r, .g = g, .b = b, .a = a, .u = -1, .v = -1 };
    verts[start + 2] = .{ .pos_x = x1, .pos_y = y1, .r = r, .g = g, .b = b, .a = a, .u = -1, .v = -1 };
    verts[start + 3] = .{ .pos_x = x, .pos_y = y, .r = r, .g = g, .b = b, .a = a, .u = -1, .v = -1 };
    verts[start + 4] = .{ .pos_x = x1, .pos_y = y1, .r = r, .g = g, .b = b, .a = a, .u = -1, .v = -1 };
    verts[start + 5] = .{ .pos_x = x, .pos_y = y1, .r = r, .g = g, .b = b, .a = a, .u = -1, .v = -1 };

    return start + 6;
}

/// Emit a free-form quad from four arbitrary corners (2 triangles, 6 verts).
fn addFreeQuad(
    verts: []UiVertex,
    start: u32,
    x0: f32,
    y0: f32,
    x1: f32,
    y1: f32,
    x2: f32,
    y2: f32,
    x3: f32,
    y3: f32,
    col: [4]f32,
) u32 {
    if (start + 6 > verts.len) return start;
    const r = col[0];
    const g = col[1];
    const b = col[2];
    const a = col[3];

    verts[start + 0] = .{ .pos_x = x0, .pos_y = y0, .r = r, .g = g, .b = b, .a = a, .u = -1, .v = -1 };
    verts[start + 1] = .{ .pos_x = x1, .pos_y = y1, .r = r, .g = g, .b = b, .a = a, .u = -1, .v = -1 };
    verts[start + 2] = .{ .pos_x = x2, .pos_y = y2, .r = r, .g = g, .b = b, .a = a, .u = -1, .v = -1 };
    verts[start + 3] = .{ .pos_x = x0, .pos_y = y0, .r = r, .g = g, .b = b, .a = a, .u = -1, .v = -1 };
    verts[start + 4] = .{ .pos_x = x2, .pos_y = y2, .r = r, .g = g, .b = b, .a = a, .u = -1, .v = -1 };
    verts[start + 5] = .{ .pos_x = x3, .pos_y = y3, .r = r, .g = g, .b = b, .a = a, .u = -1, .v = -1 };

    return start + 6;
}

// ── Number drawing via bitmap_font ─────────────────────────────────────

const char_w = @as(f32, @floatFromInt(bitmap_font.GLYPH_W)) * pixel_scale + digit_spacing * pixel_scale;

/// Draw an unsigned number centred at (cx, y). Returns new vertex index.
fn drawNumber(verts: []UiVertex, start: u32, cx: f32, y: f32, value: u32, col: [4]f32) u32 {
    var c = start;
    const num_digits = bitmap_font.digitCount(value);
    const total_w = @as(f32, @floatFromInt(num_digits)) * char_w;
    const left_x = cx - total_w * 0.5;

    var di: u32 = 0;
    while (di < num_digits) : (di += 1) {
        const digit = bitmap_font.getDigit(value, num_digits - 1 - di);
        const dx = left_x + @as(f32, @floatFromInt(di)) * char_w;
        var py: u32 = 0;
        while (py < bitmap_font.GLYPH_H) : (py += 1) {
            var px: u32 = 0;
            while (px < bitmap_font.GLYPH_W) : (px += 1) {
                if (bitmap_font.getPixel(digit, px, py)) {
                    c = addQuad(
                        verts,
                        c,
                        dx + @as(f32, @floatFromInt(px)) * pixel_scale,
                        y + @as(f32, @floatFromInt(py)) * pixel_scale,
                        pixel_scale,
                        pixel_scale,
                        col,
                    );
                }
            }
        }
    }
    return c;
}

// ── Arc rendering ──────────────────────────────────────────────────────

/// Draw cooldown arc segments around (cx, cy). The number of segments
/// drawn is proportional to `pct` (0.0 = none, 1.0 = full ring).
/// Returns the new vertex index.
fn drawArc(verts: []UiVertex, start: u32, cx: f32, cy: f32, pct: f32) u32 {
    if (pct <= 0.0) return start;
    var c = start;
    const clamped = std.math.clamp(pct, 0.0, 1.0);
    const active_segs: u32 = @intFromFloat(@ceil(clamped * @as(f32, @floatFromInt(arc_segments))));

    var i: u32 = 0;
    while (i < active_segs) : (i += 1) {
        const c0 = trig_table[i].cos;
        const s0 = trig_table[i].sin;
        const c1 = trig_table[i + 1].cos;
        const s1 = trig_table[i + 1].sin;

        // Inner edge endpoints
        const ix0 = cx + c0 * arc_inner_radius;
        const iy0 = cy + s0 * arc_inner_radius;
        const ix1 = cx + c1 * arc_inner_radius;
        const iy1 = cy + s1 * arc_inner_radius;

        // Outer edge endpoints
        const ox0 = cx + c0 * arc_outer_radius;
        const oy0 = cy + s0 * arc_outer_radius;
        const ox1 = cx + c1 * arc_outer_radius;
        const oy1 = cy + s1 * arc_outer_radius;

        c = addFreeQuad(verts, c, ix0, iy0, ox0, oy0, ox1, oy1, ix1, iy1, arc_col);
    }
    return c;
}

// ── Public render entry point ──────────────────────────────────────────

/// Render block-ID number below screen centre and cooldown arc around
/// the crosshair. `block_id` 0 means "no block targeted" and skips the
/// number. `cooldown_pct` 0..1 controls how many arc segments are drawn.
/// Returns the final vertex index.
pub fn render(
    verts: []UiVertex,
    start: u32,
    sw: f32,
    sh: f32,
    block_id: u16,
    cooldown_pct: f32,
) u32 {
    var c = start;
    const cx = sw * 0.5;
    const cy = sh * 0.5;

    if (block_id > 0) {
        c = drawNumber(verts, c, cx, cy + id_offset_y, @as(u32, block_id), text_col);
    }
    c = drawArc(verts, c, cx, cy, cooldown_pct);

    return c;
}

// ── Tests ──────────────────────────────────────────────────────────────

const testing = std.testing;

test "UiVertex is 32 bytes (8 x f32)" {
    try testing.expectEqual(@as(usize, 32), @sizeOf(UiVertex));
}

test "render with block_id=0 and cooldown=0 emits nothing" {
    var buf: [256]UiVertex = undefined;
    const c = render(&buf, 0, 800.0, 600.0, 0, 0.0);
    try testing.expectEqual(@as(u32, 0), c);
}

test "render with block_id>0 emits vertices in multiples of 6" {
    var buf: [4096]UiVertex = undefined;
    const c = render(&buf, 0, 800.0, 600.0, 42, 0.0);
    try testing.expect(c > 0);
    try testing.expect(c % 6 == 0);
}

test "render preserves start offset" {
    var buf: [4096]UiVertex = undefined;
    const offset: u32 = 18;
    const c = render(&buf, offset, 800.0, 600.0, 1, 0.5);
    try testing.expect(c >= offset);
    try testing.expect((c - offset) % 6 == 0);
}

test "all vertices use untextured UV (-1, -1)" {
    var buf: [4096]UiVertex = undefined;
    const c = render(&buf, 0, 1920.0, 1080.0, 256, 1.0);
    for (0..c) |i| {
        try testing.expectApproxEqAbs(@as(f32, -1.0), buf[i].u, 0.001);
        try testing.expectApproxEqAbs(@as(f32, -1.0), buf[i].v, 0.001);
    }
}

test "cooldown=1.0 draws all 8 arc segments (48 verts)" {
    var buf: [4096]UiVertex = undefined;
    // Only arc, no block ID
    const c = render(&buf, 0, 800.0, 600.0, 0, 1.0);
    try testing.expectEqual(@as(u32, arc_segments * 6), c);
}

test "cooldown=0.5 draws 4 arc segments (24 verts)" {
    var buf: [4096]UiVertex = undefined;
    const c = render(&buf, 0, 800.0, 600.0, 0, 0.5);
    try testing.expectEqual(@as(u32, 4 * 6), c);
}

test "cooldown is clamped so >1 equals 1" {
    var buf_over: [4096]UiVertex = undefined;
    var buf_one: [4096]UiVertex = undefined;
    const c_over = render(&buf_over, 0, 800.0, 600.0, 0, 2.0);
    const c_one = render(&buf_one, 0, 800.0, 600.0, 0, 1.0);
    try testing.expectEqual(c_one, c_over);
}

test "block ID text is centred horizontally on screen" {
    var buf: [4096]UiVertex = undefined;
    const sw: f32 = 800.0;
    _ = render(&buf, 0, sw, 600.0, 5, 0.0);
    // First vertex of first digit quad should be left of centre
    const first_x = buf[0].pos_x;
    try testing.expect(first_x < sw * 0.5);
}

test "larger block IDs produce more vertices" {
    var buf_small: [4096]UiVertex = undefined;
    var buf_large: [4096]UiVertex = undefined;
    const c_small = render(&buf_small, 0, 800.0, 600.0, 1, 0.0);
    const c_large = render(&buf_large, 0, 800.0, 600.0, 12345, 0.0);
    try testing.expect(c_large > c_small);
}

test "arc vertices are near screen centre" {
    var buf: [4096]UiVertex = undefined;
    const sw: f32 = 800.0;
    const sh: f32 = 600.0;
    const c = render(&buf, 0, sw, sh, 0, 1.0);
    const cx = sw * 0.5;
    const cy = sh * 0.5;
    const max_dist = arc_outer_radius + 1.0;
    for (0..c) |i| {
        const dx = buf[i].pos_x - cx;
        const dy = buf[i].pos_y - cy;
        const dist = @sqrt(dx * dx + dy * dy);
        try testing.expect(dist <= max_dist);
    }
}

test "addQuad guards against buffer overflow" {
    var buf: [3]UiVertex = undefined;
    const c = addQuad(&buf, 0, 0, 0, 1, 1, .{ 0, 0, 0, 1 });
    try testing.expectEqual(@as(u32, 0), c);
}

test "addFreeQuad guards against buffer overflow" {
    var buf: [3]UiVertex = undefined;
    const c = addFreeQuad(&buf, 0, 0, 0, 1, 0, 1, 1, 0, 1, .{ 1, 1, 1, 1 });
    try testing.expectEqual(@as(u32, 0), c);
}

test "drawNumber for value 0 produces quads" {
    var buf: [1024]UiVertex = undefined;
    const c = drawNumber(&buf, 0, 400.0, 300.0, 0, text_col);
    try testing.expect(c > 0);
    try testing.expect(c % 6 == 0);
}

test "trig_table entries form a unit circle" {
    for (0..arc_segments + 1) |i| {
        const cs = trig_table[i].cos;
        const sn = trig_table[i].sin;
        try testing.expectApproxEqAbs(@as(f32, 1.0), cs * cs + sn * sn, 0.001);
    }
}
