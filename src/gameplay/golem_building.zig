const std = @import("std");

/// Block ID type (matches world/block.zig BlockId)
const BlockId = u8;

// Block IDs for golem construction.
// Reference: src/world/block.zig for the canonical block registry.
// SNOW reuses block.SNOW (24). IRON_BLOCK and CARVED_PUMPKIN are not yet
// in the registry; placeholder IDs are used until they are added.
const IRON_BLOCK: BlockId = 99;
const CARVED_PUMPKIN: BlockId = 100;
const SNOW_BLOCK: BlockId = 24; // block.SNOW

pub const GolemType = enum {
    iron,
    snow,
};

pub const BlockPos = struct {
    x: i32,
    y: i32,
    z: i32,
};

pub const IronGolemSpawn = struct {
    x: f32,
    y: f32,
    z: f32,
    clear_blocks: [5]BlockPos,
};

pub const SnowGolemSpawn = struct {
    x: f32,
    y: f32,
    z: f32,
    clear_blocks: [3]BlockPos,
};

pub const GolemSpawnResult = struct {
    golem_type: GolemType,
    spawn: union(enum) {
        iron: IronGolemSpawn,
        snow: SnowGolemSpawn,
    },
};

const GetBlockFn = *const fn (i32, i32, i32) BlockId;

/// Check for iron golem T-shape pattern with pumpkin on top center.
/// The T-shape is 3 iron blocks across the top row + 1 iron block below center.
/// The carved pumpkin sits on top of the center iron block.
///
/// Side view (X-Z or Z-X axis):
///   [P]          <- carved pumpkin (pumpkin_y)
///   [I][I][I]    <- 3 iron blocks across (pumpkin_y - 1)
///      [I]       <- 1 iron block below center (pumpkin_y - 2)
pub fn checkIronGolemPattern(getBlock: GetBlockFn, pumpkin_x: i32, pumpkin_y: i32, pumpkin_z: i32) ?IronGolemSpawn {
    if (getBlock(pumpkin_x, pumpkin_y, pumpkin_z) != CARVED_PUMPKIN) return null;

    const arm_y = pumpkin_y - 1;
    const body_y = pumpkin_y - 2;

    // Try both orientations: arms along X axis or arms along Z axis
    const orientations = [_]struct { dx: i32, dz: i32 }{
        .{ .dx = 1, .dz = 0 }, // arms along X
        .{ .dx = 0, .dz = 1 }, // arms along Z
    };

    for (orientations) |orient| {
        const left_x = pumpkin_x - orient.dx;
        const left_z = pumpkin_z - orient.dz;
        const right_x = pumpkin_x + orient.dx;
        const right_z = pumpkin_z + orient.dz;

        // Short-circuit: skip remaining checks if any block is wrong
        if (getBlock(pumpkin_x, arm_y, pumpkin_z) != IRON_BLOCK) continue;
        if (getBlock(left_x, arm_y, left_z) != IRON_BLOCK) continue;
        if (getBlock(right_x, arm_y, right_z) != IRON_BLOCK) continue;
        if (getBlock(pumpkin_x, body_y, pumpkin_z) != IRON_BLOCK) continue;

        return IronGolemSpawn{
            .x = @as(f32, @floatFromInt(pumpkin_x)) + 0.5,
            .y = @as(f32, @floatFromInt(body_y)),
            .z = @as(f32, @floatFromInt(pumpkin_z)) + 0.5,
            .clear_blocks = .{
                .{ .x = pumpkin_x, .y = pumpkin_y, .z = pumpkin_z },
                .{ .x = pumpkin_x, .y = arm_y, .z = pumpkin_z },
                .{ .x = left_x, .y = arm_y, .z = left_z },
                .{ .x = right_x, .y = arm_y, .z = right_z },
                .{ .x = pumpkin_x, .y = body_y, .z = pumpkin_z },
            },
        };
    }

    return null;
}

/// Check for snow golem pattern: 2 snow blocks vertically + carved pumpkin on top.
///
///   [P]     <- carved pumpkin (pumpkin_y)
///   [S]     <- snow block (pumpkin_y - 1)
///   [S]     <- snow block (pumpkin_y - 2)
pub fn checkSnowGolemPattern(getBlock: GetBlockFn, pumpkin_x: i32, pumpkin_y: i32, pumpkin_z: i32) ?SnowGolemSpawn {
    if (getBlock(pumpkin_x, pumpkin_y, pumpkin_z) != CARVED_PUMPKIN) return null;

    const upper_snow = getBlock(pumpkin_x, pumpkin_y - 1, pumpkin_z) == SNOW_BLOCK;
    const lower_snow = getBlock(pumpkin_x, pumpkin_y - 2, pumpkin_z) == SNOW_BLOCK;

    if (upper_snow and lower_snow) {
        return SnowGolemSpawn{
            .x = @as(f32, @floatFromInt(pumpkin_x)) + 0.5,
            .y = @as(f32, @floatFromInt(pumpkin_y - 2)),
            .z = @as(f32, @floatFromInt(pumpkin_z)) + 0.5,
            .clear_blocks = .{
                .{ .x = pumpkin_x, .y = pumpkin_y, .z = pumpkin_z },
                .{ .x = pumpkin_x, .y = pumpkin_y - 1, .z = pumpkin_z },
                .{ .x = pumpkin_x, .y = pumpkin_y - 2, .z = pumpkin_z },
            },
        };
    }

    return null;
}

/// Called when a block is placed. Checks if the placement completes a golem pattern.
pub fn onBlockPlaced(placed_block: BlockId, x: i32, y: i32, z: i32, getBlock: GetBlockFn) ?GolemSpawnResult {
    // Golem patterns are only triggered by placing a carved pumpkin
    if (placed_block != CARVED_PUMPKIN) return null;

    // Try iron golem first (more specific pattern)
    if (checkIronGolemPattern(getBlock, x, y, z)) |iron_spawn| {
        return GolemSpawnResult{
            .golem_type = .iron,
            .spawn = .{ .iron = iron_spawn },
        };
    }

    // Try snow golem
    if (checkSnowGolemPattern(getBlock, x, y, z)) |snow_spawn| {
        return GolemSpawnResult{
            .golem_type = .snow,
            .spawn = .{ .snow = snow_spawn },
        };
    }

    return null;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

const testing = std.testing;

/// Helper to build a small test world from a block map.
fn makeGetBlock(comptime blocks: []const struct { x: i32, y: i32, z: i32, id: BlockId }) GetBlockFn {
    const S = struct {
        fn get(x: i32, y: i32, z: i32) BlockId {
            for (blocks) |b| {
                if (b.x == x and b.y == y and b.z == z) return b.id;
            }
            return 0; // air
        }
    };
    return S.get;
}

test "iron golem T-shape detected (arms along X)" {
    // Pattern with pumpkin at (5, 12, 5)
    //   [P] at (5,12,5)
    //   [I][I][I] at y=11, x=4..6, z=5
    //   [I] at (5,10,5)
    const getBlock = comptime makeGetBlock(&.{
        .{ .x = 5, .y = 12, .z = 5, .id = CARVED_PUMPKIN },
        .{ .x = 4, .y = 11, .z = 5, .id = IRON_BLOCK },
        .{ .x = 5, .y = 11, .z = 5, .id = IRON_BLOCK },
        .{ .x = 6, .y = 11, .z = 5, .id = IRON_BLOCK },
        .{ .x = 5, .y = 10, .z = 5, .id = IRON_BLOCK },
    });

    const result = checkIronGolemPattern(getBlock, 5, 12, 5);
    try testing.expect(result != null);

    const spawn = result.?;
    try testing.expectApproxEqAbs(@as(f32, 5.5), spawn.x, 0.01);
    try testing.expectApproxEqAbs(@as(f32, 10.0), spawn.y, 0.01);
    try testing.expectApproxEqAbs(@as(f32, 5.5), spawn.z, 0.01);
    try testing.expectEqual(@as(usize, 5), spawn.clear_blocks.len);
}

test "iron golem T-shape detected (arms along Z)" {
    // Arms along Z axis
    const getBlock = comptime makeGetBlock(&.{
        .{ .x = 5, .y = 12, .z = 5, .id = CARVED_PUMPKIN },
        .{ .x = 5, .y = 11, .z = 4, .id = IRON_BLOCK },
        .{ .x = 5, .y = 11, .z = 5, .id = IRON_BLOCK },
        .{ .x = 5, .y = 11, .z = 6, .id = IRON_BLOCK },
        .{ .x = 5, .y = 10, .z = 5, .id = IRON_BLOCK },
    });

    const result = checkIronGolemPattern(getBlock, 5, 12, 5);
    try testing.expect(result != null);
}

test "snow golem vertical pattern detected" {
    const getBlock = comptime makeGetBlock(&.{
        .{ .x = 3, .y = 7, .z = 3, .id = CARVED_PUMPKIN },
        .{ .x = 3, .y = 6, .z = 3, .id = SNOW_BLOCK },
        .{ .x = 3, .y = 5, .z = 3, .id = SNOW_BLOCK },
    });

    const result = checkSnowGolemPattern(getBlock, 3, 7, 3);
    try testing.expect(result != null);

    const spawn = result.?;
    try testing.expectApproxEqAbs(@as(f32, 3.5), spawn.x, 0.01);
    try testing.expectApproxEqAbs(@as(f32, 5.0), spawn.y, 0.01);
    try testing.expectApproxEqAbs(@as(f32, 3.5), spawn.z, 0.01);
    try testing.expectEqual(@as(usize, 3), spawn.clear_blocks.len);
}

test "wrong pattern rejected - missing iron block" {
    // Missing the body iron block at y=10
    const getBlock = comptime makeGetBlock(&.{
        .{ .x = 5, .y = 12, .z = 5, .id = CARVED_PUMPKIN },
        .{ .x = 4, .y = 11, .z = 5, .id = IRON_BLOCK },
        .{ .x = 5, .y = 11, .z = 5, .id = IRON_BLOCK },
        .{ .x = 6, .y = 11, .z = 5, .id = IRON_BLOCK },
        // no body block
    });

    const result = checkIronGolemPattern(getBlock, 5, 12, 5);
    try testing.expect(result == null);
}

test "wrong pattern rejected - snow with only one snow block" {
    const getBlock = comptime makeGetBlock(&.{
        .{ .x = 3, .y = 7, .z = 3, .id = CARVED_PUMPKIN },
        .{ .x = 3, .y = 6, .z = 3, .id = SNOW_BLOCK },
        // missing second snow block
    });

    const result = checkSnowGolemPattern(getBlock, 3, 7, 3);
    try testing.expect(result == null);
}

test "wrong pattern rejected - not a pumpkin" {
    const getBlock = comptime makeGetBlock(&.{
        .{ .x = 5, .y = 12, .z = 5, .id = IRON_BLOCK }, // iron instead of pumpkin
        .{ .x = 4, .y = 11, .z = 5, .id = IRON_BLOCK },
        .{ .x = 5, .y = 11, .z = 5, .id = IRON_BLOCK },
        .{ .x = 6, .y = 11, .z = 5, .id = IRON_BLOCK },
        .{ .x = 5, .y = 10, .z = 5, .id = IRON_BLOCK },
    });

    const result = checkIronGolemPattern(getBlock, 5, 12, 5);
    try testing.expect(result == null);
}

test "block clearing list contains correct positions for iron golem" {
    const getBlock = comptime makeGetBlock(&.{
        .{ .x = 5, .y = 12, .z = 5, .id = CARVED_PUMPKIN },
        .{ .x = 4, .y = 11, .z = 5, .id = IRON_BLOCK },
        .{ .x = 5, .y = 11, .z = 5, .id = IRON_BLOCK },
        .{ .x = 6, .y = 11, .z = 5, .id = IRON_BLOCK },
        .{ .x = 5, .y = 10, .z = 5, .id = IRON_BLOCK },
    });

    const spawn = checkIronGolemPattern(getBlock, 5, 12, 5).?;

    // Pumpkin position
    try testing.expectEqual(@as(i32, 5), spawn.clear_blocks[0].x);
    try testing.expectEqual(@as(i32, 12), spawn.clear_blocks[0].y);
    try testing.expectEqual(@as(i32, 5), spawn.clear_blocks[0].z);

    // Center arm
    try testing.expectEqual(@as(i32, 5), spawn.clear_blocks[1].x);
    try testing.expectEqual(@as(i32, 11), spawn.clear_blocks[1].y);

    // Left arm
    try testing.expectEqual(@as(i32, 4), spawn.clear_blocks[2].x);
    try testing.expectEqual(@as(i32, 11), spawn.clear_blocks[2].y);

    // Right arm
    try testing.expectEqual(@as(i32, 6), spawn.clear_blocks[3].x);
    try testing.expectEqual(@as(i32, 11), spawn.clear_blocks[3].y);

    // Body
    try testing.expectEqual(@as(i32, 5), spawn.clear_blocks[4].x);
    try testing.expectEqual(@as(i32, 10), spawn.clear_blocks[4].y);
}

test "block clearing list contains correct positions for snow golem" {
    const getBlock = comptime makeGetBlock(&.{
        .{ .x = 3, .y = 7, .z = 3, .id = CARVED_PUMPKIN },
        .{ .x = 3, .y = 6, .z = 3, .id = SNOW_BLOCK },
        .{ .x = 3, .y = 5, .z = 3, .id = SNOW_BLOCK },
    });

    const spawn = checkSnowGolemPattern(getBlock, 3, 7, 3).?;

    // Pumpkin
    try testing.expectEqual(@as(i32, 3), spawn.clear_blocks[0].x);
    try testing.expectEqual(@as(i32, 7), spawn.clear_blocks[0].y);

    // Upper snow
    try testing.expectEqual(@as(i32, 3), spawn.clear_blocks[1].x);
    try testing.expectEqual(@as(i32, 6), spawn.clear_blocks[1].y);

    // Lower snow
    try testing.expectEqual(@as(i32, 3), spawn.clear_blocks[2].x);
    try testing.expectEqual(@as(i32, 5), spawn.clear_blocks[2].y);
}

test "onBlockPlaced triggers iron golem" {
    const getBlock = comptime makeGetBlock(&.{
        .{ .x = 5, .y = 12, .z = 5, .id = CARVED_PUMPKIN },
        .{ .x = 4, .y = 11, .z = 5, .id = IRON_BLOCK },
        .{ .x = 5, .y = 11, .z = 5, .id = IRON_BLOCK },
        .{ .x = 6, .y = 11, .z = 5, .id = IRON_BLOCK },
        .{ .x = 5, .y = 10, .z = 5, .id = IRON_BLOCK },
    });

    const result = onBlockPlaced(CARVED_PUMPKIN, 5, 12, 5, getBlock);
    try testing.expect(result != null);
    try testing.expectEqual(GolemType.iron, result.?.golem_type);
}

test "onBlockPlaced triggers snow golem" {
    const getBlock = comptime makeGetBlock(&.{
        .{ .x = 3, .y = 7, .z = 3, .id = CARVED_PUMPKIN },
        .{ .x = 3, .y = 6, .z = 3, .id = SNOW_BLOCK },
        .{ .x = 3, .y = 5, .z = 3, .id = SNOW_BLOCK },
    });

    const result = onBlockPlaced(CARVED_PUMPKIN, 3, 7, 3, getBlock);
    try testing.expect(result != null);
    try testing.expectEqual(GolemType.snow, result.?.golem_type);
}

test "onBlockPlaced ignores non-pumpkin blocks" {
    const getBlock = comptime makeGetBlock(&.{
        .{ .x = 5, .y = 12, .z = 5, .id = IRON_BLOCK },
    });

    const result = onBlockPlaced(IRON_BLOCK, 5, 12, 5, getBlock);
    try testing.expect(result == null);
}
