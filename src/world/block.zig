/// Block type definitions and registry.
/// Each block type has an ID and face texture indices into the texture atlas.

pub const BlockId = u8;

pub const Face = enum(u3) {
    north = 0, // -Z
    south = 1, // +Z
    east = 2, // +X
    west = 3, // -X
    top = 4, // +Y
    bottom = 5, // -Y
};

pub const BlockDef = struct {
    name: []const u8,
    /// Texture index per face (indexes into the atlas array layers)
    tex: [6]u16,
    solid: bool = true,
    transparent: bool = false,
};

// Block IDs
pub const AIR: BlockId = 0;
pub const STONE: BlockId = 1;
pub const DIRT: BlockId = 2;
pub const GRASS: BlockId = 3;
pub const COBBLESTONE: BlockId = 4;
pub const OAK_PLANKS: BlockId = 5;
pub const SAND: BlockId = 6;
pub const GRAVEL: BlockId = 7;
pub const OAK_LOG: BlockId = 8;
pub const OAK_LEAVES: BlockId = 9;
pub const WATER: BlockId = 10;
pub const BEDROCK: BlockId = 11;

// Texture atlas indices (placeholder -- will map to real textures later)
const T_STONE: u16 = 0;
const T_DIRT: u16 = 1;
const T_GRASS_TOP: u16 = 2;
const T_GRASS_SIDE: u16 = 3;
const T_COBBLE: u16 = 4;
const T_PLANKS: u16 = 5;
const T_SAND: u16 = 6;
const T_GRAVEL: u16 = 7;
const T_LOG_SIDE: u16 = 8;
const T_LOG_TOP: u16 = 9;
const T_LEAVES: u16 = 10;
const T_WATER: u16 = 11;
const T_BEDROCK: u16 = 12;

fn allFaces(tex: u16) [6]u16 {
    return .{ tex, tex, tex, tex, tex, tex };
}

fn topBottomSide(top: u16, bottom: u16, side: u16) [6]u16 {
    return .{ side, side, side, side, top, bottom };
}

/// Registry: indexed by BlockId
pub const BLOCKS = [_]BlockDef{
    .{ .name = "air", .tex = allFaces(0), .solid = false }, // 0
    .{ .name = "stone", .tex = allFaces(T_STONE) }, // 1
    .{ .name = "dirt", .tex = allFaces(T_DIRT) }, // 2
    .{ .name = "grass", .tex = topBottomSide(T_GRASS_TOP, T_DIRT, T_GRASS_SIDE) }, // 3
    .{ .name = "cobblestone", .tex = allFaces(T_COBBLE) }, // 4
    .{ .name = "oak_planks", .tex = allFaces(T_PLANKS) }, // 5
    .{ .name = "sand", .tex = allFaces(T_SAND) }, // 6
    .{ .name = "gravel", .tex = allFaces(T_GRAVEL) }, // 7
    .{ .name = "oak_log", .tex = topBottomSide(T_LOG_TOP, T_LOG_TOP, T_LOG_SIDE) }, // 8
    .{ .name = "oak_leaves", .tex = allFaces(T_LEAVES), .transparent = true }, // 9
    .{ .name = "water", .tex = allFaces(T_WATER), .solid = false, .transparent = true }, // 10
    .{ .name = "bedrock", .tex = allFaces(T_BEDROCK) }, // 11
};

pub fn get(id: BlockId) BlockDef {
    if (id < BLOCKS.len) return BLOCKS[id];
    return BLOCKS[0]; // fallback to air
}

pub fn isSolid(id: BlockId) bool {
    return get(id).solid;
}

pub fn isTransparent(id: BlockId) bool {
    return get(id).transparent;
}

const std = @import("std");

test "air is not solid" {
    try std.testing.expect(!isSolid(AIR));
}

test "stone is solid" {
    try std.testing.expect(isSolid(STONE));
}

test "grass has different top texture" {
    const grass = get(GRASS);
    try std.testing.expect(grass.tex[@intFromEnum(Face.top)] != grass.tex[@intFromEnum(Face.north)]);
}
