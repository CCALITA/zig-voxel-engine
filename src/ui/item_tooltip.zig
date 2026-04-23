/// Item tooltip rendered at the mouse cursor position.
/// Shows a dark background panel containing the item ID number, a durability
/// bar (green at full, red at zero), and enchantment indicator dots.
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
    durability_pct: f32 = 1,
    enchant_count: u8 = 0,
    is_tool: bool = false,
};

// ── Layout constants ─────────────────────────────────────────────────

const panel_padding: f32 = 6.0;
const pixel_scale: f32 = 2.0;
const durability_bar_height: f32 = 4.0;
const durability_bar_width: f32 = 60.0;
const durability_bar_gap: f32 = 4.0;
const enchant_dot_size: f32 = 4.0;
const enchant_dot_gap: f32 = 3.0;
const enchant_row_gap: f32 = 4.0;
const border_thickness: f32 = 1.0;

pub const max_vertices: u32 = 2048;

// ── Colours ──────────────────────────────────────────────────────────

const Color = struct { r: f32, g: f32, b: f32, a: f32 };

const bg_color = Color{ .r = 0.08, .g = 0.08, .b = 0.12, .a = 0.90 };
const border_color = Color{ .r = 0.20, .g = 0.15, .b = 0.35, .a = 0.95 };
const text_color = Color{ .r = 1.00, .g = 1.00, .b = 1.00, .a = 1.00 };
const text_shadow = Color{ .r = 0.05, .g = 0.05, .b = 0.05, .a = 0.85 };
const durability_bg = Color{ .r = 0.15, .g = 0.15, .b = 0.15, .a = 0.80 };
const enchant_color = Color{ .r = 0.40, .g = 0.60, .b = 1.00, .a = 1.00 };

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

// ── Number drawing (bitmap font digits with drop-shadow) ─────────────

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

// ── Durability bar colour (green -> yellow -> red) ───────────────────

fn durabilityColor(pct: f32) Color {
    const p = std.math.clamp(pct, 0.0, 1.0);
    // Green at 1.0, yellow at 0.5, red at 0.0
    const r_val = std.math.clamp(2.0 * (1.0 - p), 0.0, 1.0);
    const g_val = std.math.clamp(2.0 * p, 0.0, 1.0);
    return Color{ .r = r_val, .g = g_val, .b = 0.0, .a = 1.0 };
}

// ── Tooltip content height calculation ───────────────────────────────

fn contentHeight(data: TooltipData) f32 {
    const glyph_h: f32 = @floatFromInt(bitmap_font.GLYPH_H);
    var h = glyph_h * pixel_scale; // item ID number row
    if (data.is_tool) {
        h += durability_bar_gap + durability_bar_height; // durability bar
    }
    if (data.enchant_count > 0) {
        h += enchant_row_gap + enchant_dot_size; // enchant dots row
    }
    return h;
}

fn contentWidth(data: TooltipData) f32 {
    const glyph_w: f32 = @floatFromInt(bitmap_font.GLYPH_W);
    const digit_spacing: f32 = 1.0;
    const num_digits = bitmap_font.digitCount(@as(u32, data.item_id));
    const text_w = @as(f32, @floatFromInt(num_digits)) * (glyph_w * pixel_scale + digit_spacing) - digit_spacing;

    var w = text_w;
    if (data.is_tool and durability_bar_width > w) {
        w = durability_bar_width;
    }
    if (data.enchant_count > 0) {
        const enchant_count_f: f32 = @floatFromInt(data.enchant_count);
        const dots_w = enchant_count_f * enchant_dot_size + (enchant_count_f - 1.0) * enchant_dot_gap;
        if (dots_w > w) w = dots_w;
    }
    return w;
}

// ── Public render entry point ────────────────────────────────────────

/// Render an item tooltip at the mouse cursor position.
/// Returns the final vertex index after all emitted quads.
pub fn render(verts: []UiVertex, start: u32, mx: f32, my: f32, data: TooltipData) u32 {
    var idx = start;

    const inner_w = contentWidth(data);
    const inner_h = contentHeight(data);
    const panel_w = inner_w + panel_padding * 2.0;
    const panel_h = inner_h + panel_padding * 2.0;

    // Position panel to the right and below the cursor
    const panel_x = mx + 12.0;
    const panel_y = my + 12.0;

    // Border (slightly larger rectangle behind the panel)
    addQuad(verts, &idx, panel_x - border_thickness, panel_y - border_thickness, panel_w + border_thickness * 2.0, panel_h + border_thickness * 2.0, border_color);

    // Dark background panel
    addQuad(verts, &idx, panel_x, panel_y, panel_w, panel_h, bg_color);

    // Item ID number
    const text_x = panel_x + panel_padding;
    const text_y = panel_y + panel_padding;
    drawNumber(verts, &idx, text_x, text_y, @as(u32, data.item_id), text_color, text_shadow);

    const glyph_h: f32 = @floatFromInt(bitmap_font.GLYPH_H);
    var cursor_y = text_y + glyph_h * pixel_scale;

    // Durability bar (only for tools)
    if (data.is_tool) {
        cursor_y += durability_bar_gap;
        const dur_pct = std.math.clamp(data.durability_pct, 0.0, 1.0);

        // Bar background
        addQuad(verts, &idx, text_x, cursor_y, durability_bar_width, durability_bar_height, durability_bg);

        // Bar fill
        if (dur_pct > 0.0) {
            addQuad(verts, &idx, text_x, cursor_y, durability_bar_width * dur_pct, durability_bar_height, durabilityColor(dur_pct));
        }

        cursor_y += durability_bar_height;
    }

    // Enchantment indicator dots
    if (data.enchant_count > 0) {
        cursor_y += enchant_row_gap;
        var e: u32 = 0;
        const count: u32 = @intCast(data.enchant_count);
        while (e < count) : (e += 1) {
            const dot_x = text_x + @as(f32, @floatFromInt(e)) * (enchant_dot_size + enchant_dot_gap);
            addQuad(verts, &idx, dot_x, cursor_y, enchant_dot_size, enchant_dot_size, enchant_color);
        }
    }

    return idx;
}

// ── Tests ────────────────────────────────────────────────────────────

test "render produces vertices in multiples of 6" {
    var buf: [max_vertices]UiVertex = undefined;
    const count = render(&buf, 0, 100.0, 100.0, .{ .item_id = 42, .count = 1 });
    try std.testing.expect(count > 0);
    try std.testing.expect(count % 6 == 0);
}

test "render preserves start offset" {
    var buf: [max_vertices]UiVertex = undefined;
    const offset: u32 = 12;
    const count = render(&buf, offset, 50.0, 50.0, .{ .item_id = 1, .count = 1 });
    try std.testing.expect(count >= offset);
    try std.testing.expect((count - offset) % 6 == 0);
}

test "all vertices have u=-1 and v=-1" {
    var buf: [max_vertices]UiVertex = undefined;
    const count = render(&buf, 0, 200.0, 200.0, .{ .item_id = 999, .count = 5 });
    for (0..count) |i| {
        try std.testing.expectApproxEqAbs(@as(f32, -1.0), buf[i].u, 0.001);
        try std.testing.expectApproxEqAbs(@as(f32, -1.0), buf[i].v, 0.001);
    }
}

test "panel is positioned to the right of the cursor" {
    var buf: [max_vertices]UiVertex = undefined;
    const mx: f32 = 300.0;
    _ = render(&buf, 0, mx, 200.0, .{ .item_id = 10, .count = 1 });
    // First vertices belong to the border quad; panel_x = mx + 12 - border
    try std.testing.expect(buf[0].pos_x > mx);
}

test "tool tooltip includes durability bar quads" {
    var buf: [max_vertices]UiVertex = undefined;
    const count_no_tool = render(&buf, 0, 0, 0, .{ .item_id = 1, .count = 1, .is_tool = false });

    var buf2: [max_vertices]UiVertex = undefined;
    const count_tool = render(&buf2, 0, 0, 0, .{ .item_id = 1, .count = 1, .is_tool = true, .durability_pct = 0.5 });

    // Tool tooltip must have more quads (durability bg + fill)
    try std.testing.expect(count_tool > count_no_tool);
}

test "durability colour is green at full health" {
    const col = durabilityColor(1.0);
    try std.testing.expect(col.g >= 0.9);
    try std.testing.expect(col.r <= 0.1);
}

test "durability colour is red at zero health" {
    const col = durabilityColor(0.0);
    try std.testing.expect(col.r >= 0.9);
    try std.testing.expect(col.g <= 0.1);
}

test "enchant dots increase vertex count" {
    var buf: [max_vertices]UiVertex = undefined;
    const count_no_enchant = render(&buf, 0, 0, 0, .{ .item_id = 5, .count = 1, .enchant_count = 0 });

    var buf2: [max_vertices]UiVertex = undefined;
    const count_enchant = render(&buf2, 0, 0, 0, .{ .item_id = 5, .count = 1, .enchant_count = 3 });

    try std.testing.expect(count_enchant > count_no_enchant);
}

test "buffer overflow protection" {
    var small: [6]UiVertex = undefined;
    const count = render(&small, 0, 0, 0, .{ .item_id = 1, .count = 1, .is_tool = true, .enchant_count = 5 });
    try std.testing.expect(count <= 6);
}

test "zero durability produces no fill quad but does produce bg quad" {
    var buf: [max_vertices]UiVertex = undefined;
    const count_zero = render(&buf, 0, 0, 0, .{ .item_id = 1, .count = 1, .is_tool = true, .durability_pct = 0.0 });

    var buf2: [max_vertices]UiVertex = undefined;
    const count_half = render(&buf2, 0, 0, 0, .{ .item_id = 1, .count = 1, .is_tool = true, .durability_pct = 0.5 });

    // Zero durability should have one fewer quad (no fill, only bg)
    try std.testing.expect(count_half > count_zero);
}

test "default TooltipData values" {
    const data = TooltipData{ .item_id = 42, .count = 1 };
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), data.durability_pct, 0.001);
    try std.testing.expectEqual(@as(u8, 0), data.enchant_count);
    try std.testing.expect(!data.is_tool);
}
