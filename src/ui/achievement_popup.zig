/// Achievement toast popup that slides in from the top-right of the screen,
/// holds for a few seconds, then fades out. Up to 4 popups can be queued and
/// stack vertically. Renders as flat-coloured UI quads (u=-1, v=-1) plus a
/// gold border and the achievement id drawn as digits via the bitmap font.
const std = @import("std");
const bitmap_font = @import("../renderer/bitmap_font.zig");

// ── Public types ─────────────────────────────────────────────────────

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

pub const Popup = struct {
    achievement_id: u16,
    timer: f32 = 0,
    state: enum { sliding_in, showing, fading_out, done } = .sliding_in,
};

pub const PopupQueue = struct {
    items: [4]?Popup = [_]?Popup{null} ** 4,

    /// Append an achievement to the first free slot. Silently dropped if full.
    pub fn push(self: *PopupQueue, id: u16) void {
        for (&self.items) |*slot| {
            if (slot.* == null) {
                slot.* = Popup{ .achievement_id = id };
                return;
            }
        }
    }

    /// Advance every active popup by `dt` seconds, retiring finished ones.
    pub fn update(self: *PopupQueue, dt: f32) void {
        for (&self.items) |*slot| {
            if (slot.*) |*p| {
                p.timer += dt;
                if (p.timer < slide_in_duration) {
                    p.state = .sliding_in;
                } else if (p.timer < slide_in_duration + show_duration) {
                    p.state = .showing;
                } else if (p.timer < total_duration) {
                    p.state = .fading_out;
                } else {
                    p.state = .done;
                    slot.* = null;
                }
            }
        }
    }

    /// Emit quads for every active popup. Returns the new write index.
    pub fn render(self: *const PopupQueue, verts: []UiVertex, start: u32, sw: f32, sh: f32) u32 {
        var idx = start;
        var stack_y: f32 = popup_top_margin;
        for (self.items) |maybe_popup| {
            if (maybe_popup) |p| {
                idx = renderOne(verts, idx, sw, sh, p, stack_y);
                stack_y += popup_height + popup_gap;
            }
        }
        return idx;
    }
};

// ── Timing constants ─────────────────────────────────────────────────

pub const slide_in_duration: f32 = 0.5;
pub const show_duration: f32 = 5.0;
pub const fade_out_duration: f32 = 0.5;
pub const total_duration: f32 = slide_in_duration + show_duration + fade_out_duration;

// ── Layout constants ─────────────────────────────────────────────────

const popup_width: f32 = 240.0;
const popup_height: f32 = 48.0;
const popup_top_margin: f32 = 16.0;
const popup_right_margin: f32 = 16.0;
const popup_gap: f32 = 8.0;
const border_thickness: f32 = 2.0;
const pixel_scale: f32 = 2.0;

pub const max_vertices: u32 = 1024;

// ── Colors ───────────────────────────────────────────────────────────

const Color = struct { r: f32, g: f32, b: f32, a: f32 };

const bg_base = Color{ .r = 0.05, .g = 0.05, .b = 0.10, .a = 0.85 };
const gold_base = Color{ .r = 1.00, .g = 0.84, .b = 0.20, .a = 1.00 };
const text_base = Color{ .r = 1.00, .g = 1.00, .b = 1.00, .a = 1.00 };
const shadow_base = Color{ .r = 0.05, .g = 0.05, .b = 0.05, .a = 0.85 };

fn scaleAlpha(c: Color, a: f32) Color {
    return .{ .r = c.r, .g = c.g, .b = c.b, .a = c.a * a };
}

// ── Quad helper (u=-1, v=-1: untextured flat colour) ─────────────────

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

// ── Number drawing (re-used pattern from hud_renderer) ───────────────

fn drawNumber(verts: []UiVertex, idx: *u32, left_x: f32, y: f32, value: u32, fg: Color, shadow: Color) void {
    const num_digits = bitmap_font.digitCount(value);
    const glyph_w: f32 = @floatFromInt(bitmap_font.GLYPH_W);
    const digit_spacing: f32 = 1.0;

    var d: u32 = 0;
    while (d < num_digits) : (d += 1) {
        const digit = bitmap_font.getDigit(value, num_digits - 1 - d);
        const dx = left_x + @as(f32, @floatFromInt(d)) * (glyph_w * pixel_scale + digit_spacing);

        var py: u32 = 0;
        while (py < bitmap_font.GLYPH_H) : (py += 1) {
            var px: u32 = 0;
            while (px < bitmap_font.GLYPH_W) : (px += 1) {
                if (bitmap_font.getPixel(digit, px, py)) {
                    const fx = dx + @as(f32, @floatFromInt(px)) * pixel_scale;
                    const fy = y + @as(f32, @floatFromInt(py)) * pixel_scale;
                    addQuad(verts, idx, fx + 1.0, fy + 1.0, pixel_scale, pixel_scale, shadow);
                    addQuad(verts, idx, fx, fy, pixel_scale, pixel_scale, fg);
                }
            }
        }
    }
}

// ── Animation curves ─────────────────────────────────────────────────

/// Returns alpha [0,1] for a popup based on its current state and timer.
fn popupAlpha(p: Popup) f32 {
    return switch (p.state) {
        .sliding_in, .showing => 1.0,
        .fading_out => blk: {
            const into_fade = p.timer - (slide_in_duration + show_duration);
            const t = std.math.clamp(into_fade / fade_out_duration, 0.0, 1.0);
            break :blk 1.0 - t;
        },
        .done => 0.0,
    };
}

/// Returns the slide-in offset in pixels (positive = off-screen to the right).
fn slideOffset(p: Popup) f32 {
    if (p.state != .sliding_in) return 0.0;
    const t = std.math.clamp(p.timer / slide_in_duration, 0.0, 1.0);
    // ease-out: start at full width offset, end at 0
    const eased = 1.0 - (1.0 - t) * (1.0 - t);
    return (popup_width + popup_right_margin) * (1.0 - eased);
}

// ── Single popup render ──────────────────────────────────────────────

fn renderOne(verts: []UiVertex, start: u32, sw: f32, _: f32, p: Popup, stack_y: f32) u32 {
    var idx = start;
    const alpha = popupAlpha(p);
    if (alpha <= 0.0) return idx;

    const x = sw - popup_width - popup_right_margin + slideOffset(p);
    const y = stack_y;

    const bg = scaleAlpha(bg_base, alpha);
    const gold = scaleAlpha(gold_base, alpha);
    const fg = scaleAlpha(text_base, alpha);
    const shadow = scaleAlpha(shadow_base, alpha);

    // Background fill
    addQuad(verts, &idx, x, y, popup_width, popup_height, bg);

    // Gold border (top, bottom, left, right)
    addQuad(verts, &idx, x, y, popup_width, border_thickness, gold);
    addQuad(verts, &idx, x, y + popup_height - border_thickness, popup_width, border_thickness, gold);
    addQuad(verts, &idx, x, y, border_thickness, popup_height, gold);
    addQuad(verts, &idx, x + popup_width - border_thickness, y, border_thickness, popup_height, gold);

    // Achievement id drawn as digits, vertically centred inside the card
    const digit_h = @as(f32, @floatFromInt(bitmap_font.GLYPH_H)) * pixel_scale;
    const text_y = y + (popup_height - digit_h) * 0.5;
    const text_x = x + 12.0;
    drawNumber(verts, &idx, text_x, text_y, @as(u32, p.achievement_id), fg, shadow);

    return idx;
}

// ── Tests ────────────────────────────────────────────────────────────

test "queue starts empty" {
    var q = PopupQueue{};
    for (q.items) |slot| try std.testing.expect(slot == null);
}

test "push fills first free slot" {
    var q = PopupQueue{};
    q.push(7);
    try std.testing.expect(q.items[0] != null);
    try std.testing.expectEqual(@as(u16, 7), q.items[0].?.achievement_id);
    try std.testing.expect(q.items[1] == null);
}

test "push respects 4-slot cap" {
    var q = PopupQueue{};
    q.push(1);
    q.push(2);
    q.push(3);
    q.push(4);
    q.push(5); // dropped
    try std.testing.expect(q.items[0] != null);
    try std.testing.expect(q.items[3] != null);
    try std.testing.expectEqual(@as(u16, 4), q.items[3].?.achievement_id);
}

test "popup starts in sliding_in state" {
    var q = PopupQueue{};
    q.push(42);
    try std.testing.expectEqual(Popup.State.sliding_in, q.items[0].?.state);
}

test "update transitions sliding_in -> showing" {
    var q = PopupQueue{};
    q.push(1);
    q.update(slide_in_duration + 0.01);
    try std.testing.expectEqual(Popup.State.showing, q.items[0].?.state);
}

test "update transitions showing -> fading_out" {
    var q = PopupQueue{};
    q.push(1);
    q.update(slide_in_duration + show_duration + 0.01);
    try std.testing.expectEqual(Popup.State.fading_out, q.items[0].?.state);
}

test "update retires popup after total_duration" {
    var q = PopupQueue{};
    q.push(1);
    q.update(total_duration + 0.01);
    try std.testing.expect(q.items[0] == null);
}

test "render writes multiples of 6 vertices" {
    var q = PopupQueue{};
    q.push(99);
    var buf: [max_vertices]UiVertex = undefined;
    const count = q.render(&buf, 0, 1920.0, 1080.0, );
    try std.testing.expect(count > 0);
    try std.testing.expect(count % 6 == 0);
}

test "render with empty queue writes nothing" {
    const q = PopupQueue{};
    var buf: [max_vertices]UiVertex = undefined;
    const count = q.render(&buf, 0, 1920.0, 1080.0);
    try std.testing.expectEqual(@as(u32, 0), count);
}

test "render preserves start offset" {
    var q = PopupQueue{};
    q.push(1);
    var buf: [max_vertices]UiVertex = undefined;
    const count = q.render(&buf, 18, 1920.0, 1080.0);
    try std.testing.expect(count >= 18);
    try std.testing.expect((count - 18) % 6 == 0);
}

test "all rendered vertices have u=-1 and v=-1" {
    var q = PopupQueue{};
    q.push(123);
    var buf: [max_vertices]UiVertex = undefined;
    const count = q.render(&buf, 0, 1280.0, 720.0);
    var i: u32 = 0;
    while (i < count) : (i += 1) {
        try std.testing.expectApproxEqAbs(@as(f32, -1.0), buf[i].u, 0.001);
        try std.testing.expectApproxEqAbs(@as(f32, -1.0), buf[i].v, 0.001);
    }
}

test "popup is positioned in the right half of the screen" {
    var q = PopupQueue{};
    q.push(5);
    // Skip the slide-in so the popup is fully on-screen
    q.update(slide_in_duration + 0.001);
    var buf: [max_vertices]UiVertex = undefined;
    const sw: f32 = 1600.0;
    _ = q.render(&buf, 0, sw, 900.0);
    // First vertex is the top-left of the background quad
    try std.testing.expect(buf[0].pos_x > sw * 0.5);
}

test "fade_out reduces alpha below 1" {
    var q = PopupQueue{};
    q.push(1);
    q.update(slide_in_duration + show_duration + fade_out_duration * 0.5);
    var buf: [max_vertices]UiVertex = undefined;
    _ = q.render(&buf, 0, 800.0, 600.0);
    try std.testing.expect(buf[0].a < 1.0);
    try std.testing.expect(buf[0].a > 0.0);
}

test "multiple popups stack vertically" {
    var q = PopupQueue{};
    q.push(1);
    q.push(2);
    q.update(slide_in_duration + 0.001); // both fully visible
    var buf: [max_vertices]UiVertex = undefined;
    _ = q.render(&buf, 0, 1920.0, 1080.0);
    // First popup background quad starts at vertex 0; the second background
    // quad comes after the first popup's 5 quads (bg + 4 borders) plus its
    // digit quads. We check that some vertex below the first popup exists.
    const first_y = buf[0].pos_y;
    var found_lower = false;
    var i: u32 = 6;
    while (i < buf.len) : (i += 1) {
        if (buf[i].pos_y > first_y + popup_height) {
            found_lower = true;
            break;
        }
    }
    try std.testing.expect(found_lower);
}

test "buffer overflow protection" {
    var q = PopupQueue{};
    q.push(99);
    var small: [6]UiVertex = undefined;
    const count = q.render(&small, 0, 800.0, 600.0);
    try std.testing.expect(count <= 6);
}

test "slide-in offset shrinks over time" {
    const p0 = Popup{ .achievement_id = 1, .timer = 0.0, .state = .sliding_in };
    const p1 = Popup{ .achievement_id = 1, .timer = slide_in_duration * 0.5, .state = .sliding_in };
    const p2 = Popup{ .achievement_id = 1, .timer = slide_in_duration, .state = .showing };
    try std.testing.expect(slideOffset(p0) > slideOffset(p1));
    try std.testing.expect(slideOffset(p1) > slideOffset(p2));
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), slideOffset(p2), 0.001);
}

// Helper: re-export the anonymous enum so tests can name its variants.
const PopupStateAlias = @TypeOf(@as(Popup, undefined).state);
comptime {
    // Make the alias name resolvable in tests through Popup.State.
    _ = PopupStateAlias;
}
