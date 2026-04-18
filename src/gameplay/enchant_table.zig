/// Enchanting table interaction: generate enchantment offers based on
/// bookshelves, player XP, and lapis cost. Applies the cheapest affordable
/// enchantment automatically on right-click.

const std = @import("std");

pub const EnchantOffer = struct {
    enchant_index: u8, // index into EnchantmentType enum
    level: u8,
    xp_cost: u32,
    lapis_cost: u8,
};

const MAX_OFFERS = 3;

pub const EnchantOffers = struct {
    offers: [MAX_OFFERS]EnchantOffer,
    count: u8,
};

/// Lapis item ID (non-block item, in the same range as other materials).
pub const LAPIS_ITEM_ID: u16 = 220;

/// Generate up to 3 enchantment offers based on a seed value and bookshelf count.
/// Bookshelf count (0-15) increases max enchantment level available.
pub fn generateOffers(seed: u64, bookshelf_count: u8) EnchantOffers {
    const capped_shelves: u32 = @min(bookshelf_count, 15);
    var result = EnchantOffers{
        .offers = undefined,
        .count = 0,
    };

    // Generate 1-3 offers based on seed
    const offer_count: u8 = @intCast(1 + (seed % 3));
    var i: u8 = 0;
    while (i < offer_count) : (i += 1) {
        const offer_seed = seed +% @as(u64, i) *% 7919;
        const enchant_index: u8 = @intCast(offer_seed % 18); // 18 enchantment types
        const max_level: u32 = 1 + capped_shelves / 5;
        const level: u8 = @intCast(1 + (offer_seed / 18) % max_level);
        const xp_cost: u32 = @as(u32, level) * (1 + capped_shelves / 3);
        const lapis_cost: u8 = @intCast(@min(@as(u32, i) + 1, 3));

        result.offers[i] = .{
            .enchant_index = enchant_index,
            .level = level,
            .xp_cost = xp_cost,
            .lapis_cost = lapis_cost,
        };
        result.count += 1;
    }

    return result;
}

/// Find the cheapest offer the player can afford.
/// Returns the offer index (0-based) or null if none affordable.
pub fn findCheapestAffordable(offers: *const EnchantOffers, player_xp: u32, lapis_count: u8) ?u8 {
    var best_idx: ?u8 = null;
    var best_cost: u32 = std.math.maxInt(u32);

    for (0..offers.count) |i| {
        const offer = offers.offers[i];
        if (offer.xp_cost <= player_xp and offer.lapis_cost <= lapis_count) {
            if (offer.xp_cost < best_cost) {
                best_cost = offer.xp_cost;
                best_idx = @intCast(i);
            }
        }
    }

    return best_idx;
}

// ──────────────────────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────────────────────

test "generateOffers produces at least one offer" {
    const offers = generateOffers(42, 0);
    try std.testing.expect(offers.count >= 1);
    try std.testing.expect(offers.count <= 3);
}

test "generateOffers respects bookshelf scaling" {
    const low = generateOffers(42, 0);
    const high = generateOffers(42, 15);
    // With more bookshelves, max level should be higher
    try std.testing.expect(low.offers[0].level <= high.offers[0].level or
        low.offers[0].xp_cost <= high.offers[0].xp_cost);
}

test "findCheapestAffordable returns cheapest" {
    var offers = EnchantOffers{
        .offers = undefined,
        .count = 3,
    };
    offers.offers[0] = .{ .enchant_index = 0, .level = 3, .xp_cost = 15, .lapis_cost = 3 };
    offers.offers[1] = .{ .enchant_index = 1, .level = 1, .xp_cost = 5, .lapis_cost = 1 };
    offers.offers[2] = .{ .enchant_index = 2, .level = 2, .xp_cost = 10, .lapis_cost = 2 };

    const idx = findCheapestAffordable(&offers, 20, 3);
    try std.testing.expect(idx != null);
    try std.testing.expectEqual(@as(u8, 1), idx.?);
}

test "findCheapestAffordable returns null when too poor" {
    var offers = EnchantOffers{
        .offers = undefined,
        .count = 1,
    };
    offers.offers[0] = .{ .enchant_index = 0, .level = 5, .xp_cost = 100, .lapis_cost = 3 };

    const idx = findCheapestAffordable(&offers, 5, 3);
    try std.testing.expect(idx == null);
}

test "findCheapestAffordable checks lapis" {
    var offers = EnchantOffers{
        .offers = undefined,
        .count = 1,
    };
    offers.offers[0] = .{ .enchant_index = 0, .level = 1, .xp_cost = 5, .lapis_cost = 3 };

    // Enough XP but not enough lapis
    const idx = findCheapestAffordable(&offers, 100, 2);
    try std.testing.expect(idx == null);
}

test "deterministic offers for same seed" {
    const a = generateOffers(12345, 10);
    const b = generateOffers(12345, 10);
    try std.testing.expectEqual(a.count, b.count);
    for (0..a.count) |i| {
        try std.testing.expectEqual(a.offers[i].enchant_index, b.offers[i].enchant_index);
        try std.testing.expectEqual(a.offers[i].level, b.offers[i].level);
    }
}
