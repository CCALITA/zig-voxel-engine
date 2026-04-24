const std = @import("std");

pub const CLIMB_SPEED: f32 = 0.1;

const WATER_BLOCK_ID: u16 = 8;
const LAVA_BLOCK_ID: u16 = 32;

/// Wall face indices used by `ClimbState.wall_face`.
pub const FACE_NORTH: u3 = 0;
pub const FACE_SOUTH: u3 = 1;
pub const FACE_EAST: u3 = 2;
pub const FACE_WEST: u3 = 3;

/// Tracks whether a spider-like entity is climbing a wall and which face it is attached to.
pub const ClimbState = struct {
    is_climbing: bool = false,
    wall_face: ?u3 = null,

    /// Set `wall_face` to the first adjacent solid face in N/S/E/W order.
    /// When no solid face is adjacent, clear both `wall_face` and `is_climbing`.
    pub fn detectWall(self: *ClimbState, n: bool, s: bool, e: bool, w: bool) void {
        if (n) {
            self.wall_face = FACE_NORTH;
            self.is_climbing = true;
        } else if (s) {
            self.wall_face = FACE_SOUTH;
            self.is_climbing = true;
        } else if (e) {
            self.wall_face = FACE_EAST;
            self.is_climbing = true;
        } else if (w) {
            self.wall_face = FACE_WEST;
            self.is_climbing = true;
        } else {
            self.wall_face = null;
            self.is_climbing = false;
        }
    }

    /// Vertical climbing velocity in blocks per tick.
    pub fn getClimbVelocity(self: ClimbState) f32 {
        return if (self.is_climbing) CLIMB_SPEED else 0.0;
    }

    /// True when the entity is latched onto a wall face.
    pub fn isOnWall(self: ClimbState) bool {
        return self.wall_face != null;
    }
};

/// Returns true when the given block id is climbable. Water and lava are not climbable.
pub fn canClimb(block_id: u16) bool {
    return block_id != WATER_BLOCK_ID and block_id != LAVA_BLOCK_ID;
}

test "ClimbState default is not climbing" {
    const s = ClimbState{};
    try std.testing.expect(!s.is_climbing);
    try std.testing.expect(s.wall_face == null);
    try std.testing.expect(!s.isOnWall());
}

test "detectWall picks north first" {
    var s = ClimbState{};
    s.detectWall(true, true, true, true);
    try std.testing.expectEqual(@as(?u3, FACE_NORTH), s.wall_face);
    try std.testing.expect(s.is_climbing);
}

test "detectWall picks south when no north" {
    var s = ClimbState{};
    s.detectWall(false, true, true, true);
    try std.testing.expectEqual(@as(?u3, FACE_SOUTH), s.wall_face);
}

test "detectWall picks east when only east/west" {
    var s = ClimbState{};
    s.detectWall(false, false, true, true);
    try std.testing.expectEqual(@as(?u3, FACE_EAST), s.wall_face);
}

test "detectWall picks west when only west" {
    var s = ClimbState{};
    s.detectWall(false, false, false, true);
    try std.testing.expectEqual(@as(?u3, FACE_WEST), s.wall_face);
}

test "detectWall clears state when no adjacent solid" {
    var s = ClimbState{ .is_climbing = true, .wall_face = FACE_NORTH };
    s.detectWall(false, false, false, false);
    try std.testing.expect(s.wall_face == null);
    try std.testing.expect(!s.is_climbing);
}

test "getClimbVelocity returns CLIMB_SPEED when climbing" {
    const s = ClimbState{ .is_climbing = true, .wall_face = FACE_NORTH };
    try std.testing.expectEqual(@as(f32, 0.1), s.getClimbVelocity());
    try std.testing.expectEqual(CLIMB_SPEED, s.getClimbVelocity());
}

test "getClimbVelocity returns zero when not climbing" {
    const s = ClimbState{};
    try std.testing.expectEqual(@as(f32, 0.0), s.getClimbVelocity());
}

test "isOnWall reflects wall_face presence" {
    var s = ClimbState{};
    try std.testing.expect(!s.isOnWall());
    s.wall_face = FACE_EAST;
    try std.testing.expect(s.isOnWall());
}

test "canClimb rejects water" {
    try std.testing.expect(!canClimb(WATER_BLOCK_ID));
    try std.testing.expect(!canClimb(8));
}

test "canClimb rejects lava" {
    try std.testing.expect(!canClimb(LAVA_BLOCK_ID));
    try std.testing.expect(!canClimb(32));
}

test "canClimb accepts stone and other solids" {
    try std.testing.expect(canClimb(1));
    try std.testing.expect(canClimb(2));
    try std.testing.expect(canClimb(100));
    try std.testing.expect(canClimb(0));
}

test "CLIMB_SPEED is 0.1" {
    try std.testing.expectEqual(@as(f32, 0.1), CLIMB_SPEED);
}

test "detectWall sequence transitions" {
    var s = ClimbState{};
    s.detectWall(true, false, false, false);
    try std.testing.expectEqual(@as(?u3, FACE_NORTH), s.wall_face);
    s.detectWall(false, false, true, false);
    try std.testing.expectEqual(@as(?u3, FACE_EAST), s.wall_face);
    s.detectWall(false, false, false, false);
    try std.testing.expect(s.wall_face == null);
    try std.testing.expect(!s.is_climbing);
}
