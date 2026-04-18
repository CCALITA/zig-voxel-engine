/// Beacon block system: provides area-of-effect status buffs based on
/// pyramid tier level (1-4). Higher tiers unlock stronger effects and
/// wider radius.

const std = @import("std");

pub const BeaconTier = enum(u8) {
    none = 0,
    tier1 = 1,
    tier2 = 2,
    tier3 = 3,
    tier4 = 4,
};

pub const BeaconEffect = enum {
    speed,
    haste,
    resistance,
    jump_boost,
    strength,
    regeneration,
};

pub const BeaconState = struct {
    tier: BeaconTier,
    primary_effect: ?BeaconEffect,
    secondary_effect: ?BeaconEffect,

    pub fn init() BeaconState {
        return .{
            .tier = .none,
            .primary_effect = null,
            .secondary_effect = null,
        };
    }

    /// Set the pyramid tier (call after scanning the pyramid beneath).
    pub fn setTier(self: *BeaconState, tier: BeaconTier) void {
        self.tier = tier;
        // Clear effects that are no longer available at the new tier
        if (@intFromEnum(tier) < 3) {
            self.secondary_effect = null;
        }
    }

    /// Get the effect radius in blocks for the current tier.
    pub fn getRadius(self: *const BeaconState) f32 {
        return switch (self.tier) {
            .none => 0.0,
            .tier1 => 20.0,
            .tier2 => 30.0,
            .tier3 => 40.0,
            .tier4 => 50.0,
        };
    }

    /// Check whether a player at (px, pz) is within the beacon's effect range.
    pub fn isInRange(self: *const BeaconState, beacon_x: f32, beacon_z: f32, player_x: f32, player_z: f32) bool {
        const radius = self.getRadius();
        if (radius <= 0) return false;
        const dx = player_x - beacon_x;
        const dz = player_z - beacon_z;
        return (dx * dx + dz * dz) <= (radius * radius);
    }
};

// ──────────────────────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────────────────────

test "init starts with no tier" {
    const b = BeaconState.init();
    try std.testing.expectEqual(BeaconTier.none, b.tier);
    try std.testing.expect(b.primary_effect == null);
}

test "getRadius scales with tier" {
    var b = BeaconState.init();
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), b.getRadius(), 0.001);
    b.setTier(.tier1);
    try std.testing.expectApproxEqAbs(@as(f32, 20.0), b.getRadius(), 0.001);
    b.setTier(.tier4);
    try std.testing.expectApproxEqAbs(@as(f32, 50.0), b.getRadius(), 0.001);
}

test "isInRange checks distance" {
    var b = BeaconState.init();
    b.setTier(.tier1); // radius 20
    try std.testing.expect(b.isInRange(0, 0, 10, 10));
    try std.testing.expect(!b.isInRange(0, 0, 100, 100));
}

test "setTier clears secondary below tier3" {
    var b = BeaconState.init();
    b.setTier(.tier4);
    b.secondary_effect = .regeneration;
    b.setTier(.tier2);
    try std.testing.expect(b.secondary_effect == null);
}
