/// Map data system for storing and querying map pixel data.
/// Provides a 128x128 RGB pixel grid with zoom levels that control
/// how many world blocks each pixel represents (z0=1, z4=16).

const std = @import("std");

// ── Constants ──────────────────────────────────────────────────────────────

pub const MAP_SIZE: u16 = 128;

// ── Zoom Level ─────────────────────────────────────────────────────────────

pub const ZoomLevel = enum(u3) {
    z0,
    z1,
    z2,
    z3,
    z4,
};

/// Returns the number of world blocks represented by each pixel at the
/// given zoom level: z0=1, z1=2, z2=4, z3=8, z4=16.
pub fn getBlocksPerPixel(zoom: ZoomLevel) u16 {
    return @as(u16, 1) << @intFromEnum(zoom);
}

// ── MapData ────────────────────────────────────────────────────────────────

pub const MapData = struct {
    pixels: [MAP_SIZE * MAP_SIZE][3]u8 = undefined,
    center_x: i32 = 0,
    center_z: i32 = 0,
    zoom: ZoomLevel = .z0,
    initialized: bool = false,

    /// Create a new map centered at (cx, cz) with the given zoom level.
    /// All pixels are initialized to black (0,0,0).
    pub fn init(cx: i32, cz: i32, zoom: ZoomLevel) MapData {
        return .{
            .pixels = [_][3]u8{.{ 0, 0, 0 }} ** (MAP_SIZE * MAP_SIZE),
            .center_x = cx,
            .center_z = cz,
            .zoom = zoom,
            .initialized = true,
        };
    }

    /// Convert a world coordinate to a pixel coordinate on this map.
    /// Returns null if the world position falls outside the map bounds.
    pub fn worldToPixel(self: *const MapData, wx: i32, wz: i32) ?struct { px: u7, pz: u7 } {
        const bpp: i32 = @intCast(getBlocksPerPixel(self.zoom));
        const half: i32 = @divExact(@as(i32, MAP_SIZE), 2);
        const half_span: i32 = half * bpp;

        const rel_x = wx - (self.center_x - half_span);
        const rel_z = wz - (self.center_z - half_span);

        const px = @divFloor(rel_x, bpp);
        const pz = @divFloor(rel_z, bpp);

        if (px < 0 or px >= MAP_SIZE or pz < 0 or pz >= MAP_SIZE) return null;

        return .{
            .px = @intCast(px),
            .pz = @intCast(pz),
        };
    }

    /// Set the RGB color of a pixel.
    pub fn setPixel(self: *MapData, px: u7, pz: u7, r: u8, g: u8, b: u8) void {
        const idx = @as(usize, pz) * MAP_SIZE + @as(usize, px);
        self.pixels[idx] = .{ r, g, b };
    }

    /// Get the RGB color of a pixel.
    pub fn getPixel(self: *const MapData, px: u7, pz: u7) [3]u8 {
        const idx = @as(usize, pz) * MAP_SIZE + @as(usize, px);
        return self.pixels[idx];
    }

    /// Returns true if the world coordinate (wx, wz) falls within this map's range.
    pub fn isInRange(self: *const MapData, wx: i32, wz: i32) bool {
        return self.worldToPixel(wx, wz) != null;
    }
};

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

test "getBlocksPerPixel returns correct value for each zoom" {
    try std.testing.expectEqual(@as(u16, 1), getBlocksPerPixel(.z0));
    try std.testing.expectEqual(@as(u16, 2), getBlocksPerPixel(.z1));
    try std.testing.expectEqual(@as(u16, 4), getBlocksPerPixel(.z2));
    try std.testing.expectEqual(@as(u16, 8), getBlocksPerPixel(.z3));
    try std.testing.expectEqual(@as(u16, 16), getBlocksPerPixel(.z4));
}

test "init sets center, zoom, and initialized flag" {
    const map = MapData.init(100, -200, .z2);
    try std.testing.expectEqual(@as(i32, 100), map.center_x);
    try std.testing.expectEqual(@as(i32, -200), map.center_z);
    try std.testing.expectEqual(ZoomLevel.z2, map.zoom);
    try std.testing.expect(map.initialized);
}

test "init zeros all pixels to black" {
    const map = MapData.init(0, 0, .z0);
    try std.testing.expectEqual([3]u8{ 0, 0, 0 }, map.getPixel(0, 0));
    try std.testing.expectEqual([3]u8{ 0, 0, 0 }, map.getPixel(127, 127));
    try std.testing.expectEqual([3]u8{ 0, 0, 0 }, map.getPixel(64, 64));
}

test "default MapData is not initialized" {
    const map = MapData{};
    try std.testing.expect(!map.initialized);
    try std.testing.expectEqual(@as(i32, 0), map.center_x);
    try std.testing.expectEqual(@as(i32, 0), map.center_z);
    try std.testing.expectEqual(ZoomLevel.z0, map.zoom);
}

test "setPixel and getPixel round-trip" {
    var map = MapData.init(0, 0, .z0);
    map.setPixel(10, 20, 255, 128, 0);
    try std.testing.expectEqual([3]u8{ 255, 128, 0 }, map.getPixel(10, 20));
}

test "setPixel overwrites previous value" {
    var map = MapData.init(0, 0, .z0);
    map.setPixel(5, 5, 10, 20, 30);
    map.setPixel(5, 5, 40, 50, 60);
    try std.testing.expectEqual([3]u8{ 40, 50, 60 }, map.getPixel(5, 5));
}

test "worldToPixel maps center to pixel (64,64) at z0" {
    const map = MapData.init(0, 0, .z0);
    const result = map.worldToPixel(0, 0).?;
    try std.testing.expectEqual(@as(u7, 64), result.px);
    try std.testing.expectEqual(@as(u7, 64), result.pz);
}

test "worldToPixel returns null for out-of-range coordinates" {
    const map = MapData.init(0, 0, .z0);
    // At z0 the map covers -64..63, so 64 is out of range
    try std.testing.expect(map.worldToPixel(64, 0) == null);
    try std.testing.expect(map.worldToPixel(0, 64) == null);
    try std.testing.expect(map.worldToPixel(-65, 0) == null);
    try std.testing.expect(map.worldToPixel(0, -65) == null);
}

test "worldToPixel at z2 covers larger area" {
    const map = MapData.init(0, 0, .z2);
    // At z2, bpp=4, half_span=256, so map covers -256..255
    const result = map.worldToPixel(0, 0).?;
    try std.testing.expectEqual(@as(u7, 64), result.px);
    try std.testing.expectEqual(@as(u7, 64), result.pz);

    // Edge of range at z2
    try std.testing.expect(map.worldToPixel(-256, -256) != null);
    try std.testing.expect(map.worldToPixel(256, 256) == null);
}

test "isInRange returns true for coordinates within the map" {
    const map = MapData.init(0, 0, .z0);
    try std.testing.expect(map.isInRange(0, 0));
    try std.testing.expect(map.isInRange(-64, -64));
    try std.testing.expect(map.isInRange(63, 63));
}

test "isInRange returns false for coordinates outside the map" {
    const map = MapData.init(0, 0, .z0);
    try std.testing.expect(!map.isInRange(64, 0));
    try std.testing.expect(!map.isInRange(0, 64));
    try std.testing.expect(!map.isInRange(-65, 0));
    try std.testing.expect(!map.isInRange(1000, 1000));
}

test "worldToPixel with non-zero center" {
    const map = MapData.init(500, -300, .z0);
    // Center should map to (64, 64)
    const center = map.worldToPixel(500, -300).?;
    try std.testing.expectEqual(@as(u7, 64), center.px);
    try std.testing.expectEqual(@as(u7, 64), center.pz);

    // Top-left corner of the map
    const tl = map.worldToPixel(500 - 64, -300 - 64).?;
    try std.testing.expectEqual(@as(u7, 0), tl.px);
    try std.testing.expectEqual(@as(u7, 0), tl.pz);
}

test "getPixel at boundary pixels" {
    var map = MapData.init(0, 0, .z0);
    map.setPixel(0, 0, 1, 2, 3);
    map.setPixel(127, 0, 4, 5, 6);
    map.setPixel(0, 127, 7, 8, 9);
    map.setPixel(127, 127, 10, 11, 12);

    try std.testing.expectEqual([3]u8{ 1, 2, 3 }, map.getPixel(0, 0));
    try std.testing.expectEqual([3]u8{ 4, 5, 6 }, map.getPixel(127, 0));
    try std.testing.expectEqual([3]u8{ 7, 8, 9 }, map.getPixel(0, 127));
    try std.testing.expectEqual([3]u8{ 10, 11, 12 }, map.getPixel(127, 127));
}

test "isInRange at z4 covers 2048-block range" {
    const map = MapData.init(0, 0, .z4);
    // At z4, bpp=16, half_span=1024, so map covers -1024..1023
    try std.testing.expect(map.isInRange(0, 0));
    try std.testing.expect(map.isInRange(-1024, -1024));
    try std.testing.expect(map.isInRange(1023, 1023));
    try std.testing.expect(!map.isInRange(1024, 0));
    try std.testing.expect(!map.isInRange(-1025, 0));
}
