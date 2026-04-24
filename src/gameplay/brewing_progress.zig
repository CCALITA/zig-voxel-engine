/// Brewing progress tracker for potion brewing.
/// Manages fuel consumption, brew timing, and progress reporting.
/// Only depends on `std`.

const std = @import("std");

pub const BREW_TIME: f32 = 20.0;
pub const FUEL_PER_BLAZE_POWDER: u8 = 20;

pub const BrewProgress = struct {
    progress: f32 = 0,
    fuel: u8 = 0,
    is_brewing: bool = false,

    /// Add one blaze powder worth of fuel.
    pub fn addFuel(self: *BrewProgress) void {
        const new: u16 = @as(u16, self.fuel) + FUEL_PER_BLAZE_POWDER;
        self.fuel = @intCast(@min(new, 255));
    }

    /// Attempt to start a brew cycle. Returns false if no fuel available.
    pub fn startBrew(self: *BrewProgress) bool {
        if (self.fuel == 0) return false;
        self.is_brewing = true;
        self.progress = 0;
        return true;
    }

    /// Advance the brew by `dt` seconds. Returns true when the cycle completes.
    pub fn update(self: *BrewProgress, dt: f32) bool {
        if (!self.is_brewing) return false;
        if (dt <= 0) return false;

        self.progress += dt;

        if (self.progress >= BREW_TIME) {
            self.is_brewing = false;
            self.progress = 0;
            return true;
        }
        return false;
    }

    /// Current brew progress as a percentage in [0, 100].
    pub fn getProgressPercent(self: BrewProgress) f32 {
        if (!self.is_brewing) return 0;
        return @min(self.progress / BREW_TIME * 100.0, 100.0);
    }

    /// Consume one unit of fuel.
    pub fn consumeFuel(self: *BrewProgress) void {
        if (self.fuel > 0) {
            self.fuel -= 1;
        }
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "default state is idle with no fuel" {
    const bp = BrewProgress{};
    try std.testing.expect(!bp.is_brewing);
    try std.testing.expectEqual(@as(f32, 0), bp.progress);
    try std.testing.expectEqual(@as(u8, 0), bp.fuel);
}

test "addFuel adds 20 per call" {
    var bp = BrewProgress{};
    bp.addFuel();
    try std.testing.expectEqual(@as(u8, 20), bp.fuel);
    bp.addFuel();
    try std.testing.expectEqual(@as(u8, 40), bp.fuel);
}

test "addFuel clamps at 255" {
    var bp = BrewProgress{ .fuel = 250 };
    bp.addFuel();
    try std.testing.expectEqual(@as(u8, 255), bp.fuel);
}

test "startBrew fails without fuel" {
    var bp = BrewProgress{};
    try std.testing.expect(!bp.startBrew());
    try std.testing.expect(!bp.is_brewing);
}

test "startBrew succeeds with fuel" {
    var bp = BrewProgress{};
    bp.addFuel();
    try std.testing.expect(bp.startBrew());
    try std.testing.expect(bp.is_brewing);
    try std.testing.expectEqual(@as(f32, 0), bp.progress);
}

test "update returns false while brewing is incomplete" {
    var bp = BrewProgress{};
    bp.addFuel();
    _ = bp.startBrew();
    try std.testing.expect(!bp.update(10.0));
    try std.testing.expect(bp.is_brewing);
}

test "update returns true when brew completes" {
    var bp = BrewProgress{};
    bp.addFuel();
    _ = bp.startBrew();
    try std.testing.expect(bp.update(BREW_TIME));
    try std.testing.expect(!bp.is_brewing);
    try std.testing.expectEqual(@as(f32, 0), bp.progress);
}

test "update accumulates across multiple calls" {
    var bp = BrewProgress{};
    bp.addFuel();
    _ = bp.startBrew();
    try std.testing.expect(!bp.update(10.0));
    try std.testing.expect(bp.update(10.0));
    try std.testing.expect(!bp.is_brewing);
}

test "update is a no-op when not brewing" {
    var bp = BrewProgress{};
    try std.testing.expect(!bp.update(5.0));
    try std.testing.expectEqual(@as(f32, 0), bp.progress);
}

test "update ignores non-positive dt" {
    var bp = BrewProgress{};
    bp.addFuel();
    _ = bp.startBrew();
    try std.testing.expect(!bp.update(0));
    try std.testing.expect(!bp.update(-1.0));
    try std.testing.expectEqual(@as(f32, 0), bp.progress);
}

test "getProgressPercent returns 0 when idle" {
    const bp = BrewProgress{};
    try std.testing.expectEqual(@as(f32, 0), bp.getProgressPercent());
}

test "getProgressPercent returns 50 at halfway" {
    var bp = BrewProgress{};
    bp.addFuel();
    _ = bp.startBrew();
    _ = bp.update(10.0);
    try std.testing.expectApproxEqAbs(@as(f32, 50.0), bp.getProgressPercent(), 0.01);
}

test "getProgressPercent caps at 100" {
    var bp = BrewProgress{ .is_brewing = true, .progress = BREW_TIME + 5.0, .fuel = 1 };
    try std.testing.expectApproxEqAbs(@as(f32, 100.0), bp.getProgressPercent(), 0.01);
}

test "consumeFuel decrements by 1" {
    var bp = BrewProgress{};
    bp.addFuel();
    try std.testing.expectEqual(@as(u8, 20), bp.fuel);
    bp.consumeFuel();
    try std.testing.expectEqual(@as(u8, 19), bp.fuel);
}

test "consumeFuel does nothing at zero" {
    var bp = BrewProgress{};
    bp.consumeFuel();
    try std.testing.expectEqual(@as(u8, 0), bp.fuel);
}

test "startBrew resets progress from a previous partial brew" {
    var bp = BrewProgress{};
    bp.addFuel();
    _ = bp.startBrew();
    _ = bp.update(5.0);
    try std.testing.expect(bp.progress > 0);
    // restart
    _ = bp.startBrew();
    try std.testing.expectEqual(@as(f32, 0), bp.progress);
}
