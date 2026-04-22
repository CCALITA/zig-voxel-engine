/// Extended item slot with durability tracking and packed enchantment data.
/// Builds on the basic Slot (item + count) by adding tool wear and enchantment storage.
/// Enchantments are bit-packed into a u32: 6 slots x 5 bits (3-bit id + 2-bit level).

const std = @import("std");

pub const ItemSlot = struct {
    item: u16 = 0,
    count: u8 = 0,
    durability: u16 = 0,
    max_durability: u16 = 0,
    enchantments: u32 = 0,

    pub const empty = ItemSlot{};

    pub fn isEmpty(self: ItemSlot) bool {
        return self.count == 0;
    }

    /// Decrement durability by 1. Returns false if the tool broke (count set to 0).
    /// Non-tools (max_durability == 0) are unaffected and always return true.
    pub fn useTool(self: *ItemSlot) bool {
        if (self.max_durability == 0) return true;
        if (self.durability == 0) return true;

        self.durability -= 1;
        if (self.durability == 0) {
            self.count = 0;
            return false;
        }
        return true;
    }

    /// Restore durability, capped at max_durability.
    pub fn repairItem(self: *ItemSlot, amount: u16) void {
        if (self.max_durability == 0) return;
        self.durability = @min(self.durability + amount, self.max_durability);
    }

    /// Fraction of durability remaining (1.0 = full, 0.0 = about to break).
    /// Returns 1.0 for non-tools.
    pub fn getDurabilityPercent(self: ItemSlot) f32 {
        if (self.max_durability == 0) return 1.0;
        return @as(f32, @floatFromInt(self.durability)) / @as(f32, @floatFromInt(self.max_durability));
    }

    /// RGB color for a durability bar: green at 100 %, yellow at 50 %, red near 0 %.
    pub fn getDurabilityColor(self: ItemSlot) [3]f32 {
        const pct = self.getDurabilityPercent();
        if (pct > 0.5) {
            // green -> yellow  (r rises from 0 to 1 as pct drops from 1.0 to 0.5)
            const t = (pct - 0.5) * 2.0;
            return .{ 1.0 - t, 1.0, 0.0 };
        }
        // yellow -> red  (g drops from 1 to 0 as pct drops from 0.5 to 0.0)
        const t = pct * 2.0;
        return .{ 1.0, t, 0.0 };
    }

    // ---- enchantment helpers ----
    // Layout inside the u32:  slot0[4:0]  slot1[9:5]  slot2[14:10] ... slot5[29:25]
    // Each 5-bit group: id (bits 2..0, u3, 0 = none) | level (bits 4..3, u2, 0-3 = level 1-4)

    const bits_per_slot: u5 = 5;
    const max_slots: u4 = 6;

    pub fn getEnchantLevel(self: ItemSlot, slot: u3) struct { id: u3, level: u2 } {
        if (slot >= max_slots) return .{ .id = 0, .level = 0 };
        const shift: u5 = @as(u5, slot) * bits_per_slot;
        const raw: u5 = @truncate(self.enchantments >> shift);
        return .{
            .id = @truncate(raw),
            .level = @truncate(raw >> 3),
        };
    }

    pub fn setEnchant(self: *ItemSlot, slot: u3, id: u3, level: u2) void {
        if (slot >= max_slots) return;
        const shift: u5 = @as(u5, slot) * bits_per_slot;
        const mask: u32 = ~(@as(u32, 0x1F) << shift);
        const value: u32 = (@as(u32, level) << 3 | @as(u32, id)) << shift;
        self.enchantments = (self.enchantments & mask) | value;
    }

    pub fn hasEnchant(self: ItemSlot, id: u3) bool {
        if (id == 0) return false; // 0 means "no enchant"
        var s: u3 = 0;
        while (s < max_slots) : (s += 1) {
            const info = self.getEnchantLevel(s);
            if (info.id == id) return true;
        }
        return false;
    }

    pub fn clearEnchants(self: *ItemSlot) void {
        self.enchantments = 0;
    }

    /// Sum of (level + 1) across all non-empty enchantment slots.
    pub fn getTotalEnchantLevels(self: ItemSlot) u8 {
        var total: u8 = 0;
        var s: u3 = 0;
        while (s < max_slots) : (s += 1) {
            const info = self.getEnchantLevel(s);
            if (info.id != 0) {
                total += @as(u8, info.level) + 1;
            }
        }
        return total;
    }
};

// ---------------------------------------------------------------------------
// Migration helpers
// ---------------------------------------------------------------------------

/// Convert any struct with `.item` (u16) and `.count` (u8) fields into an ItemSlot.
pub fn fromBasicSlot(basic: anytype) ItemSlot {
    return .{
        .item = basic.item,
        .count = basic.count,
    };
}

/// Strip extended fields, returning a lightweight {item, count} pair.
pub fn toBasicSlot(extended: ItemSlot) struct { item: u16, count: u8 } {
    return .{ .item = extended.item, .count = extended.count };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "empty slot is empty" {
    const slot = ItemSlot.empty;
    try std.testing.expect(slot.isEmpty());
    try std.testing.expectEqual(@as(u16, 0), slot.item);
    try std.testing.expectEqual(@as(u8, 0), slot.count);
}

test "non-empty slot is not empty" {
    const slot = ItemSlot{ .item = 5, .count = 3 };
    try std.testing.expect(!slot.isEmpty());
}

test "useTool decrements durability" {
    var slot = ItemSlot{ .item = 1, .count = 1, .durability = 10, .max_durability = 100 };
    const ok = slot.useTool();
    try std.testing.expect(ok);
    try std.testing.expectEqual(@as(u16, 9), slot.durability);
}

test "useTool breaks tool at durability 1" {
    var slot = ItemSlot{ .item = 1, .count = 1, .durability = 1, .max_durability = 100 };
    const ok = slot.useTool();
    try std.testing.expect(!ok);
    try std.testing.expectEqual(@as(u8, 0), slot.count);
    try std.testing.expectEqual(@as(u16, 0), slot.durability);
}

test "useTool on non-tool is no-op" {
    var slot = ItemSlot{ .item = 2, .count = 5 };
    const ok = slot.useTool();
    try std.testing.expect(ok);
    try std.testing.expectEqual(@as(u8, 5), slot.count);
}

test "repairItem adds durability" {
    var slot = ItemSlot{ .item = 1, .count = 1, .durability = 50, .max_durability = 100 };
    slot.repairItem(30);
    try std.testing.expectEqual(@as(u16, 80), slot.durability);
}

test "repairItem caps at max_durability" {
    var slot = ItemSlot{ .item = 1, .count = 1, .durability = 90, .max_durability = 100 };
    slot.repairItem(50);
    try std.testing.expectEqual(@as(u16, 100), slot.durability);
}

test "repairItem on non-tool is no-op" {
    var slot = ItemSlot{ .item = 2, .count = 1, .durability = 0, .max_durability = 0 };
    slot.repairItem(10);
    try std.testing.expectEqual(@as(u16, 0), slot.durability);
}

test "getDurabilityPercent for tool" {
    const slot = ItemSlot{ .item = 1, .count = 1, .durability = 75, .max_durability = 100 };
    try std.testing.expectApproxEqAbs(@as(f32, 0.75), slot.getDurabilityPercent(), 0.001);
}

test "getDurabilityPercent for non-tool returns 1.0" {
    const slot = ItemSlot{ .item = 2, .count = 1 };
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), slot.getDurabilityPercent(), 0.001);
}

test "getDurabilityColor green at full" {
    const slot = ItemSlot{ .item = 1, .count = 1, .durability = 100, .max_durability = 100 };
    const c = slot.getDurabilityColor();
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), c[0], 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), c[1], 0.01);
}

test "getDurabilityColor red near zero" {
    const slot = ItemSlot{ .item = 1, .count = 1, .durability = 1, .max_durability = 100 };
    const c = slot.getDurabilityColor();
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), c[0], 0.01);
    // green should be very low
    try std.testing.expect(c[1] < 0.1);
}

test "enchant set and get round-trip" {
    var slot = ItemSlot{ .item = 1, .count = 1 };
    slot.setEnchant(0, 3, 2);
    const info = slot.getEnchantLevel(0);
    try std.testing.expectEqual(@as(u3, 3), info.id);
    try std.testing.expectEqual(@as(u2, 2), info.level);
}

test "enchant multiple slots independent" {
    var slot = ItemSlot{ .item = 1, .count = 1 };
    slot.setEnchant(0, 1, 0);
    slot.setEnchant(2, 5, 3);
    const a = slot.getEnchantLevel(0);
    const b = slot.getEnchantLevel(2);
    try std.testing.expectEqual(@as(u3, 1), a.id);
    try std.testing.expectEqual(@as(u2, 0), a.level);
    try std.testing.expectEqual(@as(u3, 5), b.id);
    try std.testing.expectEqual(@as(u2, 3), b.level);
    // unset slot should be zero
    const c = slot.getEnchantLevel(1);
    try std.testing.expectEqual(@as(u3, 0), c.id);
}

test "hasEnchant finds set enchant" {
    var slot = ItemSlot{ .item = 1, .count = 1 };
    slot.setEnchant(3, 4, 1);
    try std.testing.expect(slot.hasEnchant(4));
    try std.testing.expect(!slot.hasEnchant(2));
}

test "clearEnchants removes all" {
    var slot = ItemSlot{ .item = 1, .count = 1 };
    slot.setEnchant(0, 1, 1);
    slot.setEnchant(1, 2, 2);
    slot.clearEnchants();
    try std.testing.expectEqual(@as(u32, 0), slot.enchantments);
}

test "getTotalEnchantLevels sums correctly" {
    var slot = ItemSlot{ .item = 1, .count = 1 };
    slot.setEnchant(0, 1, 0); // level 1
    slot.setEnchant(1, 2, 2); // level 3
    try std.testing.expectEqual(@as(u8, 4), slot.getTotalEnchantLevels());
}

test "fromBasicSlot preserves item and count" {
    const Basic = struct { item: u16, count: u8 };
    const basic = Basic{ .item = 42, .count = 16 };
    const extended = fromBasicSlot(basic);
    try std.testing.expectEqual(@as(u16, 42), extended.item);
    try std.testing.expectEqual(@as(u8, 16), extended.count);
    try std.testing.expectEqual(@as(u16, 0), extended.durability);
    try std.testing.expectEqual(@as(u32, 0), extended.enchantments);
}

test "toBasicSlot strips extended fields" {
    const extended = ItemSlot{ .item = 7, .count = 3, .durability = 50, .max_durability = 100, .enchantments = 999 };
    const basic = toBasicSlot(extended);
    try std.testing.expectEqual(@as(u16, 7), basic.item);
    try std.testing.expectEqual(@as(u8, 3), basic.count);
}

test "out-of-range enchant slot returns zero" {
    const slot = ItemSlot{ .item = 1, .count = 1, .enchantments = 0xFFFFFFFF };
    const info = slot.getEnchantLevel(7); // slot 7 >= max_slots(6)
    try std.testing.expectEqual(@as(u3, 0), info.id);
    try std.testing.expectEqual(@as(u2, 0), info.level);
}
