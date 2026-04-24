/// Level-up UI overlay: green flash + centred level number when the player
/// gains an XP level. Call `trigger` with the new level, `update` each frame,
/// and `render` into the shared UI vertex buffer.
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

pub const LevelUpState = struct {
    timer: f32 = 0,
    level: u32 = 0,
    active: bool = false,

    pub fn trigger(self: *LevelUpState, new_level: u32) void {
        self.timer = effect_duration;
        self.level = new_level;
        self.active = true;
    }

    pub fn update(self: *LevelUpState, dt: f32) void {
        if (!self.active) return;
        self.timer -= dt;
        if (self.timer <= 0) {
            self.active = false;
            self.timer = 0;
        }
    }
};

// ── Constants ────────────────────────────────────────────────────────

pub const effect_duration: f32 = 1.5;
const pixel_scale: f32 = 3.0;
const digit_spacing: f32 = 1.0;
pub const max_vertices: u32 = 1024;

const Color = struct { r: f32, g: f32, b: f32, a: f32 };

const flash_color = Color{ .r = 0.2, .g = 0.9, .b = 0.3, .a = 0.3 };
const text_color = Color{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 1.0 };
const shadow_color = Color{ .r = 0.05, .g = 0.05, .b = 0.05, .a = 0.85 };

fn scaleAlpha(c: Color, a: f32) Color {
    return .{ .r = c.r, .g = c.g, .b = c.b, .a = c.a * a };
}

// ── Quad helper (u=-1, v=-1: untextured flat colour) ────────────────

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

// ── Number drawing ──────────────────────────────────────────────────

fn drawNumber(verts: []UiVertex, idx: *u32, left_x: f32, y: f32, value: u32, fg: Color, shadow: Color) void {
    const num_digits = bitmap_font.digitCount(value);
    const glyph_w: f32 = @floatFromInt(bitmap_font.GLYPH_W);

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

// ── Public render ───────────────────────────────────────────────────

pub fn render(verts: []UiVertex, start: u32, sw: f32, sh: f32, state: LevelUpState) u32 {
    if (!state.active) return start;

    var idx = start;
    const alpha = std.math.clamp(state.timer / effect_duration, 0.0, 1.0);

    // Green flash fullscreen
    addQuad(verts, &idx, 0, 0, sw, sh, scaleAlpha(flash_color, alpha));

    // Level number centred on screen
    const num_digits = bitmap_font.digitCount(state.level);
    const glyph_w: f32 = @floatFromInt(bitmap_font.GLYPH_W);
    const glyph_h: f32 = @floatFromInt(bitmap_font.GLYPH_H);
    const total_w = @as(f32, @floatFromInt(num_digits)) * (glyph_w * pixel_scale + digit_spacing) - digit_spacing;
    const text_x = sw / 2.0 - total_w / 2.0;
    const text_y = sh / 2.0 - (glyph_h * pixel_scale) / 2.0;

    drawNumber(verts, &idx, text_x, text_y, state.level, scaleAlpha(text_color, alpha), scaleAlpha(shadow_color, alpha));

    return idx;
}

// ── Tests ───────────────────────────────────────────────────────────

test "default state is inactive" {
    const state = LevelUpState{};
    try std.testing.expect(!state.active);
    try std.testing.expectEqual(@as(u32, 0), state.level);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), state.timer, 0.001);
}

test "trigger activates state with correct level" {
    var state = LevelUpState{};
    state.trigger(5);
    try std.testing.expect(state.active);
    try std.testing.expectEqual(@as(u32, 5), state.level);
    try std.testing.expectApproxEqAbs(effect_duration, state.timer, 0.001);
}

test "trigger replaces previous state" {
    var state = LevelUpState{};
    state.trigger(3);
    state.trigger(10);
    try std.testing.expectEqual(@as(u32, 10), state.level);
    try std.testing.expectApproxEqAbs(effect_duration, state.timer, 0.001);
}

test "update decrements timer" {
    var state = LevelUpState{};
    state.trigger(1);
    state.update(0.5);
    try std.testing.expect(state.active);
    try std.testing.expectApproxEqAbs(effect_duration - 0.5, state.timer, 0.001);
}

test "update deactivates after duration expires" {
    var state = LevelUpState{};
    state.trigger(1);
    state.update(effect_duration + 0.1);
    try std.testing.expect(!state.active);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), state.timer, 0.001);
}

test "update is no-op when inactive" {
    var state = LevelUpState{};
    state.update(1.0);
    try std.testing.expect(!state.active);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), state.timer, 0.001);
}

test "render returns start when inactive" {
    var buf: [max_vertices]UiVertex = undefined;
    const state = LevelUpState{};
    const count = render(&buf, 0, 800.0, 600.0, state);
    try std.testing.expectEqual(@as(u32, 0), count);
}

test "render emits vertices in multiples of 6" {
    var buf: [max_vertices]UiVertex = undefined;
    var state = LevelUpState{};
    state.trigger(7);
    const end = render(&buf, 0, 800.0, 600.0, state);
    try std.testing.expect(end > 0);
    try std.testing.expect(end % 6 == 0);
}

test "render preserves start offset" {
    var buf: [max_vertices]UiVertex = undefined;
    var state = LevelUpState{};
    state.trigger(42);
    const end = render(&buf, 12, 1920.0, 1080.0, state);
    try std.testing.expect(end >= 12);
    try std.testing.expect((end - 12) % 6 == 0);
}

test "all rendered vertices have u=-1 and v=-1" {
    var buf: [max_vertices]UiVertex = undefined;
    var state = LevelUpState{};
    state.trigger(99);
    const end = render(&buf, 0, 1280.0, 720.0, state);
    var i: u32 = 0;
    while (i < end) : (i += 1) {
        try std.testing.expectApproxEqAbs(@as(f32, -1.0), buf[i].u, 0.001);
        try std.testing.expectApproxEqAbs(@as(f32, -1.0), buf[i].v, 0.001);
    }
}

test "flash quad covers full screen" {
    var buf: [max_vertices]UiVertex = undefined;
    var state = LevelUpState{};
    state.trigger(1);
    _ = render(&buf, 0, 800.0, 600.0, state);
    // First quad (6 verts) is the fullscreen flash
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), buf[0].pos_x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), buf[0].pos_y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 800.0), buf[1].pos_x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 600.0), buf[2].pos_y, 0.001);
}

test "flash has green tint" {
    var buf: [max_vertices]UiVertex = undefined;
    var state = LevelUpState{};
    state.trigger(1);
    _ = render(&buf, 0, 800.0, 600.0, state);
    // Green channel should dominate in the flash quad
    try std.testing.expect(buf[0].g > buf[0].r);
    try std.testing.expect(buf[0].g > buf[0].b);
}

test "alpha fades over time" {
    var buf1: [max_vertices]UiVertex = undefined;
    var buf2: [max_vertices]UiVertex = undefined;
    var state1 = LevelUpState{};
    var state2 = LevelUpState{};
    state1.trigger(1);
    state2.trigger(1);
    state2.update(0.75);

    _ = render(&buf1, 0, 800.0, 600.0, state1);
    _ = render(&buf2, 0, 800.0, 600.0, state2);

    // Fresh effect should have higher alpha than half-expired one
    try std.testing.expect(buf1[0].a > buf2[0].a);
}

test "level number is centred horizontally" {
    var buf: [max_vertices]UiVertex = undefined;
    var state = LevelUpState{};
    state.trigger(5);
    _ = render(&buf, 0, 800.0, 600.0, state);
    // Digit pixel quads start after the fullscreen flash (6 verts).
    // The shadow quad comes first at index 6, then the foreground at 12.
    // The foreground x should be near the centre of the 800px screen.
    const fg_x = buf[12].pos_x;
    try std.testing.expect(fg_x > 300.0);
    try std.testing.expect(fg_x < 500.0);
}

test "buffer overflow is handled gracefully" {
    var small: [6]UiVertex = undefined;
    var state = LevelUpState{};
    state.trigger(999);
    const end = render(&small, 0, 800.0, 600.0, state);
    // Only the flash quad fits; digit quads silently skipped
    try std.testing.expect(end <= 6);
}

test "render with level 0 shows single digit" {
    var buf: [max_vertices]UiVertex = undefined;
    var state = LevelUpState{};
    state.trigger(0);
    const end = render(&buf, 0, 800.0, 600.0, state);
    // 1 flash quad + digit pixel quads for '0' (the glyph 0 has many lit pixels)
    try std.testing.expect(end > 6);
    try std.testing.expect(end % 6 == 0);
}
