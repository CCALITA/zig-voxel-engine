/// Compact XYZ position display (smaller than the F3 debug overlay).
/// Renders three rows in the top-left corner — one per axis — each with a
/// colour-coded indicator dot followed by the coordinate value.
/// Dot colours: X = red, Y = green, Z = blue.
///
/// Self-contained: defines its own `UiVertex` matching the UI pipeline layout
/// (pos.xy, rgba, uv). Untextured quads use `u = -1, v = -1` so the fragment
/// shader takes the solid-colour branch.
const std = @import("std");
const bitmap_font = @import("bitmap_font");

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

const margin_x: f32 = 6.0;
const margin_y: f32 = 6.0;
const row_height: f32 = 12.0;
const pixel_scale: f32 = 1.5;
const digit_spacing: f32 = 1.0;
const bg_pad_x: f32 = 3.0;
const bg_pad_y: f32 = 2.0;
const dot_size: f32 = 4.0;
const dot_gap: f32 = 3.0;

// ── Colours ────────────────────────────────────────────────────────────

const bg_col = [4]f32{ 0.0, 0.0, 0.0, 0.45 };
const text_col = [4]f32{ 1.0, 1.0, 1.0, 1.0 };
const neg_col = [4]f32{ 1.0, 0.4, 0.4, 1.0 };
const dot_x_col = [4]f32{ 1.0, 0.3, 0.3, 1.0 }; // red
const dot_y_col = [4]f32{ 0.3, 1.0, 0.3, 1.0 }; // green
const dot_z_col = [4]f32{ 0.3, 0.5, 1.0, 1.0 }; // blue

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

// ── Number drawing helpers ─────────────────────────────────────────────

const char_w = @as(f32, @floatFromInt(bitmap_font.GLYPH_W)) * pixel_scale + digit_spacing * pixel_scale;
const glyph_h_px = @as(f32, @floatFromInt(bitmap_font.GLYPH_H)) * pixel_scale;

/// Compute the pixel width of a signed number at the current scale.
fn signedWidth(value: i32) f32 {
    const abs_val: u32 = if (value < 0) @intCast(-@as(i64, value)) else @intCast(value);
    var w = @as(f32, @floatFromInt(bitmap_font.digitCount(abs_val))) * char_w;
    if (value < 0) {
        w += 2.0 * pixel_scale + digit_spacing * pixel_scale;
    }
    return w;
}

/// Draw an unsigned number at (x, y) using the bitmap font. Returns new index.
fn drawNumber(verts: []UiVertex, start: u32, x: f32, y: f32, value: u32, col: [4]f32) u32 {
    var c = start;
    const num_digits = bitmap_font.digitCount(value);

    var di: u32 = 0;
    while (di < num_digits) : (di += 1) {
        const digit = bitmap_font.getDigit(value, num_digits - 1 - di);
        const dx = x + @as(f32, @floatFromInt(di)) * char_w;
        var py: u32 = 0;
        while (py < bitmap_font.GLYPH_H) : (py += 1) {
            var px: u32 = 0;
            while (px < bitmap_font.GLYPH_W) : (px += 1) {
                if (bitmap_font.getPixel(digit, px, py)) {
                    c = addQuad(
                        verts,
                        c,
                        dx + @as(f32, @floatFromInt(px)) * pixel_scale,
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
/// Returns the new vertex index.
fn drawSigned(verts: []UiVertex, start: u32, x: f32, y: f32, value: i32) u32 {
    var c = start;
    var cursor_x = x;

    if (value < 0) {
        const bar_y = y + 2.0 * pixel_scale;
        c = addQuad(verts, c, cursor_x, bar_y, 2.0 * pixel_scale, pixel_scale, neg_col);
        cursor_x += 2.0 * pixel_scale + digit_spacing * pixel_scale;
    }

    const abs_val: u32 = if (value < 0) @intCast(-@as(i64, value)) else @intCast(value);
    const col = if (value < 0) neg_col else text_col;
    c = drawNumber(verts, c, cursor_x, y, abs_val, col);
    return c;
}

// ── Row rendering ──────────────────────────────────────────────────────

/// Draw one coordinate row: background strip, colour dot, signed number.
fn drawRow(verts: []UiVertex, start: u32, x: f32, y: f32, value: i32, dot_col: [4]f32) u32 {
    var c = start;

    // Compute content width: dot + gap + number
    const num_w = signedWidth(value);
    const content_w = dot_size + dot_gap + num_w;
    const strip_w = content_w + bg_pad_x * 2.0;
    const strip_h = glyph_h_px + bg_pad_y * 2.0;

    // Semi-transparent background
    c = addQuad(verts, c, x, y, strip_w, strip_h, bg_col);

    // Colour indicator dot — vertically centred within the strip
    const dot_y = y + (strip_h - dot_size) * 0.5;
    c = addQuad(verts, c, x + bg_pad_x, dot_y, dot_size, dot_size, dot_col);

    // Signed coordinate number
    const text_x = x + bg_pad_x + dot_size + dot_gap;
    const text_y = y + bg_pad_y;
    c = drawSigned(verts, c, text_x, text_y, value);

    return c;
}

// ── Public render entry point ──────────────────────────────────────────

/// Render the compact XYZ coordinate display into the vertex buffer.
/// Draws three rows in the top-left corner of the screen.
/// Returns the final vertex index (vertices written from `start` to return value).
pub fn render(
    verts: []UiVertex,
    start: u32,
    sw: f32,
    sh: f32,
    px: i32,
    py: i32,
    pz: i32,
) u32 {
    _ = sw;
    _ = sh;
    var c = start;
    var line_y = margin_y;

    c = drawRow(verts, c, margin_x, line_y, px, dot_x_col);
    line_y += row_height;

    c = drawRow(verts, c, margin_x, line_y, py, dot_y_col);
    line_y += row_height;

    c = drawRow(verts, c, margin_x, line_y, pz, dot_z_col);

    return c;
}

// ── Tests ──────────────────────────────────────────────────────────────

const testing = std.testing;

test "UiVertex layout is 32 bytes (8 x f32)" {
    try testing.expectEqual(@as(usize, 32), @sizeOf(UiVertex));
    try testing.expectEqual(@as(usize, 8), @sizeOf(UiVertex) / @sizeOf(f32));
}

test "addQuad emits 6 vertices with u=-1 v=-1" {
    var buf: [6]UiVertex = undefined;
    const c = addQuad(&buf, 0, 5, 10, 20, 30, .{ 1, 0.5, 0.25, 0.75 });
    try testing.expectEqual(@as(u32, 6), c);
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
    var buf: [4096]UiVertex = undefined;
    const c = render(&buf, 0, 800.0, 600.0, 100, 64, -200);
    try testing.expect(c > 0);
    try testing.expect(c % 6 == 0);
}

test "render with start offset preserves offset and produces whole quads" {
    var buf: [4096]UiVertex = undefined;
    const c = render(&buf, 42, 1920.0, 1080.0, -50, 256, 0);
    try testing.expect(c >= 42);
    try testing.expect((c - 42) % 6 == 0);
}

test "negative coordinates produce more vertices than positive (minus sign)" {
    var buf1: [4096]UiVertex = undefined;
    const c_neg = render(&buf1, 0, 800.0, 600.0, -100, -64, -200);
    var buf2: [4096]UiVertex = undefined;
    const c_pos = render(&buf2, 0, 800.0, 600.0, 100, 64, 200);
    try testing.expect(c_neg > c_pos);
}

test "render produces at least 3 background quads (one per row)" {
    var buf: [4096]UiVertex = undefined;
    const c = render(&buf, 0, 800.0, 600.0, 0, 0, 0);
    // 3 bg quads + 3 dot quads + digit quads for three zeros
    // minimum = 6 quads * 6 verts = 36
    try testing.expect(c >= 36);
}

test "render does not overflow a small buffer" {
    var buf: [12]UiVertex = undefined;
    const c = render(&buf, 0, 800.0, 600.0, 999, 999, 999);
    try testing.expect(c <= 12);
}

test "drawNumber renders correct pixel quads for value 42" {
    var buf: [1024]UiVertex = undefined;
    const c = drawNumber(&buf, 0, 0, 0, 42, text_col);
    // digit 4 = 0b101_101_111_001_001 => 9 lit pixels
    // digit 2 = 0b111_001_111_100_111 => 11 lit pixels
    // Total = 20 quads * 6 verts = 120
    try testing.expectEqual(@as(u32, 120), c);
}

test "signedWidth accounts for minus sign" {
    const w_pos = signedWidth(42);
    const w_neg = signedWidth(-42);
    try testing.expect(w_neg > w_pos);
}

test "each row has a coloured dot as second quad" {
    var buf: [4096]UiVertex = undefined;
    _ = render(&buf, 0, 800.0, 600.0, 10, 20, 30);
    // First quad is row-0 background (bg_col alpha=0.45), second is the red dot.
    // The red dot quad starts at index 6.
    try testing.expectApproxEqAbs(dot_x_col[0], buf[6].r, 0.01);
    try testing.expectApproxEqAbs(dot_x_col[1], buf[6].g, 0.01);
    try testing.expectApproxEqAbs(dot_x_col[2], buf[6].b, 0.01);
}
