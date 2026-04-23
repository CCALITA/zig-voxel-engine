/// Entity health bar renderer.
/// Renders a small 40x4 pixel health bar above mobs. Red fill proportional to
/// HP percentage. Fades out over 3 seconds after last damage. Dark border.
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

const bar_width: f32 = 40.0;
const bar_height: f32 = 4.0;
const border_thickness: f32 = 1.0;

/// Duration in seconds the bar remains fully visible after damage.
const visible_duration: f32 = 3.0;

/// Maximum vertices: border (6) + background (6) + fill (6) = 18.
pub const max_vertices: u32 = 18;

// ── Colours ──────────────────────────────────────────────────────────

const Color = struct { r: f32, g: f32, b: f32, a: f32 };

const border_color = Color{ .r = 0.15, .g = 0.15, .b = 0.15, .a = 0.9 };
const bg_color = Color{ .r = 0.1, .g = 0.1, .b = 0.1, .a = 0.7 };
const fill_color = Color{ .r = 0.85, .g = 0.1, .b = 0.1, .a = 1.0 };

// ── Visibility ───────────────────────────────────────────────────────

/// Returns true when the bar should be displayed. The bar is visible for
/// `visible_duration` seconds (3 s) after the last damage event.
pub fn shouldShow(timer: f32) bool {
    return timer > 0.0 and timer <= visible_duration;
}

// ── Fade helpers ─────────────────────────────────────────────────────

/// Compute an opacity multiplier [0..1] based on the show timer.
/// Fully opaque while timer >= 1 s; fades linearly to zero during the
/// last second before the bar disappears.
fn fadeAlpha(timer: f32) f32 {
    if (timer <= 0.0) return 0.0;
    if (timer >= 1.0) return 1.0;
    return timer;
}

/// Return a copy of `col` with its alpha scaled by `alpha_mul`.
fn faded(col: Color, alpha_mul: f32) Color {
    return .{ .r = col.r, .g = col.g, .b = col.b, .a = col.a * alpha_mul };
}

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

/// Render a small entity health bar centred at (`screen_x`, `screen_y`).
/// The bar is drawn above the mob position (shifted up by `bar_height + border`).
/// `hp_pct` is the fill fraction 0..1. `show_timer` is the countdown in seconds
/// since the last damage; the bar fades during the final second.
/// Returns the final vertex index after all emitted quads.
pub fn render(
    verts: []UiVertex,
    start: u32,
    screen_x: f32,
    screen_y: f32,
    hp_pct: f32,
    show_timer: f32,
) u32 {
    var idx = start;

    if (!shouldShow(show_timer)) return idx;

    const hp = std.math.clamp(hp_pct, 0.0, 1.0);
    const alpha_mul = fadeAlpha(show_timer);

    // Centre the bar horizontally on screen_x, place it above screen_y.
    const bar_x = screen_x - bar_width * 0.5;
    const bar_y = screen_y - bar_height - border_thickness;

    const border_faded = faded(border_color, alpha_mul);
    const bg_faded = faded(bg_color, alpha_mul);
    const fill_faded = faded(fill_color, alpha_mul);

    // Border (slightly larger rectangle behind the bar).
    addQuad(
        verts,
        &idx,
        bar_x - border_thickness,
        bar_y - border_thickness,
        bar_width + border_thickness * 2.0,
        bar_height + border_thickness * 2.0,
        border_faded,
    );

    // Background (full bar width, dark).
    addQuad(verts, &idx, bar_x, bar_y, bar_width, bar_height, bg_faded);

    // HP fill (left-to-right, red).
    if (hp > 0.0) {
        addQuad(verts, &idx, bar_x, bar_y, bar_width * hp, bar_height, fill_faded);
    }

    return idx;
}

// ── Tests ────────────────────────────────────────────────────────────

const testing = std.testing;

test "shouldShow returns true within 3 seconds" {
    try testing.expect(shouldShow(3.0));
    try testing.expect(shouldShow(1.5));
    try testing.expect(shouldShow(0.01));
}

test "shouldShow returns false outside visible window" {
    try testing.expect(!shouldShow(0.0));
    try testing.expect(!shouldShow(-1.0));
    try testing.expect(!shouldShow(3.01));
    try testing.expect(!shouldShow(10.0));
}

test "render produces vertices in multiples of 6" {
    var buf: [max_vertices]UiVertex = undefined;
    const count = render(&buf, 0, 400.0, 300.0, 0.75, 2.0);
    try testing.expect(count > 0);
    try testing.expect(count % 6 == 0);
}

test "render returns start unchanged when timer expired" {
    var buf: [max_vertices]UiVertex = undefined;
    const count = render(&buf, 6, 400.0, 300.0, 1.0, 0.0);
    try testing.expectEqual(@as(u32, 6), count);
}

test "all vertices use untextured UV (-1, -1)" {
    var buf: [max_vertices]UiVertex = undefined;
    const count = render(&buf, 0, 400.0, 300.0, 0.5, 2.0);
    for (0..count) |i| {
        try testing.expectApproxEqAbs(@as(f32, -1.0), buf[i].u, 0.001);
        try testing.expectApproxEqAbs(@as(f32, -1.0), buf[i].v, 0.001);
    }
}

test "zero hp produces only border and background (no fill)" {
    var buf: [max_vertices]UiVertex = undefined;
    const count = render(&buf, 0, 400.0, 300.0, 0.0, 2.0);
    // Border (6) + Background (6) = 12, no fill quad.
    try testing.expectEqual(@as(u32, 12), count);
}

test "full hp produces border, background, and fill" {
    var buf: [max_vertices]UiVertex = undefined;
    const count = render(&buf, 0, 400.0, 300.0, 1.0, 2.0);
    // Border (6) + Background (6) + Fill (6) = 18.
    try testing.expectEqual(@as(u32, 18), count);
}

test "bar is horizontally centred on screen_x" {
    var buf: [max_vertices]UiVertex = undefined;
    const sx: f32 = 500.0;
    _ = render(&buf, 0, sx, 300.0, 1.0, 2.0);
    // Second quad (index 6) is the background; its left edge = screen_x - bar_width/2.
    const bar_left = buf[6].pos_x;
    const expected_left = sx - bar_width * 0.5;
    try testing.expectApproxEqAbs(expected_left, bar_left, 0.01);
}

test "fade reduces alpha during last second" {
    var buf_full: [max_vertices]UiVertex = undefined;
    _ = render(&buf_full, 0, 400.0, 300.0, 1.0, 2.0);

    var buf_fading: [max_vertices]UiVertex = undefined;
    _ = render(&buf_fading, 0, 400.0, 300.0, 1.0, 0.5);

    // The border quad (vertex 0) should have lower alpha when fading.
    try testing.expect(buf_fading[0].a < buf_full[0].a);
}

test "hp_pct is clamped to 0..1" {
    var buf_over: [max_vertices]UiVertex = undefined;
    const count_over = render(&buf_over, 0, 400.0, 300.0, 2.0, 2.0);

    var buf_full: [max_vertices]UiVertex = undefined;
    const count_full = render(&buf_full, 0, 400.0, 300.0, 1.0, 2.0);

    try testing.expectEqual(count_over, count_full);
}

test "buffer overflow protection" {
    var small: [6]UiVertex = undefined;
    const count = render(&small, 0, 400.0, 300.0, 1.0, 2.0);
    try testing.expect(count <= 6);
}

test "render preserves start offset" {
    var buf: [max_vertices + 12]UiVertex = undefined;
    const offset: u32 = 12;
    const count = render(&buf, offset, 400.0, 300.0, 0.5, 2.0);
    try testing.expect(count >= offset);
    try testing.expect((count - offset) % 6 == 0);
}
