/// Loading screen renderer.
/// Produces UiVertex quads for a dark background, a centered "Loading"
/// indicator bar, a progress bar with green fill (0-100 %), a chunk count
/// display rendered via bitmap_font, and a spinning indicator dot that
/// orbits above the progress bar.
///
/// Self-contained: defines its own `UiVertex` matching the UI pipeline layout
/// (pos.xy, rgba, uv). Untextured quads use `u = -1, v = -1` so the fragment
/// shader takes the solid-color branch.
const std = @import("std");
const bitmap_font = @import("../renderer/bitmap_font.zig");

// ── Vertex type (mirrors ui_pipeline.UiVertex layout) ────────────────

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

const bar_w: f32 = 300.0;
const bar_h: f32 = 20.0;
const bar_border: f32 = 2.0;

/// Title indicator bar dimensions (thin white bar above progress bar).
const title_bar_w: f32 = 200.0;
const title_bar_h: f32 = 6.0;

/// Gap between title indicator and progress bar.
const title_gap: f32 = 24.0;

/// Gap between progress bar bottom and chunk count text.
const count_gap: f32 = 16.0;

/// Pixel scale for bitmap font digits.
const pixel_scale: f32 = 2.5;

/// Spinning dot radius and orbit radius.
const dot_size: f32 = 6.0;
const orbit_radius: f32 = 16.0;

/// Separator "/" glyph width in pixel units.
const slash_w: f32 = @as(f32, @floatFromInt(bitmap_font.GLYPH_W)) * pixel_scale;

/// Spacing between adjacent digit glyphs.
const digit_spacing: f32 = 1.0;

// ── Colors ───────────────────────────────────────────────────────────

const Color = struct { r: f32, g: f32, b: f32, a: f32 };

const bg_col = Color{ .r = 0.05, .g = 0.05, .b = 0.08, .a = 1.0 };
const title_col = Color{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 1.0 };
const bar_border_col = Color{ .r = 0.3, .g = 0.3, .b = 0.3, .a = 1.0 };
const bar_bg_col = Color{ .r = 0.12, .g = 0.12, .b = 0.12, .a = 1.0 };
const bar_fill_col = Color{ .r = 0.18, .g = 0.72, .b = 0.22, .a = 1.0 };
const count_col = Color{ .r = 0.8, .g = 0.8, .b = 0.8, .a = 1.0 };
const slash_col = Color{ .r = 0.5, .g = 0.5, .b = 0.5, .a = 1.0 };
const dot_col = Color{ .r = 0.9, .g = 0.9, .b = 1.0, .a = 1.0 };

// ── Maximum vertex budget ────────────────────────────────────────────

/// Background (6) + title bar (6) + bar border (6) + bar bg (6) +
/// bar fill (6) + spinning dot (6) + chunk digits (~10 digits * ~9px * 6)
/// + slash quads (~6 * 6) ≈ ~640. Budget rounded up generously.
pub const max_vertices: u32 = 2048;

// ── Quad helper ──────────────────────────────────────────────────────

/// Emit a solid-colored quad (2 triangles, 6 vertices). UV set to (-1, -1).
fn addQuad(verts: []UiVertex, idx: u32, x: f32, y: f32, w: f32, h: f32, col: Color) u32 {
    if (idx + 6 > verts.len) return idx;
    const x1 = x + w;
    const y1 = y + h;

    verts[idx + 0] = .{ .pos_x = x, .pos_y = y, .r = col.r, .g = col.g, .b = col.b, .a = col.a, .u = -1, .v = -1 };
    verts[idx + 1] = .{ .pos_x = x1, .pos_y = y, .r = col.r, .g = col.g, .b = col.b, .a = col.a, .u = -1, .v = -1 };
    verts[idx + 2] = .{ .pos_x = x1, .pos_y = y1, .r = col.r, .g = col.g, .b = col.b, .a = col.a, .u = -1, .v = -1 };
    verts[idx + 3] = .{ .pos_x = x, .pos_y = y, .r = col.r, .g = col.g, .b = col.b, .a = col.a, .u = -1, .v = -1 };
    verts[idx + 4] = .{ .pos_x = x1, .pos_y = y1, .r = col.r, .g = col.g, .b = col.b, .a = col.a, .u = -1, .v = -1 };
    verts[idx + 5] = .{ .pos_x = x, .pos_y = y1, .r = col.r, .g = col.g, .b = col.b, .a = col.a, .u = -1, .v = -1 };

    return idx + 6;
}

// ── Number rendering ─────────────────────────────────────────────────

/// Compute the pixel width of a number rendered with the bitmap font.
fn numberWidth(value: u32) f32 {
    const num_digits = bitmap_font.digitCount(value);
    const glyph_w: f32 = @floatFromInt(bitmap_font.GLYPH_W);
    return @as(f32, @floatFromInt(num_digits)) * (glyph_w * pixel_scale + digit_spacing) - digit_spacing;
}

/// Draw a number left-aligned starting at (left_x, top_y).
/// Returns the vertex index after all emitted quads.
fn drawNumber(verts: []UiVertex, idx: u32, left_x: f32, top_y: f32, value: u32, col: Color) u32 {
    const num_digits = bitmap_font.digitCount(value);
    const glyph_w: f32 = @floatFromInt(bitmap_font.GLYPH_W);

    var c = idx;
    var d: u32 = 0;
    while (d < num_digits) : (d += 1) {
        const digit = bitmap_font.getDigit(value, num_digits - 1 - d);
        const dx = left_x + @as(f32, @floatFromInt(d)) * (glyph_w * pixel_scale + digit_spacing);

        var py: u32 = 0;
        while (py < bitmap_font.GLYPH_H) : (py += 1) {
            var px: u32 = 0;
            while (px < bitmap_font.GLYPH_W) : (px += 1) {
                if (bitmap_font.getPixel(digit, px, py)) {
                    c = addQuad(
                        verts,
                        c,
                        dx + @as(f32, @floatFromInt(px)) * pixel_scale,
                        top_y + @as(f32, @floatFromInt(py)) * pixel_scale,
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

/// Draw a slash "/" separator as a simple diagonal of small quads.
fn drawSlash(verts: []UiVertex, idx: u32, x: f32, y: f32, col: Color) u32 {
    const h: f32 = @floatFromInt(bitmap_font.GLYPH_H);
    const total_h = h * pixel_scale;
    var c = idx;
    // Draw 5 small quads along a diagonal (bottom-left to top-right).
    var i: u32 = 0;
    while (i < bitmap_font.GLYPH_H) : (i += 1) {
        const fi: f32 = @floatFromInt(i);
        const px = x + (fi / h) * slash_w;
        const py = y + total_h - (fi + 1.0) * pixel_scale;
        c = addQuad(verts, c, px, py, pixel_scale, pixel_scale, col);
    }
    return c;
}

// ── Public render entry point ────────────────────────────────────────

/// Render the loading screen into the provided vertex buffer.
/// `progress` is clamped to [0, 1]. `chunks_loaded` and `total_chunks` are
/// displayed as "loaded / total" below the progress bar.
/// Returns the new vertex index (total vertices written from `start`).
pub fn render(verts: []UiVertex, start: u32, sw: f32, sh: f32, progress: f32, chunks_loaded: u32, total_chunks: u32) u32 {
    var idx = start;
    const prog = std.math.clamp(progress, 0.0, 1.0);

    // 1. Dark background covering the full screen.
    idx = addQuad(verts, idx, 0, 0, sw, sh, bg_col);

    // Vertical center: title bar + gap + progress bar as a group.
    const group_h = title_bar_h + title_gap + bar_h;
    const group_top = (sh - group_h) * 0.5;

    // 2. "Loading" title indicator bar (thin centered white bar).
    const title_x = (sw - title_bar_w) * 0.5;
    idx = addQuad(verts, idx, title_x, group_top, title_bar_w, title_bar_h, title_col);

    // 3. Progress bar (border + background + green fill).
    const bar_x = (sw - bar_w) * 0.5;
    const bar_y = group_top + title_bar_h + title_gap;

    // Border
    idx = addQuad(verts, idx, bar_x - bar_border, bar_y - bar_border, bar_w + bar_border * 2, bar_h + bar_border * 2, bar_border_col);
    // Background
    idx = addQuad(verts, idx, bar_x, bar_y, bar_w, bar_h, bar_bg_col);
    // Green fill (width proportional to progress)
    const fill_w = bar_w * prog;
    if (fill_w > 0.5) {
        idx = addQuad(verts, idx, bar_x, bar_y, fill_w, bar_h, bar_fill_col);
    }

    // 4. Spinning indicator dot orbiting above the title bar.
    const dot_center_x = sw * 0.5;
    const dot_center_y = group_top - orbit_radius - dot_size;
    // Use progress as a simple angle source (full rotations as loading proceeds).
    const angle = prog * std.math.pi * 6.0;
    const dot_x = dot_center_x + @cos(angle) * orbit_radius - dot_size * 0.5;
    const dot_y = dot_center_y + @sin(angle) * orbit_radius - dot_size * 0.5;
    idx = addQuad(verts, idx, dot_x, dot_y, dot_size, dot_size, dot_col);

    // 5. Chunk count: "chunks_loaded / total_chunks" centered below the bar.
    const count_y = bar_y + bar_h + count_gap;
    const spacing: f32 = 4.0;

    // Measure widths to center the whole "loaded / total" string.
    const loaded_w = numberWidth(chunks_loaded);
    const total_w_px = numberWidth(total_chunks);
    const full_w = loaded_w + spacing + slash_w + spacing + total_w_px;
    const count_start_x = (sw - full_w) * 0.5;

    // Draw loaded count (left-aligned).
    idx = drawNumber(verts, idx, count_start_x, count_y, chunks_loaded, count_col);

    // Draw slash separator.
    const slash_x = count_start_x + loaded_w + spacing;
    idx = drawSlash(verts, idx, slash_x, count_y, slash_col);

    // Draw total count (left-aligned after slash).
    const total_x = slash_x + slash_w + spacing;
    idx = drawNumber(verts, idx, total_x, count_y, total_chunks, count_col);

    return idx;
}

// ── Tests ────────────────────────────────────────────────────────────

test "render returns more vertices than start index" {
    var buf: [max_vertices]UiVertex = undefined;
    const count = render(&buf, 0, 800.0, 600.0, 0.5, 10, 20);
    try std.testing.expect(count > 0);
    try std.testing.expect(count % 6 == 0);
}

test "render respects start offset" {
    var buf: [max_vertices]UiVertex = undefined;
    const offset: u32 = 18;
    const count = render(&buf, offset, 1024.0, 768.0, 0.3, 5, 100);
    try std.testing.expect(count >= offset);
    try std.testing.expect((count - offset) % 6 == 0);
    // First written vertex should be at offset.
    try std.testing.expect(buf[offset].a != 0.0);
}

test "progress clamped to valid range" {
    var buf: [max_vertices]UiVertex = undefined;
    // Out-of-range values should not crash.
    const c1 = render(&buf, 0, 800.0, 600.0, -0.5, 0, 10);
    const c2 = render(&buf, 0, 800.0, 600.0, 2.0, 10, 10);
    try std.testing.expect(c1 > 0);
    try std.testing.expect(c2 > 0);
}

test "background covers full screen" {
    var buf: [max_vertices]UiVertex = undefined;
    const sw: f32 = 1920.0;
    const sh: f32 = 1080.0;
    _ = render(&buf, 0, sw, sh, 0.0, 0, 0);
    // First quad is the dark background.
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), buf[0].pos_x, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), buf[0].pos_y, 0.01);
    try std.testing.expectApproxEqAbs(sw, buf[1].pos_x, 0.01);
    try std.testing.expectApproxEqAbs(sh, buf[2].pos_y, 0.01);
    // Verify dark background color.
    try std.testing.expectApproxEqAbs(bg_col.r, buf[0].r, 0.01);
    try std.testing.expectApproxEqAbs(bg_col.a, buf[0].a, 0.01);
}

test "more chunks produce more vertices" {
    var buf1: [max_vertices]UiVertex = undefined;
    const count1 = render(&buf1, 0, 800.0, 600.0, 0.5, 5, 9);

    var buf2: [max_vertices]UiVertex = undefined;
    const count2 = render(&buf2, 0, 800.0, 600.0, 0.5, 12345, 99999);

    // More digits means more pixel quads.
    try std.testing.expect(count2 > count1);
}

test "addQuad emits 6 vertices with u=-1 v=-1" {
    var buf: [6]UiVertex = undefined;
    const after = addQuad(&buf, 0, 10.0, 20.0, 50.0, 30.0, .{ .r = 1, .g = 0, .b = 0, .a = 1 });
    try std.testing.expectEqual(@as(u32, 6), after);
    try std.testing.expectApproxEqAbs(@as(f32, -1.0), buf[0].u, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, -1.0), buf[0].v, 0.001);
}

test "addQuad overflow protection" {
    var buf: [4]UiVertex = undefined;
    const after = addQuad(&buf, 0, 0, 0, 10, 10, .{ .r = 0, .g = 0, .b = 0, .a = 1 });
    try std.testing.expectEqual(@as(u32, 0), after);
}

test "zero progress produces no green fill" {
    var buf: [max_vertices]UiVertex = undefined;
    _ = render(&buf, 0, 800.0, 600.0, 0.0, 0, 10);
    // Check that no vertex has the green fill color.
    // The first 5 quads (30 verts) are: bg, title, border, bar_bg, dot
    // (no fill quad emitted when fill_w < 0.5).
    var has_green = false;
    for (0..30) |i| {
        if (@abs(buf[i].r - bar_fill_col.r) < 0.01 and
            @abs(buf[i].g - bar_fill_col.g) < 0.01)
        {
            has_green = true;
        }
    }
    try std.testing.expect(!has_green);
}

test "full progress fills entire bar width" {
    var buf: [max_vertices]UiVertex = undefined;
    _ = render(&buf, 0, 800.0, 600.0, 1.0, 10, 10);
    // With progress=1.0, the fill quad should span bar_w.
    // Border quad starts at idx 18, bg at 24, fill at 30.
    const fill_start: usize = 30;
    const fill_left = buf[fill_start].pos_x;
    const fill_right = buf[fill_start + 1].pos_x;
    const fill_width = fill_right - fill_left;
    try std.testing.expectApproxEqAbs(bar_w, fill_width, 0.5);
}

test "spinning dot position changes with progress" {
    var buf1: [max_vertices]UiVertex = undefined;
    _ = render(&buf1, 0, 800.0, 600.0, 0.0, 5, 10);

    var buf2: [max_vertices]UiVertex = undefined;
    _ = render(&buf2, 0, 800.0, 600.0, 0.5, 5, 10);

    // The dot quad is the 6th element (after bg, title, border, bar_bg, fill).
    // At progress=0.0 there is no fill quad, so dot is at index 24.
    // At progress=0.5 there IS a fill quad, so dot is at index 30.
    // Compare dot positions; they must differ due to different angles.
    const dot_idx_no_fill: usize = 24;
    const dot_idx_with_fill: usize = 30;
    const dx = @abs(buf1[dot_idx_no_fill].pos_x - buf2[dot_idx_with_fill].pos_x);
    const dy = @abs(buf1[dot_idx_no_fill].pos_y - buf2[dot_idx_with_fill].pos_y);
    try std.testing.expect(dx > 0.01 or dy > 0.01);
}

test "render does not overflow small buffer" {
    var buf: [12]UiVertex = undefined;
    const count = render(&buf, 0, 800.0, 600.0, 0.5, 99999, 99999);
    try std.testing.expect(count <= 12);
}
