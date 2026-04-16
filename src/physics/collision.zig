/// Voxel collision resolution.
/// Resolves an AABB against solid blocks in a chunk, axis by axis (Y first
/// for ground detection, then X, then Z).
const std = @import("std");
const aabb_mod = @import("aabb.zig");
const AABB = aabb_mod.AABB;
const Chunk = @import("chunk");
const block = @import("block");

/// Return a unit-cube AABB for the block at integer coordinates (bx, by, bz).
pub fn getBlockAABB(bx: i32, by: i32, bz: i32) AABB {
    const fx: f32 = @floatFromInt(bx);
    const fy: f32 = @floatFromInt(by);
    const fz: f32 = @floatFromInt(bz);
    return .{
        .min_x = fx,
        .min_y = fy,
        .min_z = fz,
        .max_x = fx + 1.0,
        .max_y = fy + 1.0,
        .max_z = fz + 1.0,
    };
}

pub const Axis = enum { x, y, z };

/// Clamp `velocity` along one axis so that `player` does not penetrate any of
/// the provided block AABBs.  Returns the clamped velocity.
pub fn sweepAxis(player: AABB, blocks: []const AABB, velocity: f32, axis: Axis) f32 {
    var vel = velocity;

    for (blocks) |b| {
        vel = clampVelocity(player, b, vel, axis);
    }

    return vel;
}

/// Clamp velocity along `axis` so that `player` moved by `vel` does not
/// overlap `block_aabb`.  The other two axes must already overlap for a
/// collision to be possible.
fn clampVelocity(player: AABB, block_aabb: AABB, vel: f32, axis: Axis) f32 {
    switch (axis) {
        .x => {
            if (player.max_y <= block_aabb.min_y or player.min_y >= block_aabb.max_y) return vel;
            if (player.max_z <= block_aabb.min_z or player.min_z >= block_aabb.max_z) return vel;

            if (vel > 0 and player.max_x <= block_aabb.min_x) {
                const d = block_aabb.min_x - player.max_x;
                if (d < vel) return d;
            } else if (vel < 0 and player.min_x >= block_aabb.max_x) {
                const d = block_aabb.max_x - player.min_x;
                if (d > vel) return d;
            }
        },
        .y => {
            if (player.max_x <= block_aabb.min_x or player.min_x >= block_aabb.max_x) return vel;
            if (player.max_z <= block_aabb.min_z or player.min_z >= block_aabb.max_z) return vel;

            if (vel > 0 and player.max_y <= block_aabb.min_y) {
                const d = block_aabb.min_y - player.max_y;
                if (d < vel) return d;
            } else if (vel < 0 and player.min_y >= block_aabb.max_y) {
                const d = block_aabb.max_y - player.min_y;
                if (d > vel) return d;
            }
        },
        .z => {
            if (player.max_x <= block_aabb.min_x or player.min_x >= block_aabb.max_x) return vel;
            if (player.max_y <= block_aabb.min_y or player.min_y >= block_aabb.max_y) return vel;

            if (vel > 0 and player.max_z <= block_aabb.min_z) {
                const d = block_aabb.min_z - player.max_z;
                if (d < vel) return d;
            } else if (vel < 0 and player.min_z >= block_aabb.max_z) {
                const d = block_aabb.max_z - player.min_z;
                if (d > vel) return d;
            }
        },
    }
    return vel;
}

pub const CollisionResult = struct {
    vx: f32,
    vy: f32,
    vz: f32,
    on_ground: bool,
};

/// Resolve collision between `player_aabb` moving by (vx, vy, vz) against
/// all solid blocks in `chunk`.  `chunk_offset_*` is the world-space origin
/// of the chunk (multiply chunk coords by 16).
///
/// Resolution order: Y first (for ground detection), then X, then Z.
pub fn resolveCollision(
    player_aabb: AABB,
    vx_in: f32,
    vy_in: f32,
    vz_in: f32,
    chunk: *const Chunk,
    chunk_offset_x: i32,
    chunk_offset_y: i32,
    chunk_offset_z: i32,
) CollisionResult {
    // Collect solid block AABBs that the player might collide with.
    // We expand the player AABB by the velocity to find candidate blocks.
    const broad = player_aabb.expand(vx_in, vy_in, vz_in);

    // Convert broadphase AABB to block coordinate range (clamped to chunk).
    const bx0 = clampToChunk(@as(i32, @intFromFloat(@floor(broad.min_x))) - chunk_offset_x);
    const by0 = clampToChunk(@as(i32, @intFromFloat(@floor(broad.min_y))) - chunk_offset_y);
    const bz0 = clampToChunk(@as(i32, @intFromFloat(@floor(broad.min_z))) - chunk_offset_z);
    const bx1 = clampToChunk(@as(i32, @intFromFloat(@floor(broad.max_x))) - chunk_offset_x);
    const by1 = clampToChunk(@as(i32, @intFromFloat(@floor(broad.max_y))) - chunk_offset_y);
    const bz1 = clampToChunk(@as(i32, @intFromFloat(@floor(broad.max_z))) - chunk_offset_z);

    // Gather solid block AABBs into a fixed-size buffer.
    // Max broadphase range is bounded by chunk size; 512 entries covers
    // any realistic velocity within a single chunk.
    var solid_buf: [512]AABB = undefined;
    var solid_count: usize = 0;

    var iy: i32 = by0;
    while (iy <= by1) : (iy += 1) {
        var iz: i32 = bz0;
        while (iz <= bz1) : (iz += 1) {
            var ix: i32 = bx0;
            while (ix <= bx1) : (ix += 1) {
                const bid = chunk.getBlock(
                    @intCast(ix),
                    @intCast(iy),
                    @intCast(iz),
                );
                if (block.isSolid(bid)) {
                    if (solid_count >= solid_buf.len) break;
                    solid_buf[solid_count] = getBlockAABB(
                        ix + chunk_offset_x,
                        iy + chunk_offset_y,
                        iz + chunk_offset_z,
                    );
                    solid_count += 1;
                }
            }
        }
    }

    const solids = solid_buf[0..solid_count];

    // Resolve Y first (gravity / ground detection).
    var vy = sweepAxis(player_aabb, solids, vy_in, .y);
    var cur = player_aabb.offset(0, vy, 0);

    // Resolve X.
    var vx = sweepAxis(cur, solids, vx_in, .x);
    cur = cur.offset(vx, 0, 0);

    // Resolve Z.
    var vz = sweepAxis(cur, solids, vz_in, .z);

    const on_ground = vy_in < 0 and vy > vy_in;

    // Zero out velocities that were clamped (prevent accumulation).
    if (vy != vy_in) vy = 0;
    if (vx != vx_in) vx = 0;
    if (vz != vz_in) vz = 0;

    return .{ .vx = vx, .vy = vy, .vz = vz, .on_ground = on_ground };
}

/// Clamp a coordinate to [0, Chunk.SIZE - 1].
fn clampToChunk(v: i32) i32 {
    if (v < 0) return 0;
    if (v >= Chunk.SIZE) return Chunk.SIZE - 1;
    return v;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "getBlockAABB: unit cube at origin" {
    const b = getBlockAABB(0, 0, 0);
    try std.testing.expectApproxEqAbs(@as(f32, 0), b.min_x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1), b.max_y, 0.001);
}

test "standing on solid block: vy clamped, on_ground true" {
    // Build a chunk with a solid floor at y=0.
    var chunk = Chunk.init();
    for (0..Chunk.SIZE) |xi| {
        for (0..Chunk.SIZE) |zi| {
            chunk.setBlock(@intCast(xi), 0, @intCast(zi), block.STONE);
        }
    }

    // Player AABB standing just above block at y=1, width 0.6, height 1.8.
    const player = AABB{
        .min_x = 7.7,
        .min_y = 1.0,
        .min_z = 7.7,
        .max_x = 8.3,
        .max_y = 2.8,
        .max_z = 8.3,
    };

    const result = resolveCollision(player, 0, -0.1, 0, &chunk, 0, 0, 0);
    try std.testing.expectApproxEqAbs(@as(f32, 0), result.vy, 0.001);
    try std.testing.expect(result.on_ground);
}

test "falling in air: vy unchanged" {
    // Empty chunk (all air).
    const chunk = Chunk.init();

    const player = AABB{
        .min_x = 7.7,
        .min_y = 5.0,
        .min_z = 7.7,
        .max_x = 8.3,
        .max_y = 6.8,
        .max_z = 8.3,
    };

    const result = resolveCollision(player, 0, -0.5, 0, &chunk, 0, 0, 0);
    try std.testing.expectApproxEqAbs(@as(f32, -0.5), result.vy, 0.001);
    try std.testing.expect(!result.on_ground);
}

test "horizontal collision stops movement" {
    // Build a chunk with a wall at x=10 (block at local x=10).
    var chunk = Chunk.init();
    for (0..Chunk.SIZE) |yi| {
        for (0..Chunk.SIZE) |zi| {
            chunk.setBlock(10, @intCast(yi), @intCast(zi), block.STONE);
        }
    }

    // Player moving +x towards the wall.
    const player = AABB{
        .min_x = 9.0,
        .min_y = 1.0,
        .min_z = 7.7,
        .max_x = 9.6,
        .max_y = 2.8,
        .max_z = 8.3,
    };

    const result = resolveCollision(player, 1.0, 0, 0, &chunk, 0, 0, 0);
    // Player should stop at x=10 wall. max_x 9.6 + vx should not exceed 10.0.
    try std.testing.expect(result.vx < 1.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0), result.vx, 0.001);
}

test "sweepAxis: no blocks means velocity unchanged" {
    const player = AABB{ .min_x = 0, .min_y = 0, .min_z = 0, .max_x = 1, .max_y = 1, .max_z = 1 };
    const empty: []const AABB = &.{};
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), sweepAxis(player, empty, 5.0, .x), 0.001);
}
