/// Entity nameplate renderer.
/// Draws a dark semi-transparent background rectangle scaled by the entity's
/// name length, with a white text-placeholder bar centred inside. The nameplate
/// fades out as the entity moves further away: alpha = 1.0 - distance / 32.0.
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

pub const NameplateData = struct {
    screen_x: f32,
    screen_y: f32,
    name_len: u8,
    distance: f32,
};

// ── Layout constants ─────────────────────────────────────────────────

/// Pixels per character used to scale the background width.
const char_width: f32 = 6.0;

/// Horizontal padding on each side of the text bar.
const pad_x: f32 = 4.0;

/// Vertical padding above and below the text bar.
const pad_y: f32 = 3.0;

/// Height of the white text-placeholder bar.
const text_bar_height: f32 = 8.0;

/// Distance at which the nameplate is fully transparent.
const max_visible_distance: f32 = 32.0;

pub const max_vertices: u32 = 12;

// ── Colours ──────────────────────────────────────────────────────────

const Color = struct { r: f32, g: f32, b: f32, a: f32 };

const bg_color = Color{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 0.5 };
const text_color = Color{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 1.0 };

fn applyAlpha(col: Color, alpha: f32) Color {
    return .{ .r = col.r, .g = col.g, .b = col.b, .a = col.a * alpha };
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

// ── Alpha from distance ──────────────────────────────────────────────

fn distanceAlpha(distance: f32) f32 {
    const d = std.math.clamp(distance, 0.0, max_visible_distance);
    return 1.0 - d / max_visible_distance;
}

// ── Public render entry point ────────────────────────────────────────

/// Render an entity nameplate centred at the given screen position.
/// Returns the final vertex index after all emitted quads.
pub fn render(verts: []UiVertex, start: u32, data: NameplateData) u32 {
    var idx = start;

    const alpha = distanceAlpha(data.distance);
    if (alpha <= 0.0) return idx;

    const name_len_f: f32 = @floatFromInt(data.name_len);
    const text_width = name_len_f * char_width;
    const bg_w = text_width + pad_x * 2.0;
    const bg_h = text_bar_height + pad_y * 2.0;

    // Centre the background on the screen position.
    const bg_x = data.screen_x - bg_w * 0.5;
    const bg_y = data.screen_y - bg_h * 0.5;

    // Dark background rectangle.
    addQuad(verts, &idx, bg_x, bg_y, bg_w, bg_h, applyAlpha(bg_color, alpha));

    // White text-placeholder bar inside the background.
    const bar_x = bg_x + pad_x;
    const bar_y = bg_y + pad_y;
    addQuad(verts, &idx, bar_x, bar_y, text_width, text_bar_height, applyAlpha(text_color, alpha));

    return idx;
}

// ── Tests ────────────────────────────────────────────────────────────

test "render produces vertices in multiples of 6" {
    var buf: [max_vertices]UiVertex = undefined;
    const count = render(&buf, 0, .{ .screen_x = 400.0, .screen_y = 300.0, .name_len = 5, .distance = 10.0 });
    try std.testing.expect(count > 0);
    try std.testing.expect(count % 6 == 0);
}

test "render preserves start offset" {
    var buf: [24]UiVertex = undefined;
    const offset: u32 = 6;
    const count = render(&buf, offset, .{ .screen_x = 400.0, .screen_y = 300.0, .name_len = 8, .distance = 5.0 });
    try std.testing.expect(count >= offset);
    try std.testing.expect((count - offset) % 6 == 0);
}

test "all vertices have u=-1 and v=-1" {
    var buf: [max_vertices]UiVertex = undefined;
    const count = render(&buf, 0, .{ .screen_x = 200.0, .screen_y = 100.0, .name_len = 10, .distance = 0.0 });
    for (0..count) |i| {
        try std.testing.expectApproxEqAbs(@as(f32, -1.0), buf[i].u, 0.001);
        try std.testing.expectApproxEqAbs(@as(f32, -1.0), buf[i].v, 0.001);
    }
}

test "nameplate at max distance produces no vertices" {
    var buf: [max_vertices]UiVertex = undefined;
    const count = render(&buf, 0, .{ .screen_x = 400.0, .screen_y = 300.0, .name_len = 5, .distance = 32.0 });
    try std.testing.expectEqual(@as(u32, 0), count);
}

test "nameplate beyond max distance produces no vertices" {
    var buf: [max_vertices]UiVertex = undefined;
    const count = render(&buf, 0, .{ .screen_x = 400.0, .screen_y = 300.0, .name_len = 5, .distance = 50.0 });
    try std.testing.expectEqual(@as(u32, 0), count);
}

test "close distance produces higher alpha than far distance" {
    var buf_close: [max_vertices]UiVertex = undefined;
    _ = render(&buf_close, 0, .{ .screen_x = 400.0, .screen_y = 300.0, .name_len = 5, .distance = 4.0 });

    var buf_far: [max_vertices]UiVertex = undefined;
    _ = render(&buf_far, 0, .{ .screen_x = 400.0, .screen_y = 300.0, .name_len = 5, .distance = 24.0 });

    try std.testing.expect(buf_close[0].a > buf_far[0].a);
}

test "longer name produces wider background" {
    var buf_short: [max_vertices]UiVertex = undefined;
    _ = render(&buf_short, 0, .{ .screen_x = 400.0, .screen_y = 300.0, .name_len = 3, .distance = 0.0 });

    var buf_long: [max_vertices]UiVertex = undefined;
    _ = render(&buf_long, 0, .{ .screen_x = 400.0, .screen_y = 300.0, .name_len = 12, .distance = 0.0 });

    // Background quad: vertex 0 is top-left, vertex 1 is top-right.
    const short_w = buf_short[1].pos_x - buf_short[0].pos_x;
    const long_w = buf_long[1].pos_x - buf_long[0].pos_x;
    try std.testing.expect(long_w > short_w);
}

test "background is centred on screen_x" {
    var buf: [max_vertices]UiVertex = undefined;
    const sx: f32 = 500.0;
    _ = render(&buf, 0, .{ .screen_x = sx, .screen_y = 300.0, .name_len = 6, .distance = 0.0 });

    // Vertex 0 is top-left, vertex 1 is top-right of background quad.
    const left = buf[0].pos_x;
    const right = buf[1].pos_x;
    const centre = (left + right) * 0.5;
    try std.testing.expectApproxEqAbs(sx, centre, 0.01);
}

test "zero distance gives full alpha (1.0 scaled by base)" {
    const alpha = distanceAlpha(0.0);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), alpha, 0.001);
}

test "buffer overflow protection" {
    var small: [6]UiVertex = undefined;
    const count = render(&small, 0, .{ .screen_x = 400.0, .screen_y = 300.0, .name_len = 5, .distance = 0.0 });
    // Only room for 1 quad (bg), text bar is skipped.
    try std.testing.expect(count <= 6);
}

test "render emits bg and text bar quads at zero distance" {
    var buf: [max_vertices]UiVertex = undefined;
    const count = render(&buf, 0, .{ .screen_x = 400.0, .screen_y = 300.0, .name_len = 5, .distance = 0.0 });
    // Background (6) + text bar (6) = 12 vertices.
    try std.testing.expectEqual(@as(u32, 12), count);
}
