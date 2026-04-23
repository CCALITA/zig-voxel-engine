/// Furnace / smoker / blast furnace screen renderer.
/// Produces UiVertex quads for a centered panel with input, fuel, and output
/// slots, a fire icon (burn progress), and an arrow (smelt progress).
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

pub const FurnaceData = struct {
    input_item: u16 = 0,
    input_count: u8 = 0,
    fuel_item: u16 = 0,
    fuel_count: u8 = 0,
    output_item: u16 = 0,
    output_count: u8 = 0,
    burn_progress: f32 = 0, // 0-1 (fire icon fill)
    smelt_progress: f32 = 0, // 0-1 (arrow fill)
    furnace_type: u8 = 0, // 0=furnace, 1=smoker, 2=blast
};

pub const max_vertices = 2048;

// ---------------------------------------------------------------------------
// Layout constants
// ---------------------------------------------------------------------------

const panel_w: f32 = 350.0;
const panel_h: f32 = 280.0;

const slot_size: f32 = 36.0;
const slot_border: f32 = 2.0;

// Fire icon (vertical bar showing burn progress)
const fire_w: f32 = 14.0;
const fire_h: f32 = 20.0;

// Arrow (horizontal bar showing smelt progress)
const arrow_w: f32 = 32.0;
const arrow_h: f32 = 10.0;

// Pixel scale for bitmap font digits
const pixel_scale: f32 = 2.0;

// ---------------------------------------------------------------------------
// Colors
// ---------------------------------------------------------------------------

const Color = struct { r: f32, g: f32, b: f32, a: f32 };

const panel_bg = Color{ .r = 0.15, .g = 0.15, .b = 0.15, .a = 0.88 };
const panel_border_col = Color{ .r = 0.35, .g = 0.35, .b = 0.35, .a = 0.95 };
const slot_bg = Color{ .r = 0.22, .g = 0.22, .b = 0.22, .a = 0.90 };
const slot_border_col = Color{ .r = 0.45, .g = 0.45, .b = 0.45, .a = 0.90 };

const fire_bg = Color{ .r = 0.25, .g = 0.12, .b = 0.05, .a = 0.70 };
const fire_fill = Color{ .r = 1.0, .g = 0.55, .b = 0.05, .a = 1.0 };

const arrow_bg = Color{ .r = 0.30, .g = 0.30, .b = 0.30, .a = 0.70 };
const arrow_fill_col = Color{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 0.95 };

const title_col = Color{ .r = 0.90, .g = 0.90, .b = 0.90, .a = 1.0 };
const item_col = Color{ .r = 0.60, .g = 0.80, .b = 1.0, .a = 1.0 };
const count_col = Color{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 1.0 };

// ---------------------------------------------------------------------------
// Title pixel art (3-char abbreviated titles)
// ---------------------------------------------------------------------------

/// Simple 3-wide, 5-tall letter bitmasks (same encoding as bitmap_font digits).
const LetterGlyph = u15;

/// Letters used in titles: F, U, R, N, S, M, K, B, L, A, T
const letter_F: LetterGlyph = 0b111_100_110_100_100;
const letter_U: LetterGlyph = 0b101_101_101_101_111;
const letter_R: LetterGlyph = 0b110_101_110_101_101;
const letter_N: LetterGlyph = 0b101_111_111_101_101;
const letter_S: LetterGlyph = 0b111_100_111_001_111;
const letter_M: LetterGlyph = 0b101_111_111_101_101;
const letter_K: LetterGlyph = 0b101_110_100_110_101;
const letter_B: LetterGlyph = 0b110_101_110_101_110;
const letter_L: LetterGlyph = 0b100_100_100_100_111;
const letter_T: LetterGlyph = 0b111_010_010_010_010;

/// "FUR" for Furnace, "SMK" for Smoker, "BLT" for Blast Furnace
fn titleGlyphs(furnace_type: u8) [3]LetterGlyph {
    return switch (furnace_type) {
        1 => .{ letter_S, letter_M, letter_K },
        2 => .{ letter_B, letter_L, letter_T },
        else => .{ letter_F, letter_U, letter_R },
    };
}

fn getLetterPixel(glyph: LetterGlyph, x: u32, y: u32) bool {
    if (x >= 3 or y >= 5) return false;
    const bit_index: u4 = @intCast(y * 3 + x);
    return (glyph >> (14 - bit_index)) & 1 == 1;
}

// ---------------------------------------------------------------------------
// Quad helpers (local, operate on slice + counter)
// ---------------------------------------------------------------------------

/// Emit a solid-colored quad (2 triangles, 6 vertices). UV set to zero.
fn addQuad(verts: []UiVertex, idx: *u32, x: f32, y: f32, w: f32, h: f32, col: Color) void {
    if (idx.* + 6 > verts.len) return;
    const x1 = x + w;
    const y1 = y + h;

    verts[idx.*] = .{ .pos_x = x, .pos_y = y, .r = col.r, .g = col.g, .b = col.b, .a = col.a, .u = 0, .v = 0 };
    verts[idx.* + 1] = .{ .pos_x = x1, .pos_y = y, .r = col.r, .g = col.g, .b = col.b, .a = col.a, .u = 0, .v = 0 };
    verts[idx.* + 2] = .{ .pos_x = x, .pos_y = y1, .r = col.r, .g = col.g, .b = col.b, .a = col.a, .u = 0, .v = 0 };
    verts[idx.* + 3] = .{ .pos_x = x1, .pos_y = y, .r = col.r, .g = col.g, .b = col.b, .a = col.a, .u = 0, .v = 0 };
    verts[idx.* + 4] = .{ .pos_x = x1, .pos_y = y1, .r = col.r, .g = col.g, .b = col.b, .a = col.a, .u = 0, .v = 0 };
    verts[idx.* + 5] = .{ .pos_x = x, .pos_y = y1, .r = col.r, .g = col.g, .b = col.b, .a = col.a, .u = 0, .v = 0 };

    idx.* += 6;
}

/// Emit a textured quad (2 triangles, 6 vertices) with UV coordinates.
fn addTexQuad(verts: []UiVertex, idx: *u32, x: f32, y: f32, w: f32, h: f32, col: Color, tex_u0: f32, tex_v0: f32, tex_u1: f32, tex_v1: f32) void {
    if (idx.* + 6 > verts.len) return;
    const x1 = x + w;
    const y1 = y + h;

    verts[idx.*] = .{ .pos_x = x, .pos_y = y, .r = col.r, .g = col.g, .b = col.b, .a = col.a, .u = tex_u0, .v = tex_v0 };
    verts[idx.* + 1] = .{ .pos_x = x1, .pos_y = y, .r = col.r, .g = col.g, .b = col.b, .a = col.a, .u = tex_u1, .v = tex_v0 };
    verts[idx.* + 2] = .{ .pos_x = x, .pos_y = y1, .r = col.r, .g = col.g, .b = col.b, .a = col.a, .u = tex_u0, .v = tex_v1 };
    verts[idx.* + 3] = .{ .pos_x = x1, .pos_y = y, .r = col.r, .g = col.g, .b = col.b, .a = col.a, .u = tex_u1, .v = tex_v0 };
    verts[idx.* + 4] = .{ .pos_x = x1, .pos_y = y1, .r = col.r, .g = col.g, .b = col.b, .a = col.a, .u = tex_u1, .v = tex_v1 };
    verts[idx.* + 5] = .{ .pos_x = x, .pos_y = y1, .r = col.r, .g = col.g, .b = col.b, .a = col.a, .u = tex_u0, .v = tex_v1 };

    idx.* += 6;
}

/// Draw a slot background with border and optional item indicator + count.
fn renderSlot(verts: []UiVertex, idx: *u32, cx: f32, cy: f32, item: u16, count: u8) void {
    const x = cx - slot_size * 0.5;
    const y = cy - slot_size * 0.5;

    // Border
    addQuad(verts, idx, x - slot_border, y - slot_border, slot_size + slot_border * 2, slot_border, slot_border_col);
    addQuad(verts, idx, x - slot_border, y + slot_size, slot_size + slot_border * 2, slot_border, slot_border_col);
    addQuad(verts, idx, x - slot_border, y, slot_border, slot_size, slot_border_col);
    addQuad(verts, idx, x + slot_size, y, slot_border, slot_size, slot_border_col);

    // Background
    addQuad(verts, idx, x, y, slot_size, slot_size, slot_bg);

    // Item indicator (small colored square when item is present)
    if (item != 0 and count > 0) {
        const item_size: f32 = 20.0;
        addQuad(verts, idx, cx - item_size * 0.5, cy - item_size * 0.5, item_size, item_size, item_col);

        // Draw count as bitmap digits in the bottom-right of the slot
        if (count > 1) {
            drawNumber(verts, idx, x + slot_size - 2.0, y + slot_size - 2.0, count);
        }
    }
}

/// Draw a number (right-aligned, bottom-aligned at the given anchor) using
/// the bitmap font. Each pixel of the glyph becomes a tiny quad.
fn drawNumber(verts: []UiVertex, idx: *u32, right_x: f32, bottom_y: f32, value: u8) void {
    const val32: u32 = @intCast(value);
    const num_digits = bitmap_font.digitCount(val32);
    const glyph_w: f32 = @floatFromInt(bitmap_font.GLYPH_W);
    const glyph_h: f32 = @floatFromInt(bitmap_font.GLYPH_H);
    const digit_spacing: f32 = 1.0;

    const total_w = @as(f32, @floatFromInt(num_digits)) * (glyph_w * pixel_scale + digit_spacing) - digit_spacing;
    const start_x = right_x - total_w;
    const start_y = bottom_y - glyph_h * pixel_scale;

    var d: u32 = 0;
    while (d < num_digits) : (d += 1) {
        // Digits are stored least-significant first; render most-significant first
        const digit = bitmap_font.getDigit(val32, num_digits - 1 - d);
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
                        count_col,
                    );
                }
            }
        }
    }
}

/// Render a letter glyph at the given position using pixel quads.
fn drawLetter(verts: []UiVertex, idx: *u32, x: f32, y: f32, glyph: LetterGlyph, scale: f32, col: Color) void {
    var py: u32 = 0;
    while (py < 5) : (py += 1) {
        var px: u32 = 0;
        while (px < 3) : (px += 1) {
            if (getLetterPixel(glyph, px, py)) {
                addQuad(
                    verts,
                    idx,
                    x + @as(f32, @floatFromInt(px)) * scale,
                    y + @as(f32, @floatFromInt(py)) * scale,
                    scale,
                    scale,
                    col,
                );
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Public render entry point
// ---------------------------------------------------------------------------

/// Render the furnace screen UI into the provided vertex buffer.
/// Returns the number of vertices written.
pub fn render(verts: []UiVertex, start: u32, sw: f32, sh: f32, data: FurnaceData) u32 {
    var idx: u32 = start;

    const burn = std.math.clamp(data.burn_progress, 0.0, 1.0);
    const smelt = std.math.clamp(data.smelt_progress, 0.0, 1.0);

    // Panel centered on screen
    const px = (sw - panel_w) * 0.5;
    const py = (sh - panel_h) * 0.5;

    // Panel border
    const bw: f32 = 3.0;
    addQuad(verts, &idx, px - bw, py - bw, panel_w + bw * 2, bw, panel_border_col);
    addQuad(verts, &idx, px - bw, py + panel_h, panel_w + bw * 2, bw, panel_border_col);
    addQuad(verts, &idx, px - bw, py, bw, panel_h, panel_border_col);
    addQuad(verts, &idx, px + panel_w, py, bw, panel_h, panel_border_col);

    // Panel background
    addQuad(verts, &idx, px, py, panel_w, panel_h, panel_bg);

    // Title (abbreviated 3-letter name using pixel art)
    const title_scale: f32 = 3.0;
    const title_char_w: f32 = 3.0 * title_scale + 2.0; // glyph width * scale + gap
    const title_total_w: f32 = 3.0 * title_char_w - 2.0;
    const title_x = px + (panel_w - title_total_w) * 0.5;
    const title_y = py + 12.0;
    const glyphs_arr = titleGlyphs(data.furnace_type);
    for (0..3) |ci| {
        const offset = @as(f32, @floatFromInt(ci)) * title_char_w;
        drawLetter(verts, &idx, title_x + offset, title_y, glyphs_arr[ci], title_scale, title_col);
    }

    // Slot positions (relative to panel center)
    const center_x = px + panel_w * 0.5;
    const center_y = py + panel_h * 0.5;

    // Input slot: top-center
    const input_cx = center_x;
    const input_cy = center_y - 50.0;
    renderSlot(verts, &idx, input_cx, input_cy, data.input_item, data.input_count);

    // Fuel slot: below-left of input
    const fuel_cx = center_x - 50.0;
    const fuel_cy = center_y + 30.0;
    renderSlot(verts, &idx, fuel_cx, fuel_cy, data.fuel_item, data.fuel_count);

    // Output slot: right of center
    const output_cx = center_x + 70.0;
    const output_cy = center_y;
    renderSlot(verts, &idx, output_cx, output_cy, data.output_item, data.output_count);

    // Fire icon: between fuel slot and input slot (vertical bar, fills from bottom)
    const fire_x = fuel_cx - fire_w * 0.5;
    const fire_y = input_cy + slot_size * 0.5 + 8.0;

    // Fire background
    addQuad(verts, &idx, fire_x, fire_y, fire_w, fire_h, fire_bg);

    // Fire fill (from bottom upward based on burn_progress)
    if (burn > 0.0) {
        const fill_h = fire_h * burn;
        addQuad(verts, &idx, fire_x, fire_y + fire_h - fill_h, fire_w, fill_h, fire_fill);
    }

    // Arrow: between fire/input area and output slot (horizontal bar, fills from left)
    const arrow_x = center_x - arrow_w * 0.5 + 10.0;
    const arrow_y = center_y - arrow_h * 0.5;

    // Arrow background
    addQuad(verts, &idx, arrow_x, arrow_y, arrow_w, arrow_h, arrow_bg);

    // Arrow fill (from left based on smelt_progress)
    if (smelt > 0.0) {
        addQuad(verts, &idx, arrow_x, arrow_y, arrow_w * smelt, arrow_h, arrow_fill_col);
    }

    return idx - start;
}

// ===========================================================================
// Tests
// ===========================================================================

test "render returns non-zero vertices for default data" {
    var buf: [max_vertices]UiVertex = undefined;
    const count = render(&buf, 0, 800.0, 600.0, .{});
    // At minimum: 4 border + 1 bg + title glyphs + 3 slots (5 quads each minimum) + fire bg + arrow bg
    try std.testing.expect(count >= 6 * 10);
    try std.testing.expect(count % 6 == 0); // always whole quads
}

test "render with active smelting produces more vertices than idle" {
    var buf_idle: [max_vertices]UiVertex = undefined;
    const idle_count = render(&buf_idle, 0, 800.0, 600.0, .{});

    var buf_active: [max_vertices]UiVertex = undefined;
    const active_count = render(&buf_active, 0, 800.0, 600.0, .{
        .input_item = 4,
        .input_count = 1,
        .fuel_item = 5,
        .fuel_count = 1,
        .burn_progress = 0.7,
        .smelt_progress = 0.5,
    });

    // Active state has fire fill + arrow fill + item quads + count digits
    try std.testing.expect(active_count > idle_count);
}

test "render respects start offset" {
    var buf: [max_vertices]UiVertex = undefined;
    const sentinel: u32 = 42;
    const count = render(&buf, sentinel, 800.0, 600.0, .{});
    // Vertices are written starting at `start`, count is relative
    try std.testing.expect(count > 0);
    // First vertex written should be at index 42
    try std.testing.expect(buf[sentinel].pos_x != 0.0 or buf[sentinel].pos_y != 0.0 or buf[sentinel].a != 0.0);
}

test "render clamps burn and smelt progress" {
    var buf: [max_vertices]UiVertex = undefined;
    // Out-of-range values should not crash
    const count = render(&buf, 0, 800.0, 600.0, .{
        .burn_progress = 1.5,
        .smelt_progress = -0.3,
    });
    try std.testing.expect(count > 0);
}

test "render handles all furnace types" {
    var buf: [max_vertices]UiVertex = undefined;
    const c0 = render(&buf, 0, 800.0, 600.0, .{ .furnace_type = 0 });
    const c1 = render(&buf, 0, 800.0, 600.0, .{ .furnace_type = 1 });
    const c2 = render(&buf, 0, 800.0, 600.0, .{ .furnace_type = 2 });
    // All types produce valid output
    try std.testing.expect(c0 > 0);
    try std.testing.expect(c1 > 0);
    try std.testing.expect(c2 > 0);
}

test "render panel is centered" {
    var buf: [max_vertices]UiVertex = undefined;
    _ = render(&buf, 0, 800.0, 600.0, .{});

    // First quad is the top border; its x should be roughly (800-350)/2 - 3 = 222
    const expected_x = (800.0 - panel_w) * 0.5 - 3.0;
    try std.testing.expectApproxEqAbs(expected_x, buf[0].pos_x, 0.01);

    const expected_y = (600.0 - panel_h) * 0.5 - 3.0;
    try std.testing.expectApproxEqAbs(expected_y, buf[0].pos_y, 0.01);
}

test "render does not overflow small buffer" {
    // A tiny buffer should not crash — addQuad guards against overflow
    var buf: [12]UiVertex = undefined;
    const count = render(&buf, 0, 800.0, 600.0, .{
        .input_item = 1,
        .input_count = 64,
        .fuel_item = 2,
        .fuel_count = 32,
        .output_item = 3,
        .output_count = 16,
        .burn_progress = 0.5,
        .smelt_progress = 0.8,
    });
    try std.testing.expect(count <= 12);
}

test "addQuad writes exactly 6 vertices" {
    var buf: [6]UiVertex = undefined;
    var idx: u32 = 0;
    addQuad(&buf, &idx, 10, 20, 30, 40, .{ .r = 1, .g = 0, .b = 0, .a = 1 });
    try std.testing.expectEqual(@as(u32, 6), idx);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), buf[0].pos_x, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 40.0), buf[2].pos_x, 0.01);
}

test "addTexQuad writes UV coordinates" {
    var buf: [6]UiVertex = undefined;
    var idx: u32 = 0;
    addTexQuad(&buf, &idx, 0, 0, 10, 10, .{ .r = 1, .g = 1, .b = 1, .a = 1 }, 0.1, 0.2, 0.9, 0.8);
    try std.testing.expectEqual(@as(u32, 6), idx);
    try std.testing.expectApproxEqAbs(@as(f32, 0.1), buf[0].u, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.2), buf[0].v, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.9), buf[1].u, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.8), buf[5].v, 0.001);
}

test "drawNumber renders digit pixels" {
    var buf: [512]UiVertex = undefined;
    var idx: u32 = 0;
    drawNumber(&buf, &idx, 100.0, 100.0, 42);
    // Two-digit number: each digit has up to 15 lit pixels, so expect > 0
    try std.testing.expect(idx > 0);
    try std.testing.expect(idx % 6 == 0);
}

test "renderSlot empty produces 5 quads" {
    var buf: [512]UiVertex = undefined;
    var idx: u32 = 0;
    renderSlot(&buf, &idx, 100.0, 100.0, 0, 0);
    // 4 border + 1 background = 5 quads = 30 verts
    try std.testing.expectEqual(@as(u32, 30), idx);
}

test "renderSlot with item produces extra quads" {
    var buf: [512]UiVertex = undefined;
    var idx: u32 = 0;
    renderSlot(&buf, &idx, 100.0, 100.0, 5, 10);
    // 4 border + 1 bg + 1 item + digit pixels > 30
    try std.testing.expect(idx > 30);
}

test "getLetterPixel returns correct bits" {
    // letter_F = 0b111_100_110_100_100
    // Top row should be all lit
    try std.testing.expect(getLetterPixel(letter_F, 0, 0));
    try std.testing.expect(getLetterPixel(letter_F, 1, 0));
    try std.testing.expect(getLetterPixel(letter_F, 2, 0));
    // Bottom-right should be off
    try std.testing.expect(!getLetterPixel(letter_F, 2, 4));
}
