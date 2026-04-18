/// Ender item system: ender pearls (teleportation) and ender chest
/// (shared cross-dimension storage).

const std = @import("std");

pub const ENDER_PEARL_ITEM_ID: u16 = 230;
pub const ENDER_CHEST_BLOCK_ID: u8 = 46; // next available block ID

/// Calculate the teleport destination from throwing an ender pearl.
/// Returns the landing position given launch position and direction.
pub fn calculatePearlLanding(
    start_x: f32,
    start_y: f32,
    start_z: f32,
    dir_x: f32,
    dir_y: f32,
    dir_z: f32,
    throw_speed: f32,
) struct { x: f32, y: f32, z: f32 } {
    // Simplified parabolic arc: travel ~20 blocks in the throw direction
    const travel_time: f32 = 1.5;
    return .{
        .x = start_x + dir_x * throw_speed * travel_time,
        .y = start_y + dir_y * throw_speed * travel_time - 4.9 * travel_time * travel_time,
        .z = start_z + dir_z * throw_speed * travel_time,
    };
}

/// Damage taken on ender pearl landing.
pub fn getPearlDamage() f32 {
    return 5.0;
}

/// Ender chest inventory: 27 slots shared across all ender chests.
pub const ENDER_CHEST_SLOTS = 27;

pub const EnderChestInventory = struct {
    items: [ENDER_CHEST_SLOTS]EnderSlot,

    pub const EnderSlot = struct {
        item_id: u16 = 0,
        count: u8 = 0,

        pub fn isEmpty(self: *const EnderSlot) bool {
            return self.count == 0 or self.item_id == 0;
        }
    };

    pub fn init() EnderChestInventory {
        return .{
            .items = [_]EnderSlot{.{}} ** ENDER_CHEST_SLOTS,
        };
    }

    /// Add an item to the first available slot. Returns leftover count.
    pub fn addItem(self: *EnderChestInventory, item_id: u16, count: u8) u8 {
        var remaining = count;
        for (&self.items) |*slot| {
            if (remaining == 0) break;
            if (slot.isEmpty()) {
                slot.item_id = item_id;
                slot.count = remaining;
                remaining = 0;
            } else if (slot.item_id == item_id and slot.count < 64) {
                const space = 64 - slot.count;
                const add = @min(remaining, space);
                slot.count += add;
                remaining -= add;
            }
        }
        return remaining;
    }
};

// ──────────────────────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────────────────────

test "calculatePearlLanding moves in direction" {
    const landing = calculatePearlLanding(0, 70, 0, 1, 0, 0, 20.0);
    try std.testing.expect(landing.x > 0);
}

test "getPearlDamage returns 5" {
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), getPearlDamage(), 0.001);
}

test "EnderChestInventory init is empty" {
    const inv = EnderChestInventory.init();
    for (inv.items) |slot| {
        try std.testing.expect(slot.isEmpty());
    }
}

test "EnderChestInventory addItem stores items" {
    var inv = EnderChestInventory.init();
    const leftover = inv.addItem(42, 10);
    try std.testing.expectEqual(@as(u8, 0), leftover);
    try std.testing.expectEqual(@as(u16, 42), inv.items[0].item_id);
    try std.testing.expectEqual(@as(u8, 10), inv.items[0].count);
}
