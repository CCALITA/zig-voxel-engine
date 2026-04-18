/// Decorative block features: flower placement, tall grass, mushrooms,
/// and other non-functional world decorations.
/// Used during world generation to place decoration features.

const std = @import("std");

pub const DecorationType = enum {
    flower_red,
    flower_yellow,
    tall_grass,
    fern,
    mushroom_red,
    mushroom_brown,
    dead_bush,
    sugar_cane,
    lily_pad,
};

pub const DecorationDef = struct {
    decoration_type: DecorationType,
    can_place_on_grass: bool,
    can_place_on_sand: bool,
    can_place_on_water: bool,
    light_requirement: u8, // minimum light level (0-15)
};

/// Get the placement rules for a decoration type.
pub fn getDef(dtype: DecorationType) DecorationDef {
    return switch (dtype) {
        .flower_red, .flower_yellow => .{
            .decoration_type = dtype,
            .can_place_on_grass = true,
            .can_place_on_sand = false,
            .can_place_on_water = false,
            .light_requirement = 8,
        },
        .tall_grass, .fern => .{
            .decoration_type = dtype,
            .can_place_on_grass = true,
            .can_place_on_sand = false,
            .can_place_on_water = false,
            .light_requirement = 4,
        },
        .mushroom_red, .mushroom_brown => .{
            .decoration_type = dtype,
            .can_place_on_grass = true,
            .can_place_on_sand = false,
            .can_place_on_water = false,
            .light_requirement = 0, // can grow in dark
        },
        .dead_bush => .{
            .decoration_type = dtype,
            .can_place_on_grass = false,
            .can_place_on_sand = true,
            .can_place_on_water = false,
            .light_requirement = 0,
        },
        .sugar_cane => .{
            .decoration_type = dtype,
            .can_place_on_grass = true,
            .can_place_on_sand = true,
            .can_place_on_water = false,
            .light_requirement = 4,
        },
        .lily_pad => .{
            .decoration_type = dtype,
            .can_place_on_grass = false,
            .can_place_on_sand = false,
            .can_place_on_water = true,
            .light_requirement = 4,
        },
    };
}

// ──────────────────────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────────────────────

test "flowers need grass and light" {
    const def = getDef(.flower_red);
    try std.testing.expect(def.can_place_on_grass);
    try std.testing.expect(!def.can_place_on_sand);
    try std.testing.expect(def.light_requirement >= 8);
}

test "mushrooms grow in dark" {
    const def = getDef(.mushroom_red);
    try std.testing.expectEqual(@as(u8, 0), def.light_requirement);
}

test "dead bush on sand only" {
    const def = getDef(.dead_bush);
    try std.testing.expect(!def.can_place_on_grass);
    try std.testing.expect(def.can_place_on_sand);
}

test "lily pad on water only" {
    const def = getDef(.lily_pad);
    try std.testing.expect(def.can_place_on_water);
    try std.testing.expect(!def.can_place_on_grass);
    try std.testing.expect(!def.can_place_on_sand);
}
