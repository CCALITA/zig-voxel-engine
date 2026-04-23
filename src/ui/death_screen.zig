/// Death screen overlay renderer.
/// Produces UiVertex quads for a red-tinted full-screen overlay with a dark
/// center panel, title indicator bar, score display, and "Press R" prompt.
const std = @import("std");
const bitmap_font = @import("../renderer/bitmap_font.zig");

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

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

pub const max_vertices = 2048;

// ---------------------------------------------------------------------------
// Layout constants
// ---------------------------------------------------------------------------

const panel_w: f32 = 320.0;
const panel_h: f32 = 200.0;

const title_bar_w: f32 = 260.0;
const title_bar_h: f32 = 6.0;

const button_w: f32 = 160.0;
const button_h: f32 = 32.0;

/// Pixel scale for bitmap font digits in the score display.
const pixel_scale: f32 = 3.0;

// ---------------------------------------------------------------------------
// Colors
// ---------------------------------------------------------------------------

const Color = struct { r: f32, g: f32, b: f32, a: f32 };

fn overlayColor(fade_alpha: f32) Color {
    return .{ .r = 0.5, .g = 0.0, .b = 0.0, .a = fade_alpha * 0.6 };
}

const panel_bg = Color{ .r = 0.08, .g = 0.08, .b = 0.08, .a = 0.85 };
const title_bar_col = Color{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 1.0 };
const score_col = Color{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 1.0 };
const button_bg = Color{ .r = 0.35, .g = 0.35, .b = 0.35, .a = 0.9 };

// ---------------------------------------------------------------------------
// Quad helper
// ---------------------------------------------------------------------------

/// Emit a solid-colored quad (2 triangles, 6 vertices). UV set to (-1, -1).
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

// ---------------------------------------------------------------------------
// Score rendering
// ---------------------------------------------------------------------------

/// Draw a number centered horizontally at (center_x, top_y) using the bitmap
/// font. Each lit pixel of each glyph becomes a tiny quad.
fn drawNumber(verts: []UiVertex, idx: *u32, center_x: f32, top_y: f32, value: u32, col: Color) void {
    const num_digits = bitmap_font.digitCount(value);
    const glyph_w: f32 = @floatFromInt(bitmap_font.GLYPH_W);
    const digit_spacing: f32 = 1.0;

    const total_w = @as(f32, @floatFromInt(num_digits)) * (glyph_w * pixel_scale + digit_spacing) - digit_spacing;
    const start_x = center_x - total_w * 0.5;
    const start_y = top_y;

    var d: u32 = 0;
    while (d < num_digits) : (d += 1) {
        const digit = bitmap_font.getDigit(value, num_digits - 1 - d);
        const dx = start_x + @as(f32, @floatFromInt(d)) * (glyph_w * pixel_scale + digit_spacing);

        var py: u32 = 0;
        while (py < bitmap_font.GLYPH_H) : (py += 1) {
            var px: u32 = 0;
            while (px < bitmap_font.GLYPH_W) : (px += 1) {
                if (bitmap_font.getPixel(digit, px, py)) {
                    addQuad(
                        verts,
                        idx,
                        dx + @as(f32, @floatFromInt(px)) * pixel_scale,
                        start_y + @as(f32, @floatFromInt(py)) * pixel_scale,
                        pixel_scale,
                        pixel_scale,
                        col,
                    );
                }
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Public render entry point
// ---------------------------------------------------------------------------

/// Render the death screen overlay into the provided vertex buffer.
/// Returns the number of vertices written (starting from `start`).
pub fn render(verts: []UiVertex, start: u32, sw: f32, sh: f32, score: u32, fade_alpha: f32) u32 {
    var idx: u32 = start;

    const alpha = std.math.clamp(fade_alpha, 0.0, 1.0);

    // 1. Full-screen red-tinted overlay
    addQuad(verts, &idx, 0, 0, sw, sh, overlayColor(alpha));

    // 2. Dark center panel
    const px = (sw - panel_w) * 0.5;
    const py = (sh - panel_h) * 0.5;
    addQuad(verts, &idx, px, py, panel_w, panel_h, panel_bg);

    // 3. Title indicator bar (wide white bar near top of panel)
    const bar_x = px + (panel_w - title_bar_w) * 0.5;
    const bar_y = py + 24.0;
    addQuad(verts, &idx, bar_x, bar_y, title_bar_w, title_bar_h, title_bar_col);

    // 4. Score number (centered, below title bar)
    const score_y = bar_y + title_bar_h + 30.0;
    drawNumber(verts, &idx, sw * 0.5, score_y, score, score_col);

    // 5. "Press R" indicator (gray button rectangle near bottom of panel)
    const btn_x = px + (panel_w - button_w) * 0.5;
    const btn_y = py + panel_h - button_h - 20.0;
    addQuad(verts, &idx, btn_x, btn_y, button_w, button_h, button_bg);

    return idx - start;
}

// ===========================================================================
// Tests
// ===========================================================================

test "render returns non-zero vertex count" {
    var buf: [max_vertices]UiVertex = undefined;
    const count = render(&buf, 0, 800.0, 600.0, 0, 1.0);
    // At minimum: overlay + panel + title bar + score (digit 0) + button = 4 quads + digit pixels
    try std.testing.expect(count >= 6 * 4);
    try std.testing.expect(count % 6 == 0);
}

test "render respects start offset" {
    var buf: [max_vertices]UiVertex = undefined;
    const offset: u32 = 60;
    const count = render(&buf, offset, 800.0, 600.0, 42, 1.0);
    try std.testing.expect(count > 0);
    try std.testing.expect(count % 6 == 0);
    // Verify vertices were written at the offset
    try std.testing.expect(buf[offset].a != 0.0);
}

test "render clamps fade_alpha" {
    var buf: [max_vertices]UiVertex = undefined;
    // Out-of-range fade values should not crash
    const c1 = render(&buf, 0, 800.0, 600.0, 10, 2.5);
    const c2 = render(&buf, 0, 800.0, 600.0, 10, -0.5);
    try std.testing.expect(c1 > 0);
    try std.testing.expect(c2 > 0);
}

test "higher score produces more vertices" {
    var buf1: [max_vertices]UiVertex = undefined;
    const count1 = render(&buf1, 0, 800.0, 600.0, 5, 1.0);

    var buf2: [max_vertices]UiVertex = undefined;
    const count2 = render(&buf2, 0, 800.0, 600.0, 12345, 1.0);

    // 5 digits produce far more pixel quads than 1 digit
    try std.testing.expect(count2 > count1);
}

test "overlay covers full screen" {
    var buf: [max_vertices]UiVertex = undefined;
    const sw: f32 = 1920.0;
    const sh: f32 = 1080.0;
    _ = render(&buf, 0, sw, sh, 0, 1.0);
    // First quad is the full-screen overlay
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), buf[0].pos_x, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), buf[0].pos_y, 0.01);
    // Second vertex (top-right corner)
    try std.testing.expectApproxEqAbs(sw, buf[1].pos_x, 0.01);
}

test "panel is centered" {
    var buf: [max_vertices]UiVertex = undefined;
    const sw: f32 = 800.0;
    const sh: f32 = 600.0;
    _ = render(&buf, 0, sw, sh, 0, 1.0);
    // Second quad (index 6) is the panel background
    const expected_x = (sw - panel_w) * 0.5;
    const expected_y = (sh - panel_h) * 0.5;
    try std.testing.expectApproxEqAbs(expected_x, buf[6].pos_x, 0.01);
    try std.testing.expectApproxEqAbs(expected_y, buf[6].pos_y, 0.01);
}

test "addQuad writes UV as negative one" {
    var buf: [6]UiVertex = undefined;
    var idx: u32 = 0;
    addQuad(&buf, &idx, 0, 0, 10, 10, .{ .r = 1, .g = 0, .b = 0, .a = 1 });
    try std.testing.expectEqual(@as(u32, 6), idx);
    try std.testing.expectApproxEqAbs(@as(f32, -1.0), buf[0].u, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, -1.0), buf[0].v, 0.001);
}

test "render does not overflow small buffer" {
    var buf: [12]UiVertex = undefined;
    const count = render(&buf, 0, 800.0, 600.0, 99999, 1.0);
    try std.testing.expect(count <= 12);
}

test "fade_alpha zero produces overlay with zero alpha" {
    var buf: [max_vertices]UiVertex = undefined;
    _ = render(&buf, 0, 800.0, 600.0, 0, 0.0);
    // First quad is the overlay; alpha should be 0.0 * 0.6 = 0.0
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), buf[0].a, 0.001);
}

test "drawNumber renders score zero as single digit" {
    var buf: [512]UiVertex = undefined;
    var idx: u32 = 0;
    drawNumber(&buf, &idx, 400.0, 300.0, 0, score_col);
    // Digit '0' has some lit pixels; expect > 0 vertices
    try std.testing.expect(idx > 0);
    try std.testing.expect(idx % 6 == 0);
}
