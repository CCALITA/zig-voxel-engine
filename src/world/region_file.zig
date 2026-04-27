/// Minecraft-style region file storage for chunks.
///
/// Batches 32x32 chunks into a single region file (Anvil .mca format).
/// Each region file has a header with offsets and timestamps, followed by
/// sector-aligned chunk data. Includes SimpleRLE for optional compression.
const std = @import("std");

pub const REGION_SIZE: u6 = 32;
pub const SECTOR_SIZE: usize = 4096;
const SLOTS: usize = @as(usize, REGION_SIZE) * REGION_SIZE; // 1024

// ── RegionHeader ──────────────────────────────────────────────────────

pub const RegionHeader = struct {
    offsets: [SLOTS]u32 = .{0} ** SLOTS,
    timestamps: [SLOTS]u32 = .{0} ** SLOTS,

    pub fn getChunkIndex(local_cx: u5, local_cz: u5) u10 {
        return @as(u10, local_cz) * REGION_SIZE + local_cx;
    }

    pub const OffsetInfo = struct { sector: u24, count: u8 };

    pub fn getOffset(self: *const RegionHeader, index: u10) OffsetInfo {
        const raw = self.offsets[index];
        return .{
            .sector = @intCast(raw >> 8),
            .count = @intCast(raw & 0xFF),
        };
    }

    pub fn setOffset(self: *RegionHeader, index: u10, sector: u24, count: u8) void {
        self.offsets[index] = (@as(u32, sector) << 8) | count;
    }
};

// ── ChunkDataHeader ───────────────────────────────────────────────────

pub const ChunkDataHeader = struct {
    length: u32,
    compression: u8, // 1=gzip, 2=zlib, 3=none

    pub const SIZE: usize = 5;

    pub fn encode(self: ChunkDataHeader) [SIZE]u8 {
        var buf: [SIZE]u8 = undefined;
        std.mem.writeInt(u32, buf[0..4], self.length, .big);
        buf[4] = self.compression;
        return buf;
    }

    pub fn decode(buf: *const [SIZE]u8) ChunkDataHeader {
        return .{
            .length = std.mem.readInt(u32, buf[0..4], .big),
            .compression = buf[4],
        };
    }
};

// ── RegionFile ────────────────────────────────────────────────────────

pub const MAX_DATA_SECTORS: usize = 1024;

pub const RegionFile = struct {
    header: RegionHeader = .{},
    data_buffer: [MAX_DATA_SECTORS * SECTOR_SIZE]u8 = undefined,
    next_sector: u24 = 2, // sectors 0-1 reserved for header

    pub const WriteError = error{RegionFull};

    /// Convert an absolute sector number to a byte offset in data_buffer.
    fn sectorToOffset(sector: u24) usize {
        return (@as(usize, sector) - 2) * SECTOR_SIZE;
    }

    /// Write chunk data into the region at the given local coordinates.
    /// Data is stored with a ChunkDataHeader (compression=3, uncompressed).
    pub fn writeChunk(self: *RegionFile, local_cx: u5, local_cz: u5, chunk_data: []const u8) WriteError!void {
        const total_len = ChunkDataHeader.SIZE + chunk_data.len;
        const sectors_needed: u24 = @intCast((total_len + SECTOR_SIZE - 1) / SECTOR_SIZE);
        const index = RegionHeader.getChunkIndex(local_cx, local_cz);

        // Allocate sectors from the end (no reuse of freed sectors for simplicity)
        const sector_start = self.next_sector;
        const new_next = @as(u32, sector_start) + sectors_needed;
        if (new_next > MAX_DATA_SECTORS) return WriteError.RegionFull;
        self.next_sector = @intCast(new_next);

        // Write ChunkDataHeader + payload into data_buffer
        const buf_offset = sectorToOffset(sector_start);
        const hdr = ChunkDataHeader{ .length = @intCast(chunk_data.len), .compression = 3 };
        const hdr_bytes = hdr.encode();
        @memcpy(self.data_buffer[buf_offset..][0..ChunkDataHeader.SIZE], &hdr_bytes);
        @memcpy(self.data_buffer[buf_offset + ChunkDataHeader.SIZE ..][0..chunk_data.len], chunk_data);

        // Update header
        self.header.setOffset(index, sector_start, @intCast(sectors_needed));
        self.header.timestamps[index] = 1;
    }

    /// Read chunk data from the region. Returns null if the slot is empty.
    pub fn readChunk(self: *const RegionFile, local_cx: u5, local_cz: u5) ?[]const u8 {
        const index = RegionHeader.getChunkIndex(local_cx, local_cz);
        const info = self.header.getOffset(index);
        if (info.count == 0) return null;

        const buf_offset = sectorToOffset(info.sector);
        const hdr_bytes: *const [ChunkDataHeader.SIZE]u8 = self.data_buffer[buf_offset..][0..ChunkDataHeader.SIZE];
        const hdr = ChunkDataHeader.decode(hdr_bytes);
        const start = buf_offset + ChunkDataHeader.SIZE;
        return self.data_buffer[start..][0..hdr.length];
    }

    pub fn hasChunk(self: *const RegionFile, local_cx: u5, local_cz: u5) bool {
        const index = RegionHeader.getChunkIndex(local_cx, local_cz);
        return self.header.getOffset(index).count != 0;
    }

    pub fn getChunkTimestamp(self: *const RegionFile, local_cx: u5, local_cz: u5) u32 {
        const index = RegionHeader.getChunkIndex(local_cx, local_cz);
        return self.header.timestamps[index];
    }

    pub fn chunkCount(self: *const RegionFile) u16 {
        var count: u16 = 0;
        for (self.header.offsets) |off| {
            if ((off & 0xFF) != 0) count += 1;
        }
        return count;
    }
};

// ── Coordinate helpers ────────────────────────────────────────────────

pub const RegionCoords = struct {
    region_x: i32,
    region_z: i32,
    local_x: u5,
    local_z: u5,
};

/// Convert world chunk coordinates to region + local coordinates.
pub fn regionCoords(chunk_x: i32, chunk_z: i32) RegionCoords {
    return .{
        .region_x = @divFloor(chunk_x, REGION_SIZE),
        .region_z = @divFloor(chunk_z, REGION_SIZE),
        .local_x = @intCast(@mod(chunk_x, REGION_SIZE)),
        .local_z = @intCast(@mod(chunk_z, REGION_SIZE)),
    };
}

/// Format a region file name like "r.{rx}.{rz}.mca".
pub fn regionFileName(region_x: i32, region_z: i32) [32]u8 {
    var buf: [32]u8 = .{0} ** 32;
    _ = std.fmt.bufPrint(&buf, "r.{d}.{d}.mca", .{ region_x, region_z }) catch unreachable;
    return buf;
}

// ── SimpleRLE ─────────────────────────────────────────────────────────

pub const SimpleRLE = struct {
    /// Run-length encode: pairs of (count, byte). Runs capped at 255.
    pub fn compress(input: []const u8, buf: []u8) []u8 {
        var out: usize = 0;
        var i: usize = 0;
        while (i < input.len) {
            const val = input[i];
            var run: usize = 1;
            while (i + run < input.len and input[i + run] == val and run < 255) {
                run += 1;
            }
            buf[out] = @intCast(run);
            buf[out + 1] = val;
            out += 2;
            i += run;
        }
        return buf[0..out];
    }

    /// Decode RLE pairs back to the original data.
    pub fn decompress(input: []const u8, buf: []u8) []u8 {
        var out: usize = 0;
        var i: usize = 0;
        while (i + 1 < input.len) {
            const count: usize = input[i];
            const val = input[i + 1];
            @memset(buf[out..][0..count], val);
            out += count;
            i += 2;
        }
        return buf[0..out];
    }
};

// ── Tests ─────────────────────────────────────────────────────────────

test "header offset packing and unpacking" {
    var hdr = RegionHeader{};
    hdr.setOffset(0, 100, 3);
    const info = hdr.getOffset(0);
    try std.testing.expectEqual(@as(u24, 100), info.sector);
    try std.testing.expectEqual(@as(u8, 3), info.count);
}

test "header getChunkIndex" {
    try std.testing.expectEqual(@as(u10, 0), RegionHeader.getChunkIndex(0, 0));
    try std.testing.expectEqual(@as(u10, 1), RegionHeader.getChunkIndex(1, 0));
    try std.testing.expectEqual(@as(u10, 32), RegionHeader.getChunkIndex(0, 1));
    try std.testing.expectEqual(@as(u10, 1023), RegionHeader.getChunkIndex(31, 31));
}

test "write and read back chunk data" {
    var region: RegionFile = .{};
    const data = "hello chunk data!";
    try region.writeChunk(0, 0, data);
    const result = region.readChunk(0, 0);
    try std.testing.expect(result != null);
    try std.testing.expectEqualStrings(data, result.?);
}

test "regionCoords calculation" {
    const c = regionCoords(33, -1);
    try std.testing.expectEqual(@as(i32, 1), c.region_x);
    try std.testing.expectEqual(@as(i32, -1), c.region_z);
    try std.testing.expectEqual(@as(u5, 1), c.local_x);
    try std.testing.expectEqual(@as(u5, 31), c.local_z);
}

test "regionCoords zero" {
    const c = regionCoords(0, 0);
    try std.testing.expectEqual(@as(i32, 0), c.region_x);
    try std.testing.expectEqual(@as(i32, 0), c.region_z);
    try std.testing.expectEqual(@as(u5, 0), c.local_x);
    try std.testing.expectEqual(@as(u5, 0), c.local_z);
}

test "multiple chunks in same region" {
    var region: RegionFile = .{};
    try region.writeChunk(0, 0, "chunk_0_0");
    try region.writeChunk(1, 0, "chunk_1_0");
    try region.writeChunk(0, 1, "chunk_0_1");

    try std.testing.expectEqualStrings("chunk_0_0", region.readChunk(0, 0).?);
    try std.testing.expectEqualStrings("chunk_1_0", region.readChunk(1, 0).?);
    try std.testing.expectEqualStrings("chunk_0_1", region.readChunk(0, 1).?);
}

test "overwrite existing chunk" {
    var region: RegionFile = .{};
    try region.writeChunk(5, 5, "old data");
    try region.writeChunk(5, 5, "new data");
    // Note: old data sectors are leaked (append-only), but latest read is correct
    try std.testing.expectEqualStrings("new data", region.readChunk(5, 5).?);
}

test "hasChunk" {
    var region: RegionFile = .{};
    try std.testing.expect(!region.hasChunk(0, 0));
    try region.writeChunk(0, 0, "data");
    try std.testing.expect(region.hasChunk(0, 0));
}

test "chunkCount" {
    var region: RegionFile = .{};
    try std.testing.expectEqual(@as(u16, 0), region.chunkCount());
    try region.writeChunk(0, 0, "a");
    try region.writeChunk(1, 1, "b");
    try region.writeChunk(2, 2, "c");
    try std.testing.expectEqual(@as(u16, 3), region.chunkCount());
}

test "timestamps" {
    var region: RegionFile = .{};
    try std.testing.expectEqual(@as(u32, 0), region.getChunkTimestamp(0, 0));
    try region.writeChunk(0, 0, "data");
    try std.testing.expectEqual(@as(u32, 1), region.getChunkTimestamp(0, 0));
}

test "region file name formatting" {
    const name = regionFileName(1, -2);
    const expected = "r.1.-2.mca";
    try std.testing.expectEqualStrings(expected, name[0..expected.len]);
}

test "RLE compress and decompress round-trip" {
    const input = "aaabbbccccdddddd";
    var comp_buf: [256]u8 = undefined;
    var decomp_buf: [256]u8 = undefined;
    const compressed = SimpleRLE.compress(input, &comp_buf);
    const decompressed = SimpleRLE.decompress(compressed, &decomp_buf);
    try std.testing.expectEqualStrings(input, decompressed);
}

test "empty region has zero chunks" {
    const region: RegionFile = .{};
    try std.testing.expectEqual(@as(u16, 0), region.chunkCount());
    try std.testing.expect(region.readChunk(0, 0) == null);
    try std.testing.expect(!region.hasChunk(15, 15));
}

test "ChunkDataHeader encode and decode round-trip" {
    const hdr = ChunkDataHeader{ .length = 12345, .compression = 2 };
    const bytes = hdr.encode();
    const decoded = ChunkDataHeader.decode(&bytes);
    try std.testing.expectEqual(hdr.length, decoded.length);
    try std.testing.expectEqual(hdr.compression, decoded.compression);
}
