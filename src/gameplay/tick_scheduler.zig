//! Fixed-rate tick scheduler for Minecraft-style game loops.
//!
//! Runs at 20 ticks per second (50 ms per tick). The `update` method
//! accumulates frame delta-time and returns how many fixed ticks should
//! be processed this frame. `shouldRandomTick` provides deterministic
//! pseudo-random block positions for random-tick processing.

const std = @import("std");

/// Fixed tick interval in seconds (1/20 = 0.05 s).
pub const TICK_RATE: f32 = 0.05;

/// Number of random-tick attempts per 16x16x16 chunk section per game tick.
pub const RANDOM_TICKS_PER_SECTION: u8 = 3;

pub const TickScheduler = struct {
    accumulator: f32 = 0,
    tick_count: u64 = 0,

    /// Accumulate `dt` seconds and return the number of fixed ticks to
    /// process this frame. Caps at 10 ticks to prevent spiral-of-death
    /// when a frame takes too long.
    pub fn update(self: *TickScheduler, dt: f32) u8 {
        if (dt <= 0) return 0;

        self.accumulator += dt;
        var ticks: u8 = 0;

        while (self.accumulator >= TICK_RATE and ticks < 10) {
            self.accumulator -= TICK_RATE;
            self.tick_count += 1;
            ticks += 1;
        }

        // Clamp leftover so accumulator never grows unbounded.
        if (self.accumulator > TICK_RATE * 10.0) {
            self.accumulator = 0;
        }

        return ticks;
    }

    /// Deterministic pseudo-random block position for random ticking.
    ///
    /// Given a chunk `section_idx` and a `sub_tick` (0 ..< RANDOM_TICKS_PER_SECTION),
    /// returns a block coordinate within the 16x16x16 section, or `null` when the
    /// scheduler has not yet ticked.
    pub fn shouldRandomTick(self: *const TickScheduler, section_idx: u16, sub_tick: u8) ?struct { x: u4, y: u4, z: u4 } {
        if (self.tick_count == 0) return null;
        if (sub_tick >= RANDOM_TICKS_PER_SECTION) return null;

        const seed = hash(self.tick_count, section_idx, sub_tick);

        return .{
            .x = @intCast(seed & 0xF),
            .y = @intCast((seed >> 4) & 0xF),
            .z = @intCast((seed >> 8) & 0xF),
        };
    }

    /// Return the total number of ticks elapsed since creation.
    pub fn getTickCount(self: *const TickScheduler) u64 {
        return self.tick_count;
    }

    // -- internal helpers --------------------------------------------------

    /// Simple deterministic hash combining tick count, section index, and
    /// sub-tick into a 32-bit value used for coordinate extraction.
    fn hash(tick: u64, section: u16, sub: u8) u32 {
        var h: u64 = tick;
        h = h *% 6364136223846793005 +% @as(u64, section);
        h = h *% 6364136223846793005 +% @as(u64, sub);
        // Xorshift-fold into 32 bits.
        h ^= h >> 33;
        h *%= 0xff51afd7ed558ccd;
        h ^= h >> 33;
        return @truncate(h);
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

const testing = std.testing;

test "TICK_RATE is 50 ms" {
    try testing.expectEqual(@as(f32, 0.05), TICK_RATE);
}

test "RANDOM_TICKS_PER_SECTION is 3" {
    try testing.expectEqual(@as(u8, 3), RANDOM_TICKS_PER_SECTION);
}

test "update returns 0 for zero dt" {
    var sched = TickScheduler{};
    try testing.expectEqual(@as(u8, 0), sched.update(0));
    try testing.expectEqual(@as(u64, 0), sched.getTickCount());
}

test "update returns 0 for negative dt" {
    var sched = TickScheduler{};
    try testing.expectEqual(@as(u8, 0), sched.update(-1.0));
}

test "update returns 1 tick for exactly one tick interval" {
    var sched = TickScheduler{};
    try testing.expectEqual(@as(u8, 1), sched.update(0.05));
    try testing.expectEqual(@as(u64, 1), sched.getTickCount());
}

test "update accumulates partial frames" {
    var sched = TickScheduler{};
    try testing.expectEqual(@as(u8, 0), sched.update(0.03));
    try testing.expectEqual(@as(u8, 1), sched.update(0.03));
    try testing.expectEqual(@as(u64, 1), sched.getTickCount());
}

test "update returns multiple ticks for large dt" {
    var sched = TickScheduler{};
    const ticks = sched.update(0.17);
    try testing.expectEqual(@as(u8, 3), ticks);
    try testing.expectEqual(@as(u64, 3), sched.getTickCount());
}

test "update caps at 10 ticks per frame" {
    var sched = TickScheduler{};
    const ticks = sched.update(1.0);
    try testing.expectEqual(@as(u8, 10), ticks);
}

test "tick count increments across multiple updates" {
    var sched = TickScheduler{};
    _ = sched.update(0.1);
    _ = sched.update(0.1);
    try testing.expectEqual(@as(u64, 4), sched.getTickCount());
}

test "shouldRandomTick returns null before any tick" {
    const sched = TickScheduler{};
    try testing.expect(sched.shouldRandomTick(0, 0) == null);
}

test "shouldRandomTick returns null for out-of-range sub_tick" {
    var sched = TickScheduler{};
    _ = sched.update(0.05);
    try testing.expect(sched.shouldRandomTick(0, RANDOM_TICKS_PER_SECTION) == null);
    try testing.expect(sched.shouldRandomTick(0, 255) == null);
}

test "shouldRandomTick returns valid coordinates" {
    var sched = TickScheduler{};
    _ = sched.update(0.05);
    const pos = sched.shouldRandomTick(42, 0).?;
    // u4 values are inherently 0..15, but verify explicitly
    try testing.expect(pos.x <= 15);
    try testing.expect(pos.y <= 15);
    try testing.expect(pos.z <= 15);
}

test "shouldRandomTick is deterministic" {
    var a = TickScheduler{};
    var b = TickScheduler{};
    _ = a.update(0.1);
    _ = b.update(0.1);
    const pa = a.shouldRandomTick(7, 1).?;
    const pb = b.shouldRandomTick(7, 1).?;
    try testing.expectEqual(pa.x, pb.x);
    try testing.expectEqual(pa.y, pb.y);
    try testing.expectEqual(pa.z, pb.z);
}

test "shouldRandomTick varies with section_idx" {
    var sched = TickScheduler{};
    _ = sched.update(0.05);
    const a = sched.shouldRandomTick(0, 0).?;
    const b = sched.shouldRandomTick(1, 0).?;
    // Hash should produce different results for different sections
    // (extremely unlikely all three coordinates match)
    const same = (a.x == b.x) and (a.y == b.y) and (a.z == b.z);
    try testing.expect(!same);
}

test "shouldRandomTick varies with sub_tick" {
    var sched = TickScheduler{};
    _ = sched.update(0.05);
    const a = sched.shouldRandomTick(0, 0).?;
    const b = sched.shouldRandomTick(0, 1).?;
    const same = (a.x == b.x) and (a.y == b.y) and (a.z == b.z);
    try testing.expect(!same);
}

test "getTickCount returns 0 on fresh scheduler" {
    const sched = TickScheduler{};
    try testing.expectEqual(@as(u64, 0), sched.getTickCount());
}
