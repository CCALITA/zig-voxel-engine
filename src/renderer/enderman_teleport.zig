/// Enderman teleport visual effect: purple particle bursts at the start and
/// end positions that fade out over a short duration.
const std = @import("std");

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

/// A single purple particle with position and RGBA color.
pub const Particle = struct {
    x: f32,
    y: f32,
    z: f32,
    r: f32,
    g: f32,
    b: f32,
    a: f32,
};

/// Tracks the lifecycle of one enderman teleport visual.
pub const TeleportEffect = struct {
    start_x: f32 = 0,
    start_y: f32 = 0,
    start_z: f32 = 0,
    end_x: f32 = 0,
    end_y: f32 = 0,
    end_z: f32 = 0,
    timer: f32 = 0,
    duration: f32 = 0.3,
    active: bool = false,
};

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const PARTICLE_COUNT: usize = 16;
const HALF_COUNT: usize = PARTICLE_COUNT / 2;
const DEFAULT_DURATION: f32 = 0.3;

/// Base purple color channels (r, g, b).
const PURPLE_R: f32 = 0.6;
const PURPLE_G: f32 = 0.0;
const PURPLE_B: f32 = 0.8;

/// Maximum spread of particles around their anchor point.
const SPREAD: f32 = 0.8;

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Create an active teleport effect between two world positions.
pub fn triggerTeleport(sx: f32, sy: f32, sz: f32, ex: f32, ey: f32, ez: f32) TeleportEffect {
    return .{
        .start_x = sx,
        .start_y = sy,
        .start_z = sz,
        .end_x = ex,
        .end_y = ey,
        .end_z = ez,
        .timer = DEFAULT_DURATION,
        .duration = DEFAULT_DURATION,
        .active = true,
    };
}

/// Advance the effect timer by `dt` seconds.
/// Returns `true` while the effect is still visible.
pub fn update(e: *TeleportEffect, dt: f32) bool {
    if (!e.active) return false;
    e.timer -= dt;
    if (e.timer <= 0) {
        e.active = false;
        e.timer = 0;
        return false;
    }
    return true;
}

/// Compute 16 purple particles: the first 8 around the start position,
/// the last 8 around the end position.  Alpha fades with the remaining
/// timer so the burst disappears smoothly.
pub fn getParticles(e: TeleportEffect) [PARTICLE_COUNT]Particle {
    var result: [PARTICLE_COUNT]Particle = undefined;

    const progress = if (e.duration > 0) e.timer / e.duration else 0;
    const alpha = clamp01(progress);

    const angle_step = std.math.tau / @as(f32, @floatFromInt(HALF_COUNT));

    for (0..PARTICLE_COUNT) |i| {
        const fi: f32 = @floatFromInt(i);
        const angle = fi * angle_step;
        const offset_x = @sin(angle) * SPREAD * (1.0 - 0.3 * progress);
        const offset_y = @cos(angle) * SPREAD * 0.5;
        const offset_z = @cos(angle + std.math.pi * 0.25) * SPREAD * 0.4;

        const tint = 0.1 * @sin(fi * 1.7);

        const anchor_x = if (i < HALF_COUNT) e.start_x else e.end_x;
        const anchor_y = if (i < HALF_COUNT) e.start_y else e.end_y;
        const anchor_z = if (i < HALF_COUNT) e.start_z else e.end_z;

        result[i] = .{
            .x = anchor_x + offset_x,
            .y = anchor_y + offset_y,
            .z = anchor_z + offset_z,
            .r = clamp01(PURPLE_R + tint),
            .g = PURPLE_G,
            .b = clamp01(PURPLE_B + tint),
            .a = alpha,
        };
    }

    return result;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

fn clamp01(v: f32) f32 {
    return @max(0.0, @min(1.0, v));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "triggerTeleport returns active effect with correct positions" {
    const e = triggerTeleport(1, 2, 3, 4, 5, 6);
    try std.testing.expect(e.active);
    try std.testing.expectApproxEqAbs(@as(f32, 1), e.start_x, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 2), e.start_y, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 3), e.start_z, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 4), e.end_x, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 5), e.end_y, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 6), e.end_z, 0.0001);
    try std.testing.expectApproxEqAbs(DEFAULT_DURATION, e.timer, 0.0001);
}

test "update returns false for inactive effect" {
    var e = TeleportEffect{};
    const alive = update(&e, 0.016);
    try std.testing.expect(!alive);
}

test "update decrements timer while active" {
    var e = triggerTeleport(0, 0, 0, 1, 1, 1);
    const alive = update(&e, 0.1);
    try std.testing.expect(alive);
    try std.testing.expectApproxEqAbs(@as(f32, 0.2), e.timer, 0.0001);
}

test "update deactivates when timer expires" {
    var e = triggerTeleport(0, 0, 0, 1, 1, 1);
    const alive = update(&e, 0.5);
    try std.testing.expect(!alive);
    try std.testing.expect(!e.active);
    try std.testing.expectApproxEqAbs(@as(f32, 0), e.timer, 0.0001);
}

test "multiple updates drain timer correctly" {
    var e = triggerTeleport(0, 0, 0, 5, 5, 5);
    _ = update(&e, 0.1);
    _ = update(&e, 0.1);
    try std.testing.expect(e.active);
    try std.testing.expectApproxEqAbs(@as(f32, 0.1), e.timer, 0.0001);
    const last = update(&e, 0.15);
    try std.testing.expect(!last);
    try std.testing.expect(!e.active);
}

test "getParticles returns 16 particles" {
    const e = triggerTeleport(0, 0, 0, 10, 10, 10);
    const ps = getParticles(e);
    try std.testing.expectEqual(@as(usize, 16), ps.len);
}

test "first 8 particles are near start, last 8 near end" {
    const e = triggerTeleport(0, 0, 0, 100, 100, 100);
    const ps = getParticles(e);
    for (0..8) |i| {
        try std.testing.expect(ps[i].x < 50);
        try std.testing.expect(ps[i].y < 50);
    }
    for (8..16) |i| {
        try std.testing.expect(ps[i].x > 50);
        try std.testing.expect(ps[i].y > 50);
    }
}

test "particles are purple: r and b dominate over g" {
    const e = triggerTeleport(0, 0, 0, 5, 5, 5);
    const ps = getParticles(e);
    for (ps) |p| {
        try std.testing.expect(p.r > p.g);
        try std.testing.expect(p.b > p.g);
    }
}

test "particle color channels clamped to [0,1]" {
    const e = triggerTeleport(-50, -50, -50, 50, 50, 50);
    const ps = getParticles(e);
    for (ps) |p| {
        try std.testing.expect(p.r >= 0.0 and p.r <= 1.0);
        try std.testing.expect(p.g >= 0.0 and p.g <= 1.0);
        try std.testing.expect(p.b >= 0.0 and p.b <= 1.0);
        try std.testing.expect(p.a >= 0.0 and p.a <= 1.0);
    }
}

test "particle alpha fades toward zero as timer decreases" {
    var e = triggerTeleport(0, 0, 0, 1, 1, 1);
    const full = getParticles(e);
    _ = update(&e, 0.15);
    const half = getParticles(e);
    // Alpha at start should be ~1.0, at midpoint ~0.5
    try std.testing.expect(full[0].a > half[0].a);
}

test "getParticles is deterministic" {
    const e = triggerTeleport(3, 4, 5, 6, 7, 8);
    const a = getParticles(e);
    const b = getParticles(e);
    for (0..PARTICLE_COUNT) |i| {
        try std.testing.expectApproxEqAbs(a[i].x, b[i].x, 0.0001);
        try std.testing.expectApproxEqAbs(a[i].y, b[i].y, 0.0001);
        try std.testing.expectApproxEqAbs(a[i].z, b[i].z, 0.0001);
        try std.testing.expectApproxEqAbs(a[i].r, b[i].r, 0.0001);
    }
}

test "TeleportEffect default values" {
    const e = TeleportEffect{};
    try std.testing.expect(!e.active);
    try std.testing.expectApproxEqAbs(@as(f32, 0), e.timer, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.3), e.duration, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), e.start_x, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), e.end_x, 0.0001);
}

test "inactive effect produces zero-alpha particles" {
    const e = TeleportEffect{};
    const ps = getParticles(e);
    for (ps) |p| {
        try std.testing.expectApproxEqAbs(@as(f32, 0), p.a, 0.0001);
    }
}
