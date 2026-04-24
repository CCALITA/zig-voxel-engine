/// Enchanting table cost calculations.
/// Computes required levels, lapis costs, enchant power from bookshelves,
/// and deterministic offer seeds for the three enchanting table slots.

const std = @import("std");

const max_bookshelves: u8 = 15;

/// Returns the effective enchant power from nearby bookshelves (capped at 15).
pub fn getEnchantPower(bookshelf_count: u8) u8 {
    return @min(max_bookshelves, bookshelf_count);
}

/// Returns the lapis lazuli cost for a given slot (0-indexed).
/// Slot 0 = 1, slot 1 = 2, slot 2 = 3.
pub fn getLapisCost(slot: u2) u8 {
    return @as(u8, slot) + 1;
}

/// Returns the minimum player level required for the given enchanting slot.
///
/// Base level = 1 + (slot * 5), so slot 0 = 1, slot 1 = 6, slot 2 = 11.
/// Bookshelf bonus per slot:
///   slot 0: +0
///   slot 1: +floor(bookshelves / 3)
///   slot 2: +floor(bookshelves * 2 / 3)
pub fn getRequiredLevel(slot: u2, bookshelf_count: u8) u8 {
    const s: u8 = slot;
    const base: u8 = 1 + s * 5;
    const effective: u8 = getEnchantPower(bookshelf_count);

    const bonus: u8 = switch (slot) {
        0 => 0,
        1 => effective / 3,
        2 => (effective * 2) / 3,
        3 => 0,
    };

    return base + bonus;
}

/// Generates a deterministic hash for enchantment offer randomization.
/// Combines player XP seed, slot index, and item ID into a single u32.
pub fn generateOfferSeed(player_xp_seed: u32, slot: u2, item_id: u16) u32 {
    var h = std.hash.Fnv1a_32.init();
    h.update(std.mem.asBytes(&player_xp_seed));
    h.update(std.mem.asBytes(&slot));
    h.update(std.mem.asBytes(&item_id));
    return h.final();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "getEnchantPower caps at 15" {
    try std.testing.expectEqual(@as(u8, 0), getEnchantPower(0));
    try std.testing.expectEqual(@as(u8, 10), getEnchantPower(10));
    try std.testing.expectEqual(@as(u8, 15), getEnchantPower(15));
    try std.testing.expectEqual(@as(u8, 15), getEnchantPower(20));
    try std.testing.expectEqual(@as(u8, 15), getEnchantPower(255));
}

test "getLapisCost returns slot + 1" {
    try std.testing.expectEqual(@as(u8, 1), getLapisCost(0));
    try std.testing.expectEqual(@as(u8, 2), getLapisCost(1));
    try std.testing.expectEqual(@as(u8, 3), getLapisCost(2));
}

test "getRequiredLevel slot 0 ignores bookshelves" {
    try std.testing.expectEqual(@as(u8, 1), getRequiredLevel(0, 0));
    try std.testing.expectEqual(@as(u8, 1), getRequiredLevel(0, 5));
    try std.testing.expectEqual(@as(u8, 1), getRequiredLevel(0, 15));
    try std.testing.expectEqual(@as(u8, 1), getRequiredLevel(0, 30));
}

test "getRequiredLevel slot 1 base is 6 plus bookshelf/3" {
    try std.testing.expectEqual(@as(u8, 6), getRequiredLevel(1, 0));
    try std.testing.expectEqual(@as(u8, 7), getRequiredLevel(1, 3));
    try std.testing.expectEqual(@as(u8, 8), getRequiredLevel(1, 6));
    try std.testing.expectEqual(@as(u8, 11), getRequiredLevel(1, 15));
}

test "getRequiredLevel slot 2 base is 11 plus bookshelves*2/3" {
    try std.testing.expectEqual(@as(u8, 11), getRequiredLevel(2, 0));
    try std.testing.expectEqual(@as(u8, 13), getRequiredLevel(2, 3));
    try std.testing.expectEqual(@as(u8, 15), getRequiredLevel(2, 6));
    try std.testing.expectEqual(@as(u8, 21), getRequiredLevel(2, 15));
}

test "getRequiredLevel clamps bookshelves above 15" {
    // 20 bookshelves should behave the same as 15
    try std.testing.expectEqual(getRequiredLevel(1, 15), getRequiredLevel(1, 20));
    try std.testing.expectEqual(getRequiredLevel(2, 15), getRequiredLevel(2, 20));
    try std.testing.expectEqual(getRequiredLevel(2, 15), getRequiredLevel(2, 255));
}

test "generateOfferSeed is deterministic" {
    const seed_a = generateOfferSeed(42, 0, 300);
    const seed_b = generateOfferSeed(42, 0, 300);
    try std.testing.expectEqual(seed_a, seed_b);
}

test "generateOfferSeed varies with slot" {
    const s0 = generateOfferSeed(100, 0, 500);
    const s1 = generateOfferSeed(100, 1, 500);
    const s2 = generateOfferSeed(100, 2, 500);
    try std.testing.expect(s0 != s1);
    try std.testing.expect(s1 != s2);
    try std.testing.expect(s0 != s2);
}

test "generateOfferSeed varies with item_id" {
    const a = generateOfferSeed(7, 1, 100);
    const b = generateOfferSeed(7, 1, 200);
    try std.testing.expect(a != b);
}

test "generateOfferSeed varies with player_xp_seed" {
    const a = generateOfferSeed(0, 2, 10);
    const b = generateOfferSeed(999, 2, 10);
    try std.testing.expect(a != b);
}

test "getRequiredLevel all slots with zero bookshelves" {
    try std.testing.expectEqual(@as(u8, 1), getRequiredLevel(0, 0));
    try std.testing.expectEqual(@as(u8, 6), getRequiredLevel(1, 0));
    try std.testing.expectEqual(@as(u8, 11), getRequiredLevel(2, 0));
}

test "generateOfferSeed nonzero output for zero inputs" {
    const result = generateOfferSeed(0, 0, 0);
    try std.testing.expect(result != 0);
}
