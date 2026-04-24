/// Anvil repair utilities for item-combining repair operations.
/// Handles durability merging with a 12% bonus, XP cost calculation,
/// item compatibility checks, and anvil degradation. Only depends on `std`.

const std = @import("std");

/// Maximum XP level cost the anvil will accept.
pub const ANVIL_MAX_COST: u8 = 39;

/// Repair bonus multiplier numerator (112 / 100 = 1.12x).
const REPAIR_BONUS_NUM: u32 = 112;
const REPAIR_BONUS_DEN: u32 = 100;

/// Base XP cost for a repair operation.
const BASE_XP_COST: u8 = 4;

/// Additional XP cost when the item carries enchantments.
const ENCHANT_XP_SURCHARGE: u8 = 2;

/// Anvil damage probability threshold out of 100 (12%).
const ANVIL_DAMAGE_THRESHOLD: u32 = 12;

/// Returns true when two items are the same type and can be combined on an anvil.
pub fn canRepair(item_a: u16, item_b: u16) bool {
    return item_a == item_b;
}

/// Calculates the resulting durability when combining two items.
/// Formula: min((dur_a + dur_b) * 1.12, max_dur).
/// All arithmetic stays in u32 to avoid overflow, then is clamped back to u16.
pub fn calculateRepair(dur_a: u16, dur_b: u16, max_dur: u16) u16 {
    const sum: u32 = @as(u32, dur_a) + @as(u32, dur_b);
    const boosted: u32 = (sum * REPAIR_BONUS_NUM) / REPAIR_BONUS_DEN;
    const capped: u32 = @min(boosted, @as(u32, max_dur));
    return @intCast(capped);
}

/// Returns the XP level cost for a repair operation.
/// Base cost is 4; add 2 if the item has enchantments.
pub fn getXPCost(item_id: u16, has_enchants: bool) u8 {
    _ = item_id;
    return if (has_enchants) BASE_XP_COST + ENCHANT_XP_SURCHARGE else BASE_XP_COST;
}

/// Determines whether the anvil should take damage after this use.
/// Returns true with a 12% probability, derived from `rng % 100 < 12`.
pub fn shouldDamageAnvil(rng: u32) bool {
    return (rng % 100) < ANVIL_DAMAGE_THRESHOLD;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

const testing = std.testing;

test "canRepair returns true for matching item types" {
    try testing.expect(canRepair(10, 10));
    try testing.expect(canRepair(0, 0));
    try testing.expect(canRepair(65535, 65535));
}

test "canRepair returns false for different item types" {
    try testing.expect(!canRepair(10, 11));
    try testing.expect(!canRepair(0, 1));
    try testing.expect(!canRepair(100, 200));
}

test "calculateRepair basic addition with 12% bonus" {
    // (50 + 30) * 1.12 = 89.6 -> truncated to 89
    const result = calculateRepair(50, 30, 200);
    try testing.expectEqual(@as(u16, 89), result);
}

test "calculateRepair caps at max durability" {
    // (400 + 400) * 1.12 = 896, capped to 500
    const result = calculateRepair(400, 400, 500);
    try testing.expectEqual(@as(u16, 500), result);
}

test "calculateRepair with zero durabilities" {
    const result = calculateRepair(0, 0, 100);
    try testing.expectEqual(@as(u16, 0), result);
}

test "calculateRepair one item at zero durability" {
    // (0 + 100) * 1.12 = 112
    const result = calculateRepair(0, 100, 200);
    try testing.expectEqual(@as(u16, 112), result);
}

test "calculateRepair exact cap boundary" {
    // (100 + 100) * 1.12 = 224, cap at 224 -> exactly at max
    const result = calculateRepair(100, 100, 224);
    try testing.expectEqual(@as(u16, 224), result);
}

test "getXPCost base cost without enchantments" {
    try testing.expectEqual(@as(u8, 4), getXPCost(1, false));
    try testing.expectEqual(@as(u8, 4), getXPCost(999, false));
}

test "getXPCost increased cost with enchantments" {
    try testing.expectEqual(@as(u8, 6), getXPCost(1, true));
    try testing.expectEqual(@as(u8, 6), getXPCost(999, true));
}

test "shouldDamageAnvil returns true for low rng values" {
    // rng % 100 < 12 => damage
    try testing.expect(shouldDamageAnvil(0));
    try testing.expect(shouldDamageAnvil(11));
    try testing.expect(shouldDamageAnvil(111)); // 111 % 100 = 11
}

test "shouldDamageAnvil returns false for high rng values" {
    try testing.expect(!shouldDamageAnvil(12));
    try testing.expect(!shouldDamageAnvil(50));
    try testing.expect(!shouldDamageAnvil(99));
    try testing.expect(!shouldDamageAnvil(112)); // 112 % 100 = 12 => false
}

test "ANVIL_MAX_COST constant is 39" {
    try testing.expectEqual(@as(u8, 39), ANVIL_MAX_COST);
}

test "calculateRepair handles large u16 values without overflow" {
    // (65535 + 65535) * 112 / 100 = 146,798 -> capped to 65535
    const result = calculateRepair(65535, 65535, 65535);
    try testing.expectEqual(@as(u16, 65535), result);
}
