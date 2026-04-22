/// 3x3 crafting grid state for the crafting table UI.
/// Separate from the player's 2x2 inventory crafting area.

const std = @import("std");
const inv = @import("inventory.zig");

pub const Slot = inv.Slot;
pub const ItemId = inv.ItemId;
pub const STACK_MAX = inv.STACK_MAX;

pub const CraftingGrid = struct {
    slots: [9]Slot,

    pub fn init() CraftingGrid {
        return .{ .slots = [_]Slot{Slot.empty} ** 9 };
    }

    /// Extract a 3x3 grid of item IDs (0 for empty) for recipe matching.
    pub fn getRecipeGrid(self: *const CraftingGrid) [3][3]ItemId {
        var grid: [3][3]ItemId = undefined;
        for (0..3) |r| {
            for (0..3) |c| {
                const slot = self.slots[r * 3 + c];
                grid[r][c] = if (slot.isEmpty()) 0 else slot.item;
            }
        }
        return grid;
    }

    /// Decrement count by 1 for each non-zero pattern cell. Clear slot if count reaches 0.
    pub fn consumeForPattern(self: *CraftingGrid, pattern: [3][3]ItemId) void {
        for (0..3) |r| {
            for (0..3) |c| {
                if (pattern[r][c] != 0) {
                    const idx = r * 3 + c;
                    if (self.slots[idx].count > 0) {
                        self.slots[idx].count -= 1;
                        if (self.slots[idx].count == 0) {
                            self.slots[idx] = Slot.empty;
                        }
                    }
                }
            }
        }
    }

    /// Move all grid items back to inventory slots (find empty or stackable slots). Clear grid.
    pub fn returnAllToInventory(self: *CraftingGrid, inventory_slots: []Slot) void {
        for (&self.slots) |*grid_slot| {
            if (grid_slot.isEmpty()) continue;

            var remaining = grid_slot.count;
            const item = grid_slot.item;

            // First pass: stack onto matching slots.
            for (inventory_slots) |*inv_slot| {
                if (remaining == 0) break;
                if (inv_slot.item == item and inv_slot.count > 0 and inv_slot.count < STACK_MAX) {
                    const space = STACK_MAX - inv_slot.count;
                    const to_add = @min(space, remaining);
                    inv_slot.count += to_add;
                    remaining -= to_add;
                }
            }

            // Second pass: fill empty slots.
            for (inventory_slots) |*inv_slot| {
                if (remaining == 0) break;
                if (inv_slot.isEmpty()) {
                    const to_add = @min(STACK_MAX, remaining);
                    inv_slot.item = item;
                    inv_slot.count = to_add;
                    remaining -= to_add;
                }
            }

            grid_slot.* = Slot.empty;
        }
    }

    /// Left-click: same item stacks cursor onto slot; different/empty swaps. Returns new cursor.
    pub fn leftClickSlot(self: *CraftingGrid, idx: u8, cursor: Slot) Slot {
        if (idx >= 9) return cursor;

        const slot = &self.slots[idx];

        // Both empty: nothing to do.
        if (cursor.isEmpty() and slot.isEmpty()) return cursor;

        // Same item: stack cursor onto slot.
        if (!cursor.isEmpty() and !slot.isEmpty() and cursor.item == slot.item) {
            const space = STACK_MAX - slot.count;
            const to_move = @min(space, cursor.count);
            slot.count += to_move;
            const new_count = cursor.count - to_move;
            if (new_count == 0) {
                return Slot.empty;
            }
            return .{ .item = cursor.item, .count = new_count };
        }

        // Different items or one empty: swap.
        const old_slot = slot.*;
        slot.* = cursor;
        return old_slot;
    }

    /// Right-click: place 1 item from cursor into slot (if empty or same item and not full).
    pub fn rightClickSlot(self: *CraftingGrid, idx: u8, cursor: Slot) Slot {
        if (idx >= 9) return cursor;
        if (cursor.isEmpty()) return cursor;

        const slot = &self.slots[idx];

        if (slot.isEmpty()) {
            slot.* = .{ .item = cursor.item, .count = 1 };
        } else if (slot.item == cursor.item and slot.count < STACK_MAX) {
            slot.count += 1;
        } else {
            return cursor;
        }

        if (cursor.count == 1) {
            return Slot.empty;
        }
        return .{ .item = cursor.item, .count = cursor.count - 1 };
    }

    pub fn isEmpty(self: *const CraftingGrid) bool {
        for (self.slots) |slot| {
            if (!slot.isEmpty()) return false;
        }
        return true;
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "init creates empty grid" {
    const grid = CraftingGrid.init();
    for (grid.slots) |slot| {
        try std.testing.expect(slot.isEmpty());
    }
    try std.testing.expect(grid.isEmpty());
}

test "isEmpty returns false when grid has items" {
    var grid = CraftingGrid.init();
    grid.slots[4] = .{ .item = 1, .count = 5 };
    try std.testing.expect(!grid.isEmpty());
}

test "getRecipeGrid extracts item IDs" {
    var grid = CraftingGrid.init();
    grid.slots[0] = .{ .item = 5, .count = 1 };
    grid.slots[1] = .{ .item = 5, .count = 3 };
    grid.slots[3] = .{ .item = 5, .count = 1 };
    grid.slots[4] = .{ .item = 5, .count = 2 };

    const recipe = grid.getRecipeGrid();
    try std.testing.expectEqual(@as(ItemId, 5), recipe[0][0]);
    try std.testing.expectEqual(@as(ItemId, 5), recipe[0][1]);
    try std.testing.expectEqual(@as(ItemId, 0), recipe[0][2]);
    try std.testing.expectEqual(@as(ItemId, 5), recipe[1][0]);
    try std.testing.expectEqual(@as(ItemId, 5), recipe[1][1]);
    try std.testing.expectEqual(@as(ItemId, 0), recipe[2][2]);
}

test "getRecipeGrid all empty returns zeros" {
    const grid = CraftingGrid.init();
    const recipe = grid.getRecipeGrid();
    for (0..3) |r| {
        for (0..3) |c| {
            try std.testing.expectEqual(@as(ItemId, 0), recipe[r][c]);
        }
    }
}

test "consumeForPattern decrements counts" {
    var grid = CraftingGrid.init();
    grid.slots[0] = .{ .item = 5, .count = 3 };
    grid.slots[1] = .{ .item = 5, .count = 1 };

    const pattern = [3][3]ItemId{
        .{ 5, 5, 0 },
        .{ 0, 0, 0 },
        .{ 0, 0, 0 },
    };
    grid.consumeForPattern(pattern);

    try std.testing.expectEqual(@as(u8, 2), grid.slots[0].count);
    try std.testing.expect(grid.slots[1].isEmpty());
}

test "consumeForPattern clears slot at zero" {
    var grid = CraftingGrid.init();
    grid.slots[0] = .{ .item = 8, .count = 1 };

    const pattern = [3][3]ItemId{
        .{ 8, 0, 0 },
        .{ 0, 0, 0 },
        .{ 0, 0, 0 },
    };
    grid.consumeForPattern(pattern);

    try std.testing.expect(grid.slots[0].isEmpty());
    try std.testing.expectEqual(@as(ItemId, 0), grid.slots[0].item);
}

test "leftClickSlot swaps cursor with empty slot" {
    var grid = CraftingGrid.init();
    const cursor = Slot{ .item = 10, .count = 5 };
    const result = grid.leftClickSlot(0, cursor);

    try std.testing.expect(result.isEmpty());
    try std.testing.expectEqual(@as(ItemId, 10), grid.slots[0].item);
    try std.testing.expectEqual(@as(u8, 5), grid.slots[0].count);
}

test "leftClickSlot picks up item with empty cursor" {
    var grid = CraftingGrid.init();
    grid.slots[2] = .{ .item = 7, .count = 12 };

    const result = grid.leftClickSlot(2, Slot.empty);

    try std.testing.expectEqual(@as(ItemId, 7), result.item);
    try std.testing.expectEqual(@as(u8, 12), result.count);
    try std.testing.expect(grid.slots[2].isEmpty());
}

test "leftClickSlot stacks same item" {
    var grid = CraftingGrid.init();
    grid.slots[0] = .{ .item = 3, .count = 20 };
    const cursor = Slot{ .item = 3, .count = 10 };

    const result = grid.leftClickSlot(0, cursor);

    try std.testing.expect(result.isEmpty());
    try std.testing.expectEqual(@as(u8, 30), grid.slots[0].count);
}

test "leftClickSlot stacking with overflow returns remainder" {
    var grid = CraftingGrid.init();
    grid.slots[0] = .{ .item = 3, .count = 60 };
    const cursor = Slot{ .item = 3, .count = 10 };

    const result = grid.leftClickSlot(0, cursor);

    try std.testing.expectEqual(@as(u8, 64), grid.slots[0].count);
    try std.testing.expectEqual(@as(ItemId, 3), result.item);
    try std.testing.expectEqual(@as(u8, 6), result.count);
}

test "leftClickSlot swaps different items" {
    var grid = CraftingGrid.init();
    grid.slots[0] = .{ .item = 1, .count = 5 };
    const cursor = Slot{ .item = 2, .count = 10 };

    const result = grid.leftClickSlot(0, cursor);

    try std.testing.expectEqual(@as(ItemId, 1), result.item);
    try std.testing.expectEqual(@as(u8, 5), result.count);
    try std.testing.expectEqual(@as(ItemId, 2), grid.slots[0].item);
    try std.testing.expectEqual(@as(u8, 10), grid.slots[0].count);
}

test "rightClickSlot places one item into empty slot" {
    var grid = CraftingGrid.init();
    const cursor = Slot{ .item = 4, .count = 8 };

    const result = grid.rightClickSlot(0, cursor);

    try std.testing.expectEqual(@as(u8, 1), grid.slots[0].count);
    try std.testing.expectEqual(@as(ItemId, 4), grid.slots[0].item);
    try std.testing.expectEqual(@as(u8, 7), result.count);
}

test "rightClickSlot places one onto same item" {
    var grid = CraftingGrid.init();
    grid.slots[0] = .{ .item = 4, .count = 3 };
    const cursor = Slot{ .item = 4, .count = 5 };

    const result = grid.rightClickSlot(0, cursor);

    try std.testing.expectEqual(@as(u8, 4), grid.slots[0].count);
    try std.testing.expectEqual(@as(u8, 4), result.count);
}

test "rightClickSlot does nothing on different item" {
    var grid = CraftingGrid.init();
    grid.slots[0] = .{ .item = 1, .count = 3 };
    const cursor = Slot{ .item = 2, .count = 5 };

    const result = grid.rightClickSlot(0, cursor);

    try std.testing.expectEqual(@as(u8, 3), grid.slots[0].count);
    try std.testing.expectEqual(@as(u8, 5), result.count);
}

test "rightClickSlot does nothing on full slot" {
    var grid = CraftingGrid.init();
    grid.slots[0] = .{ .item = 4, .count = 64 };
    const cursor = Slot{ .item = 4, .count = 5 };

    const result = grid.rightClickSlot(0, cursor);

    try std.testing.expectEqual(@as(u8, 64), grid.slots[0].count);
    try std.testing.expectEqual(@as(u8, 5), result.count);
}

test "rightClickSlot empties cursor when placing last item" {
    var grid = CraftingGrid.init();
    const cursor = Slot{ .item = 4, .count = 1 };

    const result = grid.rightClickSlot(0, cursor);

    try std.testing.expect(result.isEmpty());
    try std.testing.expectEqual(@as(u8, 1), grid.slots[0].count);
}

test "returnAllToInventory moves items and clears grid" {
    var grid = CraftingGrid.init();
    grid.slots[0] = .{ .item = 5, .count = 10 };
    grid.slots[4] = .{ .item = 8, .count = 3 };

    var inv_slots = [_]Slot{Slot.empty} ** 4;
    grid.returnAllToInventory(&inv_slots);

    try std.testing.expect(grid.isEmpty());
    try std.testing.expectEqual(@as(ItemId, 5), inv_slots[0].item);
    try std.testing.expectEqual(@as(u8, 10), inv_slots[0].count);
    try std.testing.expectEqual(@as(ItemId, 8), inv_slots[1].item);
    try std.testing.expectEqual(@as(u8, 3), inv_slots[1].count);
}

test "returnAllToInventory stacks onto existing matching slots" {
    var grid = CraftingGrid.init();
    grid.slots[0] = .{ .item = 5, .count = 10 };

    var inv_slots = [_]Slot{Slot.empty} ** 4;
    inv_slots[0] = .{ .item = 5, .count = 20 };
    grid.returnAllToInventory(&inv_slots);

    try std.testing.expect(grid.isEmpty());
    try std.testing.expectEqual(@as(u8, 30), inv_slots[0].count);
    try std.testing.expect(inv_slots[1].isEmpty());
}

test "leftClickSlot with out-of-range index returns cursor unchanged" {
    var grid = CraftingGrid.init();
    const cursor = Slot{ .item = 1, .count = 5 };
    const result = grid.leftClickSlot(10, cursor);
    try std.testing.expectEqual(cursor.item, result.item);
    try std.testing.expectEqual(cursor.count, result.count);
}
