const std = @import("std");
const math = std.math;

pub const LodestoneCompass = struct {
    linked: bool = false,
    lodestone_x: i32 = 0,
    lodestone_y: i32 = 0,
    lodestone_z: i32 = 0,
    lodestone_dimension: u8 = 0,

    pub fn linkToLodestone(self: *LodestoneCompass, x: i32, y: i32, z: i32, dimension: u8) void {
        self.linked = true;
        self.lodestone_x = x;
        self.lodestone_y = y;
        self.lodestone_z = z;
        self.lodestone_dimension = dimension;
    }

    pub fn getDirection(self: LodestoneCompass, player_x: f32, player_z: f32) f32 {
        const dx = @as(f32, @floatFromInt(self.lodestone_x)) - player_x;
        const dz = @as(f32, @floatFromInt(self.lodestone_z)) - player_z;
        return math.atan2(dz, dx);
    }

    pub fn isLinked(self: LodestoneCompass) bool {
        return self.linked;
    }

    pub fn isInSameDimension(self: LodestoneCompass, current_dim: u8) bool {
        return self.lodestone_dimension == current_dim;
    }
};

pub const RecoveryCompass = struct {
    death_x: ?i32 = null,
    death_y: ?i32 = null,
    death_z: ?i32 = null,
    death_dimension: ?u8 = null,

    pub fn recordDeath(self: *RecoveryCompass, x: i32, y: i32, z: i32, dim: u8) void {
        self.death_x = x;
        self.death_y = y;
        self.death_z = z;
        self.death_dimension = dim;
    }

    pub fn getDirection(self: RecoveryCompass, player_x: f32, player_z: f32) ?f32 {
        if (!self.hasDeathLocation()) return null;
        const fdx = @as(f32, @floatFromInt(self.death_x.?)) - player_x;
        const fdz = @as(f32, @floatFromInt(self.death_z.?)) - player_z;
        return math.atan2(fdz, fdx);
    }

    pub fn hasDeathLocation(self: RecoveryCompass) bool {
        return self.death_x != null and self.death_y != null and self.death_z != null and self.death_dimension != null;
    }
};

test "lodestone compass linking" {
    var compass = LodestoneCompass{};
    try std.testing.expect(!compass.isLinked());

    compass.linkToLodestone(100, 64, -200, 0);
    try std.testing.expect(compass.isLinked());
    try std.testing.expectEqual(@as(i32, 100), compass.lodestone_x);
    try std.testing.expectEqual(@as(i32, 64), compass.lodestone_y);
    try std.testing.expectEqual(@as(i32, -200), compass.lodestone_z);
    try std.testing.expectEqual(@as(u8, 0), compass.lodestone_dimension);
}

test "lodestone compass direction calculation" {
    var compass = LodestoneCompass{};
    compass.linkToLodestone(100, 64, 0, 0);

    // Player at origin, lodestone at (100, 64, 0) => angle should be 0 (east)
    const angle = compass.getDirection(0.0, 0.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), angle, 0.001);
}

test "lodestone compass cross-dimension spin" {
    var compass = LodestoneCompass{};
    compass.linkToLodestone(100, 64, -200, 0);

    // Same dimension
    try std.testing.expect(compass.isInSameDimension(0));
    // Different dimension => would spin randomly
    try std.testing.expect(!compass.isInSameDimension(1));
    try std.testing.expect(!compass.isInSameDimension(2));
}

test "recovery compass death recording" {
    var compass = RecoveryCompass{};
    try std.testing.expect(!compass.hasDeathLocation());

    compass.recordDeath(50, 30, -100, 0);
    try std.testing.expect(compass.hasDeathLocation());
    try std.testing.expectEqual(@as(i32, 50), compass.death_x.?);
    try std.testing.expectEqual(@as(i32, 30), compass.death_y.?);
    try std.testing.expectEqual(@as(i32, -100), compass.death_z.?);
    try std.testing.expectEqual(@as(u8, 0), compass.death_dimension.?);
}

test "recovery compass no death returns null" {
    const compass = RecoveryCompass{};
    const direction = compass.getDirection(10.0, 20.0);
    try std.testing.expect(direction == null);
}

test "recovery compass direction after death" {
    var compass = RecoveryCompass{};
    compass.recordDeath(100, 64, 0, 0);

    const direction = compass.getDirection(0.0, 0.0);
    try std.testing.expect(direction != null);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), direction.?, 0.001);
}
