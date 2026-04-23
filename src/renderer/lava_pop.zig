/// Lava pop particle system for orange bubble effects on lava surfaces.
/// Deterministic spawning and physics driven by a seed-based PRNG so
/// identical inputs always produce the same visual result.
const std = @import("std");

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

pub const LavaPopParticle = struct {
    x: f32,
    y: f32,
    z: f32,
    vy: f32,
    life: f32,
    size: f32,
    r: f32,
    g: f32,
    b: f32,
    a: f32,
};

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const SPAWN_THRESHOLD: u32 = 0x19999999; // ~10% of u32 range
const GRAVITY: f32 = 4.0;
const BASE_LIFE: f32 = 0.6;
const LIFE_VARIATION: f32 = 0.3;
const BASE_VY: f32 = 1.8;
const VY_VARIATION: f32 = 0.6;
const BASE_SIZE: f32 = 0.06;
const SIZE_VARIATION: f32 = 0.03;
const SPREAD: f32 = 0.4;

// Orange palette bounds
const BASE_R: f32 = 1.0;
const BASE_G: f32 = 0.45;
const BASE_B: f32 = 0.0;
const BASE_A: f32 = 0.9;
const G_VARIATION: f32 = 0.15;

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

/// Map a hash to a value in [base - variation, base + variation].
fn vary(h: u32, base: f32, variation: f32) f32 {
    return base + (hashToFloat01(h) * 2.0 - 1.0) * variation;
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Returns true roughly 10% of the time, determined by `seed`.
pub fn shouldSpawn(seed: u32) bool {
    var s = seed;
    if (s == 0) s = 1;
    const h = xorshift(s);
    return h <= SPAWN_THRESHOLD;
}

/// Attempt to spawn a lava pop particle at the given surface position.
/// Returns `null` when `shouldSpawn` rejects the seed (roughly 90% of calls).
pub fn spawnLavaPop(sx: f32, sy: f32, sz: f32, seed: u32) ?LavaPopParticle {
    if (!shouldSpawn(seed)) return null;

    var state = seed;
    if (state == 0) state = 1;

    // Horizontal offset
    state = xorshift(state);
    const ox = vary(state, 0.0, SPREAD);
    state = xorshift(state);
    const oz = vary(state, 0.0, SPREAD);

    // Vertical velocity
    state = xorshift(state);
    const vy = vary(state, BASE_VY, VY_VARIATION);

    // Lifetime
    state = xorshift(state);
    const life = vary(state, BASE_LIFE, LIFE_VARIATION);

    // Size
    state = xorshift(state);
    const size = vary(state, BASE_SIZE, SIZE_VARIATION);

    // Slight green-channel variation for color diversity
    state = xorshift(state);
    const g = vary(state, BASE_G, G_VARIATION);

    return .{
        .x = sx + ox,
        .y = sy,
        .z = sz + oz,
        .vy = vy,
        .life = life,
        .size = size,
        .r = BASE_R,
        .g = g,
        .b = BASE_B,
        .a = BASE_A,
    };
}

/// Advance a lava pop particle by `dt` seconds.
/// Applies upward velocity, gravity, and alpha fade.
/// Returns `true` while the particle is still alive.
pub fn updatePop(p: *LavaPopParticle, dt: f32) bool {
    p.life -= dt;
    if (p.life <= 0.0) return false;

    // Rise then fall
    p.y += p.vy * dt;
    p.vy -= GRAVITY * dt;

    // Shrink over lifetime
    p.size *= 1.0 - 0.5 * dt;
    if (p.size < 0.01) p.size = 0.01;

    // Fade out
    p.a -= dt * 0.8;
    if (p.a < 0.0) p.a = 0.0;

    return true;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "shouldSpawn returns true roughly 10% of the time" {
    var hits: u32 = 0;
    const total: u32 = 10000;
    for (1..total + 1) |i| {
        if (shouldSpawn(@intCast(i))) hits += 1;
    }
    // Expect between 5% and 20% (generous bounds for deterministic hash)
    try std.testing.expect(hits > total / 20);
    try std.testing.expect(hits < total / 5);
}

test "shouldSpawn seed zero does not hang" {
    _ = shouldSpawn(0);
}

test "shouldSpawn is deterministic" {
    const a = shouldSpawn(42);
    const b = shouldSpawn(42);
    try std.testing.expectEqual(a, b);
}

test "spawnLavaPop returns null when shouldSpawn is false" {
    // Find a seed that does not spawn
    var seed: u32 = 1;
    while (shouldSpawn(seed)) : (seed += 1) {}
    const result = spawnLavaPop(0, 0, 0, seed);
    try std.testing.expect(result == null);
}

test "spawnLavaPop returns particle when shouldSpawn is true" {
    // Find a seed that does spawn
    var seed: u32 = 1;
    while (!shouldSpawn(seed)) : (seed += 1) {}
    const result = spawnLavaPop(5.0, 64.0, 10.0, seed);
    try std.testing.expect(result != null);
    const p = result.?;
    try std.testing.expect(p.life > 0.0);
    try std.testing.expect(p.size > 0.0);
}

test "spawnLavaPop particle has orange color" {
    var seed: u32 = 1;
    while (!shouldSpawn(seed)) : (seed += 1) {}
    const p = spawnLavaPop(0, 0, 0, seed).?;
    // Red channel should be 1.0 (bright orange)
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), p.r, 0.001);
    // Blue channel should be 0.0
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), p.b, 0.001);
    // Green channel between 0.3 and 0.6
    try std.testing.expect(p.g >= 0.25);
    try std.testing.expect(p.g <= 0.65);
}

test "spawnLavaPop is deterministic with same seed" {
    var seed: u32 = 1;
    while (!shouldSpawn(seed)) : (seed += 1) {}
    const a = spawnLavaPop(1.0, 2.0, 3.0, seed).?;
    const b = spawnLavaPop(1.0, 2.0, 3.0, seed).?;
    try std.testing.expectApproxEqAbs(a.x, b.x, 0.0001);
    try std.testing.expectApproxEqAbs(a.y, b.y, 0.0001);
    try std.testing.expectApproxEqAbs(a.z, b.z, 0.0001);
    try std.testing.expectApproxEqAbs(a.vy, b.vy, 0.0001);
    try std.testing.expectApproxEqAbs(a.life, b.life, 0.0001);
    try std.testing.expectApproxEqAbs(a.size, b.size, 0.0001);
}

test "spawnLavaPop particle spawns near origin" {
    var seed: u32 = 1;
    while (!shouldSpawn(seed)) : (seed += 1) {}
    const p = spawnLavaPop(10.0, 20.0, 30.0, seed).?;
    try std.testing.expect(p.x >= 10.0 - SPREAD - 0.001);
    try std.testing.expect(p.x <= 10.0 + SPREAD + 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 20.0), p.y, 0.001);
    try std.testing.expect(p.z >= 30.0 - SPREAD - 0.001);
    try std.testing.expect(p.z <= 30.0 + SPREAD + 0.001);
}

test "updatePop reduces life" {
    var p = LavaPopParticle{
        .x = 0, .y = 64, .z = 0,
        .vy = 2.0, .life = 0.8, .size = 0.06,
        .r = 1.0, .g = 0.45, .b = 0.0, .a = 0.9,
    };
    const before = p.life;
    const alive = updatePop(&p, 0.1);
    try std.testing.expect(alive);
    try std.testing.expect(p.life < before);
}

test "updatePop returns false when life expires" {
    var p = LavaPopParticle{
        .x = 0, .y = 64, .z = 0,
        .vy = 1.0, .life = 0.05, .size = 0.06,
        .r = 1.0, .g = 0.45, .b = 0.0, .a = 0.9,
    };
    const alive = updatePop(&p, 0.1);
    try std.testing.expect(!alive);
}

test "updatePop applies gravity to vy" {
    var p = LavaPopParticle{
        .x = 0, .y = 64, .z = 0,
        .vy = 2.0, .life = 1.0, .size = 0.06,
        .r = 1.0, .g = 0.45, .b = 0.0, .a = 0.9,
    };
    const vy_before = p.vy;
    _ = updatePop(&p, 0.1);
    try std.testing.expect(p.vy < vy_before);
}

test "updatePop moves particle upward initially" {
    var p = LavaPopParticle{
        .x = 0, .y = 64, .z = 0,
        .vy = 2.0, .life = 1.0, .size = 0.06,
        .r = 1.0, .g = 0.45, .b = 0.0, .a = 0.9,
    };
    const y_before = p.y;
    _ = updatePop(&p, 0.05);
    try std.testing.expect(p.y > y_before);
}

test "updatePop fades alpha over time" {
    var p = LavaPopParticle{
        .x = 0, .y = 64, .z = 0,
        .vy = 2.0, .life = 1.0, .size = 0.06,
        .r = 1.0, .g = 0.45, .b = 0.0, .a = 0.9,
    };
    const a_before = p.a;
    _ = updatePop(&p, 0.2);
    try std.testing.expect(p.a < a_before);
}

test "updatePop shrinks size over time" {
    var p = LavaPopParticle{
        .x = 0, .y = 64, .z = 0,
        .vy = 2.0, .life = 1.0, .size = 0.06,
        .r = 1.0, .g = 0.45, .b = 0.0, .a = 0.9,
    };
    const size_before = p.size;
    _ = updatePop(&p, 0.2);
    try std.testing.expect(p.size < size_before);
    try std.testing.expect(p.size >= 0.01);
}

test "updatePop alpha does not go below zero" {
    var p = LavaPopParticle{
        .x = 0, .y = 64, .z = 0,
        .vy = 1.0, .life = 5.0, .size = 0.06,
        .r = 1.0, .g = 0.45, .b = 0.0, .a = 0.1,
    };
    _ = updatePop(&p, 0.5);
    try std.testing.expect(p.a >= 0.0);
}
