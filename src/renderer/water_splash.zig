/// Water splash particle system for water-entry effects.
/// White-blue particles burst outward when an entity enters water;
/// higher velocity produces a larger, more intense splash.
const std = @import("std");

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

pub const SplashParticle = struct {
    x: f32,
    y: f32,
    z: f32,
    vx: f32,
    vy: f32,
    vz: f32,
    life: f32,
    size: f32,
};

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const MAX_PARTICLES = 16;
const GRAVITY: f32 = 9.8;
const DRAG: f32 = 0.98;
const BASE_LIFETIME: f32 = 0.6;
const MIN_SIZE: f32 = 0.03;
const MAX_SIZE: f32 = 0.12;
const MAX_INTENSITY: f32 = 1.0;
const INTENSITY_SCALE: f32 = 0.15;

// ---------------------------------------------------------------------------
// Deterministic PRNG helpers
// ---------------------------------------------------------------------------

fn xorshift(state: u32) u32 {
    var s = state;
    s ^= s << 13;
    s ^= s >> 17;
    s ^= s << 5;
    return s;
}

fn hashToFloat01(h: u32) f32 {
    return @as(f32, @floatFromInt(h & 0xFFFF)) / 65536.0;
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Spawn 16 splash particles at the given position.
/// `velocity` controls spread and upward force; `seed` drives deterministic
/// randomness so identical inputs always produce the same burst.
pub fn spawnSplash(x: f32, y: f32, z: f32, velocity: f32, seed: u32) [16]SplashParticle {
    var result: [16]SplashParticle = @splat(std.mem.zeroes(SplashParticle));
    var state = seed;
    if (state == 0) state = 1;

    const spread = @min(velocity, 10.0);

    for (0..MAX_PARTICLES) |i| {
        // Random horizontal direction
        state = xorshift(state);
        const angle = hashToFloat01(state) * std.math.pi * 2.0;
        state = xorshift(state);
        const radius = hashToFloat01(state) * spread * 0.5;

        // Horizontal velocity components
        const hx = @cos(angle) * radius;
        const hz = @sin(angle) * radius;

        // Upward velocity biased by entry speed
        state = xorshift(state);
        const up_t = hashToFloat01(state);
        const vy = spread * 0.5 + up_t * spread * 0.5;

        // Particle size
        state = xorshift(state);
        const size_t = hashToFloat01(state);
        const size = MIN_SIZE + (MAX_SIZE - MIN_SIZE) * size_t;

        // Lifetime varies per particle
        state = xorshift(state);
        const life_t = hashToFloat01(state);
        const life = BASE_LIFETIME * (0.6 + 0.4 * life_t);

        result[i] = .{
            .x = x,
            .y = y,
            .z = z,
            .vx = hx,
            .vy = vy,
            .vz = hz,
            .life = life,
            .size = size,
        };
    }

    return result;
}

/// Advance a single splash particle by `dt` seconds.
/// Returns `true` while the particle is still alive.
pub fn updateSplash(p: *SplashParticle, dt: f32) bool {
    p.life -= dt;
    if (p.life <= 0.0) {
        p.life = 0.0;
        return false;
    }

    // Apply gravity
    p.vy -= GRAVITY * dt;

    // Integrate position
    p.x += p.vx * dt;
    p.y += p.vy * dt;
    p.z += p.vz * dt;

    // Air drag
    p.vx *= DRAG;
    p.vz *= DRAG;

    return true;
}

/// Map fall distance to a visual intensity in [0, 1].
/// Short falls produce subtle splashes; long falls produce dramatic ones.
pub fn getSplashIntensity(fall_distance: f32) f32 {
    if (fall_distance <= 0.0) return 0.0;
    const raw = fall_distance * INTENSITY_SCALE;
    return @min(raw, MAX_INTENSITY);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "spawnSplash returns 16 live particles" {
    const particles = spawnSplash(0.0, 64.0, 0.0, 5.0, 42);
    var alive: u32 = 0;
    for (particles) |p| {
        if (p.life > 0.0) alive += 1;
    }
    try std.testing.expectEqual(@as(u32, 16), alive);
}

test "spawnSplash is deterministic with same seed" {
    const a = spawnSplash(1.0, 2.0, 3.0, 4.0, 999);
    const b = spawnSplash(1.0, 2.0, 3.0, 4.0, 999);
    for (0..MAX_PARTICLES) |i| {
        try std.testing.expectApproxEqAbs(a[i].x, b[i].x, 0.0001);
        try std.testing.expectApproxEqAbs(a[i].vy, b[i].vy, 0.0001);
        try std.testing.expectApproxEqAbs(a[i].life, b[i].life, 0.0001);
        try std.testing.expectApproxEqAbs(a[i].size, b[i].size, 0.0001);
    }
}

test "spawnSplash different seeds produce different results" {
    const a = spawnSplash(0.0, 0.0, 0.0, 5.0, 1);
    const b = spawnSplash(0.0, 0.0, 0.0, 5.0, 2);
    var any_diff = false;
    for (0..MAX_PARTICLES) |i| {
        if (@abs(a[i].vx - b[i].vx) > 0.0001) any_diff = true;
    }
    try std.testing.expect(any_diff);
}

test "spawnSplash with seed zero does not hang" {
    const particles = spawnSplash(0.0, 0.0, 0.0, 3.0, 0);
    var alive: u32 = 0;
    for (particles) |p| {
        if (p.life > 0.0) alive += 1;
    }
    try std.testing.expectEqual(@as(u32, 16), alive);
}

test "spawnSplash particle sizes within bounds" {
    const particles = spawnSplash(0.0, 0.0, 0.0, 8.0, 777);
    for (particles) |p| {
        try std.testing.expect(p.size >= MIN_SIZE - 0.001);
        try std.testing.expect(p.size <= MAX_SIZE + 0.001);
    }
}

test "spawnSplash particle lifetimes within expected range" {
    const particles = spawnSplash(0.0, 0.0, 0.0, 5.0, 123);
    for (particles) |p| {
        try std.testing.expect(p.life >= BASE_LIFETIME * 0.6 - 0.001);
        try std.testing.expect(p.life <= BASE_LIFETIME + 0.001);
    }
}

test "spawnSplash higher velocity increases upward speed" {
    const low = spawnSplash(0.0, 0.0, 0.0, 1.0, 42);
    const high = spawnSplash(0.0, 0.0, 0.0, 10.0, 42);
    // Average vy of high-velocity splash should exceed low-velocity
    var sum_low: f32 = 0.0;
    var sum_high: f32 = 0.0;
    for (0..MAX_PARTICLES) |i| {
        sum_low += low[i].vy;
        sum_high += high[i].vy;
    }
    try std.testing.expect(sum_high > sum_low);
}

test "updateSplash returns false when life expires" {
    var p = SplashParticle{ .x = 0, .y = 10, .z = 0, .vx = 1, .vy = 2, .vz = 1, .life = 0.1, .size = 0.05 };
    // Step well past lifetime
    const alive = updateSplash(&p, 0.5);
    try std.testing.expect(!alive);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), p.life, 0.001);
}

test "updateSplash applies gravity" {
    var p = SplashParticle{ .x = 0, .y = 10, .z = 0, .vx = 0, .vy = 5, .vz = 0, .life = 1.0, .size = 0.05 };
    const vy_before = p.vy;
    _ = updateSplash(&p, 0.1);
    try std.testing.expect(p.vy < vy_before);
}

test "updateSplash moves position" {
    var p = SplashParticle{ .x = 0, .y = 0, .z = 0, .vx = 3, .vy = 5, .vz = -2, .life = 1.0, .size = 0.05 };
    _ = updateSplash(&p, 0.1);
    try std.testing.expect(p.x > 0.0);
    try std.testing.expect(p.y > 0.0);
    try std.testing.expect(p.z < 0.0);
}

test "updateSplash reduces lifetime" {
    var p = SplashParticle{ .x = 0, .y = 0, .z = 0, .vx = 0, .vy = 0, .vz = 0, .life = 1.0, .size = 0.05 };
    _ = updateSplash(&p, 0.3);
    try std.testing.expectApproxEqAbs(@as(f32, 0.7), p.life, 0.001);
}

test "getSplashIntensity zero fall returns zero" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), getSplashIntensity(0.0), 0.001);
}

test "getSplashIntensity negative fall returns zero" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), getSplashIntensity(-5.0), 0.001);
}

test "getSplashIntensity scales with distance" {
    const short = getSplashIntensity(2.0);
    const long = getSplashIntensity(5.0);
    try std.testing.expect(long > short);
    try std.testing.expect(short > 0.0);
}

test "getSplashIntensity clamps to 1.0" {
    const intense = getSplashIntensity(100.0);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), intense, 0.001);
}

test "SplashParticle struct has expected fields" {
    const p = SplashParticle{
        .x = 1.0,
        .y = 2.0,
        .z = 3.0,
        .vx = 0.5,
        .vy = 1.5,
        .vz = -0.5,
        .life = 0.8,
        .size = 0.06,
    };
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), p.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), p.y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), p.z, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.06), p.size, 0.001);
}
