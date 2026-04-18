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

// -- Mechanical / interactive blocks --
pub const ANVIL: BlockId = 46;
pub const BEACON: BlockId = 47;
pub const BREWING_STAND: BlockId = 48;
pub const JUKEBOX: BlockId = 49;
pub const NOTE_BLOCK: BlockId = 50;

// -- Pistons --
pub const PISTON_BASE: BlockId = 51;
pub const STICKY_PISTON_BASE: BlockId = 52;
pub const PISTON_HEAD: BlockId = 53;

// -- Redstone containers --
pub const HOPPER: BlockId = 54;
pub const DROPPER: BlockId = 55;
pub const DISPENSER: BlockId = 56;

// -- Enchanting / End --
pub const ENCHANTING_TABLE: BlockId = 57;
pub const END_PORTAL_FRAME: BlockId = 58;
pub const END_PORTAL: BlockId = 59;

// -- Rails --
pub const RAIL: BlockId = 60;
pub const POWERED_RAIL: BlockId = 61;
pub const DETECTOR_RAIL: BlockId = 62;
pub const ACTIVATOR_RAIL: BlockId = 63;

// -- Farming --
pub const FARMLAND: BlockId = 64;
pub const WHEAT_CROP: BlockId = 65;
pub const CARROTS_CROP: BlockId = 66;
pub const POTATOES_CROP: BlockId = 67;

// -- Misc solid --
pub const MELON_BLOCK: BlockId = 68;
pub const JACK_O_LANTERN: BlockId = 69;
pub const HAY_BALE: BlockId = 70;

// -- Wool (16 colors) --
pub const WHITE_WOOL: BlockId = 71;
pub const ORANGE_WOOL: BlockId = 72;
pub const MAGENTA_WOOL: BlockId = 73;
pub const LIGHT_BLUE_WOOL: BlockId = 74;
pub const YELLOW_WOOL: BlockId = 75;
pub const LIME_WOOL: BlockId = 76;
pub const PINK_WOOL: BlockId = 77;
pub const GRAY_WOOL: BlockId = 78;
pub const LIGHT_GRAY_WOOL: BlockId = 79;
pub const CYAN_WOOL: BlockId = 80;
pub const PURPLE_WOOL: BlockId = 81;
pub const BLUE_WOOL: BlockId = 82;
pub const BROWN_WOOL: BlockId = 83;
pub const GREEN_WOOL: BlockId = 84;
pub const RED_WOOL: BlockId = 85;
pub const BLACK_WOOL: BlockId = 86;

// -- Terracotta (4 representative colors) --
pub const WHITE_TERRACOTTA: BlockId = 87;
pub const ORANGE_TERRACOTTA: BlockId = 88;
pub const RED_TERRACOTTA: BlockId = 89;
pub const BLACK_TERRACOTTA: BlockId = 90;

// -- Concrete (4 representative colors) --
pub const WHITE_CONCRETE: BlockId = 91;
pub const ORANGE_CONCRETE: BlockId = 92;
pub const RED_CONCRETE: BlockId = 93;
pub const BLACK_CONCRETE: BlockId = 94;

// -- Copper (4 oxidation stages) --
pub const COPPER_BLOCK: BlockId = 95;
pub const EXPOSED_COPPER: BlockId = 96;
pub const WEATHERED_COPPER: BlockId = 97;
pub const OXIDIZED_COPPER: BlockId = 98;

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

// -- New texture indices --
const T_ANVIL_SIDE: u16 = 55;
const T_ANVIL_TOP: u16 = 56;
const T_BEACON: u16 = 57;
const T_BREWING_STAND: u16 = 58;
const T_JUKEBOX_SIDE: u16 = 59;
const T_JUKEBOX_TOP: u16 = 60;
const T_NOTE_BLOCK: u16 = 61;
const T_PISTON_BASE_SIDE: u16 = 62;
const T_PISTON_BASE_TOP: u16 = 63;
const T_PISTON_BASE_BOTTOM: u16 = 64;
const T_STICKY_PISTON_TOP: u16 = 65;
const T_PISTON_HEAD_FACE: u16 = 66;
const T_PISTON_HEAD_SIDE: u16 = 67;
const T_HOPPER_SIDE: u16 = 68;
const T_HOPPER_TOP: u16 = 69;
const T_DROPPER_FRONT: u16 = 70;
const T_DROPPER_SIDE: u16 = 71;
const T_DISPENSER_FRONT: u16 = 72;
const T_DISPENSER_SIDE: u16 = 73;
const T_ENCHANTING_TABLE_TOP: u16 = 74;
const T_ENCHANTING_TABLE_SIDE: u16 = 75;
const T_ENCHANTING_TABLE_BOTTOM: u16 = 76;
const T_END_PORTAL_FRAME_SIDE: u16 = 77;
const T_END_PORTAL_FRAME_TOP: u16 = 78;
const T_END_PORTAL: u16 = 79;
const T_RAIL: u16 = 80;
const T_POWERED_RAIL: u16 = 81;
const T_DETECTOR_RAIL: u16 = 82;
const T_ACTIVATOR_RAIL: u16 = 83;
const T_FARMLAND_TOP: u16 = 84;
const T_FARMLAND_SIDE: u16 = 85;
const T_WHEAT: u16 = 86;
const T_CARROTS: u16 = 87;
const T_POTATOES: u16 = 88;
const T_MELON_BLOCK_SIDE: u16 = 89;
const T_MELON_BLOCK_TOP: u16 = 90;
const T_JACK_O_LANTERN_FRONT: u16 = 91;
const T_JACK_O_LANTERN_SIDE: u16 = 92;
const T_JACK_O_LANTERN_TOP: u16 = 93;
const T_HAY_BALE_SIDE: u16 = 94;
const T_HAY_BALE_TOP: u16 = 95;
const T_WHITE_WOOL: u16 = 96;
const T_ORANGE_WOOL: u16 = 97;
const T_MAGENTA_WOOL: u16 = 98;
const T_LIGHT_BLUE_WOOL: u16 = 99;
const T_YELLOW_WOOL: u16 = 100;
const T_LIME_WOOL: u16 = 101;
const T_PINK_WOOL: u16 = 102;
const T_GRAY_WOOL: u16 = 103;
const T_LIGHT_GRAY_WOOL: u16 = 104;
const T_CYAN_WOOL: u16 = 105;
const T_PURPLE_WOOL: u16 = 106;
const T_BLUE_WOOL: u16 = 107;
const T_BROWN_WOOL: u16 = 108;
const T_GREEN_WOOL: u16 = 109;
const T_RED_WOOL: u16 = 110;
const T_BLACK_WOOL: u16 = 111;
const T_WHITE_TERRACOTTA: u16 = 112;
const T_ORANGE_TERRACOTTA: u16 = 113;
const T_RED_TERRACOTTA: u16 = 114;
const T_BLACK_TERRACOTTA: u16 = 115;
const T_WHITE_CONCRETE: u16 = 116;
const T_ORANGE_CONCRETE: u16 = 117;
const T_RED_CONCRETE: u16 = 118;
const T_BLACK_CONCRETE: u16 = 119;
const T_COPPER_BLOCK: u16 = 120;
const T_EXPOSED_COPPER: u16 = 121;
const T_WEATHERED_COPPER: u16 = 122;
const T_OXIDIZED_COPPER: u16 = 123;

fn allFaces(tex: u16) [6]u16 {
    return .{ tex, tex, tex, tex, tex, tex };
}

fn topBottomSide(top: u16, bottom: u16, side: u16) [6]u16 {
    return .{ side, side, side, side, top, bottom };
}

/// North face is `front`, all other faces are `rest`.
fn frontRest(front: u16, rest: u16) [6]u16 {
    return .{ front, rest, rest, rest, rest, rest };
}

/// North face is `front`, top/bottom distinct, remaining sides shared.
fn frontTopBottomSide(front: u16, top: u16, bottom: u16, side: u16) [6]u16 {
    return .{ front, side, side, side, top, bottom };
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

    // -- Mechanical / interactive --
    .{ .name = "anvil", .tex = topBottomSide(T_ANVIL_TOP, T_ANVIL_TOP, T_ANVIL_SIDE) }, // 46
    .{ .name = "beacon", .tex = allFaces(T_BEACON), .transparent = true }, // 47
    .{ .name = "brewing_stand", .tex = allFaces(T_BREWING_STAND), .solid = false }, // 48
    .{ .name = "jukebox", .tex = topBottomSide(T_JUKEBOX_TOP, T_JUKEBOX_SIDE, T_JUKEBOX_SIDE) }, // 49
    .{ .name = "note_block", .tex = allFaces(T_NOTE_BLOCK) }, // 50

    // -- Pistons --
    .{ .name = "piston_base", .tex = topBottomSide(T_PISTON_BASE_TOP, T_PISTON_BASE_BOTTOM, T_PISTON_BASE_SIDE) }, // 51
    .{ .name = "sticky_piston_base", .tex = topBottomSide(T_STICKY_PISTON_TOP, T_PISTON_BASE_BOTTOM, T_PISTON_BASE_SIDE) }, // 52
    .{ .name = "piston_head", .tex = topBottomSide(T_PISTON_HEAD_FACE, T_PISTON_HEAD_FACE, T_PISTON_HEAD_SIDE) }, // 53

    // -- Redstone containers --
    .{ .name = "hopper", .tex = topBottomSide(T_HOPPER_TOP, T_HOPPER_TOP, T_HOPPER_SIDE) }, // 54
    .{ .name = "dropper", .tex = frontRest(T_DROPPER_FRONT, T_DROPPER_SIDE) }, // 55
    .{ .name = "dispenser", .tex = frontRest(T_DISPENSER_FRONT, T_DISPENSER_SIDE) }, // 56

    // -- Enchanting / End --
    .{ .name = "enchanting_table", .tex = topBottomSide(T_ENCHANTING_TABLE_TOP, T_ENCHANTING_TABLE_BOTTOM, T_ENCHANTING_TABLE_SIDE) }, // 57
    .{ .name = "end_portal_frame", .tex = topBottomSide(T_END_PORTAL_FRAME_TOP, T_END_STONE, T_END_PORTAL_FRAME_SIDE) }, // 58
    .{ .name = "end_portal", .tex = allFaces(T_END_PORTAL), .solid = false, .transparent = true }, // 59

    // -- Rails --
    .{ .name = "rail", .tex = allFaces(T_RAIL), .solid = false }, // 60
    .{ .name = "powered_rail", .tex = allFaces(T_POWERED_RAIL), .solid = false }, // 61
    .{ .name = "detector_rail", .tex = allFaces(T_DETECTOR_RAIL), .solid = false }, // 62
    .{ .name = "activator_rail", .tex = allFaces(T_ACTIVATOR_RAIL), .solid = false }, // 63

    // -- Farming --
    .{ .name = "farmland", .tex = topBottomSide(T_FARMLAND_TOP, T_DIRT, T_FARMLAND_SIDE) }, // 64
    .{ .name = "wheat_crop", .tex = allFaces(T_WHEAT), .solid = false }, // 65
    .{ .name = "carrots_crop", .tex = allFaces(T_CARROTS), .solid = false }, // 66
    .{ .name = "potatoes_crop", .tex = allFaces(T_POTATOES), .solid = false }, // 67

    // -- Misc solid --
    .{ .name = "melon_block", .tex = topBottomSide(T_MELON_BLOCK_TOP, T_MELON_BLOCK_TOP, T_MELON_BLOCK_SIDE) }, // 68
    .{ .name = "jack_o_lantern", .tex = frontTopBottomSide(T_JACK_O_LANTERN_FRONT, T_JACK_O_LANTERN_TOP, T_PUMPKIN_TOP, T_JACK_O_LANTERN_SIDE) }, // 69
    .{ .name = "hay_bale", .tex = topBottomSide(T_HAY_BALE_TOP, T_HAY_BALE_TOP, T_HAY_BALE_SIDE) }, // 70

    // -- Wool (16 colors) --
    .{ .name = "white_wool", .tex = allFaces(T_WHITE_WOOL) }, // 71
    .{ .name = "orange_wool", .tex = allFaces(T_ORANGE_WOOL) }, // 72
    .{ .name = "magenta_wool", .tex = allFaces(T_MAGENTA_WOOL) }, // 73
    .{ .name = "light_blue_wool", .tex = allFaces(T_LIGHT_BLUE_WOOL) }, // 74
    .{ .name = "yellow_wool", .tex = allFaces(T_YELLOW_WOOL) }, // 75
    .{ .name = "lime_wool", .tex = allFaces(T_LIME_WOOL) }, // 76
    .{ .name = "pink_wool", .tex = allFaces(T_PINK_WOOL) }, // 77
    .{ .name = "gray_wool", .tex = allFaces(T_GRAY_WOOL) }, // 78
    .{ .name = "light_gray_wool", .tex = allFaces(T_LIGHT_GRAY_WOOL) }, // 79
    .{ .name = "cyan_wool", .tex = allFaces(T_CYAN_WOOL) }, // 80
    .{ .name = "purple_wool", .tex = allFaces(T_PURPLE_WOOL) }, // 81
    .{ .name = "blue_wool", .tex = allFaces(T_BLUE_WOOL) }, // 82
    .{ .name = "brown_wool", .tex = allFaces(T_BROWN_WOOL) }, // 83
    .{ .name = "green_wool", .tex = allFaces(T_GREEN_WOOL) }, // 84
    .{ .name = "red_wool", .tex = allFaces(T_RED_WOOL) }, // 85
    .{ .name = "black_wool", .tex = allFaces(T_BLACK_WOOL) }, // 86

    // -- Terracotta (4 representative colors) --
    .{ .name = "white_terracotta", .tex = allFaces(T_WHITE_TERRACOTTA) }, // 87
    .{ .name = "orange_terracotta", .tex = allFaces(T_ORANGE_TERRACOTTA) }, // 88
    .{ .name = "red_terracotta", .tex = allFaces(T_RED_TERRACOTTA) }, // 89
    .{ .name = "black_terracotta", .tex = allFaces(T_BLACK_TERRACOTTA) }, // 90

    // -- Concrete (4 representative colors) --
    .{ .name = "white_concrete", .tex = allFaces(T_WHITE_CONCRETE) }, // 91
    .{ .name = "orange_concrete", .tex = allFaces(T_ORANGE_CONCRETE) }, // 92
    .{ .name = "red_concrete", .tex = allFaces(T_RED_CONCRETE) }, // 93
    .{ .name = "black_concrete", .tex = allFaces(T_BLACK_CONCRETE) }, // 94

    // -- Copper (4 oxidation stages) --
    .{ .name = "copper_block", .tex = allFaces(T_COPPER_BLOCK) }, // 95
    .{ .name = "exposed_copper", .tex = allFaces(T_EXPOSED_COPPER) }, // 96
    .{ .name = "weathered_copper", .tex = allFaces(T_WEATHERED_COPPER) }, // 97
    .{ .name = "oxidized_copper", .tex = allFaces(T_OXIDIZED_COPPER) }, // 98
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

test "block registry has 99 entries" {
    try std.testing.expectEqual(@as(usize, 99), BLOCKS.len);
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

test "texture indices fit in u8" {
    for (BLOCKS) |def| {
        for (def.tex) |t| {
            try std.testing.expect(t < 256);
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

test "rails are not solid" {
    try std.testing.expect(!isSolid(RAIL));
    try std.testing.expect(!isSolid(POWERED_RAIL));
    try std.testing.expect(!isSolid(DETECTOR_RAIL));
    try std.testing.expect(!isSolid(ACTIVATOR_RAIL));
}

test "crops are not solid" {
    try std.testing.expect(!isSolid(WHEAT_CROP));
    try std.testing.expect(!isSolid(CARROTS_CROP));
    try std.testing.expect(!isSolid(POTATOES_CROP));
}

test "end portal is non-solid and transparent" {
    try std.testing.expect(!isSolid(END_PORTAL));
    try std.testing.expect(isTransparent(END_PORTAL));
}

test "wool blocks are solid" {
    try std.testing.expect(isSolid(WHITE_WOOL));
    try std.testing.expect(isSolid(BLACK_WOOL));
}

test "terracotta blocks are solid" {
    try std.testing.expect(isSolid(WHITE_TERRACOTTA));
    try std.testing.expect(isSolid(BLACK_TERRACOTTA));
}

test "concrete blocks are solid" {
    try std.testing.expect(isSolid(WHITE_CONCRETE));
    try std.testing.expect(isSolid(BLACK_CONCRETE));
}

test "new block names are correct" {
    try std.testing.expectEqualStrings("anvil", get(ANVIL).name);
    try std.testing.expectEqualStrings("beacon", get(BEACON).name);
    try std.testing.expectEqualStrings("rail", get(RAIL).name);
    try std.testing.expectEqualStrings("white_wool", get(WHITE_WOOL).name);
    try std.testing.expectEqualStrings("black_concrete", get(BLACK_CONCRETE).name);
}

test "brewing stand is non-solid" {
    try std.testing.expect(!isSolid(BREWING_STAND));
}

test "last block id matches registry length" {
    try std.testing.expectEqual(@as(usize, OXIDIZED_COPPER + 1), BLOCKS.len);
}
