/// Dispenser / dropper mechanics: maps items to one of nine dispense actions,
/// selects a random non-empty slot, applies a 4-tick cooldown, and returns the
/// action + direction so the caller can spawn the appropriate entity or effect.

const std = @import("std");

// ─────────────────────────────────────────────────────────────────────────────
// Types
// ─────────────────────────────────────────────────────────────────────────────

/// Categorises the behaviour a dispenser performs for a given item.
pub const DispenserAction = enum {
    fire_projectile,
    place_block,
    pour_liquid,
    use_item,
    drop_item,
    equip_armor,
    ignite_tnt,
    shear_entity,
    fill_bucket,
};

/// Six cardinal directions a dispenser can face.
pub const Direction = enum {
    north,
    south,
    east,
    west,
    up,
    down,

    /// Returns (dx, dy, dz) for one block in this direction.
    pub fn toOffset(self: Direction) [3]i8 {
        return switch (self) {
            .north => .{ 0, 0, -1 },
            .south => .{ 0, 0, 1 },
            .east => .{ 1, 0, 0 },
            .west => .{ -1, 0, 0 },
            .up => .{ 0, 1, 0 },
            .down => .{ 0, -1, 0 },
        };
    }
};

/// A single inventory slot: item ID + stack count.
pub const SlotState = struct {
    item_id: u16 = 0,
    count: u8 = 0,
};

/// Returned by `DispenserState.dispense` on a successful activation.
pub const DispenseResult = struct {
    action: DispenserAction,
    item_id: u16,
    direction: Direction,
    slot_index: u4,
};

// ─────────────────────────────────────────────────────────────────────────────
// Item → Action mapping
// ─────────────────────────────────────────────────────────────────────────────

/// Determines which dispenser behaviour applies to `item_id`.
pub fn getAction(item_id: u16) DispenserAction {
    return switch (item_id) {
        // Projectiles
        262, 344, 332, 385, 384 => .fire_projectile,

        // Liquids
        326, 327 => .pour_liquid,

        // TNT
        46 => .ignite_tnt,

        // Shears
        359 => .shear_entity,

        // Bone meal (dye ID 351)
        351 => .use_item,

        // Armor pieces (leather 298-301, chain 302-305, iron 306-309,
        // diamond 310-313, gold 314-317)
        298...317 => .equip_armor,

        // Empty bucket
        325 => .fill_bucket,

        // Pumpkin / jack o' lantern
        86, 91 => .place_block,

        else => .drop_item,
    };
}

// ─────────────────────────────────────────────────────────────────────────────
// Dispenser state
// ─────────────────────────────────────────────────────────────────────────────

/// Ticks a dispenser must wait between activations.
pub const DISPENSE_COOLDOWN: u8 = 4;

/// Runtime state for a single dispenser block.
pub const DispenserState = struct {
    slots: [9]SlotState = [_]SlotState{.{}} ** 9,
    facing: Direction = .north,
    cooldown: u8 = 0,

    /// Deterministically pick a random non-empty slot using `seed`.
    /// Returns `null` when every slot is empty.
    pub fn selectSlot(self: *const DispenserState, seed: u32) ?u4 {
        var non_empty_count: u8 = 0;
        for (self.slots) |slot| {
            if (slot.count > 0) non_empty_count += 1;
        }
        if (non_empty_count == 0) return null;

        // Mix the seed with a fast integer hash, then modulo by count.
        const hash: u32 = @bitCast(std.hash.int(seed));
        const pick = hash % non_empty_count;

        var seen: u8 = 0;
        for (self.slots, 0..) |slot, idx| {
            if (slot.count > 0) {
                if (seen == pick) return @intCast(idx);
                seen += 1;
            }
        }
        unreachable;
    }

    /// Attempt to dispense one item. Returns `null` if all slots are empty or
    /// the dispenser is still on cooldown.
    pub fn dispense(self: *DispenserState, seed: u32) ?DispenseResult {
        if (self.cooldown > 0) return null;

        const idx = self.selectSlot(seed) orelse return null;
        const item_id = self.slots[idx].item_id;
        const action = getAction(item_id);

        self.slots[idx].count -= 1;
        if (self.slots[idx].count == 0) {
            self.slots[idx].item_id = 0;
        }

        self.cooldown = DISPENSE_COOLDOWN;

        return .{
            .action = action,
            .item_id = item_id,
            .direction = self.facing,
            .slot_index = idx,
        };
    }

    /// Advance cooldown by one game tick.
    pub fn tick(self: *DispenserState) void {
        if (self.cooldown > 0) self.cooldown -= 1;
    }
};

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

test "getAction — fire_projectile for arrows" {
    try std.testing.expectEqual(DispenserAction.fire_projectile, getAction(262));
}

test "getAction — fire_projectile for eggs" {
    try std.testing.expectEqual(DispenserAction.fire_projectile, getAction(344));
}

test "getAction — fire_projectile for snowballs" {
    try std.testing.expectEqual(DispenserAction.fire_projectile, getAction(332));
}

test "getAction — pour_liquid for water bucket" {
    try std.testing.expectEqual(DispenserAction.pour_liquid, getAction(326));
}

test "getAction — ignite_tnt" {
    try std.testing.expectEqual(DispenserAction.ignite_tnt, getAction(46));
}

test "getAction — shear_entity" {
    try std.testing.expectEqual(DispenserAction.shear_entity, getAction(359));
}

test "getAction — use_item for bone meal" {
    try std.testing.expectEqual(DispenserAction.use_item, getAction(351));
}

test "getAction — equip_armor for all armor ids" {
    var id: u16 = 298;
    while (id <= 317) : (id += 1) {
        try std.testing.expectEqual(DispenserAction.equip_armor, getAction(id));
    }
}

test "getAction — fill_bucket" {
    try std.testing.expectEqual(DispenserAction.fill_bucket, getAction(325));
}

test "getAction — place_block for pumpkin and jack o lantern" {
    try std.testing.expectEqual(DispenserAction.place_block, getAction(86));
    try std.testing.expectEqual(DispenserAction.place_block, getAction(91));
}

test "getAction — drop_item for unknown id" {
    try std.testing.expectEqual(DispenserAction.drop_item, getAction(1));
    try std.testing.expectEqual(DispenserAction.drop_item, getAction(999));
}

test "selectSlot returns null for empty inventory" {
    const state = DispenserState{};
    try std.testing.expect(state.selectSlot(42) == null);
}

test "selectSlot returns the only non-empty slot" {
    var state = DispenserState{};
    state.slots[4] = .{ .item_id = 262, .count = 5 };
    const idx = state.selectSlot(0).?;
    try std.testing.expectEqual(@as(u4, 4), idx);
}

test "selectSlot picks among multiple non-empty slots" {
    var state = DispenserState{};
    state.slots[0] = .{ .item_id = 1, .count = 10 };
    state.slots[3] = .{ .item_id = 2, .count = 5 };
    state.slots[8] = .{ .item_id = 3, .count = 1 };

    // With three occupied slots the result must be one of {0, 3, 8}.
    var seen_slots = [_]bool{false} ** 9;
    var seed: u32 = 0;
    while (seed < 100) : (seed += 1) {
        const idx = state.selectSlot(seed).?;
        seen_slots[idx] = true;
    }
    // All three slots should be selected at least once over 100 seeds.
    try std.testing.expect(seen_slots[0]);
    try std.testing.expect(seen_slots[3]);
    try std.testing.expect(seen_slots[8]);
}

test "dispense reduces item count and returns correct action" {
    var state = DispenserState{};
    state.slots[0] = .{ .item_id = 262, .count = 3 };

    const result = state.dispense(0).?;
    try std.testing.expectEqual(DispenserAction.fire_projectile, result.action);
    try std.testing.expectEqual(@as(u16, 262), result.item_id);
    try std.testing.expectEqual(@as(u4, 0), result.slot_index);
    try std.testing.expectEqual(@as(u8, 2), state.slots[0].count);
}

test "dispense clears item_id when count reaches zero" {
    var state = DispenserState{};
    state.slots[2] = .{ .item_id = 46, .count = 1 };

    const result = state.dispense(0).?;
    try std.testing.expectEqual(DispenserAction.ignite_tnt, result.action);
    try std.testing.expectEqual(@as(u8, 0), state.slots[2].count);
    try std.testing.expectEqual(@as(u16, 0), state.slots[2].item_id);
}

test "dispense returns null when all slots empty" {
    var state = DispenserState{};
    try std.testing.expect(state.dispense(0) == null);
}

test "cooldown prevents rapid firing" {
    var state = DispenserState{};
    state.slots[0] = .{ .item_id = 344, .count = 10 };

    _ = state.dispense(0);
    try std.testing.expect(state.cooldown > 0);
    try std.testing.expect(state.dispense(1) == null);
}

test "tick decrements cooldown to zero then allows dispense" {
    var state = DispenserState{};
    state.slots[0] = .{ .item_id = 332, .count = 5 };

    _ = state.dispense(0);
    var t: u8 = 0;
    while (t < DISPENSE_COOLDOWN) : (t += 1) {
        try std.testing.expect(state.dispense(t) == null);
        state.tick();
    }
    // After full cooldown, dispense should succeed again.
    try std.testing.expect(state.dispense(99) != null);
}

test "dispense result carries facing direction" {
    var state = DispenserState{ .facing = .up };
    state.slots[0] = .{ .item_id = 86, .count = 1 };
    const result = state.dispense(0).?;
    try std.testing.expectEqual(Direction.up, result.direction);
}

test "direction offsets are correct" {
    const n = Direction.north.toOffset();
    try std.testing.expectEqual(@as(i8, 0), n[0]);
    try std.testing.expectEqual(@as(i8, 0), n[1]);
    try std.testing.expectEqual(@as(i8, -1), n[2]);

    const u = Direction.up.toOffset();
    try std.testing.expectEqual(@as(i8, 0), u[0]);
    try std.testing.expectEqual(@as(i8, 1), u[1]);
    try std.testing.expectEqual(@as(i8, 0), u[2]);

    const e = Direction.east.toOffset();
    try std.testing.expectEqual(@as(i8, 1), e[0]);
    try std.testing.expectEqual(@as(i8, 0), e[1]);
    try std.testing.expectEqual(@as(i8, 0), e[2]);

    const d = Direction.down.toOffset();
    try std.testing.expectEqual(@as(i8, 0), d[0]);
    try std.testing.expectEqual(@as(i8, -1), d[1]);
    try std.testing.expectEqual(@as(i8, 0), d[2]);

    const s = Direction.south.toOffset();
    try std.testing.expectEqual(@as(i8, 0), s[0]);
    try std.testing.expectEqual(@as(i8, 0), s[1]);
    try std.testing.expectEqual(@as(i8, 1), s[2]);

    const w = Direction.west.toOffset();
    try std.testing.expectEqual(@as(i8, -1), w[0]);
    try std.testing.expectEqual(@as(i8, 0), w[1]);
    try std.testing.expectEqual(@as(i8, 0), w[2]);
}
