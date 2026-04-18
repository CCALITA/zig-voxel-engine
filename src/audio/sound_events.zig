/// Sound event definitions, categories, and a data-only sound manager stub.
/// No actual audio playback — provides the type system and property lookup
/// that higher-level systems (e.g. networking, UI) can depend on.

const std = @import("std");

// ──────────────────────────────────────────────────────────────────────────────
// Sound Category
// ──────────────────────────────────────────────────────────────────────────────

pub const SoundCategory = enum {
    master,
    music,
    weather,
    blocks,
    hostile,
    player,
    ambient,
    voice,

    pub const count = @typeInfo(SoundCategory).@"enum".fields.len;
};

// ──────────────────────────────────────────────────────────────────────────────
// Sound Event
// ──────────────────────────────────────────────────────────────────────────────

pub const SoundEvent = enum {
    // Blocks
    block_break,
    block_place,

    // Footsteps
    step_grass,
    step_stone,
    step_wood,
    step_sand,
    step_gravel,
    step_snow,

    // Combat
    attack_swing,
    attack_hit,

    // Player
    player_hurt,
    player_death,
    eat,
    drink,
    burp,

    // Ranged
    bow_shoot,
    arrow_hit,

    // Explosions
    explosion_tnt,
    explosion_creeper,

    // Interactables
    door_open,
    door_close,
    chest_open,
    chest_close,
    anvil_use,
    anvil_land,

    // Progression
    enchant,
    level_up,
    experience_orb,

    // Environment
    ambient_cave,
    thunder,
    rain,
    fire_crackle,
    lava_pop,
    water_splash,

    // Villagers
    villager_trade,
    villager_hurt,

    // Hostile mobs
    zombie_growl,
    skeleton_rattle,
    creeper_hiss,
    enderman_stare,
    ghast_scream,
    blaze_breath,

    // Miscellaneous
    portal_ambient,
    beacon_activate,
    beacon_deactivate,
    note_block,
    piston_extend,
    piston_retract,
    music_disc,

    pub const count = @typeInfo(SoundEvent).@"enum".fields.len;
};

// ──────────────────────────────────────────────────────────────────────────────
// Sound Properties
// ──────────────────────────────────────────────────────────────────────────────

pub const SoundProperties = struct {
    volume: f32,
    pitch_min: f32,
    pitch_max: f32,
    category: SoundCategory,
    is_positional: bool,
};

/// Return the properties for a given sound event.  All volumes are in [0, 1].
pub fn getProperties(event: SoundEvent) SoundProperties {
    return switch (event) {
        // Blocks
        .block_break => .{ .volume = 1.0, .pitch_min = 0.8, .pitch_max = 1.0, .category = .blocks, .is_positional = true },
        .block_place => .{ .volume = 1.0, .pitch_min = 0.8, .pitch_max = 1.0, .category = .blocks, .is_positional = true },

        // Footsteps
        .step_grass => .{ .volume = 0.3, .pitch_min = 0.9, .pitch_max = 1.1, .category = .player, .is_positional = true },
        .step_stone => .{ .volume = 0.3, .pitch_min = 0.9, .pitch_max = 1.1, .category = .player, .is_positional = true },
        .step_wood => .{ .volume = 0.3, .pitch_min = 0.9, .pitch_max = 1.1, .category = .player, .is_positional = true },
        .step_sand => .{ .volume = 0.3, .pitch_min = 0.9, .pitch_max = 1.1, .category = .player, .is_positional = true },
        .step_gravel => .{ .volume = 0.3, .pitch_min = 0.9, .pitch_max = 1.1, .category = .player, .is_positional = true },
        .step_snow => .{ .volume = 0.3, .pitch_min = 0.9, .pitch_max = 1.1, .category = .player, .is_positional = true },

        // Combat
        .attack_swing => .{ .volume = 0.5, .pitch_min = 0.8, .pitch_max = 1.2, .category = .player, .is_positional = true },
        .attack_hit => .{ .volume = 0.7, .pitch_min = 0.8, .pitch_max = 1.2, .category = .player, .is_positional = true },

        // Player
        .player_hurt => .{ .volume = 1.0, .pitch_min = 0.8, .pitch_max = 1.0, .category = .player, .is_positional = true },
        .player_death => .{ .volume = 1.0, .pitch_min = 0.8, .pitch_max = 1.0, .category = .player, .is_positional = true },
        .eat => .{ .volume = 0.5, .pitch_min = 0.9, .pitch_max = 1.2, .category = .player, .is_positional = true },
        .drink => .{ .volume = 0.5, .pitch_min = 0.9, .pitch_max = 1.2, .category = .player, .is_positional = true },
        .burp => .{ .volume = 0.5, .pitch_min = 0.9, .pitch_max = 1.0, .category = .player, .is_positional = true },

        // Ranged
        .bow_shoot => .{ .volume = 1.0, .pitch_min = 0.8, .pitch_max = 1.2, .category = .player, .is_positional = true },
        .arrow_hit => .{ .volume = 0.8, .pitch_min = 0.9, .pitch_max = 1.1, .category = .player, .is_positional = true },

        // Explosions
        .explosion_tnt => .{ .volume = 1.0, .pitch_min = 0.9, .pitch_max = 1.0, .category = .blocks, .is_positional = true },
        .explosion_creeper => .{ .volume = 1.0, .pitch_min = 0.9, .pitch_max = 1.0, .category = .hostile, .is_positional = true },

        // Interactables
        .door_open => .{ .volume = 1.0, .pitch_min = 0.9, .pitch_max = 1.0, .category = .blocks, .is_positional = true },
        .door_close => .{ .volume = 1.0, .pitch_min = 0.9, .pitch_max = 1.0, .category = .blocks, .is_positional = true },
        .chest_open => .{ .volume = 0.5, .pitch_min = 0.9, .pitch_max = 1.0, .category = .blocks, .is_positional = true },
        .chest_close => .{ .volume = 0.5, .pitch_min = 0.9, .pitch_max = 1.0, .category = .blocks, .is_positional = true },
        .anvil_use => .{ .volume = 0.8, .pitch_min = 0.8, .pitch_max = 1.0, .category = .blocks, .is_positional = true },
        .anvil_land => .{ .volume = 1.0, .pitch_min = 0.7, .pitch_max = 0.8, .category = .blocks, .is_positional = true },

        // Progression
        .enchant => .{ .volume = 1.0, .pitch_min = 0.9, .pitch_max = 1.0, .category = .player, .is_positional = true },
        .level_up => .{ .volume = 1.0, .pitch_min = 1.0, .pitch_max = 1.0, .category = .player, .is_positional = false },
        .experience_orb => .{ .volume = 0.3, .pitch_min = 0.8, .pitch_max = 1.2, .category = .player, .is_positional = true },

        // Environment
        .ambient_cave => .{ .volume = 0.7, .pitch_min = 0.8, .pitch_max = 1.2, .category = .ambient, .is_positional = false },
        .thunder => .{ .volume = 1.0, .pitch_min = 0.8, .pitch_max = 1.0, .category = .weather, .is_positional = false },
        .rain => .{ .volume = 0.5, .pitch_min = 1.0, .pitch_max = 1.0, .category = .weather, .is_positional = false },
        .fire_crackle => .{ .volume = 0.5, .pitch_min = 0.9, .pitch_max = 1.1, .category = .blocks, .is_positional = true },
        .lava_pop => .{ .volume = 0.4, .pitch_min = 0.8, .pitch_max = 1.2, .category = .blocks, .is_positional = true },
        .water_splash => .{ .volume = 0.8, .pitch_min = 0.9, .pitch_max = 1.1, .category = .player, .is_positional = true },

        // Villagers
        .villager_trade => .{ .volume = 0.6, .pitch_min = 0.8, .pitch_max = 1.2, .category = .voice, .is_positional = true },
        .villager_hurt => .{ .volume = 0.8, .pitch_min = 0.8, .pitch_max = 1.0, .category = .voice, .is_positional = true },

        // Hostile mobs
        .zombie_growl => .{ .volume = 0.8, .pitch_min = 0.8, .pitch_max = 1.0, .category = .hostile, .is_positional = true },
        .skeleton_rattle => .{ .volume = 0.6, .pitch_min = 0.9, .pitch_max = 1.1, .category = .hostile, .is_positional = true },
        .creeper_hiss => .{ .volume = 1.0, .pitch_min = 0.9, .pitch_max = 1.0, .category = .hostile, .is_positional = true },
        .enderman_stare => .{ .volume = 0.8, .pitch_min = 0.8, .pitch_max = 1.0, .category = .hostile, .is_positional = true },
        .ghast_scream => .{ .volume = 1.0, .pitch_min = 0.8, .pitch_max = 1.0, .category = .hostile, .is_positional = true },
        .blaze_breath => .{ .volume = 0.7, .pitch_min = 0.9, .pitch_max = 1.1, .category = .hostile, .is_positional = true },

        // Miscellaneous
        .portal_ambient => .{ .volume = 0.5, .pitch_min = 0.8, .pitch_max = 1.2, .category = .ambient, .is_positional = true },
        .beacon_activate => .{ .volume = 1.0, .pitch_min = 1.0, .pitch_max = 1.0, .category = .blocks, .is_positional = true },
        .beacon_deactivate => .{ .volume = 1.0, .pitch_min = 1.0, .pitch_max = 1.0, .category = .blocks, .is_positional = true },
        .note_block => .{ .volume = 1.0, .pitch_min = 0.5, .pitch_max = 2.0, .category = .blocks, .is_positional = true },
        .piston_extend => .{ .volume = 0.5, .pitch_min = 0.9, .pitch_max = 1.0, .category = .blocks, .is_positional = true },
        .piston_retract => .{ .volume = 0.5, .pitch_min = 0.9, .pitch_max = 1.0, .category = .blocks, .is_positional = true },
        .music_disc => .{ .volume = 1.0, .pitch_min = 1.0, .pitch_max = 1.0, .category = .music, .is_positional = true },
    };
}

// ──────────────────────────────────────────────────────────────────────────────
// Sound Manager (data-only stub)
// ──────────────────────────────────────────────────────────────────────────────

pub const SoundManager = struct {
    category_volumes: [SoundCategory.count]f32,

    pub fn init() SoundManager {
        return .{ .category_volumes = [_]f32{1.0} ** SoundCategory.count };
    }

    /// Record a positional sound event (stub — no actual audio output).
    pub fn play(self: *SoundManager, event: SoundEvent, x: f32, y: f32, z: f32) void {
        _ = self;
        _ = event;
        _ = x;
        _ = y;
        _ = z;
    }

    /// Stop all currently-playing sounds (stub).
    pub fn stopAll(self: *SoundManager) void {
        _ = self;
    }

    /// Set the volume for a category, clamped to [0, 1].
    pub fn setVolume(self: *SoundManager, category: SoundCategory, volume: f32) void {
        self.category_volumes[@intFromEnum(category)] = std.math.clamp(volume, 0.0, 1.0);
    }

    /// Get the current volume for a category.
    pub fn getVolume(self: *const SoundManager, category: SoundCategory) f32 {
        return self.category_volumes[@intFromEnum(category)];
    }
};

// ──────────────────────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────────────────────

test "every SoundEvent has valid properties" {
    inline for (@typeInfo(SoundEvent).@"enum".fields) |field| {
        const event: SoundEvent = @enumFromInt(field.value);
        const props = getProperties(event);

        // Volume must be in [0, 1].
        try std.testing.expect(props.volume >= 0.0 and props.volume <= 1.0);
        // Pitch range must be positive and ordered.
        try std.testing.expect(props.pitch_min > 0.0);
        try std.testing.expect(props.pitch_max >= props.pitch_min);
    }
}

test "category assignment matches expectations" {
    const expect = std.testing.expect;

    try expect(getProperties(.block_break).category == .blocks);
    try expect(getProperties(.block_place).category == .blocks);
    try expect(getProperties(.step_grass).category == .player);
    try expect(getProperties(.player_hurt).category == .player);
    try expect(getProperties(.zombie_growl).category == .hostile);
    try expect(getProperties(.explosion_creeper).category == .hostile);
    try expect(getProperties(.thunder).category == .weather);
    try expect(getProperties(.rain).category == .weather);
    try expect(getProperties(.ambient_cave).category == .ambient);
    try expect(getProperties(.villager_trade).category == .voice);
    try expect(getProperties(.music_disc).category == .music);
}

test "SoundManager volume clamped 0-1" {
    var mgr = SoundManager.init();

    // Default volumes are 1.0
    try std.testing.expectEqual(@as(f32, 1.0), mgr.getVolume(.master));
    try std.testing.expectEqual(@as(f32, 1.0), mgr.getVolume(.music));

    // Set within range
    mgr.setVolume(.master, 0.5);
    try std.testing.expectEqual(@as(f32, 0.5), mgr.getVolume(.master));

    // Set below 0 — clamped to 0
    mgr.setVolume(.master, -1.0);
    try std.testing.expectEqual(@as(f32, 0.0), mgr.getVolume(.master));

    // Set above 1 — clamped to 1
    mgr.setVolume(.master, 2.0);
    try std.testing.expectEqual(@as(f32, 1.0), mgr.getVolume(.master));
}

test "SoundManager play and stopAll are callable" {
    var mgr = SoundManager.init();
    mgr.play(.block_break, 1.0, 2.0, 3.0);
    mgr.stopAll();
}

test "SoundEvent count is at least 49" {
    try std.testing.expect(SoundEvent.count >= 49);
}
