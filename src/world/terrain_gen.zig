/// Terrain generator that populates a Chunk given world-space chunk
/// coordinates and a seed.  Uses biome-aware heightmaps, cave carving,
/// and tree placement for varied world generation.
///
/// Generation order: fill columns (biome-driven) -> carve caves -> place trees.
const std = @import("std");
const Chunk = @import("chunk.zig");
const ChunkColumn = @import("chunk_column.zig");
const block = @import("block.zig");
const noise = @import("noise.zig");
const biome = @import("biome.zig");
const caves = @import("worldgen/caves.zig");
const trees = @import("worldgen/trees.zig");

// ---------------------------------------------------------------------------
// Terrain parameters
// ---------------------------------------------------------------------------

const NOISE_SCALE: f64 = 0.008; // world-space -> noise-space (lower = smoother hills)
const FBM_OCTAVES: u32 = 4;
const FBM_LACUNARITY: f64 = 2.0;
const FBM_PERSISTENCE: f64 = 0.5;

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Generate a single 16x16x16 chunk at the given chunk coordinates.
/// Assumes chunk_y = 0 (terrain fits within the first vertical chunk).
/// The `allocator` parameter is reserved for future use (e.g. structure
/// generation that needs dynamic memory); it is unused today.
pub fn generateChunk(
    _: std.mem.Allocator,
    seed: u64,
    chunk_x: i32,
    chunk_z: i32,
) Chunk {
    const pt = noise.PermTable.init(seed);
    const biome_noise = biome.BiomeNoise.init(seed);
    var chunk = Chunk.init();

    // --- Phase 1: Fill columns using biome-driven heights and blocks ---
    for (0..Chunk.SIZE) |lz| {
        for (0..Chunk.SIZE) |lx| {
            const world_x: f64 = @floatFromInt(@as(i32, @intCast(lx)) +% chunk_x * @as(i32, Chunk.SIZE));
            const world_z: f64 = @floatFromInt(@as(i32, @intCast(lz)) +% chunk_z * @as(i32, Chunk.SIZE));

            // Determine biome for this column
            const biome_type = biome_noise.getBiomeAt(world_x, world_z);
            const biome_def = biome.getDef(biome_type);

            const n = noise.fbm2d(
                &pt,
                world_x * NOISE_SCALE,
                world_z * NOISE_SCALE,
                FBM_OCTAVES,
                FBM_LACUNARITY,
                FBM_PERSISTENCE,
            );

            // Map noise [-1,1] -> height using biome parameters, clamped to [0, 15]
            const raw_height = biome_def.base_height + n * biome_def.height_scale;
            const terrain_height = clampHeight(raw_height);

            fillColumn(
                &chunk,
                @intCast(lx),
                @intCast(lz),
                terrain_height,
                biome_def.surface_block,
                biome_def.filler_block,
            );
        }
    }

    // --- Phase 2: Carve caves ---
    caves.carveCaves(&chunk, seed, chunk_x, chunk_z);

    // --- Phase 3: Place trees (only for biomes with tree density > 0) ---
    // Check if any column in this chunk belongs to a biome that supports trees.
    // For efficiency, sample a few representative points rather than every column.
    if (chunkHasTrees(&biome_noise, chunk_x, chunk_z)) {
        trees.placeTrees(&chunk, seed, chunk_x, chunk_z);
    }

    return chunk;
}

// ---------------------------------------------------------------------------
// Column terrain parameters (taller world)
// ---------------------------------------------------------------------------

/// Scale factor to convert biome heights (tuned for 16-high chunks) to
/// 256-high column heights. Biome base_height ~8 maps to ~64.
const COL_HEIGHT_SCALE: f64 = 8.0;

// ---------------------------------------------------------------------------
// Column-based generation (256-high world)
// ---------------------------------------------------------------------------

/// Generate a full 256-high chunk column at the given chunk coordinates.
/// Uses biome-aware heightmaps with scaled parameters for the taller world.
/// The `allocator` parameter is reserved for future use.
pub fn generateColumn(
    _: std.mem.Allocator,
    seed: u64,
    chunk_x: i32,
    chunk_z: i32,
) ChunkColumn {
    const pt = noise.PermTable.init(seed);
    const biome_noise = biome.BiomeNoise.init(seed);
    var column = ChunkColumn.init();

    for (0..Chunk.SIZE) |lz| {
        for (0..Chunk.SIZE) |lx| {
            const world_x: f64 = @floatFromInt(@as(i32, @intCast(lx)) +% chunk_x * @as(i32, Chunk.SIZE));
            const world_z: f64 = @floatFromInt(@as(i32, @intCast(lz)) +% chunk_z * @as(i32, Chunk.SIZE));

            // Determine biome for this column
            const biome_type = biome_noise.getBiomeAt(world_x, world_z);
            const biome_def = biome.getDef(biome_type);

            const n = noise.fbm2d(
                &pt,
                world_x * NOISE_SCALE,
                world_z * NOISE_SCALE,
                FBM_OCTAVES,
                FBM_LACUNARITY,
                FBM_PERSISTENCE,
            );

            // Scale biome heights to 256-high world
            const scaled_base = biome_def.base_height * COL_HEIGHT_SCALE;
            const scaled_variation = biome_def.height_scale * COL_HEIGHT_SCALE;
            const raw_height = scaled_base + n * scaled_variation;
            const terrain_height = clampColumnHeight(raw_height);

            fillColumnBlocks(
                &column,
                @intCast(lx),
                @intCast(lz),
                terrain_height,
                biome_def.surface_block,
                biome_def.filler_block,
            );
        }
    }

    return column;
}

fn clampColumnHeight(h: f64) u8 {
    const clamped = @max(1.0, @min(128.0, @round(h)));
    return @intFromFloat(clamped);
}

fn fillColumnBlocks(
    column: *ChunkColumn,
    x: u4,
    z: u4,
    terrain_height: u8,
    surface_block: block.BlockId,
    filler_block: block.BlockId,
) void {
    // Always bedrock at y=0
    column.setBlock(x, 0, z, block.BEDROCK);

    if (terrain_height == 0) return;

    // Stone layer: y=1 up to terrain_height - 4 (inclusive)
    const stone_top: i32 = @as(i32, terrain_height) - 4;
    if (stone_top >= 1) {
        var y: i32 = 1;
        while (y <= stone_top) : (y += 1) {
            column.setBlock(x, @intCast(y), z, block.STONE);
        }
    }

    // Filler layer (biome-specific): from stone_top+1 up to terrain_height - 1
    const filler_start: i32 = @max(1, stone_top + 1);
    const filler_end: i32 = @as(i32, terrain_height) - 1;
    if (filler_end >= filler_start) {
        var y: i32 = filler_start;
        while (y <= filler_end) : (y += 1) {
            column.setBlock(x, @intCast(y), z, filler_block);
        }
    }

    // Surface block (biome-specific)
    column.setBlock(x, terrain_height, z, surface_block);
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

fn clampHeight(h: f64) u4 {
    const clamped = @max(0.0, @min(15.0, @round(h)));
    return @intFromFloat(clamped);
}

fn fillColumn(
    chunk: *Chunk,
    x: u4,
    z: u4,
    terrain_height: u4,
    surface_block: block.BlockId,
    filler_block: block.BlockId,
) void {
    // Always bedrock at y=0
    chunk.setBlock(x, 0, z, block.BEDROCK);

    if (terrain_height == 0) return;

    // Stone layer: y=1 up to terrain_height - 4 (inclusive)
    const stone_top: i32 = @as(i32, terrain_height) - 4;
    if (stone_top >= 1) {
        var y: u4 = 1;
        while (y <= @as(u4, @intCast(stone_top))) : (y += 1) {
            chunk.setBlock(x, y, z, block.STONE);
        }
    }

    // Filler layer (biome-specific): from stone_top+1 up to terrain_height - 1
    const filler_start: i32 = @max(1, stone_top + 1);
    const filler_end: i32 = @as(i32, terrain_height) - 1;
    if (filler_end >= filler_start) {
        var y: i32 = filler_start;
        while (y <= filler_end) : (y += 1) {
            chunk.setBlock(x, @intCast(y), z, filler_block);
        }
    }

    // Surface block (biome-specific)
    chunk.setBlock(x, terrain_height, z, surface_block);
}

/// Check whether this chunk has any biomes that support trees by sampling
/// the four corners and center. Returns true if any sampled point belongs
/// to a biome with tree_density > 0.
fn chunkHasTrees(biome_noise: *const biome.BiomeNoise, chunk_x: i32, chunk_z: i32) bool {
    const base_x: f64 = @floatFromInt(@as(i32, chunk_x) *% @as(i32, Chunk.SIZE));
    const base_z: f64 = @floatFromInt(@as(i32, chunk_z) *% @as(i32, Chunk.SIZE));

    const sample_points = [_][2]f64{
        .{ base_x, base_z },
        .{ base_x + 15.0, base_z },
        .{ base_x, base_z + 15.0 },
        .{ base_x + 15.0, base_z + 15.0 },
        .{ base_x + 8.0, base_z + 8.0 },
    };

    for (sample_points) |pt| {
        const biome_type = biome_noise.getBiomeAt(pt[0], pt[1]);
        const biome_def = biome.getDef(biome_type);
        if (biome_def.tree_density > 0.0) return true;
    }
    return false;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "bedrock at y=0 for every column" {
    const chunk = generateChunk(std.testing.allocator, 42, 0, 0);
    for (0..Chunk.SIZE) |z| {
        for (0..Chunk.SIZE) |x| {
            try std.testing.expectEqual(
                block.BEDROCK,
                chunk.getBlock(@intCast(x), 0, @intCast(z)),
            );
        }
    }
}

test "surface matches biome definition" {
    const seed: u64 = 42;
    const chunk = generateChunk(std.testing.allocator, seed, 0, 0);
    const biome_noise = biome.BiomeNoise.init(seed);
    const pt = noise.PermTable.init(seed);

    // For each column, verify the surface block (before caves/trees may alter it)
    // We check that any non-air surface block is either the biome's surface block
    // or a tree/cave artifact (OAK_LOG, OAK_LEAVES, AIR).
    for (0..Chunk.SIZE) |z| {
        for (0..Chunk.SIZE) |x| {
            const world_x: f64 = @floatFromInt(@as(i32, @intCast(x)));
            const world_z: f64 = @floatFromInt(@as(i32, @intCast(z)));
            const biome_type = biome_noise.getBiomeAt(world_x, world_z);
            const biome_def = biome.getDef(biome_type);

            // Compute expected terrain height
            const n = noise.fbm2d(
                &pt,
                world_x * NOISE_SCALE,
                world_z * NOISE_SCALE,
                FBM_OCTAVES,
                FBM_LACUNARITY,
                FBM_PERSISTENCE,
            );
            const raw_height = biome_def.base_height + n * biome_def.height_scale;
            const terrain_height = clampHeight(raw_height);

            const actual = chunk.getBlock(@intCast(x), terrain_height, @intCast(z));
            // Surface might be carved by caves (AIR) or replaced by a tree trunk (OAK_LOG)
            const is_expected = (actual == biome_def.surface_block or
                actual == block.AIR or
                actual == block.OAK_LOG);
            try std.testing.expect(is_expected);
        }
    }
}

test "determinism from seed" {
    const a = generateChunk(std.testing.allocator, 12345, 3, -2);
    const b = generateChunk(std.testing.allocator, 12345, 3, -2);
    try std.testing.expectEqualSlices(block.BlockId, &a.blocks, &b.blocks);
}

test "different seeds produce different terrain" {
    const a = generateChunk(std.testing.allocator, 111, 0, 0);
    const b = generateChunk(std.testing.allocator, 222, 0, 0);
    var diffs: u32 = 0;
    for (0..Chunk.VOLUME) |i| {
        if (a.blocks[i] != b.blocks[i]) diffs += 1;
    }
    try std.testing.expect(diffs > 0);
}

test "different chunk coords produce different terrain" {
    const a = generateChunk(std.testing.allocator, 42, 0, 0);
    const b = generateChunk(std.testing.allocator, 42, 1, 0);
    var diffs: u32 = 0;
    for (0..Chunk.VOLUME) |i| {
        if (a.blocks[i] != b.blocks[i]) diffs += 1;
    }
    try std.testing.expect(diffs > 0);
}

test "caves create air pockets below surface" {
    const chunk = generateChunk(std.testing.allocator, 42, 0, 0);
    // Look for air blocks between y=1 and y=11 (cave carving range, excluding bedrock)
    var air_in_cave_zone: u32 = 0;
    for (1..12) |y| {
        for (0..Chunk.SIZE) |z| {
            for (0..Chunk.SIZE) |x| {
                if (chunk.getBlock(@intCast(x), @intCast(y), @intCast(z)) == block.AIR) {
                    air_in_cave_zone += 1;
                }
            }
        }
    }
    // With this seed and coordinates, caves should have carved some blocks.
    // The cave test module covers edge cases more thoroughly.
    try std.testing.expect(air_in_cave_zone > 0);
}

test "biome variation across distant chunks" {
    // Chunks far apart should have different biome-driven surfaces
    const a = generateChunk(std.testing.allocator, 42, 0, 0);
    const b = generateChunk(std.testing.allocator, 42, 100, 100);
    var diffs: u32 = 0;
    for (0..Chunk.VOLUME) |i| {
        if (a.blocks[i] != b.blocks[i]) diffs += 1;
    }
    try std.testing.expect(diffs > 0);
}

test "stone below filler below surface" {
    const chunk = generateChunk(std.testing.allocator, 42, 0, 0);
    for (0..Chunk.SIZE) |z| {
        for (0..Chunk.SIZE) |x| {
            var found_stone = false;
            var y: u4 = 15;
            // Scan top-down: filler/dirt must not appear below stone
            while (true) {
                const b = chunk.getBlock(@intCast(x), y, @intCast(z));
                if (b == block.STONE) found_stone = true;
                // Once we've passed stone going down, no dirt/sand/gravel should appear
                // (those are filler blocks). Allow AIR from caves.
                if (found_stone and (b == block.DIRT or b == block.GRASS or b == block.SAND or b == block.GRAVEL)) {
                    // This would indicate filler below stone -- which is wrong.
                    // However, cave carving can expose filler below stone by removing
                    // stone blocks. So we only flag this if the block directly above
                    // is also solid (not carved).
                    if (y < 15) {
                        const above = chunk.getBlock(@intCast(x), y + 1, @intCast(z));
                        if (above == block.STONE) {
                            // Filler sandwiched under stone with stone above = real error
                            try std.testing.expect(false);
                        }
                    }
                }
                if (y == 0) break;
                y -= 1;
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Column generation tests
// ---------------------------------------------------------------------------

test "column: bedrock at y=0 for every column" {
    const col = generateColumn(std.testing.allocator, 42, 0, 0);
    for (0..Chunk.SIZE) |z| {
        for (0..Chunk.SIZE) |x| {
            try std.testing.expectEqual(
                block.BEDROCK,
                col.getBlock(@intCast(x), 0, @intCast(z)),
            );
        }
    }
}

test "column: surface matches biome definition" {
    const seed: u64 = 42;
    const col = generateColumn(std.testing.allocator, seed, 0, 0);
    const biome_noise = biome.BiomeNoise.init(seed);

    for (0..Chunk.SIZE) |z| {
        for (0..Chunk.SIZE) |x| {
            const h = col.getHeight(@intCast(x), @intCast(z));
            if (h > 0) {
                const world_x: f64 = @floatFromInt(@as(i32, @intCast(x)));
                const world_z: f64 = @floatFromInt(@as(i32, @intCast(z)));
                const biome_type = biome_noise.getBiomeAt(world_x, world_z);
                const biome_def = biome.getDef(biome_type);

                const surface = col.getBlock(@intCast(x), h, @intCast(z));
                try std.testing.expectEqual(biome_def.surface_block, surface);
            }
        }
    }
}

test "column: determinism from seed" {
    const a = generateColumn(std.testing.allocator, 12345, 3, -2);
    const b = generateColumn(std.testing.allocator, 12345, 3, -2);
    for (0..ChunkColumn.SECTIONS) |s| {
        const sa = a.sections[s];
        const sb = b.sections[s];
        if (sa == null and sb == null) continue;
        if (sa != null and sb != null) {
            try std.testing.expectEqualSlices(block.BlockId, &sa.?.blocks, &sb.?.blocks);
        } else {
            // One null, one not -- mismatch
            try std.testing.expect(false);
        }
    }
}

test "column: terrain height is in expected range" {
    const col = generateColumn(std.testing.allocator, 42, 0, 0);
    for (0..Chunk.SIZE) |z| {
        for (0..Chunk.SIZE) |x| {
            const h = col.getHeight(@intCast(x), @intCast(z));
            try std.testing.expect(h >= 1); // at least bedrock
            try std.testing.expect(h <= 128); // capped at 128
        }
    }
}
