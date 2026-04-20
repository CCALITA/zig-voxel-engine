const std = @import("std");

pub const MushroomBlockType = enum {
    mushroom_stem,
    brown_cap,
    red_cap,
};

pub const HugeMushroomType = enum {
    brown,
    red,
};

pub const MushroomBlock = struct {
    dx: i8,
    dy: i8,
    dz: i8,
    block_type: MushroomBlockType,
};

pub const MushroomBlocks = struct {
    blocks: [128]?MushroomBlock,
    count: u8,

    pub fn init() MushroomBlocks {
        return .{
            .blocks = [_]?MushroomBlock{null} ** 128,
            .count = 0,
        };
    }

    pub fn append(self: *MushroomBlocks, block: MushroomBlock) void {
        if (self.count < 128) {
            self.blocks[self.count] = block;
            self.count += 1;
        }
    }
};

pub const HugeMushroom = struct {
    mushroom_type: HugeMushroomType,
    trunk_height: u4,

    pub fn init(mushroom_type: HugeMushroomType, seed: u64) HugeMushroom {
        var rng = std.Random.DefaultPrng.init(seed);
        const random = rng.random();
        const height: u4 = @intCast(5 + random.uintLessThan(u4, 4));
        return .{
            .mushroom_type = mushroom_type,
            .trunk_height = height,
        };
    }
};

pub const MushroomIslandFeatures = struct {
    surface_block_id: u8 = 200,
    no_hostile_spawns: bool = true,
    huge_mushroom_density: f32 = 0.1,
};

pub const MooshroomVariant = enum {
    red,
    brown,
};

pub const MooshroomCow = struct {
    variant: MooshroomVariant,

    /// Shearing a mooshroom drops 5 mushrooms and converts it to a normal cow.
    /// Returns the number of mushroom items dropped.
    pub fn shear(self: MooshroomCow) u8 {
        _ = self;
        return 5;
    }

    /// Milking a mooshroom with a bowl produces suspicious stew.
    /// Returns the item ID for suspicious_stew.
    pub fn milkWithBowl(self: MooshroomCow) u16 {
        _ = self;
        // suspicious_stew item id placeholder
        return 734;
    }
};

pub fn generateHugeMushroom(
    base_x: i32,
    base_y: i32,
    base_z: i32,
    mtype: HugeMushroomType,
    seed: u64,
) MushroomBlocks {
    var result = MushroomBlocks.init();
    const mushroom = HugeMushroom.init(mtype, seed);
    const height: i32 = @intCast(mushroom.trunk_height);

    // Trunk
    for (0..@as(u32, @intCast(height))) |i| {
        const dy: i32 = @intCast(i);
        result.append(.{
            .dx = @intCast(base_x),
            .dy = @intCast(base_y + dy),
            .dz = @intCast(base_z),
            .block_type = .mushroom_stem,
        });
    }

    // Cap
    const cap_block_type: MushroomBlockType = switch (mtype) {
        .brown => .brown_cap,
        .red => .red_cap,
    };

    switch (mtype) {
        .brown => {
            // Brown mushroom: flat 7x7 cap on top (radius 3), single layer
            const cap_y = base_y + height;
            var cx: i32 = -3;
            while (cx <= 3) : (cx += 1) {
                var cz: i32 = -3;
                while (cz <= 3) : (cz += 1) {
                    result.append(.{
                        .dx = @intCast(base_x + cx),
                        .dy = @intCast(cap_y),
                        .dz = @intCast(base_z + cz),
                        .block_type = cap_block_type,
                    });
                }
            }
        },
        .red => {
            // Red mushroom: dome-shaped cap, 3 layers from top-2 to top
            const top_y = base_y + height;

            // Layer 1 (bottom of cap): 5x5 ring
            {
                const layer_y = top_y - 2;
                var cx: i32 = -2;
                while (cx <= 2) : (cx += 1) {
                    var cz: i32 = -2;
                    while (cz <= 2) : (cz += 1) {
                        const edge = (@abs(cx) == 2) or (@abs(cz) == 2);
                        if (edge) {
                            result.append(.{
                                .dx = @intCast(base_x + cx),
                                .dy = @intCast(layer_y),
                                .dz = @intCast(base_z + cz),
                                .block_type = cap_block_type,
                            });
                        }
                    }
                }
            }

            // Layer 2 (middle): 3x3 ring
            {
                const layer_y = top_y - 1;
                var cx: i32 = -1;
                while (cx <= 1) : (cx += 1) {
                    var cz: i32 = -1;
                    while (cz <= 1) : (cz += 1) {
                        result.append(.{
                            .dx = @intCast(base_x + cx),
                            .dy = @intCast(layer_y),
                            .dz = @intCast(base_z + cz),
                            .block_type = cap_block_type,
                        });
                    }
                }
            }

            // Layer 3 (top): single block
            result.append(.{
                .dx = @intCast(base_x),
                .dy = @intCast(top_y),
                .dz = @intCast(base_z),
                .block_type = cap_block_type,
            });
        },
    }

    return result;
}

const BlockCounts = struct {
    stems: u32 = 0,
    brown_caps: u32 = 0,
    red_caps: u32 = 0,
};

fn countBlockTypes(result: *const MushroomBlocks) BlockCounts {
    var counts = BlockCounts{};
    for (0..result.count) |i| {
        if (result.blocks[i]) |block| {
            switch (block.block_type) {
                .mushroom_stem => counts.stems += 1,
                .brown_cap => counts.brown_caps += 1,
                .red_cap => counts.red_caps += 1,
            }
        }
    }
    return counts;
}

test "mushroom island has no hostile spawns" {
    const features = MushroomIslandFeatures{};
    try std.testing.expect(features.no_hostile_spawns);
}

test "mycelium surface block id" {
    const features = MushroomIslandFeatures{};
    try std.testing.expectEqual(@as(u8, 200), features.surface_block_id);
    try std.testing.expectApproxEqAbs(@as(f32, 0.1), features.huge_mushroom_density, 0.001);
}

test "huge mushroom shape - brown has flat cap" {
    const result = generateHugeMushroom(0, 0, 0, .brown, 42);
    try std.testing.expect(result.count > 0);

    const counts = countBlockTypes(&result);
    try std.testing.expect(counts.stems >= 5);
    try std.testing.expect(counts.stems <= 8);
    // Brown cap is 7x7 = 49 blocks
    try std.testing.expectEqual(@as(u32, 49), counts.brown_caps);
}

test "huge mushroom shape - red has dome cap" {
    const result = generateHugeMushroom(0, 0, 0, .red, 99);
    try std.testing.expect(result.count > 0);

    const counts = countBlockTypes(&result);
    try std.testing.expect(counts.stems >= 5);
    try std.testing.expect(counts.stems <= 8);
    // Red cap: 16 edge blocks (layer 1) + 9 blocks (layer 2) + 1 block (layer 3) = 26
    try std.testing.expectEqual(@as(u32, 26), counts.red_caps);
}

test "mooshroom shear returns 5 mushrooms" {
    const red_mooshroom = MooshroomCow{ .variant = .red };
    try std.testing.expectEqual(@as(u8, 5), red_mooshroom.shear());

    const brown_mooshroom = MooshroomCow{ .variant = .brown };
    try std.testing.expectEqual(@as(u8, 5), brown_mooshroom.shear());
}

test "mooshroom milk with bowl returns suspicious stew" {
    const mooshroom = MooshroomCow{ .variant = .red };
    try std.testing.expectEqual(@as(u16, 734), mooshroom.milkWithBowl());
}

test "huge mushroom trunk height range" {
    // Test multiple seeds to verify height is always in 5-8 range
    const seeds = [_]u64{ 0, 1, 42, 99, 1000, 65535 };
    for (seeds) |seed| {
        const mushroom = HugeMushroom.init(.brown, seed);
        try std.testing.expect(mushroom.trunk_height >= 5);
        try std.testing.expect(mushroom.trunk_height <= 8);
    }
}
