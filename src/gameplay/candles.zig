const std = @import("std");

pub const CandleBlock = struct {
    count: u3,
    color: u4,
    lit: bool,

    const max_count: u3 = 4;
    const light_per_candle: u4 = 3;

    pub fn init(color: u4) CandleBlock {
        return .{ .count = 1, .color = color, .lit = false };
    }

    /// Attempts to add a candle. Returns true if successful, false if already at max.
    pub fn addCandle(self: *CandleBlock) bool {
        if (self.count >= max_count) return false;
        self.count += 1;
        return true;
    }

    pub fn toggleLit(self: *CandleBlock) void {
        self.lit = !self.lit;
    }

    /// Returns the light level: 0 when unlit, 3 * count when lit, capped at 12.
    pub fn getLightLevel(self: CandleBlock) u4 {
        if (!self.lit) return 0;
        return @min(@as(u4, self.count) * light_per_candle, 12);
    }

    /// Returns true if a candle of the given color can be placed on this block.
    /// If no existing block, any color is valid. Otherwise colors must match.
    pub fn canPlace(existing: ?CandleBlock, new_color: u4) bool {
        const block = existing orelse return true;
        if (block.count >= max_count) return false;
        return block.color == new_color;
    }
};

pub const CakeCandle = struct {
    has_candle: bool,

    pub fn init() CakeCandle {
        return .{ .has_candle = false };
    }

    pub fn placeCandle(self: *CakeCandle) bool {
        if (self.has_candle) return false;
        self.has_candle = true;
        return true;
    }

    pub fn removeCandle(self: *CakeCandle) bool {
        if (!self.has_candle) return false;
        self.has_candle = false;
        return true;
    }
};

// ── Tests ───────────────────────────────────────────────────────────────────

test "addCandle increments up to max 4" {
    var block = CandleBlock.init(0);
    try std.testing.expectEqual(@as(u3, 1), block.count);

    try std.testing.expect(block.addCandle());
    try std.testing.expectEqual(@as(u3, 2), block.count);

    try std.testing.expect(block.addCandle());
    try std.testing.expectEqual(@as(u3, 3), block.count);

    try std.testing.expect(block.addCandle());
    try std.testing.expectEqual(@as(u3, 4), block.count);

    // Fifth candle should fail
    try std.testing.expect(!block.addCandle());
    try std.testing.expectEqual(@as(u3, 4), block.count);
}

test "getLightLevel returns 0 when unlit" {
    const block = CandleBlock{ .count = 3, .color = 5, .lit = false };
    try std.testing.expectEqual(@as(u4, 0), block.getLightLevel());
}

test "getLightLevel returns 3 * count when lit" {
    const one = CandleBlock{ .count = 1, .color = 0, .lit = true };
    try std.testing.expectEqual(@as(u4, 3), one.getLightLevel());

    const two = CandleBlock{ .count = 2, .color = 0, .lit = true };
    try std.testing.expectEqual(@as(u4, 6), two.getLightLevel());

    const three = CandleBlock{ .count = 3, .color = 0, .lit = true };
    try std.testing.expectEqual(@as(u4, 9), three.getLightLevel());

    const four = CandleBlock{ .count = 4, .color = 0, .lit = true };
    try std.testing.expectEqual(@as(u4, 12), four.getLightLevel());
}

test "canPlace requires matching color" {
    const block = CandleBlock{ .count = 2, .color = 3, .lit = false };

    // Same color: allowed
    try std.testing.expect(CandleBlock.canPlace(block, 3));

    // Different color: rejected
    try std.testing.expect(!CandleBlock.canPlace(block, 7));
}

test "canPlace allows any color when no existing block" {
    try std.testing.expect(CandleBlock.canPlace(null, 0));
    try std.testing.expect(CandleBlock.canPlace(null, 15));
}

test "canPlace rejects when existing block is full" {
    const full = CandleBlock{ .count = 4, .color = 2, .lit = false };
    try std.testing.expect(!CandleBlock.canPlace(full, 2));
}

test "toggleLit switches state" {
    var block = CandleBlock.init(0);
    try std.testing.expect(!block.lit);

    block.toggleLit();
    try std.testing.expect(block.lit);

    block.toggleLit();
    try std.testing.expect(!block.lit);
}

test "CakeCandle single candle placement" {
    var cake = CakeCandle.init();
    try std.testing.expect(!cake.has_candle);

    try std.testing.expect(cake.placeCandle());
    try std.testing.expect(cake.has_candle);

    // Cannot place a second candle
    try std.testing.expect(!cake.placeCandle());

    try std.testing.expect(cake.removeCandle());
    try std.testing.expect(!cake.has_candle);

    // Cannot remove when there is none
    try std.testing.expect(!cake.removeCandle());
}
