/// Automation system: hopper and dropper block mechanics.
/// Hoppers transfer items between inventories on a timer.
/// Droppers eject items when triggered by redstone.

const std = @import("std");

pub const HOPPER_TRANSFER_INTERVAL: f32 = 0.4; // seconds between transfers

pub const HopperState = struct {
    source_item: u16, // item being transferred (0 = empty)
    source_count: u8,
    cooldown: f32,

    pub fn init() HopperState {
        return .{
            .source_item = 0,
            .source_count = 0,
            .cooldown = 0.0,
        };
    }

    /// Load items into the hopper buffer.
    pub fn loadItem(self: *HopperState, item_id: u16, count: u8) void {
        self.source_item = item_id;
        self.source_count = count;
    }

    /// Tick the hopper. Returns an item transfer if one occurred.
    pub fn update(self: *HopperState, dt: f32) ?struct { item_id: u16, count: u8 } {
        if (self.source_count == 0) return null;
        self.cooldown -= dt;
        if (self.cooldown <= 0.0) {
            self.cooldown = HOPPER_TRANSFER_INTERVAL;
            const transfer_count: u8 = 1;
            self.source_count -= transfer_count;
            const item = self.source_item;
            if (self.source_count == 0) self.source_item = 0;
            return .{ .item_id = item, .count = transfer_count };
        }
        return null;
    }
};

pub const DropperState = struct {
    items: [9]DropperSlot,

    pub const DropperSlot = struct {
        item_id: u16 = 0,
        count: u8 = 0,
    };

    pub fn init() DropperState {
        return .{
            .items = [_]DropperSlot{.{}} ** 9,
        };
    }

    /// Eject one item from the first non-empty slot.
    /// Returns the ejected item or null if empty.
    pub fn eject(self: *DropperState) ?struct { item_id: u16, count: u8 } {
        for (&self.items) |*slot| {
            if (slot.count > 0) {
                const item = slot.item_id;
                slot.count -= 1;
                if (slot.count == 0) slot.item_id = 0;
                return .{ .item_id = item, .count = 1 };
            }
        }
        return null;
    }
};

// ──────────────────────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────────────────────

test "HopperState init is empty" {
    const h = HopperState.init();
    try std.testing.expectEqual(@as(u16, 0), h.source_item);
    try std.testing.expectEqual(@as(u8, 0), h.source_count);
}

test "HopperState transfers on cooldown" {
    var h = HopperState.init();
    h.loadItem(42, 5);
    // First update after cooldown
    const result = h.update(0.5);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(u16, 42), result.?.item_id);
    try std.testing.expectEqual(@as(u8, 1), result.?.count);
    try std.testing.expectEqual(@as(u8, 4), h.source_count);
}

test "HopperState no transfer when empty" {
    var h = HopperState.init();
    try std.testing.expect(h.update(1.0) == null);
}

test "DropperState eject returns item" {
    var d = DropperState.init();
    d.items[0] = .{ .item_id = 10, .count = 3 };
    const result = d.eject();
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(u16, 10), result.?.item_id);
    try std.testing.expectEqual(@as(u8, 2), d.items[0].count);
}

test "DropperState eject returns null when empty" {
    var d = DropperState.init();
    try std.testing.expect(d.eject() == null);
}
