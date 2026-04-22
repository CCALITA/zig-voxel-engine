const std = @import("std");
const testing = std.testing;

pub const ShapeType = enum(u2) { full, slab, stair, wall };

pub const ShapedBlock = struct {
    id: u16,
    name: []const u8,
    base_block: u16,
    shape: ShapeType,
    tex: u16,
};

pub const SHAPED_BLOCKS = [_]ShapedBlock{
    // Stone variants
    .{ .id = 171, .name = "stone_stairs", .base_block = 1, .shape = .stair, .tex = 0 },
    .{ .id = 172, .name = "stone_slab", .base_block = 1, .shape = .slab, .tex = 0 },
    .{ .id = 173, .name = "cobblestone_stairs", .base_block = 4, .shape = .stair, .tex = 4 },
    .{ .id = 174, .name = "cobblestone_slab", .base_block = 4, .shape = .slab, .tex = 4 },
    .{ .id = 175, .name = "cobblestone_wall", .base_block = 4, .shape = .wall, .tex = 4 },
    .{ .id = 176, .name = "brick_stairs", .base_block = 19, .shape = .stair, .tex = 19 },
    .{ .id = 177, .name = "brick_slab", .base_block = 19, .shape = .slab, .tex = 19 },
    .{ .id = 178, .name = "brick_wall", .base_block = 19, .shape = .wall, .tex = 19 },
    .{ .id = 179, .name = "sandstone_stairs", .base_block = 6, .shape = .stair, .tex = 6 },
    .{ .id = 180, .name = "sandstone_slab", .base_block = 6, .shape = .slab, .tex = 6 },
    .{ .id = 181, .name = "sandstone_wall", .base_block = 6, .shape = .wall, .tex = 6 },
    // Oak wood
    .{ .id = 182, .name = "oak_stairs", .base_block = 5, .shape = .stair, .tex = 5 },
    .{ .id = 183, .name = "oak_slab", .base_block = 5, .shape = .slab, .tex = 5 },
    // Stone bricks
    .{ .id = 184, .name = "stone_brick_stairs", .base_block = 168, .shape = .stair, .tex = 0 },
    .{ .id = 185, .name = "stone_brick_slab", .base_block = 168, .shape = .slab, .tex = 0 },
    .{ .id = 186, .name = "stone_brick_wall", .base_block = 168, .shape = .wall, .tex = 0 },
    // Nether brick
    .{ .id = 187, .name = "nether_brick_stairs", .base_block = 35, .shape = .stair, .tex = 35 },
    .{ .id = 188, .name = "nether_brick_slab", .base_block = 35, .shape = .slab, .tex = 35 },
    // Prismarine
    .{ .id = 189, .name = "prismarine_stairs", .base_block = 1, .shape = .stair, .tex = 0 },
    .{ .id = 190, .name = "prismarine_slab", .base_block = 1, .shape = .slab, .tex = 0 },
    // Quartz
    .{ .id = 191, .name = "quartz_stairs", .base_block = 1, .shape = .stair, .tex = 26 },
    .{ .id = 192, .name = "quartz_slab", .base_block = 1, .shape = .slab, .tex = 26 },
    // Purpur
    .{ .id = 193, .name = "purpur_stairs", .base_block = 20, .shape = .stair, .tex = 20 },
    .{ .id = 194, .name = "purpur_slab", .base_block = 20, .shape = .slab, .tex = 20 },
    // End stone brick
    .{ .id = 195, .name = "end_stone_brick_stairs", .base_block = 45, .shape = .stair, .tex = 54 },
    .{ .id = 196, .name = "end_stone_brick_slab", .base_block = 45, .shape = .slab, .tex = 54 },
    .{ .id = 197, .name = "end_stone_brick_wall", .base_block = 45, .shape = .wall, .tex = 54 },
    // Smooth stone
    .{ .id = 198, .name = "smooth_stone_slab", .base_block = 1, .shape = .slab, .tex = 0 },
    // Mossy cobblestone
    .{ .id = 199, .name = "mossy_cobble_stairs", .base_block = 22, .shape = .stair, .tex = 24 },
    .{ .id = 200, .name = "mossy_cobble_slab", .base_block = 22, .shape = .slab, .tex = 24 },
    .{ .id = 201, .name = "mossy_cobble_wall", .base_block = 22, .shape = .wall, .tex = 24 },
};

pub fn getShapedBlock(id: u16) ?ShapedBlock {
    for (SHAPED_BLOCKS) |block| {
        if (block.id == id) return block;
    }
    return null;
}

fn isShape(id: u16, shape: ShapeType) bool {
    const block = getShapedBlock(id) orelse return false;
    return block.shape == shape;
}

pub fn isSlabBlock(id: u16) bool {
    return isShape(id, .slab);
}

pub fn isStairBlock(id: u16) bool {
    return isShape(id, .stair);
}

pub fn isWallBlock(id: u16) bool {
    return isShape(id, .wall);
}

pub fn getBaseBlock(id: u16) ?u16 {
    const block = getShapedBlock(id) orelse return null;
    return block.base_block;
}

// ---------- Tests ----------

test "getShapedBlock returns correct block" {
    const block = getShapedBlock(171).?;
    try testing.expectEqualStrings("stone_stairs", block.name);
    try testing.expectEqual(@as(u16, 1), block.base_block);
    try testing.expectEqual(ShapeType.stair, block.shape);
}

test "getShapedBlock returns null for unknown id" {
    try testing.expectEqual(@as(?ShapedBlock, null), getShapedBlock(999));
}

test "isSlabBlock identifies slabs" {
    try testing.expect(isSlabBlock(172)); // stone_slab
    try testing.expect(isSlabBlock(174)); // cobblestone_slab
    try testing.expect(isSlabBlock(198)); // smooth_stone_slab
}

test "isSlabBlock rejects non-slabs" {
    try testing.expect(!isSlabBlock(171)); // stone_stairs
    try testing.expect(!isSlabBlock(175)); // cobblestone_wall
    try testing.expect(!isSlabBlock(0)); // unknown
}

test "isStairBlock identifies stairs" {
    try testing.expect(isStairBlock(171)); // stone_stairs
    try testing.expect(isStairBlock(176)); // brick_stairs
    try testing.expect(isStairBlock(199)); // mossy_cobble_stairs
}

test "isStairBlock rejects non-stairs" {
    try testing.expect(!isStairBlock(172)); // stone_slab
    try testing.expect(!isStairBlock(175)); // cobblestone_wall
    try testing.expect(!isStairBlock(42)); // unknown
}

test "isWallBlock identifies walls" {
    try testing.expect(isWallBlock(175)); // cobblestone_wall
    try testing.expect(isWallBlock(178)); // brick_wall
    try testing.expect(isWallBlock(201)); // mossy_cobble_wall
}

test "isWallBlock rejects non-walls" {
    try testing.expect(!isWallBlock(171)); // stone_stairs
    try testing.expect(!isWallBlock(172)); // stone_slab
    try testing.expect(!isWallBlock(1)); // unknown
}

test "getBaseBlock returns base block id" {
    try testing.expectEqual(@as(?u16, 4), getBaseBlock(173)); // cobblestone_stairs -> cobblestone
    try testing.expectEqual(@as(?u16, 19), getBaseBlock(177)); // brick_slab -> brick
    try testing.expectEqual(@as(?u16, 22), getBaseBlock(201)); // mossy_cobble_wall -> mossy_cobblestone
}

test "getBaseBlock returns null for unknown id" {
    try testing.expectEqual(@as(?u16, null), getBaseBlock(0));
    try testing.expectEqual(@as(?u16, null), getBaseBlock(500));
}

test "SHAPED_BLOCKS has correct count" {
    try testing.expectEqual(@as(usize, 31), SHAPED_BLOCKS.len);
}

test "all block ids are in range 171-201" {
    for (SHAPED_BLOCKS) |block| {
        try testing.expect(block.id >= 171 and block.id <= 201);
    }
}

test "no duplicate block ids" {
    for (SHAPED_BLOCKS, 0..) |a, i| {
        for (SHAPED_BLOCKS[i + 1 ..]) |b| {
            try testing.expect(a.id != b.id);
        }
    }
}
