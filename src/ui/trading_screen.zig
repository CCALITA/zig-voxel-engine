/// Villager trading screen renderer.
/// Produces UiVertex quads for a centered 450x400 panel with:
///   - Left column: 4 visible trade offers (scrollable via scroll_offset)
///   - Each offer: input item icon + arrow + output item icon + emerald cost
///   - Right side: selected trade detail with input/output slots
///   - Trade button
/// Pure vertex generation -- no GPU dependencies.
const std = @import("std");
const bitmap_font = @import("../renderer/bitmap_font.zig");

// ── Vertex type (mirrors ui_pipeline.UiVertex layout) ───────────────

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

// ── Data ────────────────────────────────────────────────────────────

pub const TradeOffer = struct {
    input1: u16,
    count1: u8,
    output: u16,
    out_count: u8,
    uses: u8,
    max_uses: u8,
};

pub const TradeDisplayData = struct {
    offers: [8]?TradeOffer = [_]?TradeOffer{null} ** 8,
    selected: ?u8 = null,
    offer_count: u8 = 0,
    scroll_offset: u8 = 0,
};

// ── Layout constants ────────────────────────────────────────────────

const panel_w: f32 = 450.0;
const panel_h: f32 = 400.0;

const title_bar_h: f32 = 28.0;
const padding: f32 = 12.0;

const offer_h: f32 = 52.0;
const offer_gap: f32 = 6.0;
const offer_w: f32 = 180.0;
const visible_offers: u8 = 4;

const slot_size: f32 = 40.0;
const slot_border: f32 = 2.0;
const icon_size: f32 = 24.0;

const arrow_w: f32 = 16.0;
const arrow_h: f32 = 4.0;
const arrow_gap: f32 = 6.0;

const button_w: f32 = 100.0;
const button_h: f32 = 32.0;

const detail_slot_size: f32 = 48.0;

const digit_scale: f32 = 2.0;

// ── Colors ──────────────────────────────────────────────────────────

const Col = [4]f32;

const panel_bg: Col = .{ 0.55, 0.55, 0.55, 0.95 };
const panel_border_col: Col = .{ 0.15, 0.15, 0.15, 0.95 };
const title_bg: Col = .{ 0.35, 0.35, 0.35, 1.0 };
const offer_bg: Col = .{ 0.42, 0.42, 0.42, 0.90 };
const offer_selected_bg: Col = .{ 0.50, 0.60, 0.50, 0.95 };
const offer_disabled_bg: Col = .{ 0.35, 0.30, 0.30, 0.80 };
const slot_bg_col: Col = .{ 0.30, 0.30, 0.30, 1.0 };
const slot_border_col: Col = .{ 0.20, 0.20, 0.20, 1.0 };
const item_col: Col = .{ 0.78, 0.62, 0.36, 0.95 };
const item_empty_col: Col = .{ 0.50, 0.50, 0.50, 0.30 };
const arrow_col: Col = .{ 0.80, 0.80, 0.80, 0.70 };
const emerald_col: Col = .{ 0.20, 0.80, 0.30, 1.0 };
const button_bg: Col = .{ 0.30, 0.65, 0.30, 1.0 };
const button_disabled: Col = .{ 0.40, 0.40, 0.40, 0.70 };
const digit_col: Col = .{ 1.0, 1.0, 1.0, 1.0 };
const uses_ok_col: Col = .{ 0.30, 0.90, 0.30, 1.0 };
const uses_warn_col: Col = .{ 0.90, 0.60, 0.10, 1.0 };
const uses_full_col: Col = .{ 0.90, 0.20, 0.20, 1.0 };
const highlight_col: Col = .{ 1.0, 1.0, 0.0, 1.0 };
const detail_label_col: Col = .{ 0.85, 0.85, 0.85, 1.0 };

// ── Maximum vertex budget ───────────────────────────────────────────

pub const max_vertices: u32 = 4096;

// ── Quad helper ─────────────────────────────────────────────────────

/// Emit a colored (untextured) quad as two triangles. Untextured: u=-1, v=-1.
fn addQuad(verts: []UiVertex, start: u32, x: f32, y: f32, w: f32, h: f32, col: Col) u32 {
    if (start + 6 > verts.len) return start;
    const r = col[0];
    const g = col[1];
    const b = col[2];
    const a = col[3];
    verts[start + 0] = .{ .pos_x = x, .pos_y = y, .r = r, .g = g, .b = b, .a = a, .u = -1, .v = -1 };
    verts[start + 1] = .{ .pos_x = x + w, .pos_y = y, .r = r, .g = g, .b = b, .a = a, .u = -1, .v = -1 };
    verts[start + 2] = .{ .pos_x = x + w, .pos_y = y + h, .r = r, .g = g, .b = b, .a = a, .u = -1, .v = -1 };
    verts[start + 3] = .{ .pos_x = x, .pos_y = y, .r = r, .g = g, .b = b, .a = a, .u = -1, .v = -1 };
    verts[start + 4] = .{ .pos_x = x + w, .pos_y = y + h, .r = r, .g = g, .b = b, .a = a, .u = -1, .v = -1 };
    verts[start + 5] = .{ .pos_x = x, .pos_y = y + h, .r = r, .g = g, .b = b, .a = a, .u = -1, .v = -1 };
    return start + 6;
}

/// Emit a hollow rectangular border (4 quads: top, bottom, left, right).
fn addBorder(verts: []UiVertex, start: u32, x: f32, y: f32, w: f32, h: f32, t: f32, col: Col) u32 {
    var c = start;
    c = addQuad(verts, c, x, y, w, t, col); // top
    c = addQuad(verts, c, x, y + h - t, w, t, col); // bottom
    c = addQuad(verts, c, x, y + t, t, h - 2 * t, col); // left
    c = addQuad(verts, c, x + w - t, y + t, t, h - 2 * t, col); // right
    return c;
}

// ── Drawing helpers ─────────────────────────────────────────────────

/// Draw a number at (x, y) using the bitmap font. Returns new vertex index.
fn drawNumber(verts: []UiVertex, start: u32, x: f32, y: f32, value: u8, scale: f32, col: Col) u32 {
    var c = start;
    const val32: u32 = @intCast(value);
    const num_digits = bitmap_font.digitCount(val32);
    const char_w = @as(f32, @floatFromInt(bitmap_font.GLYPH_W)) * scale + scale;

    var di: u32 = 0;
    while (di < num_digits) : (di += 1) {
        const digit = bitmap_font.getDigit(val32, num_digits - 1 - di);
        const dx = x + @as(f32, @floatFromInt(di)) * char_w;
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

/// Render a slot with border, background, and optional item indicator + count.
fn renderSlot(verts: []UiVertex, start: u32, x: f32, y: f32, size: f32, item: u16, count: u8) u32 {
    var c = start;
    // Border
    c = addQuad(verts, c, x, y, size, size, slot_border_col);
    // Background
    c = addQuad(verts, c, x + slot_border, y + slot_border, size - slot_border * 2, size - slot_border * 2, slot_bg_col);

    // Item indicator
    if (item != 0) {
        const inset: f32 = 6.0;
        c = addQuad(verts, c, x + inset, y + inset, size - inset * 2, size - inset * 2, item_col);
    } else {
        const inset: f32 = 8.0;
        c = addQuad(verts, c, x + inset, y + inset, size - inset * 2, size - inset * 2, item_empty_col);
    }

    // Stack count (bottom-right)
    if (count > 1) {
        const num_x = x + size - 14.0;
        const num_y = y + size - 12.0;
        c = drawNumber(verts, c, num_x, num_y, count, 1.5, digit_col);
    }

    return c;
}

/// Render a small arrow (horizontal bar).
fn renderArrow(verts: []UiVertex, start: u32, x: f32, y: f32) u32 {
    return addQuad(verts, start, x, y, arrow_w, arrow_h, arrow_col);
}

/// Render a small emerald cost indicator (green square + number).
fn renderEmeraldCost(verts: []UiVertex, start: u32, x: f32, y: f32, count: u8) u32 {
    var c = start;
    // Small emerald icon
    c = addQuad(verts, c, x, y, 10.0, 10.0, emerald_col);
    // Cost number to the right
    if (count > 0) {
        c = drawNumber(verts, c, x + 12.0, y + 1.0, count, 1.5, digit_col);
    }
    return c;
}

/// Render a uses indicator bar.
fn renderUsesBar(verts: []UiVertex, start: u32, x: f32, y: f32, uses: u8, max_uses: u8) u32 {
    if (max_uses == 0) return start;
    var c = start;
    const bar_w: f32 = 40.0;
    const bar_h: f32 = 4.0;

    // Background
    c = addQuad(verts, c, x, y, bar_w, bar_h, .{ 0.2, 0.2, 0.2, 0.8 });

    // Fill
    const ratio = @as(f32, @floatFromInt(uses)) / @as(f32, @floatFromInt(max_uses));
    const fill_w = bar_w * ratio;
    const col = if (ratio >= 1.0)
        uses_full_col
    else if (ratio >= 0.75)
        uses_warn_col
    else
        uses_ok_col;

    if (fill_w > 0) {
        c = addQuad(verts, c, x, y, fill_w, bar_h, col);
    }

    return c;
}

// ── Main render function ────────────────────────────────────────────

/// Render the villager trading screen into `verts` starting at index `start`.
/// Returns the number of vertices written (not the new index).
/// The panel is centered on screen using `sw` (screen width) and `sh` (screen height).
pub fn render(verts: []UiVertex, start: u32, sw: f32, sh: f32, data: TradeDisplayData) u32 {
    var c = start;

    // Panel origin (centered)
    const px = (sw - panel_w) * 0.5;
    const py = (sh - panel_h) * 0.5;

    // 1. Panel border + background
    c = addQuad(verts, c, px - 3, py - 3, panel_w + 6, panel_h + 6, panel_border_col);
    c = addQuad(verts, c, px, py, panel_w, panel_h, panel_bg);

    // 2. Title bar
    c = addQuad(verts, c, px, py, panel_w, title_bar_h, title_bg);

    // ── Left column: trade offer list ───────────────────────────────
    const list_x = px + padding;
    const list_top = py + title_bar_h + padding;

    var vis: u8 = 0;
    while (vis < visible_offers) : (vis += 1) {
        const offer_idx = vis + data.scroll_offset;
        if (offer_idx >= data.offer_count) break;

        const oy = list_top + @as(f32, @floatFromInt(vis)) * (offer_h + offer_gap);

        // Offer background (selected vs normal vs disabled)
        const bg = if (data.selected != null and data.selected.? == offer_idx)
            offer_selected_bg
        else if (data.offers[offer_idx]) |o|
            (if (o.uses >= o.max_uses) offer_disabled_bg else offer_bg)
        else
            offer_bg;

        c = addQuad(verts, c, list_x, oy, offer_w, offer_h, bg);

        if (data.offers[offer_idx]) |offer| {
            // Input item icon
            const icon_y = oy + (offer_h - icon_size) * 0.5;
            const in_x = list_x + 6.0;
            if (offer.input1 != 0) {
                c = addQuad(verts, c, in_x, icon_y, icon_size, icon_size, item_col);
            }

            // Count for input
            if (offer.count1 > 1) {
                c = drawNumber(verts, c, in_x + icon_size - 8.0, icon_y + icon_size - 8.0, offer.count1, 1.5, digit_col);
            }

            // Arrow
            const arr_x = in_x + icon_size + arrow_gap;
            const arr_y = oy + (offer_h - arrow_h) * 0.5;
            c = renderArrow(verts, c, arr_x, arr_y);

            // Output item icon
            const out_x = arr_x + arrow_w + arrow_gap;
            if (offer.output != 0) {
                c = addQuad(verts, c, out_x, icon_y, icon_size, icon_size, item_col);
            }

            // Output count
            if (offer.out_count > 1) {
                c = drawNumber(verts, c, out_x + icon_size - 8.0, icon_y + icon_size - 8.0, offer.out_count, 1.5, digit_col);
            }

            // Emerald cost (below icons)
            const cost_y = oy + offer_h - 14.0;
            c = renderEmeraldCost(verts, c, in_x, cost_y, offer.count1);

            // Uses bar (bottom of offer row)
            const uses_x = list_x + offer_w - 46.0;
            c = renderUsesBar(verts, c, uses_x, cost_y + 2.0, offer.uses, offer.max_uses);
        }
    }

    // ── Right side: selected trade detail ────────────────────────────
    const detail_x = px + padding + offer_w + 24.0;
    const detail_top = py + title_bar_h + padding;

    if (data.selected) |sel_idx| {
        if (sel_idx < 8) {
            if (data.offers[sel_idx]) |offer| {
                // "Input" label area
                const label_y = detail_top;
                c = addQuad(verts, c, detail_x, label_y, 40.0, 10.0, detail_label_col);

                // Input slot
                const in_slot_y = label_y + 16.0;
                c = renderSlot(verts, c, detail_x, in_slot_y, detail_slot_size, offer.input1, offer.count1);

                // Arrow between input and output
                const detail_arrow_x = detail_x + detail_slot_size + 12.0;
                const detail_arrow_y = in_slot_y + detail_slot_size * 0.5 - arrow_h * 0.5;
                c = renderArrow(verts, c, detail_arrow_x, detail_arrow_y);

                // Output slot
                const out_slot_x = detail_arrow_x + arrow_w + 12.0;
                c = renderSlot(verts, c, out_slot_x, in_slot_y, detail_slot_size, offer.output, offer.out_count);

                // Selection highlight on output slot
                c = addBorder(verts, c, out_slot_x - 2.0, in_slot_y - 2.0, detail_slot_size + 4.0, detail_slot_size + 4.0, 2.0, highlight_col);

                // Uses display
                const uses_y = in_slot_y + detail_slot_size + 12.0;
                c = renderUsesBar(verts, c, detail_x, uses_y, offer.uses, offer.max_uses);

                // Uses text (number/max)
                c = drawNumber(verts, c, detail_x + 46.0, uses_y - 1.0, offer.uses, 1.5, digit_col);
                c = addQuad(verts, c, detail_x + 64.0, uses_y + 2.0, 4.0, 2.0, digit_col); // slash
                c = drawNumber(verts, c, detail_x + 72.0, uses_y - 1.0, offer.max_uses, 1.5, digit_col);

                // Trade button
                const btn_y = uses_y + 24.0;
                const btn_col = if (offer.uses >= offer.max_uses) button_disabled else button_bg;
                c = addQuad(verts, c, detail_x, btn_y, button_w, button_h, btn_col);
                c = addBorder(verts, c, detail_x, btn_y, button_w, button_h, 2.0, panel_border_col);
            }
        }
    }

    return c - start;
}

// ═══════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════

const testing = std.testing;

test "UiVertex is extern and correctly sized" {
    try testing.expectEqual(@as(usize, 32), @sizeOf(UiVertex));
}

test "addQuad emits 6 vertices with u=-1, v=-1" {
    var buf: [6]UiVertex = undefined;
    const c = addQuad(&buf, 0, 10, 20, 30, 40, .{ 1, 0.5, 0.25, 0.75 });
    try testing.expectEqual(@as(u32, 6), c);
    try testing.expectEqual(@as(f32, 10), buf[0].pos_x);
    try testing.expectEqual(@as(f32, 20), buf[0].pos_y);
    for (buf) |v| {
        try testing.expectEqual(@as(f32, -1), v.u);
        try testing.expectEqual(@as(f32, -1), v.v);
    }
}

test "addQuad overflow protection" {
    var buf: [3]UiVertex = undefined;
    const c = addQuad(&buf, 0, 0, 0, 1, 1, .{ 0, 0, 0, 1 });
    try testing.expectEqual(@as(u32, 0), c);
}

test "render returns nonzero for empty data" {
    var buf: [max_vertices]UiVertex = undefined;
    const count = render(&buf, 0, 800.0, 600.0, .{});
    // At minimum: border(6) + bg(6) + title(6) = 18 verts = 3 quads
    try testing.expect(count >= 18);
    try testing.expect(count % 6 == 0);
}

test "render panel is centered" {
    var buf: [max_vertices]UiVertex = undefined;
    const sw: f32 = 1280.0;
    const sh: f32 = 720.0;
    _ = render(&buf, 0, sw, sh, .{});
    // First quad is the panel border (3px outset)
    const expected_x = (sw - panel_w) * 0.5 - 3.0;
    const expected_y = (sh - panel_h) * 0.5 - 3.0;
    try testing.expectApproxEqAbs(expected_x, buf[0].pos_x, 0.01);
    try testing.expectApproxEqAbs(expected_y, buf[0].pos_y, 0.01);
}

test "render respects start offset" {
    var buf: [max_vertices]UiVertex = undefined;
    const offset: u32 = 12;
    const count = render(&buf, offset, 800.0, 600.0, .{});
    try testing.expect(count > 0);
    try testing.expect(buf[offset].a != 0.0);
}

test "render with offers produces more vertices than empty" {
    var buf_empty: [max_vertices]UiVertex = undefined;
    const count_empty = render(&buf_empty, 0, 800.0, 600.0, .{});

    var data = TradeDisplayData{};
    data.offer_count = 2;
    data.offers[0] = .{ .input1 = 1, .count1 = 3, .output = 10, .out_count = 1, .uses = 0, .max_uses = 8 };
    data.offers[1] = .{ .input1 = 2, .count1 = 1, .output = 20, .out_count = 5, .uses = 4, .max_uses = 8 };

    var buf_offers: [max_vertices]UiVertex = undefined;
    const count_offers = render(&buf_offers, 0, 800.0, 600.0, data);
    try testing.expect(count_offers > count_empty);
}

test "render selected offer adds detail section vertices" {
    var data = TradeDisplayData{};
    data.offer_count = 1;
    data.offers[0] = .{ .input1 = 5, .count1 = 2, .output = 50, .out_count = 1, .uses = 1, .max_uses = 12 };

    var buf_no_sel: [max_vertices]UiVertex = undefined;
    const count_no_sel = render(&buf_no_sel, 0, 800.0, 600.0, data);

    data.selected = 0;
    var buf_sel: [max_vertices]UiVertex = undefined;
    const count_sel = render(&buf_sel, 0, 800.0, 600.0, data);

    // Selecting an offer adds the detail panel (slots, arrow, button, etc.)
    try testing.expect(count_sel > count_no_sel);
}

test "render disabled offer has different background" {
    var data = TradeDisplayData{};
    data.offer_count = 1;
    data.offers[0] = .{ .input1 = 1, .count1 = 1, .output = 2, .out_count = 1, .uses = 8, .max_uses = 8 };

    var buf: [max_vertices]UiVertex = undefined;
    _ = render(&buf, 0, 800.0, 600.0, data);

    // The offer background is the 4th quad (after border, bg, title).
    // Index 18 is start of 4th quad. Check that its color matches offer_disabled_bg.
    try testing.expectApproxEqAbs(offer_disabled_bg[0], buf[18].r, 0.01);
    try testing.expectApproxEqAbs(offer_disabled_bg[1], buf[18].g, 0.01);
}

test "drawNumber renders digit pixels" {
    var buf: [512]UiVertex = undefined;
    const c = drawNumber(&buf, 0, 0, 0, 42, 1.0, .{ 1, 1, 1, 1 });
    try testing.expect(c > 0);
    try testing.expect(c % 6 == 0);
}

test "renderSlot with item produces more vertices than empty" {
    var buf: [512]UiVertex = undefined;
    const empty_count = renderSlot(&buf, 0, 0, 0, slot_size, 0, 0);
    const filled_count = renderSlot(&buf, 0, 0, 0, slot_size, 42, 5);
    try testing.expect(filled_count > empty_count);
}

test "render small buffer does not crash" {
    var buf: [4]UiVertex = undefined;
    const count = render(&buf, 0, 800.0, 600.0, .{
        .offer_count = 4,
        .offers = .{
            .{ .input1 = 1, .count1 = 10, .output = 2, .out_count = 1, .uses = 0, .max_uses = 8 },
            .{ .input1 = 3, .count1 = 5, .output = 4, .out_count = 2, .uses = 3, .max_uses = 8 },
            .{ .input1 = 5, .count1 = 1, .output = 6, .out_count = 1, .uses = 8, .max_uses = 8 },
            .{ .input1 = 7, .count1 = 2, .output = 8, .out_count = 3, .uses = 0, .max_uses = 16 },
            null,
            null,
            null,
            null,
        },
        .selected = 0,
    });
    try testing.expect(count <= 4);
}

test "renderUsesBar emits correct fill color for exhausted offer" {
    var buf: [64]UiVertex = undefined;
    const c = renderUsesBar(&buf, 0, 0, 0, 8, 8);
    // Background(6) + fill(6) = 12 vertices.
    try testing.expect(c >= 12);
    // Fill quad (starts at vertex 6) should use uses_full_col.
    try testing.expectApproxEqAbs(uses_full_col[0], buf[6].r, 0.01);
    try testing.expectApproxEqAbs(uses_full_col[1], buf[6].g, 0.01);
}

test "addBorder writes 4 quads (24 vertices)" {
    var buf: [32]UiVertex = undefined;
    const end = addBorder(&buf, 0, 10, 10, 100, 50, 2, highlight_col);
    try testing.expectEqual(@as(u32, 24), end);
}

test "render all 8 offers with scroll" {
    var data = TradeDisplayData{};
    data.offer_count = 8;
    for (0..8) |i| {
        data.offers[i] = .{
            .input1 = @intCast(i + 1),
            .count1 = @intCast(i + 1),
            .output = @intCast((i + 1) * 10),
            .out_count = 1,
            .uses = 0,
            .max_uses = 12,
        };
    }
    data.scroll_offset = 4;
    data.selected = 5;

    var buf: [max_vertices]UiVertex = undefined;
    const count = render(&buf, 0, 1920.0, 1080.0, data);
    try testing.expect(count > 0);
    try testing.expect(count <= max_vertices);
}

test "renderEmeraldCost emits icon and digits" {
    var buf: [256]UiVertex = undefined;
    const c = renderEmeraldCost(&buf, 0, 0, 0, 5);
    // At least: emerald icon(6) + digit quads
    try testing.expect(c > 6);
    // First quad should be emerald-colored
    try testing.expectApproxEqAbs(emerald_col[0], buf[0].r, 0.01);
    try testing.expectApproxEqAbs(emerald_col[1], buf[0].g, 0.01);
}
