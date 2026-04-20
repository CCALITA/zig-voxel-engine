const std = @import("std");

pub const JungleBlockType = enum {
    jungle_log,
    jungle_leaves,
    vine,
    cocoa_bean,
};

pub const JungleBlock = struct {
    dx: i8,
    dy: i8,
    dz: i8,
    block_type: JungleBlockType,
};

pub const TreeBlocks = struct {
    blocks: [512]?JungleBlock,
    count: u16,

    pub fn init() TreeBlocks {
        return .{
            .blocks = [_]?JungleBlock{null} ** 512,
            .count = 0,
        };
    }

    fn append(self: *TreeBlocks, block: JungleBlock) void {
        if (self.count < 512) {
            self.blocks[self.count] = block;
            self.count += 1;
        }
    }
};

pub const JungleTree = struct {
    trunk_height: u5,
    is_large: bool,
    vine_density: f32,

    pub fn create(seed: u64, large: bool) JungleTree {
        const height = heightFromSeed(seed);
        return .{
            .trunk_height = height,
            .is_large = large,
            .vine_density = 0.3,
        };
    }

    fn heightFromSeed(seed: u64) u5 {
        // Range: 12..20
        const variation: u8 = @truncate(seed % 9);
        return @intCast(12 + variation);
    }
};

fn simpleHash(a: u64, b: u64) u64 {
    var h = a *% 6364136223846793005 +% b;
    h ^= h >> 33;
    h *%= 0xff51afd7ed558ccd;
    h ^= h >> 33;
    return h;
}

fn hashToFloat(h: u64) f32 {
    return @as(f32, @floatFromInt(h >> 40)) / 16777216.0;
}

pub fn generateTree(base_x: i32, base_y: i32, base_z: i32, seed: u64, large: bool) TreeBlocks {
    _ = base_x;
    _ = base_y;
    _ = base_z;

    const tree = JungleTree.create(seed, large);
    var result = TreeBlocks.init();
    const height: i8 = @intCast(tree.trunk_height);
    const trunk_width: i8 = if (large) 2 else 1;

    // Trunk
    var y: i8 = 0;
    while (y < height) : (y += 1) {
        var tx: i8 = 0;
        while (tx < trunk_width) : (tx += 1) {
            var tz: i8 = 0;
            while (tz < trunk_width) : (tz += 1) {
                result.append(.{ .dx = tx, .dy = y, .dz = tz, .block_type = .jungle_log });
            }
        }
    }

    // Canopy (leaves)
    const canopy_base = height - 3;
    const canopy_radius: i8 = if (large) 4 else 3;
    var cy: i8 = canopy_base;
    while (cy <= height + 1) : (cy += 1) {
        const layer_radius = if (cy <= height) canopy_radius else canopy_radius - 1;
        var cx: i8 = -layer_radius;
        while (cx <= layer_radius) : (cx += 1) {
            var cz: i8 = -layer_radius;
            while (cz <= layer_radius) : (cz += 1) {
                const dist_sq = @as(i16, cx) * @as(i16, cx) + @as(i16, cz) * @as(i16, cz);
                const r16: i16 = @as(i16, layer_radius);
                if (dist_sq <= r16 * r16) {
                    const is_trunk = cx >= 0 and cx < trunk_width and cz >= 0 and cz < trunk_width and cy < height;
                    if (!is_trunk) {
                        result.append(.{ .dx = cx, .dy = cy, .dz = cz, .block_type = .jungle_leaves });
                    }
                }
            }
        }
    }

    // Vines along trunk
    var vy: i8 = 1;
    while (vy < height) : (vy += 1) {
        const vy_u8: u8 = @bitCast(vy);
        const vine_hash = simpleHash(seed, @as(u64, vy_u8));
        if (hashToFloat(vine_hash) < tree.vine_density) {
            result.append(.{ .dx = -1, .dy = vy, .dz = 0, .block_type = .vine });
        }
        const vine_hash2 = simpleHash(seed +% 1, @as(u64, vy_u8));
        if (hashToFloat(vine_hash2) < tree.vine_density) {
            result.append(.{ .dx = trunk_width, .dy = vy, .dz = 0, .block_type = .vine });
        }
    }

    // Cocoa beans on lower trunk
    const cocoa_hash = simpleHash(seed, 0xc0c0a);
    if (hashToFloat(cocoa_hash) < 0.5) {
        result.append(.{ .dx = -1, .dy = 3, .dz = 0, .block_type = .cocoa_bean });
    }

    return result;
}

pub const JungleBiomeFeatures = struct {
    tree_density: f32,
    melon_chance: f32,
    cocoa_chance: f32,
    bamboo_variant: bool,
    temperature: f32,
    humidity: f32,
};

pub fn getFeatures(is_bamboo_jungle: bool) JungleBiomeFeatures {
    var features = JungleBiomeFeatures{
        .tree_density = 0.3,
        .melon_chance = 0.02,
        .cocoa_chance = 0.1,
        .bamboo_variant = false,
        .temperature = 0.95,
        .humidity = 0.9,
    };
    if (is_bamboo_jungle) {
        features.tree_density = 0.15;
        features.bamboo_variant = true;
    }
    return features;
}

pub const VegPlacement = struct {
    x: i32,
    z: i32,
    veg_type: VegetationType,
};

pub const VegetationType = enum {
    jungle_tree,
    large_jungle_tree,
    melon,
    bamboo,
    fern,
};

pub fn generateVegetation(seed: u64, cx: i32, cz: i32) [64]?VegPlacement {
    var placements = [_]?VegPlacement{null} ** 64;
    var idx: usize = 0;

    const features = getFeatures(false);
    const base_x = cx * 16;
    const base_z = cz * 16;

    var lx: u32 = 0;
    while (lx < 16) : (lx += 1) {
        var lz: u32 = 0;
        while (lz < 16) : (lz += 1) {
            if (idx >= 64) return placements;

            const pos_seed = simpleHash(seed, @as(u64, lx) * 16 + @as(u64, lz));
            const roll = hashToFloat(pos_seed);
            const wx = base_x + @as(i32, @intCast(lx));
            const wz = base_z + @as(i32, @intCast(lz));

            if (roll < features.tree_density * 0.1) {
                const large_roll = hashToFloat(simpleHash(pos_seed, 0x1a4e));
                const veg_type: VegetationType = if (large_roll < 0.2) .large_jungle_tree else .jungle_tree;
                placements[idx] = .{
                    .x = wx,
                    .z = wz,
                    .veg_type = veg_type,
                };
                idx += 1;
            } else if (roll < features.tree_density * 0.1 + features.melon_chance) {
                placements[idx] = .{
                    .x = wx,
                    .z = wz,
                    .veg_type = .melon,
                };
                idx += 1;
            }
        }
    }

    return placements;
}

test "large tree generates 2x2 trunk" {
    const result = generateTree(0, 64, 0, 42, true);

    var has_0_0 = false;
    var has_1_0 = false;
    var has_0_1 = false;
    var has_1_1 = false;

    for (result.blocks) |maybe_block| {
        const block = maybe_block orelse continue;
        if (block.block_type != .jungle_log) continue;
        if (block.dy == 0) {
            if (block.dx == 0 and block.dz == 0) has_0_0 = true;
            if (block.dx == 1 and block.dz == 0) has_1_0 = true;
            if (block.dx == 0 and block.dz == 1) has_0_1 = true;
            if (block.dx == 1 and block.dz == 1) has_1_1 = true;
        }
    }

    try std.testing.expect(has_0_0);
    try std.testing.expect(has_1_0);
    try std.testing.expect(has_0_1);
    try std.testing.expect(has_1_1);
}

test "small tree has 1x1 trunk" {
    const result = generateTree(0, 64, 0, 99, false);

    for (result.blocks) |maybe_block| {
        const block = maybe_block orelse continue;
        if (block.block_type == .jungle_log) {
            try std.testing.expect(block.dx == 0);
            try std.testing.expect(block.dz == 0);
        }
    }
}

test "vine generation produces vine blocks" {
    const result = generateTree(0, 64, 0, 12345, false);

    var vine_count: u32 = 0;
    for (result.blocks) |maybe_block| {
        const block = maybe_block orelse continue;
        if (block.block_type == .vine) {
            vine_count += 1;
        }
    }

    try std.testing.expect(vine_count > 0);
}

test "cocoa beans can appear on tree" {
    // Try multiple seeds until we find one that produces a cocoa bean
    var found_cocoa = false;
    var s: u64 = 0;
    while (s < 100) : (s += 1) {
        const result = generateTree(0, 64, 0, s, false);
        for (result.blocks) |maybe_block| {
            const block = maybe_block orelse continue;
            if (block.block_type == .cocoa_bean) {
                found_cocoa = true;
                break;
            }
        }
        if (found_cocoa) break;
    }

    try std.testing.expect(found_cocoa);
}

test "bamboo variant features" {
    const bamboo = getFeatures(true);
    const normal = getFeatures(false);

    try std.testing.expect(bamboo.bamboo_variant);
    try std.testing.expect(!normal.bamboo_variant);
    try std.testing.expect(bamboo.tree_density < normal.tree_density);
    try std.testing.expectApproxEqAbs(bamboo.temperature, 0.95, 0.01);
    try std.testing.expectApproxEqAbs(bamboo.humidity, 0.9, 0.01);
}

test "vegetation density produces placements" {
    // Try multiple seeds to find one that produces placements
    var found = false;
    var test_seed: u64 = 0;
    while (test_seed < 100) : (test_seed += 1) {
        const veg = generateVegetation(test_seed, 0, 0);
        var count: u32 = 0;
        for (veg) |maybe_v| {
            if (maybe_v != null) count += 1;
        }
        if (count > 0) {
            found = true;
            try std.testing.expect(count <= 64);
            break;
        }
    }

    try std.testing.expect(found);
}

test "vegetation placement coordinates within chunk" {
    const veg = generateVegetation(42, 3, 5);
    const base_x: i32 = 3 * 16;
    const base_z: i32 = 5 * 16;

    for (veg) |maybe_v| {
        const v = maybe_v orelse continue;
        try std.testing.expect(v.x >= base_x and v.x < base_x + 16);
        try std.testing.expect(v.z >= base_z and v.z < base_z + 16);
    }
}

test "tree height within valid range 12-20" {
    var s: u64 = 0;
    while (s < 200) : (s += 1) {
        const tree = JungleTree.create(s, false);
        try std.testing.expect(tree.trunk_height >= 12);
        try std.testing.expect(tree.trunk_height <= 20);
    }
}

test "default vine density is 0.3" {
    const tree = JungleTree.create(0, false);
    try std.testing.expectApproxEqAbs(tree.vine_density, 0.3, 0.01);
}

test "default biome features" {
    const f = getFeatures(false);
    try std.testing.expectApproxEqAbs(f.tree_density, 0.3, 0.01);
    try std.testing.expectApproxEqAbs(f.melon_chance, 0.02, 0.01);
    try std.testing.expectApproxEqAbs(f.cocoa_chance, 0.1, 0.01);
}
