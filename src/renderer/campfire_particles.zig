const std = @import("std");

/// A single campfire particle with position, velocity, and visual properties.
pub const CampfireParticle = struct {
    x: f32,
    y: f32,
    z: f32,
    vx: f32,
    vy: f32,
    vz: f32,
    life: f32,
    size: f32,
    r: f32,
    g: f32,
    b: f32,
    a: f32,
};

/// The type of campfire, which determines smoke color.
pub const CampfireType = enum {
    normal,
    soul,
};

// ---------------------------------------------------------------------------
// Smoke templates
// ---------------------------------------------------------------------------

const SmokeTemplate = struct {
    vy: f32,
    life: f32,
    r: f32,
    g: f32,
    b: f32,
};

// Shared values across all campfire smoke types.
const smoke_size: f32 = 0.25;
const smoke_alpha: f32 = 0.7;
const smoke_spread: f32 = 0.3;
const smoke_vy_variation: f32 = 0.5;
const smoke_life_variation: f32 = 1.0;
const smoke_size_variation: f32 = 0.1;
const smoke_drift: f32 = 0.15;

fn smokeTemplate(ctype: CampfireType) SmokeTemplate {
    return switch (ctype) {
        .normal => .{ .vy = 2.0, .life = 4.0, .r = 0.45, .g = 0.45, .b = 0.45 },
        .soul => .{ .vy = 2.2, .life = 4.5, .r = 0.2, .g = 0.6, .b = 0.7 },
    };
}

// ---------------------------------------------------------------------------
// Ember constants (orange sparks)
// ---------------------------------------------------------------------------

const ember_vy: f32 = 3.0;
const ember_life: f32 = 1.2;
const ember_size: f32 = 0.04;
const ember_r: f32 = 1.0;
const ember_g: f32 = 0.55;
const ember_b: f32 = 0.1;
const ember_a: f32 = 0.9;
const ember_spread: f32 = 0.2;
const ember_kick: f32 = 0.8;

// ---------------------------------------------------------------------------
// Deterministic pseudo-random helpers
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

/// Map a [0,1) float to a centered range [-1,1).
fn centered(f: f32) f32 {
    return f * 2.0 - 1.0;
}

// ---------------------------------------------------------------------------
// Physics constants
// ---------------------------------------------------------------------------

const DRAG: f32 = 0.3;
const GRAVITY: f32 = 1.5;

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Spawn 6 campfire particles at (cx, cy, cz):
///   - indices 0..3: tall smoke columns (gray for normal, cyan-tinted for soul)
///   - indices 4..5: ember sparks (orange)
///
/// `seed` drives deterministic pseudo-random variation.
pub fn spawnSmoke(cx: f32, cy: f32, cz: f32, ctype: CampfireType, seed: u32) [6]CampfireParticle {
    const tmpl = smokeTemplate(ctype);
    var result: [6]CampfireParticle = undefined;
    var state = seed;
    if (state == 0) state = 1;

    // 4 smoke particles
    for (0..4) |i| {
        state = xorshift(state);
        const ox = centered(hashToFloat01(state)) * smoke_spread;
        state = xorshift(state);
        const oz = centered(hashToFloat01(state)) * smoke_spread;
        state = xorshift(state);
        const vy_off = centered(hashToFloat01(state)) * smoke_vy_variation;
        state = xorshift(state);
        const life_off = centered(hashToFloat01(state)) * smoke_life_variation;
        state = xorshift(state);
        const size_off = centered(hashToFloat01(state)) * smoke_size_variation;
        state = xorshift(state);
        const drift_x = centered(hashToFloat01(state)) * smoke_drift;
        state = xorshift(state);
        const drift_z = centered(hashToFloat01(state)) * smoke_drift;

        result[i] = .{
            .x = cx + ox,
            .y = cy,
            .z = cz + oz,
            .vx = drift_x,
            .vy = tmpl.vy + vy_off,
            .vz = drift_z,
            .life = tmpl.life + life_off,
            .size = smoke_size + size_off,
            .r = tmpl.r,
            .g = tmpl.g,
            .b = tmpl.b,
            .a = smoke_alpha,
        };
    }

    // 2 ember sparks
    for (0..2) |j| {
        state = xorshift(state);
        const ex = centered(hashToFloat01(state)) * ember_spread;
        state = xorshift(state);
        const ez = centered(hashToFloat01(state)) * ember_spread;
        state = xorshift(state);
        const evx = centered(hashToFloat01(state)) * ember_kick;
        state = xorshift(state);
        const evz = centered(hashToFloat01(state)) * ember_kick;
        state = xorshift(state);
        const life_t = hashToFloat01(state);

        result[4 + j] = .{
            .x = cx + ex,
            .y = cy,
            .z = cz + ez,
            .vx = evx,
            .vy = ember_vy + life_t,
            .vz = evz,
            .life = ember_life + life_t * 0.4,
            .size = ember_size,
            .r = ember_r,
            .g = ember_g,
            .b = ember_b,
            .a = ember_a,
        };
    }

    return result;
}

/// Advance a single campfire particle by `dt` seconds.
///
/// Applies rising velocity, horizontal drift with drag, and alpha fade.
/// Returns `true` while the particle is still alive, `false` when expired.
pub fn updateParticle(p: *CampfireParticle, dt: f32) bool {
    p.life -= dt;
    if (p.life <= 0.0) {
        p.life = 0.0;
        p.a = 0.0;
        return false;
    }

    // Rise
    p.y += p.vy * dt;

    // Horizontal drift
    p.x += p.vx * dt;
    p.z += p.vz * dt;

    // Drag on all velocity components
    const decay = 1.0 - DRAG * dt;
    p.vx *= decay;
    p.vy *= decay;
    p.vz *= decay;

    // Slight downward pull for embers (small particles)
    if (p.size < 0.1) {
        p.vy -= GRAVITY * dt;
    }

    // Fade alpha linearly
    p.a *= decay;

    return true;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "spawnSmoke returns 6 particles" {
    const particles = spawnSmoke(0.0, 0.0, 0.0, .normal, 42);
    try std.testing.expectEqual(@as(usize, 6), particles.len);
}

test "all spawned particles have positive life" {
    const particles = spawnSmoke(5.0, 10.0, 5.0, .normal, 42);
    for (particles) |p| {
        try std.testing.expect(p.life > 0.0);
    }
}

test "normal smoke has gray color" {
    const particles = spawnSmoke(0.0, 0.0, 0.0, .normal, 100);
    // First 4 are smoke
    for (0..4) |i| {
        try std.testing.expectApproxEqAbs(@as(f32, 0.45), particles[i].r, 0.001);
        try std.testing.expectApproxEqAbs(@as(f32, 0.45), particles[i].g, 0.001);
        try std.testing.expectApproxEqAbs(@as(f32, 0.45), particles[i].b, 0.001);
    }
}

test "soul smoke has cyan tint" {
    const particles = spawnSmoke(0.0, 0.0, 0.0, .soul, 77);
    for (0..4) |i| {
        // Cyan tint: green and blue channels higher than red
        try std.testing.expect(particles[i].g > particles[i].r);
        try std.testing.expect(particles[i].b > particles[i].r);
    }
}

test "ember sparks are orange" {
    const particles = spawnSmoke(0.0, 0.0, 0.0, .normal, 55);
    for (4..6) |i| {
        try std.testing.expectApproxEqAbs(@as(f32, 1.0), particles[i].r, 0.001);
        try std.testing.expectApproxEqAbs(@as(f32, 0.55), particles[i].g, 0.001);
        try std.testing.expectApproxEqAbs(@as(f32, 0.1), particles[i].b, 0.001);
    }
}

test "ember sparks are smaller than smoke" {
    const particles = spawnSmoke(0.0, 0.0, 0.0, .normal, 123);
    for (4..6) |i| {
        try std.testing.expect(particles[i].size < particles[0].size);
    }
}

test "deterministic: same seed produces identical results" {
    const a = spawnSmoke(1.0, 2.0, 3.0, .normal, 999);
    const b = spawnSmoke(1.0, 2.0, 3.0, .normal, 999);
    for (0..6) |i| {
        try std.testing.expectApproxEqAbs(a[i].x, b[i].x, 0.0001);
        try std.testing.expectApproxEqAbs(a[i].y, b[i].y, 0.0001);
        try std.testing.expectApproxEqAbs(a[i].z, b[i].z, 0.0001);
        try std.testing.expectApproxEqAbs(a[i].vy, b[i].vy, 0.0001);
        try std.testing.expectApproxEqAbs(a[i].life, b[i].life, 0.0001);
    }
}

test "different seeds produce different results" {
    const a = spawnSmoke(0.0, 0.0, 0.0, .normal, 1);
    const b = spawnSmoke(0.0, 0.0, 0.0, .normal, 2);
    var any_diff = false;
    for (0..6) |i| {
        if (@abs(a[i].x - b[i].x) > 0.0001) any_diff = true;
    }
    try std.testing.expect(any_diff);
}

test "seed zero does not hang" {
    const particles = spawnSmoke(1.0, 1.0, 1.0, .soul, 0);
    for (particles) |p| {
        try std.testing.expect(p.life > 0.0);
    }
}

test "particles spawn near the given position" {
    const particles = spawnSmoke(10.0, 20.0, 30.0, .normal, 321);
    for (particles) |p| {
        try std.testing.expect(@abs(p.x - 10.0) < 1.0);
        try std.testing.expectApproxEqAbs(@as(f32, 20.0), p.y, 0.001);
        try std.testing.expect(@abs(p.z - 30.0) < 1.0);
    }
}

test "updateParticle reduces life" {
    var p = CampfireParticle{
        .x = 0, .y = 0, .z = 0,
        .vx = 0, .vy = 2.0, .vz = 0,
        .life = 3.0, .size = 0.2,
        .r = 0.4, .g = 0.4, .b = 0.4, .a = 0.7,
    };
    const before = p.life;
    const alive = updateParticle(&p, 0.5);
    try std.testing.expect(alive);
    try std.testing.expect(p.life < before);
}

test "updateParticle moves particle upward" {
    var p = CampfireParticle{
        .x = 0, .y = 5.0, .z = 0,
        .vx = 0, .vy = 2.0, .vz = 0,
        .life = 3.0, .size = 0.2,
        .r = 0.4, .g = 0.4, .b = 0.4, .a = 0.7,
    };
    const before_y = p.y;
    _ = updateParticle(&p, 0.5);
    try std.testing.expect(p.y > before_y);
}

test "updateParticle returns false when life expires" {
    var p = CampfireParticle{
        .x = 0, .y = 0, .z = 0,
        .vx = 0, .vy = 1.0, .vz = 0,
        .life = 0.1, .size = 0.1,
        .r = 0.4, .g = 0.4, .b = 0.4, .a = 0.7,
    };
    const alive = updateParticle(&p, 0.5);
    try std.testing.expect(!alive);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), p.a, 0.001);
}

test "updateParticle fades alpha over time" {
    var p = CampfireParticle{
        .x = 0, .y = 0, .z = 0,
        .vx = 0, .vy = 2.0, .vz = 0,
        .life = 4.0, .size = 0.2,
        .r = 0.4, .g = 0.4, .b = 0.4, .a = 0.7,
    };
    const a_before = p.a;
    _ = updateParticle(&p, 1.0);
    try std.testing.expect(p.a < a_before);
}

test "updateParticle applies drag (velocity decreases)" {
    var p = CampfireParticle{
        .x = 0, .y = 0, .z = 0,
        .vx = 1.0, .vy = 2.0, .vz = 1.0,
        .life = 5.0, .size = 0.2,
        .r = 0.4, .g = 0.4, .b = 0.4, .a = 0.7,
    };
    const initial_vx = p.vx;
    const initial_vy = p.vy;
    _ = updateParticle(&p, 0.5);
    try std.testing.expect(p.vx < initial_vx);
    try std.testing.expect(p.vy < initial_vy);
}

test "ember gravity pulls small particles down over time" {
    var p = CampfireParticle{
        .x = 0, .y = 5.0, .z = 0,
        .vx = 0, .vy = 3.0, .vz = 0,
        .life = 2.0, .size = 0.04,
        .r = 1.0, .g = 0.55, .b = 0.1, .a = 0.9,
    };
    const vy_before = p.vy;
    _ = updateParticle(&p, 0.5);
    // Gravity + drag should pull vy down more than drag alone
    try std.testing.expect(p.vy < vy_before);
    // After enough time, ember vy should go negative (falls back down)
    _ = updateParticle(&p, 1.0);
    _ = updateParticle(&p, 1.0);
    try std.testing.expect(p.vy < 0.0);
}

test "CampfireType enum has 2 variants" {
    const fields = std.meta.fields(CampfireType);
    try std.testing.expectEqual(@as(usize, 2), fields.len);
}
