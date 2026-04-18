/// 2D screen-space vertex generation for HUD overlay elements.
/// Produces colored quads (2 triangles = 6 vertices each) in pixel coordinates.
const std = @import("std");

pub const HudVertex = struct {
    x: f32,
    y: f32,
    r: f32,
    g: f32,
    b: f32,
    a: f32,
};

pub const HudState = struct {
    screen_width: f32,
    screen_height: f32,
    health: u8, // 0-20 (10 hearts)
    hunger: u8, // 0-20 (10 drumsticks)
    selected_slot: u8, // 0-8
    xp_progress: f32, // 0.0-1.0
    xp_level: u32,
    oxygen: f32, // 0.0-1.0 (1.0 = full, show only when < 1.0)
    is_underwater: bool,
};

pub const max_vertices = 2048;

// Dimensions
const slot_size: f32 = 20.0;
const slot_gap: f32 = 2.0;
const slot_count: f32 = 9.0;
const hotbar_width: f32 = slot_count * slot_size + (slot_count - 1.0) * slot_gap;
const heart_size: f32 = 8.0;
const icon_gap: f32 = 2.0;
const xp_bar_height: f32 = 4.0;
const crosshair_half_len: f32 = 10.0;
const crosshair_half_w: f32 = 1.0;
const hotbar_bottom_margin: f32 = 10.0;
const icon_row_gap: f32 = 2.0;
const border_width: f32 = 2.0;

// Colors
const white = Color{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 0.8 };
const gray_bg = Color{ .r = 0.2, .g = 0.2, .b = 0.2, .a = 0.7 };
const yellow_border = Color{ .r = 1.0, .g = 1.0, .b = 0.0, .a = 1.0 };
const red_full = Color{ .r = 0.9, .g = 0.1, .b = 0.1, .a = 1.0 };
const red_empty = Color{ .r = 0.3, .g = 0.05, .b = 0.05, .a = 0.6 };
const brown_full = Color{ .r = 0.7, .g = 0.5, .b = 0.2, .a = 1.0 };
const brown_empty = Color{ .r = 0.25, .g = 0.15, .b = 0.05, .a = 0.6 };
const green_xp = Color{ .r = 0.3, .g = 0.9, .b = 0.1, .a = 1.0 };
const green_xp_bg = Color{ .r = 0.1, .g = 0.2, .b = 0.05, .a = 0.6 };
const blue_bubble = Color{ .r = 0.2, .g = 0.5, .b = 1.0, .a = 1.0 };
const blue_empty = Color{ .r = 0.1, .g = 0.2, .b = 0.4, .a = 0.6 };

const Color = struct { r: f32, g: f32, b: f32, a: f32 };

/// Generates all HUD vertices into `buf` and returns the count written.
/// The buffer must be at least `max_vertices` elements.
pub fn generateHudVertices(state: HudState, buf: []HudVertex) u32 {
    var count: u32 = 0;

    const cx = state.screen_width * 0.5;
    const cy = state.screen_height * 0.5;

    // -- Crosshair: 4 non-overlapping arms forming a + --
    const gap = 2.0;
    const arm = crosshair_half_len - gap;
    // Left arm
    emitQuad(buf, &count, cx - crosshair_half_len, cy - crosshair_half_w, arm, crosshair_half_w * 2.0, white);
    // Right arm
    emitQuad(buf, &count, cx + gap, cy - crosshair_half_w, arm, crosshair_half_w * 2.0, white);
    // Top arm
    emitQuad(buf, &count, cx - crosshair_half_w, cy - crosshair_half_len, crosshair_half_w * 2.0, arm, white);
    // Bottom arm
    emitQuad(buf, &count, cx - crosshair_half_w, cy + gap, crosshair_half_w * 2.0, arm, white);

    // -- Hotbar --
    const hotbar_x = cx - hotbar_width * 0.5;
    const hotbar_y = state.screen_height - hotbar_bottom_margin - slot_size;

    for (0..9) |i| {
        const fi: f32 = @floatFromInt(i);
        const sx = hotbar_x + fi * (slot_size + slot_gap);

        emitQuad(buf, &count, sx, hotbar_y, slot_size, slot_size, gray_bg);

        if (i == state.selected_slot) {
            emitQuad(buf, &count, sx - border_width, hotbar_y - border_width, slot_size + border_width * 2.0, border_width, yellow_border);
            emitQuad(buf, &count, sx - border_width, hotbar_y + slot_size, slot_size + border_width * 2.0, border_width, yellow_border);
            emitQuad(buf, &count, sx - border_width, hotbar_y, border_width, slot_size, yellow_border);
            emitQuad(buf, &count, sx + slot_size, hotbar_y, border_width, slot_size, yellow_border);
        }
    }

    // -- XP bar (above hotbar) --
    const xp_y = hotbar_y - icon_row_gap - xp_bar_height;
    emitQuad(buf, &count, hotbar_x, xp_y, hotbar_width, xp_bar_height, green_xp_bg);
    const xp_fill = std.math.clamp(state.xp_progress, 0.0, 1.0);
    if (xp_fill > 0.0) {
        emitQuad(buf, &count, hotbar_x, xp_y, hotbar_width * xp_fill, xp_bar_height, green_xp);
    }

    // -- Health hearts (above xp bar, left-aligned to hotbar) --
    const hearts_y = xp_y - icon_row_gap - heart_size;
    emitIconRow(buf, &count, hotbar_x, hearts_y, state.health, red_full, red_empty);

    // -- Hunger drumsticks (above xp bar, right-aligned to hotbar) --
    const hunger_base_x = hotbar_x + hotbar_width - 10.0 * (heart_size + icon_gap) + icon_gap;
    emitIconRow(buf, &count, hunger_base_x, hearts_y, state.hunger, brown_full, brown_empty);

    // -- Oxygen bubbles (above hunger, only when underwater) --
    if (state.is_underwater) {
        const oxy_y = hearts_y - icon_row_gap - heart_size;
        const filled_bubbles: u8 = @intFromFloat(std.math.clamp(state.oxygen * 10.0, 0.0, 10.0));

        for (0..10) |i| {
            const fi: f32 = @floatFromInt(i);
            const bx = hunger_base_x + fi * (heart_size + icon_gap);
            if (i < filled_bubbles) {
                emitQuad(buf, &count, bx, oxy_y, heart_size, heart_size, blue_bubble);
            } else {
                emitQuad(buf, &count, bx, oxy_y, heart_size, heart_size, blue_empty);
            }
        }
    }

    return count;
}

/// Emits a row of 10 icons (hearts, drumsticks, etc.) with full/half/empty states.
/// `value` is 0-20 where each icon represents 2 units.
fn emitIconRow(buf: []HudVertex, count: *u32, base_x: f32, y: f32, value: u8, full_col: Color, empty_col: Color) void {
    const full_icons = value / 2;
    const has_half = value % 2 == 1;

    for (0..10) |i| {
        const fi: f32 = @floatFromInt(i);
        const ix = base_x + fi * (heart_size + icon_gap);

        if (i < full_icons) {
            emitQuad(buf, count, ix, y, heart_size, heart_size, full_col);
        } else if (i == full_icons and has_half) {
            emitQuad(buf, count, ix, y, heart_size * 0.5, heart_size, full_col);
            emitQuad(buf, count, ix + heart_size * 0.5, y, heart_size * 0.5, heart_size, empty_col);
        } else {
            emitQuad(buf, count, ix, y, heart_size, heart_size, empty_col);
        }
    }
}

/// Writes a quad (2 triangles, 6 vertices) into `buf` at position `count`.
fn emitQuad(buf: []HudVertex, count: *u32, x: f32, y: f32, w: f32, h: f32, col: Color) void {
    if (count.* + 6 > buf.len) return;

    const x1 = x + w;
    const y1 = y + h;

    buf[count.*] = .{ .x = x, .y = y, .r = col.r, .g = col.g, .b = col.b, .a = col.a };
    buf[count.* + 1] = .{ .x = x1, .y = y, .r = col.r, .g = col.g, .b = col.b, .a = col.a };
    buf[count.* + 2] = .{ .x = x, .y = y1, .r = col.r, .g = col.g, .b = col.b, .a = col.a };
    buf[count.* + 3] = .{ .x = x1, .y = y, .r = col.r, .g = col.g, .b = col.b, .a = col.a };
    buf[count.* + 4] = .{ .x = x1, .y = y1, .r = col.r, .g = col.g, .b = col.b, .a = col.a };
    buf[count.* + 5] = .{ .x = x, .y = y1, .r = col.r, .g = col.g, .b = col.b, .a = col.a };

    count.* += 6;
}

// ── Tests ──────────────────────────────────────────────────────────────

test "crosshair generates 24 vertices (4 lines)" {
    var buf: [max_vertices]HudVertex = undefined;
    const state = HudState{
        .screen_width = 800,
        .screen_height = 600,
        .health = 0,
        .hunger = 0,
        .selected_slot = 0,
        .xp_progress = 0.0,
        .xp_level = 0,
        .oxygen = 1.0,
        .is_underwater = false,
    };
    const total = generateHudVertices(state, &buf);
    try std.testing.expect(total >= 24);

    // First vertex is the left crosshair arm, positioned at screen center minus half-length
    try std.testing.expectApproxEqAbs(buf[0].x, 400.0 - 10.0, 0.01);
    try std.testing.expectApproxEqAbs(buf[0].y, 300.0 - 1.0, 0.01);
}

test "hotbar generates correct slot count" {
    var buf: [max_vertices]HudVertex = undefined;
    const state = HudState{
        .screen_width = 800,
        .screen_height = 600,
        .health = 20,
        .hunger = 20,
        .selected_slot = 4,
        .xp_progress = 0.5,
        .xp_level = 5,
        .oxygen = 1.0,
        .is_underwater = false,
    };
    const total = generateHudVertices(state, &buf);

    // 4 crosshair + 13 hotbar (9 bg + 4 border) + 2 xp + 10 hearts + 10 hunger = 39 quads = 234 verts
    try std.testing.expectEqual(@as(u32, 234), total);
}

test "health hearts match health value" {
    var buf: [max_vertices]HudVertex = undefined;

    // 7 health = 3 full + 1 half + 6 empty hearts
    const state = HudState{
        .screen_width = 800,
        .screen_height = 600,
        .health = 7,
        .hunger = 20,
        .selected_slot = 0,
        .xp_progress = 0.0,
        .xp_level = 0,
        .oxygen = 1.0,
        .is_underwater = false,
    };
    const total = generateHudVertices(state, &buf);
    _ = total;

    // Hearts start after: crosshair(24) + hotbar(78) + xp_bg(6) = 108 verts
    const hearts_start: u32 = 108;

    // First 3 hearts should be red (full)
    for (0..3) |i| {
        const idx = hearts_start + @as(u32, @intCast(i)) * 6;
        try std.testing.expectApproxEqAbs(buf[idx].r, red_full.r, 0.01);
    }

    // 4th heart is half: left half red, right half dark = 2 quads
    const half_idx = hearts_start + 3 * 6;
    try std.testing.expectApproxEqAbs(buf[half_idx].r, red_full.r, 0.01);
    try std.testing.expectApproxEqAbs(buf[half_idx + 6].r, red_empty.r, 0.01);

    // 5th heart (index 4) starts after the half-heart's 2 quads: offset = 3*6 + 12 = 30
    const empty_start = hearts_start + 3 * 6 + 12;
    try std.testing.expectApproxEqAbs(buf[empty_start].r, red_empty.r, 0.01);
}

test "oxygen bubbles only shown when underwater" {
    var buf: [max_vertices]HudVertex = undefined;

    const surface_state = HudState{
        .screen_width = 800,
        .screen_height = 600,
        .health = 20,
        .hunger = 20,
        .selected_slot = 0,
        .xp_progress = 0.0,
        .xp_level = 0,
        .oxygen = 0.5,
        .is_underwater = false,
    };
    const surface_total = generateHudVertices(surface_state, &buf);

    var buf2: [max_vertices]HudVertex = undefined;
    const underwater_state = HudState{
        .screen_width = 800,
        .screen_height = 600,
        .health = 20,
        .hunger = 20,
        .selected_slot = 0,
        .xp_progress = 0.0,
        .xp_level = 0,
        .oxygen = 0.5,
        .is_underwater = true,
    };
    const underwater_total = generateHudVertices(underwater_state, &buf2);

    // Underwater should have 10 extra bubble quads = 60 more vertices
    try std.testing.expectEqual(surface_total + 60, underwater_total);
}

test "buffer overflow protection" {
    // Tiny buffer should not crash
    var buf: [6]HudVertex = undefined;
    const state = HudState{
        .screen_width = 800,
        .screen_height = 600,
        .health = 20,
        .hunger = 20,
        .selected_slot = 0,
        .xp_progress = 1.0,
        .xp_level = 30,
        .oxygen = 0.5,
        .is_underwater = true,
    };
    const count = generateHudVertices(state, &buf);
    try std.testing.expect(count <= 6);
}
