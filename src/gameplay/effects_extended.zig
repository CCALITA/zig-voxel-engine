const std = @import("std");

pub const ExtendedEffectType = enum {
    levitation,
    slow_falling,
    conduit_power,
    dolphins_grace,
    bad_omen,
    hero_of_village,
    darkness,
    wind_charged,
    weaving,
    oozing,
    infested,
    trial_omen,
    raid_omen,
};

pub const VisualEffect = struct {
    particle_color: [3]u8,
    screen_overlay: bool,
    fog_distance: ?f32,
};

pub const ExtendedEffect = struct {
    effect_type: ExtendedEffectType,
    amplifier: u8,
    duration: f32,
    active: bool,
};

/// Returns a movement speed modifier for the given effect and amplifier level.
/// Levitation: +0.9 per level (upward force).
/// Slow falling: reduces gravity to 0.01.
/// Dolphins grace: +2.0 swim speed.
/// All others: 0.0 (no movement modification).
pub fn getMovementModifier(effect: ExtendedEffectType, amplifier: u8) f32 {
    return switch (effect) {
        .levitation => 0.9 * @as(f32, @floatFromInt(amplifier + 1)),
        .slow_falling => 0.01,
        .dolphins_grace => 2.0,
        else => 0.0,
    };
}

/// Returns the visual effect associated with an extended effect type, or null
/// if the effect has no special visuals.
pub fn getVisualEffect(effect: ExtendedEffectType) ?VisualEffect {
    return switch (effect) {
        .levitation => VisualEffect{
            .particle_color = .{ 206, 255, 255 },
            .screen_overlay = false,
            .fog_distance = null,
        },
        .slow_falling => VisualEffect{
            .particle_color = .{ 248, 248, 255 },
            .screen_overlay = false,
            .fog_distance = null,
        },
        .conduit_power => VisualEffect{
            .particle_color = .{ 29, 194, 209 },
            .screen_overlay = true,
            .fog_distance = 48.0,
        },
        .dolphins_grace => VisualEffect{
            .particle_color = .{ 136, 163, 190 },
            .screen_overlay = false,
            .fog_distance = null,
        },
        .bad_omen => VisualEffect{
            .particle_color = .{ 11, 97, 56 },
            .screen_overlay = true,
            .fog_distance = null,
        },
        .hero_of_village => VisualEffect{
            .particle_color = .{ 68, 255, 68 },
            .screen_overlay = false,
            .fog_distance = null,
        },
        .darkness => VisualEffect{
            .particle_color = .{ 0, 0, 0 },
            .screen_overlay = true,
            .fog_distance = 2.0,
        },
        .wind_charged => VisualEffect{
            .particle_color = .{ 189, 224, 254 },
            .screen_overlay = false,
            .fog_distance = null,
        },
        .weaving => VisualEffect{
            .particle_color = .{ 119, 117, 109 },
            .screen_overlay = false,
            .fog_distance = null,
        },
        .oozing => VisualEffect{
            .particle_color = .{ 153, 255, 163 },
            .screen_overlay = false,
            .fog_distance = null,
        },
        .infested => VisualEffect{
            .particle_color = .{ 140, 155, 127 },
            .screen_overlay = false,
            .fog_distance = null,
        },
        .trial_omen => VisualEffect{
            .particle_color = .{ 21, 159, 180 },
            .screen_overlay = true,
            .fog_distance = null,
        },
        .raid_omen => VisualEffect{
            .particle_color = .{ 65, 0, 0 },
            .screen_overlay = true,
            .fog_distance = null,
        },
    };
}

/// Returns true if the effect causes a damaging side effect on death.
/// Oozing: spawns slimes on death.
/// Weaving: places cobwebs on death.
pub fn isDamaging(effect: ExtendedEffectType) bool {
    return switch (effect) {
        .oozing, .weaving => true,
        else => false,
    };
}

/// Returns the Bad Omen level based on the number of raid captain kills.
/// Capped at level 5.
pub fn getBadOmenLevel(kills: u8) u8 {
    return @min(kills, 5);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "levitation movement modifier scales with amplifier" {
    const mod0 = getMovementModifier(.levitation, 0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.9), mod0, 0.001);

    const mod2 = getMovementModifier(.levitation, 2);
    try std.testing.expectApproxEqAbs(@as(f32, 2.7), mod2, 0.001);
}

test "slow falling reduces gravity to 0.01" {
    const mod = getMovementModifier(.slow_falling, 0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.01), mod, 0.001);
}

test "dolphins grace adds swim speed" {
    const mod = getMovementModifier(.dolphins_grace, 0);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), mod, 0.001);
}

test "non-movement effects return zero modifier" {
    const effects = [_]ExtendedEffectType{
        .conduit_power,
        .bad_omen,
        .hero_of_village,
        .darkness,
        .wind_charged,
        .weaving,
        .oozing,
        .infested,
        .trial_omen,
        .raid_omen,
    };
    for (effects) |eff| {
        const mod = getMovementModifier(eff, 0);
        try std.testing.expectApproxEqAbs(@as(f32, 0.0), mod, 0.001);
    }
}

test "all effects have visual effects" {
    const all_effects = std.enums.values(ExtendedEffectType);
    for (all_effects) |eff| {
        const visual = getVisualEffect(eff);
        try std.testing.expect(visual != null);
    }
}

test "darkness has screen overlay and short fog distance" {
    const visual = getVisualEffect(.darkness).?;
    try std.testing.expect(visual.screen_overlay);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), visual.fog_distance.?, 0.001);
}

test "conduit power has fog distance" {
    const visual = getVisualEffect(.conduit_power).?;
    try std.testing.expect(visual.screen_overlay);
    try std.testing.expectApproxEqAbs(@as(f32, 48.0), visual.fog_distance.?, 0.001);
}

test "oozing and weaving are damaging" {
    try std.testing.expect(isDamaging(.oozing));
    try std.testing.expect(isDamaging(.weaving));
}

test "non-damaging effects return false" {
    const non_damaging = [_]ExtendedEffectType{
        .levitation,
        .slow_falling,
        .conduit_power,
        .dolphins_grace,
        .bad_omen,
        .hero_of_village,
        .darkness,
        .wind_charged,
        .infested,
        .trial_omen,
        .raid_omen,
    };
    for (non_damaging) |eff| {
        try std.testing.expect(!isDamaging(eff));
    }
}

test "bad omen level scales with kills up to 5" {
    try std.testing.expectEqual(@as(u8, 0), getBadOmenLevel(0));
    try std.testing.expectEqual(@as(u8, 1), getBadOmenLevel(1));
    try std.testing.expectEqual(@as(u8, 3), getBadOmenLevel(3));
    try std.testing.expectEqual(@as(u8, 5), getBadOmenLevel(5));
    try std.testing.expectEqual(@as(u8, 5), getBadOmenLevel(7));
    try std.testing.expectEqual(@as(u8, 5), getBadOmenLevel(255));
}
