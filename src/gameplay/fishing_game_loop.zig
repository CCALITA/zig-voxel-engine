//! Fishing game loop: state machine driving the full cast -> wait -> bite ->
//! reel -> caught pipeline with lure/luck enchantment modifiers and a weighted
//! loot table (fish / junk / treasure).
//!
//! This module is self-contained and deterministic given a caller-provided
//! `std.Random` instance, so it is cheap to test.

const std = @import("std");

/// Phases the fishing rod can be in during a cast.
pub const FishingPhase = enum {
    idle,
    casting,
    waiting,
    bite,
    reeling,
    caught,
};

/// Result handed back to the caller when a fish is successfully hauled in.
pub const CatchResult = struct {
    item: u16,
    count: u8,
    xp: u8,
};

/// Runtime state for the fishing mini-game.
pub const FishingState = struct {
    phase: FishingPhase = .idle,
    bobber_x: f32 = 0,
    bobber_y: f32 = 0,
    bobber_z: f32 = 0,
    wait_timer: f32 = 0,
    bite_window: f32 = 0,
    lure_level: u8 = 0,
    luck_level: u8 = 0,
};

// ---------------------------------------------------------------------------
// Tunables
// ---------------------------------------------------------------------------

/// How far the bobber sails along the look vector on cast.
const CAST_DISTANCE: f32 = 4.0;

/// Base minimum wait before the fish bites.
const MIN_WAIT: f32 = 5.0;
/// Base maximum wait before the fish bites.
const MAX_WAIT: f32 = 30.0;
/// Each level of Lure trims this many seconds off both ends of the wait range.
const LURE_REDUCTION_PER_LEVEL: f32 = 5.0;
/// Minimum wait can never drop below this (prevents instant bites).
const MIN_WAIT_FLOOR: f32 = 0.5;

/// Window (seconds) the player has to reel in after a bite.
const BITE_WINDOW_SEC: f32 = 0.5;

// Item IDs used in the loot table (arbitrary but stable).
pub const ITEM_RAW_FISH: u16 = 300;
pub const ITEM_RAW_SALMON: u16 = 301;
pub const ITEM_PUFFERFISH: u16 = 302;
pub const ITEM_CLOWNFISH: u16 = 303;
pub const ITEM_LEATHER_BOOT: u16 = 400;
pub const ITEM_STICK: u16 = 401;
pub const ITEM_BOWL: u16 = 402;
pub const ITEM_ROTTEN_FLESH: u16 = 403;
pub const ITEM_NAME_TAG: u16 = 500;
pub const ITEM_SADDLE: u16 = 501;
pub const ITEM_ENCHANTED_BOOK: u16 = 502;
pub const ITEM_NAUTILUS_SHELL: u16 = 503;

/// Top-level loot category (internal only).
const LootCategory = enum { fish, junk, treasure };

const LootEntry = struct {
    item: u16,
    count: u8,
    xp: u8,
    weight: u16,
};

const FISH_TABLE = [_]LootEntry{
    .{ .item = ITEM_RAW_FISH, .count = 1, .xp = 2, .weight = 60 },
    .{ .item = ITEM_RAW_SALMON, .count = 1, .xp = 3, .weight = 25 },
    .{ .item = ITEM_PUFFERFISH, .count = 1, .xp = 5, .weight = 13 },
    .{ .item = ITEM_CLOWNFISH, .count = 1, .xp = 5, .weight = 2 },
};

const JUNK_TABLE = [_]LootEntry{
    .{ .item = ITEM_LEATHER_BOOT, .count = 1, .xp = 1, .weight = 10 },
    .{ .item = ITEM_STICK, .count = 1, .xp = 1, .weight = 10 },
    .{ .item = ITEM_BOWL, .count = 1, .xp = 1, .weight = 10 },
    .{ .item = ITEM_ROTTEN_FLESH, .count = 1, .xp = 1, .weight = 10 },
};

const TREASURE_TABLE = [_]LootEntry{
    .{ .item = ITEM_NAME_TAG, .count = 1, .xp = 7, .weight = 1 },
    .{ .item = ITEM_SADDLE, .count = 1, .xp = 7, .weight = 1 },
    .{ .item = ITEM_ENCHANTED_BOOK, .count = 1, .xp = 10, .weight = 1 },
    .{ .item = ITEM_NAUTILUS_SHELL, .count = 1, .xp = 4, .weight = 1 },
};

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Cast the rod from the player's position toward the look vector.
/// The look vector does not need to be normalized; it will be normalized here.
pub fn cast(
    state: *FishingState,
    px: f32,
    py: f32,
    pz: f32,
    look_x: f32,
    look_y: f32,
    look_z: f32,
) void {
    const len_sq = look_x * look_x + look_y * look_y + look_z * look_z;
    var nx: f32 = 0;
    var ny: f32 = 0;
    var nz: f32 = 1;
    if (len_sq > 0.000001) {
        const len = @sqrt(len_sq);
        nx = look_x / len;
        ny = look_y / len;
        nz = look_z / len;
    }
    state.phase = .casting;
    state.bobber_x = px + nx * CAST_DISTANCE;
    state.bobber_y = py + ny * CAST_DISTANCE;
    state.bobber_z = pz + nz * CAST_DISTANCE;
    state.wait_timer = 0;
    state.bite_window = 0;
}

/// Advance the fishing state machine by `dt` seconds.
/// Returns a `CatchResult` on the tick the fish is successfully reeled in,
/// otherwise null.
pub fn update(state: *FishingState, dt: f32, rng: std.Random) ?CatchResult {
    switch (state.phase) {
        .idle, .caught => return null,

        .casting => {
            // Bobber hits water immediately, arm the wait timer.
            state.phase = .waiting;
            state.wait_timer = rollWaitDuration(rng, state.lure_level);
            return null;
        },

        .waiting => {
            state.wait_timer -= dt;
            if (state.wait_timer <= 0) {
                state.phase = .bite;
                state.bite_window = BITE_WINDOW_SEC;
            }
            return null;
        },

        .bite => {
            state.bite_window -= dt;
            if (state.bite_window <= 0) {
                // Missed the window, back to idle.
                state.phase = .idle;
                state.wait_timer = 0;
                state.bite_window = 0;
            }
            return null;
        },

        .reeling => {
            // Rolling the catch takes exactly one update tick.
            const result = rollCatch(rng, state.luck_level);
            state.phase = .caught;
            return result;
        },
    }
}

/// Player-initiated reel action. Transitions into `.reeling` only when a bite
/// is active; otherwise it just aborts back to idle.
pub fn reel(state: *FishingState) void {
    if (state.phase == .bite) {
        state.phase = .reeling;
    } else {
        resetToIdle(state);
    }
}

/// Reset the state back to idle without rolling loot.
pub fn resetToIdle(state: *FishingState) void {
    state.phase = .idle;
    state.wait_timer = 0;
    state.bite_window = 0;
}

// ---------------------------------------------------------------------------
// Internals
// ---------------------------------------------------------------------------

fn rollWaitDuration(rng: std.Random, lure_level: u8) f32 {
    const reduction: f32 = @as(f32, @floatFromInt(lure_level)) * LURE_REDUCTION_PER_LEVEL;
    var min_wait = MIN_WAIT - reduction;
    var max_wait = MAX_WAIT - reduction;
    if (min_wait < MIN_WAIT_FLOOR) min_wait = MIN_WAIT_FLOOR;
    if (max_wait < min_wait) max_wait = min_wait;
    const t = rng.float(f32); // [0, 1)
    return min_wait + (max_wait - min_wait) * t;
}

/// Luck shifts probability mass from junk into treasure. At luck 0 the ratios
/// are 85/10/5 fish/junk/treasure. Each level moves 1pt from junk to treasure
/// (capped so junk never goes negative).
fn categoryWeights(luck_level: u8) struct { fish: u16, junk: u16, treasure: u16 } {
    const luck: u16 = @min(@as(u16, luck_level), 5);
    const junk_base: u16 = 10;
    const treasure_base: u16 = 5;
    const shift: u16 = @min(luck, junk_base); // never drain junk negative
    return .{
        .fish = 85,
        .junk = junk_base - shift,
        .treasure = treasure_base + shift,
    };
}

fn rollCatch(rng: std.Random, luck_level: u8) CatchResult {
    const w = categoryWeights(luck_level);
    const total: u16 = w.fish + w.junk + w.treasure;
    const roll: u16 = @intCast(rng.uintLessThan(u32, total));

    const category: LootCategory = if (roll < w.fish)
        .fish
    else if (roll < w.fish + w.junk)
        .junk
    else
        .treasure;

    return rollFromTable(rng, category);
}

fn rollFromTable(rng: std.Random, category: LootCategory) CatchResult {
    const table: []const LootEntry = switch (category) {
        .fish => &FISH_TABLE,
        .junk => &JUNK_TABLE,
        .treasure => &TREASURE_TABLE,
    };

    var total: u32 = 0;
    for (table) |e| total += e.weight;

    const roll: u32 = rng.uintLessThan(u32, total);
    var cumulative: u32 = 0;
    for (table) |e| {
        cumulative += e.weight;
        if (roll < cumulative) {
            return .{ .item = e.item, .count = e.count, .xp = e.xp };
        }
    }
    // Unreachable if total > 0.
    const fallback = table[0];
    return .{ .item = fallback.item, .count = fallback.count, .xp = fallback.xp };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

fn testRng(seed: u64) std.Random.DefaultPrng {
    return std.Random.DefaultPrng.init(seed);
}

test "default state starts idle with zero fields" {
    const state = FishingState{};
    try std.testing.expectEqual(FishingPhase.idle, state.phase);
    try std.testing.expectEqual(@as(f32, 0), state.bobber_x);
    try std.testing.expectEqual(@as(u8, 0), state.lure_level);
    try std.testing.expectEqual(@as(u8, 0), state.luck_level);
}

test "cast places bobber along normalized look vector" {
    var state = FishingState{};
    cast(&state, 10.0, 65.0, 20.0, 0.0, 0.0, 2.0); // length 2, normalized to z=1
    try std.testing.expectEqual(FishingPhase.casting, state.phase);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), state.bobber_x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 65.0), state.bobber_y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 20.0 + CAST_DISTANCE), state.bobber_z, 0.001);
}

test "cast with zero look vector falls back to +Z" {
    var state = FishingState{};
    cast(&state, 0, 0, 0, 0, 0, 0);
    try std.testing.expectEqual(FishingPhase.casting, state.phase);
    try std.testing.expectApproxEqAbs(CAST_DISTANCE, state.bobber_z, 0.001);
}

test "first update after cast transitions to waiting and arms timer" {
    var state = FishingState{};
    var prng = testRng(42);
    cast(&state, 0, 0, 0, 1, 0, 0);
    const r = update(&state, 0.0, prng.random());
    try std.testing.expectEqual(@as(?CatchResult, null), r);
    try std.testing.expectEqual(FishingPhase.waiting, state.phase);
    try std.testing.expect(state.wait_timer >= MIN_WAIT);
    try std.testing.expect(state.wait_timer <= MAX_WAIT);
}

test "waiting transitions to bite after timer elapses" {
    var state = FishingState{};
    var prng = testRng(7);
    cast(&state, 0, 0, 0, 1, 0, 0);
    _ = update(&state, 0, prng.random()); // casting -> waiting
    // Blow past the max wait to guarantee a bite.
    _ = update(&state, MAX_WAIT + 1.0, prng.random());
    try std.testing.expectEqual(FishingPhase.bite, state.phase);
    try std.testing.expectApproxEqAbs(BITE_WINDOW_SEC, state.bite_window, 0.001);
}

test "missed bite window returns to idle" {
    var state = FishingState{};
    var prng = testRng(9);
    cast(&state, 0, 0, 0, 1, 0, 0);
    _ = update(&state, 0, prng.random());
    _ = update(&state, MAX_WAIT + 1.0, prng.random());
    try std.testing.expectEqual(FishingPhase.bite, state.phase);
    _ = update(&state, BITE_WINDOW_SEC + 0.1, prng.random());
    try std.testing.expectEqual(FishingPhase.idle, state.phase);
}

test "reel during bite moves to reeling then caught with result" {
    var state = FishingState{};
    var prng = testRng(123);
    cast(&state, 0, 0, 0, 1, 0, 0);
    _ = update(&state, 0, prng.random());
    _ = update(&state, MAX_WAIT + 1.0, prng.random());
    try std.testing.expectEqual(FishingPhase.bite, state.phase);
    reel(&state);
    try std.testing.expectEqual(FishingPhase.reeling, state.phase);
    const result = update(&state, 0, prng.random());
    try std.testing.expect(result != null);
    try std.testing.expect(result.?.count > 0);
    try std.testing.expectEqual(FishingPhase.caught, state.phase);
}

test "reel outside bite aborts to idle" {
    var state = FishingState{};
    var prng = testRng(3);
    cast(&state, 0, 0, 0, 1, 0, 0);
    _ = update(&state, 0, prng.random());
    try std.testing.expectEqual(FishingPhase.waiting, state.phase);
    reel(&state);
    try std.testing.expectEqual(FishingPhase.idle, state.phase);
    try std.testing.expectEqual(@as(f32, 0), state.wait_timer);
}

test "update on idle is a no-op and returns null" {
    var state = FishingState{};
    var prng = testRng(1);
    const r = update(&state, 1.0, prng.random());
    try std.testing.expectEqual(@as(?CatchResult, null), r);
    try std.testing.expectEqual(FishingPhase.idle, state.phase);
}

test "lure level shortens wait window" {
    var state = FishingState{ .lure_level = 3 };
    var prng = testRng(99);
    cast(&state, 0, 0, 0, 1, 0, 0);
    _ = update(&state, 0, prng.random());
    // min/max should be reduced by 15 seconds.
    try std.testing.expect(state.wait_timer >= MIN_WAIT_FLOOR);
    try std.testing.expect(state.wait_timer <= MAX_WAIT - 15.0);
}

test "lure level clamps to floor" {
    // Lure 10 would push min to -45, should clamp to floor.
    var state = FishingState{ .lure_level = 10 };
    var prng = testRng(11);
    cast(&state, 0, 0, 0, 1, 0, 0);
    _ = update(&state, 0, prng.random());
    try std.testing.expect(state.wait_timer >= MIN_WAIT_FLOOR);
    try std.testing.expect(state.wait_timer <= MIN_WAIT_FLOOR + 0.0001);
}

test "luck level shifts junk weight into treasure" {
    const base = categoryWeights(0);
    try std.testing.expectEqual(@as(u16, 85), base.fish);
    try std.testing.expectEqual(@as(u16, 10), base.junk);
    try std.testing.expectEqual(@as(u16, 5), base.treasure);

    const lucky = categoryWeights(3);
    try std.testing.expectEqual(@as(u16, 85), lucky.fish);
    try std.testing.expectEqual(@as(u16, 7), lucky.junk);
    try std.testing.expectEqual(@as(u16, 8), lucky.treasure);
}

test "loot distribution over many rolls is plausibly 85/10/5" {
    var prng = testRng(0xC0FFEE);
    var fish_count: u32 = 0;
    var junk_count: u32 = 0;
    var treasure_count: u32 = 0;
    const N: u32 = 20_000;
    var i: u32 = 0;
    while (i < N) : (i += 1) {
        const res = rollCatch(prng.random(), 0);
        if (isFish(res.item)) {
            fish_count += 1;
        } else if (isJunk(res.item)) {
            junk_count += 1;
        } else if (isTreasure(res.item)) {
            treasure_count += 1;
        }
    }
    try std.testing.expectEqual(N, fish_count + junk_count + treasure_count);
    // Generous bounds: fish ~85%, junk ~10%, treasure ~5%.
    try std.testing.expect(fish_count > (N * 80) / 100);
    try std.testing.expect(fish_count < (N * 90) / 100);
    try std.testing.expect(junk_count > (N * 6) / 100);
    try std.testing.expect(junk_count < (N * 14) / 100);
    try std.testing.expect(treasure_count > (N * 2) / 100);
    try std.testing.expect(treasure_count < (N * 9) / 100);
}

test "full cycle cast -> caught yields usable CatchResult" {
    var state = FishingState{};
    var prng = testRng(2024);
    cast(&state, 10, 64, 10, 1, 0, 0);
    _ = update(&state, 0, prng.random()); // waiting
    _ = update(&state, MAX_WAIT + 1, prng.random()); // bite
    reel(&state);
    const result = update(&state, 0, prng.random());
    try std.testing.expect(result != null);
    try std.testing.expect(result.?.item > 0);
    try std.testing.expect(result.?.count >= 1);
    try std.testing.expectEqual(FishingPhase.caught, state.phase);

    // Reset and do it again.
    resetToIdle(&state);
    try std.testing.expectEqual(FishingPhase.idle, state.phase);
    cast(&state, 0, 0, 0, 0, 1, 0);
    try std.testing.expectEqual(FishingPhase.casting, state.phase);
}

fn isFish(item: u16) bool {
    for (FISH_TABLE) |e| if (e.item == item) return true;
    return false;
}
fn isJunk(item: u16) bool {
    for (JUNK_TABLE) |e| if (e.item == item) return true;
    return false;
}
fn isTreasure(item: u16) bool {
    for (TREASURE_TABLE) |e| if (e.item == item) return true;
    return false;
}
