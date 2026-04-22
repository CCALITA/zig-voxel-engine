const std = @import("std");

pub const Slot = struct {
    item: u16,
    count: u8,

    pub const empty = Slot{ .item = 0, .count = 0 };

    pub fn isEmpty(self: Slot) bool {
        return self.count == 0;
    }
};

pub const ArmorSlotType = enum(u2) {
    helmet,
    chestplate,
    leggings,
    boots,
};

/// Defense values per tier per slot: [tier][slot]
/// Tiers: leather, iron, gold, diamond, netherite
/// Slots: helmet, chestplate, leggings, boots
pub const DEFENSE = [5][4]u8{
    .{ 1, 3, 2, 1 }, // leather
    .{ 2, 6, 5, 2 }, // iron
    .{ 2, 5, 3, 1 }, // gold
    .{ 3, 8, 6, 3 }, // diamond
    .{ 3, 8, 6, 3 }, // netherite
};

// Armor item IDs arranged as [tier][slot]:
//   Helmet IDs:     282, 286, 290, 294, 298
//   Chestplate IDs: 283, 287, 291, 295, 299
//   Leggings IDs:   284, 288, 292, 296, 300
//   Boots IDs:      285, 289, 293, 297, 301
const armor_base_ids = [5]u16{ 282, 286, 290, 294, 298 };

pub const ArmorEquipState = struct {
    slots: [4]Slot = [_]Slot{Slot.empty} ** 4,

    pub fn init() ArmorEquipState {
        return .{};
    }

    pub fn getSlot(self: *const ArmorEquipState, slot_type: ArmorSlotType) Slot {
        return self.slots[@intFromEnum(slot_type)];
    }

    /// Auto-detect armor slot from item ID. Equip the item and return the
    /// displaced item, or null if the slot was empty.
    pub fn equipItem(self: *ArmorEquipState, item: Slot) ?Slot {
        const slot_type = getArmorSlotForItem(item.item) orelse return null;
        const idx = @intFromEnum(slot_type);
        const old = self.slots[idx];
        self.slots[idx] = item;
        if (old.isEmpty()) return null;
        return old;
    }

    /// Swap cursor with armor slot. Only allow valid armor for that slot type.
    /// If the cursor holds a non-matching armor piece, return it unchanged.
    pub fn clickSlot(self: *ArmorEquipState, slot_type: ArmorSlotType, cursor: Slot) Slot {
        const idx = @intFromEnum(slot_type);
        if (cursor.isEmpty()) {
            // Pick up whatever is in the slot.
            const old = self.slots[idx];
            self.slots[idx] = Slot.empty;
            return old;
        }
        // Cursor has an item -- validate it belongs in this slot.
        const item_slot = getArmorSlotForItem(cursor.item) orelse return cursor;
        if (item_slot != slot_type) return cursor;
        const old = self.slots[idx];
        self.slots[idx] = cursor;
        return old;
    }

    /// Remove and return the item in the given slot. Slot becomes empty.
    pub fn unequipSlot(self: *ArmorEquipState, slot_type: ArmorSlotType) Slot {
        const idx = @intFromEnum(slot_type);
        const old = self.slots[idx];
        self.slots[idx] = Slot.empty;
        return old;
    }

    /// Sum defense values across all equipped pieces.
    pub fn getTotalDefense(self: *const ArmorEquipState) u8 {
        var total: u8 = 0;
        for (self.slots, 0..) |slot, i| {
            if (slot.isEmpty()) continue;
            if (classifyArmor(slot.item)) |info| {
                const tier = info.tier;
                total += DEFENSE[tier][i];
            }
        }
        return total;
    }

    /// Returns which slot an armor item belongs to, or null if not armor.
    pub fn getArmorSlotForItem(item_id: u16) ?ArmorSlotType {
        const info = classifyArmor(item_id) orelse return null;
        return info.slot;
    }

    /// Returns true if the item ID corresponds to any armor piece.
    pub fn isArmorItem(item_id: u16) bool {
        return classifyArmor(item_id) != null;
    }
};

const ArmorClassification = struct {
    tier: usize,
    slot: ArmorSlotType,
};

/// Single lookup that returns both tier and slot for an armor item ID.
fn classifyArmor(item_id: u16) ?ArmorClassification {
    for (armor_base_ids, 0..) |base, tier| {
        if (item_id >= base and item_id < base + 4) {
            const offset: u2 = @intCast(item_id - base);
            return .{ .tier = tier, .slot = @enumFromInt(offset) };
        }
    }
    return null;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "init creates empty slots" {
    const state = ArmorEquipState.init();
    for (state.slots) |slot| {
        try std.testing.expect(slot.isEmpty());
    }
}

test "equipItem places helmet and returns null for empty slot" {
    var state = ArmorEquipState.init();
    const helmet = Slot{ .item = 282, .count = 1 }; // leather helmet
    const displaced = state.equipItem(helmet);
    try std.testing.expect(displaced == null);
    try std.testing.expectEqual(@as(u16, 282), state.getSlot(.helmet).item);
}

test "equipItem displaces existing armor" {
    var state = ArmorEquipState.init();
    const leather_helm = Slot{ .item = 282, .count = 1 };
    const iron_helm = Slot{ .item = 286, .count = 1 };
    _ = state.equipItem(leather_helm);
    const displaced = state.equipItem(iron_helm);
    try std.testing.expect(displaced != null);
    try std.testing.expectEqual(@as(u16, 282), displaced.?.item);
    try std.testing.expectEqual(@as(u16, 286), state.getSlot(.helmet).item);
}

test "equipItem rejects non-armor item" {
    var state = ArmorEquipState.init();
    const not_armor = Slot{ .item = 100, .count = 1 };
    const result = state.equipItem(not_armor);
    try std.testing.expect(result == null);
    try std.testing.expect(state.getSlot(.helmet).isEmpty());
}

test "clickSlot swaps cursor with slot" {
    var state = ArmorEquipState.init();
    const boots = Slot{ .item = 285, .count = 1 }; // leather boots
    const returned = state.clickSlot(.boots, boots);
    try std.testing.expect(returned.isEmpty());
    try std.testing.expectEqual(@as(u16, 285), state.getSlot(.boots).item);
}

test "clickSlot rejects wrong slot type" {
    var state = ArmorEquipState.init();
    const helmet = Slot{ .item = 282, .count = 1 }; // leather helmet
    const returned = state.clickSlot(.boots, helmet); // wrong slot
    try std.testing.expectEqual(@as(u16, 282), returned.item);
    try std.testing.expect(state.getSlot(.boots).isEmpty());
}

test "clickSlot with empty cursor picks up item" {
    var state = ArmorEquipState.init();
    const chestplate = Slot{ .item = 283, .count = 1 };
    _ = state.equipItem(chestplate);
    const picked = state.clickSlot(.chestplate, Slot.empty);
    try std.testing.expectEqual(@as(u16, 283), picked.item);
    try std.testing.expect(state.getSlot(.chestplate).isEmpty());
}

test "unequipSlot removes and returns item" {
    var state = ArmorEquipState.init();
    const leggings = Slot{ .item = 284, .count = 1 };
    _ = state.equipItem(leggings);
    const removed = state.unequipSlot(.leggings);
    try std.testing.expectEqual(@as(u16, 284), removed.item);
    try std.testing.expect(state.getSlot(.leggings).isEmpty());
}

test "unequipSlot on empty slot returns empty" {
    var state = ArmorEquipState.init();
    const removed = state.unequipSlot(.helmet);
    try std.testing.expect(removed.isEmpty());
}

test "getTotalDefense with full diamond set" {
    var state = ArmorEquipState.init();
    _ = state.equipItem(Slot{ .item = 294, .count = 1 }); // diamond helmet
    _ = state.equipItem(Slot{ .item = 295, .count = 1 }); // diamond chestplate
    _ = state.equipItem(Slot{ .item = 296, .count = 1 }); // diamond leggings
    _ = state.equipItem(Slot{ .item = 297, .count = 1 }); // diamond boots
    // 3 + 8 + 6 + 3 = 20
    try std.testing.expectEqual(@as(u8, 20), state.getTotalDefense());
}

test "getTotalDefense with full leather set" {
    var state = ArmorEquipState.init();
    _ = state.equipItem(Slot{ .item = 282, .count = 1 }); // leather helmet
    _ = state.equipItem(Slot{ .item = 283, .count = 1 }); // leather chestplate
    _ = state.equipItem(Slot{ .item = 284, .count = 1 }); // leather leggings
    _ = state.equipItem(Slot{ .item = 285, .count = 1 }); // leather boots
    // 1 + 3 + 2 + 1 = 7
    try std.testing.expectEqual(@as(u8, 7), state.getTotalDefense());
}

test "getTotalDefense with empty inventory is zero" {
    const state = ArmorEquipState.init();
    try std.testing.expectEqual(@as(u8, 0), state.getTotalDefense());
}

test "isArmorItem identifies armor and non-armor" {
    // All five tiers of helmets
    try std.testing.expect(ArmorEquipState.isArmorItem(282));
    try std.testing.expect(ArmorEquipState.isArmorItem(286));
    try std.testing.expect(ArmorEquipState.isArmorItem(290));
    try std.testing.expect(ArmorEquipState.isArmorItem(294));
    try std.testing.expect(ArmorEquipState.isArmorItem(298));
    // Boots
    try std.testing.expect(ArmorEquipState.isArmorItem(301)); // netherite boots
    // Non-armor
    try std.testing.expect(!ArmorEquipState.isArmorItem(0));
    try std.testing.expect(!ArmorEquipState.isArmorItem(100));
    try std.testing.expect(!ArmorEquipState.isArmorItem(281));
    try std.testing.expect(!ArmorEquipState.isArmorItem(302));
}

test "getArmorSlotForItem returns correct slot types" {
    // Chestplate IDs across tiers: 283, 287, 291, 295, 299
    try std.testing.expectEqual(ArmorSlotType.chestplate, ArmorEquipState.getArmorSlotForItem(283).?);
    try std.testing.expectEqual(ArmorSlotType.chestplate, ArmorEquipState.getArmorSlotForItem(287).?);
    try std.testing.expectEqual(ArmorSlotType.chestplate, ArmorEquipState.getArmorSlotForItem(291).?);
    try std.testing.expectEqual(ArmorSlotType.chestplate, ArmorEquipState.getArmorSlotForItem(295).?);
    try std.testing.expectEqual(ArmorSlotType.chestplate, ArmorEquipState.getArmorSlotForItem(299).?);
    // Leggings
    try std.testing.expectEqual(ArmorSlotType.leggings, ArmorEquipState.getArmorSlotForItem(300).?);
    // Non-armor returns null
    try std.testing.expect(ArmorEquipState.getArmorSlotForItem(50) == null);
}

test "mixed armor set defense" {
    var state = ArmorEquipState.init();
    _ = state.equipItem(Slot{ .item = 294, .count = 1 }); // diamond helmet (3)
    _ = state.equipItem(Slot{ .item = 287, .count = 1 }); // iron chestplate (6)
    _ = state.equipItem(Slot{ .item = 292, .count = 1 }); // gold leggings (3)
    _ = state.equipItem(Slot{ .item = 285, .count = 1 }); // leather boots (1)
    // 3 + 6 + 3 + 1 = 13
    try std.testing.expectEqual(@as(u8, 13), state.getTotalDefense());
}

test "clickSlot rejects non-armor cursor" {
    var state = ArmorEquipState.init();
    const non_armor = Slot{ .item = 50, .count = 1 };
    const returned = state.clickSlot(.helmet, non_armor);
    try std.testing.expectEqual(@as(u16, 50), returned.item);
    try std.testing.expect(state.getSlot(.helmet).isEmpty());
}
