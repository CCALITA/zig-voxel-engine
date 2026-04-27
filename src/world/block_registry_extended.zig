/// Extended block registry adding ~86 blocks starting at ID 171.
/// Covers deepslate, nether, sculk, copper, end, ocean, and misc blocks.

const std = @import("std");

pub const ToolType = enum(u3) {
    none = 0,
    pickaxe = 1,
    axe = 2,
    shovel = 3,
    hoe = 4,
    shears = 5,
};

pub const ExtendedBlockInfo = struct {
    id: u16,
    name: []const u8,
    hardness: f32,
    blast_resistance: f32,
    luminance: u4,
    is_solid: bool,
    is_transparent: bool,
    tool_type: ToolType,
    tool_level: u2,
};

// --- ID range constants ---
const FIRST_ID: u16 = 171;

fn b(id: u16, name: []const u8, hardness: f32, blast_res: f32, lum: u4, solid: bool, transparent: bool, tool: ToolType, level: u2) ExtendedBlockInfo {
    return .{
        .id = id,
        .name = name,
        .hardness = hardness,
        .blast_resistance = blast_res,
        .luminance = lum,
        .is_solid = solid,
        .is_transparent = transparent,
        .tool_type = tool,
        .tool_level = level,
    };
}

/// All extended blocks in a single comptime array, IDs 171-256.
pub const EXTENDED_BLOCKS = [_]ExtendedBlockInfo{
    // --- Deepslate variants (14 blocks, IDs 171-184) ---
    b(171, "deepslate", 3.0, 6.0, 0, true, false, .pickaxe, 1),
    b(172, "cobbled_deepslate", 3.5, 6.0, 0, true, false, .pickaxe, 1),
    b(173, "polished_deepslate", 3.5, 6.0, 0, true, false, .pickaxe, 1),
    b(174, "deepslate_bricks", 3.5, 6.0, 0, true, false, .pickaxe, 1),
    b(175, "cracked_deepslate_bricks", 3.5, 6.0, 0, true, false, .pickaxe, 1),
    b(176, "deepslate_tiles", 3.5, 6.0, 0, true, false, .pickaxe, 1),
    b(177, "cracked_deepslate_tiles", 3.5, 6.0, 0, true, false, .pickaxe, 1),
    b(178, "chiseled_deepslate", 3.5, 6.0, 0, true, false, .pickaxe, 1),
    b(179, "deepslate_coal_ore", 4.5, 3.0, 0, true, false, .pickaxe, 1),
    b(180, "deepslate_iron_ore", 4.5, 3.0, 0, true, false, .pickaxe, 2),
    b(181, "deepslate_gold_ore", 4.5, 3.0, 0, true, false, .pickaxe, 2),
    b(182, "deepslate_diamond_ore", 4.5, 3.0, 0, true, false, .pickaxe, 2),
    b(183, "deepslate_redstone_ore", 4.5, 3.0, 0, true, false, .pickaxe, 2),
    b(184, "deepslate_lapis_ore", 4.5, 3.0, 0, true, false, .pickaxe, 2),
    // --- Nether blocks (25 blocks, IDs 185-209) ---
    b(185, "soul_soil", 0.5, 0.5, 0, true, false, .shovel, 0),
    b(186, "basalt", 1.25, 4.2, 0, true, false, .pickaxe, 1),
    b(187, "polished_basalt", 1.25, 4.2, 0, true, false, .pickaxe, 1),
    b(188, "smooth_basalt", 1.25, 4.2, 0, true, false, .pickaxe, 1),
    b(189, "blackstone", 1.5, 6.0, 0, true, false, .pickaxe, 1),
    b(190, "polished_blackstone", 2.0, 6.0, 0, true, false, .pickaxe, 1),
    b(191, "polished_blackstone_bricks", 1.5, 6.0, 0, true, false, .pickaxe, 1),
    b(192, "cracked_polished_blackstone_bricks", 1.5, 6.0, 0, true, false, .pickaxe, 1),
    b(193, "chiseled_polished_blackstone", 1.5, 6.0, 0, true, false, .pickaxe, 1),
    b(194, "gilded_blackstone", 1.5, 6.0, 0, true, false, .pickaxe, 1),
    b(195, "nether_bricks", 2.0, 6.0, 0, true, false, .pickaxe, 1),
    b(196, "red_nether_bricks", 2.0, 6.0, 0, true, false, .pickaxe, 1),
    b(197, "cracked_nether_bricks", 2.0, 6.0, 0, true, false, .pickaxe, 1),
    b(198, "chiseled_nether_bricks", 2.0, 6.0, 0, true, false, .pickaxe, 1),
    b(199, "nether_gold_ore", 3.0, 3.0, 0, true, false, .pickaxe, 1),
    b(200, "nether_quartz_ore", 3.0, 3.0, 0, true, false, .pickaxe, 1),
    b(201, "ancient_debris", 30.0, 1200.0, 0, true, false, .pickaxe, 3),
    b(202, "crimson_planks", 2.0, 3.0, 0, true, false, .axe, 0),
    b(203, "warped_planks", 2.0, 3.0, 0, true, false, .axe, 0),
    b(204, "crimson_stem", 2.0, 3.0, 0, true, false, .axe, 0),
    b(205, "warped_stem", 2.0, 3.0, 0, true, false, .axe, 0),
    b(206, "crimson_nylium", 0.4, 0.4, 0, true, false, .pickaxe, 1),
    b(207, "warped_nylium", 0.4, 0.4, 0, true, false, .pickaxe, 1),
    b(208, "shroomlight", 1.0, 1.0, 15, true, false, .hoe, 0),
    b(209, "crying_obsidian", 50.0, 1200.0, 10, true, false, .pickaxe, 3),
    // --- Sculk family (5 blocks, IDs 210-214) ---
    b(210, "sculk", 0.2, 0.2, 0, true, false, .hoe, 0),
    b(211, "sculk_vein", 0.2, 0.2, 0, false, true, .hoe, 0),
    b(212, "sculk_catalyst", 3.0, 3.0, 6, true, false, .hoe, 0),
    b(213, "sculk_shrieker", 3.0, 3.0, 0, true, false, .hoe, 0),
    b(214, "sculk_sensor", 1.5, 1.5, 1, true, false, .hoe, 0),
    // --- Copper stages (9 blocks, IDs 215-223) ---
    b(215, "cut_copper", 3.0, 6.0, 0, true, false, .pickaxe, 2),
    b(216, "exposed_cut_copper", 3.0, 6.0, 0, true, false, .pickaxe, 2),
    b(217, "weathered_cut_copper", 3.0, 6.0, 0, true, false, .pickaxe, 2),
    b(218, "oxidized_cut_copper", 3.0, 6.0, 0, true, false, .pickaxe, 2),
    b(219, "waxed_copper_block", 3.0, 6.0, 0, true, false, .pickaxe, 2),
    b(220, "waxed_exposed_copper", 3.0, 6.0, 0, true, false, .pickaxe, 2),
    b(221, "waxed_weathered_copper", 3.0, 6.0, 0, true, false, .pickaxe, 2),
    b(222, "waxed_oxidized_copper", 3.0, 6.0, 0, true, false, .pickaxe, 2),
    b(223, "copper_grate", 3.0, 6.0, 0, false, true, .pickaxe, 2),
    // --- End blocks (7 blocks, IDs 224-230) ---
    b(224, "purpur_block", 1.5, 6.0, 0, true, false, .pickaxe, 1),
    b(225, "purpur_pillar", 1.5, 6.0, 0, true, false, .pickaxe, 1),
    b(226, "end_stone_bricks", 3.0, 9.0, 0, true, false, .pickaxe, 1),
    b(227, "end_rod", 0.0, 0.0, 14, false, true, .none, 0),
    b(228, "chorus_plant", 0.4, 0.4, 0, false, true, .axe, 0),
    b(229, "chorus_flower", 0.4, 0.4, 0, false, true, .axe, 0),
    b(230, "dragon_egg", 3.0, 9.0, 1, true, false, .none, 0),
    // --- Ocean blocks (6 blocks, IDs 231-236) ---
    b(231, "prismarine", 1.5, 6.0, 0, true, false, .pickaxe, 1),
    b(232, "prismarine_bricks", 1.5, 6.0, 0, true, false, .pickaxe, 1),
    b(233, "dark_prismarine", 1.5, 6.0, 0, true, false, .pickaxe, 1),
    b(234, "sea_lantern", 0.3, 0.3, 15, true, false, .none, 0),
    b(235, "conduit", 3.0, 3.0, 15, false, true, .none, 0),
    b(236, "dried_kelp_block", 0.5, 2.5, 0, true, false, .hoe, 0),
    // --- Misc blocks (20 blocks, IDs 237-256) ---
    b(237, "tuff", 1.5, 6.0, 0, true, false, .pickaxe, 1),
    b(238, "calcite", 0.75, 0.75, 0, true, false, .pickaxe, 1),
    b(239, "amethyst_block", 1.5, 1.5, 0, true, false, .pickaxe, 1),
    b(240, "budding_amethyst", 1.5, 1.5, 1, true, false, .pickaxe, 1),
    b(241, "pointed_dripstone", 1.5, 3.0, 0, false, true, .pickaxe, 1),
    b(242, "dripstone_block", 1.5, 1.0, 0, true, false, .pickaxe, 1),
    b(243, "mud", 0.5, 0.5, 0, true, false, .shovel, 0),
    b(244, "packed_mud", 1.0, 3.0, 0, true, false, .pickaxe, 1),
    b(245, "mud_bricks", 1.5, 3.0, 0, true, false, .pickaxe, 1),
    b(246, "moss_block", 0.1, 0.1, 0, true, false, .hoe, 0),
    b(247, "moss_carpet", 0.1, 0.1, 0, false, false, .hoe, 0),
    b(248, "azalea", 0.0, 0.0, 0, false, true, .none, 0),
    b(249, "flowering_azalea", 0.0, 0.0, 0, false, true, .none, 0),
    b(250, "big_dripleaf", 0.1, 0.1, 0, false, true, .none, 0),
    b(251, "small_dripleaf", 0.0, 0.0, 0, false, true, .shears, 0),
    b(252, "glow_lichen", 0.2, 0.2, 7, false, true, .shears, 0),
    b(253, "bell", 5.0, 5.0, 0, false, false, .pickaxe, 1),
    b(254, "honey_block", 0.0, 0.0, 0, true, true, .none, 0),
    b(255, "honeycomb_block", 0.6, 0.6, 0, true, false, .none, 0),
    b(256, "rooted_dirt", 0.5, 0.5, 0, true, false, .shovel, 0),
};

const LAST_ID: u16 = FIRST_ID + EXTENDED_BLOCKS.len - 1;

/// Look up an extended block by its ID. Returns null if not in range.
pub fn getExtendedBlock(id: u16) ?ExtendedBlockInfo {
    if (id < FIRST_ID or id > LAST_ID) return null;
    return EXTENDED_BLOCKS[id - FIRST_ID];
}

/// Look up an extended block by name. Linear scan over comptime array.
pub fn getBlockByName(name: []const u8) ?ExtendedBlockInfo {
    for (EXTENDED_BLOCKS) |blk| {
        if (std.mem.eql(u8, blk.name, name)) return blk;
    }
    return null;
}

/// Returns true if the block ID is a deepslate variant (171-184).
pub fn isDeepslateVariant(id: u16) bool {
    return id >= 171 and id <= 184;
}

/// Returns true if the block ID is a nether block (185-209).
pub fn isNetherBlock(id: u16) bool {
    return id >= 185 and id <= 209;
}

/// Returns true if the block ID is a copper block (215-223).
pub fn isCopperBlock(id: u16) bool {
    return id >= 215 and id <= 223;
}

/// Returns true if the block ID is a sculk block (210-214).
pub fn isSculkBlock(id: u16) bool {
    return id >= 210 and id <= 214;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "EXTENDED_BLOCKS has 86 entries" {
    try std.testing.expectEqual(@as(usize, 86), EXTENDED_BLOCKS.len);
}

test "lookup by ID returns correct block" {
    const blk = getExtendedBlock(171).?;
    try std.testing.expectEqualStrings("deepslate", blk.name);
    try std.testing.expectEqual(@as(u16, 171), blk.id);

    const last = getExtendedBlock(256).?;
    try std.testing.expectEqualStrings("rooted_dirt", last.name);
}

test "lookup by name returns correct block" {
    const blk = getBlockByName("ancient_debris").?;
    try std.testing.expectEqual(@as(u16, 201), blk.id);
    try std.testing.expectEqual(@as(f32, 30.0), blk.hardness);
}

test "null for unknown ID" {
    try std.testing.expect(getExtendedBlock(0) == null);
    try std.testing.expect(getExtendedBlock(170) == null);
    try std.testing.expect(getExtendedBlock(257) == null);
    try std.testing.expect(getExtendedBlock(999) == null);
}

test "null for unknown name" {
    try std.testing.expect(getBlockByName("unobtainium") == null);
}

test "deepslate category check" {
    try std.testing.expect(isDeepslateVariant(171));
    try std.testing.expect(isDeepslateVariant(184));
    try std.testing.expect(!isDeepslateVariant(170));
    try std.testing.expect(!isDeepslateVariant(185));
}

test "nether category check" {
    try std.testing.expect(isNetherBlock(185));
    try std.testing.expect(isNetherBlock(209));
    try std.testing.expect(!isNetherBlock(184));
    try std.testing.expect(!isNetherBlock(210));
}

test "copper category check" {
    try std.testing.expect(isCopperBlock(215));
    try std.testing.expect(isCopperBlock(223));
    try std.testing.expect(!isCopperBlock(214));
    try std.testing.expect(!isCopperBlock(224));
}

test "sculk category check" {
    try std.testing.expect(isSculkBlock(210));
    try std.testing.expect(isSculkBlock(214));
    try std.testing.expect(!isSculkBlock(209));
    try std.testing.expect(!isSculkBlock(215));
}

test "luminance values for light-emitting blocks" {
    const sea_lantern = getBlockByName("sea_lantern").?;
    try std.testing.expectEqual(@as(u4, 15), sea_lantern.luminance);

    const shroomlight = getBlockByName("shroomlight").?;
    try std.testing.expectEqual(@as(u4, 15), shroomlight.luminance);

    const end_rod = getBlockByName("end_rod").?;
    try std.testing.expectEqual(@as(u4, 14), end_rod.luminance);

    const glow_lichen = getBlockByName("glow_lichen").?;
    try std.testing.expectEqual(@as(u4, 7), glow_lichen.luminance);

    const sculk_catalyst = getBlockByName("sculk_catalyst").?;
    try std.testing.expectEqual(@as(u4, 6), sculk_catalyst.luminance);
}

test "hardness and tool requirements" {
    const ancient = getBlockByName("ancient_debris").?;
    try std.testing.expectEqual(@as(f32, 30.0), ancient.hardness);
    try std.testing.expectEqual(ToolType.pickaxe, ancient.tool_type);
    try std.testing.expectEqual(@as(u2, 3), ancient.tool_level);

    const moss = getBlockByName("moss_block").?;
    try std.testing.expectEqual(ToolType.hoe, moss.tool_type);
}

test "end blocks are in correct range" {
    const purpur = getExtendedBlock(224).?;
    try std.testing.expectEqualStrings("purpur_block", purpur.name);

    const dragon = getExtendedBlock(230).?;
    try std.testing.expectEqualStrings("dragon_egg", dragon.name);
    try std.testing.expect(dragon.is_solid);
}

test "IDs are sequential and contiguous" {
    for (EXTENDED_BLOCKS, 0..) |blk, i| {
        try std.testing.expectEqual(FIRST_ID + @as(u16, @intCast(i)), blk.id);
    }
}
