/// Terrain generator that populates a Chunk given world-space chunk
/// coordinates and a seed.  Uses Perlin noise for heightmap generation
/// and applies layer rules (bedrock, stone, dirt, grass/sand).
const std = @import("std");
const Chunk = @import("chunk.zig");
const block = @import("block.zig");
const noise = @import("noise.zig");

// ---------------------------------------------------------------------------
// Terrain parameters
// ---------------------------------------------------------------------------

const BASE_HEIGHT: f64 = 9.0; // midpoint of terrain height
const HEIGHT_VARIATION: f64 = 2.0; // +/- blocks around base
const NOISE_SCALE: f64 = 0.008; // world-space -> noise-space (lower = smoother hills)
const SAND_THRESHOLD: u4 = 7; // heights at or below this get sand on top
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
    var chunk = Chunk.init();

    for (0..Chunk.SIZE) |lz| {
        for (0..Chunk.SIZE) |lx| {
            const world_x: f64 = @floatFromInt(@as(i32, @intCast(lx)) +% chunk_x * @as(i32, Chunk.SIZE));
            const world_z: f64 = @floatFromInt(@as(i32, @intCast(lz)) +% chunk_z * @as(i32, Chunk.SIZE));

            const n = noise.fbm2d(
                &pt,
                world_x * NOISE_SCALE,
                world_z * NOISE_SCALE,
                FBM_OCTAVES,
                FBM_LACUNARITY,
                FBM_PERSISTENCE,
            );

            // Map noise [-1,1] -> height [BASE - VAR, BASE + VAR], clamped to [0, 15]
            const raw_height = BASE_HEIGHT + n * HEIGHT_VARIATION;
            const terrain_height = clampHeight(raw_height);

            fillColumn(&chunk, @intCast(lx), @intCast(lz), terrain_height);
        }
    }

    return chunk;
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

fn clampHeight(h: f64) u4 {
    const clamped = @max(0.0, @min(15.0, @round(h)));
    return @intFromFloat(clamped);
}

fn fillColumn(chunk: *Chunk, x: u4, z: u4, terrain_height: u4) void {
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

    // Dirt layer: from stone_top+1 up to terrain_height - 1
    const dirt_start: i32 = @max(1, stone_top + 1);
    const dirt_end: i32 = @as(i32, terrain_height) - 1;
    if (dirt_end >= dirt_start) {
        var y: i32 = dirt_start;
        while (y <= dirt_end) : (y += 1) {
            chunk.setBlock(x, @intCast(y), z, block.DIRT);
        }
    }

    // Surface block
    const surface_block: block.BlockId = if (terrain_height <= SAND_THRESHOLD)
        block.SAND
    else
        block.GRASS;
    chunk.setBlock(x, terrain_height, z, surface_block);
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

test "surface is grass or sand" {
    const chunk = generateChunk(std.testing.allocator, 42, 0, 0);
    for (0..Chunk.SIZE) |z| {
        for (0..Chunk.SIZE) |x| {
            // Find the topmost non-air block
            var top_y: ?u4 = null;
            var y: u4 = 15;
            while (true) {
                const b = chunk.getBlock(@intCast(x), y, @intCast(z));
                if (b != block.AIR) {
                    top_y = y;
                    break;
                }
                if (y == 0) break;
                y -= 1;
            }
            if (top_y) |ty| {
                const surface = chunk.getBlock(@intCast(x), ty, @intCast(z));
                const is_grass_or_sand = (surface == block.GRASS or surface == block.SAND);
                try std.testing.expect(is_grass_or_sand);
            }
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

test "stone below dirt below surface" {
    const chunk = generateChunk(std.testing.allocator, 42, 0, 0);
    for (0..Chunk.SIZE) |z| {
        for (0..Chunk.SIZE) |x| {
            var found_stone = false;
            var y: u4 = 15;
            // Scan top-down: dirt must not appear below stone
            while (true) {
                const b = chunk.getBlock(@intCast(x), y, @intCast(z));
                if (b == block.STONE) found_stone = true;
                if (b == block.DIRT) {
                    // Scanning top-down: if we already passed stone, dirt is below stone -- wrong
                    try std.testing.expect(!found_stone);
                }
                if (y == 0) break;
                y -= 1;
            }
        }
    }
}
