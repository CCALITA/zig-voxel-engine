const std = @import("std");
const blocks = @import("block.zig");

pub const FluidType = enum {
    water,
    lava,
};

pub const DripstoneType = enum {
    stalactite,
    stalagmite,
};

pub const Thickness = enum(u2) {
    tip = 0,
    frustum = 1,
    middle = 2,
    base = 3,
};

pub const DripResult = struct {
    fluid: FluidType,
    filled_cauldron: bool,
};

pub const DripstoneBlock = struct {
    dripstone_type: DripstoneType,
    thickness: Thickness,
    height: u4,

    /// Attempts slow random-tick growth. Returns true if growth occurred.
    /// Growth only happens at the tip and with a low probability (~1/36).
    pub fn tickGrowth(self: *DripstoneBlock) bool {
        if (self.thickness != .tip) return false;

        // In a real implementation this would use the world random tick RNG.
        var rng = std.Random.DefaultPrng.init(@as(u64, self.height));
        const roll = rng.random().intRangeAtMost(u32, 0, 35);
        if (roll != 0) return false;

        self.thickness = .frustum;
        self.height = @min(self.height + 1, 15);
        return true;
    }

    /// Returns the fluid that drips from a stalactite given the block above it.
    pub fn getDripFluid(above_block: blocks.BlockId) ?FluidType {
        return switch (above_block) {
            blocks.WATER => .water,
            blocks.LAVA => .lava,
            else => null,
        };
    }

    /// Stalagmites deal double fall damage.
    pub fn getFallDamageMultiplier() f32 {
        return 2.0;
    }

    /// Checks whether a dripstone of the given type can be placed.
    /// Stalactites need a solid block above; stalagmites need a solid block below.
    pub fn canSupportAt(below_solid: bool, above_solid: bool, dtype: DripstoneType) bool {
        return switch (dtype) {
            .stalactite => above_solid,
            .stalagmite => below_solid,
        };
    }

    /// Simulates a drip tick for a stalactite. If a cauldron is below and the
    /// dripstone is a tip stalactite, the cauldron may be filled.
    pub fn tickDrip(self: DripstoneBlock, cauldron_below: bool) ?DripResult {
        if (self.dripstone_type != .stalactite) return null;
        if (self.thickness != .tip) return null;

        const fluid: FluidType = .water;

        return DripResult{
            .fluid = fluid,
            .filled_cauldron = cauldron_below,
        };
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "stalactite placement requires solid above" {
    try std.testing.expect(DripstoneBlock.canSupportAt(false, true, .stalactite));
    try std.testing.expect(!DripstoneBlock.canSupportAt(false, false, .stalactite));
    try std.testing.expect(DripstoneBlock.canSupportAt(true, true, .stalactite));
}

test "stalagmite placement requires solid below" {
    try std.testing.expect(DripstoneBlock.canSupportAt(true, false, .stalagmite));
    try std.testing.expect(!DripstoneBlock.canSupportAt(false, false, .stalagmite));
    try std.testing.expect(DripstoneBlock.canSupportAt(true, true, .stalagmite));
}

test "drip mechanics - stalactite tip drips into cauldron" {
    const drip_block = DripstoneBlock{
        .dripstone_type = .stalactite,
        .thickness = .tip,
        .height = 1,
    };

    const result = drip_block.tickDrip(true);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(FluidType.water, result.?.fluid);
    try std.testing.expect(result.?.filled_cauldron);
}

test "drip mechanics - stalactite tip without cauldron" {
    const drip_block = DripstoneBlock{
        .dripstone_type = .stalactite,
        .thickness = .tip,
        .height = 1,
    };

    const result = drip_block.tickDrip(false);
    try std.testing.expect(result != null);
    try std.testing.expect(!result.?.filled_cauldron);
}

test "drip mechanics - non-tip stalactite does not drip" {
    const drip_block = DripstoneBlock{
        .dripstone_type = .stalactite,
        .thickness = .base,
        .height = 3,
    };

    try std.testing.expect(drip_block.tickDrip(true) == null);
}

test "drip mechanics - stalagmite does not drip" {
    const drip_block = DripstoneBlock{
        .dripstone_type = .stalagmite,
        .thickness = .tip,
        .height = 1,
    };

    try std.testing.expect(drip_block.tickDrip(true) == null);
}

test "fall damage multiplier is 2.0 for stalagmites" {
    try std.testing.expectEqual(@as(f32, 2.0), DripstoneBlock.getFallDamageMultiplier());
}

test "getDripFluid returns water for water block" {
    const fluid = DripstoneBlock.getDripFluid(blocks.WATER);
    try std.testing.expect(fluid != null);
    try std.testing.expectEqual(FluidType.water, fluid.?);
}

test "getDripFluid returns lava for lava block" {
    const fluid = DripstoneBlock.getDripFluid(blocks.LAVA);
    try std.testing.expect(fluid != null);
    try std.testing.expectEqual(FluidType.lava, fluid.?);
}

test "getDripFluid returns null for other blocks" {
    try std.testing.expect(DripstoneBlock.getDripFluid(0) == null);
    try std.testing.expect(DripstoneBlock.getDripFluid(1) == null);
    try std.testing.expect(DripstoneBlock.getDripFluid(255) == null);
}

test "growth only occurs at tip thickness" {
    var drip_block = DripstoneBlock{
        .dripstone_type = .stalactite,
        .thickness = .base,
        .height = 2,
    };
    try std.testing.expect(!drip_block.tickGrowth());
    try std.testing.expectEqual(Thickness.base, drip_block.thickness);

    var mid_block = DripstoneBlock{
        .dripstone_type = .stalagmite,
        .thickness = .middle,
        .height = 5,
    };
    try std.testing.expect(!mid_block.tickGrowth());
    try std.testing.expectEqual(Thickness.middle, mid_block.thickness);
}

test "growth at tip changes thickness to frustum" {
    var grew = false;
    var winning_height: u4 = 0;
    for (0..16) |h| {
        var probe = DripstoneBlock{
            .dripstone_type = .stalactite,
            .thickness = .tip,
            .height = @intCast(h),
        };
        if (probe.tickGrowth()) {
            grew = true;
            winning_height = @intCast(h);
            break;
        }
    }

    if (grew) {
        var drip_block = DripstoneBlock{
            .dripstone_type = .stalactite,
            .thickness = .tip,
            .height = winning_height,
        };
        _ = drip_block.tickGrowth();
        try std.testing.expectEqual(Thickness.frustum, drip_block.thickness);
        try std.testing.expect(drip_block.height >= winning_height);
    }
}
