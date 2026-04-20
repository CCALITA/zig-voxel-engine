const std = @import("std");

pub const RiverFeatures = struct {
    water_color: [3]u8 = .{ 63, 118, 228 },
    surface_block: u8 = 12,
    depth: u8 = 5,
    width: u8 = 8,
    frozen: bool = false,
};

pub const RiverPoint = struct {
    x: i32,
    z: i32,
};

pub const RiverPath = struct {
    points: [64]RiverPoint,
    point_count: u8,
};

pub fn generateRiverPath(seed: u64, start_x: i32, start_z: i32) RiverPath {
    var path = RiverPath{
        .points = undefined,
        .point_count = 0,
    };

    var rng = std.Random.DefaultPrng.init(seed);
    const random = rng.random();

    var current_x = start_x;
    var current_z = start_z;

    const max_points: u8 = 64;
    var i: u8 = 0;
    while (i < max_points) : (i += 1) {
        path.points[i] = .{ .x = current_x, .z = current_z };

        const dx: i32 = @as(i32, @intCast(random.intRangeAtMost(u32, 0, 2))) - 1;
        const dz: i32 = @as(i32, @intCast(random.intRangeAtMost(u32, 0, 2)));
        const step: i32 = @as(i32, @intCast(random.intRangeAtMost(u32, 4, 8)));

        current_x += dx * step;
        current_z += dz * step + 4;
    }

    path.point_count = max_points;
    return path;
}

fn distanceToSegment(px: f32, pz: f32, ax: f32, az: f32, bx: f32, bz: f32) f32 {
    const ab_x = bx - ax;
    const ab_z = bz - az;
    const ap_x = px - ax;
    const ap_z = pz - az;

    const ab_len_sq = ab_x * ab_x + ab_z * ab_z;
    if (ab_len_sq == 0.0) {
        return @sqrt(ap_x * ap_x + ap_z * ap_z);
    }

    const t_raw = (ap_x * ab_x + ap_z * ab_z) / ab_len_sq;
    const t = std.math.clamp(t_raw, 0.0, 1.0);

    const proj_x = ax + t * ab_x;
    const proj_z = az + t * ab_z;

    const diff_x = px - proj_x;
    const diff_z = pz - proj_z;

    return @sqrt(diff_x * diff_x + diff_z * diff_z);
}

pub fn isRiverAt(path: RiverPath, x: i32, z: i32, width: u8) bool {
    if (path.point_count < 2) return false;

    const half_width: f32 = @as(f32, @floatFromInt(width)) / 2.0;
    const px: f32 = @floatFromInt(x);
    const pz: f32 = @floatFromInt(z);

    var i: u8 = 0;
    while (i < path.point_count - 1) : (i += 1) {
        const ax: f32 = @floatFromInt(path.points[i].x);
        const az: f32 = @floatFromInt(path.points[i].z);
        const bx: f32 = @floatFromInt(path.points[i + 1].x);
        const bz: f32 = @floatFromInt(path.points[i + 1].z);

        const dist = distanceToSegment(px, pz, ax, az, bx, bz);
        if (dist < half_width) return true;
    }

    return false;
}

pub fn getRiverDepth(distance_from_center: f32, max_depth: u8) u8 {
    const max_f: f32 = @floatFromInt(max_depth);
    if (distance_from_center >= 1.0) return 0;
    if (distance_from_center <= 0.0) return max_depth;

    const depth = max_f * (1.0 - distance_from_center * distance_from_center);
    return @intFromFloat(@max(depth, 0.0));
}

pub fn getFrozenVariant(temperature: f32) bool {
    return temperature < 0.15;
}

pub const RiverMobs = struct {
    salmon: bool,
    squid: bool,
    drowned_chance: f32,
};

pub fn getRiverMobs() RiverMobs {
    return .{
        .salmon = true,
        .squid = true,
        .drowned_chance = 0.05,
    };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "generateRiverPath produces consistent path from seed" {
    const path = generateRiverPath(42, 0, 0);
    try std.testing.expect(path.point_count == 64);
    try std.testing.expectEqual(RiverPoint{ .x = 0, .z = 0 }, path.points[0]);

    // Same seed produces same path
    const path2 = generateRiverPath(42, 0, 0);
    try std.testing.expectEqual(path.points[10], path2.points[10]);

    // Different seed produces different path
    const path3 = generateRiverPath(99, 0, 0);
    // At least one later point should differ
    var differs = false;
    var i: u8 = 1;
    while (i < path.point_count) : (i += 1) {
        if (path.points[i].x != path3.points[i].x or path.points[i].z != path3.points[i].z) {
            differs = true;
            break;
        }
    }
    try std.testing.expect(differs);
}

test "isRiverAt detects points within river width" {
    var path = RiverPath{ .points = undefined, .point_count = 2 };
    path.points[0] = .{ .x = 0, .z = 0 };
    path.points[1] = .{ .x = 0, .z = 100 };

    // Point on the river center line
    try std.testing.expect(isRiverAt(path, 0, 50, 8));

    // Point just within half-width (3 < 4)
    try std.testing.expect(isRiverAt(path, 3, 50, 8));

    // Point outside river width (5 >= 4)
    try std.testing.expect(!isRiverAt(path, 5, 50, 8));

    // Narrow width: 2 means half-width 1
    try std.testing.expect(isRiverAt(path, 0, 50, 2));
    try std.testing.expect(!isRiverAt(path, 2, 50, 2));
}

test "getRiverDepth gradient from center to edge" {
    // At center (distance 0), depth equals max
    try std.testing.expectEqual(@as(u8, 5), getRiverDepth(0.0, 5));

    // At edge (distance 1.0), depth is 0
    try std.testing.expectEqual(@as(u8, 0), getRiverDepth(1.0, 5));

    // Beyond edge
    try std.testing.expectEqual(@as(u8, 0), getRiverDepth(1.5, 5));

    // Midway: depth should be between 0 and max
    const mid_depth = getRiverDepth(0.5, 5);
    try std.testing.expect(mid_depth > 0);
    try std.testing.expect(mid_depth <= 5);

    // Depth decreases as distance increases
    const d1 = getRiverDepth(0.2, 5);
    const d2 = getRiverDepth(0.8, 5);
    try std.testing.expect(d1 >= d2);
}

test "getFrozenVariant based on temperature" {
    // Cold temperatures freeze
    try std.testing.expect(getFrozenVariant(0.0));
    try std.testing.expect(getFrozenVariant(0.1));
    try std.testing.expect(getFrozenVariant(-1.0));

    // Warm temperatures don't freeze
    try std.testing.expect(!getFrozenVariant(0.15));
    try std.testing.expect(!getFrozenVariant(0.5));
    try std.testing.expect(!getFrozenVariant(1.0));
}

test "getRiverMobs returns correct spawn configuration" {
    const mobs = getRiverMobs();
    try std.testing.expect(mobs.salmon);
    try std.testing.expect(mobs.squid);
    try std.testing.expectApproxEqAbs(@as(f32, 0.05), mobs.drowned_chance, 0.001);
}
