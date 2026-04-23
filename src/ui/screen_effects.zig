/// Screen effects overlay renderer.
/// Produces UiVertex quads for full-screen visual effects such as damage flash,
/// heal flash, portal overlay, pumpkin overlay, nausea distortion, and
/// low-health vignette.
const std = @import("std");

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

pub const ScreenEffect = enum {
    none,
    damage_flash,
    heal_flash,
    portal_overlay,
    pumpkin_overlay,
    nausea,
    low_health_vignette,
};

pub const EffectState = struct {
    effect: ScreenEffect = .none,
    timer: f32 = 0,
    intensity: f32 = 0,
};

pub const max_vertices = 2048;

// ── Duration constants ──────────────────────────────────────────────

const flash_duration: f32 = 0.4;
const portal_duration: f32 = 2.0;
const pumpkin_duration: f32 = 999.0;
const nausea_duration: f32 = 1.5;
const vignette_duration: f32 = 999.0;

// ── Colors ──────────────────────────────────────────────────────────

const Color = struct { r: f32, g: f32, b: f32, a: f32 };

const damage_color = Color{ .r = 0.8, .g = 0.0, .b = 0.0, .a = 0.5 };
const heal_color = Color{ .r = 0.0, .g = 0.8, .b = 0.2, .a = 0.5 };
const portal_color = Color{ .r = 0.4, .g = 0.1, .b = 0.6, .a = 0.6 };
const pumpkin_border_color = Color{ .r = 0.05, .g = 0.03, .b = 0.0, .a = 0.9 };
const nausea_color = Color{ .r = 0.2, .g = 0.4, .b = 0.1, .a = 0.4 };
const vignette_color = Color{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 0.7 };

// ── Quad helper ─────────────────────────────────────────────────────

/// Emit a solid-colored quad (2 triangles, 6 vertices). UV set to (-1, -1).
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

// ── Duration lookup ─────────────────────────────────────────────────

fn effectDuration(effect: ScreenEffect) f32 {
    return switch (effect) {
        .none => 0,
        .damage_flash => flash_duration,
        .heal_flash => flash_duration,
        .portal_overlay => portal_duration,
        .pumpkin_overlay => pumpkin_duration,
        .nausea => nausea_duration,
        .low_health_vignette => vignette_duration,
    };
}

// ── Public API ──────────────────────────────────────────────────────

/// Activate a new screen effect, replacing the current one.
pub fn triggerEffect(state: *EffectState, effect: ScreenEffect, intensity: f32) void {
    state.* = .{
        .effect = effect,
        .timer = effectDuration(effect),
        .intensity = std.math.clamp(intensity, 0.0, 1.0),
    };
}

/// Tick the effect timer by `dt` seconds. Resets to `.none` when expired.
pub fn updateEffect(state: *EffectState, dt: f32) void {
    if (state.effect == .none) return;
    state.timer -= dt;
    if (state.timer <= 0) {
        state.* = .{};
    }
}

/// Render the active effect into the vertex buffer starting at `start`.
/// Returns the number of vertices written.
pub fn renderEffect(verts: []UiVertex, start: u32, sw: f32, sh: f32, state: EffectState) u32 {
    if (state.effect == .none) return 0;

    var idx: u32 = start;
    const duration = effectDuration(state.effect);
    const progress: f32 = if (duration > 0) std.math.clamp(state.timer / duration, 0.0, 1.0) else 0;

    switch (state.effect) {
        .none => {},
        .damage_flash => renderFlash(verts, &idx, sw, sh, damage_color, progress, state.intensity),
        .heal_flash => renderFlash(verts, &idx, sw, sh, heal_color, progress, state.intensity),
        .portal_overlay => renderPortalOverlay(verts, &idx, sw, sh, progress, state.intensity),
        .pumpkin_overlay => {
            const border = sw * 0.15 * state.intensity;
            renderBorderFrame(verts, &idx, sw, sh, border, border, pumpkin_border_color);
        },
        .nausea => renderNausea(verts, &idx, sw, sh, progress, state.intensity),
        .low_health_vignette => {
            const frac = 0.25 * state.intensity;
            renderBorderFrame(verts, &idx, sw, sh, sw * frac, sh * frac, vignette_color);
        },
    }

    return idx - start;
}

// ── Effect renderers ────────────────────────────────────────────────

/// Full-screen color flash that fades with progress.
fn renderFlash(verts: []UiVertex, idx: *u32, sw: f32, sh: f32, base: Color, progress: f32, intensity: f32) void {
    const alpha = base.a * progress * intensity;
    const col = Color{ .r = base.r, .g = base.g, .b = base.b, .a = alpha };
    addQuad(verts, idx, 0, 0, sw, sh, col);
}

/// Purple swirl rendered as overlapping offset quads.
fn renderPortalOverlay(verts: []UiVertex, idx: *u32, sw: f32, sh: f32, progress: f32, intensity: f32) void {
    const base_alpha = portal_color.a * intensity * progress;
    const swirl_count: u32 = 4;
    const offset_scale: f32 = sw * 0.05;

    var i: u32 = 0;
    while (i < swirl_count) : (i += 1) {
        const fi = @as(f32, @floatFromInt(i));
        const angle = fi * std.math.pi * 0.5 + progress * std.math.pi * 2.0;
        const ox = @cos(angle) * offset_scale;
        const oy = @sin(angle) * offset_scale;
        const layer_alpha = base_alpha * (1.0 - fi * 0.15);
        const col = Color{ .r = portal_color.r, .g = portal_color.g, .b = portal_color.b, .a = layer_alpha };
        addQuad(verts, idx, ox, oy, sw, sh, col);
    }
}

/// Four-sided border frame (used by pumpkin overlay and vignette).
fn renderBorderFrame(verts: []UiVertex, idx: *u32, sw: f32, sh: f32, edge_w: f32, edge_h: f32, col: Color) void {
    addQuad(verts, idx, 0, 0, sw, edge_h, col);
    addQuad(verts, idx, 0, sh - edge_h, sw, edge_h, col);
    addQuad(verts, idx, 0, edge_h, edge_w, sh - edge_h * 2.0, col);
    addQuad(verts, idx, sw - edge_w, edge_h, edge_w, sh - edge_h * 2.0, col);
}

/// Green-tinted overlay for nausea.
fn renderNausea(verts: []UiVertex, idx: *u32, sw: f32, sh: f32, progress: f32, intensity: f32) void {
    const alpha = nausea_color.a * intensity * progress;
    const wave = @sin(progress * std.math.pi * 4.0) * 0.15 * intensity;
    const col = Color{ .r = nausea_color.r + wave, .g = nausea_color.g, .b = nausea_color.b, .a = alpha };
    addQuad(verts, idx, 0, 0, sw, sh, col);
}

// ── Tests ───────────────────────────────────────────────────────────

test "triggerEffect sets state correctly" {
    var state = EffectState{};
    triggerEffect(&state, .damage_flash, 0.75);
    try std.testing.expectEqual(ScreenEffect.damage_flash, state.effect);
    try std.testing.expectApproxEqAbs(@as(f32, 0.4), state.timer, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.75), state.intensity, 0.001);
}

test "triggerEffect clamps intensity above 1" {
    var state = EffectState{};
    triggerEffect(&state, .heal_flash, 5.0);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), state.intensity, 0.001);
}

test "triggerEffect clamps intensity below 0" {
    var state = EffectState{};
    triggerEffect(&state, .heal_flash, -2.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), state.intensity, 0.001);
}

test "updateEffect decrements timer" {
    var state = EffectState{};
    triggerEffect(&state, .damage_flash, 1.0);
    const initial_timer = state.timer;
    updateEffect(&state, 0.1);
    try std.testing.expectApproxEqAbs(initial_timer - 0.1, state.timer, 0.001);
    try std.testing.expectEqual(ScreenEffect.damage_flash, state.effect);
}

test "updateEffect resets when timer expires" {
    var state = EffectState{};
    triggerEffect(&state, .damage_flash, 1.0);
    updateEffect(&state, 10.0);
    try std.testing.expectEqual(ScreenEffect.none, state.effect);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), state.timer, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), state.intensity, 0.001);
}

test "updateEffect is no-op for none" {
    var state = EffectState{};
    updateEffect(&state, 1.0);
    try std.testing.expectEqual(ScreenEffect.none, state.effect);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), state.timer, 0.001);
}

test "renderEffect returns 0 for none" {
    var buf: [64]UiVertex = undefined;
    const state = EffectState{};
    const count = renderEffect(&buf, 0, 800, 600, state);
    try std.testing.expectEqual(@as(u32, 0), count);
}

test "renderEffect damage_flash emits 6 vertices" {
    var buf: [64]UiVertex = undefined;
    var state = EffectState{};
    triggerEffect(&state, .damage_flash, 1.0);
    const count = renderEffect(&buf, 0, 800, 600, state);
    try std.testing.expectEqual(@as(u32, 6), count);
    // First vertex should be red-tinted at origin
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), buf[0].pos_x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), buf[0].pos_y, 0.001);
    try std.testing.expect(buf[0].r > 0.5);
    try std.testing.expect(buf[0].a > 0.0);
    try std.testing.expectApproxEqAbs(@as(f32, -1.0), buf[0].u, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, -1.0), buf[0].v, 0.001);
}

test "renderEffect heal_flash emits green quad" {
    var buf: [64]UiVertex = undefined;
    var state = EffectState{};
    triggerEffect(&state, .heal_flash, 1.0);
    const count = renderEffect(&buf, 0, 800, 600, state);
    try std.testing.expectEqual(@as(u32, 6), count);
    // Green channel should dominate
    try std.testing.expect(buf[0].g > buf[0].r);
}

test "renderEffect portal_overlay emits swirl quads" {
    var buf: [256]UiVertex = undefined;
    var state = EffectState{};
    triggerEffect(&state, .portal_overlay, 1.0);
    const count = renderEffect(&buf, 0, 800, 600, state);
    // 4 swirl layers x 6 vertices = 24
    try std.testing.expectEqual(@as(u32, 24), count);
    // Should have purple tint
    try std.testing.expect(buf[0].b > buf[0].g);
}

test "renderEffect pumpkin_overlay emits 4 border quads" {
    var buf: [256]UiVertex = undefined;
    var state = EffectState{};
    triggerEffect(&state, .pumpkin_overlay, 1.0);
    const count = renderEffect(&buf, 0, 800, 600, state);
    // 4 borders x 6 vertices = 24
    try std.testing.expectEqual(@as(u32, 24), count);
}

test "renderEffect vignette emits 4 edge quads" {
    var buf: [256]UiVertex = undefined;
    var state = EffectState{};
    triggerEffect(&state, .low_health_vignette, 1.0);
    const count = renderEffect(&buf, 0, 800, 600, state);
    // 4 edges x 6 vertices = 24
    try std.testing.expectEqual(@as(u32, 24), count);
    // Vignette should be dark (low r, g, b)
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), buf[0].r, 0.001);
}

test "renderEffect nausea emits 6 vertices" {
    var buf: [64]UiVertex = undefined;
    var state = EffectState{};
    triggerEffect(&state, .nausea, 1.0);
    const count = renderEffect(&buf, 0, 800, 600, state);
    try std.testing.expectEqual(@as(u32, 6), count);
}

test "renderEffect respects start offset" {
    var buf: [128]UiVertex = undefined;
    var state = EffectState{};
    triggerEffect(&state, .damage_flash, 1.0);
    const count = renderEffect(&buf, 10, 800, 600, state);
    try std.testing.expectEqual(@as(u32, 6), count);
    // Vertex at index 10 should be populated
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), buf[10].pos_x, 0.001);
}

test "triggerEffect replaces existing effect" {
    var state = EffectState{};
    triggerEffect(&state, .damage_flash, 1.0);
    triggerEffect(&state, .heal_flash, 0.5);
    try std.testing.expectEqual(ScreenEffect.heal_flash, state.effect);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), state.intensity, 0.001);
}

test "default EffectState is none" {
    const state = EffectState{};
    try std.testing.expectEqual(ScreenEffect.none, state.effect);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), state.timer, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), state.intensity, 0.001);
}

test "damage flash alpha fades over time" {
    var buf1: [64]UiVertex = undefined;
    var buf2: [64]UiVertex = undefined;
    var state1 = EffectState{};
    var state2 = EffectState{};
    triggerEffect(&state1, .damage_flash, 1.0);
    triggerEffect(&state2, .damage_flash, 1.0);
    updateEffect(&state2, 0.2);

    _ = renderEffect(&buf1, 0, 800, 600, state1);
    _ = renderEffect(&buf2, 0, 800, 600, state2);

    // Fresh flash should have higher alpha than half-expired one
    try std.testing.expect(buf1[0].a > buf2[0].a);
}

test "buffer overflow is handled gracefully" {
    // Buffer too small for even one quad
    var buf: [3]UiVertex = undefined;
    var state = EffectState{};
    triggerEffect(&state, .damage_flash, 1.0);
    const count = renderEffect(&buf, 0, 800, 600, state);
    try std.testing.expectEqual(@as(u32, 0), count);
}
