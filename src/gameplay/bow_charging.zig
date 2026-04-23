const std = @import("std");

/// Bow charging state machine.
/// Charge accumulates linearly from 0 to 1 over 1 second.
/// Releasing with charge >= 0.1 fires an arrow whose damage and velocity
/// scale with the charge level.
pub const BowState = struct {
    charge: f32 = 0,
    is_charging: bool = false,

    const max_charge: f32 = 1.0;
    const charge_rate: f32 = 1.0; // 0 → 1 over 1 second
    const min_fire_charge: f32 = 0.1;

    pub fn startCharge(self: *BowState) void {
        self.is_charging = true;
        self.charge = 0;
    }

    pub fn update(self: *BowState, dt: f32) void {
        if (!self.is_charging) return;
        self.charge = @min(self.charge + dt * charge_rate, max_charge);
    }

    /// Release the bowstring. Returns shot parameters when the charge
    /// meets the minimum threshold, or null when the draw was too short.
    pub fn release(self: *BowState) ?ShotResult {
        if (!self.is_charging) return null;

        const c = self.charge;
        self.is_charging = false;
        self.charge = 0;

        if (c < min_fire_charge) return null;

        return ShotResult{
            .damage = 1.0 + c * 9.0,
            .velocity = 1.0 + c * 2.0,
        };
    }

    pub fn getChargePct(self: BowState) f32 {
        return self.charge;
    }

    pub fn isFullyCharged(self: BowState) bool {
        return self.charge >= max_charge;
    }
};

pub const ShotResult = struct {
    damage: f32,
    velocity: f32,
};

// ─── Tests ──────────────────────────────────────────────────────────────────

test "initial state is uncharged and idle" {
    const bow = BowState{};
    try std.testing.expectEqual(@as(f32, 0), bow.charge);
    try std.testing.expect(!bow.is_charging);
}

test "startCharge resets charge and begins charging" {
    var bow = BowState{ .charge = 0.5, .is_charging = false };
    bow.startCharge();
    try std.testing.expect(bow.is_charging);
    try std.testing.expectEqual(@as(f32, 0), bow.charge);
}

test "update accumulates charge over time" {
    var bow = BowState{};
    bow.startCharge();
    bow.update(0.25);
    try std.testing.expectApproxEqAbs(@as(f32, 0.25), bow.charge, 1e-6);
    bow.update(0.25);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), bow.charge, 1e-6);
}

test "charge clamps at 1.0" {
    var bow = BowState{};
    bow.startCharge();
    bow.update(2.0);
    try std.testing.expectEqual(@as(f32, 1.0), bow.charge);
}

test "update is a no-op when not charging" {
    var bow = BowState{};
    bow.update(1.0);
    try std.testing.expectEqual(@as(f32, 0), bow.charge);
}

test "release fires when charge meets minimum" {
    var bow = BowState{};
    bow.startCharge();
    bow.update(0.5);
    const result = bow.release().?;
    // damage = 1 + 0.5*9 = 5.5, velocity = 1 + 0.5*2 = 2.0
    try std.testing.expectApproxEqAbs(@as(f32, 5.5), result.damage, 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), result.velocity, 1e-6);
    try std.testing.expect(!bow.is_charging);
    try std.testing.expectEqual(@as(f32, 0), bow.charge);
}

test "release returns null when charge is below minimum" {
    var bow = BowState{};
    bow.startCharge();
    bow.update(0.05);
    try std.testing.expect(bow.release() == null);
    try std.testing.expect(!bow.is_charging);
}

test "release returns null when not charging" {
    var bow = BowState{};
    try std.testing.expect(bow.release() == null);
}

test "full charge produces maximum damage and velocity" {
    var bow = BowState{};
    bow.startCharge();
    bow.update(1.0);
    const result = bow.release().?;
    // damage = 1 + 1*9 = 10, velocity = 1 + 1*2 = 3
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), result.damage, 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), result.velocity, 1e-6);
}

test "getChargePct reflects current charge" {
    var bow = BowState{};
    bow.startCharge();
    bow.update(0.75);
    try std.testing.expectApproxEqAbs(@as(f32, 0.75), bow.getChargePct(), 1e-6);
}

test "isFullyCharged returns true only at max" {
    var bow = BowState{};
    bow.startCharge();
    bow.update(0.99);
    try std.testing.expect(!bow.isFullyCharged());
    bow.update(0.01);
    try std.testing.expect(bow.isFullyCharged());
}

test "minimum threshold release produces correct scaling" {
    var bow = BowState{};
    bow.startCharge();
    bow.update(0.1);
    const result = bow.release().?;
    // damage = 1 + 0.1*9 = 1.9, velocity = 1 + 0.1*2 = 1.2
    try std.testing.expectApproxEqAbs(@as(f32, 1.9), result.damage, 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, 1.2), result.velocity, 1e-6);
}

test "restarting charge after release resets state" {
    var bow = BowState{};
    bow.startCharge();
    bow.update(0.5);
    _ = bow.release();

    bow.startCharge();
    try std.testing.expect(bow.is_charging);
    try std.testing.expectEqual(@as(f32, 0), bow.charge);
    bow.update(0.3);
    try std.testing.expectApproxEqAbs(@as(f32, 0.3), bow.charge, 1e-6);
}
