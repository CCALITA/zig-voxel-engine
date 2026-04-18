/// Redstone automation blocks: Hopper, Dropper, and Dispenser.
/// Each has a 9-slot inventory and directional facing.
/// Hoppers transfer items on a cooldown, Droppers eject items randomly,
/// and Dispensers apply special behaviors depending on item type.

const std = @import("std");

// ──────────────────────────────────────────────────────────────────────────────
// Shared types
// ──────────────────────────────────────────────────────────────────────────────

pub const ItemId = u16;
pub const SLOT_COUNT: u8 = 9;
pub const STACK_MAX: u8 = 64;

pub const Direction = enum {
    north,
    south,
    east,
    west,
    down,
};

pub const Slot = struct {
    item: ItemId,
    count: u8,

    pub const empty = Slot{ .item = 0, .count = 0 };

    pub fn isEmpty(self: Slot) bool {
        return self.count == 0;
    }
};

pub const Inventory9 = [SLOT_COUNT]Slot;

pub fn emptyInventory() Inventory9 {
    return [_]Slot{Slot.empty} ** SLOT_COUNT;
}

/// Remove one item from `slot`, clearing it if the count reaches zero.
fn decrementSlot(slot: *Slot) void {
    slot.count -= 1;
    if (slot.count == 0) slot.* = Slot.empty;
}

/// Pick a random non-empty slot from `inv` using `seed` for deterministic selection.
/// Returns the slot index, or null if the inventory is empty.
fn pickOccupiedSlot(inv: *const Inventory9, seed: u64) ?u8 {
    var occupied: [SLOT_COUNT]u8 = undefined;
    var count: u8 = 0;
    for (inv.*, 0..) |slot, i| {
        if (!slot.isEmpty()) {
            occupied[count] = @intCast(i);
            count += 1;
        }
    }
    if (count == 0) return null;
    return occupied[@intCast(seed % count)];
}

/// Transfer one item from the first non-empty slot in `from` to `to`.
/// Stacks onto existing matching slots first, then fills empty slots.
/// Returns true if an item was transferred.
pub fn transferItem(from: *Inventory9, to: *Inventory9) bool {
    // Find the first non-empty source slot.
    var src_idx: ?u8 = null;
    for (from, 0..) |slot, i| {
        if (!slot.isEmpty()) {
            src_idx = @intCast(i);
            break;
        }
    }
    const idx = src_idx orelse return false;
    const item = from[idx].item;

    // Try to stack onto an existing matching slot in the destination.
    for (to) |*dst| {
        if (dst.item == item and dst.count > 0 and dst.count < STACK_MAX) {
            dst.count += 1;
            decrementSlot(&from[idx]);
            return true;
        }
    }

    // Try to place into an empty destination slot.
    for (to) |*dst| {
        if (dst.isEmpty()) {
            dst.item = item;
            dst.count = 1;
            decrementSlot(&from[idx]);
            return true;
        }
    }

    return false;
}

// ──────────────────────────────────────────────────────────────────────────────
// Hopper
// ──────────────────────────────────────────────────────────────────────────────

pub const HOPPER_COOLDOWN: u8 = 8; // game ticks (0.4 s at 20 tps)

pub const TransferEvent = struct {
    item: ItemId,
    count: u8,
    direction: Direction,
};

pub const HopperState = struct {
    inventory: Inventory9,
    facing: Direction,
    cooldown_timer: u8,

    pub fn init(facing: Direction) HopperState {
        return .{
            .inventory = emptyInventory(),
            .facing = facing,
            .cooldown_timer = 0,
        };
    }

    /// Pull one item from `above` inventory into this hopper's inventory.
    pub fn pullFromAbove(self: *HopperState, above: *Inventory9) bool {
        return transferItem(above, &self.inventory);
    }

    /// Push one item from this hopper's inventory into the `target` inventory.
    pub fn pushToFacing(self: *HopperState, target: *Inventory9) bool {
        return transferItem(&self.inventory, target);
    }

    /// Advance the hopper by one game tick.
    /// Returns a TransferEvent when a cooldown cycle completes and a transfer
    /// could logically occur (caller provides neighboring inventories externally).
    pub fn update(self: *HopperState, dt: u8) ?TransferEvent {
        if (self.cooldown_timer >= dt) {
            self.cooldown_timer -= dt;
            return null;
        }

        self.cooldown_timer = 0;

        // Check whether there is something to transfer.
        for (self.inventory) |slot| {
            if (!slot.isEmpty()) {
                self.cooldown_timer = HOPPER_COOLDOWN;
                return .{
                    .item = slot.item,
                    .count = 1,
                    .direction = self.facing,
                };
            }
        }

        return null;
    }
};

// ──────────────────────────────────────────────────────────────────────────────
// Dropper
// ──────────────────────────────────────────────────────────────────────────────

pub const ItemDrop = struct {
    item: ItemId,
    count: u8,
    direction: Direction,
    velocity: f32,
};

const DROP_VELOCITY: f32 = 2.0;

pub const DropperState = struct {
    inventory: Inventory9,
    facing: Direction,

    pub fn init(facing: Direction) DropperState {
        return .{
            .inventory = emptyInventory(),
            .facing = facing,
        };
    }

    /// When powered, pick a random non-empty slot and eject one item.
    /// `tick_seed` provides deterministic randomness based on the game tick.
    pub fn dropItem(self: *DropperState, tick_seed: u64) ?ItemDrop {
        const chosen_idx = pickOccupiedSlot(&self.inventory, tick_seed) orelse return null;
        const slot = &self.inventory[chosen_idx];
        const item = slot.item;
        decrementSlot(slot);

        return .{
            .item = item,
            .count = 1,
            .direction = self.facing,
            .velocity = DROP_VELOCITY,
        };
    }
};

// ──────────────────────────────────────────────────────────────────────────────
// Dispenser
// ──────────────────────────────────────────────────────────────────────────────

/// Well-known item IDs for special dispenser behaviors.
/// These are outside the block ID range (>255) to avoid collision.
pub const Items = struct {
    pub const arrow: ItemId = 256;
    pub const water_bucket: ItemId = 257;
    pub const lava_bucket: ItemId = 258;
    pub const tnt: ItemId = 259;
    pub const fire_charge: ItemId = 260;
    pub const bone_meal: ItemId = 261;
};

pub const DispenseAction = enum {
    shoot_arrow,
    place_water,
    place_lava,
    ignite_tnt,
    ignite_block,
    grow_crop,
    drop_item,
};

pub const DispenseResult = struct {
    action: DispenseAction,
    item: ItemId,
    direction: Direction,
};

pub const DispenserState = struct {
    inventory: Inventory9,
    facing: Direction,

    pub fn init(facing: Direction) DispenserState {
        return .{
            .inventory = emptyInventory(),
            .facing = facing,
        };
    }

    /// When powered, pick a random non-empty slot and dispense the item.
    /// Special items trigger unique behaviors; everything else drops like a dropper.
    pub fn dispenseItem(self: *DispenserState, tick_seed: u64) ?DispenseResult {
        const chosen_idx = pickOccupiedSlot(&self.inventory, tick_seed) orelse return null;
        const slot = &self.inventory[chosen_idx];
        const item = slot.item;
        decrementSlot(slot);

        const action: DispenseAction = switch (item) {
            Items.arrow => .shoot_arrow,
            Items.water_bucket => .place_water,
            Items.lava_bucket => .place_lava,
            Items.tnt => .ignite_tnt,
            Items.fire_charge => .ignite_block,
            Items.bone_meal => .grow_crop,
            else => .drop_item,
        };

        return .{
            .action = action,
            .item = item,
            .direction = self.facing,
        };
    }
};

// ──────────────────────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────────────────────

test "transferItem moves one item between inventories" {
    var src = emptyInventory();
    var dst = emptyInventory();
    src[0] = .{ .item = 1, .count = 10 };

    const ok = transferItem(&src, &dst);
    try std.testing.expect(ok);
    try std.testing.expectEqual(@as(u8, 9), src[0].count);
    try std.testing.expectEqual(@as(ItemId, 1), dst[0].item);
    try std.testing.expectEqual(@as(u8, 1), dst[0].count);
}

test "transferItem stacks onto matching destination slot" {
    var src = emptyInventory();
    var dst = emptyInventory();
    src[0] = .{ .item = 5, .count = 3 };
    dst[0] = .{ .item = 5, .count = 60 };

    const ok = transferItem(&src, &dst);
    try std.testing.expect(ok);
    try std.testing.expectEqual(@as(u8, 61), dst[0].count);
    try std.testing.expectEqual(@as(u8, 2), src[0].count);
}

test "transferItem fails when source is empty" {
    var src = emptyInventory();
    var dst = emptyInventory();

    const ok = transferItem(&src, &dst);
    try std.testing.expect(!ok);
}

test "transferItem fails when destination is full" {
    var src = emptyInventory();
    var dst = emptyInventory();
    src[0] = .{ .item = 1, .count = 5 };

    // Fill all destination slots with a different item at max stack.
    for (&dst) |*slot| {
        slot.* = .{ .item = 2, .count = STACK_MAX };
    }

    const ok = transferItem(&src, &dst);
    try std.testing.expect(!ok);
    try std.testing.expectEqual(@as(u8, 5), src[0].count);
}

test "transferItem clears source slot when last item moved" {
    var src = emptyInventory();
    var dst = emptyInventory();
    src[0] = .{ .item = 7, .count = 1 };

    const ok = transferItem(&src, &dst);
    try std.testing.expect(ok);
    try std.testing.expect(src[0].isEmpty());
    try std.testing.expectEqual(@as(ItemId, 7), dst[0].item);
}

// --- Hopper tests ---

test "hopper init has empty inventory and zero cooldown" {
    const h = HopperState.init(.south);
    try std.testing.expectEqual(Direction.south, h.facing);
    try std.testing.expectEqual(@as(u8, 0), h.cooldown_timer);
    for (h.inventory) |slot| {
        try std.testing.expect(slot.isEmpty());
    }
}

test "hopper pullFromAbove transfers item" {
    var h = HopperState.init(.down);
    var above = emptyInventory();
    above[0] = .{ .item = 3, .count = 10 };

    const ok = h.pullFromAbove(&above);
    try std.testing.expect(ok);
    try std.testing.expectEqual(@as(u8, 9), above[0].count);
    try std.testing.expectEqual(@as(ItemId, 3), h.inventory[0].item);
    try std.testing.expectEqual(@as(u8, 1), h.inventory[0].count);
}

test "hopper pushToFacing transfers item" {
    var h = HopperState.init(.north);
    h.inventory[0] = .{ .item = 8, .count = 5 };
    var target = emptyInventory();

    const ok = h.pushToFacing(&target);
    try std.testing.expect(ok);
    try std.testing.expectEqual(@as(u8, 4), h.inventory[0].count);
    try std.testing.expectEqual(@as(ItemId, 8), target[0].item);
}

test "hopper update returns event when items present" {
    var h = HopperState.init(.east);
    h.inventory[0] = .{ .item = 12, .count = 3 };

    const event = h.update(1);
    try std.testing.expect(event != null);
    try std.testing.expectEqual(@as(ItemId, 12), event.?.item);
    try std.testing.expectEqual(@as(u8, 1), event.?.count);
    try std.testing.expectEqual(Direction.east, event.?.direction);
}

test "hopper cooldown prevents immediate second transfer" {
    var h = HopperState.init(.west);
    h.inventory[0] = .{ .item = 1, .count = 10 };

    // First update triggers transfer and sets cooldown.
    const first = h.update(1);
    try std.testing.expect(first != null);
    try std.testing.expectEqual(HOPPER_COOLDOWN, h.cooldown_timer);

    // Next update within cooldown should produce no event.
    const second = h.update(1);
    try std.testing.expect(second == null);

    // After enough ticks, cooldown expires and transfer fires again.
    const third = h.update(HOPPER_COOLDOWN);
    try std.testing.expect(third != null);
}

test "hopper update returns null when empty" {
    var h = HopperState.init(.down);
    const event = h.update(1);
    try std.testing.expect(event == null);
}

// --- Dropper tests ---

test "dropper init has empty inventory" {
    const d = DropperState.init(.north);
    try std.testing.expectEqual(Direction.north, d.facing);
    for (d.inventory) |slot| {
        try std.testing.expect(slot.isEmpty());
    }
}

test "dropper dropItem picks random non-empty slot" {
    var d = DropperState.init(.south);
    d.inventory[3] = .{ .item = 42, .count = 5 };
    d.inventory[7] = .{ .item = 99, .count = 1 };

    // seed=0 -> index 0 of occupied -> slot 3 (item 42)
    const drop0 = d.dropItem(0);
    try std.testing.expect(drop0 != null);
    try std.testing.expectEqual(@as(ItemId, 42), drop0.?.item);
    try std.testing.expectEqual(@as(u8, 1), drop0.?.count);
    try std.testing.expectEqual(Direction.south, drop0.?.direction);
    try std.testing.expectEqual(@as(u8, 4), d.inventory[3].count);

    // seed=1 -> index 1 of occupied -> slot 7 (item 99)
    const drop1 = d.dropItem(1);
    try std.testing.expect(drop1 != null);
    try std.testing.expectEqual(@as(ItemId, 99), drop1.?.item);
    // slot 7 had count 1, should now be empty
    try std.testing.expect(d.inventory[7].isEmpty());
}

test "dropper dropItem returns null when empty" {
    var d = DropperState.init(.east);
    const drop = d.dropItem(42);
    try std.testing.expect(drop == null);
}

test "dropper dropItem decrements count" {
    var d = DropperState.init(.west);
    d.inventory[0] = .{ .item = 10, .count = 3 };

    _ = d.dropItem(0);
    try std.testing.expectEqual(@as(u8, 2), d.inventory[0].count);
    _ = d.dropItem(0);
    try std.testing.expectEqual(@as(u8, 1), d.inventory[0].count);
    _ = d.dropItem(0);
    try std.testing.expect(d.inventory[0].isEmpty());
}

// --- Dispenser tests ---

test "dispenser init has empty inventory" {
    const disp = DispenserState.init(.north);
    try std.testing.expectEqual(Direction.north, disp.facing);
    for (disp.inventory) |slot| {
        try std.testing.expect(slot.isEmpty());
    }
}

test "dispenser arrow triggers shoot_arrow" {
    var disp = DispenserState.init(.south);
    disp.inventory[0] = .{ .item = Items.arrow, .count = 10 };

    const result = disp.dispenseItem(0);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(DispenseAction.shoot_arrow, result.?.action);
    try std.testing.expectEqual(Items.arrow, result.?.item);
    try std.testing.expectEqual(Direction.south, result.?.direction);
    try std.testing.expectEqual(@as(u8, 9), disp.inventory[0].count);
}

test "dispenser water_bucket triggers place_water" {
    var disp = DispenserState.init(.east);
    disp.inventory[0] = .{ .item = Items.water_bucket, .count = 1 };

    const result = disp.dispenseItem(0);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(DispenseAction.place_water, result.?.action);
    try std.testing.expect(disp.inventory[0].isEmpty());
}

test "dispenser lava_bucket triggers place_lava" {
    var disp = DispenserState.init(.north);
    disp.inventory[0] = .{ .item = Items.lava_bucket, .count = 1 };

    const result = disp.dispenseItem(0);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(DispenseAction.place_lava, result.?.action);
}

test "dispenser tnt triggers ignite_tnt" {
    var disp = DispenserState.init(.west);
    disp.inventory[0] = .{ .item = Items.tnt, .count = 2 };

    const result = disp.dispenseItem(0);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(DispenseAction.ignite_tnt, result.?.action);
    try std.testing.expectEqual(@as(u8, 1), disp.inventory[0].count);
}

test "dispenser fire_charge triggers ignite_block" {
    var disp = DispenserState.init(.south);
    disp.inventory[0] = .{ .item = Items.fire_charge, .count = 1 };

    const result = disp.dispenseItem(0);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(DispenseAction.ignite_block, result.?.action);
}

test "dispenser bone_meal triggers grow_crop" {
    var disp = DispenserState.init(.down);
    disp.inventory[0] = .{ .item = Items.bone_meal, .count = 5 };

    const result = disp.dispenseItem(0);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(DispenseAction.grow_crop, result.?.action);
    try std.testing.expectEqual(@as(u8, 4), disp.inventory[0].count);
}

test "dispenser unknown item triggers drop_item" {
    var disp = DispenserState.init(.north);
    disp.inventory[0] = .{ .item = 999, .count = 1 };

    const result = disp.dispenseItem(0);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(DispenseAction.drop_item, result.?.action);
}

test "dispenser returns null when empty" {
    var disp = DispenserState.init(.east);
    const result = disp.dispenseItem(0);
    try std.testing.expect(result == null);
}

test "dispenser decrements count and clears slot" {
    var disp = DispenserState.init(.south);
    disp.inventory[0] = .{ .item = Items.arrow, .count = 1 };

    const result = disp.dispenseItem(0);
    try std.testing.expect(result != null);
    try std.testing.expect(disp.inventory[0].isEmpty());
}
