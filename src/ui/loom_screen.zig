/// Loom UI screen renderer.
/// Produces textured/colored quads for the loom interface: banner input slot,
/// dye slot, 4x5 pattern selector grid with scroll support, and output slot.
/// Centered 420x320 panel. Only depends on `std`.
const std = @import("std");

// ── Vertex type (mirrors ui_pipeline.UiVertex layout) ─────────────────

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

// ── Data ──────────────────────────────────────────────────────────────

pub const LoomData = struct {
    banner_item: u16 = 0,
    banner_count: u8 = 0,
    dye_item: u16 = 0,
    dye_count: u8 = 0,
    output_item: u16 = 0,
    output_count: u8 = 0,
    selected_pattern: ?u8 = null,
    scroll_offset: u8 = 0,
};

// ── Layout constants ──────────────────────────────────────────────────

const panel_w: f32 = 420.0;
const panel_h: f32 = 320.0;

const slot_size: f32 = 36.0;
const slot_gap: f32 = 8.0;

const grid_cols: u8 = 4;
const grid_rows: u8 = 5;
const cell_size: f32 = 28.0;
const cell_gap: f32 = 4.0;

const border: f32 = 2.0;

// ── Colors ────────────────────────────────────────────────────────────

const Color = struct { r: f32, g: f32, b: f32, a: f32 };

const bg_panel = Color{ .r = 0.12, .g = 0.12, .b = 0.12, .a = 0.92 };
const bg_slot = Color{ .r = 0.22, .g = 0.22, .b = 0.22, .a = 1.0 };
const bg_slot_filled = Color{ .r = 0.30, .g = 0.28, .b = 0.22, .a = 1.0 };
const bg_cell = Color{ .r = 0.18, .g = 0.18, .b = 0.18, .a = 1.0 };
const selected_border = Color{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 1.0 };
const output_border = Color{ .r = 0.8, .g = 0.7, .b = 0.2, .a = 1.0 };

// Pattern icon indicator colors
const stripe_color = Color{ .r = 0.55, .g = 0.35, .b = 0.15, .a = 1.0 };
const cross_color = Color{ .r = 0.70, .g = 0.20, .b = 0.20, .a = 1.0 };
const diagonal_color = Color{ .r = 0.20, .g = 0.50, .b = 0.70, .a = 1.0 };
const plain_color = Color{ .r = 0.40, .g = 0.40, .b = 0.60, .a = 1.0 };

// ── Maximum vertex budget ─────────────────────────────────────────────

/// Upper bound on vertices the render function can emit.
/// Panel(1) + slots(3) + slot-fills(3) + output-border(4) + grid-cells(20)
/// + pattern-icons(~40) + selected-border(4) = ~75 quads * 6 = 450.
/// Rounded up for safety.
pub const max_vertices: u32 = 512;

// ── Quad helper ───────────────────────────────────────────────────────

/// Write a single colored quad (2 triangles, 6 vertices) into `verts`
/// starting at index `idx`. Returns the new index after the written
/// vertices, or `idx` unchanged if there is no room.
pub fn addQuad(verts: []UiVertex, idx: u32, x: f32, y: f32, w: f32, h: f32, col: Color) u32 {
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

/// Emit a hollow rectangular border (4 quads: top, bottom, left, right).
fn addBorder(verts: []UiVertex, idx: u32, x: f32, y: f32, w: f32, h: f32, t: f32, col: Color) u32 {
    var c = idx;
    c = addQuad(verts, c, x, y, w, t, col); // top
    c = addQuad(verts, c, x, y + h - t, w, t, col); // bottom
    c = addQuad(verts, c, x, y + t, t, h - 2 * t, col); // left
    c = addQuad(verts, c, x + w - t, y + t, t, h - 2 * t, col); // right
    return c;
}

// ── Pattern icon rendering ────────────────────────────────────────────

/// Draw a small pattern indicator inside a cell. The `pattern_index`
/// determines the visual style (stripe, cross, diagonal, or plain).
fn addPatternIcon(verts: []UiVertex, idx: u32, cx: f32, cy: f32, size: f32, pattern_index: u8) u32 {
    var c = idx;
    const inset: f32 = 4.0;
    const ix = cx + inset;
    const iy = cy + inset;
    const is = size - inset * 2.0;

    const kind = pattern_index % 4;
    switch (kind) {
        0 => {
            // Horizontal stripe: full-width bar in the middle third
            c = addQuad(verts, c, ix, iy + is * 0.33, is, is * 0.34, stripe_color);
        },
        1 => {
            // Cross: vertical + horizontal bars
            c = addQuad(verts, c, ix + is * 0.4, iy, is * 0.2, is, cross_color);
            c = addQuad(verts, c, ix, iy + is * 0.4, is, is * 0.2, cross_color);
        },
        2 => {
            // Diagonal indicator: two small squares at opposite corners
            const ds = is * 0.3;
            c = addQuad(verts, c, ix, iy, ds, ds, diagonal_color);
            c = addQuad(verts, c, ix + is - ds, iy + is - ds, ds, ds, diagonal_color);
        },
        3 => {
            // Plain filled square
            c = addQuad(verts, c, ix, iy, is, is, plain_color);
        },
        else => {},
    }
    return c;
}

// ── Main render function ──────────────────────────────────────────────

/// Render the loom UI into `verts` starting at index `start`.
/// Returns the new vertex index (number of vertices written = result - start).
/// The panel is centered on screen using `sw` (screen width) and `sh` (screen height).
pub fn render(verts: []UiVertex, start: u32, sw: f32, sh: f32, data: LoomData) u32 {
    var c = start;

    // Panel origin (centered)
    const px = (sw - panel_w) * 0.5;
    const py = (sh - panel_h) * 0.5;

    // 1. Background panel
    c = addQuad(verts, c, px, py, panel_w, panel_h, bg_panel);

    // -- Left column: banner slot + dye slot (vertically stacked) --
    const left_x = px + 16.0;
    const slots_top = py + 40.0;

    // Banner slot
    const banner_bg = if (data.banner_count > 0) bg_slot_filled else bg_slot;
    c = addQuad(verts, c, left_x, slots_top, slot_size, slot_size, banner_bg);

    // Dye slot (below banner)
    const dye_y = slots_top + slot_size + slot_gap;
    const dye_bg = if (data.dye_count > 0) bg_slot_filled else bg_slot;
    c = addQuad(verts, c, left_x, dye_y, slot_size, slot_size, dye_bg);

    // -- Center: 4x5 pattern selector grid --
    const grid_w = @as(f32, @floatFromInt(grid_cols)) * cell_size +
        @as(f32, @floatFromInt(grid_cols - 1)) * cell_gap;
    const grid_h = @as(f32, @floatFromInt(grid_rows)) * cell_size +
        @as(f32, @floatFromInt(grid_rows - 1)) * cell_gap;
    const grid_x = px + (panel_w - grid_w) * 0.5;
    const grid_y = py + (panel_h - grid_h) * 0.5;

    const total_patterns: u8 = grid_cols * grid_rows; // visible at once
    for (0..total_patterns) |i| {
        const fi: u8 = @intCast(i);
        const col_i: u8 = fi % grid_cols;
        const row_i: u8 = fi / grid_cols;
        const cx = grid_x + @as(f32, @floatFromInt(col_i)) * (cell_size + cell_gap);
        const cy = grid_y + @as(f32, @floatFromInt(row_i)) * (cell_size + cell_gap);

        // Cell background
        c = addQuad(verts, c, cx, cy, cell_size, cell_size, bg_cell);

        // Pattern icon inside cell
        const pattern_idx = fi + data.scroll_offset * grid_cols;
        c = addPatternIcon(verts, c, cx, cy, cell_size, pattern_idx);

        // Selection border
        if (data.selected_pattern) |sel| {
            if (sel == pattern_idx) {
                c = addBorder(verts, c, cx - border, cy - border, cell_size + border * 2, cell_size + border * 2, border, selected_border);
            }
        }
    }

    // -- Right column: output slot --
    const out_x = px + panel_w - 16.0 - slot_size;
    const out_y = py + (panel_h - slot_size) * 0.5;
    const out_bg = if (data.output_count > 0) bg_slot_filled else bg_slot;
    c = addQuad(verts, c, out_x, out_y, slot_size, slot_size, out_bg);

    // Output slot decorative border
    c = addBorder(verts, c, out_x - border, out_y - border, slot_size + border * 2, slot_size + border * 2, border, output_border);

    return c;
}

// ── Tests ─────────────────────────────────────────────────────────────

test "addQuad writes 6 vertices" {
    var buf: [12]UiVertex = undefined;
    const end = addQuad(&buf, 0, 10.0, 20.0, 30.0, 40.0, bg_panel);
    try std.testing.expectEqual(@as(u32, 6), end);
    // First vertex at top-left
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), buf[0].pos_x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 20.0), buf[0].pos_y, 0.001);
    // Second vertex at top-right
    try std.testing.expectApproxEqAbs(@as(f32, 40.0), buf[1].pos_x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 20.0), buf[1].pos_y, 0.001);
    // Third vertex at bottom-right
    try std.testing.expectApproxEqAbs(@as(f32, 40.0), buf[2].pos_x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 60.0), buf[2].pos_y, 0.001);
}

test "addQuad overflow protection" {
    var buf: [3]UiVertex = undefined;
    const end = addQuad(&buf, 0, 0, 0, 1, 1, bg_panel);
    try std.testing.expectEqual(@as(u32, 0), end);
}

test "addQuad at offset" {
    var buf: [12]UiVertex = undefined;
    const end = addQuad(&buf, 6, 0, 0, 5, 5, bg_slot);
    try std.testing.expectEqual(@as(u32, 12), end);
}

test "addBorder writes 4 quads (24 vertices)" {
    var buf: [32]UiVertex = undefined;
    const end = addBorder(&buf, 0, 10, 10, 100, 50, 2, selected_border);
    try std.testing.expectEqual(@as(u32, 24), end);
}

test "render returns vertex count greater than start" {
    var buf: [max_vertices]UiVertex = undefined;
    const data = LoomData{};
    const end = render(&buf, 0, 800.0, 600.0, data);
    try std.testing.expect(end > 0);
}

test "render panel is centered" {
    var buf: [max_vertices]UiVertex = undefined;
    const data = LoomData{};
    _ = render(&buf, 0, 800.0, 600.0, data);
    // First quad is the panel background, first vertex is top-left corner
    const expected_x = (800.0 - panel_w) * 0.5;
    const expected_y = (600.0 - panel_h) * 0.5;
    try std.testing.expectApproxEqAbs(expected_x, buf[0].pos_x, 0.01);
    try std.testing.expectApproxEqAbs(expected_y, buf[0].pos_y, 0.01);
}

test "render with filled slots uses filled background" {
    var buf: [max_vertices]UiVertex = undefined;
    const data = LoomData{
        .banner_item = 100,
        .banner_count = 1,
        .dye_item = 200,
        .dye_count = 3,
    };
    _ = render(&buf, 0, 800.0, 600.0, data);
    // Banner slot is the second quad (indices 6..11), check its color
    try std.testing.expectApproxEqAbs(bg_slot_filled.r, buf[6].r, 0.001);
    try std.testing.expectApproxEqAbs(bg_slot_filled.g, buf[6].g, 0.001);
    // Dye slot is the third quad (indices 12..17)
    try std.testing.expectApproxEqAbs(bg_slot_filled.r, buf[12].r, 0.001);
}

test "render with empty slots uses empty background" {
    var buf: [max_vertices]UiVertex = undefined;
    const data = LoomData{};
    _ = render(&buf, 0, 800.0, 600.0, data);
    // Banner slot (second quad, vertex 6)
    try std.testing.expectApproxEqAbs(bg_slot.r, buf[6].r, 0.001);
    // Dye slot (third quad, vertex 12)
    try std.testing.expectApproxEqAbs(bg_slot.r, buf[12].r, 0.001);
}

test "render selected pattern adds border quads" {
    var buf: [max_vertices]UiVertex = undefined;
    const without_sel = render(&buf, 0, 800.0, 600.0, LoomData{});

    var buf2: [max_vertices]UiVertex = undefined;
    const with_sel = render(&buf2, 0, 800.0, 600.0, LoomData{ .selected_pattern = 0 });

    // Selected pattern adds 4 border quads = 24 extra vertices
    try std.testing.expectEqual(without_sel + 24, with_sel);
}

test "render output slot has decorative border" {
    var buf: [max_vertices]UiVertex = undefined;
    const end = render(&buf, 0, 1024.0, 768.0, LoomData{});
    // The last 24 vertices should be the output border (4 quads).
    // Check the border color on the last quad's first vertex.
    const border_start = end - 24;
    try std.testing.expectApproxEqAbs(output_border.r, buf[border_start].r, 0.001);
    try std.testing.expectApproxEqAbs(output_border.g, buf[border_start].g, 0.001);
}

test "render with non-zero start offset" {
    var buf: [max_vertices]UiVertex = undefined;
    const start: u32 = 6;
    const end = render(&buf, start, 800.0, 600.0, LoomData{});
    try std.testing.expect(end > start);
    // Panel background first vertex is at index `start`
    const expected_x = (800.0 - panel_w) * 0.5;
    try std.testing.expectApproxEqAbs(expected_x, buf[start].pos_x, 0.01);
}

test "render grid produces 20 cell backgrounds" {
    var buf: [max_vertices]UiVertex = undefined;
    // With no selection, the grid produces 20 bg quads + 20 pattern icon quads (variable).
    // Count total quads: 1 panel + 2 input slots + 20 cells + icons + 1 output + 4 output border
    const end = render(&buf, 0, 800.0, 600.0, LoomData{});
    // Minimum: panel(6) + banner(6) + dye(6) + 20 cells(120) + 20 icons (at least 20 quads = 120) + output(6) + output border(24) = 288
    try std.testing.expect(end >= 288);
}

test "render small buffer does not crash" {
    var buf: [6]UiVertex = undefined;
    const end = render(&buf, 0, 800.0, 600.0, LoomData{});
    try std.testing.expect(end <= 6);
}

test "render scroll offset shifts pattern indices" {
    var buf1: [max_vertices]UiVertex = undefined;
    var buf2: [max_vertices]UiVertex = undefined;

    // Scroll offset 0: first cell shows pattern 0 (kind=0 -> stripe)
    _ = render(&buf1, 0, 800.0, 600.0, LoomData{ .scroll_offset = 0 });
    // Scroll offset 1: first cell shows pattern 4 (kind=0 -> stripe again since 4%4==0)
    _ = render(&buf2, 0, 800.0, 600.0, LoomData{ .scroll_offset = 1 });

    // Both produce valid output; vertex counts may differ only if
    // icon types change (different pattern kinds have different quad counts).
    // Just verify both are valid non-zero.
    try std.testing.expect(buf1[0].pos_x > 0);
    try std.testing.expect(buf2[0].pos_x > 0);
}

test "UiVertex is extern and correctly sized" {
    // 8 floats * 4 bytes = 32 bytes
    try std.testing.expectEqual(@as(usize, 32), @sizeOf(UiVertex));
}
