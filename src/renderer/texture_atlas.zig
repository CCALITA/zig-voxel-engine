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
    c[45] = .{ 130, 130, 130 }; // furnace side
    c[46] = .{ 128, 128, 128 }; // furnace top
    c[51] = .{ 150, 105, 55 }; // chest side
    c[52] = .{ 150, 105, 55 }; // chest top
    c[54] = .{ 217, 210, 166 }; // end stone
    c[57] = .{ 200, 240, 255 }; // beacon
    c[58] = .{ 80, 80, 80 }; // brewing stand
    c[74] = .{ 30, 10, 40 }; // enchanting table top
    c[75] = .{ 25, 15, 35 }; // enchanting table side
    c[77] = .{ 102, 140, 76 }; // end portal frame side
    c[78] = .{ 90, 130, 70 }; // end portal frame top
    c[79] = .{ 5, 5, 10 }; // end portal
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
    // Crafting table
    c[124] = .{ 178, 140, 76 }; // top (planks-ish with grid)
    c[125] = .{ 178, 140, 76 }; // side (planks with tool silhouettes)
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
        21 => genTntSide(x, y, h),
        22 => genTntTop(x, y, h),
        23 => genBookshelf(x, y, h),
        24 => genMossyCobblestone(x, y, h),
        25 => genIce(x, y, h),
        26 => genSnow(x, y, h),
        27 => genClay(x, y, h),
        28 => genCactusSide(x, y, h),
        29 => genCactusTop(x, y, h),
        30 => genPumpkinSide(x, y, h),
        31 => genPumpkinTop(x, y, h),
        32 => genMelonSide(x, y, h),
        33 => genMelonTop(x, y, h),
        34 => genGlowstone(x, y, h),
        35 => genNetherrack(x, y, h),
        36 => genSoulSand(x, y, h),
        37 => genLava(x, y, h),
        38 => genRedstoneWire(x, y, h),
        39 => genRedstoneTorch(x, y, h),
        40 => genLever(x, y, h),
        41 => genButton(x, y, h),
        42 => genPistonSide(x, y, h),
        43 => genPistonTop(x, y, h),
        44 => genRepeater(x, y, h),
        45 => genFurnaceSide(x, y, h),
        46 => genFurnaceTop(x, y, h),
        47 => genDoor(x, y, h),
        48 => genBedHead(x, y, h),
        49 => genBedFoot(x, y, h),
        50 => genLadder(x, y, h),
        51 => genChestSide(x, y, h),
        52 => genChestTop(x, y, h),
        53 => genTrapdoor(x, y, h),
        54 => genEndStone(x, y, h),
        55 => genAnvilSide(x, y, h),
        56 => genAnvilTop(x, y, h),
        57 => genBeacon(x, y),
        58 => genBrewingStand(x, y, h),
        59 => genJukeboxSide(x, y, h),
        60 => genJukeboxTop(x, y, h),
        61 => genNoteBlock(x, y, h),
        62 => genPistonBaseSide(x, y, h),
        64, 71, 73 => genStone(x, y, h),
        65 => genStickyPistonTop(x, y, h),
        66 => genPistonHeadFace(x, y, h),
        67 => genPlanks(x, y, h),
        68 => genHopperSide(x, y, h),
        69 => genHopperTop(x, y, h),
        70 => genDropperFront(x, y, h),
        72 => genDispenserFront(x, y, h),
        74 => genEnchantingTableTop(x, y, h),
        75 => genEnchantingTableSide(x, y, h),
        76 => genEnchantingTableBottom(x, y, h),
        77 => genEndPortalFrameSide(x, y, h),
        78 => genEndPortalFrameTop(x, y, h),
        79 => genEndPortal(x, y, h),
        80 => genRail(x, y, h),
        81 => genPoweredRail(x, y, h),
        82 => genDetectorRail(x, y, h),
        83 => genActivatorRail(x, y, h),
        84 => genFarmlandTop(x, y, h),
        85 => genFarmlandSide(x, y, h),
        86 => genWheat(x, y, h),
        87 => genCarrots(x, y, h),
        88 => genPotatoes(x, y, h),
        89 => genMelonSide(x, y, h),
        90 => genMelonTop(x, y, h),
        91 => genJackOLanternFront(x, y, h),
        92 => genPumpkinSide(x, y, h),
        93 => genPumpkinTop(x, y, h),
        94 => genHayBaleSide(x, y, h),
        95 => genHayBaleTop(x, y, h),
        96...111 => genWool(x, y, h, base),
        112...115 => genTerracotta(x, y, h, base),
        116...119 => genConcrete(h, base),
        120 => genCopperBlock(x, y, h),
        121 => genExposedCopper(x, y, h),
        122 => genWeatheredCopper(x, y, h),
        123 => genOxidizedCopper(x, y, h),
        124 => genCraftingTableTop(x, y, h),
        125 => genCraftingTableSide(x, y, h),
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

fn genObsidian(x: u32, y: u32, h: u32) Pixel {
    const n = noise16(h);
    const streak = (x *% 3 +% y *% 5 +% (h >> 4) % 16) % 12;
    if (streak < 2) return .{ .r = clampU8(40 + n), .g = clampU8(20 + n), .b = clampU8(60 + n), .a = 255 };
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
    if ((h >> 7) % 40 == 0) return px(255, 255, 255);
    if ((h >> 5) % 25 == 0) return px(210, 215, 230);
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

// --- TNT (PR 260) ---

fn genTntSide(x: u32, y: u32, h: u32) Pixel {
    const n = noise16(h);
    // Red bands: top 3px and bottom 3px
    if (y < 3 or y > 12) return .{ .r = clampU8(192 + n), .g = clampU8(50 + @divTrunc(n, 2)), .b = clampU8(40 + @divTrunc(n, 2)), .a = 255 };
    // Dark fuse line at x=7-8
    if ((x == 7 or x == 8) and y >= 3 and y <= 5) return px(clampU8(40 + @divTrunc(n, 4)), clampU8(35 + @divTrunc(n, 4)), clampU8(30 + @divTrunc(n, 4)));
    // Brown/tan TNT label area y=6..9
    if (y >= 6 and y <= 9) return .{ .r = clampU8(160 + n), .g = clampU8(120 + n), .b = clampU8(70 + n), .a = 255 };
    // White center
    return .{ .r = clampU8(230 + @divTrunc(n, 2)), .g = clampU8(225 + @divTrunc(n, 2)), .b = clampU8(220 + @divTrunc(n, 2)), .a = 255 };
}

fn genTntTop(x: u32, y: u32, h: u32) Pixel {
    const n = noise16(h);
    const cx: i32 = @as(i32, @intCast(x)) - 7;
    const cy: i32 = @as(i32, @intCast(y)) - 7;
    const dist = @abs(cx) + @abs(cy);
    // Fuse hole at center (2px radius)
    if (dist <= 2) return px(clampU8(30 + @divTrunc(n, 4)), clampU8(25 + @divTrunc(n, 4)), clampU8(20 + @divTrunc(n, 4)));
    // Concentric square pattern
    const ring = @max(@abs(cx), @abs(cy));
    const shade: i32 = if (ring % 2 == 0) 10 else -10;
    return .{ .r = clampU8(160 + shade + n), .g = clampU8(150 + shade + n), .b = clampU8(135 + shade + n), .a = 255 };
}

fn genBookshelf(x: u32, y: u32, h: u32) Pixel {
    const n = noise16(h);
    // Wood frame: top/bottom 2px
    if (y < 2 or y > 13) return .{ .r = clampU8(140 + n), .g = clampU8(100 + n), .b = clampU8(50 + n), .a = 255 };
    // Shelf divider at y=8
    if (y == 8) return .{ .r = clampU8(100 + @divTrunc(n, 2)), .g = clampU8(70 + @divTrunc(n, 2)), .b = clampU8(35 + @divTrunc(n, 2)), .a = 255 };
    // Book spines: cycle through colors every 3-4px
    const book_idx = x / 3;
    const colors = [5]Rgb{ .{ 180, 50, 50 }, .{ 50, 60, 170 }, .{ 50, 140, 50 }, .{ 200, 180, 50 }, .{ 120, 80, 50 } };
    const c = colors[book_idx % 5];
    return .{ .r = clampU8(@as(i32, c[0]) + n), .g = clampU8(@as(i32, c[1]) + n), .b = clampU8(@as(i32, c[2]) + n), .a = 255 };
}

// --- Natural blocks (PR 259) ---

fn genMossyCobblestone(x: u32, y: u32, h: u32) Pixel {
    const sx = (x +% (h >> 10) % 2) % 5;
    const sy = (y +% (h >> 12) % 2) % 5;
    if (sx == 0 or sy == 0) {
        // Mortar line — ~30% chance of moss
        const moss_h = hash(x, y, 2400);
        if (moss_h % 10 < 3) {
            const n = noise16(h);
            return .{ .r = clampU8(50 + n), .g = clampU8(120 + n), .b = clampU8(40 + n), .a = 255 };
        }
        return px(60, 60, 60);
    }
    const n = noise32(h);
    const shade: i32 = @as(i32, @intCast((h >> 6) % 30)) - 15;
    const v = clampU8(110 + n + shade);
    return px(v, v, clampU8(@as(i32, v) - 5));
}

fn genClay(_: u32, y: u32, h: u32) Pixel {
    const n = noise16(h);
    const layer: i32 = if (y % 4 == 0) @as(i32, -5) else @as(i32, 0);
    return .{ .r = clampU8(166 + n + layer), .g = clampU8(158 + n + layer), .b = clampU8(148 + n + layer), .a = 255 };
}

fn genCactusSide(x: u32, _: u32, h: u32) Pixel {
    const n = noise16(h);
    if (x % 4 == 0) return .{ .r = clampU8(35 + n), .g = clampU8(100 + n), .b = clampU8(25 + n), .a = 255 };
    // Spine dots — ~8% chance
    if ((h >> 5) % 12 == 0) return .{ .r = clampU8(80 + n), .g = clampU8(190 + n), .b = clampU8(70 + n), .a = 255 };
    return .{ .r = clampU8(51 + n), .g = clampU8(140 + n), .b = clampU8(38 + n), .a = 255 };
}

fn genCactusTop(x: u32, y: u32, h: u32) Pixel {
    const n = noise16(h);
    const dx = @as(i32, @intCast(x)) - 7;
    const dy = @as(i32, @intCast(y)) - 7;
    // Cross/star shape: center cross is lighter
    if (@abs(dx) <= 2 or @abs(dy) <= 2) {
        return .{ .r = clampU8(80 + n), .g = clampU8(180 + n), .b = clampU8(65 + n), .a = 255 };
    }
    return .{ .r = clampU8(50 + n), .g = clampU8(130 + n), .b = clampU8(40 + n), .a = 255 };
}

fn genPumpkinSide(x: u32, _: u32, h: u32) Pixel {
    const n = noise16(h);
    if (x % 4 == 0) return .{ .r = clampU8(140 + n), .g = clampU8(80 + n), .b = clampU8(10 + n), .a = 255 };
    return .{ .r = clampU8(204 + n), .g = clampU8(128 + n), .b = clampU8(25 + n), .a = 255 };
}

fn genPumpkinTop(x: u32, y: u32, h: u32) Pixel {
    const n = noise16(h);
    // Brown stem centered top (x 6..9, y 0..3)
    if (x >= 6 and x <= 9 and y <= 3) {
        if (x == 6 or x == 9) {
            // Green vine hint on sides of stem
            return .{ .r = clampU8(50 + n), .g = clampU8(120 + n), .b = clampU8(30 + n), .a = 255 };
        }
        return .{ .r = clampU8(100 + n), .g = clampU8(70 + n), .b = clampU8(20 + n), .a = 255 };
    }
    return .{ .r = clampU8(178 + n), .g = clampU8(140 + n), .b = clampU8(38 + n), .a = 255 };
}

fn genMelonSide(x: u32, _: u32, h: u32) Pixel {
    const n = noise16(h);
    if (x == 0 or x == 15) return .{ .r = clampU8(60 + n), .g = clampU8(100 + n), .b = clampU8(30 + n), .a = 255 };
    if (x % 3 == 0) return .{ .r = clampU8(120 + n), .g = clampU8(180 + n), .b = clampU8(70 + n), .a = 255 };
    return .{ .r = clampU8(102 + n), .g = clampU8(153 + n), .b = clampU8(51 + n), .a = 255 };
}

fn genMelonTop(x: u32, y: u32, h: u32) Pixel {
    const n = noise16(h);
    const dx = @as(i32, @intCast(x)) - 7;
    const dy = @as(i32, @intCast(y)) - 7;
    // Brown center spot (3x3)
    if (@abs(dx) <= 1 and @abs(dy) <= 1) return .{ .r = clampU8(115 + n), .g = clampU8(80 + n), .b = clampU8(30 + n), .a = 255 };
    // Radial lighter stripes
    const dist: u32 = @intCast(@abs(dx) + @abs(dy));
    if (dist % 3 == 0) return .{ .r = clampU8(130 + n), .g = clampU8(170 + n), .b = clampU8(75 + n), .a = 255 };
    return .{ .r = clampU8(115 + n), .g = clampU8(140 + n), .b = clampU8(64 + n), .a = 255 };
}

// --- Soul sand, End, Enchanting, Portal (PR 258) ---

fn genSoulSand(x: u32, y: u32, h: u32) Pixel {
    const n = noise16(h);
    // Face-like dark hollows: 2-3 circular spots
    const spots = [_][2]i32{ .{ 4, 6 }, .{ 11, 5 }, .{ 7, 12 } };
    for (spots) |s| {
        const dx = @as(i32, @intCast(x)) - s[0];
        const dy = @as(i32, @intCast(y)) - s[1];
        if (dx * dx + dy * dy < 16) return px(40, 30, 25);
    }
    return .{ .r = clampU8(90 + n), .g = clampU8(71 + n), .b = clampU8(56 + n), .a = 255 };
}

// --- Redstone & Rails (PR 261) ---

fn stoneBase(h: u32) Pixel {
    const sn = noise32(h);
    const sv = clampU8(128 + sn);
    return px(sv, sv, sv);
}

fn ironRail(n: i32) Pixel {
    return px(clampU8(80 + n), clampU8(80 + n), clampU8(85 + n));
}

fn railTie(x: u32, y: u32, n: i32) ?Pixel {
    const is_tie_row = (y >= 2 and y <= 3) or (y >= 5 and y <= 6) or (y >= 8 and y <= 9) or (y >= 11 and y <= 12) or (y >= 14 and y <= 15);
    if (is_tie_row and x >= 2 and x <= 13) {
        return px(clampU8(130 + n), clampU8(90 + n), clampU8(50 + n));
    }
    return null;
}

fn railGravel(h: u32) Pixel {
    const sn = noise32(h);
    return px(clampU8(110 + sn), clampU8(105 + sn), clampU8(95 + sn));
}

fn genRedstoneWire(x: u32, y: u32, h: u32) Pixel {
    const n = noise16(h);
    if ((x == 7 or x == 8) or (y == 7 or y == 8)) {
        return px(clampU8(200 + n), clampU8(20 + @divTrunc(n, 2)), clampU8(20 + @divTrunc(n, 2)));
    }
    // Red glow near the cross
    if ((x >= 6 and x <= 9) or (y >= 6 and y <= 9)) {
        const v = clampU8(128 + n);
        return px(clampU8(@as(i32, v) + 30), v, v);
    }
    return stoneBase(h);
}

fn genRedstoneTorch(x: u32, y: u32, h: u32) Pixel {
    const n = noise16(h);
    if (y <= 3 and x >= 6 and x <= 9) {
        if (y <= 1) return px(255, clampU8(200 + n), clampU8(60 + n));
        return px(clampU8(220 + n), clampU8(50 + n), clampU8(20 + n));
    }
    if ((x == 7 or x == 8) and y >= 4 and y <= 10) {
        return px(clampU8(100 + n), clampU8(70 + n), clampU8(35 + n));
    }
    return stoneBase(h);
}

fn genLever(x: u32, y: u32, h: u32) Pixel {
    const n = noise16(h);
    if (y == 10 and (x == 7 or x == 8)) {
        return px(clampU8(180 + n), clampU8(180 + n), clampU8(190 + n));
    }
    // Diagonal lever arm: 2px wide line from bottom-left to upper-right
    if (y >= 4 and y <= 14) {
        const target_x: i32 = @as(i32, 14) - @as(i32, @intCast(y)) + 1;
        const dx = @as(i32, @intCast(x)) - target_x;
        if (dx >= 0 and dx <= 1) {
            return px(clampU8(120 + n), clampU8(85 + n), clampU8(45 + n));
        }
    }
    return stoneBase(h);
}

fn genButton(x: u32, y: u32, h: u32) Pixel {
    const n = noise16(h);
    if (x >= 5 and x <= 10 and y >= 5 and y <= 8) {
        if (y == 8) return px(clampU8(110 + n), clampU8(110 + n), clampU8(110 + n));
        return px(clampU8(170 + n), clampU8(170 + n), clampU8(170 + n));
    }
    return stoneBase(h);
}

// --- Mechanical blocks (piston, anvil, hopper, dropper, dispenser) ---

fn darkIron(n: i32) Pixel {
    return .{ .r = clampU8(50 + n), .g = clampU8(50 + n), .b = clampU8(55 + n), .a = 255 };
}

fn lightIron(n: i32) Pixel {
    return px(clampU8(80 + n), clampU8(80 + n), clampU8(85 + n));
}

fn ironBand(n: i32) Pixel {
    return .{ .r = clampU8(140 + n), .g = clampU8(140 + n), .b = clampU8(150 + n), .a = 255 };
}

fn genPistonSide(x: u32, y: u32, h: u32) Pixel {
    if (y >= 6 and y <= 9) {
        if ((x <= 1 or x >= 14) and (y == 6 or y == 9)) return px(80, 80, 85);
        return ironBand(noise16(h));
    }
    return genStone(x, y, h);
}

fn genPistonTop(x: u32, y: u32, h: u32) Pixel {
    const n = noise16(h);
    const dx = @as(i32, @intCast(x)) - 7;
    const dy = @as(i32, @intCast(y)) - 7;
    if (@abs(dx) <= 1 and @abs(dy) <= 1) return ironBand(n);
    const band = (y +% (h >> 8) % 2) % 7;
    if (band < 3) return .{ .r = clampU8(170 + n), .g = clampU8(132 + n), .b = clampU8(70 + n), .a = 255 };
    if (band == 3) return .{ .r = clampU8(142 + n), .g = clampU8(104 + n), .b = clampU8(50 + n), .a = 255 };
    return .{ .r = clampU8(182 + n), .g = clampU8(142 + n), .b = clampU8(80 + n), .a = 255 };
}

fn genRepeater(x: u32, y: u32, h: u32) Pixel {
    const n = noise16(h);
    // Torch dots at (4,6) and (11,6)
    if (y == 6 and (x == 4 or x == 11)) {
        return px(clampU8(220 + n), clampU8(30 + @divTrunc(n, 2)), clampU8(30 + @divTrunc(n, 2)));
    }
    // Redstone line connecting torches
    if (y == 6 and x >= 4 and x <= 11) {
        return px(clampU8(120 + n), clampU8(15 + @divTrunc(n, 4)), clampU8(15 + @divTrunc(n, 4)));
    }
    const sv = clampU8(140 + n);
    return px(sv, sv, clampU8(@as(i32, sv) - 5));
}

// --- Furnace, Chest (PR 260) ---

fn genFurnaceSide(x: u32, y: u32, h: u32) Pixel {
    const n = noise16(h);
    // Dark front opening: 6x4px rectangle centered in lower half (x=5..10, y=9..12)
    if (x >= 5 and x <= 10 and y >= 9 and y <= 12) return px(clampU8(30 + @divTrunc(n, 4)), clampU8(28 + @divTrunc(n, 4)), clampU8(25 + @divTrunc(n, 4)));
    // Stone bricks frame pattern
    const bx = x % 8;
    const by = y % 4;
    if (bx == 0 or by == 0) return .{ .r = clampU8(100 + n), .g = clampU8(100 + n), .b = clampU8(100 + n), .a = 255 };
    return .{ .r = clampU8(130 + n), .g = clampU8(130 + n), .b = clampU8(130 + n), .a = 255 };
}

fn genFurnaceTop(x: u32, y: u32, h: u32) Pixel {
    const n = noise16(h);
    // Cross-shaped tool marks at center
    if ((x == 7 or x == 8) and y >= 3 and y <= 12) return .{ .r = clampU8(110 + n), .g = clampU8(110 + n), .b = clampU8(110 + n), .a = 255 };
    if ((y == 7 or y == 8) and x >= 3 and x <= 12) return .{ .r = clampU8(110 + n), .g = clampU8(110 + n), .b = clampU8(110 + n), .a = 255 };
    // Stone background
    return .{ .r = clampU8(128 + n), .g = clampU8(128 + n), .b = clampU8(128 + n), .a = 255 };
}

// --- Door, Ladder, Trapdoor (PR 262) ---

fn genDoor(x: u32, y: u32, h: u32) Pixel {
    const n = noise16(h);
    if (x == 12 and y == 7) return px(200, 180, 50);
    if (y >= 1 and y <= 6 and x >= 2 and x <= 13) {
        if (x == 2 or x == 13 or y == 1 or y == 6)
            return px(clampU8(100 + n), clampU8(70 + n), clampU8(35 + n));
        return px(clampU8(120 + n), clampU8(85 + n), clampU8(45 + n));
    }
    if (y >= 9 and y <= 14 and x >= 2 and x <= 13) {
        if (x == 2 or x == 13 or y == 9 or y == 14)
            return px(clampU8(100 + n), clampU8(70 + n), clampU8(35 + n));
        return px(clampU8(120 + n), clampU8(85 + n), clampU8(45 + n));
    }
    return px(clampU8(160 + n), clampU8(120 + n), clampU8(65 + n));
}

// --- Bed (PR 257) ---

fn genBedHead(_: u32, y: u32, h: u32) Pixel {
    const n = noise16(h);
    if (y == 15) return px(clampU8(80 + n), clampU8(50 + n), clampU8(30 + n));
    if (y < 3) return px(clampU8(200 + n), clampU8(180 + n), clampU8(170 + n));
    if (y == 5 or y == 10) return px(clampU8(150 + n), clampU8(35 + n), clampU8(35 + n));
    return px(clampU8(180 + n), clampU8(50 + n), clampU8(50 + n));
}

fn genBedFoot(_: u32, y: u32, h: u32) Pixel {
    const n = noise16(h);
    if (y == 15) return px(clampU8(80 + n), clampU8(50 + n), clampU8(30 + n));
    if (y == 4 or y == 11) return px(clampU8(145 + n), clampU8(32 + n), clampU8(32 + n));
    return px(clampU8(170 + n), clampU8(45 + n), clampU8(45 + n));
}

fn genLadder(x: u32, y: u32, h: u32) Pixel {
    const n = noise16(h);
    // Vertical rails
    if (x == 2 or x == 13)
        return px(clampU8(140 + n), clampU8(100 + n), clampU8(50 + n));
    // Horizontal rungs (2px high at y=2-3, 6-7, 10-11, 14-15)
    if ((y >= 2 and y <= 3) or (y >= 6 and y <= 7) or (y >= 10 and y <= 11) or (y >= 14 and y <= 15)) {
        if (x >= 2 and x <= 13)
            return px(clampU8(140 + n), clampU8(100 + n), clampU8(50 + n));
    }
    return .{ .r = 0, .g = 0, .b = 0, .a = 0 };
}

// --- Chest (PR 260) ---

fn genChestSide(x: u32, y: u32, h: u32) Pixel {
    const n = noise16(h);
    // Lock plate: 3x2px centered at y=7 (x=6..8, y=6..7)
    if (x >= 6 and x <= 8 and (y == 6 or y == 7)) {
        // Golden latch dot at center of lock
        if (x == 7 and y == 7) return px(clampU8(220 + @divTrunc(n, 4)), clampU8(190 + @divTrunc(n, 4)), clampU8(50 + @divTrunc(n, 4)));
        return px(clampU8(50 + @divTrunc(n, 4)), clampU8(45 + @divTrunc(n, 4)), clampU8(40 + @divTrunc(n, 4)));
    }
    // Brown planks with horizontal grain
    const band = y % 4;
    if (band == 0) return .{ .r = clampU8(130 + n), .g = clampU8(90 + n), .b = clampU8(45 + n), .a = 255 };
    return .{ .r = clampU8(150 + n), .g = clampU8(105 + n), .b = clampU8(55 + n), .a = 255 };
}

fn genChestTop(x: u32, y: u32, h: u32) Pixel {
    const n = noise16(h);
    // Darker trim at edges
    if (x == 0 or x == 15 or y == 0 or y == 15) return .{ .r = clampU8(110 + n), .g = clampU8(75 + n), .b = clampU8(35 + n), .a = 255 };
    // Horizontal clasp line at y=8
    if (y == 8) return .{ .r = clampU8(100 + @divTrunc(n, 2)), .g = clampU8(70 + @divTrunc(n, 2)), .b = clampU8(30 + @divTrunc(n, 2)), .a = 255 };
    // Brown planks
    return .{ .r = clampU8(150 + n), .g = clampU8(105 + n), .b = clampU8(55 + n), .a = 255 };
}

fn genTrapdoor(x: u32, y: u32, h: u32) Pixel {
    const n = noise16(h);
    // Iron hinge marks at corners
    if ((x <= 1 and y <= 1) or (x >= 14 and y <= 1) or (x <= 1 and y >= 14) or (x >= 14 and y >= 14))
        return px(clampU8(80 + n), clampU8(80 + n), clampU8(80 + n));
    // Cross brace diagonals
    if (x == y or x == 15 - y)
        return px(clampU8(110 + n), clampU8(75 + n), clampU8(35 + n));
    // Horizontal grain planks
    const band = (y +% (h >> 8) % 2) % 5;
    if (band == 0) return px(clampU8(130 + n), clampU8(90 + n), clampU8(45 + n));
    return px(clampU8(150 + n), clampU8(110 + n), clampU8(55 + n));
}

// --- End Stone, Beacon, Brewing, Enchanting, Portal (PR 258) ---

fn genEndStone(_: u32, _: u32, h: u32) Pixel {
    const n = noise16(h);
    if ((h >> 5) % 6 == 0) return .{ .r = clampU8(180 + n), .g = clampU8(170 + n), .b = clampU8(130 + n), .a = 255 };
    return .{ .r = clampU8(217 + n), .g = clampU8(210 + n), .b = clampU8(166 + n), .a = 255 };
}

fn genAnvilSide(_: u32, _: u32, h: u32) Pixel {
    const n = noise16(h);
    if ((h >> 5) % 12 == 0) return lightIron(n);
    return darkIron(n);
}

fn genAnvilTop(x: u32, y: u32, h: u32) Pixel {
    const cx = @as(i32, @intCast(x)) - 7;
    const half_width: i32 = if (y < 4) 7 else if (y < 6) 3 else if (y < 10) 4 else 6;
    if (@abs(cx) > half_width) return px(20, 20, 22);
    return darkIron(noise16(h));
}

fn genBeacon(x: u32, y: u32) Pixel {
    const dx = @as(i32, @intCast(x)) - 7;
    const dy = @as(i32, @intCast(y)) - 7;
    const dist_sq: u32 = @intCast(dx * dx + dy * dy);
    if (dist_sq < 16) return px(255, 255, 255);
    if (dist_sq < 36) return px(200, 240, 255);
    return .{ .r = 150, .g = 210, .b = 230, .a = 180 };
}

fn genBrewingStand(x: u32, y: u32, h: u32) Pixel {
    const n = noise16(h);
    // Stone base at bottom
    if (y >= 12) return px(clampU8(80 + n), clampU8(80 + n), clampU8(80 + n));
    // Bottle silhouette in center
    if (x >= 6 and x <= 9 and y >= 3 and y <= 11) return px(clampU8(160 + n), clampU8(140 + n), clampU8(120 + n));
    // Bottle bulb
    if (x >= 5 and x <= 10 and y >= 7 and y <= 10) return px(clampU8(150 + n), clampU8(130 + n), clampU8(110 + n));
    return px(clampU8(50 + n), clampU8(50 + n), clampU8(50 + n));
}

// --- Jukebox, Note Block (PR 257) ---

fn genJukeboxSide(x: u32, y: u32, h: u32) Pixel {
    const n = noise16(h);
    if (y == 0 or y == 15) return px(clampU8(100 + n), clampU8(65 + n), clampU8(30 + n));
    if (x == 0 or x == 5 or x == 10 or x == 15) return px(clampU8(95 + n), clampU8(60 + n), clampU8(28 + n));
    return px(clampU8(128 + n), clampU8(90 + n), clampU8(51 + n));
}

fn genJukeboxTop(x: u32, y: u32, h: u32) Pixel {
    const n = noise16(h);
    const dx = @as(i32, @intCast(x)) - 7;
    const dy = @as(i32, @intCast(y)) - 7;
    const dist_sq = dx * dx + dy * dy;
    if (dist_sq <= 9) return px(clampU8(30 + n), clampU8(30 + n), clampU8(30 + n));
    if (dist_sq <= 20) return px(clampU8(155 + n), clampU8(115 + n), clampU8(70 + n));
    return px(clampU8(128 + n), clampU8(90 + n), clampU8(51 + n));
}

fn genNoteBlock(x: u32, y: u32, h: u32) Pixel {
    const n = noise16(h);
    // Note head: oval at y=7, x=6-8
    if (y >= 6 and y <= 8 and x >= 6 and x <= 8) return px(clampU8(160 + n), clampU8(120 + n), clampU8(75 + n));
    // Note stem: vertical line at x=9, y=3-7
    if (x == 9 and y >= 3 and y <= 7) return px(clampU8(160 + n), clampU8(120 + n), clampU8(75 + n));
    // Panel lines like jukebox side
    if (x == 0 or x == 5 or x == 10 or x == 15) return px(clampU8(95 + n), clampU8(60 + n), clampU8(28 + n));
    return px(clampU8(128 + n), clampU8(90 + n), clampU8(51 + n));
}

fn genPistonBaseSide(x: u32, y: u32, h: u32) Pixel {
    if (y == 7) return ironBand(noise16(h));
    return genStone(x, y, h);
}

fn genStickyPistonTop(x: u32, y: u32, h: u32) Pixel {
    if (x >= 4 and x <= 11 and y >= 4 and y <= 11) {
        const n = noise16(h);
        return .{ .r = clampU8(80 + n), .g = clampU8(200 + n), .b = clampU8(60 + n), .a = 255 };
    }
    return genPistonTop(x, y, h);
}

fn genPistonHeadFace(x: u32, y: u32, h: u32) Pixel {
    const n = noise16(h);
    const dx = @as(i32, @intCast(x)) - 7;
    const dy = @as(i32, @intCast(y)) - 7;
    if (dx * dx + dy * dy <= 4) return px(clampU8(90 + n), clampU8(90 + n), clampU8(95 + n));
    return genPlanks(x, y, h);
}

fn genHopperSide(x: u32, y: u32, h: u32) Pixel {
    const n = noise16(h);
    const cx = @as(i32, @intCast(x)) - 7;
    if (y < 6) {
        if (x == 0 or x == 15) return lightIron(n);
        return darkIron(n);
    }
    const half_width: i32 = 7 - @as(i32, @intCast(y - 6));
    if (@abs(cx) > half_width) return px(20, 20, 22);
    if (@abs(cx) == half_width) return lightIron(n);
    return darkIron(n);
}

fn genHopperTop(x: u32, y: u32, h: u32) Pixel {
    const n = noise16(h);
    const dx = @as(i32, @intCast(x)) - 7;
    const dy = @as(i32, @intCast(y)) - 7;
    const dist_sq = dx * dx + dy * dy;
    if (dist_sq <= 9) return px(20, 20, 22);
    if (dist_sq <= 20) return darkIron(n);
    return lightIron(n);
}

fn genDropperFront(x: u32, y: u32, h: u32) Pixel {
    if (y >= 6 and y <= 10 and x >= 5 and x <= 10) {
        if (y == 6 or y == 10 or x == 5 or x == 10) return px(60, 60, 65);
        return px(30, 30, 35);
    }
    return genStone(x, y, h);
}

fn genDispenserFront(x: u32, y: u32, h: u32) Pixel {
    if (y >= 6 and y <= 10 and x >= 5 and x <= 10) {
        if (y == 6 or y == 10 or x == 5 or x == 10) return px(60, 60, 65);
        return px(25, 25, 30);
    }
    return genStone(x, y, h);
}

// --- Enchanting, Portal Frame (PR 258) ---

fn genEnchantingTableTop(x: u32, y: u32, h: u32) Pixel {
    const n = noise16(h);
    // Glowing symbol lines
    if (y == 4 and x >= 3 and x <= 12) return px(200, 50, 220);
    if (y == 11 and x >= 3 and x <= 12) return px(200, 50, 220);
    if (x == y and x >= 2 and x <= 13) return px(180, 40, 200);
    if (x + y == 15 and x >= 2 and x <= 13) return px(180, 40, 200);
    return .{ .r = clampU8(30 + @divTrunc(n, 2)), .g = clampU8(10 + @divTrunc(n, 2)), .b = clampU8(40 + @divTrunc(n, 2)), .a = 255 };
}

fn genEnchantingTableSide(_: u32, y: u32, h: u32) Pixel {
    const n = noise16(h);
    if (y == 0 or y == 15) return px(200, 170, 50);
    return .{ .r = clampU8(25 + @divTrunc(n, 2)), .g = clampU8(15 + @divTrunc(n, 2)), .b = clampU8(35 + @divTrunc(n, 2)), .a = 255 };
}

fn genEnchantingTableBottom(x: u32, _: u32, h: u32) Pixel {
    const n = noise16(h);
    if (x % 6 == 0) return .{ .r = clampU8(30 + n), .g = clampU8(12 + @divTrunc(n, 2)), .b = clampU8(45 + n), .a = 255 };
    return .{ .r = clampU8(20 + @divTrunc(n, 2)), .g = clampU8(10 + @divTrunc(n, 2)), .b = clampU8(30 + @divTrunc(n, 2)), .a = 255 };
}

fn genEndPortalFrameSide(x: u32, y: u32, h: u32) Pixel {
    const n = noise16(h);
    // Eye socket: dark circle at center with green iris
    const dx = @as(i32, @intCast(x)) - 7;
    const dy = @as(i32, @intCast(y)) - 7;
    const dist_sq: u32 = @intCast(dx * dx + dy * dy);
    if (dist_sq < 4) return px(50, 200, 50);
    if (dist_sq < 16) return px(20, 20, 20);
    return .{ .r = clampU8(102 + n), .g = clampU8(140 + n), .b = clampU8(76 + n), .a = 255 };
}

fn genEndPortalFrameTop(x: u32, y: u32, h: u32) Pixel {
    const n = noise16(h);
    // Darker border, lighter center
    if (x <= 2 or x >= 13 or y <= 2 or y >= 13) return .{ .r = clampU8(60 + n), .g = clampU8(90 + n), .b = clampU8(50 + n), .a = 255 };
    if (x <= 4 or x >= 11 or y <= 4 or y >= 11) return .{ .r = clampU8(80 + n), .g = clampU8(120 + n), .b = clampU8(65 + n), .a = 255 };
    return .{ .r = clampU8(120 + n), .g = clampU8(170 + n), .b = clampU8(100 + n), .a = 255 };
}

fn genEndPortal(_: u32, _: u32, h: u32) Pixel {
    // Scattered star dots at ~5% density
    if ((h >> 3) % 20 == 0) {
        return switch ((h >> 7) % 3) {
            0 => px(100, 220, 255),
            1 => px(180, 100, 255),
            else => px(240, 240, 255),
        };
    }
    return px(5, 5, 10);
}

// --- Rails (PR 261) ---

fn genRail(x: u32, y: u32, h: u32) Pixel {
    const n = noise16(h);
    if (x == 3 or x == 12) return ironRail(n);
    if (railTie(x, y, n)) |tie| return tie;
    return railGravel(h);
}

fn genPoweredRail(x: u32, y: u32, h: u32) Pixel {
    const n = noise16(h);
    if (x == 3 or x == 12) return px(clampU8(200 + n), clampU8(170 + n), clampU8(50 + n));
    if (x == 7 or x == 8) return px(clampU8(200 + n), clampU8(20 + @divTrunc(n, 2)), clampU8(20 + @divTrunc(n, 2)));
    if (railTie(x, y, n)) |tie| return tie;
    return railGravel(h);
}

fn genDetectorRail(x: u32, y: u32, h: u32) Pixel {
    const n = noise16(h);
    if (x == 3 or x == 12) return ironRail(n);
    if (x >= 4 and x <= 11 and (y == 7 or y == 8)) {
        return px(clampU8(160 + n), clampU8(30 + @divTrunc(n, 2)), clampU8(30 + @divTrunc(n, 2)));
    }
    if (railTie(x, y, n)) |tie| return tie;
    return railGravel(h);
}

fn genActivatorRail(x: u32, y: u32, h: u32) Pixel {
    const n = noise16(h);
    if (x == 3 or x == 12) return ironRail(n);
    if (x == 7 or x == 8) return px(clampU8(220 + n), clampU8(30 + @divTrunc(n, 2)), clampU8(30 + @divTrunc(n, 2)));
    if (railTie(x, y, n)) |tie| return tie;
    return railGravel(h);
}

// --- Farming & Crops (PR 262) ---

fn genFarmlandTop(x: u32, _: u32, h: u32) Pixel {
    const n = noise16(h);
    // Furrow lines
    if (x == 0 or x == 4 or x == 8 or x == 12)
        return px(clampU8(70 + n), clampU8(45 + n), clampU8(15 + n));
    // Moist spots
    if ((h >> 5) % 8 == 0)
        return px(clampU8(75 + n), clampU8(48 + n), clampU8(18 + n));
    return px(clampU8(100 + n), clampU8(65 + n), clampU8(30 + n));
}

fn genFarmlandSide(_: u32, y: u32, h: u32) Pixel {
    const n = noise16(h);
    // Dark top stripe
    if (y <= 1) return px(clampU8(85 + n), clampU8(55 + n), clampU8(25 + n));
    // Dirt body
    return px(clampU8(140 + n), clampU8(90 + n), clampU8(50 + n));
}

fn genWheat(x: u32, y: u32, h: u32) Pixel {
    const n = noise16(h);
    const is_stalk = (x == 2 or x == 5 or x == 8 or x == 11 or x == 14);
    if (y >= 13 and is_stalk)
        return px(clampU8(60 + n), clampU8(120 + n), clampU8(30 + n));
    if (y <= 2 and is_stalk)
        return px(clampU8(200 + n), clampU8(180 + n), clampU8(50 + n));
    if (y <= 2) {
        if (x == 1 or x == 3 or x == 4 or x == 6 or x == 7 or x == 9 or x == 10 or x == 12 or x == 13)
            return px(clampU8(190 + n), clampU8(170 + n), clampU8(45 + n));
    }
    if (is_stalk)
        return px(clampU8(200 + n), clampU8(180 + n), clampU8(50 + n));
    return .{ .r = 0, .g = 0, .b = 0, .a = 0 };
}

fn genCropPlant(x: u32, y: u32, h: u32, tuber_color: Rgb) Pixel {
    const n = noise16(h);
    const is_stem = (x == 3 or x == 7 or x == 11);
    if (is_stem and y <= 12)
        return px(clampU8(50 + n), clampU8(130 + n), clampU8(30 + n));
    if (y <= 3 and (x == 2 or x == 4 or x == 6 or x == 8 or x == 10 or x == 12))
        return px(clampU8(40 + n), clampU8(110 + n), clampU8(25 + n));
    if (y >= 14 and (x == 4 or x == 5 or x == 8 or x == 9 or x == 12 or x == 13))
        return px(clampU8(@as(i32, tuber_color[0]) + n), clampU8(@as(i32, tuber_color[1]) + n), clampU8(@as(i32, tuber_color[2]) + n));
    return .{ .r = 0, .g = 0, .b = 0, .a = 0 };
}

fn genCarrots(x: u32, y: u32, h: u32) Pixel {
    return genCropPlant(x, y, h, Rgb{ 230, 130, 30 });
}

fn genPotatoes(x: u32, y: u32, h: u32) Pixel {
    return genCropPlant(x, y, h, Rgb{ 160, 120, 60 });
}

// --- Jack-o-Lantern (PR 262) ---

fn genJackOLanternFront(x: u32, y: u32, h: u32) Pixel {
    const glow = px(255, 200, 50);
    // Triangle left eye: y=4-7, widening downward from x=4
    if (y >= 4 and y <= 7 and x >= 3 and x <= 5) {
        const ey = y - 4;
        const center: u32 = 4;
        const half_w = ey;
        if (x >= center - @min(half_w, center) and x <= center + half_w)
            return glow;
    }
    // Triangle right eye: y=4-7, widening downward from x=11
    if (y >= 4 and y <= 7 and x >= 10 and x <= 12) {
        const ey = y - 4;
        const center: u32 = 11;
        const half_w = ey;
        if (x >= center - @min(half_w, center) and x <= center + half_w)
            return glow;
    }
    // Jagged mouth with triangle teeth
    if (y >= 9 and y <= 12 and x >= 3 and x <= 12) {
        const is_tooth = (y <= 10) and ((x == 5 or x == 6) or (x == 9 or x == 10));
        if (!is_tooth) return glow;
    }
    return genPumpkinSide(x, y, h);
}

// --- Hay Bale (PR 262) ---

fn genHayBaleSide(_: u32, y: u32, h: u32) Pixel {
    if (y == 3 or y == 12) {
        const n = noise16(h);
        return px(clampU8(90 + n), clampU8(60 + n), clampU8(25 + n));
    }
    const n = noise32(h);
    return px(clampU8(200 + n), clampU8(180 + n), clampU8(80 + n));
}

fn genHayBaleTop(x: u32, y: u32, h: u32) Pixel {
    const n = noise16(h);
    // Concentric circles from center
    const dx = @as(i32, @intCast(x)) - 7;
    const dy = @as(i32, @intCast(y)) - 7;
    const dist: u32 = @intCast(@abs(dx) + @abs(dy));
    const ring = dist % 3;
    if (ring == 0) return px(clampU8(210 + n), clampU8(190 + n), clampU8(90 + n));
    if (ring == 1) return px(clampU8(190 + n), clampU8(170 + n), clampU8(70 + n));
    return px(clampU8(200 + n), clampU8(180 + n), clampU8(80 + n));
}

// --- Concrete & Copper (PR 256) ---

fn genConcrete(h: u32, base: Rgb) Pixel {
    const n = noise16(h);
    if ((h >> 6) % 15 == 0) return mixColor(base, n + 12);
    if ((h >> 8) % 20 == 0) return mixColor(base, n - 10);
    return mixColor(base, n);
}

fn genCopperBlock(_: u32, y: u32, h: u32) Pixel {
    const n = noise16(h);
    const sheen: i32 = if (y % 5 == 0) 15 else 0;
    if (h % 20 == 0) return px(clampU8(60 + n), clampU8(140 + n), clampU8(90 + n));
    return px(clampU8(192 + n + sheen), clampU8(115 + n + sheen), clampU8(71 + n + sheen));
}

fn genExposedCopper(x: u32, y: u32, h: u32) Pixel {
    const n = noise16(h);
    if (y % 8 == 0) return px(clampU8(140 + n), clampU8(95 + n), clampU8(60 + n));
    const patch = hash(x / 3, y / 3, 121);
    if (patch % 5 == 0) return px(clampU8(60 + n), clampU8(140 + n), clampU8(90 + n));
    return px(clampU8(166 + n), clampU8(128 + n), clampU8(90 + n));
}

fn genWeatheredCopper(x: u32, y: u32, h: u32) Pixel {
    const n = noise16(h);
    if (y % 8 == 0) return px(clampU8(90 + n), clampU8(115 + n), clampU8(90 + n));
    const patch = hash(x / 3, y / 3, 122);
    if (patch % 10 < 3) return px(clampU8(166 + n), clampU8(128 + n), clampU8(90 + n));
    return px(clampU8(115 + n), clampU8(150 + n), clampU8(115 + n));
}

fn genOxidizedCopper(x: u32, y: u32, h: u32) Pixel {
    const n = noise16(h);
    if (x % 5 == 0 or y % 5 == 0) return px(clampU8(50 + n), clampU8(130 + n), clampU8(110 + n));
    return px(clampU8(76 + n), clampU8(166 + n), clampU8(140 + n));
}

fn genWool(x: u32, y: u32, _: u32, base: Rgb) Pixel {
    const weave: i32 = if ((x / 2 + y / 2) % 2 == 0) 8 else -8;
    return mixColor(base, weave);
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

fn genCraftingTableTop(x: u32, y: u32, h: u32) Pixel {
    // 4x4 grid pattern: alternating light and dark wood quadrants
    const qx = (x / 4) % 2;
    const qy = (y / 4) % 2;
    const n = noise16(h);
    if (x == 0 or x == 15 or y == 0 or y == 15) return .{ .r = clampU8(90 + n), .g = clampU8(60 + n), .b = clampU8(30 + n), .a = 255 };
    if (qx != qy) {
        return .{ .r = clampU8(190 + n), .g = clampU8(150 + n), .b = clampU8(85 + n), .a = 255 };
    }
    return .{ .r = clampU8(160 + n), .g = clampU8(120 + n), .b = clampU8(65 + n), .a = 255 };
}

fn genCraftingTableSide(x: u32, y: u32, h: u32) Pixel {
    const n = noise16(h);
    // Dark frame border
    if (x == 0 or x == 15 or y == 0 or y == 15) return .{ .r = clampU8(90 + n), .g = clampU8(60 + n), .b = clampU8(30 + n), .a = 255 };
    // Tool silhouettes: saw (left half) and hammer (right half)
    if (x < 8) {
        // Saw teeth pattern
        if (y >= 3 and y <= 12 and x == 3) return px(60, 60, 65);
        if (y >= 3 and y <= 12 and x == 4 and y % 2 == 0) return px(60, 60, 65);
    } else {
        // Hammer shape
        if (y >= 3 and y <= 5 and x >= 10 and x <= 13) return px(60, 60, 65);
        if (y >= 6 and y <= 11 and x == 11) return .{ .r = clampU8(120 + n), .g = clampU8(85 + n), .b = clampU8(40 + n), .a = 255 };
    }
    // Wood plank base
    const band = (y +% (h >> 8) % 2) % 5;
    if (band == 0) return .{ .r = clampU8(150 + n), .g = clampU8(110 + n), .b = clampU8(55 + n), .a = 255 };
    return .{ .r = clampU8(178 + n), .g = clampU8(140 + n), .b = clampU8(76 + n), .a = 255 };
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
