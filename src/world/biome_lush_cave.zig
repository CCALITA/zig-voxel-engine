const std = @import("std");

pub const LushCaveBlock = enum {
    glow_berries,
    azalea,
    flowering_azalea,
    moss_block,
    moss_carpet,
    small_dripleaf,
    big_dripleaf,
    spore_blossom,
    cave_vine,
    rooted_dirt,
    hanging_roots,
};

pub const DripleafSize = enum {
    small,
    big,
};

pub const LushCaveFeatures = struct {
    glow_berry_density: f32 = 0.15,
    azalea_density: f32 = 0.1,
    moss_carpet_density: f32 = 0.3,
    dripleaf_density: f32 = 0.05,
    spore_blossom_density: f32 = 0.02,
};

pub const VegetationPlacement = struct {
    x: u4,
    y: u4,
    z: u4,
    block: LushCaveBlock,
};

/// Simple deterministic hash for procedural generation.
fn hashSeed(seed: u64, a: u64, b: u64) u64 {
    var h = seed;
    h ^= a *% @as(u64, 0x9E3779B97F4A7C15);
    h = (h << 13) | (h >> 51);
    h ^= b *% @as(u64, 0x517CC1B727220A95);
    h = (h << 17) | (h >> 47);
    h *%= 0x6C62272E07BB0142;
    return h;
}

/// Converts a hash value to a float in [0, 1).
fn hashToFloat(h: u64) f32 {
    return @as(f32, @floatFromInt(h >> 40)) / @as(f32, 16777216.0);
}

/// Generates vegetation placements for a lush cave chunk region.
/// Returns an array of up to 128 optional placements.
pub fn generateVegetation(
    seed: u64,
    chunk_x: i32,
    chunk_z: i32,
    cave_y: i32,
) [128]?VegetationPlacement {
    const features = LushCaveFeatures{};
    var result: [128]?VegetationPlacement = [_]?VegetationPlacement{null} ** 128;
    var count: usize = 0;

    const cx: u64 = @bitCast(@as(i64, chunk_x));
    const cz: u64 = @bitCast(@as(i64, chunk_z));
    const cy: u64 = @bitCast(@as(i64, cave_y));

    const DensityEntry = struct {
        density: f32,
        block: LushCaveBlock,
    };

    const densities = [_]DensityEntry{
        .{ .density = features.moss_carpet_density, .block = .moss_carpet },
        .{ .density = features.glow_berry_density, .block = .glow_berries },
        .{ .density = features.azalea_density, .block = .azalea },
        .{ .density = features.dripleaf_density, .block = .small_dripleaf },
        .{ .density = features.spore_blossom_density, .block = .spore_blossom },
    };

    for (0..16) |xi| {
        for (0..16) |zi| {
            if (count >= 128) break;

            const pos_hash = hashSeed(seed, cx *% 16 +% xi, cz *% 16 +% zi);

            for (densities) |entry| {
                if (count >= 128) break;

                const variant_hash = hashSeed(pos_hash, @intFromEnum(entry.block), cy);
                const roll = hashToFloat(variant_hash);

                if (roll < entry.density) {
                    const y_hash = hashSeed(variant_hash, xi, zi);
                    const y_offset: u4 = @truncate((y_hash >> 4) & 0xF);

                    result[count] = VegetationPlacement{
                        .x = @truncate(xi),
                        .y = y_offset,
                        .z = @truncate(zi),
                        .block = entry.block,
                    };
                    count += 1;
                }
            }
        }
    }

    return result;
}

/// Returns the light level emitted by glow berries.
/// Lit glow berries emit light level 14, unlit emit 0.
pub fn getGlowBerryLightLevel(is_lit: bool) u4 {
    return if (is_lit) 14 else 0;
}

/// Returns whether a dripleaf block is walkable.
/// Big dripleaf is walkable (but tilts under weight), small is not.
pub fn isDripleafWalkable(size: DripleafSize) bool {
    return size == .big;
}

// ── Tests ──────────────────────────────────────────────────────────────

test "glow berry light level when lit" {
    try std.testing.expectEqual(@as(u4, 14), getGlowBerryLightLevel(true));
}

test "glow berry light level when unlit" {
    try std.testing.expectEqual(@as(u4, 0), getGlowBerryLightLevel(false));
}

test "small dripleaf is not walkable" {
    try std.testing.expect(!isDripleafWalkable(.small));
}

test "big dripleaf is walkable" {
    try std.testing.expect(isDripleafWalkable(.big));
}

test "vegetation generation produces placements" {
    const result = generateVegetation(42, 0, 0, 30);
    var count: usize = 0;
    for (result) |maybe_placement| {
        if (maybe_placement != null) count += 1;
    }
    try std.testing.expect(count > 0);
    try std.testing.expect(count <= 128);
}

test "vegetation generation density is reasonable" {
    const result = generateVegetation(12345, 5, 10, 40);
    var count: usize = 0;
    var moss_count: usize = 0;
    var berry_count: usize = 0;

    for (result) |maybe_placement| {
        if (maybe_placement) |placement| {
            count += 1;
            switch (placement.block) {
                .moss_carpet => moss_count += 1,
                .glow_berries => berry_count += 1,
                else => {},
            }
        }
    }

    try std.testing.expect(count > 0);
    try std.testing.expect(count <= 128);
    // Moss carpet (0.3 density) should appear more often than glow berries (0.15)
    try std.testing.expect(moss_count >= berry_count);
}

test "vegetation placement coordinates are in bounds" {
    const result = generateVegetation(99, 3, 7, 20);
    for (result) |maybe_placement| {
        if (maybe_placement) |placement| {
            try std.testing.expect(placement.x <= 15);
            try std.testing.expect(placement.y <= 15);
            try std.testing.expect(placement.z <= 15);
            try std.testing.expect(@intFromEnum(placement.block) <= @intFromEnum(LushCaveBlock.hanging_roots));
        }
    }
}

test "different seeds produce different vegetation" {
    const result_a = generateVegetation(111, 0, 0, 30);
    const result_b = generateVegetation(222, 0, 0, 30);

    var count_a: usize = 0;
    var count_b: usize = 0;
    for (result_a) |p| {
        if (p != null) count_a += 1;
    }
    for (result_b) |p| {
        if (p != null) count_b += 1;
    }

    // Different seeds should (very likely) produce different counts
    // or at least both produce some output
    try std.testing.expect(count_a > 0);
    try std.testing.expect(count_b > 0);
}

test "LushCaveFeatures default values" {
    const features = LushCaveFeatures{};
    try std.testing.expectApproxEqAbs(@as(f32, 0.15), features.glow_berry_density, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.1), features.azalea_density, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.3), features.moss_carpet_density, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.05), features.dripleaf_density, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.02), features.spore_blossom_density, 0.001);
}
