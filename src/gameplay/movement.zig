const std = @import("std");

pub const MoveMode = enum { walk, sprint, sneak, swim };

const walk_speed: f32 = 1.0;
const sprint_speed: f32 = 1.3;
const sneak_speed: f32 = 0.3;
const swim_speed: f32 = 0.5;

const double_tap_window: f64 = 0.3; // seconds

const sprint_hunger_multiplier: f32 = 3.0;
const sneak_camera_y_offset: f32 = -0.08;
const sprint_fov_modifier: f32 = 10.0;

pub const MovementState = struct {
    mode: MoveMode = .walk,
    last_forward_press_time: f64 = 0.0,
    was_forward_pressed: bool = false,

    pub fn init() MovementState {
        return .{};
    }

    /// Get speed multiplier for current mode.
    pub fn getSpeedMultiplier(self: *const MovementState) f32 {
        return switch (self.mode) {
            .walk => walk_speed,
            .sprint => sprint_speed,
            .sneak => sneak_speed,
            .swim => swim_speed,
        };
    }

    /// Get hunger drain multiplier (sprint drains 3x faster).
    pub fn getHungerDrainMultiplier(self: *const MovementState) f32 {
        return switch (self.mode) {
            .sprint => sprint_hunger_multiplier,
            else => 1.0,
        };
    }

    /// Get camera Y offset (sneak lowers camera by 0.08).
    pub fn getCameraYOffset(self: *const MovementState) f32 {
        return switch (self.mode) {
            .sneak => sneak_camera_y_offset,
            else => 0.0,
        };
    }

    /// Get FOV modifier (sprint adds 10 degrees).
    pub fn getFOVModifier(self: *const MovementState) f32 {
        return switch (self.mode) {
            .sprint => sprint_fov_modifier,
            else => 0.0,
        };
    }

    /// Update movement mode based on current input state.
    pub fn updateInput(
        self: *MovementState,
        ctrl_held: bool,
        shift_held: bool,
        forward_pressed: bool,
        current_time: f64,
        in_water: bool,
    ) void {
        defer self.was_forward_pressed = forward_pressed;

        if (in_water) {
            self.mode = .swim;
            return;
        }

        // Reset swim mode when leaving water
        if (self.mode == .swim) {
            self.mode = .walk;
        }

        // Sneak takes priority over sprint when shift is held
        if (shift_held) {
            self.mode = .sneak;
            return;
        }

        // Sprint stops when forward is released
        if (self.mode == .sprint and !forward_pressed) {
            self.mode = .walk;
        }

        // Sprint activation via Ctrl held while moving forward
        if (ctrl_held and forward_pressed) {
            self.mode = .sprint;
            return;
        }

        // Double-tap W sprint detection: two presses within the time window
        if (forward_pressed and !self.was_forward_pressed) {
            const elapsed = current_time - self.last_forward_press_time;
            if (elapsed <= double_tap_window and elapsed > 0.0) {
                self.mode = .sprint;
            }
            self.last_forward_press_time = current_time;
        }
    }

    /// Should prevent falling off edges (sneak mode).
    pub fn preventEdgeFall(self: *const MovementState) bool {
        return self.mode == .sneak;
    }
};

// ──────────────────────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────────────────────

test "init returns default walk state" {
    const state = MovementState.init();
    try std.testing.expectEqual(MoveMode.walk, state.mode);
    try std.testing.expectEqual(@as(f64, 0.0), state.last_forward_press_time);
}

test "speed multipliers match spec" {
    var state = MovementState.init();

    state.mode = .walk;
    try std.testing.expectEqual(@as(f32, 1.0), state.getSpeedMultiplier());

    state.mode = .sprint;
    try std.testing.expectEqual(@as(f32, 1.3), state.getSpeedMultiplier());

    state.mode = .sneak;
    try std.testing.expectEqual(@as(f32, 0.3), state.getSpeedMultiplier());

    state.mode = .swim;
    try std.testing.expectEqual(@as(f32, 0.5), state.getSpeedMultiplier());
}

test "sprint activation via ctrl held" {
    var state = MovementState.init();

    // Hold ctrl + forward => sprint
    state.updateInput(true, false, true, 1.0, false);
    try std.testing.expectEqual(MoveMode.sprint, state.mode);
}

test "sprint activation via double-tap forward" {
    var state = MovementState.init();

    // First tap: press forward
    state.updateInput(false, false, true, 1.0, false);
    try std.testing.expectEqual(MoveMode.walk, state.mode);

    // Release forward
    state.updateInput(false, false, false, 1.1, false);
    try std.testing.expectEqual(MoveMode.walk, state.mode);

    // Second tap within 0.3s window
    state.updateInput(false, false, true, 1.2, false);
    try std.testing.expectEqual(MoveMode.sprint, state.mode);
}

test "double-tap too slow does not sprint" {
    var state = MovementState.init();

    // First tap
    state.updateInput(false, false, true, 1.0, false);

    // Release
    state.updateInput(false, false, false, 1.1, false);

    // Second tap after 0.5s (> 0.3s window)
    state.updateInput(false, false, true, 1.5, false);
    try std.testing.expectEqual(MoveMode.walk, state.mode);
}

test "sprint stops when releasing forward" {
    var state = MovementState.init();

    // Start sprinting
    state.updateInput(true, false, true, 1.0, false);
    try std.testing.expectEqual(MoveMode.sprint, state.mode);

    // Release forward (but still hold ctrl)
    state.updateInput(true, false, false, 1.1, false);
    try std.testing.expectEqual(MoveMode.walk, state.mode);
}

test "sneak prevents edge fall" {
    var state = MovementState.init();
    try std.testing.expect(!state.preventEdgeFall());

    state.mode = .sneak;
    try std.testing.expect(state.preventEdgeFall());
}

test "shift activates sneak" {
    var state = MovementState.init();
    state.updateInput(false, true, true, 1.0, false);
    try std.testing.expectEqual(MoveMode.sneak, state.mode);
    try std.testing.expect(state.preventEdgeFall());
}

test "sneak overrides sprint when both held" {
    var state = MovementState.init();

    // First sprint
    state.updateInput(true, false, true, 1.0, false);
    try std.testing.expectEqual(MoveMode.sprint, state.mode);

    // Now hold shift too => sneak takes priority
    state.updateInput(true, true, true, 1.1, false);
    try std.testing.expectEqual(MoveMode.sneak, state.mode);
}

test "hunger drain multiplier is 3x for sprint" {
    var state = MovementState.init();

    state.mode = .walk;
    try std.testing.expectEqual(@as(f32, 1.0), state.getHungerDrainMultiplier());

    state.mode = .sprint;
    try std.testing.expectEqual(@as(f32, 3.0), state.getHungerDrainMultiplier());

    state.mode = .sneak;
    try std.testing.expectEqual(@as(f32, 1.0), state.getHungerDrainMultiplier());

    state.mode = .swim;
    try std.testing.expectEqual(@as(f32, 1.0), state.getHungerDrainMultiplier());
}

test "camera Y offset for sneak" {
    var state = MovementState.init();

    state.mode = .walk;
    try std.testing.expectEqual(@as(f32, 0.0), state.getCameraYOffset());

    state.mode = .sneak;
    try std.testing.expectEqual(@as(f32, -0.08), state.getCameraYOffset());

    state.mode = .sprint;
    try std.testing.expectEqual(@as(f32, 0.0), state.getCameraYOffset());
}

test "FOV modifier for sprint" {
    var state = MovementState.init();

    state.mode = .walk;
    try std.testing.expectEqual(@as(f32, 0.0), state.getFOVModifier());

    state.mode = .sprint;
    try std.testing.expectEqual(@as(f32, 10.0), state.getFOVModifier());

    state.mode = .sneak;
    try std.testing.expectEqual(@as(f32, 0.0), state.getFOVModifier());
}

test "in_water activates swim mode" {
    var state = MovementState.init();
    state.updateInput(false, false, true, 1.0, true);
    try std.testing.expectEqual(MoveMode.swim, state.mode);
}

test "swim overrides sprint when in water" {
    var state = MovementState.init();

    // Sprint first
    state.updateInput(true, false, true, 1.0, false);
    try std.testing.expectEqual(MoveMode.sprint, state.mode);

    // Enter water => swim
    state.updateInput(true, false, true, 1.1, true);
    try std.testing.expectEqual(MoveMode.swim, state.mode);
}

test "leaving water returns to walk" {
    var state = MovementState.init();

    // In water
    state.updateInput(false, false, true, 1.0, true);
    try std.testing.expectEqual(MoveMode.swim, state.mode);

    // Leave water, no modifiers
    state.updateInput(false, false, true, 1.1, false);
    try std.testing.expectEqual(MoveMode.walk, state.mode);
}

test "walk mode has no edge fall prevention" {
    var state = MovementState.init();
    state.mode = .walk;
    try std.testing.expect(!state.preventEdgeFall());

    state.mode = .sprint;
    try std.testing.expect(!state.preventEdgeFall());

    state.mode = .swim;
    try std.testing.expect(!state.preventEdgeFall());
}
