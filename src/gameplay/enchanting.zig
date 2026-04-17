/// Enchantment system for items.
/// Supports adding, querying, and computing bonuses from enchantments
/// on weapons, tools, and armor.

const std = @import("std");

pub const EnchantmentType = enum {
    sharpness,
    smite,
    bane_of_arthropods,
    efficiency,
    unbreaking,
    fortune,
    silk_touch,
    protection,
    fire_protection,
    blast_protection,
    projectile_protection,
    feather_falling,
    respiration,
    aqua_affinity,
    power,
    punch,
    flame,
    infinity,
};

pub const Enchantment = struct {
    enchant_type: EnchantmentType,
    level: u8, // 1-5 typically
};

pub const MAX_ENCHANTMENTS = 5;
const MAX_LEVEL: u8 = 5;

pub const EnchantedItem = struct {
    item_id: u16,
    enchantments: [MAX_ENCHANTMENTS]?Enchantment,

    pub fn init(item_id: u16) EnchantedItem {
        return .{
            .item_id = item_id,
            .enchantments = [_]?Enchantment{null} ** MAX_ENCHANTMENTS,
        };
    }

    /// Add an enchantment. Returns false if no free slot is available.
    pub fn addEnchantment(self: *EnchantedItem, enchant: Enchantment) bool {
        for (&self.enchantments) |*slot| {
            if (slot.* == null) {
                slot.* = enchant;
                return true;
            }
        }
        return false;
    }

    /// Look up an enchantment by type. Returns it if present, null otherwise.
    pub fn hasEnchantment(self: *const EnchantedItem, enchant_type: EnchantmentType) ?Enchantment {
        for (self.enchantments) |maybe| {
            if (maybe) |e| {
                if (e.enchant_type == enchant_type) return e;
            }
        }
        return null;
    }

    /// Sum damage bonus from offensive enchantments.
    /// Sharpness: +1.25 per level, Smite: +2.5 per level,
    /// Bane of Arthropods: +2.5 per level, Power: +1.5 per level.
    pub fn getDamageBonus(self: *const EnchantedItem) f32 {
        var bonus: f32 = 0.0;
        for (self.enchantments) |maybe| {
            if (maybe) |e| {
                const lvl: f32 = @floatFromInt(e.level);
                switch (e.enchant_type) {
                    .sharpness => bonus += 1.25 * lvl,
                    .smite => bonus += 2.5 * lvl,
                    .bane_of_arthropods => bonus += 2.5 * lvl,
                    .power => bonus += 1.5 * lvl,
                    else => {},
                }
            }
        }
        return bonus;
    }

    /// Sum protection bonus from defensive enchantments.
    /// Protection: +1.0 per level, Fire/Blast/Projectile Protection: +2.0 per level,
    /// Feather Falling: +3.0 per level.
    pub fn getProtectionBonus(self: *const EnchantedItem) f32 {
        var bonus: f32 = 0.0;
        for (self.enchantments) |maybe| {
            if (maybe) |e| {
                const lvl: f32 = @floatFromInt(e.level);
                switch (e.enchant_type) {
                    .protection => bonus += 1.0 * lvl,
                    .fire_protection => bonus += 2.0 * lvl,
                    .blast_protection => bonus += 2.0 * lvl,
                    .projectile_protection => bonus += 2.0 * lvl,
                    .feather_falling => bonus += 3.0 * lvl,
                    else => {},
                }
            }
        }
        return bonus;
    }

    /// Number of enchantments currently on the item.
    pub fn enchantmentCount(self: *const EnchantedItem) u8 {
        var count: u8 = 0;
        for (self.enchantments) |maybe| {
            if (maybe != null) count += 1;
        }
        return count;
    }
};

/// Calculate XP cost for enchanting (simplified).
/// Base cost per type + multiplier per level.
pub fn getEnchantCost(enchant_type: EnchantmentType, level: u8) u32 {
    const clamped: u32 = @min(level, MAX_LEVEL);
    const base: u32 = switch (enchant_type) {
        .sharpness, .smite, .bane_of_arthropods => 5,
        .efficiency, .unbreaking => 5,
        .fortune => 8,
        .silk_touch => 15,
        .protection, .fire_protection, .blast_protection, .projectile_protection => 5,
        .feather_falling, .respiration, .aqua_affinity => 5,
        .power, .punch => 5,
        .flame => 10,
        .infinity => 20,
    };
    return base * clamped;
}

// ──────────────────────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────────────────────

test "init creates item with no enchantments" {
    const item = EnchantedItem.init(42);
    try std.testing.expectEqual(@as(u16, 42), item.item_id);
    try std.testing.expectEqual(@as(u8, 0), item.enchantmentCount());
    for (item.enchantments) |e| {
        try std.testing.expect(e == null);
    }
}

test "addEnchantment stores enchantment" {
    var item = EnchantedItem.init(1);
    const ok = item.addEnchantment(.{ .enchant_type = .sharpness, .level = 3 });
    try std.testing.expect(ok);
    try std.testing.expectEqual(@as(u8, 1), item.enchantmentCount());
}

test "addEnchantment returns false when full" {
    var item = EnchantedItem.init(1);
    for (0..MAX_ENCHANTMENTS) |_| {
        _ = item.addEnchantment(.{ .enchant_type = .unbreaking, .level = 1 });
    }
    const ok = item.addEnchantment(.{ .enchant_type = .sharpness, .level = 1 });
    try std.testing.expect(!ok);
    try std.testing.expectEqual(@as(u8, MAX_ENCHANTMENTS), item.enchantmentCount());
}

test "hasEnchantment returns matching enchantment" {
    var item = EnchantedItem.init(1);
    _ = item.addEnchantment(.{ .enchant_type = .efficiency, .level = 4 });

    const found = item.hasEnchantment(.efficiency);
    try std.testing.expect(found != null);
    try std.testing.expectEqual(@as(u8, 4), found.?.level);
}

test "hasEnchantment returns null when absent" {
    const item = EnchantedItem.init(1);
    try std.testing.expect(item.hasEnchantment(.sharpness) == null);
}

test "getDamageBonus sums offensive enchantments" {
    var item = EnchantedItem.init(1);
    _ = item.addEnchantment(.{ .enchant_type = .sharpness, .level = 2 }); // 2.5
    _ = item.addEnchantment(.{ .enchant_type = .smite, .level = 1 }); // 2.5

    const bonus = item.getDamageBonus();
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), bonus, 0.001);
}

test "getDamageBonus is zero with no offensive enchantments" {
    var item = EnchantedItem.init(1);
    _ = item.addEnchantment(.{ .enchant_type = .protection, .level = 3 });

    try std.testing.expectApproxEqAbs(@as(f32, 0.0), item.getDamageBonus(), 0.001);
}

test "getProtectionBonus sums defensive enchantments" {
    var item = EnchantedItem.init(1);
    _ = item.addEnchantment(.{ .enchant_type = .protection, .level = 4 }); // 4.0
    _ = item.addEnchantment(.{ .enchant_type = .fire_protection, .level = 2 }); // 4.0

    const bonus = item.getProtectionBonus();
    try std.testing.expectApproxEqAbs(@as(f32, 8.0), bonus, 0.001);
}

test "getProtectionBonus includes feather falling" {
    var item = EnchantedItem.init(1);
    _ = item.addEnchantment(.{ .enchant_type = .feather_falling, .level = 3 }); // 9.0

    try std.testing.expectApproxEqAbs(@as(f32, 9.0), item.getProtectionBonus(), 0.001);
}

test "getProtectionBonus is zero with no defensive enchantments" {
    var item = EnchantedItem.init(1);
    _ = item.addEnchantment(.{ .enchant_type = .sharpness, .level = 5 });

    try std.testing.expectApproxEqAbs(@as(f32, 0.0), item.getProtectionBonus(), 0.001);
}

test "getEnchantCost returns base * level" {
    try std.testing.expectEqual(@as(u32, 5), getEnchantCost(.sharpness, 1));
    try std.testing.expectEqual(@as(u32, 25), getEnchantCost(.sharpness, 5));
    try std.testing.expectEqual(@as(u32, 15), getEnchantCost(.silk_touch, 1));
    try std.testing.expectEqual(@as(u32, 20), getEnchantCost(.infinity, 1));
}

test "getEnchantCost clamps level to MAX_LEVEL" {
    // Level 10 should be treated as 5
    try std.testing.expectEqual(@as(u32, 25), getEnchantCost(.sharpness, 10));
}

test "multiple enchantments coexist independently" {
    var item = EnchantedItem.init(1);
    _ = item.addEnchantment(.{ .enchant_type = .sharpness, .level = 3 });
    _ = item.addEnchantment(.{ .enchant_type = .unbreaking, .level = 2 });
    _ = item.addEnchantment(.{ .enchant_type = .fire_protection, .level = 1 });

    try std.testing.expectEqual(@as(u8, 3), item.enchantmentCount());
    try std.testing.expect(item.hasEnchantment(.sharpness) != null);
    try std.testing.expect(item.hasEnchantment(.unbreaking) != null);
    try std.testing.expect(item.hasEnchantment(.fire_protection) != null);
    try std.testing.expect(item.hasEnchantment(.fortune) == null);

    // Damage bonus only from sharpness (3 * 1.25 = 3.75)
    try std.testing.expectApproxEqAbs(@as(f32, 3.75), item.getDamageBonus(), 0.001);
    // Protection bonus only from fire_protection (1 * 2.0 = 2.0)
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), item.getProtectionBonus(), 0.001);
}
