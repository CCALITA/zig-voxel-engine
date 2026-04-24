const std = @import("std");

/// Returns the RGB color for redstone wire at a given signal strength.
///
/// Signal 0 produces dark red (0.3, 0, 0) and signal 15 produces bright
/// red (1.0, 0, 0). Intermediate values are linearly interpolated.
pub fn getWireColor(signal: u4) [3]f32 {
    const t: f32 = @as(f32, @floatFromInt(signal)) / 15.0;
    return .{ 0.3 + 0.7 * t, 0.0, 0.0 };
}

/// Returns the RGB glow color for a redstone torch.
///
/// A powered (lit) torch glows bright orange-red (1.0, 0.3, 0.1).
/// An unpowered (off) torch has a dim residual glow (0.2, 0.05, 0.02).
pub fn getTorchGlow(is_powered: bool) [3]f32 {
    return if (is_powered)
        .{ 1.0, 0.3, 0.1 }
    else
        .{ 0.2, 0.05, 0.02 };
}

/// Returns the RGB indicator color for a redstone repeater.
///
/// The delay parameter (0..3) maps to tick counts 1..4 and shifts the
/// hue from red toward orange. When locked, the color is overridden to
/// a dark bedrock-gray to indicate the repeater cannot change state.
pub fn getRepeaterIndicator(delay: u2, is_locked: bool) [3]f32 {
    if (is_locked) {
        return .{ 0.3, 0.3, 0.3 };
    }
    const t: f32 = @as(f32, @floatFromInt(delay)) / 3.0;
    return .{ 1.0, 0.2 * t, 0.0 };
}

/// Returns the brightness multiplier for a redstone lamp.
///
/// A lit lamp returns 1.0 (full brightness) and an unlit lamp returns 0.0.
pub fn getLampBrightness(is_lit: bool) f32 {
    return if (is_lit) 1.0 else 0.0;
}

/// Returns a mode indicator byte for a redstone comparator.
///
/// Compare mode returns 0, subtract mode returns 1.
pub fn getComparatorMode(is_subtract: bool) u8 {
    return if (is_subtract) 1 else 0;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "getWireColor signal 0 is dark red" {
    const c = getWireColor(0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.3), c[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), c[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), c[2], 0.001);
}

test "getWireColor signal 15 is bright red" {
    const c = getWireColor(15);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), c[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), c[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), c[2], 0.001);
}

test "getWireColor interpolates linearly at midpoint" {
    const c = getWireColor(7);
    const expected_r: f32 = 0.3 + 0.7 * (7.0 / 15.0);
    try std.testing.expectApproxEqAbs(expected_r, c[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), c[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), c[2], 0.001);
}

test "getWireColor all values in valid range" {
    for (0..16) |i| {
        const signal: u4 = @intCast(i);
        const c = getWireColor(signal);
        try std.testing.expect(c[0] >= 0.3 and c[0] <= 1.0);
        try std.testing.expectApproxEqAbs(@as(f32, 0.0), c[1], 0.001);
        try std.testing.expectApproxEqAbs(@as(f32, 0.0), c[2], 0.001);
    }
}

test "getWireColor monotonically increases red with signal" {
    var prev_r: f32 = 0.0;
    for (0..16) |i| {
        const signal: u4 = @intCast(i);
        const c = getWireColor(signal);
        try std.testing.expect(c[0] >= prev_r);
        prev_r = c[0];
    }
}

test "getTorchGlow powered is bright orange-red" {
    const c = getTorchGlow(true);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), c[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.3), c[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.1), c[2], 0.001);
}

test "getTorchGlow unpowered is dim" {
    const c = getTorchGlow(false);
    try std.testing.expectApproxEqAbs(@as(f32, 0.2), c[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.05), c[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.02), c[2], 0.001);
}

test "getRepeaterIndicator unlocked delay 0 is red" {
    const c = getRepeaterIndicator(0, false);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), c[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), c[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), c[2], 0.001);
}

test "getRepeaterIndicator unlocked delay 3 shifts toward orange" {
    const c = getRepeaterIndicator(3, false);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), c[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.2), c[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), c[2], 0.001);
}

test "getRepeaterIndicator locked returns gray regardless of delay" {
    const c0 = getRepeaterIndicator(0, true);
    const c3 = getRepeaterIndicator(3, true);
    try std.testing.expectApproxEqAbs(@as(f32, 0.3), c0[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.3), c0[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.3), c0[2], 0.001);
    try std.testing.expectApproxEqAbs(c0[0], c3[0], 0.001);
    try std.testing.expectApproxEqAbs(c0[1], c3[1], 0.001);
    try std.testing.expectApproxEqAbs(c0[2], c3[2], 0.001);
}

test "getLampBrightness lit is 1.0" {
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), getLampBrightness(true), 0.001);
}

test "getLampBrightness unlit is 0.0" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), getLampBrightness(false), 0.001);
}

test "getComparatorMode subtract returns 1" {
    try std.testing.expectEqual(@as(u8, 1), getComparatorMode(true));
}

test "getComparatorMode compare returns 0" {
    try std.testing.expectEqual(@as(u8, 0), getComparatorMode(false));
}
