const std = @import("std");

pub const SwimState = struct {
    in_water: bool = false,
    submerged_depth: f32 = 0,
    swim_speed: f32 = 0.02,

    const swim_up_vy: f32 = 0.04;
    const sink_vy: f32 = -0.02;
    const base_water_speed_mult: f32 = 0.8;
    const depth_strider_bonus_per_level: f32 = 1.0 / 3.0;

    pub fn init() SwimState {
        return .{};
    }

    /// Update swim state based on player position relative to water surface.
    /// Returns vertical velocity and horizontal speed multiplier.
    pub fn update(
        self: *SwimState,
        player_y: f32,
        water_surface_y: f32,
        space_pressed: bool,
        dt: f32,
    ) struct { vy: f32, speed_mult: f32 } {
        _ = dt;
        self.submerged_depth = water_surface_y - player_y;
        self.in_water = self.submerged_depth > 0;

        if (!self.in_water) {
            return .{ .vy = 0, .speed_mult = 1.0 };
        }

        const vy: f32 = if (space_pressed) swim_up_vy else sink_vy;
        return .{ .vy = vy, .speed_mult = base_water_speed_mult };
    }

    /// Get vertical velocity for swimming: space = swim up, otherwise sink.
    pub fn getSwimVelocity(space: bool, depth_strider: u8) f32 {
        _ = depth_strider;
        return if (space) swim_up_vy else sink_vy;
    }

    /// Get horizontal speed multiplier in water, improved by Depth Strider enchantment.
    /// Each level adds +33% of the lost speed back (base 0.8x).
    pub fn getWaterSpeedMultiplier(depth_strider: u8) f32 {
        const level_f: f32 = @floatFromInt(@min(depth_strider, 3));
        return base_water_speed_mult + (1.0 - base_water_speed_mult) * level_f * depth_strider_bonus_per_level;
    }

    /// Returns true when the player is below the water surface.
    pub fn isSubmerged(self: SwimState) bool {
        return self.submerged_depth > 0;
    }
};

// ──────────────────────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────────────────────

test "init returns default state" {
    const s = SwimState.init();
    try std.testing.expect(!s.in_water);
    try std.testing.expectEqual(@as(f32, 0), s.submerged_depth);
    try std.testing.expectEqual(@as(f32, 0.02), s.swim_speed);
}

test "update above water returns neutral values" {
    var s = SwimState.init();
    const result = s.update(10.0, 5.0, false, 0.016);
    try std.testing.expectEqual(@as(f32, 0), result.vy);
    try std.testing.expectEqual(@as(f32, 1.0), result.speed_mult);
    try std.testing.expect(!s.in_water);
}

test "update in water without space sinks" {
    var s = SwimState.init();
    const result = s.update(3.0, 5.0, false, 0.016);
    try std.testing.expectEqual(@as(f32, -0.02), result.vy);
    try std.testing.expectEqual(@as(f32, 0.8), result.speed_mult);
    try std.testing.expect(s.in_water);
}

test "update in water with space swims up" {
    var s = SwimState.init();
    const result = s.update(3.0, 5.0, true, 0.016);
    try std.testing.expectEqual(@as(f32, 0.04), result.vy);
    try std.testing.expectEqual(@as(f32, 0.8), result.speed_mult);
}

test "submerged depth is calculated correctly" {
    var s = SwimState.init();
    _ = s.update(2.0, 5.0, false, 0.016);
    try std.testing.expectEqual(@as(f32, 3.0), s.submerged_depth);
}

test "isSubmerged returns true when underwater" {
    var s = SwimState.init();
    _ = s.update(2.0, 5.0, false, 0.016);
    try std.testing.expect(s.isSubmerged());
}

test "isSubmerged returns false when above water" {
    var s = SwimState.init();
    _ = s.update(10.0, 5.0, false, 0.016);
    try std.testing.expect(!s.isSubmerged());
}

test "getSwimVelocity space pressed returns positive" {
    const vy = SwimState.getSwimVelocity(true, 0);
    try std.testing.expectEqual(@as(f32, 0.04), vy);
}

test "getSwimVelocity no space returns negative" {
    const vy = SwimState.getSwimVelocity(false, 0);
    try std.testing.expectEqual(@as(f32, -0.02), vy);
}

test "getWaterSpeedMultiplier with no enchant returns 0.8" {
    const mult = SwimState.getWaterSpeedMultiplier(0);
    try std.testing.expectEqual(@as(f32, 0.8), mult);
}

test "depth strider level 1 adds 33% of lost speed" {
    const mult = SwimState.getWaterSpeedMultiplier(1);
    const expected: f32 = 0.8 + 0.2 * (1.0 / 3.0);
    try std.testing.expectApproxEqAbs(expected, mult, 0.001);
}

test "depth strider level 2 adds 67% of lost speed" {
    const mult = SwimState.getWaterSpeedMultiplier(2);
    const expected: f32 = 0.8 + 0.2 * (2.0 / 3.0);
    try std.testing.expectApproxEqAbs(expected, mult, 0.001);
}

test "depth strider level 3 restores full speed" {
    const mult = SwimState.getWaterSpeedMultiplier(3);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), mult, 0.001);
}

test "depth strider capped at level 3" {
    const mult = SwimState.getWaterSpeedMultiplier(5);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), mult, 0.001);
}

test "leaving water resets in_water flag" {
    var s = SwimState.init();
    _ = s.update(2.0, 5.0, false, 0.016);
    try std.testing.expect(s.in_water);
    _ = s.update(10.0, 5.0, false, 0.016);
    try std.testing.expect(!s.in_water);
}

test "at water surface boundary is not submerged" {
    var s = SwimState.init();
    _ = s.update(5.0, 5.0, false, 0.016);
    try std.testing.expect(!s.isSubmerged());
    try std.testing.expect(!s.in_water);
}
