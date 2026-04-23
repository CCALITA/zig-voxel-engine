//! Tick integration layer: bridges the tick scheduler with crop growth.
//!
//! `processGameTicks` drives the scheduler forward by a frame delta and
//! returns how many fixed ticks fired plus how many crops grew.
//! `processCropTick` wraps `cg.tryGrow` with a single-call convenience API.

const std = @import("std");
const ts = @import("tick_scheduler.zig");
const cg = @import("crop_growth.zig");

pub const TickResult = struct {
    ticks_processed: u8,
    crops_grown: u8,
};

/// Advance the scheduler by `dt` seconds and, for each tick produced,
/// perform `RANDOM_TICKS_PER_SECTION` random-tick attempts on section 0.
/// Returns the number of ticks processed and the count of successful
/// random-tick positions found (used as a proxy for crops that would grow).
pub fn processGameTicks(scheduler: *ts.TickScheduler, dt: f32) TickResult {
    const ticks = scheduler.update(dt);

    var crops_grown: u8 = 0;
    var i: u8 = 0;
    while (i < ticks) : (i += 1) {
        var sub: u8 = 0;
        while (sub < ts.RANDOM_TICKS_PER_SECTION) : (sub += 1) {
            if (scheduler.shouldRandomTick(0, sub) != null) {
                crops_grown +|= 1;
            }
        }
    }

    return TickResult{
        .ticks_processed = ticks,
        .crops_grown = crops_grown,
    };
}

/// Convenience wrapper around `cg.tryGrow`.
///
/// Returns `true` when the crop advanced a growth stage.
pub fn processCropTick(
    crop: *cg.CropState,
    hydrated: bool,
    light: u4,
    adjacent: u8,
    rng: u32,
) bool {
    return cg.tryGrow(crop, hydrated, light, adjacent, rng);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

const testing = std.testing;

// -- processGameTicks tests -------------------------------------------------

test "processGameTicks returns zero ticks for zero dt" {
    var sched = ts.TickScheduler{};
    const result = processGameTicks(&sched, 0);
    try testing.expectEqual(@as(u8, 0), result.ticks_processed);
    try testing.expectEqual(@as(u8, 0), result.crops_grown);
}

test "processGameTicks returns one tick for exactly one interval" {
    var sched = ts.TickScheduler{};
    const result = processGameTicks(&sched, ts.TICK_RATE);
    try testing.expectEqual(@as(u8, 1), result.ticks_processed);
}

test "processGameTicks returns multiple ticks for large dt" {
    var sched = ts.TickScheduler{};
    const result = processGameTicks(&sched, ts.TICK_RATE * 4.0);
    try testing.expectEqual(@as(u8, 4), result.ticks_processed);
}

test "processGameTicks caps at 10 ticks" {
    var sched = ts.TickScheduler{};
    const result = processGameTicks(&sched, 2.0);
    try testing.expectEqual(@as(u8, 10), result.ticks_processed);
}

test "processGameTicks crops_grown is nonzero when ticks fire" {
    var sched = ts.TickScheduler{};
    const result = processGameTicks(&sched, ts.TICK_RATE);
    // One tick fires 3 random-tick attempts; all should yield positions.
    try testing.expect(result.crops_grown > 0);
}

test "processGameTicks accumulates across calls" {
    var sched = ts.TickScheduler{};
    const r1 = processGameTicks(&sched, ts.TICK_RATE * 2.0);
    const r2 = processGameTicks(&sched, ts.TICK_RATE * 3.0);
    try testing.expectEqual(@as(u8, 2), r1.ticks_processed);
    try testing.expectEqual(@as(u8, 3), r2.ticks_processed);
}

test "processGameTicks negative dt yields zero" {
    var sched = ts.TickScheduler{};
    const result = processGameTicks(&sched, -5.0);
    try testing.expectEqual(@as(u8, 0), result.ticks_processed);
    try testing.expectEqual(@as(u8, 0), result.crops_grown);
}

// -- processCropTick tests --------------------------------------------------

test "processCropTick grows crop on favorable roll" {
    var crop = cg.CropState{ .crop_type = .wheat, .x = 0, .y = 0, .z = 0 };
    // rng % 1000 = 10 -> 0.01 < 0.05 base chance, should succeed
    const grew = processCropTick(&crop, false, 15, 0, 10);
    try testing.expect(grew);
    try testing.expectEqual(@as(u8, 1), crop.stage);
}

test "processCropTick rejects unfavorable roll" {
    var crop = cg.CropState{ .crop_type = .carrot, .x = 0, .y = 0, .z = 0 };
    // rng % 1000 = 999 -> 0.999, well above any chance
    const grew = processCropTick(&crop, false, 15, 0, 999);
    try testing.expect(!grew);
    try testing.expectEqual(@as(u8, 0), crop.stage);
}

test "processCropTick fails in low light" {
    var crop = cg.CropState{ .crop_type = .potato, .x = 0, .y = 0, .z = 0 };
    const grew = processCropTick(&crop, true, 5, 0, 0);
    try testing.expect(!grew);
    try testing.expectEqual(@as(u8, 0), crop.stage);
}

test "processCropTick does not exceed MAX_STAGE" {
    var crop = cg.CropState{ .crop_type = .beetroot, .stage = cg.MAX_STAGE, .x = 0, .y = 0, .z = 0 };
    const grew = processCropTick(&crop, true, 15, 0, 0);
    try testing.expect(!grew);
    try testing.expectEqual(cg.MAX_STAGE, crop.stage);
}

test "processCropTick hydration doubles growth chance" {
    // With hydration, chance = 0.10. rng=90 -> 0.09 < 0.10 succeeds.
    var crop = cg.CropState{ .crop_type = .wheat, .x = 0, .y = 0, .z = 0 };
    const grew = processCropTick(&crop, true, 15, 0, 90);
    try testing.expect(grew);
    try testing.expectEqual(@as(u8, 1), crop.stage);
}

test "processCropTick crowding halves growth chance" {
    // Without hydration + crowded: chance = 0.025. rng=30 -> 0.03 >= 0.025, fails.
    var crop = cg.CropState{ .crop_type = .wheat, .x = 0, .y = 0, .z = 0 };
    const grew = processCropTick(&crop, false, 15, 4, 30);
    try testing.expect(!grew);
}

// -- TickResult struct tests ------------------------------------------------

test "TickResult default values via struct literal" {
    const r = TickResult{ .ticks_processed = 5, .crops_grown = 3 };
    try testing.expectEqual(@as(u8, 5), r.ticks_processed);
    try testing.expectEqual(@as(u8, 3), r.crops_grown);
}
