/// Extended villager trading system with all twelve professions and
/// level-gated trade tables.  Each profession unlocks up to 4 trades per
/// level (1-5).  Trades have limited uses that are consumed by executeTrade.
const std = @import("std");

// ---------------------------------------------------------------------------
// Item ID constants
// ---------------------------------------------------------------------------

pub const EMERALD: u16 = 325;
pub const WHEAT: u16 = 512;
pub const BREAD: u16 = 257;
pub const PAPER: u16 = 389;
pub const BOOKSHELF: u16 = 21;
pub const IRON_SWORD: u16 = 301;
pub const IRON_PICKAXE: u16 = 302;
pub const IRON_AXE: u16 = 303;
pub const IRON_SHOVEL: u16 = 304;
pub const IRON_HOE: u16 = 305;
pub const RAW_CHICKEN: u16 = 263;
pub const COOKED_CHICKEN: u16 = 264;
pub const RAW_PORKCHOP: u16 = 265;
pub const COOKED_PORKCHOP: u16 = 266;
pub const PUMPKIN_PIE: u16 = 267;
pub const COOKIE: u16 = 268;
pub const LAPIS_LAZULI: u16 = 351;
pub const REDSTONE: u16 = 352;
pub const GLOWSTONE: u16 = 353;
pub const ENDER_PEARL: u16 = 354;
pub const ROTTEN_FLESH: u16 = 355;
pub const GOLD_INGOT: u16 = 356;
pub const RAW_COD: u16 = 270;
pub const COOKED_COD: u16 = 271;
pub const RAW_SALMON: u16 = 272;
pub const COOKED_SALMON: u16 = 273;
pub const STRING: u16 = 280;
pub const BOW: u16 = 281;
pub const ARROW: u16 = 282;
pub const CROSSBOW: u16 = 283;
pub const LEATHER: u16 = 290;
pub const LEATHER_PANTS: u16 = 291;
pub const LEATHER_TUNIC: u16 = 292;
pub const STONE: u16 = 1;
pub const BRICK: u16 = 2;
pub const STONE_BRICKS: u16 = 3;
pub const QUARTZ_BLOCK: u16 = 4;
pub const WOOL: u16 = 400;
pub const SHEARS: u16 = 401;
pub const PAINTING: u16 = 402;
pub const DIAMOND_AXE: u16 = 310;
pub const DIAMOND_PICKAXE: u16 = 311;
pub const BELL: u16 = 420;
pub const ENCHANTED_BOOK: u16 = 430;

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

pub const Profession = enum(u4) {
    farmer,
    librarian,
    blacksmith,
    butcher,
    cleric,
    fisherman,
    fletcher,
    leatherworker,
    mason,
    shepherd,
    toolsmith,
    weaponsmith,
};

pub const TradeOffer = struct {
    input1: u16,
    input1_count: u8,
    input2: u16 = 0,
    input2_count: u8 = 0,
    output: u16,
    output_count: u8,
    uses: u8 = 0,
    max_uses: u8 = 12,
};

// ---------------------------------------------------------------------------
// Trade tables  (farmer, librarian, blacksmith fully fleshed out; others
// have at least level-1 trades)
// ---------------------------------------------------------------------------

/// Return up to 4 trade offers for `prof` at `level` (1-5).
/// Higher levels unlock progressively better trades.  Levels outside
/// the 1-5 range yield all-null offers.
pub fn getOffers(prof: Profession, level: u8) [4]?TradeOffer {
    var result = [_]?TradeOffer{null} ** 4;
    if (level < 1 or level > 5) return result;

    switch (prof) {
        .farmer => populateFarmer(&result, level),
        .librarian => populateLibrarian(&result, level),
        .blacksmith => populateBlacksmith(&result, level),
        .butcher => populateButcher(&result, level),
        .cleric => populateCleric(&result, level),
        .fisherman => populateFisherman(&result, level),
        .fletcher => populateFletcher(&result, level),
        .leatherworker => populateLeatherworker(&result, level),
        .mason => populateMason(&result, level),
        .shepherd => populateShepherd(&result, level),
        .toolsmith => populateToolsmith(&result, level),
        .weaponsmith => populateWeaponsmith(&result, level),
    }

    return result;
}

/// Execute a trade: if the offer has remaining uses, increment the use
/// counter and return true.  Otherwise return false and leave the offer
/// unchanged.
pub fn executeTrade(offer: *TradeOffer) bool {
    if (offer.uses >= offer.max_uses) return false;
    offer.uses += 1;
    return true;
}

// ---------------------------------------------------------------------------
// Per-profession trade tables
// ---------------------------------------------------------------------------

fn populateFarmer(r: *[4]?TradeOffer, level: u8) void {
    switch (level) {
        1 => {
            r[0] = .{ .input1 = WHEAT, .input1_count = 20, .output = EMERALD, .output_count = 1, .max_uses = 16 };
            r[1] = .{ .input1 = EMERALD, .input1_count = 1, .output = BREAD, .output_count = 6 };
        },
        2 => {
            r[0] = .{ .input1 = EMERALD, .input1_count = 1, .output = PUMPKIN_PIE, .output_count = 4 };
            r[1] = .{ .input1 = EMERALD, .input1_count = 1, .output = BREAD, .output_count = 8 };
        },
        3 => {
            r[0] = .{ .input1 = EMERALD, .input1_count = 3, .output = COOKIE, .output_count = 18 };
        },
        4 => {
            r[0] = .{ .input1 = EMERALD, .input1_count = 1, .output = COOKIE, .output_count = 12, .max_uses = 16 };
        },
        5 => {
            r[0] = .{ .input1 = EMERALD, .input1_count = 3, .output = PUMPKIN_PIE, .output_count = 8, .max_uses = 8 };
        },
        else => {},
    }
}

fn populateLibrarian(r: *[4]?TradeOffer, level: u8) void {
    switch (level) {
        1 => {
            r[0] = .{ .input1 = PAPER, .input1_count = 24, .output = EMERALD, .output_count = 1, .max_uses = 16 };
            r[1] = .{ .input1 = EMERALD, .input1_count = 9, .output = BOOKSHELF, .output_count = 1 };
        },
        2 => {
            r[0] = .{ .input1 = PAPER, .input1_count = 16, .output = EMERALD, .output_count = 1, .max_uses = 16 };
            r[1] = .{ .input1 = EMERALD, .input1_count = 5, .output = ENCHANTED_BOOK, .output_count = 1, .max_uses = 8 };
        },
        3 => {
            r[0] = .{ .input1 = EMERALD, .input1_count = 1, .input2 = BOOKSHELF, .input2_count = 4, .output = ENCHANTED_BOOK, .output_count = 1, .max_uses = 8 };
        },
        4 => {
            r[0] = .{ .input1 = EMERALD, .input1_count = 12, .output = ENCHANTED_BOOK, .output_count = 1, .max_uses = 4 };
        },
        5 => {
            r[0] = .{ .input1 = EMERALD, .input1_count = 20, .output = ENCHANTED_BOOK, .output_count = 1, .max_uses = 4 };
        },
        else => {},
    }
}

fn populateBlacksmith(r: *[4]?TradeOffer, level: u8) void {
    switch (level) {
        1 => {
            r[0] = .{ .input1 = EMERALD, .input1_count = 3, .output = IRON_PICKAXE, .output_count = 1, .max_uses = 8 };
            r[1] = .{ .input1 = EMERALD, .input1_count = 2, .output = IRON_SHOVEL, .output_count = 1, .max_uses = 8 };
        },
        2 => {
            r[0] = .{ .input1 = EMERALD, .input1_count = 4, .output = IRON_AXE, .output_count = 1, .max_uses = 8 };
            r[1] = .{ .input1 = EMERALD, .input1_count = 5, .output = IRON_SWORD, .output_count = 1, .max_uses = 8 };
        },
        3 => {
            r[0] = .{ .input1 = EMERALD, .input1_count = 6, .output = IRON_HOE, .output_count = 1, .max_uses = 8 };
            r[1] = .{ .input1 = IRON_PICKAXE, .input1_count = 1, .input2 = EMERALD, .input2_count = 2, .output = IRON_PICKAXE, .output_count = 1, .max_uses = 4 };
        },
        4 => {
            r[0] = .{ .input1 = EMERALD, .input1_count = 12, .output = DIAMOND_PICKAXE, .output_count = 1, .max_uses = 4 };
        },
        5 => {
            r[0] = .{ .input1 = EMERALD, .input1_count = 15, .output = DIAMOND_AXE, .output_count = 1, .max_uses = 4 };
        },
        else => {},
    }
}

fn populateButcher(r: *[4]?TradeOffer, level: u8) void {
    switch (level) {
        1 => {
            r[0] = .{ .input1 = RAW_CHICKEN, .input1_count = 14, .output = EMERALD, .output_count = 1, .max_uses = 16 };
            r[1] = .{ .input1 = RAW_PORKCHOP, .input1_count = 7, .output = EMERALD, .output_count = 1, .max_uses = 16 };
        },
        2 => {
            r[0] = .{ .input1 = EMERALD, .input1_count = 1, .output = COOKED_CHICKEN, .output_count = 8 };
        },
        3 => {
            r[0] = .{ .input1 = EMERALD, .input1_count = 1, .output = COOKED_PORKCHOP, .output_count = 5 };
        },
        else => {},
    }
}

fn populateCleric(r: *[4]?TradeOffer, level: u8) void {
    switch (level) {
        1 => {
            r[0] = .{ .input1 = ROTTEN_FLESH, .input1_count = 32, .output = EMERALD, .output_count = 1, .max_uses = 16 };
            r[1] = .{ .input1 = EMERALD, .input1_count = 1, .output = REDSTONE, .output_count = 2 };
        },
        2 => {
            r[0] = .{ .input1 = GOLD_INGOT, .input1_count = 3, .output = EMERALD, .output_count = 1 };
            r[1] = .{ .input1 = EMERALD, .input1_count = 1, .output = LAPIS_LAZULI, .output_count = 2 };
        },
        3 => {
            r[0] = .{ .input1 = EMERALD, .input1_count = 4, .output = GLOWSTONE, .output_count = 1, .max_uses = 8 };
        },
        4 => {
            r[0] = .{ .input1 = EMERALD, .input1_count = 5, .output = ENDER_PEARL, .output_count = 1, .max_uses = 8 };
        },
        else => {},
    }
}

fn populateFisherman(r: *[4]?TradeOffer, level: u8) void {
    switch (level) {
        1 => {
            r[0] = .{ .input1 = RAW_COD, .input1_count = 6, .output = EMERALD, .output_count = 1, .max_uses = 16 };
            r[1] = .{ .input1 = EMERALD, .input1_count = 1, .output = COOKED_COD, .output_count = 6 };
        },
        2 => {
            r[0] = .{ .input1 = RAW_SALMON, .input1_count = 6, .output = EMERALD, .output_count = 1, .max_uses = 16 };
            r[1] = .{ .input1 = EMERALD, .input1_count = 1, .output = COOKED_SALMON, .output_count = 6 };
        },
        else => {},
    }
}

fn populateFletcher(r: *[4]?TradeOffer, level: u8) void {
    switch (level) {
        1 => {
            r[0] = .{ .input1 = STRING, .input1_count = 32, .output = EMERALD, .output_count = 1, .max_uses = 16 };
            r[1] = .{ .input1 = EMERALD, .input1_count = 1, .output = ARROW, .output_count = 16 };
        },
        2 => {
            r[0] = .{ .input1 = EMERALD, .input1_count = 2, .output = BOW, .output_count = 1, .max_uses = 8 };
        },
        3 => {
            r[0] = .{ .input1 = EMERALD, .input1_count = 3, .output = CROSSBOW, .output_count = 1, .max_uses = 8 };
        },
        else => {},
    }
}

fn populateLeatherworker(r: *[4]?TradeOffer, level: u8) void {
    switch (level) {
        1 => {
            r[0] = .{ .input1 = LEATHER, .input1_count = 6, .output = EMERALD, .output_count = 1, .max_uses = 16 };
            r[1] = .{ .input1 = EMERALD, .input1_count = 3, .output = LEATHER_PANTS, .output_count = 1, .max_uses = 8 };
        },
        2 => {
            r[0] = .{ .input1 = EMERALD, .input1_count = 7, .output = LEATHER_TUNIC, .output_count = 1, .max_uses = 8 };
        },
        else => {},
    }
}

fn populateMason(r: *[4]?TradeOffer, level: u8) void {
    switch (level) {
        1 => {
            r[0] = .{ .input1 = STONE, .input1_count = 20, .output = EMERALD, .output_count = 1, .max_uses = 16 };
            r[1] = .{ .input1 = EMERALD, .input1_count = 1, .output = BRICK, .output_count = 10 };
        },
        2 => {
            r[0] = .{ .input1 = EMERALD, .input1_count = 1, .output = STONE_BRICKS, .output_count = 4 };
        },
        3 => {
            r[0] = .{ .input1 = EMERALD, .input1_count = 1, .output = QUARTZ_BLOCK, .output_count = 1, .max_uses = 8 };
        },
        else => {},
    }
}

fn populateShepherd(r: *[4]?TradeOffer, level: u8) void {
    switch (level) {
        1 => {
            r[0] = .{ .input1 = WOOL, .input1_count = 18, .output = EMERALD, .output_count = 1, .max_uses = 16 };
            r[1] = .{ .input1 = EMERALD, .input1_count = 2, .output = SHEARS, .output_count = 1, .max_uses = 8 };
        },
        2 => {
            r[0] = .{ .input1 = EMERALD, .input1_count = 2, .output = PAINTING, .output_count = 3 };
        },
        else => {},
    }
}

fn populateToolsmith(r: *[4]?TradeOffer, level: u8) void {
    switch (level) {
        1 => {
            r[0] = .{ .input1 = EMERALD, .input1_count = 1, .output = IRON_AXE, .output_count = 1, .max_uses = 8 };
            r[1] = .{ .input1 = EMERALD, .input1_count = 1, .output = IRON_SHOVEL, .output_count = 1, .max_uses = 8 };
        },
        2 => {
            r[0] = .{ .input1 = EMERALD, .input1_count = 2, .output = IRON_PICKAXE, .output_count = 1, .max_uses = 8 };
        },
        3 => {
            r[0] = .{ .input1 = EMERALD, .input1_count = 3, .output = IRON_HOE, .output_count = 1, .max_uses = 8 };
        },
        4 => {
            r[0] = .{ .input1 = EMERALD, .input1_count = 13, .output = DIAMOND_PICKAXE, .output_count = 1, .max_uses = 4 };
        },
        5 => {
            r[0] = .{ .input1 = EMERALD, .input1_count = 8, .output = BELL, .output_count = 1, .max_uses = 4 };
        },
        else => {},
    }
}

fn populateWeaponsmith(r: *[4]?TradeOffer, level: u8) void {
    switch (level) {
        1 => {
            r[0] = .{ .input1 = EMERALD, .input1_count = 3, .output = IRON_SWORD, .output_count = 1, .max_uses = 8 };
            r[1] = .{ .input1 = EMERALD, .input1_count = 3, .output = IRON_AXE, .output_count = 1, .max_uses = 8 };
        },
        2 => {
            r[0] = .{ .input1 = EMERALD, .input1_count = 10, .output = DIAMOND_AXE, .output_count = 1, .max_uses = 4 };
        },
        3 => {
            r[0] = .{ .input1 = EMERALD, .input1_count = 8, .output = BELL, .output_count = 1, .max_uses = 4 };
        },
        else => {},
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "Profession enum has 12 values backed by u4" {
    try std.testing.expectEqual(@as(u4, 0), @intFromEnum(Profession.farmer));
    try std.testing.expectEqual(@as(u4, 11), @intFromEnum(Profession.weaponsmith));
}

test "EMERALD constant is 325" {
    try std.testing.expectEqual(@as(u16, 325), EMERALD);
}

test "getOffers farmer level 1 returns wheat-for-emerald and emerald-for-bread" {
    const offers = getOffers(.farmer, 1);
    const t0 = offers[0].?;
    try std.testing.expectEqual(WHEAT, t0.input1);
    try std.testing.expectEqual(@as(u8, 20), t0.input1_count);
    try std.testing.expectEqual(EMERALD, t0.output);
    try std.testing.expectEqual(@as(u8, 1), t0.output_count);

    const t1 = offers[1].?;
    try std.testing.expectEqual(EMERALD, t1.input1);
    try std.testing.expectEqual(BREAD, t1.output);
    try std.testing.expectEqual(@as(u8, 6), t1.output_count);
}

test "getOffers farmer level 5 returns trade" {
    const offers = getOffers(.farmer, 5);
    try std.testing.expect(offers[0] != null);
    try std.testing.expectEqual(PUMPKIN_PIE, offers[0].?.output);
}

test "getOffers librarian level 1 returns paper and bookshelf trades" {
    const offers = getOffers(.librarian, 1);
    const paper_trade = offers[0].?;
    try std.testing.expectEqual(PAPER, paper_trade.input1);
    try std.testing.expectEqual(@as(u8, 24), paper_trade.input1_count);
    try std.testing.expectEqual(EMERALD, paper_trade.output);

    const bookshelf_trade = offers[1].?;
    try std.testing.expectEqual(EMERALD, bookshelf_trade.input1);
    try std.testing.expectEqual(BOOKSHELF, bookshelf_trade.output);
}

test "getOffers librarian level 3 uses two inputs" {
    const offers = getOffers(.librarian, 3);
    const t = offers[0].?;
    try std.testing.expectEqual(EMERALD, t.input1);
    try std.testing.expectEqual(BOOKSHELF, t.input2);
    try std.testing.expectEqual(@as(u8, 4), t.input2_count);
    try std.testing.expectEqual(ENCHANTED_BOOK, t.output);
}

test "getOffers blacksmith level 1 returns pickaxe and shovel" {
    const offers = getOffers(.blacksmith, 1);
    const t0 = offers[0].?;
    try std.testing.expectEqual(EMERALD, t0.input1);
    try std.testing.expectEqual(IRON_PICKAXE, t0.output);

    const t1 = offers[1].?;
    try std.testing.expectEqual(IRON_SHOVEL, t1.output);
}

test "getOffers blacksmith level 4 returns diamond pickaxe" {
    const offers = getOffers(.blacksmith, 4);
    const t = offers[0].?;
    try std.testing.expectEqual(DIAMOND_PICKAXE, t.output);
    try std.testing.expectEqual(@as(u8, 12), t.input1_count);
}

test "getOffers returns all nulls for level 0" {
    const offers = getOffers(.farmer, 0);
    for (offers) |slot| {
        try std.testing.expect(slot == null);
    }
}

test "getOffers returns all nulls for level 6" {
    const offers = getOffers(.librarian, 6);
    for (offers) |slot| {
        try std.testing.expect(slot == null);
    }
}

test "executeTrade succeeds and increments uses" {
    var offer = TradeOffer{
        .input1 = WHEAT,
        .input1_count = 20,
        .output = EMERALD,
        .output_count = 1,
        .max_uses = 3,
    };
    try std.testing.expect(executeTrade(&offer));
    try std.testing.expectEqual(@as(u8, 1), offer.uses);
    try std.testing.expect(executeTrade(&offer));
    try std.testing.expectEqual(@as(u8, 2), offer.uses);
}

test "executeTrade fails when uses exhausted" {
    var offer = TradeOffer{
        .input1 = EMERALD,
        .input1_count = 1,
        .output = BREAD,
        .output_count = 6,
        .max_uses = 2,
    };
    try std.testing.expect(executeTrade(&offer));
    try std.testing.expect(executeTrade(&offer));
    try std.testing.expect(!executeTrade(&offer));
    try std.testing.expectEqual(@as(u8, 2), offer.uses);
}

test "TradeOffer defaults are correct" {
    const offer = TradeOffer{
        .input1 = EMERALD,
        .input1_count = 1,
        .output = BREAD,
        .output_count = 6,
    };
    try std.testing.expectEqual(@as(u16, 0), offer.input2);
    try std.testing.expectEqual(@as(u8, 0), offer.input2_count);
    try std.testing.expectEqual(@as(u8, 0), offer.uses);
    try std.testing.expectEqual(@as(u8, 12), offer.max_uses);
}

test "all professions return at least one level-1 trade" {
    const professions = [_]Profession{
        .farmer,      .librarian,     .blacksmith,  .butcher,
        .cleric,      .fisherman,     .fletcher,    .leatherworker,
        .mason,       .shepherd,      .toolsmith,   .weaponsmith,
    };
    for (professions) |prof| {
        const offers = getOffers(prof, 1);
        try std.testing.expect(offers[0] != null);
    }
}

test "higher levels unlock progressively for farmer" {
    var total_non_null: u32 = 0;
    var level: u8 = 1;
    while (level <= 5) : (level += 1) {
        const offers = getOffers(.farmer, level);
        for (offers) |slot| {
            if (slot != null) total_non_null += 1;
        }
    }
    // Farmer has trades across 5 levels, totalling more than just level-1.
    try std.testing.expect(total_non_null >= 5);
}
