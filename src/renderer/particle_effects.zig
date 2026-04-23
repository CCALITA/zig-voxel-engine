const std = @import("std");

/// Extended particle types beyond basic block break effects.
pub const ParticleType = enum(u4) {
    block_break,
    torch_flame,
    enchant_glyph,
    potion_splash,
    campfire_smoke,
    critical_hit,
    portal,
    lava_drip,
    water_drip,
    redstone_dust,
    snow_fall,
    explosion,
};

/// Visual template describing the appearance and physics of a particle type.
pub const ParticleTemplate = struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32,
    size_min: f32,
    size_max: f32,
    lifetime: f32,
    gravity: f32,
    spread: f32,
};

/// A single spawned particle with position, velocity, and visual properties.
pub const SpawnedParticle = struct {
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

/// Return the visual template for a given particle type.
pub fn getTemplate(ptype: ParticleType) ParticleTemplate {
    return switch (ptype) {
        .block_break => .{ .r = 0.6, .g = 0.4, .b = 0.2, .a = 1.0, .size_min = 0.05, .size_max = 0.15, .lifetime = 0.8, .gravity = 10.0, .spread = 2.0 },
        .torch_flame => .{ .r = 1.0, .g = 0.7, .b = 0.2, .a = 0.9, .size_min = 0.02, .size_max = 0.06, .lifetime = 0.5, .gravity = -1.5, .spread = 0.3 },
        .enchant_glyph => .{ .r = 0.5, .g = 0.2, .b = 0.8, .a = 0.8, .size_min = 0.03, .size_max = 0.08, .lifetime = 1.5, .gravity = -0.5, .spread = 1.0 },
        .potion_splash => .{ .r = 0.3, .g = 0.8, .b = 0.3, .a = 0.7, .size_min = 0.04, .size_max = 0.1, .lifetime = 1.0, .gravity = 5.0, .spread = 3.0 },
        .campfire_smoke => .{ .r = 0.4, .g = 0.4, .b = 0.4, .a = 0.6, .size_min = 0.1, .size_max = 0.3, .lifetime = 3.0, .gravity = -0.8, .spread = 0.5 },
        .critical_hit => .{ .r = 1.0, .g = 0.9, .b = 0.3, .a = 1.0, .size_min = 0.03, .size_max = 0.07, .lifetime = 0.4, .gravity = 3.0, .spread = 1.5 },
        .portal => .{ .r = 0.3, .g = 0.1, .b = 0.6, .a = 0.8, .size_min = 0.02, .size_max = 0.05, .lifetime = 1.2, .gravity = -0.3, .spread = 0.8 },
        .lava_drip => .{ .r = 1.0, .g = 0.4, .b = 0.1, .a = 1.0, .size_min = 0.03, .size_max = 0.06, .lifetime = 0.6, .gravity = 8.0, .spread = 0.2 },
        .water_drip => .{ .r = 0.2, .g = 0.4, .b = 0.9, .a = 0.7, .size_min = 0.02, .size_max = 0.05, .lifetime = 0.7, .gravity = 9.0, .spread = 0.2 },
        .redstone_dust => .{ .r = 0.9, .g = 0.1, .b = 0.1, .a = 0.9, .size_min = 0.01, .size_max = 0.04, .lifetime = 0.6, .gravity = 2.0, .spread = 0.4 },
        .snow_fall => .{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 0.8, .size_min = 0.03, .size_max = 0.08, .lifetime = 4.0, .gravity = 1.5, .spread = 2.0 },
        .explosion => .{ .r = 1.0, .g = 0.6, .b = 0.1, .a = 1.0, .size_min = 0.1, .size_max = 0.4, .lifetime = 0.6, .gravity = 0.0, .spread = 5.0 },
    };
}

const MAX_BURST = 32;

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

/// Spawn a burst of particles at (x, y, z) with deterministic randomness.
/// Returns an array of 32 particles; only the first `count` are meaningful
/// (the rest are zeroed).
pub fn spawnBurst(
    ptype: ParticleType,
    x: f32,
    y: f32,
    z: f32,
    count: u8,
    seed: u32,
) [MAX_BURST]SpawnedParticle {
    const tmpl = getTemplate(ptype);
    const n = @min(count, MAX_BURST);

    var result: [MAX_BURST]SpawnedParticle = @splat(std.mem.zeroes(SpawnedParticle));
    var state = seed;
    if (state == 0) state = 1;

    for (0..n) |i| {
        state = xorshift(state);
        const fx = hashToFloat01(state) * 2.0 - 1.0;
        state = xorshift(state);
        const fy = hashToFloat01(state) * 2.0 - 1.0;
        state = xorshift(state);
        const fz = hashToFloat01(state) * 2.0 - 1.0;

        state = xorshift(state);
        const size_t = hashToFloat01(state);
        const size = tmpl.size_min + (tmpl.size_max - tmpl.size_min) * size_t;

        state = xorshift(state);
        const life_t = hashToFloat01(state);
        const life = tmpl.lifetime * (0.5 + 0.5 * life_t);

        result[i] = .{
            .x = x + fx * tmpl.spread * 0.5,
            .y = y + fy * tmpl.spread * 0.5,
            .z = z + fz * tmpl.spread * 0.5,
            .vx = fx * tmpl.spread,
            .vy = fy * tmpl.spread - tmpl.gravity * 0.1,
            .vz = fz * tmpl.spread,
            .life = life,
            .size = size,
            .r = tmpl.r,
            .g = tmpl.g,
            .b = tmpl.b,
            .a = tmpl.a,
        };
    }

    return result;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "getTemplate returns valid template for every particle type" {
    inline for (std.meta.fields(ParticleType)) |field| {
        const ptype: ParticleType = @enumFromInt(field.value);
        const tmpl = getTemplate(ptype);
        try std.testing.expect(tmpl.r >= 0.0 and tmpl.r <= 1.0);
        try std.testing.expect(tmpl.g >= 0.0 and tmpl.g <= 1.0);
        try std.testing.expect(tmpl.b >= 0.0 and tmpl.b <= 1.0);
        try std.testing.expect(tmpl.a >= 0.0 and tmpl.a <= 1.0);
        try std.testing.expect(tmpl.size_min > 0.0);
        try std.testing.expect(tmpl.size_max >= tmpl.size_min);
        try std.testing.expect(tmpl.lifetime > 0.0);
    }
}

test "getTemplate torch_flame has negative gravity (rises)" {
    const tmpl = getTemplate(.torch_flame);
    try std.testing.expect(tmpl.gravity < 0.0);
}

test "getTemplate explosion has zero gravity" {
    const tmpl = getTemplate(.explosion);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), tmpl.gravity, 0.001);
}

test "spawnBurst returns correct count of active particles" {
    const burst = spawnBurst(.block_break, 5.0, 10.0, 5.0, 8, 42);
    var active: u32 = 0;
    for (burst) |p| {
        if (p.life > 0.0) active += 1;
    }
    try std.testing.expectEqual(@as(u32, 8), active);
}

test "spawnBurst unused slots are zeroed" {
    const burst = spawnBurst(.torch_flame, 0.0, 0.0, 0.0, 3, 100);
    // Slots 3..31 should be zeroed
    for (3..MAX_BURST) |i| {
        try std.testing.expectApproxEqAbs(@as(f32, 0.0), burst[i].life, 0.001);
        try std.testing.expectApproxEqAbs(@as(f32, 0.0), burst[i].x, 0.001);
    }
}

test "spawnBurst clamps count to 32" {
    const burst = spawnBurst(.portal, 0.0, 0.0, 0.0, 255, 7);
    var active: u32 = 0;
    for (burst) |p| {
        if (p.life > 0.0) active += 1;
    }
    try std.testing.expectEqual(@as(u32, MAX_BURST), active);
}

test "spawnBurst deterministic with same seed" {
    const a = spawnBurst(.critical_hit, 1.0, 2.0, 3.0, 16, 999);
    const b = spawnBurst(.critical_hit, 1.0, 2.0, 3.0, 16, 999);
    for (0..16) |i| {
        try std.testing.expectApproxEqAbs(a[i].x, b[i].x, 0.0001);
        try std.testing.expectApproxEqAbs(a[i].vy, b[i].vy, 0.0001);
        try std.testing.expectApproxEqAbs(a[i].life, b[i].life, 0.0001);
    }
}

test "spawnBurst different seeds produce different results" {
    const a = spawnBurst(.lava_drip, 0.0, 0.0, 0.0, 4, 1);
    const b = spawnBurst(.lava_drip, 0.0, 0.0, 0.0, 4, 2);
    var any_diff = false;
    for (0..4) |i| {
        if (@abs(a[i].x - b[i].x) > 0.0001) any_diff = true;
    }
    try std.testing.expect(any_diff);
}

test "spawnBurst particle colors match template" {
    const burst = spawnBurst(.redstone_dust, 0.0, 0.0, 0.0, 5, 50);
    const tmpl = getTemplate(.redstone_dust);
    for (0..5) |i| {
        try std.testing.expectApproxEqAbs(tmpl.r, burst[i].r, 0.001);
        try std.testing.expectApproxEqAbs(tmpl.g, burst[i].g, 0.001);
        try std.testing.expectApproxEqAbs(tmpl.b, burst[i].b, 0.001);
        try std.testing.expectApproxEqAbs(tmpl.a, burst[i].a, 0.001);
    }
}

test "spawnBurst particle sizes within template bounds" {
    const burst = spawnBurst(.snow_fall, 0.0, 0.0, 0.0, 32, 777);
    const tmpl = getTemplate(.snow_fall);
    for (0..MAX_BURST) |i| {
        if (burst[i].life > 0.0) {
            try std.testing.expect(burst[i].size >= tmpl.size_min - 0.001);
            try std.testing.expect(burst[i].size <= tmpl.size_max + 0.001);
        }
    }
}

test "spawnBurst particle lifetimes within expected range" {
    const burst = spawnBurst(.campfire_smoke, 0.0, 0.0, 0.0, 20, 123);
    const tmpl = getTemplate(.campfire_smoke);
    for (0..20) |i| {
        try std.testing.expect(burst[i].life >= tmpl.lifetime * 0.5 - 0.001);
        try std.testing.expect(burst[i].life <= tmpl.lifetime + 0.001);
    }
}

test "spawnBurst with zero count produces all-zero array" {
    const burst = spawnBurst(.water_drip, 5.0, 5.0, 5.0, 0, 42);
    for (burst) |p| {
        try std.testing.expectApproxEqAbs(@as(f32, 0.0), p.life, 0.001);
    }
}

test "spawnBurst with seed zero does not hang" {
    const burst = spawnBurst(.enchant_glyph, 1.0, 1.0, 1.0, 4, 0);
    var active: u32 = 0;
    for (burst) |p| {
        if (p.life > 0.0) active += 1;
    }
    try std.testing.expectEqual(@as(u32, 4), active);
}

test "ParticleType enum has 12 variants" {
    const fields = std.meta.fields(ParticleType);
    try std.testing.expectEqual(@as(usize, 12), fields.len);
}

test "spawnBurst positions near spawn origin" {
    const burst = spawnBurst(.potion_splash, 10.0, 20.0, 30.0, 16, 555);
    const tmpl = getTemplate(.potion_splash);
    const half_spread = tmpl.spread * 0.5;
    for (0..16) |i| {
        try std.testing.expect(burst[i].x >= 10.0 - half_spread - 0.001);
        try std.testing.expect(burst[i].x <= 10.0 + half_spread + 0.001);
        try std.testing.expect(burst[i].y >= 20.0 - half_spread - 0.001);
        try std.testing.expect(burst[i].y <= 20.0 + half_spread + 0.001);
        try std.testing.expect(burst[i].z >= 30.0 - half_spread - 0.001);
        try std.testing.expect(burst[i].z <= 30.0 + half_spread + 0.001);
    }
}
