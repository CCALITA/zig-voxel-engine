const std = @import("std");

/// Visual representation of an experience orb with position, glow, size, and sparkle state.
pub const XpOrbVisual = struct {
    x: f32,
    y: f32,
    z: f32,
    glow: f32,
    size: f32,
    sparkle_timer: f32,
};

/// XP value thresholds for orb tiers.
const small_max: u16 = 10;
const medium_max: u16 = 50;

/// Return the RGB color for an orb based on its XP value.
/// Small (0..10) = green, medium (11..50) = yellow, large (51+) = cyan.
pub fn getOrbColor(xp_value: u16) [3]f32 {
    if (xp_value <= small_max) {
        return .{ 0.3, 0.9, 0.1 };
    } else if (xp_value <= medium_max) {
        return .{ 0.9, 0.9, 0.1 };
    } else {
        return .{ 0.1, 0.9, 0.9 };
    }
}

/// Return the visual size of an orb (0.1 to 0.3) based on its XP value.
/// Linearly interpolated: 0 XP -> 0.1, 100+ XP -> 0.3, clamped.
pub fn getOrbSize(xp_value: u16) f32 {
    const t = @min(@as(f32, @floatFromInt(xp_value)) / 100.0, 1.0);
    return 0.1 + t * 0.2;
}

/// Pulsing glow speed in radians per second.
const glow_pulse_speed: f32 = 4.0;

/// Sparkle cycle duration in seconds.
const sparkle_cycle: f32 = 1.5;

/// Update the orb visual each frame: advance sparkle timer and compute
/// a sinusoidal pulsing glow.
pub fn updateVisual(v: *XpOrbVisual, dt: f32) void {
    v.sparkle_timer += dt;
    if (v.sparkle_timer >= sparkle_cycle) {
        v.sparkle_timer -= sparkle_cycle;
    }
    v.glow = 0.5 + 0.5 * @sin(v.sparkle_timer * glow_pulse_speed);
}

/// Return the current glow intensity, combining the base glow with a
/// sparkle boost when the timer is in the first quarter of its cycle.
pub fn getGlowIntensity(v: XpOrbVisual) f32 {
    const sparkle_boost: f32 = if (v.sparkle_timer < sparkle_cycle * 0.25) 0.3 else 0.0;
    return @min(v.glow + sparkle_boost, 1.0);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "getOrbColor small xp returns green" {
    const c = getOrbColor(5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.3), c[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.9), c[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.1), c[2], 0.001);
}

test "getOrbColor boundary small (10) returns green" {
    const c = getOrbColor(10);
    try std.testing.expectApproxEqAbs(@as(f32, 0.3), c[0], 0.001);
}

test "getOrbColor medium xp returns yellow" {
    const c = getOrbColor(25);
    try std.testing.expectApproxEqAbs(@as(f32, 0.9), c[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.9), c[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.1), c[2], 0.001);
}

test "getOrbColor boundary medium (50) returns yellow" {
    const c = getOrbColor(50);
    try std.testing.expectApproxEqAbs(@as(f32, 0.9), c[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.9), c[1], 0.001);
}

test "getOrbColor large xp returns cyan" {
    const c = getOrbColor(100);
    try std.testing.expectApproxEqAbs(@as(f32, 0.1), c[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.9), c[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.9), c[2], 0.001);
}

test "getOrbColor zero xp returns green" {
    const c = getOrbColor(0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.3), c[0], 0.001);
}

test "getOrbSize zero xp returns minimum" {
    const s = getOrbSize(0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.1), s, 0.001);
}

test "getOrbSize 100 xp returns maximum" {
    const s = getOrbSize(100);
    try std.testing.expectApproxEqAbs(@as(f32, 0.3), s, 0.001);
}

test "getOrbSize clamps above 100" {
    const s = getOrbSize(500);
    try std.testing.expectApproxEqAbs(@as(f32, 0.3), s, 0.001);
}

test "getOrbSize 50 xp returns midpoint" {
    const s = getOrbSize(50);
    try std.testing.expectApproxEqAbs(@as(f32, 0.2), s, 0.001);
}

test "updateVisual advances sparkle timer" {
    var v = XpOrbVisual{ .x = 0, .y = 0, .z = 0, .glow = 0, .size = 0.2, .sparkle_timer = 0 };
    updateVisual(&v, 0.5);
    try std.testing.expect(v.sparkle_timer > 0.0);
}

test "updateVisual wraps sparkle timer" {
    var v = XpOrbVisual{ .x = 0, .y = 0, .z = 0, .glow = 0, .size = 0.2, .sparkle_timer = 1.4 };
    updateVisual(&v, 0.2);
    try std.testing.expect(v.sparkle_timer < sparkle_cycle);
}

test "updateVisual sets glow between 0 and 1" {
    var v = XpOrbVisual{ .x = 1, .y = 2, .z = 3, .glow = 0, .size = 0.15, .sparkle_timer = 0 };
    updateVisual(&v, 0.1);
    try std.testing.expect(v.glow >= 0.0 and v.glow <= 1.0);
}

test "getGlowIntensity includes sparkle boost in first quarter" {
    const v = XpOrbVisual{ .x = 0, .y = 0, .z = 0, .glow = 0.5, .size = 0.2, .sparkle_timer = 0.1 };
    const intensity = getGlowIntensity(v);
    try std.testing.expectApproxEqAbs(@as(f32, 0.8), intensity, 0.001);
}

test "getGlowIntensity no boost after first quarter" {
    const v = XpOrbVisual{ .x = 0, .y = 0, .z = 0, .glow = 0.5, .size = 0.2, .sparkle_timer = 1.0 };
    const intensity = getGlowIntensity(v);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), intensity, 0.001);
}

test "getGlowIntensity clamps to 1.0" {
    const v = XpOrbVisual{ .x = 0, .y = 0, .z = 0, .glow = 0.9, .size = 0.2, .sparkle_timer = 0.1 };
    const intensity = getGlowIntensity(v);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), intensity, 0.001);
}

test "XpOrbVisual struct can be initialized" {
    const v = XpOrbVisual{ .x = 1.0, .y = 2.0, .z = 3.0, .glow = 0.5, .size = 0.2, .sparkle_timer = 0.0 };
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), v.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), v.y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), v.z, 0.001);
}
