/// DDA (Digital Differential Analyzer) voxel traversal for block targeting.
/// Walks a ray through the voxel grid one cell at a time and reports the
/// first solid block hit, which face was crossed, and the adjacent empty
/// block (useful for block placement).
///
/// This module is intentionally decoupled from chunk storage: solidity checks
/// are provided via function-pointer callbacks, so callers can wire up any
/// world representation.
const std = @import("std");

pub const Face = enum {
    north,
    south,
    east,
    west,
    top,
    bottom,

    /// Returns the integer offset along each axis for this face's outward normal.
    pub fn normal(self: Face) [3]i32 {
        return switch (self) {
            .east => .{ 1, 0, 0 },
            .west => .{ -1, 0, 0 },
            .top => .{ 0, 1, 0 },
            .bottom => .{ 0, -1, 0 },
            .south => .{ 0, 0, 1 },
            .north => .{ 0, 0, -1 },
        };
    }
};

pub const RayHit = struct {
    bx: i32,
    by: i32,
    bz: i32,
    face: Face,
    adjacent_x: i32,
    adjacent_y: i32,
    adjacent_z: i32,
    distance: f32,
};

/// Cast a ray through the voxel grid using the DDA algorithm.
///
/// `origin_*` -- ray start in world-space (f32).
/// `dir_*`    -- ray direction (need not be normalized; the function handles it).
/// `max_distance` -- maximum travel distance before giving up.
/// `isSolid`  -- callback: takes world-space integer block coords, returns true if solid.
///
/// Returns the first solid block hit, or null if none within range.
pub fn cast(
    origin_x: f32,
    origin_y: f32,
    origin_z: f32,
    dir_x: f32,
    dir_y: f32,
    dir_z: f32,
    max_distance: f32,
    isSolid: *const fn (i32, i32, i32) bool,
) ?RayHit {
    const len = @sqrt(dir_x * dir_x + dir_y * dir_y + dir_z * dir_z);
    if (len == 0.0) return null;
    const dx = dir_x / len;
    const dy = dir_y / len;
    const dz = dir_z / len;

    var vx: i32 = @intFromFloat(@floor(origin_x));
    var vy: i32 = @intFromFloat(@floor(origin_y));
    var vz: i32 = @intFromFloat(@floor(origin_z));

    const step_x: i32 = if (dx >= 0) 1 else -1;
    const step_y: i32 = if (dy >= 0) 1 else -1;
    const step_z: i32 = if (dz >= 0) 1 else -1;

    const t_delta_x: f32 = if (dx != 0.0) @abs(1.0 / dx) else std.math.inf(f32);
    const t_delta_y: f32 = if (dy != 0.0) @abs(1.0 / dy) else std.math.inf(f32);
    const t_delta_z: f32 = if (dz != 0.0) @abs(1.0 / dz) else std.math.inf(f32);

    var t_max_x: f32 = initTMax(dx, origin_x, vx);
    var t_max_y: f32 = initTMax(dy, origin_y, vy);
    var t_max_z: f32 = initTMax(dz, origin_z, vz);

    // Check the starting voxel itself
    if (isSolid(vx, vy, vz)) {
        return RayHit{
            .bx = vx,
            .by = vy,
            .bz = vz,
            .face = .north,
            .adjacent_x = vx,
            .adjacent_y = vy,
            .adjacent_z = vz,
            .distance = 0.0,
        };
    }

    var last_face: Face = .north;

    while (true) {
        if (t_max_x < t_max_y) {
            if (t_max_x < t_max_z) {
                if (t_max_x > max_distance) return null;
                last_face = if (step_x > 0) .west else .east;
                vx += step_x;
                t_max_x += t_delta_x;
            } else {
                if (t_max_z > max_distance) return null;
                last_face = if (step_z > 0) .north else .south;
                vz += step_z;
                t_max_z += t_delta_z;
            }
        } else {
            if (t_max_y < t_max_z) {
                if (t_max_y > max_distance) return null;
                last_face = if (step_y > 0) .bottom else .top;
                vy += step_y;
                t_max_y += t_delta_y;
            } else {
                if (t_max_z > max_distance) return null;
                last_face = if (step_z > 0) .north else .south;
                vz += step_z;
                t_max_z += t_delta_z;
            }
        }

        if (isSolid(vx, vy, vz)) {
            const dist = switch (last_face) {
                .west, .east => t_max_x - t_delta_x,
                .bottom, .top => t_max_y - t_delta_y,
                .north, .south => t_max_z - t_delta_z,
            };

            const n = last_face.normal();

            return RayHit{
                .bx = vx,
                .by = vy,
                .bz = vz,
                .face = last_face,
                .adjacent_x = vx + n[0],
                .adjacent_y = vy + n[1],
                .adjacent_z = vz + n[2],
                .distance = dist,
            };
        }
    }
}

/// Convenience wrapper that casts within a single 16x16x16 chunk.
/// `getBlock` returns the block ID at chunk-local coords; coordinates
/// outside 0..15 should be treated as air (return 0). `isBlockSolid`
/// maps a block ID to a boolean (e.g., `block.isSolid`).
pub fn castInChunk(
    ox: f32,
    oy: f32,
    oz: f32,
    dx: f32,
    dy: f32,
    dz: f32,
    max_dist: f32,
    comptime getBlock: fn (*const anyopaque, i32, i32, i32) u8,
    chunk_ptr: *const anyopaque,
    comptime isBlockSolid: fn (u8) bool,
) ?RayHit {
    const Wrapper = struct {
        var ctx: ?*const anyopaque = null;

        fn isSolid(x: i32, y: i32, z: i32) bool {
            const c = ctx orelse return false;
            return isBlockSolid(getBlock(c, x, y, z));
        }
    };

    Wrapper.ctx = chunk_ptr;
    defer Wrapper.ctx = null;
    return cast(ox, oy, oz, dx, dy, dz, max_dist, &Wrapper.isSolid);
}

/// Compute the parametric distance from the ray origin to the first
/// voxel boundary along one axis.
fn initTMax(d: f32, origin: f32, voxel: i32) f32 {
    if (d == 0.0) return std.math.inf(f32);
    const boundary: f32 = if (d > 0)
        @as(f32, @floatFromInt(voxel)) + 1.0
    else
        @as(f32, @floatFromInt(voxel));
    return (boundary - origin) / d;
}

// =============================================================================
// Tests
// =============================================================================

const CHUNK_SIZE = 16;

fn solidAtOrigin(x: i32, y: i32, z: i32) bool {
    return (x == 0 and y == 0 and z == 0);
}

fn nothingSolid(_: i32, _: i32, _: i32) bool {
    return false;
}

fn solidBelow(_: i32, y: i32, _: i32) bool {
    return y < 0;
}

fn solidWall(x: i32, _: i32, _: i32) bool {
    return x >= 5;
}

/// Shared test helper: read a block from a flat u8 array treated as 16x16x16.
fn testGetBlock(ctx: *const anyopaque, x: i32, y: i32, z: i32) u8 {
    if (x < 0 or x >= CHUNK_SIZE or y < 0 or y >= CHUNK_SIZE or z < 0 or z >= CHUNK_SIZE)
        return 0;
    const b: *const [CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE]u8 = @ptrCast(@alignCast(ctx));
    return b[@as(usize, @intCast(y)) * 256 + @as(usize, @intCast(z)) * 16 + @as(usize, @intCast(x))];
}

/// Shared test helper: any non-zero block ID is solid.
fn testIsSolid(id: u8) bool {
    return id != 0;
}

test "ray hits a known solid block at expected coords" {
    const hit = cast(-3.0, 0.5, 0.5, 1.0, 0.0, 0.0, 10.0, &solidAtOrigin);
    try std.testing.expect(hit != null);
    const h = hit.?;
    try std.testing.expectEqual(@as(i32, 0), h.bx);
    try std.testing.expectEqual(@as(i32, 0), h.by);
    try std.testing.expectEqual(@as(i32, 0), h.bz);
}

test "ray through empty space returns null" {
    const hit = cast(0.5, 0.5, 0.5, 1.0, 0.0, 0.0, 10.0, &nothingSolid);
    try std.testing.expect(hit == null);
}

test "hit face is correct — ray from +Y hitting top face" {
    const hit = cast(0.5, 5.0, 0.5, 0.0, -1.0, 0.0, 20.0, &solidBelow);
    try std.testing.expect(hit != null);
    const h = hit.?;
    try std.testing.expectEqual(Face.top, h.face);
    try std.testing.expectEqual(@as(i32, -1), h.by);
}

test "hit face — ray from -X hitting west face" {
    const hit = cast(0.5, 0.5, 0.5, 1.0, 0.0, 0.0, 20.0, &solidWall);
    try std.testing.expect(hit != null);
    const h = hit.?;
    try std.testing.expectEqual(Face.west, h.face);
    try std.testing.expectEqual(@as(i32, 5), h.bx);
}

test "adjacent position is correct for block placement" {
    const hit = cast(0.5, 0.5, 0.5, 1.0, 0.0, 0.0, 20.0, &solidWall);
    try std.testing.expect(hit != null);
    const h = hit.?;
    try std.testing.expectEqual(@as(i32, 4), h.adjacent_x);
    try std.testing.expectEqual(@as(i32, 0), h.adjacent_y);
    try std.testing.expectEqual(@as(i32, 0), h.adjacent_z);
}

test "ray at chunk boundary — castInChunk with mock chunk" {
    var blocks = [_]u8{0} ** (CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE);
    for (0..CHUNK_SIZE) |x| {
        for (0..CHUNK_SIZE) |z| {
            blocks[0 * 256 + z * 16 + x] = 1;
        }
    }

    const hit = castInChunk(8.5, 10.0, 8.5, 0.0, -1.0, 0.0, 20.0, testGetBlock, @ptrCast(&blocks), testIsSolid);
    try std.testing.expect(hit != null);
    const h = hit.?;
    try std.testing.expectEqual(@as(i32, 0), h.by);
    try std.testing.expectEqual(Face.top, h.face);
    try std.testing.expectEqual(@as(i32, 1), h.adjacent_y);
}

test "castInChunk — ray misses all blocks" {
    const blocks = [_]u8{0} ** (CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE);
    const hit = castInChunk(8.5, 8.5, 8.5, 1.0, 0.0, 0.0, 50.0, testGetBlock, @ptrCast(&blocks), testIsSolid);
    try std.testing.expect(hit == null);
}

test "castInChunk — ray hits corner block at chunk boundary" {
    var blocks = [_]u8{0} ** (CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE);
    blocks[0 * 256 + 15 * 16 + 15] = 1;

    const hit = castInChunk(0.5, 0.5, 0.5, 1.0, 0.0, 1.0, 50.0, testGetBlock, @ptrCast(&blocks), testIsSolid);
    try std.testing.expect(hit != null);
    const h = hit.?;
    try std.testing.expectEqual(@as(i32, 15), h.bx);
    try std.testing.expectEqual(@as(i32, 0), h.by);
    try std.testing.expectEqual(@as(i32, 15), h.bz);
}

test "distance is non-negative for a valid hit" {
    const hit = cast(0.5, 5.0, 0.5, 0.0, -1.0, 0.0, 20.0, &solidBelow);
    try std.testing.expect(hit != null);
    try std.testing.expect(hit.?.distance >= 0.0);
}

test "face normals cover all six directions" {
    try std.testing.expectEqual([3]i32{ -1, 0, 0 }, Face.west.normal());
    try std.testing.expectEqual([3]i32{ 1, 0, 0 }, Face.east.normal());
    try std.testing.expectEqual([3]i32{ 0, 1, 0 }, Face.top.normal());
    try std.testing.expectEqual([3]i32{ 0, -1, 0 }, Face.bottom.normal());
    try std.testing.expectEqual([3]i32{ 0, 0, -1 }, Face.north.normal());
    try std.testing.expectEqual([3]i32{ 0, 0, 1 }, Face.south.normal());
}
