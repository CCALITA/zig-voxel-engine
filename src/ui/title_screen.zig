/// Title screen renderer.
/// Produces UiVertex quads for a dark-blue background gradient, a centered logo
/// area composed of pixel-art blocks, four vertically stacked menu buttons
/// (Singleplayer, Multiplayer, Options, Quit), and a version text indicator in
/// the bottom-left corner. Also provides hit-testing for mouse clicks.
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

// ── Button enum ──────────────────────────────────────────────────────

pub const Button = enum { singleplayer, multiplayer, options, quit };

// ── Layout constants ─────────────────────────────────────────────────

const btn_w: f32 = 200.0;
const btn_h: f32 = 36.0;
const btn_gap: f32 = 10.0;

/// Total height of the 4-button stack including gaps.
const btn_stack_h: f32 = btn_h * 4.0 + btn_gap * 3.0;

/// Logo area dimensions.
const logo_w: f32 = 180.0;
const logo_h: f32 = 60.0;

/// Gap between logo bottom and first button top.
const logo_btn_gap: f32 = 30.0;

/// Version text position offset from bottom-left.
const version_x: f32 = 8.0;
const version_y_offset: f32 = 20.0;

// ── Colors ───────────────────────────────────────────────────────────

const Color = struct { r: f32, g: f32, b: f32, a: f32 };

const bg_top = Color{ .r = 0.02, .g = 0.02, .b = 0.12, .a = 1.0 };
const bg_bot = Color{ .r = 0.05, .g = 0.05, .b = 0.22, .a = 1.0 };

const singleplayer_col = Color{ .r = 0.18, .g = 0.55, .b = 0.22, .a = 1.0 };
const multiplayer_col = Color{ .r = 0.35, .g = 0.35, .b = 0.35, .a = 0.6 };
const options_col = Color{ .r = 0.18, .g = 0.30, .b = 0.65, .a = 1.0 };
const quit_col = Color{ .r = 0.65, .g = 0.15, .b = 0.15, .a = 1.0 };

const label_col = Color{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 1.0 };
const version_col = Color{ .r = 0.6, .g = 0.6, .b = 0.6, .a = 0.8 };

// Logo block colors (pixel art palette).
const logo_grass = Color{ .r = 0.30, .g = 0.70, .b = 0.20, .a = 1.0 };
const logo_dirt = Color{ .r = 0.55, .g = 0.35, .b = 0.20, .a = 1.0 };
const logo_stone = Color{ .r = 0.50, .g = 0.50, .b = 0.50, .a = 1.0 };
const logo_water = Color{ .r = 0.15, .g = 0.40, .b = 0.80, .a = 0.9 };

// ── Maximum vertex budget ────────────────────────────────────────────

/// Background gradient (6 verts) + logo blocks (~20*6) + 4 buttons (4*6)
/// + 4 button labels (~22 glyphs * ~9 pixels * 6) + version (~6 glyphs * ~7 * 6)
/// ≈ ~1700 verts typical. Budget rounded up generously.
pub const max_vertices: u32 = 4096;

// ── Pixel-art glyph system ───────────────────────────────────────────

/// Simple 3-wide, 5-tall letter bitmasks (15 bits each, MSB = top-left).
const LetterGlyph = u15;

fn getLetterPixel(glyph: LetterGlyph, x: u32, y: u32) bool {
    if (x >= 3 or y >= 5) return false;
    const bit_index: u4 = @intCast(y * 3 + x);
    return (glyph >> (14 - bit_index)) & 1 == 1;
}

// Letter definitions.
const letter_A: LetterGlyph = 0b010_101_111_101_101;
const letter_C: LetterGlyph = 0b011_100_100_100_011;
const letter_E: LetterGlyph = 0b111_100_110_100_111;
const letter_G: LetterGlyph = 0b011_100_101_101_011;
const letter_I: LetterGlyph = 0b111_010_010_010_111;
const letter_L: LetterGlyph = 0b100_100_100_100_111;
const letter_M: LetterGlyph = 0b101_111_111_101_101;
const letter_N: LetterGlyph = 0b101_111_111_111_101;
const letter_O: LetterGlyph = 0b010_101_101_101_010;
const letter_P: LetterGlyph = 0b110_101_110_100_100;
const letter_Q: LetterGlyph = 0b010_101_101_111_011;
const letter_R: LetterGlyph = 0b110_101_110_101_101;
const letter_S: LetterGlyph = 0b111_100_111_001_111;
const letter_T: LetterGlyph = 0b111_010_010_010_010;
const letter_U: LetterGlyph = 0b101_101_101_101_111;
const letter_Y: LetterGlyph = 0b101_101_010_010_010;

// Button label glyph arrays.
const sp_glyphs = [_]LetterGlyph{ letter_S, letter_I, letter_N, letter_G, letter_L, letter_E };
const mp_glyphs = [_]LetterGlyph{ letter_M, letter_U, letter_L, letter_T, letter_I };
const opt_glyphs = [_]LetterGlyph{ letter_O, letter_P, letter_T, letter_I, letter_O, letter_N, letter_S };
const quit_glyphs = [_]LetterGlyph{ letter_Q, letter_U, letter_I, letter_T };

// Version string: "v0.1.0"
const letter_V: LetterGlyph = 0b101_101_101_101_010;
const digit_0: LetterGlyph = 0b111_101_101_101_111;
const digit_1: LetterGlyph = 0b010_110_010_010_111;
const dot_glyph: LetterGlyph = 0b000_000_000_000_010;

const version_glyphs = [_]LetterGlyph{ letter_V, digit_0, dot_glyph, digit_1, dot_glyph, digit_0 };

// ── Logo pixel art: 3x3 block grid ──────────────────────────────────

/// 6x4 grid of colored blocks representing a stylized landscape.
const logo_grid_w: u32 = 6;
const logo_grid_h: u32 = 4;

/// Color index for each cell in the logo grid (row-major).
/// 0 = empty, 1 = grass, 2 = dirt, 3 = stone, 4 = water.
const logo_grid = [logo_grid_h][logo_grid_w]u8{
    .{ 0, 1, 1, 1, 1, 0 },
    .{ 1, 2, 2, 2, 2, 1 },
    .{ 3, 3, 2, 2, 3, 3 },
    .{ 4, 3, 3, 3, 3, 4 },
};

fn logoColor(idx: u8) ?Color {
    return switch (idx) {
        1 => logo_grass,
        2 => logo_dirt,
        3 => logo_stone,
        4 => logo_water,
        else => null,
    };
}

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

/// Write a gradient quad (top color to bottom color).
fn addGradientQuad(verts: []UiVertex, idx: u32, x: f32, y: f32, w: f32, h: f32, top: Color, bot: Color) u32 {
    if (idx + 6 > verts.len) return idx;
    const x1 = x + w;
    const y1 = y + h;
    const V = UiVertex;
    // Triangle 1: top-left, top-right, bottom-right
    verts[idx + 0] = V{ .pos_x = x, .pos_y = y, .r = top.r, .g = top.g, .b = top.b, .a = top.a, .u = -1, .v = -1 };
    verts[idx + 1] = V{ .pos_x = x1, .pos_y = y, .r = top.r, .g = top.g, .b = top.b, .a = top.a, .u = -1, .v = -1 };
    verts[idx + 2] = V{ .pos_x = x1, .pos_y = y1, .r = bot.r, .g = bot.g, .b = bot.b, .a = bot.a, .u = -1, .v = -1 };
    // Triangle 2: top-left, bottom-right, bottom-left
    verts[idx + 3] = V{ .pos_x = x, .pos_y = y, .r = top.r, .g = top.g, .b = top.b, .a = top.a, .u = -1, .v = -1 };
    verts[idx + 4] = V{ .pos_x = x1, .pos_y = y1, .r = bot.r, .g = bot.g, .b = bot.b, .a = bot.a, .u = -1, .v = -1 };
    verts[idx + 5] = V{ .pos_x = x, .pos_y = y1, .r = bot.r, .g = bot.g, .b = bot.b, .a = bot.a, .u = -1, .v = -1 };
    return idx + 6;
}

/// Render a letter glyph at the given position using pixel quads.
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

/// Draw a sequence of letter glyphs centered horizontally at the given y.
fn drawLabel(verts: []UiVertex, idx: u32, center_x: f32, y: f32, glyphs: []const LetterGlyph, scale: f32, col: Color) u32 {
    const char_w = 3.0 * scale + 2.0;
    const count_f: f32 = @floatFromInt(glyphs.len);
    const total_w = count_f * char_w - 2.0;
    const start_x = center_x - total_w * 0.5;

    var c = idx;
    for (glyphs, 0..) |glyph, i| {
        const offset = @as(f32, @floatFromInt(i)) * char_w;
        c = drawLetter(verts, c, start_x + offset, y, glyph, scale, col);
    }
    return c;
}

/// Compute the center_x needed to left-align a label at the given x position.
fn labelCenterForLeftAlign(x: f32, glyph_count: usize, scale: f32) f32 {
    const char_w = 3.0 * scale + 2.0;
    const count_f: f32 = @floatFromInt(glyph_count);
    const total_w = count_f * char_w - 2.0;
    return x + total_w * 0.5;
}

// ── Layout helpers ───────────────────────────────────────────────────

/// Compute the Y position where the logo+button group starts so the whole
/// group is vertically centered on screen.
fn groupTopY(sh: f32) f32 {
    const total_h = logo_h + logo_btn_gap + btn_stack_h;
    return (sh - total_h) * 0.5;
}

/// Compute the Y of the first button's top edge.
fn firstButtonY(sh: f32) f32 {
    return groupTopY(sh) + logo_h + logo_btn_gap;
}

/// Compute the Y of the n-th button (0-indexed).
fn buttonY(sh: f32, n: u32) f32 {
    return firstButtonY(sh) + @as(f32, @floatFromInt(n)) * (btn_h + btn_gap);
}

/// Compute the X of all buttons (centered).
fn buttonX(sw: f32) f32 {
    return (sw - btn_w) * 0.5;
}

// ── Public API ───────────────────────────────────────────────────────

/// Render the title screen into the provided vertex buffer.
/// `time` can be used for subtle animations (currently: logo block shimmer).
/// Returns the new vertex index (total vertices written from index 0).
pub fn render(verts: []UiVertex, start: u32, sw: f32, sh: f32, time: f32) u32 {
    var idx = start;

    // 1. Background gradient (dark blue top to slightly lighter blue bottom).
    idx = addGradientQuad(verts, idx, 0, 0, sw, sh, bg_top, bg_bot);

    // 2. Logo area: pixel-art block grid centered above buttons.
    const group_top = groupTopY(sh);
    const logo_x = (sw - logo_w) * 0.5;
    const logo_y = group_top;
    const cell_w = logo_w / @as(f32, @floatFromInt(logo_grid_w));
    const cell_h = logo_h / @as(f32, @floatFromInt(logo_grid_h));

    var gy: u32 = 0;
    while (gy < logo_grid_h) : (gy += 1) {
        var gx: u32 = 0;
        while (gx < logo_grid_w) : (gx += 1) {
            if (logoColor(logo_grid[gy][gx])) |base_col| {
                // Subtle shimmer: modulate brightness with time and position.
                const phase = @as(f32, @floatFromInt(gx + gy * logo_grid_w));
                const shimmer = 1.0 + 0.08 * @sin(time * 2.0 + phase);
                const col = Color{
                    .r = @min(base_col.r * shimmer, 1.0),
                    .g = @min(base_col.g * shimmer, 1.0),
                    .b = @min(base_col.b * shimmer, 1.0),
                    .a = base_col.a,
                };
                idx = addQuad(
                    verts,
                    idx,
                    logo_x + @as(f32, @floatFromInt(gx)) * cell_w,
                    logo_y + @as(f32, @floatFromInt(gy)) * cell_h,
                    cell_w - 1.0,
                    cell_h - 1.0,
                    col,
                );
            }
        }
    }

    // 3. Buttons: 4 stacked vertically, centered.
    const bx = buttonX(sw);
    const label_scale: f32 = 2.0;
    const label_y_pad = (btn_h - 5.0 * label_scale) * 0.5;
    const btn_center_x = bx + btn_w * 0.5;

    const btn_colors = [_]Color{ singleplayer_col, multiplayer_col, options_col, quit_col };
    const btn_labels = [_][]const LetterGlyph{ &sp_glyphs, &mp_glyphs, &opt_glyphs, &quit_glyphs };

    for (btn_colors, 0..) |col, i| {
        const by = buttonY(sh, @intCast(i));
        idx = addQuad(verts, idx, bx, by, btn_w, btn_h, col);
        idx = drawLabel(verts, idx, btn_center_x, by + label_y_pad, btn_labels[i], label_scale, label_col);
    }

    // 4. Version text in bottom-left corner.
    const ver_y = sh - version_y_offset;
    const ver_center = labelCenterForLeftAlign(version_x, version_glyphs.len, 1.5);
    idx = drawLabel(verts, idx, ver_center, ver_y, &version_glyphs, 1.5, version_col);

    return idx;
}

/// Test whether the mouse position (mx, my) hits any of the four buttons.
/// Multiplayer is included in hit-testing (callers can check the enum and
/// ignore it if the button is disabled).
/// Returns the corresponding `Button` or `null` if outside all buttons.
pub fn hitTest(mx: f32, my: f32, sw: f32, sh: f32) ?Button {
    const bx = buttonX(sw);

    const buttons = [_]Button{ .singleplayer, .multiplayer, .options, .quit };
    for (buttons, 0..) |btn, i| {
        const by = buttonY(sh, @intCast(i));
        if (mx >= bx and mx <= bx + btn_w and my >= by and my <= by + btn_h) {
            return btn;
        }
    }

    return null;
}

// ── Tests ────────────────────────────────────────────────────────────

test "render returns more vertices than start index" {
    var buf: [max_vertices]UiVertex = undefined;
    const count = render(&buf, 0, 1920.0, 1080.0, 0.0);
    try std.testing.expect(count > 0);
    try std.testing.expect(count % 6 == 0);
}

test "render with start offset preserves offset" {
    var buf: [max_vertices]UiVertex = undefined;
    const count = render(&buf, 12, 800.0, 600.0, 0.0);
    try std.testing.expect(count >= 12);
    try std.testing.expect((count - 12) % 6 == 0);
}

test "background gradient covers full screen" {
    var buf: [max_vertices]UiVertex = undefined;
    const sw: f32 = 1024.0;
    const sh: f32 = 768.0;
    _ = render(&buf, 0, sw, sh, 0.0);
    // First quad is the gradient background
    try std.testing.expectApproxEqAbs(buf[0].pos_x, 0.0, 0.01);
    try std.testing.expectApproxEqAbs(buf[0].pos_y, 0.0, 0.01);
    try std.testing.expectApproxEqAbs(buf[1].pos_x, sw, 0.01);
    try std.testing.expectApproxEqAbs(buf[1].pos_y, 0.0, 0.01);
    // Top vertices should have dark blue
    try std.testing.expectApproxEqAbs(buf[0].r, bg_top.r, 0.01);
    try std.testing.expectApproxEqAbs(buf[0].b, bg_top.b, 0.01);
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

test "hitTest returns singleplayer for first button" {
    const sw: f32 = 800.0;
    const sh: f32 = 600.0;
    const bx = buttonX(sw);
    const by = buttonY(sh, 0);
    const mx = bx + btn_w * 0.5;
    const my = by + btn_h * 0.5;
    const result = hitTest(mx, my, sw, sh);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(Button.singleplayer, result.?);
}

test "hitTest returns multiplayer for second button" {
    const sw: f32 = 800.0;
    const sh: f32 = 600.0;
    const bx = buttonX(sw);
    const by = buttonY(sh, 1);
    const mx = bx + btn_w * 0.5;
    const my = by + btn_h * 0.5;
    const result = hitTest(mx, my, sw, sh);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(Button.multiplayer, result.?);
}

test "hitTest returns options for third button" {
    const sw: f32 = 800.0;
    const sh: f32 = 600.0;
    const bx = buttonX(sw);
    const by = buttonY(sh, 2);
    const mx = bx + btn_w * 0.5;
    const my = by + btn_h * 0.5;
    const result = hitTest(mx, my, sw, sh);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(Button.options, result.?);
}

test "hitTest returns quit for fourth button" {
    const sw: f32 = 800.0;
    const sh: f32 = 600.0;
    const bx = buttonX(sw);
    const by = buttonY(sh, 3);
    const mx = bx + btn_w * 0.5;
    const my = by + btn_h * 0.5;
    const result = hitTest(mx, my, sw, sh);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(Button.quit, result.?);
}

test "hitTest returns null for click outside buttons" {
    const sw: f32 = 800.0;
    const sh: f32 = 600.0;
    try std.testing.expectEqual(@as(?Button, null), hitTest(10.0, 10.0, sw, sh));
    // Between buttons (in the gap)
    const by0 = buttonY(sh, 0);
    const gap_y = by0 + btn_h + btn_gap * 0.5;
    try std.testing.expectEqual(@as(?Button, null), hitTest(sw * 0.5, gap_y, sw, sh));
}

test "hitTest at button edges" {
    const sw: f32 = 800.0;
    const sh: f32 = 600.0;
    const bx = buttonX(sw);

    // Exact top-left corner of singleplayer button
    const result_tl = hitTest(bx, buttonY(sh, 0), sw, sh);
    try std.testing.expectEqual(Button.singleplayer, result_tl.?);

    // Exact bottom-right corner of quit button
    const result_br = hitTest(bx + btn_w, buttonY(sh, 3) + btn_h, sw, sh);
    try std.testing.expectEqual(Button.quit, result_br.?);

    // Just outside left edge
    const result_out = hitTest(bx - 1.0, buttonY(sh, 0), sw, sh);
    try std.testing.expectEqual(@as(?Button, null), result_out);
}

test "render produces consistent output for same inputs" {
    var buf1: [max_vertices]UiVertex = undefined;
    var buf2: [max_vertices]UiVertex = undefined;
    const count1 = render(&buf1, 0, 1280.0, 720.0, 5.0);
    const count2 = render(&buf2, 0, 1280.0, 720.0, 5.0);
    try std.testing.expectEqual(count1, count2);
    for (0..@min(count1, 30)) |i| {
        try std.testing.expectApproxEqAbs(buf1[i].pos_x, buf2[i].pos_x, 0.001);
        try std.testing.expectApproxEqAbs(buf1[i].pos_y, buf2[i].pos_y, 0.001);
    }
}

test "render does not overflow small buffer" {
    var buf: [12]UiVertex = undefined;
    const count = render(&buf, 0, 800.0, 600.0, 0.0);
    try std.testing.expect(count <= 12);
}

test "different time values produce different logo colors" {
    var buf1: [max_vertices]UiVertex = undefined;
    var buf2: [max_vertices]UiVertex = undefined;
    _ = render(&buf1, 0, 800.0, 600.0, 0.0);
    _ = render(&buf2, 0, 800.0, 600.0, 1.5);
    // The first logo block quad starts at index 6 (after the background gradient).
    // Compare the red channel of the first logo pixel — shimmer should differ.
    const logo_idx: usize = 6;
    const diff = @abs(buf1[logo_idx].r - buf2[logo_idx].r);
    try std.testing.expect(diff > 0.001);
}
