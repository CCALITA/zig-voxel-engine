/// RLE-compressed chunk serialization / deserialization.
///
/// Binary format:
///   MAGIC (4 bytes) + VERSION (1 byte) + RLE_PAIRS (N * 2 bytes)
///   Each RLE pair: count(u8) + block_id(u8)
///   Runs longer than 255 are split into multiple consecutive pairs.
const std = @import("std");
const Chunk = @import("chunk.zig");
const block = @import("block.zig");

pub const MAGIC = [4]u8{ 'Z', 'V', 'C', 'K' };
pub const VERSION: u8 = 1;
const HEADER_SIZE: usize = MAGIC.len + 1; // 5 bytes

pub const SerialError = error{
    InvalidMagic,
    UnsupportedVersion,
    CorruptData,
};

/// Serialize a chunk to bytes using RLE compression.
/// Caller owns the returned slice and must free it with `allocator`.
pub fn serialize(allocator: std.mem.Allocator, chunk: *const Chunk) ![]u8 {
    var buf = std.ArrayList(u8).empty;
    defer buf.deinit(allocator);

    // Header
    try buf.appendSlice(allocator, &MAGIC);
    try buf.append(allocator, VERSION);

    // RLE encode blocks in linear order (y*256 + z*16 + x)
    const blocks = &chunk.blocks;
    var i: usize = 0;
    while (i < Chunk.VOLUME) {
        const current_id = blocks[i];
        var run_len: usize = 1;
        while (i + run_len < Chunk.VOLUME and blocks[i + run_len] == current_id) {
            run_len += 1;
        }
        // Emit RLE pairs, splitting runs > 255
        var remaining = run_len;
        while (remaining > 0) {
            const count: u8 = @intCast(@min(remaining, 255));
            try buf.append(allocator, count);
            try buf.append(allocator, current_id);
            remaining -= count;
        }
        i += run_len;
    }

    return buf.toOwnedSlice(allocator);
}

/// Deserialize bytes back to a Chunk.
pub fn deserialize(data: []const u8) SerialError!Chunk {
    if (data.len < HEADER_SIZE) return SerialError.CorruptData;
    if (!std.mem.eql(u8, data[0..4], &MAGIC)) return SerialError.InvalidMagic;
    if (data[4] != VERSION) return SerialError.UnsupportedVersion;

    var chunk = Chunk.init();
    var pos: usize = HEADER_SIZE;
    var block_idx: usize = 0;

    while (pos + 1 < data.len) {
        const count: usize = data[pos];
        const id = data[pos + 1];
        pos += 2;

        if (count == 0) return SerialError.CorruptData;
        if (block_idx + count > Chunk.VOLUME) return SerialError.CorruptData;

        @memset(chunk.blocks[block_idx..][0..count], id);
        block_idx += count;
    }

    if (block_idx != Chunk.VOLUME) return SerialError.CorruptData;
    return chunk;
}

/// Convenience: serialize a chunk and write it to a file.
pub fn saveToFile(allocator: std.mem.Allocator, chunk: *const Chunk, path: []const u8) !void {
    const data = try serialize(allocator, chunk);
    defer allocator.free(data);

    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();
    try file.writeAll(data);
}

/// Convenience: read a file and deserialize it to a Chunk.
pub fn loadFromFile(allocator: std.mem.Allocator, path: []const u8) !Chunk {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const data = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(data);

    return deserialize(data);
}

// ── Tests ──────────────────────────────────────────────────────────────

test "round-trip empty chunk" {
    const allocator = std.testing.allocator;
    const original = Chunk.init();
    const bytes = try serialize(allocator, &original);
    defer allocator.free(bytes);

    const restored = try deserialize(bytes);
    try std.testing.expectEqualSlices(u8, &original.blocks, &restored.blocks);
}

test "round-trip filled chunk compresses to small size" {
    const allocator = std.testing.allocator;
    const original = Chunk.initFilled(block.STONE);
    const bytes = try serialize(allocator, &original);
    defer allocator.free(bytes);

    // All-stone: one run of 4096 blocks = ceil(4096/255)=17 pairs = 34 bytes + 5 header = 39
    try std.testing.expect(bytes.len < 100);

    const restored = try deserialize(bytes);
    try std.testing.expectEqualSlices(u8, &original.blocks, &restored.blocks);
}

test "round-trip mixed chunk" {
    const allocator = std.testing.allocator;
    var original = Chunk.init();
    // Set a variety of blocks
    original.setBlock(0, 0, 0, block.STONE);
    original.setBlock(1, 0, 0, block.DIRT);
    original.setBlock(2, 0, 0, block.GRASS);
    original.setBlock(15, 15, 15, block.BEDROCK);
    original.setBlock(8, 8, 8, block.WATER);
    // Fill one y-layer with stone
    for (0..16) |z| {
        for (0..16) |x| {
            original.setBlock(@intCast(x), 0, @intCast(z), block.STONE);
        }
    }

    const bytes = try serialize(allocator, &original);
    defer allocator.free(bytes);

    const restored = try deserialize(bytes);
    for (0..Chunk.VOLUME) |i| {
        try std.testing.expectEqual(original.blocks[i], restored.blocks[i]);
    }
}

test "invalid magic returns error" {
    var bad_data = [_]u8{ 'B', 'A', 'D', '!', VERSION, 1, 0 };
    const result = deserialize(&bad_data);
    try std.testing.expectError(SerialError.InvalidMagic, result);
}

test "unsupported version returns error" {
    var bad_data = [_]u8{ 'Z', 'V', 'C', 'K', 99, 1, 0 };
    const result = deserialize(&bad_data);
    try std.testing.expectError(SerialError.UnsupportedVersion, result);
}

test "corrupt data - too short" {
    var bad_data = [_]u8{ 'Z', 'V', 'C', 'K' };
    const result = deserialize(&bad_data);
    try std.testing.expectError(SerialError.CorruptData, result);
}

test "mostly-air chunk compresses to less than 100 bytes" {
    const allocator = std.testing.allocator;
    var chunk = Chunk.init();
    // Place a few blocks to keep it mostly air
    chunk.setBlock(0, 0, 0, block.STONE);
    chunk.setBlock(7, 7, 7, block.DIRT);

    const bytes = try serialize(allocator, &chunk);
    defer allocator.free(bytes);

    try std.testing.expect(bytes.len < 100);
}

test "runs longer than 255 blocks handled correctly" {
    const allocator = std.testing.allocator;
    // An all-air chunk has a single run of 4096, requiring ceil(4096/255)=17 pairs
    const original = Chunk.init();
    const bytes = try serialize(allocator, &original);
    defer allocator.free(bytes);

    // 16 * 255 = 4080, 4096 - 4080 = 16 => 17 pairs total
    const rle_bytes = bytes.len - HEADER_SIZE;
    try std.testing.expectEqual(@as(usize, 17 * 2), rle_bytes);

    // Verify round-trip still works
    const restored = try deserialize(bytes);
    try std.testing.expectEqualSlices(u8, &original.blocks, &restored.blocks);
}

test "save and load from file" {
    const allocator = std.testing.allocator;
    var original = Chunk.init();
    original.setBlock(3, 4, 5, block.GRASS);

    const tmp_path = "/tmp/zig_chunk_serial_test.zvck";
    try saveToFile(allocator, &original, tmp_path);

    const restored = try loadFromFile(allocator, tmp_path);
    try std.testing.expectEqualSlices(u8, &original.blocks, &restored.blocks);

    // Cleanup
    std.fs.cwd().deleteFile(tmp_path) catch {};
}
