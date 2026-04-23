const std = @import("std");

pub const CLIMB_SPEED: f32 = 0.1;

const BLOCK_WATER: u16 = 10;
const BLOCK_LAVA: u16 = 32;

/// Wall face indices the spider can be attached to.
/// 0 = north, 1 = south, 2 = east, 3 = west.
pub const ClimbState = struct {
    is_climbing: bool = false,
    wall_face: ?u3 = null,

    /// Detect the first adjacent solid face (in N, S, E, W order) and update
    /// the climb state accordingly. If none of the directions has a solid
    /// neighbor, climbing stops and `wall_face` is cleared.
    pub fn detectWall(
        self: *ClimbState,
        has_north: bool,
        has_south: bool,
        has_east: bool,
        has_west: bool,
    ) void {
        if (has_north) {
            self.wall_face = 0;
            self.is_climbing = true;
        } else if (has_south) {
            self.wall_face = 1;
            self.is_climbing = true;
        } else if (has_east) {
            self.wall_face = 2;
            self.is_climbing = true;
        } else if (has_west) {
            self.wall_face = 3;
            self.is_climbing = true;
        } else {
            self.wall_face = null;
            self.is_climbing = false;
        }
    }

    /// Vertical climb velocity in blocks/tick.
    pub fn getClimbVelocity(self: ClimbState) f32 {
        return if (self.is_climbing) CLIMB_SPEED else 0;
    }

    /// Returns true when the spider is currently attached to a wall.
    pub fn isOnWall(self: ClimbState) bool {
        return self.is_climbing and self.wall_face != null;
    }
};

/// Spiders cannot climb when submerged in water or lava.
pub fn canClimb(block_at_spider: u16) bool {
    return block_at_spider != BLOCK_WATER and block_at_spider != BLOCK_LAVA;
}

test "default ClimbState is idle" {
    const s = ClimbState{};
    try std.testing.expect(!s.is_climbing);
    try std.testing.expect(s.wall_face == null);
    try std.testing.expect(!s.isOnWall());
}

test "detectWall picks north first" {
    var s = ClimbState{};
    s.detectWall(true, true, true, true);
    try std.testing.expectEqual(@as(?u3, 0), s.wall_face);
    try std.testing.expect(s.is_climbing);
}

test "detectWall picks south when no north" {
    var s = ClimbState{};
    s.detectWall(false, true, true, true);
    try std.testing.expectEqual(@as(?u3, 1), s.wall_face);
    try std.testing.expect(s.is_climbing);
}

test "detectWall picks east when no north or south" {
    var s = ClimbState{};
    s.detectWall(false, false, true, true);
    try std.testing.expectEqual(@as(?u3, 2), s.wall_face);
}

test "detectWall picks west as last resort" {
    var s = ClimbState{};
    s.detectWall(false, false, false, true);
    try std.testing.expectEqual(@as(?u3, 3), s.wall_face);
    try std.testing.expect(s.is_climbing);
}

test "detectWall clears state when no walls present" {
    var s = ClimbState{ .is_climbing = true, .wall_face = 2 };
    s.detectWall(false, false, false, false);
    try std.testing.expect(s.wall_face == null);
    try std.testing.expect(!s.is_climbing);
    try std.testing.expect(!s.isOnWall());
}

test "getClimbVelocity is CLIMB_SPEED while climbing" {
    const s = ClimbState{ .is_climbing = true, .wall_face = 0 };
    try std.testing.expectEqual(@as(f32, 0.1), s.getClimbVelocity());
    try std.testing.expectEqual(CLIMB_SPEED, s.getClimbVelocity());
}

test "getClimbVelocity is zero when not climbing" {
    const s = ClimbState{};
    try std.testing.expectEqual(@as(f32, 0), s.getClimbVelocity());
}

test "isOnWall reflects climbing + wall_face" {
    var s = ClimbState{ .is_climbing = true, .wall_face = 0 };
    try std.testing.expect(s.isOnWall());
    s.is_climbing = false;
    try std.testing.expect(!s.isOnWall());
}

test "canClimb in air" {
    try std.testing.expect(canClimb(0));
}

test "canClimb in stone" {
    try std.testing.expect(canClimb(1));
}

test "canClimb is false in water" {
    try std.testing.expect(!canClimb(BLOCK_WATER));
}

test "canClimb is false in lava" {
    try std.testing.expect(!canClimb(BLOCK_LAVA));
}

test "CLIMB_SPEED constant value" {
    try std.testing.expectEqual(@as(f32, 0.1), CLIMB_SPEED);
}

test "detectWall transitions from one face to another" {
    var s = ClimbState{};
    s.detectWall(true, false, false, false);
    try std.testing.expectEqual(@as(?u3, 0), s.wall_face);
    s.detectWall(false, false, true, false);
    try std.testing.expectEqual(@as(?u3, 2), s.wall_face);
    try std.testing.expect(s.is_climbing);
}
