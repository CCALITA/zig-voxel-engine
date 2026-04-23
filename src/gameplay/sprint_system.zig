const std = @import("std");

const double_tap_window: f32 = 0.3;
const sprint_speed_multiplier: f32 = 1.3;
const exhaustion_per_block: f32 = 0.1;

pub const SprintState = struct {
    is_sprinting: bool = false,
    sprint_timer: f32 = 0,
    double_tap_timer: f32 = 0,
    last_forward: bool = false,
    hunger_threshold: u8 = 6,

    /// Update sprint state based on input, hunger, and elapsed time.
    ///
    /// Sprint activates when:
    ///   - `sprint_key` is held while `forward_pressed`, or
    ///   - forward is double-tapped within 0.3 s.
    ///
    /// Sprint deactivates when:
    ///   - forward is released,
    ///   - hunger drops below `hunger_threshold`, or
    ///   - `collide()` is called externally.
    pub fn update(self: *SprintState, forward_pressed: bool, sprint_key: bool, hunger: u8, dt: f32) void {
        if (self.double_tap_timer > 0) {
            self.double_tap_timer = @max(0, self.double_tap_timer - dt);
        }

        if (self.is_sprinting) {
            self.sprint_timer += dt;

            if (!forward_pressed or hunger < self.hunger_threshold) {
                self.stop();
            }
        }

        // Detect double-tap: rising edge of forward within the window
        const forward_rising = forward_pressed and !self.last_forward;
        if (forward_rising) {
            if (self.double_tap_timer > 0) {
                if (hunger >= self.hunger_threshold) {
                    self.startSprint();
                }
                self.double_tap_timer = 0;
            } else {
                self.double_tap_timer = double_tap_window;
            }
        }

        // Sprint key activation
        if (sprint_key and forward_pressed and hunger >= self.hunger_threshold) {
            self.startSprint();
        }

        self.last_forward = forward_pressed;
    }

    /// Called when the player collides with a block — stops sprinting.
    pub fn collide(self: *SprintState) void {
        self.stop();
    }

    /// Returns 1.3 while sprinting, 1.0 otherwise.
    pub fn getSpeedMultiplier(self: SprintState) f32 {
        return if (self.is_sprinting) sprint_speed_multiplier else 1.0;
    }

    /// Returns exhaustion cost (0.1 per block) while sprinting, 0 otherwise.
    pub fn getExhaustion(self: SprintState, distance: f32) f32 {
        return if (self.is_sprinting) distance * exhaustion_per_block else 0.0;
    }

    /// Sprinting players emit particles.
    pub fn shouldEmitParticles(self: SprintState) bool {
        return self.is_sprinting;
    }

    // ── internal helpers ─────────────────────────────────────────────────

    fn startSprint(self: *SprintState) void {
        if (!self.is_sprinting) {
            self.is_sprinting = true;
            self.sprint_timer = 0;
        }
    }

    fn stop(self: *SprintState) void {
        self.is_sprinting = false;
        self.sprint_timer = 0;
    }
};

// ──────────────────────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────────────────────

test "default state is not sprinting" {
    const state = SprintState{};
    try std.testing.expect(!state.is_sprinting);
    try std.testing.expectEqual(@as(f32, 0), state.sprint_timer);
    try std.testing.expectEqual(@as(f32, 0), state.double_tap_timer);
    try std.testing.expectEqual(@as(u8, 6), state.hunger_threshold);
}

test "sprint key activates sprint when forward is pressed" {
    var state = SprintState{};
    state.update(true, true, 20, 0.016);
    try std.testing.expect(state.is_sprinting);
}

test "sprint key does not activate without forward" {
    var state = SprintState{};
    state.update(false, true, 20, 0.016);
    try std.testing.expect(!state.is_sprinting);
}

test "double-tap forward activates sprint" {
    var state = SprintState{};

    // First tap — press forward
    state.update(true, false, 20, 0.016);
    try std.testing.expect(!state.is_sprinting);

    // Release forward
    state.update(false, false, 20, 0.05);

    // Second tap within 0.3 s window
    state.update(true, false, 20, 0.05);
    try std.testing.expect(state.is_sprinting);
}

test "double-tap too slow does not activate sprint" {
    var state = SprintState{};

    // First tap
    state.update(true, false, 20, 0.016);

    // Release
    state.update(false, false, 20, 0.016);

    // Wait for window to expire (simulate many frames)
    for (0..20) |_| {
        state.update(false, false, 20, 0.02);
    }

    // Second tap — window has expired
    state.update(true, false, 20, 0.016);
    try std.testing.expect(!state.is_sprinting);
}

test "releasing forward stops sprint" {
    var state = SprintState{};

    // Start sprinting
    state.update(true, true, 20, 0.016);
    try std.testing.expect(state.is_sprinting);

    // Release forward
    state.update(false, false, 20, 0.016);
    try std.testing.expect(!state.is_sprinting);
}

test "low hunger stops sprint" {
    var state = SprintState{};

    // Start sprinting
    state.update(true, true, 20, 0.016);
    try std.testing.expect(state.is_sprinting);

    // Hunger drops below threshold (forward still held)
    state.update(true, false, 5, 0.016);
    try std.testing.expect(!state.is_sprinting);
}

test "low hunger prevents sprint activation" {
    var state = SprintState{};
    state.update(true, true, 5, 0.016);
    try std.testing.expect(!state.is_sprinting);
}

test "collision stops sprint" {
    var state = SprintState{};

    // Start sprinting
    state.update(true, true, 20, 0.016);
    try std.testing.expect(state.is_sprinting);

    state.collide();
    try std.testing.expect(!state.is_sprinting);
    try std.testing.expectEqual(@as(f32, 0), state.sprint_timer);
}

test "speed multiplier is 1.3 when sprinting and 1.0 otherwise" {
    var state = SprintState{};
    try std.testing.expectEqual(@as(f32, 1.0), state.getSpeedMultiplier());

    state.update(true, true, 20, 0.016);
    try std.testing.expectEqual(@as(f32, 1.3), state.getSpeedMultiplier());
}

test "exhaustion is 0.1 per block while sprinting" {
    var state = SprintState{};

    // Not sprinting — no exhaustion
    try std.testing.expectEqual(@as(f32, 0.0), state.getExhaustion(5.0));

    // Start sprinting
    state.update(true, true, 20, 0.016);
    try std.testing.expectEqual(@as(f32, 0.5), state.getExhaustion(5.0));
    try std.testing.expectEqual(@as(f32, 0.1), state.getExhaustion(1.0));
    try std.testing.expectEqual(@as(f32, 0.0), state.getExhaustion(0.0));
}

test "particles emitted only while sprinting" {
    var state = SprintState{};
    try std.testing.expect(!state.shouldEmitParticles());

    state.update(true, true, 20, 0.016);
    try std.testing.expect(state.shouldEmitParticles());

    state.update(false, false, 20, 0.016);
    try std.testing.expect(!state.shouldEmitParticles());
}

test "sprint timer accumulates while sprinting" {
    var state = SprintState{};

    state.update(true, true, 20, 0.5);
    try std.testing.expectEqual(@as(f32, 0), state.sprint_timer);

    // Timer starts accumulating on subsequent frames
    state.update(true, false, 20, 0.5);
    try std.testing.expectEqual(@as(f32, 0.5), state.sprint_timer);

    state.update(true, false, 20, 0.3);
    try std.testing.expect(state.sprint_timer > 0.79 and state.sprint_timer < 0.81);
}

test "hunger exactly at threshold allows sprint" {
    var state = SprintState{};
    state.update(true, true, 6, 0.016);
    try std.testing.expect(state.is_sprinting);
}
