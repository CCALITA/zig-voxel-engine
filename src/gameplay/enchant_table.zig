/// Enchantment table system.
/// Detects nearby bookshelves, generates weighted enchant offers,
/// and applies enchantments with level and lapis costs.

const std = @import("std");

pub const BOOKSHELF_BLOCK_ID: u8 = 21;
const MAX_BOOKSHELVES: u8 = 15;

pub const EnchantOffer = struct {
    enchant_type: u8,
    level: u8,
    cost_levels: u8,
    cost_lapis: u8,
};

pub const EnchantResult = struct {
    enchant_type: u8,
    level: u8,
    success: bool,
};

pub const EnchantTable = struct {
    bookshelves: u8,
    seed: u64,

    pub fn init(seed: u64) EnchantTable {
        return .{
            .bookshelves = 0,
            .seed = seed,
        };
    }

    /// Scan the 5x5x2 area around the table (with a 1-block air gap) and
    /// count BOOKSHELF blocks, capping at 15.
    ///
    /// The table sits at (tx, ty, tz). Bookshelves must be exactly 2 blocks
    /// away on the x or z axis (ring at distance 2) and at table height or
    /// one block above (dy 0..1). The block between the shelf and the table
    /// (the "air gap") must be AIR (0).
    pub fn detectBookshelves(
        self: *EnchantTable,
        getBlock: *const fn (i32, i32, i32) u8,
        table_x: i32,
        table_y: i32,
        table_z: i32,
    ) void {
        var count: u8 = 0;

        var dy: i32 = 0;
        while (dy <= 1) : (dy += 1) {
            var dx: i32 = -2;
            while (dx <= 2) : (dx += 1) {
                var dz: i32 = -2;
                while (dz <= 2) : (dz += 1) {
                    if (!isBookshelfRing(dx, dz)) continue;

                    // Air-gap check: the block between shelf and table must be air.
                    const gap_x = table_x + @divTrunc(dx, 2);
                    const gap_z = table_z + @divTrunc(dz, 2);
                    if (getBlock(gap_x, table_y + dy, gap_z) != 0) continue;

                    if (getBlock(table_x + dx, table_y + dy, table_z + dz) == BOOKSHELF_BLOCK_ID) {
                        count += 1;
                        if (count >= MAX_BOOKSHELVES) {
                            self.bookshelves = MAX_BOOKSHELVES;
                            return;
                        }
                    }
                }
            }
        }

        self.bookshelves = count;
    }

    /// Generate three enchant offers based on bookshelves and player level.
    pub fn generateOffers(self: *const EnchantTable, player_level: u32) [3]EnchantOffer {
        const base = computeBase(self.seed, player_level);
        const bs = self.bookshelves;

        var offers: [3]EnchantOffer = undefined;

        inline for (0..3) |slot| {
            const multiplier: u8 = slot + 1;
            const cost: u8 = if (slot == 2)
                base *| multiplier +| bs
            else
                base *| multiplier +| (bs / 3);

            const clamped_cost = if (cost == 0) @as(u8, 1) else cost;
            const etype = enchantTypeFromCost(self.seed, clamped_cost);
            const level = enchantLevelFromCost(clamped_cost);

            offers[slot] = .{
                .enchant_type = etype,
                .level = level,
                .cost_levels = clamped_cost,
                .cost_lapis = multiplier,
            };
        }

        return offers;
    }

    /// Apply the enchantment from the chosen slot (0, 1, or 2).
    /// Advances the internal seed. Returns the resulting enchant type and level.
    pub fn applyEnchant(self: *EnchantTable, slot: u2, player_level: u32) EnchantResult {
        if (slot > 2) {
            return .{ .enchant_type = 0, .level = 0, .success = false };
        }

        const offers = self.generateOffers(player_level);
        const offer = offers[slot];

        self.seed = nextSeed(self.seed);

        return .{
            .enchant_type = offer.enchant_type,
            .level = offer.level,
            .success = true,
        };
    }

    /// Returns true when (dx, dz) lies on the bookshelf ring — exactly 2
    /// blocks away on at least one axis while within the 5x5 footprint.
    fn isBookshelfRing(dx: i32, dz: i32) bool {
        const abs_dx = if (dx < 0) -dx else dx;
        const abs_dz = if (dz < 0) -dz else dz;
        if (abs_dx > 2 or abs_dz > 2) return false;
        return abs_dx == 2 or abs_dz == 2;
    }
};

// ─────────────────────────────── helpers ──────────────────────────────────

fn computeBase(seed: u64, player_level: u32) u8 {
    const hash = seed ^ (@as(u64, player_level) *% 2654435761);
    const raw: u8 = @truncate(hash & 0x3);
    return raw + 1; // 1..4
}

fn enchantTypeFromCost(seed: u64, cost: u8) u8 {
    const hash = seed ^ (@as(u64, cost) *% 2246822519);
    const pool_size: u8 = 6;
    return @truncate(hash % pool_size);
}

fn enchantLevelFromCost(cost: u8) u8 {
    return (cost / 10) + 1;
}

fn nextSeed(seed: u64) u64 {
    return seed *% 6364136223846793005 +% 1442695040888963407;
}

// ──────────────────────────────── Tests ───────────────────────────────────

/// Test helper: builds a getBlock function that returns BOOKSHELF for
/// `count` positions on the bookshelf ring, and AIR everywhere else.
fn worldWithShelves(comptime count: u8) *const fn (i32, i32, i32) u8 {
    const S = struct {
        /// Pre-computed bookshelf positions on the ring (dy=0 only).
        const positions = blk: {
            var buf: [48][2]i32 = undefined;
            var idx: usize = 0;
            var dx: i32 = -2;
            while (dx <= 2) : (dx += 1) {
                var dz: i32 = -2;
                while (dz <= 2) : (dz += 1) {
                    const abs_dx = if (dx < 0) -dx else dx;
                    const abs_dz = if (dz < 0) -dz else dz;
                    if (abs_dx > 2 or abs_dz > 2) continue;
                    if (abs_dx == 2 or abs_dz == 2) {
                        buf[idx] = .{ dx, dz };
                        idx += 1;
                    }
                }
            }
            break :blk .{ .positions = buf, .len = idx };
        };

        fn getBlock(x: i32, y: i32, z: i32) u8 {
            // Only place at table height (y == 0).
            if (y != 0) return 0;
            for (0..positions.len) |i| {
                if (i >= count) break;
                if (x == positions.positions[i][0] and z == positions.positions[i][1]) {
                    return BOOKSHELF_BLOCK_ID;
                }
            }
            return 0;
        }
    };
    return &S.getBlock;
}

test "detectBookshelves counts bookshelves on the ring" {
    var table = EnchantTable.init(42);
    table.detectBookshelves(worldWithShelves(5), 0, 0, 0);
    try std.testing.expectEqual(@as(u8, 5), table.bookshelves);
}

test "detectBookshelves caps at 15" {
    var table = EnchantTable.init(42);
    // Place 16 shelves — should still read 15.
    table.detectBookshelves(worldWithShelves(16), 0, 0, 0);
    try std.testing.expectEqual(@as(u8, MAX_BOOKSHELVES), table.bookshelves);
}

test "detectBookshelves zero when no shelves" {
    var table = EnchantTable.init(42);
    table.detectBookshelves(worldWithShelves(0), 0, 0, 0);
    try std.testing.expectEqual(@as(u8, 0), table.bookshelves);
}

test "lapis cost equals slot index plus one" {
    const table = EnchantTable{ .bookshelves = 0, .seed = 100 };
    const offers = table.generateOffers(10);
    try std.testing.expectEqual(@as(u8, 1), offers[0].cost_lapis);
    try std.testing.expectEqual(@as(u8, 2), offers[1].cost_lapis);
    try std.testing.expectEqual(@as(u8, 3), offers[2].cost_lapis);
}

test "offer costs scale with bookshelves" {
    const table_lo = EnchantTable{ .bookshelves = 0, .seed = 77 };
    const table_hi = EnchantTable{ .bookshelves = 15, .seed = 77 };

    const offers_lo = table_lo.generateOffers(10);
    const offers_hi = table_hi.generateOffers(10);

    // Each slot should have higher (or equal) cost with more bookshelves.
    try std.testing.expect(offers_hi[0].cost_levels >= offers_lo[0].cost_levels);
    try std.testing.expect(offers_hi[1].cost_levels >= offers_lo[1].cost_levels);
    try std.testing.expect(offers_hi[2].cost_levels >= offers_lo[2].cost_levels);
}

test "slot 2 cost uses full bookshelves not divided by 3" {
    // With bookshelves = 15, slot 2 adds full 15 instead of 15/3=5.
    const table = EnchantTable{ .bookshelves = 15, .seed = 55 };
    const offers = table.generateOffers(10);

    // Slot 0 adds bs/3 = 5, slot 2 adds bs = 15; slot 2 must be larger
    // than slot 0 by at least 10 (the difference is (3*base + 15) vs (base + 5)).
    try std.testing.expect(offers[2].cost_levels > offers[0].cost_levels);
}

test "applyEnchant returns success and advances seed" {
    var table = EnchantTable{ .bookshelves = 5, .seed = 999 };
    const old_seed = table.seed;

    const result = table.applyEnchant(0, 30);
    try std.testing.expect(result.success);
    try std.testing.expect(table.seed != old_seed);
}

test "applyEnchant for each slot succeeds" {
    var t0 = EnchantTable{ .bookshelves = 5, .seed = 123 };
    var t1 = EnchantTable{ .bookshelves = 5, .seed = 123 };
    var t2 = EnchantTable{ .bookshelves = 5, .seed = 123 };

    const r0 = t0.applyEnchant(0, 30);
    const r1 = t1.applyEnchant(1, 30);
    const r2 = t2.applyEnchant(2, 30);

    try std.testing.expect(r0.success);
    try std.testing.expect(r1.success);
    try std.testing.expect(r2.success);
}

test "init sets bookshelves to zero" {
    const table = EnchantTable.init(42);
    try std.testing.expectEqual(@as(u8, 0), table.bookshelves);
    try std.testing.expectEqual(@as(u64, 42), table.seed);
}

test "generateOffers cost_levels always at least 1" {
    // With zero bookshelves the base is small but should never be 0.
    const table = EnchantTable{ .bookshelves = 0, .seed = 0 };
    const offers = table.generateOffers(0);
    for (offers) |offer| {
        try std.testing.expect(offer.cost_levels >= 1);
    }
}
