const std = @import("std");

pub const SkyGradient = struct {
    top: [3]f32,
    horizon: [3]f32,
};

pub const SunPosition = struct {
    angle: f32,
    visible: bool,
};

pub const MoonPosition = struct {
    angle: f32,
    visible: bool,
    phase: u3,
};

pub const StarField = struct {
    positions: [star_count][2]f32,
    brightness: [star_count]f32,

    pub const star_count: usize = 64;

    /// Deterministically generate a star field from a seed.
    pub fn init(seed: u64) StarField {
        var prng = std.Random.DefaultPrng.init(seed);
        const rng = prng.random();

        var field: StarField = undefined;
        for (0..star_count) |i| {
            field.positions[i] = .{ rng.float(f32), rng.float(f32) };
            field.brightness[i] = 0.3 + rng.float(f32) * 0.7;
        }
        return field;
    }

    /// Star visibility factor: 0.0 during full day, 1.0 at midnight.
    /// Stars begin appearing at sunset (0.2) and fade after sunrise (0.8).
    pub fn getVisibility(time: f32) f32 {
        const t = wrapTime(time);
        // Night window: visible between 0.2 and 0.8 on the day cycle.
        // Peak at 0.5 (midnight).
        if (t <= 0.2 or t >= 0.8) return 0.0;
        if (t <= 0.3) return (t - 0.2) * 10.0; // fade in
        if (t >= 0.7) return (0.8 - t) * 10.0; // fade out
        return 1.0; // full night
    }
};

const KeyColor = struct { top: [3]f32, horizon: [3]f32 };

const noon_color = KeyColor{
    .top = .{ 0.3, 0.5, 1.0 },
    .horizon = .{ 0.6, 0.8, 1.0 },
};
const sunset_color = KeyColor{
    .top = .{ 0.2, 0.1, 0.3 },
    .horizon = .{ 0.9, 0.4, 0.2 },
};
const night_color = KeyColor{
    .top = .{ 0.01, 0.01, 0.05 },
    .horizon = .{ 0.05, 0.05, 0.1 },
};
const sunrise_color = KeyColor{
    .top = .{ 0.3, 0.2, 0.4 },
    .horizon = .{ 0.9, 0.5, 0.3 },
};

// Ordered key-frame colors at 0.0, 0.25, 0.5, 0.75.
const key_colors = [_]KeyColor{ noon_color, sunset_color, night_color, sunrise_color };

/// Wrap time into [0, 1).  `x - floor(x)` is always non-negative for finite f32.
fn wrapTime(t: f32) f32 {
    return t - @floor(t);
}

fn lerpScalar(a: f32, b: f32, t: f32) f32 {
    return a + (b - a) * t;
}

fn lerpColor(a: [3]f32, b: [3]f32, t: f32) [3]f32 {
    return .{
        lerpScalar(a[0], b[0], t),
        lerpScalar(a[1], b[1], t),
        lerpScalar(a[2], b[2], t),
    };
}

/// Return sky gradient colors (top and horizon) for a given time of day.
/// time_of_day: 0.0 = noon, 0.25 = sunset, 0.5 = midnight, 0.75 = sunrise.
pub fn getSkyGradient(time_of_day: f32) SkyGradient {
    const t = wrapTime(time_of_day);

    // Key-frames are evenly spaced at 0.25 intervals.
    const scaled = t * 4.0;
    const lo: usize = @min(@as(usize, @intFromFloat(scaled)), 3);
    const hi = (lo + 1) % 4;
    const frac = scaled - @as(f32, @floatFromInt(lo));

    return SkyGradient{
        .top = lerpColor(key_colors[lo].top, key_colors[hi].top, frac),
        .horizon = lerpColor(key_colors[lo].horizon, key_colors[hi].horizon, frac),
    };
}

/// Return the sun's angle and visibility for a given time.
/// The sun is visible during the day half (time 0.75..1.0..0.25).
/// Angle: 0 = horizon (sunrise), pi/2 = zenith (noon), pi = horizon (sunset).
pub fn getSunPosition(time: f32) SunPosition {
    const t = wrapTime(time);
    // Sun visible from 0.75 (sunrise) through 0.0 (noon) to 0.25 (sunset).
    const visible = (t >= 0.75 or t <= 0.25);

    // Map [0.75, 1.25) -> [0, pi].  Normalize so sunrise=0, noon=pi/2, sunset=pi.
    const sun_t = if (t >= 0.75) t - 0.75 else t + 0.25;
    const angle = sun_t * 2.0 * std.math.pi;

    return SunPosition{ .angle = angle, .visible = visible };
}

/// Return the moon's angle, visibility, and phase for a given time.
/// The moon is visible during the night half (time 0.25..0.75).
/// Phase cycles 0-7 based on the integer part of time (each full day advances phase).
pub fn getMoonPosition(time: f32) MoonPosition {
    const t = wrapTime(time);
    const visible = (t >= 0.25 and t <= 0.75);

    // Map [0.25, 0.75] -> [0, pi].
    const moon_t = if (t >= 0.25 and t <= 0.75) (t - 0.25) * 2.0 else 0.0;
    const angle = moon_t * std.math.pi;

    // Phase: use the integer day count (floor of input time).
    const day: u64 = @intFromFloat(@abs(@floor(time)));
    const phase: u3 = @truncate(day % 8);

    return MoonPosition{ .angle = angle, .visible = visible, .phase = phase };
}

/// Return the fog color, blended to match the sky horizon.
pub fn getFogColor(time: f32) [3]f32 {
    return getSkyGradient(time).horizon;
}

/// Return the ambient light level: 0.1 at midnight, 1.0 at noon.
/// Smoothly interpolated using a cosine curve.
pub fn getAmbientLight(time: f32) f32 {
    const t = wrapTime(time);
    // cos(2*pi*t) gives 1.0 at t=0 (noon) and -1.0 at t=0.5 (midnight).
    // Remap [-1,1] to [0.1, 1.0]: level = 0.55 + 0.45*cos(2*pi*t).
    return 0.55 + 0.45 * @cos(2.0 * std.math.pi * t);
}

const expectApprox = std.testing.expectApproxEqAbs;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const tolerance: f32 = 0.001;

test "sky gradient at noon" {
    const g = getSkyGradient(0.0);
    try expectApprox(0.3, g.top[0], tolerance);
    try expectApprox(0.5, g.top[1], tolerance);
    try expectApprox(1.0, g.top[2], tolerance);
    try expectApprox(0.6, g.horizon[0], tolerance);
    try expectApprox(0.8, g.horizon[1], tolerance);
    try expectApprox(1.0, g.horizon[2], tolerance);
}

test "sky gradient at sunset" {
    const g = getSkyGradient(0.25);
    try expectApprox(0.2, g.top[0], tolerance);
    try expectApprox(0.1, g.top[1], tolerance);
    try expectApprox(0.3, g.top[2], tolerance);
    try expectApprox(0.9, g.horizon[0], tolerance);
    try expectApprox(0.4, g.horizon[1], tolerance);
    try expectApprox(0.2, g.horizon[2], tolerance);
}

test "sky gradient at midnight" {
    const g = getSkyGradient(0.5);
    try expectApprox(0.01, g.top[0], tolerance);
    try expectApprox(0.01, g.top[1], tolerance);
    try expectApprox(0.05, g.top[2], tolerance);
}

test "sky gradient at sunrise" {
    const g = getSkyGradient(0.75);
    try expectApprox(0.3, g.top[0], tolerance);
    try expectApprox(0.2, g.top[1], tolerance);
    try expectApprox(0.4, g.top[2], tolerance);
}

test "sky gradient interpolates mid-values" {
    // Halfway between noon (0.0) and sunset (0.25) = 0.125
    const g = getSkyGradient(0.125);
    // Expect midpoint of noon and sunset top-R: (0.3+0.2)/2 = 0.25
    try expectApprox(0.25, g.top[0], tolerance);
}

test "sun visible at noon, invisible at midnight" {
    const noon = getSunPosition(0.0);
    try expect(noon.visible);

    const midnight = getSunPosition(0.5);
    try expect(!midnight.visible);
}

test "sun angle increases from sunrise to sunset" {
    const sunrise = getSunPosition(0.75);
    const noon = getSunPosition(0.0);
    const sunset = getSunPosition(0.25);
    try expect(sunrise.angle < noon.angle);
    try expect(noon.angle < sunset.angle);
}

test "moon visible at midnight, invisible at noon" {
    const midnight = getMoonPosition(0.5);
    try expect(midnight.visible);

    const noon = getMoonPosition(0.0);
    try expect(!noon.visible);
}

test "moon phase advances with day count" {
    const day0 = getMoonPosition(0.5);
    const day1 = getMoonPosition(1.5);
    const day7 = getMoonPosition(7.5);
    try expectEqual(@as(u3, 0), day0.phase);
    try expectEqual(@as(u3, 1), day1.phase);
    try expectEqual(@as(u3, 7), day7.phase);
    // Day 8 wraps back to 0
    const day8 = getMoonPosition(8.5);
    try expectEqual(@as(u3, 0), day8.phase);
}

test "star field init is deterministic" {
    const a = StarField.init(42);
    const b = StarField.init(42);
    for (0..StarField.star_count) |i| {
        try expectApprox(a.positions[i][0], b.positions[i][0], tolerance);
        try expectApprox(a.brightness[i], b.brightness[i], tolerance);
    }
}

test "star visibility: zero during day, one at midnight" {
    try expectApprox(0.0, StarField.getVisibility(0.0), tolerance);
    try expectApprox(0.0, StarField.getVisibility(0.1), tolerance);
    try expectApprox(1.0, StarField.getVisibility(0.5), tolerance);
}

test "fog color matches horizon" {
    const fog = getFogColor(0.25);
    const grad = getSkyGradient(0.25);
    try expectApprox(grad.horizon[0], fog[0], tolerance);
    try expectApprox(grad.horizon[1], fog[1], tolerance);
    try expectApprox(grad.horizon[2], fog[2], tolerance);
}

test "ambient light range" {
    const noon_light = getAmbientLight(0.0);
    const midnight_light = getAmbientLight(0.5);
    try expectApprox(1.0, noon_light, tolerance);
    try expectApprox(0.1, midnight_light, tolerance);
    // Mid value should be between extremes
    const quarter = getAmbientLight(0.25);
    try expect(quarter > 0.1 and quarter < 1.0);
}

test "time wrapping works for negative and large values" {
    // Gradient at time 1.0 should equal time 0.0 (noon)
    const g0 = getSkyGradient(0.0);
    const g1 = getSkyGradient(1.0);
    try expectApprox(g0.top[0], g1.top[0], tolerance);

    // Large positive time
    const g100 = getSkyGradient(100.0);
    try expectApprox(g0.top[0], g100.top[0], tolerance);
}
