const std = @import("std");

/// A single star-like particle rendered inside the end portal frame.
pub const StarParticle = struct {
    x: f32,
    y: f32,
    z: f32,
    r: f32,
    g: f32,
    b: f32,
    a: f32,
    size: f32,
};

const star_count = 48;

/// Color palette for portal star particles.
const StarKind = enum(u2) {
    white,
    cyan,
    green,
};

const KindColor = struct { r: f32, g: f32, b: f32 };

fn kindBaseColor(kind: StarKind) KindColor {
    return switch (kind) {
        .white => .{ .r = 1.0, .g = 1.0, .b = 1.0 },
        .cyan => .{ .r = 0.3, .g = 0.9, .b = 0.95 },
        .green => .{ .r = 0.2, .g = 0.85, .b = 0.3 },
    };
}

/// Distribution: first 16 white, next 16 cyan, last 16 green.
const white_count = 16;
const cyan_count = 16;

/// Drift speed in units per second for the slow swirl motion.
const drift_speed: f32 = 0.15;

/// Portal frame half-extent used to keep stars inside the frame area.
const frame_radius: f32 = 1.5;

// -----------------------------------------------------------------------
// Deterministic PRNG helpers
// -----------------------------------------------------------------------

fn xorshift64(state: u64) u64 {
    var s = state;
    s ^= s << 13;
    s ^= s >> 7;
    s ^= s << 17;
    return s;
}

fn hashToFloat01(h: u64) f32 {
    return @as(f32, @floatFromInt(h & 0xFFFF)) / 65536.0;
}

fn clamp01(v: f32) f32 {
    return @max(0.0, @min(1.0, v));
}

/// Generate 48 star particles drifting inside the portal frame centered at
/// (cx, cy, cz). `time` drives the slow drift animation and `seed` makes
/// each portal instance unique.
pub fn generateStars(cx: f32, cy: f32, cz: f32, time: f32, seed: u64) [star_count]StarParticle {
    var result: [star_count]StarParticle = undefined;
    var state: u64 = seed;
    if (state == 0) state = 1;

    for (0..star_count) |i| {
        // Advance PRNG for position offsets
        state = xorshift64(state);
        const fx = hashToFloat01(state) * 2.0 - 1.0;
        state = xorshift64(state);
        const fy = hashToFloat01(state);
        state = xorshift64(state);
        const fz = hashToFloat01(state) * 2.0 - 1.0;

        // Per-star phase offset so they twinkle independently
        state = xorshift64(state);
        const phase = hashToFloat01(state) * std.math.pi * 2.0;

        // Size variation
        state = xorshift64(state);
        const size_t = hashToFloat01(state);

        // Color variation
        state = xorshift64(state);
        const color_var = hashToFloat01(state) * 0.15 - 0.075;

        // Determine kind from index distribution
        const kind: StarKind = if (i < white_count)
            .white
        else if (i < white_count + cyan_count)
            .cyan
        else
            .green;

        const base = kindBaseColor(kind);

        // Slow circular drift driven by time
        const angle = time * drift_speed + phase;
        const drift_x = @cos(angle) * 0.1;
        const drift_z = @sin(angle) * 0.1;

        // Alpha twinkle: sinusoidal pulse per particle
        const twinkle = 0.5 + 0.5 * @sin(time * 2.0 + phase);

        result[i] = .{
            .x = cx + fx * frame_radius + drift_x,
            .y = cy + fy * 0.3,
            .z = cz + fz * frame_radius + drift_z,
            .r = clamp01(base.r + color_var),
            .g = clamp01(base.g + color_var),
            .b = clamp01(base.b + color_var),
            .a = clamp01(0.4 + twinkle * 0.6),
            .size = 0.02 + size_t * 0.04,
        };
    }

    return result;
}

/// Return the current portal surface color as an RGB triple.
/// Cycles slowly through dark purple, near-black, and dark green.
pub fn getPortalColor(time: f32) [3]f32 {
    // Three-phase cycle: purple -> black -> green -> purple
    const cycle_speed: f32 = 0.3;
    const t = @mod(time * cycle_speed, 1.0);

    // Purple: (0.15, 0.0, 0.2)   Black: (0.02, 0.02, 0.02)   Green: (0.0, 0.15, 0.05)
    if (t < 1.0 / 3.0) {
        // Purple to black
        const s = t * 3.0;
        return .{
            lerp(0.15, 0.02, s),
            lerp(0.0, 0.02, s),
            lerp(0.2, 0.02, s),
        };
    } else if (t < 2.0 / 3.0) {
        // Black to green
        const s = (t - 1.0 / 3.0) * 3.0;
        return .{
            lerp(0.02, 0.0, s),
            lerp(0.02, 0.15, s),
            lerp(0.02, 0.05, s),
        };
    } else {
        // Green to purple
        const s = (t - 2.0 / 3.0) * 3.0;
        return .{
            lerp(0.0, 0.15, s),
            lerp(0.15, 0.0, s),
            lerp(0.05, 0.2, s),
        };
    }
}

fn lerp(a: f32, b: f32, t: f32) f32 {
    return a + (b - a) * t;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "generateStars returns 48 particles" {
    const stars = generateStars(0, 0, 0, 0, 42);
    try std.testing.expectEqual(@as(usize, 48), stars.len);
}

test "all stars have colors in 0-1 range" {
    const stars = generateStars(1, 2, 3, 5.0, 999);
    for (stars) |s| {
        try std.testing.expect(s.r >= 0.0 and s.r <= 1.0);
        try std.testing.expect(s.g >= 0.0 and s.g <= 1.0);
        try std.testing.expect(s.b >= 0.0 and s.b <= 1.0);
        try std.testing.expect(s.a >= 0.0 and s.a <= 1.0);
    }
}

test "all stars have positive size" {
    const stars = generateStars(0, 0, 0, 1.0, 7);
    for (stars) |s| {
        try std.testing.expect(s.size > 0.0);
    }
}

test "white stars have high RGB channels" {
    const stars = generateStars(0, 0, 0, 0, 123);
    for (0..white_count) |i| {
        try std.testing.expect(stars[i].r > 0.8);
        try std.testing.expect(stars[i].g > 0.8);
        try std.testing.expect(stars[i].b > 0.8);
    }
}

test "cyan stars have high green and blue channels" {
    const stars = generateStars(0, 0, 0, 0, 456);
    for (white_count..white_count + cyan_count) |i| {
        try std.testing.expect(stars[i].g > 0.7);
        try std.testing.expect(stars[i].b > 0.7);
    }
}

test "green stars have dominant green channel" {
    const stars = generateStars(0, 0, 0, 0, 789);
    for (white_count + cyan_count..star_count) |i| {
        try std.testing.expect(stars[i].g > stars[i].r);
        try std.testing.expect(stars[i].g > stars[i].b);
    }
}

test "deterministic with same seed" {
    const a = generateStars(1, 2, 3, 0.5, 999);
    const b = generateStars(1, 2, 3, 0.5, 999);
    for (0..star_count) |i| {
        try std.testing.expectApproxEqAbs(a[i].x, b[i].x, 0.0001);
        try std.testing.expectApproxEqAbs(a[i].y, b[i].y, 0.0001);
        try std.testing.expectApproxEqAbs(a[i].r, b[i].r, 0.0001);
    }
}

test "different seeds produce different results" {
    const a = generateStars(0, 0, 0, 0, 1);
    const b = generateStars(0, 0, 0, 0, 2);
    var any_diff = false;
    for (0..star_count) |i| {
        if (@abs(a[i].x - b[i].x) > 0.0001) any_diff = true;
    }
    try std.testing.expect(any_diff);
}

test "seed zero does not hang and produces valid particles" {
    const stars = generateStars(0, 0, 0, 0, 0);
    for (stars) |s| {
        try std.testing.expect(s.size > 0.0);
        try std.testing.expect(std.math.isFinite(s.x));
    }
}

test "stars centered around portal position" {
    const cx: f32 = 10.0;
    const cy: f32 = 20.0;
    const cz: f32 = -5.0;
    const stars = generateStars(cx, cy, cz, 0, 42);
    var sum_x: f32 = 0;
    var sum_z: f32 = 0;
    for (stars) |s| {
        sum_x += s.x;
        sum_z += s.z;
        // y should be near cy (within small vertical offset)
        try std.testing.expect(s.y >= cy and s.y <= cy + 0.4);
    }
    // Mean x and z should be near center
    const mean_x = sum_x / @as(f32, star_count);
    const mean_z = sum_z / @as(f32, star_count);
    try std.testing.expect(@abs(mean_x - cx) < frame_radius);
    try std.testing.expect(@abs(mean_z - cz) < frame_radius);
}

test "getPortalColor returns values in 0-1 range" {
    const times = [_]f32{ 0.0, 0.5, 1.0, 2.5, 10.0, 100.0 };
    for (times) |t| {
        const c = getPortalColor(t);
        for (c) |ch| {
            try std.testing.expect(ch >= 0.0 and ch <= 1.0);
        }
    }
}

test "getPortalColor is dark (low brightness)" {
    const times = [_]f32{ 0.0, 1.0, 3.0, 7.0 };
    for (times) |t| {
        const c = getPortalColor(t);
        const brightness = (c[0] + c[1] + c[2]) / 3.0;
        try std.testing.expect(brightness < 0.25);
    }
}

test "getPortalColor cycles over time (different at different times)" {
    const c1 = getPortalColor(0.0);
    const c2 = getPortalColor(1.5);
    const diff = @abs(c1[0] - c2[0]) + @abs(c1[1] - c2[1]) + @abs(c1[2] - c2[2]);
    try std.testing.expect(diff > 0.01);
}

test "time changes star positions via drift" {
    const a = generateStars(0, 0, 0, 0.0, 42);
    const b = generateStars(0, 0, 0, 10.0, 42);
    var any_diff = false;
    for (0..star_count) |i| {
        if (@abs(a[i].x - b[i].x) > 0.001) any_diff = true;
    }
    try std.testing.expect(any_diff);
}
