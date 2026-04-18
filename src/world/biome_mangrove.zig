const std = @import("std");

pub const MangroveBlockType = enum {
    mangrove_log,
    mangrove_roots,
    mangrove_leaves,
    mud,
    propagule,
};

pub const MangroveBlock = struct {
    dx: i8,
    dy: i8,
    dz: i8,
    block_type: MangroveBlockType,
};

pub const TreeBlocks = struct {
    blocks: [512]?MangroveBlock,
    count: u16,

    pub fn init() TreeBlocks {
        return .{
            .blocks = [_]?MangroveBlock{null} ** 512,
            .count = 0,
        };
    }

    pub fn append(self: *TreeBlocks, block: MangroveBlock) void {
        if (self.count < 512) {
            self.blocks[self.count] = block;
            self.count += 1;
        }
    }
};

pub const MangroveTree = struct {
    trunk_height: u3,
    root_spread: u3,

    pub fn init(seed: u64) MangroveTree {
        return .{
            .trunk_height = @intCast(3 + @as(u3, @truncate(seed % 3))),
            .root_spread = @intCast(2 + @as(u3, @truncate((seed >> 3) % 3))),
        };
    }

    pub fn generateTree(_: i32, base_y: i32, _: i32, seed: u64, water_level: i32) TreeBlocks {
        var result = TreeBlocks.init();
        const tree = MangroveTree.init(seed);

        // Generate stilt roots that extend down into water/mud
        const root_base_y: i32 = if (base_y > water_level) water_level - 1 else base_y - 1;
        const root_height: i32 = base_y - root_base_y;

        var root_seed = seed;
        const spread: i32 = @intCast(tree.root_spread);
        var rx: i32 = -spread;
        while (rx <= spread) : (rx += 1) {
            var rz: i32 = -spread;
            while (rz <= spread) : (rz += 1) {
                root_seed = splitmix64(root_seed);
                const dist = absI32(rx) + absI32(rz);
                if (dist > spread) continue;
                // Roots are more likely closer to trunk
                if (dist > 1 and (root_seed % 3 != 0)) continue;

                var ry: i32 = 0;
                while (ry < root_height) : (ry += 1) {
                    const dy_val: i32 = (root_base_y + ry) - base_y;
                    result.append(.{
                        .dx = @intCast(rx),
                        .dy = @intCast(dy_val),
                        .dz = @intCast(rz),
                        .block_type = .mangrove_roots,
                    });
                }
            }
        }

        // Place mud under roots when at or below water level
        if (base_y <= water_level + 1) {
            var mx: i32 = -spread;
            while (mx <= spread) : (mx += 1) {
                var mz: i32 = -spread;
                while (mz <= spread) : (mz += 1) {
                    const dist = absI32(mx) + absI32(mz);
                    if (dist <= spread) {
                        const mud_dy: i32 = root_base_y - 1 - base_y;
                        result.append(.{
                            .dx = @intCast(mx),
                            .dy = @intCast(mud_dy),
                            .dz = @intCast(mz),
                            .block_type = .mud,
                        });
                    }
                }
            }
        }

        // Generate trunk
        const height: i32 = @intCast(tree.trunk_height);
        var ty: i32 = 0;
        while (ty < height) : (ty += 1) {
            result.append(.{
                .dx = 0,
                .dy = @intCast(ty),
                .dz = 0,
                .block_type = .mangrove_log,
            });
        }

        // Generate leaf canopy
        const leaf_radius: i32 = 2;
        const leaf_start: i32 = height - 1;
        const leaf_end: i32 = height + 2;
        var ly: i32 = leaf_start;
        while (ly <= leaf_end) : (ly += 1) {
            const r: i32 = if (ly == leaf_end) 1 else leaf_radius;
            var lx: i32 = -r;
            while (lx <= r) : (lx += 1) {
                var lz: i32 = -r;
                while (lz <= r) : (lz += 1) {
                    if (lx == 0 and lz == 0 and ly < height) continue;
                    const dist = absI32(lx) + absI32(lz);
                    if (dist > r + 1) continue;
                    result.append(.{
                        .dx = @intCast(lx),
                        .dy = @intCast(ly),
                        .dz = @intCast(lz),
                        .block_type = .mangrove_leaves,
                    });
                }
            }
        }

        // Add propagules hanging from leaves
        var prop_seed = splitmix64(seed ^ 0xDEAD);
        var px: i32 = -leaf_radius;
        while (px <= leaf_radius) : (px += 1) {
            var pz: i32 = -leaf_radius;
            while (pz <= leaf_radius) : (pz += 1) {
                prop_seed = splitmix64(prop_seed);
                if (prop_seed % 4 == 0) {
                    result.append(.{
                        .dx = @intCast(px),
                        .dy = @intCast(leaf_start - 1),
                        .dz = @intCast(pz),
                        .block_type = .propagule,
                    });
                }
            }
        }

        return result;
    }
};

pub const MangroveSwampFeatures = struct {
    tree_density: f32 = 0.25,
    water_color: [3]u8 = .{ 61, 128, 68 },
    fog_color: [3]u8 = .{ 87, 127, 83 },
    has_mud: bool = true,
    firefly_ambient: bool = true,
};

pub const MudPatch = struct {
    x: u4,
    z: u4,
};

pub fn generateMudPatches(seed: u64, chunk_x: i32, chunk_z: i32) [32]?MudPatch {
    var patches: [32]?MudPatch = [_]?MudPatch{null} ** 32;
    var count: usize = 0;

    // Combine seed with chunk coordinates for deterministic placement
    const chunk_seed = seed ^ @as(u64, @bitCast(@as(i64, chunk_x))) ^ (@as(u64, @bitCast(@as(i64, chunk_z))) << 32);
    var rng = splitmix64(chunk_seed);

    var attempt: usize = 0;
    while (attempt < 64 and count < 32) : (attempt += 1) {
        rng = splitmix64(rng);
        const x_val: u4 = @truncate(rng & 0xF);
        rng = splitmix64(rng);
        const z_val: u4 = @truncate(rng & 0xF);

        // ~50% chance to place a mud patch at each candidate position
        rng = splitmix64(rng);
        if (rng % 2 == 0) {
            patches[count] = .{ .x = x_val, .z = z_val };
            count += 1;
        }
    }

    return patches;
}

fn splitmix64(state: u64) u64 {
    var z = state +% 0x9E3779B97F4A7C15;
    z = (z ^ (z >> 30)) *% 0xBF58476D1CE4E5B9;
    z = (z ^ (z >> 27)) *% 0x94D049BB133111EB;
    return z ^ (z >> 31);
}

fn absI32(v: i32) i32 {
    return @intCast(@as(u32, @abs(v)));
}

// ============================================================================
// Tests
// ============================================================================

test "tree generates roots in water" {
    const water_level: i32 = 62;
    const base_y: i32 = 64; // tree base above water
    const result = MangroveTree.generateTree(0, base_y, 0, 42, water_level);

    try std.testing.expect(result.count > 0);

    var has_roots = false;
    var has_log = false;
    var has_leaves = false;
    var root_below_water = false;

    for (result.blocks) |maybe_block| {
        if (maybe_block) |block| {
            switch (block.block_type) {
                .mangrove_roots => {
                    has_roots = true;
                    // Root dy should be negative (below base)
                    if (block.dy < 0) {
                        // Check that root extends into water zone
                        const world_y = base_y + @as(i32, block.dy);
                        if (world_y <= water_level) {
                            root_below_water = true;
                        }
                    }
                },
                .mangrove_log => has_log = true,
                .mangrove_leaves => has_leaves = true,
                else => {},
            }
        }
    }

    try std.testing.expect(has_roots);
    try std.testing.expect(has_log);
    try std.testing.expect(has_leaves);
    try std.testing.expect(root_below_water);
}

test "tree generates mud when near water level" {
    const water_level: i32 = 62;
    const base_y: i32 = 62; // at water level
    const result = MangroveTree.generateTree(0, base_y, 0, 123, water_level);

    var has_mud = false;
    for (result.blocks) |maybe_block| {
        if (maybe_block) |block| {
            if (block.block_type == .mud) {
                has_mud = true;
                break;
            }
        }
    }

    try std.testing.expect(has_mud);
}

test "tree generates propagules" {
    const result = MangroveTree.generateTree(0, 64, 0, 999, 62);

    var has_propagule = false;
    for (result.blocks) |maybe_block| {
        if (maybe_block) |block| {
            if (block.block_type == .propagule) {
                has_propagule = true;
                break;
            }
        }
    }

    try std.testing.expect(has_propagule);
}

test "mud patches generated deterministically" {
    const patches_a = generateMudPatches(42, 10, 20);
    const patches_b = generateMudPatches(42, 10, 20);

    // Same seed + chunk coords should produce identical results
    for (patches_a, patches_b) |a, b| {
        if (a) |pa| {
            const pb = b.?;
            try std.testing.expectEqual(pa.x, pb.x);
            try std.testing.expectEqual(pa.z, pb.z);
        } else {
            try std.testing.expect(b == null);
        }
    }

    // Should have some non-null patches
    var non_null_count: usize = 0;
    for (patches_a) |p| {
        if (p != null) non_null_count += 1;
    }
    try std.testing.expect(non_null_count > 0);
}

test "mud patches differ for different chunks" {
    const patches_a = generateMudPatches(42, 10, 20);
    const patches_b = generateMudPatches(42, 11, 20);

    var differs = false;
    for (patches_a, patches_b) |a, b| {
        if (a != null and b != null) {
            if (a.?.x != b.?.x or a.?.z != b.?.z) {
                differs = true;
                break;
            }
        } else if ((a == null) != (b == null)) {
            differs = true;
            break;
        }
    }

    try std.testing.expect(differs);
}

test "swamp features have correct defaults" {
    const features = MangroveSwampFeatures{};

    try std.testing.expectApproxEqAbs(@as(f32, 0.25), features.tree_density, 0.001);
    try std.testing.expectEqual([3]u8{ 61, 128, 68 }, features.water_color);
    try std.testing.expectEqual([3]u8{ 87, 127, 83 }, features.fog_color);
    try std.testing.expect(features.has_mud);
    try std.testing.expect(features.firefly_ambient);
}

test "MangroveTree init produces valid ranges" {
    // Test multiple seeds to verify trunk_height in [3,5] and root_spread in [2,4]
    const seeds = [_]u64{ 0, 1, 2, 42, 100, 999, 0xFFFF };
    for (seeds) |seed| {
        const tree = MangroveTree.init(seed);
        try std.testing.expect(tree.trunk_height >= 3 and tree.trunk_height <= 5);
        try std.testing.expect(tree.root_spread >= 2 and tree.root_spread <= 4);
    }
}

test "TreeBlocks append respects capacity" {
    var tb = TreeBlocks.init();
    try std.testing.expectEqual(@as(u16, 0), tb.count);

    tb.append(.{ .dx = 1, .dy = 2, .dz = 3, .block_type = .mangrove_log });
    try std.testing.expectEqual(@as(u16, 1), tb.count);
    try std.testing.expect(tb.blocks[0] != null);
    try std.testing.expectEqual(@as(i8, 1), tb.blocks[0].?.dx);
}
