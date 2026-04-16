/// A 16x16x16 chunk of blocks.
/// Stores block IDs in a flat array indexed [y * 256 + z * 16 + x].
const block = @import("block.zig");
const BlockId = block.BlockId;

pub const SIZE = 16;
pub const VOLUME = SIZE * SIZE * SIZE;

blocks: [VOLUME]BlockId,

const Self = @This();

pub fn init() Self {
    return .{ .blocks = .{block.AIR} ** VOLUME };
}

pub fn initFilled(id: BlockId) Self {
    return .{ .blocks = .{id} ** VOLUME };
}

pub fn getBlock(self: *const Self, x: u4, y: u4, z: u4) BlockId {
    return self.blocks[index(x, y, z)];
}

pub fn setBlock(self: *Self, x: u4, y: u4, z: u4, id: BlockId) void {
    self.blocks[index(x, y, z)] = id;
}

fn index(x: u4, y: u4, z: u4) usize {
    return @as(usize, y) * 256 + @as(usize, z) * 16 + @as(usize, x);
}

/// Check if a neighbor block (potentially out of bounds) is solid.
/// Out-of-bounds = air (not solid), so faces on chunk edges are always emitted.
pub fn isNeighborSolid(self: *const Self, x: i32, y: i32, z: i32) bool {
    if (x < 0 or x >= SIZE or y < 0 or y >= SIZE or z < 0 or z >= SIZE) return false;
    return block.isSolid(self.blocks[index(@intCast(x), @intCast(y), @intCast(z))]);
}

const std = @import("std");

test "empty chunk is all air" {
    const chunk = Self.init();
    try std.testing.expectEqual(block.AIR, chunk.getBlock(0, 0, 0));
    try std.testing.expectEqual(block.AIR, chunk.getBlock(15, 15, 15));
}

test "set and get block" {
    var chunk = Self.init();
    chunk.setBlock(5, 10, 3, block.STONE);
    try std.testing.expectEqual(block.STONE, chunk.getBlock(5, 10, 3));
}

test "filled chunk" {
    const chunk = Self.initFilled(block.STONE);
    try std.testing.expectEqual(block.STONE, chunk.getBlock(0, 0, 0));
}
