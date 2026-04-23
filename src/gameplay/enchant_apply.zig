/// Bridge between enchantment data and gameplay effects.
///
/// Reads enchantments from a bit-packed u32 (6 slots x 5 bits) and applies
/// them to base gameplay values such as mining speed, melee damage, and
/// armor defense.

const std = @import("std");

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Return the mining speed after applying an Efficiency enchantment.
/// Efficiency bonus: level^2 + 1.
pub fn getAdjustedMiningSpeed(base_speed: f32, enchants: u32) f32 {
    const eff_level = getEnchantLevel(enchants, 1);
    if (eff_level > 0) return base_speed + @as(f32, @floatFromInt(eff_level * eff_level + 1));
    return base_speed;
}

/// Return the damage after applying a Sharpness enchantment.
/// Sharpness bonus: 0.5 + level * 0.5.
pub fn getAdjustedDamage(base_dmg: f32, enchants: u32) f32 {
    const sharp = getEnchantLevel(enchants, 5);
    return base_dmg + 0.5 + @as(f32, @floatFromInt(sharp)) * 0.5;
}

/// Return the defense after applying a Protection enchantment.
/// Protection bonus: level * 1.0.
pub fn getAdjustedDefense(base_def: f32, enchants: u32) f32 {
    const prot = getEnchantLevel(enchants, 6);
    return base_def + @as(f32, @floatFromInt(prot));
}

/// Return true when the packed enchantments contain Silk Touch (id 4).
pub fn hasSilkTouch(enchants: u32) bool {
    return getEnchantLevel(enchants, 4) > 0;
}

/// Return the Fortune level (1-4) or 0 when absent.
pub fn getFortuneLevel(enchants: u32) u8 {
    return getEnchantLevel(enchants, 3);
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

const slot_count: u3 = 6;
const bits_per_slot: u5 = 5;

/// Scan six 5-bit slots inside `enchants` for the given enchant `id`.
/// Each slot: bits [2:0] = enchant id, bits [4:3] = level (0-3 maps to 1-4).
/// Returns the enchant level (1-4) on match, or 0 when absent.
fn getEnchantLevel(enchants: u32, id: u3) u8 {
    var i: u3 = 0;
    while (i < slot_count) : (i += 1) {
        const shift: u5 = @as(u5, i) * bits_per_slot;
        const raw: u5 = @truncate(enchants >> shift);
        const slot_id: u3 = @truncate(raw);
        const slot_level: u2 = @truncate(raw >> 3);
        if (slot_id == id) return @as(u8, slot_level) + 1;
    }
    return 0;
}

// ---------------------------------------------------------------------------
// Helpers used by tests to build packed enchantment words
// ---------------------------------------------------------------------------

/// Pack a single (id, level) pair into the given slot of a u32.
fn packSlot(enchants: u32, slot: u3, id: u3, level: u2) u32 {
    const shift: u5 = @as(u5, slot) * bits_per_slot;
    const raw: u32 = @as(u32, level) << 3 | @as(u32, id);
    const mask: u32 = ~(@as(u32, 0x1F) << shift);
    return (enchants & mask) | (raw << shift);
}

// ===========================================================================
// Tests
// ===========================================================================

test "getEnchantLevel returns 0 for empty enchantments" {
    try std.testing.expectEqual(@as(u8, 0), getEnchantLevel(0, 1));
    try std.testing.expectEqual(@as(u8, 0), getEnchantLevel(0, 3));
    try std.testing.expectEqual(@as(u8, 0), getEnchantLevel(0, 5));
}

test "getEnchantLevel returns correct level for slot 0" {
    // Efficiency (id=1) at level field 2 => enchant level 3
    const enc = packSlot(0, 0, 1, 2);
    try std.testing.expectEqual(@as(u8, 3), getEnchantLevel(enc, 1));
}

test "getEnchantLevel finds enchant in later slot" {
    // Put sharpness (id=5) in slot 3 with level field 1 => enchant level 2
    const enc = packSlot(0, 3, 5, 1);
    try std.testing.expectEqual(@as(u8, 2), getEnchantLevel(enc, 5));
}

test "getEnchantLevel ignores non-matching ids" {
    const enc = packSlot(0, 0, 2, 3); // unbreaking (id=2), level 4
    try std.testing.expectEqual(@as(u8, 0), getEnchantLevel(enc, 1)); // no efficiency
}

test "getAdjustedMiningSpeed unchanged without efficiency" {
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), getAdjustedMiningSpeed(4.0, 0), 0.001);
}

test "getAdjustedMiningSpeed with efficiency I" {
    // Efficiency I: level=1, bonus = 1*1 + 1 = 2
    const enc = packSlot(0, 0, 1, 0); // id=1, level field 0 => level 1
    try std.testing.expectApproxEqAbs(@as(f32, 6.0), getAdjustedMiningSpeed(4.0, enc), 0.001);
}

test "getAdjustedMiningSpeed with efficiency IV" {
    // Efficiency IV: level=4, bonus = 4*4 + 1 = 17
    const enc = packSlot(0, 0, 1, 3); // id=1, level field 3 => level 4
    try std.testing.expectApproxEqAbs(@as(f32, 21.0), getAdjustedMiningSpeed(4.0, enc), 0.001);
}

test "getAdjustedDamage adds base 0.5 even without sharpness" {
    // No sharpness: sharp=0, bonus = 0.5 + 0*0.5 = 0.5
    try std.testing.expectApproxEqAbs(@as(f32, 5.5), getAdjustedDamage(5.0, 0), 0.001);
}

test "getAdjustedDamage with sharpness III" {
    // Sharpness III: level=3, bonus = 0.5 + 3*0.5 = 2.0
    const enc = packSlot(0, 0, 5, 2); // id=5, level field 2 => level 3
    try std.testing.expectApproxEqAbs(@as(f32, 7.0), getAdjustedDamage(5.0, enc), 0.001);
}

test "getAdjustedDefense unchanged without protection" {
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), getAdjustedDefense(3.0, 0), 0.001);
}

test "getAdjustedDefense with protection IV" {
    // Protection IV: level=4, bonus = 4.0
    const enc = packSlot(0, 1, 6, 3); // id=6, level field 3 => level 4
    try std.testing.expectApproxEqAbs(@as(f32, 7.0), getAdjustedDefense(3.0, enc), 0.001);
}

test "hasSilkTouch false when absent" {
    try std.testing.expect(!hasSilkTouch(0));
}

test "hasSilkTouch true when present" {
    const enc = packSlot(0, 2, 4, 0); // silk_touch id=4 in slot 2
    try std.testing.expect(hasSilkTouch(enc));
}

test "getFortuneLevel returns 0 when absent" {
    try std.testing.expectEqual(@as(u8, 0), getFortuneLevel(0));
}

test "getFortuneLevel returns correct level" {
    // Fortune (id=3) at level field 2 => enchant level 3
    const enc = packSlot(0, 4, 3, 2);
    try std.testing.expectEqual(@as(u8, 3), getFortuneLevel(enc));
}

test "multiple enchantments coexist in separate slots" {
    var enc: u32 = 0;
    enc = packSlot(enc, 0, 1, 3); // efficiency IV
    enc = packSlot(enc, 1, 5, 1); // sharpness II
    enc = packSlot(enc, 2, 4, 0); // silk touch I
    enc = packSlot(enc, 3, 6, 2); // protection III

    try std.testing.expectApproxEqAbs(@as(f32, 21.0), getAdjustedMiningSpeed(4.0, enc), 0.001);
    // Damage: 5.0 + 0.5 + 2*0.5 = 6.5
    try std.testing.expectApproxEqAbs(@as(f32, 6.5), getAdjustedDamage(5.0, enc), 0.001);
    // Defense: 3.0 + 3.0 = 6.0
    try std.testing.expectApproxEqAbs(@as(f32, 6.0), getAdjustedDefense(3.0, enc), 0.001);
    try std.testing.expect(hasSilkTouch(enc));
}

test "packSlot preserves other slots" {
    var enc: u32 = 0;
    enc = packSlot(enc, 0, 1, 0);
    enc = packSlot(enc, 5, 3, 2);
    try std.testing.expectEqual(@as(u8, 1), getEnchantLevel(enc, 1));
    try std.testing.expectEqual(@as(u8, 3), getEnchantLevel(enc, 3));
}
