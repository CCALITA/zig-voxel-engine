const std = @import("std");

/// A lava surface bubble particle that pops up and falls back down.
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

// Physics constants
const gravity: f32 = 9.8;
const initial_vy_min: f32 = 1.5;
const initial_vy_range: f32 = 2.0;
const base_lifetime: f32 = 0.8;
const lifetime_range: f32 = 0.4;
const size_min: f32 = 0.05;
const size_range: f32 = 0.1;
const spawn_spread: f32 = 0.4;
const fade_speed: f32 = 1.2;

// Spawn threshold: 10% chance => values below this threshold trigger a spawn.
// 0.10 * 0xFFFFFFFF = 429_496_729
const spawn_threshold: u32 = 429_496_729;

/// Murmur3 finalizer for strong seed mixing (uniform distribution).
fn murmurMix(input: u32) u32 {
    var h = input;
    h ^= h >> 16;
    h *%= 0x85ebca6b;
    h ^= h >> 13;
    h *%= 0xc2b2ae35;
    h ^= h >> 16;
    return h;
}

/// Deterministic xorshift hash for pseudo-random generation chains.
fn xorshift(state: u32) u32 {
    var s = state;
    s ^= s << 13;
    s ^= s >> 17;
    s ^= s << 5;
    return s;
}

/// Convert a u32 hash to a float in [0, 1).
fn hashToFloat01(h: u32) f32 {
    return @as(f32, @floatFromInt(h & 0xFFFF)) / 65536.0;
}

/// Returns true ~10% of the time based on a deterministic seed hash.
pub fn shouldSpawn(seed: u32) bool {
    const h = murmurMix(if (seed == 0) 1 else seed);
    return h <= spawn_threshold;
}

/// Attempt to spawn a lava pop particle at the given surface position.
/// Returns null 90% of the time (based on seed); returns an orange bubble
/// particle the other 10%.
pub fn spawnLavaPop(surface_x: f32, surface_y: f32, surface_z: f32, seed: u32) ?LavaPopParticle {
    const mixed = murmurMix(if (seed == 0) 1 else seed);
    if (mixed > spawn_threshold) return null;

    var state = mixed;

    // Offset position slightly for visual variety
    state = xorshift(state);
    const offset_x = (hashToFloat01(state) * 2.0 - 1.0) * spawn_spread;
    state = xorshift(state);
    const offset_z = (hashToFloat01(state) * 2.0 - 1.0) * spawn_spread;

    // Upward velocity
    state = xorshift(state);
    const vy = initial_vy_min + hashToFloat01(state) * initial_vy_range;

    // Lifetime
    state = xorshift(state);
    const life = base_lifetime + hashToFloat01(state) * lifetime_range;

    // Size
    state = xorshift(state);
    const size = size_min + hashToFloat01(state) * size_range;

    // Orange color variation
    state = xorshift(state);
    const color_t = hashToFloat01(state);
    const r = 1.0;
    const g = 0.3 + color_t * 0.35;
    const b = 0.05 + color_t * 0.1;

    return LavaPopParticle{
        .x = surface_x + offset_x,
        .y = surface_y,
        .z = surface_z + offset_z,
        .vy = vy,
        .life = life,
        .size = size,
        .r = r,
        .g = g,
        .b = b,
        .a = 1.0,
    };
}

/// Update a lava pop particle by one tick. Applies gravity, reduces life,
/// and fades alpha. Returns true if the particle is still alive.
pub fn updatePop(p: *LavaPopParticle, dt: f32) bool {
    p.life -= dt;
    if (p.life <= 0.0) return false;

    p.vy -= gravity * dt;
    p.y += p.vy * dt;

    p.a = @max(0.0, p.a - fade_speed * dt);

    return true;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

/// Test helper: find a seed that produces a particle at the given position.
fn findSpawningParticle(sx: f32, sy: f32, sz: f32) LavaPopParticle {
    for (1..10_000) |i| {
        if (spawnLavaPop(sx, sy, sz, @intCast(i))) |p| return p;
    }
    unreachable;
}

test "shouldSpawn returns true roughly 10% of the time" {
    var spawned: u32 = 0;
    const trials: u32 = 10_000;
    for (1..trials + 1) |i| {
        if (shouldSpawn(@intCast(i))) spawned += 1;
    }
    // Expect between 5% and 15% (generous tolerance for hash distribution)
    const rate = @as(f32, @floatFromInt(spawned)) / @as(f32, @floatFromInt(trials));
    try std.testing.expect(rate >= 0.05);
    try std.testing.expect(rate <= 0.15);
}

test "shouldSpawn is deterministic" {
    const a = shouldSpawn(12345);
    const b = shouldSpawn(12345);
    try std.testing.expectEqual(a, b);
}

test "shouldSpawn handles seed zero without panic" {
    _ = shouldSpawn(0);
}

test "spawnLavaPop returns null for non-spawning seeds" {
    // Find a seed that does NOT spawn (should be the majority)
    var found_null = false;
    for (1..100) |i| {
        if (spawnLavaPop(0.0, 64.0, 0.0, @intCast(i)) == null) {
            found_null = true;
            break;
        }
    }
    try std.testing.expect(found_null);
}

test "spawnLavaPop returns a particle for spawning seeds" {
    // Find a seed that DOES spawn
    var found_particle = false;
    for (1..200) |i| {
        if (spawnLavaPop(5.0, 10.0, 5.0, @intCast(i)) != null) {
            found_particle = true;
            break;
        }
    }
    try std.testing.expect(found_particle);
}

test "spawnLavaPop particle has orange color" {
    const p = findSpawningParticle(0.0, 0.0, 0.0);
    // Orange: high red, moderate green, low blue
    try std.testing.expect(p.r >= 0.9);
    try std.testing.expect(p.g >= 0.3 and p.g <= 0.65);
    try std.testing.expect(p.b >= 0.05 and p.b <= 0.15);
}

test "spawnLavaPop particle has positive upward velocity" {
    const p = findSpawningParticle(0.0, 64.0, 0.0);
    try std.testing.expect(p.vy > 0.0);
}

test "spawnLavaPop particle starts with full alpha" {
    const p = findSpawningParticle(0.0, 0.0, 0.0);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), p.a, 0.001);
}

test "spawnLavaPop is deterministic with same seed" {
    const a = spawnLavaPop(1.0, 2.0, 3.0, 42);
    const b = spawnLavaPop(1.0, 2.0, 3.0, 42);
    if (a) |pa| {
        const pb = b.?;
        try std.testing.expectApproxEqAbs(pa.x, pb.x, 0.0001);
        try std.testing.expectApproxEqAbs(pa.vy, pb.vy, 0.0001);
        try std.testing.expectApproxEqAbs(pa.life, pb.life, 0.0001);
        try std.testing.expectApproxEqAbs(pa.size, pb.size, 0.0001);
    } else {
        try std.testing.expect(b == null);
    }
}

test "spawnLavaPop position near surface origin" {
    const p = findSpawningParticle(10.0, 64.0, 20.0);
    try std.testing.expect(p.x >= 10.0 - spawn_spread - 0.001);
    try std.testing.expect(p.x <= 10.0 + spawn_spread + 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 64.0), p.y, 0.001);
    try std.testing.expect(p.z >= 20.0 - spawn_spread - 0.001);
    try std.testing.expect(p.z <= 20.0 + spawn_spread + 0.001);
}

test "updatePop reduces life and returns false when dead" {
    var p = LavaPopParticle{
        .x = 0, .y = 64, .z = 0,
        .vy = 2.0, .life = 0.5, .size = 0.1,
        .r = 1, .g = 0.5, .b = 0.1, .a = 1.0,
    };
    const alive = updatePop(&p, 0.2);
    try std.testing.expect(alive);
    try std.testing.expectApproxEqAbs(@as(f32, 0.3), p.life, 0.001);

    // Advance past lifetime
    const dead = updatePop(&p, 0.5);
    try std.testing.expect(!dead);
}

test "updatePop applies gravity (velocity decreases)" {
    var p = LavaPopParticle{
        .x = 0, .y = 64, .z = 0,
        .vy = 3.0, .life = 2.0, .size = 0.1,
        .r = 1, .g = 0.5, .b = 0.1, .a = 1.0,
    };
    const vy_before = p.vy;
    _ = updatePop(&p, 0.1);
    try std.testing.expect(p.vy < vy_before);
}

test "updatePop moves particle upward initially then downward" {
    var p = LavaPopParticle{
        .x = 0, .y = 64, .z = 0,
        .vy = 2.0, .life = 2.0, .size = 0.1,
        .r = 1, .g = 0.5, .b = 0.1, .a = 1.0,
    };
    // First tick: particle moves up
    _ = updatePop(&p, 0.05);
    try std.testing.expect(p.y > 64.0);

    // Many ticks later: gravity pulls it back down
    for (0..40) |_| {
        _ = updatePop(&p, 0.05);
    }
    try std.testing.expect(p.y < 64.0);
}

test "updatePop fades alpha over time" {
    var p = LavaPopParticle{
        .x = 0, .y = 64, .z = 0,
        .vy = 2.0, .life = 2.0, .size = 0.1,
        .r = 1, .g = 0.5, .b = 0.1, .a = 1.0,
    };
    _ = updatePop(&p, 0.3);
    try std.testing.expect(p.a < 1.0);
    try std.testing.expect(p.a >= 0.0);
}

test "updatePop alpha does not go below zero" {
    var p = LavaPopParticle{
        .x = 0, .y = 64, .z = 0,
        .vy = 2.0, .life = 5.0, .size = 0.1,
        .r = 1, .g = 0.5, .b = 0.1, .a = 0.05,
    };
    _ = updatePop(&p, 0.5);
    try std.testing.expect(p.a >= 0.0);
}

test "spawnLavaPop particle size within expected range" {
    const p = findSpawningParticle(0.0, 0.0, 0.0);
    try std.testing.expect(p.size >= size_min - 0.001);
    try std.testing.expect(p.size <= size_min + size_range + 0.001);
}

test "spawnLavaPop particle life within expected range" {
    const p = findSpawningParticle(0.0, 0.0, 0.0);
    try std.testing.expect(p.life >= base_lifetime - 0.001);
    try std.testing.expect(p.life <= base_lifetime + lifetime_range + 0.001);
}
