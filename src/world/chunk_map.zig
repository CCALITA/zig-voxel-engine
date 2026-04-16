/// A spatial map of chunks keyed by integer chunk coordinates.
const std = @import("std");
const Chunk = @import("chunk.zig");

pub const ChunkCoord = struct {
    x: i32,
    y: i32,
    z: i32,
};

pub const ChunkMap = struct {
    map: std.AutoHashMap(ChunkCoord, Chunk),

    pub fn init(allocator: std.mem.Allocator) ChunkMap {
        return .{
            .map = std.AutoHashMap(ChunkCoord, Chunk).init(allocator),
        };
    }

    pub fn deinit(self: *ChunkMap) void {
        self.map.deinit();
    }

    pub fn put(self: *ChunkMap, coord: ChunkCoord, chunk: Chunk) !void {
        try self.map.put(coord, chunk);
    }

    pub fn get(self: *const ChunkMap, coord: ChunkCoord) ?*const Chunk {
        return if (self.map.getPtr(coord)) |ptr| ptr else null;
    }

    pub fn count(self: *const ChunkMap) usize {
        return self.map.count();
    }

    pub fn iterator(self: *const ChunkMap) std.AutoHashMap(ChunkCoord, Chunk).Iterator {
        return self.map.iterator();
    }
};

// --- Tests ---

test "chunk_map put and get" {
    var cm = ChunkMap.init(std.testing.allocator);
    defer cm.deinit();

    const coord = ChunkCoord{ .x = 1, .y = 0, .z = -1 };
    const chunk = Chunk.init();
    try cm.put(coord, chunk);

    const result = cm.get(coord);
    try std.testing.expect(result != null);
}

test "chunk_map returns null for missing coord" {
    var cm = ChunkMap.init(std.testing.allocator);
    defer cm.deinit();

    const result = cm.get(.{ .x = 99, .y = 0, .z = 99 });
    try std.testing.expect(result == null);
}

test "chunk_map count" {
    var cm = ChunkMap.init(std.testing.allocator);
    defer cm.deinit();

    try cm.put(.{ .x = 0, .y = 0, .z = 0 }, Chunk.init());
    try cm.put(.{ .x = 1, .y = 0, .z = 0 }, Chunk.init());
    try std.testing.expectEqual(@as(usize, 2), cm.count());
}
