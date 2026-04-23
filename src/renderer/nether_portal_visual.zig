const std = @import("std");

/// Visual particle emitted by a nether portal frame.
/// Positioned inside the 2x3 portal interior and tinted purple/magenta.
pub const PortalParticle = struct {
    x: f32,
    y: f32,
    z: f32,
    r: f32,
    g: f32,
    b: f32,
    a: f32,
    size: f32,
};

const PARTICLE_COUNT: usize = 32;

/// Portal frame dimensions (interior, like Minecraft 2 wide x 3 tall).
const FRAME_HALF_WIDTH: f32 = 1.0;
const FRAME_HEIGHT: f32 = 3.0;
const FRAME_DEPTH: f32 = 0.2;

/// Fraction of a second for the purple tone cycle period.
const COLOR_CYCLE_PERIOD: f32 = 2.5;

/// Overlay fade-in duration in seconds.
const OVERLAY_FADE_SECONDS: f32 = 4.0;
/// Maximum overlay alpha value.
const OVERLAY_MAX_ALPHA: f32 = 0.8;

/// Generate 32 purple/magenta particles spiraling upward inside the portal frame.
///
/// The particles are distributed along a double-helix-like path. Index `i`
/// determines the base height and angle; `time` advances the spiral so that
/// animating `time` rotates the helix smoothly.
pub fn generatePortalParticles(px: f32, py: f32, pz: f32, time: f32) [PARTICLE_COUNT]PortalParticle {
    var result: [PARTICLE_COUNT]PortalParticle = undefined;
    const count_f: f32 = @floatFromInt(PARTICLE_COUNT);

    for (0..PARTICLE_COUNT) |i| {
        const fi: f32 = @floatFromInt(i);
        const t_i: f32 = fi / count_f; // 0..1

        // Vertical position: wrap so particles recycle upward over time.
        const phase = @mod(t_i + time * 0.15, 1.0);
        const height = phase * FRAME_HEIGHT;

        // Spiral angle: two full turns plus time rotation.
        const angle = t_i * std.math.tau * 2.0 + time * 1.2;

        // Horizontal oscillation inside frame width; keep within [-half, +half].
        const x_offset = @sin(angle) * FRAME_HALF_WIDTH * 0.9;
        // Small depth oscillation so it reads as 3D swirl rather than flat.
        const z_offset = @cos(angle) * FRAME_DEPTH;

        // Color: start from base cycle color, then shift per-particle to add variety.
        const base = getPortalColor(time + t_i * 0.5);
        const tint = 0.15 * @sin(angle * 0.5);

        // Size modulates with phase: bright near middle, dim near edges of cycle.
        const size_pulse = 0.08 + 0.07 * (1.0 - @abs(phase - 0.5) * 2.0);

        result[i] = .{
            .x = px + x_offset,
            .y = py + height,
            .z = pz + z_offset,
            .r = clamp01(base[0] + tint),
            .g = clamp01(base[1]),
            .b = clamp01(base[2] + tint),
            .a = 0.85,
            .size = size_pulse,
        };
    }

    return result;
}

/// Alpha of the purple screen overlay shown while the player stands in a portal.
/// Ramps linearly from 0 at `timer=0` to `OVERLAY_MAX_ALPHA` at `timer>=4s`.
pub fn getScreenOverlayAlpha(timer: f32) f32 {
    if (timer <= 0.0) return 0.0;
    if (timer >= OVERLAY_FADE_SECONDS) return OVERLAY_MAX_ALPHA;
    return (timer / OVERLAY_FADE_SECONDS) * OVERLAY_MAX_ALPHA;
}

/// Cycling purple/magenta RGB color for portal shimmer.
///
/// Red and blue oscillate between ~0.4 and ~0.9; green stays low so the color
/// stays in the purple/violet/magenta family. `time` in seconds.
pub fn getPortalColor(time: f32) [3]f32 {
    const phase = (time / COLOR_CYCLE_PERIOD) * std.math.tau;
    // Red peaks toward magenta; blue peaks toward violet; offset phases.
    const r = 0.65 + 0.25 * @sin(phase);
    const b = 0.65 + 0.25 * @sin(phase + std.math.pi * 0.5);
    const g = 0.12 + 0.06 * @sin(phase);
    return .{ clamp01(r), clamp01(g), clamp01(b) };
}

fn clamp01(v: f32) f32 {
    return @max(0.0, @min(1.0, v));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "generatePortalParticles returns 32 particles" {
    const ps = generatePortalParticles(0.0, 0.0, 0.0, 0.0);
    try std.testing.expectEqual(@as(usize, 32), ps.len);
}

test "particles stay within portal frame bounds" {
    const px: f32 = 10.0;
    const py: f32 = 64.0;
    const pz: f32 = -5.0;
    // Sample several times to verify bounds hold through animation.
    var t: f32 = 0.0;
    while (t < 10.0) : (t += 0.37) {
        const ps = generatePortalParticles(px, py, pz, t);
        for (ps) |p| {
            try std.testing.expect(p.x >= px - FRAME_HALF_WIDTH);
            try std.testing.expect(p.x <= px + FRAME_HALF_WIDTH);
            try std.testing.expect(p.y >= py - 0.001);
            try std.testing.expect(p.y <= py + FRAME_HEIGHT + 0.001);
            try std.testing.expect(p.z >= pz - FRAME_DEPTH - 0.001);
            try std.testing.expect(p.z <= pz + FRAME_DEPTH + 0.001);
        }
    }
}

test "particles are purple/magenta: r and b dominate over g" {
    const ps = generatePortalParticles(0.0, 0.0, 0.0, 1.5);
    for (ps) |p| {
        try std.testing.expect(p.r > p.g);
        try std.testing.expect(p.b > p.g);
    }
}

test "particle color channels clamped to [0,1]" {
    var t: f32 = 0.0;
    while (t < 5.0) : (t += 0.21) {
        const ps = generatePortalParticles(0.0, 0.0, 0.0, t);
        for (ps) |p| {
            try std.testing.expect(p.r >= 0.0 and p.r <= 1.0);
            try std.testing.expect(p.g >= 0.0 and p.g <= 1.0);
            try std.testing.expect(p.b >= 0.0 and p.b <= 1.0);
            try std.testing.expect(p.a >= 0.0 and p.a <= 1.0);
            try std.testing.expect(p.size > 0.0);
        }
    }
}

test "particles are deterministic for same inputs" {
    const a = generatePortalParticles(1.0, 2.0, 3.0, 0.75);
    const b = generatePortalParticles(1.0, 2.0, 3.0, 0.75);
    for (0..32) |i| {
        try std.testing.expectApproxEqAbs(a[i].x, b[i].x, 0.0001);
        try std.testing.expectApproxEqAbs(a[i].y, b[i].y, 0.0001);
        try std.testing.expectApproxEqAbs(a[i].z, b[i].z, 0.0001);
        try std.testing.expectApproxEqAbs(a[i].r, b[i].r, 0.0001);
    }
}

test "particles spiral: positions change with time" {
    const a = generatePortalParticles(0.0, 0.0, 0.0, 0.0);
    const b = generatePortalParticles(0.0, 0.0, 0.0, 0.5);
    var any_diff = false;
    for (0..32) |i| {
        if (@abs(a[i].x - b[i].x) > 0.001 or @abs(a[i].y - b[i].y) > 0.001) {
            any_diff = true;
            break;
        }
    }
    try std.testing.expect(any_diff);
}

test "particles translate with portal position" {
    const a = generatePortalParticles(0.0, 0.0, 0.0, 2.0);
    const b = generatePortalParticles(100.0, 200.0, -50.0, 2.0);
    for (0..32) |i| {
        try std.testing.expectApproxEqAbs(a[i].x + 100.0, b[i].x, 0.001);
        try std.testing.expectApproxEqAbs(a[i].y + 200.0, b[i].y, 0.001);
        try std.testing.expectApproxEqAbs(a[i].z - 50.0, b[i].z, 0.001);
    }
}

test "getScreenOverlayAlpha is zero at timer=0" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), getScreenOverlayAlpha(0.0), 0.0001);
}

test "getScreenOverlayAlpha is zero for negative timer" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), getScreenOverlayAlpha(-1.0), 0.0001);
}

test "getScreenOverlayAlpha reaches 0.8 at 4 seconds" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.8), getScreenOverlayAlpha(4.0), 0.0001);
}

test "getScreenOverlayAlpha caps at 0.8 beyond 4 seconds" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.8), getScreenOverlayAlpha(10.0), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.8), getScreenOverlayAlpha(4.1), 0.0001);
}

test "getScreenOverlayAlpha is 0.4 at 2 seconds (linear midpoint)" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.4), getScreenOverlayAlpha(2.0), 0.0001);
}

test "getScreenOverlayAlpha is monotonically non-decreasing" {
    var prev = getScreenOverlayAlpha(0.0);
    var t: f32 = 0.0;
    while (t < 6.0) : (t += 0.1) {
        const cur = getScreenOverlayAlpha(t);
        try std.testing.expect(cur >= prev - 0.0001);
        prev = cur;
    }
}

test "getPortalColor returns purple tones: r and b dominate over g" {
    var t: f32 = 0.0;
    while (t < 10.0) : (t += 0.19) {
        const c = getPortalColor(t);
        try std.testing.expect(c[0] > c[1]);
        try std.testing.expect(c[2] > c[1]);
    }
}

test "getPortalColor values in [0,1]" {
    var t: f32 = -3.0;
    while (t < 10.0) : (t += 0.13) {
        const c = getPortalColor(t);
        try std.testing.expect(c[0] >= 0.0 and c[0] <= 1.0);
        try std.testing.expect(c[1] >= 0.0 and c[1] <= 1.0);
        try std.testing.expect(c[2] >= 0.0 and c[2] <= 1.0);
    }
}

test "getPortalColor cycles: repeats after COLOR_CYCLE_PERIOD" {
    const a = getPortalColor(1.2);
    const b = getPortalColor(1.2 + COLOR_CYCLE_PERIOD);
    try std.testing.expectApproxEqAbs(a[0], b[0], 0.001);
    try std.testing.expectApproxEqAbs(a[1], b[1], 0.001);
    try std.testing.expectApproxEqAbs(a[2], b[2], 0.001);
}

test "getPortalColor changes over time (not constant)" {
    const a = getPortalColor(0.0);
    const b = getPortalColor(COLOR_CYCLE_PERIOD * 0.25);
    const diff = @abs(a[0] - b[0]) + @abs(a[2] - b[2]);
    try std.testing.expect(diff > 0.05);
}
