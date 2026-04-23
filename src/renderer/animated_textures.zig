/// Animated texture lookup and frame computation for the texture atlas.
///
/// Each animated texture occupies a contiguous range of tile indices in the
/// atlas starting at `base_tex`.  At runtime the current frame is selected
/// from elapsed time and the per-entry `frame_dur` (seconds per frame).
const std = @import("std");

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

pub const AnimEntry = struct {
    base_tex: u16,
    frames: u8,
    frame_dur: f32,
};

// ---------------------------------------------------------------------------
// Animation table
// ---------------------------------------------------------------------------

/// Static table of all animated textures.
pub const ANIMATED = [_]AnimEntry{
    .{ .base_tex = 11, .frames = 32, .frame_dur = 0.05 },
    .{ .base_tex = 37, .frames = 20, .frame_dur = 0.1 },
};

// ---------------------------------------------------------------------------
// Atlas layout (mirrors texture_atlas.zig)
// ---------------------------------------------------------------------------

const ATLAS_TILES_PER_ROW: u32 = 64;

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Returns `true` when `tex` is the base index of an animated texture.
pub fn isAnimated(tex: u16) bool {
    for (ANIMATED) |entry| {
        if (tex == entry.base_tex) return true;
    }
    return false;
}

/// Returns the atlas tile index for the current animation frame.
///
/// If `tex` is not an animated base index the function returns `tex` unchanged.
pub fn getAnimatedFrame(tex: u16, time: f32) u16 {
    for (ANIMATED) |entry| {
        if (tex == entry.base_tex) {
            const period = @as(f32, @floatFromInt(entry.frames)) * entry.frame_dur;
            const wrapped = wrap(time, period);
            const frame_idx: u16 = @intFromFloat(wrapped / entry.frame_dur);
            return entry.base_tex + frame_idx;
        }
    }
    return tex;
}

/// Returns the UV pixel-offset (in normalised 0..1 atlas space) that
/// corresponds to the difference between `base_tex` and the current frame
/// tile.  Non-animated textures return `{0, 0}`.
pub fn getFrameUVOffset(tex: u16, time: f32) [2]f32 {
    const resolved = getAnimatedFrame(tex, time);
    if (resolved == tex) return .{ 0.0, 0.0 };

    const delta: u16 = resolved - tex;
    const cols: u16 = @intCast(ATLAS_TILES_PER_ROW);
    const dc = delta % cols;
    const dr = delta / cols;

    const inv: f32 = 1.0 / @as(f32, @floatFromInt(ATLAS_TILES_PER_ROW));
    return .{
        @as(f32, @floatFromInt(dc)) * inv,
        @as(f32, @floatFromInt(dr)) * inv,
    };
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/// Modulo wrapping into [0, period).  Zig's `@mod` already returns a
/// non-negative result when the divisor is positive.
fn wrap(t: f32, period: f32) f32 {
    if (period <= 0.0) return 0.0;
    return @mod(t, period);
}

// ===========================================================================
// Tests
// ===========================================================================

test "isAnimated returns true for known base textures" {
    try std.testing.expect(isAnimated(11));
    try std.testing.expect(isAnimated(37));
}

test "isAnimated returns false for non-animated textures" {
    try std.testing.expect(!isAnimated(0));
    try std.testing.expect(!isAnimated(10));
    try std.testing.expect(!isAnimated(12));
    try std.testing.expect(!isAnimated(36));
    try std.testing.expect(!isAnimated(38));
    try std.testing.expect(!isAnimated(255));
}

test "getAnimatedFrame returns base at time zero" {
    try std.testing.expectEqual(@as(u16, 11), getAnimatedFrame(11, 0.0));
    try std.testing.expectEqual(@as(u16, 37), getAnimatedFrame(37, 0.0));
}

test "getAnimatedFrame advances frame with time" {
    // entry 0: frame_dur = 0.05, so at t=0.05 we should be on frame 1
    try std.testing.expectEqual(@as(u16, 12), getAnimatedFrame(11, 0.05));
    // entry 1: frame_dur = 0.1, so at t=0.1 we should be on frame 1
    try std.testing.expectEqual(@as(u16, 38), getAnimatedFrame(37, 0.1));
}

test "getAnimatedFrame wraps around at period boundary" {
    // entry 0: 32 frames * 0.05 = 1.6s period, so t=1.6 wraps to frame 0
    try std.testing.expectEqual(@as(u16, 11), getAnimatedFrame(11, 1.6));
    // entry 1: 20 frames * 0.1 = 2.0s period, so t=2.0 wraps to frame 0
    try std.testing.expectEqual(@as(u16, 37), getAnimatedFrame(37, 2.0));
}

test "getAnimatedFrame returns tex unchanged for non-animated" {
    try std.testing.expectEqual(@as(u16, 5), getAnimatedFrame(5, 1.0));
    try std.testing.expectEqual(@as(u16, 100), getAnimatedFrame(100, 99.0));
}

test "getAnimatedFrame last frame before wrap" {
    // Use a time safely within the last frame to avoid float truncation:
    // entry 0: last frame starts at 31 * 0.05 = 1.55; use 1.559 to stay in frame 31
    try std.testing.expectEqual(@as(u16, 11 + 31), getAnimatedFrame(11, 1.559));
    // entry 1: last frame starts at 19 * 0.1 = 1.9; use 1.95 to stay in frame 19
    try std.testing.expectEqual(@as(u16, 37 + 19), getAnimatedFrame(37, 1.95));
}

test "getFrameUVOffset returns zero for non-animated" {
    const uv = getFrameUVOffset(5, 1.0);
    try std.testing.expectEqual(@as(f32, 0.0), uv[0]);
    try std.testing.expectEqual(@as(f32, 0.0), uv[1]);
}

test "getFrameUVOffset returns zero at time zero" {
    const uv = getFrameUVOffset(11, 0.0);
    try std.testing.expectEqual(@as(f32, 0.0), uv[0]);
    try std.testing.expectEqual(@as(f32, 0.0), uv[1]);
}

test "getFrameUVOffset returns correct offset for frame 1" {
    const uv = getFrameUVOffset(11, 0.05);
    // frame 1 is 1 tile to the right in the atlas row
    const expected_u: f32 = 1.0 / 64.0;
    try std.testing.expectApproxEqAbs(expected_u, uv[0], 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), uv[1], 1e-6);
}

test "getFrameUVOffset accounts for row wrapping" {
    // With the current table the max delta is 31 (< 64) so row is always 0.
    // Use 1.559 to land safely in frame 31 despite float truncation.
    const uv = getFrameUVOffset(11, 1.559); // frame 31
    const expected_u: f32 = 31.0 / 64.0;
    try std.testing.expectApproxEqAbs(expected_u, uv[0], 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), uv[1], 1e-6);
}

test "wrap handles negative time gracefully" {
    // Negative time should still produce a valid frame
    const frame = getAnimatedFrame(11, -0.05);
    // The wrapped time should be in [0, period), producing a valid base+offset
    try std.testing.expect(frame >= 11 and frame < 11 + 32);
}

test "ANIMATED table has expected entry count" {
    try std.testing.expectEqual(@as(usize, 2), ANIMATED.len);
}

test "AnimEntry fields are set correctly" {
    const first = ANIMATED[0];
    try std.testing.expectEqual(@as(u16, 11), first.base_tex);
    try std.testing.expectEqual(@as(u8, 32), first.frames);
    try std.testing.expectApproxEqAbs(@as(f32, 0.05), first.frame_dur, 1e-9);

    const second = ANIMATED[1];
    try std.testing.expectEqual(@as(u16, 37), second.base_tex);
    try std.testing.expectEqual(@as(u8, 20), second.frames);
    try std.testing.expectApproxEqAbs(@as(f32, 0.1), second.frame_dur, 1e-9);
}
