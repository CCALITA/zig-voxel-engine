/// Crafting station types: crafting table, smithing table, cartography table, loom, stonecutter.
const std = @import("std");

pub const StationType = enum {
    crafting_table,
    smithing_table,
    cartography_table,
    loom,
    stonecutter,
    grindstone,
};

pub const StationDef = struct {
    name: []const u8,
    grid_width: u8,
    grid_height: u8,
    has_fuel_slot: bool,
};

pub fn getDef(station: StationType) StationDef {
    return switch (station) {
        .crafting_table => .{ .name = "Crafting Table", .grid_width = 3, .grid_height = 3, .has_fuel_slot = false },
        .smithing_table => .{ .name = "Smithing Table", .grid_width = 2, .grid_height = 1, .has_fuel_slot = false },
        .cartography_table => .{ .name = "Cartography Table", .grid_width = 2, .grid_height = 1, .has_fuel_slot = false },
        .loom => .{ .name = "Loom", .grid_width = 1, .grid_height = 3, .has_fuel_slot = false },
        .stonecutter => .{ .name = "Stonecutter", .grid_width = 1, .grid_height = 1, .has_fuel_slot = false },
        .grindstone => .{ .name = "Grindstone", .grid_width = 2, .grid_height = 1, .has_fuel_slot = false },
    };
}

test "crafting table is 3x3" {
    const def = getDef(.crafting_table);
    try std.testing.expectEqual(@as(u8, 3), def.grid_width);
    try std.testing.expectEqual(@as(u8, 3), def.grid_height);
}

test "stonecutter is 1x1" {
    const def = getDef(.stonecutter);
    try std.testing.expectEqual(@as(u8, 1), def.grid_width);
}

test "no station has fuel slot" {
    inline for (std.meta.fields(StationType)) |f| {
        const station: StationType = @enumFromInt(f.value);
        const def = getDef(station);
        try std.testing.expect(!def.has_fuel_slot);
    }
}
