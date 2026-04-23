/// Lightweight sound manager providing event metadata, distance attenuation,
/// and randomised pitch.  No actual audio playback — pure data lookups that
/// higher-level systems can query.

const std = @import("std");

// ──────────────────────────────────────────────────────────────────────────────
// Sound Event
// ──────────────────────────────────────────────────────────────────────────────

pub const SoundEvent = enum(u8) {
    block_break,
    block_place,
    footstep_stone,
    footstep_grass,
    footstep_sand,
    footstep_wood,
    footstep_snow,
    hurt,
    death,
    eat,
    drink,
    burp,
    door_open,
    door_close,
    chest_open,
    chest_close,
    anvil_use,
    level_up,
    explosion,
    bow_shoot,
    arrow_hit,
    splash,
    fizz,
    click,
    note_block,
    enderdragon_growl,
    wither_spawn,
    thunder,
};

// ──────────────────────────────────────────────────────────────────────────────
// Sound Category & Info
// ──────────────────────────────────────────────────────────────────────────────

pub const SoundCategory = enum {
    master,
    music,
    weather,
    block,
    hostile,
    player,
    ambient,
};

pub const SoundInfo = struct {
    volume: f32,
    pitch_min: f32,
    pitch_max: f32,
    range: f32,
    category: SoundCategory,
};

// ──────────────────────────────────────────────────────────────────────────────
// Lookup
// ──────────────────────────────────────────────────────────────────────────────

/// Return the immutable properties for a given sound event.
pub fn getSoundInfo(event: SoundEvent) SoundInfo {
    return switch (event) {
        // Blocks
        .block_break => .{ .volume = 1.0, .pitch_min = 0.8, .pitch_max = 1.0, .range = 16.0, .category = .block },
        .block_place => .{ .volume = 1.0, .pitch_min = 0.8, .pitch_max = 1.0, .range = 16.0, .category = .block },

        // Footsteps
        .footstep_stone => .{ .volume = 0.3, .pitch_min = 0.9, .pitch_max = 1.1, .range = 12.0, .category = .player },
        .footstep_grass => .{ .volume = 0.3, .pitch_min = 0.9, .pitch_max = 1.1, .range = 12.0, .category = .player },
        .footstep_sand => .{ .volume = 0.3, .pitch_min = 0.9, .pitch_max = 1.1, .range = 12.0, .category = .player },
        .footstep_wood => .{ .volume = 0.3, .pitch_min = 0.9, .pitch_max = 1.1, .range = 12.0, .category = .player },
        .footstep_snow => .{ .volume = 0.3, .pitch_min = 0.9, .pitch_max = 1.1, .range = 12.0, .category = .player },

        // Player
        .hurt => .{ .volume = 1.0, .pitch_min = 0.8, .pitch_max = 1.0, .range = 16.0, .category = .player },
        .death => .{ .volume = 1.0, .pitch_min = 0.8, .pitch_max = 1.0, .range = 16.0, .category = .player },
        .eat => .{ .volume = 0.5, .pitch_min = 0.9, .pitch_max = 1.2, .range = 8.0, .category = .player },
        .drink => .{ .volume = 0.5, .pitch_min = 0.9, .pitch_max = 1.2, .range = 8.0, .category = .player },
        .burp => .{ .volume = 0.5, .pitch_min = 0.9, .pitch_max = 1.0, .range = 8.0, .category = .player },

        // Interactables
        .door_open => .{ .volume = 1.0, .pitch_min = 0.9, .pitch_max = 1.0, .range = 16.0, .category = .block },
        .door_close => .{ .volume = 1.0, .pitch_min = 0.9, .pitch_max = 1.0, .range = 16.0, .category = .block },
        .chest_open => .{ .volume = 0.5, .pitch_min = 0.9, .pitch_max = 1.0, .range = 12.0, .category = .block },
        .chest_close => .{ .volume = 0.5, .pitch_min = 0.9, .pitch_max = 1.0, .range = 12.0, .category = .block },
        .anvil_use => .{ .volume = 0.8, .pitch_min = 0.8, .pitch_max = 1.0, .range = 16.0, .category = .block },

        // Progression
        .level_up => .{ .volume = 1.0, .pitch_min = 1.0, .pitch_max = 1.0, .range = 0.0, .category = .player },

        // Combat / ranged
        .explosion => .{ .volume = 1.0, .pitch_min = 0.9, .pitch_max = 1.0, .range = 48.0, .category = .block },
        .bow_shoot => .{ .volume = 1.0, .pitch_min = 0.8, .pitch_max = 1.2, .range = 16.0, .category = .player },
        .arrow_hit => .{ .volume = 0.8, .pitch_min = 0.9, .pitch_max = 1.1, .range = 16.0, .category = .player },

        // Liquid / misc
        .splash => .{ .volume = 0.8, .pitch_min = 0.9, .pitch_max = 1.1, .range = 16.0, .category = .player },
        .fizz => .{ .volume = 0.5, .pitch_min = 0.9, .pitch_max = 1.0, .range = 12.0, .category = .block },
        .click => .{ .volume = 0.3, .pitch_min = 0.9, .pitch_max = 1.0, .range = 8.0, .category = .master },
        .note_block => .{ .volume = 1.0, .pitch_min = 0.5, .pitch_max = 2.0, .range = 48.0, .category = .block },

        // Bosses
        .enderdragon_growl => .{ .volume = 1.0, .pitch_min = 0.8, .pitch_max = 1.0, .range = 64.0, .category = .hostile },
        .wither_spawn => .{ .volume = 1.0, .pitch_min = 0.8, .pitch_max = 1.0, .range = 64.0, .category = .hostile },

        // Weather
        .thunder => .{ .volume = 1.0, .pitch_min = 0.8, .pitch_max = 1.0, .range = 128.0, .category = .weather },
    };
}

// ──────────────────────────────────────────────────────────────────────────────
// Attenuation
// ──────────────────────────────────────────────────────────────────────────────

/// Linear distance attenuation.  Returns 1.0 at distance 0, 0.0 at `range`,
/// and is clamped so it never goes negative or exceeds 1.0.
/// A `range` of 0 (non-positional sound) always returns 1.0.
pub fn getAttenuation(distance: f32, range: f32) f32 {
    if (range <= 0.0) return 1.0;
    return std.math.clamp(1.0 - distance / range, 0.0, 1.0);
}

// ──────────────────────────────────────────────────────────────────────────────
// Pitch randomisation
// ──────────────────────────────────────────────────────────────────────────────

/// Derive a pitch value in [pitch_min, pitch_max] from a cheap integer hash.
/// `rng` is any u32 — callers can pass a frame counter, entity id, etc.
pub fn getPitch(info: SoundInfo, rng: u32) f32 {
    const t: f32 = @as(f32, @floatFromInt(rng % 1001)) / 1000.0;
    return info.pitch_min + t * (info.pitch_max - info.pitch_min);
}

// ──────────────────────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────────────────────

test "every SoundEvent has valid SoundInfo" {
    inline for (@typeInfo(SoundEvent).@"enum".fields) |field| {
        const event: SoundEvent = @enumFromInt(field.value);
        const info = getSoundInfo(event);
        try std.testing.expect(info.volume >= 0.0 and info.volume <= 1.0);
        try std.testing.expect(info.pitch_min > 0.0);
        try std.testing.expect(info.pitch_max >= info.pitch_min);
        try std.testing.expect(info.range >= 0.0);
    }
}

test "getSoundInfo returns expected category for block events" {
    try std.testing.expectEqual(SoundCategory.block, getSoundInfo(.block_break).category);
    try std.testing.expectEqual(SoundCategory.block, getSoundInfo(.block_place).category);
    try std.testing.expectEqual(SoundCategory.block, getSoundInfo(.door_open).category);
    try std.testing.expectEqual(SoundCategory.block, getSoundInfo(.anvil_use).category);
}

test "getSoundInfo returns expected category for player events" {
    try std.testing.expectEqual(SoundCategory.player, getSoundInfo(.hurt).category);
    try std.testing.expectEqual(SoundCategory.player, getSoundInfo(.death).category);
    try std.testing.expectEqual(SoundCategory.player, getSoundInfo(.eat).category);
    try std.testing.expectEqual(SoundCategory.player, getSoundInfo(.footstep_stone).category);
}

test "getSoundInfo returns expected category for hostile events" {
    try std.testing.expectEqual(SoundCategory.hostile, getSoundInfo(.enderdragon_growl).category);
    try std.testing.expectEqual(SoundCategory.hostile, getSoundInfo(.wither_spawn).category);
}

test "getSoundInfo returns weather category for thunder" {
    try std.testing.expectEqual(SoundCategory.weather, getSoundInfo(.thunder).category);
}

test "getAttenuation returns 1.0 at distance zero" {
    try std.testing.expectEqual(@as(f32, 1.0), getAttenuation(0.0, 16.0));
}

test "getAttenuation returns 0.0 at range" {
    try std.testing.expectEqual(@as(f32, 0.0), getAttenuation(16.0, 16.0));
}

test "getAttenuation returns 0.5 at half range" {
    try std.testing.expectEqual(@as(f32, 0.5), getAttenuation(8.0, 16.0));
}

test "getAttenuation clamps beyond range to 0" {
    try std.testing.expectEqual(@as(f32, 0.0), getAttenuation(100.0, 16.0));
}

test "getAttenuation clamps negative distance to 1" {
    try std.testing.expectEqual(@as(f32, 1.0), getAttenuation(-5.0, 16.0));
}

test "getAttenuation returns 1.0 when range is zero (non-positional)" {
    try std.testing.expectEqual(@as(f32, 1.0), getAttenuation(10.0, 0.0));
}

test "getPitch returns pitch_min when rng is 0" {
    const info = getSoundInfo(.block_break);
    try std.testing.expectEqual(info.pitch_min, getPitch(info, 0));
}

test "getPitch returns pitch_max when rng is 1000" {
    const info = getSoundInfo(.block_break);
    try std.testing.expectEqual(info.pitch_max, getPitch(info, 1000));
}

test "getPitch stays within [pitch_min, pitch_max] for many values" {
    const info = getSoundInfo(.note_block); // widest range: 0.5 – 2.0
    var i: u32 = 0;
    while (i < 2000) : (i += 1) {
        const p = getPitch(info, i);
        try std.testing.expect(p >= info.pitch_min and p <= info.pitch_max);
    }
}

test "level_up has zero range (non-positional)" {
    const info = getSoundInfo(.level_up);
    try std.testing.expectEqual(@as(f32, 0.0), info.range);
    // Non-positional sounds are always full volume regardless of distance.
    try std.testing.expectEqual(@as(f32, 1.0), getAttenuation(999.0, info.range));
}

test "boss sounds have large range" {
    try std.testing.expect(getSoundInfo(.enderdragon_growl).range >= 64.0);
    try std.testing.expect(getSoundInfo(.wither_spawn).range >= 64.0);
}

test "explosion has larger range than footsteps" {
    try std.testing.expect(getSoundInfo(.explosion).range > getSoundInfo(.footstep_grass).range);
}
