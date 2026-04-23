/// Creeper fuse visual effects: alternating white flash overlay and body swell.
/// The flash frequency increases as the fuse timer approaches detonation,
/// and the creeper model scales from 1.0x to 1.2x over the 1.5-second fuse.
const std = @import("std");

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const FUSE_DURATION: f32 = 1.5;
const MAX_SWELL: f32 = 1.2;
const BASE_FLASH_FREQ: f32 = 4.0;
const MAX_FLASH_FREQ: f32 = 16.0;

// ---------------------------------------------------------------------------
// Public type
// ---------------------------------------------------------------------------

/// Tracks the visual state of a creeper's fuse countdown.
pub const CreeperVisual = struct {
    fuse_timer: f32 = 0,
    is_fusing: bool = false,

    /// Begin the fuse countdown, resetting the timer to zero.
    pub fn startFuse(self: *CreeperVisual) void {
        self.is_fusing = true;
        self.fuse_timer = 0;
    }

    /// Cancel the fuse, resetting all visual state.
    pub fn cancelFuse(self: *CreeperVisual) void {
        self.is_fusing = false;
        self.fuse_timer = 0;
    }

    /// Advance the fuse timer by `dt` seconds.
    /// Returns `true` when the creeper explodes (timer reaches 1.5s).
    pub fn update(self: *CreeperVisual, dt: f32) bool {
        if (!self.is_fusing) return false;
        self.fuse_timer += dt;
        if (self.fuse_timer >= FUSE_DURATION) {
            self.fuse_timer = FUSE_DURATION;
            self.is_fusing = false;
            return true;
        }
        return false;
    }

    /// Flash intensity in [0, 1]. The flash alternates using a sine wave
    /// whose frequency ramps from BASE_FLASH_FREQ to MAX_FLASH_FREQ as
    /// the fuse progresses, producing faster flashing near detonation.
    pub fn getFlashIntensity(self: CreeperVisual) f32 {
        if (!self.is_fusing) return 0;
        const progress = self.fuse_timer / FUSE_DURATION;
        const freq = BASE_FLASH_FREQ + (MAX_FLASH_FREQ - BASE_FLASH_FREQ) * progress;
        const wave = @sin(self.fuse_timer * freq * std.math.pi * 2.0);
        return @max(0, wave);
    }

    /// Body swell factor that linearly interpolates from 1.0 to 1.2
    /// over the fuse duration.
    pub fn getSwellScale(self: CreeperVisual) f32 {
        if (!self.is_fusing) return 1.0;
        const progress = self.fuse_timer / FUSE_DURATION;
        return 1.0 + (MAX_SWELL - 1.0) * progress;
    }

    /// Whether the creeper model should currently render with a white
    /// overlay. True when the flash intensity exceeds 0.5.
    pub fn shouldRenderWhite(self: CreeperVisual) bool {
        return self.getFlashIntensity() > 0.5;
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "default CreeperVisual is idle" {
    const cv = CreeperVisual{};
    try std.testing.expect(!cv.is_fusing);
    try std.testing.expectApproxEqAbs(@as(f32, 0), cv.fuse_timer, 0.0001);
}

test "startFuse activates fusing and resets timer" {
    var cv = CreeperVisual{ .fuse_timer = 0.5, .is_fusing = false };
    cv.startFuse();
    try std.testing.expect(cv.is_fusing);
    try std.testing.expectApproxEqAbs(@as(f32, 0), cv.fuse_timer, 0.0001);
}

test "cancelFuse deactivates fusing and resets timer" {
    var cv = CreeperVisual{};
    cv.startFuse();
    _ = cv.update(0.5);
    cv.cancelFuse();
    try std.testing.expect(!cv.is_fusing);
    try std.testing.expectApproxEqAbs(@as(f32, 0), cv.fuse_timer, 0.0001);
}

test "update returns false while fusing" {
    var cv = CreeperVisual{};
    cv.startFuse();
    const exploded = cv.update(0.5);
    try std.testing.expect(!exploded);
    try std.testing.expect(cv.is_fusing);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), cv.fuse_timer, 0.0001);
}

test "update returns true at 1.5s detonation" {
    var cv = CreeperVisual{};
    cv.startFuse();
    _ = cv.update(1.0);
    const exploded = cv.update(0.5);
    try std.testing.expect(exploded);
    try std.testing.expectApproxEqAbs(FUSE_DURATION, cv.fuse_timer, 0.0001);
    try std.testing.expect(!cv.is_fusing);
}

test "update does nothing when not fusing" {
    var cv = CreeperVisual{};
    const exploded = cv.update(1.0);
    try std.testing.expect(!exploded);
    try std.testing.expectApproxEqAbs(@as(f32, 0), cv.fuse_timer, 0.0001);
}

test "getFlashIntensity is zero when not fusing" {
    const cv = CreeperVisual{};
    try std.testing.expectApproxEqAbs(@as(f32, 0), cv.getFlashIntensity(), 0.0001);
}

test "getFlashIntensity returns values in 0-1 while fusing" {
    var cv = CreeperVisual{};
    cv.startFuse();
    // Sample at many points to verify bounds
    var t: f32 = 0.01;
    while (t < FUSE_DURATION) : (t += 0.01) {
        cv.fuse_timer = t;
        const intensity = cv.getFlashIntensity();
        try std.testing.expect(intensity >= 0.0);
        try std.testing.expect(intensity <= 1.0);
    }
}

test "getSwellScale is 1.0 when not fusing" {
    const cv = CreeperVisual{};
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), cv.getSwellScale(), 0.0001);
}

test "getSwellScale grows from 1.0 to 1.2 over fuse" {
    var cv = CreeperVisual{};
    cv.startFuse();

    // At the start
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), cv.getSwellScale(), 0.0001);

    // At midpoint
    cv.fuse_timer = FUSE_DURATION / 2.0;
    try std.testing.expectApproxEqAbs(@as(f32, 1.1), cv.getSwellScale(), 0.0001);

    // At the end
    cv.fuse_timer = FUSE_DURATION;
    try std.testing.expectApproxEqAbs(@as(f32, 1.2), cv.getSwellScale(), 0.0001);
}

test "shouldRenderWhite is false when not fusing" {
    const cv = CreeperVisual{};
    try std.testing.expect(!cv.shouldRenderWhite());
}

test "shouldRenderWhite alternates during fuse" {
    var cv = CreeperVisual{};
    cv.startFuse();

    var white_count: u32 = 0;
    var normal_count: u32 = 0;
    var t: f32 = 0.01;
    while (t < FUSE_DURATION) : (t += 0.005) {
        cv.fuse_timer = t;
        if (cv.shouldRenderWhite()) {
            white_count += 1;
        } else {
            normal_count += 1;
        }
    }
    // Both states must appear — the flash alternates
    try std.testing.expect(white_count > 0);
    try std.testing.expect(normal_count > 0);
}

test "flash frequency increases near detonation" {
    var cv = CreeperVisual{};
    cv.startFuse();

    // Count white-to-normal transitions in the first half vs second half.
    // More transitions in the second half means higher frequency.
    const count_transitions = struct {
        fn f(visual: *CreeperVisual, start: f32, end: f32) u32 {
            var transitions: u32 = 0;
            var prev_white = false;
            var t = start;
            while (t < end) : (t += 0.001) {
                visual.fuse_timer = t;
                const w = visual.shouldRenderWhite();
                if (w != prev_white) transitions += 1;
                prev_white = w;
            }
            return transitions;
        }
    }.f;

    const first_half = count_transitions(&cv, 0.01, FUSE_DURATION / 2.0);
    const second_half = count_transitions(&cv, FUSE_DURATION / 2.0, FUSE_DURATION);
    try std.testing.expect(second_half > first_half);
}

test "multiple update calls accumulate timer" {
    var cv = CreeperVisual{};
    cv.startFuse();
    _ = cv.update(0.3);
    _ = cv.update(0.3);
    _ = cv.update(0.3);
    try std.testing.expectApproxEqAbs(@as(f32, 0.9), cv.fuse_timer, 0.0001);
    try std.testing.expect(cv.is_fusing);
}

test "restart fuse after cancel resets properly" {
    var cv = CreeperVisual{};
    cv.startFuse();
    _ = cv.update(1.0);
    cv.cancelFuse();
    cv.startFuse();
    try std.testing.expectApproxEqAbs(@as(f32, 0), cv.fuse_timer, 0.0001);
    try std.testing.expect(cv.is_fusing);
}
