/// Smithing table UI for upgrading diamond gear to netherite.
/// Manages template, base, addition, and output slots with recipe lookup.

const std = @import("std");
const inv = @import("inventory.zig");
const Slot = inv.Slot;

pub const SmithingUpgrade = struct {
    base: u16,
    addition: u16,
    result: u16,
};

pub const UPGRADES = [_]SmithingUpgrade{
    .{ .base = 261, .addition = 327, .result = 570 }, // diamond_pickaxe -> netherite_pickaxe
    .{ .base = 266, .addition = 327, .result = 571 }, // diamond_axe -> netherite_axe
    .{ .base = 271, .addition = 327, .result = 572 }, // diamond_shovel -> netherite_shovel
    .{ .base = 276, .addition = 327, .result = 573 }, // diamond_hoe -> netherite_hoe
    .{ .base = 281, .addition = 327, .result = 574 }, // diamond_sword -> netherite_sword
    .{ .base = 294, .addition = 327, .result = 575 }, // diamond_helmet -> netherite_helmet
    .{ .base = 295, .addition = 327, .result = 576 }, // diamond_chestplate -> netherite_chestplate
    .{ .base = 296, .addition = 327, .result = 577 }, // diamond_leggings -> netherite_leggings
    .{ .base = 297, .addition = 327, .result = 578 }, // diamond_boots -> netherite_boots
};

pub const SmithingUI = struct {
    template_slot: Slot = Slot.empty, // smithing template (1.20+), optional for netherite
    base_slot: Slot = Slot.empty,
    addition_slot: Slot = Slot.empty,
    output_slot: Slot = Slot.empty,

    pub fn init() SmithingUI {
        return .{};
    }

    /// Click a slot (0=template, 1=base, 2=addition, 3=output).
    /// Swaps cursor with slot contents. Output slot only allows taking.
    /// After base/addition change, recalculates output.
    pub fn clickSlot(self: *SmithingUI, slot_idx: u8, cursor: Slot) Slot {
        if (slot_idx == 3) {
            if (cursor.isEmpty()) {
                return self.takeOutput() orelse Slot.empty;
            }
            return cursor;
        }

        const slot_ptr = self.slotPtr(slot_idx) orelse return cursor;
        const old = slot_ptr.*;
        slot_ptr.* = cursor;
        if (slot_idx == 1 or slot_idx == 2) {
            self.recalculate();
        }
        return old;
    }

    fn slotPtr(self: *SmithingUI, idx: u8) ?*Slot {
        return switch (idx) {
            0 => &self.template_slot,
            1 => &self.base_slot,
            2 => &self.addition_slot,
            3 => &self.output_slot,
            else => null,
        };
    }

    /// Match base+addition against UPGRADES table.
    /// Output preserves count from base (enchantments carried over conceptually).
    pub fn recalculate(self: *SmithingUI) void {
        self.output_slot = Slot.empty;

        if (self.base_slot.isEmpty() or self.addition_slot.isEmpty()) return;

        const upgrade = findUpgrade(self.base_slot.item, self.addition_slot.item) orelse return;
        self.output_slot = Slot{
            .item = upgrade.result,
            .count = self.base_slot.count,
        };
    }

    /// Consume base+addition (and template if present), return output.
    /// Returns null if no valid output exists.
    pub fn takeOutput(self: *SmithingUI) ?Slot {
        if (self.output_slot.isEmpty()) return null;

        const result = self.output_slot;

        self.base_slot.count -= 1;
        if (self.base_slot.count == 0) self.base_slot = Slot.empty;

        self.addition_slot.count -= 1;
        if (self.addition_slot.count == 0) self.addition_slot = Slot.empty;

        if (!self.template_slot.isEmpty()) {
            self.template_slot.count -= 1;
            if (self.template_slot.count == 0) self.template_slot = Slot.empty;
        }

        self.output_slot = Slot.empty;
        self.recalculate();
        return result;
    }

    /// Close the smithing UI, returning template+base+addition to inventory.
    pub fn close(self: *SmithingUI, inv_slots: []Slot) void {
        const slots_to_return = [_]Slot{ self.template_slot, self.base_slot, self.addition_slot };
        for (slots_to_return) |slot| {
            if (slot.isEmpty()) continue;
            for (inv_slots) |*inv_slot| {
                if (inv_slot.isEmpty()) {
                    inv_slot.* = slot;
                    break;
                }
            }
        }
        self.* = SmithingUI.init();
    }

    /// Look up the upgrade result for a given base+addition pair.
    pub fn findUpgrade(base_item: u16, addition_item: u16) ?SmithingUpgrade {
        for (UPGRADES) |upgrade| {
            if (upgrade.base == base_item and upgrade.addition == addition_item) {
                return upgrade;
            }
        }
        return null;
    }

    /// Get screen position for a slot. Layout: template, base, addition, output
    /// left-to-right with gaps, centered on screen.
    pub fn getSlotPosition(slot_idx: u8, sw: f32, sh: f32) struct { x: f32, y: f32 } {
        const slot_size: f32 = 48.0;
        const gap: f32 = 60.0;
        const total_width = slot_size * 4.0 + gap * 3.0;
        const start_x = (sw - total_width) / 2.0;
        const y = (sh - slot_size) / 2.0;

        const offset: f32 = switch (slot_idx) {
            0 => 0.0,
            1 => slot_size + gap,
            2 => (slot_size + gap) * 2.0,
            3 => (slot_size + gap) * 3.0,
            else => 0.0,
        };

        return .{ .x = start_x + offset, .y = y };
    }
};

// ── Tests ────────────────────────────────────────────────────────────

test "init returns empty smithing table" {
    const ui = SmithingUI.init();
    try std.testing.expect(ui.template_slot.isEmpty());
    try std.testing.expect(ui.base_slot.isEmpty());
    try std.testing.expect(ui.addition_slot.isEmpty());
    try std.testing.expect(ui.output_slot.isEmpty());
}

test "clickSlot swaps cursor with base slot" {
    var ui = SmithingUI.init();
    const cursor = Slot{ .item = 261, .count = 1 };
    const returned = ui.clickSlot(1, cursor);
    try std.testing.expect(returned.isEmpty());
    try std.testing.expectEqual(@as(u16, 261), ui.base_slot.item);
}

test "recalculate produces netherite pickaxe from diamond pickaxe + netherite ingot" {
    var ui = SmithingUI.init();
    ui.base_slot = Slot{ .item = 261, .count = 1 };
    ui.addition_slot = Slot{ .item = 327, .count = 1 };
    ui.recalculate();
    try std.testing.expectEqual(@as(u16, 570), ui.output_slot.item);
    try std.testing.expectEqual(@as(u8, 1), ui.output_slot.count);
}

test "recalculate clears output when base is empty" {
    var ui = SmithingUI.init();
    ui.addition_slot = Slot{ .item = 327, .count = 1 };
    ui.recalculate();
    try std.testing.expect(ui.output_slot.isEmpty());
}

test "recalculate clears output when addition is empty" {
    var ui = SmithingUI.init();
    ui.base_slot = Slot{ .item = 261, .count = 1 };
    ui.recalculate();
    try std.testing.expect(ui.output_slot.isEmpty());
}

test "recalculate clears output for invalid combination" {
    var ui = SmithingUI.init();
    ui.base_slot = Slot{ .item = 999, .count = 1 };
    ui.addition_slot = Slot{ .item = 327, .count = 1 };
    ui.recalculate();
    try std.testing.expect(ui.output_slot.isEmpty());
}

test "takeOutput consumes base and addition" {
    var ui = SmithingUI.init();
    ui.base_slot = Slot{ .item = 261, .count = 1 };
    ui.addition_slot = Slot{ .item = 327, .count = 3 };
    ui.recalculate();
    const result = ui.takeOutput();
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(u16, 570), result.?.item);
    try std.testing.expect(ui.base_slot.isEmpty());
    try std.testing.expectEqual(@as(u8, 2), ui.addition_slot.count);
}

test "takeOutput consumes template when present" {
    var ui = SmithingUI.init();
    ui.template_slot = Slot{ .item = 400, .count = 2 };
    ui.base_slot = Slot{ .item = 266, .count = 1 };
    ui.addition_slot = Slot{ .item = 327, .count = 1 };
    ui.recalculate();
    const result = ui.takeOutput();
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(u16, 571), result.?.item);
    try std.testing.expectEqual(@as(u8, 1), ui.template_slot.count);
}

test "takeOutput returns null when output is empty" {
    var ui = SmithingUI.init();
    const result = ui.takeOutput();
    try std.testing.expect(result == null);
}

test "clickSlot output only allows taking" {
    var ui = SmithingUI.init();
    ui.base_slot = Slot{ .item = 281, .count = 1 };
    ui.addition_slot = Slot{ .item = 327, .count = 1 };
    ui.recalculate();

    // Take with empty cursor
    const taken = ui.clickSlot(3, Slot.empty);
    try std.testing.expectEqual(@as(u16, 574), taken.item);

    // Try placing into output -- should be rejected
    ui.recalculate();
    const rejected = ui.clickSlot(3, Slot{ .item = 50, .count = 1 });
    try std.testing.expectEqual(@as(u16, 50), rejected.item);
}

test "close returns items to inventory" {
    var ui = SmithingUI.init();
    ui.template_slot = Slot{ .item = 400, .count = 1 };
    ui.base_slot = Slot{ .item = 261, .count = 1 };
    ui.addition_slot = Slot{ .item = 327, .count = 1 };
    var slots = [_]Slot{Slot.empty} ** 5;
    ui.close(&slots);
    try std.testing.expectEqual(@as(u16, 400), slots[0].item);
    try std.testing.expectEqual(@as(u16, 261), slots[1].item);
    try std.testing.expectEqual(@as(u16, 327), slots[2].item);
    try std.testing.expect(ui.template_slot.isEmpty());
    try std.testing.expect(ui.base_slot.isEmpty());
}

test "all 9 upgrades produce correct results" {
    var ui = SmithingUI.init();
    for (UPGRADES) |upgrade| {
        ui.base_slot = Slot{ .item = upgrade.base, .count = 1 };
        ui.addition_slot = Slot{ .item = upgrade.addition, .count = 1 };
        ui.recalculate();
        try std.testing.expectEqual(upgrade.result, ui.output_slot.item);
    }
}

test "findUpgrade returns correct upgrade" {
    const result = SmithingUI.findUpgrade(261, 327);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(u16, 570), result.?.result);
}

test "findUpgrade returns null for invalid combo" {
    const result = SmithingUI.findUpgrade(999, 327);
    try std.testing.expect(result == null);
}

test "output preserves base count" {
    var ui = SmithingUI.init();
    ui.base_slot = Slot{ .item = 294, .count = 3 };
    ui.addition_slot = Slot{ .item = 327, .count = 1 };
    ui.recalculate();
    try std.testing.expectEqual(@as(u8, 3), ui.output_slot.count);
}

test "getSlotPosition orders slots left to right" {
    const pos0 = SmithingUI.getSlotPosition(0, 800.0, 600.0);
    const pos1 = SmithingUI.getSlotPosition(1, 800.0, 600.0);
    const pos2 = SmithingUI.getSlotPosition(2, 800.0, 600.0);
    const pos3 = SmithingUI.getSlotPosition(3, 800.0, 600.0);
    try std.testing.expect(pos0.x < pos1.x);
    try std.testing.expect(pos1.x < pos2.x);
    try std.testing.expect(pos2.x < pos3.x);
    // All at same y
    try std.testing.expectEqual(pos0.y, pos1.y);
    try std.testing.expectEqual(pos2.y, pos3.y);
}

test "clickSlot with invalid index returns cursor unchanged" {
    var ui = SmithingUI.init();
    const cursor = Slot{ .item = 5, .count = 1 };
    const returned = ui.clickSlot(10, cursor);
    try std.testing.expectEqual(@as(u16, 5), returned.item);
}

test "takeOutput recalculates after consuming inputs" {
    var ui = SmithingUI.init();
    ui.base_slot = Slot{ .item = 261, .count = 2 };
    ui.addition_slot = Slot{ .item = 327, .count = 2 };
    ui.recalculate();
    _ = ui.takeOutput();
    // After taking, base has 1 left and addition has 1 left, so output should recalculate
    try std.testing.expectEqual(@as(u16, 570), ui.output_slot.item);
}
