const std = @import("std");
const armor = @import("armor.zig");

pub const ArmorSlot = armor.ArmorSlot;

pub const TrimPattern = enum(u4) {
    sentry,
    dune,
    coast,
    wild,
    ward,
    eye,
    vex,
    tide,
    snout,
    rib,
    spire,
    wayfinder,
    shaper,
    silence,
    raiser,
    host,
};

pub const TrimMaterial = enum(u4) {
    iron,
    copper,
    gold,
    lapis,
    emerald,
    diamond,
    netherite,
    redstone,
    amethyst,
    quartz,

    pub fn color(self: TrimMaterial) [3]u8 {
        return switch (self) {
            .iron => .{ 196, 196, 196 },
            .copper => .{ 184, 115, 81 },
            .gold => .{ 249, 236, 79 },
            .lapis => .{ 31, 67, 140 },
            .emerald => .{ 17, 160, 54 },
            .diamond => .{ 110, 236, 222 },
            .netherite => .{ 68, 58, 59 },
            .redstone => .{ 151, 0, 0 },
            .amethyst => .{ 157, 100, 197 },
            .quartz => .{ 227, 218, 201 },
        };
    }
};

pub const ArmorTrim = struct {
    pattern: TrimPattern,
    material: TrimMaterial,
};

pub const TrimmedArmor = struct {
    slot: ArmorSlot,
    trim: ArmorTrim,

    pub fn getColorOverlay(self: TrimmedArmor) [3]u8 {
        return self.trim.material.color();
    }
};

pub fn applyTrim(armor_slot: ArmorSlot, trim: ArmorTrim) TrimmedArmor {
    return TrimmedArmor{
        .slot = armor_slot,
        .trim = trim,
    };
}

// ── Tests ───────────────────────────────────────────────────────────────────

test "all 16 trim patterns are valid" {
    const patterns = std.enums.values(TrimPattern);
    try std.testing.expectEqual(@as(usize, 16), patterns.len);
    for (patterns) |p| {
        try std.testing.expect(@tagName(p).len > 0);
    }
}

test "all 10 trim materials are valid" {
    const materials = std.enums.values(TrimMaterial);
    try std.testing.expectEqual(@as(usize, 10), materials.len);
    for (materials) |m| {
        try std.testing.expect(@tagName(m).len > 0);
    }
}

test "material colors return correct RGB values" {
    const iron_color = TrimMaterial.iron.color();
    try std.testing.expectEqual([3]u8{ 196, 196, 196 }, iron_color);

    const gold_color = TrimMaterial.gold.color();
    try std.testing.expectEqual([3]u8{ 249, 236, 79 }, gold_color);

    const diamond_color = TrimMaterial.diamond.color();
    try std.testing.expectEqual([3]u8{ 110, 236, 222 }, diamond_color);

    const netherite_color = TrimMaterial.netherite.color();
    try std.testing.expectEqual([3]u8{ 68, 58, 59 }, netherite_color);

    const redstone_color = TrimMaterial.redstone.color();
    try std.testing.expectEqual([3]u8{ 151, 0, 0 }, redstone_color);
}

test "each material produces a unique color" {
    const materials = std.enums.values(TrimMaterial);
    for (materials, 0..) |a, i| {
        for (materials[i + 1 ..]) |b| {
            const ca = a.color();
            const cb = b.color();
            const same = (ca[0] == cb[0]) and (ca[1] == cb[1]) and (ca[2] == cb[2]);
            try std.testing.expect(!same);
        }
    }
}

test "applyTrim produces correct TrimmedArmor" {
    const trim = ArmorTrim{
        .pattern = .coast,
        .material = .emerald,
    };
    const result = applyTrim(.leggings, trim);
    try std.testing.expectEqual(ArmorSlot.leggings, result.slot);
    try std.testing.expectEqual(TrimPattern.coast, result.trim.pattern);
    try std.testing.expectEqual(TrimMaterial.emerald, result.trim.material);
}

test "TrimmedArmor getColorOverlay matches material color" {
    const trim = ArmorTrim{
        .pattern = .silence,
        .material = .amethyst,
    };
    const trimmed = applyTrim(.chestplate, trim);
    const overlay = trimmed.getColorOverlay();
    const expected = TrimMaterial.amethyst.color();
    try std.testing.expectEqual(expected, overlay);
}

test "applyTrim works for all four armor slots" {
    const trim = ArmorTrim{ .pattern = .sentry, .material = .iron };
    const slots = std.enums.values(ArmorSlot);
    for (slots) |slot| {
        const result = applyTrim(slot, trim);
        try std.testing.expectEqual(slot, result.slot);
    }
}
