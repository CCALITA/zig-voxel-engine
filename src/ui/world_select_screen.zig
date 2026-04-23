/// World select screen renderer.
/// Produces UiVertex quads for a centered 400x400 panel with 5 world slots
/// (each 360x50), action buttons (Create New, Play, Delete), seed/gamemode
/// display per slot, and a selection highlight border. Uses bitmap_font for
/// numeric display.
///
/// Self-contained: defines its own `UiVertex` matching the UI pipeline layout
/// (pos.xy, rgba, uv). Untextured quads use `u = -1, v = -1` so the fragment
/// shader takes the solid-color branch.
const std = @import("std");
const bitmap_font = @import("../renderer/bitmap_font.zig");

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

// ── World data ──────────────────────────────────────────────────────

pub const WorldEntry = struct {
    seed: u64,
    last_played: u64,
    gamemode: u8,
};

// ── Layout constants ─────────────────────────────────────────────────

const panel_w: f32 = 400.0;
const panel_h: f32 = 400.0;

const slot_w: f32 = 360.0;
const slot_h: f32 = 50.0;
const slot_gap: f32 = 6.0;
const slot_left_pad: f32 = (panel_w - slot_w) * 0.5;

const slot_area_top: f32 = 10.0;

const btn_w: f32 = 110.0;
const btn_h: f32 = 32.0;
const btn_gap: f32 = 8.0;
const btn_bottom_pad: f32 = 12.0;

const border_width: f32 = 2.0;
const highlight_width: f32 = 2.0;

const pixel_scale: f32 = 2.0;

// ── Colors ───────────────────────────────────────────────────────────

const Color = struct { r: f32, g: f32, b: f32, a: f32 };

const panel_bg = Color{ .r = 0.12, .g = 0.12, .b = 0.12, .a = 0.92 };
const panel_border_col = Color{ .r = 0.35, .g = 0.35, .b = 0.35, .a = 0.95 };

const slot_empty_bg = Color{ .r = 0.18, .g = 0.18, .b = 0.18, .a = 0.8 };
const slot_filled_bg = Color{ .r = 0.22, .g = 0.22, .b = 0.28, .a = 0.9 };
const highlight_col = Color{ .r = 1.0, .g = 0.85, .b = 0.2, .a = 1.0 };

const create_btn_col = Color{ .r = 0.18, .g = 0.55, .b = 0.22, .a = 1.0 };
const play_btn_col = Color{ .r = 0.20, .g = 0.40, .b = 0.70, .a = 1.0 };
const delete_btn_col = Color{ .r = 0.65, .g = 0.15, .b = 0.15, .a = 1.0 };

const label_col = Color{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 1.0 };
const seed_col = Color{ .r = 0.7, .g = 0.7, .b = 0.7, .a = 0.9 };
const slot_index_col = Color{ .r = 0.9, .g = 0.9, .b = 0.9, .a = 1.0 };
const empty_label_col = Color{ .r = 0.5, .g = 0.5, .b = 0.5, .a = 0.7 };

// ── Pixel-art glyph system ───────────────────────────────────────────

const LetterGlyph = u15;

fn getLetterPixel(glyph: LetterGlyph, x: u32, y: u32) bool {
    if (x >= 3 or y >= 5) return false;
    const bit_index: u4 = @intCast(y * 3 + x);
    return (glyph >> (14 - bit_index)) & 1 == 1;
}

// Letter definitions
const letter_C: LetterGlyph = 0b011_100_100_100_011;
const letter_R: LetterGlyph = 0b110_101_110_101_101;
const letter_E: LetterGlyph = 0b111_100_110_100_111;
const letter_A: LetterGlyph = 0b010_101_111_101_101;
const letter_T: LetterGlyph = 0b111_010_010_010_010;
const letter_N: LetterGlyph = 0b101_111_111_111_101;
const letter_W: LetterGlyph = 0b101_101_111_111_101;
const letter_P: LetterGlyph = 0b110_101_110_100_100;
const letter_L: LetterGlyph = 0b100_100_100_100_111;
const letter_Y: LetterGlyph = 0b101_101_010_010_010;
const letter_D: LetterGlyph = 0b110_101_101_101_110;
const letter_I: LetterGlyph = 0b111_010_010_010_111;
const letter_S: LetterGlyph = 0b111_100_111_001_111;
const letter_G: LetterGlyph = 0b011_100_101_101_011;
const letter_M: LetterGlyph = 0b101_111_111_101_101;
const letter_O: LetterGlyph = 0b010_101_101_101_010;

// dash glyph: middle row lit
const dash_glyph: LetterGlyph = 0b000_000_111_000_000;

// Button label glyph arrays: "CREATE NEW", "PLAY", "DELETE"
const create_glyphs = [_]LetterGlyph{ letter_N, letter_E, letter_W };
const play_glyphs = [_]LetterGlyph{ letter_P, letter_L, letter_A, letter_Y };
const delete_glyphs = [_]LetterGlyph{ letter_D, letter_E, letter_L };

// World slot label: "WORLD" + number
const world_glyphs = [_]LetterGlyph{ letter_W, letter_O, letter_R, letter_L, letter_D };

// Empty slot label: "---"
const empty_glyphs = [_]LetterGlyph{ dash_glyph, dash_glyph, dash_glyph };

// Gamemode labels: S=Survival, C=Creative, A=Adventure, P=Spectator
const gm_survival = [_]LetterGlyph{letter_S};
const gm_creative = [_]LetterGlyph{letter_C};
const gm_adventure = [_]LetterGlyph{letter_A};
const gm_spectator = [_]LetterGlyph{letter_P};

// ── Maximum vertex budget ────────────────────────────────────────────

/// Panel border(4) + panel bg(1) + 5 slots(5) + highlight(4) + 3 buttons(3)
/// + labels + seed numbers + slot indices ≈ generous budget.
pub const max_vertices: u32 = 8192;

// ── Quad helper ──────────────────────────────────────────────────────

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

// ── Text rendering helpers ──────────────────────────────────────────

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

/// Draw a number left-aligned at (x, y) using bitmap_font.
/// Returns the new vertex index.
fn drawNumber(verts: []UiVertex, idx: u32, x: f32, y: f32, value: u32, scale: f32, col: Color) u32 {
    const num_digits = bitmap_font.digitCount(value);
    const glyph_w: f32 = @floatFromInt(bitmap_font.GLYPH_W);
    const digit_spacing: f32 = 1.0;

    var c = idx;
    var d: u32 = 0;
    while (d < num_digits) : (d += 1) {
        const digit = bitmap_font.getDigit(value, num_digits - 1 - d);
        const dx = x + @as(f32, @floatFromInt(d)) * (glyph_w * scale + digit_spacing);

        var py: u32 = 0;
        while (py < bitmap_font.GLYPH_H) : (py += 1) {
            var px: u32 = 0;
            while (px < bitmap_font.GLYPH_W) : (px += 1) {
                if (bitmap_font.getPixel(digit, px, py)) {
                    c = addQuad(
                        verts,
                        c,
                        dx + @as(f32, @floatFromInt(px)) * scale,
                        y + @as(f32, @floatFromInt(py)) * scale,
                        scale,
                        scale,
                        col,
                    );
                }
            }
        }
    }
    return c;
}

// ── Layout helpers ───────────────────────────────────────────────────

fn panelX(sw: f32) f32 {
    return (sw - panel_w) * 0.5;
}

fn panelY(sh: f32) f32 {
    return (sh - panel_h) * 0.5;
}

fn slotY(sh: f32, slot: u32) f32 {
    return panelY(sh) + slot_area_top + @as(f32, @floatFromInt(slot)) * (slot_h + slot_gap);
}

fn slotX(sw: f32) f32 {
    return panelX(sw) + slot_left_pad;
}

fn btnY(sh: f32) f32 {
    return panelY(sh) + panel_h - btn_h - btn_bottom_pad;
}

fn gamemodeGlyphs(gm: u8) []const LetterGlyph {
    return switch (gm) {
        0 => &gm_survival,
        1 => &gm_creative,
        2 => &gm_adventure,
        else => &gm_spectator,
    };
}

// ── Public API ───────────────────────────────────────────────────────

/// Render the world select screen into the provided vertex buffer.
/// Returns the new vertex index (total vertices written from index 0).
pub fn render(verts: []UiVertex, start: u32, sw: f32, sh: f32, worlds: [5]?WorldEntry, selected: ?u8) u32 {
    var idx = start;

    const px = panelX(sw);
    const py = panelY(sh);

    // 1. Panel border (4 edges)
    const bw = border_width;
    idx = addQuad(verts, idx, px - bw, py - bw, panel_w + bw * 2, bw, panel_border_col);
    idx = addQuad(verts, idx, px - bw, py + panel_h, panel_w + bw * 2, bw, panel_border_col);
    idx = addQuad(verts, idx, px - bw, py, bw, panel_h, panel_border_col);
    idx = addQuad(verts, idx, px + panel_w, py, bw, panel_h, panel_border_col);

    // 2. Panel background
    idx = addQuad(verts, idx, px, py, panel_w, panel_h, panel_bg);

    // 3. World slots
    const sx = slotX(sw);
    const label_scale: f32 = 1.5;
    const label_y_pad: f32 = 6.0;

    for (0..5) |i| {
        const slot_i: u32 = @intCast(i);
        const sy = slotY(sh, slot_i);

        if (worlds[i]) |entry| {
            // Filled slot
            idx = addQuad(verts, idx, sx, sy, slot_w, slot_h, slot_filled_bg);

            // "WORLD N" label (left-aligned in slot)
            const text_x = sx + 8.0;
            const text_y = sy + label_y_pad;
            var c_label = idx;
            // Draw "WORLD" text
            const char_w_label = 3.0 * label_scale + 2.0;
            var g_i: usize = 0;
            while (g_i < world_glyphs.len) : (g_i += 1) {
                c_label = drawLetter(verts, c_label, text_x + @as(f32, @floatFromInt(g_i)) * char_w_label, text_y, world_glyphs[g_i], label_scale, slot_index_col);
            }
            // Draw slot number (1-based)
            const num_x = text_x + @as(f32, @floatFromInt(world_glyphs.len)) * char_w_label + 4.0;
            c_label = drawNumber(verts, c_label, num_x, text_y, slot_i + 1, label_scale, slot_index_col);
            idx = c_label;

            // Seed display (second row, smaller)
            const seed_y = sy + label_y_pad + 5.0 * label_scale + 4.0;
            const seed_scale: f32 = 1.0;
            // Display lower 32 bits of seed as a number
            const seed_lo: u32 = @truncate(entry.seed);
            idx = drawNumber(verts, idx, text_x, seed_y, seed_lo, seed_scale, seed_col);

            // Gamemode indicator (right side of slot)
            const gm_glyphs_data = gamemodeGlyphs(entry.gamemode);
            const gm_x = sx + slot_w - 20.0;
            idx = drawLabel(verts, idx, gm_x, text_y, gm_glyphs_data, label_scale, label_col);
        } else {
            // Empty slot
            idx = addQuad(verts, idx, sx, sy, slot_w, slot_h, slot_empty_bg);

            // "---" centered in slot
            const slot_center_x = sx + slot_w * 0.5;
            const empty_y = sy + (slot_h - 5.0 * label_scale) * 0.5;
            idx = drawLabel(verts, idx, slot_center_x, empty_y, &empty_glyphs, label_scale, empty_label_col);
        }

        // Selection highlight border
        if (selected) |sel| {
            if (sel == i) {
                const hw = highlight_width;
                idx = addQuad(verts, idx, sx - hw, sy - hw, slot_w + hw * 2, hw, highlight_col);
                idx = addQuad(verts, idx, sx - hw, sy + slot_h, slot_w + hw * 2, hw, highlight_col);
                idx = addQuad(verts, idx, sx - hw, sy, hw, slot_h, highlight_col);
                idx = addQuad(verts, idx, sx + slot_w, sy, hw, slot_h, highlight_col);
            }
        }
    }

    // 4. Action buttons (bottom of panel, evenly spaced)
    const by = btnY(sh);
    const bsx = btnStartX(sw);
    const btn_label_scale: f32 = 1.5;
    const btn_label_y_pad = (btn_h - 5.0 * btn_label_scale) * 0.5;

    // Create New button
    const create_x = bsx;
    idx = addQuad(verts, idx, create_x, by, btn_w, btn_h, create_btn_col);
    idx = drawLabel(verts, idx, create_x + btn_w * 0.5, by + btn_label_y_pad, &create_glyphs, btn_label_scale, label_col);

    // Play button
    const play_x = bsx + btn_w + btn_gap;
    idx = addQuad(verts, idx, play_x, by, btn_w, btn_h, play_btn_col);
    idx = drawLabel(verts, idx, play_x + btn_w * 0.5, by + btn_label_y_pad, &play_glyphs, btn_label_scale, label_col);

    // Delete button
    const del_x = bsx + (btn_w + btn_gap) * 2.0;
    idx = addQuad(verts, idx, del_x, by, btn_w, btn_h, delete_btn_col);
    idx = drawLabel(verts, idx, del_x + btn_w * 0.5, by + btn_label_y_pad, &delete_glyphs, btn_label_scale, label_col);

    return idx;
}

// ── Hit-test ────────────────────────────────────────────────────────

pub const HitResult = union(enum) {
    slot: u8,
    create_new,
    play,
    delete,
};

/// Test whether (mx, my) hits a world slot or one of the three action buttons.
pub fn hitTest(mx: f32, my: f32, sw: f32, sh: f32) ?HitResult {
    // Check slots
    const sx = slotX(sw);
    for (0..5) |i| {
        const sy = slotY(sh, @intCast(i));
        if (mx >= sx and mx <= sx + slot_w and my >= sy and my <= sy + slot_h) {
            return .{ .slot = @intCast(i) };
        }
    }

    // Check buttons
    const by = btnY(sh);
    const bsx = btnStartX(sw);

    const create_x = bsx;
    if (mx >= create_x and mx <= create_x + btn_w and my >= by and my <= by + btn_h) {
        return .create_new;
    }

    const play_x = bsx + btn_w + btn_gap;
    if (mx >= play_x and mx <= play_x + btn_w and my >= by and my <= by + btn_h) {
        return .play;
    }

    const del_x = bsx + (btn_w + btn_gap) * 2.0;
    if (mx >= del_x and mx <= del_x + btn_w and my >= by and my <= by + btn_h) {
        return .delete;
    }

    return null;
}

// ── Tests ────────────────────────────────────────────────────────────

test "render returns more vertices than start index" {
    var buf: [max_vertices]UiVertex = undefined;
    const worlds = [5]?WorldEntry{
        WorldEntry{ .seed = 12345, .last_played = 100, .gamemode = 0 },
        null,
        null,
        null,
        null,
    };
    const count = render(&buf, 0, 800.0, 600.0, worlds, null);
    try std.testing.expect(count > 0);
    try std.testing.expect(count % 6 == 0);
}

test "render with start offset preserves offset" {
    var buf: [max_vertices]UiVertex = undefined;
    const worlds = [5]?WorldEntry{ null, null, null, null, null };
    const count = render(&buf, 12, 800.0, 600.0, worlds, null);
    try std.testing.expect(count >= 12);
    try std.testing.expect((count - 12) % 6 == 0);
}

test "panel is centered on screen" {
    var buf: [max_vertices]UiVertex = undefined;
    const sw: f32 = 800.0;
    const sh: f32 = 600.0;
    const worlds = [5]?WorldEntry{ null, null, null, null, null };
    _ = render(&buf, 0, sw, sh, worlds, null);
    // After 4 border quads (24 verts), the panel bg starts at index 24
    const expected_x = (sw - panel_w) * 0.5;
    const expected_y = (sh - panel_h) * 0.5;
    try std.testing.expectApproxEqAbs(expected_x, buf[24].pos_x, 0.01);
    try std.testing.expectApproxEqAbs(expected_y, buf[24].pos_y, 0.01);
}

test "selected slot produces more vertices (highlight border)" {
    var buf1: [max_vertices]UiVertex = undefined;
    var buf2: [max_vertices]UiVertex = undefined;
    const worlds = [5]?WorldEntry{ null, null, null, null, null };
    const count_no_sel = render(&buf1, 0, 800.0, 600.0, worlds, null);
    const count_sel = render(&buf2, 0, 800.0, 600.0, worlds, 0);
    // Selection adds 4 highlight border quads = 24 extra vertices
    try std.testing.expect(count_sel > count_no_sel);
    try std.testing.expectEqual(count_sel - count_no_sel, 24);
}

test "filled slot produces more vertices than empty slot" {
    var buf1: [max_vertices]UiVertex = undefined;
    var buf2: [max_vertices]UiVertex = undefined;
    const empty_worlds = [5]?WorldEntry{ null, null, null, null, null };
    const one_world = [5]?WorldEntry{
        WorldEntry{ .seed = 42, .last_played = 0, .gamemode = 0 },
        null,
        null,
        null,
        null,
    };
    const count_empty = render(&buf1, 0, 800.0, 600.0, empty_worlds, null);
    const count_one = render(&buf2, 0, 800.0, 600.0, one_world, null);
    try std.testing.expect(count_one > count_empty);
}

test "hitTest returns slot for click on first world slot" {
    const sw: f32 = 800.0;
    const sh: f32 = 600.0;
    const sx = slotX(sw);
    const sy = slotY(sh, 0);
    const mx = sx + slot_w * 0.5;
    const my = sy + slot_h * 0.5;
    const result = hitTest(mx, my, sw, sh);
    try std.testing.expect(result != null);
    switch (result.?) {
        .slot => |s| try std.testing.expectEqual(@as(u8, 0), s),
        else => return error.TestUnexpectedResult,
    }
}

test "hitTest returns create_new for click on create button" {
    const sw: f32 = 800.0;
    const sh: f32 = 600.0;
    const by = btnY(sh);
    const bsx = btnStartX(sw);
    const mx = bsx + btn_w * 0.5;
    const my = by + btn_h * 0.5;
    const result = hitTest(mx, my, sw, sh);
    try std.testing.expect(result != null);
    try std.testing.expect(result.? == .create_new);
}

test "hitTest returns play for click on play button" {
    const sw: f32 = 800.0;
    const sh: f32 = 600.0;
    const by = btnY(sh);
    const bsx = btnStartX(sw);
    const mx = bsx + btn_w + btn_gap + btn_w * 0.5;
    const my = by + btn_h * 0.5;
    const result = hitTest(mx, my, sw, sh);
    try std.testing.expect(result != null);
    try std.testing.expect(result.? == .play);
}

test "hitTest returns delete for click on delete button" {
    const sw: f32 = 800.0;
    const sh: f32 = 600.0;
    const by = btnY(sh);
    const bsx = btnStartX(sw);
    const mx = bsx + (btn_w + btn_gap) * 2.0 + btn_w * 0.5;
    const my = by + btn_h * 0.5;
    const result = hitTest(mx, my, sw, sh);
    try std.testing.expect(result != null);
    try std.testing.expect(result.? == .delete);
}

test "hitTest returns null for click outside panel" {
    try std.testing.expectEqual(@as(?HitResult, null), hitTest(5.0, 5.0, 800.0, 600.0));
}

test "render does not overflow small buffer" {
    var buf: [12]UiVertex = undefined;
    const worlds = [5]?WorldEntry{ null, null, null, null, null };
    const count = render(&buf, 0, 800.0, 600.0, worlds, null);
    try std.testing.expect(count <= 12);
}

test "addQuad emits 6 vertices with u=-1, v=-1" {
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

test "drawNumber renders digit pixels" {
    var buf: [512]UiVertex = undefined;
    const after = drawNumber(&buf, 0, 100.0, 100.0, 42, 2.0, seed_col);
    try std.testing.expect(after > 0);
    try std.testing.expect(after % 6 == 0);
}

test "render produces consistent output for same inputs" {
    var buf1: [max_vertices]UiVertex = undefined;
    var buf2: [max_vertices]UiVertex = undefined;
    const worlds = [5]?WorldEntry{
        WorldEntry{ .seed = 999, .last_played = 50, .gamemode = 1 },
        WorldEntry{ .seed = 123, .last_played = 10, .gamemode = 0 },
        null,
        null,
        null,
    };
    const count1 = render(&buf1, 0, 1280.0, 720.0, worlds, 1);
    const count2 = render(&buf2, 0, 1280.0, 720.0, worlds, 1);
    try std.testing.expectEqual(count1, count2);
    for (0..@min(count1, 30)) |i| {
        try std.testing.expectApproxEqAbs(buf1[i].pos_x, buf2[i].pos_x, 0.001);
        try std.testing.expectApproxEqAbs(buf1[i].pos_y, buf2[i].pos_y, 0.001);
    }
}

test "hitTest returns correct slot indices for all 5 slots" {
    const sw: f32 = 1024.0;
    const sh: f32 = 768.0;
    const sx = slotX(sw);
    for (0..5) |i| {
        const sy = slotY(sh, @intCast(i));
        const result = hitTest(sx + 10.0, sy + 10.0, sw, sh);
        try std.testing.expect(result != null);
        switch (result.?) {
            .slot => |s| try std.testing.expectEqual(@as(u8, @intCast(i)), s),
            else => return error.TestUnexpectedResult,
        }
    }
}
