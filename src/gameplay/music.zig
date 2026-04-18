/// Music and ambient sound system.
/// Tracks which background music track should play based on dimension,
/// time of day, and biome. Also handles note block pitch calculation.

const std = @import("std");

pub const MusicTrack = enum {
    calm1,
    calm2,
    calm3,
    hal1,
    hal2,
    hal3,
    nether_ambient,
    end_ambient,
    creative_mode,
    none,
};

/// Select the appropriate background music track based on game state.
pub fn selectTrack(is_creative: bool, dimension: u8, is_night: bool) MusicTrack {
    if (is_creative) return .creative_mode;
    return switch (dimension) {
        1 => .nether_ambient, // nether
        2 => .end_ambient, // end
        else => if (is_night) .hal1 else .calm1,
    };
}

/// Note block pitch: returns frequency multiplier for a given note (0-24).
pub fn getNotePitch(note: u8) f32 {
    const clamped: f32 = @floatFromInt(@min(note, 24));
    // Two octaves: each semitone is 2^(1/12) apart
    return std.math.pow(f32, 2.0, (clamped - 12.0) / 12.0);
}

/// Minimum interval (seconds) between ambient music tracks.
pub const MIN_MUSIC_INTERVAL: f32 = 60.0;

/// Maximum interval (seconds) between ambient music tracks.
pub const MAX_MUSIC_INTERVAL: f32 = 300.0;

// ──────────────────────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────────────────────

test "selectTrack creative mode" {
    try std.testing.expectEqual(MusicTrack.creative_mode, selectTrack(true, 0, false));
}

test "selectTrack nether" {
    try std.testing.expectEqual(MusicTrack.nether_ambient, selectTrack(false, 1, false));
}

test "selectTrack overworld night" {
    try std.testing.expectEqual(MusicTrack.hal1, selectTrack(false, 0, true));
}

test "selectTrack overworld day" {
    try std.testing.expectEqual(MusicTrack.calm1, selectTrack(false, 0, false));
}

test "getNotePitch middle note is 1.0" {
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), getNotePitch(12), 0.001);
}

test "getNotePitch increases with note" {
    try std.testing.expect(getNotePitch(24) > getNotePitch(12));
    try std.testing.expect(getNotePitch(12) > getNotePitch(0));
}
