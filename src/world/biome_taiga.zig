const std = @import("std");

pub const TaigaFeatures = struct {
    base_height: f64 = 8.0,
    height_scale: f64 = 1.5,
    tree_density: f32 = 0.2,
    temperature: f32 = 0.25,
    is_snowy: bool = false,
    snow_layers: bool = false,
    has_sweet_berries: bool = true,
    grass_color: [3]u8 = .{ 134, 167, 97 },
};

pub const SpruceBlock = struct {
    dx: i8,
    dy: i8,
    dz: i8,
    block_type: BlockType,

    pub const BlockType = enum {
        spruce_log,
        spruce_leaves,
        snow_layer,
    };
};

pub const TreeBlocks = struct {
    blocks: [256]?SpruceBlock,
    count: u16,

    pub fn init() TreeBlocks {
        return .{
            .blocks = [_]?SpruceBlock{null} ** 256,
            .count = 0,
        };
    }

    pub fn append(self: *TreeBlocks, block: SpruceBlock) void {
        if (self.count < 256) {
            self.blocks[self.count] = block;
            self.count += 1;
        }
    }
};

pub const SpruceTree = struct {
    trunk_height: u4,
    canopy_layers: u3,

    pub fn fromSeed(seed: u64) SpruceTree {
        const trunk = @as(u4, @intCast(6 + @as(u4, @truncate(seed % 5))));
        const canopy = @as(u3, @intCast(3 + @as(u3, @truncate((seed >> 8) % 3))));
        return .{
            .trunk_height = trunk,
            .canopy_layers = canopy,
        };
    }
};

pub fn generateTree(_: i32, _: i32, _: i32, seed: u64) TreeBlocks {
    var result = TreeBlocks.init();
    const tree = SpruceTree.fromSeed(seed);
    const trunk_h: i8 = @intCast(tree.trunk_height);
    const layers: i8 = @intCast(tree.canopy_layers);

    for (0..@as(usize, @intCast(trunk_h))) |i| {
        result.append(.{
            .dx = 0,
            .dy = @intCast(i),
            .dz = 0,
            .block_type = .spruce_log,
        });
    }

    const canopy_start: i8 = trunk_h - layers - 1;
    for (0..@as(usize, @intCast(layers))) |layer_idx| {
        const li: i8 = @intCast(layer_idx);
        const y_pos = canopy_start + li;
        const radius: i8 = layers - li;

        var dx: i8 = -radius;
        while (dx <= radius) : (dx += 1) {
            var dz: i8 = -radius;
            while (dz <= radius) : (dz += 1) {
                if (dx == 0 and dz == 0) continue;
                const dist = absI8(dx) + absI8(dz);
                if (dist <= radius + 1) {
                    result.append(.{
                        .dx = dx,
                        .dy = y_pos,
                        .dz = dz,
                        .block_type = .spruce_leaves,
                    });
                }
            }
        }
    }

    result.append(.{
        .dx = 0,
        .dy = trunk_h,
        .dz = 0,
        .block_type = .spruce_leaves,
    });

    return result;
}

fn absI8(v: i8) i8 {
    return @intCast(@as(u8, @abs(v)));
}

pub fn getSnowyVariant() TaigaFeatures {
    var features = TaigaFeatures{};
    features.temperature = -0.5;
    features.is_snowy = true;
    features.snow_layers = true;
    return features;
}

pub const TaigaMobs = struct {
    fox: bool,
    rabbit: bool,
    wolf: bool,
};

pub fn getMobs() TaigaMobs {
    return .{
        .fox = true,
        .rabbit = true,
        .wolf = true,
    };
}

pub fn hasIgloo(features: TaigaFeatures) bool {
    return features.is_snowy;
}

test "spruce tree shape" {
    const tree_blocks = generateTree(0, 64, 0, 42);
    try std.testing.expect(tree_blocks.count > 0);

    // Verify trunk exists (blocks at dx=0, dz=0 with spruce_log type)
    var trunk_count: u16 = 0;
    var leaf_count: u16 = 0;
    for (tree_blocks.blocks) |maybe_block| {
        if (maybe_block) |block| {
            switch (block.block_type) {
                .spruce_log => {
                    try std.testing.expectEqual(@as(i8, 0), block.dx);
                    try std.testing.expectEqual(@as(i8, 0), block.dz);
                    trunk_count += 1;
                },
                .spruce_leaves => {
                    leaf_count += 1;
                },
                .snow_layer => {},
            }
        }
    }
    // Trunk height should be between 6-10
    try std.testing.expect(trunk_count >= 6);
    try std.testing.expect(trunk_count <= 10);
    // Should have leaves forming canopy
    try std.testing.expect(leaf_count > 0);
}

test "snowy variant snow" {
    const snowy = getSnowyVariant();
    try std.testing.expect(snowy.is_snowy);
    try std.testing.expect(snowy.snow_layers);
    try std.testing.expectEqual(@as(f32, -0.5), snowy.temperature);
}

test "berry bushes" {
    const normal = TaigaFeatures{};
    try std.testing.expect(normal.has_sweet_berries);

    const snowy = getSnowyVariant();
    try std.testing.expect(snowy.has_sweet_berries);
}

test "fox spawning" {
    const mobs = getMobs();
    try std.testing.expect(mobs.fox);
    try std.testing.expect(mobs.rabbit);
    try std.testing.expect(mobs.wolf);
}

test "igloo in snowy" {
    const normal = TaigaFeatures{};
    try std.testing.expect(!hasIgloo(normal));

    const snowy = getSnowyVariant();
    try std.testing.expect(hasIgloo(snowy));
}
