const std = @import("std");

pub const BONE_MEAL: u16 = 710;

pub const BoneMealResult = struct {
    success: bool = false,
    particles: bool = false,
    growth_stages: u8 = 0,
    spawn_grass: bool = false,
    try_grow_tree: bool = false,
};

pub fn isBoneMealTarget(block_id: u16) bool {
    return switch (block_id) {
        65, 66, 67 => true,
        3 => true,
        9 => true,
        else => false,
    };
}

pub fn applyBoneMeal(target_block: u16, growth_stage: u8, rng: u32) BoneMealResult {
    _ = growth_stage;
    return switch (target_block) {
        65, 66, 67 => .{
            .success = true,
            .particles = true,
            .growth_stages = @intCast(1 + rng % 3),
        },
        3 => .{ .success = true, .particles = true, .spawn_grass = true },
        9 => .{
            .success = (rng % 3 == 0),
            .particles = true,
            .try_grow_tree = (rng % 3 == 0),
        },
        else => .{},
    };
}

test "bone meal constant" {
    try std.testing.expectEqual(@as(u16, 710), BONE_MEAL);
}

test "wheat is target" {
    try std.testing.expect(isBoneMealTarget(65));
}

test "carrot is target" {
    try std.testing.expect(isBoneMealTarget(66));
}

test "grass block is target" {
    try std.testing.expect(isBoneMealTarget(3));
}

test "sapling is target" {
    try std.testing.expect(isBoneMealTarget(9));
}

test "stone not target" {
    try std.testing.expect(!isBoneMealTarget(1));
}

test "crop growth 1-3 stages" {
    const r = applyBoneMeal(65, 0, 42);
    try std.testing.expect(r.success);
    try std.testing.expect(r.particles);
    try std.testing.expect(r.growth_stages >= 1 and r.growth_stages <= 3);
}

test "grass spawns vegetation" {
    const r = applyBoneMeal(3, 0, 0);
    try std.testing.expect(r.spawn_grass);
}

test "sapling tree grow chance" {
    const r1 = applyBoneMeal(9, 0, 0);
    try std.testing.expect(r1.try_grow_tree);
    const r2 = applyBoneMeal(9, 0, 1);
    try std.testing.expect(!r2.try_grow_tree);
}

test "non-target returns failure" {
    const r = applyBoneMeal(1, 0, 0);
    try std.testing.expect(!r.success);
}
