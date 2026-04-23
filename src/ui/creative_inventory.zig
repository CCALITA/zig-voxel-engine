/// Creative-mode inventory screen renderer.
/// Produces UiVertex quads for a centered 500x450 panel with:
///   - 8 category tabs (colored bars across the top)
///   - 9-column scrollable item grid
///   - Search bar at the bottom
/// All quads use u=-1, v=-1 (color-only, no texture sampling).
const std = @import("std");

// ── Public types ────────────────────────────────────────────────────

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

pub const Category = enum(u3) {
    all,
    building,
    decoration,
    redstone,
    transportation,
    tools,
    food,
    misc,
};

pub const max_vertices = 8192;

// ── Layout constants ────────────────────────────────────────────────

const panel_w: f32 = 500.0;
const panel_h: f32 = 450.0;

const panel_pad: f32 = 12.0;

const tab_h: f32 = 20.0;
const tab_gap: f32 = 4.0;
const tab_count: u32 = 8;

const slot_size: f32 = 36.0;
const slot_gap: f32 = 4.0;
const grid_cols: u32 = 9;

const search_bar_h: f32 = 24.0;
const search_cursor_w: f32 = 2.0;

const section_gap: f32 = 8.0;

const grid_total_w: f32 = @as(f32, @floatFromInt(grid_cols)) * slot_size +
    @as(f32, @floatFromInt(grid_cols - 1)) * slot_gap;

// ── Colors ──────────────────────────────────────────────────────────

const Color = struct { r: f32, g: f32, b: f32, a: f32 };

const panel_bg = Color{ .r = 0.13, .g = 0.13, .b = 0.13, .a = 0.92 };
const border_light = Color{ .r = 0.50, .g = 0.50, .b = 0.50, .a = 1.0 };
const border_dark = Color{ .r = 0.08, .g = 0.08, .b = 0.08, .a = 1.0 };
const slot_bg = Color{ .r = 0.22, .g = 0.22, .b = 0.22, .a = 0.90 };
const slot_border_col = Color{ .r = 0.38, .g = 0.38, .b = 0.38, .a = 0.80 };
const item_placeholder = Color{ .r = 0.55, .g = 0.75, .b = 0.95, .a = 0.85 };
const search_bg = Color{ .r = 0.18, .g = 0.18, .b = 0.18, .a = 0.95 };
const search_border = Color{ .r = 0.45, .g = 0.45, .b = 0.45, .a = 0.90 };
const search_cursor_col = Color{ .r = 0.9, .g = 0.9, .b = 0.9, .a = 1.0 };
const tab_active_border = Color{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 1.0 };
const scrollbar_bg = Color{ .r = 0.25, .g = 0.25, .b = 0.25, .a = 0.80 };
const scrollbar_thumb = Color{ .r = 0.60, .g = 0.60, .b = 0.60, .a = 0.90 };

/// One color per category tab.
const tab_colors = [tab_count]Color{
    .{ .r = 0.45, .g = 0.45, .b = 0.45, .a = 1.0 }, // all        – gray
    .{ .r = 0.65, .g = 0.40, .b = 0.20, .a = 1.0 }, // building   – brown
    .{ .r = 0.30, .g = 0.70, .b = 0.35, .a = 1.0 }, // decoration – green
    .{ .r = 0.80, .g = 0.15, .b = 0.15, .a = 1.0 }, // redstone   – red
    .{ .r = 0.20, .g = 0.50, .b = 0.80, .a = 1.0 }, // transport  – blue
    .{ .r = 0.70, .g = 0.70, .b = 0.70, .a = 1.0 }, // tools      – silver
    .{ .r = 0.85, .g = 0.60, .b = 0.20, .a = 1.0 }, // food       – orange
    .{ .r = 0.55, .g = 0.30, .b = 0.65, .a = 1.0 }, // misc       – purple
};

// ── Item catalogue ──────────────────────────────────────────────────

/// Total creative-mode items (mirrors item_registry ITEMS count).
const total_items: u32 = 183;

/// Number of items visible per category (simplified mapping).
/// "all" shows everything; other categories show a slice.
fn itemsForCategory(cat: Category) u32 {
    return switch (cat) {
        .all => total_items,
        .building => 50,
        .decoration => 30,
        .redstone => 18,
        .transportation => 12,
        .tools => 45,
        .food => 14,
        .misc => 14,
    };
}

/// First item id for a given category (offset into the full list).
fn categoryOffset(cat: Category) u32 {
    return switch (cat) {
        .all => 0,
        .building => 0,
        .decoration => 50,
        .redstone => 80,
        .transportation => 98,
        .tools => 110,
        .food => 155,
        .misc => 169,
    };
}

// ── Quad helper ─────────────────────────────────────────────────────

/// Emit a color-only quad (6 vertices, u=-1 v=-1).
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

// ── Sub-renderers ───────────────────────────────────────────────────

/// Render the 8 category tabs across the top of the panel.
fn renderTabs(verts: []UiVertex, idx: *u32, ox: f32, oy: f32, active: Category) void {
    const usable_w = panel_w - panel_pad * 2.0;
    const tw = (usable_w - @as(f32, @floatFromInt(tab_count - 1)) * tab_gap) / @as(f32, @floatFromInt(tab_count));

    for (0..tab_count) |i| {
        const fi: f32 = @floatFromInt(i);
        const tx = ox + panel_pad + fi * (tw + tab_gap);
        const ty = oy + panel_pad;

        addQuad(verts, idx, tx, ty, tw, tab_h, tab_colors[i]);

        // Active indicator: bright border below the active tab
        if (i == @intFromEnum(active)) {
            addQuad(verts, idx, tx, ty + tab_h, tw, 2.0, tab_active_border);
        }
    }
}

/// Render a single item slot (border + bg + item placeholder).
fn renderSlot(verts: []UiVertex, idx: *u32, x: f32, y: f32, has_item: bool) void {
    // Slot border
    addQuad(verts, idx, x, y, slot_size, 1.0, slot_border_col);
    addQuad(verts, idx, x, y + slot_size - 1.0, slot_size, 1.0, slot_border_col);
    addQuad(verts, idx, x, y + 1.0, 1.0, slot_size - 2.0, slot_border_col);
    addQuad(verts, idx, x + slot_size - 1.0, y + 1.0, 1.0, slot_size - 2.0, slot_border_col);

    // Background
    addQuad(verts, idx, x + 1.0, y + 1.0, slot_size - 2.0, slot_size - 2.0, slot_bg);

    // Item indicator
    if (has_item) {
        const item_size: f32 = 24.0;
        const inset = (slot_size - item_size) / 2.0;
        addQuad(verts, idx, x + inset, y + inset, item_size, item_size, item_placeholder);
    }
}

/// Compute the number of visible rows that fit in the grid area.
fn visibleRows(grid_area_h: f32) u32 {
    const row_step = slot_size + slot_gap;
    const rows = @as(u32, @intFromFloat(grid_area_h / row_step));
    return if (rows == 0) 1 else rows;
}

/// Render the scrollable item grid.
fn renderGrid(
    verts: []UiVertex,
    idx: *u32,
    ox: f32,
    grid_top: f32,
    grid_area_h: f32,
    category: Category,
    scroll: u8,
) void {
    const num_items = itemsForCategory(category);
    const vis_rows = visibleRows(grid_area_h);
    const total_rows = (num_items + grid_cols - 1) / grid_cols;

    const grid_x = ox + (panel_w - grid_total_w) / 2.0;

    const scroll_row: u32 = @min(@as(u32, scroll), if (total_rows > vis_rows) total_rows - vis_rows else 0);

    for (0..vis_rows) |row| {
        const abs_row = scroll_row + @as(u32, @intCast(row));
        if (abs_row >= total_rows) break;

        const fr: f32 = @floatFromInt(row);
        const ry = grid_top + fr * (slot_size + slot_gap);

        for (0..grid_cols) |col| {
            const item_index = abs_row * grid_cols + @as(u32, @intCast(col));
            const has_item = item_index < num_items;

            const fc: f32 = @floatFromInt(col);
            const sx = grid_x + fc * (slot_size + slot_gap);
            renderSlot(verts, idx, sx, ry, has_item);
        }
    }

    // Scrollbar (right edge)
    if (total_rows > vis_rows) {
        const sb_x = grid_x + grid_total_w + 6.0;
        const sb_h = grid_area_h;
        addQuad(verts, idx, sb_x, grid_top, 6.0, sb_h, scrollbar_bg);

        const thumb_h_ratio = @as(f32, @floatFromInt(vis_rows)) / @as(f32, @floatFromInt(total_rows));
        const thumb_h = @max(sb_h * thumb_h_ratio, 12.0);
        const scroll_frac = @as(f32, @floatFromInt(scroll_row)) /
            @as(f32, @floatFromInt(total_rows - vis_rows));
        const thumb_y = grid_top + scroll_frac * (sb_h - thumb_h);
        addQuad(verts, idx, sb_x, thumb_y, 6.0, thumb_h, scrollbar_thumb);
    }
}

/// Render the search bar at the bottom of the panel.
fn renderSearchBar(verts: []UiVertex, idx: *u32, ox: f32, bar_y: f32, search_len: u8) void {
    const bar_x = ox + panel_pad;
    const bar_w = panel_w - panel_pad * 2.0;

    // Border
    addQuad(verts, idx, bar_x, bar_y, bar_w, 1.0, search_border);
    addQuad(verts, idx, bar_x, bar_y + search_bar_h - 1.0, bar_w, 1.0, search_border);
    addQuad(verts, idx, bar_x, bar_y + 1.0, 1.0, search_bar_h - 2.0, search_border);
    addQuad(verts, idx, bar_x + bar_w - 1.0, bar_y + 1.0, 1.0, search_bar_h - 2.0, search_border);

    // Background
    addQuad(verts, idx, bar_x + 1.0, bar_y + 1.0, bar_w - 2.0, search_bar_h - 2.0, search_bg);

    // Cursor (thin line after typed characters)
    const char_w: f32 = 8.0;
    const cursor_x = bar_x + 6.0 + @as(f32, @floatFromInt(search_len)) * char_w;
    const cursor_y = bar_y + 4.0;
    const cursor_h = search_bar_h - 8.0;
    addQuad(verts, idx, cursor_x, cursor_y, search_cursor_w, cursor_h, search_cursor_col);
}

// ── Main render function ────────────────────────────────────────────

/// Render the creative inventory screen into the provided vertex buffer.
/// Returns the total number of vertices written (starting from `start`).
pub fn render(
    verts: []UiVertex,
    start: u32,
    sw: f32,
    sh: f32,
    category: Category,
    scroll: u8,
    search_len: u8,
) u32 {
    var idx: u32 = start;

    // Panel origin (centered)
    const ox = (sw - panel_w) / 2.0;
    const oy = (sh - panel_h) / 2.0;

    // ── Panel background ────────────────────────────────────────
    addQuad(verts, &idx, ox, oy, panel_w, panel_h, panel_bg);

    // Bevelled border (light top/left, dark bottom/right)
    addQuad(verts, &idx, ox, oy, panel_w, 2.0, border_light);
    addQuad(verts, &idx, ox, oy, 2.0, panel_h, border_light);
    addQuad(verts, &idx, ox, oy + panel_h - 2.0, panel_w, 2.0, border_dark);
    addQuad(verts, &idx, ox + panel_w - 2.0, oy, 2.0, panel_h, border_dark);

    // ── Category tabs ───────────────────────────────────────────
    renderTabs(verts, &idx, ox, oy, category);

    // ── Item grid ───────────────────────────────────────────────
    const grid_top = oy + panel_pad + tab_h + 2.0 + section_gap;
    const search_y = oy + panel_h - panel_pad - search_bar_h;
    const grid_area_h = search_y - section_gap - grid_top;

    renderGrid(verts, &idx, ox, grid_top, grid_area_h, category, scroll);

    // ── Search bar ──────────────────────────────────────────────
    renderSearchBar(verts, &idx, ox, search_y, search_len);

    return idx;
}

// ═══════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════

test "render returns more vertices than start index" {
    var buf: [max_vertices]UiVertex = undefined;
    const count = render(&buf, 0, 1920.0, 1080.0, .all, 0, 0);
    try std.testing.expect(count > 0);
    try std.testing.expect(count % 6 == 0);
}

test "render panel is centered on screen" {
    var buf: [max_vertices]UiVertex = undefined;
    const sw: f32 = 1920.0;
    const sh: f32 = 1080.0;
    _ = render(&buf, 0, sw, sh, .all, 0, 0);
    const expected_x = (sw - panel_w) / 2.0;
    const expected_y = (sh - panel_h) / 2.0;
    try std.testing.expectApproxEqAbs(expected_x, buf[0].pos_x, 0.01);
    try std.testing.expectApproxEqAbs(expected_y, buf[0].pos_y, 0.01);
}

test "render respects start offset" {
    var buf: [max_vertices]UiVertex = undefined;
    const offset: u32 = 18;
    const count = render(&buf, offset, 800.0, 600.0, .building, 0, 0);
    try std.testing.expect(count >= offset);
    try std.testing.expect((count - offset) % 6 == 0);
}

test "all quads have u=-1 v=-1" {
    var buf: [max_vertices]UiVertex = undefined;
    const count = render(&buf, 0, 800.0, 600.0, .all, 0, 3);
    for (0..count) |i| {
        try std.testing.expectApproxEqAbs(@as(f32, -1.0), buf[i].u, 0.001);
        try std.testing.expectApproxEqAbs(@as(f32, -1.0), buf[i].v, 0.001);
    }
}

test "different categories produce valid output" {
    var buf: [max_vertices]UiVertex = undefined;
    const cats = [_]Category{ .all, .building, .decoration, .redstone, .transportation, .tools, .food, .misc };
    for (cats) |cat| {
        const count = render(&buf, 0, 800.0, 600.0, cat, 0, 0);
        try std.testing.expect(count > 0);
        try std.testing.expect(count % 6 == 0);
    }
}

test "scrolling changes vertex positions" {
    var buf0: [max_vertices]UiVertex = undefined;
    const c0 = render(&buf0, 0, 800.0, 600.0, .all, 0, 0);

    var buf1: [max_vertices]UiVertex = undefined;
    const c1 = render(&buf1, 0, 800.0, 600.0, .all, 5, 0);

    // Both produce valid output; scrollbar thumb position differs
    try std.testing.expect(c0 > 0);
    try std.testing.expect(c1 > 0);
    // With scroll the scrollbar thumb moves, so at least one vertex differs
    var differ = false;
    const check_len = @min(c0, c1);
    for (0..check_len) |i| {
        if (buf0[i].pos_y != buf1[i].pos_y) {
            differ = true;
            break;
        }
    }
    try std.testing.expect(differ);
}

test "search bar cursor advances with search_len" {
    var buf_a: [max_vertices]UiVertex = undefined;
    const ca = render(&buf_a, 0, 800.0, 600.0, .all, 0, 0);

    var buf_b: [max_vertices]UiVertex = undefined;
    const cb = render(&buf_b, 0, 800.0, 600.0, .all, 0, 10);

    // More search text shifts the cursor quad; vertex data should differ
    try std.testing.expect(ca > 0);
    try std.testing.expect(cb > 0);
    // The last few quads include the cursor; compare
    var differ = false;
    const check_len = @min(ca, cb);
    for (0..check_len) |i| {
        if (buf_a[i].pos_x != buf_b[i].pos_x) {
            differ = true;
            break;
        }
    }
    try std.testing.expect(differ);
}

test "buffer overflow protection does not crash" {
    var buf: [12]UiVertex = undefined;
    const count = render(&buf, 0, 800.0, 600.0, .all, 0, 0);
    try std.testing.expect(count <= 12);
}

test "addQuad writes exactly 6 vertices with u=-1 v=-1" {
    var buf: [6]UiVertex = undefined;
    var idx: u32 = 0;
    addQuad(&buf, &idx, 10.0, 20.0, 50.0, 30.0, .{ .r = 1, .g = 0, .b = 0, .a = 1 });
    try std.testing.expectEqual(@as(u32, 6), idx);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), buf[0].pos_x, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 20.0), buf[0].pos_y, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, -1.0), buf[0].u, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, -1.0), buf[0].v, 0.001);
}

test "addQuad overflow protection" {
    var buf: [4]UiVertex = undefined;
    var idx: u32 = 0;
    addQuad(&buf, &idx, 0, 0, 10, 10, .{ .r = 1, .g = 1, .b = 1, .a = 1 });
    try std.testing.expectEqual(@as(u32, 0), idx);
}

test "visibleRows returns at least 1" {
    try std.testing.expect(visibleRows(40.0) >= 1);
    try std.testing.expect(visibleRows(200.0) >= 1);
}

test "itemsForCategory returns valid counts" {
    const cats = [_]Category{ .all, .building, .decoration, .redstone, .transportation, .tools, .food, .misc };
    for (cats) |cat| {
        const n = itemsForCategory(cat);
        try std.testing.expect(n > 0);
        try std.testing.expect(n <= total_items);
    }
}

test "categoryOffset values are within bounds" {
    const cats = [_]Category{ .all, .building, .decoration, .redstone, .transportation, .tools, .food, .misc };
    for (cats) |cat| {
        const off = categoryOffset(cat);
        try std.testing.expect(off + itemsForCategory(cat) <= total_items);
    }
}
