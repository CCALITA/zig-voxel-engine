const std = @import("std");
const inv = @import("inventory.zig");
const Slot = inv.Slot;

const max_rename_len: u8 = 35;

pub const AnvilUI = struct {
    input_slot: Slot = Slot.empty,
    material_slot: Slot = Slot.empty,
    output_slot: Slot = Slot.empty,
    rename_buf: [max_rename_len]u8 = [_]u8{0} ** max_rename_len,
    rename_len: u8 = 0,
    xp_cost: u8 = 0,

    pub fn init() AnvilUI {
        return .{};
    }

    /// Click a slot (0=input, 1=material, 2=output). Swaps cursor with slot contents.
    /// After input/material change, recalculates output.
    pub fn clickSlot(self: *AnvilUI, slot_idx: u8, cursor: Slot) Slot {
        const slot_ptr = self.slotPtr(slot_idx) orelse return cursor;
        const old = slot_ptr.*;
        slot_ptr.* = cursor;
        if (slot_idx <= 1) {
            self.recalculate();
        }
        return old;
    }

    fn slotPtr(self: *AnvilUI, idx: u8) ?*Slot {
        return switch (idx) {
            0 => &self.input_slot,
            1 => &self.material_slot,
            2 => &self.output_slot,
            else => null,
        };
    }

    /// Recalculate output slot and XP cost based on current inputs.
    /// - Same item type in both slots: repair (restore 25% durability), cost = 4 XP
    /// - Input has enchantments + material: combine enchantments, cost = enchant levels
    /// - Rename adds +1 to cost
    pub fn recalculate(self: *AnvilUI) void {
        self.output_slot = Slot.empty;
        self.xp_cost = 0;

        if (self.input_slot.isEmpty()) return;

        var cost: u8 = 0;
        var has_operation = false;

        // Repair: same item type in both slots
        if (!self.material_slot.isEmpty() and self.input_slot.item == self.material_slot.item) {
            // Repair operation: restore 25% durability, represented by boosting count
            const repair_amount = @max(1, self.input_slot.count / 4);
            const new_count = @min(inv.STACK_MAX, self.input_slot.count + repair_amount);
            self.output_slot = Slot{ .item = self.input_slot.item, .count = new_count };
            cost += 4;
            has_operation = true;
        } else if (!self.material_slot.isEmpty() and self.input_slot.item != self.material_slot.item) {
            // Combine enchantments: different material present
            // Enchant level approximated by material count
            const enchant_levels = self.material_slot.count;
            self.output_slot = Slot{ .item = self.input_slot.item, .count = self.input_slot.count };
            cost += enchant_levels;
            has_operation = true;
        }

        // Rename adds +1 cost
        if (self.rename_len > 0 and !self.input_slot.isEmpty()) {
            if (!has_operation) {
                // Rename-only operation
                self.output_slot = Slot{ .item = self.input_slot.item, .count = self.input_slot.count };
            }
            cost += 1;
            has_operation = true;
        }

        if (has_operation) {
            self.xp_cost = cost;
        }
    }

    /// Take the output if player has enough XP. Consumes input+material, deducts XP.
    pub fn takeOutput(self: *AnvilUI, player_xp: *u32) ?Slot {
        if (self.output_slot.isEmpty()) return null;
        if (player_xp.* < self.xp_cost) return null;

        const result = self.output_slot;
        player_xp.* -= self.xp_cost;
        self.input_slot = Slot.empty;
        self.material_slot = Slot.empty;
        self.output_slot = Slot.empty;
        self.xp_cost = 0;
        return result;
    }

    /// Append a character to the rename buffer.
    pub fn appendRenameChar(self: *AnvilUI, c: u8) void {
        if (self.rename_len < max_rename_len) {
            self.rename_buf[self.rename_len] = c;
            self.rename_len += 1;
            self.recalculate();
        }
    }

    /// Delete the last character from the rename buffer.
    pub fn deleteRenameChar(self: *AnvilUI) void {
        if (self.rename_len > 0) {
            self.rename_len -= 1;
            self.rename_buf[self.rename_len] = 0;
            self.recalculate();
        }
    }

    /// Close the anvil UI, returning input+material to inventory and clearing state.
    pub fn close(self: *AnvilUI, inv_slots: []Slot) void {
        const slots_to_return = [_]Slot{ self.input_slot, self.material_slot };
        for (slots_to_return) |slot| {
            if (slot.isEmpty()) continue;
            for (inv_slots) |*inv_slot| {
                if (inv_slot.isEmpty()) {
                    inv_slot.* = slot;
                    break;
                }
            }
        }
        self.* = AnvilUI.init();
    }

    /// Get screen position for a slot. Layout: input left, material center, output right.
    /// Slot size = 48px, gap = 60px between slots, centered on screen.
    pub fn getSlotPosition(slot_idx: u8, sw: f32, sh: f32) struct { x: f32, y: f32 } {
        const slot_size: f32 = 48.0;
        const gap: f32 = 60.0;
        const total_width = slot_size * 3.0 + gap * 2.0;
        const start_x = (sw - total_width) / 2.0;
        const y = (sh - slot_size) / 2.0;

        const offset: f32 = switch (slot_idx) {
            0 => 0.0,
            1 => slot_size + gap,
            2 => (slot_size + gap) * 2.0,
            else => 0.0,
        };

        return .{ .x = start_x + offset, .y = y };
    }
};

// ─── Tests ───────────────────────────────────────────────────────────────────

test "init returns empty anvil" {
    const anvil = AnvilUI.init();
    try std.testing.expect(anvil.input_slot.isEmpty());
    try std.testing.expect(anvil.material_slot.isEmpty());
    try std.testing.expect(anvil.output_slot.isEmpty());
    try std.testing.expectEqual(@as(u8, 0), anvil.xp_cost);
}

test "clickSlot swaps cursor with input" {
    var anvil = AnvilUI.init();
    const cursor = Slot{ .item = 5, .count = 10 };
    const returned = anvil.clickSlot(0, cursor);
    try std.testing.expect(returned.isEmpty());
    try std.testing.expectEqual(@as(u16, 5), anvil.input_slot.item);
}

test "repair: same item type restores 25% durability" {
    var anvil = AnvilUI.init();
    anvil.input_slot = Slot{ .item = 10, .count = 40 };
    anvil.material_slot = Slot{ .item = 10, .count = 20 };
    anvil.recalculate();
    try std.testing.expectEqual(@as(u8, 50), anvil.output_slot.count);
    try std.testing.expectEqual(@as(u8, 4), anvil.xp_cost);
}

test "repair: count capped at STACK_MAX" {
    var anvil = AnvilUI.init();
    anvil.input_slot = Slot{ .item = 10, .count = 60 };
    anvil.material_slot = Slot{ .item = 10, .count = 1 };
    anvil.recalculate();
    try std.testing.expectEqual(inv.STACK_MAX, anvil.output_slot.count);
}

test "combine enchantments: different material" {
    var anvil = AnvilUI.init();
    anvil.input_slot = Slot{ .item = 10, .count = 1 };
    anvil.material_slot = Slot{ .item = 20, .count = 3 };
    anvil.recalculate();
    try std.testing.expectEqual(@as(u16, 10), anvil.output_slot.item);
    try std.testing.expectEqual(@as(u8, 3), anvil.xp_cost);
}

test "rename adds 1 to cost" {
    var anvil = AnvilUI.init();
    anvil.input_slot = Slot{ .item = 10, .count = 1 };
    anvil.material_slot = Slot{ .item = 10, .count = 1 };
    anvil.recalculate();
    const base_cost = anvil.xp_cost;
    anvil.appendRenameChar('A');
    try std.testing.expectEqual(base_cost + 1, anvil.xp_cost);
}

test "rename only operation" {
    var anvil = AnvilUI.init();
    anvil.input_slot = Slot{ .item = 5, .count = 1 };
    anvil.appendRenameChar('X');
    try std.testing.expect(!anvil.output_slot.isEmpty());
    try std.testing.expectEqual(@as(u8, 1), anvil.xp_cost);
}

test "takeOutput deducts XP and clears slots" {
    var anvil = AnvilUI.init();
    anvil.input_slot = Slot{ .item = 10, .count = 40 };
    anvil.material_slot = Slot{ .item = 10, .count = 20 };
    anvil.recalculate();
    var xp: u32 = 10;
    const result = anvil.takeOutput(&xp);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(u32, 6), xp);
    try std.testing.expect(anvil.input_slot.isEmpty());
}

test "takeOutput fails with insufficient XP" {
    var anvil = AnvilUI.init();
    anvil.input_slot = Slot{ .item = 10, .count = 40 };
    anvil.material_slot = Slot{ .item = 10, .count = 20 };
    anvil.recalculate();
    var xp: u32 = 2;
    const result = anvil.takeOutput(&xp);
    try std.testing.expect(result == null);
    try std.testing.expectEqual(@as(u32, 2), xp);
}

test "close returns items to inventory" {
    var anvil = AnvilUI.init();
    anvil.input_slot = Slot{ .item = 5, .count = 3 };
    anvil.material_slot = Slot{ .item = 8, .count = 1 };
    var slots = [_]Slot{Slot.empty} ** 4;
    anvil.close(&slots);
    try std.testing.expectEqual(@as(u16, 5), slots[0].item);
    try std.testing.expectEqual(@as(u16, 8), slots[1].item);
    try std.testing.expect(anvil.input_slot.isEmpty());
}

test "deleteRenameChar removes last char" {
    var anvil = AnvilUI.init();
    anvil.input_slot = Slot{ .item = 1, .count = 1 };
    anvil.appendRenameChar('A');
    anvil.appendRenameChar('B');
    try std.testing.expectEqual(@as(u8, 2), anvil.rename_len);
    anvil.deleteRenameChar();
    try std.testing.expectEqual(@as(u8, 1), anvil.rename_len);
}

test "getSlotPosition centers on screen" {
    const pos0 = AnvilUI.getSlotPosition(0, 800.0, 600.0);
    const pos1 = AnvilUI.getSlotPosition(1, 800.0, 600.0);
    const pos2 = AnvilUI.getSlotPosition(2, 800.0, 600.0);
    // Slots should be ordered left to right
    try std.testing.expect(pos0.x < pos1.x);
    try std.testing.expect(pos1.x < pos2.x);
    // All at same y
    try std.testing.expectEqual(pos0.y, pos1.y);
    try std.testing.expectEqual(pos1.y, pos2.y);
}

test "no valid operation produces empty output" {
    var anvil = AnvilUI.init();
    anvil.recalculate();
    try std.testing.expect(anvil.output_slot.isEmpty());
    try std.testing.expectEqual(@as(u8, 0), anvil.xp_cost);
}
