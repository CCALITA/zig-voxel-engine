/// Grindstone screen renderer: generates UI vertices for the grindstone
/// interface. Layout: centered 380x260 panel with two input slots (input +
/// sacrifice) on the left, an arrow indicator, one output slot on the right,
/// and a green XP reward number below the output slot.
///
/// Self-contained: defines its own `UiVertex` matching the layout used by
/// the UI pipeline (pos.xy, rgba, uv) so it can be tested in isolation
/// without pulling in the Vulkan-bound `ui_pipeline.zig`. Untextured quads
/// use `u = -1, v = -1` per the convention in `engine.zig` so the fragment
/// shader takes the solid-color branch.
const std = @import("std");
const bitmap_font = @import("../renderer/bitmap_font.zig");

// -- Types -------------------------------------------------------------------

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

// -- Layout constants --------------------------------------------------------

const panel_w: f32 = 380.0;
const panel_h: f32 = 260.0;
const slot_size: f32 = 36.0;
const slot_gap: f32 = 12.0;
const digit_scale: f32 = 1.5;

// Horizontal zones inside the panel.
const input_col_x: f32 = 60.0; // left-edge offset for input slots column
const output_col_x: f32 = 260.0; // left-edge offset for output slot column
const arrow_x_off: f32 = 170.0; // left-edge offset for arrow indicator

// -- Colors (rgba arrays) ----------------------------------------------------

const dim_overlay = [_]f32{ 0.0, 0.0, 0.0, 0.55 };
const panel_border = [_]f32{ 0.10, 0.10, 0.10, 0.95 };
const panel_bg = [_]f32{ 0.55, 0.55, 0.55, 0.95 };
const title_bar = [_]f32{ 0.40, 0.40, 0.40, 1.00 };
const slot_border = [_]f32{ 0.30, 0.30, 0.30, 1.00 };
const slot_bg_col = [_]f32{ 0.42, 0.42, 0.42, 0.90 };
const item_filled = [_]f32{ 0.78, 0.62, 0.36, 0.95 };
const item_empty = [_]f32{ 0.50, 0.50, 0.50, 0.30 };
const indicator = [_]f32{ 0.95, 0.95, 0.95, 0.85 };
const output_glow = [_]f32{ 0.95, 0.85, 0.30, 0.85 };
const xp_green = [_]f32{ 0.30, 0.95, 0.30, 1.00 };

// -- Public API --------------------------------------------------------------

/// Render the grindstone screen into `verts` starting at index `start`.
/// Returns the total vertex count (including `start`). Silently truncates
/// if `verts` is too small.
///
/// Layout:
///   - Full-screen dim overlay
///   - Dark panel (380x260) centered on screen
///   - Title bar at the top of the panel
///   - Input slot (top-left region) with item count badge
///   - Sacrifice slot (below input) with item count badge
///   - Arrow indicator between inputs and output
///   - Output slot (right region) with item count badge and glow
///   - Green XP reward number below the output slot
pub fn render(
    verts: []UiVertex,
    start: u32,
    sw: f32,
    sh: f32,
    input_item: u16,
    input_count: u8,
    sacrifice_item: u16,
    sacrifice_count: u8,
    output_item: u16,
    output_count: u8,
    xp: u8,
) u32 {
    var c = start;

    // Full-screen dim overlay.
    c = addQuad(verts, c, 0, 0, sw, sh, dim_overlay);

    // Centered panel with border.
    const px = (sw - panel_w) * 0.5;
    const py = (sh - panel_h) * 0.5;
    c = addQuad(verts, c, px - 2, py - 2, panel_w + 4, panel_h + 4, panel_border);
    c = addQuad(verts, c, px, py, panel_w, panel_h, panel_bg);
    c = addQuad(verts, c, px, py, panel_w, 24, title_bar);

    // Vertical center of the slot area (below title bar).
    const content_top = py + 24.0;
    const content_h = panel_h - 24.0;
    const slots_total_h = slot_size * 2.0 + slot_gap;
    const slots_y = content_top + (content_h - slots_total_h) * 0.5;

    // -- Input slot (upper-left) --
    const in_x = px + input_col_x;
    const in_y = slots_y;
    c = renderSlot(verts, c, in_x, in_y, input_item, input_count, false);

    // -- Sacrifice slot (lower-left, same column as input) --
    const sac_y = slots_y + slot_size + slot_gap;
    c = renderSlot(verts, c, in_x, sac_y, sacrifice_item, sacrifice_count, false);

    // -- Arrow indicator (centered vertically between the two input slots) --
    const arrow_cx = px + arrow_x_off;
    const arrow_cy = slots_y + (slots_total_h - 12.0) * 0.5;
    c = drawArrow(verts, c, arrow_cx, arrow_cy);

    // -- Output slot (right, centered vertically in the slot area) --
    const out_x = px + output_col_x;
    const out_y = slots_y + (slots_total_h - slot_size) * 0.5;
    c = renderSlot(verts, c, out_x, out_y, output_item, output_count, true);

    // -- XP reward number in green below the output slot --
    if (xp > 0) {
        const xp_y = out_y + slot_size + 8.0;
        const num_digits = bitmap_font.digitCount(@as(u32, xp));
        const char_w = @as(f32, @floatFromInt(bitmap_font.GLYPH_W)) * digit_scale + digit_scale;
        const total_w = @as(f32, @floatFromInt(num_digits)) * char_w - digit_scale;
        const xp_x = out_x + (slot_size - total_w) * 0.5;
        c = drawNumber(verts, c, xp_x, xp_y, @as(u32, xp), digit_scale, xp_green[0], xp_green[1], xp_green[2], xp_green[3]);
    }

    return c;
}

// -- Drawing helpers ---------------------------------------------------------

/// Emit a colored (untextured) quad as two triangles. Uses u=-1, v=-1.
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
fn renderSlot(verts: []UiVertex, start: u32, x: f32, y: f32, item: u16, count: u8, is_output: bool) u32 {
    var c = start;
    if (is_output and item != 0) {
        c = addQuad(verts, c, x - 4, y - 4, slot_size + 8, slot_size + 8, output_glow);
    }
    c = addQuad(verts, c, x, y, slot_size, slot_size, slot_border);
    c = addQuad(verts, c, x + 2, y + 2, slot_size - 4, slot_size - 4, slot_bg_col);
    if (item != 0) {
        c = addQuad(verts, c, x + 6, y + 6, slot_size - 12, slot_size - 12, item_filled);
    } else {
        c = addQuad(verts, c, x + 8, y + 8, slot_size - 16, slot_size - 16, item_empty);
    }
    if (count > 1) {
        const num_x = x + slot_size - 14;
        const num_y = y + slot_size - 12;
        c = drawNumber(verts, c, num_x, num_y, @as(u32, count), digit_scale, 1.0, 1.0, 1.0, 1.0);
    }
    return c;
}

/// Draw a non-negative integer using the shared bitmap font.
fn drawNumber(verts: []UiVertex, start: u32, x: f32, y: f32, value: u32, scale: f32, r: f32, g: f32, b: f32, a: f32) u32 {
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

/// Draw a 12x12 arrow indicator (shaft + wedge head).
fn drawArrow(verts: []UiVertex, start: u32, x: f32, y: f32) u32 {
    var c = start;
    c = addQuad(verts, c, x, y + 5, 10, 2, indicator);
    c = addQuad(verts, c, x + 8, y + 3, 2, 6, indicator);
    c = addQuad(verts, c, x + 9, y + 4, 2, 4, indicator);
    c = addQuad(verts, c, x + 10, y + 5, 2, 2, indicator);
    return c;
}

// -- Tests -------------------------------------------------------------------

const testing = std.testing;

test "UiVertex layout matches ui_pipeline shape" {
    try testing.expectEqual(@as(usize, 32), @sizeOf(UiVertex));
}

test "addQuad emits 6 vertices with u=-1 v=-1" {
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

test "renderSlot empty produces 3 quads" {
    var buf: [64]UiVertex = undefined;
    const c = renderSlot(&buf, 0, 0, 0, 0, 0, false);
    try testing.expectEqual(@as(u32, 3 * 6), c);
}

test "renderSlot filled with count>1 emits digit pixels" {
    var buf: [512]UiVertex = undefined;
    const empty_c = renderSlot(&buf, 0, 0, 0, 0, 0, false);
    const filled_c = renderSlot(&buf, 0, 0, 0, 42, 5, false);
    try testing.expect(filled_c > empty_c);
}

test "renderSlot output with item adds glow" {
    var buf: [256]UiVertex = undefined;
    const non_output = renderSlot(&buf, 0, 0, 0, 7, 1, false);
    const output = renderSlot(&buf, 0, 0, 0, 7, 1, true);
    try testing.expectEqual(non_output + 6, output);
}

test "render empty state produces expected chrome" {
    var buf: [4096]UiVertex = undefined;
    const total = render(&buf, 0, 800, 600, 0, 0, 0, 0, 0, 0, 0);
    // dim(1) + border(1) + bg(1) + title(1) = 4 chrome quads
    // input slot: 3 quads, sacrifice slot: 3 quads, output slot: 3 quads (no glow)
    // arrow: 4 quads
    // xp=0 so no XP digits
    // Total: 4 + 3 + 3 + 4 + 3 = 17 quads = 102 verts
    try testing.expectEqual(@as(u32, 17 * 6), total);
}

test "render with xp>0 adds green digit pixels" {
    var buf: [4096]UiVertex = undefined;
    const no_xp = render(&buf, 0, 800, 600, 1, 1, 0, 0, 1, 1, 0);
    const with_xp = render(&buf, 0, 800, 600, 1, 1, 0, 0, 1, 1, 5);
    try testing.expect(with_xp > no_xp);
}

test "render xp digits are green" {
    var buf: [4096]UiVertex = undefined;
    // Render with items so output glow + xp are present.
    const total = render(&buf, 0, 800, 600, 1, 1, 0, 0, 1, 1, 3);
    // Find the last group of quads -- they are xp digits, should be green.
    // The last emitted vertex is at total-1; check its color.
    const last = buf[total - 1];
    try testing.expectApproxEqAbs(xp_green[0], last.r, 0.01);
    try testing.expectApproxEqAbs(xp_green[1], last.g, 0.01);
    try testing.expectApproxEqAbs(xp_green[2], last.b, 0.01);
}

test "render is centered on screen" {
    var buf: [4096]UiVertex = undefined;
    const sw: f32 = 1280;
    const sh: f32 = 720;
    _ = render(&buf, 0, sw, sh, 0, 0, 0, 0, 0, 0, 0);
    // Dim is verts[0..6]; panel border starts at vert 6.
    const border_x = buf[6].pos_x;
    const border_w = buf[7].pos_x - buf[6].pos_x;
    const expected_left = (sw - panel_w) * 0.5 - 2.0;
    const expected_w = panel_w + 4.0;
    try testing.expectApproxEqAbs(expected_left, border_x, 0.001);
    try testing.expectApproxEqAbs(expected_w, border_w, 0.001);
}

test "render respects start offset" {
    var buf: [4096]UiVertex = undefined;
    const start: u32 = 18;
    const total = render(&buf, start, 800, 600, 0, 0, 0, 0, 0, 0, 0);
    try testing.expect(total >= start);
    try testing.expectEqual(@as(u32, start + 17 * 6), total);
}

test "render truncates safely with tiny buffer" {
    var buf: [4]UiVertex = undefined;
    const total = render(&buf, 0, 800, 600, 0, 0, 0, 0, 0, 0, 0);
    try testing.expect(total <= buf.len);
}

test "render with all slots filled and high xp" {
    var buf: [4096]UiVertex = undefined;
    const total = render(&buf, 0, 1920, 1080, 100, 64, 200, 32, 300, 16, 255);
    try testing.expect(total > 0);
    try testing.expect(total <= buf.len);
}

test "drawNumber zero emits one digit of pixels" {
    var buf: [256]UiVertex = undefined;
    const c = drawNumber(&buf, 0, 0, 0, 0, 1.0, 1, 1, 1, 1);
    // Digit '0' has 12 lit pixels.
    try testing.expectEqual(@as(u32, 12 * 6), c);
}
