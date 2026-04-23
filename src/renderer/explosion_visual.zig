const std = @import("std");

/// A single explosion particle with position, velocity, and visual properties.
pub const ExplosionParticle = struct {
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

/// Particle category used to assign color and behavior.
const ParticleKind = enum(u2) {
    fire,
    smoke,
    debris,
};

/// Per-kind visual properties: color, base lifetime, base size, and speed multiplier.
const KindProps = struct {
    r: f32,
    g: f32,
    b: f32,
    base_life: f32,
    base_size: f32,
    speed_mult: f32,
};

fn kindProps(kind: ParticleKind) KindProps {
    return switch (kind) {
        .fire => .{ .r = 1.0, .g = 0.6, .b = 0.1, .base_life = 0.4, .base_size = 0.2, .speed_mult = 1.0 },
        .smoke => .{ .r = 0.5, .g = 0.5, .b = 0.5, .base_life = 1.2, .base_size = 0.3, .speed_mult = 0.5 },
        .debris => .{ .r = 0.55, .g = 0.35, .b = 0.15, .base_life = 0.8, .base_size = 0.1, .speed_mult = 1.5 },
    };
}

const PARTICLE_COUNT = 32;
const GRAVITY = 9.8;
const DRAG = 0.95;
const FIRE_RATIO = 12; // out of 32
const SMOKE_RATIO = 12; // out of 32 (fire + smoke = 24, rest = debris)

/// Hash helper for deterministic pseudo-random number generation.
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

/// Spawn 32 explosion particles at the given center position.
/// The mix contains fire (orange), smoke (gray), and debris (brown) particles
/// expanding outward. Power affects speed and size.
pub fn spawnExplosion(cx: f32, cy: f32, cz: f32, power: f32, seed: u32) [PARTICLE_COUNT]ExplosionParticle {
    var result: [PARTICLE_COUNT]ExplosionParticle = undefined;
    var state = seed;
    if (state == 0) state = 1;

    const clamped_power = @max(power, 0.1);
    const speed_scale = clamped_power * 2.0;
    const size_scale = clamped_power * 0.15;

    for (0..PARTICLE_COUNT) |i| {
        // Determine particle kind based on index distribution
        const kind: ParticleKind = if (i < FIRE_RATIO)
            .fire
        else if (i < FIRE_RATIO + SMOKE_RATIO)
            .smoke
        else
            .debris;

        // Generate direction vector components in [-1, 1]
        state = xorshift(state);
        const fx = hashToFloat01(state) * 2.0 - 1.0;
        state = xorshift(state);
        const fy = hashToFloat01(state) * 2.0 - 1.0;
        state = xorshift(state);
        const fz = hashToFloat01(state) * 2.0 - 1.0;

        // Generate size and lifetime variation
        state = xorshift(state);
        const size_t = hashToFloat01(state);
        state = xorshift(state);
        const life_t = hashToFloat01(state);

        // Generate color variation
        state = xorshift(state);
        const color_var = hashToFloat01(state) * 0.2 - 0.1;

        const props = kindProps(kind);
        const vel_scale = speed_scale * props.speed_mult;

        result[i] = .{
            .x = cx,
            .y = cy,
            .z = cz,
            .vx = fx * vel_scale,
            .vy = fy * vel_scale + 2.0,
            .vz = fz * vel_scale,
            .life = props.base_life * (0.7 + 0.6 * life_t),
            .size = (props.base_size + size_t * 0.1) * (1.0 + size_scale),
            .r = clamp01(props.r + color_var),
            .g = clamp01(props.g + color_var),
            .b = clamp01(props.b + color_var),
            .a = 1.0,
        };
    }

    return result;
}

/// Update a single explosion particle by dt seconds.
/// Applies drag, gravity, fades alpha, shrinks size, and decrements life.
/// Returns true if the particle is still alive after the update.
pub fn updateExplosion(p: *ExplosionParticle, dt: f32) bool {
    p.life -= dt;
    if (p.life <= 0.0) {
        p.life = 0.0;
        p.a = 0.0;
        return false;
    }

    // Apply drag
    const drag_factor = std.math.pow(f32, DRAG, dt * 60.0);
    p.vx *= drag_factor;
    p.vy *= drag_factor;
    p.vz *= drag_factor;

    // Apply gravity
    p.vy -= GRAVITY * dt;

    // Integrate position
    p.x += p.vx * dt;
    p.y += p.vy * dt;
    p.z += p.vz * dt;

    // Fade alpha linearly
    p.a = @max(p.a - dt * 1.5, 0.0);

    // Shrink size over time
    p.size = @max(p.size - dt * 0.1, 0.01);

    return true;
}

fn clamp01(v: f32) f32 {
    return @max(0.0, @min(1.0, v));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "spawnExplosion returns 32 particles" {
    const particles = spawnExplosion(0.0, 0.0, 0.0, 1.0, 42);
    try std.testing.expectEqual(@as(usize, 32), particles.len);
}

test "all particles start at the explosion center" {
    const cx: f32 = 5.0;
    const cy: f32 = 10.0;
    const cz: f32 = -3.0;
    const particles = spawnExplosion(cx, cy, cz, 1.0, 99);
    for (particles) |p| {
        try std.testing.expectApproxEqAbs(cx, p.x, 0.001);
        try std.testing.expectApproxEqAbs(cy, p.y, 0.001);
        try std.testing.expectApproxEqAbs(cz, p.z, 0.001);
    }
}

test "all particles have positive life and size" {
    const particles = spawnExplosion(0.0, 0.0, 0.0, 2.0, 7);
    for (particles) |p| {
        try std.testing.expect(p.life > 0.0);
        try std.testing.expect(p.size > 0.0);
    }
}

test "fire particles have orange-ish color" {
    const particles = spawnExplosion(0.0, 0.0, 0.0, 1.0, 123);
    // First FIRE_RATIO particles are fire
    for (0..FIRE_RATIO) |i| {
        try std.testing.expect(particles[i].r > 0.8);
        try std.testing.expect(particles[i].g > 0.4);
        try std.testing.expect(particles[i].b < 0.3);
    }
}

test "smoke particles have grayish color" {
    const particles = spawnExplosion(0.0, 0.0, 0.0, 1.0, 456);
    for (FIRE_RATIO..FIRE_RATIO + SMOKE_RATIO) |i| {
        // Gray means r, g, b are close to each other
        try std.testing.expect(@abs(particles[i].r - particles[i].g) < 0.25);
        try std.testing.expect(@abs(particles[i].g - particles[i].b) < 0.25);
    }
}

test "debris particles have brownish color" {
    const particles = spawnExplosion(0.0, 0.0, 0.0, 1.0, 789);
    for (FIRE_RATIO + SMOKE_RATIO..PARTICLE_COUNT) |i| {
        // Brown: r > g > b
        try std.testing.expect(particles[i].r > particles[i].b);
        try std.testing.expect(particles[i].g > particles[i].b);
    }
}

test "higher power produces faster particles" {
    const low = spawnExplosion(0.0, 0.0, 0.0, 0.5, 42);
    const high = spawnExplosion(0.0, 0.0, 0.0, 4.0, 42);

    var low_speed_sum: f32 = 0.0;
    var high_speed_sum: f32 = 0.0;
    for (0..PARTICLE_COUNT) |i| {
        low_speed_sum += @abs(low[i].vx) + @abs(low[i].vy) + @abs(low[i].vz);
        high_speed_sum += @abs(high[i].vx) + @abs(high[i].vy) + @abs(high[i].vz);
    }
    try std.testing.expect(high_speed_sum > low_speed_sum);
}

test "deterministic with same seed" {
    const a = spawnExplosion(1.0, 2.0, 3.0, 1.5, 999);
    const b = spawnExplosion(1.0, 2.0, 3.0, 1.5, 999);
    for (0..PARTICLE_COUNT) |i| {
        try std.testing.expectApproxEqAbs(a[i].vx, b[i].vx, 0.0001);
        try std.testing.expectApproxEqAbs(a[i].vy, b[i].vy, 0.0001);
        try std.testing.expectApproxEqAbs(a[i].life, b[i].life, 0.0001);
        try std.testing.expectApproxEqAbs(a[i].r, b[i].r, 0.0001);
    }
}

test "different seeds produce different results" {
    const a = spawnExplosion(0.0, 0.0, 0.0, 1.0, 1);
    const b = spawnExplosion(0.0, 0.0, 0.0, 1.0, 2);
    var any_diff = false;
    for (0..PARTICLE_COUNT) |i| {
        if (@abs(a[i].vx - b[i].vx) > 0.0001) any_diff = true;
    }
    try std.testing.expect(any_diff);
}

test "seed zero does not hang and produces valid particles" {
    const particles = spawnExplosion(0.0, 0.0, 0.0, 1.0, 0);
    for (particles) |p| {
        try std.testing.expect(p.life > 0.0);
        try std.testing.expect(std.math.isFinite(p.vx));
    }
}

test "updateExplosion returns false when life expires" {
    var p = ExplosionParticle{
        .x = 0, .y = 0, .z = 0,
        .vx = 1, .vy = 1, .vz = 1,
        .life = 0.1, .size = 0.2,
        .r = 1, .g = 0.5, .b = 0.1, .a = 1.0,
    };
    // dt larger than life
    const alive = updateExplosion(&p, 0.5);
    try std.testing.expect(!alive);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), p.life, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), p.a, 0.001);
}

test "updateExplosion returns true while alive" {
    var p = ExplosionParticle{
        .x = 0, .y = 10, .z = 0,
        .vx = 2, .vy = 5, .vz = -1,
        .life = 2.0, .size = 0.3,
        .r = 1, .g = 0.6, .b = 0.1, .a = 1.0,
    };
    const alive = updateExplosion(&p, 0.016);
    try std.testing.expect(alive);
    try std.testing.expect(p.life > 0.0);
}

test "updateExplosion applies gravity (vy decreases)" {
    var p = ExplosionParticle{
        .x = 0, .y = 0, .z = 0,
        .vx = 0, .vy = 10, .vz = 0,
        .life = 5.0, .size = 0.2,
        .r = 1, .g = 1, .b = 1, .a = 1.0,
    };
    const vy_before = p.vy;
    _ = updateExplosion(&p, 0.1);
    try std.testing.expect(p.vy < vy_before);
}

test "updateExplosion moves position" {
    var p = ExplosionParticle{
        .x = 0, .y = 0, .z = 0,
        .vx = 5, .vy = 0, .vz = -3,
        .life = 5.0, .size = 0.2,
        .r = 1, .g = 1, .b = 1, .a = 1.0,
    };
    _ = updateExplosion(&p, 0.1);
    try std.testing.expect(p.x > 0.0);
    try std.testing.expect(p.z < 0.0);
}

test "updateExplosion fades alpha" {
    var p = ExplosionParticle{
        .x = 0, .y = 0, .z = 0,
        .vx = 0, .vy = 0, .vz = 0,
        .life = 5.0, .size = 0.2,
        .r = 1, .g = 1, .b = 1, .a = 1.0,
    };
    _ = updateExplosion(&p, 0.1);
    try std.testing.expect(p.a < 1.0);
}

test "updateExplosion shrinks size" {
    var p = ExplosionParticle{
        .x = 0, .y = 0, .z = 0,
        .vx = 0, .vy = 0, .vz = 0,
        .life = 5.0, .size = 0.5,
        .r = 1, .g = 1, .b = 1, .a = 1.0,
    };
    const size_before = p.size;
    _ = updateExplosion(&p, 0.1);
    try std.testing.expect(p.size < size_before);
}

test "color channels clamped to 0-1" {
    const particles = spawnExplosion(0.0, 0.0, 0.0, 10.0, 12345);
    for (particles) |p| {
        try std.testing.expect(p.r >= 0.0 and p.r <= 1.0);
        try std.testing.expect(p.g >= 0.0 and p.g <= 1.0);
        try std.testing.expect(p.b >= 0.0 and p.b <= 1.0);
        try std.testing.expect(p.a >= 0.0 and p.a <= 1.0);
    }
}
