/// BFS flood-fill light propagation engine for block light and sky light.
/// Each block stores 4 bits of block light + 4 bits of sky light packed into a u8.
const std = @import("std");
const Chunk = @import("chunk.zig");
const block = @import("block.zig");

const SIZE: usize = Chunk.SIZE;
const VOLUME: usize = Chunk.VOLUME;
const MAX_LIGHT: u4 = 15;

/// Opaque blocks stop light propagation (solid and non-transparent).
fn isOpaque(id: block.BlockId) bool {
    return block.isSolid(id) and !block.isTransparent(id);
}

/// Packed lighting data for a 16x16x16 chunk.
/// Lower nibble = block light, upper nibble = sky light.
pub const LightMap = struct {
    data: [VOLUME]u8,

    pub fn init() LightMap {
        return .{ .data = .{0} ** VOLUME };
    }

    pub fn getBlockLight(self: *const LightMap, x: u4, y: u4, z: u4) u4 {
        return @truncate(self.data[index(x, y, z)] & 0x0F);
    }

    pub fn getSkyLight(self: *const LightMap, x: u4, y: u4, z: u4) u4 {
        return @truncate((self.data[index(x, y, z)] >> 4) & 0x0F);
    }

    pub fn setBlockLight(self: *LightMap, x: u4, y: u4, z: u4, level: u4) void {
        const idx = index(x, y, z);
        self.data[idx] = (self.data[idx] & 0xF0) | @as(u8, level);
    }

    pub fn setSkyLight(self: *LightMap, x: u4, y: u4, z: u4, level: u4) void {
        const idx = index(x, y, z);
        self.data[idx] = (self.data[idx] & 0x0F) | (@as(u8, level) << 4);
    }

    pub fn getCombinedLight(self: *const LightMap, x: u4, y: u4, z: u4) u4 {
        const bl = self.getBlockLight(x, y, z);
        const sl = self.getSkyLight(x, y, z);
        return if (bl > sl) bl else sl;
    }
};

fn index(x: u4, y: u4, z: u4) usize {
    return @as(usize, y) * 256 + @as(usize, z) * 16 + @as(usize, x);
}

/// A position within the chunk stored as three coordinates and a light level.
const LightNode = struct {
    x: u4,
    y: u4,
    z: u4,
    level: u4,
};

/// Six cardinal neighbor offsets (dx, dy, dz).
const NEIGHBORS = [6][3]i8{
    .{ 1, 0, 0 },
    .{ -1, 0, 0 },
    .{ 0, 1, 0 },
    .{ 0, -1, 0 },
    .{ 0, 0, 1 },
    .{ 0, 0, -1 },
};

/// Propagate block light from a source at (x, y, z) with given level (1-15).
/// Uses BFS: each step decreases light by 1, stops at 0 or opaque blocks.
pub fn propagateBlockLight(light: *LightMap, chunk: *const Chunk, x: u4, y: u4, z: u4, level: u4) void {
    if (level == 0) return;

    light.setBlockLight(x, y, z, level);

    var queue: [VOLUME]LightNode = undefined;
    var head: usize = 0;
    var tail: usize = 0;

    queue[tail] = .{ .x = x, .y = y, .z = z, .level = level };
    tail += 1;

    while (head < tail) {
        const node = queue[head];
        head += 1;

        if (node.level <= 1) continue;
        const new_level: u4 = node.level - 1;

        for (NEIGHBORS) |offset| {
            const nx_i32: i32 = @as(i32, node.x) + offset[0];
            const ny_i32: i32 = @as(i32, node.y) + offset[1];
            const nz_i32: i32 = @as(i32, node.z) + offset[2];

            if (nx_i32 < 0 or nx_i32 >= SIZE or
                ny_i32 < 0 or ny_i32 >= SIZE or
                nz_i32 < 0 or nz_i32 >= SIZE) continue;

            const nx: u4 = @intCast(nx_i32);
            const ny: u4 = @intCast(ny_i32);
            const nz: u4 = @intCast(nz_i32);

            const block_id = chunk.getBlock(nx, ny, nz);
            if (isOpaque(block_id)) continue;

            if (light.getBlockLight(nx, ny, nz) < new_level) {
                light.setBlockLight(nx, ny, nz, new_level);
                queue[tail] = .{ .x = nx, .y = ny, .z = nz, .level = new_level };
                tail += 1;
            }
        }
    }
}

/// Compute sky light for the chunk. Light enters from y=15 downward at level 15.
/// Propagates straight down through transparent/non-solid blocks without diminishing,
/// then spreads horizontally with BFS (decreasing by 1 per step).
pub fn computeSkyLight(light: *LightMap, chunk: *const Chunk) void {
    var queue: [VOLUME]LightNode = undefined;
    var head: usize = 0;
    var tail: usize = 0;

    // Phase 1: vertical propagation downward from y=15.
    // For each (x, z) column, propagate sky light straight down until an opaque block.
    var x: u4 = 0;
    while (true) {
        var z: u4 = 0;
        while (true) {
            // Start at the top layer (y=15) with full sky light.
            light.setSkyLight(x, 15, z, MAX_LIGHT);
            queue[tail] = .{ .x = x, .y = 15, .z = z, .level = MAX_LIGHT };
            tail += 1;

            // Propagate downward through air/transparent.
            var y: i32 = 14;
            while (y >= 0) : (y -= 1) {
                const yu4: u4 = @intCast(y);
                const block_id = chunk.getBlock(x, yu4, z);
                if (isOpaque(block_id)) break;

                light.setSkyLight(x, yu4, z, MAX_LIGHT);
                queue[tail] = .{ .x = x, .y = yu4, .z = z, .level = MAX_LIGHT };
                tail += 1;
            }

            if (z == 15) break;
            z += 1;
        }
        if (x == 15) break;
        x += 1;
    }

    // Phase 2: BFS horizontal spread from all sky-lit blocks.
    while (head < tail) {
        const node = queue[head];
        head += 1;

        if (node.level <= 1) continue;
        const new_level: u4 = node.level - 1;

        for (NEIGHBORS) |offset| {
            const nx_i32: i32 = @as(i32, node.x) + offset[0];
            const ny_i32: i32 = @as(i32, node.y) + offset[1];
            const nz_i32: i32 = @as(i32, node.z) + offset[2];

            if (nx_i32 < 0 or nx_i32 >= SIZE or
                ny_i32 < 0 or ny_i32 >= SIZE or
                nz_i32 < 0 or nz_i32 >= SIZE) continue;

            const nx: u4 = @intCast(nx_i32);
            const ny: u4 = @intCast(ny_i32);
            const nz: u4 = @intCast(nz_i32);

            const block_id = chunk.getBlock(nx, ny, nz);
            if (isOpaque(block_id)) continue;

            if (light.getSkyLight(nx, ny, nz) < new_level) {
                light.setSkyLight(nx, ny, nz, new_level);
                queue[tail] = .{ .x = nx, .y = ny, .z = nz, .level = new_level };
                tail += 1;
            }
        }
    }
}

/// Remove a block light source and update propagation using reverse BFS.
/// First clears all light that was solely dependent on the removed source,
/// then re-propagates from any remaining neighboring light sources.
pub fn removeBlockLight(light: *LightMap, chunk: *const Chunk, x: u4, y: u4, z: u4) void {
    const old_level = light.getBlockLight(x, y, z);
    if (old_level == 0) return;

    var removal_queue: [VOLUME]LightNode = undefined;
    var r_head: usize = 0;
    var r_tail: usize = 0;

    var repropagate_queue: [VOLUME]LightNode = undefined;
    var rp_tail: usize = 0;

    light.setBlockLight(x, y, z, 0);
    removal_queue[r_tail] = .{ .x = x, .y = y, .z = z, .level = old_level };
    r_tail += 1;

    while (r_head < r_tail) {
        const node = removal_queue[r_head];
        r_head += 1;

        for (NEIGHBORS) |offset| {
            const nx_i32: i32 = @as(i32, node.x) + offset[0];
            const ny_i32: i32 = @as(i32, node.y) + offset[1];
            const nz_i32: i32 = @as(i32, node.z) + offset[2];

            if (nx_i32 < 0 or nx_i32 >= SIZE or
                ny_i32 < 0 or ny_i32 >= SIZE or
                nz_i32 < 0 or nz_i32 >= SIZE) continue;

            const nx: u4 = @intCast(nx_i32);
            const ny: u4 = @intCast(ny_i32);
            const nz: u4 = @intCast(nz_i32);

            const neighbor_level = light.getBlockLight(nx, ny, nz);
            if (neighbor_level == 0) continue;

            if (neighbor_level < node.level) {
                light.setBlockLight(nx, ny, nz, 0);
                removal_queue[r_tail] = .{ .x = nx, .y = ny, .z = nz, .level = neighbor_level };
                r_tail += 1;
            } else {
                repropagate_queue[rp_tail] = .{ .x = nx, .y = ny, .z = nz, .level = neighbor_level };
                rp_tail += 1;
            }
        }
    }

    // Re-propagate from remaining sources.
    var i: usize = 0;
    while (i < rp_tail) : (i += 1) {
        const node = repropagate_queue[i];
        propagateBlockLight(light, chunk, node.x, node.y, node.z, node.level);
    }
}

/// Full light computation for an entire chunk.
/// Computes sky light and returns the resulting LightMap.
/// (Block light sources like torches would be added separately.)
pub fn computeFullLighting(chunk: *const Chunk) LightMap {
    var light = LightMap.init();
    computeSkyLight(&light, chunk);
    return light;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "LightMap init is all zeros" {
    const lm = LightMap.init();
    try std.testing.expectEqual(@as(u4, 0), lm.getBlockLight(0, 0, 0));
    try std.testing.expectEqual(@as(u4, 0), lm.getSkyLight(0, 0, 0));
    try std.testing.expectEqual(@as(u4, 0), lm.getBlockLight(15, 15, 15));
    try std.testing.expectEqual(@as(u4, 0), lm.getSkyLight(15, 15, 15));
}

test "setBlockLight and getBlockLight round-trip" {
    var lm = LightMap.init();
    lm.setBlockLight(3, 7, 11, 12);
    try std.testing.expectEqual(@as(u4, 12), lm.getBlockLight(3, 7, 11));
    try std.testing.expectEqual(@as(u4, 0), lm.getSkyLight(3, 7, 11));
}

test "setSkyLight and getSkyLight round-trip" {
    var lm = LightMap.init();
    lm.setSkyLight(5, 2, 14, 9);
    try std.testing.expectEqual(@as(u4, 9), lm.getSkyLight(5, 2, 14));
    try std.testing.expectEqual(@as(u4, 0), lm.getBlockLight(5, 2, 14));
}

test "block and sky light stored independently" {
    var lm = LightMap.init();
    lm.setBlockLight(0, 0, 0, 5);
    lm.setSkyLight(0, 0, 0, 10);
    try std.testing.expectEqual(@as(u4, 5), lm.getBlockLight(0, 0, 0));
    try std.testing.expectEqual(@as(u4, 10), lm.getSkyLight(0, 0, 0));
}

test "getCombinedLight returns max of block and sky" {
    var lm = LightMap.init();
    lm.setBlockLight(1, 1, 1, 7);
    lm.setSkyLight(1, 1, 1, 12);
    try std.testing.expectEqual(@as(u4, 12), lm.getCombinedLight(1, 1, 1));

    lm.setBlockLight(2, 2, 2, 14);
    lm.setSkyLight(2, 2, 2, 3);
    try std.testing.expectEqual(@as(u4, 14), lm.getCombinedLight(2, 2, 2));
}

test "empty chunk: sky light = 15 everywhere" {
    const chunk = Chunk.init();
    const lm = computeFullLighting(&chunk);

    var x: u4 = 0;
    while (true) {
        var y: u4 = 0;
        while (true) {
            var z: u4 = 0;
            while (true) {
                try std.testing.expectEqual(@as(u4, 15), lm.getSkyLight(x, y, z));
                if (z == 15) break;
                z += 1;
            }
            if (y == 15) break;
            y += 1;
        }
        if (x == 15) break;
        x += 1;
    }
}

test "block light source at center: decreases with distance" {
    var chunk = Chunk.init();
    var lm = LightMap.init();

    const cx: u4 = 8;
    const cy: u4 = 8;
    const cz: u4 = 8;
    const source_level: u4 = 14;

    propagateBlockLight(&lm, &chunk, cx, cy, cz, source_level);

    try std.testing.expectEqual(source_level, lm.getBlockLight(cx, cy, cz));

    try std.testing.expectEqual(source_level - 1, lm.getBlockLight(cx + 1, cy, cz));
    try std.testing.expectEqual(source_level - 1, lm.getBlockLight(cx, cy + 1, cz));
    try std.testing.expectEqual(source_level - 1, lm.getBlockLight(cx, cy, cz + 1));

    try std.testing.expectEqual(source_level - 2, lm.getBlockLight(cx + 2, cy, cz));

    // (0,8,8) is 8 blocks from center, so light = 14 - 8 = 6.
    try std.testing.expectEqual(@as(u4, 6), lm.getBlockLight(0, cy, cz));
}

test "opaque block blocks light" {
    var chunk = Chunk.init();
    // Place a stone wall at x=9 across the full yz plane.
    var y: u4 = 0;
    while (true) {
        var z: u4 = 0;
        while (true) {
            chunk.setBlock(9, y, z, block.STONE);
            if (z == 15) break;
            z += 1;
        }
        if (y == 15) break;
        y += 1;
    }

    var lm = LightMap.init();
    propagateBlockLight(&lm, &chunk, 8, 8, 8, 15);

    try std.testing.expectEqual(@as(u4, 15), lm.getBlockLight(8, 8, 8));
    try std.testing.expectEqual(@as(u4, 0), lm.getBlockLight(10, 8, 8));
}

test "sky light: column of air below open sky = 15 all the way down" {
    var chunk = Chunk.init();
    // Place a roof with a 1-block hole at (7, 14, 7).
    var x: u4 = 0;
    while (true) {
        var z: u4 = 0;
        while (true) {
            if (x != 7 or z != 7) {
                chunk.setBlock(x, 14, z, block.STONE);
            }
            if (z == 15) break;
            z += 1;
        }
        if (x == 15) break;
        x += 1;
    }

    var lm = LightMap.init();
    computeSkyLight(&lm, &chunk);

    // Open column at (7, _, 7) gets full sky light all the way down.
    try std.testing.expectEqual(@as(u4, 15), lm.getSkyLight(7, 15, 7));
    try std.testing.expectEqual(@as(u4, 15), lm.getSkyLight(7, 14, 7));
    try std.testing.expectEqual(@as(u4, 15), lm.getSkyLight(7, 13, 7));
    try std.testing.expectEqual(@as(u4, 15), lm.getSkyLight(7, 0, 7));
}

test "sky light: opaque block above = 0 sky light below (no horizontal spread reaches)" {
    // Fill y=14 entirely with stone -- complete roof.
    var chunk = Chunk.init();
    var x: u4 = 0;
    while (true) {
        var z: u4 = 0;
        while (true) {
            chunk.setBlock(x, 14, z, block.STONE);
            if (z == 15) break;
            z += 1;
        }
        if (x == 15) break;
        x += 1;
    }

    var lm = LightMap.init();
    computeSkyLight(&lm, &chunk);

    try std.testing.expectEqual(@as(u4, 15), lm.getSkyLight(8, 15, 8));

    // Full roof at y=14 blocks all vertical propagation; BFS from y=15 cannot
    // pass through stone, so nothing below the roof receives sky light.
    try std.testing.expectEqual(@as(u4, 0), lm.getSkyLight(8, 13, 8));
    try std.testing.expectEqual(@as(u4, 0), lm.getSkyLight(0, 0, 0));
}

test "light removal: after removing source, affected areas go dark" {
    var chunk = Chunk.init();
    var lm = LightMap.init();

    propagateBlockLight(&lm, &chunk, 8, 8, 8, 12);
    try std.testing.expectEqual(@as(u4, 12), lm.getBlockLight(8, 8, 8));
    try std.testing.expectEqual(@as(u4, 11), lm.getBlockLight(9, 8, 8));

    removeBlockLight(&lm, &chunk, 8, 8, 8);

    try std.testing.expectEqual(@as(u4, 0), lm.getBlockLight(8, 8, 8));
    try std.testing.expectEqual(@as(u4, 0), lm.getBlockLight(9, 8, 8));
    try std.testing.expectEqual(@as(u4, 0), lm.getBlockLight(7, 8, 8));
    try std.testing.expectEqual(@as(u4, 0), lm.getBlockLight(8, 10, 8));
}

test "light removal with two sources preserves second source" {
    var chunk = Chunk.init();
    var lm = LightMap.init();

    // Place two light sources.
    propagateBlockLight(&lm, &chunk, 3, 8, 8, 10);
    propagateBlockLight(&lm, &chunk, 13, 8, 8, 10);

    removeBlockLight(&lm, &chunk, 3, 8, 8);

    // Distance from (13,8,8) to (3,8,8) = 10, so second source cannot reach here.
    try std.testing.expectEqual(@as(u4, 0), lm.getBlockLight(3, 8, 8));

    try std.testing.expectEqual(@as(u4, 10), lm.getBlockLight(13, 8, 8));
    try std.testing.expectEqual(@as(u4, 9), lm.getBlockLight(12, 8, 8));
}
