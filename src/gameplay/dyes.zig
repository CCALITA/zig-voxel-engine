const std = @import("std");

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

pub const DyeableType = enum {
    wool,
    glass,
    terracotta,
    concrete,
    shulker,
    banner,
    leather_armor,
    wolf_collar,
};

pub const DyeMixResult = struct {
    a: DyeColor,
    b: DyeColor,
    result: DyeColor,
};

/// Canonical mixing rules. mixDyes checks both orderings automatically,
/// so each pair only needs a single entry here.
pub const MIXING_TABLE = [_]DyeMixResult{
    .{ .a = .red, .b = .yellow, .result = .orange },
    .{ .a = .blue, .b = .white, .result = .light_blue },
    .{ .a = .blue, .b = .red, .result = .purple },
    .{ .a = .red, .b = .white, .result = .pink },
    .{ .a = .green, .b = .white, .result = .lime },
    .{ .a = .purple, .b = .pink, .result = .magenta },
    .{ .a = .white, .b = .black, .result = .gray },
    .{ .a = .gray, .b = .white, .result = .light_gray },
    .{ .a = .blue, .b = .green, .result = .cyan },
};

/// Look up the result of mixing two dye colors. Returns null if the
/// combination has no defined mix result.
pub fn mixDyes(a: DyeColor, b: DyeColor) ?DyeColor {
    for (MIXING_TABLE) |entry| {
        if ((entry.a == a and entry.b == b) or (entry.a == b and entry.b == a)) {
            return entry.result;
        }
    }
    return null;
}

/// Apply a dye to a dyeable item. For leather armor the result is
/// determined by mixing the current color with the dye; for all other
/// item types the dye color simply replaces the current color.
pub fn applyDye(item_type: DyeableType, current_color: DyeColor, dye: DyeColor) DyeColor {
    if (item_type == .leather_armor) {
        return mixDyes(current_color, dye) orelse dye;
    }
    return dye;
}

/// Return the RGB color value for a dye color, matching the canonical
/// Minecraft Java Edition map/display colors.
pub fn getRGB(color: DyeColor) [3]u8 {
    return switch (color) {
        .white => .{ 249, 255, 254 },
        .orange => .{ 249, 128, 29 },
        .magenta => .{ 199, 78, 189 },
        .light_blue => .{ 58, 179, 218 },
        .yellow => .{ 254, 216, 61 },
        .lime => .{ 128, 199, 31 },
        .pink => .{ 243, 139, 170 },
        .gray => .{ 71, 79, 82 },
        .light_gray => .{ 157, 157, 151 },
        .cyan => .{ 22, 156, 156 },
        .purple => .{ 137, 50, 184 },
        .blue => .{ 60, 68, 170 },
        .brown => .{ 131, 84, 50 },
        .green => .{ 94, 124, 22 },
        .red => .{ 176, 46, 38 },
        .black => .{ 29, 29, 33 },
    };
}

// Tests

test "mix red and yellow produces orange" {
    const result = mixDyes(.red, .yellow);
    try std.testing.expectEqual(DyeColor.orange, result.?);
}

test "mix blue and white produces light_blue" {
    const result = mixDyes(.blue, .white);
    try std.testing.expectEqual(DyeColor.light_blue, result.?);
}

test "mix is commutative (yellow+red also produces orange)" {
    const result = mixDyes(.yellow, .red);
    try std.testing.expectEqual(DyeColor.orange, result.?);
}

test "mix undefined pair returns null" {
    const result = mixDyes(.black, .brown);
    try std.testing.expect(result == null);
}

test "all 16 RGB values are valid (each channel 0-255)" {
    for (0..16) |i| {
        const color: DyeColor = @enumFromInt(i);
        const rgb = getRGB(color);
        try std.testing.expect(rgb[0] > 0 or rgb[1] > 0 or rgb[2] > 0);
    }
}

test "applyDye changes color for wool" {
    const result = applyDye(.wool, .white, .red);
    try std.testing.expectEqual(DyeColor.red, result);
}

test "applyDye on leather_armor mixes colors" {
    // red + yellow → orange via mixing table
    const result = applyDye(.leather_armor, .red, .yellow);
    try std.testing.expectEqual(DyeColor.orange, result);
}

test "applyDye on leather_armor falls back to dye when no mix" {
    // black + brown has no mixing entry → should return the dye color (brown)
    const result = applyDye(.leather_armor, .black, .brown);
    try std.testing.expectEqual(DyeColor.brown, result);
}
