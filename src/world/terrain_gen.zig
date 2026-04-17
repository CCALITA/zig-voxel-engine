/// Terrain generator that populates a Chunk given world-space chunk
/// coordinates and a seed.  Uses biome-aware heightmaps, cave carving,
/// ore vein placement, structure generation, and tree placement for
/// varied world generation.
///
/// Generation order (column): fill columns (biome-driven) -> place ore veins
///   -> carve caves -> place structures -> place trees.
/// Generation order (chunk):  fill columns (biome-driven) -> carve caves
///   -> place trees.
const std = @import("std");
const Chunk = @import("chunk.zig");
const ChunkColumn = @import("chunk_column.zig");
const block = @import("block.zig");
const noise = @import("noise.zig");
const biome = @import("biome.zig");
const caves = @import("worldgen/caves.zig");
const trees = @import("worldgen/trees.zig");
const structures = @import("worldgen/structures.zig");

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

/// Sea level for the 256-high world. Columns with terrain below this height
/// are filled with water up to SEA_LEVEL.
const SEA_LEVEL: u8 = 62;

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

            // Fill ocean water for columns below sea level
            if (terrain_height < SEA_LEVEL) {
                var y: u8 = terrain_height + 1;
                while (y <= SEA_LEVEL) : (y += 1) {
                    column.setBlock(@intCast(lx), y, @intCast(lz), block.WATER);
                }
            }
        }
    }

    // --- Phase 2: Place ore veins (before cave carving so caves cut through ores) ---
    placeOreVeins(&column, seed, chunk_x, chunk_z);

    // --- Phase 3: Carve caves across all terrain sections ---
    carveCavesInColumn(&column, seed, chunk_x, chunk_z);

    // --- Phase 4: Place structures at surface level ---
    if (structures.shouldPlaceStructure(seed, chunk_x, chunk_z)) |result| {
        const template = structures.getTemplate(result.structure_type);
        const surface_y = column.getHeight(result.local_x, result.local_z);
        const origin_y: i32 = @as(i32, surface_y) + 1;
        placeStructureInColumn(
            &column,
            template,
            @as(i32, result.local_x),
            origin_y,
            @as(i32, result.local_z),
        );
    }

    // --- Phase 5: Place trees on surface sections ---
    if (chunkHasTrees(&biome_noise, chunk_x, chunk_z)) {
        placeTreesInColumn(&column, seed, chunk_x, chunk_z);
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
// Ore vein generation
// ---------------------------------------------------------------------------

/// Seed offset for ore noise so it does not correlate with terrain/cave noise.
const ORE_SEED_OFFSET: u64 = 99999;

/// Noise scale for ore placement -- higher frequency than terrain for
/// fine-grained pocket distribution.
const ORE_NOISE_SCALE: f64 = 0.15;

/// Configuration for each ore type: block id, max height, number of
/// placement attempts per chunk column, min and max vein size, and the
/// noise threshold that must be exceeded for placement.
const OreConfig = struct {
    block_id: block.BlockId,
    max_y: u8,
    attempts: u8,
    min_vein: u8,
    max_vein: u8,
    threshold: f64,
};

const ore_configs = [_]OreConfig{
    .{ .block_id = block.COAL_ORE, .max_y = 127, .attempts = 20, .min_vein = 8, .max_vein = 12, .threshold = 0.3 },
    .{ .block_id = block.IRON_ORE, .max_y = 63, .attempts = 10, .min_vein = 4, .max_vein = 8, .threshold = 0.35 },
    .{ .block_id = block.GOLD_ORE, .max_y = 31, .attempts = 4, .min_vein = 4, .max_vein = 6, .threshold = 0.4 },
    .{ .block_id = block.DIAMOND_ORE, .max_y = 15, .attempts = 2, .min_vein = 2, .max_vein = 4, .threshold = 0.45 },
    .{ .block_id = block.REDSTONE_ORE, .max_y = 15, .attempts = 4, .min_vein = 4, .max_vein = 8, .threshold = 0.4 },
};

/// Place ore veins throughout a chunk column. Uses 3D noise to find
/// candidate positions within stone, then spreads each vein to adjacent
/// stone blocks up to the configured vein size.
fn placeOreVeins(column: *ChunkColumn, seed: u64, chunk_x: i32, chunk_z: i32) void {
    const pt = noise.PermTable.init(seed +% ORE_SEED_OFFSET);
    const cx: f64 = @floatFromInt(chunk_x);
    const cz: f64 = @floatFromInt(chunk_z);

    for (ore_configs, 0..) |cfg, ore_idx| {
        const ore_offset: f64 = @floatFromInt(ore_idx * 1000);

        for (0..cfg.attempts) |attempt| {
            const attempt_offset: f64 = @floatFromInt(attempt * 137);

            const nx = noise.noise3d(
                &pt,
                cx * 3.17 + attempt_offset + ore_offset,
                0.0,
                cz * 3.17,
            );
            const ny = noise.noise3d(
                &pt,
                cx * 2.31,
                attempt_offset * 0.73 + ore_offset,
                cz * 2.31,
            );
            const nz = noise.noise3d(
                &pt,
                cx * 2.89 + ore_offset,
                cz * 2.89,
                attempt_offset * 0.91,
            );

            const lx: u4 = @intFromFloat(@round(normalizeNoise01(nx) * 15.0));
            const raw_y = normalizeNoise01(ny) * @as(f64, @floatFromInt(cfg.max_y));
            const ly: u8 = @intFromFloat(@max(1.0, @min(@as(f64, @floatFromInt(cfg.max_y)), @round(raw_y))));
            const lz: u4 = @intFromFloat(@round(normalizeNoise01(nz) * 15.0));

            if (column.getBlock(lx, ly, lz) != block.STONE) continue;

            const world_x: f64 = @floatFromInt(@as(i32, @intCast(lx)) +% chunk_x *% @as(i32, Chunk.SIZE));
            const world_z: f64 = @floatFromInt(@as(i32, @intCast(lz)) +% chunk_z *% @as(i32, Chunk.SIZE));
            const world_y: f64 = @floatFromInt(ly);

            const placement_n = noise.noise3d(
                &pt,
                world_x * ORE_NOISE_SCALE + ore_offset,
                world_y * ORE_NOISE_SCALE,
                world_z * ORE_NOISE_SCALE + ore_offset,
            );

            if (placement_n < cfg.threshold) continue;

            column.setBlock(lx, ly, lz, cfg.block_id);

            const vein_size = cfg.min_vein + @as(u8, @intFromFloat(
                normalizeNoise01(placement_n) * @as(f64, @floatFromInt(cfg.max_vein - cfg.min_vein)),
            ));
            const vein_offset = ore_offset + attempt_offset;
            spreadVein(column, lx, ly, lz, cfg.block_id, vein_size, &pt, vein_offset);
        }
    }
}

/// Spread ore from a seed position to adjacent stone blocks via a
/// noise-guided random walk, placing up to `vein_size` blocks total.
fn spreadVein(
    column: *ChunkColumn,
    start_x: u4,
    start_y: u8,
    start_z: u4,
    ore_id: block.BlockId,
    vein_size: u8,
    pt: *const noise.PermTable,
    offset: f64,
) void {
    var cx: i32 = @intCast(start_x);
    var cy: i32 = @intCast(start_y);
    var cz: i32 = @intCast(start_z);
    var placed: u8 = 1; // seed block already placed
    var iterations: u8 = 0;
    const max_iterations: u8 = vein_size *| 3; // cap to prevent runaway walks

    const directions = [6][3]i32{
        .{ 1, 0, 0 },
        .{ -1, 0, 0 },
        .{ 0, 1, 0 },
        .{ 0, -1, 0 },
        .{ 0, 0, 1 },
        .{ 0, 0, -1 },
    };

    while (placed < vein_size and iterations < max_iterations) {
        iterations += 1;
        // Pick a direction using noise at current position + iteration
        const fx: f64 = @floatFromInt(cx);
        const fy: f64 = @floatFromInt(cy);
        const fz: f64 = @floatFromInt(cz);
        const step: f64 = @floatFromInt(iterations);
        const dir_noise = noise.noise3d(pt, fx * 0.7 + offset + step, fy * 0.7, fz * 0.7);
        const dir_idx: usize = @intFromFloat(@mod(normalizeNoise01(dir_noise) * 5.99, 6.0));
        const dir = directions[dir_idx];

        const nx_i = cx + dir[0];
        const ny_i = cy + dir[1];
        const nz_i = cz + dir[2];

        // Bounds check
        if (nx_i < 0 or nx_i > 15 or ny_i < 1 or ny_i > 255 or nz_i < 0 or nz_i > 15) {
            break;
        }

        const nx_u4: u4 = @intCast(nx_i);
        const ny_u8: u8 = @intCast(ny_i);
        const nz_u4: u4 = @intCast(nz_i);

        if (column.getBlock(nx_u4, ny_u8, nz_u4) == block.STONE) {
            column.setBlock(nx_u4, ny_u8, nz_u4, ore_id);
            placed += 1;
        }

        // Move to the neighbor position regardless (allows the walk to continue)
        cx = nx_i;
        cy = ny_i;
        cz = nz_i;
    }
}

// ---------------------------------------------------------------------------
// Structure placement for chunk columns
// ---------------------------------------------------------------------------

/// Place a structure into a ChunkColumn at a given world-y position.
/// Unlike `structures.placeStructure` which operates on a single 16x16x16
/// Chunk, this function handles blocks spanning multiple vertical sections.
fn placeStructureInColumn(
    column: *ChunkColumn,
    template: structures.StructureDef,
    origin_x: i32,
    origin_y: i32,
    origin_z: i32,
) void {
    for (template.blocks) |sb| {
        const wx = origin_x + @as(i32, sb.dx);
        const wy = origin_y + @as(i32, sb.dy);
        const wz = origin_z + @as(i32, sb.dz);

        // Bounds check: must fit within 16x256x16 column
        if (wx < 0 or wx >= Chunk.SIZE or
            wy < 0 or wy > 255 or
            wz < 0 or wz >= Chunk.SIZE) continue;

        column.setBlock(@intCast(wx), @intCast(wy), @intCast(wz), sb.block_id);
    }
}

// ---------------------------------------------------------------------------
// Column cave carving
// ---------------------------------------------------------------------------

/// Maximum world-space Y level for cave carving in the 256-high world.
/// Caves are carved from y=1 up to (but not including) this value.
const COL_MAX_CAVE_Y: u8 = 128;

/// Noise parameters matching caves.zig but applied to world-space coordinates.
const COL_CAVE_NOISE_SCALE: f64 = 0.07;
const COL_CAVE_NOISE_SCALE_2: f64 = COL_CAVE_NOISE_SCALE * 2.0;
const COL_CAVE_OCTAVE2_WEIGHT: f64 = 0.5;
const COL_CAVE_THRESHOLD: f64 = 0.35;
const COL_CAVE_SEED_OFFSET: u64 = 12345;

/// Carve caves across the full 256-high chunk column using 3D noise.
/// Uses the same noise algorithm as caves.zig but operates on world-space
/// Y coordinates spanning multiple sections.
fn carveCavesInColumn(column: *ChunkColumn, seed: u64, chunk_x: i32, chunk_z: i32) void {
    const pt = noise.PermTable.init(seed +% COL_CAVE_SEED_OFFSET);

    const base_x: f64 = @floatFromInt(@as(i64, chunk_x) * Chunk.SIZE);
    const base_z: f64 = @floatFromInt(@as(i64, chunk_z) * Chunk.SIZE);

    var y: u8 = 1;
    while (y < COL_MAX_CAVE_Y) : (y += 1) {
        const wy: f64 = @floatFromInt(y);

        for (0..Chunk.SIZE) |z| {
            const wz: f64 = base_z + @as(f64, @floatFromInt(z));

            for (0..Chunk.SIZE) |x| {
                const wx: f64 = base_x + @as(f64, @floatFromInt(x));

                const current = column.getBlock(@intCast(x), y, @intCast(z));

                if (current == block.BEDROCK or !block.isSolid(current)) continue;

                const n1 = noise.noise3d(&pt, wx * COL_CAVE_NOISE_SCALE, wy * COL_CAVE_NOISE_SCALE, wz * COL_CAVE_NOISE_SCALE);
                const n2 = noise.noise3d(&pt, wx * COL_CAVE_NOISE_SCALE_2, wy * COL_CAVE_NOISE_SCALE_2, wz * COL_CAVE_NOISE_SCALE_2);
                const combined = (n1 + n2 * COL_CAVE_OCTAVE2_WEIGHT) / (1.0 + COL_CAVE_OCTAVE2_WEIGHT);

                if (combined > COL_CAVE_THRESHOLD) {
                    column.setBlock(@intCast(x), y, @intCast(z), block.AIR);
                }
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Column tree placement
// ---------------------------------------------------------------------------

/// Tree noise parameters (matching trees.zig).
const COL_TREE_NOISE_FREQ: f64 = 0.3;
const COL_TREE_NOISE_THRESHOLD: f64 = 0.35;
const COL_TREE_SEED_OFFSET: u64 = 73_856_093;
const COL_TRUNK_HEIGHT_SEED_OFFSET: u64 = 19_349_669;
const COL_MIN_TRUNK_HEIGHT: u8 = 4;
const COL_MAX_TRUNK_HEIGHT: u8 = 6;
const COL_TREE_EDGE_MARGIN: u4 = 2;

/// Place trees in a chunk column. Scans the surface for grass blocks and
/// places oak trees at noise-determined positions.
fn placeTreesInColumn(column: *ChunkColumn, seed: u64, chunk_x: i32, chunk_z: i32) void {
    const tree_pt = noise.PermTable.init(seed +% COL_TREE_SEED_OFFSET);
    const height_pt = noise.PermTable.init(seed +% COL_TRUNK_HEIGHT_SEED_OFFSET);

    const min: u4 = COL_TREE_EDGE_MARGIN;
    const max: u4 = Chunk.SIZE - 1 - COL_TREE_EDGE_MARGIN;

    var lz: u4 = min;
    while (lz <= max) : (lz += 1) {
        var lx: u4 = min;
        while (lx <= max) : (lx += 1) {
            const world_x: f64 = @floatFromInt(@as(i32, lx) +% chunk_x * @as(i32, Chunk.SIZE));
            const world_z: f64 = @floatFromInt(@as(i32, lz) +% chunk_z * @as(i32, Chunk.SIZE));

            const n = noise.noise2d(&tree_pt, world_x * COL_TREE_NOISE_FREQ, world_z * COL_TREE_NOISE_FREQ);
            if (n < COL_TREE_NOISE_THRESHOLD) continue;

            // Find the topmost grass block in this column
            const surface_y = findSurfaceGrassInColumn(column, lx, lz) orelse continue;

            const trunk_height = colTrunkHeightFor(&height_pt, world_x, world_z);

            placeTreeInColumn(column, lx, surface_y, lz, trunk_height);
        }
    }
}

/// Scan a column top-down for the topmost GRASS block, returning its y or null.
fn findSurfaceGrassInColumn(column: *const ChunkColumn, x: u4, z: u4) ?u8 {
    const h = column.getHeight(x, z);
    if (h == 0) return null;
    if (column.getBlock(x, h, z) == block.GRASS) return h;
    // Scan downward a few blocks in case the very top is not grass
    var y: u8 = h;
    while (y > 0) {
        y -= 1;
        const b = column.getBlock(x, y, z);
        if (b == block.GRASS) return y;
        if (b == block.STONE) break;
    }
    return null;
}

/// Deterministically derive a trunk height for a column-world tree.
fn colTrunkHeightFor(pt: *const noise.PermTable, wx: f64, wz: f64) u8 {
    const min_f: f64 = @floatFromInt(COL_MIN_TRUNK_HEIGHT);
    const max_f: f64 = @floatFromInt(COL_MAX_TRUNK_HEIGHT);
    const n = noise.noise2d(pt, wx * 0.7, wz * 0.7);
    const t = (n + 1.0) * 0.5;
    const raw = min_f + t * (max_f - min_f);
    return @intFromFloat(@max(min_f, @min(max_f, @round(raw))));
}

/// Place a single oak tree in a chunk column starting above surface_y.
fn placeTreeInColumn(column: *ChunkColumn, x: u4, surface_y: u8, z: u4, trunk_height: u8) void {
    const base_y: i32 = @as(i32, surface_y) + 1;
    const top_y: i32 = base_y + @as(i32, trunk_height) - 1;
    const canopy_top: i32 = top_y + 2;

    // Abort if tree would exceed world height
    if (canopy_top > 255) return;

    // --- Trunk ---
    {
        var y: i32 = base_y;
        while (y <= top_y) : (y += 1) {
            column.setBlock(x, @intCast(y), z, block.OAK_LOG);
        }
    }

    // --- Leaf canopy: 5x5x3 centered on trunk, corners removed ---
    const canopy_base: i32 = top_y;

    var cy: i32 = canopy_base;
    while (cy <= canopy_top) : (cy += 1) {
        if (cy < 0 or cy > 255) continue;

        var dz: i32 = -2;
        while (dz <= 2) : (dz += 1) {
            var dx: i32 = -2;
            while (dx <= 2) : (dx += 1) {
                // Skip corners of the 5x5 square
                if ((@abs(dx) == 2) and (@abs(dz) == 2)) continue;

                // Skip the trunk column itself (already has OAK_LOG)
                if (dx == 0 and dz == 0 and cy <= top_y) continue;

                const bx: i32 = @as(i32, x) + dx;
                const bz: i32 = @as(i32, z) + dz;

                if (bx < 0 or bx >= Chunk.SIZE or bz < 0 or bz >= Chunk.SIZE) continue;

                const bx_u: u4 = @intCast(bx);
                const bz_u: u4 = @intCast(bz);
                const cy_u: u8 = @intCast(cy);

                // Don't overwrite existing solid blocks
                if (block.isSolid(column.getBlock(bx_u, cy_u, bz_u))) continue;

                column.setBlock(bx_u, cy_u, bz_u, block.OAK_LEAVES);
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/// Normalize a Perlin noise value from [-1, 1] to [0, 1], clamped.
fn normalizeNoise01(n: f64) f64 {
    return @max(0.0, @min(1.0, (n + 1.0) * 0.5));
}

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
                // Surface may be overwritten by caves (AIR), trees (OAK_LOG,
                // OAK_LEAVES), structures, or ocean water (WATER).
                const is_expected = (surface == biome_def.surface_block or
                    surface == block.OAK_LOG or
                    surface == block.OAK_LEAVES or
                    surface == block.WATER or
                    surface == block.COBBLESTONE or
                    surface == block.OAK_PLANKS or
                    surface == block.MOSSY_COBBLESTONE);
                try std.testing.expect(is_expected);
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
            // With structures the height may exceed 128 (structure on top of terrain)
            try std.testing.expect(h <= 200);
        }
    }
}

// ---------------------------------------------------------------------------
// Ore vein tests
// ---------------------------------------------------------------------------

test "column: ore veins place ore blocks in stone" {
    const col = generateColumn(std.testing.allocator, 42, 0, 0);

    // Count ore blocks across the entire column
    var ore_count: u32 = 0;
    const ore_ids = [_]block.BlockId{
        block.COAL_ORE,
        block.IRON_ORE,
        block.GOLD_ORE,
        block.DIAMOND_ORE,
        block.REDSTONE_ORE,
    };

    for (0..ChunkColumn.SECTIONS) |s| {
        if (col.sections[s]) |sec| {
            for (0..Chunk.VOLUME) |i| {
                for (ore_ids) |ore_id| {
                    if (sec.blocks[i] == ore_id) {
                        ore_count += 1;
                        break;
                    }
                }
            }
        }
    }

    // With the noise-based placement, we expect at least some ores
    try std.testing.expect(ore_count > 0);
}

test "column: coal ore appears more often than diamond" {
    const col = generateColumn(std.testing.allocator, 42, 0, 0);

    var coal_count: u32 = 0;
    var diamond_count: u32 = 0;

    for (0..ChunkColumn.SECTIONS) |s| {
        if (col.sections[s]) |sec| {
            for (0..Chunk.VOLUME) |i| {
                if (sec.blocks[i] == block.COAL_ORE) coal_count += 1;
                if (sec.blocks[i] == block.DIAMOND_ORE) diamond_count += 1;
            }
        }
    }

    // Coal has 20 attempts vs diamond's 2, so coal should be more common
    try std.testing.expect(coal_count >= diamond_count);
}

test "column: diamond ore only below y=16" {
    const col = generateColumn(std.testing.allocator, 42, 0, 0);

    // Diamond ore is configured with max_y=15, so no diamond above section 0
    for (1..ChunkColumn.SECTIONS) |s| {
        if (col.sections[s]) |sec| {
            for (0..Chunk.VOLUME) |i| {
                try std.testing.expect(sec.blocks[i] != block.DIAMOND_ORE);
            }
        }
    }
}

test "column: ore vein determinism" {
    const a = generateColumn(std.testing.allocator, 777, 5, 5);
    const b = generateColumn(std.testing.allocator, 777, 5, 5);

    for (0..ChunkColumn.SECTIONS) |s| {
        const sa = a.sections[s];
        const sb = b.sections[s];
        if (sa == null and sb == null) continue;
        if (sa != null and sb != null) {
            try std.testing.expectEqualSlices(block.BlockId, &sa.?.blocks, &sb.?.blocks);
        } else {
            try std.testing.expect(false);
        }
    }
}

// ---------------------------------------------------------------------------
// Cave tests for column generation
// ---------------------------------------------------------------------------

test "column: caves create air pockets below surface" {
    const col = generateColumn(std.testing.allocator, 42, 0, 0);

    // Look for air blocks between y=1 and y=127 (cave carving range)
    var air_in_cave_zone: u32 = 0;
    for (0..8) |section_idx| {
        if (col.sections[section_idx]) |sec| {
            for (0..Chunk.VOLUME) |i| {
                const local_y = i / 256;
                const world_y = section_idx * 16 + local_y;
                // Skip y=0 (bedrock) and skip surface/above-surface air
                if (world_y == 0) continue;
                if (sec.blocks[i] == block.AIR) {
                    // Check if there is solid terrain above this air block,
                    // which indicates a cave rather than open sky
                    const x: u4 = @intCast(i % 16);
                    const z: u4 = @intCast((i / 16) % 16);
                    const h = col.getHeight(x, z);
                    if (world_y < h) {
                        air_in_cave_zone += 1;
                    }
                }
            }
        }
    }
    // Caves should have carved some blocks underground
    try std.testing.expect(air_in_cave_zone > 0);
}

test "column: caves do not carve bedrock" {
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

// ---------------------------------------------------------------------------
// Tree tests for column generation
// ---------------------------------------------------------------------------

test "column: trees place oak logs in terrain" {
    // Use a seed and coordinates that produce a forested biome
    const col = generateColumn(std.testing.allocator, 42, 0, 0);

    var log_count: u32 = 0;
    for (0..ChunkColumn.SECTIONS) |s| {
        if (col.sections[s]) |sec| {
            for (0..Chunk.VOLUME) |i| {
                if (sec.blocks[i] == block.OAK_LOG) log_count += 1;
            }
        }
    }
    // At least some trees should have been placed (structures also use OAK_LOG)
    try std.testing.expect(log_count > 0);
}

test "column: trees place leaves" {
    const col = generateColumn(std.testing.allocator, 42, 0, 0);

    var leaf_count: u32 = 0;
    for (0..ChunkColumn.SECTIONS) |s| {
        if (col.sections[s]) |sec| {
            for (0..Chunk.VOLUME) |i| {
                if (sec.blocks[i] == block.OAK_LEAVES) leaf_count += 1;
            }
        }
    }
    try std.testing.expect(leaf_count > 0);
}

// ---------------------------------------------------------------------------
// Ocean water tests for column generation
// ---------------------------------------------------------------------------

test "column: ocean water fills below sea level" {
    // Use a seed and chunk coordinates likely to produce ocean biome
    // (or at least some terrain below sea level).
    // Try multiple chunks to find one with terrain below sea level.
    var found_water = false;
    const seeds = [_]u64{ 42, 100, 200, 300 };
    const coords = [_][2]i32{ .{ 0, 0 }, .{ 10, 10 }, .{ -5, 3 }, .{ 20, -20 } };

    for (seeds) |seed| {
        for (coords) |coord| {
            const col = generateColumn(std.testing.allocator, seed, coord[0], coord[1]);
            for (0..ChunkColumn.SECTIONS) |s| {
                if (col.sections[s]) |sec| {
                    for (0..Chunk.VOLUME) |i| {
                        if (sec.blocks[i] == block.WATER) {
                            found_water = true;
                            break;
                        }
                    }
                }
                if (found_water) break;
            }
            if (found_water) break;
        }
        if (found_water) break;
    }
    try std.testing.expect(found_water);
}
