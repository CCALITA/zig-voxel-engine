/// Stonecutter screen renderer: generates UI vertices for the stonecutter
/// interface. Layout: input slot on the left, 4x4 output grid on the right
/// with selection highlight. Pure vertex generation — no GPU dependencies.
const std = @import("std");
const bitmap_font = @import("../renderer/bitmap_font.zig");

// ── Vertex type ─────────────────────────────────────────────────────────

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

// ── Layout constants ────────────────────────────────────────────────────

const panel_w: f32 = 260.0;
const panel_h: f32 = 180.0;

const slot_size: f32 = 32.0;
const slot_gap: f32 = 4.0;
const border: f32 = 2.0;
const grid_cols: u32 = 4;
const grid_rows: u32 = 4;

const input_margin_left: f32 = 16.0;
const grid_margin_left: f32 = 70.0;

const pixel_size: f32 = 2.0;
const digit_spacing: f32 = 1.0;

// ── Colors ──────────────────────────────────────────────────────────────

const Color = struct { r: f32, g: f32, b: f32, a: f32 };

const bg_color = Color{ .r = 0.15, .g = 0.15, .b = 0.15, .a = 0.88 };
const slot_bg = Color{ .r = 0.25, .g = 0.25, .b = 0.25, .a = 0.9 };
const slot_filled = Color{ .r = 0.40, .g = 0.55, .b = 0.40, .a = 0.9 };
const slot_empty = Color{ .r = 0.20, .g = 0.20, .b = 0.20, .a = 0.7 };
const highlight = Color{ .r = 1.0, .g = 1.0, .b = 0.0, .a = 1.0 };
const text_color = Color{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 1.0 };
const arrow_color = Color{ .r = 0.7, .g = 0.7, .b = 0.7, .a = 0.9 };

// ── Quad helpers ────────────────────────────────────────────────────────

pub fn addQuad(verts: []UiVertex, idx: *u32, x: f32, y: f32, w: f32, h: f32, col: Color) void {
    if (idx.* + 6 > verts.len) return;
    const x1 = x + w;
    const y1 = y + h;
    verts[idx.*] = .{ .pos_x = x, .pos_y = y, .r = col.r, .g = col.g, .b = col.b, .a = col.a, .u = 0, .v = 0 };
    verts[idx.* + 1] = .{ .pos_x = x1, .pos_y = y, .r = col.r, .g = col.g, .b = col.b, .a = col.a, .u = 1, .v = 0 };
    verts[idx.* + 2] = .{ .pos_x = x, .pos_y = y1, .r = col.r, .g = col.g, .b = col.b, .a = col.a, .u = 0, .v = 1 };
    verts[idx.* + 3] = .{ .pos_x = x1, .pos_y = y, .r = col.r, .g = col.g, .b = col.b, .a = col.a, .u = 1, .v = 0 };
    verts[idx.* + 4] = .{ .pos_x = x1, .pos_y = y1, .r = col.r, .g = col.g, .b = col.b, .a = col.a, .u = 1, .v = 1 };
    verts[idx.* + 5] = .{ .pos_x = x, .pos_y = y1, .r = col.r, .g = col.g, .b = col.b, .a = col.a, .u = 0, .v = 1 };
    idx.* += 6;
}

pub fn addTexQuad(verts: []UiVertex, idx: *u32, x: f32, y: f32, w: f32, h: f32, col: Color, u0: f32, v0: f32, u1: f32, v1: f32) void {
    if (idx.* + 6 > verts.len) return;
    const x1 = x + w;
    const y1 = y + h;
    verts[idx.*] = .{ .pos_x = x, .pos_y = y, .r = col.r, .g = col.g, .b = col.b, .a = col.a, .u = u0, .v = v0 };
    verts[idx.* + 1] = .{ .pos_x = x1, .pos_y = y, .r = col.r, .g = col.g, .b = col.b, .a = col.a, .u = u1, .v = v0 };
    verts[idx.* + 2] = .{ .pos_x = x, .pos_y = y1, .r = col.r, .g = col.g, .b = col.b, .a = col.a, .u = u0, .v = v1 };
    verts[idx.* + 3] = .{ .pos_x = x1, .pos_y = y, .r = col.r, .g = col.g, .b = col.b, .a = col.a, .u = u1, .v = v0 };
    verts[idx.* + 4] = .{ .pos_x = x1, .pos_y = y1, .r = col.r, .g = col.g, .b = col.b, .a = col.a, .u = u1, .v = v1 };
    verts[idx.* + 5] = .{ .pos_x = x, .pos_y = y1, .r = col.r, .g = col.g, .b = col.b, .a = col.a, .u = u0, .v = v1 };
    idx.* += 6;
}

/// Render a single slot background (filled or empty).
pub fn renderSlot(verts: []UiVertex, idx: *u32, x: f32, y: f32, filled: bool) void {
    const col = if (filled) slot_filled else slot_empty;
    addQuad(verts, idx, x, y, slot_size, slot_size, col);
}

/// Draw a number at (x, y) using the bitmap font. Each lit pixel becomes a
/// small quad of `pixel_size` x `pixel_size`. Returns the total width drawn.
pub fn drawNumber(verts: []UiVertex, idx: *u32, x: f32, y: f32, value: u32) f32 {
    const num_digits = bitmap_font.digitCount(value);
    const gw: f32 = @floatFromInt(bitmap_font.GLYPH_W);
    const char_w = gw * pixel_size + digit_spacing;
    var cursor_x = x;

    // Render most-significant digit first (leftmost).
    var d: u32 = 0;
    while (d < num_digits) : (d += 1) {
        const digit = bitmap_font.getDigit(value, num_digits - 1 - d);
        var py: u32 = 0;
        while (py < bitmap_font.GLYPH_H) : (py += 1) {
            var px: u32 = 0;
            while (px < bitmap_font.GLYPH_W) : (px += 1) {
                if (bitmap_font.getPixel(digit, px, py)) {
                    const qx = cursor_x + @as(f32, @floatFromInt(px)) * pixel_size;
                    const qy = y + @as(f32, @floatFromInt(py)) * pixel_size;
                    addQuad(verts, idx, qx, qy, pixel_size, pixel_size, text_color);
                }
            }
        }
        cursor_x += char_w;
    }

    return @as(f32, @floatFromInt(num_digits)) * char_w;
}

// ── Main render function ────────────────────────────────────────────────

/// Generate all UI vertices for the stonecutter screen.
///
/// Layout:
///   - Dark semi-transparent panel centred on screen
///   - Input slot on the left with item count
///   - Arrow indicator between input and output grid
///   - 4x4 output grid on the right; occupied cells are brighter
///   - Yellow border highlight on the selected output slot
///
/// Returns the number of vertices written starting from `start`.
pub fn render(
    verts: []UiVertex,
    start: u32,
    sw: f32,
    sh: f32,
    input_item: u16,
    input_count: u8,
    outputs: [16]u16,
    output_count: u8,
    selected: ?u8,
) u32 {
    var idx: u32 = start;

    // Panel origin (centred).
    const px = (sw - panel_w) * 0.5;
    const py = (sh - panel_h) * 0.5;

    // Background panel.
    addQuad(verts, &idx, px, py, panel_w, panel_h, bg_color);

    // ── Input slot ──────────────────────────────────────────────────
    const in_x = px + input_margin_left;
    const in_y = py + (panel_h - slot_size) * 0.5;

    renderSlot(verts, &idx, in_x, in_y, input_item != 0);

    // Item count badge (bottom-right of slot).
    if (input_item != 0 and input_count > 1) {
        const count_x = in_x + slot_size - 12.0;
        const count_y = in_y + slot_size - 12.0;
        _ = drawNumber(verts, &idx, count_x, count_y, @as(u32, input_count));
    }

    // ── Arrow between input and grid ────────────────────────────────
    const arrow_x = in_x + slot_size + 6.0;
    const arrow_y = in_y + slot_size * 0.5 - 2.0;
    addQuad(verts, &idx, arrow_x, arrow_y, 12.0, 4.0, arrow_color);

    // ── 4x4 output grid ────────────────────────────────────────────
    const grid_x = px + grid_margin_left;
    const grid_y = py + (panel_h - @as(f32, @floatFromInt(grid_rows)) * (slot_size + slot_gap) + slot_gap) * 0.5;

    var cell: u32 = 0;
    while (cell < grid_rows * grid_cols) : (cell += 1) {
        const col_idx: u32 = cell % grid_cols;
        const row_idx: u32 = cell / grid_cols;
        const cx = grid_x + @as(f32, @floatFromInt(col_idx)) * (slot_size + slot_gap);
        const cy = grid_y + @as(f32, @floatFromInt(row_idx)) * (slot_size + slot_gap);

        const filled = cell < @as(u32, output_count) and outputs[cell] != 0;
        renderSlot(verts, &idx, cx, cy, filled);

        // Selection highlight (yellow border).
        if (selected) |sel| {
            if (sel == cell) {
                // Top edge
                addQuad(verts, &idx, cx - border, cy - border, slot_size + border * 2.0, border, highlight);
                // Bottom edge
                addQuad(verts, &idx, cx - border, cy + slot_size, slot_size + border * 2.0, border, highlight);
                // Left edge
                addQuad(verts, &idx, cx - border, cy, border, slot_size, highlight);
                // Right edge
                addQuad(verts, &idx, cx + slot_size, cy, border, slot_size, highlight);
            }
        }
    }

    return idx - start;
}

// ── Tests ───────────────────────────────────────────────────────────────

const testing = std.testing;

test "render returns zero vertices for empty state" {
    var buf: [max_vertices]UiVertex = undefined;
    const count = render(&buf, 0, 800, 600, 0, 0, [_]u16{0} ** 16, 0, null);
    // Panel(6) + input slot(6) + arrow(6) + 16 empty grid slots(96) = 114
    try testing.expectEqual(@as(u32, 114), count);
}

test "render adds highlight for selected output" {
    var buf: [max_vertices]UiVertex = undefined;
    var outputs = [_]u16{0} ** 16;
    outputs[0] = 500;
    outputs[1] = 501;

    const without_sel = render(&buf, 0, 800, 600, 1, 3, outputs, 2, null);

    var buf2: [max_vertices]UiVertex = undefined;
    const with_sel = render(&buf2, 0, 800, 600, 1, 3, outputs, 2, 0);

    // Selection adds 4 border quads = 24 vertices.
    try testing.expectEqual(without_sel + 24, with_sel);
}

test "render adds count badge when input_count > 1" {
    var buf: [max_vertices]UiVertex = undefined;
    const count_one = render(&buf, 0, 800, 600, 1, 1, [_]u16{0} ** 16, 0, null);

    var buf2: [max_vertices]UiVertex = undefined;
    const count_five = render(&buf2, 0, 800, 600, 1, 5, [_]u16{0} ** 16, 0, null);

    // count > 1 adds digit quads; count == 1 does not.
    try testing.expect(count_five > count_one);
}

test "render starts at given offset" {
    var buf: [max_vertices]UiVertex = undefined;
    const start: u32 = 42;
    const count = render(&buf, start, 800, 600, 0, 0, [_]u16{0} ** 16, 0, null);
    // Vertices are written starting at index 42.
    // First vertex should have a valid position (the panel top-left).
    try testing.expect(buf[start].pos_x > 0);
    try testing.expect(count > 0);
}

test "render handles all 16 outputs filled" {
    var buf: [max_vertices]UiVertex = undefined;
    var outputs = [_]u16{0} ** 16;
    for (&outputs, 0..) |*o, i| {
        o.* = @as(u16, @intCast(500 + i));
    }
    const count = render(&buf, 0, 800, 600, 1, 64, outputs, 16, 15);
    // Should succeed without overflow.
    try testing.expect(count > 0);
}

test "addQuad writes 6 vertices" {
    var buf: [12]UiVertex = undefined;
    var idx: u32 = 0;
    addQuad(&buf, &idx, 10, 20, 30, 40, slot_bg);
    try testing.expectEqual(@as(u32, 6), idx);
    try testing.expectApproxEqAbs(@as(f32, 10.0), buf[0].pos_x, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 20.0), buf[0].pos_y, 0.001);
}

test "addTexQuad preserves UV coordinates" {
    var buf: [12]UiVertex = undefined;
    var idx: u32 = 0;
    addTexQuad(&buf, &idx, 0, 0, 16, 16, slot_bg, 0.25, 0.5, 0.75, 1.0);
    try testing.expectEqual(@as(u32, 6), idx);
    try testing.expectApproxEqAbs(@as(f32, 0.25), buf[0].u, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 0.5), buf[0].v, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 0.75), buf[1].u, 0.001);
}

test "renderSlot emits 6 vertices" {
    var buf: [12]UiVertex = undefined;
    var idx: u32 = 0;
    renderSlot(&buf, &idx, 0, 0, true);
    try testing.expectEqual(@as(u32, 6), idx);
}

test "drawNumber renders correct pixel count for digit 1" {
    var buf: [max_vertices]UiVertex = undefined;
    var idx: u32 = 0;
    _ = drawNumber(&buf, &idx, 0, 0, 1);
    // Digit '1' bitmap: 0b010_110_010_010_111 has 8 lit pixels.
    try testing.expectEqual(@as(u32, 8 * 6), idx);
}

test "drawNumber renders multi-digit number" {
    var buf: [max_vertices]UiVertex = undefined;
    var idx: u32 = 0;
    _ = drawNumber(&buf, &idx, 0, 0, 42);
    // Two digits rendered; vertex count should be > single digit.
    try testing.expect(idx > 6);
}

test "addQuad overflow protection" {
    var buf: [3]UiVertex = undefined;
    var idx: u32 = 0;
    addQuad(&buf, &idx, 0, 0, 10, 10, slot_bg);
    try testing.expectEqual(@as(u32, 0), idx);
}

test "render panel is centred" {
    var buf: [max_vertices]UiVertex = undefined;
    _ = render(&buf, 0, 800, 600, 0, 0, [_]u16{0} ** 16, 0, null);
    // First quad is the background panel, top-left corner.
    const expected_x = (800.0 - panel_w) * 0.5;
    const expected_y = (600.0 - panel_h) * 0.5;
    try testing.expectApproxEqAbs(expected_x, buf[0].pos_x, 0.01);
    try testing.expectApproxEqAbs(expected_y, buf[0].pos_y, 0.01);
}

test "highlight not emitted when selected is null" {
    var buf: [max_vertices]UiVertex = undefined;
    var outputs = [_]u16{0} ** 16;
    outputs[0] = 500;
    const count_no_sel = render(&buf, 0, 800, 600, 1, 1, outputs, 1, null);

    var buf2: [max_vertices]UiVertex = undefined;
    const count_with_sel = render(&buf2, 0, 800, 600, 1, 1, outputs, 1, 0);

    try testing.expect(count_with_sel > count_no_sel);
}

test "filled vs empty output slots use different colors" {
    var buf: [max_vertices]UiVertex = undefined;
    var outputs = [_]u16{0} ** 16;
    outputs[0] = 500;
    // Render with 1 filled output.
    _ = render(&buf, 0, 800, 600, 1, 1, outputs, 1, null);

    // The first grid slot starts after: panel(6) + input(6) + arrow(6) = 18 verts,
    // at index 18. Filled slot should have slot_filled color.
    try testing.expectApproxEqAbs(slot_filled.r, buf[18].r, 0.01);
    try testing.expectApproxEqAbs(slot_filled.g, buf[18].g, 0.01);

    // The second grid slot (index 24) should be empty-colored.
    try testing.expectApproxEqAbs(slot_empty.r, buf[24].r, 0.01);
}
