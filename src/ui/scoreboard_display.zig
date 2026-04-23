/// Sidebar scoreboard display renderer.
/// Renders a right-aligned scoreboard panel with a title bar and score rows,
/// sorted by score descending. Each row shows a right-aligned score number
/// rendered via the bitmap font. Semi-transparent black background panel.
const std = @import("std");
const bitmap_font = @import("../renderer/bitmap_font.zig");

// ── Vertex type (mirrors ui_pipeline.UiVertex) ────────────────────────

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

// ── Score entry ───────────────────────────────────────────────────────

pub const ScoreEntry = struct {
    score: u32,
    color_r: f32 = 1,
    color_g: f32 = 1,
    color_b: f32 = 1,
};

// ── Layout constants ──────────────────────────────────────────────────

const panel_width: f32 = 120.0;
const margin_right: f32 = 8.0;
const margin_top: f32 = 8.0;
const row_height: f32 = 16.0;
const title_bar_height: f32 = 14.0;
const pad_x: f32 = 6.0;
const pad_y: f32 = 2.0;
const pixel_scale: f32 = 2.0;
const digit_spacing: f32 = 1.0;

// ── Colours ───────────────────────────────────────────────────────────

const bg_color = [4]f32{ 0.0, 0.0, 0.0, 0.45 };
const title_bar_color = [4]f32{ 0.2, 0.2, 0.2, 0.7 };

// ── Quad helper ───────────────────────────────────────────────────────

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

// ── Number drawing ────────────────────────────────────────────────────

/// Compute the pixel width of a number rendered at the current scale.
fn numberWidth(value: u32) f32 {
    const char_w = @as(f32, @floatFromInt(bitmap_font.GLYPH_W)) * pixel_scale + digit_spacing * pixel_scale;
    return @as(f32, @floatFromInt(bitmap_font.digitCount(value))) * char_w;
}

/// Draw a right-aligned number. `right_x` is the right edge; the number
/// is drawn leftward from that position. Returns the new vertex index.
fn drawNumber(verts: []UiVertex, start: u32, right_x: f32, y: f32, value: u32, col: [4]f32) u32 {
    var c = start;
    const num_digits = bitmap_font.digitCount(value);
    const char_w = @as(f32, @floatFromInt(bitmap_font.GLYPH_W)) * pixel_scale + digit_spacing * pixel_scale;
    const total_w = @as(f32, @floatFromInt(num_digits)) * char_w;
    const left_x = right_x - total_w;

    var di: u32 = 0;
    while (di < num_digits) : (di += 1) {
        const digit = bitmap_font.getDigit(value, num_digits - 1 - di);
        const dx = left_x + @as(f32, @floatFromInt(di)) * char_w;
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

// ── Sorting helper ────────────────────────────────────────────────────

/// Return a copy of the entries array sorted by score descending, with only
/// the first `count` slots populated. Non-populated slots remain null.
fn sortedEntries(entries: [15]?ScoreEntry, entry_count: u8) [15]?ScoreEntry {
    const count: usize = @min(entry_count, 15);

    // Collect non-null entries into a fixed buffer.
    var buf: [15]ScoreEntry = undefined;
    var n: usize = 0;
    for (entries[0..count]) |maybe| {
        if (maybe) |e| {
            buf[n] = e;
            n += 1;
        }
    }

    // Insertion sort descending by score.
    if (n > 1) {
        var i: usize = 1;
        while (i < n) : (i += 1) {
            const key = buf[i];
            var j: usize = i;
            while (j > 0 and buf[j - 1].score < key.score) : (j -= 1) {
                buf[j] = buf[j - 1];
            }
            buf[j] = key;
        }
    }

    // Rebuild the optional array.
    var result: [15]?ScoreEntry = .{null} ** 15;
    for (0..n) |i| {
        result[i] = buf[i];
    }
    return result;
}

// ── Public render entry point ─────────────────────────────────────────

/// Render the sidebar scoreboard into the vertex buffer.
/// Returns the final vertex index (vertices written from `start` to return value).
pub fn render(
    verts: []UiVertex,
    start: u32,
    sw: f32,
    sh: f32,
    entries: [15]?ScoreEntry,
    entry_count: u8,
) u32 {
    _ = sh;
    const sorted = sortedEntries(entries, entry_count);

    // Count visible rows.
    var visible: u32 = 0;
    for (sorted) |maybe| {
        if (maybe != null) visible += 1;
    }
    if (visible == 0) return start;

    var c = start;

    // Panel dimensions.
    const panel_h = title_bar_height + @as(f32, @floatFromInt(visible)) * row_height + pad_y * 2.0;
    const panel_x = sw - panel_width - margin_right;
    const panel_y = margin_top;

    // Background panel.
    c = addQuad(verts, c, panel_x, panel_y, panel_width, panel_h, bg_color);

    // Title bar at top.
    c = addQuad(verts, c, panel_x, panel_y, panel_width, title_bar_height, title_bar_color);

    // Score rows.
    const right_edge = panel_x + panel_width - pad_x;
    var row: u32 = 0;
    for (sorted) |maybe| {
        const entry = maybe orelse continue;
        const row_y = panel_y + title_bar_height + pad_y + @as(f32, @floatFromInt(row)) * row_height;
        const text_y = row_y + (row_height - @as(f32, @floatFromInt(bitmap_font.GLYPH_H)) * pixel_scale) * 0.5;
        c = drawNumber(verts, c, right_edge, text_y, entry.score, .{ entry.color_r, entry.color_g, entry.color_b, 1.0 });
        row += 1;
    }

    return c;
}

// ── Tests ─────────────────────────────────────────────────────────────

const testing = std.testing;

test "render returns start when no entries are provided" {
    var buf: [4096]UiVertex = undefined;
    const entries: [15]?ScoreEntry = .{null} ** 15;
    const c = render(&buf, 0, 800.0, 600.0, entries, 0);
    try testing.expectEqual(@as(u32, 0), c);
}

test "render produces quads for a single entry" {
    var buf: [4096]UiVertex = undefined;
    var entries: [15]?ScoreEntry = .{null} ** 15;
    entries[0] = .{ .score = 42 };
    const c = render(&buf, 0, 800.0, 600.0, entries, 1);
    // At minimum: bg panel quad + title bar quad + score digit quads
    try testing.expect(c > 0);
    try testing.expect(c % 6 == 0);
    // Must have at least 2 background quads (panel + title) = 12 verts + digit verts
    try testing.expect(c >= 12);
}

test "entries are sorted by score descending" {
    var entries: [15]?ScoreEntry = .{null} ** 15;
    entries[0] = .{ .score = 10 };
    entries[1] = .{ .score = 50 };
    entries[2] = .{ .score = 30 };
    const sorted = sortedEntries(entries, 3);
    try testing.expectEqual(@as(u32, 50), sorted[0].?.score);
    try testing.expectEqual(@as(u32, 30), sorted[1].?.score);
    try testing.expectEqual(@as(u32, 10), sorted[2].?.score);
    try testing.expect(sorted[3] == null);
}

test "render respects start offset and produces whole quads" {
    var buf: [4096]UiVertex = undefined;
    var entries: [15]?ScoreEntry = .{null} ** 15;
    entries[0] = .{ .score = 100, .color_r = 0.0, .color_g = 1.0, .color_b = 0.0 };
    const offset: u32 = 24;
    const c = render(&buf, offset, 1920.0, 1080.0, entries, 1);
    try testing.expect(c >= offset);
    try testing.expect((c - offset) % 6 == 0);
}

test "more entries produce more vertices" {
    var buf1: [4096]UiVertex = undefined;
    var entries1: [15]?ScoreEntry = .{null} ** 15;
    entries1[0] = .{ .score = 5 };
    const c1 = render(&buf1, 0, 800.0, 600.0, entries1, 1);

    var buf2: [4096]UiVertex = undefined;
    var entries2: [15]?ScoreEntry = .{null} ** 15;
    entries2[0] = .{ .score = 5 };
    entries2[1] = .{ .score = 10 };
    entries2[2] = .{ .score = 15 };
    const c2 = render(&buf2, 0, 800.0, 600.0, entries2, 3);

    try testing.expect(c2 > c1);
}

test "addQuad writes UV as negative one" {
    var buf: [6]UiVertex = undefined;
    const c = addQuad(&buf, 0, 0, 0, 10, 10, .{ 1, 0, 0, 1 });
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

test "panel is positioned on the right side of the screen" {
    var buf: [4096]UiVertex = undefined;
    var entries: [15]?ScoreEntry = .{null} ** 15;
    entries[0] = .{ .score = 1 };
    const sw: f32 = 800.0;
    _ = render(&buf, 0, sw, 600.0, entries, 1);
    // First quad is the background panel; its left edge must be on the right half
    const panel_left = buf[0].pos_x;
    try testing.expect(panel_left > sw * 0.5);
}

test "render does not overflow a small buffer" {
    var buf: [12]UiVertex = undefined;
    var entries: [15]?ScoreEntry = .{null} ** 15;
    entries[0] = .{ .score = 99999 };
    const c = render(&buf, 0, 800.0, 600.0, entries, 1);
    try testing.expect(c <= 12);
}

test "sortedEntries handles null gaps and entry_count cap" {
    var entries: [15]?ScoreEntry = .{null} ** 15;
    entries[0] = .{ .score = 5 };
    entries[2] = .{ .score = 15 };
    entries[4] = .{ .score = 10 };
    // entry_count = 5 covers indices 0..4
    const sorted = sortedEntries(entries, 5);
    try testing.expectEqual(@as(u32, 15), sorted[0].?.score);
    try testing.expectEqual(@as(u32, 10), sorted[1].?.score);
    try testing.expectEqual(@as(u32, 5), sorted[2].?.score);
    try testing.expect(sorted[3] == null);
}
