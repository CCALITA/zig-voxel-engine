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
pub const COAL_ORE: BlockId = 12;
pub const IRON_ORE: BlockId = 13;
pub const GOLD_ORE: BlockId = 14;
pub const DIAMOND_ORE: BlockId = 15;
pub const REDSTONE_ORE: BlockId = 16;
pub const GLASS: BlockId = 17;
pub const BRICK: BlockId = 18;
pub const OBSIDIAN: BlockId = 19;
pub const TNT: BlockId = 20;
pub const BOOKSHELF: BlockId = 21;
pub const MOSSY_COBBLESTONE: BlockId = 22;
pub const ICE: BlockId = 23;
pub const SNOW: BlockId = 24;
pub const CLAY: BlockId = 25;
pub const CACTUS: BlockId = 26;
pub const PUMPKIN: BlockId = 27;
pub const MELON: BlockId = 28;
pub const GLOWSTONE: BlockId = 29;
pub const NETHERRACK: BlockId = 30;
pub const SOUL_SAND: BlockId = 31;
pub const LAVA: BlockId = 32;
pub const REDSTONE_WIRE: BlockId = 33;
pub const REDSTONE_TORCH: BlockId = 34;
pub const LEVER: BlockId = 35;
pub const BUTTON: BlockId = 36;
pub const PISTON: BlockId = 37;
pub const REPEATER: BlockId = 38;
pub const FURNACE: BlockId = 39;
pub const DOOR: BlockId = 40;
pub const BED: BlockId = 41;
pub const LADDER: BlockId = 42;
pub const CHEST: BlockId = 43;
pub const TRAPDOOR: BlockId = 44;
pub const END_STONE: BlockId = 45;

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
const T_COAL_ORE: u16 = 13;
const T_IRON_ORE: u16 = 14;
const T_GOLD_ORE: u16 = 15;
const T_DIAMOND_ORE: u16 = 16;
const T_REDSTONE_ORE: u16 = 17;
const T_GLASS: u16 = 18;
const T_BRICK: u16 = 19;
const T_OBSIDIAN: u16 = 20;
const T_TNT_SIDE: u16 = 21;
const T_TNT_TOP: u16 = 22;
const T_BOOKSHELF: u16 = 23;
const T_MOSSY_COBBLE: u16 = 24;
const T_ICE: u16 = 25;
const T_SNOW: u16 = 26;
const T_CLAY: u16 = 27;
const T_CACTUS_SIDE: u16 = 28;
const T_CACTUS_TOP: u16 = 29;
const T_PUMPKIN_SIDE: u16 = 30;
const T_PUMPKIN_TOP: u16 = 31;
const T_MELON_SIDE: u16 = 32;
const T_MELON_TOP: u16 = 33;
const T_GLOWSTONE: u16 = 34;
const T_NETHERRACK: u16 = 35;
const T_SOUL_SAND: u16 = 36;
const T_LAVA: u16 = 37;
const T_REDSTONE_WIRE: u16 = 38;
const T_REDSTONE_TORCH: u16 = 39;
const T_LEVER: u16 = 40;
const T_BUTTON: u16 = 41;
const T_PISTON_SIDE: u16 = 42;
const T_PISTON_TOP: u16 = 43;
const T_REPEATER: u16 = 44;
const T_FURNACE_SIDE: u16 = 45;
const T_FURNACE_TOP: u16 = 46;
const T_DOOR: u16 = 47;
const T_BED_HEAD: u16 = 48;
const T_BED_FOOT: u16 = 49;
const T_LADDER: u16 = 50;
const T_CHEST_SIDE: u16 = 51;
const T_CHEST_TOP: u16 = 52;
const T_TRAPDOOR: u16 = 53;
const T_END_STONE: u16 = 54;

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
    .{ .name = "coal_ore", .tex = allFaces(T_COAL_ORE) }, // 12
    .{ .name = "iron_ore", .tex = allFaces(T_IRON_ORE) }, // 13
    .{ .name = "gold_ore", .tex = allFaces(T_GOLD_ORE) }, // 14
    .{ .name = "diamond_ore", .tex = allFaces(T_DIAMOND_ORE) }, // 15
    .{ .name = "redstone_ore", .tex = allFaces(T_REDSTONE_ORE) }, // 16
    .{ .name = "glass", .tex = allFaces(T_GLASS), .solid = false, .transparent = true }, // 17
    .{ .name = "brick", .tex = allFaces(T_BRICK) }, // 18
    .{ .name = "obsidian", .tex = allFaces(T_OBSIDIAN) }, // 19
    .{ .name = "tnt", .tex = topBottomSide(T_TNT_TOP, T_TNT_TOP, T_TNT_SIDE) }, // 20
    .{ .name = "bookshelf", .tex = topBottomSide(T_PLANKS, T_PLANKS, T_BOOKSHELF) }, // 21
    .{ .name = "mossy_cobblestone", .tex = allFaces(T_MOSSY_COBBLE) }, // 22
    .{ .name = "ice", .tex = allFaces(T_ICE), .transparent = true }, // 23
    .{ .name = "snow", .tex = allFaces(T_SNOW) }, // 24
    .{ .name = "clay", .tex = allFaces(T_CLAY) }, // 25
    .{ .name = "cactus", .tex = topBottomSide(T_CACTUS_TOP, T_CACTUS_TOP, T_CACTUS_SIDE) }, // 26
    .{ .name = "pumpkin", .tex = topBottomSide(T_PUMPKIN_TOP, T_PUMPKIN_TOP, T_PUMPKIN_SIDE) }, // 27
    .{ .name = "melon", .tex = topBottomSide(T_MELON_TOP, T_MELON_TOP, T_MELON_SIDE) }, // 28
    .{ .name = "glowstone", .tex = allFaces(T_GLOWSTONE) }, // 29
    .{ .name = "netherrack", .tex = allFaces(T_NETHERRACK) }, // 30
    .{ .name = "soul_sand", .tex = allFaces(T_SOUL_SAND) }, // 31
    .{ .name = "lava", .tex = allFaces(T_LAVA), .solid = false, .transparent = true }, // 32
    .{ .name = "redstone_wire", .tex = allFaces(T_REDSTONE_WIRE), .solid = false }, // 33
    .{ .name = "redstone_torch", .tex = allFaces(T_REDSTONE_TORCH), .solid = false }, // 34
    .{ .name = "lever", .tex = allFaces(T_LEVER), .solid = false }, // 35
    .{ .name = "button", .tex = allFaces(T_BUTTON), .solid = false }, // 36
    .{ .name = "piston", .tex = topBottomSide(T_PISTON_TOP, T_PISTON_TOP, T_PISTON_SIDE) }, // 37
    .{ .name = "repeater", .tex = allFaces(T_REPEATER), .solid = false }, // 38
    .{ .name = "furnace", .tex = topBottomSide(T_FURNACE_TOP, T_FURNACE_TOP, T_FURNACE_SIDE) }, // 39
    .{ .name = "door", .tex = allFaces(T_DOOR), .solid = false }, // 40
    .{ .name = "bed", .tex = topBottomSide(T_BED_HEAD, T_BED_FOOT, T_BED_FOOT), .solid = false }, // 41
    .{ .name = "ladder", .tex = allFaces(T_LADDER), .solid = false, .transparent = true }, // 42
    .{ .name = "chest", .tex = topBottomSide(T_CHEST_TOP, T_CHEST_TOP, T_CHEST_SIDE) }, // 43
    .{ .name = "trapdoor", .tex = allFaces(T_TRAPDOOR), .solid = false }, // 44
    .{ .name = "end_stone", .tex = allFaces(T_END_STONE) }, // 45
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

test "block registry has 46 entries" {
    try std.testing.expectEqual(@as(usize, 46), BLOCKS.len);
}

test "glass is not solid but is transparent" {
    try std.testing.expect(!isSolid(GLASS));
    try std.testing.expect(isTransparent(GLASS));
}

test "ice is transparent" {
    try std.testing.expect(isTransparent(ICE));
}

test "ore blocks are solid" {
    try std.testing.expect(isSolid(COAL_ORE));
    try std.testing.expect(isSolid(IRON_ORE));
    try std.testing.expect(isSolid(GOLD_ORE));
    try std.testing.expect(isSolid(DIAMOND_ORE));
    try std.testing.expect(isSolid(REDSTONE_ORE));
}

test "tnt has different top and side textures" {
    const tnt = get(TNT);
    try std.testing.expect(tnt.tex[@intFromEnum(Face.top)] != tnt.tex[@intFromEnum(Face.north)]);
}

test "bookshelf uses planks for top and bottom" {
    const bs = get(BOOKSHELF);
    const planks_tex = get(OAK_PLANKS).tex[0];
    try std.testing.expectEqual(planks_tex, bs.tex[@intFromEnum(Face.top)]);
    try std.testing.expectEqual(planks_tex, bs.tex[@intFromEnum(Face.bottom)]);
}

test "all block IDs map to correct names" {
    try std.testing.expectEqualStrings("coal_ore", get(COAL_ORE).name);
    try std.testing.expectEqualStrings("soul_sand", get(SOUL_SAND).name);
    try std.testing.expectEqualStrings("glowstone", get(GLOWSTONE).name);
}

test "texture indices fit in u6" {
    for (BLOCKS) |def| {
        for (def.tex) |t| {
            try std.testing.expect(t < 64);
        }
    }
}

test "redstone blocks are not solid" {
    try std.testing.expect(!isSolid(REDSTONE_WIRE));
    try std.testing.expect(!isSolid(REDSTONE_TORCH));
    try std.testing.expect(!isSolid(LEVER));
    try std.testing.expect(!isSolid(BUTTON));
    try std.testing.expect(!isSolid(REPEATER));
}

test "piston is solid" {
    try std.testing.expect(isSolid(PISTON));
}
