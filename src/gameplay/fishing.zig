/// Fishing system.
/// Supports casting a line, waiting for a bite, and reeling in catches.
/// Loot follows Minecraft-style probabilities: 85% fish, 10% junk, 5% treasure.
/// Wait time is 5-30 seconds (deterministic from seed). Reeling while hooked
/// yields a catch; reeling at any other time returns null (lost bait).

const std = @import("std");

pub const FishType = enum { raw_cod, raw_salmon, pufferfish, tropical_fish };
pub const LootCategory = enum { fish, treasure, junk };

const MIN_WAIT: f32 = 5.0;
const MAX_WAIT: f32 = 30.0;
/// Number of 0.1s ticks in the [MIN_WAIT, MAX_WAIT] range (inclusive).
const WAIT_RANGE_TICKS: u32 = @intFromFloat((MAX_WAIT - MIN_WAIT) * 10.0 + 1.0);

const FISH_ITEM_BASE: u16 = 600;
const JUNK_ITEM_BASE: u16 = 700;
const TREASURE_ITEM_BASE: u16 = 800;

pub const CatchResult = struct {
    category: LootCategory,
    item_id: u16,
    count: u8,
    xp: u32,
};

pub const FishingState = struct {
    phase: Phase = .idle,
    wait_timer: f32 = 0.0,
    bobber_x: f32 = 0,
    bobber_y: f32 = 0,
    bobber_z: f32 = 0,

    pub const Phase = enum { idle, waiting, hooked };

    pub fn init() FishingState {
        return .{};
    }

    /// Cast the fishing line to a target position.
    pub fn cast(self: *FishingState, x: f32, y: f32, z: f32) void {
        if (self.phase != .idle) return;
        self.bobber_x = x;
        self.bobber_y = y;
        self.bobber_z = z;

        const seed = positionSeed(x, y, z);
        var rng = std.Random.DefaultPrng.init(seed);
        // Wait 5-30s; deterministic so the same cast always produces the same timing.
        const wait: f32 = MIN_WAIT + @as(f32, @floatFromInt(rng.random().intRangeLessThan(u32, 0, WAIT_RANGE_TICKS))) / 10.0;
        self.wait_timer = wait;
        self.phase = .waiting;
    }

    /// Advance the fishing state by `dt` seconds. While waiting, counts down the
    /// timer and transitions to hooked when it reaches zero.
    pub fn update(self: *FishingState, dt: f32) void {
        switch (self.phase) {
            .waiting => {
                self.wait_timer -= dt;
                if (self.wait_timer <= 0.0) {
                    self.wait_timer = 0.0;
                    self.phase = .hooked;
                }
            },
            else => {},
        }
    }

    /// Attempt to reel in the line. Returns a catch only when the bobber is
    /// hooked. While waiting, reeling loses the bait and returns null.
    pub fn reel(self: *FishingState) ?CatchResult {
        switch (self.phase) {
            .hooked => {
                const seed = positionSeed(self.bobber_x, self.bobber_y, self.bobber_z);
                const result = rollCatch(seed);
                self.reset();
                return result;
            },
            .idle => return null,
            else => {
                self.reset();
                return null;
            },
        }
    }

    /// Cancel the cast and return to idle without catching anything.
    pub fn cancel(self: *FishingState) void {
        self.reset();
    }

    pub fn isHooked(self: *const FishingState) bool {
        return self.phase == .hooked;
    }

    fn reset(self: *FishingState) void {
        self.phase = .idle;
        self.wait_timer = 0.0;
        self.bobber_x = 0;
        self.bobber_y = 0;
        self.bobber_z = 0;
    }
};

// ---------------------------------------------------------------------------
// Free functions
// ---------------------------------------------------------------------------

/// Roll a catch result from a seed. Probability: 85% fish, 10% junk, 5% treasure.
pub fn rollCatch(seed: u64) CatchResult {
    var rng = std.Random.DefaultPrng.init(seed);
    const roll = rng.random().intRangeLessThan(u32, 0, 100);

    if (roll < 85) {
        // Fish (85%)
        const fish_roll = rng.random().intRangeLessThan(u32, 0, 4);
        const fish_type: FishType = @enumFromInt(fish_roll);
        return .{
            .category = .fish,
            .item_id = FISH_ITEM_BASE + @as(u16, @intCast(fish_roll)),
            .count = 1,
            .xp = switch (fish_type) {
                .raw_cod => 1,
                .raw_salmon => 2,
                .pufferfish => 3,
                .tropical_fish => 4,
            },
        };
    } else if (roll < 95) {
        // Junk (10%)
        const junk_id = rng.random().intRangeLessThan(u16, 0, 5);
        return .{
            .category = .junk,
            .item_id = JUNK_ITEM_BASE + junk_id,
            .count = 1,
            .xp = 1,
        };
    } else {
        // Treasure (5%)
        const treasure_id = rng.random().intRangeLessThan(u16, 0, 3);
        return .{
            .category = .treasure,
            .item_id = TREASURE_ITEM_BASE + treasure_id,
            .count = 1,
            .xp = 10,
        };
    }
}

/// Build a deterministic seed from bobber position floats.
fn positionSeed(x: f32, y: f32, z: f32) u64 {
    const bx: u32 = @bitCast(x);
    const by: u32 = @bitCast(y);
    const bz: u32 = @bitCast(z);
    return @as(u64, bx) *% 6364136223846793005 +%
        @as(u64, by) *% 1442695040888963407 +%
        @as(u64, bz);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "init returns idle state" {
    const state = FishingState.init();
    try std.testing.expectEqual(FishingState.Phase.idle, state.phase);
    try std.testing.expectEqual(@as(f32, 0.0), state.wait_timer);
}

test "cast changes phase to waiting" {
    var state = FishingState.init();
    state.cast(10.0, 64.0, 20.0);
    try std.testing.expectEqual(FishingState.Phase.waiting, state.phase);
    try std.testing.expect(state.wait_timer >= 5.0);
    try std.testing.expect(state.wait_timer <= 30.0);
}

test "cast sets bobber position" {
    var state = FishingState.init();
    state.cast(1.5, 2.5, 3.5);
    try std.testing.expectEqual(@as(f32, 1.5), state.bobber_x);
    try std.testing.expectEqual(@as(f32, 2.5), state.bobber_y);
    try std.testing.expectEqual(@as(f32, 3.5), state.bobber_z);
}

test "cast does nothing when not idle" {
    var state = FishingState.init();
    state.cast(1.0, 2.0, 3.0);
    const timer = state.wait_timer;
    // Casting again while waiting should be ignored.
    state.cast(99.0, 99.0, 99.0);
    try std.testing.expectEqual(timer, state.wait_timer);
    try std.testing.expectEqual(@as(f32, 1.0), state.bobber_x);
}

test "update counts down timer" {
    var state = FishingState.init();
    state.cast(5.0, 5.0, 5.0);
    const initial = state.wait_timer;
    state.update(1.0);
    try std.testing.expect(state.wait_timer < initial);
    try std.testing.expectEqual(FishingState.Phase.waiting, state.phase);
}

test "hooked after timer expires" {
    var state = FishingState.init();
    state.cast(5.0, 5.0, 5.0);
    // Advance past the maximum possible wait time.
    state.update(31.0);
    try std.testing.expect(state.isHooked());
    try std.testing.expectEqual(FishingState.Phase.hooked, state.phase);
}

test "reel when hooked returns catch" {
    var state = FishingState.init();
    state.cast(5.0, 5.0, 5.0);
    state.update(31.0);
    try std.testing.expect(state.isHooked());

    const result = state.reel();
    try std.testing.expect(result != null);
    try std.testing.expect(result.?.count >= 1);
    try std.testing.expect(result.?.xp >= 1);
    try std.testing.expectEqual(FishingState.Phase.idle, state.phase);
}

test "reel when not hooked returns null" {
    var state = FishingState.init();
    state.cast(5.0, 5.0, 5.0);
    // Still in waiting phase, reel should lose bait.
    try std.testing.expect(!state.isHooked());
    const result = state.reel();
    try std.testing.expectEqual(@as(?CatchResult, null), result);
    try std.testing.expectEqual(FishingState.Phase.idle, state.phase);
}

test "reel when idle returns null" {
    var state = FishingState.init();
    const result = state.reel();
    try std.testing.expectEqual(@as(?CatchResult, null), result);
}

test "cancel resets to idle" {
    var state = FishingState.init();
    state.cast(1.0, 2.0, 3.0);
    state.cancel();
    try std.testing.expectEqual(FishingState.Phase.idle, state.phase);
    try std.testing.expectEqual(@as(f32, 0.0), state.wait_timer);
}

test "rollCatch produces valid categories" {
    // Run many seeds and verify all results have valid categories.
    for (0..100) |i| {
        const result = rollCatch(@as(u64, i) *% 2654435761);
        switch (result.category) {
            .fish => try std.testing.expect(result.item_id >= FISH_ITEM_BASE and result.item_id <= FISH_ITEM_BASE + 3),
            .junk => try std.testing.expect(result.item_id >= JUNK_ITEM_BASE and result.item_id <= JUNK_ITEM_BASE + 4),
            .treasure => try std.testing.expect(result.item_id >= TREASURE_ITEM_BASE and result.item_id <= TREASURE_ITEM_BASE + 2),
        }
        try std.testing.expect(result.count >= 1);
        try std.testing.expect(result.xp >= 1);
    }
}

test "rollCatch distribution approximates 85/10/5" {
    var fish_count: u32 = 0;
    var junk_count: u32 = 0;
    var treasure_count: u32 = 0;
    const total: u32 = 10_000;

    for (0..total) |i| {
        const result = rollCatch(@as(u64, i));
        switch (result.category) {
            .fish => fish_count += 1,
            .junk => junk_count += 1,
            .treasure => treasure_count += 1,
        }
    }

    // Allow +-5% tolerance from expected distribution.
    try std.testing.expect(fish_count > 8000);
    try std.testing.expect(fish_count < 9000);
    try std.testing.expect(junk_count > 500);
    try std.testing.expect(junk_count < 1500);
    try std.testing.expect(treasure_count > 0);
    try std.testing.expect(treasure_count < 1000);
}

test "update does nothing when idle" {
    var state = FishingState.init();
    state.update(10.0);
    try std.testing.expectEqual(FishingState.Phase.idle, state.phase);
}

test "update does nothing when hooked" {
    var state = FishingState.init();
    state.cast(1.0, 1.0, 1.0);
    state.update(31.0);
    try std.testing.expect(state.isHooked());
    // Further updates should not change the hooked state.
    state.update(100.0);
    try std.testing.expect(state.isHooked());
}
