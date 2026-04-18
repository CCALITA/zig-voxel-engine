const std = @import("std");

pub const ItemId = u16;
pub const BlockId = u8;
pub const STACK_MAX: u8 = 64;

pub const Coord = struct {
    x: i32,
    y: i32,
    z: i32,
};

pub const ChunkCoord = struct {
    x: i32,
    z: i32,
};

pub fn floatToBlock(v: f32) i32 {
    return @intFromFloat(@floor(v));
}

pub fn blockToFloat(v: i32) f32 {
    return @as(f32, @floatFromInt(v)) + 0.5;
}

test "floatToBlock" {
    try std.testing.expectEqual(@as(i32, 3), floatToBlock(3.7));
    try std.testing.expectEqual(@as(i32, -1), floatToBlock(-0.1));
    try std.testing.expectEqual(@as(i32, 0), floatToBlock(0.9));
}

test "blockToFloat centers on block" {
    try std.testing.expectApproxEqAbs(@as(f32, 3.5), blockToFloat(3), 0.001);
}
