const std = @import("std");

/// Smoke source types with distinct visual behavior.
pub const SmokeType = enum {
    campfire,
    furnace,
    extinguished_torch,
    soul_campfire,
};

/// A single smoke particle with position, velocity, and visual properties.
pub const SmokeParticle = struct {
    x: f32,
    y: f32,
    z: f32,
    vy: f32,
    life: f32,
    max_life: f32,
    size: f32,
    r: f32,
    g: f32,
    b: f32,
    a: f32,
};

/// Visual/physics template for each smoke type.
const SmokeTemplate = struct {
    vy: f32,
    life: f32,
    size: f32,
    r: f32,
    g: f32,
    b: f32,
    a: f32,
    spread: f32,
    vy_variation: f32,
    life_variation: f32,
    size_variation: f32,
};

fn getTemplate(smoke_type: SmokeType) SmokeTemplate {
    return switch (smoke_type) {
        // Campfire: tall gray columns, high rise speed, long life, larger size
        .campfire => .{
            .vy = 2.0,
            .life = 4.0,
            .size = 0.25,
            .r = 0.45,
            .g = 0.45,
            .b = 0.45,
            .a = 0.7,
            .spread = 0.3,
            .vy_variation = 0.5,
            .life_variation = 1.0,
            .size_variation = 0.1,
        },
        // Furnace: small puffs, low rise speed, short life, small size
        .furnace => .{
            .vy = 0.8,
            .life = 1.5,
            .size = 0.08,
            .r = 0.35,
            .g = 0.35,
            .b = 0.35,
            .a = 0.5,
            .spread = 0.15,
            .vy_variation = 0.2,
            .life_variation = 0.4,
            .size_variation = 0.03,
        },
        // Extinguished torch: wispy thin trail, very short life
        .extinguished_torch => .{
            .vy = 0.5,
            .life = 1.0,
            .size = 0.05,
            .r = 0.5,
            .g = 0.5,
            .b = 0.5,
            .a = 0.4,
            .spread = 0.1,
            .vy_variation = 0.15,
            .life_variation = 0.3,
            .size_variation = 0.02,
        },
        // Soul campfire: tall columns with cyan tint
        .soul_campfire => .{
            .vy = 2.2,
            .life = 4.5,
            .size = 0.25,
            .r = 0.2,
            .g = 0.6,
            .b = 0.7,
            .a = 0.7,
            .spread = 0.3,
            .vy_variation = 0.5,
            .life_variation = 1.0,
            .size_variation = 0.1,
        },
    };
}

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

/// Spawn 4 smoke particles at (sx, sy, sz) with deterministic randomness.
///
/// Campfire and soul campfire produce tall rising columns.
/// Furnace produces small puffs. Extinguished torch produces thin wisps.
/// Soul campfire has a cyan color tint.
pub fn spawnSmoke(sx: f32, sy: f32, sz: f32, smoke_type: SmokeType, seed: u32) [4]SmokeParticle {
    const tmpl = getTemplate(smoke_type);
    var result: [4]SmokeParticle = undefined;
    var state = seed;
    if (state == 0) state = 1;

    for (0..4) |i| {
        // Horizontal offset
        state = xorshift(state);
        const ox = (hashToFloat01(state) * 2.0 - 1.0) * tmpl.spread;
        state = xorshift(state);
        const oz = (hashToFloat01(state) * 2.0 - 1.0) * tmpl.spread;

        // Vertical velocity variation
        state = xorshift(state);
        const vy_offset = (hashToFloat01(state) * 2.0 - 1.0) * tmpl.vy_variation;

        // Lifetime variation
        state = xorshift(state);
        const life_offset = (hashToFloat01(state) * 2.0 - 1.0) * tmpl.life_variation;
        const life = tmpl.life + life_offset;

        // Size variation
        state = xorshift(state);
        const size_offset = (hashToFloat01(state) * 2.0 - 1.0) * tmpl.size_variation;
        const size = tmpl.size + size_offset;

        result[i] = .{
            .x = sx + ox,
            .y = sy,
            .z = sz + oz,
            .vy = tmpl.vy + vy_offset,
            .life = life,
            .max_life = life,
            .size = size,
            .r = tmpl.r,
            .g = tmpl.g,
            .b = tmpl.b,
            .a = tmpl.a,
        };
    }

    return result;
}

/// Update a smoke particle for one tick.
///
/// Applies upward velocity with drag, and fades alpha linearly as life
/// decreases. Returns true if the particle is still alive, false if it
/// should be removed.
pub fn updateSmoke(p: *SmokeParticle, dt: f32) bool {
    p.life -= dt;
    if (p.life <= 0.0) {
        return false;
    }

    // Rise upward
    p.y += p.vy * dt;

    // Slow down slightly as smoke disperses
    p.vy *= 1.0 - 0.3 * dt;

    // Fade alpha linearly with remaining life
    p.a = p.life / p.max_life;

    return true;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "spawnSmoke returns 4 particles for campfire" {
    const particles = spawnSmoke(5.0, 10.0, 5.0, .campfire, 42);
    for (particles) |p| {
        try std.testing.expect(p.life > 0.0);
        try std.testing.expect(p.max_life > 0.0);
    }
}

test "spawnSmoke campfire particles have gray color" {
    const particles = spawnSmoke(0.0, 0.0, 0.0, .campfire, 100);
    const tmpl = getTemplate(.campfire);
    for (particles) |p| {
        try std.testing.expectApproxEqAbs(tmpl.r, p.r, 0.001);
        try std.testing.expectApproxEqAbs(tmpl.g, p.g, 0.001);
        try std.testing.expectApproxEqAbs(tmpl.b, p.b, 0.001);
    }
}

test "spawnSmoke soul_campfire particles have cyan tint" {
    const particles = spawnSmoke(0.0, 0.0, 0.0, .soul_campfire, 77);
    for (particles) |p| {
        // Cyan tint: green and blue channels significantly higher than red
        try std.testing.expect(p.g > p.r);
        try std.testing.expect(p.b > p.r);
    }
}

test "spawnSmoke furnace produces small particles" {
    const furnace = spawnSmoke(0.0, 0.0, 0.0, .furnace, 55);
    // Furnace base size is smaller than campfire
    const furnace_tmpl = getTemplate(.furnace);
    const campfire_tmpl = getTemplate(.campfire);
    try std.testing.expect(furnace_tmpl.size < campfire_tmpl.size);
    // Check actual particles are small
    for (furnace) |p| {
        try std.testing.expect(p.size < 0.15);
    }
}

test "spawnSmoke furnace has shorter life than campfire" {
    const furnace_tmpl = getTemplate(.furnace);
    const campfire_tmpl = getTemplate(.campfire);
    try std.testing.expect(furnace_tmpl.life < campfire_tmpl.life);
}

test "spawnSmoke deterministic with same seed" {
    const a = spawnSmoke(1.0, 2.0, 3.0, .campfire, 999);
    const b = spawnSmoke(1.0, 2.0, 3.0, .campfire, 999);
    for (0..4) |i| {
        try std.testing.expectApproxEqAbs(a[i].x, b[i].x, 0.0001);
        try std.testing.expectApproxEqAbs(a[i].y, b[i].y, 0.0001);
        try std.testing.expectApproxEqAbs(a[i].z, b[i].z, 0.0001);
        try std.testing.expectApproxEqAbs(a[i].vy, b[i].vy, 0.0001);
        try std.testing.expectApproxEqAbs(a[i].life, b[i].life, 0.0001);
    }
}

test "spawnSmoke different seeds produce different results" {
    const a = spawnSmoke(0.0, 0.0, 0.0, .campfire, 1);
    const b = spawnSmoke(0.0, 0.0, 0.0, .campfire, 2);
    var any_diff = false;
    for (0..4) |i| {
        if (@abs(a[i].x - b[i].x) > 0.0001) any_diff = true;
    }
    try std.testing.expect(any_diff);
}

test "spawnSmoke seed zero does not hang" {
    const particles = spawnSmoke(1.0, 1.0, 1.0, .extinguished_torch, 0);
    for (particles) |p| {
        try std.testing.expect(p.life > 0.0);
    }
}

test "spawnSmoke particles spawn near origin" {
    const particles = spawnSmoke(10.0, 20.0, 30.0, .campfire, 123);
    const tmpl = getTemplate(.campfire);
    for (particles) |p| {
        try std.testing.expect(p.x >= 10.0 - tmpl.spread - 0.001);
        try std.testing.expect(p.x <= 10.0 + tmpl.spread + 0.001);
        try std.testing.expectApproxEqAbs(@as(f32, 20.0), p.y, 0.001);
        try std.testing.expect(p.z >= 30.0 - tmpl.spread - 0.001);
        try std.testing.expect(p.z <= 30.0 + tmpl.spread + 0.001);
    }
}

test "updateSmoke reduces life" {
    var p = SmokeParticle{
        .x = 0,
        .y = 0,
        .z = 0,
        .vy = 2.0,
        .life = 3.0,
        .max_life = 3.0,
        .size = 0.2,
        .r = 0.4,
        .g = 0.4,
        .b = 0.4,
        .a = 0.7,
    };
    const before = p.life;
    const alive = updateSmoke(&p, 0.5);
    try std.testing.expect(alive);
    try std.testing.expect(p.life < before);
    try std.testing.expectApproxEqAbs(@as(f32, 2.5), p.life, 0.001);
}

test "updateSmoke moves particle upward" {
    var p = SmokeParticle{
        .x = 0,
        .y = 5.0,
        .z = 0,
        .vy = 2.0,
        .life = 3.0,
        .max_life = 3.0,
        .size = 0.2,
        .r = 0.4,
        .g = 0.4,
        .b = 0.4,
        .a = 0.7,
    };
    const before_y = p.y;
    _ = updateSmoke(&p, 0.5);
    try std.testing.expect(p.y > before_y);
}

test "updateSmoke returns false when life expires" {
    var p = SmokeParticle{
        .x = 0,
        .y = 0,
        .z = 0,
        .vy = 1.0,
        .life = 0.3,
        .max_life = 1.0,
        .size = 0.1,
        .r = 0.4,
        .g = 0.4,
        .b = 0.4,
        .a = 0.7,
    };
    const alive = updateSmoke(&p, 0.5);
    try std.testing.expect(!alive);
}

test "updateSmoke fades alpha over time" {
    var p = SmokeParticle{
        .x = 0,
        .y = 0,
        .z = 0,
        .vy = 2.0,
        .life = 4.0,
        .max_life = 4.0,
        .size = 0.2,
        .r = 0.4,
        .g = 0.4,
        .b = 0.4,
        .a = 0.7,
    };
    _ = updateSmoke(&p, 2.0);
    // life is now 2.0, max_life is 4.0 => alpha should be 0.5
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), p.a, 0.001);
}

test "updateSmoke velocity decreases over time (drag)" {
    var p = SmokeParticle{
        .x = 0,
        .y = 0,
        .z = 0,
        .vy = 2.0,
        .life = 5.0,
        .max_life = 5.0,
        .size = 0.2,
        .r = 0.4,
        .g = 0.4,
        .b = 0.4,
        .a = 0.7,
    };
    const initial_vy = p.vy;
    _ = updateSmoke(&p, 0.5);
    try std.testing.expect(p.vy < initial_vy);
}

test "SmokeType enum has 4 variants" {
    const fields = std.meta.fields(SmokeType);
    try std.testing.expectEqual(@as(usize, 4), fields.len);
}

test "spawnSmoke extinguished_torch has low rise speed" {
    const torch_tmpl = getTemplate(.extinguished_torch);
    const campfire_tmpl = getTemplate(.campfire);
    try std.testing.expect(torch_tmpl.vy < campfire_tmpl.vy);
}
