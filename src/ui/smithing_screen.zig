/// Smithing table UI screen rendering.
/// Renders a centered 400x250 panel containing three input slots
/// (template, base, addition) and one output slot, with "+" indicators
/// between the inputs and a "→" indicator between the last input and the
/// output slot.
///
/// Self-contained: defines its own `UiVertex` matching the layout used by
/// the UI pipeline (pos.xy, rgba, uv) so it can be tested in isolation
/// without pulling in the Vulkan-bound `ui_pipeline.zig`. Untextured quads
/// use `u = -1, v = -1` per the convention in `engine.zig` so the fragment
/// shader takes the solid-color branch.
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

pub const SmithingData = struct {
    template_item: u16 = 0,
    template_count: u8 = 0,
    base_item: u16 = 0,
    base_count: u8 = 0,
    addition_item: u16 = 0,
    addition_count: u8 = 0,
    output_item: u16 = 0,
    output_count: u8 = 0,
};

// ── Layout constants ─────────────────────────────────────────────────────

const panel_w: f32 = 400.0;
const panel_h: f32 = 250.0;
const slot_size: f32 = 36.0;
const slot_gap: f32 = 28.0; // space between adjacent slot centres for indicator
const num_slots: usize = 4;
const digit_scale: f32 = 1.5;

// Colors (rgba)
const dim_overlay = [_]f32{ 0.0, 0.0, 0.0, 0.55 };
const panel_border = [_]f32{ 0.10, 0.10, 0.10, 0.95 };
const panel_bg = [_]f32{ 0.55, 0.55, 0.55, 0.95 };
const title_bar = [_]f32{ 0.40, 0.40, 0.40, 1.00 };
const slot_border = [_]f32{ 0.30, 0.30, 0.30, 1.00 };
const slot_bg = [_]f32{ 0.42, 0.42, 0.42, 0.90 };
const item_filled = [_]f32{ 0.78, 0.62, 0.36, 0.95 };
const item_empty = [_]f32{ 0.50, 0.50, 0.50, 0.30 };
const indicator = [_]f32{ 0.95, 0.95, 0.95, 0.85 };
const output_glow = [_]f32{ 0.95, 0.85, 0.30, 0.85 };

// ── Public API ───────────────────────────────────────────────────────────

/// Render the smithing screen into `verts` starting at index `start`.
/// Returns the new vertex count. Silently truncates if `verts` is too small.
pub fn render(verts: []UiVertex, start: u32, sw: f32, sh: f32, data: SmithingData) u32 {
    var c = start;

    // Full-screen dim overlay.
    c = addQuad(verts, c, 0, 0, sw, sh, dim_overlay);

    // Centred panel.
    const px = (sw - panel_w) * 0.5;
    const py = (sh - panel_h) * 0.5;
    c = addQuad(verts, c, px - 2, py - 2, panel_w + 4, panel_h + 4, panel_border);
    c = addQuad(verts, c, px, py, panel_w, panel_h, panel_bg);
    c = addQuad(verts, c, px, py, panel_w, 24, title_bar);

    // Slot row, centred horizontally inside the panel.
    const row_w = @as(f32, @floatFromInt(num_slots)) * slot_size +
        @as(f32, @floatFromInt(num_slots - 1)) * slot_gap;
    const row_x = px + (panel_w - row_w) * 0.5;
    const row_y = py + (panel_h - slot_size) * 0.5 + 8;

    const items = [_]u16{ data.template_item, data.base_item, data.addition_item, data.output_item };
    const counts = [_]u8{ data.template_count, data.base_count, data.addition_count, data.output_count };

    var i: usize = 0;
    while (i < num_slots) : (i += 1) {
        const fi: f32 = @floatFromInt(i);
        const sx = row_x + fi * (slot_size + slot_gap);
        const is_output = i == num_slots - 1;
        c = renderSlot(verts, c, sx, row_y, items[i], counts[i], is_output);

        // Indicator between this slot and the next.
        if (i + 1 < num_slots) {
            const ix = sx + slot_size + (slot_gap - 12.0) * 0.5;
            const iy = row_y + (slot_size - 12.0) * 0.5;
            if (i == num_slots - 2) {
                c = drawArrow(verts, c, ix, iy);
            } else {
                c = drawPlus(verts, c, ix, iy);
            }
        }
    }

    return c;
}

// ── Drawing helpers ──────────────────────────────────────────────────────

/// Emit a coloured (untextured) quad as two triangles. Untextured: u=-1, v=-1.
pub fn addQuad(verts: []UiVertex, start: u32, x: f32, y: f32, w: f32, h: f32, col: [4]f32) u32 {
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
pub fn renderSlot(verts: []UiVertex, start: u32, x: f32, y: f32, item: u16, count: u8, is_output: bool) u32 {
    var c = start;
    if (is_output and item != 0) {
        // Soft glow behind output when something is craftable.
        c = addQuad(verts, c, x - 4, y - 4, slot_size + 8, slot_size + 8, output_glow);
    }
    c = addQuad(verts, c, x, y, slot_size, slot_size, slot_border);
    c = addQuad(verts, c, x + 2, y + 2, slot_size - 4, slot_size - 4, slot_bg);
    if (item != 0) {
        c = addQuad(verts, c, x + 6, y + 6, slot_size - 12, slot_size - 12, item_filled);
    } else {
        c = addQuad(verts, c, x + 8, y + 8, slot_size - 16, slot_size - 16, item_empty);
    }
    if (count > 1) {
        const num_x = x + slot_size - 14;
        const num_y = y + slot_size - 12;
        c = drawNumber(verts, c, num_x, num_y, count, digit_scale, 1.0, 1.0, 1.0, 1.0);
    }
    return c;
}

/// Draw a non-negative integer using the shared bitmap font.
pub fn drawNumber(verts: []UiVertex, start: u32, x: f32, y: f32, value: u32, scale: f32, r: f32, g: f32, b: f32, a: f32) u32 {
    var c = start;
    const num_digits = bitmap_font.digitCount(value);
    const char_w = @as(f32, @floatFromInt(bitmap_font.GLYPH_W)) * scale + scale;
    var di: u32 = 0;
    while (di < num_digits) : (di += 1) {
        const digit = bitmap_font.getDigit(value, num_digits - 1 - di);
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
                        .{ r, g, b, a },
                    );
                }
            }
        }
    }
    return c;
}

/// Draw a 12x12 "+" indicator (two crossing 2px-thick bars).
fn drawPlus(verts: []UiVertex, start: u32, x: f32, y: f32) u32 {
    var c = start;
    c = addQuad(verts, c, x, y + 5, 12, 2, indicator);
    c = addQuad(verts, c, x + 5, y, 2, 12, indicator);
    return c;
}

/// Draw a 12x12 "→" indicator (shaft + small wedge head).
fn drawArrow(verts: []UiVertex, start: u32, x: f32, y: f32) u32 {
    var c = start;
    // Horizontal shaft.
    c = addQuad(verts, c, x, y + 5, 10, 2, indicator);
    // Arrowhead: three stacked bars forming a wedge.
    c = addQuad(verts, c, x + 8, y + 3, 2, 6, indicator);
    c = addQuad(verts, c, x + 9, y + 4, 2, 4, indicator);
    c = addQuad(verts, c, x + 10, y + 5, 2, 2, indicator);
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
    try testing.expectEqual(@as(f32, 40), buf[2].pos_x);
    try testing.expectEqual(@as(f32, 60), buf[2].pos_y);
    try testing.expectEqual(@as(f32, 0.5), buf[1].g);
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
    const c = renderSlot(&buf, 0, 0, 0, 0, 0, false);
    try testing.expectEqual(@as(u32, 3 * 6), c);
}

test "renderSlot filled with count>1 emits item quad and digit pixels" {
    var buf: [256]UiVertex = undefined;
    const empty_count = renderSlot(&buf, 0, 0, 0, 0, 0, false);
    const filled_count = renderSlot(&buf, 0, 0, 0, 42, 5, false);
    // Filled produces more vertices than empty (item quad is same count, digits add more).
    try testing.expect(filled_count > empty_count);
}

test "renderSlot count==1 does not draw a number" {
    var buf: [256]UiVertex = undefined;
    const single = renderSlot(&buf, 0, 0, 0, 7, 1, false);
    // border + bg + item = 3 quads = 18 verts (no glow because not output).
    try testing.expectEqual(@as(u32, 18), single);
}

test "renderSlot output with item adds glow quad" {
    var buf: [256]UiVertex = undefined;
    const non_output = renderSlot(&buf, 0, 0, 0, 7, 1, false);
    const output = renderSlot(&buf, 0, 0, 0, 7, 1, true);
    try testing.expectEqual(non_output + 6, output);
}

test "render emits panel chrome and four slots without overflow" {
    var buf: [4096]UiVertex = undefined;
    const data = SmithingData{
        .template_item = 1, .template_count = 1,
        .base_item = 2, .base_count = 1,
        .addition_item = 3, .addition_count = 1,
        .output_item = 4, .output_count = 1,
    };
    const total = render(&buf, 0, 1280, 720, data);
    // dim + border + bg + title (4 quads) + 4 slots (with 1 glow on output) +
    // 2 plus indicators (2 quads each) + 1 arrow (4 quads).
    // Slots: 4 * 3 quads + 1 glow = 13 quads.
    // Total quads: 4 + 13 + 2*2 + 4 = 25 quads = 150 verts.
    try testing.expectEqual(@as(u32, 25 * 6), total);
}

test "render is centred on screen" {
    var buf: [4096]UiVertex = undefined;
    const sw: f32 = 1280;
    const sh: f32 = 720;
    _ = render(&buf, 0, sw, sh, SmithingData{});
    // Dim quad is verts[0..6]; panel border begins at vert 6.
    const border_x = buf[6].pos_x;
    const border_w = buf[7].pos_x - buf[6].pos_x;
    const expected_left = (sw - panel_w) * 0.5 - 2.0;
    const expected_w = panel_w + 4.0;
    try testing.expectApproxEqAbs(expected_left, border_x, 0.001);
    try testing.expectApproxEqAbs(expected_w, border_w, 0.001);
}

test "render handles empty smithing data" {
    var buf: [4096]UiVertex = undefined;
    const total = render(&buf, 0, 800, 600, SmithingData{});
    // 4 chrome quads + 4 slots * 3 quads + 2 plus + 1 arrow (4 quads) = 4+12+4+4 = 24 quads.
    try testing.expectEqual(@as(u32, 24 * 6), total);
}

test "render truncates safely with tiny buffer" {
    var buf: [4]UiVertex = undefined;
    const total = render(&buf, 0, 800, 600, SmithingData{});
    try testing.expect(total <= buf.len);
}

test "render respects start offset" {
    var buf: [4096]UiVertex = undefined;
    const start: u32 = 12;
    const total = render(&buf, start, 800, 600, SmithingData{});
    try testing.expect(total >= start);
    try testing.expectEqual(@as(u32, start + 24 * 6), total);
}

test "drawNumber with zero emits one digit's worth of pixels" {
    var buf: [256]UiVertex = undefined;
    const c = drawNumber(&buf, 0, 0, 0, 0, 1.0, 1, 1, 1, 1);
    // Digit 0 has 12 lit pixels in the 3x5 grid.
    try testing.expectEqual(@as(u32, 12 * 6), c);
}
