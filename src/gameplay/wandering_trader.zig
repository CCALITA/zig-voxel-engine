const std = @import("std");

// -- Trade Offer ---------------------------------------------------------------

pub const TradeOffer = struct {
    input_item: u16,
    input_count: u8,
    output_item: u16,
    output_count: u8,
    max_uses: u8 = 1,
};

// -- Trade Pool (50 possible wandering trader offers) -------------------------

pub const TRADE_POOL: [50]TradeOffer = .{
    // Saplings (6)
    .{ .input_item = 264, .input_count = 5, .output_item = 6, .output_count = 1 },   // oak sapling
    .{ .input_item = 264, .input_count = 5, .output_item = 7, .output_count = 1 },   // spruce sapling
    .{ .input_item = 264, .input_count = 5, .output_item = 8, .output_count = 1 },   // birch sapling
    .{ .input_item = 264, .input_count = 5, .output_item = 9, .output_count = 1 },   // jungle sapling
    .{ .input_item = 264, .input_count = 5, .output_item = 10, .output_count = 1 },  // acacia sapling
    .{ .input_item = 264, .input_count = 5, .output_item = 11, .output_count = 1 },  // dark oak sapling

    // Flowers (8)
    .{ .input_item = 264, .input_count = 1, .output_item = 37, .output_count = 1 },  // dandelion
    .{ .input_item = 264, .input_count = 1, .output_item = 38, .output_count = 1 },  // poppy
    .{ .input_item = 264, .input_count = 1, .output_item = 39, .output_count = 1 },  // blue orchid
    .{ .input_item = 264, .input_count = 1, .output_item = 40, .output_count = 1 },  // allium
    .{ .input_item = 264, .input_count = 1, .output_item = 41, .output_count = 1 },  // azure bluet
    .{ .input_item = 264, .input_count = 1, .output_item = 42, .output_count = 1 },  // red tulip
    .{ .input_item = 264, .input_count = 1, .output_item = 43, .output_count = 1 },  // oxeye daisy
    .{ .input_item = 264, .input_count = 1, .output_item = 44, .output_count = 1 },  // cornflower

    // Dyes (8)
    .{ .input_item = 264, .input_count = 3, .output_item = 350, .output_count = 3 }, // red dye
    .{ .input_item = 264, .input_count = 3, .output_item = 351, .output_count = 3 }, // green dye
    .{ .input_item = 264, .input_count = 3, .output_item = 352, .output_count = 3 }, // blue dye
    .{ .input_item = 264, .input_count = 3, .output_item = 353, .output_count = 3 }, // yellow dye
    .{ .input_item = 264, .input_count = 3, .output_item = 354, .output_count = 3 }, // purple dye
    .{ .input_item = 264, .input_count = 3, .output_item = 355, .output_count = 3 }, // cyan dye
    .{ .input_item = 264, .input_count = 3, .output_item = 356, .output_count = 3 }, // pink dye
    .{ .input_item = 264, .input_count = 3, .output_item = 357, .output_count = 3 }, // orange dye

    // Ice variants (3)
    .{ .input_item = 264, .input_count = 6, .output_item = 174, .output_count = 1 }, // packed ice
    .{ .input_item = 264, .input_count = 6, .output_item = 175, .output_count = 1 }, // blue ice
    .{ .input_item = 264, .input_count = 3, .output_item = 79, .output_count = 1 },  // ice

    // Ocean items (6)
    .{ .input_item = 264, .input_count = 5, .output_item = 467, .output_count = 1 }, // nautilus shell
    .{ .input_item = 264, .input_count = 3, .output_item = 468, .output_count = 1 }, // sea pickle
    .{ .input_item = 264, .input_count = 3, .output_item = 469, .output_count = 1 }, // tube coral
    .{ .input_item = 264, .input_count = 3, .output_item = 470, .output_count = 1 }, // brain coral
    .{ .input_item = 264, .input_count = 3, .output_item = 471, .output_count = 1 }, // bubble coral
    .{ .input_item = 264, .input_count = 3, .output_item = 472, .output_count = 1 }, // fire coral

    // Seeds and crops (6)
    .{ .input_item = 264, .input_count = 1, .output_item = 295, .output_count = 1 }, // wheat seeds
    .{ .input_item = 264, .input_count = 1, .output_item = 361, .output_count = 1 }, // pumpkin seeds
    .{ .input_item = 264, .input_count = 1, .output_item = 362, .output_count = 1 }, // melon seeds
    .{ .input_item = 264, .input_count = 1, .output_item = 363, .output_count = 1 }, // beetroot seeds
    .{ .input_item = 264, .input_count = 3, .output_item = 103, .output_count = 1 }, // melon slice
    .{ .input_item = 264, .input_count = 1, .output_item = 296, .output_count = 1 }, // sugar cane

    // Misc blocks (5)
    .{ .input_item = 264, .input_count = 2, .output_item = 12, .output_count = 8 },  // sand
    .{ .input_item = 264, .input_count = 2, .output_item = 13, .output_count = 8 },  // red sand
    .{ .input_item = 264, .input_count = 4, .output_item = 82, .output_count = 1 },  // clay ball
    .{ .input_item = 264, .input_count = 6, .output_item = 165, .output_count = 1 }, // slime ball
    .{ .input_item = 264, .input_count = 3, .output_item = 106, .output_count = 1 }, // vines

    // Nether / exotic (4)
    .{ .input_item = 264, .input_count = 3, .output_item = 372, .output_count = 1 }, // nether wart
    .{ .input_item = 264, .input_count = 5, .output_item = 369, .output_count = 1 }, // gunpowder
    .{ .input_item = 264, .input_count = 1, .output_item = 287, .output_count = 3 }, // string
    .{ .input_item = 264, .input_count = 3, .output_item = 348, .output_count = 1 }, // glowstone dust

    // Rare / special (4)
    .{ .input_item = 264, .input_count = 2, .output_item = 86, .output_count = 1 },  // pumpkin
    .{ .input_item = 264, .input_count = 3, .output_item = 170, .output_count = 1 }, // hay bale
    .{ .input_item = 264, .input_count = 4, .output_item = 397, .output_count = 1 }, // moss block
    .{ .input_item = 264, .input_count = 5, .output_item = 398, .output_count = 1 }, // dripleaf
};

// -- Wandering Trader ----------------------------------------------------------

pub const WanderingTrader = struct {
    trades: [6]TradeOffer,
    despawn_timer: f32 = 2400.0,
    llama_count: u2 = 2,

    /// Advance the despawn timer. Returns true when the trader should despawn
    /// (40 real-time minutes = 2400 seconds at 1x speed).
    pub fn update(self: *WanderingTrader, dt: f32) bool {
        self.despawn_timer -= dt;
        return self.despawn_timer <= 0.0;
    }
};

/// Pick 6 unique random trades from the pool using a deterministic seed.
pub fn spawnTrader(seed: u64) WanderingTrader {
    var rng = std.Random.DefaultPrng.init(seed);
    const random = rng.random();

    // Fisher-Yates partial shuffle to select 6 unique indices
    var indices: [TRADE_POOL.len]u8 = undefined;
    for (0..TRADE_POOL.len) |i| {
        indices[i] = @intCast(i);
    }

    var selected: [6]TradeOffer = undefined;
    for (0..6) |i| {
        const j = i + random.uintLessThan(usize, TRADE_POOL.len - i);
        const tmp = indices[i];
        indices[i] = indices[j];
        indices[j] = tmp;
        selected[i] = TRADE_POOL[indices[i]];
    }

    return WanderingTrader{ .trades = selected };
}

// -- Piglin Barter -------------------------------------------------------------

pub const BarterResult = struct {
    item: u16,
    count: u8,
};

pub const BARTER_TABLE: [40]BarterResult = .{
    // Ender pearls
    .{ .item = 368, .count = 4 },
    .{ .item = 368, .count = 2 },

    // Fire resistance potions
    .{ .item = 373, .count = 1 },

    // Obsidian
    .{ .item = 49, .count = 1 },
    .{ .item = 49, .count = 2 },

    // Crying obsidian
    .{ .item = 490, .count = 1 },
    .{ .item = 490, .count = 3 },

    // Soul sand
    .{ .item = 88, .count = 4 },
    .{ .item = 88, .count = 2 },

    // Nether bricks
    .{ .item = 405, .count = 8 },
    .{ .item = 405, .count = 4 },

    // String
    .{ .item = 287, .count = 8 },
    .{ .item = 287, .count = 3 },

    // Quartz
    .{ .item = 406, .count = 8 },
    .{ .item = 406, .count = 5 },

    // Iron nuggets
    .{ .item = 452, .count = 16 },
    .{ .item = 452, .count = 9 },

    // Spectral arrows
    .{ .item = 439, .count = 12 },
    .{ .item = 439, .count = 6 },

    // Gravel
    .{ .item = 13, .count = 8 },

    // Blackstone
    .{ .item = 491, .count = 8 },
    .{ .item = 491, .count = 16 },

    // Leather
    .{ .item = 334, .count = 4 },
    .{ .item = 334, .count = 2 },

    // Soul speed enchanted book
    .{ .item = 403, .count = 1 },

    // Iron boots (soul speed)
    .{ .item = 309, .count = 1 },

    // Splash potion of fire resistance
    .{ .item = 438, .count = 1 },

    // Water bottle
    .{ .item = 374, .count = 1 },

    // Magma cream
    .{ .item = 378, .count = 2 },
    .{ .item = 378, .count = 4 },

    // Glowstone dust
    .{ .item = 348, .count = 5 },
    .{ .item = 348, .count = 12 },

    // Fire charge
    .{ .item = 385, .count = 1 },

    // Gold nuggets
    .{ .item = 371, .count = 8 },

    // Nether quartz ore
    .{ .item = 153, .count = 2 },

    // Warped fungus
    .{ .item = 492, .count = 1 },

    // Crimson fungus
    .{ .item = 493, .count = 1 },

    // Weeping vines
    .{ .item = 494, .count = 1 },

    // Twisting vines
    .{ .item = 495, .count = 1 },

    // Nether sprouts
    .{ .item = 496, .count = 2 },
};

pub const PiglinBarter = struct {
    input: u16 = 300, // gold_ingot

    pub fn barter(seed: u64) BarterResult {
        var rng = std.Random.DefaultPrng.init(seed);
        const idx = rng.random().uintLessThan(usize, BARTER_TABLE.len);
        return BARTER_TABLE[idx];
    }
};

// -- Tests ---------------------------------------------------------------------

test "trader has exactly 6 trades" {
    const trader = spawnTrader(12345);
    try std.testing.expectEqual(@as(usize, 6), trader.trades.len);
}

test "trader trades come from the pool" {
    const trader = spawnTrader(99999);
    for (trader.trades) |offer| {
        var found = false;
        for (TRADE_POOL) |pool_offer| {
            if (offer.input_item == pool_offer.input_item and
                offer.input_count == pool_offer.input_count and
                offer.output_item == pool_offer.output_item and
                offer.output_count == pool_offer.output_count)
            {
                found = true;
                break;
            }
        }
        try std.testing.expect(found);
    }
}

test "trader 6 trades are unique" {
    const trader = spawnTrader(42);
    for (0..6) |i| {
        for ((i + 1)..6) |j| {
            const a = trader.trades[i];
            const b = trader.trades[j];
            const same = (a.output_item == b.output_item and a.output_count == b.output_count);
            try std.testing.expect(!same);
        }
    }
}

test "despawn timer counts down and triggers at 0" {
    var trader = spawnTrader(1);
    try std.testing.expectEqual(@as(f32, 2400.0), trader.despawn_timer);

    // Advance 2399 seconds — should NOT despawn yet
    try std.testing.expect(!trader.update(2399.0));
    try std.testing.expect(trader.despawn_timer > 0.0);

    // Advance the remaining time — should despawn
    try std.testing.expect(trader.update(1.0));
    try std.testing.expect(trader.despawn_timer <= 0.0);
}

test "default llama count is 2" {
    const trader = spawnTrader(77);
    try std.testing.expectEqual(@as(u2, 2), trader.llama_count);
}

test "barter is deterministic" {
    const r1 = PiglinBarter.barter(555);
    const r2 = PiglinBarter.barter(555);
    try std.testing.expectEqual(r1.item, r2.item);
    try std.testing.expectEqual(r1.count, r2.count);
}

test "barter result comes from table" {
    const result = PiglinBarter.barter(7777);
    var found = false;
    for (BARTER_TABLE) |entry| {
        if (entry.item == result.item and entry.count == result.count) {
            found = true;
            break;
        }
    }
    try std.testing.expect(found);
}

test "different seeds yield different barter results" {
    // Try many seed pairs; at least some must differ
    var differ_count: usize = 0;
    for (0..20) |i| {
        const a = PiglinBarter.barter(i);
        const b = PiglinBarter.barter(i + 1000);
        if (a.item != b.item or a.count != b.count) differ_count += 1;
    }
    try std.testing.expect(differ_count > 0);
}

test "trade pool has 50 entries" {
    try std.testing.expectEqual(@as(usize, 50), TRADE_POOL.len);
}

test "barter table has 40 entries" {
    try std.testing.expectEqual(@as(usize, 40), BARTER_TABLE.len);
}

test "trade pool coverage — many seeds touch most entries" {
    var seen = [_]bool{false} ** TRADE_POOL.len;
    for (0..200) |s| {
        const trader = spawnTrader(s);
        for (trader.trades) |offer| {
            for (0..TRADE_POOL.len) |idx| {
                const p = TRADE_POOL[idx];
                if (offer.output_item == p.output_item and offer.output_count == p.output_count) {
                    seen[idx] = true;
                }
            }
        }
    }
    var covered: usize = 0;
    for (seen) |s| {
        if (s) covered += 1;
    }
    // With 200 seeds × 6 picks from 50, expect nearly full coverage
    try std.testing.expect(covered >= 40);
}

test "spawnTrader is deterministic" {
    const t1 = spawnTrader(12345);
    const t2 = spawnTrader(12345);
    for (0..6) |i| {
        try std.testing.expectEqual(t1.trades[i].output_item, t2.trades[i].output_item);
        try std.testing.expectEqual(t1.trades[i].output_count, t2.trades[i].output_count);
    }
}
