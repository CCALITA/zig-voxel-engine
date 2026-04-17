/// Dimension definitions for the Minecraft clone.
/// Each dimension type has properties controlling sky color, fog, ceiling,
/// ambient light, and gameplay behavior (bed works, day/night cycle).
const std = @import("std");

pub const DimensionType = enum {
    overworld,
    nether,
    the_end,
};

pub const DimensionDef = struct {
    sky_color: [3]f32,
    fog_color: [3]f32,
    has_ceiling: bool,
    ceiling_height: u8,
    floor_height: u8,
    ambient_light: f32,
    bed_works: bool,
    /// Whether this dimension has a day/night cycle.
    natural: bool,
};

const overworld_def = DimensionDef{
    .sky_color = .{ 0.47, 0.65, 1.0 },
    .fog_color = .{ 0.75, 0.87, 1.0 },
    .has_ceiling = false,
    .ceiling_height = 0,
    .floor_height = 0,
    .ambient_light = 0.0,
    .bed_works = true,
    .natural = true,
};

const nether_def = DimensionDef{
    .sky_color = .{ 0.15, 0.05, 0.05 },
    .fog_color = .{ 0.2, 0.03, 0.03 },
    .has_ceiling = true,
    .ceiling_height = 128,
    .floor_height = 0,
    .ambient_light = 0.1,
    .bed_works = false,
    .natural = false,
};

const the_end_def = DimensionDef{
    .sky_color = .{ 0.02, 0.0, 0.05 },
    .fog_color = .{ 0.01, 0.0, 0.03 },
    .has_ceiling = false,
    .ceiling_height = 0,
    .floor_height = 0,
    .ambient_light = 0.1,
    .bed_works = false,
    .natural = false,
};

pub fn getDef(dim: DimensionType) DimensionDef {
    return switch (dim) {
        .overworld => overworld_def,
        .nether => nether_def,
        .the_end => the_end_def,
    };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "overworld has correct sky color" {
    const def = getDef(.overworld);
    try std.testing.expectApproxEqAbs(@as(f32, 0.47), def.sky_color[0], 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.65), def.sky_color[1], 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), def.sky_color[2], 0.01);
}

test "overworld properties" {
    const def = getDef(.overworld);
    try std.testing.expect(!def.has_ceiling);
    try std.testing.expect(def.bed_works);
    try std.testing.expect(def.natural);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), def.ambient_light, 0.001);
}

test "nether has ceiling at y=128" {
    const def = getDef(.nether);
    try std.testing.expect(def.has_ceiling);
    try std.testing.expectEqual(@as(u8, 128), def.ceiling_height);
    try std.testing.expectEqual(@as(u8, 0), def.floor_height);
}

test "nether has dark red sky and red fog" {
    const def = getDef(.nether);
    try std.testing.expectApproxEqAbs(@as(f32, 0.15), def.sky_color[0], 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.05), def.sky_color[1], 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.05), def.sky_color[2], 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.2), def.fog_color[0], 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.03), def.fog_color[1], 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.03), def.fog_color[2], 0.01);
}

test "nether bed explodes and no day/night" {
    const def = getDef(.nether);
    try std.testing.expect(!def.bed_works);
    try std.testing.expect(!def.natural);
    try std.testing.expectApproxEqAbs(@as(f32, 0.1), def.ambient_light, 0.001);
}

test "the end has dark purple sky" {
    const def = getDef(.the_end);
    try std.testing.expectApproxEqAbs(@as(f32, 0.02), def.sky_color[0], 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), def.sky_color[1], 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.05), def.sky_color[2], 0.01);
}

test "the end properties" {
    const def = getDef(.the_end);
    try std.testing.expect(!def.has_ceiling);
    try std.testing.expect(!def.bed_works);
    try std.testing.expect(!def.natural);
    try std.testing.expectApproxEqAbs(@as(f32, 0.1), def.ambient_light, 0.001);
}

test "all dimension types return valid definitions" {
    const types = [_]DimensionType{ .overworld, .nether, .the_end };
    for (types) |dim_type| {
        const def = getDef(dim_type);
        // Sky and fog colors must be in [0, 1]
        for (def.sky_color) |c| {
            try std.testing.expect(c >= 0.0 and c <= 1.0);
        }
        for (def.fog_color) |c| {
            try std.testing.expect(c >= 0.0 and c <= 1.0);
        }
        // Ambient light in [0, 1]
        try std.testing.expect(def.ambient_light >= 0.0 and def.ambient_light <= 1.0);
    }
}
