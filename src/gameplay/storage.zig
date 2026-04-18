/// Storage container systems: ShulkerBox, Barrel, EnderChest, and Bundle.
/// Each container type wraps a shared Inventory27 or custom storage with
/// behaviour specific to its Minecraft counterpart.

const std = @import("std");
const inventory = @import("inventory.zig");

const ItemId = inventory.ItemId;
const STACK_MAX = inventory.STACK_MAX;

// ──────────────────────────────────────────────────────────────────────────────
// Slot (container-local, lightweight)
// ──────────────────────────────────────────────────────────────────────────────

pub const Slot = struct {
    item_id: u16,
    count: u8,

    pub const empty = Slot{ .item_id = 0, .count = 0 };

    pub fn isEmpty(self: Slot) bool {
        return self.count == 0;
    }
};

// ──────────────────────────────────────────────────────────────────────────────
// Inventory27 – reusable 27-slot inventory used by ShulkerBox, Barrel, EnderChest
// ──────────────────────────────────────────────────────────────────────────────

pub const INVENTORY27_SIZE: u8 = 27;

pub const Inventory27 = struct {
    slots: [INVENTORY27_SIZE]Slot,

    pub fn init() Inventory27 {
        return .{ .slots = [_]Slot{Slot.empty} ** INVENTORY27_SIZE };
    }

    pub fn getSlot(self: *const Inventory27, idx: u8) Slot {
        if (idx >= INVENTORY27_SIZE) return Slot.empty;
        return self.slots[idx];
    }

    pub fn setSlot(self: *Inventory27, idx: u8, slot: Slot) void {
        if (idx >= INVENTORY27_SIZE) return;
        self.slots[idx] = slot;
    }

    /// Add `count` of `item_id` to the inventory.
    /// Stacks onto matching slots first, then fills empty slots.
    /// Returns the number of items that could not fit (leftover).
    pub fn addItem(self: *Inventory27, item_id: u16, count: u8) u8 {
        var remaining: u8 = count;

        for (&self.slots) |*slot| {
            if (remaining == 0) break;
            if (slot.item_id == item_id and slot.count > 0 and slot.count < STACK_MAX) {
                const space = STACK_MAX - slot.count;
                const to_add = @min(space, remaining);
                slot.count += to_add;
                remaining -= to_add;
            }
        }

        for (&self.slots) |*slot| {
            if (remaining == 0) break;
            if (slot.isEmpty()) {
                const to_add = @min(STACK_MAX, remaining);
                slot.item_id = item_id;
                slot.count = to_add;
                remaining -= to_add;
            }
        }

        return remaining;
    }

    /// Return the index of the first empty slot, or null if full.
    pub fn firstEmpty(self: *const Inventory27) ?u8 {
        for (self.slots, 0..) |slot, i| {
            if (slot.isEmpty()) return @intCast(i);
        }
        return null;
    }

    /// Return true when every slot is empty.
    pub fn isEmpty(self: *const Inventory27) bool {
        for (self.slots) |slot| {
            if (!slot.isEmpty()) return false;
        }
        return true;
    }
};

// ──────────────────────────────────────────────────────────────────────────────
// ShulkerBox – 27 slots, coloured, keeps inventory when broken
// ──────────────────────────────────────────────────────────────────────────────

pub const ShulkerBox = struct {
    inventory: Inventory27,
    color: u4,
    keeps_inventory_when_broken: bool,

    pub fn init(color: u4) ShulkerBox {
        return .{
            .inventory = Inventory27.init(),
            .color = color,
            .keeps_inventory_when_broken = true,
        };
    }

    pub fn getSlot(self: *const ShulkerBox, idx: u8) Slot {
        return self.inventory.getSlot(idx);
    }

    pub fn setSlot(self: *ShulkerBox, idx: u8, slot: Slot) void {
        self.inventory.setSlot(idx, slot);
    }

    pub fn isEmpty(self: *const ShulkerBox) bool {
        return self.inventory.isEmpty();
    }
};

// ──────────────────────────────────────────────────────────────────────────────
// Barrel – 27 slots, blocked when a solid block is above
// ──────────────────────────────────────────────────────────────────────────────

pub const Barrel = struct {
    inventory: Inventory27,

    pub fn init() Barrel {
        return .{ .inventory = Inventory27.init() };
    }

    /// A barrel cannot open when a solid block sits directly above it.
    pub fn canOpen(block_above_solid: bool) bool {
        return !block_above_solid;
    }

    pub fn getSlot(self: *const Barrel, idx: u8) Slot {
        return self.inventory.getSlot(idx);
    }

    pub fn setSlot(self: *Barrel, idx: u8, slot: Slot) void {
        self.inventory.setSlot(idx, slot);
    }

    pub fn isEmpty(self: *const Barrel) bool {
        return self.inventory.isEmpty();
    }
};

// ──────────────────────────────────────────────────────────────────────────────
// EnderChest – shared global 27-slot inventory
// ──────────────────────────────────────────────────────────────────────────────

pub const EnderChest = struct {
    var shared_inventory: Inventory27 = Inventory27.init();

    /// Return a pointer to the single shared ender-chest inventory.
    pub fn getSharedInventory() *Inventory27 {
        return &shared_inventory;
    }

    /// Reset shared state (useful in tests).
    pub fn resetSharedInventory() void {
        shared_inventory = Inventory27.init();
    }
};

// ──────────────────────────────────────────────────────────────────────────────
// Bundle – up to 64 total item weight in a single container
// ──────────────────────────────────────────────────────────────────────────────

pub const BUNDLE_CAPACITY: u8 = 64;
pub const BUNDLE_MAX_ENTRIES: usize = 64;

pub const BundleEntry = struct {
    item_id: u16,
    count: u8,
};

pub const Bundle = struct {
    items: [BUNDLE_MAX_ENTRIES]?BundleEntry,

    pub fn init() Bundle {
        return .{ .items = [_]?BundleEntry{null} ** BUNDLE_MAX_ENTRIES };
    }

    /// Current total weight (sum of all item counts).
    pub fn getWeight(self: *const Bundle) u8 {
        var total: u8 = 0;
        for (self.items) |entry| {
            if (entry) |e| {
                total += e.count;
            }
        }
        return total;
    }

    pub fn isFull(self: *const Bundle) bool {
        return self.getWeight() >= BUNDLE_CAPACITY;
    }

    /// Add items to the bundle. Returns true if all items were added,
    /// false if the bundle would exceed its weight limit (no items added).
    pub fn addItem(self: *Bundle, item_id: u16, count: u8) bool {
        if (count == 0) return true;
        const weight = self.getWeight();
        if (@as(u16, weight) + @as(u16, count) > BUNDLE_CAPACITY) return false;

        var first_empty: ?*?BundleEntry = null;
        for (&self.items) |*slot| {
            if (slot.*) |*entry| {
                if (entry.item_id == item_id) {
                    entry.count += count;
                    return true;
                }
            } else if (first_empty == null) {
                first_empty = slot;
            }
        }

        if (first_empty) |slot| {
            slot.* = BundleEntry{ .item_id = item_id, .count = count };
            return true;
        }

        return false;
    }

    /// Remove all items matching `item_id` from the bundle.
    /// Returns the total count removed.
    pub fn removeItem(self: *Bundle, item_id: u16) u8 {
        var removed: u8 = 0;
        for (&self.items) |*slot| {
            if (slot.*) |entry| {
                if (entry.item_id == item_id) {
                    removed += entry.count;
                    slot.* = null;
                }
            }
        }
        return removed;
    }
};

// ──────────────────────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────────────────────

test "Inventory27 init is empty" {
    const inv = Inventory27.init();
    try std.testing.expect(inv.isEmpty());
    try std.testing.expectEqual(@as(?u8, 0), inv.firstEmpty());
}

test "Inventory27 addItem and getSlot" {
    var inv = Inventory27.init();
    const leftover = inv.addItem(10, 5);
    try std.testing.expectEqual(@as(u8, 0), leftover);
    const slot = inv.getSlot(0);
    try std.testing.expectEqual(@as(u16, 10), slot.item_id);
    try std.testing.expectEqual(@as(u8, 5), slot.count);
}

test "Inventory27 addItem stacks onto existing" {
    var inv = Inventory27.init();
    _ = inv.addItem(10, 30);
    _ = inv.addItem(10, 20);
    const slot = inv.getSlot(0);
    try std.testing.expectEqual(@as(u8, 50), slot.count);
    try std.testing.expect(inv.getSlot(1).isEmpty());
}

test "Inventory27 addItem returns leftover when full" {
    var inv = Inventory27.init();
    for (0..INVENTORY27_SIZE) |_| {
        _ = inv.addItem(1, STACK_MAX);
    }
    const leftover = inv.addItem(1, 10);
    try std.testing.expectEqual(@as(u8, 10), leftover);
}

test "Inventory27 setSlot" {
    var inv = Inventory27.init();
    inv.setSlot(5, .{ .item_id = 42, .count = 7 });
    const slot = inv.getSlot(5);
    try std.testing.expectEqual(@as(u16, 42), slot.item_id);
    try std.testing.expectEqual(@as(u8, 7), slot.count);
}

test "Inventory27 firstEmpty skips occupied slots" {
    var inv = Inventory27.init();
    inv.setSlot(0, .{ .item_id = 1, .count = 1 });
    inv.setSlot(1, .{ .item_id = 2, .count = 1 });
    try std.testing.expectEqual(@as(?u8, 2), inv.firstEmpty());
}

test "ShulkerBox keeps inventory when broken" {
    var box = ShulkerBox.init(5);
    box.setSlot(0, .{ .item_id = 99, .count = 32 });

    try std.testing.expect(box.keeps_inventory_when_broken);
    const slot = box.getSlot(0);
    try std.testing.expectEqual(@as(u16, 99), slot.item_id);
    try std.testing.expectEqual(@as(u8, 32), slot.count);
    try std.testing.expectEqual(@as(u4, 5), box.color);
}

test "ShulkerBox isEmpty" {
    const box = ShulkerBox.init(0);
    try std.testing.expect(box.isEmpty());
}

test "Barrel blocked by solid block above" {
    try std.testing.expect(!Barrel.canOpen(true));
    try std.testing.expect(Barrel.canOpen(false));
}

test "Barrel inventory operations" {
    var barrel = Barrel.init();
    barrel.setSlot(0, .{ .item_id = 7, .count = 16 });
    try std.testing.expectEqual(@as(u16, 7), barrel.getSlot(0).item_id);
    try std.testing.expect(!barrel.isEmpty());
}

test "EnderChest shared inventory" {
    EnderChest.resetSharedInventory();
    const inv = EnderChest.getSharedInventory();
    _ = inv.addItem(42, 10);

    // A second call returns the same inventory.
    const inv2 = EnderChest.getSharedInventory();
    const slot = inv2.getSlot(0);
    try std.testing.expectEqual(@as(u16, 42), slot.item_id);
    try std.testing.expectEqual(@as(u8, 10), slot.count);

    // Both pointers are identical.
    try std.testing.expectEqual(inv, inv2);

    EnderChest.resetSharedInventory();
}

test "Bundle weight limit" {
    var bundle = Bundle.init();
    try std.testing.expect(bundle.addItem(1, 60));
    try std.testing.expectEqual(@as(u8, 60), bundle.getWeight());
    try std.testing.expect(!bundle.isFull());

    // Adding 5 more exceeds the 64 limit.
    try std.testing.expect(!bundle.addItem(2, 5));
    // Weight unchanged after failed add.
    try std.testing.expectEqual(@as(u8, 60), bundle.getWeight());

    // Adding exactly 4 fills it up.
    try std.testing.expect(bundle.addItem(2, 4));
    try std.testing.expect(bundle.isFull());
}

test "Bundle addItem stacks same item" {
    var bundle = Bundle.init();
    try std.testing.expect(bundle.addItem(10, 5));
    try std.testing.expect(bundle.addItem(10, 3));
    try std.testing.expectEqual(@as(u8, 8), bundle.getWeight());
}

test "Bundle removeItem" {
    var bundle = Bundle.init();
    _ = bundle.addItem(10, 5);
    _ = bundle.addItem(20, 3);

    const removed = bundle.removeItem(10);
    try std.testing.expectEqual(@as(u8, 5), removed);
    try std.testing.expectEqual(@as(u8, 3), bundle.getWeight());
}

test "Bundle removeItem returns zero for missing item" {
    var bundle = Bundle.init();
    const removed = bundle.removeItem(999);
    try std.testing.expectEqual(@as(u8, 0), removed);
}

test "Bundle empty weight is zero" {
    const bundle = Bundle.init();
    try std.testing.expectEqual(@as(u8, 0), bundle.getWeight());
    try std.testing.expect(!bundle.isFull());
}
