const std = @import("std");

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/// Maximum depression depth: 1/16 of a block (0.0625).
const max_depress: f32 = 0.0625;

/// Animation rate in units per second (reaches max_depress in 1/64 s at full rate).
const depress_rate: f32 = 4.0;

// ---------------------------------------------------------------------------
// Plate types for signal strength calculation
// ---------------------------------------------------------------------------

pub const PlateKind = enum {
    wooden,
    stone,
    weighted,
};

// ---------------------------------------------------------------------------
// PlateState
// ---------------------------------------------------------------------------

/// Visual state for a single pressure plate, tracking press/release status
/// and smooth depression animation.
pub const PlateState = struct {
    is_pressed: bool = false,
    depress_amount: f32 = 0,

    /// Mark the plate as pressed.
    pub fn press(self: *PlateState) void {
        self.is_pressed = true;
    }

    /// Mark the plate as released.
    pub fn release(self: *PlateState) void {
        self.is_pressed = false;
    }

    /// Animate the depression amount toward its target over `dt` seconds.
    /// When pressed the plate lowers toward `max_depress`; when released it
    /// rises back to 0. Movement is clamped at the rate of `depress_rate`
    /// per second.
    pub fn update(self: *PlateState, dt: f32) void {
        const target: f32 = if (self.is_pressed) max_depress else 0.0;
        const step = depress_rate * dt;

        if (self.depress_amount < target) {
            self.depress_amount = @min(self.depress_amount + step, target);
        } else if (self.depress_amount > target) {
            self.depress_amount = @max(self.depress_amount - step, target);
        }
    }

    /// Return the current Y-axis offset (always <= 0) for the plate model.
    pub fn getYOffset(self: PlateState) f32 {
        return -self.depress_amount;
    }
};

// ---------------------------------------------------------------------------
// Signal strength
// ---------------------------------------------------------------------------

/// Compute the redstone signal strength emitted by a pressure plate.
///
/// - **wooden**: emits 15 if *any* entity is present, 0 otherwise.
/// - **stone**: emits 15 only when a player is present (modelled here as
///   `entity_count >= 1` with `is_weighted == false` and kind == .stone).
/// - **weighted**: emits min(15, entity_count).
pub fn getSignalStrength(entity_count: u8, plate_kind: PlateKind) u4 {
    return switch (plate_kind) {
        .wooden => if (entity_count > 0) 15 else 0,
        .stone => if (entity_count > 0) 15 else 0,
        .weighted => @intCast(@min(@as(u16, entity_count), 15)),
    };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "PlateState defaults to unpressed with zero depression" {
    const state = PlateState{};
    try std.testing.expect(!state.is_pressed);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), state.depress_amount, 0.0001);
}

test "press sets is_pressed to true" {
    var state = PlateState{};
    state.press();
    try std.testing.expect(state.is_pressed);
}

test "release sets is_pressed to false" {
    var state = PlateState{};
    state.press();
    state.release();
    try std.testing.expect(!state.is_pressed);
}

test "update increases depress_amount when pressed" {
    var state = PlateState{};
    state.press();
    state.update(0.01);
    try std.testing.expect(state.depress_amount > 0.0);
}

test "update decreases depress_amount when released" {
    var state = PlateState{ .is_pressed = false, .depress_amount = max_depress };
    state.update(0.01);
    try std.testing.expect(state.depress_amount < max_depress);
}

test "depress_amount clamps at max_depress" {
    var state = PlateState{};
    state.press();
    // Large dt to overshoot
    state.update(10.0);
    try std.testing.expectApproxEqAbs(max_depress, state.depress_amount, 0.0001);
}

test "depress_amount clamps at zero when released" {
    var state = PlateState{ .is_pressed = false, .depress_amount = 0.01 };
    // Large dt to overshoot below zero
    state.update(10.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), state.depress_amount, 0.0001);
}

test "getYOffset returns negative of depress_amount" {
    const state = PlateState{ .depress_amount = 0.03 };
    try std.testing.expectApproxEqAbs(@as(f32, -0.03), state.getYOffset(), 0.0001);
}

test "getYOffset is zero when unpressed and not animated" {
    const state = PlateState{};
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), state.getYOffset(), 0.0001);
}

test "full press cycle reaches max_depress then returns to zero" {
    var state = PlateState{};
    state.press();
    // Animate fully down
    state.update(1.0);
    try std.testing.expectApproxEqAbs(max_depress, state.depress_amount, 0.0001);

    state.release();
    // Animate fully up
    state.update(1.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), state.depress_amount, 0.0001);
}

test "wooden plate signal: 15 when any entity present" {
    try std.testing.expectEqual(@as(u4, 15), getSignalStrength(1, .wooden));
    try std.testing.expectEqual(@as(u4, 15), getSignalStrength(5, .wooden));
    try std.testing.expectEqual(@as(u4, 0), getSignalStrength(0, .wooden));
}

test "stone plate signal: 15 when entity present, 0 otherwise" {
    try std.testing.expectEqual(@as(u4, 15), getSignalStrength(1, .stone));
    try std.testing.expectEqual(@as(u4, 0), getSignalStrength(0, .stone));
}

test "weighted plate signal: min(15, count)" {
    try std.testing.expectEqual(@as(u4, 0), getSignalStrength(0, .weighted));
    try std.testing.expectEqual(@as(u4, 3), getSignalStrength(3, .weighted));
    try std.testing.expectEqual(@as(u4, 15), getSignalStrength(15, .weighted));
    try std.testing.expectEqual(@as(u4, 15), getSignalStrength(255, .weighted));
}

test "lerp rate: partial dt produces intermediate depress_amount" {
    var state = PlateState{};
    state.press();
    // dt = 0.005 => step = 4.0 * 0.005 = 0.02
    state.update(0.005);
    try std.testing.expectApproxEqAbs(@as(f32, 0.02), state.depress_amount, 0.0001);
}
