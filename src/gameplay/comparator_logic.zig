/// Redstone comparator mechanics: compare/subtract modes, container fill-level
/// signal detection, jukebox disc signals, and cake bite signals.

const std = @import("std");

// ──────────────────────────────────────────────────────────────────────────────
// Comparator mode and state
// ──────────────────────────────────────────────────────────────────────────────

pub const ComparatorMode = enum {
    compare,
    subtract,
};

pub const ComparatorState = struct {
    mode: ComparatorMode = .compare,
    rear_signal: u4 = 0,
    side_signal: u4 = 0,
    output_signal: u4 = 0,
    is_powered: bool = false,

    /// Switch between compare and subtract mode.
    pub fn toggle(self: ComparatorState) ComparatorState {
        const new_mode: ComparatorMode = if (self.mode == .compare) .subtract else .compare;
        const output = computeOutput(new_mode, self.rear_signal, self.side_signal);
        return .{
            .mode = new_mode,
            .rear_signal = self.rear_signal,
            .side_signal = self.side_signal,
            .output_signal = output,
            .is_powered = output > 0,
        };
    }

    /// Set input signals and recompute the output.
    pub fn update(self: ComparatorState, rear: u4, side: u4) ComparatorState {
        const output = computeOutput(self.mode, rear, side);
        return .{
            .mode = self.mode,
            .rear_signal = rear,
            .side_signal = side,
            .output_signal = output,
            .is_powered = output > 0,
        };
    }

    /// Compute output from current state fields.
    pub fn getOutput(self: ComparatorState) u4 {
        return computeOutput(self.mode, self.rear_signal, self.side_signal);
    }
};

/// Pure computation of comparator output given mode and input strengths.
fn computeOutput(mode: ComparatorMode, rear: u4, side: u4) u4 {
    return switch (mode) {
        .compare => if (rear >= side) rear else 0,
        .subtract => if (rear > side) rear - side else 0,
    };
}

// ──────────────────────────────────────────────────────────────────────────────
// Container signal strength
// ──────────────────────────────────────────────────────────────────────────────

/// Minecraft formula: when item_count > 0, floor(1 + (item_count / total_capacity) * 14),
/// clamped to 15. Returns 0 for empty containers.
pub fn getContainerSignal(item_count: u32, max_slots: u16, slot_capacity: u16) u4 {
    if (item_count == 0) return 0;
    const total_capacity: u64 = @as(u64, max_slots) * @as(u64, slot_capacity);
    if (total_capacity == 0) return 0;
    const scaled: u64 = 1 + (item_count * 14) / total_capacity;
    return if (scaled > 15) 15 else @intCast(scaled);
}

/// Chest: 27 slots x 64 capacity.
pub fn getChestSignal(item_count: u32) u4 {
    return getContainerSignal(item_count, 27, 64);
}

/// Hopper: 5 slots x 64 capacity.
pub fn getHopperSignal(item_count: u32) u4 {
    return getContainerSignal(item_count, 5, 64);
}

/// Furnace: 3 slots x 64 capacity.
pub fn getFurnaceSignal(item_count: u32) u4 {
    return getContainerSignal(item_count, 3, 64);
}

/// Brewing stand: 4 slots x 64 capacity (3 potion + 1 fuel).
pub fn getBrewingSignal(item_count: u32) u4 {
    return getContainerSignal(item_count, 4, 64);
}

/// Dispenser / dropper: 9 slots x 64 capacity.
pub fn getDispenserSignal(item_count: u32) u4 {
    return getContainerSignal(item_count, 9, 64);
}

/// Barrel: 27 slots x 64 capacity (same as chest).
pub fn getBarrelSignal(item_count: u32) u4 {
    return getContainerSignal(item_count, 27, 64);
}

// ──────────────────────────────────────────────────────────────────────────────
// Jukebox signal
// ──────────────────────────────────────────────────────────────────────────────

/// Music disc IDs 2256-2267 map to signal strengths 1-12. Non-disc items return 0.
pub fn getJukeboxSignal(disc_id: u16) u4 {
    if (disc_id >= 2256 and disc_id <= 2267) {
        return @intCast(disc_id - 2256 + 1);
    }
    return 0;
}

// ──────────────────────────────────────────────────────────────────────────────
// Cake signal
// ──────────────────────────────────────────────────────────────────────────────

/// Signal equals bites_remaining * 2 (max 7 bites -> signal 14, 0 bites -> 0).
pub fn getCakeSignal(bites_remaining: u3) u4 {
    return @as(u4, bites_remaining) * 2;
}

// ──────────────────────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────────────────────

test "compare mode — rear greater than side" {
    const state = (ComparatorState{}).update(10, 5);
    try std.testing.expectEqual(@as(u4, 10), state.output_signal);
    try std.testing.expect(state.is_powered);
}

test "compare mode — rear equal to side" {
    const state = (ComparatorState{}).update(7, 7);
    try std.testing.expectEqual(@as(u4, 7), state.output_signal);
    try std.testing.expect(state.is_powered);
}

test "compare mode — rear less than side" {
    const state = (ComparatorState{}).update(3, 9);
    try std.testing.expectEqual(@as(u4, 0), state.output_signal);
    try std.testing.expect(!state.is_powered);
}

test "subtract mode — rear greater than side" {
    const state = (ComparatorState{ .mode = .subtract }).update(12, 4);
    try std.testing.expectEqual(@as(u4, 8), state.output_signal);
    try std.testing.expect(state.is_powered);
}

test "subtract mode — rear equal to side" {
    const state = (ComparatorState{ .mode = .subtract }).update(6, 6);
    try std.testing.expectEqual(@as(u4, 0), state.output_signal);
    try std.testing.expect(!state.is_powered);
}

test "subtract mode — rear less than side" {
    const state = (ComparatorState{ .mode = .subtract }).update(2, 10);
    try std.testing.expectEqual(@as(u4, 0), state.output_signal);
    try std.testing.expect(!state.is_powered);
}

test "toggle mode switches compare to subtract and recomputes" {
    const initial = (ComparatorState{}).update(8, 5);
    try std.testing.expectEqual(ComparatorMode.compare, initial.mode);
    try std.testing.expectEqual(@as(u4, 8), initial.output_signal);

    const toggled = initial.toggle();
    try std.testing.expectEqual(ComparatorMode.subtract, toggled.mode);
    try std.testing.expectEqual(@as(u4, 3), toggled.output_signal);
}

test "container signal — empty returns 0" {
    try std.testing.expectEqual(@as(u4, 0), getChestSignal(0));
    try std.testing.expectEqual(@as(u4, 0), getHopperSignal(0));
}

test "container signal — partial fill" {
    // Hopper: 5 slots x 64 = 320 total. 160 items = 50% fill.
    // floor(1 + (160 / 320) * 14) = floor(1 + 7) = 8
    try std.testing.expectEqual(@as(u4, 8), getHopperSignal(160));
}

test "container signal — full chest" {
    // Chest: 27 x 64 = 1728. Full -> floor(1 + 1728*14/1728) = floor(15) = 15.
    try std.testing.expectEqual(@as(u4, 15), getChestSignal(1728));
}

test "container signal — overfull clamps to 15" {
    try std.testing.expectEqual(@as(u4, 15), getChestSignal(5000));
}

test "jukebox signal — valid disc IDs" {
    try std.testing.expectEqual(@as(u4, 1), getJukeboxSignal(2256));
    try std.testing.expectEqual(@as(u4, 6), getJukeboxSignal(2261));
    try std.testing.expectEqual(@as(u4, 12), getJukeboxSignal(2267));
}

test "jukebox signal — invalid item returns 0" {
    try std.testing.expectEqual(@as(u4, 0), getJukeboxSignal(1));
    try std.testing.expectEqual(@as(u4, 0), getJukeboxSignal(2268));
}

test "cake signal — full, partial, empty" {
    try std.testing.expectEqual(@as(u4, 14), getCakeSignal(7));
    try std.testing.expectEqual(@as(u4, 6), getCakeSignal(3));
    try std.testing.expectEqual(@as(u4, 0), getCakeSignal(0));
}

test "edge cases — zero and max signals" {
    // Zero inputs produce zero output in both modes.
    const zero_compare = (ComparatorState{}).update(0, 0);
    try std.testing.expectEqual(@as(u4, 0), zero_compare.output_signal);
    try std.testing.expect(!zero_compare.is_powered);

    const zero_subtract = (ComparatorState{ .mode = .subtract }).update(0, 0);
    try std.testing.expectEqual(@as(u4, 0), zero_subtract.output_signal);

    // Max inputs: 15, 15 in compare -> 15; in subtract -> 0.
    const max_compare = (ComparatorState{}).update(15, 15);
    try std.testing.expectEqual(@as(u4, 15), max_compare.output_signal);

    const max_subtract = (ComparatorState{ .mode = .subtract }).update(15, 15);
    try std.testing.expectEqual(@as(u4, 0), max_subtract.output_signal);
}

test "container helpers — furnace, brewing, dispenser, barrel" {
    // All empty
    try std.testing.expectEqual(@as(u4, 0), getFurnaceSignal(0));
    try std.testing.expectEqual(@as(u4, 0), getBrewingSignal(0));
    try std.testing.expectEqual(@as(u4, 0), getDispenserSignal(0));
    try std.testing.expectEqual(@as(u4, 0), getBarrelSignal(0));

    // Furnace full: 3 x 64 = 192 -> signal 15
    try std.testing.expectEqual(@as(u4, 15), getFurnaceSignal(192));
    // Barrel full = chest full: 27 x 64 = 1728 -> signal 15
    try std.testing.expectEqual(@as(u4, 15), getBarrelSignal(1728));
}
