/// Baby zombie variant traits.
///
/// Baby zombies spawn with a 5% probability (1-in-20), move 50% faster than
/// adults, are rendered at half scale, have a shorter hitbox, and are immune
/// to sunlight burning only when the world difficulty is "hard" (matching the
/// vanilla quirk where chicken jockey baby zombies on hard difficulty survive
/// daylight).
const std = @import("std");

/// Returns true when an RNG draw should produce a baby zombie.
/// Uses a 1-in-20 (5%) chance matching vanilla Minecraft behavior.
pub fn shouldSpawnBaby(rng: u32) bool {
    return rng % 20 == 0;
}

/// Movement speed multiplier relative to an adult zombie.
/// Baby zombies move 50% faster than adults.
pub fn getSpeedMultiplier(is_baby: bool) f32 {
    return if (is_baby) 1.5 else 1.0;
}

/// Rendered scale factor. Baby zombies are half the size of adults.
pub fn getScale(is_baby: bool) f32 {
    return if (is_baby) 0.5 else 1.0;
}

/// Hitbox height in blocks. Adult zombies are 1.95 blocks tall; babies are
/// half that (0.975 blocks), enabling them to fit through 1-block gaps.
pub fn getHitboxHeight(is_baby: bool) f32 {
    return if (is_baby) 0.975 else 1.95;
}

/// Whether the zombie will burn when exposed to sunlight.
/// Adults always burn. Babies burn except on "hard" difficulty, where they
/// are immune (matching the vanilla quirk).
pub fn burnInSunlight(is_baby: bool, hard: bool) bool {
    return !(is_baby and hard);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "shouldSpawnBaby: multiples of 20 spawn babies" {
    try std.testing.expect(shouldSpawnBaby(0));
    try std.testing.expect(shouldSpawnBaby(20));
    try std.testing.expect(shouldSpawnBaby(40));
    try std.testing.expect(shouldSpawnBaby(1000));
}

test "shouldSpawnBaby: non-multiples of 20 do not spawn babies" {
    try std.testing.expect(!shouldSpawnBaby(1));
    try std.testing.expect(!shouldSpawnBaby(19));
    try std.testing.expect(!shouldSpawnBaby(21));
    try std.testing.expect(!shouldSpawnBaby(999));
}

test "shouldSpawnBaby: roughly 5% across a large sample" {
    var hits: u32 = 0;
    var i: u32 = 0;
    while (i < 2000) : (i += 1) {
        if (shouldSpawnBaby(i)) hits += 1;
    }
    // 2000 / 20 == 100 exact hits
    try std.testing.expectEqual(@as(u32, 100), hits);
}

test "getSpeedMultiplier: baby is 1.5x, adult is 1.0x" {
    try std.testing.expectEqual(@as(f32, 1.5), getSpeedMultiplier(true));
    try std.testing.expectEqual(@as(f32, 1.0), getSpeedMultiplier(false));
}

test "getSpeedMultiplier: baby is faster than adult" {
    try std.testing.expect(getSpeedMultiplier(true) > getSpeedMultiplier(false));
}

test "getScale: baby is half size of adult" {
    try std.testing.expectEqual(@as(f32, 0.5), getScale(true));
    try std.testing.expectEqual(@as(f32, 1.0), getScale(false));
    try std.testing.expect(getScale(true) < getScale(false));
}

test "getHitboxHeight: baby is 0.975, adult is 1.95" {
    try std.testing.expectEqual(@as(f32, 0.975), getHitboxHeight(true));
    try std.testing.expectEqual(@as(f32, 1.95), getHitboxHeight(false));
}

test "getHitboxHeight: baby height is half of adult" {
    const baby = getHitboxHeight(true);
    const adult = getHitboxHeight(false);
    try std.testing.expectApproxEqAbs(adult / 2.0, baby, 0.0001);
}

test "burnInSunlight: adult burns regardless of difficulty" {
    try std.testing.expect(burnInSunlight(false, false));
    try std.testing.expect(burnInSunlight(false, true));
}

test "burnInSunlight: baby burns on non-hard difficulty" {
    try std.testing.expect(burnInSunlight(true, false));
}

test "burnInSunlight: baby is immune on hard difficulty" {
    try std.testing.expect(!burnInSunlight(true, true));
}

test "burnInSunlight: only baby+hard combination is immune" {
    // Truth table coverage
    try std.testing.expect(burnInSunlight(false, false));
    try std.testing.expect(burnInSunlight(false, true));
    try std.testing.expect(burnInSunlight(true, false));
    try std.testing.expect(!burnInSunlight(true, true));
}

test "scale and hitbox are internally consistent for baby" {
    // Baby scale is 0.5 and baby hitbox is half of adult hitbox.
    try std.testing.expectApproxEqAbs(
        getScale(true),
        getHitboxHeight(true) / getHitboxHeight(false),
        0.0001,
    );
}
