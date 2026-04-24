/// Hopper transfer logic: cooldown-gated item movement between 27-slot inventories.
/// A hopper scans its source inventory for the first non-empty slot, then finds
/// the first destination slot that either matches (and has room) or is empty.

const std = @import("std");

/// Ticks between successive item transfers (Minecraft-standard 8 game ticks).
pub const TRANSFER_COOLDOWN: u8 = 8;

/// Per-hopper runtime state: cooldown timer and redstone lock.
pub const HopperState = struct {
    cooldown: u8 = 0,
    is_locked: bool = false,

    /// Returns true when the hopper is off cooldown and not locked by redstone.
    pub fn canTransfer(self: HopperState) bool {
        return self.cooldown == 0 and !self.is_locked;
    }

    /// Begin the cooldown after a successful transfer.
    pub fn transfer(self: *HopperState) void {
        self.cooldown = TRANSFER_COOLDOWN;
    }

    /// Advance the cooldown by one game tick.
    pub fn tick(self: *HopperState) void {
        if (self.cooldown > 0) self.cooldown -= 1;
    }
};

/// Result of a successful slot match between two inventories.
pub const TransferSlot = struct {
    from: u8,
    to: u8,
};

/// Scan `source` for the first non-empty slot whose item can be placed into
/// `dest` (matching item with count < 64, or first empty slot). Returns the
/// source and destination slot indices, or null if no valid pair exists.
pub fn findTransferSlot(
    source_items: [27]u16,
    source_counts: [27]u8,
    dest_items: [27]u16,
    dest_counts: [27]u8,
) ?TransferSlot {
    for (source_items, source_counts, 0..) |src_item, src_count, src_idx| {
        if (src_count == 0) continue;

        // Pass 1: look for a destination slot already holding the same item.
        for (dest_items, dest_counts, 0..) |dst_item, dst_count, dst_idx| {
            if (dst_item == src_item and dst_count > 0 and dst_count < 64) {
                return .{
                    .from = @intCast(src_idx),
                    .to = @intCast(dst_idx),
                };
            }
        }

        // Pass 2: look for the first empty destination slot.
        for (dest_counts, 0..) |dst_count, dst_idx| {
            if (dst_count == 0) {
                return .{
                    .from = @intCast(src_idx),
                    .to = @intCast(dst_idx),
                };
            }
        }
    }
    return null;
}

// ──────────────────────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────────────────────

fn emptyItems() [27]u16 {
    return [_]u16{0} ** 27;
}

fn emptyCounts() [27]u8 {
    return [_]u8{0} ** 27;
}

// --- HopperState tests ---

test "default HopperState can transfer" {
    const state = HopperState{};
    try std.testing.expect(state.canTransfer());
}

test "locked hopper cannot transfer" {
    const state = HopperState{ .is_locked = true };
    try std.testing.expect(!state.canTransfer());
}

test "hopper on cooldown cannot transfer" {
    const state = HopperState{ .cooldown = 3 };
    try std.testing.expect(!state.canTransfer());
}

test "transfer sets cooldown to TRANSFER_COOLDOWN" {
    var state = HopperState{};
    state.transfer();
    try std.testing.expectEqual(TRANSFER_COOLDOWN, state.cooldown);
    try std.testing.expect(!state.canTransfer());
}

test "tick decrements cooldown by one" {
    var state = HopperState{ .cooldown = 5 };
    state.tick();
    try std.testing.expectEqual(@as(u8, 4), state.cooldown);
}

test "tick does not underflow at zero" {
    var state = HopperState{ .cooldown = 0 };
    state.tick();
    try std.testing.expectEqual(@as(u8, 0), state.cooldown);
}

test "full cooldown cycle restores canTransfer" {
    var state = HopperState{};
    state.transfer();
    var i: u8 = 0;
    while (i < TRANSFER_COOLDOWN) : (i += 1) {
        try std.testing.expect(!state.canTransfer());
        state.tick();
    }
    try std.testing.expect(state.canTransfer());
}

// --- findTransferSlot tests ---

test "both inventories empty returns null" {
    const result = findTransferSlot(emptyItems(), emptyCounts(), emptyItems(), emptyCounts());
    try std.testing.expect(result == null);
}

test "source has item, dest empty — transfers to slot 0" {
    var si = emptyItems();
    var sc = emptyCounts();
    si[3] = 42;
    sc[3] = 10;
    const result = findTransferSlot(si, sc, emptyItems(), emptyCounts()).?;
    try std.testing.expectEqual(@as(u8, 3), result.from);
    try std.testing.expectEqual(@as(u8, 0), result.to);
}

test "dest has matching item — stacks before using empty slot" {
    var si = emptyItems();
    var sc = emptyCounts();
    si[0] = 7;
    sc[0] = 5;

    var di = emptyItems();
    var dc = emptyCounts();
    di[2] = 7;
    dc[2] = 30;

    const result = findTransferSlot(si, sc, di, dc).?;
    try std.testing.expectEqual(@as(u8, 0), result.from);
    try std.testing.expectEqual(@as(u8, 2), result.to);
}

test "dest matching slot full — falls back to empty slot" {
    var si = emptyItems();
    var sc = emptyCounts();
    si[0] = 7;
    sc[0] = 5;

    var di = emptyItems();
    var dc = emptyCounts();
    di[0] = 7;
    dc[0] = 64; // full
    // slot 1 is empty

    const result = findTransferSlot(si, sc, di, dc).?;
    try std.testing.expectEqual(@as(u8, 0), result.from);
    try std.testing.expectEqual(@as(u8, 1), result.to);
}

test "dest completely full returns null" {
    var si = emptyItems();
    var sc = emptyCounts();
    si[0] = 10;
    sc[0] = 1;

    var di = emptyItems();
    var dc = emptyCounts();
    // Fill every dest slot with a different item at max count.
    for (&di, &dc, 0..) |*item, *count, idx| {
        item.* = @intCast(idx + 100);
        count.* = 64;
    }

    const result = findTransferSlot(si, sc, di, dc);
    try std.testing.expect(result == null);
}

test "picks first non-empty source slot" {
    var si = emptyItems();
    var sc = emptyCounts();
    si[5] = 1;
    sc[5] = 3;
    si[10] = 2;
    sc[10] = 7;

    const result = findTransferSlot(si, sc, emptyItems(), emptyCounts()).?;
    try std.testing.expectEqual(@as(u8, 5), result.from);
}

test "prefers matching dest over empty dest" {
    var si = emptyItems();
    var sc = emptyCounts();
    si[0] = 20;
    sc[0] = 1;

    var di = emptyItems();
    var dc = emptyCounts();
    // slot 1 is empty (count 0)
    di[5] = 20;
    dc[5] = 10; // matching, not full

    const result = findTransferSlot(si, sc, di, dc).?;
    try std.testing.expectEqual(@as(u8, 0), result.from);
    try std.testing.expectEqual(@as(u8, 5), result.to);
}
