/// Boss bar HUD renderer.
/// Renders a top-center health bar for boss mobs (dragon, wither, elder guardian).
/// Bar is 300x12 pixels, coloured by boss type, with HP fill left-to-right.
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

pub const BossType = enum { dragon, wither, elder_guardian };

pub const BossBarData = struct {
    boss_type: BossType,
    hp_pct: f32,
    name_indicator: u8 = 0,
};

// ── Layout constants ─────────────────────────────────────────────────

const bar_width: f32 = 300.0;
const bar_height: f32 = 12.0;
const bar_top_margin: f32 = 16.0;
const border_thickness: f32 = 1.0;

pub const max_vertices: u32 = 256;

// ── Colours ──────────────────────────────────────────────────────────

const Color = struct { r: f32, g: f32, b: f32, a: f32 };

const bg_color = Color{ .r = 0.1, .g = 0.1, .b = 0.1, .a = 0.7 };
const border_color = Color{ .r = 0.2, .g = 0.2, .b = 0.2, .a = 0.9 };

fn bossColor(boss_type: BossType) Color {
    return switch (boss_type) {
        .dragon, .wither => Color{ .r = 0.6, .g = 0.2, .b = 0.8, .a = 1.0 },
        .elder_guardian => Color{ .r = 0.2, .g = 0.8, .b = 0.8, .a = 1.0 },
    };
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

/// Render a boss health bar centred at the top of the screen.
/// Returns the final vertex index after all emitted quads.
pub fn render(verts: []UiVertex, start: u32, sw: f32, sh: f32, data: BossBarData) u32 {
    _ = sh;
    var idx = start;

    const hp = std.math.clamp(data.hp_pct, 0.0, 1.0);
    const bar_x = (sw - bar_width) * 0.5;
    const bar_y = bar_top_margin;

    // Border (slightly larger rectangle behind the bar)
    addQuad(verts, &idx, bar_x - border_thickness, bar_y - border_thickness, bar_width + border_thickness * 2.0, bar_height + border_thickness * 2.0, border_color);

    // Background (full bar width, dark)
    addQuad(verts, &idx, bar_x, bar_y, bar_width, bar_height, bg_color);

    // HP fill (left-to-right, coloured by boss type)
    if (hp > 0.0) {
        addQuad(verts, &idx, bar_x, bar_y, bar_width * hp, bar_height, bossColor(data.boss_type));
    }

    return idx;
}

// ── Tests ────────────────────────────────────────────────────────────

test "render produces vertices in multiples of 6" {
    var buf: [max_vertices]UiVertex = undefined;
    const count = render(&buf, 0, 800.0, 600.0, .{ .boss_type = .dragon, .hp_pct = 0.75 });
    try std.testing.expect(count > 0);
    try std.testing.expect(count % 6 == 0);
}

test "render preserves start offset" {
    var buf: [max_vertices]UiVertex = undefined;
    const offset: u32 = 18;
    const count = render(&buf, offset, 800.0, 600.0, .{ .boss_type = .wither, .hp_pct = 1.0 });
    try std.testing.expect(count >= offset);
    try std.testing.expect((count - offset) % 6 == 0);
}

test "all vertices have u=-1 and v=-1" {
    var buf: [max_vertices]UiVertex = undefined;
    const count = render(&buf, 0, 1920.0, 1080.0, .{ .boss_type = .elder_guardian, .hp_pct = 0.5 });
    for (0..count) |i| {
        try std.testing.expectApproxEqAbs(@as(f32, -1.0), buf[i].u, 0.001);
        try std.testing.expectApproxEqAbs(@as(f32, -1.0), buf[i].v, 0.001);
    }
}

test "bar is horizontally centred on screen" {
    var buf: [max_vertices]UiVertex = undefined;
    const sw: f32 = 1000.0;
    _ = render(&buf, 0, sw, 600.0, .{ .boss_type = .dragon, .hp_pct = 1.0 });
    // First quad is the border; second quad (index 6) is the bg starting at bar_x.
    const bar_left = buf[6].pos_x;
    const expected_left = (sw - bar_width) * 0.5;
    try std.testing.expectApproxEqAbs(expected_left, bar_left, 0.01);
}

test "zero hp produces only border and background quads" {
    var buf: [max_vertices]UiVertex = undefined;
    const count = render(&buf, 0, 800.0, 600.0, .{ .boss_type = .wither, .hp_pct = 0.0 });
    // Border (6) + Background (6) = 12 vertices, no fill quad
    try std.testing.expectEqual(@as(u32, 12), count);
}

test "full hp produces border, background, and fill quads" {
    var buf: [max_vertices]UiVertex = undefined;
    const count = render(&buf, 0, 800.0, 600.0, .{ .boss_type = .dragon, .hp_pct = 1.0 });
    // Border (6) + Background (6) + Fill (6) = 18 vertices
    try std.testing.expectEqual(@as(u32, 18), count);
}

test "dragon and wither share purple colour" {
    var buf_d: [max_vertices]UiVertex = undefined;
    const count_d = render(&buf_d, 0, 800.0, 600.0, .{ .boss_type = .dragon, .hp_pct = 1.0 });

    var buf_w: [max_vertices]UiVertex = undefined;
    const count_w = render(&buf_w, 0, 800.0, 600.0, .{ .boss_type = .wither, .hp_pct = 1.0 });

    try std.testing.expectEqual(count_d, count_w);
    // Fill quad starts at vertex 12; check the colour matches
    try std.testing.expectApproxEqAbs(buf_d[12].r, buf_w[12].r, 0.001);
    try std.testing.expectApproxEqAbs(buf_d[12].g, buf_w[12].g, 0.001);
    try std.testing.expectApproxEqAbs(buf_d[12].b, buf_w[12].b, 0.001);
}

test "guardian uses cyan colour distinct from dragon purple" {
    var buf_d: [max_vertices]UiVertex = undefined;
    _ = render(&buf_d, 0, 800.0, 600.0, .{ .boss_type = .dragon, .hp_pct = 1.0 });

    var buf_g: [max_vertices]UiVertex = undefined;
    _ = render(&buf_g, 0, 800.0, 600.0, .{ .boss_type = .elder_guardian, .hp_pct = 1.0 });

    // Fill quad vertex 12: guardian colour should differ from dragon
    const dragon_r = buf_d[12].r;
    const guardian_r = buf_g[12].r;
    try std.testing.expect(@abs(dragon_r - guardian_r) > 0.1);
}

test "hp_pct is clamped to 0..1" {
    var buf_over: [max_vertices]UiVertex = undefined;
    const count_over = render(&buf_over, 0, 800.0, 600.0, .{ .boss_type = .dragon, .hp_pct = 2.0 });

    var buf_full: [max_vertices]UiVertex = undefined;
    const count_full = render(&buf_full, 0, 800.0, 600.0, .{ .boss_type = .dragon, .hp_pct = 1.0 });

    // Over-1.0 should clamp to 1.0 and produce the same result
    try std.testing.expectEqual(count_over, count_full);
}

test "buffer overflow protection" {
    var small: [6]UiVertex = undefined;
    const count = render(&small, 0, 800.0, 600.0, .{ .boss_type = .dragon, .hp_pct = 1.0 });
    try std.testing.expect(count <= 6);
}

test "default name_indicator is zero" {
    const data = BossBarData{ .boss_type = .dragon, .hp_pct = 1.0 };
    try std.testing.expectEqual(@as(u8, 0), data.name_indicator);
}
