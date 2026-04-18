/// Map item system for in-game cartography.
/// Each map captures a top-down view of the world as a 128x128 pixel grid.
/// Scale levels control how many world blocks each pixel represents:
/// scale 0 = 1 block/pixel (128x128 area), scale 4 = 16 blocks/pixel (2048x2048).

const std = @import("std");

// ── Constants ──────────────────────────────────────────────────────────────

pub const MAP_SIZE: u32 = 128;

// ── Block ID constants (mirrors src/world/block.zig) ───────────────────────

const AIR: u8 = 0;
const STONE: u8 = 1;
const DIRT: u8 = 2;
const GRASS: u8 = 3;
const COBBLESTONE: u8 = 4;
const OAK_PLANKS: u8 = 5;
const SAND: u8 = 6;
const GRAVEL: u8 = 7;
const OAK_LOG: u8 = 8;
const OAK_LEAVES: u8 = 9;
const WATER: u8 = 10;
const BEDROCK: u8 = 11;
const COAL_ORE: u8 = 12;
const IRON_ORE: u8 = 13;
const GOLD_ORE: u8 = 14;
const DIAMOND_ORE: u8 = 15;
const REDSTONE_ORE: u8 = 16;
const GLASS: u8 = 17;
const BRICK: u8 = 18;
const OBSIDIAN: u8 = 19;
const TNT: u8 = 20;
const ICE: u8 = 23;
const SNOW: u8 = 24;
const CLAY: u8 = 25;
const CACTUS: u8 = 26;
const PUMPKIN: u8 = 27;
const MELON: u8 = 28;
const GLOWSTONE: u8 = 29;
const NETHERRACK: u8 = 30;
const SOUL_SAND: u8 = 31;
const LAVA: u8 = 32;
const END_STONE: u8 = 45;

// ── Map colors ─────────────────────────────────────────────────────────────

pub const Color = struct {
    pub const none: u8 = 0;
    pub const green: u8 = 1;
    pub const brown: u8 = 2;
    pub const gray: u8 = 3;
    pub const blue: u8 = 4;
    pub const dark_gray: u8 = 5;
    pub const white: u8 = 6;
    pub const tan: u8 = 7;
    pub const dark_green: u8 = 8;
    pub const red: u8 = 9;
    pub const dark_brown: u8 = 10;
    pub const light_gray: u8 = 11;
    pub const yellow: u8 = 12;
    pub const orange: u8 = 13;
    pub const purple: u8 = 14;
    pub const black: u8 = 15;
};

// ── Scale ──────────────────────────────────────────────────────────────────

pub const MapScale = enum(u3) {
    scale_0 = 0,
    scale_1 = 1,
    scale_2 = 2,
    scale_3 = 3,
    scale_4 = 4,
};

// ── MapData ────────────────────────────────────────────────────────────────

pub const MapData = struct {
    pixels: [MAP_SIZE][MAP_SIZE]u8,
    center_x: i32,
    center_z: i32,
    scale: MapScale,
    explored: [MAP_SIZE][MAP_SIZE]bool,

    pub fn init(center_x: i32, center_z: i32, scale: MapScale) MapData {
        return .{
            .pixels = [_][MAP_SIZE]u8{[_]u8{Color.none} ** MAP_SIZE} ** MAP_SIZE,
            .center_x = center_x,
            .center_z = center_z,
            .scale = scale,
            .explored = [_][MAP_SIZE]bool{[_]bool{false} ** MAP_SIZE} ** MAP_SIZE,
        };
    }

    /// Returns the number of world blocks represented by each pixel.
    pub fn getBlocksPerPixel(self: *const MapData) u32 {
        return @as(u32, 1) << @intFromEnum(self.scale);
    }

    /// Convert a world coordinate to a pixel coordinate on this map.
    /// Returns null if the world position falls outside the map bounds.
    pub fn worldToPixel(self: *const MapData, wx: i32, wz: i32) ?struct { x: u7, z: u7 } {
        const bpp: i32 = @intCast(self.getBlocksPerPixel());
        const half_span: i32 = @intCast((MAP_SIZE / 2) * self.getBlocksPerPixel());

        const rel_x = wx - (self.center_x - half_span);
        const rel_z = wz - (self.center_z - half_span);

        const px = @divFloor(rel_x, bpp);
        const pz = @divFloor(rel_z, bpp);

        if (px < 0 or px >= MAP_SIZE or pz < 0 or pz >= MAP_SIZE) return null;

        return .{
            .x = @intCast(px),
            .z = @intCast(pz),
        };
    }

    /// Set the color of a pixel and mark it as explored.
    pub fn setPixel(self: *MapData, px: u7, pz: u7, color: u8) void {
        self.pixels[pz][px] = color;
        self.explored[pz][px] = true;
    }

    /// Update a single pixel from terrain data. Converts the top block at
    /// (wx, wz) to a map color and writes it to the corresponding pixel.
    pub fn updateFromTerrain(self: *MapData, wx: i32, wz: i32, top_block: u8) void {
        const pixel = self.worldToPixel(wx, wz) orelse return;
        const color = blockToMapColor(top_block);
        self.setPixel(pixel.x, pixel.z, color);
    }

    /// Mark all pixels within `radius` world-blocks of the player as explored.
    pub fn revealArea(self: *MapData, player_x: i32, player_z: i32, radius: u32) void {
        const bpp = self.getBlocksPerPixel();
        // Convert world radius to pixel radius (round up so partial pixels count)
        const pixel_radius = (radius + bpp - 1) / bpp;

        const center_pixel = self.worldToPixel(player_x, player_z) orelse return;
        const cx: i32 = @intCast(center_pixel.x);
        const cz: i32 = @intCast(center_pixel.z);
        const pr: i32 = @intCast(pixel_radius);
        const radius_sq = pr * pr;

        var dz: i32 = -pr;
        while (dz <= pr) : (dz += 1) {
            var dx: i32 = -pr;
            while (dx <= pr) : (dx += 1) {
                if (dx * dx + dz * dz > radius_sq) continue;

                const px = cx + dx;
                const pz = cz + dz;
                if (px < 0 or px >= MAP_SIZE or pz < 0 or pz >= MAP_SIZE) continue;

                self.explored[@intCast(pz)][@intCast(px)] = true;
            }
        }
    }
};

// ── Block-to-color mapping ─────────────────────────────────────────────────

/// Map a block ID to a map display color.
pub fn blockToMapColor(block_id: u8) u8 {
    return switch (block_id) {
        GRASS => Color.green,
        OAK_LEAVES => Color.dark_green,
        CACTUS => Color.dark_green,

        DIRT => Color.brown,
        OAK_LOG => Color.brown,

        STONE => Color.gray,
        COBBLESTONE => Color.gray,
        BEDROCK => Color.gray,
        COAL_ORE => Color.gray,
        IRON_ORE => Color.gray,

        WATER => Color.blue,
        ICE => Color.blue,

        SAND => Color.tan,
        GRAVEL => Color.tan,
        CLAY => Color.tan,
        END_STONE => Color.tan,

        SNOW => Color.white,
        GLASS => Color.white,

        OAK_PLANKS => Color.dark_brown,
        BRICK => Color.dark_brown,

        OBSIDIAN => Color.black,

        GOLD_ORE => Color.yellow,
        GLOWSTONE => Color.yellow,

        DIAMOND_ORE => Color.light_gray,
        REDSTONE_ORE => Color.red,
        TNT => Color.red,
        LAVA => Color.red,
        NETHERRACK => Color.red,

        PUMPKIN => Color.orange,
        MELON => Color.orange,

        SOUL_SAND => Color.dark_brown,

        AIR => Color.none,

        else => Color.light_gray,
    };
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

test "init creates blank unexplored map" {
    const map = MapData.init(100, 200, .scale_0);
    try std.testing.expectEqual(@as(i32, 100), map.center_x);
    try std.testing.expectEqual(@as(i32, 200), map.center_z);
    try std.testing.expectEqual(MapScale.scale_0, map.scale);
    try std.testing.expectEqual(Color.none, map.pixels[0][0]);
    try std.testing.expectEqual(Color.none, map.pixels[127][127]);
    try std.testing.expect(!map.explored[0][0]);
    try std.testing.expect(!map.explored[64][64]);
}

// ── Scale / blocks-per-pixel tests ─────────────────────────────────────────

test "getBlocksPerPixel returns correct values for each scale" {
    const s0 = MapData.init(0, 0, .scale_0);
    try std.testing.expectEqual(@as(u32, 1), s0.getBlocksPerPixel());

    const s1 = MapData.init(0, 0, .scale_1);
    try std.testing.expectEqual(@as(u32, 2), s1.getBlocksPerPixel());

    const s2 = MapData.init(0, 0, .scale_2);
    try std.testing.expectEqual(@as(u32, 4), s2.getBlocksPerPixel());

    const s3 = MapData.init(0, 0, .scale_3);
    try std.testing.expectEqual(@as(u32, 8), s3.getBlocksPerPixel());

    const s4 = MapData.init(0, 0, .scale_4);
    try std.testing.expectEqual(@as(u32, 16), s4.getBlocksPerPixel());
}

// ── worldToPixel tests ─────────────────────────────────────────────────────

test "worldToPixel maps center to pixel (64,64) at scale 0" {
    const map = MapData.init(0, 0, .scale_0);
    const result = map.worldToPixel(0, 0).?;
    try std.testing.expectEqual(@as(u7, 64), result.x);
    try std.testing.expectEqual(@as(u7, 64), result.z);
}

test "worldToPixel maps offset center correctly" {
    const map = MapData.init(1000, 2000, .scale_0);
    const result = map.worldToPixel(1000, 2000).?;
    try std.testing.expectEqual(@as(u7, 64), result.x);
    try std.testing.expectEqual(@as(u7, 64), result.z);
}

test "worldToPixel returns null for out-of-bounds position" {
    const map = MapData.init(0, 0, .scale_0);
    // scale_0 covers -64..+63, so 200 is way out
    try std.testing.expect(map.worldToPixel(200, 200) == null);
    try std.testing.expect(map.worldToPixel(-200, 0) == null);
}

test "worldToPixel at scale_4 maps wider area" {
    const map = MapData.init(0, 0, .scale_4);
    // scale_4 = 16 blocks/pixel, half-span = 64*16 = 1024
    // so world range is -1024..+1023
    const edge = map.worldToPixel(1000, 1000);
    try std.testing.expect(edge != null);

    // But 2000 should be out of range
    try std.testing.expect(map.worldToPixel(2000, 2000) == null);
}

test "worldToPixel scale affects pixel coordinate" {
    // At scale_2 (4 blocks/pixel), blocks 0..3 should all map to the same pixel
    const map = MapData.init(0, 0, .scale_2);
    const p0 = map.worldToPixel(0, 0).?;
    const p1 = map.worldToPixel(1, 1).?;
    const p3 = map.worldToPixel(3, 3).?;
    try std.testing.expectEqual(p0.x, p1.x);
    try std.testing.expectEqual(p0.z, p1.z);
    try std.testing.expectEqual(p0.x, p3.x);
    try std.testing.expectEqual(p0.z, p3.z);

    // But 4 should be the next pixel
    const p4 = map.worldToPixel(4, 4).?;
    try std.testing.expectEqual(p0.x + 1, p4.x);
}

// ── setPixel tests ─────────────────────────────────────────────────────────

test "setPixel writes color and marks explored" {
    var map = MapData.init(0, 0, .scale_0);
    map.setPixel(10, 20, Color.green);
    try std.testing.expectEqual(Color.green, map.pixels[20][10]);
    try std.testing.expect(map.explored[20][10]);
}

// ── updateFromTerrain tests ────────────────────────────────────────────────

test "updateFromTerrain sets correct color from block" {
    var map = MapData.init(0, 0, .scale_0);
    map.updateFromTerrain(0, 0, GRASS);
    const pixel = map.worldToPixel(0, 0).?;
    try std.testing.expectEqual(Color.green, map.pixels[pixel.z][pixel.x]);
    try std.testing.expect(map.explored[pixel.z][pixel.x]);
}

test "updateFromTerrain ignores out-of-bounds world coords" {
    var map = MapData.init(0, 0, .scale_0);
    // Should not crash for out-of-range coords
    map.updateFromTerrain(5000, 5000, STONE);
    // Map should remain blank
    try std.testing.expectEqual(Color.none, map.pixels[0][0]);
}

// ── revealArea tests ───────────────────────────────────────────────────────

test "revealArea marks pixels as explored within radius" {
    var map = MapData.init(0, 0, .scale_0);
    map.revealArea(0, 0, 5);

    // Center pixel (64,64) should be explored
    try std.testing.expect(map.explored[64][64]);

    // A pixel within radius should be explored
    try std.testing.expect(map.explored[64][67]); // 3 pixels east

    // A pixel outside radius should NOT be explored
    try std.testing.expect(!map.explored[64][74]); // 10 pixels east
}

test "revealArea respects map boundaries" {
    var map = MapData.init(0, 0, .scale_0);
    // Player at edge of map, large radius -- should not crash
    map.revealArea(-60, -60, 20);

    // Pixel at (4, 4) should be explored (player is at pixel ~4,4)
    try std.testing.expect(map.explored[4][4]);

    // But pixel (0,0) may or may not be explored depending on radius circle,
    // but the function should not panic.
}

test "revealArea at higher scale reveals more world blocks per pixel" {
    var map_s0 = MapData.init(0, 0, .scale_0);
    map_s0.revealArea(0, 0, 10);

    var map_s2 = MapData.init(0, 0, .scale_2);
    map_s2.revealArea(0, 0, 10);

    // Count explored pixels in each map
    var count_s0: u32 = 0;
    var count_s2: u32 = 0;
    for (0..MAP_SIZE) |z| {
        for (0..MAP_SIZE) |x| {
            if (map_s0.explored[z][x]) count_s0 += 1;
            if (map_s2.explored[z][x]) count_s2 += 1;
        }
    }

    // Scale_0 should have more explored pixels since each pixel is smaller
    try std.testing.expect(count_s0 > count_s2);
    try std.testing.expect(count_s0 > 0);
    try std.testing.expect(count_s2 > 0);
}

// ── blockToMapColor tests ──────────────────────────────────────────────────

test "blockToMapColor maps grass to green" {
    try std.testing.expectEqual(Color.green, blockToMapColor(GRASS));
}

test "blockToMapColor maps water to blue" {
    try std.testing.expectEqual(Color.blue, blockToMapColor(WATER));
}

test "blockToMapColor maps stone to gray" {
    try std.testing.expectEqual(Color.gray, blockToMapColor(STONE));
}

test "blockToMapColor maps sand to tan" {
    try std.testing.expectEqual(Color.tan, blockToMapColor(SAND));
}

test "blockToMapColor maps lava to red" {
    try std.testing.expectEqual(Color.red, blockToMapColor(LAVA));
}

test "blockToMapColor maps snow to white" {
    try std.testing.expectEqual(Color.white, blockToMapColor(SNOW));
}

test "blockToMapColor maps air to none" {
    try std.testing.expectEqual(Color.none, blockToMapColor(AIR));
}

test "blockToMapColor maps obsidian to black" {
    try std.testing.expectEqual(Color.black, blockToMapColor(OBSIDIAN));
}

test "blockToMapColor maps leaves and cactus to dark_green" {
    try std.testing.expectEqual(Color.dark_green, blockToMapColor(OAK_LEAVES));
    try std.testing.expectEqual(Color.dark_green, blockToMapColor(CACTUS));
}

test "blockToMapColor returns light_gray for unknown blocks" {
    try std.testing.expectEqual(Color.light_gray, blockToMapColor(255));
    try std.testing.expectEqual(Color.light_gray, blockToMapColor(100));
}
