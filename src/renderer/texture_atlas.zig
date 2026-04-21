const std = @import("std");

pub const TILE_SIZE: u32 = 16;
pub const ATLAS_TILES_PER_ROW: u32 = 64;
pub const ATLAS_SIZE: u32 = TILE_SIZE * ATLAS_TILES_PER_ROW; // 1024
pub const TOTAL_TILES: u32 = 512;

pub const Pixel = struct { r: u8, g: u8, b: u8, a: u8 };

const Rgb = [3]u8;

const base_colors = init_base_colors();

fn init_base_colors() [256]Rgb {
    var c: [256]Rgb = [_]Rgb{.{ 128, 128, 128 }} ** 256;
    c[0] = .{ 128, 128, 128 }; // stone
    c[1] = .{ 140, 90, 50 }; // dirt
    c[2] = .{ 76, 166, 38 }; // grass top
    c[3] = .{ 115, 140, 64 }; // grass side
    c[4] = .{ 102, 102, 102 }; // cobblestone
    c[5] = .{ 178, 140, 76 }; // planks
    c[6] = .{ 218, 210, 158 }; // sand
    c[7] = .{ 140, 132, 115 }; // gravel
    c[8] = .{ 102, 76, 38 }; // log side
    c[9] = .{ 140, 115, 64 }; // log top
    c[10] = .{ 51, 128, 25 }; // leaves
    c[11] = .{ 51, 89, 204 }; // water
    c[12] = .{ 64, 64, 64 }; // bedrock
    c[13] = .{ 90, 90, 90 }; // coal ore
    c[14] = .{ 140, 128, 115 }; // iron ore
    c[15] = .{ 166, 153, 76 }; // gold ore
    c[16] = .{ 102, 166, 166 }; // diamond ore
    c[17] = .{ 140, 64, 51 }; // redstone ore
    c[18] = .{ 192, 217, 230 }; // glass
    c[19] = .{ 153, 76, 64 }; // brick
    c[20] = .{ 25, 13, 38 }; // obsidian
    c[21] = .{ 192, 76, 64 }; // tnt side
    c[22] = .{ 204, 192, 166 }; // tnt top
    c[23] = .{ 128, 90, 51 }; // bookshelf
    c[24] = .{ 90, 115, 76 }; // mossy cobblestone
    c[25] = .{ 166, 204, 242 }; // ice
    c[26] = .{ 230, 235, 242 }; // snow
    c[27] = .{ 166, 158, 148 }; // clay
    c[28] = .{ 51, 140, 38 }; // cactus side
    c[29] = .{ 64, 153, 51 }; // cactus top
    c[30] = .{ 204, 128, 25 }; // pumpkin side
    c[31] = .{ 178, 140, 38 }; // pumpkin top
    c[32] = .{ 102, 153, 51 }; // melon side
    c[33] = .{ 115, 140, 64 }; // melon top
    c[34] = .{ 217, 192, 102 }; // glowstone
    c[35] = .{ 115, 51, 51 }; // netherrack
    c[36] = .{ 90, 71, 56 }; // soul sand
    c[37] = .{ 192, 64, 51 }; // lava
    // Wool colors (96-111)
    c[96] = .{ 242, 242, 242 }; // white
    c[97] = .{ 230, 140, 38 }; // orange
    c[98] = .{ 192, 76, 178 }; // magenta
    c[99] = .{ 115, 166, 217 }; // light blue
    c[100] = .{ 230, 217, 64 }; // yellow
    c[101] = .{ 115, 192, 51 }; // lime
    c[102] = .{ 230, 140, 166 }; // pink
    c[103] = .{ 90, 90, 90 }; // gray
    c[104] = .{ 153, 153, 153 }; // light gray
    c[105] = .{ 51, 128, 140 }; // cyan
    c[106] = .{ 128, 64, 178 }; // purple
    c[107] = .{ 51, 64, 166 }; // blue
    c[108] = .{ 115, 76, 46 }; // brown
    c[109] = .{ 76, 102, 38 }; // green
    c[110] = .{ 166, 51, 46 }; // red
    c[111] = .{ 30, 30, 36 }; // black
    // Terracotta (112-115)
    c[112] = .{ 204, 192, 184 }; // white terracotta
    c[113] = .{ 178, 115, 64 }; // orange terracotta
    c[114] = .{ 166, 71, 64 }; // red terracotta
    c[115] = .{ 56, 38, 36 }; // black terracotta
    // Concrete (116-119)
    c[116] = .{ 242, 242, 242 };
    c[117] = .{ 230, 140, 25 };
    c[118] = .{ 166, 38, 38 };
    c[119] = .{ 20, 20, 25 };
    // Copper
    c[120] = .{ 192, 115, 71 };
    c[121] = .{ 166, 128, 90 };
    c[122] = .{ 115, 140, 115 };
    c[123] = .{ 76, 166, 140 };
    return c;
}

fn hash(x: u32, y: u32, seed: u32) u32 {
    var h = x *% 374761393 +% y *% 668265263 +% seed *% 1274126177;
    h = (h ^ (h >> 13)) *% 1103515245;
    return h ^ (h >> 16);
}

fn clampU8(v: i32) u8 {
    return @intCast(@max(0, @min(255, v)));
}

fn mixColor(base: Rgb, noise: i32) Pixel {
    return .{
        .r = clampU8(@as(i32, base[0]) + noise),
        .g = clampU8(@as(i32, base[1]) + noise),
        .b = clampU8(@as(i32, base[2]) + noise),
        .a = 255,
    };
}

fn px(r: u8, g: u8, b: u8) Pixel {
    return .{ .r = r, .g = g, .b = b, .a = 255 };
}

fn noise32(h: u32) i32 {
    return @as(i32, @intCast(h & 0x1F)) - 16;
}

fn noise16(h: u32) i32 {
    return @as(i32, @intCast(h & 0xF)) - 8;
}

pub fn generateTile(tex_index: u16) [TILE_SIZE * TILE_SIZE]Pixel {
    var pixels: [TILE_SIZE * TILE_SIZE]Pixel = undefined;
    const idx: u32 = tex_index;

    for (0..TILE_SIZE) |yi| {
        for (0..TILE_SIZE) |xi| {
            const x: u32 = @intCast(xi);
            const y: u32 = @intCast(yi);
            pixels[y * TILE_SIZE + x] = generatePixel(idx, x, y);
        }
    }
    return pixels;
}

fn generatePixel(idx: u32, x: u32, y: u32) Pixel {
    const h = hash(x, y, idx);
    const noise_i32: i32 = @as(i32, @intCast(h & 0x1F)) - 16;
    const fine_i32: i32 = @as(i32, @intCast(h & 0xF)) - 8;
    const base = if (idx < 256) base_colors[idx] else Rgb{ 128, 128, 128 };

    return switch (idx) {
        0 => genStone(x, y, h),
        1 => genDirt(x, y, h),
        2 => genGrassTop(x, y, h),
        3 => genGrassSide(x, y, h),
        4 => genCobblestone(x, y, h),
        5 => genPlanks(x, y, h),
        6 => genSand(x, y, h, base),
        7 => genGravel(x, y, h),
        8 => genLogSide(x, y, h),
        9 => genLogTop(x, y, h),
        10 => genLeaves(x, y, h),
        11 => genWater(x, y, h),
        12 => genBedrock(x, y, h),
        13 => genOre(x, y, h, base, Rgb{ 30, 30, 30 }),
        14 => genOre(x, y, h, base, Rgb{ 210, 180, 140 }),
        15 => genOre(x, y, h, base, Rgb{ 255, 220, 50 }),
        16 => genOre(x, y, h, base, Rgb{ 80, 220, 230 }),
        17 => genOre(x, y, h, base, Rgb{ 220, 50, 40 }),
        18 => genGlass(x, y),
        19 => genBrick(x, y, h),
        20 => genObsidian(x, y, h),
        25 => genIce(x, y, h),
        26 => genSnow(x, y, h),
        34 => genGlowstone(x, y, h),
        35 => genNetherrack(x, y, h),
        37 => genLava(x, y, h),
        96...111 => genWool(x, y, h, base),
        112...115 => genTerracotta(x, y, h, base),
        else => mixColor(base, if (fine_i32 > noise_i32) fine_i32 else noise_i32),
    };
}

fn genStone(_: u32, y: u32, h: u32) Pixel {
    const layer: i32 = @as(i32, @intCast((y + (h >> 8) % 3) % 4)) - 2;
    const n = noise32(h);
    const v = clampU8(128 + layer * 3 + n);
    return px(v, v, v);
}

fn genDirt(_: u32, _: u32, h: u32) Pixel {
    const n = noise32(h);
    if ((h >> 5) % 20 == 0) return px(60, 40, 20);
    if ((h >> 7) % 8 == 0) return px(170, 120, 70);
    return .{ .r = clampU8(140 + n), .g = clampU8(90 + n), .b = clampU8(50 + n), .a = 255 };
}

fn genGrassTop(_: u32, _: u32, h: u32) Pixel {
    const n = noise32(h);
    if ((h >> 5) % 30 == 0) return px(200, 200, 50);
    if ((h >> 7) % 12 == 0) return px(40, 100, 20);
    return .{ .r = clampU8(76 + n), .g = clampU8(166 + n), .b = clampU8(38 + @divTrunc(n, 2)), .a = 255 };
}

fn genGrassSide(_: u32, y: u32, h: u32) Pixel {
    const n = noise32(h);
    if (y < 3) {
        if (y == 2 and (h >> 5) % 3 == 0) return .{ .r = clampU8(115 + n), .g = clampU8(140 + n), .b = clampU8(64 + n), .a = 255 };
        return .{ .r = clampU8(76 + n), .g = clampU8(166 + n), .b = clampU8(38 + @divTrunc(n, 2)), .a = 255 };
    }
    return .{ .r = clampU8(140 + n), .g = clampU8(90 + n), .b = clampU8(50 + n), .a = 255 };
}

fn genCobblestone(x: u32, y: u32, h: u32) Pixel {
    const sx = (x +% (h >> 10) % 2) % 5;
    const sy = (y +% (h >> 12) % 2) % 5;
    if (sx == 0 or sy == 0) return px(60, 60, 60);
    const n = noise32(h);
    const shade: i32 = @as(i32, @intCast((h >> 6) % 30)) - 15;
    const v = clampU8(110 + n + shade);
    return px(v, v, clampU8(@as(i32, v) - 5));
}

fn genPlanks(_: u32, y: u32, h: u32) Pixel {
    const band = (y +% (h >> 8) % 2) % 7;
    const n = noise16(h);
    if (band < 3) return .{ .r = clampU8(178 + n), .g = clampU8(140 + n), .b = clampU8(76 + n), .a = 255 };
    if (band == 3) return .{ .r = clampU8(150 + n), .g = clampU8(110 + n), .b = clampU8(55 + n), .a = 255 };
    return .{ .r = clampU8(190 + n), .g = clampU8(150 + n), .b = clampU8(85 + n), .a = 255 };
}

fn genSand(_: u32, _: u32, h: u32, base: Rgb) Pixel {
    const n = noise16(h);
    if ((h >> 5) % 15 == 0) return px(clampU8(@as(i32, base[0]) + 20), clampU8(@as(i32, base[1]) + 15), clampU8(@as(i32, base[2]) + 5));
    return mixColor(base, n);
}

fn genGravel(_: u32, _: u32, h: u32) Pixel {
    return switch ((h >> 4) % 5) {
        0 => px(120, 115, 105),
        1 => px(150, 142, 130),
        2 => px(100, 90, 80),
        3 => px(160, 155, 145),
        else => px(130, 125, 110),
    };
}

fn genLogSide(x: u32, _: u32, h: u32) Pixel {
    const groove = (x +% (h >> 8) % 2) % 4;
    const n = noise16(h);
    if (groove == 0) return .{ .r = clampU8(65 + n), .g = clampU8(45 + n), .b = clampU8(20 + n), .a = 255 };
    return .{ .r = clampU8(102 + n), .g = clampU8(76 + n), .b = clampU8(38 + n), .a = 255 };
}

fn genLogTop(x: u32, y: u32, h: u32) Pixel {
    const dx = @as(i32, @intCast(x)) - 7;
    const dy = @as(i32, @intCast(y)) - 7;
    const dist: u32 = @intCast(@abs(dx) + @abs(dy));
    const ring = dist % 4;
    const n = noise16(h);
    if (ring < 2) return .{ .r = clampU8(140 + n), .g = clampU8(115 + n), .b = clampU8(64 + n), .a = 255 };
    return .{ .r = clampU8(120 + n), .g = clampU8(95 + n), .b = clampU8(50 + n), .a = 255 };
}

fn genLeaves(_: u32, _: u32, h: u32) Pixel {
    if ((h >> 3) % 6 == 0) return px(30, 80, 15);
    if ((h >> 5) % 8 == 0) return px(70, 180, 40);
    const n = noise32(h);
    return .{ .r = clampU8(51 + n), .g = clampU8(128 + n), .b = clampU8(25 + @divTrunc(n, 2)), .a = 255 };
}

fn genWater(_: u32, y: u32, h: u32) Pixel {
    const wave = (y + (h >> 8) % 3) % 6;
    const n = noise16(h);
    if (wave == 0) return px(clampU8(80 + n), clampU8(120 + n), clampU8(230 + n));
    return .{ .r = clampU8(51 + n), .g = clampU8(89 + n), .b = clampU8(204 + n), .a = 220 };
}

fn genBedrock(_: u32, _: u32, h: u32) Pixel {
    const n = noise32(h);
    if ((h >> 5) % 8 == 0) return px(30, 30, 30);
    return px(clampU8(64 + n), clampU8(64 + n), clampU8(64 + n));
}

fn genOre(_: u32, _: u32, h: u32, _: Rgb, ore_color: Rgb) Pixel {
    const cluster = (h >> 8) % 5;
    if (cluster == 0) {
        const on = noise16(h);
        return .{ .r = clampU8(@as(i32, ore_color[0]) + on), .g = clampU8(@as(i32, ore_color[1]) + on), .b = clampU8(@as(i32, ore_color[2]) + on), .a = 255 };
    }
    const n = noise32(h);
    const v = clampU8(128 + n);
    return px(v, v, v);
}

fn genGlass(x: u32, y: u32) Pixel {
    if (x == 0 or x == 15 or y == 0 or y == 15) return px(180, 190, 200);
    if (x == 1 or x == 14 or y == 1 or y == 14) return px(200, 210, 220);
    return px(220, 235, 245);
}

fn genBrick(x: u32, y: u32, h: u32) Pixel {
    const shifted_x = if (y % 8 < 4) x else (x + 8) % 16;
    if (shifted_x % 8 == 0 or y % 4 == 0) return px(160, 160, 155);
    const n = noise16(h);
    return .{ .r = clampU8(153 + n), .g = clampU8(76 + n), .b = clampU8(64 + n), .a = 255 };
}

fn genObsidian(_: u32, _: u32, h: u32) Pixel {
    const n = noise16(h);
    if ((h >> 5) % 10 == 0) return .{ .r = clampU8(40 + n), .g = clampU8(20 + n), .b = clampU8(60 + n), .a = 255 };
    return .{ .r = clampU8(25 + @divTrunc(n, 2)), .g = clampU8(13 + @divTrunc(n, 2)), .b = clampU8(38 + @divTrunc(n, 2)), .a = 255 };
}

fn genIce(_: u32, y: u32, h: u32) Pixel {
    const crack = (y + (h >> 6) % 4) % 8;
    const n = noise16(h);
    if (crack == 0) return .{ .r = clampU8(140 + n), .g = clampU8(180 + n), .b = clampU8(220 + n), .a = 255 };
    return .{ .r = clampU8(166 + n), .g = clampU8(204 + n), .b = clampU8(242 + n), .a = 230 };
}

fn genSnow(_: u32, _: u32, h: u32) Pixel {
    const n = noise16(h);
    return px(clampU8(230 + n), clampU8(235 + n), clampU8(242 + n));
}

fn genGlowstone(_: u32, _: u32, h: u32) Pixel {
    const n = noise32(h);
    if ((h >> 5) % 5 == 0) return px(255, 240, 150);
    return .{ .r = clampU8(217 + n), .g = clampU8(192 + n), .b = clampU8(102 + n), .a = 255 };
}

fn genNetherrack(_: u32, _: u32, h: u32) Pixel {
    const n = noise32(h);
    if ((h >> 5) % 7 == 0) return .{ .r = clampU8(80 + n), .g = clampU8(30 + n), .b = clampU8(30 + n), .a = 255 };
    return .{ .r = clampU8(115 + n), .g = clampU8(51 + n), .b = clampU8(51 + n), .a = 255 };
}

fn genLava(_: u32, y: u32, h: u32) Pixel {
    const flow = (y + (h >> 6) % 4) % 5;
    const n = noise16(h);
    if (flow == 0) return px(255, clampU8(180 + n), 50);
    if (flow == 1) return px(255, clampU8(120 + n), 30);
    return .{ .r = clampU8(192 + n), .g = clampU8(64 + n), .b = clampU8(51 + @divTrunc(n, 2)), .a = 255 };
}

fn genWool(_: u32, _: u32, h: u32, base: Rgb) Pixel {
    _ = h;
    return mixColor(base, 0);
}

fn genTerracotta(_: u32, y: u32, h: u32, base: Rgb) Pixel {
    const layer = (y + (h >> 8) % 3) % 6;
    const n: i32 = if (layer < 3) 8 else -8;
    return mixColor(base, n);
}

pub fn generateAtlas(allocator: std.mem.Allocator) ![]Pixel {
    const total_pixels = ATLAS_SIZE * ATLAS_SIZE;
    var pixels = try allocator.alloc(Pixel, total_pixels);

    for (0..TOTAL_TILES) |ti| {
        const tile = generateTile(@intCast(ti));
        const tile_col = ti % ATLAS_TILES_PER_ROW;
        const tile_row = ti / ATLAS_TILES_PER_ROW;
        const base_x = tile_col * TILE_SIZE;
        const base_y = tile_row * TILE_SIZE;

        for (0..TILE_SIZE) |py| {
            for (0..TILE_SIZE) |pxi| {
                const dst_x = base_x + pxi;
                const dst_y = base_y + py;
                pixels[dst_y * ATLAS_SIZE + dst_x] = tile[py * TILE_SIZE + pxi];
            }
        }
    }

    // Fill remaining pixels with magenta (debug — indicates missing tile)
    const filled = TOTAL_TILES * TILE_SIZE * TILE_SIZE;
    _ = filled;
    // Actually the atlas is 2D so we filled tiles in grid positions — remaining grid cells get magenta
    for (TOTAL_TILES..ATLAS_TILES_PER_ROW * ATLAS_TILES_PER_ROW) |ti| {
        const tile_col = ti % ATLAS_TILES_PER_ROW;
        const tile_row = ti / ATLAS_TILES_PER_ROW;
        const bx = tile_col * TILE_SIZE;
        const by = tile_row * TILE_SIZE;
        for (0..TILE_SIZE) |py| {
            for (0..TILE_SIZE) |pxi| {
                pixels[(by + py) * ATLAS_SIZE + (bx + pxi)] = px(255, 0, 255);
            }
        }
    }

    return pixels;
}

pub fn getUV(tex_index: u16, corner: u2) [2]f32 {
    const tiles_per_row: f32 = @floatFromInt(ATLAS_TILES_PER_ROW);
    const tx = tex_index % ATLAS_TILES_PER_ROW;
    const ty = tex_index / ATLAS_TILES_PER_ROW;
    const u_base: f32 = @as(f32, @floatFromInt(tx)) / tiles_per_row;
    const v_base: f32 = @as(f32, @floatFromInt(ty)) / tiles_per_row;
    const tile_uv: f32 = 1.0 / tiles_per_row;

    return switch (corner) {
        0 => .{ u_base, v_base + tile_uv },
        1 => .{ u_base + tile_uv, v_base + tile_uv },
        2 => .{ u_base + tile_uv, v_base },
        3 => .{ u_base, v_base },
    };
}

pub fn getTileColor(tex_index: u8) [3]f32 {
    const c = base_colors[tex_index];
    return .{ @as(f32, @floatFromInt(c[0])) / 255.0, @as(f32, @floatFromInt(c[1])) / 255.0, @as(f32, @floatFromInt(c[2])) / 255.0 };
}

test "atlas tile generation" {
    const tile = generateTile(0);
    try std.testing.expect(tile.len == TILE_SIZE * TILE_SIZE);
    try std.testing.expect(tile[0].a == 255);
}

test "atlas full generation" {
    const allocator = std.testing.allocator;
    const atlas = try generateAtlas(allocator);
    defer allocator.free(atlas);
    try std.testing.expectEqual(@as(usize, ATLAS_SIZE * ATLAS_SIZE), atlas.len);
    // First pixel should be stone-colored (grayish)
    try std.testing.expect(atlas[0].r > 80 and atlas[0].r < 180);
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
