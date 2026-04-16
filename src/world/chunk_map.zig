/// Sparse world container mapping chunk coordinates to chunks.
/// Provides O(1) lookup of chunks by coordinate and cross-chunk block queries.
const std = @import("std");
const Chunk = @import("chunk.zig");
const block = @import("block.zig");

pub const ChunkCoord = struct {
    x: i32,
    y: i32,
    z: i32,
};

const ChunkCoordContext = struct {
    pub fn hash(_: ChunkCoordContext, coord: ChunkCoord) u64 {
        var h: u64 = 0;
        h ^= @as(u64, @as(u32, @bitCast(coord.x))) *% 0x9e3779b97f4a7c15;
        h ^= @as(u64, @as(u32, @bitCast(coord.y))) *% 0x517cc1b727220a95;
        h ^= @as(u64, @as(u32, @bitCast(coord.z))) *% 0x6c62272e07bb0142;
        return h;
    }

    pub fn eql(_: ChunkCoordContext, a: ChunkCoord, b: ChunkCoord) bool {
        return a.x == b.x and a.y == b.y and a.z == b.z;
    }
};

const InternalMap = std.HashMap(ChunkCoord, *Chunk, ChunkCoordContext, std.hash_map.default_max_load_percentage);

pub const ChunkMap = struct {
    map: InternalMap,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) ChunkMap {
        return .{
            .map = InternalMap.init(allocator),
            .allocator = allocator,
        };
    }

    /// Frees all chunks owned by the map and releases internal storage.
    pub fn deinit(self: *ChunkMap) void {
        var it = self.map.iterator();
        while (it.next()) |entry| {
            self.allocator.destroy(entry.value_ptr.*);
        }
        self.map.deinit();
    }

    /// Inserts or replaces the chunk at the given coordinate.
    /// If a chunk already exists at coord, the old chunk is freed.
    pub fn put(self: *ChunkMap, coord: ChunkCoord, chunk: *Chunk) !void {
        const result = try self.map.fetchPut(coord, chunk);
        if (result) |old| {
            self.allocator.destroy(old.value);
        }
    }

    /// Returns the chunk at the given coordinate, or null if not loaded.
    pub fn get(self: *ChunkMap, coord: ChunkCoord) ?*Chunk {
        return self.map.get(coord);
    }

    /// Removes and returns the chunk at the given coordinate.
    /// The caller is responsible for freeing the returned chunk.
    pub fn remove(self: *ChunkMap, coord: ChunkCoord) ?*Chunk {
        return if (self.map.fetchRemove(coord)) |entry| entry.value else null;
    }

    /// Returns the number of loaded chunks.
    pub fn count(self: *ChunkMap) usize {
        return self.map.count();
    }

    pub const Iterator = InternalMap.Iterator;

    /// Returns an iterator over all loaded chunk entries.
    pub fn iterator(self: *ChunkMap) Iterator {
        return self.map.iterator();
    }

    /// Converts world-space block coordinates to a chunk coordinate and local offsets.
    pub fn worldToChunk(wx: i32, wy: i32, wz: i32) struct { coord: ChunkCoord, local_x: u4, local_y: u4, local_z: u4 } {
        return .{
            .coord = .{
                .x = @divFloor(wx, Chunk.SIZE),
                .y = @divFloor(wy, Chunk.SIZE),
                .z = @divFloor(wz, Chunk.SIZE),
            },
            .local_x = @intCast(@mod(wx, Chunk.SIZE)),
            .local_y = @intCast(@mod(wy, Chunk.SIZE)),
            .local_z = @intCast(@mod(wz, Chunk.SIZE)),
        };
    }

    /// Looks up the block at absolute world coordinates.
    /// Returns AIR if the chunk is not loaded.
    pub fn getBlockAt(self: *ChunkMap, wx: i32, wy: i32, wz: i32) block.BlockId {
        const result = worldToChunk(wx, wy, wz);
        const chunk = self.get(result.coord) orelse return block.AIR;
        return chunk.getBlock(result.local_x, result.local_y, result.local_z);
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "insert, get, and remove chunk" {
    const allocator = std.testing.allocator;
    var map = ChunkMap.init(allocator);
    defer map.deinit();

    const coord = ChunkCoord{ .x = 1, .y = 0, .z = -1 };
    const chunk = try allocator.create(Chunk);
    chunk.* = Chunk.init();
    chunk.setBlock(0, 0, 0, block.STONE);

    try map.put(coord, chunk);
    try std.testing.expectEqual(@as(usize, 1), map.count());

    const got = map.get(coord).?;
    try std.testing.expectEqual(block.STONE, got.getBlock(0, 0, 0));

    // Remove gives back the pointer; caller owns it.
    const removed = map.remove(coord).?;
    try std.testing.expectEqual(@as(usize, 0), map.count());
    // Free manually since we removed it from the map (deinit won't free it).
    allocator.destroy(removed);
}

test "get returns null for missing coord" {
    const allocator = std.testing.allocator;
    var map = ChunkMap.init(allocator);
    defer map.deinit();

    try std.testing.expectEqual(@as(?*Chunk, null), map.get(.{ .x = 0, .y = 0, .z = 0 }));
}

test "iteration count matches inserted chunks" {
    const allocator = std.testing.allocator;
    var map = ChunkMap.init(allocator);
    defer map.deinit();

    const coords = [_]ChunkCoord{
        .{ .x = 0, .y = 0, .z = 0 },
        .{ .x = 1, .y = 0, .z = 0 },
        .{ .x = 0, .y = 1, .z = 0 },
    };

    for (coords) |c| {
        const chunk = try allocator.create(Chunk);
        chunk.* = Chunk.init();
        try map.put(c, chunk);
    }

    var iter_count: usize = 0;
    var it = map.iterator();
    while (it.next()) |_| {
        iter_count += 1;
    }
    try std.testing.expectEqual(@as(usize, 3), iter_count);
    try std.testing.expectEqual(@as(usize, 3), map.count());
}

test "worldToChunk positive coordinates" {
    const result = ChunkMap.worldToChunk(17, 5, 33);
    try std.testing.expectEqual(@as(i32, 1), result.coord.x);
    try std.testing.expectEqual(@as(i32, 0), result.coord.y);
    try std.testing.expectEqual(@as(i32, 2), result.coord.z);
    try std.testing.expectEqual(@as(u4, 1), result.local_x);
    try std.testing.expectEqual(@as(u4, 5), result.local_y);
    try std.testing.expectEqual(@as(u4, 1), result.local_z);
}

test "worldToChunk negative coordinates" {
    // -1 should map to chunk -1, local 15
    const result = ChunkMap.worldToChunk(-1, -1, -1);
    try std.testing.expectEqual(@as(i32, -1), result.coord.x);
    try std.testing.expectEqual(@as(i32, -1), result.coord.y);
    try std.testing.expectEqual(@as(i32, -1), result.coord.z);
    try std.testing.expectEqual(@as(u4, 15), result.local_x);
    try std.testing.expectEqual(@as(u4, 15), result.local_y);
    try std.testing.expectEqual(@as(u4, 15), result.local_z);
}

test "worldToChunk boundary at zero" {
    const result = ChunkMap.worldToChunk(0, 0, 0);
    try std.testing.expectEqual(@as(i32, 0), result.coord.x);
    try std.testing.expectEqual(@as(i32, 0), result.coord.y);
    try std.testing.expectEqual(@as(i32, 0), result.coord.z);
    try std.testing.expectEqual(@as(u4, 0), result.local_x);
    try std.testing.expectEqual(@as(u4, 0), result.local_y);
    try std.testing.expectEqual(@as(u4, 0), result.local_z);
}

test "getBlockAt cross-chunk lookup" {
    const allocator = std.testing.allocator;
    var map = ChunkMap.init(allocator);
    defer map.deinit();

    // Place a stone block at world (17, 5, 33) => chunk (1,0,2) local (1,5,1)
    const coord = ChunkCoord{ .x = 1, .y = 0, .z = 2 };
    const chunk = try allocator.create(Chunk);
    chunk.* = Chunk.init();
    chunk.setBlock(1, 5, 1, block.STONE);
    try map.put(coord, chunk);

    try std.testing.expectEqual(block.STONE, map.getBlockAt(17, 5, 33));
    // Unloaded chunk returns AIR
    try std.testing.expectEqual(block.AIR, map.getBlockAt(0, 0, 0));
}

test "getBlockAt negative world coords" {
    const allocator = std.testing.allocator;
    var map = ChunkMap.init(allocator);
    defer map.deinit();

    // Place a dirt block at world (-1, -1, -1) => chunk (-1,-1,-1) local (15,15,15)
    const coord = ChunkCoord{ .x = -1, .y = -1, .z = -1 };
    const chunk = try allocator.create(Chunk);
    chunk.* = Chunk.init();
    chunk.setBlock(15, 15, 15, block.DIRT);
    try map.put(coord, chunk);

    try std.testing.expectEqual(block.DIRT, map.getBlockAt(-1, -1, -1));
}
