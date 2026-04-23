const std = @import("std");

pub const LADDER_BLOCK: u16 = 42;
pub const VINE_BLOCK: u16 = 600;

const climb_up_vy: f32 = 0.12;
const slide_down_vy: f32 = -0.05;
const hold_vy: f32 = 0.0;

const neutral: ClimbResult = .{ .vy = 0, .cancel_gravity = false };

pub const ClimbResult = struct {
    vy: f32,
    cancel_gravity: bool,
};

pub const ClimbState = struct {
    on_ladder: bool = false,
    on_vine: bool = false,

    /// Update climb state for the current tick.
    ///
    /// Sets `on_ladder` / `on_vine` from `block_at_feet` and returns the
    /// velocity + gravity-cancel result for ladders.  For vines, call
    /// `updateVineClimb` afterwards with the adjacent-solid check.
    pub fn update(
        self: *ClimbState,
        block_at_feet: u16,
        forward_pressed: bool,
        sneak_pressed: bool,
        space_pressed: bool,
    ) ClimbResult {
        _ = space_pressed;

        self.on_ladder = block_at_feet == LADDER_BLOCK;
        self.on_vine = block_at_feet == VINE_BLOCK;

        if (self.on_ladder) {
            return .{
                .vy = getClimbSpeed(forward_pressed, sneak_pressed),
                .cancel_gravity = true,
            };
        }

        return neutral;
    }

    /// Vine-specific update that accounts for adjacent solid block support.
    /// Must be called after `update` when `on_vine` is true.
    pub fn updateVineClimb(
        self: *ClimbState,
        has_adjacent_solid: bool,
        forward_pressed: bool,
        sneak_pressed: bool,
    ) ClimbResult {
        if (!self.on_vine or !has_adjacent_solid) {
            return neutral;
        }

        return .{
            .vy = getClimbSpeed(forward_pressed, sneak_pressed),
            .cancel_gravity = true,
        };
    }

    /// True when the player is on any climbable surface.
    pub fn isClimbing(self: ClimbState) bool {
        return self.on_ladder or self.on_vine;
    }
};

/// Return the vertical velocity for the given input combination.
///   - forward + not sneak  -> climb up   ( 0.12)
///   - sneak                -> hold        ( 0.00)
///   - no input             -> slide down  (-0.05)
pub fn getClimbSpeed(forward: bool, sneak: bool) f32 {
    if (sneak) return hold_vy;
    if (forward) return climb_up_vy;
    return slide_down_vy;
}

/// Returns `true` when `block_id` is a block the player can climb.
pub fn isClimbable(block_id: u16) bool {
    return block_id == LADDER_BLOCK or block_id == VINE_BLOCK;
}

// ──────────────────────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────────────────────

test "default state has no climb flags set" {
    const state = ClimbState{};
    try std.testing.expect(!state.on_ladder);
    try std.testing.expect(!state.on_vine);
}

test "isClimbable recognises ladder" {
    try std.testing.expect(isClimbable(LADDER_BLOCK));
}

test "isClimbable recognises vine" {
    try std.testing.expect(isClimbable(VINE_BLOCK));
}

test "isClimbable rejects ordinary blocks" {
    try std.testing.expect(!isClimbable(0));
    try std.testing.expect(!isClimbable(1));
    try std.testing.expect(!isClimbable(999));
}

test "getClimbSpeed forward returns climb up velocity" {
    try std.testing.expectEqual(@as(f32, 0.12), getClimbSpeed(true, false));
}

test "getClimbSpeed sneak returns hold velocity" {
    try std.testing.expectEqual(@as(f32, 0.0), getClimbSpeed(false, true));
}

test "getClimbSpeed sneak overrides forward" {
    try std.testing.expectEqual(@as(f32, 0.0), getClimbSpeed(true, true));
}

test "getClimbSpeed no input returns slide down velocity" {
    try std.testing.expectEqual(@as(f32, -0.05), getClimbSpeed(false, false));
}

test "ladder climb up with forward pressed" {
    var state = ClimbState{};
    const result = state.update(LADDER_BLOCK, true, false, false);
    try std.testing.expect(state.on_ladder);
    try std.testing.expectEqual(@as(f32, 0.12), result.vy);
    try std.testing.expect(result.cancel_gravity);
}

test "ladder hold position with sneak" {
    var state = ClimbState{};
    const result = state.update(LADDER_BLOCK, false, true, false);
    try std.testing.expectEqual(@as(f32, 0.0), result.vy);
    try std.testing.expect(result.cancel_gravity);
}

test "ladder slide down with no input" {
    var state = ClimbState{};
    const result = state.update(LADDER_BLOCK, false, false, false);
    try std.testing.expectEqual(@as(f32, -0.05), result.vy);
    try std.testing.expect(result.cancel_gravity);
}

test "vine without adjacent solid does not cancel gravity" {
    var state = ClimbState{};
    _ = state.update(VINE_BLOCK, true, false, false);
    try std.testing.expect(state.on_vine);

    const result = state.updateVineClimb(false, true, false);
    try std.testing.expectEqual(@as(f32, 0), result.vy);
    try std.testing.expect(!result.cancel_gravity);
}

test "vine with adjacent solid allows climbing" {
    var state = ClimbState{};
    _ = state.update(VINE_BLOCK, true, false, false);

    const result = state.updateVineClimb(true, true, false);
    try std.testing.expectEqual(@as(f32, 0.12), result.vy);
    try std.testing.expect(result.cancel_gravity);
}

test "vine sneak with adjacent solid holds position" {
    var state = ClimbState{};
    _ = state.update(VINE_BLOCK, false, true, false);

    const result = state.updateVineClimb(true, false, true);
    try std.testing.expectEqual(@as(f32, 0.0), result.vy);
    try std.testing.expect(result.cancel_gravity);
}

test "stepping off climbable resets flags" {
    var state = ClimbState{};

    _ = state.update(LADDER_BLOCK, true, false, false);
    try std.testing.expect(state.on_ladder);

    const result = state.update(1, false, false, false);
    try std.testing.expect(!state.on_ladder);
    try std.testing.expect(!state.on_vine);
    try std.testing.expectEqual(@as(f32, 0), result.vy);
    try std.testing.expect(!result.cancel_gravity);
}

test "isClimbing reflects combined state" {
    var state = ClimbState{};
    try std.testing.expect(!state.isClimbing());

    _ = state.update(LADDER_BLOCK, false, false, false);
    try std.testing.expect(state.isClimbing());

    _ = state.update(VINE_BLOCK, false, false, false);
    try std.testing.expect(state.isClimbing());

    _ = state.update(0, false, false, false);
    try std.testing.expect(!state.isClimbing());
}

test "ladder sneak with forward still holds (sneak takes priority)" {
    var state = ClimbState{};
    const result = state.update(LADDER_BLOCK, true, true, false);
    try std.testing.expectEqual(@as(f32, 0.0), result.vy);
    try std.testing.expect(result.cancel_gravity);
}

test "vine updateVineClimb without prior update returns neutral" {
    var state = ClimbState{};
    const result = state.updateVineClimb(true, true, false);
    try std.testing.expectEqual(@as(f32, 0), result.vy);
    try std.testing.expect(!result.cancel_gravity);
}
