/// Armor bar HUD renderer.
/// Renders 10 armor icons above hearts at screen height - 92.
/// Full armor = white 8x8 square (covers 2 defense points).
/// Half armor = 4x8 rectangle (covers 1 defense point).
/// Empty armor = dark outline.
/// Skips rendering if defense == 0.
/// All quads are flat-coloured (u=-1, v=-1).
const std = @import("std");

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

const icon_width: f32 = 8.0;
const icon_height: f32 = 8.0;
const icon_spacing: f32 = 1.0;
const bar_top_offset: f32 = 92.0; // above hearts at screen height - 92

const full_width: f32 = 8.0;
const half_width: f32 = 4.0;

/// Maximum vertices: 10 icons × 2 quads (border + fill) × 6 vertices = 120.
pub const max_vertices: u32 = 120;

// ── Colours ──────────────────────────────────────────────────────────

const Color = struct { r: f32, g: f32, b: f32, a: f32 };

const full_color = Color{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 1.0 };
const half_color = Color{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 1.0 };
const empty_color = Color{ .r = 0.2, .g = 0.2, .b = 0.2, .a = 0.7 };
const border_color = Color{ .r = 0.1, .g = 0.1, .b = 0.1, .a = 0.9 };

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

// ── Public render entry point ────────────────────────────────────────

/// Render 10 armor icons above hearts at screen height - 92.
/// Each icon represents 2 defense points (full = 8x8, half = 4x8).
/// Returns the final vertex index after all emitted quads.
pub fn render(verts: []UiVertex, start: u32, sw: f32, sh: f32, defense: u8) u32 {
    var idx = start;

    // Skip rendering if defense is zero
    if (defense == 0) return idx;

    const total_icons = 10;
    const bar_y = sh - bar_top_offset;

    // Calculate total width of all icons with spacing
    const total_width = total_icons * icon_width + (total_icons - 1) * icon_spacing;
    const bar_x = (sw - total_width) * 0.5;

    var remaining_defense = defense;

    for (0..total_icons) |i| {
        const icon_x = bar_x + @as(f32, @floatFromInt(i)) * (icon_width + icon_spacing);

        // Draw border for all icons
        addQuad(verts, &idx, icon_x, bar_y, icon_width, icon_height, border_color);

        if (remaining_defense >= 2) {
            // Full armor (8x8 white square)
            addQuad(verts, &idx, icon_x, bar_y, full_width, icon_height, full_color);
            remaining_defense -= 2;
        } else if (remaining_defense == 1) {
            // Half armor (4x8 white rectangle)
            addQuad(verts, &idx, icon_x, bar_y, half_width, icon_height, half_color);
            remaining_defense -= 1;
        } else {
            // Empty armor (dark outline only)
            addQuad(verts, &idx, icon_x, bar_y, icon_width, icon_height, empty_color);
        }
    }

    return idx;
}

// ── Tests ────────────────────────────────────────────────────────────

const testing = std.testing;

test "render produces vertices in multiples of 6" {
    var buf: [max_vertices]UiVertex = undefined;
    const count = render(&buf, 0, 800.0, 600.0, 10);
    try testing.expect(count > 0);
    try testing.expect(count % 6 == 0);
}

test "render preserves start offset" {
    var buf: [max_vertices]UiVertex = undefined;
    const offset: u32 = 12;
    const count = render(&buf, offset, 800.0, 600.0, 5);
    try testing.expect(count >= offset);
    try testing.expect((count - offset) % 6 == 0);
}

test "all vertices have u=-1 and v=-1" {
    var buf: [max_vertices]UiVertex = undefined;
    const count = render(&buf, 0, 800.0, 600.0, 7);
    for (0..count) |i| {
        try testing.expectApproxEqAbs(@as(f32, -1.0), buf[i].u, 0.001);
        try testing.expectApproxEqAbs(@as(f32, -1.0), buf[i].v, 0.001);
    }
}

test "zero defense returns start unchanged" {
    var buf: [max_vertices]UiVertex = undefined;
    const count = render(&buf, 6, 800.0, 600.0, 0);
    try testing.expectEqual(@as(u32, 6), count);
}

test "full defense (20) produces 20 quads" {
    var buf: [max_vertices]UiVertex = undefined;
    const count = render(&buf, 0, 800.0, 600.0, 20);
    // 10 icons × 2 quads each (border + fill) = 20 quads × 6 vertices = 120 vertices
    try testing.expectEqual(@as(u32, 120), count);
}

test "partial defense (7) produces correct number of quads" {
    var buf: [max_vertices]UiVertex = undefined;
    const count = render(&buf, 0, 800.0, 600.0, 7);
    // 3 full icons (2 pts each) + 1 half icon (1 pt) + 6 empty icons
    // Each icon has border (1 quad) + fill (1 quad) = 2 quads per icon
    // 10 icons × 2 quads = 20 quads × 6 vertices = 120 vertices
    try testing.expectEqual(@as(u32, 120), count);
}

test "bar is horizontally centred on screen" {
    var buf: [max_vertices]UiVertex = undefined;
    const sw: f32 = 1000.0;
    _ = render(&buf, 0, sw, 600.0, 10);
    // First quad is the first icon border
    const first_icon_left = buf[0].pos_x;
    const total_width = 10 * icon_width + 9 * icon_spacing;
    const expected_left = (sw - total_width) * 0.5;
    try testing.expectApproxEqAbs(expected_left, first_icon_left, 0.01);
}

test "bar is positioned at screen height - 92" {
    var buf: [max_vertices]UiVertex = undefined;
    const sh: f32 = 600.0;
    _ = render(&buf, 0, 800.0, sh, 10);
    // First quad Y position should be sh - 92
    const bar_y = buf[0].pos_y;
    const expected_y = sh - bar_top_offset;
    try testing.expectApproxEqAbs(expected_y, bar_y, 0.01);
}

test "buffer overflow protection" {
    var small: [6]UiVertex = undefined;
    const count = render(&small, 0, 800.0, 600.0, 20);
    try testing.expect(count <= 6);
}

test "defense greater than 20 caps at 20" {
    var buf: [max_vertices]UiVertex = undefined;
    const count1 = render(&buf, 0, 800.0, 600.0, 20);

    var buf2: [max_vertices]UiVertex = undefined;
    const count2 = render(&buf2, 0, 800.0, 600.0, 25);

    // Should produce same number of vertices (all icons full)
    try testing.expectEqual(count1, count2);
}

test "full armor icon is white" {
    var buf: [max_vertices]UiVertex = undefined;
    _ = render(&buf, 0, 800.0, 600.0, 20);
    // Second quad (index 6) is the fill of the first icon (full white)
    try testing.expectApproxEqAbs(@as(f32, 1.0), buf[6].r, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 1.0), buf[6].g, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 1.0), buf[6].b, 0.001);
}

test "half armor (defense=1) uses half-width fill" {
    var buf: [max_vertices]UiVertex = undefined;
    _ = render(&buf, 0, 800.0, 600.0, 1);
    // Second quad (index 6) is the fill of the first icon (half)
    // Width = x1 - x0, where x0 = buf[6].pos_x and x1 = buf[7].pos_x
    const fill_w = buf[7].pos_x - buf[6].pos_x;
    try testing.expectApproxEqAbs(half_width, fill_w, 0.01);
}

test "icon spacing is applied between icons" {
    var buf: [max_vertices]UiVertex = undefined;
    _ = render(&buf, 0, 800.0, 600.0, 20);
    // Border of icon 0 starts at buf[0]; border of icon 1 starts at buf[12]
    // (6 vertices per quad * 2 quads per icon = 12)
    const first_icon_x = buf[0].pos_x;
    const second_icon_x = buf[12].pos_x;
    const delta = second_icon_x - first_icon_x;
    try testing.expectApproxEqAbs(icon_width + icon_spacing, delta, 0.01);
}