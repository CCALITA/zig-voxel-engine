/// End dimension terrain generator.
/// Generates End terrain for a ChunkColumn at given coordinates.
/// The End has: a main island sphere of END_STONE at world center (radius ~40),
/// small floating islands scattered around, obsidian pillars at fixed positions,
/// and void (AIR) everywhere else.
const std = @import("std");
const Chunk = @import("chunk.zig");
const ChunkColumn = @import("chunk_column.zig");
const block = @import("block.zig");

// ---------------------------------------------------------------------------
// End terrain parameters
// ---------------------------------------------------------------------------

/// Y center of the main island sphere.
const ISLAND_CENTER_Y: i32 = 48;

/// Radius of the main island sphere in blocks.
const MAIN_ISLAND_RADIUS: i32 = 40;

/// Squared radius for distance checks (avoids sqrt).
const MAIN_ISLAND_RADIUS_SQ: i32 = MAIN_ISLAND_RADIUS * MAIN_ISLAND_RADIUS;

/// Minimum distance from center before floating islands can appear.
const OUTER_ISLAND_MIN_DIST: i32 = 80;

/// Height of obsidian pillars (above island surface).
const PILLAR_MIN_HEIGHT: u8 = 40;
const PILLAR_MAX_HEIGHT: u8 = 76;

/// Radius of each obsidian pillar in blocks.
const PILLAR_RADIUS: i32 = 3;

/// Fixed pillar positions around center (x, z offsets).
const PILLAR_POSITIONS = [10][2]i32{
    .{ 24, 0 },
    .{ -24, 0 },
    .{ 0, 24 },
    .{ 0, -24 },
    .{ 17, 17 },
    .{ -17, 17 },
    .{ 17, -17 },
    .{ -17, -17 },
    .{ 30, 12 },
    .{ -30, -12 },
};

/// Floating island parameters.
const FLOAT_ISLAND_RADIUS: i32 = 6;
const FLOAT_ISLAND_RADIUS_SQ: i32 = FLOAT_ISLAND_RADIUS * FLOAT_ISLAND_RADIUS;
const FLOAT_ISLAND_Y: i32 = 55;

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Generate End terrain for a chunk column at the given coordinates.
/// The result is a 16x256x16 column populated with End blocks.
pub fn generateChunk(seed: u64, chunk_x: i32, chunk_z: i32) ChunkColumn {
    _ = seed;
    var column = ChunkColumn.init();

    for (0..Chunk.SIZE) |lz| {
        for (0..Chunk.SIZE) |lx| {
            const world_x: i32 = @as(i32, @intCast(lx)) +% chunk_x *% @as(i32, Chunk.SIZE);
            const world_z: i32 = @as(i32, @intCast(lz)) +% chunk_z *% @as(i32, Chunk.SIZE);

            fillEndColumn(&column, @intCast(lx), @intCast(lz), world_x, world_z);
        }
    }

    return column;
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

fn fillEndColumn(
    column: *ChunkColumn,
    lx: u4,
    lz: u4,
    world_x: i32,
    world_z: i32,
) void {
    // Phase 1: Main island -- sphere of END_STONE centered at (0, ISLAND_CENTER_Y, 0)
    fillMainIsland(column, lx, lz, world_x, world_z);

    // Phase 2: Obsidian pillars at fixed positions
    fillPillars(column, lx, lz, world_x, world_z);

    // Phase 3: Scattered floating islands in outer ring
    fillFloatingIslands(column, lx, lz, world_x, world_z);
}

fn fillMainIsland(
    column: *ChunkColumn,
    lx: u4,
    lz: u4,
    world_x: i32,
    world_z: i32,
) void {
    const dx = world_x;
    const dz = world_z;
    const horiz_sq = dx * dx + dz * dz;

    // Early exit if this column is too far from center for the main island
    if (horiz_sq > MAIN_ISLAND_RADIUS_SQ) return;

    const y_min = @max(0, ISLAND_CENTER_Y - MAIN_ISLAND_RADIUS);
    const y_max = @min(255, ISLAND_CENTER_Y + MAIN_ISLAND_RADIUS);

    var y: i32 = y_min;
    while (y <= y_max) : (y += 1) {
        const dy = y - ISLAND_CENTER_Y;
        const dist_sq = horiz_sq + dy * dy;
        if (dist_sq <= MAIN_ISLAND_RADIUS_SQ) {
            column.setBlock(lx, @intCast(y), lz, block.END_STONE);
        }
    }
}

fn fillPillars(
    column: *ChunkColumn,
    lx: u4,
    lz: u4,
    world_x: i32,
    world_z: i32,
) void {
    for (PILLAR_POSITIONS, 0..) |pos, idx| {
        const pdx = world_x - pos[0];
        const pdz = world_z - pos[1];
        const dist_sq = pdx * pdx + pdz * pdz;

        if (dist_sq <= PILLAR_RADIUS * PILLAR_RADIUS) {
            // Pillar height varies per pillar (deterministic from index)
            const height: u8 = PILLAR_MIN_HEIGHT +% @as(u8, @intCast((idx * 7) % (PILLAR_MAX_HEIGHT - PILLAR_MIN_HEIGHT + 1)));

            // Pillar starts at the top of the main island sphere at this xz
            const base_y: u8 = computeIslandSurfaceY(pos[0], pos[1]);
            const top_y: u8 = @min(250, base_y +% height);

            var y: u8 = base_y;
            while (y <= top_y) : (y += 1) {
                column.setBlock(lx, y, lz, block.OBSIDIAN);
            }
        }
    }
}

/// Compute the highest y of the main island sphere at a given (wx, wz).
/// Returns the island center y if the point is outside the island.
fn computeIslandSurfaceY(wx: i32, wz: i32) u8 {
    const horiz_sq = wx * wx + wz * wz;
    if (horiz_sq > MAIN_ISLAND_RADIUS_SQ) {
        return @intCast(ISLAND_CENTER_Y);
    }
    // y_offset = sqrt(R^2 - horiz_sq)
    const remaining: f64 = @floatFromInt(MAIN_ISLAND_RADIUS_SQ - horiz_sq);
    const y_offset: i32 = @intFromFloat(@sqrt(remaining));
    const surface: i32 = ISLAND_CENTER_Y + y_offset;
    return @intCast(@min(255, @max(0, surface)));
}

fn fillFloatingIslands(
    column: *ChunkColumn,
    lx: u4,
    lz: u4,
    world_x: i32,
    world_z: i32,
) void {
    // Generate floating islands at deterministic positions based on a grid
    // Each 64x64 cell may have one island at a pseudo-random offset
    const cell_x = @divFloor(world_x, 64);
    const cell_z = @divFloor(world_z, 64);

    // Check the 3x3 neighborhood of cells to catch island edges
    var cz: i32 = cell_z - 1;
    while (cz <= cell_z + 1) : (cz += 1) {
        var cx: i32 = cell_x - 1;
        while (cx <= cell_x + 1) : (cx += 1) {
            tryPlaceFloatingIsland(column, lx, lz, world_x, world_z, cx, cz);
        }
    }
}

fn tryPlaceFloatingIsland(
    column: *ChunkColumn,
    lx: u4,
    lz: u4,
    world_x: i32,
    world_z: i32,
    cell_x: i32,
    cell_z: i32,
) void {
    // Deterministic hash to decide if this cell has an island
    const hash = cellHash(cell_x, cell_z);
    // ~25% of cells in the outer ring have islands
    if (hash % 4 != 0) return;

    // Island center within the cell
    const ix = cell_x * 64 + @as(i32, @intCast((hash >> 8) % 48)) + 8;
    const iz = cell_z * 64 + @as(i32, @intCast((hash >> 16) % 48)) + 8;

    // Must be outside main island radius
    if (ix * ix + iz * iz < OUTER_ISLAND_MIN_DIST * OUTER_ISLAND_MIN_DIST) return;

    const dx = world_x - ix;
    const dz = world_z - iz;
    const horiz_sq = dx * dx + dz * dz;
    if (horiz_sq > FLOAT_ISLAND_RADIUS_SQ) return;

    // Small sphere of end_stone
    const center_y: i32 = FLOAT_ISLAND_Y + @as(i32, @intCast((hash >> 24) % 20));
    const y_min = @max(0, center_y - FLOAT_ISLAND_RADIUS);
    const y_max = @min(255, center_y + FLOAT_ISLAND_RADIUS);

    var y: i32 = y_min;
    while (y <= y_max) : (y += 1) {
        const dy = y - center_y;
        if (horiz_sq + dy * dy <= FLOAT_ISLAND_RADIUS_SQ) {
            column.setBlock(lx, @intCast(y), lz, block.END_STONE);
        }
    }
}

/// Simple deterministic hash for cell coordinates.
fn cellHash(cx: i32, cz: i32) u64 {
    const a: u64 = @bitCast(@as(i64, cx));
    const b: u64 = @bitCast(@as(i64, cz));
    var h = a *% 0x9E3779B97F4A7C15 +% b *% 0x517CC1B727220A95;
    h = (h ^ (h >> 30)) *% 0xBF58476D1CE4E5B9;
    h = (h ^ (h >> 27)) *% 0x94D049BB133111EB;
    return h ^ (h >> 31);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "end terrain has end_stone at center" {
    const col = generateChunk(42, 0, 0);
    var end_stone_count: u32 = 0;
    for (0..Chunk.SIZE) |z| {
        for (0..Chunk.SIZE) |x| {
            for (0..ChunkColumn.HEIGHT) |y| {
                if (col.getBlock(@intCast(x), @intCast(y), @intCast(z)) == block.END_STONE) {
                    end_stone_count += 1;
                }
            }
        }
    }
    // Center chunk should have plenty of end_stone from the sphere
    try std.testing.expect(end_stone_count > 1000);
}

test "end terrain is mostly void outside main island" {
    // Chunk at (10, 10) is at world coords 160..175 -- well outside radius 40
    const col = generateChunk(42, 10, 10);
    var solid_count: u32 = 0;
    for (0..Chunk.SIZE) |z| {
        for (0..Chunk.SIZE) |x| {
            for (0..ChunkColumn.HEIGHT) |y| {
                const b = col.getBlock(@intCast(x), @intCast(y), @intCast(z));
                if (b != block.AIR) {
                    solid_count += 1;
                }
            }
        }
    }
    // Far-out chunk may have a floating island or nothing; should be mostly air
    try std.testing.expect(solid_count < 2000);
}

test "end terrain has obsidian pillars" {
    // The pillar at (24, 0) should appear in chunk (1, 0) which covers x=16..31
    const col = generateChunk(42, 1, 0);
    var obsidian_count: u32 = 0;
    for (0..Chunk.SIZE) |z| {
        for (0..Chunk.SIZE) |x| {
            for (0..ChunkColumn.HEIGHT) |y| {
                if (col.getBlock(@intCast(x), @intCast(y), @intCast(z)) == block.OBSIDIAN) {
                    obsidian_count += 1;
                }
            }
        }
    }
    try std.testing.expect(obsidian_count > 0);
}

test "end terrain center has sphere shape" {
    const col = generateChunk(42, 0, 0);
    // Block at (0, ISLAND_CENTER_Y, 0) should be end_stone (center of sphere)
    try std.testing.expectEqual(block.END_STONE, col.getBlock(0, ISLAND_CENTER_Y, 0));
    // Block at y=0 should be air (below sphere)
    try std.testing.expectEqual(block.AIR, col.getBlock(0, 0, 0));
}

test "end generation is deterministic" {
    const a = generateChunk(42, 0, 0);
    const b = generateChunk(42, 0, 0);
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

test "end terrain has no blocks at y=255" {
    // The sphere is centered at y=48 with radius 40, so y=255 should be air
    const col = generateChunk(42, 0, 0);
    for (0..Chunk.SIZE) |z| {
        for (0..Chunk.SIZE) |x| {
            try std.testing.expectEqual(
                block.AIR,
                col.getBlock(@intCast(x), 255, @intCast(z)),
            );
        }
    }
}
