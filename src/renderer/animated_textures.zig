const std = @import("std");

/// Describes a texture that cycles through sequential frames in the atlas.
pub const AnimatedEntry = struct {
    base_tex: u16,
    frame_count: u8,
    frame_duration: f32,
};

/// Registry of all animated textures.
/// Each entry maps a base texture ID to its animation parameters.
/// Frames are assumed to occupy consecutive tile slots starting at base_tex.
pub const ANIMATED = [_]AnimatedEntry{
    // Water: 32 frames, fast ripple
    .{ .base_tex = 11, .frame_count = 32, .frame_duration = 0.05 },
    // Lava: 20 frames, slow churn
    .{ .base_tex = 37, .frame_count = 20, .frame_duration = 0.1 },
};

/// Atlas layout constants (mirrored from texture_atlas to keep this module self-contained).
const ATLAS_TILES_PER_ROW: u32 = 64;

/// Returns the texture ID for the current animation frame.
/// For non-animated textures the input tex_id is returned unchanged.
pub fn getAnimatedFrame(tex_id: u16, time: f32) u16 {
    const entry = findEntry(tex_id) orelse return tex_id;
    return tex_id + frameOffset(entry, time);
}

/// Returns true when tex_id corresponds to an animated texture base.
pub fn isAnimated(tex_id: u16) bool {
    return findEntry(tex_id) != null;
}

/// Returns a UV offset (in atlas-normalised coordinates) that shifts the
/// sampling rectangle from the base tile to the current animation frame.
/// For non-animated textures both components are 0.
pub fn getFrameUVOffset(tex_id: u16, time: f32) [2]f32 {
    const entry = findEntry(tex_id) orelse return .{ 0.0, 0.0 };
    return tileOffsetToUV(frameOffset(entry, time));
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

fn findEntry(tex_id: u16) ?AnimatedEntry {
    for (ANIMATED) |entry| {
        if (tex_id == entry.base_tex) return entry;
    }
    return null;
}

fn frameOffset(entry: AnimatedEntry, time: f32) u16 {
    const clamped_time: f32 = @max(0.0, time);
    const cycle_len = @as(f32, @floatFromInt(entry.frame_count)) * entry.frame_duration;
    const pos = @mod(clamped_time, cycle_len);
    const frame_idx: u32 = @intFromFloat(pos / entry.frame_duration);
    const safe_idx = frame_idx % @as(u32, entry.frame_count);
    return @intCast(safe_idx);
}

fn tileOffsetToUV(offset: u16) [2]f32 {
    const tiles_per_row: f32 = @floatFromInt(ATLAS_TILES_PER_ROW);
    const col: f32 = @floatFromInt(offset % ATLAS_TILES_PER_ROW);
    const row: f32 = @floatFromInt(offset / ATLAS_TILES_PER_ROW);
    return .{ col / tiles_per_row, row / tiles_per_row };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "non-animated texture returns same id" {
    try std.testing.expectEqual(@as(u16, 0), getAnimatedFrame(0, 1.0));
    try std.testing.expectEqual(@as(u16, 5), getAnimatedFrame(5, 99.0));
}

test "animated water returns base at time zero" {
    try std.testing.expectEqual(@as(u16, 11), getAnimatedFrame(11, 0.0));
}

test "animated water advances one frame" {
    // frame_duration = 0.05, so at t=0.05 we should be in frame 1
    try std.testing.expectEqual(@as(u16, 12), getAnimatedFrame(11, 0.05));
}

test "animated water wraps around" {
    // 32 frames * 0.05 = 1.6s cycle; at t=1.6 we wrap back to frame 0
    try std.testing.expectEqual(@as(u16, 11), getAnimatedFrame(11, 1.6));
}

test "animated lava at half cycle" {
    // 20 frames * 0.1 = 2.0s cycle; at t=1.0 -> frame 10
    try std.testing.expectEqual(@as(u16, 47), getAnimatedFrame(37, 1.0));
}

test "isAnimated true for water" {
    try std.testing.expect(isAnimated(11));
}

test "isAnimated true for lava" {
    try std.testing.expect(isAnimated(37));
}

test "isAnimated false for stone" {
    try std.testing.expect(!isAnimated(0));
}

test "isAnimated false for arbitrary id" {
    try std.testing.expect(!isAnimated(255));
}

test "getFrameUVOffset zero for non-animated" {
    const uv = getFrameUVOffset(0, 5.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), uv[0], 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), uv[1], 1e-6);
}

test "getFrameUVOffset water frame 1" {
    // frame 1 -> offset 1 tile in the atlas row
    const uv = getFrameUVOffset(11, 0.05);
    const expected_u: f32 = 1.0 / 64.0;
    try std.testing.expectApproxEqAbs(expected_u, uv[0], 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), uv[1], 1e-6);
}

test "getFrameUVOffset wraps same as getAnimatedFrame" {
    // Ensure UV offset at cycle boundary is zero (back to frame 0)
    const uv = getFrameUVOffset(11, 1.6);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), uv[0], 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), uv[1], 1e-6);
}

test "negative time clamped to zero" {
    try std.testing.expectEqual(@as(u16, 11), getAnimatedFrame(11, -5.0));
}

test "very large time still produces valid frame" {
    const frame = getAnimatedFrame(11, 100_000.0);
    try std.testing.expect(frame >= 11 and frame < 11 + 32);
}

test "lava full cycle returns to base" {
    // 20 * 0.1 = 2.0
    try std.testing.expectEqual(@as(u16, 37), getAnimatedFrame(37, 2.0));
}
