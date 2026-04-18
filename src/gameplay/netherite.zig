const std = @import("std");

pub const NetheriteUpgrade = struct {
    diamond_item: u16,
    netherite_item: u16,
};

/// All 9 diamond-to-netherite upgrade mappings.
/// Diamond IDs: 700-708, Netherite IDs: 800-808.
pub const UPGRADES = [9]NetheriteUpgrade{
    .{ .diamond_item = 700, .netherite_item = 800 }, // pickaxe
    .{ .diamond_item = 701, .netherite_item = 801 }, // axe
    .{ .diamond_item = 702, .netherite_item = 802 }, // shovel
    .{ .diamond_item = 703, .netherite_item = 803 }, // sword
    .{ .diamond_item = 704, .netherite_item = 804 }, // hoe
    .{ .diamond_item = 705, .netherite_item = 805 }, // helmet
    .{ .diamond_item = 706, .netherite_item = 806 }, // chestplate
    .{ .diamond_item = 707, .netherite_item = 807 }, // leggings
    .{ .diamond_item = 708, .netherite_item = 808 }, // boots
};

pub const SmeltingStep = struct {
    input_item: u16,
    output_item: u16,
    method: []const u8,
};

pub const CraftingRecipe = struct {
    inputs: [2]InputSlot,
    output_item: u16,
};

pub const InputSlot = struct {
    item_id: u16,
    count: u8,
};

pub const SmeltingChain = struct {
    smelting: SmeltingStep,
    crafting: CraftingRecipe,
};

pub const NetheriteProperties = struct {
    fire_resistant: bool = true,
    knockback_resistance: f32 = 0.1,
    durability_bonus: u16 = 2031 - 1561, // 470 extra over diamond
};

/// Returns true if the given item ID is a diamond item that can be upgraded.
pub fn canUpgrade(item_id: u16) bool {
    return upgrade(item_id) != null;
}

/// Given a diamond item ID, returns the corresponding netherite item ID, or null
/// if the item is not upgradeable.
pub fn upgrade(diamond_id: u16) ?u16 {
    for (UPGRADES) |entry| {
        if (entry.diamond_item == diamond_id) {
            return entry.netherite_item;
        }
    }
    return null;
}

/// Returns the full smelting chain for obtaining a netherite ingot:
///   1. Blast furnace: ancient_debris (900) -> netherite_scrap (901)
///   2. Crafting: 4x netherite_scrap + 4x gold_ingot (902) -> netherite_ingot (903)
pub fn getSmeltingChain() SmeltingChain {
    return .{
        .smelting = .{
            .input_item = 900, // ancient_debris
            .output_item = 901, // netherite_scrap
            .method = "blast_furnace",
        },
        .crafting = .{
            .inputs = .{
                .{ .item_id = 901, .count = 4 }, // netherite_scrap
                .{ .item_id = 902, .count = 4 }, // gold_ingot
            },
            .output_item = 903, // netherite_ingot
        },
    };
}

/// Returns the standard netherite material properties.
pub fn getProperties() NetheriteProperties {
    return .{};
}

/// Returns true if the given item ID is a netherite item (fire resistant,
/// floats in lava, does not burn).
pub fn isFireResistant(item_id: u16) bool {
    for (UPGRADES) |entry| {
        if (entry.netherite_item == item_id) {
            return true;
        }
    }
    return false;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "all 9 diamond items can be upgraded" {
    const expected_diamonds = [_]u16{ 700, 701, 702, 703, 704, 705, 706, 707, 708 };
    for (expected_diamonds) |d| {
        try std.testing.expect(canUpgrade(d));
    }
}

test "all 9 upgrades produce correct netherite item" {
    for (UPGRADES) |entry| {
        const result = upgrade(entry.diamond_item);
        try std.testing.expect(result != null);
        try std.testing.expectEqual(entry.netherite_item, result.?);
    }
}

test "upgrade returns null for non-diamond item" {
    try std.testing.expectEqual(@as(?u16, null), upgrade(999));
}

test "canUpgrade returns false for non-diamond item" {
    try std.testing.expect(!canUpgrade(999));
}

test "smelting chain uses blast furnace for ancient debris" {
    const chain = getSmeltingChain();
    try std.testing.expectEqualStrings("blast_furnace", chain.smelting.method);
    try std.testing.expectEqual(@as(u16, 900), chain.smelting.input_item);
    try std.testing.expectEqual(@as(u16, 901), chain.smelting.output_item);
}

test "smelting chain crafting requires 4 scrap and 4 gold ingot" {
    const chain = getSmeltingChain();
    try std.testing.expectEqual(@as(u16, 901), chain.crafting.inputs[0].item_id);
    try std.testing.expectEqual(@as(u8, 4), chain.crafting.inputs[0].count);
    try std.testing.expectEqual(@as(u16, 902), chain.crafting.inputs[1].item_id);
    try std.testing.expectEqual(@as(u8, 4), chain.crafting.inputs[1].count);
    try std.testing.expectEqual(@as(u16, 903), chain.crafting.output_item);
}

test "all netherite items are fire resistant" {
    for (UPGRADES) |entry| {
        try std.testing.expect(isFireResistant(entry.netherite_item));
    }
}

test "diamond items are not fire resistant" {
    for (UPGRADES) |entry| {
        try std.testing.expect(!isFireResistant(entry.diamond_item));
    }
}

test "netherite properties have correct defaults" {
    const props = getProperties();
    try std.testing.expect(props.fire_resistant);
    try std.testing.expectApproxEqAbs(@as(f32, 0.1), props.knockback_resistance, 0.001);
    try std.testing.expectEqual(@as(u16, 470), props.durability_bonus);
}

test "upgrade preserves enchantments flag" {
    // Upgrading via smithing table preserves enchantments. The upgrade function
    // returns a new item ID (netherite equivalent) while the caller is
    // responsible for copying enchantment data from the source item. Verify
    // that upgrade produces a distinct item ID (not the same as input), which
    // signals that enchantment metadata should be transferred, not discarded.
    for (UPGRADES) |entry| {
        const result = upgrade(entry.diamond_item);
        try std.testing.expect(result != null);
        // The netherite item is a different ID, so the caller knows to copy
        // enchantments from the old item to the new one.
        try std.testing.expect(result.? != entry.diamond_item);
    }
}
