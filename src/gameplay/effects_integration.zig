/// Effects integration — bridges status_effect_manager with gameplay systems.
/// Provides high-level queries (speed multiplier, damage bonus, boolean flags)
/// so that gameplay code does not need to know individual EffectType values.

const std = @import("std");
const sem = @import("status_effect_manager.zig");

// ──────────────────────────────────────────────────────────────────────────────
// Constants
// ──────────────────────────────────────────────────────────────────────────────

const speed_mult_per_level: f32 = 1.2;
const slowness_mult_per_level: f32 = 0.85;
const strength_bonus_per_level: f32 = 3.0;

// ──────────────────────────────────────────────────────────────────────────────
// Public API
// ──────────────────────────────────────────────────────────────────────────────

/// Returns the combined speed multiplier.
/// Speed effect multiplies by 1.2 per level, slowness by 0.85 per level.
/// When both are active the results are multiplied together.
/// The result is clamped so it never goes below 0.
pub fn getSpeedMultiplier(mgr: *const sem.EffectManager) f32 {
    var mult: f32 = 1.0;

    const speed_level = mgr.getLevel(.speed);
    if (speed_level > 0) {
        mult *= std.math.pow(f32, speed_mult_per_level, @floatFromInt(speed_level));
    }

    const slow_level = mgr.getLevel(.slowness);
    if (slow_level > 0) {
        mult *= std.math.pow(f32, slowness_mult_per_level, @floatFromInt(slow_level));
    }

    return @max(mult, 0.0);
}

/// Returns the flat damage bonus from strength.
/// Each level adds +3 damage.
pub fn getDamageBonus(mgr: *const sem.EffectManager) f32 {
    const level = mgr.getLevel(.strength);
    const lvl: f32 = @floatFromInt(level);
    return strength_bonus_per_level * lvl;
}

/// True when the entity has active fire resistance.
pub fn hasFireResistance(mgr: *const sem.EffectManager) bool {
    return mgr.hasEffect(.fire_resistance);
}

/// True when the entity has active water breathing.
pub fn hasWaterBreathing(mgr: *const sem.EffectManager) bool {
    return mgr.hasEffect(.water_breathing);
}

/// True when the entity is invisible.
pub fn isInvisible(mgr: *const sem.EffectManager) bool {
    return mgr.hasEffect(.invisibility);
}

/// True when the entity has night vision.
pub fn hasNightVision(mgr: *const sem.EffectManager) bool {
    return mgr.hasEffect(.night_vision);
}

// ──────────────────────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────────────────────

test "getSpeedMultiplier returns 1.0 with no effects" {
    const mgr = sem.EffectManager{};
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), getSpeedMultiplier(&mgr), 0.001);
}

test "getSpeedMultiplier with speed level 1" {
    var mgr = sem.EffectManager{};
    mgr.addEffect(.speed, 1, 60.0);
    // 1.2^1 = 1.2
    try std.testing.expectApproxEqAbs(@as(f32, 1.2), getSpeedMultiplier(&mgr), 0.001);
}

test "getSpeedMultiplier with speed level 2" {
    var mgr = sem.EffectManager{};
    mgr.addEffect(.speed, 2, 60.0);
    // 1.2^2 = 1.44
    try std.testing.expectApproxEqAbs(@as(f32, 1.44), getSpeedMultiplier(&mgr), 0.001);
}

test "getSpeedMultiplier with slowness level 1" {
    var mgr = sem.EffectManager{};
    mgr.addEffect(.slowness, 1, 60.0);
    // 0.85^1 = 0.85
    try std.testing.expectApproxEqAbs(@as(f32, 0.85), getSpeedMultiplier(&mgr), 0.001);
}

test "getSpeedMultiplier with slowness level 2" {
    var mgr = sem.EffectManager{};
    mgr.addEffect(.slowness, 2, 60.0);
    // 0.85^2 = 0.7225
    try std.testing.expectApproxEqAbs(@as(f32, 0.7225), getSpeedMultiplier(&mgr), 0.001);
}

test "getSpeedMultiplier with both speed and slowness" {
    var mgr = sem.EffectManager{};
    mgr.addEffect(.speed, 1, 60.0);
    mgr.addEffect(.slowness, 1, 60.0);
    // 1.2 * 0.85 = 1.02
    try std.testing.expectApproxEqAbs(@as(f32, 1.02), getSpeedMultiplier(&mgr), 0.001);
}

test "getSpeedMultiplier clamps to zero" {
    var mgr = sem.EffectManager{};
    // slowness level 100 pushes the multiplier extremely close to 0
    mgr.addEffect(.slowness, 100, 60.0);
    const result = getSpeedMultiplier(&mgr);
    try std.testing.expect(result >= 0.0);
}

test "getDamageBonus returns 0 with no strength" {
    const mgr = sem.EffectManager{};
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), getDamageBonus(&mgr), 0.001);
}

test "getDamageBonus returns 3 per level" {
    var mgr = sem.EffectManager{};
    mgr.addEffect(.strength, 2, 60.0);
    try std.testing.expectApproxEqAbs(@as(f32, 6.0), getDamageBonus(&mgr), 0.001);
}

test "hasFireResistance returns false when absent" {
    const mgr = sem.EffectManager{};
    try std.testing.expect(!hasFireResistance(&mgr));
}

test "hasFireResistance returns true when active" {
    var mgr = sem.EffectManager{};
    mgr.addEffect(.fire_resistance, 1, 30.0);
    try std.testing.expect(hasFireResistance(&mgr));
}

test "hasWaterBreathing returns false when absent" {
    const mgr = sem.EffectManager{};
    try std.testing.expect(!hasWaterBreathing(&mgr));
}

test "hasWaterBreathing returns true when active" {
    var mgr = sem.EffectManager{};
    mgr.addEffect(.water_breathing, 1, 30.0);
    try std.testing.expect(hasWaterBreathing(&mgr));
}

test "isInvisible returns false when absent" {
    const mgr = sem.EffectManager{};
    try std.testing.expect(!isInvisible(&mgr));
}

test "isInvisible returns true when active" {
    var mgr = sem.EffectManager{};
    mgr.addEffect(.invisibility, 1, 60.0);
    try std.testing.expect(isInvisible(&mgr));
}

test "hasNightVision returns false when absent" {
    const mgr = sem.EffectManager{};
    try std.testing.expect(!hasNightVision(&mgr));
}

test "hasNightVision returns true when active" {
    var mgr = sem.EffectManager{};
    mgr.addEffect(.night_vision, 1, 60.0);
    try std.testing.expect(hasNightVision(&mgr));
}

test "effects disappear after expiry" {
    var mgr = sem.EffectManager{};
    mgr.addEffect(.speed, 1, 1.0);
    mgr.addEffect(.strength, 2, 1.0);
    mgr.addEffect(.fire_resistance, 1, 1.0);
    mgr.addEffect(.invisibility, 1, 1.0);

    // Expire all effects.
    _ = mgr.update(2.0);

    try std.testing.expectApproxEqAbs(@as(f32, 1.0), getSpeedMultiplier(&mgr), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), getDamageBonus(&mgr), 0.001);
    try std.testing.expect(!hasFireResistance(&mgr));
    try std.testing.expect(!isInvisible(&mgr));
}
