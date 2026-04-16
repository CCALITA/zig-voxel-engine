/// Cave generation using 3D Perlin noise.
/// Called after terrain generation but before tree placement to carve
/// underground cave networks into solid terrain.
const std = @import("std");
const Chunk = @import("chunk");
const block = @import("block");
const noise = @import("noise");

/// Noise frequency — controls the spatial scale of caves.
/// Lower values produce larger, more open caves; higher values
/// produce tighter, more winding tunnels.
const NOISE_SCALE: f64 = 0.07;

/// A second, higher-frequency layer adds detail and variety.
const NOISE_SCALE_2: f64 = NOISE_SCALE * 2.0;

/// Amplitude weight for the second octave (relative to the first).
const OCTAVE2_WEIGHT: f64 = 0.5;

/// Blocks are carved to air when the combined noise exceeds this value.
/// Perlin noise output at scale 0.07 rarely reaches extreme values within
/// a single chunk, so 0.35 produces medium-sized cave networks.
const CAVE_THRESHOLD: f64 = 0.35;

/// Seed offset applied to the cave noise so it does not correlate with
/// the terrain-height noise that uses the base seed.
const SEED_OFFSET: u64 = 12345;

/// Maximum y-level (exclusive) that the carver will touch.
/// Blocks at y >= this value are never carved, preventing skylight holes
/// near the surface.
const MAX_CARVE_Y: u4 = 12;

/// Carve caves into a chunk using 3D noise.
/// Called after terrain generation but before tree placement.
pub fn carveCaves(chunk: *Chunk, seed: u64, chunk_x: i32, chunk_z: i32) void {
    const pt = noise.PermTable.init(seed +% SEED_OFFSET);

    const base_x: f64 = @floatFromInt(@as(i64, chunk_x) * Chunk.SIZE);
    const base_z: f64 = @floatFromInt(@as(i64, chunk_z) * Chunk.SIZE);

    for (1..MAX_CARVE_Y) |y| {
        const wy: f64 = @floatFromInt(y);

        for (0..Chunk.SIZE) |z| {
            const wz: f64 = base_z + @as(f64, @floatFromInt(z));

            for (0..Chunk.SIZE) |x| {
                const wx: f64 = base_x + @as(f64, @floatFromInt(x));

                const current = chunk.getBlock(@intCast(x), @intCast(y), @intCast(z));

                if (current == block.BEDROCK or !block.isSolid(current)) continue;

                const n1 = noise.noise3d(&pt, wx * NOISE_SCALE, wy * NOISE_SCALE, wz * NOISE_SCALE);
                const n2 = noise.noise3d(&pt, wx * NOISE_SCALE_2, wy * NOISE_SCALE_2, wz * NOISE_SCALE_2);
                const combined = (n1 + n2 * OCTAVE2_WEIGHT) / (1.0 + OCTAVE2_WEIGHT);

                if (combined > CAVE_THRESHOLD) {
                    chunk.setBlock(@intCast(x), @intCast(y), @intCast(z), block.AIR);
                }
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "carved chunk has fewer solid blocks than uncarved" {
    var chunk = stoneChunkWithBedrock();

    const solid_before = countSolid(&chunk);

    carveCaves(&chunk, 42, 0, 0);

    const solid_after = countSolid(&chunk);
    try std.testing.expect(solid_after < solid_before);
}

test "bedrock at y=0 is preserved" {
    var chunk = stoneChunkWithBedrock();

    carveCaves(&chunk, 42, 0, 0);

    for (0..Chunk.SIZE) |z| {
        for (0..Chunk.SIZE) |x| {
            try std.testing.expectEqual(
                block.BEDROCK,
                chunk.getBlock(@intCast(x), 0, @intCast(z)),
            );
        }
    }
}

test "some air blocks exist below the surface after carving" {
    var chunk = stoneChunkWithBedrock();

    carveCaves(&chunk, 42, 0, 0);

    var air_count: u32 = 0;
    for (1..MAX_CARVE_Y) |y| {
        for (0..Chunk.SIZE) |z| {
            for (0..Chunk.SIZE) |x| {
                if (chunk.getBlock(@intCast(x), @intCast(y), @intCast(z)) == block.AIR) {
                    air_count += 1;
                }
            }
        }
    }
    try std.testing.expect(air_count > 0);
}

test "deterministic: same seed produces same caves" {
    var chunk_a = Chunk.initFilled(block.STONE);
    var chunk_b = Chunk.initFilled(block.STONE);

    carveCaves(&chunk_a, 99, 3, -7);
    carveCaves(&chunk_b, 99, 3, -7);

    try std.testing.expectEqualSlices(block.BlockId, &chunk_a.blocks, &chunk_b.blocks);
}

test "different seeds produce different caves" {
    var chunk_a = Chunk.initFilled(block.STONE);
    var chunk_b = Chunk.initFilled(block.STONE);

    carveCaves(&chunk_a, 1, 0, 0);
    carveCaves(&chunk_b, 2, 0, 0);

    var diffs: u32 = 0;
    for (0..Chunk.VOLUME) |i| {
        if (chunk_a.blocks[i] != chunk_b.blocks[i]) diffs += 1;
    }
    try std.testing.expect(diffs > 0);
}

test "blocks at y >= MAX_CARVE_Y are never carved" {
    var chunk = Chunk.initFilled(block.STONE);

    carveCaves(&chunk, 42, 0, 0);

    for (MAX_CARVE_Y..Chunk.SIZE) |y| {
        for (0..Chunk.SIZE) |z| {
            for (0..Chunk.SIZE) |x| {
                try std.testing.expectEqual(
                    block.STONE,
                    chunk.getBlock(@intCast(x), @intCast(y), @intCast(z)),
                );
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

fn countSolid(chunk: *const Chunk) u32 {
    var count: u32 = 0;
    for (chunk.blocks) |id| {
        if (block.isSolid(id)) count += 1;
    }
    return count;
}

/// Stone-filled chunk with bedrock at y=0, used by multiple tests.
fn stoneChunkWithBedrock() Chunk {
    var chunk = Chunk.initFilled(block.STONE);
    for (0..Chunk.SIZE) |z| {
        for (0..Chunk.SIZE) |x| {
            chunk.setBlock(@intCast(x), 0, @intCast(z), block.BEDROCK);
        }
    }
    return chunk;
}
