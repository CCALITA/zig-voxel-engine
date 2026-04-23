/// Station router — maps block IDs to station UI actions.
/// Given a block ID from a player interaction, returns the corresponding
/// station action (crafting table, furnace, anvil, etc.) or null if the
/// block does not open a station UI.

const std = @import("std");

// ── Station action enum ────────────────────────────────────────────────

pub const StationAction = enum(u8) {
    open_crafting_3x3,
    open_furnace,
    open_smoker,
    open_blast_furnace,
    open_anvil,
    open_stonecutter,
    open_brewing,
    open_smithing,
    open_grindstone,
    open_loom,
    open_cartography,
    open_chest,
    open_barrel,
    open_ender_chest,
    open_enchanting,
};

// ── Block IDs ──────────────────────────────────────────────────────────

const BlockId = struct {
    const crafting_table: u16 = 110;
    const furnace: u16 = 39;
    const smoker: u16 = 99;
    const blast_furnace: u16 = 100;
    const anvil: u16 = 46;
    const stonecutter: u16 = 103;
    const brewing_stand: u16 = 48;
    const smithing_table: u16 = 104;
    const grindstone: u16 = 102;
    const loom: u16 = 105;
    const cartography_table: u16 = 106;
    const chest: u16 = 43;
    const barrel: u16 = 101;
    const ender_chest: u16 = 109;
    const enchanting_table: u16 = 47;
};

// ── Public API ─────────────────────────────────────────────────────────

/// Given a block ID, returns the station action to perform, or null if
/// the block does not correspond to any station UI.
pub fn routeBlockInteraction(block_id: u16) ?StationAction {
    return switch (block_id) {
        BlockId.crafting_table => .open_crafting_3x3,
        BlockId.furnace => .open_furnace,
        BlockId.smoker => .open_smoker,
        BlockId.blast_furnace => .open_blast_furnace,
        BlockId.anvil => .open_anvil,
        BlockId.stonecutter => .open_stonecutter,
        BlockId.brewing_stand => .open_brewing,
        BlockId.smithing_table => .open_smithing,
        BlockId.grindstone => .open_grindstone,
        BlockId.loom => .open_loom,
        BlockId.cartography_table => .open_cartography,
        BlockId.chest => .open_chest,
        BlockId.barrel => .open_barrel,
        BlockId.ender_chest => .open_ender_chest,
        BlockId.enchanting_table => .open_enchanting,
        else => null,
    };
}

// ── Tests ──────────────────────────────────────────────────────────────

test "crafting table routes to open_crafting_3x3" {
    try std.testing.expectEqual(StationAction.open_crafting_3x3, routeBlockInteraction(110).?);
}

test "furnace routes to open_furnace" {
    try std.testing.expectEqual(StationAction.open_furnace, routeBlockInteraction(39).?);
}

test "smoker routes to open_smoker" {
    try std.testing.expectEqual(StationAction.open_smoker, routeBlockInteraction(99).?);
}

test "blast furnace routes to open_blast_furnace" {
    try std.testing.expectEqual(StationAction.open_blast_furnace, routeBlockInteraction(100).?);
}

test "anvil routes to open_anvil" {
    try std.testing.expectEqual(StationAction.open_anvil, routeBlockInteraction(46).?);
}

test "stonecutter routes to open_stonecutter" {
    try std.testing.expectEqual(StationAction.open_stonecutter, routeBlockInteraction(103).?);
}

test "brewing stand routes to open_brewing" {
    try std.testing.expectEqual(StationAction.open_brewing, routeBlockInteraction(48).?);
}

test "smithing table routes to open_smithing" {
    try std.testing.expectEqual(StationAction.open_smithing, routeBlockInteraction(104).?);
}

test "grindstone routes to open_grindstone" {
    try std.testing.expectEqual(StationAction.open_grindstone, routeBlockInteraction(102).?);
}

test "loom routes to open_loom" {
    try std.testing.expectEqual(StationAction.open_loom, routeBlockInteraction(105).?);
}

test "cartography table routes to open_cartography" {
    try std.testing.expectEqual(StationAction.open_cartography, routeBlockInteraction(106).?);
}

test "chest routes to open_chest" {
    try std.testing.expectEqual(StationAction.open_chest, routeBlockInteraction(43).?);
}

test "barrel routes to open_barrel" {
    try std.testing.expectEqual(StationAction.open_barrel, routeBlockInteraction(101).?);
}

test "ender chest routes to open_ender_chest" {
    try std.testing.expectEqual(StationAction.open_ender_chest, routeBlockInteraction(109).?);
}

test "enchanting table routes to open_enchanting" {
    try std.testing.expectEqual(StationAction.open_enchanting, routeBlockInteraction(47).?);
}

test "unknown block returns null" {
    try std.testing.expectEqual(@as(?StationAction, null), routeBlockInteraction(0));
}

test "block id 1 (stone) returns null" {
    try std.testing.expectEqual(@as(?StationAction, null), routeBlockInteraction(1));
}

test "max u16 block id returns null" {
    try std.testing.expectEqual(@as(?StationAction, null), routeBlockInteraction(std.math.maxInt(u16)));
}

test "adjacent block id 111 returns null" {
    try std.testing.expectEqual(@as(?StationAction, null), routeBlockInteraction(111));
}

test "adjacent block id 38 returns null" {
    try std.testing.expectEqual(@as(?StationAction, null), routeBlockInteraction(38));
}

test "StationAction enum values are distinct" {
    const actions = [_]StationAction{
        .open_crafting_3x3,
        .open_furnace,
        .open_smoker,
        .open_blast_furnace,
        .open_anvil,
        .open_stonecutter,
        .open_brewing,
        .open_smithing,
        .open_grindstone,
        .open_loom,
        .open_cartography,
        .open_chest,
        .open_barrel,
        .open_ender_chest,
        .open_enchanting,
    };
    for (actions, 0..) |a, i| {
        for (actions, 0..) |b, j| {
            if (i != j) {
                try std.testing.expect(@intFromEnum(a) != @intFromEnum(b));
            }
        }
    }
}

test "all routing table entries produce a result" {
    const expected_ids = [_]u16{ 110, 39, 99, 100, 46, 103, 48, 104, 102, 105, 106, 43, 101, 109, 47 };
    for (expected_ids) |id| {
        try std.testing.expect(routeBlockInteraction(id) != null);
    }
}
