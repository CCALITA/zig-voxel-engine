/// Anvil UI screen renderer.
/// Produces UiVertex quads for a centered 400x300 panel with three slots
/// (input, material, output), plus/arrow indicators, XP cost display,
/// and a rename-length indicator bar.
const std = @import("std");
const bitmap_font = @import("../renderer/bitmap_font.zig");

// ── Types ────────────────────────────────────────────────────────────────

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

pub const AnvilData = struct {
    input_item: u16 = 0,
    input_count: u8 = 0,
    material_item: u16 = 0,
    material_count: u8 = 0,
    output_item: u16 = 0,
    output_count: u8 = 0,
    xp_cost: u8 = 0,
    rename_len: u8 = 0,
};

// ── Layout constants ─────────────────────────────────────────────────────

const panel_w: f32 = 400.0;
const panel_h: f32 = 300.0;
const slot_size: f32 = 48.0;
const title_bar_h: f32 = 28.0;
const rename_bar_h: f32 = 24.0;
const rename_max_w: f32 = 320.0;
const digit_scale: f32 = 2.5;

// Colors (rgba arrays)
const dim_overlay = [_]f32{ 0.0, 0.0, 0.0, 0.60 };
const panel_border = [_]f32{ 0.15, 0.15, 0.15, 0.95 };
const panel_bg = [_]f32{ 0.55, 0.55, 0.55, 0.95 };
const title_bar_col = [_]f32{ 0.40, 0.40, 0.40, 1.00 };
const slot_border_col = [_]f32{ 0.30, 0.30, 0.30, 1.00 };
const slot_bg_col = [_]f32{ 0.42, 0.42, 0.42, 0.90 };
const item_filled = [_]f32{ 0.78, 0.62, 0.36, 0.95 };
const item_empty = [_]f32{ 0.50, 0.50, 0.50, 0.30 };
const plus_col = [_]f32{ 0.80, 0.80, 0.80, 0.70 };
const arrow_col = [_]f32{ 0.80, 0.80, 0.80, 0.60 };
const xp_color = [_]f32{ 0.30, 0.90, 0.10, 1.00 };
const rename_bg = [_]f32{ 0.20, 0.20, 0.20, 0.80 };

// ── Public API ───────────────────────────────────────────────────────────

/// Render the anvil screen into `verts` starting at index `start`.
/// Returns the new vertex index (not count of vertices written).
pub fn render(verts: []UiVertex, start: u32, sw: f32, sh: f32, data: AnvilData) u32 {
    var c = start;

    // Dark overlay
    c = addQuad(verts, c, 0, 0, sw, sh, dim_overlay);

    // Panel centered on screen
    const px = (sw - panel_w) / 2;
    const py = (sh - panel_h) / 2;
    c = addQuad(verts, c, px - 3, py - 3, panel_w + 6, panel_h + 6, panel_border);
    c = addQuad(verts, c, px, py, panel_w, panel_h, panel_bg);

    // Title bar
    c = addQuad(verts, c, px, py, panel_w, title_bar_h, title_bar_col);

    // Slot row: input, +, material, arrow, output
    const sy = py + 60;

    c = renderSlot(verts, c, px + 40, sy, slot_size, data.input_item, data.input_count);

    // "+" indicator (horizontal + vertical bars)
    c = addQuad(verts, c, px + 110, sy + 20, 12, 3, plus_col);
    c = addQuad(verts, c, px + 114, sy + 16, 3, 12, plus_col);

    c = renderSlot(verts, c, px + 150, sy, slot_size, data.material_item, data.material_count);

    // Arrow indicator (horizontal shaft)
    c = addQuad(verts, c, px + 220, sy + 22, 20, 3, arrow_col);

    c = renderSlot(verts, c, px + 270, sy, slot_size, data.output_item, data.output_count);

    // XP cost (green number below the arrow)
    if (data.xp_cost > 0) {
        c = drawNumber(verts, c, px + 180, sy + 65, data.xp_cost, digit_scale, xp_color);
    }

    // Rename indicator bar
    if (data.rename_len > 0) {
        const bar_w = @min(@as(f32, @floatFromInt(data.rename_len)) * 8, rename_max_w);
        c = addQuad(verts, c, px + 40, py + 150, bar_w, rename_bar_h, rename_bg);
    }

    return c;
}

// ── Drawing helpers ──────────────────────────────────────────────────────

/// Emit a coloured (untextured) quad as two triangles. Untextured: u=-1, v=-1.
fn addQuad(verts: []UiVertex, start: u32, x: f32, y: f32, w: f32, h: f32, col: [4]f32) u32 {
    if (start + 6 > verts.len) return start;
    const r = col[0];
    const g = col[1];
    const b = col[2];
    const a = col[3];
    verts[start + 0] = .{ .pos_x = x, .pos_y = y, .r = r, .g = g, .b = b, .a = a, .u = -1, .v = -1 };
    verts[start + 1] = .{ .pos_x = x + w, .pos_y = y, .r = r, .g = g, .b = b, .a = a, .u = -1, .v = -1 };
    verts[start + 2] = .{ .pos_x = x + w, .pos_y = y + h, .r = r, .g = g, .b = b, .a = a, .u = -1, .v = -1 };
    verts[start + 3] = .{ .pos_x = x, .pos_y = y, .r = r, .g = g, .b = b, .a = a, .u = -1, .v = -1 };
    verts[start + 4] = .{ .pos_x = x + w, .pos_y = y + h, .r = r, .g = g, .b = b, .a = a, .u = -1, .v = -1 };
    verts[start + 5] = .{ .pos_x = x, .pos_y = y + h, .r = r, .g = g, .b = b, .a = a, .u = -1, .v = -1 };
    return start + 6;
}

/// Render a single slot: border, background, item placeholder, and stack count.
fn renderSlot(verts: []UiVertex, start: u32, x: f32, y: f32, size: f32, item: u16, count: u8) u32 {
    var c = start;
    c = addQuad(verts, c, x, y, size, size, slot_border_col);
    c = addQuad(verts, c, x + 2, y + 2, size - 4, size - 4, slot_bg_col);

    if (item != 0) {
        c = addQuad(verts, c, x + 6, y + 6, size - 12, size - 12, item_filled);
    } else {
        c = addQuad(verts, c, x + 8, y + 8, size - 16, size - 16, item_empty);
    }

    if (count > 1) {
        const num_x = x + size - 14;
        const num_y = y + size - 12;
        c = drawNumber(verts, c, num_x, num_y, count, 1.5, .{ 1.0, 1.0, 1.0, 1.0 });
    }

    return c;
}

/// Draw a non-negative integer using the shared bitmap font.
fn drawNumber(verts: []UiVertex, start: u32, x: f32, y: f32, value: u8, scale: f32, col: [4]f32) u32 {
    var c = start;
    const val32: u32 = @intCast(value);
    const num_digits = bitmap_font.digitCount(val32);
    const char_w = @as(f32, @floatFromInt(bitmap_font.GLYPH_W)) * scale + scale;

    var di: u32 = 0;
    while (di < num_digits) : (di += 1) {
        const digit = bitmap_font.getDigit(val32, num_digits - 1 - di);
        const dx = x + @as(f32, @floatFromInt(di)) * char_w;
        var py: u32 = 0;
        while (py < bitmap_font.GLYPH_H) : (py += 1) {
            var px_i: u32 = 0;
            while (px_i < bitmap_font.GLYPH_W) : (px_i += 1) {
                if (bitmap_font.getPixel(digit, px_i, py)) {
                    c = addQuad(
                        verts,
                        c,
                        dx + @as(f32, @floatFromInt(px_i)) * scale,
                        y + @as(f32, @floatFromInt(py)) * scale,
                        scale,
                        scale,
                        col,
                    );
                }
            }
        }
    }
    return c;
}

// ── Tests ────────────────────────────────────────────────────────────────

const testing = std.testing;

test "UiVertex layout matches ui_pipeline shape" {
    try testing.expectEqual(@as(usize, 32), @sizeOf(UiVertex));
}

test "addQuad emits 6 vertices with u=-1, v=-1" {
    var buf: [6]UiVertex = undefined;
    const c = addQuad(&buf, 0, 10, 20, 30, 40, .{ 1, 0.5, 0.25, 0.75 });
    try testing.expectEqual(@as(u32, 6), c);
    try testing.expectEqual(@as(f32, 10), buf[0].pos_x);
    try testing.expectEqual(@as(f32, 20), buf[0].pos_y);
    for (buf) |v| {
        try testing.expectEqual(@as(f32, -1), v.u);
        try testing.expectEqual(@as(f32, -1), v.v);
    }
}

test "addQuad does nothing when buffer too small" {
    var buf: [3]UiVertex = undefined;
    const c = addQuad(&buf, 0, 0, 0, 1, 1, .{ 0, 0, 0, 1 });
    try testing.expectEqual(@as(u32, 0), c);
}

test "renderSlot empty produces 3 quads (border, bg, placeholder)" {
    var buf: [64]UiVertex = undefined;
    const c = renderSlot(&buf, 0, 0, 0, slot_size, 0, 0);
    try testing.expectEqual(@as(u32, 3 * 6), c);
}

test "renderSlot filled with count>1 emits item quad and digit pixels" {
    var buf: [512]UiVertex = undefined;
    const empty_count = renderSlot(&buf, 0, 0, 0, slot_size, 0, 0);
    const filled_count = renderSlot(&buf, 0, 0, 0, slot_size, 42, 5);
    try testing.expect(filled_count > empty_count);
}

test "render emits correct chrome for empty data" {
    var buf: [4096]UiVertex = undefined;
    const total = render(&buf, 0, 800, 600, .{});
    // overlay + border + bg + title + 3 slots*3 quads + plus(2) + arrow(1) = 4 + 9 + 3 = 16 quads
    try testing.expectEqual(@as(u32, 16 * 6), total);
}

test "render with xp_cost adds digit vertices" {
    var buf: [4096]UiVertex = undefined;
    const without_xp = render(&buf, 0, 800, 600, .{});
    const with_xp = render(&buf, 0, 800, 600, .{ .xp_cost = 5 });
    try testing.expect(with_xp > without_xp);
}

test "render with rename_len adds bar quad" {
    var buf: [4096]UiVertex = undefined;
    const without_rename = render(&buf, 0, 800, 600, .{});
    const with_rename = render(&buf, 0, 800, 600, .{ .rename_len = 10 });
    try testing.expectEqual(with_rename, without_rename + 6);
}

test "render respects start offset" {
    var buf: [4096]UiVertex = undefined;
    const start: u32 = 12;
    const total = render(&buf, start, 800, 600, .{});
    try testing.expect(total >= start);
    try testing.expectEqual(@as(u32, start + 16 * 6), total);
}

test "render truncates safely with tiny buffer" {
    var buf: [4]UiVertex = undefined;
    const total = render(&buf, 0, 800, 600, .{
        .input_item = 1,
        .input_count = 64,
        .xp_cost = 30,
        .rename_len = 20,
    });
    try testing.expect(total <= buf.len);
}

test "render is centred on screen" {
    var buf: [4096]UiVertex = undefined;
    const sw: f32 = 1280;
    const sh: f32 = 720;
    _ = render(&buf, 0, sw, sh, .{});
    // First quad is dim overlay (verts 0..6); panel border begins at vert 6.
    const border_x = buf[6].pos_x;
    const expected_left = (sw - panel_w) / 2 - 3;
    try testing.expectApproxEqAbs(expected_left, border_x, 0.001);
}

test "drawNumber renders digit pixels" {
    var buf: [512]UiVertex = undefined;
    const c = drawNumber(&buf, 0, 0, 0, 42, 1.0, .{ 1, 1, 1, 1 });
    // Two-digit number produces > 0 vertices, all multiples of 6
    try testing.expect(c > 0);
    try testing.expect(c % 6 == 0);
}

test "rename bar width is capped at 320" {
    var buf: [4096]UiVertex = undefined;
    // rename_len=255 -> 255*8=2040, capped to 320
    const total = render(&buf, 0, 800, 600, .{ .rename_len = 255 });
    // Find the rename bar quad: it is the last quad emitted.
    // total is the new index; the rename bar quad spans [total-6 .. total-1].
    const bar_v0 = buf[total - 6];
    const bar_v1 = buf[total - 5];
    const bar_w = bar_v1.pos_x - bar_v0.pos_x;
    try testing.expectApproxEqAbs(rename_max_w, bar_w, 0.001);
}
