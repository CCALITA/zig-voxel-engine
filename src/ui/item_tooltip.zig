/// Item tooltip rendered at the mouse cursor position.
/// Shows a dark background panel with the item ID as digits, a durability bar
/// (green-to-red gradient) for tools, and purple enchant indicator dots.
/// All quads are flat-coloured (u=-1, v=-1).
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

pub const TooltipData = struct {
    item_id: u16,
    count: u8,
    durability_pct: f32 = 1.0,
    enchant_count: u8 = 0,
    is_tool: bool = false,
};

// ── Layout constants ─────────────────────────────────────────────────

const padding: f32 = 6.0;
const pixel_scale: f32 = 2.0;
const border_thickness: f32 = 1.0;
const durability_bar_height: f32 = 4.0;
const durability_bar_width: f32 = 40.0;
const enchant_dot_size: f32 = 4.0;
const enchant_dot_gap: f32 = 3.0;
const row_gap: f32 = 4.0;
const cursor_offset_x: f32 = 12.0;
const cursor_offset_y: f32 = 12.0;

/// Max enchant dots rendered (visual cap).
const max_enchant_dots: u8 = 8;

// ── Colours ──────────────────────────────────────────────────────────

const Color = struct { r: f32, g: f32, b: f32, a: f32 };

const bg_color = Color{ .r = 0.08, .g = 0.02, .b = 0.12, .a = 0.88 };
const border_color = Color{ .r = 0.30, .g = 0.15, .b = 0.50, .a = 0.92 };
const text_color = Color{ .r = 1.00, .g = 1.00, .b = 1.00, .a = 1.00 };
const text_shadow = Color{ .r = 0.05, .g = 0.05, .b = 0.05, .a = 0.85 };
const durability_bg = Color{ .r = 0.15, .g = 0.15, .b = 0.15, .a = 0.80 };
const enchant_dot_color = Color{ .r = 0.70, .g = 0.30, .b = 1.00, .a = 1.00 };

/// Maximum vertices the tooltip can emit.
/// Border (6) + BG (6) + ID digits (~5 digits * 15 pixels * 2 shadow+fg * 6) +
/// durability bg (6) + durability fill (6) + count digits + enchant dots (8*6).
pub const max_vertices: u32 = 2048;

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

// ── Number drawing via bitmap_font ───────────────────────────────────

fn drawNumber(verts: []UiVertex, idx: *u32, left_x: f32, y: f32, value: u32, fg: Color, shadow: Color) void {
    const num_digits = bitmap_font.digitCount(value);
    const glyph_w: f32 = @floatFromInt(bitmap_font.GLYPH_W);
    const digit_spacing: f32 = 1.0;

    var d: u32 = 0;
    while (d < num_digits) : (d += 1) {
        const digit = bitmap_font.getDigit(value, num_digits - 1 - d);
        const dx = left_x + @as(f32, @floatFromInt(d)) * (glyph_w * pixel_scale + digit_spacing);

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

// ── Durability colour (green at 100%, red at 0%) ─────────────────────

fn durabilityColor(pct: f32) Color {
    const p = std.math.clamp(pct, 0.0, 1.0);
    return .{
        .r = 1.0 - p,
        .g = p,
        .b = 0.1,
        .a = 1.0,
    };
}

// ── Content height computation ───────────────────────────────────────

fn contentHeight(data: TooltipData) f32 {
    const glyph_h: f32 = @floatFromInt(bitmap_font.GLYPH_H);
    // First row: item ID digits
    var h: f32 = glyph_h * pixel_scale;
    // Second row: stack count (only shown when stacked)
    if (data.count > 1) {
        h += row_gap + glyph_h * pixel_scale;
    }
    // Durability bar row (tools only)
    if (data.is_tool) {
        h += row_gap + durability_bar_height;
    }
    // Enchant dots row
    const dots = @min(data.enchant_count, max_enchant_dots);
    if (dots > 0) {
        h += row_gap + enchant_dot_size;
    }
    return h;
}

/// Compute the panel width needed for the content. Ensures at least the
/// durability bar and enchant dots fit.
fn contentWidth(data: TooltipData) f32 {
    const glyph_w: f32 = @floatFromInt(bitmap_font.GLYPH_W);
    const digit_spacing: f32 = 1.0;

    // Width of item-ID digits
    const id_digits = bitmap_font.digitCount(@as(u32, data.item_id));
    const id_width = @as(f32, @floatFromInt(id_digits)) * (glyph_w * pixel_scale + digit_spacing) - digit_spacing;

    var w = id_width;

    // Count digits row
    if (data.count > 1) {
        const count_digits = bitmap_font.digitCount(@as(u32, data.count));
        const count_width = @as(f32, @floatFromInt(count_digits)) * (glyph_w * pixel_scale + digit_spacing) - digit_spacing;
        w = @max(w, count_width);
    }

    // Durability bar
    if (data.is_tool) {
        w = @max(w, durability_bar_width);
    }

    // Enchant dots
    const dots: f32 = @floatFromInt(@min(data.enchant_count, max_enchant_dots));
    if (dots > 0) {
        const dots_width = dots * enchant_dot_size + (dots - 1.0) * enchant_dot_gap;
        w = @max(w, dots_width);
    }

    return w;
}

// ── Public render entry point ────────────────────────────────────────

/// Render the tooltip at mouse position (`mx`, `my`).
/// Writes quads into `verts` starting at index `start`.
/// Returns the new vertex index after all emitted quads.
pub fn render(verts: []UiVertex, start: u32, mx: f32, my: f32, data: TooltipData) u32 {
    var idx = start;

    const inner_w = contentWidth(data);
    const inner_h = contentHeight(data);
    const panel_w = inner_w + padding * 2.0;
    const panel_h = inner_h + padding * 2.0;
    const panel_x = mx + cursor_offset_x;
    const panel_y = my + cursor_offset_y;

    // Border (slightly larger rectangle behind the panel)
    addQuad(
        verts,
        &idx,
        panel_x - border_thickness,
        panel_y - border_thickness,
        panel_w + border_thickness * 2.0,
        panel_h + border_thickness * 2.0,
        border_color,
    );

    // Dark background panel
    addQuad(verts, &idx, panel_x, panel_y, panel_w, panel_h, bg_color);

    var cursor_y = panel_y + padding;
    const content_x = panel_x + padding;
    const glyph_h: f32 = @floatFromInt(bitmap_font.GLYPH_H);

    // Item ID number
    drawNumber(verts, &idx, content_x, cursor_y, @as(u32, data.item_id), text_color, text_shadow);
    cursor_y += glyph_h * pixel_scale;

    // Stack count (only shown if > 1)
    if (data.count > 1) {
        cursor_y += row_gap;
        drawNumber(verts, &idx, content_x, cursor_y, @as(u32, data.count), text_color, text_shadow);
        cursor_y += glyph_h * pixel_scale;
    }

    // Durability bar (tools only)
    if (data.is_tool) {
        cursor_y += row_gap;
        const pct = std.math.clamp(data.durability_pct, 0.0, 1.0);
        // Bar background
        addQuad(verts, &idx, content_x, cursor_y, durability_bar_width, durability_bar_height, durability_bg);
        // Bar fill
        if (pct > 0.0) {
            addQuad(verts, &idx, content_x, cursor_y, durability_bar_width * pct, durability_bar_height, durabilityColor(pct));
        }
        cursor_y += durability_bar_height;
    }

    // Enchant dots (purple)
    const dots = @min(data.enchant_count, max_enchant_dots);
    if (dots > 0) {
        cursor_y += row_gap;
        var i: u8 = 0;
        while (i < dots) : (i += 1) {
            const dot_x = content_x + @as(f32, @floatFromInt(i)) * (enchant_dot_size + enchant_dot_gap);
            addQuad(verts, &idx, dot_x, cursor_y, enchant_dot_size, enchant_dot_size, enchant_dot_color);
        }
    }

    return idx;
}

// ── Tests ────────────────────────────────────────────────────────────

const testing = std.testing;

test "render produces vertices in multiples of 6" {
    var buf: [max_vertices]UiVertex = undefined;
    const data = TooltipData{ .item_id = 42, .count = 1 };
    const count = render(&buf, 0, 100.0, 100.0, data);
    try testing.expect(count > 0);
    try testing.expect(count % 6 == 0);
}

test "render preserves start offset" {
    var buf: [max_vertices]UiVertex = undefined;
    const data = TooltipData{ .item_id = 1, .count = 1 };
    const offset: u32 = 12;
    const count = render(&buf, offset, 50.0, 50.0, data);
    try testing.expect(count >= offset);
    try testing.expect((count - offset) % 6 == 0);
}

test "all vertices use untextured UV (-1, -1)" {
    var buf: [max_vertices]UiVertex = undefined;
    const data = TooltipData{ .item_id = 99, .count = 3, .is_tool = true, .durability_pct = 0.5, .enchant_count = 2 };
    const count = render(&buf, 0, 200.0, 200.0, data);
    for (0..count) |i| {
        try testing.expectApproxEqAbs(@as(f32, -1.0), buf[i].u, 0.001);
        try testing.expectApproxEqAbs(@as(f32, -1.0), buf[i].v, 0.001);
    }
}

test "tooltip is positioned to the right and below mouse cursor" {
    var buf: [max_vertices]UiVertex = undefined;
    const mx: f32 = 300.0;
    const my: f32 = 250.0;
    const data = TooltipData{ .item_id = 5, .count = 1 };
    _ = render(&buf, 0, mx, my, data);
    // First quad (border) top-left should be offset from cursor
    try testing.expect(buf[0].pos_x > mx);
    try testing.expect(buf[0].pos_y > my);
}

test "tool with durability emits more vertices than non-tool" {
    var buf_tool: [max_vertices]UiVertex = undefined;
    var buf_no_tool: [max_vertices]UiVertex = undefined;
    const tool_data = TooltipData{ .item_id = 10, .count = 1, .is_tool = true, .durability_pct = 0.8 };
    const item_data = TooltipData{ .item_id = 10, .count = 1, .is_tool = false };
    const count_tool = render(&buf_tool, 0, 100.0, 100.0, tool_data);
    const count_item = render(&buf_no_tool, 0, 100.0, 100.0, item_data);
    // Durability bar adds at least 2 quads (bg + fill) = 12 more vertices
    try testing.expect(count_tool > count_item);
}

test "enchant dots add vertices" {
    var buf_ench: [max_vertices]UiVertex = undefined;
    var buf_plain: [max_vertices]UiVertex = undefined;
    const ench_data = TooltipData{ .item_id = 10, .count = 1, .enchant_count = 3 };
    const plain_data = TooltipData{ .item_id = 10, .count = 1, .enchant_count = 0 };
    const count_ench = render(&buf_ench, 0, 100.0, 100.0, ench_data);
    const count_plain = render(&buf_plain, 0, 100.0, 100.0, plain_data);
    // 3 enchant dots = 3 quads = 18 more vertices
    try testing.expect(count_ench > count_plain);
    try testing.expectEqual(@as(u32, count_plain + 18), count_ench);
}

test "durability colour is green at full health" {
    const col = durabilityColor(1.0);
    try testing.expectApproxEqAbs(@as(f32, 0.0), col.r, 0.01);
    try testing.expectApproxEqAbs(@as(f32, 1.0), col.g, 0.01);
}

test "durability colour is red at zero health" {
    const col = durabilityColor(0.0);
    try testing.expectApproxEqAbs(@as(f32, 1.0), col.r, 0.01);
    try testing.expectApproxEqAbs(@as(f32, 0.0), col.g, 0.01);
}

test "durability is clamped to 0..1" {
    const col_over = durabilityColor(2.0);
    const col_full = durabilityColor(1.0);
    try testing.expectApproxEqAbs(col_over.r, col_full.r, 0.001);
    try testing.expectApproxEqAbs(col_over.g, col_full.g, 0.001);
}

test "zero durability tool shows bg but no fill" {
    var buf: [max_vertices]UiVertex = undefined;
    const data_zero = TooltipData{ .item_id = 1, .count = 1, .is_tool = true, .durability_pct = 0.0 };
    const data_half = TooltipData{ .item_id = 1, .count = 1, .is_tool = true, .durability_pct = 0.5 };
    const count_zero = render(&buf, 0, 100.0, 100.0, data_zero);
    const count_half = render(&buf, 0, 100.0, 100.0, data_half);
    // Zero pct skips the fill quad (6 fewer vertices)
    try testing.expectEqual(@as(u32, count_half - 6), count_zero);
}

test "count > 1 adds a second number row" {
    var buf_single: [max_vertices]UiVertex = undefined;
    var buf_stack: [max_vertices]UiVertex = undefined;
    const single = TooltipData{ .item_id = 1, .count = 1 };
    const stack = TooltipData{ .item_id = 1, .count = 64 };
    const count_single = render(&buf_single, 0, 100.0, 100.0, single);
    const count_stack = render(&buf_stack, 0, 100.0, 100.0, stack);
    try testing.expect(count_stack > count_single);
}

test "enchant dots capped at max_enchant_dots" {
    var buf_many: [max_vertices]UiVertex = undefined;
    var buf_max: [max_vertices]UiVertex = undefined;
    const many = TooltipData{ .item_id = 1, .count = 1, .enchant_count = 20 };
    const at_max = TooltipData{ .item_id = 1, .count = 1, .enchant_count = max_enchant_dots };
    const count_many = render(&buf_many, 0, 100.0, 100.0, many);
    const count_max = render(&buf_max, 0, 100.0, 100.0, at_max);
    try testing.expectEqual(count_many, count_max);
}

test "buffer overflow protection" {
    var small: [6]UiVertex = undefined;
    const data = TooltipData{ .item_id = 999, .count = 64, .is_tool = true, .enchant_count = 5 };
    const count = render(&small, 0, 100.0, 100.0, data);
    try testing.expect(count <= 6);
}

test "addQuad writes correct triangle winding" {
    var buf: [6]UiVertex = undefined;
    var idx: u32 = 0;
    addQuad(&buf, &idx, 10.0, 20.0, 30.0, 40.0, bg_color);
    try testing.expectEqual(@as(u32, 6), idx);
    // Top-left
    try testing.expectApproxEqAbs(@as(f32, 10.0), buf[0].pos_x, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 20.0), buf[0].pos_y, 0.001);
    // Top-right
    try testing.expectApproxEqAbs(@as(f32, 40.0), buf[1].pos_x, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 20.0), buf[1].pos_y, 0.001);
    // Bottom-left
    try testing.expectApproxEqAbs(@as(f32, 10.0), buf[2].pos_x, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 60.0), buf[2].pos_y, 0.001);
}

test "content width accounts for durability bar" {
    const tool_data = TooltipData{ .item_id = 1, .count = 1, .is_tool = true };
    const item_data = TooltipData{ .item_id = 1, .count = 1, .is_tool = false };
    const w_tool = contentWidth(tool_data);
    const w_item = contentWidth(item_data);
    try testing.expect(w_tool >= w_item);
    try testing.expect(w_tool >= durability_bar_width);
}
