/// Banner crafting, patterns, and placement logic.
const std = @import("std");

pub const PatternType = enum {
    stripe,
    cross,
    border,
    gradient,
    bricks,
    creeper,
    skull,
    flower,
    mojang,
};

pub const DyeColor = enum(u4) {
    white = 0,
    orange = 1,
    magenta = 2,
    light_blue = 3,
    yellow = 4,
    lime = 5,
    pink = 6,
    gray = 7,
    light_gray = 8,
    cyan = 9,
    purple = 10,
    blue = 11,
    brown = 12,
    green = 13,
    red = 14,
    black = 15,
};

pub const BannerLayer = struct {
    pattern: PatternType,
    color: DyeColor,
};

pub const MAX_LAYERS: usize = 6;

pub const Banner = struct {
    base_color: DyeColor,
    layers: [MAX_LAYERS]?BannerLayer,
    layer_count: u8,

    pub fn init(base: DyeColor) Banner {
        return .{
            .base_color = base,
            .layers = [_]?BannerLayer{null} ** MAX_LAYERS,
            .layer_count = 0,
        };
    }

    pub fn addLayer(self: *Banner, pattern: PatternType, color: DyeColor) bool {
        if (self.layer_count >= MAX_LAYERS) return false;
        self.layers[self.layer_count] = .{ .pattern = pattern, .color = color };
        self.layer_count += 1;
        return true;
    }
};

test "banner init" {
    const b = Banner.init(.white);
    try std.testing.expectEqual(@as(u8, 0), b.layer_count);
    try std.testing.expectEqual(DyeColor.white, b.base_color);
}

test "banner add layer" {
    var b = Banner.init(.red);
    try std.testing.expect(b.addLayer(.cross, .blue));
    try std.testing.expectEqual(@as(u8, 1), b.layer_count);
}

test "banner max layers" {
    var b = Banner.init(.black);
    for (0..MAX_LAYERS) |_| {
        try std.testing.expect(b.addLayer(.stripe, .white));
    }
    try std.testing.expect(!b.addLayer(.border, .yellow));
}
