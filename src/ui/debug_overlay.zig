/// F3 debug overlay renderer.
/// Renders live stats on the left side of the screen: FPS, player coordinates,
/// chunk position, loaded chunk count, entity count, and current dimension.
/// Each line is a dark background strip with bitmap-font numbers.
///
/// Self-contained: defines its own `UiVertex` matching the UI pipeline layout
/// (pos.xy, rgba, uv). Untextured quads use `u = -1, v = -1` so the fragment
/// shader takes the solid-colour branch.
const std = @import("std");
const bitmap_font = @import("../renderer/bitmap_font.zig");

// ── Vertex type (mirrors ui_pipeline.UiVertex) ─────────────────────────

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

// ── Layout constants ───────────────────────────────────────────────────

const margin_x: f32 = 10.0;
const margin_y: f32 = 10.0;
const line_height: f32 = 16.0;
const pixel_scale: f32 = 2.0;
const digit_spacing: f32 = 1.0;
const bg_pad_x: f32 = 4.0;
const bg_pad_y: f32 = 2.0;

// ── Colours ────────────────────────────────────────────────────────────

const bg_col = [4]f32{ 0.0, 0.0, 0.0, 0.55 };
const text_col = [4]f32{ 1.0, 1.0, 1.0, 1.0 };
const label_col = [4]f32{ 0.7, 0.7, 0.7, 1.0 };
const neg_col = [4]f32{ 1.0, 0.4, 0.4, 1.0 };

// ── Letter glyphs (3x5 bitmasks, same encoding as bitmap_font digits) ──

const LetterGlyph = u15;

const letter_F: LetterGlyph = 0b111_100_110_100_100;
const letter_P: LetterGlyph = 0b111_101_111_100_100;
const letter_S: LetterGlyph = 0b111_100_111_001_111;
const letter_X: LetterGlyph = 0b101_101_010_101_101;
const letter_Y: LetterGlyph = 0b101_101_010_010_010;
const letter_Z: LetterGlyph = 0b111_001_010_100_111;
const letter_C: LetterGlyph = 0b111_100_100_100_111;
const letter_H: LetterGlyph = 0b101_101_111_101_101;
const letter_K: LetterGlyph = 0b101_110_100_110_101;
const letter_L: LetterGlyph = 0b100_100_100_100_111;
const letter_D: LetterGlyph = 0b110_101_101_101_110;
const letter_E: LetterGlyph = 0b111_100_110_100_111;
const letter_N: LetterGlyph = 0b101_111_111_101_101;
const letter_T: LetterGlyph = 0b111_010_010_010_010;
const letter_I: LetterGlyph = 0b111_010_010_010_111;
const letter_O: LetterGlyph = 0b010_101_101_101_010;

fn getLetterPixel(glyph: LetterGlyph, x: u32, y: u32) bool {
    if (x >= 3 or y >= 5) return false;
    const bit_index: u4 = @intCast(y * 3 + x);
    return (glyph >> (14 - bit_index)) & 1 == 1;
}

// ── Label definitions ──────────────────────────────────────────────────

const label_fps = [_]LetterGlyph{ letter_F, letter_P, letter_S };
const label_x = [_]LetterGlyph{letter_X};
const label_y = [_]LetterGlyph{letter_Y};
const label_z = [_]LetterGlyph{letter_Z};
const label_chk = [_]LetterGlyph{ letter_C, letter_H, letter_K };
const label_ldc = [_]LetterGlyph{ letter_L, letter_D, letter_C };
const label_ent = [_]LetterGlyph{ letter_E, letter_N, letter_T };
const label_dim = [_]LetterGlyph{ letter_D, letter_I, letter_O };

// ── Quad helper ────────────────────────────────────────────────────────

/// Emit a solid-colour quad (2 triangles, 6 vertices). UV = -1 (untextured).
fn addQuad(verts: []UiVertex, start: u32, x: f32, y: f32, w: f32, h: f32, col: [4]f32) u32 {
    if (start + 6 > verts.len) return start;
    const x1 = x + w;
    const y1 = y + h;
    const r = col[0];
    const g = col[1];
    const b = col[2];
    const a = col[3];

    verts[start + 0] = .{ .pos_x = x, .pos_y = y, .r = r, .g = g, .b = b, .a = a, .u = -1, .v = -1 };
    verts[start + 1] = .{ .pos_x = x1, .pos_y = y, .r = r, .g = g, .b = b, .a = a, .u = -1, .v = -1 };
    verts[start + 2] = .{ .pos_x = x1, .pos_y = y1, .r = r, .g = g, .b = b, .a = a, .u = -1, .v = -1 };
    verts[start + 3] = .{ .pos_x = x, .pos_y = y, .r = r, .g = g, .b = b, .a = a, .u = -1, .v = -1 };
    verts[start + 4] = .{ .pos_x = x1, .pos_y = y1, .r = r, .g = g, .b = b, .a = a, .u = -1, .v = -1 };
    verts[start + 5] = .{ .pos_x = x, .pos_y = y1, .r = r, .g = g, .b = b, .a = a, .u = -1, .v = -1 };

    return start + 6;
}

// ── Text drawing helpers ───────────────────────────────────────────────

/// Draw a single letter glyph at (x, y) and return the new vertex index.
fn drawLetter(verts: []UiVertex, start: u32, x: f32, y: f32, glyph: LetterGlyph, col: [4]f32) u32 {
    var c = start;
    var py: u32 = 0;
    while (py < bitmap_font.GLYPH_H) : (py += 1) {
        var px_i: u32 = 0;
        while (px_i < bitmap_font.GLYPH_W) : (px_i += 1) {
            if (getLetterPixel(glyph, px_i, py)) {
                c = addQuad(
                    verts,
                    c,
                    x + @as(f32, @floatFromInt(px_i)) * pixel_scale,
                    y + @as(f32, @floatFromInt(py)) * pixel_scale,
                    pixel_scale,
                    pixel_scale,
                    col,
                );
            }
        }
    }
    return c;
}

/// Draw a label (array of letter glyphs) at (x, y). Returns new vertex index.
fn drawLabel(verts: []UiVertex, start: u32, x: f32, y: f32, glyphs: []const LetterGlyph) u32 {
    var c = start;
    const char_w = @as(f32, @floatFromInt(bitmap_font.GLYPH_W)) * pixel_scale + digit_spacing * pixel_scale;
    for (glyphs, 0..) |glyph, i| {
        c = drawLetter(verts, c, x + @as(f32, @floatFromInt(i)) * char_w, y, glyph, label_col);
    }
    return c;
}

/// Draw an unsigned number at (x, y) using the bitmap font. Returns new index.
fn drawNumber(verts: []UiVertex, start: u32, x: f32, y: f32, value: u32, col: [4]f32) u32 {
    var c = start;
    const num_digits = bitmap_font.digitCount(value);
    const char_w = @as(f32, @floatFromInt(bitmap_font.GLYPH_W)) * pixel_scale + digit_spacing * pixel_scale;

    var di: u32 = 0;
    while (di < num_digits) : (di += 1) {
        const digit = bitmap_font.getDigit(value, num_digits - 1 - di);
        const dx = x + @as(f32, @floatFromInt(di)) * char_w;
        var py: u32 = 0;
        while (py < bitmap_font.GLYPH_H) : (py += 1) {
            var px_i: u32 = 0;
            while (px_i < bitmap_font.GLYPH_W) : (px_i += 1) {
                if (bitmap_font.getPixel(digit, px_i, py)) {
                    c = addQuad(
                        verts,
                        c,
                        dx + @as(f32, @floatFromInt(px_i)) * pixel_scale,
                        y + @as(f32, @floatFromInt(py)) * pixel_scale,
                        pixel_scale,
                        pixel_scale,
                        col,
                    );
                }
            }
        }
    }
    return c;
}

/// Draw a signed integer (optional "-" prefix then absolute value).
fn drawSigned(verts: []UiVertex, start: u32, x: f32, y: f32, value: i32) struct { idx: u32, w: f32 } {
    var c = start;
    var cursor_x = x;
    const char_w = @as(f32, @floatFromInt(bitmap_font.GLYPH_W)) * pixel_scale + digit_spacing * pixel_scale;

    if (value < 0) {
        // Draw minus sign: a horizontal bar at the middle row
        const bar_y = y + 2.0 * pixel_scale;
        c = addQuad(verts, c, cursor_x, bar_y, 2.0 * pixel_scale, pixel_scale, neg_col);
        cursor_x += 2.0 * pixel_scale + digit_spacing * pixel_scale;
    }

    const abs_val: u32 = if (value < 0) @intCast(-@as(i64, value)) else @intCast(value);
    const col = if (value < 0) neg_col else text_col;
    c = drawNumber(verts, c, cursor_x, y, abs_val, col);

    const num_digits = bitmap_font.digitCount(abs_val);
    const num_w = @as(f32, @floatFromInt(num_digits)) * char_w;
    const total_w = (cursor_x - x) + num_w;

    return .{ .idx = c, .w = total_w };
}

/// Compute the pixel width of a label.
fn labelWidth(count: usize) f32 {
    const char_w = @as(f32, @floatFromInt(bitmap_font.GLYPH_W)) * pixel_scale + digit_spacing * pixel_scale;
    return @as(f32, @floatFromInt(count)) * char_w;
}

/// Compute the pixel width of an unsigned number.
fn numberWidth(value: u32) f32 {
    const char_w = @as(f32, @floatFromInt(bitmap_font.GLYPH_W)) * pixel_scale + digit_spacing * pixel_scale;
    return @as(f32, @floatFromInt(bitmap_font.digitCount(value))) * char_w;
}

/// Compute the pixel width of a signed number.
fn signedWidth(value: i32) f32 {
    const char_w = @as(f32, @floatFromInt(bitmap_font.GLYPH_W)) * pixel_scale + digit_spacing * pixel_scale;
    const abs_val: u32 = if (value < 0) @intCast(-@as(i64, value)) else @intCast(value);
    var w = @as(f32, @floatFromInt(bitmap_font.digitCount(abs_val))) * char_w;
    if (value < 0) {
        w += 2.0 * pixel_scale + digit_spacing * pixel_scale;
    }
    return w;
}

// ── Line rendering ─────────────────────────────────────────────────────

const glyph_h_px = @as(f32, @floatFromInt(bitmap_font.GLYPH_H)) * pixel_scale;
const colon_gap: f32 = 6.0;

/// Draw a "LABEL: <unsigned>" line with a dark background strip.
fn drawUnsignedLine(
    verts: []UiVertex,
    start: u32,
    x: f32,
    y: f32,
    sw: f32,
    label: []const LetterGlyph,
    value: u32,
) u32 {
    _ = sw;
    var c = start;
    const lbl_w = labelWidth(label.len);
    const num_w = numberWidth(value);
    const content_w = lbl_w + colon_gap + num_w;
    const strip_w = content_w + bg_pad_x * 2.0;
    const strip_h = glyph_h_px + bg_pad_y * 2.0;

    c = addQuad(verts, c, x, y, strip_w, strip_h, bg_col);
    c = drawLabel(verts, c, x + bg_pad_x, y + bg_pad_y, label);
    c = drawNumber(verts, c, x + bg_pad_x + lbl_w + colon_gap, y + bg_pad_y, value, text_col);
    return c;
}

/// Draw a "LABEL: <signed>" line with a dark background strip.
fn drawSignedLine(
    verts: []UiVertex,
    start: u32,
    x: f32,
    y: f32,
    sw: f32,
    label: []const LetterGlyph,
    value: i32,
) u32 {
    _ = sw;
    var c = start;
    const lbl_w = labelWidth(label.len);
    const num_w = signedWidth(value);
    const content_w = lbl_w + colon_gap + num_w;
    const strip_w = content_w + bg_pad_x * 2.0;
    const strip_h = glyph_h_px + bg_pad_y * 2.0;

    c = addQuad(verts, c, x, y, strip_w, strip_h, bg_col);
    c = drawLabel(verts, c, x + bg_pad_x, y + bg_pad_y, label);
    const result = drawSigned(verts, c, x + bg_pad_x + lbl_w + colon_gap, y + bg_pad_y, value);
    c = result.idx;
    return c;
}

/// Draw a "CHK: cx, cz" line (two signed values).
fn drawChunkLine(
    verts: []UiVertex,
    start: u32,
    x: f32,
    y: f32,
    sw: f32,
    cx_val: i32,
    cz_val: i32,
) u32 {
    _ = sw;
    var c = start;
    const lbl_w = labelWidth(label_chk.len);
    const comma_gap: f32 = 6.0;
    const cx_w = signedWidth(cx_val);
    const cz_w = signedWidth(cz_val);
    const content_w = lbl_w + colon_gap + cx_w + comma_gap + cz_w;
    const strip_w = content_w + bg_pad_x * 2.0;
    const strip_h = glyph_h_px + bg_pad_y * 2.0;

    c = addQuad(verts, c, x, y, strip_w, strip_h, bg_col);
    c = drawLabel(verts, c, x + bg_pad_x, y + bg_pad_y, &label_chk);

    var cursor = x + bg_pad_x + lbl_w + colon_gap;
    const r1 = drawSigned(verts, c, cursor, y + bg_pad_y, cx_val);
    c = r1.idx;
    cursor += r1.w + comma_gap;
    const r2 = drawSigned(verts, c, cursor, y + bg_pad_y, cz_val);
    c = r2.idx;
    return c;
}

// ── Public render entry point ──────────────────────────────────────────

/// Render the F3 debug overlay into the vertex buffer.
/// Returns the final vertex index (vertices written from `start` to return value).
pub fn render(
    verts: []UiVertex,
    start: u32,
    sw: f32,
    sh: f32,
    fps: u32,
    px: i32,
    py: i32,
    pz: i32,
    cx: i32,
    cz: i32,
    chunks: u32,
    entities: u32,
    dim: u8,
) u32 {
    _ = sh;
    var c = start;
    var line_y = margin_y;

    // Line 1: FPS
    c = drawUnsignedLine(verts, c, margin_x, line_y, sw, &label_fps, fps);
    line_y += line_height;

    // Line 2: X coordinate
    c = drawSignedLine(verts, c, margin_x, line_y, sw, &label_x, px);
    line_y += line_height;

    // Line 3: Y coordinate
    c = drawSignedLine(verts, c, margin_x, line_y, sw, &label_y, py);
    line_y += line_height;

    // Line 4: Z coordinate
    c = drawSignedLine(verts, c, margin_x, line_y, sw, &label_z, pz);
    line_y += line_height;

    // Line 5: Chunk position
    c = drawChunkLine(verts, c, margin_x, line_y, sw, cx, cz);
    line_y += line_height;

    // Line 6: Loaded chunks
    c = drawUnsignedLine(verts, c, margin_x, line_y, sw, &label_ldc, chunks);
    line_y += line_height;

    // Line 7: Entity count
    c = drawUnsignedLine(verts, c, margin_x, line_y, sw, &label_ent, entities);
    line_y += line_height;

    // Line 8: Dimension (0=overworld, 1=nether, 2=end)
    c = drawUnsignedLine(verts, c, margin_x, line_y, sw, &label_dim, @as(u32, dim));

    return c;
}

// ── Tests ──────────────────────────────────────────────────────────────

const testing = std.testing;

test "UiVertex layout is 32 bytes (8 x f32)" {
    try testing.expectEqual(@as(usize, 32), @sizeOf(UiVertex));
    try testing.expectEqual(@as(usize, 8), @sizeOf(UiVertex) / @sizeOf(f32));
}

test "addQuad emits 6 vertices with u=-1, v=-1" {
    var buf: [6]UiVertex = undefined;
    const c = addQuad(&buf, 0, 10, 20, 30, 40, .{ 1, 0.5, 0.25, 0.75 });
    try testing.expectEqual(@as(u32, 6), c);
    try testing.expectApproxEqAbs(@as(f32, 10.0), buf[0].pos_x, 0.01);
    try testing.expectApproxEqAbs(@as(f32, 20.0), buf[0].pos_y, 0.01);
    // Bottom-right corner
    try testing.expectApproxEqAbs(@as(f32, 40.0), buf[2].pos_x, 0.01);
    try testing.expectApproxEqAbs(@as(f32, 60.0), buf[2].pos_y, 0.01);
    for (buf) |v| {
        try testing.expectEqual(@as(f32, -1), v.u);
        try testing.expectEqual(@as(f32, -1), v.v);
    }
}

test "addQuad guards against buffer overflow" {
    var buf: [3]UiVertex = undefined;
    const c = addQuad(&buf, 0, 0, 0, 1, 1, .{ 0, 0, 0, 1 });
    try testing.expectEqual(@as(u32, 0), c);
}

test "render returns more vertices than start and produces whole quads" {
    var buf: [8192]UiVertex = undefined;
    const c = render(&buf, 0, 800.0, 600.0, 60, 100, 64, -200, 6, -12, 128, 42, 0);
    try testing.expect(c > 0);
    try testing.expect(c % 6 == 0);
}

test "render with start offset preserves offset" {
    var buf: [8192]UiVertex = undefined;
    const c = render(&buf, 42, 1920.0, 1080.0, 30, -50, 256, 0, -3, 0, 64, 10, 1);
    try testing.expect(c >= 42);
    try testing.expect((c - 42) % 6 == 0);
}

test "render with negative coordinates produces valid output" {
    var buf: [8192]UiVertex = undefined;
    const c = render(&buf, 0, 800.0, 600.0, 120, -999, -64, -1, -62, 0, 0, 0, 2);
    try testing.expect(c > 0);
    // Negative values require more quads (minus sign) than positive
    var buf2: [8192]UiVertex = undefined;
    const c2 = render(&buf2, 0, 800.0, 600.0, 120, 999, 64, 1, 62, 0, 0, 0, 2);
    try testing.expect(c > c2);
}

test "drawNumber renders correct count of pixel quads for value 42" {
    var buf: [1024]UiVertex = undefined;
    const c = drawNumber(&buf, 0, 0, 0, 42, text_col);
    // 42 has 2 digits; each digit is a 3x5 grid of pixels. Count lit pixels.
    // digit 4 = 0b101_101_111_001_001 => 9 lit pixels
    // digit 2 = 0b111_001_111_100_111 => 11 lit pixels
    // Total = 20 quads * 6 verts = 120
    try testing.expectEqual(@as(u32, 120), c);
}

test "drawSigned handles zero" {
    var buf: [1024]UiVertex = undefined;
    const result = drawSigned(&buf, 0, 0, 0, 0);
    try testing.expect(result.idx > 0);
    try testing.expect(result.w > 0);
}

test "render does not crash with tiny buffer" {
    var buf: [12]UiVertex = undefined;
    const c = render(&buf, 0, 800.0, 600.0, 60, 0, 0, 0, 0, 0, 0, 0, 0);
    try testing.expect(c <= 12);
}

test "all dimension values produce valid output" {
    var buf: [8192]UiVertex = undefined;
    const c0 = render(&buf, 0, 800.0, 600.0, 60, 0, 0, 0, 0, 0, 16, 5, 0);
    const c1 = render(&buf, 0, 800.0, 600.0, 60, 0, 0, 0, 0, 0, 16, 5, 1);
    const c2 = render(&buf, 0, 800.0, 600.0, 60, 0, 0, 0, 0, 0, 16, 5, 2);
    try testing.expect(c0 > 0);
    try testing.expect(c1 > 0);
    try testing.expect(c2 > 0);
    // All same coordinates => same vertex count regardless of dimension digit
    // (0, 1, 2 all have the same number of lit pixels: 11, 7, 9 respectively)
    // so counts may differ slightly but all should be valid
}

test "getLetterPixel returns correct bits for letter F" {
    // letter_F = 0b111_100_110_100_100
    // Row 0: all lit
    try testing.expect(getLetterPixel(letter_F, 0, 0));
    try testing.expect(getLetterPixel(letter_F, 1, 0));
    try testing.expect(getLetterPixel(letter_F, 2, 0));
    // Row 4 (bottom): only left pixel lit
    try testing.expect(getLetterPixel(letter_F, 0, 4));
    try testing.expect(!getLetterPixel(letter_F, 1, 4));
    try testing.expect(!getLetterPixel(letter_F, 2, 4));
}
