const std = @import("std");

pub const SleepResult = struct {
    can_sleep: bool,
    message: []const u8 = "",
    skip_to_dawn: bool = false,
    set_spawn: bool = false,
};

/// Attempt to sleep. Checks are evaluated in priority order:
/// not overworld > not night > hostiles nearby.
pub fn trySleep(is_night: bool, hostile_count_nearby: u8, in_overworld: bool) SleepResult {
    if (!in_overworld) return .{ .can_sleep = false, .message = "Cannot sleep here" };
    if (!is_night) return .{ .can_sleep = false, .message = "Can only sleep at night" };
    if (hostile_count_nearby > 0) return .{ .can_sleep = false, .message = "Monsters nearby" };

    return .{ .can_sleep = true, .skip_to_dawn = true, .set_spawn = true };
}

/// Ticks without sleeping before phantoms begin spawning (3 in-game nights).
pub const INSOMNIA_THRESHOLD: u64 = 72000;

/// Returns true when the player has gone long enough without sleep
/// for phantoms to start spawning.
pub fn shouldSpawnPhantom(ticks_since_sleep: u64) bool {
    return ticks_since_sleep >= INSOMNIA_THRESHOLD;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "successful sleep returns skip_to_dawn and set_spawn" {
    const result = trySleep(true, 0, true);
    try std.testing.expect(result.can_sleep);
    try std.testing.expect(result.skip_to_dawn);
    try std.testing.expect(result.set_spawn);
    try std.testing.expectEqualStrings("", result.message);
}

test "cannot sleep during the day" {
    const result = trySleep(false, 0, true);
    try std.testing.expect(!result.can_sleep);
    try std.testing.expectEqualStrings("Can only sleep at night", result.message);
    try std.testing.expect(!result.skip_to_dawn);
    try std.testing.expect(!result.set_spawn);
}

test "cannot sleep with hostiles nearby" {
    const result = trySleep(true, 3, true);
    try std.testing.expect(!result.can_sleep);
    try std.testing.expectEqualStrings("Monsters nearby", result.message);
    try std.testing.expect(!result.skip_to_dawn);
}

test "cannot sleep outside the overworld" {
    const result = trySleep(true, 0, false);
    try std.testing.expect(!result.can_sleep);
    try std.testing.expectEqualStrings("Cannot sleep here", result.message);
    try std.testing.expect(!result.skip_to_dawn);
}

test "overworld check takes priority over night check" {
    // Daytime + not overworld: should report dimension issue, not daytime
    const result = trySleep(false, 0, false);
    try std.testing.expectEqualStrings("Cannot sleep here", result.message);
}

test "overworld check takes priority over hostile check" {
    const result = trySleep(true, 5, false);
    try std.testing.expectEqualStrings("Cannot sleep here", result.message);
}

test "night check takes priority over hostile check" {
    // Daytime + hostiles: should report daytime issue
    const result = trySleep(false, 2, true);
    try std.testing.expectEqualStrings("Can only sleep at night", result.message);
}

test "single hostile is enough to prevent sleep" {
    const result = trySleep(true, 1, true);
    try std.testing.expect(!result.can_sleep);
    try std.testing.expectEqualStrings("Monsters nearby", result.message);
}

test "max hostiles still yields same message" {
    const result = trySleep(true, 255, true);
    try std.testing.expect(!result.can_sleep);
    try std.testing.expectEqualStrings("Monsters nearby", result.message);
}

test "phantom spawns at exactly the insomnia threshold" {
    try std.testing.expect(shouldSpawnPhantom(INSOMNIA_THRESHOLD));
}

test "phantom does not spawn one tick before threshold" {
    try std.testing.expect(!shouldSpawnPhantom(INSOMNIA_THRESHOLD - 1));
}

test "phantom spawns well after threshold" {
    try std.testing.expect(shouldSpawnPhantom(INSOMNIA_THRESHOLD + 100_000));
}

test "no phantom spawn at zero ticks" {
    try std.testing.expect(!shouldSpawnPhantom(0));
}

test "insomnia threshold equals 72000 ticks" {
    try std.testing.expectEqual(@as(u64, 72000), INSOMNIA_THRESHOLD);
}
