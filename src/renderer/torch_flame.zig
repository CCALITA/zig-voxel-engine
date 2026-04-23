const std = @import("std");

/// A single flame or smoke particle with position, visual properties, and lifetime.
pub const FlameParticle = struct {
    x: f32,
    y: f32,
    z: f32,
    size: f32,
    r: f32,
    g: f32,
    b: f32,
    a: f32,
    life: f32,
};

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

/// Derive a deterministic seed from a time value.
fn seedFromTime(time: f32) u32 {
    const bits: u32 = @bitCast(time);
    const s = xorshift(bits | 1);
    return if (s == 0) 1 else s;
}

/// Spawn 3 orange/yellow flickering flame particles above the torch center.
///
/// The `time` parameter drives deterministic variation so that each frame
/// produces a slightly different flicker pattern. Particles are placed just
/// above the torch tip with small horizontal jitter and varying orange-to-yellow
/// color.
pub fn spawnTorchFlame(tx: f32, ty: f32, tz: f32, time: f32) [3]FlameParticle {
    var result: [3]FlameParticle = undefined;
    var state = seedFromTime(time);

    for (0..3) |i| {
        // Small horizontal jitter around torch center
        state = xorshift(state);
        const ox = (hashToFloat01(state) * 2.0 - 1.0) * 0.04;
        state = xorshift(state);
        const oz = (hashToFloat01(state) * 2.0 - 1.0) * 0.04;

        // Slight vertical offset above torch tip
        state = xorshift(state);
        const oy = hashToFloat01(state) * 0.05;

        // Orange-to-yellow color variation: red stays high, green varies
        state = xorshift(state);
        const g_variation = hashToFloat01(state);
        const green = 0.45 + g_variation * 0.35; // range [0.45, 0.80]

        // Size variation
        state = xorshift(state);
        const size = 0.03 + hashToFloat01(state) * 0.03; // range [0.03, 0.06]

        // Life variation
        state = xorshift(state);
        const life = 0.3 + hashToFloat01(state) * 0.3; // range [0.3, 0.6]

        result[i] = .{
            .x = tx + ox,
            .y = ty + 0.6 + oy,
            .z = tz + oz,
            .size = size,
            .r = 1.0,
            .g = green,
            .b = 0.1,
            .a = 0.9,
            .life = life,
        };
    }

    return result;
}

/// Spawn a single gray smoke wisp above the torch.
///
/// The wisp starts small and semi-transparent, positioned just above where
/// the flame would be. It rises slowly and fades out.
pub fn spawnSmokeWisp(tx: f32, ty: f32, tz: f32) FlameParticle {
    return .{
        .x = tx,
        .y = ty + 0.7,
        .z = tz,
        .size = 0.02,
        .r = 0.55,
        .g = 0.55,
        .b = 0.55,
        .a = 0.35,
        .life = 0.8,
    };
}

/// Update a flame particle for one tick.
///
/// The particle rises upward, fades its alpha, and shrinks over time.
/// Returns true if the particle is still alive, false if it should be removed.
pub fn updateFlame(p: *FlameParticle, dt: f32) bool {
    p.life -= dt;
    if (p.life <= 0.0) return false;

    // Rise upward
    p.y += 0.8 * dt;

    // Exponential alpha decay
    p.a *= 1.0 - 0.6 * dt;
    if (p.a < 0.0) p.a = 0.0;

    // Shrink
    p.size *= 1.0 - 0.5 * dt;
    if (p.size < 0.001) p.size = 0.001;

    return true;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "spawnTorchFlame returns 3 alive particles" {
    const particles = spawnTorchFlame(5.0, 10.0, 5.0, 1.0);
    for (particles) |p| {
        try std.testing.expect(p.life > 0.0);
    }
}

test "spawnTorchFlame particles are above torch position" {
    const ty: f32 = 10.0;
    const particles = spawnTorchFlame(5.0, ty, 5.0, 2.0);
    for (particles) |p| {
        try std.testing.expect(p.y > ty);
    }
}

test "spawnTorchFlame particles have orange/yellow color" {
    const particles = spawnTorchFlame(0.0, 0.0, 0.0, 3.0);
    for (particles) |p| {
        // Red channel is high (warm flame)
        try std.testing.expectApproxEqAbs(@as(f32, 1.0), p.r, 0.001);
        // Green in orange-to-yellow range
        try std.testing.expect(p.g >= 0.44);
        try std.testing.expect(p.g <= 0.81);
        // Blue is low (not white or blue)
        try std.testing.expectApproxEqAbs(@as(f32, 0.1), p.b, 0.001);
    }
}

test "spawnTorchFlame particles are near torch center horizontally" {
    const tx: f32 = 10.0;
    const tz: f32 = 20.0;
    const particles = spawnTorchFlame(tx, 0.0, tz, 4.0);
    for (particles) |p| {
        try std.testing.expect(@abs(p.x - tx) <= 0.05);
        try std.testing.expect(@abs(p.z - tz) <= 0.05);
    }
}

test "spawnTorchFlame is deterministic for same time" {
    const a = spawnTorchFlame(1.0, 2.0, 3.0, 5.5);
    const b = spawnTorchFlame(1.0, 2.0, 3.0, 5.5);
    for (0..3) |i| {
        try std.testing.expectApproxEqAbs(a[i].x, b[i].x, 0.0001);
        try std.testing.expectApproxEqAbs(a[i].y, b[i].y, 0.0001);
        try std.testing.expectApproxEqAbs(a[i].g, b[i].g, 0.0001);
        try std.testing.expectApproxEqAbs(a[i].life, b[i].life, 0.0001);
    }
}

test "spawnTorchFlame different times produce different results" {
    const a = spawnTorchFlame(0.0, 0.0, 0.0, 1.0);
    const b = spawnTorchFlame(0.0, 0.0, 0.0, 2.0);
    var any_diff = false;
    for (0..3) |i| {
        if (@abs(a[i].x - b[i].x) > 0.0001) any_diff = true;
        if (@abs(a[i].g - b[i].g) > 0.0001) any_diff = true;
    }
    try std.testing.expect(any_diff);
}

test "spawnSmokeWisp returns gray particle" {
    const wisp = spawnSmokeWisp(5.0, 10.0, 5.0);
    // Gray: all channels roughly equal
    try std.testing.expectApproxEqAbs(wisp.r, wisp.g, 0.001);
    try std.testing.expectApproxEqAbs(wisp.g, wisp.b, 0.001);
    // In the gray range
    try std.testing.expect(wisp.r >= 0.4);
    try std.testing.expect(wisp.r <= 0.7);
}

test "spawnSmokeWisp is above torch position" {
    const wisp = spawnSmokeWisp(0.0, 5.0, 0.0);
    try std.testing.expect(wisp.y > 5.0);
}

test "spawnSmokeWisp has low alpha (semi-transparent)" {
    const wisp = spawnSmokeWisp(0.0, 0.0, 0.0);
    try std.testing.expect(wisp.a < 0.5);
    try std.testing.expect(wisp.a > 0.0);
}

test "spawnSmokeWisp is positioned at torch center horizontally" {
    const wisp = spawnSmokeWisp(10.0, 0.0, 20.0);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), wisp.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 20.0), wisp.z, 0.001);
}

test "updateFlame reduces life" {
    var p = FlameParticle{
        .x = 0, .y = 0, .z = 0,
        .size = 0.05, .r = 1.0, .g = 0.6, .b = 0.1, .a = 0.9,
        .life = 0.5,
    };
    const before = p.life;
    const alive = updateFlame(&p, 0.1);
    try std.testing.expect(alive);
    try std.testing.expect(p.life < before);
}

test "updateFlame moves particle upward" {
    var p = FlameParticle{
        .x = 0, .y = 5.0, .z = 0,
        .size = 0.05, .r = 1.0, .g = 0.6, .b = 0.1, .a = 0.9,
        .life = 0.5,
    };
    const before_y = p.y;
    _ = updateFlame(&p, 0.1);
    try std.testing.expect(p.y > before_y);
}

test "updateFlame fades alpha" {
    var p = FlameParticle{
        .x = 0, .y = 0, .z = 0,
        .size = 0.05, .r = 1.0, .g = 0.6, .b = 0.1, .a = 0.9,
        .life = 0.5,
    };
    const before_a = p.a;
    _ = updateFlame(&p, 0.1);
    try std.testing.expect(p.a < before_a);
}

test "updateFlame shrinks particle" {
    var p = FlameParticle{
        .x = 0, .y = 0, .z = 0,
        .size = 0.05, .r = 1.0, .g = 0.6, .b = 0.1, .a = 0.9,
        .life = 0.5,
    };
    const before_size = p.size;
    _ = updateFlame(&p, 0.1);
    try std.testing.expect(p.size < before_size);
}

test "updateFlame returns false when life expires" {
    var p = FlameParticle{
        .x = 0, .y = 0, .z = 0,
        .size = 0.05, .r = 1.0, .g = 0.6, .b = 0.1, .a = 0.9,
        .life = 0.05,
    };
    const alive = updateFlame(&p, 0.1);
    try std.testing.expect(!alive);
}

test "updateFlame alpha never goes negative" {
    var p = FlameParticle{
        .x = 0, .y = 0, .z = 0,
        .size = 0.05, .r = 1.0, .g = 0.6, .b = 0.1, .a = 0.01,
        .life = 1.0,
    };
    _ = updateFlame(&p, 0.5);
    try std.testing.expect(p.a >= 0.0);
}

test "updateFlame size has minimum floor" {
    var p = FlameParticle{
        .x = 0, .y = 0, .z = 0,
        .size = 0.002, .r = 1.0, .g = 0.6, .b = 0.1, .a = 0.5,
        .life = 1.0,
    };
    _ = updateFlame(&p, 0.9);
    try std.testing.expect(p.size >= 0.001);
}

test "spawnTorchFlame particle sizes within expected range" {
    const particles = spawnTorchFlame(0.0, 0.0, 0.0, 7.0);
    for (particles) |p| {
        try std.testing.expect(p.size >= 0.029);
        try std.testing.expect(p.size <= 0.061);
    }
}

test "spawnTorchFlame particle lifetimes within expected range" {
    const particles = spawnTorchFlame(0.0, 0.0, 0.0, 8.0);
    for (particles) |p| {
        try std.testing.expect(p.life >= 0.29);
        try std.testing.expect(p.life <= 0.61);
    }
}
