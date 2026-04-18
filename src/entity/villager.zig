/// Villager professions, trade offers, and leveling system.
/// Each villager has a profession that determines which trades it offers.
/// Trades have limited uses and villagers gain XP to level up, unlocking
/// new trade slots.
const std = @import("std");

// ---------------------------------------------------------------------------
// Item ID constants (kept in sync with food.zig, engine.zig, block.zig)
// ---------------------------------------------------------------------------

pub const WHEAT: u16 = 512; // farming.zig harvest item
pub const BREAD: u16 = 257; // food.zig
pub const RAW_CHICKEN: u16 = 263; // food.zig
pub const EMERALD: u16 = 388; // Minecraft-style ID placeholder
pub const PAPER: u16 = 389;
pub const BOOKSHELF: u16 = 21; // block.zig BOOKSHELF
pub const IRON_PICKAXE: u16 = 302; // engine.zig

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

pub const Profession = enum {
    farmer,
    librarian,
    blacksmith,
    cleric,
    butcher,
    nitwit,
};

pub const TradeOffer = struct {
    input_item: u16,
    input_count: u8,
    input_item_2: u16,
    input_count_2: u8, // 0 = no second input
    output_item: u16,
    output_count: u8,
    max_uses: u8,
    current_uses: u8,
};

pub const VillagerState = struct {
    profession: Profession,
    level: u8, // 1-5 (novice to master)
    trades: [MAX_TRADES]?TradeOffer,
    trade_xp: u32,

    const MAX_TRADES = 8;
    const MAX_LEVEL = 5;
    const XP_PER_LEVEL = 10;

    pub fn init(profession: Profession) VillagerState {
        var state = VillagerState{
            .profession = profession,
            .level = 1,
            .trades = [_]?TradeOffer{null} ** MAX_TRADES,
            .trade_xp = 0,
        };
        const starter = generateTrades(profession, 1);
        for (starter, 0..) |maybe_offer, i| {
            state.trades[i] = maybe_offer;
        }
        return state;
    }

    /// Append a trade offer to the first empty slot. Returns true on success.
    pub fn addTrade(self: *VillagerState, offer: TradeOffer) bool {
        for (&self.trades) |*slot| {
            if (slot.* == null) {
                slot.* = offer;
                return true;
            }
        }
        return false;
    }

    /// Whether the trade at `index` is available (exists and not exhausted).
    pub fn canTrade(self: *const VillagerState, index: u8) bool {
        if (index >= MAX_TRADES) return false;
        const offer = self.trades[index] orelse return false;
        return offer.current_uses < offer.max_uses;
    }

    /// Execute the trade at `index`, consuming a use and returning the output
    /// item info. Returns null when the trade cannot be executed.
    pub fn executeTrade(self: *VillagerState, index: u8) ?TradeOffer {
        if (index >= MAX_TRADES) return null;
        const offer = &(self.trades[index] orelse return null);
        if (offer.current_uses >= offer.max_uses) return null;

        offer.current_uses += 1;
        self.trade_xp += 1;

        return offer.*;
    }

    /// Level up if enough XP has been accumulated (max level 5).
    pub fn levelUp(self: *VillagerState) void {
        if (self.level >= MAX_LEVEL) return;
        if (self.trade_xp < XP_PER_LEVEL * self.level) return;

        self.level += 1;

        // Unlock new trades for the new level.
        const new_trades = generateTrades(self.profession, self.level);
        for (new_trades) |maybe_offer| {
            const offer = maybe_offer orelse continue;
            _ = self.addTrade(offer);
        }
    }
};

// ---------------------------------------------------------------------------
// Trade generation per profession / level
// ---------------------------------------------------------------------------

/// Generate up to 4 trade offers for a given profession and level.
pub fn generateTrades(profession: Profession, level: u8) [4]?TradeOffer {
    var result = [_]?TradeOffer{null} ** 4;

    switch (profession) {
        .farmer => switch (level) {
            1 => {
                result[0] = makeTrade(WHEAT, 20, 0, 0, EMERALD, 1, 16);
                result[1] = makeTrade(EMERALD, 1, 0, 0, BREAD, 6, 12);
            },
            2 => {
                result[0] = makeTrade(EMERALD, 1, 0, 0, BREAD, 8, 12);
            },
            else => {},
        },
        .librarian => switch (level) {
            1 => {
                result[0] = makeTrade(EMERALD, 1, 0, 0, BOOKSHELF, 1, 12);
                result[1] = makeTrade(PAPER, 24, 0, 0, EMERALD, 1, 16);
            },
            2 => {
                result[0] = makeTrade(PAPER, 16, 0, 0, EMERALD, 1, 16);
            },
            else => {},
        },
        .blacksmith => switch (level) {
            1 => {
                result[0] = makeTrade(EMERALD, 1, 0, 0, IRON_PICKAXE, 1, 8);
            },
            2 => {
                result[0] = makeTrade(EMERALD, 3, 0, 0, IRON_PICKAXE, 1, 8);
            },
            else => {},
        },
        .butcher => switch (level) {
            1 => {
                result[0] = makeTrade(RAW_CHICKEN, 14, 0, 0, EMERALD, 1, 16);
            },
            2 => {
                result[0] = makeTrade(RAW_CHICKEN, 10, 0, 0, EMERALD, 1, 16);
            },
            else => {},
        },
        .cleric => switch (level) {
            1 => {
                result[0] = makeTrade(EMERALD, 1, 0, 0, EMERALD, 2, 8);
            },
            else => {},
        },
        .nitwit => {},
    }

    return result;
}

/// Helper to create a TradeOffer with zero current uses.
fn makeTrade(
    in1: u16,
    cnt1: u8,
    in2: u16,
    cnt2: u8,
    out: u16,
    out_cnt: u8,
    max: u8,
) TradeOffer {
    return .{
        .input_item = in1,
        .input_count = cnt1,
        .input_item_2 = in2,
        .input_count_2 = cnt2,
        .output_item = out,
        .output_count = out_cnt,
        .max_uses = max,
        .current_uses = 0,
    };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "init sets profession and level" {
    const v = VillagerState.init(.farmer);
    try std.testing.expectEqual(Profession.farmer, v.profession);
    try std.testing.expectEqual(@as(u8, 1), v.level);
    try std.testing.expectEqual(@as(u32, 0), v.trade_xp);
}

test "init populates starter trades for farmer" {
    const v = VillagerState.init(.farmer);
    // Farmer L1 should have two trades.
    try std.testing.expect(v.trades[0] != null);
    try std.testing.expect(v.trades[1] != null);
    try std.testing.expect(v.trades[2] == null);

    const t0 = v.trades[0].?;
    try std.testing.expectEqual(WHEAT, t0.input_item);
    try std.testing.expectEqual(@as(u8, 20), t0.input_count);
    try std.testing.expectEqual(EMERALD, t0.output_item);
}

test "init nitwit has no trades" {
    const v = VillagerState.init(.nitwit);
    for (v.trades) |slot| {
        try std.testing.expect(slot == null);
    }
}

test "generateTrades farmer level 1" {
    const trades = generateTrades(.farmer, 1);
    try std.testing.expect(trades[0] != null);
    try std.testing.expect(trades[1] != null);

    const wheat_trade = trades[0].?;
    try std.testing.expectEqual(WHEAT, wheat_trade.input_item);
    try std.testing.expectEqual(@as(u8, 20), wheat_trade.input_count);
    try std.testing.expectEqual(EMERALD, wheat_trade.output_item);
    try std.testing.expectEqual(@as(u8, 1), wheat_trade.output_count);

    const bread_trade = trades[1].?;
    try std.testing.expectEqual(EMERALD, bread_trade.input_item);
    try std.testing.expectEqual(BREAD, bread_trade.output_item);
    try std.testing.expectEqual(@as(u8, 6), bread_trade.output_count);
}

test "generateTrades librarian level 1" {
    const trades = generateTrades(.librarian, 1);
    const bookshelf_trade = trades[0].?;
    try std.testing.expectEqual(EMERALD, bookshelf_trade.input_item);
    try std.testing.expectEqual(BOOKSHELF, bookshelf_trade.output_item);

    const paper_trade = trades[1].?;
    try std.testing.expectEqual(PAPER, paper_trade.input_item);
    try std.testing.expectEqual(@as(u8, 24), paper_trade.input_count);
    try std.testing.expectEqual(EMERALD, paper_trade.output_item);
}

test "generateTrades blacksmith level 1" {
    const trades = generateTrades(.blacksmith, 1);
    const t = trades[0].?;
    try std.testing.expectEqual(EMERALD, t.input_item);
    try std.testing.expectEqual(IRON_PICKAXE, t.output_item);
}

test "generateTrades butcher level 1" {
    const trades = generateTrades(.butcher, 1);
    const t = trades[0].?;
    try std.testing.expectEqual(RAW_CHICKEN, t.input_item);
    try std.testing.expectEqual(@as(u8, 14), t.input_count);
    try std.testing.expectEqual(EMERALD, t.output_item);
}

test "executeTrade returns output and increments uses" {
    var v = VillagerState.init(.farmer);
    const result = v.executeTrade(0);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(EMERALD, result.?.output_item);

    // current_uses should now be 1
    try std.testing.expectEqual(@as(u8, 1), v.trades[0].?.current_uses);
    try std.testing.expectEqual(@as(u32, 1), v.trade_xp);
}

test "executeTrade respects max uses" {
    var v = VillagerState.init(.farmer);
    // Exhaust the first trade (max_uses = 16).
    var i: u8 = 0;
    while (i < 16) : (i += 1) {
        try std.testing.expect(v.executeTrade(0) != null);
    }
    // 17th trade should fail.
    try std.testing.expect(v.executeTrade(0) == null);
    try std.testing.expect(!v.canTrade(0));
}

test "executeTrade returns null for empty slot" {
    var v = VillagerState.init(.nitwit);
    try std.testing.expect(v.executeTrade(0) == null);
}

test "executeTrade returns null for out-of-bounds index" {
    var v = VillagerState.init(.farmer);
    try std.testing.expect(v.executeTrade(10) == null);
}

test "canTrade checks availability" {
    const v = VillagerState.init(.farmer);
    try std.testing.expect(v.canTrade(0)); // first trade exists
    try std.testing.expect(!v.canTrade(5)); // empty slot
    try std.testing.expect(!v.canTrade(255)); // out of range
}

test "addTrade fills first empty slot" {
    var v = VillagerState.init(.nitwit);
    const offer = makeTrade(EMERALD, 1, 0, 0, BREAD, 3, 8);
    try std.testing.expect(v.addTrade(offer));
    try std.testing.expect(v.trades[0] != null);
    try std.testing.expectEqual(BREAD, v.trades[0].?.output_item);
}

test "addTrade returns false when full" {
    var v = VillagerState.init(.farmer);
    // Fill all remaining slots.
    const offer = makeTrade(EMERALD, 1, 0, 0, BREAD, 1, 4);
    var added: u8 = 0;
    while (v.addTrade(offer)) {
        added += 1;
    }
    // Should have filled 6 remaining slots (2 already from init).
    try std.testing.expectEqual(@as(u8, 6), added);
}

test "levelUp advances level and adds trades" {
    var v = VillagerState.init(.farmer);
    // Accumulate enough XP (need XP_PER_LEVEL * level = 10 * 1 = 10).
    v.trade_xp = 10;
    v.levelUp();
    try std.testing.expectEqual(@as(u8, 2), v.level);

    // L2 farmer trade should have been added.
    // Slot 2 should now be populated (slots 0-1 from L1).
    try std.testing.expect(v.trades[2] != null);
}

test "levelUp does not exceed max level" {
    var v = VillagerState.init(.farmer);
    v.level = 5;
    v.trade_xp = 1000;
    v.levelUp();
    try std.testing.expectEqual(@as(u8, 5), v.level);
}

test "levelUp requires sufficient xp" {
    var v = VillagerState.init(.farmer);
    v.trade_xp = 0;
    v.levelUp();
    try std.testing.expectEqual(@as(u8, 1), v.level);
}
