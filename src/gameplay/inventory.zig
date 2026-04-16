/// Fixed-size inventory with stack management.
/// Items are identified by u16 ItemId. For now, items map directly to BlockId values,
/// but the wider type leaves room for non-block items in the future.

const std = @import("std");

pub const ItemId = u16;
pub const STACK_MAX: u8 = 64;
pub const HOTBAR_SIZE: u8 = 9;
pub const SLOT_COUNT: u8 = 36; // 9 hotbar + 27 main

pub const Slot = struct {
    item: ItemId,
    count: u8,

    pub const empty = Slot{ .item = 0, .count = 0 };

    pub fn isEmpty(self: Slot) bool {
        return self.count == 0;
    }
};

pub const Inventory = struct {
    slots: [SLOT_COUNT]Slot,

    pub fn init() Inventory {
        return .{ .slots = [_]Slot{Slot.empty} ** SLOT_COUNT };
    }

    /// Add `count` of `item` to the inventory.
    /// Tries to stack onto existing matching slots first, then fills empty slots.
    /// Returns the number of items that could not fit (leftover).
    pub fn addItem(self: *Inventory, item: ItemId, count: u8) u8 {
        var remaining: u8 = count;

        // First pass: stack onto existing slots that already contain this item.
        for (&self.slots) |*slot| {
            if (remaining == 0) break;
            if (slot.item == item and slot.count > 0 and slot.count < STACK_MAX) {
                const space = STACK_MAX - slot.count;
                const to_add = @min(space, remaining);
                slot.count += to_add;
                remaining -= to_add;
            }
        }

        // Second pass: place into empty slots.
        for (&self.slots) |*slot| {
            if (remaining == 0) break;
            if (slot.isEmpty()) {
                const to_add = @min(STACK_MAX, remaining);
                slot.item = item;
                slot.count = to_add;
                remaining -= to_add;
            }
        }

        return remaining;
    }

    /// Remove up to `count` items from the slot at `slot_idx`.
    /// Returns a Slot describing what was actually removed.
    /// If the slot is empty or index is out of range, returns Slot.empty.
    pub fn removeItem(self: *Inventory, slot_idx: u8, count: u8) Slot {
        if (slot_idx >= SLOT_COUNT) return Slot.empty;

        const slot = &self.slots[slot_idx];
        if (slot.isEmpty()) return Slot.empty;

        const removed = @min(count, slot.count);
        const item = slot.item;
        slot.count -= removed;
        if (slot.count == 0) {
            slot.item = 0;
        }
        return .{ .item = item, .count = removed };
    }

    /// Swap the contents of two slots.
    pub fn swapSlots(self: *Inventory, a: u8, b: u8) void {
        if (a >= SLOT_COUNT or b >= SLOT_COUNT) return;
        const tmp = self.slots[a];
        self.slots[a] = self.slots[b];
        self.slots[b] = tmp;
    }

    /// Get a copy of the slot at the given index.
    pub fn getSlot(self: *const Inventory, idx: u8) Slot {
        if (idx >= SLOT_COUNT) return Slot.empty;
        return self.slots[idx];
    }

    /// Find the first slot containing the given item.
    /// Returns the slot index, or null if the item is not in the inventory.
    pub fn findItem(self: *const Inventory, item: ItemId) ?u8 {
        for (self.slots, 0..) |slot, i| {
            if (slot.item == item and slot.count > 0) {
                return @intCast(i);
            }
        }
        return null;
    }

    /// Returns the hotbar portion of the inventory (slots 0..9).
    pub fn hotbarSlice(self: *const Inventory) []const Slot {
        return self.slots[0..HOTBAR_SIZE];
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "init creates empty inventory" {
    const inv = Inventory.init();
    for (inv.slots) |slot| {
        try std.testing.expect(slot.isEmpty());
    }
}

test "addItem fills an empty slot" {
    var inv = Inventory.init();
    const leftover = inv.addItem(1, 10);
    try std.testing.expectEqual(@as(u8, 0), leftover);

    const slot = inv.getSlot(0);
    try std.testing.expectEqual(@as(ItemId, 1), slot.item);
    try std.testing.expectEqual(@as(u8, 10), slot.count);
}

test "addItem stacks onto existing slot" {
    var inv = Inventory.init();
    _ = inv.addItem(1, 30);
    _ = inv.addItem(1, 20);

    // Should stack into the same slot (30 + 20 = 50, under STACK_MAX).
    const slot = inv.getSlot(0);
    try std.testing.expectEqual(@as(u8, 50), slot.count);
    // Second slot should still be empty.
    try std.testing.expect(inv.getSlot(1).isEmpty());
}

test "addItem overflows to next slot" {
    var inv = Inventory.init();
    _ = inv.addItem(1, 60);
    _ = inv.addItem(1, 20);

    // First slot: 64 (60 + 4 from second add), second slot: 16.
    const s0 = inv.getSlot(0);
    const s1 = inv.getSlot(1);
    try std.testing.expectEqual(@as(u8, 64), s0.count);
    try std.testing.expectEqual(@as(u8, 16), s1.count);
}

test "addItem returns leftover when inventory is full" {
    var inv = Inventory.init();
    // Fill all 36 slots to max.
    for (0..SLOT_COUNT) |_| {
        _ = inv.addItem(1, STACK_MAX);
    }
    // Now try to add more.
    const leftover = inv.addItem(1, 10);
    try std.testing.expectEqual(@as(u8, 10), leftover);
}

test "removeItem removes from a slot" {
    var inv = Inventory.init();
    _ = inv.addItem(5, 20);

    const removed = inv.removeItem(0, 8);
    try std.testing.expectEqual(@as(ItemId, 5), removed.item);
    try std.testing.expectEqual(@as(u8, 8), removed.count);
    try std.testing.expectEqual(@as(u8, 12), inv.getSlot(0).count);
}

test "removeItem clears slot when all removed" {
    var inv = Inventory.init();
    _ = inv.addItem(5, 10);

    const removed = inv.removeItem(0, 10);
    try std.testing.expectEqual(@as(u8, 10), removed.count);
    try std.testing.expect(inv.getSlot(0).isEmpty());
}

test "removeItem from empty slot returns empty" {
    var inv = Inventory.init();
    const removed = inv.removeItem(0, 5);
    try std.testing.expect(removed.isEmpty());
}

test "swapSlots swaps two slots" {
    var inv = Inventory.init();
    _ = inv.addItem(1, 10);
    _ = inv.addItem(2, 20);

    inv.swapSlots(0, 1);

    const s0 = inv.getSlot(0);
    const s1 = inv.getSlot(1);
    try std.testing.expectEqual(@as(ItemId, 2), s0.item);
    try std.testing.expectEqual(@as(u8, 20), s0.count);
    try std.testing.expectEqual(@as(ItemId, 1), s1.item);
    try std.testing.expectEqual(@as(u8, 10), s1.count);
}

test "findItem returns slot index" {
    var inv = Inventory.init();
    _ = inv.addItem(3, 5);
    _ = inv.addItem(7, 12);

    try std.testing.expectEqual(@as(?u8, 0), inv.findItem(3));
    try std.testing.expectEqual(@as(?u8, 1), inv.findItem(7));
    try std.testing.expectEqual(@as(?u8, null), inv.findItem(99));
}

test "hotbarSlice returns first 9 slots" {
    var inv = Inventory.init();
    _ = inv.addItem(1, 5);
    const hotbar = inv.hotbarSlice();
    try std.testing.expectEqual(@as(usize, HOTBAR_SIZE), hotbar.len);
    try std.testing.expectEqual(@as(u8, 5), hotbar[0].count);
}
