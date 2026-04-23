const std = @import("std");

const sprint_modifier: f32 = 0.10;
const fly_modifier: f32 = 0.10;
const speed_per_level: f32 = 0.10;
const slowness_per_level: f32 = 0.10;
const bow_aim_modifier: f32 = 0.30;

const min_fov: f32 = 30.0;
const max_fov: f32 = 130.0;

const transition_rate: f32 = 5.0;

/// Compute the adjusted FOV given a base value and active gameplay modifiers.
///
/// Modifiers are applied multiplicatively to the base FOV:
///   - Sprint: +10%
///   - Fly: +10%
///   - Speed effect: +10% per level
///   - Slowness effect: -10% per level
///   - Bow aiming: -30%
///
/// The result is clamped to [30, 130].
pub fn getAdjustedFOV(
    base_fov: f32,
    is_sprinting: bool,
    is_flying: bool,
    speed_effect_level: u8,
    slowness_level: u8,
    is_aiming_bow: bool,
) f32 {
    var multiplier: f32 = 1.0;

    if (is_sprinting) {
        multiplier += sprint_modifier;
    }
    if (is_flying) {
        multiplier += fly_modifier;
    }

    multiplier += speed_per_level * @as(f32, @floatFromInt(speed_effect_level));
    multiplier -= slowness_per_level * @as(f32, @floatFromInt(slowness_level));

    if (is_aiming_bow) {
        multiplier -= bow_aim_modifier;
    }

    return std.math.clamp(base_fov * multiplier, min_fov, max_fov);
}

/// Smoothly interpolate the current FOV toward a target at a fixed rate.
///
/// Uses linear interpolation with `transition_rate` (5.0) scaled by `dt`.
/// The blending factor is clamped to [0, 1] so overshooting is impossible.
pub fn getFOVTransition(current: f32, target: f32, dt: f32) f32 {
    const alpha = std.math.clamp(transition_rate * dt, 0.0, 1.0);
    return current + (target - current) * alpha;
}

test "base FOV unchanged with no modifiers" {
    const result = getAdjustedFOV(70.0, false, false, 0, 0, false);
    try std.testing.expectApproxEqAbs(70.0, result, 0.001);
}

test "sprinting adds 10%" {
    const result = getAdjustedFOV(70.0, true, false, 0, 0, false);
    try std.testing.expectApproxEqAbs(77.0, result, 0.001);
}

test "flying adds 10%" {
    const result = getAdjustedFOV(70.0, false, true, 0, 0, false);
    try std.testing.expectApproxEqAbs(77.0, result, 0.001);
}

test "sprint and fly stack to +20%" {
    const result = getAdjustedFOV(70.0, true, true, 0, 0, false);
    try std.testing.expectApproxEqAbs(84.0, result, 0.001);
}

test "speed effect level 2 adds 20%" {
    const result = getAdjustedFOV(70.0, false, false, 2, 0, false);
    try std.testing.expectApproxEqAbs(84.0, result, 0.001);
}

test "slowness level 1 subtracts 10%" {
    const result = getAdjustedFOV(70.0, false, false, 0, 1, false);
    try std.testing.expectApproxEqAbs(63.0, result, 0.001);
}

test "bow aiming subtracts 30%" {
    const result = getAdjustedFOV(70.0, false, false, 0, 0, true);
    try std.testing.expectApproxEqAbs(49.0, result, 0.001);
}

test "clamp to minimum 30" {
    // slowness 10 => multiplier = 1.0 - 1.0 = 0.0 => 0.0, clamped to 30
    const result = getAdjustedFOV(70.0, false, false, 0, 10, false);
    try std.testing.expectApproxEqAbs(30.0, result, 0.001);
}

test "clamp to maximum 130" {
    // speed 5 => multiplier = 1.0 + 0.5 = 1.5 => 105 with base 90 = 135, clamped to 130
    const result = getAdjustedFOV(90.0, true, true, 5, 0, false);
    try std.testing.expectApproxEqAbs(130.0, result, 0.001);
}

test "all modifiers combined" {
    // sprint +0.10, fly +0.10, speed 1 +0.10, slowness 1 -0.10, bow -0.30
    // multiplier = 1.0 + 0.10 + 0.10 + 0.10 - 0.10 - 0.30 = 0.90
    // 70 * 0.90 = 63.0
    const result = getAdjustedFOV(70.0, true, true, 1, 1, true);
    try std.testing.expectApproxEqAbs(63.0, result, 0.001);
}

test "transition moves toward target" {
    const result = getFOVTransition(70.0, 80.0, 0.1);
    // alpha = 5.0 * 0.1 = 0.5 => 70 + 10 * 0.5 = 75
    try std.testing.expectApproxEqAbs(75.0, result, 0.001);
}

test "transition reaches target at alpha 1" {
    const result = getFOVTransition(70.0, 80.0, 1.0);
    // alpha = 5.0 * 1.0 = 5.0, clamped to 1.0 => 70 + 10 * 1.0 = 80
    try std.testing.expectApproxEqAbs(80.0, result, 0.001);
}

test "transition with zero dt stays at current" {
    const result = getFOVTransition(70.0, 80.0, 0.0);
    try std.testing.expectApproxEqAbs(70.0, result, 0.001);
}

test "transition moves downward" {
    const result = getFOVTransition(80.0, 60.0, 0.1);
    // alpha = 0.5 => 80 + (-20) * 0.5 = 70
    try std.testing.expectApproxEqAbs(70.0, result, 0.001);
}

test "transition already at target returns target" {
    const result = getFOVTransition(70.0, 70.0, 0.2);
    try std.testing.expectApproxEqAbs(70.0, result, 0.001);
}
