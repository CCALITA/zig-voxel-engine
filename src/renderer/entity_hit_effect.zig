/// Entity hit visual effects: red damage flash tint and knockback direction.
/// The flash fades from strong red overlay to transparent over a short duration,
/// and `getKnockbackAngle` gives the XZ-plane angle from attacker to target.
const std = @import("std");

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

/// Tracks a per-entity red flash that fades out over `duration` seconds.
pub const HitFlash = struct {
    entity_id: u32 = 0,
    timer: f32 = 0,
    duration: f32 = 0.3,
    active: bool = false,
};

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const DEFAULT_DURATION: f32 = 0.3;
const RED_INTENSITY: f32 = 0.7;
const ALPHA_INTENSITY: f32 = 0.6;

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Create an active hit flash for the given entity.
pub fn triggerHit(entity_id: u32) HitFlash {
    return .{
        .entity_id = entity_id,
        .timer = DEFAULT_DURATION,
        .duration = DEFAULT_DURATION,
        .active = true,
    };
}

/// Tick the flash timer forward by `dt` seconds.
/// Returns `true` while the flash is still visible.
pub fn updateHit(flash: *HitFlash, dt: f32) bool {
    if (!flash.active) return false;
    flash.timer -= dt;
    if (flash.timer <= 0) {
        flash.active = false;
        flash.timer = 0;
        return false;
    }
    return true;
}

/// Compute the RGBA tint to multiply onto the entity's texture.
/// When inactive the tint is neutral white with zero alpha overlay.
/// When active the tint shifts toward red and fades out over the duration.
pub fn getHitTint(flash: HitFlash) [4]f32 {
    if (!flash.active) return .{ 1, 1, 1, 0 };
    const t = flash.timer / flash.duration;
    const gb = 1 - t * RED_INTENSITY;
    return .{ 1, gb, gb, t * ALPHA_INTENSITY };
}

/// Return the XZ-plane angle (radians) from the hit source toward the target.
/// `dx` and `dz` are (target.x - source.x) and (target.z - source.z).
pub fn getKnockbackAngle(dx: f32, dz: f32) f32 {
    return std.math.atan2(dz, dx);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "triggerHit returns active flash with correct entity id" {
    const flash = triggerHit(42);
    try std.testing.expect(flash.active);
    try std.testing.expectEqual(@as(u32, 42), flash.entity_id);
    try std.testing.expectApproxEqAbs(DEFAULT_DURATION, flash.timer, 0.0001);
    try std.testing.expectApproxEqAbs(DEFAULT_DURATION, flash.duration, 0.0001);
}

test "updateHit returns false for inactive flash" {
    var flash = HitFlash{};
    const result = updateHit(&flash, 0.016);
    try std.testing.expect(!result);
}

test "updateHit decrements timer while active" {
    var flash = triggerHit(1);
    const alive = updateHit(&flash, 0.1);
    try std.testing.expect(alive);
    try std.testing.expectApproxEqAbs(@as(f32, 0.2), flash.timer, 0.0001);
}

test "updateHit deactivates when timer expires" {
    var flash = triggerHit(1);
    const alive = updateHit(&flash, 0.5);
    try std.testing.expect(!alive);
    try std.testing.expect(!flash.active);
    try std.testing.expectApproxEqAbs(@as(f32, 0), flash.timer, 0.0001);
}

test "getHitTint returns neutral white when inactive" {
    const flash = HitFlash{};
    const tint = getHitTint(flash);
    try std.testing.expectApproxEqAbs(@as(f32, 1), tint[0], 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 1), tint[1], 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 1), tint[2], 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), tint[3], 0.0001);
}

test "getHitTint returns red-shifted tint at start" {
    const flash = triggerHit(1);
    const tint = getHitTint(flash);
    // At t=1.0 (timer == duration): r=1, g=1-0.7=0.3, b=0.3, a=0.6
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), tint[0], 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.3), tint[1], 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.3), tint[2], 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.6), tint[3], 0.0001);
}

test "getHitTint fades toward neutral over time" {
    var flash = triggerHit(1);
    _ = updateHit(&flash, 0.15);
    const tint = getHitTint(flash);
    // Halfway: t = 0.15/0.3 = 0.5 => g = 1-0.5*0.7 = 0.65, a = 0.5*0.6 = 0.3
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), tint[0], 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.65), tint[1], 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.65), tint[2], 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.3), tint[3], 0.0001);
}

test "getKnockbackAngle returns zero for positive x direction" {
    const angle = getKnockbackAngle(1.0, 0.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), angle, 0.0001);
}

test "getKnockbackAngle returns pi/2 for positive z direction" {
    const angle = getKnockbackAngle(0.0, 1.0);
    try std.testing.expectApproxEqAbs(std.math.pi / 2.0, angle, 0.0001);
}

test "getKnockbackAngle returns negative pi/2 for negative z" {
    const angle = getKnockbackAngle(0.0, -1.0);
    try std.testing.expectApproxEqAbs(-std.math.pi / 2.0, angle, 0.0001);
}

test "getKnockbackAngle handles diagonal knockback" {
    const angle = getKnockbackAngle(1.0, 1.0);
    try std.testing.expectApproxEqAbs(std.math.pi / 4.0, angle, 0.0001);
}

test "getKnockbackAngle handles negative diagonal" {
    const angle = getKnockbackAngle(-1.0, -1.0);
    // atan2(-1, -1) = -3*pi/4
    try std.testing.expectApproxEqAbs(-3.0 * std.math.pi / 4.0, angle, 0.0001);
}

test "HitFlash default values" {
    const flash = HitFlash{};
    try std.testing.expectEqual(@as(u32, 0), flash.entity_id);
    try std.testing.expectApproxEqAbs(@as(f32, 0), flash.timer, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.3), flash.duration, 0.0001);
    try std.testing.expect(!flash.active);
}

test "multiple updateHit calls drain timer correctly" {
    var flash = triggerHit(7);
    _ = updateHit(&flash, 0.1);
    _ = updateHit(&flash, 0.1);
    try std.testing.expect(flash.active);
    try std.testing.expectApproxEqAbs(@as(f32, 0.1), flash.timer, 0.0001);
    const final = updateHit(&flash, 0.1);
    try std.testing.expect(!final);
    try std.testing.expect(!flash.active);
}
