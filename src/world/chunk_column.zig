/// A vertical column of 16 sub-chunks spanning the full 256-block world height.
/// Null sections represent all-air regions to save memory.
const Chunk = @import("chunk.zig");
const block = @import("block.zig");

pub const SECTIONS = 16;
pub const HEIGHT = SECTIONS * Chunk.SIZE;

const Self = @This();

sections: [SECTIONS]?Chunk,

pub fn init() Self {
    return .{ .sections = .{null} ** SECTIONS };
}

/// Get block at world-height y (0-255). Null sections return AIR.
pub fn getBlock(self: *const Self, x: u4, y: u8, z: u4) block.BlockId {
    const split = splitY(y);
    if (self.sections[split.section]) |*sec| {
        return sec.getBlock(x, split.local, z);
    }
    return block.AIR;
}

/// Set block at world-height y (0-255). Creates the section if it is null.
pub fn setBlock(self: *Self, x: u4, y: u8, z: u4, id: block.BlockId) void {
    const split = splitY(y);
    self.getOrCreateSection(split.section).setBlock(x, split.local, z, id);
}

/// Get an immutable pointer to the sub-chunk at the given section index, or null if empty.
pub fn getSection(self: *const Self, section: u4) ?*const Chunk {
    if (self.sections[section]) |*sec| {
        return sec;
    }
    return null;
}

/// Get a mutable pointer to the sub-chunk at the given section index, creating it if null.
pub fn getOrCreateSection(self: *Self, section: u4) *Chunk {
    if (self.sections[section] == null) {
        self.sections[section] = Chunk.init();
    }
    return &(self.sections[section].?);
}

/// Count the number of non-null (allocated) sections.
pub fn activeSections(self: *const Self) u32 {
    var count: u32 = 0;
    for (self.sections) |sec| {
        if (sec != null) count += 1;
    }
    return count;
}

/// Split a world y coordinate into section index and local offset.
fn splitY(y: u8) struct { section: u4, local: u4 } {
    return .{
        .section = @intCast(y >> 4),
        .local = @truncate(y),
    };
}

/// Find the highest non-air block at (x, z). Returns 0 if the column is entirely air.
pub fn getHeight(self: *const Self, x: u4, z: u4) u8 {
    var section_idx: u4 = SECTIONS - 1;
    while (true) {
        if (self.sections[section_idx]) |*sec| {
            var local_y: u4 = Chunk.SIZE - 1;
            while (true) {
                if (sec.getBlock(x, local_y, z) != block.AIR) {
                    return @as(u8, section_idx) * Chunk.SIZE + @as(u8, local_y);
                }
                if (local_y == 0) break;
                local_y -= 1;
            }
        }
        if (section_idx == 0) break;
        section_idx -= 1;
    }
    return 0;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
const std = @import("std");

test "init: all sections null, getBlock returns AIR everywhere" {
    const col = Self.init();
    try std.testing.expectEqual(@as(u32, 0), col.activeSections());
    try std.testing.expectEqual(block.AIR, col.getBlock(0, 0, 0));
    try std.testing.expectEqual(block.AIR, col.getBlock(15, 255, 15));
    try std.testing.expectEqual(block.AIR, col.getBlock(7, 128, 7));
}

test "setBlock at y=200 creates section 12" {
    var col = Self.init();
    col.setBlock(3, 200, 5, block.STONE);
    // section 200/16 = 12
    try std.testing.expect(col.getSection(12) != null);
    try std.testing.expectEqual(@as(u32, 1), col.activeSections());
}

test "getBlock at y=200 returns what was set" {
    var col = Self.init();
    col.setBlock(3, 200, 5, block.STONE);
    try std.testing.expectEqual(block.STONE, col.getBlock(3, 200, 5));
    // neighbouring block still air
    try std.testing.expectEqual(block.AIR, col.getBlock(3, 201, 5));
}

test "getHeight returns correct value" {
    var col = Self.init();
    try std.testing.expectEqual(@as(u8, 0), col.getHeight(0, 0));

    col.setBlock(0, 100, 0, block.DIRT);
    try std.testing.expectEqual(@as(u8, 100), col.getHeight(0, 0));

    col.setBlock(0, 200, 0, block.GRASS);
    try std.testing.expectEqual(@as(u8, 200), col.getHeight(0, 0));

    // different (x,z) still 0
    try std.testing.expectEqual(@as(u8, 0), col.getHeight(1, 1));
}

test "activeSections counts correctly" {
    var col = Self.init();
    try std.testing.expectEqual(@as(u32, 0), col.activeSections());

    col.setBlock(0, 0, 0, block.STONE); // section 0
    try std.testing.expectEqual(@as(u32, 1), col.activeSections());

    col.setBlock(0, 16, 0, block.STONE); // section 1
    try std.testing.expectEqual(@as(u32, 2), col.activeSections());

    col.setBlock(0, 255, 0, block.STONE); // section 15
    try std.testing.expectEqual(@as(u32, 3), col.activeSections());

    // setting in an already-active section doesn't increase count
    col.setBlock(1, 1, 1, block.DIRT); // still section 0
    try std.testing.expectEqual(@as(u32, 3), col.activeSections());
}

test "round-trip: set various blocks across sections, verify all correct" {
    var col = Self.init();

    const cases = [_]struct { x: u4, y: u8, z: u4, id: block.BlockId }{
        .{ .x = 0, .y = 0, .z = 0, .id = block.BEDROCK },
        .{ .x = 5, .y = 17, .z = 3, .id = block.DIRT },
        .{ .x = 15, .y = 64, .z = 15, .id = block.GRASS },
        .{ .x = 8, .y = 128, .z = 8, .id = block.STONE },
        .{ .x = 0, .y = 255, .z = 0, .id = block.SAND },
        .{ .x = 12, .y = 200, .z = 7, .id = block.OAK_LOG },
    };

    for (cases) |c| {
        col.setBlock(c.x, c.y, c.z, c.id);
    }

    for (cases) |c| {
        try std.testing.expectEqual(c.id, col.getBlock(c.x, c.y, c.z));
    }
}

test "getOrCreateSection creates and returns mutable section" {
    var col = Self.init();
    try std.testing.expect(col.getSection(5) == null);

    const sec = col.getOrCreateSection(5);
    sec.setBlock(1, 2, 3, block.COBBLESTONE);

    try std.testing.expect(col.getSection(5) != null);
    try std.testing.expectEqual(block.COBBLESTONE, col.getBlock(1, 5 * 16 + 2, 3));
}
