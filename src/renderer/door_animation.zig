const std = @import("std");

/// Animation state for a door that swings open and closed.
/// The angle lerps toward the target at `rotation_speed` degrees per second.
pub const DoorAnim = struct {
    /// Current angle in degrees.
    angle: f32 = 0,
    /// Target angle in degrees (0 = closed, 90 = open).
    target: f32 = 0,
    /// Whether the door is logically open.
    is_open: bool = false,

    /// Rotation speed in degrees per second.
    const rotation_speed: f32 = 360.0;
    /// Tolerance for snapping to the target.
    const epsilon: f32 = 0.01;

    /// Begin opening the door.
    pub fn open(self: *DoorAnim) void {
        self.target = 90;
        self.is_open = true;
    }

    /// Begin closing the door.
    pub fn close(self: *DoorAnim) void {
        self.target = 0;
        self.is_open = false;
    }

    /// Advance the animation by `dt` seconds, lerping toward the target.
    pub fn update(self: *DoorAnim, dt: f32) void {
        const diff = self.target - self.angle;
        if (@abs(diff) < epsilon) {
            self.angle = self.target;
            return;
        }
        const max_step = rotation_speed * dt;
        if (@abs(diff) <= max_step) {
            self.angle = self.target;
        } else if (diff > 0) {
            self.angle += max_step;
        } else {
            self.angle -= max_step;
        }
    }

    /// Return the current angle in degrees.
    pub fn getAngle(self: DoorAnim) f32 {
        return self.angle;
    }

    /// True when the door has finished opening (angle == 90).
    pub fn isFullyOpen(self: DoorAnim) bool {
        return @abs(self.angle - 90.0) < epsilon;
    }

    /// True when the door has finished closing (angle == 0).
    pub fn isFullyClosed(self: DoorAnim) bool {
        return @abs(self.angle) < epsilon;
    }
};

// -------------------------------------------------------------------------
// Tests
// -------------------------------------------------------------------------

test "default state is closed at angle zero" {
    const anim = DoorAnim{};
    try std.testing.expectEqual(@as(f32, 0), anim.getAngle());
    try std.testing.expect(!anim.is_open);
}

test "open sets target to 90 and marks open" {
    var anim = DoorAnim{};
    anim.open();
    try std.testing.expectEqual(@as(f32, 90), anim.target);
    try std.testing.expect(anim.is_open);
}

test "close sets target to 0 and marks closed" {
    var anim = DoorAnim{};
    anim.open();
    anim.close();
    try std.testing.expectEqual(@as(f32, 0), anim.target);
    try std.testing.expect(!anim.is_open);
}

test "update moves angle toward target" {
    var anim = DoorAnim{};
    anim.open();
    anim.update(0.1); // 360 * 0.1 = 36 degrees
    try std.testing.expectApproxEqAbs(@as(f32, 36.0), anim.getAngle(), 0.01);
}

test "update does not overshoot target" {
    var anim = DoorAnim{};
    anim.open();
    // A full second at 360 deg/s would be 360 degrees, but target is 90.
    anim.update(1.0);
    try std.testing.expectApproxEqAbs(@as(f32, 90.0), anim.getAngle(), 0.01);
}

test "update moves angle downward when closing" {
    var anim = DoorAnim{ .angle = 90, .target = 90, .is_open = true };
    anim.close();
    anim.update(0.1); // Should move toward 0 by 36 degrees
    try std.testing.expectApproxEqAbs(@as(f32, 54.0), anim.getAngle(), 0.01);
}

test "isFullyOpen returns true when angle reaches 90" {
    var anim = DoorAnim{};
    anim.open();
    anim.update(0.25); // 360 * 0.25 = 90
    try std.testing.expect(anim.isFullyOpen());
}

test "isFullyClosed returns true at default state" {
    const anim = DoorAnim{};
    try std.testing.expect(anim.isFullyClosed());
}

test "isFullyClosed returns true after full close animation" {
    var anim = DoorAnim{ .angle = 90, .target = 90, .is_open = true };
    anim.close();
    anim.update(0.25); // 360 * 0.25 = 90 degrees of travel
    try std.testing.expect(anim.isFullyClosed());
}

test "multiple small updates converge to target" {
    var anim = DoorAnim{};
    anim.open();
    var i: u32 = 0;
    while (i < 100) : (i += 1) {
        anim.update(0.01); // 3.6 degrees per step, 100 steps = 360 total capacity
    }
    try std.testing.expect(anim.isFullyOpen());
    try std.testing.expectApproxEqAbs(@as(f32, 90.0), anim.getAngle(), 0.01);
}

test "zero dt does not change angle" {
    var anim = DoorAnim{};
    anim.open();
    anim.update(0.0);
    try std.testing.expectEqual(@as(f32, 0), anim.getAngle());
}

test "open then close then open cycles correctly" {
    var anim = DoorAnim{};
    anim.open();
    anim.update(0.25); // fully open at 90
    try std.testing.expect(anim.isFullyOpen());

    anim.close();
    anim.update(0.25); // fully closed at 0
    try std.testing.expect(anim.isFullyClosed());

    anim.open();
    anim.update(0.125); // 360 * 0.125 = 45 degrees
    try std.testing.expectApproxEqAbs(@as(f32, 45.0), anim.getAngle(), 0.01);
    try std.testing.expect(!anim.isFullyOpen());
    try std.testing.expect(!anim.isFullyClosed());
}

test "isFullyOpen is false when partially open" {
    var anim = DoorAnim{};
    anim.open();
    anim.update(0.1);
    try std.testing.expect(!anim.isFullyOpen());
}

test "angle snaps to target within epsilon" {
    var anim = DoorAnim{ .angle = 89.995, .target = 90, .is_open = true };
    anim.update(0.001);
    try std.testing.expectEqual(@as(f32, 90), anim.getAngle());
}
