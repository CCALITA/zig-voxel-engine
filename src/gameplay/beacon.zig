/// Beacon system with tiered pyramid effects.
/// Supports pyramid tiers 0-4, each unlocking a wider range and
/// more powerful effects. Only depends on `std`.

const std = @import("std");

pub const MAX_TIER: u8 = 4;

pub const Effect = enum {
    speed,
    haste,
    regeneration,
    resistance,
    jump_boost,
    strength,
};

/// Effects available at each pyramid tier (cumulative).
/// Tier 1: speed, haste
/// Tier 2: resistance, jump_boost
/// Tier 3: strength
/// Tier 4: regeneration (secondary)
pub fn effectAvailableAtTier(effect: Effect, tier: u8) bool {
    return switch (effect) {
        .speed, .haste => tier >= 1,
        .resistance, .jump_boost => tier >= 2,
        .strength => tier >= 3,
        .regeneration => tier >= 4,
    };
}

/// Range in blocks for each pyramid tier.
pub fn getTierRange(tier: u8) u32 {
    return switch (tier) {
        1 => 20,
        2 => 30,
        3 => 40,
        4 => 50,
        else => 0,
    };
}

pub const BeaconState = struct {
    pyramid_tier: u8 = 0,
    selected_effect: ?Effect = null,

    pub fn init() BeaconState {
        return .{};
    }

    /// Whether the beacon has a valid pyramid (tier > 0).
    pub fn isActive(self: *const BeaconState) bool {
        return self.pyramid_tier > 0;
    }

    /// Validate and set the pyramid tier.
    pub fn checkPyramid(self: *BeaconState, tier: u8) void {
        self.pyramid_tier = @min(tier, MAX_TIER);

        // Clear selected effect if tier no longer supports it.
        if (self.selected_effect) |eff| {
            if (!effectAvailableAtTier(eff, self.pyramid_tier)) {
                self.selected_effect = null;
            }
        }
    }

    /// Select a beacon effect. Returns false if the effect is not
    /// available at the current tier.
    pub fn selectEffect(self: *BeaconState, effect: Effect) bool {
        if (!self.isActive()) return false;
        if (!effectAvailableAtTier(effect, self.pyramid_tier)) return false;
        self.selected_effect = effect;
        return true;
    }

    /// Get the active effect if a player at the given distance is in range.
    pub fn getActiveEffect(self: *const BeaconState, player_dist: f32) ?Effect {
        if (!self.isActive()) return null;
        if (self.selected_effect == null) return null;

        const range: f32 = @floatFromInt(getTierRange(self.pyramid_tier));
        if (player_dist <= range) {
            return self.selected_effect;
        }
        return null;
    }

    /// Get the range for the current tier.
    pub fn getRange(self: *const BeaconState) u32 {
        return getTierRange(self.pyramid_tier);
    }
};

/// Check if a position (px, pz) is within range of a beacon at (bx, bz).
/// Uses Chebyshev distance (square range area like Minecraft).
pub fn isInRange(px: i32, pz: i32, bx: i32, bz: i32, range: u32) bool {
    const dx: u32 = @intCast(@abs(px - bx));
    const dz: u32 = @intCast(@abs(pz - bz));
    return dx <= range and dz <= range;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "tier 0 has zero range and is inactive" {
    var beacon = BeaconState.init();
    beacon.checkPyramid(0);

    try std.testing.expect(!beacon.isActive());
    try std.testing.expectEqual(@as(u32, 0), beacon.getRange());
}

test "tier 1 range is 20" {
    var beacon = BeaconState.init();
    beacon.checkPyramid(1);

    try std.testing.expect(beacon.isActive());
    try std.testing.expectEqual(@as(u32, 20), beacon.getRange());
}

test "tier 2 range is 30" {
    var beacon = BeaconState.init();
    beacon.checkPyramid(2);
    try std.testing.expectEqual(@as(u32, 30), beacon.getRange());
}

test "tier 3 range is 40" {
    var beacon = BeaconState.init();
    beacon.checkPyramid(3);
    try std.testing.expectEqual(@as(u32, 40), beacon.getRange());
}

test "tier 4 range is 50" {
    var beacon = BeaconState.init();
    beacon.checkPyramid(4);
    try std.testing.expectEqual(@as(u32, 50), beacon.getRange());
}

test "tier clamped to max 4" {
    var beacon = BeaconState.init();
    beacon.checkPyramid(10);
    try std.testing.expectEqual(@as(u8, 4), beacon.pyramid_tier);
    try std.testing.expectEqual(@as(u32, 50), beacon.getRange());
}

test "select effect at tier 1" {
    var beacon = BeaconState.init();
    beacon.checkPyramid(1);

    try std.testing.expect(beacon.selectEffect(.speed));
    try std.testing.expect(beacon.selectEffect(.haste));
    try std.testing.expect(!beacon.selectEffect(.strength)); // needs tier 3
    try std.testing.expect(!beacon.selectEffect(.regeneration)); // needs tier 4
}

test "select effect at tier 4 allows all" {
    var beacon = BeaconState.init();
    beacon.checkPyramid(4);

    try std.testing.expect(beacon.selectEffect(.speed));
    try std.testing.expect(beacon.selectEffect(.haste));
    try std.testing.expect(beacon.selectEffect(.resistance));
    try std.testing.expect(beacon.selectEffect(.jump_boost));
    try std.testing.expect(beacon.selectEffect(.strength));
    try std.testing.expect(beacon.selectEffect(.regeneration));
}

test "select effect fails when inactive" {
    var beacon = BeaconState.init();
    try std.testing.expect(!beacon.selectEffect(.speed));
}

test "getActiveEffect returns effect when in range" {
    var beacon = BeaconState.init();
    beacon.checkPyramid(2);
    _ = beacon.selectEffect(.speed);

    try std.testing.expect(beacon.getActiveEffect(15.0) != null);
    try std.testing.expectEqual(Effect.speed, beacon.getActiveEffect(15.0).?);
}

test "getActiveEffect returns null when out of range" {
    var beacon = BeaconState.init();
    beacon.checkPyramid(1); // range 20
    _ = beacon.selectEffect(.speed);

    try std.testing.expect(beacon.getActiveEffect(25.0) == null);
}

test "getActiveEffect returns null when no effect selected" {
    var beacon = BeaconState.init();
    beacon.checkPyramid(3);

    try std.testing.expect(beacon.getActiveEffect(10.0) == null);
}

test "getActiveEffect returns null when inactive" {
    const beacon = BeaconState.init();
    try std.testing.expect(beacon.getActiveEffect(5.0) == null);
}

test "isInRange within range" {
    try std.testing.expect(isInRange(10, 10, 0, 0, 20));
    try std.testing.expect(isInRange(20, 20, 0, 0, 20));
    try std.testing.expect(isInRange(0, 0, 0, 0, 20));
}

test "isInRange out of range" {
    try std.testing.expect(!isInRange(21, 0, 0, 0, 20));
    try std.testing.expect(!isInRange(0, 21, 0, 0, 20));
    try std.testing.expect(!isInRange(25, 25, 0, 0, 20));
}

test "isInRange with negative coordinates" {
    try std.testing.expect(isInRange(-10, -10, 0, 0, 20));
    try std.testing.expect(!isInRange(-21, 0, 0, 0, 20));
}

test "isInRange zero range" {
    try std.testing.expect(isInRange(5, 5, 5, 5, 0));
    try std.testing.expect(!isInRange(5, 6, 5, 5, 0));
}

test "checkPyramid clears invalid effect on tier downgrade" {
    var beacon = BeaconState.init();
    beacon.checkPyramid(4);
    _ = beacon.selectEffect(.regeneration); // needs tier 4

    beacon.checkPyramid(2); // downgrade
    try std.testing.expect(beacon.selected_effect == null);
}
