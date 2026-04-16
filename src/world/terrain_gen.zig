/// Procedural terrain generator using noise-based heightmaps.
/// Generates a 16x16x16 chunk at a given chunk coordinate with layered
/// bedrock / stone / dirt / grass blocks.
const std = @import("std");
const noise = @import("noise.zig");
const Chunk = @import("chunk.zig");
const block = @import("block.zig");

/// Height parameters
const BASE_HEIGHT: f64 = 8.0; // base terrain height within the chunk (y range 0..15)
const HEIGHT_SCALE: f64 = 5.0; // amplitude of height variation
const NOISE_SCALE: f64 = 0.05; // spatial frequency (lower = smoother hills)
const OCTAVES: u32 = 4;
const LACUNARITY: f64 = 2.0;
const PERSISTENCE: f64 = 0.5;

/// Generate a chunk at the given chunk coordinates.
/// chunk_x/chunk_z are in chunk space (each unit = 16 blocks).
pub fn generateChunk(seed: u64, chunk_x: i32, chunk_z: i32) Chunk {
    var chunk = Chunk.init();

    const base_x: f64 = @floatFromInt(@as(i64, chunk_x) * Chunk.SIZE);
    const base_z: f64 = @floatFromInt(@as(i64, chunk_z) * Chunk.SIZE);

    for (0..Chunk.SIZE) |xi| {
        for (0..Chunk.SIZE) |zi| {
            const world_x = base_x + @as(f64, @floatFromInt(xi));
            const world_z = base_z + @as(f64, @floatFromInt(zi));

            // Sample noise to get terrain height (0..15 range, clamped to chunk)
            const n = noise.fbm2dSeeded(seed, world_x * NOISE_SCALE, world_z * NOISE_SCALE, OCTAVES, LACUNARITY, PERSISTENCE);
            const raw_height = BASE_HEIGHT + n * HEIGHT_SCALE;
            const height: u4 = @intCast(std.math.clamp(@as(i32, @intFromFloat(@round(raw_height))), 1, 15));

            const bx: u4 = @intCast(xi);
            const bz: u4 = @intCast(zi);

            // Fill column
            for (0..@as(usize, height) + 1) |yi| {
                const by: u4 = @intCast(yi);
                if (yi == 0) {
                    chunk.setBlock(bx, by, bz, block.BEDROCK);
                } else if (yi < @as(usize, height) -| 3) {
                    chunk.setBlock(bx, by, bz, block.STONE);
                } else if (yi < @as(usize, height)) {
                    chunk.setBlock(bx, by, bz, block.DIRT);
                } else {
                    chunk.setBlock(bx, by, bz, block.GRASS);
                }
            }
        }
    }

    return chunk;
}

// --- Tests ---

test "generateChunk returns non-empty chunk" {
    const chunk = generateChunk(42, 0, 0);
    // Bedrock at y=0 should always exist everywhere
    for (0..Chunk.SIZE) |xi| {
        for (0..Chunk.SIZE) |zi| {
            const bx: u4 = @intCast(xi);
            const bz: u4 = @intCast(zi);
            try std.testing.expectEqual(block.BEDROCK, chunk.getBlock(bx, 0, bz));
        }
    }
}

test "generateChunk has grass on top" {
    const chunk = generateChunk(42, 0, 0);
    // At least one column should have grass at its top
    var found_grass = false;
    for (0..Chunk.SIZE) |xi| {
        for (0..Chunk.SIZE) |zi| {
            const bx: u4 = @intCast(xi);
            const bz: u4 = @intCast(zi);
            // Scan from top down to find the highest non-air block
            var y: u4 = 15;
            while (true) {
                const id = chunk.getBlock(bx, y, bz);
                if (id != block.AIR) {
                    if (id == block.GRASS) found_grass = true;
                    break;
                }
                if (y == 0) break;
                y -= 1;
            }
        }
    }
    try std.testing.expect(found_grass);
}

test "different chunk coords produce different terrain" {
    const c1 = generateChunk(42, 0, 0);
    const c2 = generateChunk(42, 3, 3);
    // Compare a sampling of blocks -- they should differ somewhere
    var differ = false;
    for (0..Chunk.SIZE) |xi| {
        for (0..Chunk.SIZE) |zi| {
            const bx: u4 = @intCast(xi);
            const bz: u4 = @intCast(zi);
            if (c1.getBlock(bx, 5, bz) != c2.getBlock(bx, 5, bz)) {
                differ = true;
                break;
            }
        }
        if (differ) break;
    }
    try std.testing.expect(differ);
}

test "different seeds produce different terrain" {
    const c1 = generateChunk(42, 0, 0);
    const c2 = generateChunk(999, 0, 0);
    var differ = false;
    for (0..Chunk.SIZE) |xi| {
        for (0..Chunk.SIZE) |zi| {
            const bx: u4 = @intCast(xi);
            const bz: u4 = @intCast(zi);
            if (c1.getBlock(bx, 5, bz) != c2.getBlock(bx, 5, bz)) {
                differ = true;
                break;
            }
        }
        if (differ) break;
    }
    try std.testing.expect(differ);
}
