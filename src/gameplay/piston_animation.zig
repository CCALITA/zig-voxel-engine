/// Piston animation state machine for rendering piston extend/retract cycles.
/// Tracks progress from 0.0 (retracted) to 1.0 (extended) over a fixed
/// duration, with four discrete states: retracted, extending, extended,
/// retracting. Used by the renderer to interpolate the piston head and
/// pushed-block positions each frame.

const std = @import("std");

// ──────────────────────────────────────────────────────────────────────────────
// Block constants (mirrored from world/block.zig to stay dependency-free)
// ──────────────────────────────────────────────────────────────────────────────

const BEDROCK: u16 = 11;
const OBSIDIAN: u16 = 19;

// ──────────────────────────────────────────────────────────────────────────────
// Animation timing
// ──────────────────────────────────────────────────────────────────────────────

/// Duration of a full extend or retract cycle in seconds.
const anim_duration: f32 = 0.15;

// ──────────────────────────────────────────────────────────────────────────────
// Public types
// ──────────────────────────────────────────────────────────────────────────────

pub const PistonState = enum {
    retracted,
    extending,
    extended,
    retracting,
};

pub const PistonAnim = struct {
    state: PistonState = .retracted,
    progress: f32 = 0,
    is_sticky: bool = false,
    facing: u3 = 0,

    /// Begin extending from the retracted state.  Does nothing if the piston
    /// is not currently retracted.
    pub fn extend(self: *PistonAnim) void {
        if (self.state != .retracted) return;
        self.state = .extending;
        self.progress = 0;
    }

    /// Begin retracting from the extended state.  Does nothing if the piston
    /// is not currently extended.
    pub fn retract(self: *PistonAnim) void {
        if (self.state != .extended) return;
        self.state = .retracting;
        self.progress = 1.0;
    }

    /// Advance the animation by `dt` seconds.  Clamps progress to [0, 1] and
    /// transitions to the resting state when the animation completes.
    pub fn update(self: *PistonAnim, dt: f32) void {
        switch (self.state) {
            .extending => {
                self.progress = @min(self.progress + dt / anim_duration, 1.0);
                if (self.progress >= 1.0) {
                    self.state = .extended;
                    self.progress = 1.0;
                }
            },
            .retracting => {
                self.progress = @max(self.progress - dt / anim_duration, 0.0);
                if (self.progress <= 0.0) {
                    self.state = .retracted;
                    self.progress = 0.0;
                }
            },
            .retracted, .extended => {},
        }
    }

    /// Current extension factor for rendering, in the range [0.0, 1.0].
    pub fn getExtension(self: PistonAnim) f32 {
        return self.progress;
    }

    /// Returns true when the piston is fully extended and at rest.
    pub fn isFullyExtended(self: PistonAnim) bool {
        return self.state == .extended;
    }
};

// ──────────────────────────────────────────────────────────────────────────────
// Block pushability
// ──────────────────────────────────────────────────────────────────────────────

/// Returns true when the given block can be pushed by a piston.
/// Obsidian and bedrock are immovable.
pub fn canPushBlock(block_id: u16) bool {
    return block_id != BEDROCK and block_id != OBSIDIAN;
}

/// Maximum number of blocks a piston can push in a single extension.
pub fn getMaxPushCount() u8 {
    return 12;
}

// ──────────────────────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────────────────────

test "default state is retracted with zero progress" {
    const anim = PistonAnim{};
    try std.testing.expectEqual(PistonState.retracted, anim.state);
    try std.testing.expectEqual(@as(f32, 0.0), anim.progress);
    try std.testing.expectEqual(@as(f32, 0.0), anim.getExtension());
}

test "extend transitions from retracted to extending" {
    var anim = PistonAnim{};
    anim.extend();
    try std.testing.expectEqual(PistonState.extending, anim.state);
    try std.testing.expectEqual(@as(f32, 0.0), anim.progress);
}

test "extend is no-op when not retracted" {
    var anim = PistonAnim{ .state = .extended, .progress = 1.0 };
    anim.extend();
    try std.testing.expectEqual(PistonState.extended, anim.state);
}

test "retract transitions from extended to retracting" {
    var anim = PistonAnim{ .state = .extended, .progress = 1.0 };
    anim.retract();
    try std.testing.expectEqual(PistonState.retracting, anim.state);
    try std.testing.expectEqual(@as(f32, 1.0), anim.progress);
}

test "retract is no-op when not extended" {
    var anim = PistonAnim{};
    anim.retract();
    try std.testing.expectEqual(PistonState.retracted, anim.state);
}

test "update completes extension in 0.15s" {
    var anim = PistonAnim{};
    anim.extend();
    anim.update(0.15);
    try std.testing.expectEqual(PistonState.extended, anim.state);
    try std.testing.expectEqual(@as(f32, 1.0), anim.getExtension());
    try std.testing.expect(anim.isFullyExtended());
}

test "update completes retraction in 0.15s" {
    var anim = PistonAnim{ .state = .extended, .progress = 1.0 };
    anim.retract();
    anim.update(0.15);
    try std.testing.expectEqual(PistonState.retracted, anim.state);
    try std.testing.expectEqual(@as(f32, 0.0), anim.getExtension());
}

test "partial update produces intermediate progress" {
    var anim = PistonAnim{};
    anim.extend();
    anim.update(0.075); // half the duration
    try std.testing.expectEqual(PistonState.extending, anim.state);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), anim.getExtension(), 0.001);
    try std.testing.expect(!anim.isFullyExtended());
}

test "progress clamps and does not overshoot" {
    var anim = PistonAnim{};
    anim.extend();
    anim.update(1.0); // way more than 0.15s
    try std.testing.expectEqual(@as(f32, 1.0), anim.getExtension());
    try std.testing.expectEqual(PistonState.extended, anim.state);
}

test "full extend-then-retract cycle" {
    var anim = PistonAnim{};
    anim.extend();
    anim.update(0.15);
    try std.testing.expect(anim.isFullyExtended());

    anim.retract();
    anim.update(0.15);
    try std.testing.expectEqual(PistonState.retracted, anim.state);
    try std.testing.expectEqual(@as(f32, 0.0), anim.getExtension());
}

test "update is no-op in resting states" {
    var retracted = PistonAnim{};
    retracted.update(1.0);
    try std.testing.expectEqual(PistonState.retracted, retracted.state);
    try std.testing.expectEqual(@as(f32, 0.0), retracted.progress);

    var extended = PistonAnim{ .state = .extended, .progress = 1.0 };
    extended.update(1.0);
    try std.testing.expectEqual(PistonState.extended, extended.state);
    try std.testing.expectEqual(@as(f32, 1.0), extended.progress);
}

test "canPushBlock rejects obsidian and bedrock" {
    try std.testing.expect(!canPushBlock(OBSIDIAN));
    try std.testing.expect(!canPushBlock(BEDROCK));
}

test "canPushBlock allows normal blocks" {
    try std.testing.expect(canPushBlock(0)); // air
    try std.testing.expect(canPushBlock(1)); // stone
    try std.testing.expect(canPushBlock(2)); // dirt
    try std.testing.expect(canPushBlock(100)); // arbitrary id
}

test "getMaxPushCount returns 12" {
    try std.testing.expectEqual(@as(u8, 12), getMaxPushCount());
}

test "sticky flag and facing are preserved" {
    const anim = PistonAnim{ .is_sticky = true, .facing = 4 };
    try std.testing.expect(anim.is_sticky);
    try std.testing.expectEqual(@as(u3, 4), anim.facing);
}

test "incremental updates accumulate correctly" {
    var anim = PistonAnim{};
    anim.extend();
    // Two steps of 0.05s then one of 0.06s (> remaining 0.05) to guarantee completion.
    anim.update(0.05);
    anim.update(0.05);
    try std.testing.expectEqual(PistonState.extending, anim.state);
    anim.update(0.06);
    try std.testing.expectEqual(PistonState.extended, anim.state);
    try std.testing.expectEqual(@as(f32, 1.0), anim.getExtension());
}
