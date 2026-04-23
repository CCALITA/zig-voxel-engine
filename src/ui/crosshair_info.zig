/// Crosshair info overlay renderer.
/// Renders the targeted block ID as a small semi-transparent number below the
/// crosshair, and an attack-cooldown arc (white partial circle) around the
/// crosshair proportional to `cooldown_pct`.
///
/// All quads are flat-coloured (u = -1, v = -1).
const std = @import("std");
const bitmap_font = @import("../renderer/bitmap_font.zig");

// ── Public types ─────────────────────────────────────────────────────

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

// ── Layout constants ─────────────────────────────────────────────────

const pixel_scale: f32 = 1.5;
const digit_spacing: f32 = 1.0;
const id_offset_y: f32 = 14.0;

const arc_radius: f32 = 12.0;
const arc_thickness: f32 = 2.0;
const arc_segments: u32 = 32;

pub const max_vertices: u32 = 2048;

// ── Colours ──────────────────────────────────────────────────────────

const Color = struct { r: f32, g: f32, b: f32, a: f32 };

const id_fg = Color{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 0.55 };
const id_shadow = Color{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 0.35 };
const arc_color = Color{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 0.85 };

// ── Quad helper (u=-1, v=-1: untextured flat colour) ─────────────────

fn addQuad(verts: []UiVertex, idx: *u32, x: f32, y: f32, w: f32, h: f32, col: Color) void {
    if (idx.* + 6 > verts.len) return;
    const x1 = x + w;
    const y1 = y + h;
    verts[idx.*] = .{ .pos_x = x, .pos_y = y, .r = col.r, .g = col.g, .b = col.b, .a = col.a, .u = -1, .v = -1 };
    verts[idx.* + 1] = .{ .pos_x = x1, .pos_y = y, .r = col.r, .g = col.g, .b = col.b, .a = col.a, .u = -1, .v = -1 };
    verts[idx.* + 2] = .{ .pos_x = x, .pos_y = y1, .r = col.r, .g = col.g, .b = col.b, .a = col.a, .u = -1, .v = -1 };
    verts[idx.* + 3] = .{ .pos_x = x1, .pos_y = y, .r = col.r, .g = col.g, .b = col.b, .a = col.a, .u = -1, .v = -1 };
    verts[idx.* + 4] = .{ .pos_x = x1, .pos_y = y1, .r = col.r, .g = col.g, .b = col.b, .a = col.a, .u = -1, .v = -1 };
    verts[idx.* + 5] = .{ .pos_x = x, .pos_y = y1, .r = col.r, .g = col.g, .b = col.b, .a = col.a, .u = -1, .v = -1 };
    idx.* += 6;
}

// ── Number drawing (uses bitmap_font helpers) ────────────────────────

const glyph_w: f32 = @floatFromInt(bitmap_font.GLYPH_W);
const char_stride: f32 = glyph_w * pixel_scale + digit_spacing;

fn drawNumber(verts: []UiVertex, idx: *u32, center_x: f32, y: f32, value: u32, fg: Color, shadow: Color) void {
    const num_digits = bitmap_font.digitCount(value);
    const total_w = @as(f32, @floatFromInt(num_digits)) * char_stride - digit_spacing;
    const start_x = center_x - total_w * 0.5;

    var d: u32 = 0;
    while (d < num_digits) : (d += 1) {
        const digit = bitmap_font.getDigit(value, num_digits - 1 - d);
        const dx = start_x + @as(f32, @floatFromInt(d)) * char_stride;

        var py: u32 = 0;
        while (py < bitmap_font.GLYPH_H) : (py += 1) {
            var px: u32 = 0;
            while (px < bitmap_font.GLYPH_W) : (px += 1) {
                if (bitmap_font.getPixel(digit, px, py)) {
                    const fx = dx + @as(f32, @floatFromInt(px)) * pixel_scale;
                    const fy = y + @as(f32, @floatFromInt(py)) * pixel_scale;
                    addQuad(verts, idx, fx + 1.0, fy + 1.0, pixel_scale, pixel_scale, shadow);
                    addQuad(verts, idx, fx, fy, pixel_scale, pixel_scale, fg);
                }
            }
        }
    }
}

// ── Cooldown arc (small quads approximating a partial circle) ────────

const two_pi: f32 = 2.0 * std.math.pi;
const arc_segments_f: f32 = @floatFromInt(arc_segments);
const arc_step: f32 = two_pi / arc_segments_f;

fn drawArc(verts: []UiVertex, idx: *u32, cx: f32, cy: f32, pct: f32) void {
    const clamped = std.math.clamp(pct, 0.0, 1.0);
    if (clamped <= 0.0) return;

    const segs_to_draw: u32 = @intFromFloat(@round(arc_segments_f * clamped));
    if (segs_to_draw == 0) return;

    const half_thick = arc_thickness * 0.5;
    var i: u32 = 0;
    while (i < segs_to_draw) : (i += 1) {
        const angle = -std.math.pi / 2.0 + @as(f32, @floatFromInt(i)) * arc_step;
        addQuad(verts, idx, cx + @cos(angle) * arc_radius - half_thick, cy + @sin(angle) * arc_radius - half_thick, arc_thickness, arc_thickness, arc_color);
    }
}

// ── Public render entry point ────────────────────────────────────────

/// Render crosshair info overlay: block ID number and attack cooldown arc.
/// Returns the final vertex index after all emitted quads.
pub fn render(verts: []UiVertex, start: u32, sw: f32, sh: f32, block_id: u16, cooldown_pct: f32) u32 {
    var idx = start;

    const cx = sw * 0.5;
    const cy = sh * 0.5;

    // Block ID below crosshair (only when non-zero)
    if (block_id > 0) {
        const text_y = cy + id_offset_y;
        drawNumber(verts, &idx, cx, text_y, @intCast(block_id), id_fg, id_shadow);
    }

    // Attack cooldown arc around crosshair
    drawArc(verts, &idx, cx, cy, cooldown_pct);

    return idx;
}

// ── Tests ────────────────────────────────────────────────────────────

test "render returns start when block_id is 0 and no cooldown" {
    var buf: [max_vertices]UiVertex = undefined;
    const count = render(&buf, 0, 800.0, 600.0, 0, 0.0);
    try std.testing.expectEqual(@as(u32, 0), count);
}

test "render with block_id produces digit quads in multiples of 6" {
    var buf: [max_vertices]UiVertex = undefined;
    const count = render(&buf, 0, 800.0, 600.0, 42, 0.0);
    try std.testing.expect(count > 0);
    try std.testing.expect(count % 6 == 0);
}

test "cooldown arc produces quads proportional to pct" {
    var buf: [max_vertices]UiVertex = undefined;
    const count_half = render(&buf, 0, 800.0, 600.0, 0, 0.5);

    var buf2: [max_vertices]UiVertex = undefined;
    const count_full = render(&buf2, 0, 800.0, 600.0, 0, 1.0);

    // Full arc should produce more quads than half arc
    try std.testing.expect(count_full > count_half);
    try std.testing.expect(count_half > 0);
    try std.testing.expect(count_full % 6 == 0);
    try std.testing.expect(count_half % 6 == 0);
}

test "all vertices have u=-1 and v=-1" {
    var buf: [max_vertices]UiVertex = undefined;
    const count = render(&buf, 0, 1920.0, 1080.0, 100, 0.75);
    for (0..count) |i| {
        try std.testing.expectApproxEqAbs(@as(f32, -1.0), buf[i].u, 0.001);
        try std.testing.expectApproxEqAbs(@as(f32, -1.0), buf[i].v, 0.001);
    }
}

test "render preserves start offset" {
    var buf: [max_vertices]UiVertex = undefined;
    const offset: u32 = 18;
    const count = render(&buf, offset, 800.0, 600.0, 5, 0.25);
    try std.testing.expect(count >= offset);
    try std.testing.expect((count - offset) % 6 == 0);
}

test "buffer overflow protection" {
    var small: [6]UiVertex = undefined;
    const count = render(&small, 0, 800.0, 600.0, 999, 1.0);
    try std.testing.expect(count <= 6);
}

test "cooldown pct is clamped to 0..1" {
    var buf_over: [max_vertices]UiVertex = undefined;
    const count_over = render(&buf_over, 0, 800.0, 600.0, 0, 2.0);

    var buf_full: [max_vertices]UiVertex = undefined;
    const count_full = render(&buf_full, 0, 800.0, 600.0, 0, 1.0);

    try std.testing.expectEqual(count_over, count_full);
}

test "larger block_id produces more digit quads" {
    var buf1: [max_vertices]UiVertex = undefined;
    const count_1digit = render(&buf1, 0, 800.0, 600.0, 5, 0.0);

    var buf2: [max_vertices]UiVertex = undefined;
    const count_3digit = render(&buf2, 0, 800.0, 600.0, 123, 0.0);

    // 3 digits should produce more quads than 1 digit
    try std.testing.expect(count_3digit > count_1digit);
}

test "block id text is centered horizontally" {
    var buf: [max_vertices]UiVertex = undefined;
    const sw: f32 = 800.0;
    _ = render(&buf, 0, sw, 600.0, 1, 0.0);
    // First quad is the shadow of the first pixel; check it is near center
    const center_x = sw * 0.5;
    try std.testing.expect(buf[0].pos_x > center_x - 20.0);
    try std.testing.expect(buf[0].pos_x < center_x + 20.0);
}
