const std = @import("std");

/// Duration of a hit flash effect in seconds.
const flash_duration: f32 = 0.3;

/// A visual hit-flash attached to an entity, tracking the red tint over time.
pub const HitFlash = struct {
    entity_id: u32,
    timer: f32,
    r: f32,
    g: f32,
    b: f32,
};

/// Create a new red hit flash for the given entity, lasting 0.3 seconds.
pub fn triggerHit(entity_id: u32) HitFlash {
    return .{
        .entity_id = entity_id,
        .timer = flash_duration,
        .r = 1.0,
        .g = 0.0,
        .b = 0.0,
    };
}

/// Advance the flash timer by `dt` seconds. Returns true while the effect is
/// still active, false when the timer has expired.
pub fn updateHit(flash: *HitFlash, dt: f32) bool {
    flash.timer -= dt;
    if (flash.timer <= 0.0) {
        flash.timer = 0.0;
        return false;
    }
    return true;
}

/// Return an RGBA tint colour that fades from full red to transparent over the
/// flash duration.
pub fn getHitTint(flash: HitFlash) [4]f32 {
    const t = std.math.clamp(flash.timer / flash_duration, 0.0, 1.0);
    return .{ flash.r * t, flash.g * t, flash.b * t, t };
}

/// Return the angle (in radians) of a directional damage indicator given the
/// displacement from the hit source to the entity.
pub fn getKnockbackIndicator(dx: f32, dz: f32) f32 {
    return std.math.atan2(dz, dx);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "triggerHit sets correct entity_id" {
    const flash = triggerHit(42);
    try std.testing.expectEqual(@as(u32, 42), flash.entity_id);
}

test "triggerHit sets timer to 0.3 seconds" {
    const flash = triggerHit(1);
    try std.testing.expectApproxEqAbs(@as(f32, 0.3), flash.timer, 0.001);
}

test "triggerHit colour is red" {
    const flash = triggerHit(1);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), flash.r, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), flash.g, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), flash.b, 0.001);
}

test "updateHit decreases timer" {
    var flash = triggerHit(1);
    _ = updateHit(&flash, 0.1);
    try std.testing.expectApproxEqAbs(@as(f32, 0.2), flash.timer, 0.001);
}

test "updateHit returns true while active" {
    var flash = triggerHit(1);
    try std.testing.expect(updateHit(&flash, 0.1));
    try std.testing.expect(updateHit(&flash, 0.1));
}

test "updateHit returns false when expired" {
    var flash = triggerHit(1);
    const active = updateHit(&flash, 0.5);
    try std.testing.expect(!active);
}

test "updateHit clamps timer to zero" {
    var flash = triggerHit(1);
    _ = updateHit(&flash, 1.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), flash.timer, 0.001);
}

test "getHitTint full intensity at start" {
    const flash = triggerHit(1);
    const tint = getHitTint(flash);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), tint[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), tint[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), tint[2], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), tint[3], 0.001);
}

test "getHitTint fades to zero when timer expires" {
    var flash = triggerHit(1);
    _ = updateHit(&flash, 0.5);
    const tint = getHitTint(flash);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), tint[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), tint[3], 0.001);
}

test "getHitTint at half-life has half intensity" {
    var flash = triggerHit(1);
    _ = updateHit(&flash, 0.15);
    const tint = getHitTint(flash);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), tint[0], 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), tint[3], 0.01);
}

test "getKnockbackIndicator returns correct angle for cardinal directions" {
    // Positive X axis: 0 radians
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), getKnockbackIndicator(1.0, 0.0), 0.001);
    // Positive Z axis: pi/2
    try std.testing.expectApproxEqAbs(std.math.pi / 2.0, getKnockbackIndicator(0.0, 1.0), 0.001);
    // Negative X axis: pi
    try std.testing.expectApproxEqAbs(std.math.pi, getKnockbackIndicator(-1.0, 0.0), 0.001);
    // Negative Z axis: -pi/2
    try std.testing.expectApproxEqAbs(-std.math.pi / 2.0, getKnockbackIndicator(0.0, -1.0), 0.001);
}

test "getKnockbackIndicator diagonal returns pi/4" {
    const angle = getKnockbackIndicator(1.0, 1.0);
    try std.testing.expectApproxEqAbs(std.math.pi / 4.0, angle, 0.001);
}

test "triggerHit different entity ids are independent" {
    const a = triggerHit(10);
    const b = triggerHit(20);
    try std.testing.expectEqual(@as(u32, 10), a.entity_id);
    try std.testing.expectEqual(@as(u32, 20), b.entity_id);
    try std.testing.expectApproxEqAbs(a.timer, b.timer, 0.001);
}
