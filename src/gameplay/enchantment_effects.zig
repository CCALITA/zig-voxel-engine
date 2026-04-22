/// Runtime enchantment effect calculations using bit-packed u32 encoding.
///
/// Enchantments are packed into a u32: 6 slots x 5 bits = 30 bits used.
/// Each 5-bit slot stores: lower 3 bits = EnchantId, upper 2 bits = level (0-3 maps to 1-4).

const std = @import("std");

pub const EnchantId = enum(u3) {
    none = 0,
    efficiency = 1,
    unbreaking = 2,
    fortune = 3,
    silk_touch = 4,
    sharpness = 5,
    protection = 6,
    power = 7,
};

pub const EnchantSlot = struct {
    id: EnchantId,
    level: u2,
};

const slot_count: u3 = 6;
const bits_per_slot: u5 = 5;

/// Extract a single slot from the packed enchantment word.
/// The 5 bits at position slot*5: lower 3 = id, upper 2 = level.
pub fn getSlot(enchants: u32, slot: u3) EnchantSlot {
    std.debug.assert(slot < slot_count);
    const shift: u5 = @as(u5, slot) * bits_per_slot;
    const raw: u5 = @truncate(enchants >> shift);
    return .{
        .id = @enumFromInt(@as(u3, @truncate(raw))),
        .level = @truncate(raw >> 3),
    };
}

/// Set a single slot in the packed enchantment word, returning the new value.
pub fn setSlot(enchants: u32, slot: u3, id: EnchantId, level: u2) u32 {
    std.debug.assert(slot < slot_count);
    const shift: u5 = @as(u5, slot) * bits_per_slot;
    const raw: u32 = @as(u32, level) << 3 | @intFromEnum(id);
    const mask: u32 = ~(@as(u32, 0x1F) << shift);
    return (enchants & mask) | (raw << shift);
}

/// Check whether any of the 6 slots contains the given enchant id.
pub fn hasEnchant(enchants: u32, id: EnchantId) bool {
    for (0..slot_count) |i| {
        if (getSlot(enchants, @intCast(i)).id == id) return true;
    }
    return false;
}

/// Return the enchant level (1-4) for the first slot matching `id`, or 0 if absent.
pub fn getEnchantLevel(enchants: u32, id: EnchantId) u8 {
    for (0..slot_count) |i| {
        const s = getSlot(enchants, @intCast(i));
        if (s.id == id) return @as(u8, s.level) + 1;
    }
    return 0;
}

// ---------------------------------------------------------------------------
// Effect calculations
// ---------------------------------------------------------------------------

/// Efficiency mining speed bonus: level + level^2.
/// Vanilla values: I=2, II=5, III=10, IV=17.
pub fn getMiningSpeedBonus(enchants: u32) f32 {
    const level = getEnchantLevel(enchants, .efficiency);
    if (level == 0) return 0.0;
    const l: f32 = @floatFromInt(level);
    return l + l * l;
}

/// Sharpness melee damage bonus: 0.5 + level * 0.5.
/// I=1.0, II=1.5, III=2.0, IV=2.5.
pub fn getDamageBonus(enchants: u32) f32 {
    const level = getEnchantLevel(enchants, .sharpness);
    if (level == 0) return 0.0;
    const l: f32 = @floatFromInt(level);
    return 0.5 + l * 0.5;
}

/// Protection damage reduction: level * 1.0.
/// I=1, II=2, III=3, IV=4.
pub fn getProtectionBonus(enchants: u32) f32 {
    const level = getEnchantLevel(enchants, .protection);
    if (level == 0) return 0.0;
    return @floatFromInt(level);
}

/// Unbreaking: chance to NOT consume durability.
/// Save probability = level / (level + 1).
/// `rng_val` is a uniform u32 used as the random source.
pub fn shouldSaveItem(enchants: u32, rng_val: u32) bool {
    const level = getEnchantLevel(enchants, .unbreaking);
    if (level == 0) return false;
    // Save if rng_val % (level + 1) != 0  (i.e. 1 in level+1 chance of consuming)
    const divisor: u32 = @as(u32, level) + 1;
    return (rng_val % divisor) != 0;
}

/// Fortune: returns the total drop multiplier (1 + random extra in 0..level).
/// `rng_val` is a uniform u32 used as the random source.
pub fn getFortuneMultiplier(enchants: u32, rng_val: u32) u8 {
    const level = getEnchantLevel(enchants, .fortune);
    if (level == 0) return 1;
    const extra: u8 = @intCast(rng_val % level);
    return 1 + extra;
}

/// Returns true if silk touch is present on the item.
pub fn hasSilkTouch(enchants: u32) bool {
    return hasEnchant(enchants, .silk_touch);
}

/// Power bow damage multiplier: 0.25 * (level + 1).
/// I=0.50, II=0.75, III=1.00, IV=1.25.
pub fn getBowDamageMultiplier(enchants: u32) f32 {
    const level = getEnchantLevel(enchants, .power);
    if (level == 0) return 0.0;
    const l: f32 = @floatFromInt(level);
    return 0.25 * (l + 1.0);
}

/// Sum of all enchant levels across all slots (for XP cost calculation).
pub fn getTotalEnchantLevels(enchants: u32) u8 {
    var total: u8 = 0;
    for (0..slot_count) |i| {
        const s = getSlot(enchants, @intCast(i));
        if (s.id != .none) {
            total += @as(u8, s.level) + 1;
        }
    }
    return total;
}

/// Clear all enchantment slots, returning 0.
pub fn clearAll(enchants: u32) u32 {
    _ = enchants;
    return 0;
}

/// Merge two enchantment words. For each enchant in `b`:
///   - If `a` already has the same type, keep the higher level.
///   - Otherwise, place it in the first empty slot of `a`.
pub fn combineEnchants(a: u32, b: u32) u32 {
    var result = a;
    for (0..slot_count) |bi| {
        const bs = getSlot(b, @intCast(bi));
        if (bs.id == .none) continue;

        // Check if result already has this enchant type
        var found = false;
        for (0..slot_count) |ri| {
            const rs = getSlot(result, @intCast(ri));
            if (rs.id == bs.id) {
                // Take higher level
                const max_level = @max(rs.level, bs.level);
                result = setSlot(result, @intCast(ri), rs.id, max_level);
                found = true;
                break;
            }
        }
        if (!found) {
            // Find first empty slot in result
            for (0..slot_count) |ri| {
                const rs = getSlot(result, @intCast(ri));
                if (rs.id == .none) {
                    result = setSlot(result, @intCast(ri), bs.id, bs.level);
                    break;
                }
            }
        }
    }
    return result;
}

// ===========================================================================
// Tests
// ===========================================================================

test "getSlot and setSlot roundtrip" {
    var enc: u32 = 0;
    enc = setSlot(enc, 0, .efficiency, 2);
    const s = getSlot(enc, 0);
    try std.testing.expectEqual(EnchantId.efficiency, s.id);
    try std.testing.expectEqual(@as(u2, 2), s.level);
}

test "setSlot preserves other slots" {
    var enc: u32 = 0;
    enc = setSlot(enc, 0, .sharpness, 1);
    enc = setSlot(enc, 3, .protection, 3);
    try std.testing.expectEqual(EnchantId.sharpness, getSlot(enc, 0).id);
    try std.testing.expectEqual(@as(u2, 1), getSlot(enc, 0).level);
    try std.testing.expectEqual(EnchantId.protection, getSlot(enc, 3).id);
    try std.testing.expectEqual(@as(u2, 3), getSlot(enc, 3).level);
    // Untouched slots remain none
    try std.testing.expectEqual(EnchantId.none, getSlot(enc, 1).id);
}

test "setSlot overwrites existing slot" {
    var enc: u32 = 0;
    enc = setSlot(enc, 2, .fortune, 1);
    enc = setSlot(enc, 2, .power, 3);
    try std.testing.expectEqual(EnchantId.power, getSlot(enc, 2).id);
    try std.testing.expectEqual(@as(u2, 3), getSlot(enc, 2).level);
}

test "hasEnchant finds present enchant" {
    var enc: u32 = 0;
    enc = setSlot(enc, 4, .silk_touch, 0);
    try std.testing.expect(hasEnchant(enc, .silk_touch));
}

test "hasEnchant returns false for absent enchant" {
    const enc: u32 = 0;
    try std.testing.expect(!hasEnchant(enc, .fortune));
}

test "getEnchantLevel returns correct level" {
    var enc: u32 = 0;
    enc = setSlot(enc, 1, .unbreaking, 2); // level field 2 => enchant level 3
    try std.testing.expectEqual(@as(u8, 3), getEnchantLevel(enc, .unbreaking));
}

test "getEnchantLevel returns 0 when absent" {
    try std.testing.expectEqual(@as(u8, 0), getEnchantLevel(0, .efficiency));
}

test "getMiningSpeedBonus matches vanilla formula" {
    // Efficiency I (level field 0 => enchant level 1): 1 + 1 = 2
    var enc: u32 = setSlot(0, 0, .efficiency, 0);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), getMiningSpeedBonus(enc), 0.001);

    // Efficiency IV (level field 3 => enchant level 4): 4 + 16 = 20
    enc = setSlot(0, 0, .efficiency, 3);
    try std.testing.expectApproxEqAbs(@as(f32, 20.0), getMiningSpeedBonus(enc), 0.001);

    // No efficiency => 0
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), getMiningSpeedBonus(0), 0.001);
}

test "getDamageBonus sharpness levels" {
    // Sharpness I: 0.5 + 1*0.5 = 1.0
    var enc: u32 = setSlot(0, 0, .sharpness, 0);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), getDamageBonus(enc), 0.001);

    // Sharpness IV: 0.5 + 4*0.5 = 2.5
    enc = setSlot(0, 0, .sharpness, 3);
    try std.testing.expectApproxEqAbs(@as(f32, 2.5), getDamageBonus(enc), 0.001);
}

test "getProtectionBonus scales linearly" {
    // Protection III: 3.0
    const enc: u32 = setSlot(0, 0, .protection, 2);
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), getProtectionBonus(enc), 0.001);
}

test "shouldSaveItem unbreaking probability" {
    // Unbreaking III (level field 2 => enchant level 3): save if rng % 4 != 0
    const enc: u32 = setSlot(0, 0, .unbreaking, 2);
    // rng_val 0 => 0 % 4 == 0 => no save
    try std.testing.expect(!shouldSaveItem(enc, 0));
    // rng_val 1 => 1 % 4 != 0 => save
    try std.testing.expect(shouldSaveItem(enc, 1));
    // rng_val 4 => 4 % 4 == 0 => no save
    try std.testing.expect(!shouldSaveItem(enc, 4));
    // No unbreaking => never save
    try std.testing.expect(!shouldSaveItem(0, 1));
}

test "getFortuneMultiplier returns extra drops" {
    // Fortune III (level field 2 => enchant level 3): 1 + (rng % 3)
    const enc: u32 = setSlot(0, 0, .fortune, 2);
    try std.testing.expectEqual(@as(u8, 1), getFortuneMultiplier(enc, 0)); // 0%3=0
    try std.testing.expectEqual(@as(u8, 2), getFortuneMultiplier(enc, 1)); // 1%3=1
    try std.testing.expectEqual(@as(u8, 3), getFortuneMultiplier(enc, 2)); // 2%3=2
    // No fortune => always 1
    try std.testing.expectEqual(@as(u8, 1), getFortuneMultiplier(0, 5));
}

test "hasSilkTouch detects silk touch" {
    var enc: u32 = setSlot(0, 2, .silk_touch, 0);
    try std.testing.expect(hasSilkTouch(enc));
    enc = 0;
    try std.testing.expect(!hasSilkTouch(enc));
}

test "getBowDamageMultiplier power levels" {
    // Power I: 0.25 * 2 = 0.50
    var enc: u32 = setSlot(0, 0, .power, 0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.50), getBowDamageMultiplier(enc), 0.001);

    // Power IV: 0.25 * 5 = 1.25
    enc = setSlot(0, 0, .power, 3);
    try std.testing.expectApproxEqAbs(@as(f32, 1.25), getBowDamageMultiplier(enc), 0.001);

    // No power => 0
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), getBowDamageMultiplier(0), 0.001);
}

test "getTotalEnchantLevels sums all slots" {
    var enc: u32 = 0;
    enc = setSlot(enc, 0, .sharpness, 2); // level 3
    enc = setSlot(enc, 1, .unbreaking, 0); // level 1
    enc = setSlot(enc, 5, .protection, 3); // level 4
    try std.testing.expectEqual(@as(u8, 8), getTotalEnchantLevels(enc));
    // Empty => 0
    try std.testing.expectEqual(@as(u8, 0), getTotalEnchantLevels(0));
}

test "clearAll returns zero" {
    const enc: u32 = setSlot(0, 0, .sharpness, 3);
    try std.testing.expectEqual(@as(u32, 0), clearAll(enc));
}

test "combineEnchants merges non-overlapping" {
    const a: u32 = setSlot(0, 0, .sharpness, 1);
    const b: u32 = setSlot(0, 0, .protection, 2);
    const combined = combineEnchants(a, b);
    try std.testing.expect(hasEnchant(combined, .sharpness));
    try std.testing.expect(hasEnchant(combined, .protection));
    try std.testing.expectEqual(@as(u8, 2), getEnchantLevel(combined, .sharpness));
    try std.testing.expectEqual(@as(u8, 3), getEnchantLevel(combined, .protection));
}

test "combineEnchants takes higher level on conflict" {
    const a: u32 = setSlot(0, 0, .sharpness, 1); // level 2
    const b: u32 = setSlot(0, 0, .sharpness, 3); // level 4
    const combined = combineEnchants(a, b);
    try std.testing.expectEqual(@as(u8, 4), getEnchantLevel(combined, .sharpness));
}

test "all six slots can be populated independently" {
    var enc: u32 = 0;
    enc = setSlot(enc, 0, .efficiency, 0);
    enc = setSlot(enc, 1, .unbreaking, 1);
    enc = setSlot(enc, 2, .fortune, 2);
    enc = setSlot(enc, 3, .silk_touch, 0);
    enc = setSlot(enc, 4, .sharpness, 3);
    enc = setSlot(enc, 5, .protection, 1);

    try std.testing.expectEqual(EnchantId.efficiency, getSlot(enc, 0).id);
    try std.testing.expectEqual(EnchantId.unbreaking, getSlot(enc, 1).id);
    try std.testing.expectEqual(EnchantId.fortune, getSlot(enc, 2).id);
    try std.testing.expectEqual(EnchantId.silk_touch, getSlot(enc, 3).id);
    try std.testing.expectEqual(EnchantId.sharpness, getSlot(enc, 4).id);
    try std.testing.expectEqual(EnchantId.protection, getSlot(enc, 5).id);

    try std.testing.expectEqual(@as(u2, 0), getSlot(enc, 0).level);
    try std.testing.expectEqual(@as(u2, 1), getSlot(enc, 1).level);
    try std.testing.expectEqual(@as(u2, 2), getSlot(enc, 2).level);
    try std.testing.expectEqual(@as(u2, 0), getSlot(enc, 3).level);
    try std.testing.expectEqual(@as(u2, 3), getSlot(enc, 4).level);
    try std.testing.expectEqual(@as(u2, 1), getSlot(enc, 5).level);
}
