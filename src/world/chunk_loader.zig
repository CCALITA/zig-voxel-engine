/// Chunk loading/unloading manager.
/// Tracks which chunks are loaded and computes load/unload deltas each frame
/// based on the player's current chunk position and the configured render distance.
const std = @import("std");

pub const ChunkCoord = struct {
    x: i32,
    z: i32,
};

/// Hash context for ChunkCoord so it can be used as a HashMap key.
const ChunkCoordContext = struct {
    pub fn hash(_: ChunkCoordContext, c: ChunkCoord) u64 {
        const a: u64 = @bitCast([2]u32{ @bitCast(c.x), @bitCast(c.z) });
        return std.hash.Wyhash.hash(0, std.mem.asBytes(&a));
    }

    pub fn eql(_: ChunkCoordContext, a: ChunkCoord, b: ChunkCoord) bool {
        return a.x == b.x and a.z == b.z;
    }
};

pub const LoadResult = struct {
    to_load: []ChunkCoord,
    to_unload: []ChunkCoord,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *LoadResult) void {
        self.allocator.free(self.to_load);
        self.allocator.free(self.to_unload);
    }
};

/// Maximum number of chunks returned in `to_load` per `update()` call.
/// Spreading load across frames avoids frame-time spikes.
const MAX_LOADS_PER_UPDATE: usize = 4;

pub const ChunkLoader = struct {
    render_distance: i32,
    loaded: std.HashMap(ChunkCoord, void, ChunkCoordContext, std.hash_map.default_max_load_percentage),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, render_distance: i32) ChunkLoader {
        return .{
            .render_distance = render_distance,
            .loaded = std.HashMap(ChunkCoord, void, ChunkCoordContext, std.hash_map.default_max_load_percentage).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ChunkLoader) void {
        self.loaded.deinit();
    }

    /// Given the player's current chunk position, compute which chunks to load
    /// and which to unload.
    ///
    /// `to_load` is returned in spiral order (closest to player first) and is
    /// capped at `MAX_LOADS_PER_UPDATE` entries per call.
    ///
    /// `to_unload` contains every currently-loaded chunk that falls outside
    /// the desired radius.
    pub fn update(self: *ChunkLoader, player_chunk_x: i32, player_chunk_z: i32) !LoadResult {
        const gpa = self.allocator;
        const spiral = try spiralOrder(gpa, self.render_distance);
        defer gpa.free(spiral);

        // Build to_load: spiral-ordered coords within range that are not yet loaded.
        var load_list: std.ArrayList(ChunkCoord) = .empty;
        defer load_list.deinit(gpa);

        // Build a set of desired coords for fast lookup when computing to_unload.
        var desired = std.HashMap(ChunkCoord, void, ChunkCoordContext, std.hash_map.default_max_load_percentage).init(gpa);
        defer desired.deinit();

        for (spiral) |offset| {
            const coord = ChunkCoord{
                .x = player_chunk_x + offset.x,
                .z = player_chunk_z + offset.z,
            };
            try desired.put(coord, {});

            if (self.loaded.get(coord) == null) {
                if (load_list.items.len < MAX_LOADS_PER_UPDATE) {
                    try load_list.append(gpa, coord);
                }
            }
        }

        // Build to_unload: loaded chunks not in the desired set.
        var unload_list: std.ArrayList(ChunkCoord) = .empty;
        defer unload_list.deinit(gpa);

        var it = self.loaded.iterator();
        while (it.next()) |entry| {
            if (desired.get(entry.key_ptr.*) == null) {
                try unload_list.append(gpa, entry.key_ptr.*);
            }
        }

        return LoadResult{
            .to_load = try load_list.toOwnedSlice(gpa),
            .to_unload = try unload_list.toOwnedSlice(gpa),
            .allocator = gpa,
        };
    }

    /// Mark a chunk as loaded in the tracking set.
    pub fn markLoaded(self: *ChunkLoader, coord: ChunkCoord) !void {
        try self.loaded.put(coord, {});
    }

    /// Mark a chunk as unloaded (remove from the tracking set).
    pub fn markUnloaded(self: *ChunkLoader, coord: ChunkCoord) void {
        _ = self.loaded.remove(coord);
    }

    /// How many chunks are currently tracked as loaded.
    pub fn loadedCount(self: *const ChunkLoader) usize {
        return self.loaded.count();
    }
};

/// Generate coordinates within `radius` of the origin, ordered in a spiral
/// pattern starting from (0,0) and expanding outward. The result forms a
/// (2*radius+1) x (2*radius+1) square.
pub fn spiralOrder(allocator: std.mem.Allocator, radius: i32) ![]ChunkCoord {
    const side: usize = @intCast(2 * radius + 1);
    const total = side * side;
    var coords = try allocator.alloc(ChunkCoord, total);
    errdefer allocator.free(coords);

    var idx: usize = 0;
    var x: i32 = 0;
    var z: i32 = 0;

    coords[idx] = .{ .x = x, .z = z };
    idx += 1;

    // Walk in expanding rings: length 1,1,2,2,3,3,...
    // Directions cycle: +X, +Z, -X, -Z
    const dx = [_]i32{ 1, 0, -1, 0 };
    const dz = [_]i32{ 0, 1, 0, -1 };
    var dir: usize = 0;
    var leg_len: i32 = 1;
    var legs_at_len: i32 = 0;

    while (idx < total) {
        var step: i32 = 0;
        while (step < leg_len and idx < total) : (step += 1) {
            x += dx[dir];
            z += dz[dir];
            coords[idx] = .{ .x = x, .z = z };
            idx += 1;
        }
        dir = (dir + 1) % 4;
        legs_at_len += 1;
        if (legs_at_len == 2) {
            legs_at_len = 0;
            leg_len += 1;
        }
    }

    return coords;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "spiral order: center is first" {
    const allocator = std.testing.allocator;
    const coords = try spiralOrder(allocator, 2);
    defer allocator.free(coords);

    try std.testing.expectEqual(ChunkCoord{ .x = 0, .z = 0 }, coords[0]);
}

test "spiral order: total count for radius 2" {
    const allocator = std.testing.allocator;
    const coords = try spiralOrder(allocator, 2);
    defer allocator.free(coords);

    // (2*2+1)^2 = 25
    try std.testing.expectEqual(@as(usize, 25), coords.len);
}

test "spiral order: closer coords come before farther ones" {
    const allocator = std.testing.allocator;
    const coords = try spiralOrder(allocator, 2);
    defer allocator.free(coords);

    // The first entry is the center (0,0).
    try std.testing.expectEqual(ChunkCoord{ .x = 0, .z = 0 }, coords[0]);

    // The immediate neighbors (distance 1) should all appear within
    // the first ring (indices 1..4).
    for (coords[1..4]) |c| {
        const dist = @abs(c.x) + @abs(c.z);
        try std.testing.expect(dist <= 2);
    }

    // Corners of radius 2 (distance 4) should be among the last entries.
    var corner_idx: ?usize = null;
    for (coords, 0..) |c, i| {
        if (c.x == 2 and c.z == 2) {
            corner_idx = i;
            break;
        }
    }
    try std.testing.expect(corner_idx != null);
    // The corner at (2,2) must come after the inner 3x3 ring (9 coords).
    try std.testing.expect(corner_idx.? >= 9);
}

test "spiral order: all coordinates within radius are present" {
    const allocator = std.testing.allocator;
    const radius: i32 = 2;
    const coords = try spiralOrder(allocator, radius);
    defer allocator.free(coords);

    // Every (x,z) with -2 <= x,z <= 2 should appear exactly once.
    var seen = std.HashMap(ChunkCoord, void, ChunkCoordContext, std.hash_map.default_max_load_percentage).init(allocator);
    defer seen.deinit();

    for (coords) |c| {
        try seen.put(c, {});
    }

    var cx: i32 = -radius;
    while (cx <= radius) : (cx += 1) {
        var cz: i32 = -radius;
        while (cz <= radius) : (cz += 1) {
            try std.testing.expect(seen.get(.{ .x = cx, .z = cz }) != null);
        }
    }
}

test "update: player at origin with radius 2 wants 25 chunks" {
    const allocator = std.testing.allocator;
    var loader = ChunkLoader.init(allocator, 2);
    defer loader.deinit();

    // First update — nothing loaded yet, so to_load is capped at 4.
    var result = try loader.update(0, 0);
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 4), result.to_load.len);
    try std.testing.expectEqual(@as(usize, 0), result.to_unload.len);
}

test "update: load limit is 4 per call" {
    const allocator = std.testing.allocator;
    var loader = ChunkLoader.init(allocator, 2);
    defer loader.deinit();

    // Repeatedly call update and mark loaded until everything is loaded.
    var total_loaded: usize = 0;
    while (total_loaded < 25) {
        var result = try loader.update(0, 0);
        defer result.deinit();
        try std.testing.expect(result.to_load.len <= 4);
        for (result.to_load) |c| {
            try loader.markLoaded(c);
            total_loaded += 1;
        }
    }
    try std.testing.expectEqual(@as(usize, 25), loader.loadedCount());
}

test "update: player moves causes load and unload" {
    const allocator = std.testing.allocator;
    var loader = ChunkLoader.init(allocator, 1);
    defer loader.deinit();

    // Fully load around (0,0): 3x3 = 9 chunks.
    var loaded_count: usize = 0;
    while (loaded_count < 9) {
        var result = try loader.update(0, 0);
        defer result.deinit();
        for (result.to_load) |c| {
            try loader.markLoaded(c);
            loaded_count += 1;
        }
    }

    // Move player to (1,0). New desired set is centered at (1,0).
    // Old: {-1..1} x {-1..1}  New: {0..2} x {-1..1}
    // Unload: x=-1 column (3 chunks)
    // Load:   x=2 column  (3 chunks)
    var result = try loader.update(1, 0);
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 3), result.to_unload.len);
    try std.testing.expectEqual(@as(usize, 3), result.to_load.len);

    // All to_load should have x == 2.
    for (result.to_load) |c| {
        try std.testing.expectEqual(@as(i32, 2), c.x);
    }

    // All to_unload should have x == -1.
    for (result.to_unload) |c| {
        try std.testing.expectEqual(@as(i32, -1), c.x);
    }
}

test "markLoaded and markUnloaded" {
    const allocator = std.testing.allocator;
    var loader = ChunkLoader.init(allocator, 1);
    defer loader.deinit();

    const coord = ChunkCoord{ .x = 5, .z = 3 };
    try loader.markLoaded(coord);
    try std.testing.expectEqual(@as(usize, 1), loader.loadedCount());

    loader.markUnloaded(coord);
    try std.testing.expectEqual(@as(usize, 0), loader.loadedCount());
}
