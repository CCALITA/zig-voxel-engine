/// Nether terrain generator.
/// Generates nether terrain for a ChunkColumn at given coordinates.
/// The Nether has: netherrack everywhere, lava ocean at y<=31,
/// caverns carved from 3D noise, glowstone clusters on ceiling,
/// and soul sand patches at low y values.
const std = @import("std");
const Chunk = @import("chunk.zig");
const ChunkColumn = @import("chunk_column.zig");
const block = @import("block.zig");
const noise = @import("noise.zig");

// ---------------------------------------------------------------------------
// Nether terrain parameters
// ---------------------------------------------------------------------------

/// Height of the nether ceiling (bedrock cap).
const CEILING_Y: u8 = 128;

/// Y level at or below which lava fills empty space.
const LAVA_LEVEL: u8 = 31;

/// Noise scale for the main cavern carving (lower = larger caves).
const CAVERN_NOISE_SCALE: f64 = 0.04;

/// Threshold above which 3D noise carves air. Lower = more open space.
const CAVERN_THRESHOLD: f64 = 0.4;

/// Noise scale for the secondary worm-like tunnels.
const TUNNEL_NOISE_SCALE: f64 = 0.08;

/// Threshold for tunnel carving (tighter than main caverns).
const TUNNEL_THRESHOLD: f64 = 0.55;

/// Noise scale for soul sand placement.
const SOUL_SAND_NOISE_SCALE: f64 = 0.07;

/// Threshold for soul sand patches. Higher = rarer patches.
const SOUL_SAND_THRESHOLD: f64 = 0.3;

/// Maximum y for soul sand patches.
const SOUL_SAND_MAX_Y: u8 = 40;

/// Noise scale for glowstone cluster placement.
const GLOWSTONE_NOISE_SCALE: f64 = 0.1;

/// Threshold for glowstone. Higher = rarer.
const GLOWSTONE_THRESHOLD: f64 = 0.6;

/// Minimum y for glowstone clusters (near ceiling).
const GLOWSTONE_MIN_Y: u8 = 120;

/// Maximum y for glowstone clusters.
const GLOWSTONE_MAX_Y: u8 = 127;

/// Seed offset to differentiate nether noise from overworld noise.
const NETHER_SEED_OFFSET: u64 = 0xDEAD_BEEF_CAFE_1337;

/// Bundle of permutation tables used across all nether generation phases.
const NoiseTables = struct {
    cavern: noise.PermTable,
    tunnel: noise.PermTable,
    soul_sand: noise.PermTable,
    glowstone: noise.PermTable,

    fn init(seed: u64) NoiseTables {
        return .{
            .cavern = noise.PermTable.init(seed),
            .tunnel = noise.PermTable.init(seed +% 1),
            .soul_sand = noise.PermTable.init(seed +% 2),
            .glowstone = noise.PermTable.init(seed +% 3),
        };
    }
};

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Generate nether terrain for a chunk column at the given coordinates.
/// The result is a 16x256x16 column populated with nether blocks.
pub fn generateChunk(seed: u64, chunk_x: i32, chunk_z: i32) ChunkColumn {
    const tables = NoiseTables.init(seed +% NETHER_SEED_OFFSET);
    var column = ChunkColumn.init();

    for (0..Chunk.SIZE) |lz| {
        for (0..Chunk.SIZE) |lx| {
            const world_x: f64 = @floatFromInt(@as(i32, @intCast(lx)) +% chunk_x * @as(i32, Chunk.SIZE));
            const world_z: f64 = @floatFromInt(@as(i32, @intCast(lz)) +% chunk_z * @as(i32, Chunk.SIZE));

            fillNetherColumn(&column, &tables, @intCast(lx), @intCast(lz), world_x, world_z);
        }
    }

    return column;
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

fn fillNetherColumn(
    column: *ChunkColumn,
    tables: *const NoiseTables,
    lx: u4,
    lz: u4,
    world_x: f64,
    world_z: f64,
) void {
    // Phase 1: Fill with netherrack from y=0 to ceiling, bedrock floor and cap
    column.setBlock(lx, 0, lz, block.BEDROCK);
    for (1..CEILING_Y) |y_usize| {
        const y: u8 = @intCast(y_usize);
        column.setBlock(lx, y, lz, block.NETHERRACK);
    }
    column.setBlock(lx, CEILING_Y, lz, block.BEDROCK);

    // Phase 2: Carve caverns using 3D noise
    for (1..CEILING_Y) |y_usize| {
        const y: u8 = @intCast(y_usize);
        const world_y: f64 = @floatFromInt(y);

        const cavern_val = noise.noise3d(
            &tables.cavern,
            world_x * CAVERN_NOISE_SCALE,
            world_y * CAVERN_NOISE_SCALE,
            world_z * CAVERN_NOISE_SCALE,
        );

        const tunnel_val = noise.noise3d(
            &tables.tunnel,
            world_x * TUNNEL_NOISE_SCALE,
            world_y * TUNNEL_NOISE_SCALE,
            world_z * TUNNEL_NOISE_SCALE,
        );

        if (cavern_val > CAVERN_THRESHOLD or tunnel_val > TUNNEL_THRESHOLD) {
            column.setBlock(lx, y, lz, if (y <= LAVA_LEVEL) block.LAVA else block.AIR);
        }
    }

    // Phase 3: Soul sand patches at low y on solid netherrack floors
    for (1..@as(usize, SOUL_SAND_MAX_Y) + 1) |y_usize| {
        const y: u8 = @intCast(y_usize);
        if (column.getBlock(lx, y, lz) != block.NETHERRACK) continue;

        const above = column.getBlock(lx, y + 1, lz);
        if (above != block.AIR and above != block.LAVA) continue;

        const world_y: f64 = @floatFromInt(y);
        const soul_val = noise.noise3d(
            &tables.soul_sand,
            world_x * SOUL_SAND_NOISE_SCALE,
            world_y * SOUL_SAND_NOISE_SCALE,
            world_z * SOUL_SAND_NOISE_SCALE,
        );

        if (soul_val > SOUL_SAND_THRESHOLD) {
            column.setBlock(lx, y, lz, block.SOUL_SAND);
        }
    }

    // Phase 4: Glowstone clusters near ceiling (hanging from solid blocks)
    for (@as(usize, GLOWSTONE_MIN_Y)..@as(usize, GLOWSTONE_MAX_Y) + 1) |y_usize| {
        const y: u8 = @intCast(y_usize);
        if (column.getBlock(lx, y, lz) != block.AIR) continue;

        const above = column.getBlock(lx, y + 1, lz);
        if (above != block.NETHERRACK and above != block.BEDROCK) continue;

        const world_y: f64 = @floatFromInt(y);
        const glow_val = noise.noise3d(
            &tables.glowstone,
            world_x * GLOWSTONE_NOISE_SCALE,
            world_y * GLOWSTONE_NOISE_SCALE,
            world_z * GLOWSTONE_NOISE_SCALE,
        );

        if (glow_val > GLOWSTONE_THRESHOLD) {
            column.setBlock(lx, y, lz, block.GLOWSTONE);
        }
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "nether produces netherrack" {
    const col = generateChunk(42, 0, 0);
    var netherrack_count: u32 = 0;
    for (0..Chunk.SIZE) |z| {
        for (0..Chunk.SIZE) |x| {
            for (1..CEILING_Y) |y| {
                if (col.getBlock(@intCast(x), @intCast(y), @intCast(z)) == block.NETHERRACK) {
                    netherrack_count += 1;
                }
            }
        }
    }
    // Netherrack should be the dominant block
    try std.testing.expect(netherrack_count > 10000);
}

test "nether has caverns (some AIR)" {
    const col = generateChunk(42, 0, 0);
    var air_count: u32 = 0;
    for (0..Chunk.SIZE) |z| {
        for (0..Chunk.SIZE) |x| {
            for (LAVA_LEVEL + 1..CEILING_Y) |y| {
                if (col.getBlock(@intCast(x), @intCast(y), @intCast(z)) == block.AIR) {
                    air_count += 1;
                }
            }
        }
    }
    // There must be some carved-out air above lava level
    try std.testing.expect(air_count > 0);
}

test "nether has lava at low y in carved areas" {
    const col = generateChunk(42, 0, 0);
    var lava_count: u32 = 0;
    for (0..Chunk.SIZE) |z| {
        for (0..Chunk.SIZE) |x| {
            for (1..@as(usize, LAVA_LEVEL) + 1) |y| {
                if (col.getBlock(@intCast(x), @intCast(y), @intCast(z)) == block.LAVA) {
                    lava_count += 1;
                }
            }
        }
    }
    try std.testing.expect(lava_count > 0);
}

test "nether has bedrock floor and ceiling" {
    const col = generateChunk(42, 0, 0);
    for (0..Chunk.SIZE) |z| {
        for (0..Chunk.SIZE) |x| {
            try std.testing.expectEqual(
                block.BEDROCK,
                col.getBlock(@intCast(x), 0, @intCast(z)),
            );
            try std.testing.expectEqual(
                block.BEDROCK,
                col.getBlock(@intCast(x), CEILING_Y, @intCast(z)),
            );
        }
    }
}

/// Search multiple seed/chunk combinations for a specific block in a y range.
fn findBlockInRange(target: block.BlockId, y_min: usize, y_max: usize) bool {
    const seeds = [_]u64{ 42, 123, 999, 7777, 31415 };
    const coords = [_][2]i32{ .{ 0, 0 }, .{ 1, 0 }, .{ 0, 1 }, .{ 3, 5 }, .{ -2, 7 } };
    for (seeds) |seed| {
        for (coords) |coord| {
            const col = generateChunk(seed, coord[0], coord[1]);
            for (0..Chunk.SIZE) |z| {
                for (0..Chunk.SIZE) |x| {
                    for (y_min..y_max) |y| {
                        if (col.getBlock(@intCast(x), @intCast(y), @intCast(z)) == target) {
                            return true;
                        }
                    }
                }
            }
        }
    }
    return false;
}

test "soul sand present at low y" {
    try std.testing.expect(findBlockInRange(block.SOUL_SAND, 1, @as(usize, SOUL_SAND_MAX_Y) + 1));
}

test "glowstone present near ceiling" {
    try std.testing.expect(findBlockInRange(block.GLOWSTONE, GLOWSTONE_MIN_Y, @as(usize, GLOWSTONE_MAX_Y) + 1));
}

test "deterministic from seed" {
    const a = generateChunk(12345, 3, -2);
    const b = generateChunk(12345, 3, -2);
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

test "different seeds produce different terrain" {
    const a = generateChunk(111, 0, 0);
    const b = generateChunk(222, 0, 0);
    var diffs: u32 = 0;
    for (0..ChunkColumn.SECTIONS) |s| {
        const sa = a.sections[s];
        const sb = b.sections[s];
        if (sa == null and sb == null) continue;
        if (sa != null and sb != null) {
            for (0..Chunk.VOLUME) |i| {
                if (sa.?.blocks[i] != sb.?.blocks[i]) diffs += 1;
            }
        } else {
            diffs += 1;
        }
    }
    try std.testing.expect(diffs > 0);
}

test "no blocks above ceiling" {
    const col = generateChunk(42, 0, 0);
    for (0..Chunk.SIZE) |z| {
        for (0..Chunk.SIZE) |x| {
            for (CEILING_Y + 1..ChunkColumn.HEIGHT) |y| {
                try std.testing.expectEqual(
                    block.AIR,
                    col.getBlock(@intCast(x), @intCast(y), @intCast(z)),
                );
            }
        }
    }
}
