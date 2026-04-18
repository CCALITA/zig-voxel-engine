const std = @import("std");

pub const TILE_SIZE = 16;
pub const ATLAS_TILES_PER_ROW = 16;
pub const ATLAS_SIZE = TILE_SIZE * ATLAS_TILES_PER_ROW;
pub const TOTAL_TILES = 128;

pub const Pixel = struct { r: u8, g: u8, b: u8, a: u8 };

// Base colors for each texture index (simplified Minecraft palette)
const base_colors = [_][3]u8{
    .{128,128,128}, // 0: stone
    .{140,90,50},   // 1: dirt
    .{76,166,38},   // 2: grass top
    .{115,140,64},  // 3: grass side
    .{102,102,102}, // 4: cobblestone
    .{178,140,76},  // 5: planks
    .{218,210,158}, // 6: sand
    .{140,132,115}, // 7: gravel
    .{102,76,38},   // 8: log side
    .{140,115,64},  // 9: log top
    .{51,128,25},   // 10: leaves
    .{51,89,204},   // 11: water
    .{64,64,64},    // 12: bedrock
    // ... fill remaining with gray
};

pub fn generateTile(tex_index: u8) [TILE_SIZE * TILE_SIZE]Pixel {
    var pixels: [TILE_SIZE * TILE_SIZE]Pixel = undefined;
    const color = if (tex_index < base_colors.len) base_colors[tex_index] else [3]u8{128,128,128};

    for (0..TILE_SIZE) |y| {
        for (0..TILE_SIZE) |x| {
            // Simple hash-based noise pattern
            const hash = @as(u32, @intCast(x)) *% 374761393 +% @as(u32, @intCast(y)) *% 668265263 +% @as(u32, tex_index) *% 1274126177;
            const noise: i8 = @intCast(@as(i32, @intCast(hash & 0x1F)) - 16); // -16 to +15

            pixels[y * TILE_SIZE + x] = .{
                .r = @intCast(@max(0, @min(255, @as(i32, color[0]) + noise))),
                .g = @intCast(@max(0, @min(255, @as(i32, color[1]) + noise))),
                .b = @intCast(@max(0, @min(255, @as(i32, color[2]) + noise))),
                .a = 255,
            };
        }
    }
    return pixels;
}

pub fn getUV(tex_index: u8, corner: u2) [2]f32 {
    const tx = tex_index % ATLAS_TILES_PER_ROW;
    const ty = tex_index / ATLAS_TILES_PER_ROW;
    const u_base: f32 = @as(f32, @floatFromInt(tx)) / @as(f32, ATLAS_TILES_PER_ROW);
    const v_base: f32 = @as(f32, @floatFromInt(ty)) / @as(f32, ATLAS_TILES_PER_ROW);
    const tile_uv: f32 = 1.0 / @as(f32, ATLAS_TILES_PER_ROW);

    return switch (corner) {
        0 => .{ u_base, v_base + tile_uv },
        1 => .{ u_base + tile_uv, v_base + tile_uv },
        2 => .{ u_base + tile_uv, v_base },
        3 => .{ u_base, v_base },
    };
}

pub fn getTileColor(tex_index: u8) [3]f32 {
    const c = if (tex_index < base_colors.len) base_colors[tex_index] else [3]u8{128,128,128};
    return .{ @as(f32, @floatFromInt(c[0])) / 255.0, @as(f32, @floatFromInt(c[1])) / 255.0, @as(f32, @floatFromInt(c[2])) / 255.0 };
}

test "atlas tile generation" {
    const tile = generateTile(0);
    try std.testing.expect(tile.len == TILE_SIZE * TILE_SIZE);
    try std.testing.expect(tile[0].a == 255);
}

test "UV coordinates in range" {
    for (0..128) |i| {
        for (0..4) |c| {
            const uv = getUV(@intCast(i), @intCast(c));
            try std.testing.expect(uv[0] >= 0.0 and uv[0] <= 1.0);
            try std.testing.expect(uv[1] >= 0.0 and uv[1] <= 1.0);
        }
    }
}

test "tile color for stone" {
    const c = getTileColor(0);
    try std.testing.expect(c[0] > 0.4 and c[0] < 0.6); // grayish
}
