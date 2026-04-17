/// FishingState: models a fishing rod mechanic with cast, wait, and reel phases.
/// The player casts the rod, waits for a bite, then reels in a catch.
const std = @import("std");

pub const Phase = enum {
    idle,
    casting,
    waiting,
    bite,
};

pub const CatchResult = struct {
    item_id: u16,
    count: u8,
    xp: u32,
};

/// Loot table: item_id, count, xp, weight (relative probability).
const LootEntry = struct {
    item_id: u16,
    count: u8,
    xp: u32,
    weight: u16,
};

const LOOT_TABLE = [_]LootEntry{
    .{ .item_id = 300, .count = 1, .xp = 3, .weight = 60 }, // raw fish (common)
    .{ .item_id = 301, .count = 1, .xp = 5, .weight = 25 }, // raw salmon
    .{ .item_id = 302, .count = 1, .xp = 10, .weight = 10 }, // pufferfish (rare)
    .{ .item_id = 303, .count = 1, .xp = 15, .weight = 5 }, // treasure (very rare)
};

const CAST_DURATION: f32 = 0.5; // seconds for bobber to land
const MIN_WAIT: f32 = 5.0; // min seconds before bite
const MAX_WAIT: f32 = 30.0; // max seconds before bite
const BITE_WINDOW: f32 = 2.0; // seconds player has to reel after bite

pub const FishingState = struct {
    phase: Phase,
    timer: f32,
    bite_timer: f32,
    cast_x: f32,
    cast_y: f32,
    cast_z: f32,
    rng_state: u64,

    pub fn init() FishingState {
        return .{
            .phase = .idle,
            .timer = 0,
            .bite_timer = 0,
            .cast_x = 0,
            .cast_y = 0,
            .cast_z = 0,
            .rng_state = 0x12345678_9ABCDEF0,
        };
    }

    /// Cast the fishing rod from the player's position.
    pub fn cast(self: *FishingState, x: f32, y: f32, z: f32) void {
        self.phase = .casting;
        self.timer = CAST_DURATION;
        self.bite_timer = 0;
        self.cast_x = x;
        self.cast_y = y;
        self.cast_z = z;
    }

    /// Advance the fishing state machine by `dt` seconds.
    pub fn update(self: *FishingState, dt: f32) void {
        switch (self.phase) {
            .idle => {},
            .casting => {
                self.timer -= dt;
                if (self.timer <= 0) {
                    self.phase = .waiting;
                    // Randomize the wait duration
                    self.timer = self.randomWait();
                }
            },
            .waiting => {
                self.timer -= dt;
                if (self.timer <= 0) {
                    self.phase = .bite;
                    self.bite_timer = BITE_WINDOW;
                }
            },
            .bite => {
                self.bite_timer -= dt;
                if (self.bite_timer <= 0) {
                    // Missed the bite, reset to idle
                    self.phase = .idle;
                }
            },
        }
    }

    /// Attempt to reel in a catch. Returns a CatchResult if the player reels
    /// during the bite window, or null otherwise. Resets to idle either way.
    pub fn reel(self: *FishingState) ?CatchResult {
        if (self.phase == .bite) {
            const result = self.rollCatch();
            self.phase = .idle;
            return result;
        }
        // Reeling outside bite window just retracts the rod
        self.phase = .idle;
        return null;
    }

    /// Deterministic pseudo-random number (xorshift64).
    fn nextRandom(self: *FishingState) u64 {
        var x = self.rng_state;
        x ^= x << 13;
        x ^= x >> 7;
        x ^= x << 17;
        self.rng_state = x;
        return x;
    }

    fn randomWait(self: *FishingState) f32 {
        const range = MAX_WAIT - MIN_WAIT;
        const r = self.nextRandom();
        const frac: f32 = @as(f32, @floatFromInt(r % 10000)) / 10000.0;
        return MIN_WAIT + range * frac;
    }

    fn rollCatch(self: *FishingState) CatchResult {
        var total_weight: u16 = 0;
        for (LOOT_TABLE) |entry| {
            total_weight += entry.weight;
        }

        const roll: u16 = @intCast(self.nextRandom() % total_weight);
        var cumulative: u16 = 0;
        for (LOOT_TABLE) |entry| {
            cumulative += entry.weight;
            if (roll < cumulative) {
                return .{
                    .item_id = entry.item_id,
                    .count = entry.count,
                    .xp = entry.xp,
                };
            }
        }

        // Fallback (should not happen)
        return .{ .item_id = LOOT_TABLE[0].item_id, .count = LOOT_TABLE[0].count, .xp = LOOT_TABLE[0].xp };
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "init starts in idle phase" {
    const state = FishingState.init();
    try std.testing.expectEqual(Phase.idle, state.phase);
}

test "cast transitions to casting phase" {
    var state = FishingState.init();
    state.cast(10.0, 65.0, 20.0);

    try std.testing.expectEqual(Phase.casting, state.phase);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), state.cast_x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 65.0), state.cast_y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 20.0), state.cast_z, 0.001);
}

test "casting transitions to waiting after duration" {
    var state = FishingState.init();
    state.cast(0, 0, 0);

    // Still casting
    state.update(0.3);
    try std.testing.expectEqual(Phase.casting, state.phase);

    // Now should be waiting
    state.update(0.3);
    try std.testing.expectEqual(Phase.waiting, state.phase);
}

test "waiting transitions to bite" {
    var state = FishingState.init();
    state.cast(0, 0, 0);

    // Skip past casting
    state.update(1.0);
    try std.testing.expectEqual(Phase.waiting, state.phase);

    // Skip past entire wait period
    state.update(MAX_WAIT + 1.0);
    try std.testing.expectEqual(Phase.bite, state.phase);
}

test "bite times out to idle if not reeled" {
    var state = FishingState.init();
    state.cast(0, 0, 0);
    state.update(1.0); // past casting
    state.update(MAX_WAIT + 1.0); // to bite
    try std.testing.expectEqual(Phase.bite, state.phase);

    // Bite window expires
    state.update(BITE_WINDOW + 0.1);
    try std.testing.expectEqual(Phase.idle, state.phase);
}

test "reel during bite returns a catch" {
    var state = FishingState.init();
    state.cast(0, 0, 0);
    state.update(1.0);
    state.update(MAX_WAIT + 1.0);
    try std.testing.expectEqual(Phase.bite, state.phase);

    const result = state.reel();
    try std.testing.expect(result != null);
    try std.testing.expect(result.?.count > 0);
    try std.testing.expect(result.?.xp > 0);
    try std.testing.expectEqual(Phase.idle, state.phase);
}

test "reel during idle returns null" {
    var state = FishingState.init();
    const result = state.reel();
    try std.testing.expectEqual(@as(?CatchResult, null), result);
}

test "reel during waiting returns null and resets" {
    var state = FishingState.init();
    state.cast(0, 0, 0);
    state.update(1.0); // past casting, now waiting
    try std.testing.expectEqual(Phase.waiting, state.phase);

    const result = state.reel();
    try std.testing.expectEqual(@as(?CatchResult, null), result);
    try std.testing.expectEqual(Phase.idle, state.phase);
}

test "multiple cast-reel cycles work" {
    var state = FishingState.init();

    // First cycle
    state.cast(0, 0, 0);
    state.update(1.0);
    state.update(MAX_WAIT + 1.0);
    _ = state.reel();
    try std.testing.expectEqual(Phase.idle, state.phase);

    // Second cycle
    state.cast(5, 5, 5);
    try std.testing.expectEqual(Phase.casting, state.phase);
    state.update(1.0);
    state.update(MAX_WAIT + 1.0);
    const result = state.reel();
    try std.testing.expect(result != null);
}
