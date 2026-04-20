const std = @import("std");

pub const CauldronContent = enum {
    empty,
    water,
    lava,
    powder_snow,
};

pub const DripType = enum {
    water,
    lava,
};

pub const CauldronState = struct {
    content: CauldronContent,
    level: u2,

    pub fn init() CauldronState {
        return .{ .content = .empty, .level = 0 };
    }

    pub fn fillFromRain(self: *CauldronState) void {
        if (self.content == .empty or self.content == .water) {
            if (self.level < 3) {
                self.content = .water;
                self.level += 1;
            }
        }
    }

    pub fn fillFromDripstone(self: *CauldronState, drip_type: DripType) void {
        const target_content: CauldronContent = switch (drip_type) {
            .water => .water,
            .lava => .lava,
        };

        if (self.content == .empty) {
            self.content = target_content;
            self.level = 1;
        } else if (self.content == target_content and self.level < 3) {
            self.level += 1;
        }
    }

    /// Consume one level of water. Returns true if water was available.
    fn consumeWater(self: *CauldronState) bool {
        if (self.content == .water and self.level > 0) {
            self.level -= 1;
            if (self.level == 0) {
                self.content = .empty;
            }
            return true;
        }
        return false;
    }

    pub fn washDyedItem(self: *CauldronState) bool {
        return self.consumeWater();
    }

    pub fn extinguishEntity(self: *CauldronState) bool {
        return self.consumeWater();
    }

    pub fn addPotion(self: *CauldronState, potion_type: u8) void {
        _ = potion_type;
        self.content = .water;
        self.level = 3;
    }

    pub fn takeWater(self: *CauldronState) bool {
        return self.consumeWater();
    }

    pub fn getRedstoneOutput(self: CauldronState) u4 {
        return @as(u4, self.level);
    }
};

test "rain filling increments water level" {
    var cauldron = CauldronState.init();
    cauldron.fillFromRain();
    try std.testing.expectEqual(CauldronContent.water, cauldron.content);
    try std.testing.expectEqual(@as(u2, 1), cauldron.level);

    cauldron.fillFromRain();
    try std.testing.expectEqual(@as(u2, 2), cauldron.level);

    cauldron.fillFromRain();
    try std.testing.expectEqual(@as(u2, 3), cauldron.level);

    // Should not exceed 3
    cauldron.fillFromRain();
    try std.testing.expectEqual(@as(u2, 3), cauldron.level);
}

test "wash dyed item reduces water level" {
    var cauldron = CauldronState.init();
    cauldron.content = .water;
    cauldron.level = 2;

    const washed = cauldron.washDyedItem();
    try std.testing.expect(washed);
    try std.testing.expectEqual(@as(u2, 1), cauldron.level);

    // Wash again to empty
    const washed2 = cauldron.washDyedItem();
    try std.testing.expect(washed2);
    try std.testing.expectEqual(@as(u2, 0), cauldron.level);
    try std.testing.expectEqual(CauldronContent.empty, cauldron.content);

    // Cannot wash when empty
    const washed3 = cauldron.washDyedItem();
    try std.testing.expect(!washed3);
}

test "extinguish entity consumes water" {
    var cauldron = CauldronState.init();
    cauldron.content = .water;
    cauldron.level = 1;

    const extinguished = cauldron.extinguishEntity();
    try std.testing.expect(extinguished);
    try std.testing.expectEqual(@as(u2, 0), cauldron.level);
    try std.testing.expectEqual(CauldronContent.empty, cauldron.content);

    // Cannot extinguish when empty
    const extinguished2 = cauldron.extinguishEntity();
    try std.testing.expect(!extinguished2);
}

test "redstone output matches level" {
    var cauldron = CauldronState.init();
    try std.testing.expectEqual(@as(u4, 0), cauldron.getRedstoneOutput());

    cauldron.content = .water;
    cauldron.level = 1;
    try std.testing.expectEqual(@as(u4, 1), cauldron.getRedstoneOutput());

    cauldron.level = 2;
    try std.testing.expectEqual(@as(u4, 2), cauldron.getRedstoneOutput());

    cauldron.level = 3;
    try std.testing.expectEqual(@as(u4, 3), cauldron.getRedstoneOutput());
}

test "lava content via dripstone" {
    var cauldron = CauldronState.init();
    cauldron.fillFromDripstone(.lava);
    try std.testing.expectEqual(CauldronContent.lava, cauldron.content);
    try std.testing.expectEqual(@as(u2, 1), cauldron.level);

    cauldron.fillFromDripstone(.lava);
    try std.testing.expectEqual(@as(u2, 2), cauldron.level);

    // Lava cauldron should not allow washing
    const washed = cauldron.washDyedItem();
    try std.testing.expect(!washed);
}
