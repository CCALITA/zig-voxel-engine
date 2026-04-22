/// Block variant definitions for wood types and stone variants.
/// Registers 60 variant blocks (IDs 111-170):
///   - 6 wood types x 9 shapes = 54 wood blocks (IDs 111-164)
///   - 3 polished stone variants (IDs 165-167)
///   - 3 stone brick variants (IDs 168-170)

const std = @import("std");

pub const WoodType = enum(u8) {
    birch = 0,
    spruce = 1,
    jungle = 2,
    acacia = 3,
    dark_oak = 4,
    mangrove = 5,
};

pub const ShapeType = enum(u8) {
    planks = 0,
    log = 1,
    stairs = 2,
    slab = 3,
    fence = 4,
    fence_gate = 5,
    door = 6,
    trapdoor = 7,
    sign = 8,
};

pub const VariantBlock = struct {
    id: u16,
    name: []const u8,
    wood_type: ?WoodType = null,
    shape: ?ShapeType = null,
    base_tex: u16,
    solid: bool = true,
};

const wood_type_count: u16 = @typeInfo(WoodType).@"enum".fields.len;
const shape_count: u16 = @typeInfo(ShapeType).@"enum".fields.len;
const wood_block_count: u16 = wood_type_count * shape_count; // 54
const stone_block_count: u16 = 6;
const total_block_count: u16 = wood_block_count + stone_block_count; // 60

const first_wood_id: u16 = 111;
const first_stone_id: u16 = first_wood_id + wood_block_count; // 165
const last_variant_id: u16 = first_wood_id + total_block_count - 1; // 170

// Base texture atlas indices (from block.zig conventions)
const T_PLANKS: u16 = 5;
const T_LOG_SIDE: u16 = 8;

const wood_type_names = [wood_type_count][]const u8{
    "birch",
    "spruce",
    "jungle",
    "acacia",
    "dark_oak",
    "mangrove",
};

const shape_names = [shape_count][]const u8{
    "planks",
    "log",
    "stairs",
    "slab",
    "fence",
    "fence_gate",
    "door",
    "trapdoor",
    "sign",
};

/// Shapes that are non-solid (not full cubes).
fn isShapeSolid(shape: ShapeType) bool {
    return switch (shape) {
        .planks, .log, .stairs, .slab => true,
        .fence, .fence_gate, .door, .trapdoor, .sign => false,
    };
}

/// Compute texture index for a wood variant.
/// Planks use T_PLANKS as base, logs use T_LOG_SIDE, others derive from planks.
/// Each wood type offsets by its enum value to differentiate textures.
fn woodTexture(wood: WoodType, shape: ShapeType) u16 {
    const wood_offset: u16 = @intFromEnum(wood);
    return switch (shape) {
        .log => T_LOG_SIDE + wood_offset,
        else => T_PLANKS + wood_offset,
    };
}

/// Comptime-generated block name strings for wood variants.
/// Format: "{wood_type}_{shape}" e.g. "birch_planks", "spruce_log"
const wood_block_names = blk: {
    var names: [wood_block_count][]const u8 = undefined;
    for (0..wood_type_count) |wi| {
        for (0..shape_count) |si| {
            names[wi * shape_count + si] = wood_type_names[wi] ++ "_" ++ shape_names[si];
        }
    }
    break :blk names;
};

const stone_variant_entries = [stone_block_count]VariantBlock{
    .{ .id = 165, .name = "polished_granite", .base_tex = 0, .solid = true },
    .{ .id = 166, .name = "polished_diorite", .base_tex = 0, .solid = true },
    .{ .id = 167, .name = "polished_andesite", .base_tex = 0, .solid = true },
    .{ .id = 168, .name = "mossy_stone_bricks", .base_tex = 0, .solid = true },
    .{ .id = 169, .name = "cracked_stone_bricks", .base_tex = 0, .solid = true },
    .{ .id = 170, .name = "chiseled_stone_bricks", .base_tex = 0, .solid = true },
};

/// All 60 variant blocks in a single comptime array.
pub const VARIANT_BLOCKS: [total_block_count]VariantBlock = blk: {
    var blocks: [total_block_count]VariantBlock = undefined;

    // Wood variants: 6 types x 9 shapes = 54 blocks
    for (0..wood_type_count) |wi| {
        const wood: WoodType = @enumFromInt(wi);
        for (0..shape_count) |si| {
            const shape: ShapeType = @enumFromInt(si);
            const idx = wi * shape_count + si;
            blocks[idx] = .{
                .id = first_wood_id + @as(u16, @intCast(idx)),
                .name = wood_block_names[idx],
                .wood_type = wood,
                .shape = shape,
                .base_tex = woodTexture(wood, shape),
                .solid = isShapeSolid(shape),
            };
        }
    }

    // Stone variants: 6 blocks
    for (0..stone_block_count) |i| {
        blocks[wood_block_count + i] = stone_variant_entries[i];
    }

    break :blk blocks;
};

/// Look up a variant block by its ID. Returns null if the ID is not in 111-170.
pub fn getVariant(id: u16) ?VariantBlock {
    if (id < first_wood_id or id > last_variant_id) return null;
    return VARIANT_BLOCKS[id - first_wood_id];
}

/// Returns the block ID for the planks shape of the given wood type.
pub fn getWoodPlanks(wood: WoodType) u16 {
    return first_wood_id + @as(u16, @intFromEnum(wood)) * shape_count + @as(u16, @intFromEnum(ShapeType.planks));
}

/// Returns the block ID for the log shape of the given wood type.
pub fn getWoodLog(wood: WoodType) u16 {
    return first_wood_id + @as(u16, @intFromEnum(wood)) * shape_count + @as(u16, @intFromEnum(ShapeType.log));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "VARIANT_BLOCKS has 60 entries" {
    try std.testing.expectEqual(@as(usize, 60), VARIANT_BLOCKS.len);
}

test "first wood block is birch_planks at ID 111" {
    const b = VARIANT_BLOCKS[0];
    try std.testing.expectEqual(@as(u16, 111), b.id);
    try std.testing.expectEqualStrings("birch_planks", b.name);
    try std.testing.expectEqual(WoodType.birch, b.wood_type.?);
    try std.testing.expectEqual(ShapeType.planks, b.shape.?);
}

test "birch wood IDs span 111-119" {
    try std.testing.expectEqual(@as(u16, 111), VARIANT_BLOCKS[0].id); // birch_planks
    try std.testing.expectEqual(@as(u16, 119), VARIANT_BLOCKS[8].id); // birch_sign
    try std.testing.expectEqualStrings("birch_sign", VARIANT_BLOCKS[8].name);
}

test "spruce range starts at 120" {
    try std.testing.expectEqual(@as(u16, 120), VARIANT_BLOCKS[9].id);
    try std.testing.expectEqualStrings("spruce_planks", VARIANT_BLOCKS[9].name);
    try std.testing.expectEqual(WoodType.spruce, VARIANT_BLOCKS[9].wood_type.?);
}

test "mangrove range ends at 164" {
    const last_wood = VARIANT_BLOCKS[wood_block_count - 1];
    try std.testing.expectEqual(@as(u16, 164), last_wood.id);
    try std.testing.expectEqualStrings("mangrove_sign", last_wood.name);
    try std.testing.expectEqual(WoodType.mangrove, last_wood.wood_type.?);
    try std.testing.expectEqual(ShapeType.sign, last_wood.shape.?);
}

test "stone variants at IDs 165-170" {
    try std.testing.expectEqual(@as(u16, 165), VARIANT_BLOCKS[54].id);
    try std.testing.expectEqualStrings("polished_granite", VARIANT_BLOCKS[54].name);
    try std.testing.expectEqual(@as(u16, 170), VARIANT_BLOCKS[59].id);
    try std.testing.expectEqualStrings("chiseled_stone_bricks", VARIANT_BLOCKS[59].name);
}

test "stone variants have no wood_type or shape" {
    for (VARIANT_BLOCKS[wood_block_count..]) |b| {
        try std.testing.expectEqual(@as(?WoodType, null), b.wood_type);
        try std.testing.expectEqual(@as(?ShapeType, null), b.shape);
    }
}

test "getVariant returns correct block" {
    const v = getVariant(111).?;
    try std.testing.expectEqualStrings("birch_planks", v.name);

    const v2 = getVariant(170).?;
    try std.testing.expectEqualStrings("chiseled_stone_bricks", v2.name);
}

test "getVariant returns null for out-of-range IDs" {
    try std.testing.expectEqual(@as(?VariantBlock, null), getVariant(0));
    try std.testing.expectEqual(@as(?VariantBlock, null), getVariant(110));
    try std.testing.expectEqual(@as(?VariantBlock, null), getVariant(171));
    try std.testing.expectEqual(@as(?VariantBlock, null), getVariant(999));
}

test "getWoodPlanks returns correct IDs" {
    try std.testing.expectEqual(@as(u16, 111), getWoodPlanks(.birch));
    try std.testing.expectEqual(@as(u16, 120), getWoodPlanks(.spruce));
    try std.testing.expectEqual(@as(u16, 129), getWoodPlanks(.jungle));
    try std.testing.expectEqual(@as(u16, 138), getWoodPlanks(.acacia));
    try std.testing.expectEqual(@as(u16, 147), getWoodPlanks(.dark_oak));
    try std.testing.expectEqual(@as(u16, 156), getWoodPlanks(.mangrove));
}

test "getWoodLog returns correct IDs" {
    try std.testing.expectEqual(@as(u16, 112), getWoodLog(.birch));
    try std.testing.expectEqual(@as(u16, 121), getWoodLog(.spruce));
    try std.testing.expectEqual(@as(u16, 130), getWoodLog(.jungle));
    try std.testing.expectEqual(@as(u16, 139), getWoodLog(.acacia));
    try std.testing.expectEqual(@as(u16, 148), getWoodLog(.dark_oak));
    try std.testing.expectEqual(@as(u16, 157), getWoodLog(.mangrove));
}

test "non-solid shapes: fence, fence_gate, door, trapdoor, sign" {
    // Check birch variants as representative
    const birch_fence = getVariant(115).?; // birch_fence
    try std.testing.expect(!birch_fence.solid);
    const birch_door = getVariant(117).?; // birch_door
    try std.testing.expect(!birch_door.solid);
    const birch_sign = getVariant(119).?; // birch_sign
    try std.testing.expect(!birch_sign.solid);
}

test "solid shapes: planks, log, stairs, slab" {
    const birch_planks = getVariant(111).?;
    try std.testing.expect(birch_planks.solid);
    const birch_log = getVariant(112).?;
    try std.testing.expect(birch_log.solid);
    const birch_stairs = getVariant(113).?;
    try std.testing.expect(birch_stairs.solid);
    const birch_slab = getVariant(114).?;
    try std.testing.expect(birch_slab.solid);
}

test "all stone variants are solid" {
    for (VARIANT_BLOCKS[wood_block_count..]) |b| {
        try std.testing.expect(b.solid);
    }
}

test "log texture uses T_LOG_SIDE base" {
    const birch_log = getVariant(112).?;
    try std.testing.expectEqual(T_LOG_SIDE + @as(u16, @intFromEnum(WoodType.birch)), birch_log.base_tex);
    const spruce_log = getVariant(121).?;
    try std.testing.expectEqual(T_LOG_SIDE + @as(u16, @intFromEnum(WoodType.spruce)), spruce_log.base_tex);
}
