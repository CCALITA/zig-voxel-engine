/// World persistence manager: saves/loads chunks to disk.
///
/// File layout: saves/<world_name>/chunks/<cx>_<cz>.dat
/// Uses chunk_serial for RLE-compressed serialization.
const std = @import("std");
const chunk_serial = @import("chunk_serial.zig");
const Chunk = @import("chunk.zig");
const ChunkColumn = @import("chunk_column.zig");

pub const ChunkKey = struct {
    x: i32,
    z: i32,
};

pub const WorldPersistence = struct {
    save_dir: []const u8,
    allocator: std.mem.Allocator,
    dirty_chunks: std.AutoHashMap(ChunkKey, void),

    /// Initialize a WorldPersistence for the given world name.
    /// Creates the directory tree `saves/<world_name>/chunks/` if it does not exist.
    /// Caller must call `deinit` when done.
    pub fn init(allocator: std.mem.Allocator, world_name: []const u8) !WorldPersistence {
        const save_dir = try std.fmt.allocPrint(allocator, "saves/{s}/chunks", .{world_name});
        errdefer allocator.free(save_dir);

        try std.fs.cwd().makePath(save_dir);

        return .{
            .save_dir = save_dir,
            .allocator = allocator,
            .dirty_chunks = std.AutoHashMap(ChunkKey, void).init(allocator),
        };
    }

    pub fn deinit(self: *WorldPersistence) void {
        self.dirty_chunks.deinit();
        self.allocator.free(self.save_dir);
    }

    /// Mark a chunk as modified (needs saving).
    pub fn markDirty(self: *WorldPersistence, cx: i32, cz: i32) !void {
        try self.dirty_chunks.put(.{ .x = cx, .z = cz }, {});
    }

    /// Save a single chunk to disk and clear its dirty flag.
    pub fn saveChunk(self: *WorldPersistence, cx: i32, cz: i32, chunk: *const Chunk) !void {
        var buf: [256]u8 = undefined;
        const path = self.chunkPath(cx, cz, &buf);

        const data = try chunk_serial.serialize(self.allocator, chunk);
        defer self.allocator.free(data);

        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();
        try file.writeAll(data);

        _ = self.dirty_chunks.remove(.{ .x = cx, .z = cz });
    }

    /// Load a chunk from disk. Returns null if no save file exists.
    pub fn loadChunk(self: *WorldPersistence, cx: i32, cz: i32) !?Chunk {
        var buf: [256]u8 = undefined;
        const path = self.chunkPath(cx, cz, &buf);

        const file = std.fs.cwd().openFile(path, .{}) catch |err| switch (err) {
            error.FileNotFound => return null,
            else => return err,
        };
        defer file.close();

        const data = try file.readToEndAlloc(self.allocator, 1024 * 1024);
        defer self.allocator.free(data);

        const chunk = try chunk_serial.deserialize(data);
        return chunk;
    }

    /// Save all dirty chunks using the provided chunk map.
    /// `chunks` must support `.get(ChunkKey)` returning an optional pointer to a Chunk.
    /// Returns the number of chunks saved.
    pub fn saveAllDirty(self: *WorldPersistence, chunks: anytype) !u32 {
        var saved: u32 = 0;

        // Collect keys first to avoid modifying the map while iterating.
        var keys = std.ArrayList(ChunkKey).empty;
        defer keys.deinit(self.allocator);

        var it = self.dirty_chunks.keyIterator();
        while (it.next()) |key_ptr| {
            try keys.append(self.allocator, key_ptr.*);
        }

        for (keys.items) |key| {
            if (chunks.get(key)) |chunk_ptr| {
                try self.saveChunk(key.x, key.z, chunk_ptr);
                saved += 1;
            }
        }

        return saved;
    }

    /// Check if a saved chunk file exists on disk.
    pub fn hasSavedChunk(self: *const WorldPersistence, cx: i32, cz: i32) bool {
        var buf: [256]u8 = undefined;
        const path = self.chunkPath(cx, cz, &buf);
        _ = std.fs.cwd().statFile(path) catch return false;
        return true;
    }

    /// Save all sections of a ChunkColumn to disk. Each non-null section is
    /// written as a separate `<cx>_<cz>_<section>.dat` file.
    pub fn saveColumn(self: *WorldPersistence, cx: i32, cz: i32, column: *const ChunkColumn) !void {
        for (0..ChunkColumn.SECTIONS) |si| {
            const section_idx: u4 = @intCast(si);
            if (column.getSection(section_idx)) |section_ptr| {
                try self.saveSection(cx, cz, section_idx, section_ptr);
            }
        }
        _ = self.dirty_chunks.remove(.{ .x = cx, .z = cz });
    }

    /// Load a ChunkColumn from disk. Returns null if no section files exist.
    /// Any missing section is left null (all-air).
    pub fn loadColumn(self: *WorldPersistence, cx: i32, cz: i32) !?ChunkColumn {
        var column = ChunkColumn.init();
        var found_any = false;

        for (0..ChunkColumn.SECTIONS) |si| {
            const section_idx: u4 = @intCast(si);
            if (try self.loadSection(cx, cz, section_idx)) |section| {
                column.sections[si] = section;
                found_any = true;
            }
        }

        if (found_any) return column;
        return null;
    }

    /// Save a single section (sub-chunk) to disk.
    fn saveSection(self: *WorldPersistence, cx: i32, cz: i32, section: u4, chunk: *const Chunk) !void {
        var buf: [256]u8 = undefined;
        const path = self.sectionPath(cx, cz, section, &buf);
        try chunk_serial.saveToFile(self.allocator, chunk, path);
    }

    /// Load a single section from disk. Returns null if no file exists.
    fn loadSection(self: *WorldPersistence, cx: i32, cz: i32, section: u4) !?Chunk {
        var buf: [256]u8 = undefined;
        const path = self.sectionPath(cx, cz, section, &buf);
        return chunk_serial.loadFromFile(self.allocator, path) catch |err| switch (err) {
            error.FileNotFound => return null,
            else => return err,
        };
    }

    /// Save all dirty columns. Iterates dirty keys, saves each column's sections.
    /// `columns` must support `.getPtr(key)` returning an optional pointer to a ChunkColumn.
    pub fn saveAllDirtyColumns(self: *WorldPersistence, columns: anytype) !u32 {
        var saved: u32 = 0;

        var keys = std.ArrayList(ChunkKey).empty;
        defer keys.deinit(self.allocator);

        var it = self.dirty_chunks.keyIterator();
        while (it.next()) |key_ptr| {
            try keys.append(self.allocator, key_ptr.*);
        }

        for (keys.items) |key| {
            if (columns.getPtr(.{ .x = key.x, .z = key.z })) |col_ptr| {
                self.saveColumn(key.x, key.z, col_ptr) catch |err| {
                    std.debug.print("Failed to save chunk ({d},{d}): {}\n", .{ key.x, key.z, err });
                    continue;
                };
                saved += 1;
            }
        }

        return saved;
    }

    /// Build the file path for a chunk into the provided buffer.
    /// Returns: "saves/<world>/chunks/<cx>_<cz>.dat"
    fn chunkPath(self: *const WorldPersistence, cx: i32, cz: i32, buf: []u8) []const u8 {
        return std.fmt.bufPrint(buf, "{s}/{d}_{d}.dat", .{ self.save_dir, cx, cz }) catch unreachable;
    }

    /// Build the file path for a section into the provided buffer.
    /// Returns: "saves/<world>/chunks/<cx>_<cz>_<section>.dat"
    fn sectionPath(self: *const WorldPersistence, cx: i32, cz: i32, section: u4, buf: []u8) []const u8 {
        return std.fmt.bufPrint(buf, "{s}/{d}_{d}_{d}.dat", .{ self.save_dir, cx, cz, section }) catch unreachable;
    }
};

// ── Tests ──────────────────────────────────────────────────────────────

test "load returns null for non-existent chunk" {
    const allocator = std.testing.allocator;
    var wp = try WorldPersistence.init(allocator, "test_null");
    defer wp.deinit();
    defer cleanupTestDir("saves/test_null");

    const result = try wp.loadChunk(999, 999);
    try std.testing.expect(result == null);
}

test "save and load round-trip" {
    const allocator = std.testing.allocator;
    var wp = try WorldPersistence.init(allocator, "test_roundtrip");
    defer wp.deinit();
    defer cleanupTestDir("saves/test_roundtrip");

    const block = @import("block.zig");
    var original = Chunk.init();
    original.setBlock(3, 4, 5, block.GRASS);
    original.setBlock(0, 0, 0, block.STONE);

    try wp.saveChunk(1, -2, &original);

    const loaded = (try wp.loadChunk(1, -2)).?;
    try std.testing.expectEqualSlices(u8, &original.blocks, &loaded.blocks);
}

test "hasSavedChunk returns false before save, true after" {
    const allocator = std.testing.allocator;
    var wp = try WorldPersistence.init(allocator, "test_has");
    defer wp.deinit();
    defer cleanupTestDir("saves/test_has");

    try std.testing.expect(!wp.hasSavedChunk(10, 20));

    const chunk = Chunk.init();
    try wp.saveChunk(10, 20, &chunk);

    try std.testing.expect(wp.hasSavedChunk(10, 20));
}

test "markDirty and saveAllDirty" {
    const allocator = std.testing.allocator;
    var wp = try WorldPersistence.init(allocator, "test_dirty");
    defer wp.deinit();
    defer cleanupTestDir("saves/test_dirty");

    const block = @import("block.zig");
    var c1 = Chunk.init();
    c1.setBlock(0, 0, 0, block.STONE);
    var c2 = Chunk.initFilled(block.DIRT);

    // Build a simple map that supports .get(ChunkKey) -> ?*const Chunk
    var map = std.AutoHashMap(ChunkKey, *const Chunk).init(allocator);
    defer map.deinit();
    try map.put(.{ .x = 0, .z = 0 }, &c1);
    try map.put(.{ .x = 1, .z = 1 }, &c2);

    try wp.markDirty(0, 0);
    try wp.markDirty(1, 1);

    const saved = try wp.saveAllDirty(&map);
    try std.testing.expectEqual(@as(u32, 2), saved);

    // Dirty flags should be cleared after save.
    try std.testing.expectEqual(@as(u32, 0), wp.dirty_chunks.count());

    // Verify data on disk.
    const loaded1 = (try wp.loadChunk(0, 0)).?;
    try std.testing.expectEqual(block.STONE, loaded1.getBlock(0, 0, 0));

    const loaded2 = (try wp.loadChunk(1, 1)).?;
    try std.testing.expectEqual(block.DIRT, loaded2.getBlock(7, 7, 7));
}

test "dirty flag cleared after saveChunk" {
    const allocator = std.testing.allocator;
    var wp = try WorldPersistence.init(allocator, "test_clear");
    defer wp.deinit();
    defer cleanupTestDir("saves/test_clear");

    try wp.markDirty(5, 5);
    try std.testing.expectEqual(@as(u32, 1), wp.dirty_chunks.count());

    const chunk = Chunk.init();
    try wp.saveChunk(5, 5, &chunk);
    try std.testing.expectEqual(@as(u32, 0), wp.dirty_chunks.count());
}

test "column save and load round-trip" {
    const allocator = std.testing.allocator;
    var wp = try WorldPersistence.init(allocator, "test_column");
    defer wp.deinit();
    defer cleanupTestDir("saves/test_column");

    const blk = @import("block.zig");

    var col = ChunkColumn.init();
    col.setBlock(3, 5, 7, blk.STONE); // section 0
    col.setBlock(1, 200, 2, blk.GRASS); // section 12

    try wp.saveColumn(2, -3, &col);

    const loaded = (try wp.loadColumn(2, -3)).?;
    try std.testing.expectEqual(blk.STONE, loaded.getBlock(3, 5, 7));
    try std.testing.expectEqual(blk.GRASS, loaded.getBlock(1, 200, 2));
    try std.testing.expectEqual(blk.AIR, loaded.getBlock(0, 128, 0));
}

test "loadColumn returns null for non-existent column" {
    const allocator = std.testing.allocator;
    var wp = try WorldPersistence.init(allocator, "test_col_null");
    defer wp.deinit();
    defer cleanupTestDir("saves/test_col_null");

    const result = try wp.loadColumn(999, 999);
    try std.testing.expect(result == null);
}

/// Remove a test directory tree after tests.
fn cleanupTestDir(path: []const u8) void {
    std.fs.cwd().deleteTree(path) catch {};
}
