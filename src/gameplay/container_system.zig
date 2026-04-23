/// Container management for chests, barrels, and ender chests.
/// Provides world-position-keyed storage through a fixed-capacity ContainerManager.

const std = @import("std");

// ──────────────────────────────────────────────────────────────────────────────
// Slot
// ──────────────────────────────────────────────────────────────────────────────

pub const Slot = struct {
    item: u16 = 0,
    count: u8 = 0,

    pub const empty = Slot{};

    pub fn isEmpty(self: Slot) bool {
        return self.count == 0;
    }
};

// ──────────────────────────────────────────────────────────────────────────────
// Container – 27-slot inventory with click and add semantics
// ──────────────────────────────────────────────────────────────────────────────

pub const CONTAINER_SIZE: u8 = 27;
pub const STACK_MAX: u8 = 64;

pub const Container = struct {
    slots: [CONTAINER_SIZE]Slot = [_]Slot{Slot.empty} ** CONTAINER_SIZE,

    /// Read a single slot (bounds-checked).
    pub fn getSlot(self: *const Container, idx: u8) Slot {
        if (idx >= CONTAINER_SIZE) return Slot.empty;
        return self.slots[idx];
    }

    /// Simulate a player click: swap cursor with the target slot, merging
    /// stacks of the same item type when possible.
    /// Returns the new cursor contents after the interaction.
    pub fn clickSlot(self: *Container, idx: u8, cursor: Slot) Slot {
        if (idx >= CONTAINER_SIZE) return cursor;

        const old = self.slots[idx];

        // Merge when both cursor and slot hold the same item.
        if (!cursor.isEmpty() and !old.isEmpty() and cursor.item == old.item) {
            const space = STACK_MAX - old.count;
            if (space > 0) {
                const add = @min(space, cursor.count);
                self.slots[idx].count += add;
                const remaining = cursor.count - add;
                if (remaining == 0) return Slot.empty;
                return .{ .item = cursor.item, .count = remaining };
            }
        }

        // Plain swap.
        self.slots[idx] = cursor;
        return old;
    }

    /// Insert items into the container, stacking onto existing matching slots
    /// first, then filling empty slots. Returns the number of items that did
    /// not fit.
    pub fn addItem(self: *Container, item: u16, count: u8) u8 {
        var rem = count;

        // First pass: stack onto existing slots with the same item.
        for (&self.slots) |*s| {
            if (rem == 0) break;
            if (s.item == item and s.count > 0 and s.count < STACK_MAX) {
                const add = @min(STACK_MAX - s.count, rem);
                s.count += add;
                rem -= add;
            }
        }

        // Second pass: place into empty slots.
        for (&self.slots) |*s| {
            if (rem == 0) break;
            if (s.isEmpty()) {
                const add = @min(STACK_MAX, rem);
                s.* = .{ .item = item, .count = add };
                rem -= add;
            }
        }

        return rem;
    }

    /// True when every slot is empty.
    pub fn isEmpty(self: *const Container) bool {
        for (self.slots) |s| {
            if (!s.isEmpty()) return false;
        }
        return true;
    }
};

// ──────────────────────────────────────────────────────────────────────────────
// ContainerManager – position-indexed fixed-capacity registry
// ──────────────────────────────────────────────────────────────────────────────

pub const ContainerPos = struct {
    x: i32,
    y: i32,
    z: i32,
};

pub const MAX_CONTAINERS: usize = 64;

const Entry = struct {
    pos: ContainerPos,
    data: Container,
};

pub const ContainerManager = struct {
    containers: [MAX_CONTAINERS]?Entry = [_]?Entry{null} ** MAX_CONTAINERS,

    pub fn init() ContainerManager {
        return .{};
    }

    /// Return a pointer to the container at (x, y, z), creating one if a
    /// free slot is available. Returns null when the registry is full and the
    /// position does not already exist.
    pub fn getOrCreate(self: *ContainerManager, x: i32, y: i32, z: i32) ?*Container {
        var first_empty: ?usize = null;

        for (&self.containers, 0..) |*entry, i| {
            if (entry.*) |*e| {
                if (e.pos.x == x and e.pos.y == y and e.pos.z == z) {
                    return &e.data;
                }
            } else if (first_empty == null) {
                first_empty = i;
            }
        }

        const slot = first_empty orelse return null;
        self.containers[slot] = .{
            .pos = .{ .x = x, .y = y, .z = z },
            .data = .{},
        };
        return &self.containers[slot].?.data;
    }

    /// Look up an existing container at (x, y, z). Returns null when none
    /// exists at that position.
    pub fn get(self: *ContainerManager, x: i32, y: i32, z: i32) ?*Container {
        for (&self.containers) |*entry| {
            if (entry.*) |*e| {
                if (e.pos.x == x and e.pos.y == y and e.pos.z == z) {
                    return &e.data;
                }
            }
        }
        return null;
    }

    /// Remove the container at (x, y, z), freeing the slot.
    pub fn remove(self: *ContainerManager, x: i32, y: i32, z: i32) void {
        for (&self.containers) |*entry| {
            if (entry.*) |e| {
                if (e.pos.x == x and e.pos.y == y and e.pos.z == z) {
                    entry.* = null;
                    return;
                }
            }
        }
    }
};

// ──────────────────────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────────────────────

test "Slot.empty is empty" {
    const s = Slot.empty;
    try std.testing.expect(s.isEmpty());
    try std.testing.expectEqual(@as(u16, 0), s.item);
    try std.testing.expectEqual(@as(u8, 0), s.count);
}

test "Container init is empty" {
    const c = Container{};
    try std.testing.expect(c.isEmpty());
    try std.testing.expect(c.getSlot(0).isEmpty());
}

test "Container.addItem places items and stacks" {
    var c = Container{};
    const left = c.addItem(10, 5);
    try std.testing.expectEqual(@as(u8, 0), left);
    try std.testing.expectEqual(@as(u16, 10), c.getSlot(0).item);
    try std.testing.expectEqual(@as(u8, 5), c.getSlot(0).count);

    // Stacking onto the same slot.
    const left2 = c.addItem(10, 20);
    try std.testing.expectEqual(@as(u8, 0), left2);
    try std.testing.expectEqual(@as(u8, 25), c.getSlot(0).count);
    try std.testing.expect(c.getSlot(1).isEmpty());
}

test "Container.addItem returns leftover when full" {
    var c = Container{};
    for (0..CONTAINER_SIZE) |_| {
        _ = c.addItem(1, STACK_MAX);
    }
    try std.testing.expect(!c.isEmpty());
    const left = c.addItem(1, 10);
    try std.testing.expectEqual(@as(u8, 10), left);
}

test "Container.clickSlot swaps cursor and slot" {
    var c = Container{};
    const cursor = Slot{ .item = 5, .count = 3 };
    const returned = c.clickSlot(0, cursor);
    try std.testing.expect(returned.isEmpty());
    try std.testing.expectEqual(@as(u16, 5), c.getSlot(0).item);
    try std.testing.expectEqual(@as(u8, 3), c.getSlot(0).count);
}

test "Container.clickSlot merges same-item stacks" {
    var c = Container{};
    _ = c.addItem(7, 50);
    const cursor = Slot{ .item = 7, .count = 10 };
    const returned = c.clickSlot(0, cursor);
    // 50 + 10 = 60, within STACK_MAX(64). Cursor fully consumed.
    try std.testing.expect(returned.isEmpty());
    try std.testing.expectEqual(@as(u8, 60), c.getSlot(0).count);
}

test "Container.clickSlot merge returns leftover in cursor" {
    var c = Container{};
    _ = c.addItem(7, 60);
    const cursor = Slot{ .item = 7, .count = 10 };
    const returned = c.clickSlot(0, cursor);
    // 60 + 10 = 70 > 64. Only 4 fit; 6 remain on cursor.
    try std.testing.expectEqual(@as(u8, 64), c.getSlot(0).count);
    try std.testing.expectEqual(@as(u8, 6), returned.count);
    try std.testing.expectEqual(@as(u16, 7), returned.item);
}

test "Container.clickSlot out-of-bounds returns cursor unchanged" {
    var c = Container{};
    const cursor = Slot{ .item = 1, .count = 1 };
    const returned = c.clickSlot(CONTAINER_SIZE, cursor);
    try std.testing.expectEqual(@as(u8, 1), returned.count);
}

test "Container.getSlot out-of-bounds returns empty" {
    const c = Container{};
    try std.testing.expect(c.getSlot(CONTAINER_SIZE).isEmpty());
    try std.testing.expect(c.getSlot(255).isEmpty());
}

test "ContainerManager.getOrCreate and get" {
    var mgr = ContainerManager.init();
    const c = mgr.getOrCreate(1, 2, 3).?;
    _ = c.addItem(42, 8);

    // get returns the same container.
    const c2 = mgr.get(1, 2, 3).?;
    try std.testing.expectEqual(@as(u8, 8), c2.getSlot(0).count);
}

test "ContainerManager.get returns null for missing position" {
    var mgr = ContainerManager.init();
    try std.testing.expect(mgr.get(0, 0, 0) == null);
}

test "ContainerManager.remove frees the slot" {
    var mgr = ContainerManager.init();
    _ = mgr.getOrCreate(5, 5, 5);
    try std.testing.expect(mgr.get(5, 5, 5) != null);
    mgr.remove(5, 5, 5);
    try std.testing.expect(mgr.get(5, 5, 5) == null);
}

test "ContainerManager.getOrCreate returns null when full" {
    var mgr = ContainerManager.init();
    for (0..MAX_CONTAINERS) |i| {
        try std.testing.expect(mgr.getOrCreate(@intCast(i), 0, 0) != null);
    }
    try std.testing.expect(mgr.getOrCreate(999, 0, 0) == null);
}

test "ContainerManager.getOrCreate reuses removed slot" {
    var mgr = ContainerManager.init();
    for (0..MAX_CONTAINERS) |i| {
        _ = mgr.getOrCreate(@intCast(i), 0, 0);
    }
    mgr.remove(10, 0, 0);
    // Now there is one free slot.
    const c = mgr.getOrCreate(100, 0, 0);
    try std.testing.expect(c != null);
}

test "ContainerManager.remove is idempotent on missing position" {
    var mgr = ContainerManager.init();
    mgr.remove(0, 0, 0); // should not panic
}
