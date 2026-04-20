const std = @import("std");

// ---------- Enums ----------

pub const GeodeLayer = enum(u2) {
    air_pocket = 0,
    inner_layer = 1,
    middle_layer = 2,
    outer_shell = 3,
};

// ---------- Block ID helpers ----------

pub fn getLayerBlock(layer: GeodeLayer) u8 {
    return switch (layer) {
        .outer_shell => 201,
        .middle_layer => 202,
        .inner_layer => 203,
        .air_pocket => 0,
    };
}

// ---------- Core structs ----------

pub const GeodeBlock = struct {
    dx: i8,
    dy: i8,
    dz: i8,
    layer: GeodeLayer,
};

pub const GeodeBlocks = struct {
    blocks: [1024]GeodeBlock,
    count: u16,

    pub fn init() GeodeBlocks {
        return .{
            .blocks = undefined,
            .count = 0,
        };
    }

    pub fn append(self: *GeodeBlocks, block: GeodeBlock) void {
        if (self.count < 1024) {
            self.blocks[self.count] = block;
            self.count += 1;
        }
    }

    pub fn slice(self: *const GeodeBlocks) []const GeodeBlock {
        return self.blocks[0..self.count];
    }
};

pub const GeodeShape = struct {
    center_x: i32,
    center_y: i32,
    center_z: i32,
    radius: u4,

    pub fn init(cx: i32, cy: i32, cz: i32, radius: u4) GeodeShape {
        std.debug.assert(radius >= 4 and radius <= 7);
        return .{
            .center_x = cx,
            .center_y = cy,
            .center_z = cz,
            .radius = radius,
        };
    }
};

// ---------- Layer classification ----------

pub fn getLayerForDistance(dist_sq: f32, radius: u4) GeodeLayer {
    const r: f32 = @floatFromInt(radius);
    const air_r = r - 3.0;
    const inner_r = r - 2.0;
    const middle_r = r - 1.0;

    if (dist_sq < air_r * air_r) return .air_pocket;
    if (dist_sq < inner_r * inner_r) return .inner_layer;
    if (dist_sq < middle_r * middle_r) return .middle_layer;
    return .outer_shell;
}

// ---------- Geode generation ----------

pub fn generateGeode(center_x: i32, center_y: i32, center_z: i32, radius: u4, seed: u64) GeodeBlocks {
    var result = GeodeBlocks.init();
    const r_i32: i32 = @intCast(radius);
    const r_f32: f32 = @floatFromInt(radius);
    const r_sq = r_f32 * r_f32;

    var prng = std.Random.DefaultPrng.init(seed ^ @as(u64, @bitCast(@as(i64, center_x))) ^ (@as(u64, @bitCast(@as(i64, center_y))) << 8) ^ (@as(u64, @bitCast(@as(i64, center_z))) << 16));
    const rng = prng.random();

    var dx: i32 = -r_i32;
    while (dx <= r_i32) : (dx += 1) {
        var dy: i32 = -r_i32;
        while (dy <= r_i32) : (dy += 1) {
            var dz: i32 = -r_i32;
            while (dz <= r_i32) : (dz += 1) {
                const fx: f32 = @floatFromInt(dx);
                const fy: f32 = @floatFromInt(dy);
                const fz: f32 = @floatFromInt(dz);
                const dist_sq = fx * fx + fy * fy + fz * fz;

                if (dist_sq >= r_sq) continue;

                // Noise offset for organic shape
                const noise_val: f32 = @as(f32, @floatFromInt(rng.intRangeAtMost(i32, -10, 10))) * 0.05;
                const adjusted_dist_sq = dist_sq + noise_val;

                const layer = getLayerForDistance(adjusted_dist_sq, radius);
                result.append(.{
                    .dx = @intCast(dx),
                    .dy = @intCast(dy),
                    .dz = @intCast(dz),
                    .layer = layer,
                });
            }
        }
    }
    return result;
}

// ---------- Budding amethyst ----------

pub const GrowthResult = struct {
    face_index: u3,
    new_stage: u2,
};

pub const BuddingAmethyst = struct {
    x: i32,
    y: i32,
    z: i32,
    growth_faces: [6]?u2,

    pub fn init(x: i32, y: i32, z: i32) BuddingAmethyst {
        return .{
            .x = x,
            .y = y,
            .z = z,
            .growth_faces = [_]?u2{null} ** 6,
        };
    }

    pub fn tickGrowth(self: *BuddingAmethyst, seed: u64) ?GrowthResult {
        var prng = std.Random.DefaultPrng.init(
            seed ^ @as(u64, @bitCast(@as(i64, self.x))) ^ (@as(u64, @bitCast(@as(i64, self.z))) << 16),
        );
        const rng = prng.random();

        for (0..6) |i| {
            if (rng.intRangeAtMost(u32, 0, 4) != 0) continue;

            const face_idx: u3 = @intCast(i);
            const current_stage = self.growth_faces[i] orelse 0;
            if (current_stage >= 3) continue;

            const new_stage = current_stage + 1;
            self.growth_faces[i] = new_stage;
            return .{
                .face_index = face_idx,
                .new_stage = new_stage,
            };
        }
        return null;
    }
};

// ---------- Spawn chance ----------

pub fn shouldGenerateGeode(chunk_x: i32, chunk_z: i32, y: i32, seed: u64) bool {
    if (y >= 46) return false;

    var prng = std.Random.DefaultPrng.init(
        seed ^ @as(u64, @bitCast(@as(i64, chunk_x) *% 341873128712)) ^ @as(u64, @bitCast(@as(i64, chunk_z) *% 132897987541)),
    );
    const rng = prng.random();
    return rng.intRangeAtMost(u32, 0, 52) == 0;
}

// ---------- Tests ----------

test "layer ordering by distance" {
    // For radius 7: air < 4, inner < 5, middle < 6, outer >= 6
    const radius: u4 = 7;

    // Center should be air pocket
    const center = getLayerForDistance(0.0, radius);
    try std.testing.expectEqual(GeodeLayer.air_pocket, center);

    // Just inside inner boundary (dist < 5*5=25)
    const inner = getLayerForDistance(20.0, radius);
    try std.testing.expectEqual(GeodeLayer.inner_layer, inner);

    // Just inside middle boundary (dist < 6*6=36)
    const middle = getLayerForDistance(30.0, radius);
    try std.testing.expectEqual(GeodeLayer.middle_layer, middle);

    // At outer shell (dist >= 36)
    const outer = getLayerForDistance(40.0, radius);
    try std.testing.expectEqual(GeodeLayer.outer_shell, outer);
}

test "layer block IDs" {
    try std.testing.expectEqual(@as(u8, 201), getLayerBlock(.outer_shell));
    try std.testing.expectEqual(@as(u8, 202), getLayerBlock(.middle_layer));
    try std.testing.expectEqual(@as(u8, 203), getLayerBlock(.inner_layer));
    try std.testing.expectEqual(@as(u8, 0), getLayerBlock(.air_pocket));
}

test "geode shape has blocks in all layers" {
    const result = generateGeode(0, -30, 0, 6, 42);
    try std.testing.expect(result.count > 0);

    var has_air = false;
    var has_inner = false;
    var has_middle = false;
    var has_outer = false;

    for (result.slice()) |block| {
        switch (block.layer) {
            .air_pocket => has_air = true,
            .inner_layer => has_inner = true,
            .middle_layer => has_middle = true,
            .outer_shell => has_outer = true,
        }
    }

    try std.testing.expect(has_air);
    try std.testing.expect(has_inner);
    try std.testing.expect(has_middle);
    try std.testing.expect(has_outer);
}

test "geode blocks within radius" {
    const radius: u4 = 5;
    const result = generateGeode(10, -20, 30, radius, 123);

    for (result.slice()) |b| {
        const dx: f32 = @floatFromInt(b.dx);
        const dy: f32 = @floatFromInt(b.dy);
        const dz: f32 = @floatFromInt(b.dz);
        const dist_sq = dx * dx + dy * dy + dz * dz;
        const r_f: f32 = @floatFromInt(radius);
        try std.testing.expect(dist_sq < r_f * r_f);
    }
}

test "budding amethyst growth tick" {
    var bud = BuddingAmethyst.init(5, -20, 10);

    // Run many ticks to verify growth occurs
    var grew = false;
    for (0..100) |tick| {
        const seed = @as(u64, tick) * 9973;
        if (bud.tickGrowth(seed)) |growth| {
            try std.testing.expect(growth.new_stage >= 1 and growth.new_stage <= 3);
            try std.testing.expect(growth.face_index < 6);
            grew = true;
            break;
        }
    }
    try std.testing.expect(grew);
}

test "budding amethyst max stage" {
    var bud = BuddingAmethyst.init(0, 0, 0);
    // Manually set all faces to max stage
    for (0..6) |i| {
        bud.growth_faces[i] = 3;
    }
    // Should return null since all faces are maxed
    const result = bud.tickGrowth(42);
    try std.testing.expectEqual(@as(?GrowthResult, null), result);
}

test "shouldGenerateGeode below y=46" {
    // With many seeds some should trigger, some should not
    var count: u32 = 0;
    const trials: u32 = 5300;
    for (0..trials) |i| {
        if (shouldGenerateGeode(@intCast(i), 0, 30, 777)) {
            count += 1;
        }
    }
    // Expect roughly 1/53 = ~100 out of 5300; allow generous range
    try std.testing.expect(count > 20);
    try std.testing.expect(count < 300);
}

test "shouldGenerateGeode never above y=46" {
    for (0..200) |i| {
        const above = shouldGenerateGeode(@intCast(i), 0, 46, 999);
        try std.testing.expect(!above);
    }
}
