/// Tree generation for oak trees.
/// Places trees on grass blocks at noise-determined positions after terrain
/// generation. Each tree consists of an oak-log trunk (4-6 blocks) topped by a
/// 5x5x3 leaf canopy with corners removed.
const std = @import("std");
const Chunk = @import("../chunk.zig");
const block = @import("../block.zig");
const noise = @import("../noise.zig");

// ---------------------------------------------------------------------------
// Tree parameters
// ---------------------------------------------------------------------------

/// Frequency multiplier applied to world coordinates for tree-placement noise.
/// Deliberately different from the terrain frequency so tree distribution is
/// independent of the heightmap.
const TREE_NOISE_FREQ: f64 = 0.3;

/// Noise threshold above which a candidate position gets a tree.  Tuned so
/// that roughly 2-4 positions per 16x16 chunk exceed it.
const TREE_NOISE_THRESHOLD: f64 = 0.35;

/// Seed offset mixed into the base seed so tree noise uses a completely
/// different permutation table from terrain noise.
const TREE_SEED_OFFSET: u64 = 73_856_093;

/// A second, independent noise layer used to vary trunk height per tree.
const TRUNK_HEIGHT_SEED_OFFSET: u64 = 19_349_669;

const MIN_TRUNK_HEIGHT: u4 = 4;
const MAX_TRUNK_HEIGHT: u4 = 6;

/// Minimum distance from chunk edge (in blocks) so that the 5x5 canopy does
/// not extend beyond the chunk boundary.  A 5x5 canopy centered on the trunk
/// extends 2 blocks in each horizontal direction.
const EDGE_MARGIN: u4 = 2;

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Place trees on a chunk after terrain generation.
/// Trees are placed at noise-determined positions on grass blocks.
pub fn placeTrees(chunk: *Chunk, seed: u64, chunk_x: i32, chunk_z: i32) void {
    const tree_pt = noise.PermTable.init(seed +% TREE_SEED_OFFSET);
    const height_pt = noise.PermTable.init(seed +% TRUNK_HEIGHT_SEED_OFFSET);

    const min: u4 = EDGE_MARGIN;
    const max: u4 = Chunk.SIZE - 1 - EDGE_MARGIN;

    var lz: u4 = min;
    while (lz <= max) : (lz += 1) {
        var lx: u4 = min;
        while (lx <= max) : (lx += 1) {
            const world_x: f64 = @floatFromInt(@as(i32, lx) +% chunk_x * @as(i32, Chunk.SIZE));
            const world_z: f64 = @floatFromInt(@as(i32, lz) +% chunk_z * @as(i32, Chunk.SIZE));

            const n = noise.noise2d(&tree_pt, world_x * TREE_NOISE_FREQ, world_z * TREE_NOISE_FREQ);
            if (n < TREE_NOISE_THRESHOLD) continue;

            const surface_y = findSurfaceGrass(chunk, lx, lz) orelse continue;

            const trunk_height = trunkHeightFor(&height_pt, world_x, world_z);

            placeTree(chunk, lx, surface_y, lz, trunk_height);
        }
    }
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/// Scan the column top-down and return the y coordinate of the topmost GRASS
/// block, or null if none exists.
fn findSurfaceGrass(chunk: *const Chunk, x: u4, z: u4) ?u4 {
    var y: u4 = Chunk.SIZE - 1;
    while (true) {
        if (chunk.getBlock(x, y, z) == block.GRASS) return y;
        if (y == 0) break;
        y -= 1;
    }
    return null;
}

/// Deterministically derive a trunk height in [MIN_TRUNK_HEIGHT, MAX_TRUNK_HEIGHT]
/// for a given world-space position using a second noise layer.
fn trunkHeightFor(pt: *const noise.PermTable, wx: f64, wz: f64) u4 {
    const min_f: f64 = comptime @floatFromInt(MIN_TRUNK_HEIGHT);
    const max_f: f64 = comptime @floatFromInt(MAX_TRUNK_HEIGHT);
    const n = noise.noise2d(pt, wx * 0.7, wz * 0.7);
    const t = (n + 1.0) * 0.5; // [-1,1] -> [0,1]
    const raw = min_f + t * (max_f - min_f);
    return @intFromFloat(@max(min_f, @min(max_f, @round(raw))));
}

/// Place a single oak tree: trunk of `trunk_height` logs starting one block
/// above `surface_y`, and a 5x5x3 leaf canopy (corners removed) at the top.
fn placeTree(chunk: *Chunk, x: u4, surface_y: u4, z: u4, trunk_height: u4) void {
    const base_y: i32 = @as(i32, surface_y) + 1;
    const top_y: i32 = base_y + @as(i32, trunk_height) - 1;

    // Abort if the tree would exceed the chunk height.
    if (top_y + 2 >= Chunk.SIZE) return; // +2 for the top canopy layer

    // --- Trunk ---
    {
        var y: i32 = base_y;
        while (y <= top_y) : (y += 1) {
            chunk.setBlock(x, @intCast(y), z, block.OAK_LOG);
        }
    }

    // --- Leaf canopy: 5x5x3 centered on trunk, corners removed ---
    const canopy_base: i32 = top_y; // canopy starts at the trunk top
    const canopy_top: i32 = canopy_base + 2; // 3 layers total

    var cy: i32 = canopy_base;
    while (cy <= canopy_top) : (cy += 1) {
        if (cy < 0 or cy >= Chunk.SIZE) continue;

        var dz: i32 = -2;
        while (dz <= 2) : (dz += 1) {
            var dx: i32 = -2;
            while (dx <= 2) : (dx += 1) {
                // Skip corners of the 5x5 square
                if (isCorner(dx, dz)) continue;

                // Skip the trunk column itself (already has OAK_LOG)
                if (dx == 0 and dz == 0 and cy <= top_y) continue;

                const bx: i32 = @as(i32, x) + dx;
                const bz: i32 = @as(i32, z) + dz;

                if (bx < 0 or bx >= Chunk.SIZE or bz < 0 or bz >= Chunk.SIZE) continue;

                const bx_u: u4 = @intCast(bx);
                const bz_u: u4 = @intCast(bz);
                const cy_u: u4 = @intCast(cy);

                // Don't overwrite existing solid blocks
                if (block.isSolid(chunk.getBlock(bx_u, cy_u, bz_u))) continue;

                chunk.setBlock(bx_u, cy_u, bz_u, block.OAK_LEAVES);
            }
        }
    }
}

/// Returns true for the four corners of a 5x5 square (offsets where both
/// |dx| and |dz| equal 2).
fn isCorner(dx: i32, dz: i32) bool {
    return (@abs(dx) == 2) and (@abs(dz) == 2);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "chunk after tree placement has OAK_LOG blocks" {
    var chunk = buildTestTerrain();
    placeTrees(&chunk, 42, 0, 0);

    var log_count: u32 = 0;
    for (0..Chunk.VOLUME) |i| {
        if (chunk.blocks[i] == block.OAK_LOG) log_count += 1;
    }
    try std.testing.expect(log_count > 0);
}

test "leaves surround trunk top" {
    var chunk = buildTestTerrain();
    placeTrees(&chunk, 42, 0, 0);

    // Find any OAK_LOG column and verify leaves around its top.
    const top = findAnyTrunkTop(&chunk) orelse return;
    const tx = top[0];
    const ty = top[1];
    const tz = top[2];

    // At least one adjacent block in the canopy ring should be OAK_LEAVES.
    var leaf_count: u32 = 0;
    const offsets = [_][2]i32{ .{ 1, 0 }, .{ -1, 0 }, .{ 0, 1 }, .{ 0, -1 } };
    for (offsets) |off| {
        const nx: i32 = @as(i32, tx) + off[0];
        const nz: i32 = @as(i32, tz) + off[1];
        if (nx < 0 or nx >= Chunk.SIZE or nz < 0 or nz >= Chunk.SIZE) continue;
        if (chunk.getBlock(@intCast(nx), ty, @intCast(nz)) == block.OAK_LEAVES) leaf_count += 1;
    }
    try std.testing.expect(leaf_count > 0);
}

test "no trees on non-grass blocks" {
    // Fill a chunk with stone (no grass) and ensure no trees are placed.
    var chunk = Chunk.initFilled(block.STONE);
    placeTrees(&chunk, 42, 0, 0);

    for (0..Chunk.VOLUME) |i| {
        try std.testing.expect(chunk.blocks[i] != block.OAK_LOG);
        try std.testing.expect(chunk.blocks[i] != block.OAK_LEAVES);
    }
}

test "deterministic - same seed produces same trees" {
    var a = buildTestTerrain();
    var b = buildTestTerrain();
    placeTrees(&a, 42, 0, 0);
    placeTrees(&b, 42, 0, 0);
    try std.testing.expectEqualSlices(block.BlockId, &a.blocks, &b.blocks);
}

test "leaves do not overwrite solid blocks" {
    // Run placeTrees on a chunk that already has trees -- the log count
    // should not decrease, proving leaves never overwrite solid logs.
    var chunk = buildTestTerrain();
    placeTrees(&chunk, 42, 0, 0);
    var log_count_before: u32 = 0;
    for (0..Chunk.VOLUME) |i| {
        if (chunk.blocks[i] == block.OAK_LOG) log_count_before += 1;
    }
    // Place again (double-run) -- logs should be unchanged
    placeTrees(&chunk, 42, 0, 0);
    var log_count_after: u32 = 0;
    for (0..Chunk.VOLUME) |i| {
        if (chunk.blocks[i] == block.OAK_LOG) log_count_after += 1;
    }
    try std.testing.expectEqual(log_count_before, log_count_after);
}

// ---------------------------------------------------------------------------
// Test utilities
// ---------------------------------------------------------------------------

/// Build a flat test terrain: bedrock at y=0, dirt y=1-7, grass at y=8.
/// This guarantees a known surface height for tree placement.
fn buildTestTerrain() Chunk {
    var chunk = Chunk.init();
    for (0..Chunk.SIZE) |z| {
        for (0..Chunk.SIZE) |x| {
            const xu: u4 = @intCast(x);
            const zu: u4 = @intCast(z);
            chunk.setBlock(xu, 0, zu, block.BEDROCK);
            var y: u4 = 1;
            while (y <= 7) : (y += 1) {
                chunk.setBlock(xu, y, zu, block.DIRT);
            }
            chunk.setBlock(xu, 8, zu, block.GRASS);
        }
    }
    return chunk;
}

/// Find the topmost OAK_LOG in the chunk and return its (x, y, z) or null.
fn findAnyTrunkTop(chunk: *const Chunk) ?[3]u4 {
    // Scan for all OAK_LOG blocks and find one whose block above is not OAK_LOG.
    var y: u4 = Chunk.SIZE - 1;
    while (true) {
        for (0..Chunk.SIZE) |z| {
            for (0..Chunk.SIZE) |x| {
                const xu: u4 = @intCast(x);
                const zu: u4 = @intCast(z);
                if (chunk.getBlock(xu, y, zu) == block.OAK_LOG) {
                    // Check the block above is NOT a log (this is the trunk top).
                    if (y == Chunk.SIZE - 1 or chunk.getBlock(xu, y + 1, zu) != block.OAK_LOG) {
                        return .{ xu, y, zu };
                    }
                }
            }
        }
        if (y == 0) break;
        y -= 1;
    }
    return null;
}
