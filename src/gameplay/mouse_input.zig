const std = @import("std");

const double_click_threshold: f32 = 0.3; // seconds

pub const MouseState = struct {
    left_down: bool = false,
    right_down: bool = false,
    left_just: bool = false,
    right_just: bool = false,
    scroll_delta: i32 = 0,
    last_left: bool = false,
    last_right: bool = false,
    double_click_timer: f32 = 0,

    /// Update mouse state with current frame inputs.
    /// Performs edge detection for just-pressed events and tracks
    /// double-click timing for the left button.
    pub fn update(self: *MouseState, left: bool, right: bool, scroll: i32, dt: f32) void {
        self.left_just = left and !self.last_left;
        self.right_just = right and !self.last_right;

        if (self.double_click_timer > 0) {
            self.double_click_timer -= dt;
            if (self.double_click_timer < 0) {
                self.double_click_timer = 0;
            }
        }

        if (self.left_just) {
            if (self.double_click_timer > 0) {
                // Second click within window -- mark as double click
                self.double_click_timer = -1.0;
            } else {
                // First click -- start timer
                self.double_click_timer = double_click_threshold;
            }
        }

        self.left_down = left;
        self.right_down = right;
        self.last_left = left;
        self.last_right = right;
        self.scroll_delta += scroll;
    }

    /// Returns true if a double click was detected on the most recent update.
    pub fn isDoubleClick(self: MouseState) bool {
        return self.double_click_timer < 0;
    }

    /// Returns the accumulated scroll delta and resets it to zero.
    pub fn consumeScroll(self: *MouseState) i32 {
        const delta = self.scroll_delta;
        self.scroll_delta = 0;
        return delta;
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "default state has all fields zeroed/false" {
    const state = MouseState{};
    try std.testing.expect(!state.left_down);
    try std.testing.expect(!state.right_down);
    try std.testing.expect(!state.left_just);
    try std.testing.expect(!state.right_just);
    try std.testing.expectEqual(@as(i32, 0), state.scroll_delta);
    try std.testing.expect(!state.last_left);
    try std.testing.expect(!state.last_right);
    try std.testing.expectEqual(@as(f32, 0), state.double_click_timer);
}

test "left_just detects rising edge" {
    var state = MouseState{};

    // Press left
    state.update(true, false, 0, 0.016);
    try std.testing.expect(state.left_just);
    try std.testing.expect(state.left_down);

    // Hold left -- no longer "just pressed"
    state.update(true, false, 0, 0.016);
    try std.testing.expect(!state.left_just);
    try std.testing.expect(state.left_down);
}

test "right_just detects rising edge" {
    var state = MouseState{};

    state.update(false, true, 0, 0.016);
    try std.testing.expect(state.right_just);
    try std.testing.expect(state.right_down);

    state.update(false, true, 0, 0.016);
    try std.testing.expect(!state.right_just);
    try std.testing.expect(state.right_down);
}

test "release clears down flags" {
    var state = MouseState{};

    state.update(true, true, 0, 0.016);
    try std.testing.expect(state.left_down);
    try std.testing.expect(state.right_down);

    state.update(false, false, 0, 0.016);
    try std.testing.expect(!state.left_down);
    try std.testing.expect(!state.right_down);
}

test "double click detected within threshold" {
    var state = MouseState{};

    // First click
    state.update(true, false, 0, 0.016);
    try std.testing.expect(!state.isDoubleClick());

    // Release
    state.update(false, false, 0, 0.05);
    try std.testing.expect(!state.isDoubleClick());

    // Second click within 0.3s
    state.update(true, false, 0, 0.1);
    try std.testing.expect(state.isDoubleClick());
}

test "double click not detected after threshold expires" {
    var state = MouseState{};

    // First click
    state.update(true, false, 0, 0.016);
    // Release
    state.update(false, false, 0, 0.016);

    // Wait past the threshold
    state.update(false, false, 0, 0.35);
    try std.testing.expect(!state.isDoubleClick());

    // Click again -- this is a new first click, not a double click
    state.update(true, false, 0, 0.016);
    try std.testing.expect(!state.isDoubleClick());
}

test "scroll delta accumulates across frames" {
    var state = MouseState{};

    state.update(false, false, 3, 0.016);
    state.update(false, false, -1, 0.016);
    try std.testing.expectEqual(@as(i32, 2), state.scroll_delta);
}

test "consumeScroll returns delta and resets" {
    var state = MouseState{};

    state.update(false, false, 5, 0.016);
    state.update(false, false, 2, 0.016);

    const delta = state.consumeScroll();
    try std.testing.expectEqual(@as(i32, 7), delta);
    try std.testing.expectEqual(@as(i32, 0), state.scroll_delta);
}

test "consumeScroll returns zero when no scroll" {
    var state = MouseState{};
    const delta = state.consumeScroll();
    try std.testing.expectEqual(@as(i32, 0), delta);
}

test "left and right just-pressed are independent" {
    var state = MouseState{};

    // Press both simultaneously
    state.update(true, true, 0, 0.016);
    try std.testing.expect(state.left_just);
    try std.testing.expect(state.right_just);

    // Hold both
    state.update(true, true, 0, 0.016);
    try std.testing.expect(!state.left_just);
    try std.testing.expect(!state.right_just);

    // Release left only
    state.update(false, true, 0, 0.016);
    try std.testing.expect(!state.left_just);
    try std.testing.expect(!state.right_just);

    // Re-press left while right is still held
    state.update(true, true, 0, 0.016);
    try std.testing.expect(state.left_just);
    try std.testing.expect(!state.right_just);
}

test "double click resets after being consumed by next update" {
    var state = MouseState{};

    // Trigger a double click
    state.update(true, false, 0, 0.016);
    state.update(false, false, 0, 0.05);
    state.update(true, false, 0, 0.1);
    try std.testing.expect(state.isDoubleClick());

    // Release and wait -- double click sentinel persists until next click
    state.update(false, false, 0, 0.016);
    state.update(false, false, 0, 2.0);

    // New click starts a fresh cycle, not a double click
    state.update(true, false, 0, 0.016);
    try std.testing.expect(!state.isDoubleClick());
}

test "scroll delta with negative values" {
    var state = MouseState{};

    state.update(false, false, -3, 0.016);
    try std.testing.expectEqual(@as(i32, -3), state.scroll_delta);

    state.update(false, false, -2, 0.016);
    try std.testing.expectEqual(@as(i32, -5), state.scroll_delta);

    const delta = state.consumeScroll();
    try std.testing.expectEqual(@as(i32, -5), delta);
    try std.testing.expectEqual(@as(i32, 0), state.scroll_delta);
}

test "rapid click-release-click within threshold is double click" {
    var state = MouseState{};

    // Click 1: press
    state.update(true, false, 0, 0.016);
    try std.testing.expect(state.left_just);
    try std.testing.expect(!state.isDoubleClick());

    // Click 1: release
    state.update(false, false, 0, 0.016);

    // Click 2: press (within threshold)
    state.update(true, false, 0, 0.016);
    try std.testing.expect(state.left_just);
    try std.testing.expect(state.isDoubleClick());

    // Click 2: release
    state.update(false, false, 0, 0.016);

    // Click 3: press -- should NOT be a double click (timer was reset)
    state.update(true, false, 0, 0.016);
    try std.testing.expect(state.left_just);
    try std.testing.expect(!state.isDoubleClick());
}
