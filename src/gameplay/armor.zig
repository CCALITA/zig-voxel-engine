const std = @import("std");

pub const ArmorSlot = enum(u2) {
    helmet = 0,
    chestplate = 1,
    leggings = 2,
    boots = 3,
};

pub const ArmorMaterial = enum { leather, chainmail, iron, gold, diamond };

pub const ArmorDef = struct {
    material: ArmorMaterial,
    slot: ArmorSlot,
    defense: u8,
    max_durability: u16,
};

pub const ArmorInventory = struct {
    slots: [4]?ArmorInstance,

    pub fn init() ArmorInventory {
        return .{ .slots = .{ null, null, null, null } };
    }

    /// Equips an armor instance into the matching slot, returning the previously
    /// equipped piece (if any).
    pub fn equip(self: *ArmorInventory, armor: ArmorInstance) ?ArmorInstance {
        const idx = @intFromEnum(armor.def.slot);
        const old = self.slots[idx];
        self.slots[idx] = armor;
        return old;
    }

    /// Removes and returns the armor in the given slot, or null if empty.
    pub fn unequip(self: *ArmorInventory, slot: ArmorSlot) ?ArmorInstance {
        const idx = @intFromEnum(slot);
        const old = self.slots[idx];
        self.slots[idx] = null;
        return old;
    }

    /// Sum of defense values across all equipped pieces.
    pub fn getTotalDefense(self: *const ArmorInventory) u8 {
        var total: u8 = 0;
        for (self.slots) |maybe| {
            if (maybe) |a| {
                total += a.def.defense;
            }
        }
        return total;
    }

    /// Fraction of incoming damage absorbed: min(20, total_defense) / 25.
    pub fn getDamageReduction(self: *const ArmorInventory, damage: f32) f32 {
        const def: f32 = @floatFromInt(@min(@as(u8, 20), self.getTotalDefense()));
        return damage * def / 25.0;
    }
};

pub const ArmorInstance = struct {
    def: ArmorDef,
    durability: u16,

    pub fn init(material: ArmorMaterial, slot: ArmorSlot) ArmorInstance {
        const def = getArmorDef(material, slot);
        return .{ .def = def, .durability = def.max_durability };
    }

    /// Reduces durability by 1. Returns false if the piece is now broken (0).
    pub fn takeDamage(self: *ArmorInstance) bool {
        if (self.durability == 0) return false;
        self.durability -= 1;
        return self.durability > 0;
    }
};

// ──────────────────────────────────────────────────────────────────────────────
// Defense / durability tables (Minecraft values)
// ──────────────────────────────────────────────────────────────────────────────

// Defense indexed by [material][slot] (helmet, chestplate, leggings, boots)
const defense_table = [_][4]u8{
    .{ 1, 3, 2, 1 }, // leather
    .{ 2, 5, 4, 1 }, // chainmail
    .{ 2, 6, 5, 2 }, // iron
    .{ 2, 5, 3, 1 }, // gold
    .{ 3, 8, 6, 3 }, // diamond
};

// Max durability indexed the same way
const durability_table = [_][4]u16{
    .{ 55, 80, 75, 65 }, // leather
    .{ 165, 240, 225, 195 }, // chainmail
    .{ 165, 240, 225, 195 }, // iron
    .{ 77, 112, 105, 91 }, // gold
    .{ 363, 528, 495, 429 }, // diamond
};

pub fn getArmorDef(material: ArmorMaterial, slot: ArmorSlot) ArmorDef {
    const mat: usize = @intFromEnum(material);
    const sl: usize = @intFromEnum(slot);
    return .{
        .material = material,
        .slot = slot,
        .defense = defense_table[mat][sl],
        .max_durability = durability_table[mat][sl],
    };
}

// ──────────────────────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────────────────────

test "leather defense values" {
    try std.testing.expectEqual(@as(u8, 1), getArmorDef(.leather, .helmet).defense);
    try std.testing.expectEqual(@as(u8, 3), getArmorDef(.leather, .chestplate).defense);
    try std.testing.expectEqual(@as(u8, 2), getArmorDef(.leather, .leggings).defense);
    try std.testing.expectEqual(@as(u8, 1), getArmorDef(.leather, .boots).defense);
}

test "iron defense values" {
    try std.testing.expectEqual(@as(u8, 2), getArmorDef(.iron, .helmet).defense);
    try std.testing.expectEqual(@as(u8, 6), getArmorDef(.iron, .chestplate).defense);
    try std.testing.expectEqual(@as(u8, 5), getArmorDef(.iron, .leggings).defense);
    try std.testing.expectEqual(@as(u8, 2), getArmorDef(.iron, .boots).defense);
}

test "diamond defense values" {
    try std.testing.expectEqual(@as(u8, 3), getArmorDef(.diamond, .helmet).defense);
    try std.testing.expectEqual(@as(u8, 8), getArmorDef(.diamond, .chestplate).defense);
    try std.testing.expectEqual(@as(u8, 6), getArmorDef(.diamond, .leggings).defense);
    try std.testing.expectEqual(@as(u8, 3), getArmorDef(.diamond, .boots).defense);
}

test "gold defense values" {
    try std.testing.expectEqual(@as(u8, 2), getArmorDef(.gold, .helmet).defense);
    try std.testing.expectEqual(@as(u8, 5), getArmorDef(.gold, .chestplate).defense);
    try std.testing.expectEqual(@as(u8, 3), getArmorDef(.gold, .leggings).defense);
    try std.testing.expectEqual(@as(u8, 1), getArmorDef(.gold, .boots).defense);
}

test "chainmail defense values" {
    try std.testing.expectEqual(@as(u8, 2), getArmorDef(.chainmail, .helmet).defense);
    try std.testing.expectEqual(@as(u8, 5), getArmorDef(.chainmail, .chestplate).defense);
    try std.testing.expectEqual(@as(u8, 4), getArmorDef(.chainmail, .leggings).defense);
    try std.testing.expectEqual(@as(u8, 1), getArmorDef(.chainmail, .boots).defense);
}

test "full diamond set total defense" {
    var inv = ArmorInventory.init();
    inline for (std.meta.fields(ArmorSlot)) |f| {
        const slot: ArmorSlot = @enumFromInt(f.value);
        _ = inv.equip(ArmorInstance.init(.diamond, slot));
    }
    // 3 + 8 + 6 + 3 = 20
    try std.testing.expectEqual(@as(u8, 20), inv.getTotalDefense());
}

test "full leather set total defense" {
    var inv = ArmorInventory.init();
    inline for (std.meta.fields(ArmorSlot)) |f| {
        const slot: ArmorSlot = @enumFromInt(f.value);
        _ = inv.equip(ArmorInstance.init(.leather, slot));
    }
    // 1 + 3 + 2 + 1 = 7
    try std.testing.expectEqual(@as(u8, 7), inv.getTotalDefense());
}

test "damage reduction capped at 20 defense" {
    var inv = ArmorInventory.init();
    // Full diamond = 20 defense => reduction = 20/25 * damage
    inline for (std.meta.fields(ArmorSlot)) |f| {
        const slot: ArmorSlot = @enumFromInt(f.value);
        _ = inv.equip(ArmorInstance.init(.diamond, slot));
    }
    const reduction = inv.getDamageReduction(10.0);
    try std.testing.expectApproxEqAbs(@as(f32, 8.0), reduction, 0.001);
}

test "damage reduction for leather set" {
    var inv = ArmorInventory.init();
    inline for (std.meta.fields(ArmorSlot)) |f| {
        const slot: ArmorSlot = @enumFromInt(f.value);
        _ = inv.equip(ArmorInstance.init(.leather, slot));
    }
    // 7 defense => 7/25 * 10 = 2.8
    const reduction = inv.getDamageReduction(10.0);
    try std.testing.expectApproxEqAbs(@as(f32, 2.8), reduction, 0.001);
}

test "empty inventory gives zero reduction" {
    const inv = ArmorInventory.init();
    try std.testing.expectEqual(@as(u8, 0), inv.getTotalDefense());
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), inv.getDamageReduction(10.0), 0.001);
}

test "equip returns old piece" {
    var inv = ArmorInventory.init();
    const iron_helm = ArmorInstance.init(.iron, .helmet);
    const diamond_helm = ArmorInstance.init(.diamond, .helmet);

    // First equip: slot was empty
    const old1 = inv.equip(iron_helm);
    try std.testing.expect(old1 == null);

    // Second equip: returns the iron helmet
    const old2 = inv.equip(diamond_helm);
    try std.testing.expect(old2 != null);
    try std.testing.expectEqual(ArmorMaterial.iron, old2.?.def.material);
}

test "unequip returns piece and empties slot" {
    var inv = ArmorInventory.init();
    _ = inv.equip(ArmorInstance.init(.gold, .boots));

    const removed = inv.unequip(.boots);
    try std.testing.expect(removed != null);
    try std.testing.expectEqual(ArmorMaterial.gold, removed.?.def.material);

    // Slot is now empty
    try std.testing.expect(inv.unequip(.boots) == null);
}

test "unequip empty slot returns null" {
    var inv = ArmorInventory.init();
    try std.testing.expect(inv.unequip(.chestplate) == null);
}

test "durability starts at max" {
    const piece = ArmorInstance.init(.iron, .chestplate);
    try std.testing.expectEqual(@as(u16, 240), piece.durability);
}

test "takeDamage decrements durability" {
    var piece = ArmorInstance.init(.leather, .helmet);
    const initial = piece.durability;
    const alive = piece.takeDamage();
    try std.testing.expect(alive);
    try std.testing.expectEqual(initial - 1, piece.durability);
}

test "takeDamage returns false when broken" {
    var piece = ArmorInstance.init(.leather, .boots);
    piece.durability = 1;
    const alive = piece.takeDamage();
    try std.testing.expect(!alive);
    try std.testing.expectEqual(@as(u16, 0), piece.durability);
}

test "takeDamage on already broken piece returns false" {
    var piece = ArmorInstance.init(.iron, .leggings);
    piece.durability = 0;
    try std.testing.expect(!piece.takeDamage());
    try std.testing.expectEqual(@as(u16, 0), piece.durability);
}
