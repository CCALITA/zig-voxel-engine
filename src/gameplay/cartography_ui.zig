/// Cartography table UI for map operations: extending, cloning, and locking maps.
/// Manages map slot, material slot, and computed output slot.

const std = @import("std");

// ── Local Slot type ─────────────────────────────────────────────────

pub const Slot = struct {
    item: u16 = 0,
    count: u8 = 0,

    pub const empty = Slot{};

    pub fn isEmpty(self: Slot) bool {
        return self.count == 0;
    }
};

// ── Item ID constants ───────────────────────────────────────────────

pub const MAP_EMPTY: u16 = 452;
pub const MAP_FILLED: u16 = 306;
pub const PAPER: u16 = 340;
pub const GLASS_PANE: u16 = 540;

// ── Cartography UI ─────────────────────────────────────────────────

pub const CartographyUI = struct {
    map_slot: Slot = Slot.empty,
    material_slot: Slot = Slot.empty,
    output_slot: Slot = Slot.empty,

    pub fn init() CartographyUI {
        return .{};
    }

    /// Swap cursor with map slot, then recalculate output.
    pub fn clickMapSlot(self: *CartographyUI, cursor: Slot) Slot {
        const old = self.map_slot;
        self.map_slot = cursor;
        self.recalculate();
        return old;
    }

    /// Swap cursor with material slot, then recalculate output.
    pub fn clickMaterialSlot(self: *CartographyUI, cursor: Slot) Slot {
        const old = self.material_slot;
        self.material_slot = cursor;
        self.recalculate();
        return old;
    }

    /// Recompute the output slot based on current map + material combination.
    ///  - Filled map + Paper   => extend map (1 filled map)
    ///  - Filled map + Empty map => clone map (2 filled maps)
    ///  - Filled map + Glass pane => lock map (1 filled map)
    pub fn recalculate(self: *CartographyUI) void {
        self.output_slot = Slot.empty;

        if (self.map_slot.isEmpty()) return;
        if (self.material_slot.isEmpty()) return;

        const map_id = self.map_slot.item;
        const mat_id = self.material_slot.item;

        if (map_id == MAP_FILLED and mat_id == PAPER) {
            // Extend: zoom out one level
            self.output_slot = .{ .item = MAP_FILLED, .count = 1 };
        } else if (map_id == MAP_FILLED and mat_id == MAP_EMPTY) {
            // Clone: duplicate the map
            self.output_slot = .{ .item = MAP_FILLED, .count = 2 };
        } else if (map_id == MAP_FILLED and mat_id == GLASS_PANE) {
            // Lock: make map read-only
            self.output_slot = .{ .item = MAP_FILLED, .count = 1 };
        }
    }

    /// Take the computed output, consuming one of each input. Returns null when
    /// there is no valid output. Automatically recalculates for remaining items.
    pub fn takeOutput(self: *CartographyUI) ?Slot {
        if (self.output_slot.isEmpty()) return null;

        const result = self.output_slot;

        self.map_slot.count -= 1;
        if (self.map_slot.count == 0) self.map_slot = Slot.empty;

        self.material_slot.count -= 1;
        if (self.material_slot.count == 0) self.material_slot = Slot.empty;

        self.output_slot = Slot.empty;
        self.recalculate();

        return result;
    }

    /// Return remaining items to the player inventory and reset the table.
    pub fn close(self: *CartographyUI, inv: []Slot) void {
        if (!self.map_slot.isEmpty()) {
            for (inv) |*s| {
                if (s.isEmpty()) {
                    s.* = self.map_slot;
                    break;
                }
            }
            self.map_slot = Slot.empty;
        }
        if (!self.material_slot.isEmpty()) {
            for (inv) |*s| {
                if (s.isEmpty()) {
                    s.* = self.material_slot;
                    break;
                }
            }
            self.material_slot = Slot.empty;
        }
    }
};

// ── Tests ───────────────────────────────────────────────────────────

test "init returns empty state" {
    const ui = CartographyUI.init();
    try std.testing.expect(ui.map_slot.isEmpty());
    try std.testing.expect(ui.material_slot.isEmpty());
    try std.testing.expect(ui.output_slot.isEmpty());
}

test "Slot.empty is empty" {
    try std.testing.expect(Slot.empty.isEmpty());
    const non_empty = Slot{ .item = 1, .count = 1 };
    try std.testing.expect(!non_empty.isEmpty());
}

test "clickMapSlot swaps cursor and recalculates" {
    var ui = CartographyUI.init();
    const prev = ui.clickMapSlot(Slot{ .item = MAP_FILLED, .count = 3 });
    try std.testing.expect(prev.isEmpty());
    try std.testing.expectEqual(@as(u16, MAP_FILLED), ui.map_slot.item);
    try std.testing.expectEqual(@as(u8, 3), ui.map_slot.count);
}

test "clickMaterialSlot swaps cursor and recalculates" {
    var ui = CartographyUI.init();
    _ = ui.clickMapSlot(Slot{ .item = MAP_FILLED, .count = 1 });
    const prev = ui.clickMaterialSlot(Slot{ .item = PAPER, .count = 2 });
    try std.testing.expect(prev.isEmpty());
    try std.testing.expectEqual(@as(u16, PAPER), ui.material_slot.item);
}

test "extend map: filled map + paper produces output" {
    var ui = CartographyUI.init();
    _ = ui.clickMapSlot(Slot{ .item = MAP_FILLED, .count = 1 });
    _ = ui.clickMaterialSlot(Slot{ .item = PAPER, .count = 1 });
    try std.testing.expectEqual(@as(u16, MAP_FILLED), ui.output_slot.item);
    try std.testing.expectEqual(@as(u8, 1), ui.output_slot.count);
}

test "clone map: filled map + empty map produces 2 outputs" {
    var ui = CartographyUI.init();
    _ = ui.clickMapSlot(Slot{ .item = MAP_FILLED, .count = 1 });
    _ = ui.clickMaterialSlot(Slot{ .item = MAP_EMPTY, .count = 1 });
    try std.testing.expectEqual(@as(u16, MAP_FILLED), ui.output_slot.item);
    try std.testing.expectEqual(@as(u8, 2), ui.output_slot.count);
}

test "lock map: filled map + glass pane produces output" {
    var ui = CartographyUI.init();
    _ = ui.clickMapSlot(Slot{ .item = MAP_FILLED, .count = 1 });
    _ = ui.clickMaterialSlot(Slot{ .item = GLASS_PANE, .count = 1 });
    try std.testing.expectEqual(@as(u16, MAP_FILLED), ui.output_slot.item);
    try std.testing.expectEqual(@as(u8, 1), ui.output_slot.count);
}

test "no output when map slot is empty" {
    var ui = CartographyUI.init();
    _ = ui.clickMaterialSlot(Slot{ .item = PAPER, .count = 1 });
    try std.testing.expect(ui.output_slot.isEmpty());
}

test "no output when material slot is empty" {
    var ui = CartographyUI.init();
    _ = ui.clickMapSlot(Slot{ .item = MAP_FILLED, .count = 1 });
    try std.testing.expect(ui.output_slot.isEmpty());
}

test "no output for invalid combination" {
    var ui = CartographyUI.init();
    _ = ui.clickMapSlot(Slot{ .item = MAP_FILLED, .count = 1 });
    _ = ui.clickMaterialSlot(Slot{ .item = 999, .count = 1 });
    try std.testing.expect(ui.output_slot.isEmpty());
}

test "takeOutput consumes one of each input" {
    var ui = CartographyUI.init();
    _ = ui.clickMapSlot(Slot{ .item = MAP_FILLED, .count = 3 });
    _ = ui.clickMaterialSlot(Slot{ .item = PAPER, .count = 2 });

    const result = ui.takeOutput();
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(u16, MAP_FILLED), result.?.item);
    try std.testing.expectEqual(@as(u8, 1), result.?.count);
    try std.testing.expectEqual(@as(u8, 2), ui.map_slot.count);
    try std.testing.expectEqual(@as(u8, 1), ui.material_slot.count);
}

test "takeOutput returns null when no valid output" {
    var ui = CartographyUI.init();
    try std.testing.expectEqual(@as(?Slot, null), ui.takeOutput());
}

test "takeOutput clears slots when input depleted" {
    var ui = CartographyUI.init();
    _ = ui.clickMapSlot(Slot{ .item = MAP_FILLED, .count = 1 });
    _ = ui.clickMaterialSlot(Slot{ .item = PAPER, .count = 1 });

    _ = ui.takeOutput();
    try std.testing.expect(ui.map_slot.isEmpty());
    try std.testing.expect(ui.material_slot.isEmpty());
    try std.testing.expect(ui.output_slot.isEmpty());
}

test "takeOutput recalculates for remaining items" {
    var ui = CartographyUI.init();
    _ = ui.clickMapSlot(Slot{ .item = MAP_FILLED, .count = 2 });
    _ = ui.clickMaterialSlot(Slot{ .item = GLASS_PANE, .count = 2 });

    _ = ui.takeOutput();
    // Should have recalculated a new output from remaining items
    try std.testing.expectEqual(@as(u16, MAP_FILLED), ui.output_slot.item);
    try std.testing.expectEqual(@as(u8, 1), ui.output_slot.count);
}

test "close returns map and material to inventory" {
    var ui = CartographyUI.init();
    _ = ui.clickMapSlot(Slot{ .item = MAP_FILLED, .count = 2 });
    _ = ui.clickMaterialSlot(Slot{ .item = PAPER, .count = 3 });

    var inv = [_]Slot{ Slot.empty, Slot.empty, Slot.empty };
    ui.close(&inv);

    try std.testing.expectEqual(@as(u16, MAP_FILLED), inv[0].item);
    try std.testing.expectEqual(@as(u8, 2), inv[0].count);
    try std.testing.expectEqual(@as(u16, PAPER), inv[1].item);
    try std.testing.expectEqual(@as(u8, 3), inv[1].count);
    try std.testing.expect(ui.map_slot.isEmpty());
    try std.testing.expect(ui.material_slot.isEmpty());
}

test "close with only map slot occupied" {
    var ui = CartographyUI.init();
    _ = ui.clickMapSlot(Slot{ .item = MAP_FILLED, .count = 1 });

    var inv = [_]Slot{Slot.empty};
    ui.close(&inv);

    try std.testing.expectEqual(@as(u16, MAP_FILLED), inv[0].item);
    try std.testing.expect(ui.map_slot.isEmpty());
}
