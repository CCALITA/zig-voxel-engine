/// Pause menu overlay renderer.
/// Produces UiVertex quads for a dark full-screen overlay, a centered 300x200
/// panel, a "Game Paused" title indicator, and two buttons: Resume (green) and
/// Quit (red). Also provides hit-testing for mouse clicks on those buttons.
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

// ── Layout constants ─────────────────────────────────────────────────

const panel_w: f32 = 300.0;
const panel_h: f32 = 200.0;

const btn_w: f32 = 200.0;
const btn_h: f32 = 36.0;

const title_y_offset: f32 = 20.0;
const resume_y_offset: f32 = 60.0;
const quit_y_offset: f32 = 120.0;

// ── Colors ───────────────────────────────────────────────────────────

const Color = struct { r: f32, g: f32, b: f32, a: f32 };

const overlay_col = Color{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 0.55 };
const panel_bg = Color{ .r = 0.15, .g = 0.15, .b = 0.15, .a = 0.92 };
const panel_border_col = Color{ .r = 0.35, .g = 0.35, .b = 0.35, .a = 0.95 };
const title_col = Color{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 1.0 };
const resume_col = Color{ .r = 0.18, .g = 0.55, .b = 0.22, .a = 1.0 };
const quit_col = Color{ .r = 0.65, .g = 0.15, .b = 0.15, .a = 1.0 };

// ── Title pixel art: "PAUSED" ────────────────────────────────────────

/// Simple 3-wide, 5-tall letter bitmasks (15 bits each, MSB = top-left).
const LetterGlyph = u15;

const letter_P: LetterGlyph = 0b110_101_110_100_100;
const letter_A: LetterGlyph = 0b010_101_111_101_101;
const letter_U: LetterGlyph = 0b101_101_101_101_111;
const letter_S: LetterGlyph = 0b111_100_111_001_111;
const letter_E: LetterGlyph = 0b111_100_110_100_111;
const letter_D: LetterGlyph = 0b110_101_101_101_110;

const title_glyphs = [_]LetterGlyph{ letter_P, letter_A, letter_U, letter_S, letter_E, letter_D };

fn getLetterPixel(glyph: LetterGlyph, x: u32, y: u32) bool {
    if (x >= 3 or y >= 5) return false;
    const bit_index: u4 = @intCast(y * 3 + x);
    return (glyph >> (14 - bit_index)) & 1 == 1;
}

// ── Button label pixel art ───────────────────────────────────────────

// "RESUME" label glyphs
const letter_R: LetterGlyph = 0b110_101_110_101_101;
const letter_M: LetterGlyph = 0b101_111_111_101_101;

const resume_glyphs = [_]LetterGlyph{ letter_R, letter_E, letter_S, letter_U, letter_M, letter_E };

// "QUIT" label glyphs
const letter_Q: LetterGlyph = 0b010_101_101_111_011;
const letter_I: LetterGlyph = 0b111_010_010_010_111;
const letter_T: LetterGlyph = 0b111_010_010_010_010;

const quit_glyphs = [_]LetterGlyph{ letter_Q, letter_U, letter_I, letter_T };

// ── Maximum vertex budget ────────────────────────────────────────────

/// Overlay(1) + panel(1) + border(4) + title(~6*9≈54) + 2 buttons(2)
/// + resume label(~6*9≈54) + quit label(~4*9≈36) ≈ ~152 quads * 6 ≈ 912.
/// Rounded up for safety.
pub const max_vertices: u32 = 1024;

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

// ── Hit-test result ──────────────────────────────────────────────────

pub const Button = enum { @"resume", quit };

// ── Public API ───────────────────────────────────────────────────────

/// Render the pause menu overlay into the provided vertex buffer.
/// Returns the new vertex index (total vertices written from index 0).
pub fn render(verts: []UiVertex, start: u32, sw: f32, sh: f32) u32 {
    var idx = start;

    // Full-screen dark overlay
    idx = addQuad(verts, idx, 0, 0, sw, sh, overlay_col);

    // Panel centered on screen
    const px = (sw - panel_w) * 0.5;
    const py = (sh - panel_h) * 0.5;

    // Panel border (4 edges)
    const bw: f32 = 2.0;
    idx = addQuad(verts, idx, px - bw, py - bw, panel_w + bw * 2, bw, panel_border_col);
    idx = addQuad(verts, idx, px - bw, py + panel_h, panel_w + bw * 2, bw, panel_border_col);
    idx = addQuad(verts, idx, px - bw, py, bw, panel_h, panel_border_col);
    idx = addQuad(verts, idx, px + panel_w, py, bw, panel_h, panel_border_col);

    // Panel background
    idx = addQuad(verts, idx, px, py, panel_w, panel_h, panel_bg);

    // Title: "PAUSED" centered near top of panel
    const title_scale: f32 = 3.0;
    const title_center_x = px + panel_w * 0.5;
    const title_y = py + title_y_offset;
    idx = drawLabel(verts, idx, title_center_x, title_y, &title_glyphs, title_scale, title_col);

    // Resume button (green, centered at y+60)
    const btn_x = px + (panel_w - btn_w) * 0.5;
    const resume_y = py + resume_y_offset;
    idx = addQuad(verts, idx, btn_x, resume_y, btn_w, btn_h, resume_col);

    // Resume label
    const label_scale: f32 = 2.0;
    const label_y_pad = (btn_h - 5.0 * label_scale) * 0.5;
    const btn_center_x = btn_x + btn_w * 0.5;
    idx = drawLabel(verts, idx, btn_center_x, resume_y + label_y_pad, &resume_glyphs, label_scale, title_col);

    // Quit button (red, centered at y+120)
    const quit_y = py + quit_y_offset;
    idx = addQuad(verts, idx, btn_x, quit_y, btn_w, btn_h, quit_col);

    // Quit label
    idx = drawLabel(verts, idx, btn_center_x, quit_y + label_y_pad, &quit_glyphs, label_scale, title_col);

    return idx;
}

/// Test whether the mouse position (mx, my) hits either button.
/// Returns `.resume` or `.quit` if a button was clicked, or `null` if
/// the click was outside both buttons.
pub fn hitTest(mx: f32, my: f32, sw: f32, sh: f32) ?Button {
    const px = (sw - panel_w) * 0.5;
    const py = (sh - panel_h) * 0.5;
    const btn_x = px + (panel_w - btn_w) * 0.5;

    // Resume button bounds
    const resume_y = py + resume_y_offset;
    if (mx >= btn_x and mx <= btn_x + btn_w and my >= resume_y and my <= resume_y + btn_h) {
        return .@"resume";
    }

    // Quit button bounds
    const quit_y = py + quit_y_offset;
    if (mx >= btn_x and mx <= btn_x + btn_w and my >= quit_y and my <= quit_y + btn_h) {
        return .quit;
    }

    return null;
}

// ── Tests ────────────────────────────────────────────────────────────

test "render returns more vertices than start index" {
    var buf: [max_vertices]UiVertex = undefined;
    const count = render(&buf, 0, 1920.0, 1080.0);
    try std.testing.expect(count > 0);
    try std.testing.expect(count % 6 == 0);
}

test "render with start offset preserves offset" {
    var buf: [max_vertices]UiVertex = undefined;
    const count = render(&buf, 12, 800.0, 600.0);
    try std.testing.expect(count >= 12);
    try std.testing.expect((count - 12) % 6 == 0);
}

test "overlay covers full screen" {
    var buf: [max_vertices]UiVertex = undefined;
    const sw: f32 = 1024.0;
    const sh: f32 = 768.0;
    _ = render(&buf, 0, sw, sh);
    // First quad is the overlay; check it spans the full screen
    try std.testing.expectApproxEqAbs(buf[0].pos_x, 0.0, 0.01);
    try std.testing.expectApproxEqAbs(buf[0].pos_y, 0.0, 0.01);
    // Vertex index 1 should be at (sw, 0)
    try std.testing.expectApproxEqAbs(buf[1].pos_x, sw, 0.01);
    try std.testing.expectApproxEqAbs(buf[1].pos_y, 0.0, 0.01);
    // Check overlay alpha
    try std.testing.expectApproxEqAbs(buf[0].a, 0.55, 0.01);
}

test "panel is centered on screen" {
    var buf: [max_vertices]UiVertex = undefined;
    const sw: f32 = 800.0;
    const sh: f32 = 600.0;
    _ = render(&buf, 0, sw, sh);
    // After overlay (6 verts) and top border (6 verts) starts at index 6
    // The top border x should be (800-300)/2 - 2 = 248
    const expected_border_x = (sw - panel_w) * 0.5 - 2.0;
    try std.testing.expectApproxEqAbs(buf[6].pos_x, expected_border_x, 0.01);
}

test "addQuad emits 6 vertices with u=-1, v=-1" {
    var buf: [6]UiVertex = undefined;
    const after = addQuad(&buf, 0, 10.0, 20.0, 50.0, 30.0, .{ .r = 1, .g = 0, .b = 0, .a = 1 });
    try std.testing.expectEqual(@as(u32, 6), after);
    try std.testing.expectApproxEqAbs(buf[0].pos_x, 10.0, 0.01);
    try std.testing.expectApproxEqAbs(buf[0].pos_y, 20.0, 0.01);
    try std.testing.expectApproxEqAbs(buf[0].u, -1.0, 0.01);
    try std.testing.expectApproxEqAbs(buf[0].v, -1.0, 0.01);
}

test "addQuad overflow protection" {
    var buf: [4]UiVertex = undefined;
    const after = addQuad(&buf, 0, 0, 0, 10, 10, .{ .r = 0, .g = 0, .b = 0, .a = 1 });
    // Buffer too small; should return unchanged index
    try std.testing.expectEqual(@as(u32, 0), after);
}

test "hitTest returns resume for click on resume button" {
    const sw: f32 = 800.0;
    const sh: f32 = 600.0;
    const px = (sw - panel_w) * 0.5;
    const py = (sh - panel_h) * 0.5;
    const btn_x = px + (panel_w - btn_w) * 0.5;
    // Center of resume button
    const mx = btn_x + btn_w * 0.5;
    const my = py + resume_y_offset + btn_h * 0.5;
    const result = hitTest(mx, my, sw, sh);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(Button.@"resume", result.?);
}

test "hitTest returns quit for click on quit button" {
    const sw: f32 = 800.0;
    const sh: f32 = 600.0;
    const px = (sw - panel_w) * 0.5;
    const py = (sh - panel_h) * 0.5;
    const btn_x = px + (panel_w - btn_w) * 0.5;
    // Center of quit button
    const mx = btn_x + btn_w * 0.5;
    const my = py + quit_y_offset + btn_h * 0.5;
    const result = hitTest(mx, my, sw, sh);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(Button.quit, result.?);
}

test "hitTest returns null for click outside buttons" {
    const sw: f32 = 800.0;
    const sh: f32 = 600.0;
    // Click in the top-left corner, far from any button
    try std.testing.expectEqual(@as(?Button, null), hitTest(10.0, 10.0, sw, sh));
    // Click between the two buttons
    const py = (sh - panel_h) * 0.5;
    const gap_y = py + resume_y_offset + btn_h + 5.0;
    try std.testing.expectEqual(@as(?Button, null), hitTest(sw * 0.5, gap_y, sw, sh));
}

test "hitTest at button edges" {
    const sw: f32 = 800.0;
    const sh: f32 = 600.0;
    const px = (sw - panel_w) * 0.5;
    const py = (sh - panel_h) * 0.5;
    const btn_x = px + (panel_w - btn_w) * 0.5;

    // Exact top-left corner of resume button
    const result_tl = hitTest(btn_x, py + resume_y_offset, sw, sh);
    try std.testing.expectEqual(Button.@"resume", result_tl.?);

    // Exact bottom-right corner of quit button
    const result_br = hitTest(btn_x + btn_w, py + quit_y_offset + btn_h, sw, sh);
    try std.testing.expectEqual(Button.quit, result_br.?);

    // Just outside resume button (1 pixel left)
    const result_out = hitTest(btn_x - 1.0, py + resume_y_offset, sw, sh);
    try std.testing.expectEqual(@as(?Button, null), result_out);
}

test "render does not overflow small buffer" {
    var buf: [12]UiVertex = undefined;
    const count = render(&buf, 0, 800.0, 600.0);
    try std.testing.expect(count <= 12);
}

test "render produces consistent output for same inputs" {
    var buf1: [max_vertices]UiVertex = undefined;
    var buf2: [max_vertices]UiVertex = undefined;
    const count1 = render(&buf1, 0, 1280.0, 720.0);
    const count2 = render(&buf2, 0, 1280.0, 720.0);
    try std.testing.expectEqual(count1, count2);
    // Spot-check a few vertices for equality
    for (0..@min(count1, 30)) |i| {
        try std.testing.expectApproxEqAbs(buf1[i].pos_x, buf2[i].pos_x, 0.001);
        try std.testing.expectApproxEqAbs(buf1[i].pos_y, buf2[i].pos_y, 0.001);
    }
}
