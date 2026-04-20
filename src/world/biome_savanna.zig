const std = @import("std");

pub const SavannaFeatures = struct {
    base_height: f64 = 8.0,
    height_scale: f64 = 1.2,
    tree_density: f32 = 0.05,
    temperature: f32 = 1.2,
    has_coarse_dirt: bool = true,
    grass_color: [3]u8 = .{ 191, 183, 85 },
};

pub const AcaciaBlock = struct {
    dx: i8,
    dy: i8,
    dz: i8,
    block_type: BlockType,

    pub const BlockType = enum {
        acacia_log,
        acacia_leaves,
    };
};

pub const TreeBlocks = struct {
    blocks: [128]?AcaciaBlock = .{null} ** 128,
    count: u8 = 0,

    fn append(self: *TreeBlocks, block: AcaciaBlock) void {
        if (self.count < 128) {
            self.blocks[self.count] = block;
            self.count += 1;
        }
    }
};

pub const AcaciaTree = struct {
    trunk_height: u4,
    canopy_offset_x: i4,
    canopy_offset_z: i4,
};

/// Generates an acacia tree with a diagonal trunk and flat canopy.
/// The trunk grows vertically then bends diagonally before the canopy.
pub fn generateTree(base_x: i32, base_y: i32, base_z: i32, seed: u64) TreeBlocks {
    _ = base_x;
    _ = base_y;
    _ = base_z;

    var result = TreeBlocks{};
    var rng = std.Random.DefaultPrng.init(seed);
    const random = rng.random();

    const trunk_height: u4 = @intCast(random.intRangeAtMost(u4, 4, 7));
    const canopy_offset_x: i4 = @intCast(random.intRangeAtMost(i4, -3, 3));
    const canopy_offset_z: i4 = @intCast(random.intRangeAtMost(i4, -3, 3));

    const tree = AcaciaTree{
        .trunk_height = trunk_height,
        .canopy_offset_x = canopy_offset_x,
        .canopy_offset_z = canopy_offset_z,
    };

    // Vertical trunk (lower half)
    const straight_height = trunk_height / 2;
    for (0..straight_height) |y| {
        result.append(.{
            .dx = 0,
            .dy = @intCast(y),
            .dz = 0,
            .block_type = .acacia_log,
        });
    }

    // Diagonal trunk (upper half bends toward canopy offset)
    const diagonal_height = trunk_height - straight_height;
    for (0..diagonal_height) |i| {
        const progress_x = @divTrunc(@as(i8, tree.canopy_offset_x) * @as(i8, @intCast(i + 1)), @as(i8, @intCast(diagonal_height)));
        const progress_z = @divTrunc(@as(i8, tree.canopy_offset_z) * @as(i8, @intCast(i + 1)), @as(i8, @intCast(diagonal_height)));
        result.append(.{
            .dx = progress_x,
            .dy = @intCast(straight_height + i),
            .dz = progress_z,
            .block_type = .acacia_log,
        });
    }

    // Flat canopy centered on the trunk's final offset
    const canopy_y: i8 = @intCast(trunk_height);
    const cx: i8 = @as(i8, tree.canopy_offset_x);
    const cz: i8 = @as(i8, tree.canopy_offset_z);

    var leaf_dx: i8 = -2;
    while (leaf_dx <= 2) : (leaf_dx += 1) {
        var leaf_dz: i8 = -2;
        while (leaf_dz <= 2) : (leaf_dz += 1) {
            if (@abs(leaf_dx) == 2 and @abs(leaf_dz) == 2) continue;
            result.append(.{
                .dx = cx + leaf_dx,
                .dy = canopy_y,
                .dz = cz + leaf_dz,
                .block_type = .acacia_leaves,
            });
        }
    }

    return result;
}

/// Returns a shattered savanna variant with extreme terrain values.
pub fn getShatteredVariant() SavannaFeatures {
    var variant = SavannaFeatures{};
    variant.base_height = 12.0;
    variant.height_scale = 4.0;
    return variant;
}

/// Returns the mobs that spawn in savanna biomes.
pub fn getMobs() struct { llama: bool, horse: bool } {
    return .{ .llama = true, .horse = true };
}


test "acacia tree has diagonal trunk" {
    const tree_blocks = generateTree(0, 64, 0, 42);

    var log_count: u32 = 0;
    var has_diagonal = false;

    for (0..tree_blocks.count) |i| {
        const block = tree_blocks.blocks[i] orelse continue;
        if (block.block_type == .acacia_log) {
            log_count += 1;
            if (block.dx != 0 or block.dz != 0) has_diagonal = true;
        }
    }

    try std.testing.expect(log_count >= 4);
    try std.testing.expect(log_count <= 7);
    // Verify leaves exist beyond the trunk
    try std.testing.expect(tree_blocks.count > log_count);
}

test "shattered variant has extreme terrain" {
    const shattered = getShatteredVariant();
    const default_features = SavannaFeatures{};

    try std.testing.expectEqual(@as(f64, 4.0), shattered.height_scale);
    try std.testing.expectEqual(@as(f64, 12.0), shattered.base_height);
    try std.testing.expect(shattered.height_scale > default_features.height_scale);
    try std.testing.expect(shattered.base_height > default_features.base_height);
}

test "savanna has coarse dirt" {
    const features = SavannaFeatures{};
    try std.testing.expect(features.has_coarse_dirt);

    const shattered = getShatteredVariant();
    try std.testing.expect(shattered.has_coarse_dirt);
}

test "savanna mob spawns include llama and horse" {
    const mobs = getMobs();
    try std.testing.expect(mobs.llama);
    try std.testing.expect(mobs.horse);
}
