/// Map item system: tracks explored area and stores a top-down color
/// snapshot of terrain for the held map item.

const std = @import("std");

pub const MAP_SIZE = 128;

pub const MapData = struct {
    center_x: i32,
    center_z: i32,
    scale: u8, // 0 = 1:1, 1 = 1:2, 2 = 1:4, 3 = 1:8, 4 = 1:16
    pixels: [MAP_SIZE * MAP_SIZE]u8, // color palette indices

    pub fn init(center_x: i32, center_z: i32) MapData {
        return .{
            .center_x = center_x,
            .center_z = center_z,
            .scale = 0,
            .pixels = [_]u8{0} ** (MAP_SIZE * MAP_SIZE),
        };
    }

    /// Get the world-space radius this map covers.
    pub fn getWorldRadius(self: *const MapData) i32 {
        const scale_factor: i32 = @as(i32, 1) << @intCast(self.scale);
        return (MAP_SIZE / 2) * scale_factor;
    }

    /// Set a pixel at map coordinates (mx, mz).
    pub fn setPixel(self: *MapData, mx: u8, mz: u8, color: u8) void {
        if (mx >= MAP_SIZE or mz >= MAP_SIZE) return;
        self.pixels[@as(usize, mz) * MAP_SIZE + @as(usize, mx)] = color;
    }

    /// Get a pixel at map coordinates (mx, mz).
    pub fn getPixel(self: *const MapData, mx: u8, mz: u8) u8 {
        if (mx >= MAP_SIZE or mz >= MAP_SIZE) return 0;
        return self.pixels[@as(usize, mz) * MAP_SIZE + @as(usize, mx)];
    }
};

// ──────────────────────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────────────────────

test "MapData init creates blank map" {
    const m = MapData.init(0, 0);
    try std.testing.expectEqual(@as(i32, 0), m.center_x);
    try std.testing.expectEqual(@as(u8, 0), m.scale);
    try std.testing.expectEqual(@as(u8, 0), m.getPixel(0, 0));
}

test "setPixel and getPixel roundtrip" {
    var m = MapData.init(100, 200);
    m.setPixel(10, 20, 42);
    try std.testing.expectEqual(@as(u8, 42), m.getPixel(10, 20));
}

test "getWorldRadius scales with zoom level" {
    var m = MapData.init(0, 0);
    m.scale = 0;
    const r0 = m.getWorldRadius();
    m.scale = 2;
    const r2 = m.getWorldRadius();
    try std.testing.expect(r2 > r0);
    try std.testing.expectEqual(r0 * 4, r2);
}

test "out of bounds setPixel is safe" {
    var m = MapData.init(0, 0);
    m.setPixel(255, 255, 1); // should not crash
    try std.testing.expectEqual(@as(u8, 0), m.getPixel(255, 255));
}
