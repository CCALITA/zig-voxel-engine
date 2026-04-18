/// MobSpawner: periodic mob spawning and despawning logic.
/// Controls spawn timing, placement attempts around the player, and
/// distance-based despawning of mobs that wander too far.
const std = @import("std");
const entity_mod = @import("entity.zig");

/// Maximum number of spawn attempts returned per tick.
pub const MAX_SPAWN_ATTEMPTS = 8;

/// A single spawn attempt: position and entity type.
pub const SpawnAttempt = struct {
    x: f32,
    y: f32,
    z: f32,
    entity_type: entity_mod.EntityType,
};

/// Mob caps — spawner will not generate attempts when the manager already
/// holds this many mobs of the corresponding category.
const PASSIVE_CAP: usize = 20;
const HOSTILE_CAP: usize = 15;

/// Distance (in blocks) beyond which a mob is eligible for despawning.
const DESPAWN_DISTANCE: f32 = 128.0;

/// Minimum spawn distance from the player (blocks).
const MIN_SPAWN_DIST: f32 = 24.0;
/// Maximum spawn distance from the player (blocks).
const MAX_SPAWN_DIST: f32 = 64.0;

/// Fixed Y for surface spawns (simplified; a real implementation would
/// sample the heightmap).
const SPAWN_Y: f32 = 70.0;

pub const MobSpawner = struct {
    /// Accumulated time since last spawn cycle (seconds).
    timer: f32 = 0.0,
    /// Interval between spawn cycles.
    interval: f32 = 5.0,
    /// Simple PRNG state for positioning.
    rng_state: u64 = 12345,

    pub fn init() MobSpawner {
        return .{};
    }

    /// Advance the spawn timer. Returns `true` when a spawn cycle should
    /// execute (every `interval` seconds).
    pub fn update(self: *MobSpawner, dt: f32) bool {
        self.timer += dt;
        if (self.timer >= self.interval) {
            self.timer -= self.interval;
            return true;
        }
        return false;
    }

    /// Produce up to MAX_SPAWN_ATTEMPTS spawn attempts for this cycle.
    pub fn getSpawnAttempts(
        self: *MobSpawner,
        player_x: f32,
        player_z: f32,
        is_night: bool,
        current_mob_count: usize,
    ) [MAX_SPAWN_ATTEMPTS]?SpawnAttempt {
        var result: [MAX_SPAWN_ATTEMPTS]?SpawnAttempt = .{null} ** MAX_SPAWN_ATTEMPTS;

        // Respect global mob cap (passive + hostile combined).
        const total_cap = PASSIVE_CAP + HOSTILE_CAP;
        if (current_mob_count >= total_cap) return result;

        const slots = @min(MAX_SPAWN_ATTEMPTS, total_cap - current_mob_count);
        for (0..slots) |i| {
            // Pick a random offset in the spawn ring around the player.
            const angle = self.nextFloat() * std.math.pi * 2.0;
            const dist = MIN_SPAWN_DIST + self.nextFloat() * (MAX_SPAWN_DIST - MIN_SPAWN_DIST);
            const ox = @cos(angle) * dist;
            const oz = @sin(angle) * dist;

            // Select entity type.
            const etype: entity_mod.EntityType = if (is_night and self.nextFloat() < 0.4)
                self.pickHostile()
            else
                self.pickPassive();

            result[i] = .{
                .x = player_x + ox,
                .y = SPAWN_Y,
                .z = player_z + oz,
                .entity_type = etype,
            };
        }

        return result;
    }

    /// Returns `true` when the mob at `(mx, mz)` should despawn because it
    /// is too far from the player at `(px, pz)`.
    pub fn shouldDespawn(_: *const MobSpawner, mx: f32, mz: f32, px: f32, pz: f32) bool {
        const dx = mx - px;
        const dz = mz - pz;
        return @sqrt(dx * dx + dz * dz) > DESPAWN_DISTANCE;
    }

    // -- Internal helpers ---------------------------------------------------

    fn pickHostile(self: *MobSpawner) entity_mod.EntityType {
        const roll = self.nextFloat();
        if (roll < 0.4) return .zombie;
        if (roll < 0.75) return .skeleton;
        return .creeper;
    }

    fn pickPassive(self: *MobSpawner) entity_mod.EntityType {
        const roll = self.nextFloat();
        if (roll < 0.25) return .pig;
        if (roll < 0.50) return .cow;
        if (roll < 0.75) return .sheep;
        return .chicken;
    }

    /// Simple xorshift64 PRNG returning a float in [0, 1).
    fn nextFloat(self: *MobSpawner) f32 {
        self.rng_state ^= self.rng_state << 13;
        self.rng_state ^= self.rng_state >> 7;
        self.rng_state ^= self.rng_state << 17;
        const bits: u32 = @truncate(self.rng_state);
        return @as(f32, @floatFromInt(bits & 0x7FFF)) / 32768.0;
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "update returns true after interval" {
    var s = MobSpawner.init();
    try std.testing.expect(!s.update(1.0));
    try std.testing.expect(!s.update(1.0));
    try std.testing.expect(!s.update(1.0));
    try std.testing.expect(!s.update(1.0));
    // 5th second should trigger
    try std.testing.expect(s.update(1.0));
}

test "update returns false before interval" {
    var s = MobSpawner.init();
    try std.testing.expect(!s.update(0.5));
    try std.testing.expect(!s.update(0.5));
    try std.testing.expect(!s.update(0.5));
}

test "getSpawnAttempts respects mob cap" {
    var s = MobSpawner.init();
    const attempts = s.getSpawnAttempts(0, 0, false, 35);
    // All slots should be null when at cap.
    for (attempts) |a| {
        try std.testing.expect(a == null);
    }
}

test "getSpawnAttempts produces attempts when under cap" {
    var s = MobSpawner.init();
    const attempts = s.getSpawnAttempts(0, 0, false, 0);
    // At least the first slot should be non-null.
    try std.testing.expect(attempts[0] != null);
}

test "shouldDespawn far mob" {
    const s = MobSpawner.init();
    try std.testing.expect(s.shouldDespawn(200.0, 200.0, 0.0, 0.0));
}

test "shouldDespawn nearby mob" {
    const s = MobSpawner.init();
    try std.testing.expect(!s.shouldDespawn(10.0, 10.0, 0.0, 0.0));
}

test "spawn attempts are within distance ring" {
    var s = MobSpawner.init();
    const attempts = s.getSpawnAttempts(100.0, 100.0, false, 0);
    for (attempts) |maybe| {
        if (maybe) |a| {
            const dx = a.x - 100.0;
            const dz = a.z - 100.0;
            const dist = @sqrt(dx * dx + dz * dz);
            try std.testing.expect(dist >= MIN_SPAWN_DIST - 1.0);
            try std.testing.expect(dist <= MAX_SPAWN_DIST + 1.0);
        }
    }
}

test "hostile mobs spawn at night" {
    var s = MobSpawner.init();
    // Run many attempts to check that at least one hostile spawns at night.
    var found_hostile = false;
    for (0..10) |_| {
        const attempts = s.getSpawnAttempts(0, 0, true, 0);
        for (attempts) |maybe| {
            if (maybe) |a| {
                if (a.entity_type.isHostile()) {
                    found_hostile = true;
                }
            }
        }
    }
    try std.testing.expect(found_hostile);
}
