/// In-game HUD renderer.
/// Produces UiVertex quads for crosshair, health hearts, hunger drumsticks,
/// XP bar with level number, and hotbar with item indicators.
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

// ── Layout constants ─────────────────────────────────────────────────

const crosshair_size: f32 = 10.0;
const crosshair_thick: f32 = 2.0;
const outline_pad: f32 = 1.0;

const heart_size: f32 = 8.0;
const icon_gap: f32 = 1.0;
const drumstick_gap: f32 = 4.0;

const xp_bar_height: f32 = 4.0;

const slot_size: f32 = 36.0;
const slot_gap: f32 = 2.0;
const slot_count: u32 = 9;
const hotbar_width: f32 = @as(f32, @floatFromInt(slot_count)) * slot_size +
    @as(f32, @floatFromInt(slot_count - 1)) * slot_gap;
const selected_border: f32 = 2.0;

const pixel_scale: f32 = 2.0;

pub const max_vertices = 4096;

// ── Colors ───────────────────────────────────────────────────────────

const Color = struct { r: f32, g: f32, b: f32, a: f32 };

const white = Color{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 1.0 };
const dark_outline = Color{ .r = 0.1, .g = 0.1, .b = 0.1, .a = 0.8 };
const red_heart = Color{ .r = 0.9, .g = 0.1, .b = 0.1, .a = 1.0 };
const red_empty = Color{ .r = 0.3, .g = 0.05, .b = 0.05, .a = 0.5 };
const brown_full = Color{ .r = 0.7, .g = 0.5, .b = 0.2, .a = 1.0 };
const brown_empty = Color{ .r = 0.25, .g = 0.15, .b = 0.05, .a = 0.5 };
const green_xp = Color{ .r = 0.3, .g = 0.9, .b = 0.1, .a = 1.0 };
const green_xp_bg = Color{ .r = 0.1, .g = 0.2, .b = 0.05, .a = 0.6 };
const slot_bg = Color{ .r = 0.2, .g = 0.2, .b = 0.2, .a = 0.7 };
const item_placeholder = Color{ .r = 0.6, .g = 0.8, .b = 1.0, .a = 0.9 };
const count_fg = Color{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 1.0 };
const count_shadow = Color{ .r = 0.15, .g = 0.15, .b = 0.15, .a = 0.8 };
const level_fg = Color{ .r = 0.5, .g = 1.0, .b = 0.2, .a = 1.0 };
const level_shadow = Color{ .r = 0.1, .g = 0.2, .b = 0.05, .a = 0.8 };

// ── Quad helper ──────────────────────────────────────────────────────

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

// ── Number drawing ───────────────────────────────────────────────────

fn drawNumber(verts: []UiVertex, idx: *u32, center_x: f32, y: f32, value: u32, fg: Color, shadow: Color) void {
    const num_digits = bitmap_font.digitCount(value);
    const glyph_w: f32 = @floatFromInt(bitmap_font.GLYPH_W);
    const digit_spacing: f32 = 1.0;
    const total_w = @as(f32, @floatFromInt(num_digits)) * (glyph_w * pixel_scale + digit_spacing) - digit_spacing;
    const start_x = center_x - total_w * 0.5;

    var d: u32 = 0;
    while (d < num_digits) : (d += 1) {
        const digit = bitmap_font.getDigit(value, num_digits - 1 - d);
        const dx = start_x + @as(f32, @floatFromInt(d)) * (glyph_w * pixel_scale + digit_spacing);

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

// ── Icon row (hearts / drumsticks) ───────────────────────────────────

fn drawIconRow(verts: []UiVertex, idx: *u32, base_x: f32, y: f32, value: u8, full_col: Color, empty_col: Color) void {
    const full_icons = value / 2;
    const has_half = value % 2 == 1;

    for (0..10) |i| {
        const fi: f32 = @floatFromInt(i);
        const ix = base_x + fi * (heart_size + icon_gap);

        if (i < full_icons) {
            addQuad(verts, idx, ix, y, heart_size, heart_size, full_col);
        } else if (i == full_icons and has_half) {
            addQuad(verts, idx, ix, y, heart_size * 0.5, heart_size, full_col);
            addQuad(verts, idx, ix + heart_size * 0.5, y, heart_size * 0.5, heart_size, empty_col);
        } else {
            addQuad(verts, idx, ix, y, heart_size, heart_size, empty_col);
        }
    }
}

// ── Item color from ID ───────────────────────────────────────────────

fn itemColor(item_id: u16) Color {
    if (item_id == 0) return slot_bg;
    // Derive a deterministic color from the item ID
    const r_byte: u8 = @truncate((item_id *% 7 +% 80) & 0xFF);
    const g_byte: u8 = @truncate((item_id *% 13 +% 100) & 0xFF);
    const b_byte: u8 = @truncate((item_id *% 23 +% 60) & 0xFF);
    return Color{
        .r = @as(f32, @floatFromInt(r_byte)) / 255.0,
        .g = @as(f32, @floatFromInt(g_byte)) / 255.0,
        .b = @as(f32, @floatFromInt(b_byte)) / 255.0,
        .a = 1.0,
    };
}

// ── Main render ──────────────────────────────────────────────────────

pub fn render(
    verts: []UiVertex,
    start: u32,
    sw: f32,
    sh: f32,
    health: u8,
    max_health: u8,
    hunger: u8,
    xp_progress: f32,
    xp_level: u32,
    selected_slot: u8,
    hotbar_items: [9]u16,
    hotbar_counts: [9]u8,
) u32 {
    var idx = start;

    const clamped_health = @min(health, max_health);
    const cx = sw * 0.5;
    const cy = sh * 0.5;

    // Crosshair: dark outline behind white cross
    addQuad(verts, &idx, cx - crosshair_size - outline_pad, cy - crosshair_thick * 0.5 - outline_pad, (crosshair_size + outline_pad) * 2.0, crosshair_thick + outline_pad * 2.0, dark_outline);
    // Vertical bar outline
    addQuad(verts, &idx, cx - crosshair_thick * 0.5 - outline_pad, cy - crosshair_size - outline_pad, crosshair_thick + outline_pad * 2.0, (crosshair_size + outline_pad) * 2.0, dark_outline);
    // Horizontal bar (white)
    addQuad(verts, &idx, cx - crosshair_size, cy - crosshair_thick * 0.5, crosshair_size * 2.0, crosshair_thick, white);
    // Vertical bar (white)
    addQuad(verts, &idx, cx - crosshair_thick * 0.5, cy - crosshair_size, crosshair_thick, crosshair_size * 2.0, white);

    // ── Hotbar (9 slots, 36px each, centered, at sh-42) ──────────
    const hotbar_x = cx - hotbar_width * 0.5;
    const hotbar_y = sh - 42.0;

    for (0..slot_count) |i| {
        const fi: f32 = @floatFromInt(i);
        const sx = hotbar_x + fi * (slot_size + slot_gap);

        // Slot background
        addQuad(verts, &idx, sx, hotbar_y, slot_size, slot_size, slot_bg);

        // Selected slot: white border
        if (i == selected_slot) {
            // Top
            addQuad(verts, &idx, sx - selected_border, hotbar_y - selected_border, slot_size + selected_border * 2.0, selected_border, white);
            // Bottom
            addQuad(verts, &idx, sx - selected_border, hotbar_y + slot_size, slot_size + selected_border * 2.0, selected_border, white);
            // Left
            addQuad(verts, &idx, sx - selected_border, hotbar_y, selected_border, slot_size, white);
            // Right
            addQuad(verts, &idx, sx + slot_size, hotbar_y, selected_border, slot_size, white);
        }

        // Item as colored square
        if (hotbar_items[i] != 0 and hotbar_counts[i] > 0) {
            const item_size: f32 = 24.0;
            const item_pad = (slot_size - item_size) * 0.5;
            const col = itemColor(hotbar_items[i]);
            addQuad(verts, &idx, sx + item_pad, hotbar_y + item_pad, item_size, item_size, col);

            // Draw count if > 1
            if (hotbar_counts[i] > 1) {
                const count_x = sx + slot_size - 4.0;
                const count_y = hotbar_y + slot_size - @as(f32, @floatFromInt(bitmap_font.GLYPH_H)) * pixel_scale - 2.0;
                drawNumber(verts, &idx, count_x, count_y, @intCast(hotbar_counts[i]), count_fg, count_shadow);
            }
        }
    }

    // ── XP bar (green, at sh-56) ─────────────────────────────────
    const xp_y = sh - 56.0;
    addQuad(verts, &idx, hotbar_x, xp_y, hotbar_width, xp_bar_height, green_xp_bg);
    const xp_fill = std.math.clamp(xp_progress, 0.0, 1.0);
    if (xp_fill > 0.0) {
        addQuad(verts, &idx, hotbar_x, xp_y, hotbar_width * xp_fill, xp_bar_height, green_xp);
    }

    // XP level number centered above bar
    if (xp_level > 0) {
        const level_y = xp_y - @as(f32, @floatFromInt(bitmap_font.GLYPH_H)) * pixel_scale - 2.0;
        drawNumber(verts, &idx, cx, level_y, xp_level, level_fg, level_shadow);
    }

    // ── Health hearts (10 hearts at sh-80) ───────────────────────
    const hearts_y = sh - 80.0;
    drawIconRow(verts, &idx, hotbar_x, hearts_y, clamped_health, red_heart, red_empty);

    // ── Hunger drumsticks (right of hearts) ──────────────────────
    const hearts_width = 10.0 * (heart_size + icon_gap) - icon_gap;
    const hunger_x = hotbar_x + hearts_width + drumstick_gap;
    drawIconRow(verts, &idx, hunger_x, hearts_y, hunger, brown_full, brown_empty);

    return idx;
}

// ── Tests ────────────────────────────────────────────────────────────

const empty_items = [9]u16{ 0, 0, 0, 0, 0, 0, 0, 0, 0 };
const empty_counts = [9]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0 };

test "render returns more vertices than start" {
    var buf: [max_vertices]UiVertex = undefined;
    const count = render(&buf, 0, 800.0, 600.0, 20, 20, 20, 0.5, 5, 0, empty_items, empty_counts);
    try std.testing.expect(count > 0);
    // Vertices written should be a multiple of 6
    try std.testing.expect(count % 6 == 0);
}

test "render with start offset preserves offset" {
    var buf: [max_vertices]UiVertex = undefined;
    const count = render(&buf, 12, 800.0, 600.0, 20, 20, 20, 0.0, 0, 0, empty_items, empty_counts);
    try std.testing.expect(count >= 12);
    try std.testing.expect((count - 12) % 6 == 0);
}

test "crosshair is centered on screen" {
    var buf: [max_vertices]UiVertex = undefined;
    const sw: f32 = 1920.0;
    const sh: f32 = 1080.0;
    _ = render(&buf, 0, sw, sh, 0, 20, 0, 0.0, 0, 0, empty_items, empty_counts);

    // First quad is the horizontal crosshair outline, centered on screen
    const expected_cy = sh * 0.5;
    // Check that the first vertex y is near center
    try std.testing.expect(buf[0].pos_y < expected_cy);
    try std.testing.expect(buf[0].pos_y > expected_cy - crosshair_size - outline_pad - 1.0);
}

test "selected slot adds same border quad count regardless of position" {
    var buf: [max_vertices]UiVertex = undefined;
    const count_sel0 = render(&buf, 0, 800.0, 600.0, 20, 20, 20, 0.0, 0, 0, empty_items, empty_counts);

    var buf2: [max_vertices]UiVertex = undefined;
    const count_sel4 = render(&buf2, 0, 800.0, 600.0, 20, 20, 20, 0.0, 0, 4, empty_items, empty_counts);

    // One slot is always selected; total vertex count is independent of which one
    try std.testing.expectEqual(count_sel0, count_sel4);
}

test "items generate extra quads for colored squares" {
    var buf: [max_vertices]UiVertex = undefined;
    const count_empty = render(&buf, 0, 800.0, 600.0, 20, 20, 20, 0.0, 0, 0, empty_items, empty_counts);

    var buf2: [max_vertices]UiVertex = undefined;
    const items = [9]u16{ 5, 0, 0, 0, 0, 0, 0, 0, 0 };
    const counts = [9]u8{ 1, 0, 0, 0, 0, 0, 0, 0, 0 };
    const count_with_item = render(&buf2, 0, 800.0, 600.0, 20, 20, 20, 0.0, 0, 0, items, counts);

    // One item adds at least one colored quad (6 verts)
    try std.testing.expect(count_with_item > count_empty);
}

test "xp level number generates digit quads" {
    var buf: [max_vertices]UiVertex = undefined;
    const count_no_level = render(&buf, 0, 800.0, 600.0, 20, 20, 20, 0.5, 0, 0, empty_items, empty_counts);

    var buf2: [max_vertices]UiVertex = undefined;
    const count_with_level = render(&buf2, 0, 800.0, 600.0, 20, 20, 20, 0.5, 42, 0, empty_items, empty_counts);

    // Level 42 produces digit quads; level 0 does not
    try std.testing.expect(count_with_level > count_no_level);
}

test "half heart produces extra quad" {
    var buf1: [max_vertices]UiVertex = undefined;
    const count_half = render(&buf1, 0, 800.0, 600.0, 7, 20, 20, 0.0, 0, 0, empty_items, empty_counts);

    var buf2: [max_vertices]UiVertex = undefined;
    const count_full = render(&buf2, 0, 800.0, 600.0, 20, 20, 20, 0.0, 0, 0, empty_items, empty_counts);

    // Health 7 has one half-heart icon (2 quads) replacing one full icon (1 quad)
    try std.testing.expect(count_half > count_full);
}

test "buffer overflow protection" {
    var buf: [6]UiVertex = undefined;
    const count = render(&buf, 0, 800.0, 600.0, 20, 20, 20, 1.0, 30, 0, empty_items, empty_counts);
    try std.testing.expect(count <= 6);
}

test "UV coordinates are set to -1" {
    var buf: [max_vertices]UiVertex = undefined;
    const count = render(&buf, 0, 800.0, 600.0, 20, 20, 20, 0.5, 0, 0, empty_items, empty_counts);
    // All quads should have u=-1, v=-1 (no texture)
    for (0..count) |i| {
        try std.testing.expectApproxEqAbs(buf[i].u, -1.0, 0.001);
        try std.testing.expectApproxEqAbs(buf[i].v, -1.0, 0.001);
    }
}

test "stacked items produce count digits" {
    var buf: [max_vertices]UiVertex = undefined;
    const items_single = [9]u16{ 1, 0, 0, 0, 0, 0, 0, 0, 0 };
    const counts_single = [9]u8{ 1, 0, 0, 0, 0, 0, 0, 0, 0 };
    const count_single = render(&buf, 0, 800.0, 600.0, 20, 20, 20, 0.0, 0, 0, items_single, counts_single);

    var buf2: [max_vertices]UiVertex = undefined;
    const items_stack = [9]u16{ 1, 0, 0, 0, 0, 0, 0, 0, 0 };
    const counts_stack = [9]u8{ 64, 0, 0, 0, 0, 0, 0, 0, 0 };
    const count_stack = render(&buf2, 0, 800.0, 600.0, 20, 20, 20, 0.0, 0, 0, items_stack, counts_stack);

    // Stacked item generates digit quads on top of the item square
    try std.testing.expect(count_stack > count_single);
}
