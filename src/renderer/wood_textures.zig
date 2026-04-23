const std = @import("std");

pub const Pixel = struct { r: u8, g: u8, b: u8, a: u8 };

fn hash(x: u32, y: u32, seed: u32) u32 {
    var h = x *% 374761393 +% y *% 668265263 +% seed *% 1274126177;
    h = (h ^ (h >> 13)) *% 1103515245;
    return h ^ (h >> 16);
}

fn clampU8(v: i32) u8 {
    return @intCast(@max(0, @min(255, v)));
}

fn px(r: u8, g: u8, b: u8) Pixel {
    return .{ .r = r, .g = g, .b = b, .a = 255 };
}

fn noise16(h: u32) i32 {
    return @as(i32, @intCast(h & 0xF)) - 8;
}

fn tintPx(color: [3]i32, n: i32) Pixel {
    return px(clampU8(color[0] + n), clampU8(color[1] + n), clampU8(color[2] + n));
}

// --- Color palette per wood type ---

const WoodPalette = struct {
    bark_base: [3]i32,
    bark_groove: [3]i32,
    ring_light: [3]i32,
    ring_dark: [3]i32,
    plank_light: [3]i32,
    plank_mid: [3]i32,
    plank_dark: [3]i32,
};

const palettes = [6]WoodPalette{
    // Birch: light tan bark with horizontal black stripes, white-cream planks
    .{
        .bark_base = .{ 200, 195, 180 },
        .bark_groove = .{ 30, 28, 25 },
        .ring_light = .{ 210, 200, 170 },
        .ring_dark = .{ 180, 170, 140 },
        .plank_light = .{ 235, 225, 200 },
        .plank_mid = .{ 215, 205, 175 },
        .plank_dark = .{ 195, 185, 160 },
    },
    // Spruce: dark brown bark with vertical grooves, dark reddish-brown planks
    .{
        .bark_base = .{ 70, 45, 25 },
        .bark_groove = .{ 40, 25, 12 },
        .ring_light = .{ 90, 65, 35 },
        .ring_dark = .{ 60, 40, 22 },
        .plank_light = .{ 115, 75, 50 },
        .plank_mid = .{ 95, 60, 38 },
        .plank_dark = .{ 78, 48, 30 },
    },
    // Jungle: olive-green bark with vine hints, warm reddish planks
    .{
        .bark_base = .{ 90, 100, 50 },
        .bark_groove = .{ 55, 70, 30 },
        .ring_light = .{ 120, 110, 70 },
        .ring_dark = .{ 90, 80, 50 },
        .plank_light = .{ 180, 120, 80 },
        .plank_mid = .{ 160, 100, 65 },
        .plank_dark = .{ 140, 85, 55 },
    },
    // Acacia: gray bark with orange undertone, distinctive orange planks
    .{
        .bark_base = .{ 130, 115, 100 },
        .bark_groove = .{ 90, 75, 65 },
        .ring_light = .{ 150, 120, 80 },
        .ring_dark = .{ 120, 95, 60 },
        .plank_light = .{ 200, 120, 50 },
        .plank_mid = .{ 180, 105, 40 },
        .plank_dark = .{ 160, 90, 32 },
    },
    // Dark Oak: very dark brown bark, dark chocolate brown planks
    .{
        .bark_base = .{ 50, 35, 20 },
        .bark_groove = .{ 28, 18, 10 },
        .ring_light = .{ 70, 50, 30 },
        .ring_dark = .{ 45, 30, 18 },
        .plank_light = .{ 80, 55, 30 },
        .plank_mid = .{ 65, 42, 22 },
        .plank_dark = .{ 50, 32, 16 },
    },
    // Mangrove: brown-red bark with root texture, red-tinted planks
    .{
        .bark_base = .{ 110, 55, 40 },
        .bark_groove = .{ 70, 32, 22 },
        .ring_light = .{ 130, 80, 55 },
        .ring_dark = .{ 95, 55, 38 },
        .plank_light = .{ 150, 75, 60 },
        .plank_mid = .{ 130, 60, 48 },
        .plank_dark = .{ 112, 50, 38 },
    },
};

// --- Core texture generators ---

fn genLogSide(x: u32, y: u32, pal: WoodPalette, seed: u32) Pixel {
    const h = hash(x, y, seed);
    const n = noise16(h);
    const groove = (x +% (h >> 8) % 2) % 4;
    if (groove == 0) return tintPx(pal.bark_groove, n);
    return tintPx(pal.bark_base, n);
}

fn genBirchLogSide(x: u32, y: u32) Pixel {
    const h = hash(x, y, 126);
    const n = noise16(h);
    const pal = palettes[0];

    // Horizontal black stripes (unique to birch)
    const stripe = (y +% (h >> 8) % 3) % 5;
    if (stripe == 0) return tintPx(pal.bark_groove, n);

    // Scattered darker patches
    if ((h >> 5) % 12 == 0) return tintPx(.{ pal.bark_base[0] - 20, pal.bark_base[1] - 20, pal.bark_base[2] - 15 }, n);

    return tintPx(pal.bark_base, n);
}

fn genSpruceLogSide(x: u32, y: u32) Pixel {
    const h = hash(x, y, 129);
    const n = noise16(h);
    const pal = palettes[1];

    // Deep vertical grooves (every 3 pixels)
    const groove = (x +% (h >> 8) % 2) % 3;
    if (groove == 0) return tintPx(pal.bark_groove, n);
    return tintPx(pal.bark_base, n);
}

fn genJungleLogSide(x: u32, y: u32) Pixel {
    const h = hash(x, y, 132);
    const n = noise16(h);
    const pal = palettes[2];

    // Vine hints (scattered green pixels)
    if ((h >> 4) % 10 == 0) return tintPx(.{ 50, 110, 35 }, n);

    const groove = (x +% (h >> 8) % 2) % 4;
    if (groove == 0) return tintPx(pal.bark_groove, n);
    return tintPx(pal.bark_base, n);
}

fn genAcaciaLogSide(x: u32, y: u32) Pixel {
    const h = hash(x, y, 135);
    const n = noise16(h);
    const pal = palettes[3];

    // Orange undertone shows through groove cracks
    const groove = (x +% (h >> 8) % 2) % 5;
    if (groove == 0) return tintPx(.{ 160, 90, 40 }, n);
    return tintPx(pal.bark_base, n);
}

fn genDarkOakLogSide(x: u32, y: u32) Pixel {
    return genLogSide(x, y, palettes[4], 138);
}

fn genMangroveLogSide(x: u32, y: u32) Pixel {
    const h = hash(x, y, 141);
    const n = noise16(h);
    const pal = palettes[5];

    // Root-like diagonal streaks
    const diag = (x +% y) % 6;
    if (diag == 0) return tintPx(pal.bark_groove, n);

    // Darker horizontal root bands
    if ((y +% (h >> 6) % 3) % 7 == 0) return tintPx(.{ pal.bark_base[0] - 15, pal.bark_base[1] - 10, pal.bark_base[2] - 8 }, n);

    return tintPx(pal.bark_base, n);
}

// --- Log top: concentric rings from center ---

fn genLogTop(x: u32, y: u32, pal: WoodPalette, seed: u32) Pixel {
    const h = hash(x, y, seed);
    const n = noise16(h);
    const dx = @as(i32, @intCast(x)) - 7;
    const dy = @as(i32, @intCast(y)) - 7;
    const dist: u32 = @intCast(@abs(dx) + @abs(dy));
    if (dist % 4 < 2) return tintPx(pal.ring_light, n);
    return tintPx(pal.ring_dark, n);
}

fn genPlanks(y: u32, h: u32, pal: WoodPalette, band_width: u32) Pixel {
    const n = noise16(h);
    const band = (y +% (h >> 8) % 2) % band_width;
    if (band < band_width / 2) return tintPx(pal.plank_light, n);
    if (band == band_width / 2) return tintPx(pal.plank_dark, n);
    return tintPx(pal.plank_mid, n);
}

// --- Public API ---

pub fn getWoodTexture(tex_index: u16) ?[256]Pixel {
    if (tex_index < 126 or tex_index > 143) return null;

    var pixels: [256]Pixel = undefined;
    for (0..16) |yi| {
        for (0..16) |xi| {
            const x: u32 = @intCast(xi);
            const y: u32 = @intCast(yi);
            pixels[y * 16 + x] = generatePixel(tex_index, x, y);
        }
    }
    return pixels;
}

pub fn generateTile(tex_index: u16) ?[256]Pixel {
    return getWoodTexture(tex_index);
}

fn generatePixel(tex_index: u16, x: u32, y: u32) Pixel {
    return switch (tex_index) {
        // Birch (126-128)
        126 => genBirchLogSide(x, y),
        127 => genLogTop(x, y, palettes[0], 127),
        128 => genPlanks(y, hash(x, y, 128), palettes[0], 7),
        // Spruce (129-131)
        129 => genSpruceLogSide(x, y),
        130 => genLogTop(x, y, palettes[1], 130),
        131 => genPlanks(y, hash(x, y, 131), palettes[1], 6),
        // Jungle (132-134)
        132 => genJungleLogSide(x, y),
        133 => genLogTop(x, y, palettes[2], 133),
        134 => genPlanks(y, hash(x, y, 134), palettes[2], 5),
        // Acacia (135-137)
        135 => genAcaciaLogSide(x, y),
        136 => genLogTop(x, y, palettes[3], 136),
        137 => genPlanks(y, hash(x, y, 137), palettes[3], 8),
        // Dark Oak (138-140)
        138 => genDarkOakLogSide(x, y),
        139 => genLogTop(x, y, palettes[4], 139),
        140 => genPlanks(y, hash(x, y, 140), palettes[4], 6),
        // Mangrove (141-143)
        141 => genMangroveLogSide(x, y),
        142 => genLogTop(x, y, palettes[5], 142),
        143 => genPlanks(y, hash(x, y, 143), palettes[5], 7),
        else => px(255, 0, 255), // magenta fallback (unreachable)
    };
}

// --- Tests ---

test "returns null for out-of-range indices" {
    try std.testing.expect(getWoodTexture(0) == null);
    try std.testing.expect(getWoodTexture(125) == null);
    try std.testing.expect(getWoodTexture(144) == null);
    try std.testing.expect(getWoodTexture(255) == null);
}

test "returns valid tile for every wood texture index" {
    for (126..144) |i| {
        const tile = getWoodTexture(@intCast(i));
        try std.testing.expect(tile != null);
        try std.testing.expectEqual(@as(usize, 256), tile.?.len);
    }
}

test "all pixels are fully opaque" {
    for (126..144) |i| {
        const tile = getWoodTexture(@intCast(i)).?;
        for (tile) |pixel| {
            try std.testing.expectEqual(@as(u8, 255), pixel.a);
        }
    }
}

test "birch planks are lighter than dark oak planks" {
    const birch_planks = getWoodTexture(128).?;
    const dark_oak_planks = getWoodTexture(140).?;

    var birch_avg: u64 = 0;
    var dark_avg: u64 = 0;
    for (0..256) |i| {
        birch_avg += birch_planks[i].r;
        dark_avg += dark_oak_planks[i].r;
    }
    // Birch planks should be significantly brighter than dark oak
    try std.testing.expect(birch_avg > dark_avg);
}

test "each wood type produces distinct log side textures" {
    const log_side_indices = [6]u16{ 126, 129, 132, 135, 138, 141 };

    for (log_side_indices, 0..) |idx_a, i| {
        const tile_a = getWoodTexture(idx_a).?;
        for (log_side_indices[i + 1 ..]) |idx_b| {
            const tile_b = getWoodTexture(idx_b).?;
            var diff_count: u32 = 0;
            for (0..256) |p| {
                const dr = @as(i32, tile_a[p].r) - @as(i32, tile_b[p].r);
                const dg = @as(i32, tile_a[p].g) - @as(i32, tile_b[p].g);
                const db = @as(i32, tile_a[p].b) - @as(i32, tile_b[p].b);
                if (@abs(dr) + @abs(dg) + @abs(db) > 15) diff_count += 1;
            }
            // At least 30% of pixels should differ meaningfully
            try std.testing.expect(diff_count > 76);
        }
    }
}

test "generateTile and getWoodTexture return identical results" {
    for (126..144) |i| {
        const idx: u16 = @intCast(i);
        const from_gen = generateTile(idx).?;
        const from_get = getWoodTexture(idx).?;
        try std.testing.expectEqualSlices(Pixel, &from_gen, &from_get);
    }
}
