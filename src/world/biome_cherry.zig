const std = @import("std");

pub const CherryBlockType = enum {
    cherry_log,
    cherry_leaves,
    pink_petals,
};

pub const TreeBlock = struct {
    dx: i8,
    dy: i8,
    dz: i8,
    block_type: CherryBlockType,
};

pub const TreeBlocks = struct {
    blocks: [256]?TreeBlock,
    count: u16,

    pub fn init() TreeBlocks {
        return .{
            .blocks = [_]?TreeBlock{null} ** 256,
            .count = 0,
        };
    }

    pub fn append(self: *TreeBlocks, block: TreeBlock) void {
        if (self.count < 256) {
            self.blocks[self.count] = block;
            self.count += 1;
        }
    }
};

pub const CherryTree = struct {
    trunk_height: u3,
    canopy_radius: u3,

    pub fn fromSeed(seed: u64) CherryTree {
        var rng = splitmix64(seed);
        const trunk_height: u3 = @intCast(4 + (rng % 4)); // 4-7
        rng = splitmix64(rng);
        const canopy_radius: u3 = @intCast(4 + (rng % 3)); // 4-6
        return .{
            .trunk_height = trunk_height,
            .canopy_radius = canopy_radius,
        };
    }
};

pub const PetalCluster = struct {
    x: u4,
    z: u4,
    count: u2,
};

pub const BiomeFeatures = struct {
    tree_density: f32,
    has_pink_petals: bool,
    grass_color: [3]u8,
    foliage_color: [3]u8,
    base_height: f64,
    height_scale: f64,
};

pub fn getCherryGroveFeatures() BiomeFeatures {
    return .{
        .tree_density = 0.15,
        .has_pink_petals = true,
        .grass_color = .{ 124, 189, 107 },
        .foliage_color = .{ 182, 219, 97 },
        .base_height = 8.0,
        .height_scale = 1.5,
    };
}

fn splitmix64(seed: u64) u64 {
    var s = seed +% 0x9e3779b97f4a7c15;
    s = (s ^ (s >> 30)) *% 0xbf58476d1ce4e5b9;
    s = (s ^ (s >> 27)) *% 0x94d049bb133111eb;
    return s ^ (s >> 31);
}

pub fn generateTree(base_x: i32, base_y: i32, base_z: i32, seed: u64) TreeBlocks {
    const tree = CherryTree.fromSeed(seed);
    var result = TreeBlocks.init();

    const trunk_h: i8 = @intCast(tree.trunk_height);
    const radius: i8 = @intCast(tree.canopy_radius);

    for (0..tree.trunk_height) |y| {
        result.append(.{
            .dx = @intCast(base_x),
            .dy = @intCast(base_y + @as(i32, @intCast(y))),
            .dz = @intCast(base_z),
            .block_type = .cherry_log,
        });
    }

    const canopy_center_y = trunk_h;
    const r_sq = @as(i16, radius) * @as(i16, radius);
    const shell_inner = r_sq - @as(i16, radius) * 2;
    var cy: i8 = -radius;
    while (cy <= radius) : (cy += 1) {
        var cx: i8 = -radius;
        while (cx <= radius) : (cx += 1) {
            var cz: i8 = -radius;
            while (cz <= radius) : (cz += 1) {
                const dist_sq = @as(i16, cx) * @as(i16, cx) +
                    @as(i16, cy) * @as(i16, cy) +
                    @as(i16, cz) * @as(i16, cz);
                if (dist_sq <= r_sq and dist_sq > shell_inner) {
                    const leaf_seed = splitmix64(seed +% @as(u64, @bitCast(@as(i64, cx) *% 31 +% @as(i64, cz) *% 17 +% @as(i64, cy) *% 7)));
                    if (leaf_seed % 4 != 0) {
                        result.append(.{
                            .dx = @intCast(base_x + @as(i32, cx)),
                            .dy = @intCast(base_y + @as(i32, canopy_center_y) + @as(i32, cy)),
                            .dz = @intCast(base_z + @as(i32, cz)),
                            .block_type = .cherry_leaves,
                        });
                    }
                }
            }
        }
    }

    return result;
}

pub fn generatePetalClusters(seed: u64, chunk_x: i32, chunk_z: i32) [64]?PetalCluster {
    var clusters = [_]?PetalCluster{null} ** 64;
    var rng = splitmix64(seed +% @as(u64, @bitCast(@as(i64, chunk_x) *% 7919 +% @as(i64, chunk_z) *% 6271)));

    for (0..64) |i| {
        rng = splitmix64(rng);
        if (rng % 4 == 0) {
            const x_val = splitmix64(rng +% @as(u64, i));
            const z_val = splitmix64(x_val);
            const count_val = splitmix64(z_val);
            clusters[i] = .{
                .x = @intCast(x_val % 16),
                .z = @intCast(z_val % 16),
                .count = @intCast(count_val % 4),
            };
        }
    }

    return clusters;
}

test "generateTree produces trunk and canopy blocks" {
    const tree_blocks = generateTree(0, 0, 0, 42);

    try std.testing.expect(tree_blocks.count > 0);

    // First blocks should be trunk (cherry_log)
    const first = tree_blocks.blocks[0].?;
    try std.testing.expectEqual(CherryBlockType.cherry_log, first.block_type);

    // Count logs and leaves
    var logs: u16 = 0;
    var leaves: u16 = 0;
    for (0..tree_blocks.count) |i| {
        const b = tree_blocks.blocks[i].?;
        switch (b.block_type) {
            .cherry_log => logs += 1,
            .cherry_leaves => leaves += 1,
            .pink_petals => {},
        }
    }

    // Trunk height is 4-7, so at least 4 logs
    try std.testing.expect(logs >= 4);
    try std.testing.expect(logs <= 7);
    // Canopy should produce some leaves
    try std.testing.expect(leaves > 0);
}

test "generateTree is deterministic for the same seed" {
    const a = generateTree(0, 0, 0, 123);
    const b = generateTree(0, 0, 0, 123);

    try std.testing.expectEqual(a.count, b.count);
    for (0..a.count) |i| {
        const ba = a.blocks[i].?;
        const bb = b.blocks[i].?;
        try std.testing.expectEqual(ba.dx, bb.dx);
        try std.testing.expectEqual(ba.dy, bb.dy);
        try std.testing.expectEqual(ba.dz, bb.dz);
        try std.testing.expectEqual(ba.block_type, bb.block_type);
    }
}

test "CherryTree.fromSeed produces values in valid range" {
    const seeds = [_]u64{ 0, 1, 42, 999, 0xdeadbeef, 0xffffffffffffffff };
    for (seeds) |s| {
        const tree = CherryTree.fromSeed(s);
        try std.testing.expect(tree.trunk_height >= 4 and tree.trunk_height <= 7);
        try std.testing.expect(tree.canopy_radius >= 4 and tree.canopy_radius <= 6);
    }
}

test "getCherryGroveFeatures returns correct defaults" {
    const features = getCherryGroveFeatures();

    try std.testing.expectApproxEqAbs(@as(f32, 0.15), features.tree_density, 0.001);
    try std.testing.expect(features.has_pink_petals);
    try std.testing.expectEqual([3]u8{ 124, 189, 107 }, features.grass_color);
    try std.testing.expectEqual([3]u8{ 182, 219, 97 }, features.foliage_color);
    try std.testing.expectApproxEqAbs(@as(f64, 8.0), features.base_height, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 1.5), features.height_scale, 0.001);
}

test "generatePetalClusters produces deterministic results" {
    const a = generatePetalClusters(42, 0, 0);
    const b = generatePetalClusters(42, 0, 0);

    for (0..64) |i| {
        if (a[i]) |ca| {
            const cb = b[i].?;
            try std.testing.expectEqual(ca.x, cb.x);
            try std.testing.expectEqual(ca.z, cb.z);
            try std.testing.expectEqual(ca.count, cb.count);
        } else {
            try std.testing.expectEqual(@as(?PetalCluster, null), b[i]);
        }
    }
}

test "generatePetalClusters has some non-null entries" {
    const clusters = generatePetalClusters(77, 3, 5);
    var non_null: u32 = 0;
    for (0..64) |i| {
        if (clusters[i] != null) non_null += 1;
    }
    try std.testing.expect(non_null > 0);
    try std.testing.expect(non_null < 64);
}

test "generatePetalClusters varies with chunk coordinates" {
    const a = generatePetalClusters(42, 0, 0);
    const b = generatePetalClusters(42, 1, 0);

    var differ = false;
    for (0..64) |i| {
        const a_null = a[i] == null;
        const b_null = b[i] == null;
        if (a_null != b_null) {
            differ = true;
            break;
        }
        if (!a_null and !b_null) {
            if (a[i].?.x != b[i].?.x or a[i].?.z != b[i].?.z) {
                differ = true;
                break;
            }
        }
    }
    try std.testing.expect(differ);
}
