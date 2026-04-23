/// Brewing stand screen renderer.
/// Produces UiVertex quads for a centered panel with an ingredient slot,
/// three potion slots arranged in a triangle, a fuel bar, and a brew
/// progress bar.
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

pub const BrewData = struct {
    potion_items: [3]u16 = .{ 0, 0, 0 },
    potion_counts: [3]u8 = .{ 0, 0, 0 },
    ingredient_item: u16 = 0,
    ingredient_count: u8 = 0,
    fuel_charges: u8 = 0,
    brew_progress: f32 = 0,
};

pub const max_vertices = 2048;

// ---------------------------------------------------------------------------
// Layout constants
// ---------------------------------------------------------------------------

const panel_w: f32 = 350.0;
const panel_h: f32 = 300.0;

const slot_size: f32 = 36.0;
const slot_border: f32 = 2.0;

const fuel_bar_w: f32 = 12.0;
const fuel_bar_h: f32 = 80.0;

const brew_bar_w: f32 = 100.0;
const brew_bar_h: f32 = 10.0;

const pixel_scale: f32 = 2.0;

// ---------------------------------------------------------------------------
// Colors
// ---------------------------------------------------------------------------

const Color = struct { r: f32, g: f32, b: f32, a: f32 };

const panel_bg = Color{ .r = 0.15, .g = 0.15, .b = 0.15, .a = 0.88 };
const panel_border_col = Color{ .r = 0.35, .g = 0.35, .b = 0.35, .a = 0.95 };
const slot_bg = Color{ .r = 0.22, .g = 0.22, .b = 0.22, .a = 0.90 };
const slot_border_col = Color{ .r = 0.45, .g = 0.45, .b = 0.45, .a = 0.90 };

const fuel_bg = Color{ .r = 0.18, .g = 0.18, .b = 0.30, .a = 0.70 };
const fuel_fill = Color{ .r = 0.20, .g = 0.45, .b = 1.0, .a = 1.0 };

const brew_bg = Color{ .r = 0.30, .g = 0.30, .b = 0.30, .a = 0.70 };
const brew_fill_col = Color{ .r = 0.80, .g = 0.50, .b = 1.0, .a = 0.95 };

const title_col = Color{ .r = 0.90, .g = 0.90, .b = 0.90, .a = 1.0 };
const item_col = Color{ .r = 0.60, .g = 0.80, .b = 1.0, .a = 1.0 };
const count_col = Color{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 1.0 };

// ---------------------------------------------------------------------------
// Title pixel art: "BRW"
// ---------------------------------------------------------------------------

const LetterGlyph = u15;

const letter_B: LetterGlyph = 0b110_101_110_101_110;
const letter_R: LetterGlyph = 0b110_101_110_101_101;
const letter_W: LetterGlyph = 0b101_101_111_111_101;

const title_glyphs: [3]LetterGlyph = .{ letter_B, letter_R, letter_W };

fn getLetterPixel(glyph: LetterGlyph, x: u32, y: u32) bool {
    if (x >= 3 or y >= 5) return false;
    const bit_index: u4 = @intCast(y * 3 + x);
    return (glyph >> (14 - bit_index)) & 1 == 1;
}

// ---------------------------------------------------------------------------
// Quad helpers
// ---------------------------------------------------------------------------

/// Emit a solid-colored quad (2 triangles, 6 vertices). UV set to -1.
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

    // Item indicator
    if (item != 0 and count > 0) {
        const item_size: f32 = 20.0;
        addQuad(verts, idx, cx - item_size * 0.5, cy - item_size * 0.5, item_size, item_size, item_col);

        if (count > 1) {
            drawNumber(verts, idx, x + slot_size - 2.0, y + slot_size - 2.0, count);
        }
    }
}

/// Draw a number right-aligned and bottom-aligned at the given anchor.
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

/// Render the brewing stand screen UI into the provided vertex buffer.
/// Returns the number of vertices written.
pub fn render(verts: []UiVertex, start: u32, sw: f32, sh: f32, data: BrewData) u32 {
    var idx: u32 = start;

    const progress = std.math.clamp(data.brew_progress, 0.0, 1.0);
    const max_fuel: u8 = 20;
    const fuel_charges = @min(data.fuel_charges, max_fuel);

    const px = (sw - panel_w) * 0.5;
    const py = (sh - panel_h) * 0.5;

    const bw: f32 = 3.0;
    addQuad(verts, &idx, px - bw, py - bw, panel_w + bw * 2, bw, panel_border_col);
    addQuad(verts, &idx, px - bw, py + panel_h, panel_w + bw * 2, bw, panel_border_col);
    addQuad(verts, &idx, px - bw, py, bw, panel_h, panel_border_col);
    addQuad(verts, &idx, px + panel_w, py, bw, panel_h, panel_border_col);

    // Panel background
    addQuad(verts, &idx, px, py, panel_w, panel_h, panel_bg);

    const title_scale: f32 = 3.0;
    const title_char_w: f32 = 3.0 * title_scale + 2.0;
    const title_total_w: f32 = 3.0 * title_char_w - 2.0;
    const title_x = px + (panel_w - title_total_w) * 0.5;
    const title_y = py + 12.0;
    for (0..3) |ci| {
        const offset = @as(f32, @floatFromInt(ci)) * title_char_w;
        drawLetter(verts, &idx, title_x + offset, title_y, title_glyphs[ci], title_scale, title_col);
    }

    // Center reference
    const center_x = px + panel_w * 0.5;

    const ingr_cy = py + 70.0;
    renderSlot(verts, &idx, center_x, ingr_cy, data.ingredient_item, data.ingredient_count);

    // Three potion slots in a triangle below the ingredient slot
    const potion_row_y = py + 200.0;
    const potion_spacing: f32 = 60.0;
    const potion_positions = [3][2]f32{
        .{ center_x - potion_spacing, potion_row_y }, // left
        .{ center_x, potion_row_y + 40.0 }, // bottom-center
        .{ center_x + potion_spacing, potion_row_y }, // right
    };

    for (0..3) |i| {
        renderSlot(
            verts,
            &idx,
            potion_positions[i][0],
            potion_positions[i][1],
            data.potion_items[i],
            data.potion_counts[i],
        );
    }

    // Fuel bar: left side, vertical blue bar (max 20 charges)
    const fuel_x = px + 20.0;
    const fuel_y = py + 100.0;

    addQuad(verts, &idx, fuel_x, fuel_y, fuel_bar_w, fuel_bar_h, fuel_bg);

    if (fuel_charges > 0) {
        const fill_ratio = @as(f32, @floatFromInt(fuel_charges)) / @as(f32, @floatFromInt(max_fuel));
        const fill_h = fuel_bar_h * fill_ratio;
        addQuad(verts, &idx, fuel_x, fuel_y + fuel_bar_h - fill_h, fuel_bar_w, fill_h, fuel_fill);
    }

    // Brew progress bar: horizontal, between ingredient and potions
    const brew_x = center_x - brew_bar_w * 0.5;
    const brew_y = py + 140.0;

    addQuad(verts, &idx, brew_x, brew_y, brew_bar_w, brew_bar_h, brew_bg);

    if (progress > 0.0) {
        addQuad(verts, &idx, brew_x, brew_y, brew_bar_w * progress, brew_bar_h, brew_fill_col);
    }

    return idx - start;
}

// ===========================================================================
// Tests
// ===========================================================================

test "render returns non-zero vertices for default data" {
    var buf: [max_vertices]UiVertex = undefined;
    const count = render(&buf, 0, 800.0, 600.0, .{});
    // Panel border(4) + bg(1) + title glyphs + ingr slot(5) + 3 potion slots(15)
    // + fuel bg(1) + brew bg(1) = many quads
    try std.testing.expect(count >= 6 * 10);
    try std.testing.expect(count % 6 == 0);
}

test "render with active brewing produces more vertices than idle" {
    var buf_idle: [max_vertices]UiVertex = undefined;
    const idle_count = render(&buf_idle, 0, 800.0, 600.0, .{});

    var buf_active: [max_vertices]UiVertex = undefined;
    const active_count = render(&buf_active, 0, 800.0, 600.0, .{
        .ingredient_item = 1,
        .ingredient_count = 1,
        .potion_items = .{ 2, 3, 4 },
        .potion_counts = .{ 3, 1, 5 },
        .fuel_charges = 10,
        .brew_progress = 0.6,
    });

    try std.testing.expect(active_count > idle_count);
}

test "render respects start offset" {
    var buf: [max_vertices]UiVertex = undefined;
    const sentinel: u32 = 42;
    const count = render(&buf, sentinel, 800.0, 600.0, .{});
    try std.testing.expect(count > 0);
    // First vertex written at index 42
    try std.testing.expect(buf[sentinel].a != 0.0);
}

test "render clamps brew progress" {
    var buf: [max_vertices]UiVertex = undefined;
    const count = render(&buf, 0, 800.0, 600.0, .{
        .brew_progress = 1.5,
    });
    try std.testing.expect(count > 0);
}

test "render panel is centered on 350x300" {
    var buf: [max_vertices]UiVertex = undefined;
    _ = render(&buf, 0, 800.0, 600.0, .{});

    // First quad is the top border at (800-350)/2 - 3 = 222
    const expected_x = (800.0 - panel_w) * 0.5 - 3.0;
    try std.testing.expectApproxEqAbs(expected_x, buf[0].pos_x, 0.01);

    const expected_y = (600.0 - panel_h) * 0.5 - 3.0;
    try std.testing.expectApproxEqAbs(expected_y, buf[0].pos_y, 0.01);
}

test "addQuad writes exactly 6 vertices with uv=-1" {
    var buf: [6]UiVertex = undefined;
    var idx: u32 = 0;
    addQuad(&buf, &idx, 10, 20, 30, 40, .{ .r = 1, .g = 0, .b = 0, .a = 1 });
    try std.testing.expectEqual(@as(u32, 6), idx);
    try std.testing.expectApproxEqAbs(@as(f32, -1.0), buf[0].u, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, -1.0), buf[0].v, 0.01);
}

test "render does not overflow small buffer" {
    var buf: [12]UiVertex = undefined;
    const count = render(&buf, 0, 800.0, 600.0, .{
        .ingredient_item = 1,
        .ingredient_count = 64,
        .potion_items = .{ 2, 3, 4 },
        .potion_counts = .{ 10, 20, 30 },
        .fuel_charges = 15,
        .brew_progress = 0.9,
    });
    try std.testing.expect(count <= 12);
}

test "renderSlot empty produces 5 quads" {
    var buf: [512]UiVertex = undefined;
    var idx: u32 = 0;
    renderSlot(&buf, &idx, 100.0, 100.0, 0, 0);
    // 4 border + 1 background = 5 quads = 30 verts
    try std.testing.expectEqual(@as(u32, 30), idx);
}

test "drawNumber renders digit pixels" {
    var buf: [512]UiVertex = undefined;
    var idx: u32 = 0;
    drawNumber(&buf, &idx, 100.0, 100.0, 42);
    try std.testing.expect(idx > 0);
    try std.testing.expect(idx % 6 == 0);
}

test "fuel bar renders proportionally to charges" {
    // With 0 charges: only fuel bg quad (no fill)
    var buf0: [max_vertices]UiVertex = undefined;
    const count0 = render(&buf0, 0, 800.0, 600.0, .{ .fuel_charges = 0 });

    // With 20 charges: fuel bg + fuel fill
    var buf20: [max_vertices]UiVertex = undefined;
    const count20 = render(&buf20, 0, 800.0, 600.0, .{ .fuel_charges = 20 });

    // More charges means extra fill quad
    try std.testing.expect(count20 > count0);
}
