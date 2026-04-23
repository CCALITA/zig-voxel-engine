/// Minimap HUD renderer.
/// Renders a 100x100 pixel minimap in the top-right corner of the screen.
/// Each of the 64x64 minimap pixels is drawn as a colored quad scaled to fit.
/// A white player dot sits at the center, a north indicator shows orientation,
/// and a dark border frames the map. All quads are untextured (u=-1, v=-1).
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

pub const MinimapData = struct {
    pixels: [64 * 64][3]u8 = undefined,
    center_x: i32 = 0,
    center_z: i32 = 0,
    player_facing: f32 = 0,
};

// ── Layout constants ─────────────────────────────────────────────────

const map_size: f32 = 100.0;
const map_res: u32 = 64;
const margin: f32 = 8.0;
const border_thickness: f32 = 2.0;
const pixel_size: f32 = map_size / @as(f32, @floatFromInt(map_res));
const player_dot_size: f32 = 4.0;
const north_indicator_len: f32 = 6.0;
const north_indicator_width: f32 = 2.0;

/// Conservative upper bound: border (4 quads) + bg (1) + 64*64 pixels + player dot (1) + north (1).
pub const max_vertices = (4 + 1 + map_res * map_res + 1 + 1) * 6;

// ── Colors ───────────────────────────────────────────────────────────

const Color = struct { r: f32, g: f32, b: f32, a: f32 };

const border_color = Color{ .r = 0.12, .g = 0.12, .b = 0.12, .a = 0.9 };
const bg_color = Color{ .r = 0.15, .g = 0.15, .b = 0.15, .a = 0.75 };
const player_color = Color{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 1.0 };
const north_color = Color{ .r = 1.0, .g = 0.3, .b = 0.3, .a = 1.0 };

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

// ── Pixel color helper ──────────────────────────────────────────────

fn pixelColor(rgb: [3]u8) Color {
    return Color{
        .r = @as(f32, @floatFromInt(rgb[0])) / 255.0,
        .g = @as(f32, @floatFromInt(rgb[1])) / 255.0,
        .b = @as(f32, @floatFromInt(rgb[2])) / 255.0,
        .a = 1.0,
    };
}

// ── North indicator position ────────────────────────────────────────

fn northIndicatorOffset(facing: f32) struct { dx: f32, dy: f32 } {
    // facing is radians; 0 = north (+Z), rotates clockwise.
    // North indicator sits on the edge of the map in the direction the
    // player considers "north" (opposite of facing so the map rotates
    // around the player).
    const radius = map_size * 0.5 - north_indicator_len;
    return .{
        .dx = -@sin(facing) * radius,
        .dy = -@cos(facing) * radius,
    };
}

// ── Main render ──────────────────────────────────────────────────────

pub fn render(verts: []UiVertex, start: u32, sw: f32, sh: f32, data: MinimapData) u32 {
    _ = sh;
    var idx = start;

    const map_x = sw - map_size - margin;
    const map_y = margin;

    // ── Dark border (4 edge strips) ──────────────────────────────
    // Top
    addQuad(verts, &idx, map_x - border_thickness, map_y - border_thickness, map_size + border_thickness * 2.0, border_thickness, border_color);
    // Bottom
    addQuad(verts, &idx, map_x - border_thickness, map_y + map_size, map_size + border_thickness * 2.0, border_thickness, border_color);
    // Left
    addQuad(verts, &idx, map_x - border_thickness, map_y, border_thickness, map_size, border_color);
    // Right
    addQuad(verts, &idx, map_x + map_size, map_y, border_thickness, map_size, border_color);

    // ── Background fill ──────────────────────────────────────────
    addQuad(verts, &idx, map_x, map_y, map_size, map_size, bg_color);

    // ── Minimap pixel grid ───────────────────────────────────────
    for (0..map_res) |row| {
        const fy: f32 = @floatFromInt(row);
        for (0..map_res) |col| {
            const fx: f32 = @floatFromInt(col);
            const pi = row * map_res + col;
            const rgb = data.pixels[pi];
            // Skip pure black pixels (treat as empty/transparent)
            if (rgb[0] == 0 and rgb[1] == 0 and rgb[2] == 0) continue;
            addQuad(verts, &idx, map_x + fx * pixel_size, map_y + fy * pixel_size, pixel_size, pixel_size, pixelColor(rgb));
        }
    }

    // ── Player dot (white, centered) ─────────────────────────────
    const dot_x = map_x + (map_size - player_dot_size) * 0.5;
    const dot_y = map_y + (map_size - player_dot_size) * 0.5;
    addQuad(verts, &idx, dot_x, dot_y, player_dot_size, player_dot_size, player_color);

    // ── North indicator (red tick on map edge) ───────────────────
    const n = northIndicatorOffset(data.player_facing);
    const center_x = map_x + map_size * 0.5;
    const center_y = map_y + map_size * 0.5;
    addQuad(verts, &idx, center_x + n.dx - north_indicator_width * 0.5, center_y + n.dy - north_indicator_len * 0.5, north_indicator_width, north_indicator_len, north_color);

    return idx;
}

// ── Tests ────────────────────────────────────────────────────────────

const testing = std.testing;

fn emptyData() MinimapData {
    return MinimapData{
        .pixels = std.mem.zeroes([64 * 64][3]u8),
        .center_x = 0,
        .center_z = 0,
        .player_facing = 0,
    };
}

test "render returns vertices in multiples of 6" {
    var buf: [max_vertices]UiVertex = undefined;
    const count = render(&buf, 0, 800.0, 600.0, emptyData());
    try testing.expect(count > 0);
    try testing.expect(count % 6 == 0);
}

test "render preserves start offset" {
    var buf: [max_vertices]UiVertex = undefined;
    const offset: u32 = 18;
    const count = render(&buf, offset, 800.0, 600.0, emptyData());
    try testing.expect(count >= offset);
    try testing.expect((count - offset) % 6 == 0);
}

test "all vertices have u=-1 and v=-1" {
    var buf: [max_vertices]UiVertex = undefined;
    const count = render(&buf, 0, 1920.0, 1080.0, emptyData());
    for (0..count) |i| {
        try testing.expectApproxEqAbs(@as(f32, -1.0), buf[i].u, 0.001);
        try testing.expectApproxEqAbs(@as(f32, -1.0), buf[i].v, 0.001);
    }
}

test "map is positioned in top-right corner" {
    var buf: [max_vertices]UiVertex = undefined;
    const sw: f32 = 1920.0;
    _ = render(&buf, 0, sw, 1080.0, emptyData());
    // First quad is the top border strip. Its right edge should be near sw - margin.
    // The border quad starts at map_x - border_thickness with width map_size + 2*border.
    // So right edge = (sw - map_size - margin - border_thickness) + (map_size + 2*border_thickness)
    //              = sw - margin + border_thickness
    const expected_right = sw - margin + border_thickness;
    // Vertex [1] is top-right of the first quad
    try testing.expectApproxEqAbs(expected_right, buf[1].pos_x, 0.01);
}

test "non-black pixels produce extra quads" {
    var buf_empty: [max_vertices]UiVertex = undefined;
    const count_empty = render(&buf_empty, 0, 800.0, 600.0, emptyData());

    var data = emptyData();
    data.pixels[0] = .{ 255, 0, 0 };
    data.pixels[100] = .{ 0, 255, 0 };
    data.pixels[200] = .{ 0, 0, 255 };

    var buf_some: [max_vertices]UiVertex = undefined;
    const count_some = render(&buf_some, 0, 800.0, 600.0, data);

    // 3 colored pixels => 3 extra quads => 18 extra vertices
    try testing.expectEqual(count_empty + 18, count_some);
}

test "player dot is white and centered on the map" {
    var buf: [max_vertices]UiVertex = undefined;
    const sw: f32 = 800.0;
    const count = render(&buf, 0, sw, 600.0, emptyData());

    // With all-zero pixels, layout is: 4 border + 1 bg + 0 pixel + 1 player + 1 north = 7 quads = 42 verts
    // Player dot is the 6th quad (index 30..35)
    try testing.expect(count >= 42);
    const dot_start: u32 = 30;
    // Player dot should be white
    try testing.expectApproxEqAbs(@as(f32, 1.0), buf[dot_start].r, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 1.0), buf[dot_start].g, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 1.0), buf[dot_start].b, 0.001);

    // Check centering: dot top-left x should be map_x + (map_size - dot_size) / 2
    const map_x = sw - map_size - margin;
    const expected_dot_x = map_x + (map_size - player_dot_size) * 0.5;
    try testing.expectApproxEqAbs(expected_dot_x, buf[dot_start].pos_x, 0.01);
}

test "north indicator is red" {
    var buf: [max_vertices]UiVertex = undefined;
    const count = render(&buf, 0, 800.0, 600.0, emptyData());

    // North indicator is the last quad
    const north_start = count - 6;
    try testing.expectApproxEqAbs(north_color.r, buf[north_start].r, 0.001);
    try testing.expectApproxEqAbs(north_color.g, buf[north_start].g, 0.001);
    try testing.expectApproxEqAbs(north_color.b, buf[north_start].b, 0.001);
}

test "buffer overflow protection" {
    var buf: [6]UiVertex = undefined;
    const count = render(&buf, 0, 800.0, 600.0, emptyData());
    try testing.expect(count <= 6);
}

test "pixelColor converts 255 to 1.0" {
    const col = pixelColor(.{ 255, 128, 0 });
    try testing.expectApproxEqAbs(@as(f32, 1.0), col.r, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 128.0 / 255.0), col.g, 0.005);
    try testing.expectApproxEqAbs(@as(f32, 0.0), col.b, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 1.0), col.a, 0.001);
}

test "north indicator moves with player facing" {
    var buf_north: [max_vertices]UiVertex = undefined;
    var data_north = emptyData();
    data_north.player_facing = 0;
    const count_n = render(&buf_north, 0, 800.0, 600.0, data_north);

    var buf_east: [max_vertices]UiVertex = undefined;
    var data_east = emptyData();
    data_east.player_facing = std.math.pi / 2.0;
    const count_e = render(&buf_east, 0, 800.0, 600.0, data_east);

    // Both render the same number of quads
    try testing.expectEqual(count_n, count_e);

    // But the north indicator position differs
    const n_x = buf_north[count_n - 6].pos_x;
    const e_x = buf_east[count_e - 6].pos_x;
    try testing.expect(@abs(n_x - e_x) > 1.0);
}

test "addQuad guards against buffer overflow" {
    var buf: [3]UiVertex = undefined;
    var idx: u32 = 0;
    addQuad(&buf, &idx, 0, 0, 10, 10, player_color);
    try testing.expectEqual(@as(u32, 0), idx);
}

test "northIndicatorOffset at facing=0 points upward" {
    const n = northIndicatorOffset(0);
    // At facing=0 (north), dx should be ~0, dy should be negative (upward)
    try testing.expectApproxEqAbs(@as(f32, 0.0), n.dx, 0.01);
    try testing.expect(n.dy < 0);
}
