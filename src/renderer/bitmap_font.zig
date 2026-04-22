/// Bitmap font for rendering digits and basic text using UI quads.
/// Each glyph is a 3x5 pixel grid stored as a u15 bitmask (row-major, MSB first).
/// Render by emitting one tiny quad per lit pixel.

pub const GLYPH_W: u32 = 3;
pub const GLYPH_H: u32 = 5;

const glyphs = [10]u15{
    0b111_101_101_101_111, // 0
    0b010_110_010_010_111, // 1
    0b111_001_111_100_111, // 2
    0b111_001_111_001_111, // 3
    0b101_101_111_001_001, // 4
    0b111_100_111_001_111, // 5
    0b111_100_111_101_111, // 6
    0b111_001_010_010_010, // 7
    0b111_101_111_101_111, // 8
    0b111_101_111_001_111, // 9
};

pub fn getPixel(digit: u8, x: u32, y: u32) bool {
    if (digit > 9 or x >= GLYPH_W or y >= GLYPH_H) return false;
    const bit_index: u4 = @intCast(y * GLYPH_W + x);
    return (glyphs[digit] >> (14 - bit_index)) & 1 == 1;
}

pub fn digitCount(value: u32) u32 {
    if (value == 0) return 1;
    var v = value;
    var c: u32 = 0;
    while (v > 0) : (v /= 10) c += 1;
    return c;
}

pub fn getDigit(value: u32, pos: u32) u8 {
    var v = value;
    var i: u32 = 0;
    while (i < pos) : (i += 1) v /= 10;
    return @intCast(v % 10);
}

test "digit 0 top-left pixel is lit" {
    const std = @import("std");
    try std.testing.expect(getPixel(0, 0, 0));
}

test "digit 1 top-left pixel is not lit" {
    const std = @import("std");
    try std.testing.expect(!getPixel(1, 0, 0));
}

test "digit count" {
    const std = @import("std");
    try std.testing.expectEqual(@as(u32, 1), digitCount(0));
    try std.testing.expectEqual(@as(u32, 1), digitCount(5));
    try std.testing.expectEqual(@as(u32, 2), digitCount(42));
    try std.testing.expectEqual(@as(u32, 2), digitCount(64));
}

test "get digit extracts correctly" {
    const std = @import("std");
    try std.testing.expectEqual(@as(u8, 4), getDigit(42, 0));
    try std.testing.expectEqual(@as(u8, 2), getDigit(42, 1));
}
