const std = @import("std");

/// Types of weather that can be rendered.
pub const WeatherType = enum {
    none,
    rain,
    snow,
    thunder,
};

/// A single weather particle with position, velocity, size, and color.
pub const WeatherParticle = struct {
    x: f32,
    y: f32,
    z: f32,
    vy: f32,
    size: f32,
    r: f32,
    g: f32,
    b: f32,
    a: f32,
};

const particle_count = 200;

const PrecipConfig = struct {
    min_speed: f32,
    speed_range: f32,
    size: f32,
    r: f32,
    g: f32,
    b: f32,
    a: f32,
};

const rain_cfg = PrecipConfig{ .min_speed = 12.0, .speed_range = 6.0, .size = 0.02, .r = 0.8, .g = 0.85, .b = 1.0, .a = 0.6 };
const thunder_cfg = PrecipConfig{ .min_speed = 14.0, .speed_range = 8.0, .size = 0.03, .r = 0.9, .g = 0.9, .b = 1.0, .a = 0.8 };

/// Generate 200 weather particles around the player position.
///
/// Rain: white vertical streaks falling fast (vy ~ -12 to -18).
/// Snow: white dots drifting slowly (vy ~ -1 to -2) with horizontal wobble baked into x/z.
/// Thunder: same as rain but slightly brighter/more opaque.
/// None: zeroed-out transparent particles.
pub fn generateParticles(
    wtype: WeatherType,
    player_x: f32,
    player_y: f32,
    player_z: f32,
    time: f32,
    seed: u64,
) [particle_count]WeatherParticle {
    const time_bits: u64 = @bitCast(@as(f64, time));
    var prng = std.Random.DefaultPrng.init(seed ^ time_bits);
    const rng = prng.random();

    const spread: f32 = 20.0;
    const height_range: f32 = 30.0;

    var particles: [particle_count]WeatherParticle = undefined;

    for (&particles) |*p| {
        const rx = rng.float(f32) * spread * 2.0 - spread;
        const ry = rng.float(f32) * height_range;
        const rz = rng.float(f32) * spread * 2.0 - spread;
        const base_x = player_x + rx;
        const base_y = player_y + ry;
        const base_z = player_z + rz;

        switch (wtype) {
            .rain, .thunder => {
                const cfg = if (wtype == .rain) rain_cfg else thunder_cfg;
                p.* = .{
                    .x = base_x,
                    .y = base_y,
                    .z = base_z,
                    .vy = -(cfg.min_speed + rng.float(f32) * cfg.speed_range),
                    .size = cfg.size,
                    .r = cfg.r,
                    .g = cfg.g,
                    .b = cfg.b,
                    .a = cfg.a,
                };
            },
            .snow => {
                const wobble = @sin(time + rng.float(f32) * std.math.pi * 2.0) * 0.5;
                p.* = .{
                    .x = base_x + wobble,
                    .y = base_y,
                    .z = base_z + wobble * 0.7,
                    .vy = -(1.0 + rng.float(f32)),
                    .size = 0.08,
                    .r = 1.0,
                    .g = 1.0,
                    .b = 1.0,
                    .a = 0.9,
                };
            },
            .none => {
                p.* = std.mem.zeroes(WeatherParticle);
            },
        }
    }

    return particles;
}

/// Advance a single weather particle by `dt` seconds.
///
/// Rain/thunder: purely vertical fall, slight alpha fade over time.
/// Snow: slow vertical fall with a horizontal sine wobble applied to x.
/// None: no-op.
pub fn updateParticle(p: *WeatherParticle, dt: f32, wtype: WeatherType) void {
    switch (wtype) {
        .rain, .thunder => {
            p.y += p.vy * dt;
            p.a = @max(p.a - 0.1 * dt, 0);
        },
        .snow => {
            p.y += p.vy * dt;
            p.x += @sin(p.y * 0.5) * 0.3 * dt;
            p.a = @max(p.a - 0.05 * dt, 0);
        },
        .none => {},
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "generateParticles returns 200 particles" {
    const particles = generateParticles(.rain, 0, 0, 0, 0, 42);
    try std.testing.expectEqual(@as(usize, 200), particles.len);
}

test "rain particles have negative vy between -18 and -12" {
    const particles = generateParticles(.rain, 0, 64, 0, 1.0, 123);
    for (particles) |p| {
        try std.testing.expect(p.vy <= -12.0);
        try std.testing.expect(p.vy >= -18.0);
    }
}

test "snow particles drift slowly (vy between -2 and -1)" {
    const particles = generateParticles(.snow, 10, 64, 10, 2.0, 456);
    for (particles) |p| {
        try std.testing.expect(p.vy <= -1.0);
        try std.testing.expect(p.vy >= -2.0);
    }
}

test "none weather produces transparent zeroed particles" {
    const particles = generateParticles(.none, 5, 5, 5, 0, 99);
    for (particles) |p| {
        try std.testing.expectApproxEqAbs(@as(f32, 0), p.a, 0.001);
        try std.testing.expectApproxEqAbs(@as(f32, 0), p.vy, 0.001);
        try std.testing.expectApproxEqAbs(@as(f32, 0), p.size, 0.001);
    }
}

test "particles are distributed around the player position" {
    const px: f32 = 100.0;
    const pz: f32 = -50.0;
    const particles = generateParticles(.rain, px, 64, pz, 0, 77);
    for (particles) |p| {
        try std.testing.expect(p.x >= px - 20.0 and p.x <= px + 20.0);
        try std.testing.expect(p.z >= pz - 20.0 and p.z <= pz + 20.0);
    }
}

test "thunder particles fall faster than rain" {
    const rain = generateParticles(.rain, 0, 64, 0, 0, 1);
    const thunder = generateParticles(.thunder, 0, 64, 0, 0, 1);

    var rain_avg: f32 = 0;
    var thunder_avg: f32 = 0;
    for (rain, thunder) |rp, tp| {
        rain_avg += rp.vy;
        thunder_avg += tp.vy;
    }
    rain_avg /= @as(f32, @floatFromInt(particle_count));
    thunder_avg /= @as(f32, @floatFromInt(particle_count));

    // Thunder should have a lower (more negative) average vy
    try std.testing.expect(thunder_avg < rain_avg);
}

test "updateParticle moves rain particle downward" {
    var p = WeatherParticle{
        .x = 0,
        .y = 100,
        .z = 0,
        .vy = -15.0,
        .size = 0.02,
        .r = 0.8,
        .g = 0.85,
        .b = 1.0,
        .a = 0.6,
    };
    const y_before = p.y;
    updateParticle(&p, 0.1, .rain);
    try std.testing.expect(p.y < y_before);
    try std.testing.expectApproxEqAbs(@as(f32, 98.5), p.y, 0.001);
}

test "updateParticle fades rain alpha" {
    var p = WeatherParticle{
        .x = 0,
        .y = 100,
        .z = 0,
        .vy = -15.0,
        .size = 0.02,
        .r = 0.8,
        .g = 0.85,
        .b = 1.0,
        .a = 0.6,
    };
    updateParticle(&p, 1.0, .rain);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), p.a, 0.001);
}

test "updateParticle snow wobbles horizontally" {
    var p = WeatherParticle{
        .x = 5.0,
        .y = 50.0,
        .z = 5.0,
        .vy = -1.5,
        .size = 0.08,
        .r = 1.0,
        .g = 1.0,
        .b = 1.0,
        .a = 0.9,
    };
    const x_before = p.x;
    updateParticle(&p, 0.5, .snow);
    // x should have changed due to wobble
    try std.testing.expect(p.x != x_before);
    // y should have moved down
    try std.testing.expect(p.y < 50.0);
}

test "updateParticle alpha clamps to zero" {
    var p = WeatherParticle{
        .x = 0,
        .y = 100,
        .z = 0,
        .vy = -15.0,
        .size = 0.02,
        .r = 0.8,
        .g = 0.85,
        .b = 1.0,
        .a = 0.01,
    };
    updateParticle(&p, 1.0, .rain);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), p.a, 0.001);
}

test "updateParticle none does nothing" {
    var p = WeatherParticle{
        .x = 5.0,
        .y = 50.0,
        .z = 5.0,
        .vy = -10.0,
        .size = 0.05,
        .r = 1.0,
        .g = 1.0,
        .b = 1.0,
        .a = 0.8,
    };
    updateParticle(&p, 1.0, .none);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), p.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 50.0), p.y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.8), p.a, 0.001);
}

test "different seeds produce different particle layouts" {
    const a = generateParticles(.rain, 0, 64, 0, 1.0, 100);
    const b = generateParticles(.rain, 0, 64, 0, 1.0, 200);
    var differ = false;
    for (a, b) |pa, pb| {
        if (pa.x != pb.x or pa.y != pb.y or pa.z != pb.z) {
            differ = true;
            break;
        }
    }
    try std.testing.expect(differ);
}

test "snow particles are larger than rain particles" {
    const rain = generateParticles(.rain, 0, 64, 0, 0, 1);
    const snow = generateParticles(.snow, 0, 64, 0, 0, 1);
    try std.testing.expect(snow[0].size > rain[0].size);
}
