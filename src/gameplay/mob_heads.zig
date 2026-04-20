const std = @import("std");

pub const HeadType = enum(u8) {
    zombie,
    skeleton,
    creeper,
    wither_skeleton,
    ender_dragon,
    player,
};

pub const MobHead = struct {
    head_type: HeadType,
    player_name: ?[16]u8 = null,
    player_name_len: u8 = 0,
    placed: bool = false,
    facing: u2 = 0,
};

pub const DropCondition = struct {
    source_mob: u8,
    chance: f32,
    requires_charged_creeper: bool,
};

pub const mob_ids = struct {
    pub const zombie: u8 = 0;
    pub const skeleton: u8 = 1;
    pub const creeper: u8 = 2;
    pub const wither_skeleton: u8 = 3;
    pub const ender_dragon: u8 = 4;
};

pub const instrument_ids = struct {
    pub const zombie_sound: u8 = 0;
    pub const skeleton_sound: u8 = 1;
    pub const creeper_sound: u8 = 2;
    pub const wither_sound: u8 = 3;
    pub const dragon_roar: u8 = 4;
};

pub fn getDropCondition(head_type: HeadType) DropCondition {
    return switch (head_type) {
        .zombie => .{
            .source_mob = mob_ids.zombie,
            .chance = 1.0,
            .requires_charged_creeper = true,
        },
        .skeleton => .{
            .source_mob = mob_ids.skeleton,
            .chance = 1.0,
            .requires_charged_creeper = true,
        },
        .creeper => .{
            .source_mob = mob_ids.creeper,
            .chance = 1.0,
            .requires_charged_creeper = true,
        },
        .wither_skeleton => .{
            .source_mob = mob_ids.wither_skeleton,
            .chance = 0.025,
            .requires_charged_creeper = false,
        },
        .ender_dragon => .{
            .source_mob = mob_ids.ender_dragon,
            .chance = 0.0,
            .requires_charged_creeper = false,
        },
        .player => .{
            .source_mob = 0,
            .chance = 0.0,
            .requires_charged_creeper = false,
        },
    };
}

pub fn getNoteBlockInstrument(head_type: HeadType) u8 {
    return switch (head_type) {
        .zombie => instrument_ids.zombie_sound,
        .skeleton => instrument_ids.skeleton_sound,
        .creeper => instrument_ids.creeper_sound,
        .wither_skeleton => instrument_ids.wither_sound,
        .ender_dragon => instrument_ids.dragon_roar,
        .player => instrument_ids.zombie_sound,
    };
}

pub fn canWearAsHelmet(head_type: HeadType) bool {
    _ = head_type;
    return true;
}

pub fn getDetectionReduction(head_type: HeadType, viewer_mob: u8) f32 {
    const matching_mob: u8 = switch (head_type) {
        .zombie => mob_ids.zombie,
        .skeleton => mob_ids.skeleton,
        .creeper => mob_ids.creeper,
        .wither_skeleton => mob_ids.wither_skeleton,
        .ender_dragon => mob_ids.ender_dragon,
        .player => return 0.0,
    };
    return if (viewer_mob == matching_mob) 0.5 else 0.0;
}

test "wither skeleton drop chance is 2.5 percent" {
    const condition = getDropCondition(.wither_skeleton);
    try std.testing.expectApproxEqAbs(@as(f32, 0.025), condition.chance, 0.0001);
    try std.testing.expectEqual(false, condition.requires_charged_creeper);
}

test "creeper head requires charged creeper" {
    const condition = getDropCondition(.creeper);
    try std.testing.expectEqual(true, condition.requires_charged_creeper);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), condition.chance, 0.0001);
}

test "zombie head requires charged creeper" {
    const condition = getDropCondition(.zombie);
    try std.testing.expectEqual(true, condition.requires_charged_creeper);
}

test "skeleton head requires charged creeper" {
    const condition = getDropCondition(.skeleton);
    try std.testing.expectEqual(true, condition.requires_charged_creeper);
}

test "note block instruments return correct IDs" {
    try std.testing.expectEqual(instrument_ids.zombie_sound, getNoteBlockInstrument(.zombie));
    try std.testing.expectEqual(instrument_ids.skeleton_sound, getNoteBlockInstrument(.skeleton));
    try std.testing.expectEqual(instrument_ids.creeper_sound, getNoteBlockInstrument(.creeper));
    try std.testing.expectEqual(instrument_ids.wither_sound, getNoteBlockInstrument(.wither_skeleton));
    try std.testing.expectEqual(instrument_ids.dragon_roar, getNoteBlockInstrument(.ender_dragon));
}

test "all heads can be worn as helmet" {
    inline for (std.meta.fields(HeadType)) |field| {
        const head_type: HeadType = @enumFromInt(field.value);
        try std.testing.expectEqual(true, canWearAsHelmet(head_type));
    }
}

test "helmet detection reduction matches corresponding mob" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), getDetectionReduction(.zombie, mob_ids.zombie), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), getDetectionReduction(.skeleton, mob_ids.skeleton), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), getDetectionReduction(.creeper, mob_ids.creeper), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), getDetectionReduction(.wither_skeleton, mob_ids.wither_skeleton), 0.0001);
}

test "helmet detection reduction zero for non-matching mob" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), getDetectionReduction(.zombie, mob_ids.skeleton), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), getDetectionReduction(.skeleton, mob_ids.creeper), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), getDetectionReduction(.player, mob_ids.zombie), 0.0001);
}
