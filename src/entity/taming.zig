/// Taming mechanics for wolves, cats, and horses.
/// Wolves are tamed with bones (1/3 chance), cats with raw fish (1/3 chance),
/// and horses by repeated mounting that accumulates temper until >= 100.
/// Tamed animals can sit, follow their owner, and have type-specific behaviors:
/// - Wolves attack the owner's target and have a dyeable collar.
/// - Cats scare creepers within 6 blocks.
/// - Horses are ridden once tamed.
const std = @import("std");

pub const TamableType = enum {
    wolf,
    cat,
    horse,
};

/// Item IDs for taming consumables.
pub const ITEM_BONE: u16 = 201;
pub const ITEM_RAW_FISH: u16 = 266;

/// Per-type taming chance (wolf and cat use flat probability; horse uses temper).
pub fn getTameChance(tamable_type: TamableType) f32 {
    return switch (tamable_type) {
        .wolf => 1.0 / 3.0,
        .cat => 1.0 / 3.0,
        .horse => 0.0, // horse taming is temper-based, not chance-based
    };
}

/// Returns the item required to tame the given type (horse has no item).
pub fn getTameItem(tamable_type: TamableType) u16 {
    return switch (tamable_type) {
        .wolf => ITEM_BONE,
        .cat => ITEM_RAW_FISH,
        .horse => 0, // horse uses mounting, not an item
    };
}

pub const TamingState = struct {
    tamable_type: TamableType,
    tamed: bool,
    owner_id: u32,
    sitting: bool,
    temper: u8, // horse: 0-100, tame when >= 100
    trust: u8, // cat: 0-100
    collar_color: u8, // wolf: 0-15 (dye colors)

    /// Internal PRNG counter for deterministic randomness in tests.
    rng_state: u64,

    pub fn init(tamable_type: TamableType) TamingState {
        return .{
            .tamable_type = tamable_type,
            .tamed = false,
            .owner_id = 0,
            .sitting = false,
            .temper = 0,
            .trust = 0,
            .collar_color = 14, // default red collar for wolves
            .rng_state = 0,
        };
    }

    /// Attempt to tame with the given item, owned by `owner`.
    /// For wolf/cat: consumes the correct item and rolls a 1/3 chance.
    /// For horse: call with item_id = 0 to simulate a mount attempt,
    /// which adds 5-15 temper and tames at >= 100.
    /// Returns true if the animal became tamed on this attempt.
    pub fn attemptTame(self: *TamingState, item_id: u16, owner: u32) bool {
        if (self.tamed) return false;

        const succeeded = switch (self.tamable_type) {
            .wolf, .cat => blk: {
                if (item_id != getTameItem(self.tamable_type)) break :blk false;
                break :blk self.rollChance(getTameChance(self.tamable_type));
            },
            .horse => blk: {
                const increment = self.randomRange(5, 15);
                const new_temper = @as(u16, self.temper) + increment;
                self.temper = @intCast(@min(new_temper, 100));
                break :blk self.temper >= 100;
            },
        };

        if (succeeded) {
            self.tamed = true;
            self.owner_id = owner;
        }
        return succeeded;
    }

    /// Toggle sitting state. Only works for tamed wolves and cats.
    pub fn toggleSit(self: *TamingState) void {
        if (!self.tamed) return;
        if (self.tamable_type == .horse) return; // horses don't sit
        self.sitting = !self.sitting;
    }

    /// Returns whether this animal has been tamed.
    pub fn isTamed(self: *const TamingState) bool {
        return self.tamed;
    }

    /// Maximum follow distance in blocks. Tamed animals follow their owner
    /// within this range. Sitting animals do not follow (returns 0).
    pub fn getFollowDistance(self: *const TamingState) f32 {
        if (!self.tamed) return 0;
        if (self.sitting) return 0;
        return switch (self.tamable_type) {
            .wolf => 10.0,
            .cat => 10.0,
            .horse => 0, // horses are ridden, not followed
        };
    }

    /// Returns the creeper scare radius for cats, 0 for other types.
    pub fn getCreeperScareRadius(self: *const TamingState) f32 {
        if (!self.tamed) return 0;
        if (self.tamable_type == .cat) return 6.0;
        return 0;
    }

    // -- Internal RNG helpers ------------------------------------------------

    fn nextRandom(self: *TamingState) u64 {
        // splitmix64 step
        self.rng_state +%= 0x9e3779b97f4a7c15;
        var z = self.rng_state;
        z = (z ^ (z >> 30)) *% 0xbf58476d1ce4e5b9;
        z = (z ^ (z >> 27)) *% 0x94d049bb133111eb;
        return z ^ (z >> 31);
    }

    fn rollChance(self: *TamingState, chance: f32) bool {
        const r = self.nextRandom();
        const t: f32 = @as(f32, @floatFromInt(r % 10000)) / 10000.0;
        return t < chance;
    }

    fn randomRange(self: *TamingState, min: u8, max: u8) u8 {
        const r = self.nextRandom();
        const span: u8 = max - min + 1;
        return min + @as(u8, @intCast(r % span));
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "init creates untamed state" {
    const state = TamingState.init(.wolf);
    try std.testing.expect(!state.tamed);
    try std.testing.expect(!state.sitting);
    try std.testing.expectEqual(@as(u32, 0), state.owner_id);
    try std.testing.expectEqual(@as(u8, 14), state.collar_color);
}

test "init cat starts untamed with zero trust" {
    const state = TamingState.init(.cat);
    try std.testing.expect(!state.tamed);
    try std.testing.expectEqual(@as(u8, 0), state.trust);
}

test "init horse starts with zero temper" {
    const state = TamingState.init(.horse);
    try std.testing.expect(!state.tamed);
    try std.testing.expectEqual(@as(u8, 0), state.temper);
}

test "getTameItem returns bone for wolf" {
    try std.testing.expectEqual(ITEM_BONE, getTameItem(.wolf));
}

test "getTameItem returns raw fish for cat" {
    try std.testing.expectEqual(ITEM_RAW_FISH, getTameItem(.cat));
}

test "getTameChance wolf is one third" {
    try std.testing.expectApproxEqAbs(@as(f32, 1.0 / 3.0), getTameChance(.wolf), 0.001);
}

test "getTameChance cat is one third" {
    try std.testing.expectApproxEqAbs(@as(f32, 1.0 / 3.0), getTameChance(.cat), 0.001);
}

test "wolf rejects wrong item" {
    var state = TamingState.init(.wolf);
    const result = state.attemptTame(999, 1);
    try std.testing.expect(!result);
    try std.testing.expect(!state.tamed);
}

test "cat rejects wrong item" {
    var state = TamingState.init(.cat);
    const result = state.attemptTame(ITEM_BONE, 1);
    try std.testing.expect(!result);
    try std.testing.expect(!state.tamed);
}

test "wolf tame with bone eventually succeeds" {
    var state = TamingState.init(.wolf);
    var tamed = false;
    var attempts: u32 = 0;
    while (attempts < 1000) : (attempts += 1) {
        if (state.attemptTame(ITEM_BONE, 42)) {
            tamed = true;
            break;
        }
    }
    try std.testing.expect(tamed);
    try std.testing.expect(state.isTamed());
    try std.testing.expectEqual(@as(u32, 42), state.owner_id);
}

test "cat tame with raw fish eventually succeeds" {
    var state = TamingState.init(.cat);
    var tamed = false;
    var attempts: u32 = 0;
    while (attempts < 1000) : (attempts += 1) {
        if (state.attemptTame(ITEM_RAW_FISH, 7)) {
            tamed = true;
            break;
        }
    }
    try std.testing.expect(tamed);
    try std.testing.expect(state.isTamed());
    try std.testing.expectEqual(@as(u32, 7), state.owner_id);
}

test "already tamed returns false" {
    var state = TamingState.init(.wolf);
    // Force tame.
    state.tamed = true;
    state.owner_id = 1;
    const result = state.attemptTame(ITEM_BONE, 2);
    try std.testing.expect(!result);
    // Owner should remain 1.
    try std.testing.expectEqual(@as(u32, 1), state.owner_id);
}

test "toggleSit works for tamed wolf" {
    var state = TamingState.init(.wolf);
    state.tamed = true;
    state.owner_id = 1;

    try std.testing.expect(!state.sitting);
    state.toggleSit();
    try std.testing.expect(state.sitting);
    state.toggleSit();
    try std.testing.expect(!state.sitting);
}

test "toggleSit is no-op for untamed wolf" {
    var state = TamingState.init(.wolf);
    state.toggleSit();
    try std.testing.expect(!state.sitting);
}

test "toggleSit is no-op for horse" {
    var state = TamingState.init(.horse);
    state.tamed = true;
    state.owner_id = 1;
    state.toggleSit();
    try std.testing.expect(!state.sitting);
}

test "follow distance is 10 for tamed wolf" {
    var state = TamingState.init(.wolf);
    state.tamed = true;
    state.owner_id = 1;
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), state.getFollowDistance(), 0.001);
}

test "follow distance is 0 for untamed" {
    const state = TamingState.init(.wolf);
    try std.testing.expectApproxEqAbs(@as(f32, 0), state.getFollowDistance(), 0.001);
}

test "follow distance is 0 when sitting" {
    var state = TamingState.init(.cat);
    state.tamed = true;
    state.owner_id = 1;
    state.sitting = true;
    try std.testing.expectApproxEqAbs(@as(f32, 0), state.getFollowDistance(), 0.001);
}

test "horse temper accumulates across mounts" {
    var state = TamingState.init(.horse);
    var attempts: u32 = 0;

    // Each mount adds 5-15 temper. At worst (5 per mount), 20 attempts suffice.
    while (attempts < 20 and !state.tamed) : (attempts += 1) {
        const before = state.temper;
        _ = state.attemptTame(0, 10);
        const added = state.temper - before;
        // Each raw increment is 5-15; the capped result may be smaller on the
        // final mount when temper approaches 100.
        if (state.temper < 100) {
            try std.testing.expect(added >= 5);
            try std.testing.expect(added <= 15);
        }
    }

    try std.testing.expect(state.tamed);
    try std.testing.expectEqual(@as(u8, 100), state.temper);
    try std.testing.expectEqual(@as(u32, 10), state.owner_id);
    // Should take multiple mounts (at least 7 at max increment of 15).
    try std.testing.expect(attempts >= 7);
}

test "horse temper caps at 100" {
    var state = TamingState.init(.horse);
    state.temper = 95;
    _ = state.attemptTame(0, 5);
    try std.testing.expectEqual(@as(u8, 100), state.temper);
    try std.testing.expect(state.tamed);
}

test "cat creeper scare radius" {
    var state = TamingState.init(.cat);
    // Untamed cat does not scare.
    try std.testing.expectApproxEqAbs(@as(f32, 0), state.getCreeperScareRadius(), 0.001);
    // Tame the cat.
    state.tamed = true;
    state.owner_id = 1;
    try std.testing.expectApproxEqAbs(@as(f32, 6.0), state.getCreeperScareRadius(), 0.001);
}

test "wolf has no creeper scare radius" {
    var state = TamingState.init(.wolf);
    state.tamed = true;
    state.owner_id = 1;
    try std.testing.expectApproxEqAbs(@as(f32, 0), state.getCreeperScareRadius(), 0.001);
}

test "tame chance statistical distribution for wolf" {
    // Run many trials and verify the success rate is roughly 1/3.
    var successes: u32 = 0;
    const trials: u32 = 3000;
    var i: u32 = 0;
    while (i < trials) : (i += 1) {
        var state = TamingState.init(.wolf);
        state.rng_state = @as(u64, i) * 7919;
        if (state.attemptTame(ITEM_BONE, 1)) {
            successes += 1;
        }
    }
    // Expected ~1000 successes out of 3000. Allow generous margin.
    const rate: f32 = @as(f32, @floatFromInt(successes)) / @as(f32, @floatFromInt(trials));
    try std.testing.expect(rate > 0.2);
    try std.testing.expect(rate < 0.5);
}
