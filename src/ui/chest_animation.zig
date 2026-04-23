/// Chest lid animation state machine. Smoothly lerps the lid angle toward a
/// target (open = 45 deg, closed = 0 deg) at a fixed angular speed of 180 deg/s.
const std = @import("std");

// ── Constants ───────────────────────────────────────────────────────

pub const open_angle: f32 = 45.0;
pub const closed_angle: f32 = 0.0;
const angular_speed: f32 = 180.0; // degrees per second

// ── Public types ────────────────────────────────────────────────────

pub const ChestAnimState = struct {
    lid_angle: f32 = 0,
    target_angle: f32 = 0,
    is_open: bool = false,

    /// Begin opening the chest lid.
    pub fn open(self: *ChestAnimState) void {
        self.target_angle = open_angle;
        self.is_open = true;
    }

    /// Begin closing the chest lid.
    pub fn close(self: *ChestAnimState) void {
        self.target_angle = closed_angle;
        self.is_open = false;
    }

    /// Advance the lid angle toward the target at 180 deg/s.
    pub fn update(self: *ChestAnimState, dt: f32) void {
        const diff = self.target_angle - self.lid_angle;
        if (diff == 0) return;

        const max_step = angular_speed * dt;
        if (@abs(diff) <= max_step) {
            self.lid_angle = self.target_angle;
        } else if (diff > 0) {
            self.lid_angle += max_step;
        } else {
            self.lid_angle -= max_step;
        }
    }

    /// Return the current lid angle in degrees.
    pub fn getLidAngle(self: ChestAnimState) f32 {
        return self.lid_angle;
    }

    /// True when the lid has reached the fully-open angle.
    pub fn isFullyOpen(self: ChestAnimState) bool {
        return self.lid_angle == open_angle;
    }

    /// True when the lid has reached the fully-closed angle.
    pub fn isFullyClosed(self: ChestAnimState) bool {
        return self.lid_angle == closed_angle;
    }
};

// ── Tests ───────────────────────────────────────────────────────────

test "default state is closed at angle 0" {
    const s = ChestAnimState{};
    try std.testing.expectEqual(@as(f32, 0), s.getLidAngle());
    try std.testing.expect(s.isFullyClosed());
    try std.testing.expect(!s.isFullyOpen());
    try std.testing.expect(!s.is_open);
}

test "open sets target and flag" {
    var s = ChestAnimState{};
    s.open();
    try std.testing.expectEqual(open_angle, s.target_angle);
    try std.testing.expect(s.is_open);
}

test "close sets target and flag" {
    var s = ChestAnimState{};
    s.open();
    s.close();
    try std.testing.expectEqual(closed_angle, s.target_angle);
    try std.testing.expect(!s.is_open);
}

test "update moves lid toward target" {
    var s = ChestAnimState{};
    s.open();
    s.update(0.1); // 180 * 0.1 = 18 degrees
    try std.testing.expectApproxEqAbs(@as(f32, 18.0), s.getLidAngle(), 0.001);
}

test "update does not overshoot target" {
    var s = ChestAnimState{};
    s.open();
    s.update(10.0); // 180 * 10 = 1800, but target is 45
    try std.testing.expectEqual(open_angle, s.getLidAngle());
    try std.testing.expect(s.isFullyOpen());
}

test "update closes lid toward zero" {
    var s = ChestAnimState{};
    s.open();
    s.update(10.0); // fully open
    s.close();
    s.update(0.1); // 180 * 0.1 = 18 degrees back toward 0
    try std.testing.expectApproxEqAbs(@as(f32, 27.0), s.getLidAngle(), 0.001);
}

test "fully open after sufficient updates" {
    var s = ChestAnimState{};
    s.open();
    // 45 / 180 = 0.25s needed
    s.update(0.125);
    s.update(0.125);
    try std.testing.expect(s.isFullyOpen());
}

test "fully closed after closing from open" {
    var s = ChestAnimState{};
    s.open();
    s.update(10.0);
    s.close();
    s.update(10.0);
    try std.testing.expect(s.isFullyClosed());
}

test "zero dt produces no change" {
    var s = ChestAnimState{};
    s.open();
    s.update(0.0);
    try std.testing.expectEqual(@as(f32, 0), s.getLidAngle());
}

test "multiple small updates accumulate correctly" {
    var s = ChestAnimState{};
    s.open();
    var i: u32 = 0;
    while (i < 10) : (i += 1) {
        s.update(0.01); // 180 * 0.01 = 1.8 deg each
    }
    try std.testing.expectApproxEqAbs(@as(f32, 18.0), s.getLidAngle(), 0.01);
}

test "update is no-op when already at target" {
    var s = ChestAnimState{};
    s.update(1.0); // target = 0, lid = 0
    try std.testing.expectEqual(@as(f32, 0), s.getLidAngle());
}

test "reopen after partial close" {
    var s = ChestAnimState{};
    s.open();
    s.update(10.0); // fully open at 45
    s.close();
    s.update(0.05); // moves 9 degrees toward 0 => 36
    s.open(); // target back to 45
    s.update(0.05); // moves 9 degrees toward 45 => 45
    try std.testing.expect(s.isFullyOpen());
}

test "getLidAngle matches lid_angle field" {
    var s = ChestAnimState{};
    s.open();
    s.update(0.05);
    try std.testing.expectEqual(s.lid_angle, s.getLidAngle());
}
