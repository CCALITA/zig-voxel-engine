/// Baby zombie variant data and helpers.
/// Baby zombies are faster, smaller, and (in Hard difficulty) immune to sunlight burning.
const std = @import("std");

pub const BabyZombie = struct {
    is_baby: bool = false,
    speed_multiplier: f32 = 1.5,
    scale: f32 = 0.5,
    burns_in_sun: bool = true,
};

/// Returns true with a 5% chance based on the supplied RNG value.
pub fn shouldSpawnBaby(rng: u32) bool {
    return (rng % 100) < 5;
}

/// Speed multiplier: babies move 1.5x adult speed.
pub fn getSpeedMultiplier(is_baby: bool) f32 {
    return if (is_baby) 1.5 else 1.0;
}

/// Scale: babies are half-sized.
pub fn getScale(is_baby: bool) f32 {
    return if (is_baby) 0.5 else 1.0;
}

/// Hitbox height in blocks. Adult is 1.95, baby is half (0.975).
pub fn getHitboxHeight(is_baby: bool) f32 {
    return if (is_baby) 0.975 else 1.95;
}

/// Returns true if the zombie should burn in sunlight.
/// Baby zombies are immune to sun burn on Hard difficulty.
pub fn burnInSunlight(is_baby: bool, difficulty_hard: bool) bool {
    if (is_baby and difficulty_hard) return false;
    return true;
}

test "shouldSpawnBaby returns true for 0..4" {
    try std.testing.expect(shouldSpawnBaby(0));
    try std.testing.expect(shouldSpawnBaby(4));
}

test "shouldSpawnBaby returns false for 5..99" {
    try std.testing.expect(!shouldSpawnBaby(5));
    try std.testing.expect(!shouldSpawnBaby(50));
    try std.testing.expect(!shouldSpawnBaby(99));
}

test "shouldSpawnBaby wraps over 100 correctly" {
    try std.testing.expect(shouldSpawnBaby(104));
    try std.testing.expect(!shouldSpawnBaby(105));
}

test "shouldSpawnBaby roughly 5% over a large sample" {
    var hits: u32 = 0;
    var i: u32 = 0;
    while (i < 10000) : (i += 1) {
        if (shouldSpawnBaby(i)) hits += 1;
    }
    try std.testing.expectEqual(@as(u32, 500), hits);
}

test "getSpeedMultiplier baby is 1.5" {
    try std.testing.expectEqual(@as(f32, 1.5), getSpeedMultiplier(true));
}

test "getSpeedMultiplier adult is 1.0" {
    try std.testing.expectEqual(@as(f32, 1.0), getSpeedMultiplier(false));
}

test "getScale baby is 0.5" {
    try std.testing.expectEqual(@as(f32, 0.5), getScale(true));
}

test "getScale adult is 1.0" {
    try std.testing.expectEqual(@as(f32, 1.0), getScale(false));
}

test "getHitboxHeight values" {
    try std.testing.expectEqual(@as(f32, 0.975), getHitboxHeight(true));
    try std.testing.expectEqual(@as(f32, 1.95), getHitboxHeight(false));
}

test "getHitboxHeight baby is exactly half of adult" {
    try std.testing.expectApproxEqAbs(
        getHitboxHeight(false) / 2.0,
        getHitboxHeight(true),
        0.0001,
    );
}

test "burnInSunlight baby on hard does NOT burn" {
    try std.testing.expect(!burnInSunlight(true, true));
}

test "burnInSunlight baby on non-hard burns" {
    try std.testing.expect(burnInSunlight(true, false));
}

test "burnInSunlight adult always burns" {
    try std.testing.expect(burnInSunlight(false, true));
    try std.testing.expect(burnInSunlight(false, false));
}

test "BabyZombie default field values" {
    const bz = BabyZombie{};
    try std.testing.expectEqual(false, bz.is_baby);
    try std.testing.expectEqual(@as(f32, 1.5), bz.speed_multiplier);
    try std.testing.expectEqual(@as(f32, 0.5), bz.scale);
    try std.testing.expectEqual(true, bz.burns_in_sun);
}

test "BabyZombie can be configured as baby instance" {
    const bz = BabyZombie{ .is_baby = true, .burns_in_sun = false };
    try std.testing.expect(bz.is_baby);
    try std.testing.expect(!bz.burns_in_sun);
}
