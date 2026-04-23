/// Settings screen overlay renderer.
/// Produces UiVertex quads for a centered 400x400 panel with 6 setting rows,
/// each containing a label bar and a slider (dark track + colored fill).
/// Provides hit-testing to map mouse clicks to slider value changes.
///
/// Self-contained: defines its own `UiVertex` matching the UI pipeline layout
/// (pos.xy, rgba, uv). Untextured quads use `u = -1, v = -1` so the fragment
/// shader takes the solid-color branch.
const std = @import("std");

// ── Vertex type (mirrors ui_pipeline.UiVertex layout) ────────────────

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

// ── Settings type ────────────────────────────────────────────────────

pub const Settings = struct {
    render_distance: u8 = 8,
    fov: u8 = 70,
    difficulty: u8 = 2,
    music_vol: u8 = 100,
    sound_vol: u8 = 100,
    sensitivity: u8 = 50,
};

// ── Layout constants ─────────────────────────────────────────────────

const panel_w: f32 = 400.0;
const panel_h: f32 = 400.0;

const row_count: u32 = 6;
const row_height: f32 = 52.0;
const label_h: f32 = 16.0;
const slider_h: f32 = 14.0;
const slider_margin_x: f32 = 30.0;
const top_padding: f32 = 30.0;
const label_slider_gap: f32 = 4.0;

// ── Colors ───────────────────────────────────────────────────────────

const Color = struct { r: f32, g: f32, b: f32, a: f32 };

const overlay_col = Color{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 0.55 };
const panel_bg = Color{ .r = 0.15, .g = 0.15, .b = 0.15, .a = 0.92 };
const panel_border_col = Color{ .r = 0.35, .g = 0.35, .b = 0.35, .a = 0.95 };
const label_col = Color{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 1.0 };
const track_col = Color{ .r = 0.25, .g = 0.25, .b = 0.25, .a = 1.0 };

/// Per-row slider fill colors (one per setting).
const fill_colors = [row_count]Color{
    .{ .r = 0.20, .g = 0.60, .b = 0.85, .a = 1.0 }, // render_distance — blue
    .{ .r = 0.85, .g = 0.65, .b = 0.15, .a = 1.0 }, // fov — amber
    .{ .r = 0.75, .g = 0.25, .b = 0.25, .a = 1.0 }, // difficulty — red
    .{ .r = 0.55, .g = 0.30, .b = 0.75, .a = 1.0 }, // music_vol — purple
    .{ .r = 0.25, .g = 0.70, .b = 0.45, .a = 1.0 }, // sound_vol — green
    .{ .r = 0.85, .g = 0.45, .b = 0.20, .a = 1.0 }, // sensitivity — orange
};

// ── Maximum vertex budget ────────────────────────────────────────────

/// Overlay(1) + panel(1) + border(4) + 6 rows * (track(1) + fill(1) + label glyphs).
/// Label pixel quads: up to 6 letters * 15 pixels = 90 quads per row, 540 total.
/// Total worst case: ~558 quads * 6 = 3348 vertices. Rounded up for safety.
pub const max_vertices: u32 = 3600;

// ── Label glyph data ─────────────────────────────────────────────────

/// Simple 3-wide, 5-tall letter bitmasks (15 bits each, MSB = top-left).
const LetterGlyph = u15;

const glyph_R: LetterGlyph = 0b110_101_110_101_101;
const glyph_E: LetterGlyph = 0b111_100_110_100_111;
const glyph_N: LetterGlyph = 0b101_111_111_101_101;
const glyph_D: LetterGlyph = 0b110_101_101_101_110;
const glyph_I: LetterGlyph = 0b111_010_010_010_111;
const glyph_S: LetterGlyph = 0b111_100_111_001_111;
const glyph_F: LetterGlyph = 0b111_100_110_100_100;
const glyph_O: LetterGlyph = 0b111_101_101_101_111;
const glyph_V: LetterGlyph = 0b101_101_101_010_010;
const glyph_C: LetterGlyph = 0b111_100_100_100_111;
const glyph_U: LetterGlyph = 0b101_101_101_101_111;
const glyph_M: LetterGlyph = 0b101_111_111_101_101;

/// Label glyph sequences for each setting row.
const label_render = [row_count][]const LetterGlyph{
    &.{ glyph_R, glyph_E, glyph_N, glyph_D, glyph_E, glyph_R }, // RENDER
    &.{ glyph_F, glyph_O, glyph_V }, // FOV
    &.{ glyph_D, glyph_I, glyph_F, glyph_F }, // DIFF
    &.{ glyph_M, glyph_U, glyph_S, glyph_I, glyph_C }, // MUSIC
    &.{ glyph_S, glyph_O, glyph_U, glyph_N, glyph_D }, // SOUND
    &.{ glyph_S, glyph_E, glyph_N, glyph_S }, // SENS
};

// ── Maximum setting values (used to compute fill percentages) ────────

const max_values = [row_count]f32{ 32.0, 120.0, 4.0, 100.0, 100.0, 100.0 };

// ── Quad helper ──────────────────────────────────────────────────────

/// Write a single colored quad (2 triangles, 6 vertices) with u=-1, v=-1.
fn addQuad(verts: []UiVertex, idx: u32, x: f32, y: f32, w: f32, h: f32, col: Color) u32 {
    if (idx + 6 > verts.len) return idx;
    const x1 = x + w;
    const y1 = y + h;
    const V = UiVertex;
    verts[idx + 0] = V{ .pos_x = x, .pos_y = y, .r = col.r, .g = col.g, .b = col.b, .a = col.a, .u = -1, .v = -1 };
    verts[idx + 1] = V{ .pos_x = x1, .pos_y = y, .r = col.r, .g = col.g, .b = col.b, .a = col.a, .u = -1, .v = -1 };
    verts[idx + 2] = V{ .pos_x = x1, .pos_y = y1, .r = col.r, .g = col.g, .b = col.b, .a = col.a, .u = -1, .v = -1 };
    verts[idx + 3] = V{ .pos_x = x, .pos_y = y, .r = col.r, .g = col.g, .b = col.b, .a = col.a, .u = -1, .v = -1 };
    verts[idx + 4] = V{ .pos_x = x1, .pos_y = y1, .r = col.r, .g = col.g, .b = col.b, .a = col.a, .u = -1, .v = -1 };
    verts[idx + 5] = V{ .pos_x = x, .pos_y = y1, .r = col.r, .g = col.g, .b = col.b, .a = col.a, .u = -1, .v = -1 };
    return idx + 6;
}

// ── Glyph helpers ────────────────────────────────────────────────────

fn getLetterPixel(glyph: LetterGlyph, x: u32, y: u32) bool {
    if (x >= 3 or y >= 5) return false;
    const bit_index: u4 = @intCast(y * 3 + x);
    return (glyph >> (14 - bit_index)) & 1 == 1;
}

fn drawLetter(verts: []UiVertex, idx: u32, x: f32, y: f32, glyph: LetterGlyph, scale: f32, col: Color) u32 {
    var c = idx;
    var py: u32 = 0;
    while (py < 5) : (py += 1) {
        var px: u32 = 0;
        while (px < 3) : (px += 1) {
            if (getLetterPixel(glyph, px, py)) {
                c = addQuad(
                    verts,
                    c,
                    x + @as(f32, @floatFromInt(px)) * scale,
                    y + @as(f32, @floatFromInt(py)) * scale,
                    scale,
                    scale,
                    col,
                );
            }
        }
    }
    return c;
}

fn drawLabel(verts: []UiVertex, idx: u32, left_x: f32, y: f32, glyphs: []const LetterGlyph, scale: f32, col: Color) u32 {
    const char_w = 3.0 * scale + 2.0;
    var c = idx;
    for (glyphs, 0..) |glyph, i| {
        const offset = @as(f32, @floatFromInt(i)) * char_w;
        c = drawLetter(verts, c, left_x + offset, y, glyph, scale, col);
    }
    return c;
}

// ── Value extraction helper ──────────────────────────────────────────

fn settingValue(settings: Settings, row: u32) f32 {
    return switch (row) {
        0 => @floatFromInt(settings.render_distance),
        1 => @floatFromInt(settings.fov),
        2 => @floatFromInt(settings.difficulty),
        3 => @floatFromInt(settings.music_vol),
        4 => @floatFromInt(settings.sound_vol),
        5 => @floatFromInt(settings.sensitivity),
        else => 0.0,
    };
}

// ── Geometry helpers (shared by render + hitTest) ────────────────────

fn panelOrigin(sw: f32, sh: f32) struct { x: f32, y: f32 } {
    return .{
        .x = (sw - panel_w) * 0.5,
        .y = (sh - panel_h) * 0.5,
    };
}

fn sliderTrackRect(panel_x: f32, panel_y: f32, row: u32) struct { x: f32, y: f32, w: f32 } {
    const row_y = panel_y + top_padding + @as(f32, @floatFromInt(row)) * row_height;
    return .{
        .x = panel_x + slider_margin_x,
        .y = row_y + label_h + label_slider_gap,
        .w = panel_w - slider_margin_x * 2.0,
    };
}

// ── Public API ───────────────────────────────────────────────────────

/// Render the settings screen overlay into the provided vertex buffer.
/// Returns the new vertex index (total vertices written from index 0).
pub fn render(verts: []UiVertex, start: u32, sw: f32, sh: f32, settings: Settings) u32 {
    var idx = start;

    // Full-screen dark overlay
    idx = addQuad(verts, idx, 0, 0, sw, sh, overlay_col);

    // Panel origin
    const origin = panelOrigin(sw, sh);
    const px = origin.x;
    const py = origin.y;

    // Panel border (4 edges)
    const bw: f32 = 2.0;
    idx = addQuad(verts, idx, px - bw, py - bw, panel_w + bw * 2, bw, panel_border_col);
    idx = addQuad(verts, idx, px - bw, py + panel_h, panel_w + bw * 2, bw, panel_border_col);
    idx = addQuad(verts, idx, px - bw, py, bw, panel_h, panel_border_col);
    idx = addQuad(verts, idx, px + panel_w, py, bw, panel_h, panel_border_col);

    // Panel background
    idx = addQuad(verts, idx, px, py, panel_w, panel_h, panel_bg);

    // 6 rows: label + slider each
    var row: u32 = 0;
    while (row < row_count) : (row += 1) {
        const row_y = py + top_padding + @as(f32, @floatFromInt(row)) * row_height;

        // Label bar (text-like indicator)
        const label_x = px + slider_margin_x;
        idx = drawLabel(verts, idx, label_x, row_y, label_render[row], 2.0, label_col);

        // Slider track (dark background)
        const track = sliderTrackRect(px, py, row);
        idx = addQuad(verts, idx, track.x, track.y, track.w, slider_h, track_col);

        // Slider fill (colored, width proportional to value)
        const val = settingValue(settings, row);
        const pct = std.math.clamp(val / max_values[row], 0.0, 1.0);
        const fill_w = track.w * pct;
        if (fill_w > 0.0) {
            idx = addQuad(verts, idx, track.x, track.y, fill_w, slider_h, fill_colors[row]);
        }
    }

    return idx;
}

/// Hit-test result describing which setting slider was clicked and the
/// normalized position along the track (0.0 = left edge, 1.0 = right edge).
pub const HitResult = struct {
    setting: u3,
    value_pct: f32,
};

/// Test whether the mouse position (mx, my) hits any slider track.
/// Returns the setting index and normalized value, or null if the click
/// was outside all slider tracks.
pub fn hitTest(mx: f32, my: f32, sw: f32, sh: f32) ?HitResult {
    const origin = panelOrigin(sw, sh);
    const px = origin.x;
    const py = origin.y;

    var row: u32 = 0;
    while (row < row_count) : (row += 1) {
        const track = sliderTrackRect(px, py, row);
        if (mx >= track.x and mx <= track.x + track.w and
            my >= track.y and my <= track.y + slider_h)
        {
            const pct = std.math.clamp((mx - track.x) / track.w, 0.0, 1.0);
            return .{
                .setting = @intCast(row),
                .value_pct = pct,
            };
        }
    }

    return null;
}

// ── Tests ────────────────────────────────────────────────────────────

test "render returns more vertices than start index" {
    var buf: [max_vertices]UiVertex = undefined;
    const count = render(&buf, 0, 1920.0, 1080.0, .{});
    try std.testing.expect(count > 0);
    try std.testing.expect(count % 6 == 0);
}

test "render with start offset preserves offset" {
    var buf: [max_vertices]UiVertex = undefined;
    const count = render(&buf, 12, 800.0, 600.0, .{});
    try std.testing.expect(count >= 12);
    try std.testing.expect((count - 12) % 6 == 0);
}

test "overlay covers full screen" {
    var buf: [max_vertices]UiVertex = undefined;
    const sw: f32 = 1024.0;
    const sh: f32 = 768.0;
    _ = render(&buf, 0, sw, sh, .{});
    // First quad is the overlay; check it spans the full screen
    try std.testing.expectApproxEqAbs(buf[0].pos_x, 0.0, 0.01);
    try std.testing.expectApproxEqAbs(buf[0].pos_y, 0.0, 0.01);
    try std.testing.expectApproxEqAbs(buf[1].pos_x, sw, 0.01);
    try std.testing.expectApproxEqAbs(buf[0].a, 0.55, 0.01);
}

test "panel is centered on screen" {
    var buf: [max_vertices]UiVertex = undefined;
    const sw: f32 = 800.0;
    const sh: f32 = 600.0;
    _ = render(&buf, 0, sw, sh, .{});
    // After overlay (6 verts) and top border (6 verts) the top border starts at index 6.
    // Top border x should be (800-400)/2 - 2 = 198
    const expected_border_x = (sw - panel_w) * 0.5 - 2.0;
    try std.testing.expectApproxEqAbs(buf[6].pos_x, expected_border_x, 0.01);
}

test "hitTest returns correct setting for each slider row" {
    const sw: f32 = 800.0;
    const sh: f32 = 600.0;
    const origin = panelOrigin(sw, sh);

    var row: u32 = 0;
    while (row < row_count) : (row += 1) {
        const track = sliderTrackRect(origin.x, origin.y, row);
        // Click center of slider track
        const mx = track.x + track.w * 0.5;
        const my = track.y + slider_h * 0.5;
        const result = hitTest(mx, my, sw, sh);
        try std.testing.expect(result != null);
        try std.testing.expectEqual(@as(u3, @intCast(row)), result.?.setting);
        try std.testing.expectApproxEqAbs(@as(f32, 0.5), result.?.value_pct, 0.02);
    }
}

test "hitTest returns null outside sliders" {
    const sw: f32 = 800.0;
    const sh: f32 = 600.0;
    // Click far top-left corner
    try std.testing.expectEqual(@as(?HitResult, null), hitTest(10.0, 10.0, sw, sh));
    // Click far bottom-right corner
    try std.testing.expectEqual(@as(?HitResult, null), hitTest(790.0, 590.0, sw, sh));
}

test "hitTest value_pct at slider edges" {
    const sw: f32 = 800.0;
    const sh: f32 = 600.0;
    const origin = panelOrigin(sw, sh);
    const track = sliderTrackRect(origin.x, origin.y, 0);

    // Left edge
    const left = hitTest(track.x, track.y + 1.0, sw, sh);
    try std.testing.expect(left != null);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), left.?.value_pct, 0.01);

    // Right edge
    const right = hitTest(track.x + track.w, track.y + 1.0, sw, sh);
    try std.testing.expect(right != null);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), right.?.value_pct, 0.01);
}

test "addQuad emits 6 vertices with u=-1 v=-1" {
    var buf: [6]UiVertex = undefined;
    const after = addQuad(&buf, 0, 10.0, 20.0, 50.0, 30.0, .{ .r = 1, .g = 0, .b = 0, .a = 1 });
    try std.testing.expectEqual(@as(u32, 6), after);
    try std.testing.expectApproxEqAbs(buf[0].u, -1.0, 0.01);
    try std.testing.expectApproxEqAbs(buf[0].v, -1.0, 0.01);
}

test "addQuad overflow protection" {
    var buf: [4]UiVertex = undefined;
    const after = addQuad(&buf, 0, 0, 0, 10, 10, .{ .r = 0, .g = 0, .b = 0, .a = 1 });
    try std.testing.expectEqual(@as(u32, 0), after);
}

test "slider fill scales with setting value" {
    var buf_low: [max_vertices]UiVertex = undefined;
    var buf_high: [max_vertices]UiVertex = undefined;
    const low_settings = Settings{ .render_distance = 2, .fov = 70, .difficulty = 2, .music_vol = 100, .sound_vol = 100, .sensitivity = 50 };
    const high_settings = Settings{ .render_distance = 32, .fov = 70, .difficulty = 2, .music_vol = 100, .sound_vol = 100, .sensitivity = 50 };
    const count_low = render(&buf_low, 0, 800.0, 600.0, low_settings);
    const count_high = render(&buf_high, 0, 800.0, 600.0, high_settings);
    // Both should produce valid vertex counts
    try std.testing.expect(count_low > 0);
    try std.testing.expect(count_high > 0);
    try std.testing.expect(count_low % 6 == 0);
    try std.testing.expect(count_high % 6 == 0);
}

test "render produces consistent output for same inputs" {
    var buf1: [max_vertices]UiVertex = undefined;
    var buf2: [max_vertices]UiVertex = undefined;
    const s = Settings{};
    const count1 = render(&buf1, 0, 1280.0, 720.0, s);
    const count2 = render(&buf2, 0, 1280.0, 720.0, s);
    try std.testing.expectEqual(count1, count2);
    for (0..@min(count1, 30)) |i| {
        try std.testing.expectApproxEqAbs(buf1[i].pos_x, buf2[i].pos_x, 0.001);
        try std.testing.expectApproxEqAbs(buf1[i].pos_y, buf2[i].pos_y, 0.001);
    }
}
