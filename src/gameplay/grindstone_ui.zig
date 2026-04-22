/// Grindstone UI for disenchanting items and combining durability.
/// Manages input, sacrifice, and output slots with XP reward calculation.
/// Follows Minecraft grindstone mechanics: strip enchantments for XP,
/// combine same-type items to repair durability.

const std = @import("std");

const STACK_MAX: u8 = 64;
const DURABILITY_BONUS_PERCENT: u8 = 5;

pub const Slot = struct {
    item: u16,
    count: u8,

    pub const empty = Slot{ .item = 0, .count = 0 };

    pub fn isEmpty(self: Slot) bool {
        return self.count == 0;
    }
};

/// Enchantment level stored per item. Higher values yield more XP on disenchant.
/// In a full implementation this would reference the enchanting module; here we
/// use a simple u8 to keep the grindstone self-contained.
pub const EnchantLevel = u8;

pub const GrindstoneUI = struct {
    input_slot: Slot = Slot.empty,
    sacrifice_slot: Slot = Slot.empty,
    output_slot: Slot = Slot.empty,
    xp_reward: u8 = 0,

    /// Enchantment levels attached to input and sacrifice items.
    /// These simulate the enchantment data that would normally live
    /// on the item entity.
    input_enchant: EnchantLevel = 0,
    sacrifice_enchant: EnchantLevel = 0,

    pub fn init() GrindstoneUI {
        return .{};
    }

    /// Click a slot (0 = input, 1 = sacrifice, 2 = output).
    /// Swaps cursor with the clicked slot. Recalculates output after
    /// any change to input or sacrifice.
    pub fn clickSlot(self: *GrindstoneUI, slot_idx: u8, cursor: Slot) Slot {
        if (slot_idx <= 1) {
            const slot_ptr = self.inputSlotPtr(slot_idx);
            const prev = slot_ptr.*;
            slot_ptr.* = cursor;
            self.recalculate();
            return prev;
        }
        if (slot_idx == 2) {
            // Output is take-only; placing items is rejected.
            if (cursor.isEmpty()) {
                if (self.takeOutput()) |result| {
                    return result.slot;
                }
            }
            return cursor;
        }
        return cursor;
    }

    fn inputSlotPtr(self: *GrindstoneUI, idx: u8) *Slot {
        return if (idx == 0) &self.input_slot else &self.sacrifice_slot;
    }

    /// Recalculate the output slot and XP reward based on current inputs.
    ///
    /// Rules:
    /// - Input only: strip enchantments, output = same item, xp = levels * 2
    /// - Sacrifice only: treat sacrifice as input (same rule)
    /// - Input + sacrifice (same type): combine durability (add + 5% bonus),
    ///   strip enchants from both, xp = total enchant levels * 2
    /// - Input + sacrifice (different type): no valid output
    pub fn recalculate(self: *GrindstoneUI) void {
        self.output_slot = Slot.empty;
        self.xp_reward = 0;

        const has_input = !self.input_slot.isEmpty();
        const has_sacrifice = !self.sacrifice_slot.isEmpty();

        if (!has_input and !has_sacrifice) return;

        if (has_input and has_sacrifice) {
            // Both slots occupied -- must be same item type to combine
            if (self.input_slot.item != self.sacrifice_slot.item) return;

            const combined_raw = @as(u16, self.input_slot.count) + @as(u16, self.sacrifice_slot.count);
            const bonus = @max(1, combined_raw * DURABILITY_BONUS_PERCENT / 100);
            const combined = @min(@as(u16, STACK_MAX), combined_raw + bonus);
            self.output_slot = Slot{
                .item = self.input_slot.item,
                .count = @intCast(combined),
            };
            const total_levels = @as(u16, self.input_enchant) + @as(u16, self.sacrifice_enchant);
            self.xp_reward = @intCast(@min(255, total_levels * 2));
        } else if (has_input) {
            // Input only -- disenchant
            self.output_slot = Slot{ .item = self.input_slot.item, .count = self.input_slot.count };
            self.xp_reward = self.input_enchant * 2;
        } else {
            // Sacrifice only -- treat as input
            self.output_slot = Slot{ .item = self.sacrifice_slot.item, .count = self.sacrifice_slot.count };
            self.xp_reward = self.sacrifice_enchant * 2;
        }
    }

    /// Take the output item and collect the XP reward.
    /// Clears input and sacrifice slots on success.
    /// Returns null if the output slot is empty.
    pub fn takeOutput(self: *GrindstoneUI) ?struct { slot: Slot, xp: u8 } {
        if (self.output_slot.isEmpty()) return null;

        const out = self.output_slot;
        const xp = self.xp_reward;
        self.* = GrindstoneUI.init();
        return .{ .slot = out, .xp = xp };
    }

    /// Close the UI, returning input and sacrifice items to the player inventory.
    /// Output is discarded (player must take it before closing).
    pub fn close(self: *GrindstoneUI, inv_slots: []Slot) void {
        const slots_to_return = [_]Slot{ self.input_slot, self.sacrifice_slot };
        for (slots_to_return) |slot| {
            if (slot.isEmpty()) continue;
            for (inv_slots) |*inv_slot| {
                if (inv_slot.isEmpty()) {
                    inv_slot.* = slot;
                    break;
                }
            }
        }
        self.* = GrindstoneUI.init();
    }
};

// ── Tests ────────────────────────────────────────────────────────────────────

test "init returns empty state" {
    const ui = GrindstoneUI.init();
    try std.testing.expect(ui.input_slot.isEmpty());
    try std.testing.expect(ui.sacrifice_slot.isEmpty());
    try std.testing.expect(ui.output_slot.isEmpty());
    try std.testing.expectEqual(@as(u8, 0), ui.xp_reward);
}

test "disenchant input gives XP" {
    var ui = GrindstoneUI.init();
    ui.input_slot = Slot{ .item = 100, .count = 1 };
    ui.input_enchant = 5;
    ui.recalculate();
    try std.testing.expect(!ui.output_slot.isEmpty());
    try std.testing.expectEqual(@as(u16, 100), ui.output_slot.item);
    try std.testing.expectEqual(@as(u8, 10), ui.xp_reward); // 5 * 2
}

test "disenchant sacrifice-only gives XP" {
    var ui = GrindstoneUI.init();
    ui.sacrifice_slot = Slot{ .item = 200, .count = 1 };
    ui.sacrifice_enchant = 3;
    ui.recalculate();
    try std.testing.expect(!ui.output_slot.isEmpty());
    try std.testing.expectEqual(@as(u16, 200), ui.output_slot.item);
    try std.testing.expectEqual(@as(u8, 6), ui.xp_reward); // 3 * 2
}

test "combine same-type items repairs durability with 5% bonus" {
    var ui = GrindstoneUI.init();
    ui.input_slot = Slot{ .item = 50, .count = 30 };
    ui.sacrifice_slot = Slot{ .item = 50, .count = 20 };
    ui.recalculate();
    // 30 + 20 = 50, bonus = max(1, 50*5/100) = 2, total = 52
    try std.testing.expectEqual(@as(u8, 52), ui.output_slot.count);
    try std.testing.expectEqual(@as(u16, 50), ui.output_slot.item);
}

test "combine caps at STACK_MAX" {
    var ui = GrindstoneUI.init();
    ui.input_slot = Slot{ .item = 50, .count = 60 };
    ui.sacrifice_slot = Slot{ .item = 50, .count = 60 };
    ui.recalculate();
    try std.testing.expectEqual(STACK_MAX, ui.output_slot.count);
}

test "combine with enchantments yields XP from both" {
    var ui = GrindstoneUI.init();
    ui.input_slot = Slot{ .item = 50, .count = 10 };
    ui.sacrifice_slot = Slot{ .item = 50, .count = 10 };
    ui.input_enchant = 4;
    ui.sacrifice_enchant = 3;
    ui.recalculate();
    try std.testing.expectEqual(@as(u8, 14), ui.xp_reward); // (4+3) * 2
}

test "different item types produce no output" {
    var ui = GrindstoneUI.init();
    ui.input_slot = Slot{ .item = 50, .count = 10 };
    ui.sacrifice_slot = Slot{ .item = 99, .count = 10 };
    ui.recalculate();
    try std.testing.expect(ui.output_slot.isEmpty());
    try std.testing.expectEqual(@as(u8, 0), ui.xp_reward);
}

test "takeOutput clears all slots and returns result" {
    var ui = GrindstoneUI.init();
    ui.input_slot = Slot{ .item = 100, .count = 1 };
    ui.input_enchant = 2;
    ui.recalculate();
    const result = ui.takeOutput();
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(u16, 100), result.?.slot.item);
    try std.testing.expectEqual(@as(u8, 4), result.?.xp); // 2 * 2
    try std.testing.expect(ui.input_slot.isEmpty());
    try std.testing.expect(ui.sacrifice_slot.isEmpty());
    try std.testing.expect(ui.output_slot.isEmpty());
}

test "takeOutput returns null when output is empty" {
    var ui = GrindstoneUI.init();
    try std.testing.expect(ui.takeOutput() == null);
}

test "clickSlot swaps cursor with input" {
    var ui = GrindstoneUI.init();
    const returned = ui.clickSlot(0, Slot{ .item = 10, .count = 5 });
    try std.testing.expect(returned.isEmpty());
    try std.testing.expectEqual(@as(u16, 10), ui.input_slot.item);
}

test "clickSlot swaps cursor with sacrifice" {
    var ui = GrindstoneUI.init();
    const returned = ui.clickSlot(1, Slot{ .item = 20, .count = 3 });
    try std.testing.expect(returned.isEmpty());
    try std.testing.expectEqual(@as(u16, 20), ui.sacrifice_slot.item);
}

test "clickSlot output takes item with empty cursor" {
    var ui = GrindstoneUI.init();
    ui.input_slot = Slot{ .item = 100, .count = 1 };
    ui.input_enchant = 1;
    ui.recalculate();
    const taken = ui.clickSlot(2, Slot.empty);
    try std.testing.expectEqual(@as(u16, 100), taken.item);
    try std.testing.expect(ui.output_slot.isEmpty());
}

test "clickSlot output rejects placing items" {
    var ui = GrindstoneUI.init();
    const returned = ui.clickSlot(2, Slot{ .item = 50, .count = 1 });
    try std.testing.expectEqual(@as(u16, 50), returned.item);
    try std.testing.expect(ui.output_slot.isEmpty());
}

test "close returns input and sacrifice to inventory" {
    var ui = GrindstoneUI.init();
    ui.input_slot = Slot{ .item = 10, .count = 2 };
    ui.sacrifice_slot = Slot{ .item = 20, .count = 3 };
    var inv = [_]Slot{Slot.empty} ** 4;
    ui.close(&inv);
    try std.testing.expectEqual(@as(u16, 10), inv[0].item);
    try std.testing.expectEqual(@as(u8, 2), inv[0].count);
    try std.testing.expectEqual(@as(u16, 20), inv[1].item);
    try std.testing.expectEqual(@as(u8, 3), inv[1].count);
    try std.testing.expect(ui.input_slot.isEmpty());
    try std.testing.expect(ui.sacrifice_slot.isEmpty());
}

test "close resets all state" {
    var ui = GrindstoneUI.init();
    ui.input_slot = Slot{ .item = 10, .count = 1 };
    ui.input_enchant = 5;
    ui.recalculate();
    var inv = [_]Slot{Slot.empty} ** 4;
    ui.close(&inv);
    try std.testing.expectEqual(@as(u8, 0), ui.xp_reward);
    try std.testing.expectEqual(@as(u8, 0), ui.input_enchant);
    try std.testing.expectEqual(@as(u8, 0), ui.sacrifice_enchant);
}

test "zero enchant levels produce zero XP" {
    var ui = GrindstoneUI.init();
    ui.input_slot = Slot{ .item = 100, .count = 1 };
    ui.input_enchant = 0;
    ui.recalculate();
    try std.testing.expect(!ui.output_slot.isEmpty());
    try std.testing.expectEqual(@as(u8, 0), ui.xp_reward);
}

test "Slot.empty is empty" {
    try std.testing.expect(Slot.empty.isEmpty());
    const non_empty = Slot{ .item = 1, .count = 1 };
    try std.testing.expect(!non_empty.isEmpty());
}
