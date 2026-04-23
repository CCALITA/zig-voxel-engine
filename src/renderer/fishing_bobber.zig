/// Fishing bobber visual system for rendering the bobber floating on water,
/// the fishing line from the player's hand to the bobber, and the bite-dip
/// animation when a fish is hooked.
const std = @import("std");

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

pub const BobberVisual = struct {
    x: f32,
    y: f32,
    z: f32,
    bob_offset: f32 = 0,
    is_biting: bool = false,
    line_start_x: f32 = 0,
    line_start_y: f32 = 0,
    line_start_z: f32 = 0,
};

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const BOB_FREQUENCY: f32 = 2.0;
const BOB_AMPLITUDE: f32 = 0.06;
const BITE_DIP: f32 = 0.35;

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Advance the bobber by `dt` seconds.
/// The bobber floats at `water_level` with a gentle sine-wave bob.
/// When `is_biting` is true an additional downward dip is applied.
pub fn updateBobber(b: *BobberVisual, dt: f32, water_level: f32) void {
    b.bob_offset += dt * BOB_FREQUENCY;

    // Wrap to avoid precision loss on long sessions.
    const two_pi = std.math.pi * 2.0;
    if (b.bob_offset > two_pi) {
        b.bob_offset -= two_pi;
    }

    const wave = @sin(b.bob_offset) * BOB_AMPLITUDE;
    const dip: f32 = if (b.is_biting) BITE_DIP else 0.0;

    b.y = water_level + wave - dip;
}

/// Return the two endpoints of the fishing line:
///   [0] = player hand (line start)
///   [1] = bobber position (including bob offset on Y)
pub fn getLinePoints(b: BobberVisual) [2][3]f32 {
    return .{
        .{ b.line_start_x, b.line_start_y, b.line_start_z },
        .{ b.x, b.y, b.z },
    };
}

/// Return the vertical distance the bobber has been pulled below the
/// water surface due to a bite. Returns 0 when not biting.
pub fn getDipAmount(b: BobberVisual) f32 {
    if (b.is_biting) return BITE_DIP;
    return 0.0;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "updateBobber sets y near water level" {
    var b = BobberVisual{ .x = 0, .y = 0, .z = 0 };
    updateBobber(&b, 0.0, 64.0);
    // At bob_offset == 0 sin(0) == 0, so y should equal water_level.
    try std.testing.expectApproxEqAbs(@as(f32, 64.0), b.y, 0.001);
}

test "updateBobber advances bob_offset" {
    var b = BobberVisual{ .x = 0, .y = 0, .z = 0 };
    updateBobber(&b, 0.5, 64.0);
    try std.testing.expect(b.bob_offset > 0.0);
}

test "updateBobber bob_offset wraps around two pi" {
    var b = BobberVisual{ .x = 0, .y = 0, .z = 0, .bob_offset = std.math.pi * 2.0 - 0.01 };
    updateBobber(&b, 0.1, 64.0);
    // After adding dt * freq the offset should exceed 2pi and wrap.
    try std.testing.expect(b.bob_offset < std.math.pi * 2.0);
}

test "updateBobber dips when biting" {
    var b_normal = BobberVisual{ .x = 0, .y = 0, .z = 0 };
    var b_biting = BobberVisual{ .x = 0, .y = 0, .z = 0, .is_biting = true };
    updateBobber(&b_normal, 0.0, 64.0);
    updateBobber(&b_biting, 0.0, 64.0);
    try std.testing.expect(b_biting.y < b_normal.y);
}

test "updateBobber produces oscillation over time" {
    var b = BobberVisual{ .x = 5, .y = 0, .z = 3 };
    updateBobber(&b, 0.0, 64.0);
    const y0 = b.y;
    updateBobber(&b, 0.5, 64.0);
    const y1 = b.y;
    // After some time the sine wave should move away from 0-phase.
    try std.testing.expect(y1 != y0);
}

test "getLinePoints returns hand and bobber positions" {
    const b = BobberVisual{
        .x = 10,
        .y = 64,
        .z = 20,
        .line_start_x = 5,
        .line_start_y = 66,
        .line_start_z = 18,
    };
    const pts = getLinePoints(b);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), pts[0][0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 66.0), pts[0][1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 18.0), pts[0][2], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), pts[1][0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 64.0), pts[1][1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 20.0), pts[1][2], 0.001);
}

test "getLinePoints reflects updated bobber position" {
    var b = BobberVisual{
        .x = 1,
        .y = 0,
        .z = 2,
        .line_start_x = 0,
        .line_start_y = 3,
        .line_start_z = 0,
    };
    updateBobber(&b, 0.25, 62.0);
    const pts = getLinePoints(b);
    // Bobber y should be near 62.
    try std.testing.expect(pts[1][1] > 61.0 and pts[1][1] < 63.0);
}

test "getDipAmount returns zero when not biting" {
    const b = BobberVisual{ .x = 0, .y = 64, .z = 0 };
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), getDipAmount(b), 0.001);
}

test "getDipAmount returns dip when biting" {
    const b = BobberVisual{ .x = 0, .y = 64, .z = 0, .is_biting = true };
    try std.testing.expect(getDipAmount(b) > 0.0);
    try std.testing.expectApproxEqAbs(BITE_DIP, getDipAmount(b), 0.001);
}

test "BobberVisual default field values" {
    const b = BobberVisual{ .x = 1, .y = 2, .z = 3 };
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), b.bob_offset, 0.001);
    try std.testing.expect(!b.is_biting);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), b.line_start_x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), b.line_start_y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), b.line_start_z, 0.001);
}

test "updateBobber y stays within amplitude of water level when not biting" {
    var b = BobberVisual{ .x = 0, .y = 0, .z = 0 };
    var i: u32 = 0;
    while (i < 100) : (i += 1) {
        updateBobber(&b, 0.05, 64.0);
        try std.testing.expect(b.y >= 64.0 - BOB_AMPLITUDE - 0.01);
        try std.testing.expect(b.y <= 64.0 + BOB_AMPLITUDE + 0.01);
    }
}

test "bite dip is larger than bob amplitude" {
    // Ensures the bite animation is visually distinct from normal bobbing.
    try std.testing.expect(BITE_DIP > BOB_AMPLITUDE);
}

test "getLinePoints line has nonzero length" {
    const b = BobberVisual{
        .x = 10,
        .y = 64,
        .z = 20,
        .line_start_x = 5,
        .line_start_y = 66,
        .line_start_z = 18,
    };
    const pts = getLinePoints(b);
    const dx = pts[1][0] - pts[0][0];
    const dy = pts[1][1] - pts[0][1];
    const dz = pts[1][2] - pts[0][2];
    const len_sq = dx * dx + dy * dy + dz * dz;
    try std.testing.expect(len_sq > 0.0);
}
