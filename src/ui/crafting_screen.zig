/// Crafting table screen renderer.
/// Produces UiVertex quads for a centered 480x500 panel with:
///   - "Crafting" title bar
///   - 3x3 crafting grid (48px slots)
///   - Arrow indicator
///   - Output slot
///   - 3x9 main inventory + 1x9 hotbar with selection highlight
const std = @import("std");
const bitmap_font = @import("../renderer/bitmap_font.zig");

// ── Public types ────────────────────────────────────────────────────

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

pub const Slot = struct {
    item: u16,
    count: u8,

    pub fn isEmpty(s: Slot) bool {
        return s.count == 0;
    }
};

pub const max_vertices = 4096;

// ── Layout constants ────────────────────────────────────────────────

const panel_w: f32 = 480.0;
const panel_h: f32 = 500.0;

const slot_size: f32 = 48.0;
const slot_gap: f32 = 4.0;
const slot_border: f32 = 2.0;

const panel_pad: f32 = 16.0;
const title_bar_h: f32 = 32.0;
const section_gap: f32 = 12.0;

const arrow_w: f32 = 24.0;
const arrow_h: f32 = 12.0;
const arrow_gap: f32 = 14.0;

const pixel_scale: f32 = 2.0;

// ── Colors ──────────────────────────────────────────────────────────

const Color = struct { r: f32, g: f32, b: f32, a: f32 };

const panel_bg = Color{ .r = 0.75, .g = 0.75, .b = 0.75, .a = 0.94 };
const border_dark = Color{ .r = 0.34, .g = 0.34, .b = 0.34, .a = 1.0 };
const border_light = Color{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 1.0 };
const title_bg = Color{ .r = 0.30, .g = 0.30, .b = 0.30, .a = 1.0 };
const title_text = Color{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 1.0 };
const slot_bg = Color{ .r = 0.55, .g = 0.55, .b = 0.55, .a = 1.0 };
const slot_border_col = Color{ .r = 0.40, .g = 0.40, .b = 0.40, .a = 1.0 };
const item_col = Color{ .r = 0.60, .g = 0.80, .b = 1.0, .a = 1.0 };
const count_col = Color{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 1.0 };
const count_shadow = Color{ .r = 0.2, .g = 0.2, .b = 0.2, .a = 0.8 };
const arrow_col = Color{ .r = 0.45, .g = 0.45, .b = 0.45, .a = 0.9 };
const hotbar_sel_col = Color{ .r = 1.0, .g = 1.0, .b = 0.0, .a = 1.0 };

// ── Title pixel-art glyphs ──────────────────────────────────────────

/// 3x5 bitmask letters for "CRAFTING"
const LetterGlyph = u15;

const letter_C: LetterGlyph = 0b111_100_100_100_111;
const letter_R: LetterGlyph = 0b110_101_110_101_101;
const letter_A: LetterGlyph = 0b010_101_111_101_101;
const letter_F: LetterGlyph = 0b111_100_110_100_100;
const letter_T: LetterGlyph = 0b111_010_010_010_010;
const letter_I: LetterGlyph = 0b111_010_010_010_111;
const letter_N: LetterGlyph = 0b101_111_111_101_101;
const letter_G: LetterGlyph = 0b111_100_101_101_111;

const title_glyphs = [8]LetterGlyph{
    letter_C, letter_R, letter_A, letter_F,
    letter_T, letter_I, letter_N, letter_G,
};

fn getLetterPixel(glyph: LetterGlyph, x: u32, y: u32) bool {
    if (x >= 3 or y >= 5) return false;
    const bit_index: u4 = @intCast(y * 3 + x);
    return (glyph >> (14 - bit_index)) & 1 == 1;
}

// ── Quad helpers ────────────────────────────────────────────────────

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

// ── Drawing helpers ─────────────────────────────────────────────────

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
        const digit = bitmap_font.getDigit(val32, num_digits - 1 - d);
        const dx = start_x + @as(f32, @floatFromInt(d)) * (glyph_w * pixel_scale + digit_spacing);

        var py: u32 = 0;
        while (py < bitmap_font.GLYPH_H) : (py += 1) {
            var px: u32 = 0;
            while (px < bitmap_font.GLYPH_W) : (px += 1) {
                if (bitmap_font.getPixel(digit, px, py)) {
                    const fx = dx + @as(f32, @floatFromInt(px)) * pixel_scale;
                    const fy = start_y + @as(f32, @floatFromInt(py)) * pixel_scale;
                    // Shadow
                    addQuad(verts, idx, fx + 1.0, fy + 1.0, pixel_scale, pixel_scale, count_shadow);
                    // Foreground
                    addQuad(verts, idx, fx, fy, pixel_scale, pixel_scale, count_col);
                }
            }
        }
    }
}

// ── Slot rendering ──────────────────────────────────────────────────

fn renderSlot(verts: []UiVertex, idx: *u32, x: f32, y: f32, slot: Slot, bg: Color) void {
    // Border
    addQuad(verts, idx, x - slot_border, y - slot_border, slot_size + slot_border * 2, slot_border, slot_border_col);
    addQuad(verts, idx, x - slot_border, y + slot_size, slot_size + slot_border * 2, slot_border, slot_border_col);
    addQuad(verts, idx, x - slot_border, y, slot_border, slot_size, slot_border_col);
    addQuad(verts, idx, x + slot_size, y, slot_border, slot_size, slot_border_col);

    // Background
    addQuad(verts, idx, x, y, slot_size, slot_size, bg);

    // Item indicator
    if (!slot.isEmpty()) {
        const item_size: f32 = 28.0;
        const cx = x + slot_size * 0.5;
        const cy = y + slot_size * 0.5;
        addQuad(verts, idx, cx - item_size * 0.5, cy - item_size * 0.5, item_size, item_size, item_col);

        if (slot.count > 1) {
            drawNumber(verts, idx, x + slot_size - 2.0, y + slot_size - 2.0, slot.count);
        }
    }
}

// ── Arrow rendering ─────────────────────────────────────────────────

fn renderArrow(verts: []UiVertex, idx: *u32, x: f32, y: f32) void {
    // Horizontal bar
    addQuad(verts, idx, x, y, arrow_w, arrow_h, arrow_col);
    // Arrowhead (two small quads forming a triangle-like shape)
    addQuad(verts, idx, x + arrow_w, y - 4.0, 4.0, arrow_h + 8.0, arrow_col);
    addQuad(verts, idx, x + arrow_w + 4.0, y, 4.0, arrow_h, arrow_col);
}

// ── Main render function ────────────────────────────────────────────

/// Render the crafting table screen into the provided vertex buffer.
/// Returns the number of vertices written (starting from `start`).
pub fn render(
    verts: []UiVertex,
    start: u32,
    sw: f32,
    sh: f32,
    grid: [9]Slot,
    output: Slot,
    inv: [36]Slot,
    sel: u8,
) u32 {
    var idx: u32 = start;

    // Panel origin (centered)
    const ox = (sw - panel_w) * 0.5;
    const oy = (sh - panel_h) * 0.5;

    // ── Panel background ────────────────────────────────────────
    addQuad(verts, &idx, ox, oy, panel_w, panel_h, panel_bg);

    // Borders (light top/left, dark bottom/right for 3D bevel)
    addQuad(verts, &idx, ox, oy, panel_w, 2.0, border_light);
    addQuad(verts, &idx, ox, oy, 2.0, panel_h, border_light);
    addQuad(verts, &idx, ox, oy + panel_h - 2.0, panel_w, 2.0, border_dark);
    addQuad(verts, &idx, ox + panel_w - 2.0, oy, 2.0, panel_h, border_dark);

    // ── Title bar ───────────────────────────────────────────────
    const title_y = oy + panel_pad;
    addQuad(verts, &idx, ox + panel_pad, title_y, panel_w - panel_pad * 2, title_bar_h, title_bg);

    // "CRAFTING" pixel-art text centered in the title bar
    const title_scale: f32 = 3.0;
    const char_w: f32 = 3.0 * title_scale + 2.0;
    const title_total_w: f32 = 8.0 * char_w - 2.0;
    const title_text_x = ox + (panel_w - title_total_w) * 0.5;
    const title_text_y = title_y + (title_bar_h - 5.0 * title_scale) * 0.5;
    for (0..8) |ci| {
        const offset = @as(f32, @floatFromInt(ci)) * char_w;
        drawLetter(verts, &idx, title_text_x + offset, title_text_y, title_glyphs[ci], title_scale, title_text);
    }

    // ── Crafting grid (3x3) ─────────────────────────────────────
    const grid_total = 3.0 * slot_size + 2.0 * slot_gap;
    const craft_area_top = title_y + title_bar_h + section_gap;

    // Center the crafting grid + arrow + output horizontally
    const output_total_w = grid_total + arrow_gap + arrow_w + 8.0 + arrow_gap + slot_size;
    const craft_base_x = ox + (panel_w - output_total_w) * 0.5;
    const grid_center_y = craft_area_top + grid_total * 0.5;

    for (0..3) |row| {
        for (0..3) |col| {
            const fr: f32 = @floatFromInt(row);
            const fc: f32 = @floatFromInt(col);
            const gx = craft_base_x + fc * (slot_size + slot_gap);
            const gy = craft_area_top + fr * (slot_size + slot_gap);
            const grid_idx = row * 3 + col;
            renderSlot(verts, &idx, gx, gy, grid[grid_idx], slot_bg);
        }
    }

    // ── Arrow ───────────────────────────────────────────────────
    const arrow_x = craft_base_x + grid_total + arrow_gap;
    const arrow_y = craft_area_top + grid_total * 0.5 - arrow_h * 0.5;
    renderArrow(verts, &idx, arrow_x, arrow_y);

    // ── Output slot ─────────────────────────────────────────────
    const out_x = arrow_x + arrow_w + 8.0 + arrow_gap;
    const out_y = grid_center_y - slot_size * 0.5;
    renderSlot(verts, &idx, out_x, out_y, output, slot_bg);

    // ── Lower section: 3x9 main inventory + 1x9 hotbar ─────────
    const inv_total_w = 9.0 * slot_size + 8.0 * slot_gap;
    const inv_base_x = ox + (panel_w - inv_total_w) * 0.5;

    // 3x9 main inventory (slots 9..35)
    const inv_top = oy + panel_h - panel_pad - 4.0 * (slot_size + slot_gap) - section_gap;
    for (0..3) |row| {
        const fr: f32 = @floatFromInt(row);
        const row_y = inv_top + fr * (slot_size + slot_gap);
        const row_start = 9 + row * 9;
        for (0..9) |col| {
            const fc: f32 = @floatFromInt(col);
            const sx = inv_base_x + fc * (slot_size + slot_gap);
            renderSlot(verts, &idx, sx, row_y, inv[row_start + col], slot_bg);
        }
    }

    // 1x9 hotbar (slots 0..8, below main with gap)
    const hotbar_y = inv_top + 3.0 * (slot_size + slot_gap) + section_gap;
    for (0..9) |i| {
        const fi: f32 = @floatFromInt(i);
        const hx = inv_base_x + fi * (slot_size + slot_gap);
        const bg = if (i == sel) hotbar_sel_col else slot_bg;
        renderSlot(verts, &idx, hx, hotbar_y, inv[i], bg);
    }

    return idx - start;
}

// ═══════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════

const empty_slot = Slot{ .item = 0, .count = 0 };
const empty_grid = [_]Slot{empty_slot} ** 9;
const empty_inv = [_]Slot{empty_slot} ** 36;

test "Slot isEmpty returns true for zero count" {
    const s = Slot{ .item = 42, .count = 0 };
    try std.testing.expect(s.isEmpty());
}

test "Slot isEmpty returns false for nonzero count" {
    const s = Slot{ .item = 1, .count = 5 };
    try std.testing.expect(!s.isEmpty());
}

test "render returns nonzero vertex count for empty data" {
    var buf: [max_vertices]UiVertex = undefined;
    const count = render(&buf, 0, 800.0, 600.0, empty_grid, empty_slot, empty_inv, 0);
    // Must produce at least: panel bg + 4 borders + title bar + title glyphs
    // + 9 grid slots + arrow + output slot + 27 inv slots + 9 hotbar slots
    try std.testing.expect(count >= 6 * 20);
    try std.testing.expect(count % 6 == 0);
}

test "render panel is centered" {
    var buf: [max_vertices]UiVertex = undefined;
    const sw: f32 = 1920.0;
    const sh: f32 = 1080.0;
    _ = render(&buf, 0, sw, sh, empty_grid, empty_slot, empty_inv, 0);
    // First quad is the panel background
    const expected_x = (sw - panel_w) * 0.5;
    const expected_y = (sh - panel_h) * 0.5;
    try std.testing.expectApproxEqAbs(expected_x, buf[0].pos_x, 0.01);
    try std.testing.expectApproxEqAbs(expected_y, buf[0].pos_y, 0.01);
}

test "render respects start offset" {
    var buf: [max_vertices]UiVertex = undefined;
    const offset: u32 = 24;
    const count = render(&buf, offset, 800.0, 600.0, empty_grid, empty_slot, empty_inv, 0);
    try std.testing.expect(count > 0);
    try std.testing.expect(count % 6 == 0);
    // Vertex at offset should have been written (panel bg)
    try std.testing.expect(buf[offset].a != 0.0);
}

test "filled grid produces more vertices than empty" {
    var buf_empty: [max_vertices]UiVertex = undefined;
    const count_empty = render(&buf_empty, 0, 800.0, 600.0, empty_grid, empty_slot, empty_inv, 0);

    var filled_grid: [9]Slot = undefined;
    for (0..9) |i| {
        filled_grid[i] = Slot{ .item = @intCast(i + 1), .count = 32 };
    }
    const filled_output = Slot{ .item = 10, .count = 1 };
    var buf_filled: [max_vertices]UiVertex = undefined;
    const count_filled = render(&buf_filled, 0, 800.0, 600.0, filled_grid, filled_output, empty_inv, 0);

    try std.testing.expect(count_filled > count_empty);
}

test "addQuad writes exactly 6 vertices with u=-1 v=-1" {
    var buf: [6]UiVertex = undefined;
    var idx: u32 = 0;
    addQuad(&buf, &idx, 10.0, 20.0, 50.0, 30.0, .{ .r = 1, .g = 0, .b = 0, .a = 1 });
    try std.testing.expectEqual(@as(u32, 6), idx);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), buf[0].pos_x, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 20.0), buf[0].pos_y, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, -1.0), buf[0].u, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, -1.0), buf[0].v, 0.001);
}

test "addQuad overflow protection" {
    var buf: [4]UiVertex = undefined;
    var idx: u32 = 0;
    addQuad(&buf, &idx, 0, 0, 10, 10, .{ .r = 1, .g = 1, .b = 1, .a = 1 });
    // Buffer too small for 6 verts, should write nothing
    try std.testing.expectEqual(@as(u32, 0), idx);
}

test "drawNumber renders digit pixels" {
    var buf: [512]UiVertex = undefined;
    var idx: u32 = 0;
    drawNumber(&buf, &idx, 100.0, 100.0, 64);
    try std.testing.expect(idx > 0);
    try std.testing.expect(idx % 6 == 0);
}

test "renderSlot empty produces border + bg quads only" {
    var buf: [512]UiVertex = undefined;
    var idx: u32 = 0;
    renderSlot(&buf, &idx, 100.0, 100.0, empty_slot, slot_bg);
    // 4 border + 1 bg = 5 quads = 30 verts
    try std.testing.expectEqual(@as(u32, 30), idx);
}

test "renderSlot with item produces extra quads" {
    var buf: [512]UiVertex = undefined;
    var idx: u32 = 0;
    renderSlot(&buf, &idx, 100.0, 100.0, Slot{ .item = 5, .count = 10 }, slot_bg);
    // 4 border + 1 bg + 1 item + digit quads > 30
    try std.testing.expect(idx > 30);
}

test "buffer overflow on full render does not crash" {
    var buf: [12]UiVertex = undefined;
    var filled_grid: [9]Slot = undefined;
    for (0..9) |i| {
        filled_grid[i] = Slot{ .item = @intCast(i + 1), .count = 64 };
    }
    var filled_inv: [36]Slot = undefined;
    for (0..36) |i| {
        filled_inv[i] = Slot{ .item = @intCast(i % 20), .count = 64 };
    }
    const count = render(&buf, 0, 800.0, 600.0, filled_grid, Slot{ .item = 1, .count = 1 }, filled_inv, 4);
    try std.testing.expect(count <= 12);
}

test "full inventory generates bounded vertex count" {
    var buf: [max_vertices]UiVertex = undefined;
    var filled_grid: [9]Slot = undefined;
    for (0..9) |i| {
        filled_grid[i] = Slot{ .item = @intCast(i + 1), .count = 64 };
    }
    var filled_inv: [36]Slot = undefined;
    for (0..36) |i| {
        filled_inv[i] = Slot{ .item = @intCast(i % 20), .count = 64 };
    }
    const count = render(&buf, 0, 1920.0, 1080.0, filled_grid, Slot{ .item = 5, .count = 4 }, filled_inv, 3);
    try std.testing.expect(count <= max_vertices);
    try std.testing.expect(count > 0);
}

test "getLetterPixel returns correct bits for C" {
    // letter_C = 0b111_100_100_100_111
    // Top row: all lit
    try std.testing.expect(getLetterPixel(letter_C, 0, 0));
    try std.testing.expect(getLetterPixel(letter_C, 1, 0));
    try std.testing.expect(getLetterPixel(letter_C, 2, 0));
    // Middle rows: only leftmost
    try std.testing.expect(getLetterPixel(letter_C, 0, 1));
    try std.testing.expect(!getLetterPixel(letter_C, 1, 1));
    try std.testing.expect(!getLetterPixel(letter_C, 2, 1));
    // Bottom row: all lit
    try std.testing.expect(getLetterPixel(letter_C, 0, 4));
    try std.testing.expect(getLetterPixel(letter_C, 1, 4));
    try std.testing.expect(getLetterPixel(letter_C, 2, 4));
}
