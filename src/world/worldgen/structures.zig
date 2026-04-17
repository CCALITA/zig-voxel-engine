/// Structure generation for villages, dungeons, and other world structures.
/// Defines compile-time templates for various structure types and provides
/// noise-based placement (roughly 1 structure per 8x8 chunk area).
const std = @import("std");
const Chunk = @import("../chunk.zig");
const block = @import("../block.zig");
const noise = @import("../noise.zig");

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

pub const StructureType = enum {
    village_house,
    village_church,
    village_well,
    dungeon,
    desert_temple,
    mineshaft,
};

pub const StructureBlock = struct {
    dx: i8,
    dy: i8,
    dz: i8,
    block_id: u8,
};

pub const StructureDef = struct {
    blocks: []const StructureBlock,
    width: u8,
    height: u8,
    depth: u8,
};

// ---------------------------------------------------------------------------
// Noise parameters for structure placement
// ---------------------------------------------------------------------------

/// Seed offset so structure noise does not correlate with terrain/tree/cave noise.
const STRUCTURE_SEED_OFFSET: u64 = 314_159_265;

/// Grid size in chunks -- structures spawn at most once per grid cell.
const GRID_SIZE: i32 = 8;

/// Noise threshold for structure placement within a grid cell.
/// Perlin noise returns values in [-1, 1]; a threshold of 0.15 means
/// roughly 30-40% of grid cells get a structure, yielding approximately
/// 1 structure per 8x8 = 64 chunks.
const PLACEMENT_THRESHOLD: f64 = 0.15;

/// Noise frequency for local position within grid cell.
const LOCAL_NOISE_FREQ: f64 = 0.17;

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Get the template for a structure type.
pub fn getTemplate(structure_type: StructureType) StructureDef {
    return switch (structure_type) {
        .village_house => .{ .blocks = &village_house_blocks, .width = 5, .height = 4, .depth = 5 },
        .village_church => .{ .blocks = &village_house_blocks, .width = 5, .height = 4, .depth = 5 },
        .village_well => .{ .blocks = &village_well_blocks, .width = 3, .height = 5, .depth = 3 },
        .dungeon => .{ .blocks = &dungeon_blocks, .width = 7, .height = 5, .depth = 7 },
        .desert_temple => .{ .blocks = &desert_temple_blocks, .width = 9, .height = 8, .depth = 9 },
        .mineshaft => .{ .blocks = &dungeon_blocks, .width = 7, .height = 5, .depth = 7 },
    };
}

/// Place a structure in a chunk at the given position.
/// Only places blocks that fit within the chunk bounds.
pub fn placeStructure(chunk: *Chunk, template: StructureDef, origin_x: i32, origin_y: i32, origin_z: i32) void {
    for (template.blocks) |sb| {
        const wx = origin_x + @as(i32, sb.dx);
        const wy = origin_y + @as(i32, sb.dy);
        const wz = origin_z + @as(i32, sb.dz);

        if (wx < 0 or wx >= Chunk.SIZE or
            wy < 0 or wy >= Chunk.SIZE or
            wz < 0 or wz >= Chunk.SIZE) continue;

        chunk.setBlock(@intCast(wx), @intCast(wy), @intCast(wz), sb.block_id);
    }
}

/// Determine if a chunk should have a structure (noise-based, very rare).
/// Returns the structure type and local position within the chunk, or null.
pub fn shouldPlaceStructure(seed: u64, chunk_x: i32, chunk_z: i32) ?struct { structure_type: StructureType, local_x: u4, local_z: u4 } {
    // Determine which grid cell this chunk belongs to.
    const grid_x = @divFloor(chunk_x, GRID_SIZE);
    const grid_z = @divFloor(chunk_z, GRID_SIZE);

    // Use noise to decide whether this grid cell gets a structure at all.
    const pt = noise.PermTable.init(seed +% STRUCTURE_SEED_OFFSET);
    const gx: f64 = @floatFromInt(grid_x);
    const gz: f64 = @floatFromInt(grid_z);
    const placement_noise = noise.noise2d(&pt, gx * 0.73, gz * 0.73);

    if (placement_noise < PLACEMENT_THRESHOLD) return null;

    // Determine which chunk within the grid cell hosts the structure.
    const cell_base_x = grid_x * GRID_SIZE;
    const cell_base_z = grid_z * GRID_SIZE;

    const host_offset_x = noiseToGridOffset(&pt, gx, gz, 0.0);
    const host_offset_z = noiseToGridOffset(&pt, gx, gz, 1.0);

    const host_chunk_x = cell_base_x + host_offset_x;
    const host_chunk_z = cell_base_z + host_offset_z;

    if (host_chunk_x != chunk_x or host_chunk_z != chunk_z) return null;

    // Determine local position within the chunk using noise.
    const local_noise_x = noise.noise2d(&pt, gx * LOCAL_NOISE_FREQ + 100.0, gz * LOCAL_NOISE_FREQ);
    const local_noise_z = noise.noise2d(&pt, gx * LOCAL_NOISE_FREQ, gz * LOCAL_NOISE_FREQ + 100.0);

    const local_x = noiseToU4(local_noise_x);
    const local_z = noiseToU4(local_noise_z);

    // Determine structure type from another noise sample.
    const type_noise = noise.noise2d(&pt, gx * 1.31 + 50.0, gz * 1.31 + 50.0);
    const structure_type = noiseToStructureType(type_noise);

    return .{ .structure_type = structure_type, .local_x = local_x, .local_z = local_z };
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/// Normalize a Perlin noise value from [-1, 1] to [0, 1], clamped.
fn normalizeNoise(n: f64) f64 {
    return @max(0.0, @min(1.0, (n + 1.0) * 0.5));
}

/// Convert a noise value [-1, 1] to a u4 in [0, 15].
fn noiseToU4(n: f64) u4 {
    return @intFromFloat(@round(normalizeNoise(n) * 15.0));
}

/// Convert a noise value to a grid offset in [0, GRID_SIZE-1].
fn noiseToGridOffset(pt: *const noise.PermTable, gx: f64, gz: f64, axis_offset: f64) i32 {
    const n = noise.noise2d(pt, gx * 0.53 + axis_offset * 37.0, gz * 0.53);
    const grid_f: f64 = @floatFromInt(GRID_SIZE);
    const raw: i32 = @intFromFloat(@round(normalizeNoise(n) * (grid_f - 1.0)));
    return @min(GRID_SIZE - 1, @max(0, raw));
}

/// Map a noise value to a StructureType.
fn noiseToStructureType(n: f64) StructureType {
    const t = normalizeNoise(n);

    if (t < 0.25) return .village_house;
    if (t < 0.40) return .village_church;
    if (t < 0.55) return .village_well;
    if (t < 0.70) return .dungeon;
    if (t < 0.85) return .desert_temple;
    return .mineshaft;
}

// ---------------------------------------------------------------------------
// Structure templates (compile-time arrays)
// ---------------------------------------------------------------------------

/// Village house: 5x4x5
/// - Cobblestone foundation (y=0)
/// - Oak log corners, oak planks walls (y=1..3)
/// - Air interior (y=1..2), oak planks roof interior (y=3)
const village_house_blocks = blk: {
    var buf: [256]StructureBlock = undefined;
    var count: usize = 0;

    // Foundation: cobblestone floor at y=0
    for (0..5) |z| {
        for (0..5) |x| {
            buf[count] = .{ .dx = @intCast(x), .dy = 0, .dz = @intCast(z), .block_id = block.COBBLESTONE };
            count += 1;
        }
    }

    // Walls and interior: y=1..3
    for (1..4) |y| {
        for (0..5) |z| {
            for (0..5) |x| {
                const is_edge_x = (x == 0 or x == 4);
                const is_edge_z = (z == 0 or z == 4);
                const is_corner = is_edge_x and is_edge_z;
                const is_wall = is_edge_x or is_edge_z;
                const is_roof_layer = (y == 3);

                if (is_corner) {
                    buf[count] = .{ .dx = @intCast(x), .dy = @intCast(y), .dz = @intCast(z), .block_id = block.OAK_LOG };
                } else if (is_wall or is_roof_layer) {
                    buf[count] = .{ .dx = @intCast(x), .dy = @intCast(y), .dz = @intCast(z), .block_id = block.OAK_PLANKS };
                } else {
                    buf[count] = .{ .dx = @intCast(x), .dy = @intCast(y), .dz = @intCast(z), .block_id = block.AIR };
                }
                count += 1;
            }
        }
    }

    break :blk buf[0..count].*;
};

/// Village well: 3x5x3
/// - Cobblestone walls, water at bottom (y=0)
/// - Hollow cobblestone column up to y=4
const village_well_blocks = blk: {
    var buf: [128]StructureBlock = undefined;
    var count: usize = 0;

    for (0..5) |y| {
        for (0..3) |z| {
            for (0..3) |x| {
                const is_edge_x = (x == 0 or x == 2);
                const is_edge_z = (z == 0 or z == 2);
                const is_wall = is_edge_x or is_edge_z;

                if (y == 0) {
                    if (is_wall) {
                        buf[count] = .{ .dx = @intCast(x), .dy = @intCast(y), .dz = @intCast(z), .block_id = block.COBBLESTONE };
                    } else {
                        buf[count] = .{ .dx = @intCast(x), .dy = @intCast(y), .dz = @intCast(z), .block_id = block.WATER };
                    }
                    count += 1;
                } else if (y == 4) {
                    // Top rim
                    buf[count] = .{ .dx = @intCast(x), .dy = @intCast(y), .dz = @intCast(z), .block_id = block.COBBLESTONE };
                    count += 1;
                } else if (is_wall) {
                    buf[count] = .{ .dx = @intCast(x), .dy = @intCast(y), .dz = @intCast(z), .block_id = block.COBBLESTONE };
                    count += 1;
                } else {
                    // Air interior
                    buf[count] = .{ .dx = @intCast(x), .dy = @intCast(y), .dz = @intCast(z), .block_id = block.AIR };
                    count += 1;
                }
            }
        }
    }

    break :blk buf[0..count].*;
};

/// Dungeon: 7x5x7
/// - Mossy cobblestone floor (y=0)
/// - Cobblestone walls (y=1..4)
/// - Air interior
/// - Cobblestone ceiling (y=4)
const dungeon_blocks = blk: {
    var buf: [512]StructureBlock = undefined;
    var count: usize = 0;

    for (0..5) |y| {
        for (0..7) |z| {
            for (0..7) |x| {
                const is_edge_x = (x == 0 or x == 6);
                const is_edge_z = (z == 0 or z == 6);
                const is_wall = is_edge_x or is_edge_z;

                if (y == 0) {
                    // Mossy cobblestone floor
                    buf[count] = .{ .dx = @intCast(x), .dy = @intCast(y), .dz = @intCast(z), .block_id = block.MOSSY_COBBLESTONE };
                    count += 1;
                } else if (y == 4) {
                    // Cobblestone ceiling
                    buf[count] = .{ .dx = @intCast(x), .dy = @intCast(y), .dz = @intCast(z), .block_id = block.COBBLESTONE };
                    count += 1;
                } else if (is_wall) {
                    buf[count] = .{ .dx = @intCast(x), .dy = @intCast(y), .dz = @intCast(z), .block_id = block.COBBLESTONE };
                    count += 1;
                } else {
                    // Air interior
                    buf[count] = .{ .dx = @intCast(x), .dy = @intCast(y), .dz = @intCast(z), .block_id = block.AIR };
                    count += 1;
                }
            }
        }
    }

    break :blk buf[0..count].*;
};

/// Desert temple: 9x8x9
/// - Sand floor and walls, hollow interior
/// - Sand walls on all edges, air inside
const desert_temple_blocks = blk: {
    var buf: [768]StructureBlock = undefined;
    var count: usize = 0;

    for (0..8) |y| {
        for (0..9) |z| {
            for (0..9) |x| {
                const is_edge_x = (x == 0 or x == 8);
                const is_edge_z = (z == 0 or z == 8);
                const is_wall = is_edge_x or is_edge_z;

                if (y == 0 or y == 7) {
                    // Floor and roof: full sand layer
                    buf[count] = .{ .dx = @intCast(x), .dy = @intCast(y), .dz = @intCast(z), .block_id = block.SAND };
                    count += 1;
                } else if (is_wall) {
                    buf[count] = .{ .dx = @intCast(x), .dy = @intCast(y), .dz = @intCast(z), .block_id = block.SAND };
                    count += 1;
                } else {
                    // Air interior
                    buf[count] = .{ .dx = @intCast(x), .dy = @intCast(y), .dz = @intCast(z), .block_id = block.AIR };
                    count += 1;
                }
            }
        }
    }

    break :blk buf[0..count].*;
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "placeStructure adds blocks to chunk" {
    var chunk = Chunk.init();
    const template = getTemplate(.village_house);
    placeStructure(&chunk, template, 2, 0, 2);

    // Count non-air blocks placed by the structure.
    var placed: u32 = 0;
    for (0..Chunk.VOLUME) |i| {
        if (chunk.blocks[i] != block.AIR) placed += 1;
    }
    try std.testing.expect(placed > 0);
}

test "village house template has correct dimensions" {
    const template = getTemplate(.village_house);
    try std.testing.expectEqual(@as(u8, 5), template.width);
    try std.testing.expectEqual(@as(u8, 4), template.height);
    try std.testing.expectEqual(@as(u8, 5), template.depth);

    // Verify all block offsets are within declared dimensions.
    for (template.blocks) |sb| {
        try std.testing.expect(sb.dx >= 0 and sb.dx < template.width);
        try std.testing.expect(sb.dy >= 0 and sb.dy < template.height);
        try std.testing.expect(sb.dz >= 0 and sb.dz < template.depth);
    }
}

test "village well template has correct dimensions" {
    const template = getTemplate(.village_well);
    try std.testing.expectEqual(@as(u8, 3), template.width);
    try std.testing.expectEqual(@as(u8, 5), template.height);
    try std.testing.expectEqual(@as(u8, 3), template.depth);

    for (template.blocks) |sb| {
        try std.testing.expect(sb.dx >= 0 and sb.dx < template.width);
        try std.testing.expect(sb.dy >= 0 and sb.dy < template.height);
        try std.testing.expect(sb.dz >= 0 and sb.dz < template.depth);
    }
}

test "dungeon template has correct dimensions" {
    const template = getTemplate(.dungeon);
    try std.testing.expectEqual(@as(u8, 7), template.width);
    try std.testing.expectEqual(@as(u8, 5), template.height);
    try std.testing.expectEqual(@as(u8, 7), template.depth);

    for (template.blocks) |sb| {
        try std.testing.expect(sb.dx >= 0 and sb.dx < template.width);
        try std.testing.expect(sb.dy >= 0 and sb.dy < template.height);
        try std.testing.expect(sb.dz >= 0 and sb.dz < template.depth);
    }
}

test "desert temple template has correct dimensions" {
    const template = getTemplate(.desert_temple);
    try std.testing.expectEqual(@as(u8, 9), template.width);
    try std.testing.expectEqual(@as(u8, 8), template.height);
    try std.testing.expectEqual(@as(u8, 9), template.depth);

    for (template.blocks) |sb| {
        try std.testing.expect(sb.dx >= 0 and sb.dx < template.width);
        try std.testing.expect(sb.dy >= 0 and sb.dy < template.height);
        try std.testing.expect(sb.dz >= 0 and sb.dz < template.depth);
    }
}

test "shouldPlaceStructure returns deterministic results" {
    const result_a = shouldPlaceStructure(42, 0, 0);
    const result_b = shouldPlaceStructure(42, 0, 0);

    // Both should be the same (either both null or both identical).
    if (result_a) |a| {
        const b = result_b.?;
        try std.testing.expectEqual(a.structure_type, b.structure_type);
        try std.testing.expectEqual(a.local_x, b.local_x);
        try std.testing.expectEqual(a.local_z, b.local_z);
    } else {
        try std.testing.expect(result_b == null);
    }
}

test "rare occurrence: most chunks have no structure" {
    const seed: u64 = 12345;
    var structure_count: u32 = 0;
    const range = 32; // Check 32x32 = 1024 chunks

    var cz: i32 = 0;
    while (cz < range) : (cz += 1) {
        var cx: i32 = 0;
        while (cx < range) : (cx += 1) {
            if (shouldPlaceStructure(seed, cx, cz) != null) {
                structure_count += 1;
            }
        }
    }

    const total_chunks = range * range;
    // Structures should be rare: fewer than 1 in 8 chunks on average.
    // With GRID_SIZE=8, we expect at most ~16 structures in a 32x32 area
    // (4x4 grid cells), and often fewer due to the noise threshold.
    try std.testing.expect(structure_count > 0); // At least some structures exist
    try std.testing.expect(structure_count < total_chunks / 8); // But they are rare
}

test "placeStructure clips blocks outside chunk bounds" {
    var chunk = Chunk.init();
    const template = getTemplate(.dungeon);

    // Place at edge so part of the 7x5x7 dungeon extends outside.
    placeStructure(&chunk, template, 12, 0, 12);

    // Blocks within bounds should be placed.
    var placed: u32 = 0;
    for (0..Chunk.VOLUME) |i| {
        if (chunk.blocks[i] != block.AIR) placed += 1;
    }
    try std.testing.expect(placed > 0);

    // But not as many as a fully interior placement.
    var chunk2 = Chunk.init();
    placeStructure(&chunk2, template, 2, 0, 2);
    var placed_full: u32 = 0;
    for (0..Chunk.VOLUME) |i| {
        if (chunk2.blocks[i] != block.AIR) placed_full += 1;
    }
    try std.testing.expect(placed > 0);
    try std.testing.expect(placed_full > placed);
}

test "village house has cobblestone foundation" {
    var chunk = Chunk.init();
    const template = getTemplate(.village_house);
    placeStructure(&chunk, template, 0, 0, 0);

    // Check that y=0 layer has cobblestone.
    var cobble_count: u32 = 0;
    for (0..5) |z| {
        for (0..5) |x| {
            if (chunk.getBlock(@intCast(x), 0, @intCast(z)) == block.COBBLESTONE) {
                cobble_count += 1;
            }
        }
    }
    try std.testing.expectEqual(@as(u32, 25), cobble_count); // 5x5 floor
}

test "village house has oak log corners" {
    var chunk = Chunk.init();
    const template = getTemplate(.village_house);
    placeStructure(&chunk, template, 0, 0, 0);

    // Check the four corners at y=1.
    try std.testing.expectEqual(block.OAK_LOG, chunk.getBlock(0, 1, 0));
    try std.testing.expectEqual(block.OAK_LOG, chunk.getBlock(4, 1, 0));
    try std.testing.expectEqual(block.OAK_LOG, chunk.getBlock(0, 1, 4));
    try std.testing.expectEqual(block.OAK_LOG, chunk.getBlock(4, 1, 4));
}

test "dungeon has mossy cobblestone floor" {
    var chunk = Chunk.init();
    const template = getTemplate(.dungeon);
    placeStructure(&chunk, template, 0, 0, 0);

    // Check that floor (y=0) is all mossy cobblestone.
    for (0..7) |z| {
        for (0..7) |x| {
            try std.testing.expectEqual(
                block.MOSSY_COBBLESTONE,
                chunk.getBlock(@intCast(x), 0, @intCast(z)),
            );
        }
    }
}

test "village well has water at bottom center" {
    var chunk = Chunk.init();
    const template = getTemplate(.village_well);
    placeStructure(&chunk, template, 0, 0, 0);

    // Center of 3x3 at y=0 should be water.
    try std.testing.expectEqual(block.WATER, chunk.getBlock(1, 0, 1));
}

test "desert temple uses sand blocks" {
    var chunk = Chunk.init();
    const template = getTemplate(.desert_temple);
    placeStructure(&chunk, template, 0, 0, 0);

    // Floor (y=0) should be sand.
    var sand_count: u32 = 0;
    for (0..9) |z| {
        for (0..9) |x| {
            if (chunk.getBlock(@intCast(x), 0, @intCast(z)) == block.SAND) {
                sand_count += 1;
            }
        }
    }
    try std.testing.expectEqual(@as(u32, 81), sand_count); // 9x9 floor
}
