const std = @import("std");

// ---------------------------------------------------------------------------
// BambooBlock
// ---------------------------------------------------------------------------

pub const BambooBlock = struct {
    age: u4, // 0-15
    stage: u1, // 0 = thin, 1 = thick
    height: u8,

    pub const max_age: u4 = 15;
    pub const max_height: u8 = 16;

    pub fn init() BambooBlock {
        return .{ .age = 0, .stage = 0, .height = 0 };
    }

    /// Attempts to grow the bamboo by one tick.
    /// Returns true when the block actually grew.
    pub fn tickGrowth(self: *BambooBlock) bool {
        if (self.age >= max_age) return false;
        if (self.height >= max_height) return false;

        self.age += 1;
        if (self.age >= 8 and self.stage == 0) {
            self.stage = 1;
        }
        self.height += 1;
        return true;
    }

    /// Light level 9 or above is required for bamboo growth.
    pub fn canGrowAt(light_level: u4) bool {
        return light_level >= 9;
    }
};

// ---------------------------------------------------------------------------
// ScaffoldingBlock
// ---------------------------------------------------------------------------

pub const ScaffoldingBlock = struct {
    distance: u3, // 0-6 from nearest support column

    pub const max_distance: u3 = 6;

    pub fn init(distance: u3) ScaffoldingBlock {
        return .{ .distance = distance };
    }

    /// A scaffolding block is supported when its distance from a
    /// supporting column is at most 6.
    pub fn isSupported(self: ScaffoldingBlock) bool {
        return self.distance <= max_distance;
    }

    /// Determines the distance value for a newly-placed scaffolding block.
    /// `neighbor_distance` is the smallest distance among adjacent scaffolding.
    /// `on_ground` means the block is placed directly on a solid surface.
    /// Returns the new distance, or null when placement is invalid.
    pub fn canPlaceAt(neighbor_distance: u3, on_ground: bool) ?u3 {
        if (on_ground) return 0;
        if (neighbor_distance >= max_distance) return null;
        return neighbor_distance + 1;
    }

    /// Returns true when the scaffolding should collapse (unsupported).
    pub fn collapseCheck(self: ScaffoldingBlock) bool {
        return !self.isSupported();
    }
};

// ---------------------------------------------------------------------------
// BambooCrafting
// ---------------------------------------------------------------------------

pub const CraftingResult = struct {
    item: []const u8,
    count: u8,
};

pub const BambooCrafting = struct {
    /// 1 bamboo → 1 stick (simplified; vanilla needs 2 bamboo → 1 stick)
    pub fn craftStick(bamboo_count: u8) ?CraftingResult {
        if (bamboo_count == 0) return null;
        return .{ .item = "stick", .count = bamboo_count };
    }

    /// 6 bamboo → 1 scaffolding
    pub fn craftScaffolding(bamboo_count: u8) ?CraftingResult {
        if (bamboo_count < 6) return null;
        return .{ .item = "scaffolding", .count = bamboo_count / 6 };
    }

    /// 1 bamboo_block → 2 bamboo_planks
    pub fn craftBambooPlanks(bamboo_block_count: u8) ?CraftingResult {
        if (bamboo_block_count == 0) return null;
        return .{ .item = "bamboo_planks", .count = bamboo_block_count * 2 };
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "BambooBlock — initial state" {
    const b = BambooBlock.init();
    try std.testing.expectEqual(@as(u4, 0), b.age);
    try std.testing.expectEqual(@as(u1, 0), b.stage);
    try std.testing.expectEqual(@as(u8, 0), b.height);
}

test "BambooBlock — single tick growth" {
    var b = BambooBlock.init();
    const grew = b.tickGrowth();
    try std.testing.expect(grew);
    try std.testing.expectEqual(@as(u4, 1), b.age);
    try std.testing.expectEqual(@as(u8, 1), b.height);
}

test "BambooBlock — stage transition at age 8" {
    var b = BambooBlock.init();
    var i: u8 = 0;
    while (i < 8) : (i += 1) {
        _ = b.tickGrowth();
    }
    try std.testing.expectEqual(@as(u1, 1), b.stage);
}

test "BambooBlock — max height stops growth" {
    var b = BambooBlock.init();
    var ticks: u8 = 0;
    while (b.tickGrowth()) {
        ticks += 1;
    }
    // Should stop at whichever cap is reached first (age=15 → 15 ticks).
    try std.testing.expectEqual(@as(u8, 15), ticks);
    try std.testing.expect(!b.tickGrowth());
}

test "BambooBlock — max age prevents further growth" {
    var b = BambooBlock{ .age = 15, .stage = 1, .height = 10 };
    try std.testing.expect(!b.tickGrowth());
}

test "BambooBlock — max height prevents further growth" {
    var b = BambooBlock{ .age = 5, .stage = 0, .height = 16 };
    try std.testing.expect(!b.tickGrowth());
}

test "BambooBlock — canGrowAt light levels" {
    try std.testing.expect(!BambooBlock.canGrowAt(0));
    try std.testing.expect(!BambooBlock.canGrowAt(8));
    try std.testing.expect(BambooBlock.canGrowAt(9));
    try std.testing.expect(BambooBlock.canGrowAt(15));
}

test "ScaffoldingBlock — supported at distance 0" {
    const s = ScaffoldingBlock.init(0);
    try std.testing.expect(s.isSupported());
}

test "ScaffoldingBlock — supported at max distance" {
    const s = ScaffoldingBlock.init(6);
    try std.testing.expect(s.isSupported());
}

test "ScaffoldingBlock — collapse when unsupported" {
    const s = ScaffoldingBlock.init(7);
    try std.testing.expect(!s.isSupported());
    try std.testing.expect(s.collapseCheck());
}

test "ScaffoldingBlock — no collapse when supported" {
    const s = ScaffoldingBlock.init(3);
    try std.testing.expect(!s.collapseCheck());
}

test "ScaffoldingBlock — canPlaceAt on ground" {
    const dist = ScaffoldingBlock.canPlaceAt(5, true);
    try std.testing.expectEqual(@as(?u3, 0), dist);
}

test "ScaffoldingBlock — canPlaceAt neighbor propagation" {
    const dist = ScaffoldingBlock.canPlaceAt(3, false);
    try std.testing.expectEqual(@as(?u3, 4), dist);
}

test "ScaffoldingBlock — canPlaceAt invalid beyond max distance" {
    const dist = ScaffoldingBlock.canPlaceAt(6, false);
    try std.testing.expectEqual(@as(?u3, null), dist);
}

test "BambooCrafting — stick from bamboo" {
    const result = BambooCrafting.craftStick(3).?;
    try std.testing.expectEqualStrings("stick", result.item);
    try std.testing.expectEqual(@as(u8, 3), result.count);
}

test "BambooCrafting — stick from zero bamboo" {
    try std.testing.expectEqual(@as(?CraftingResult, null), BambooCrafting.craftStick(0));
}

test "BambooCrafting — scaffolding from bamboo" {
    const result = BambooCrafting.craftScaffolding(12).?;
    try std.testing.expectEqualStrings("scaffolding", result.item);
    try std.testing.expectEqual(@as(u8, 2), result.count);
}

test "BambooCrafting — scaffolding needs at least 6" {
    try std.testing.expectEqual(@as(?CraftingResult, null), BambooCrafting.craftScaffolding(5));
}

test "BambooCrafting — bamboo planks from bamboo block" {
    const result = BambooCrafting.craftBambooPlanks(3).?;
    try std.testing.expectEqualStrings("bamboo_planks", result.item);
    try std.testing.expectEqual(@as(u8, 6), result.count);
}

test "BambooCrafting — bamboo planks from zero blocks" {
    try std.testing.expectEqual(@as(?CraftingResult, null), BambooCrafting.craftBambooPlanks(0));
}
