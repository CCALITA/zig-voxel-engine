/// Mob spawning rules based on time, biome, and light.
/// Every 20 seconds, attempts up to 4 spawns in a ring around the player.
/// Night spawns hostile mobs; day spawns passive mobs. Respects population caps
/// and uses deterministic noise for spawn positions.
const std = @import("std");

// ──────────────────────────────────────────────────────────────────────────────
// Public types
// ──────────────────────────────────────────────────────────────────────────────

pub const SpawnAttempt = struct {
    entity_type: u8, // matches EntityType enum values
    x: f32,
    y: f32,
    z: f32,
};

pub const SpawnRules = struct {
    hostile_cap: u32 = 70,
    passive_cap: u32 = 10,
    min_distance: f32 = 24.0,
    max_distance: f32 = 128.0,
    despawn_distance: f32 = 128.0,
};

// ──────────────────────────────────────────────────────────────────────────────
// EntityType enum values (mirrored from entity.zig to avoid cross-module import)
// ──────────────────────────────────────────────────────────────────────────────

const entity_zombie: u8 = 1;
const entity_skeleton: u8 = 2;
const entity_creeper: u8 = 3;
const entity_pig: u8 = 4;
const entity_cow: u8 = 5;
const entity_chicken: u8 = 6;
const entity_sheep: u8 = 7;

// ──────────────────────────────────────────────────────────────────────────────
// Time constants (mirrored from world/time.zig)
// ──────────────────────────────────────────────────────────────────────────────

const night_start: u32 = 13000;
const night_end: u32 = 23000;

// ──────────────────────────────────────────────────────────────────────────────
// Spawn interval
// ──────────────────────────────────────────────────────────────────────────────

const spawn_interval: f32 = 20.0;
const max_spawns: usize = 4;

// ──────────────────────────────────────────────────────────────────────────────
// MobSpawner
// ──────────────────────────────────────────────────────────────────────────────

pub const MobSpawner = struct {
    rules: SpawnRules,
    spawn_timer: f32,
    seed: u64,

    pub fn init(seed: u64) MobSpawner {
        return .{
            .rules = .{},
            .spawn_timer = 0,
            .seed = seed,
        };
    }

    /// Advance the spawn timer by `dt` seconds. Returns true when a spawn
    /// tick fires (every 20 seconds).
    pub fn update(self: *MobSpawner, dt: f32) bool {
        self.spawn_timer += dt;
        if (self.spawn_timer >= spawn_interval) {
            self.spawn_timer -= spawn_interval;
            return true;
        }
        return false;
    }

    /// Generate spawn attempts for this tick.
    /// `is_night` should be true when the game tick is in [13000, 23000).
    /// Returns a fixed-size array of optional spawn attempts (up to 4 filled).
    pub fn getSpawnAttempts(
        self: *MobSpawner,
        player_x: f32,
        player_z: f32,
        is_night: bool,
        current_hostile: u32,
        current_passive: u32,
    ) [max_spawns]?SpawnAttempt {
        var results: [max_spawns]?SpawnAttempt = .{null} ** max_spawns;

        if (is_night and current_hostile >= self.rules.hostile_cap) return results;
        if (!is_night and current_passive >= self.rules.passive_cap) return results;

        var rng_state = self.seed;

        for (0..max_spawns) |i| {
            rng_state = splitmix64(rng_state +% @as(u64, i));

            const angle = hashToFloat(rng_state) * std.math.pi * 2.0;
            rng_state = splitmix64(rng_state);
            const distance = self.rules.min_distance +
                hashToFloat(rng_state) * (self.rules.max_distance - self.rules.min_distance);

            const spawn_x = player_x + @cos(angle) * distance;
            const spawn_z = player_z + @sin(angle) * distance;

            rng_state = splitmix64(rng_state);
            const entity_type = if (is_night)
                pickHostile(rng_state)
            else
                pickPassive(rng_state);

            results[i] = .{
                .entity_type = entity_type,
                .x = spawn_x,
                .y = 64.0, // surface level
                .z = spawn_z,
            };
        }

        self.seed = splitmix64(rng_state);

        return results;
    }

    /// Check if an entity should despawn (too far from player).
    pub fn shouldDespawn(
        self: *const MobSpawner,
        entity_x: f32,
        entity_z: f32,
        player_x: f32,
        player_z: f32,
    ) bool {
        const dx = entity_x - player_x;
        const dz = entity_z - player_z;
        const dist_sq = dx * dx + dz * dz;
        return dist_sq >= self.rules.despawn_distance * self.rules.despawn_distance;
    }
};

// ──────────────────────────────────────────────────────────────────────────────
// Mob selection helpers
// ──────────────────────────────────────────────────────────────────────────────

/// Pick a hostile mob type: zombie 50%, skeleton 30%, creeper 20%.
fn pickHostile(state: u64) u8 {
    const roll = hashToPercent(state);
    if (roll < 50) return entity_zombie;
    if (roll < 80) return entity_skeleton;
    return entity_creeper;
}

/// Pick a passive mob type: pig 30%, cow 25%, sheep 25%, chicken 20%.
fn pickPassive(state: u64) u8 {
    const roll = hashToPercent(state);
    if (roll < 30) return entity_pig;
    if (roll < 55) return entity_cow;
    if (roll < 80) return entity_sheep;
    return entity_chicken;
}

// ──────────────────────────────────────────────────────────────────────────────
// PRNG helpers (splitmix64 — same as noise.zig)
// ──────────────────────────────────────────────────────────────────────────────

fn splitmix64(state: u64) u64 {
    var s = state +% 0x9e3779b97f4a7c15;
    s = (s ^ (s >> 30)) *% 0xbf58476d1ce4e5b9;
    s = (s ^ (s >> 27)) *% 0x94d049bb133111eb;
    return s ^ (s >> 31);
}

/// Map a u64 hash to a float in [0, 1).
fn hashToFloat(h: u64) f32 {
    return @as(f32, @floatFromInt(h & 0xFFFFFF)) / @as(f32, 0x1000000);
}

/// Map a u64 hash to an integer in [0, 100).
fn hashToPercent(h: u64) u32 {
    return @as(u32, @intCast(h % 100));
}

/// Return true when the game tick represents night (hostile spawn window).
pub fn isNightTick(tick: u32) bool {
    return tick >= night_start and tick < night_end;
}

// ──────────────────────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────────────────────

test "spawner triggers after timer reaches 20s" {
    var spawner = MobSpawner.init(42);
    // 19 seconds -- should not trigger
    try std.testing.expect(!spawner.update(19.0));
    // 1 more second -- should trigger
    try std.testing.expect(spawner.update(1.0));
}

test "spawner does not trigger before 20s" {
    var spawner = MobSpawner.init(42);
    try std.testing.expect(!spawner.update(10.0));
    try std.testing.expect(!spawner.update(5.0));
    try std.testing.expect(!spawner.update(4.9));
}

test "spawner triggers multiple times" {
    var spawner = MobSpawner.init(42);
    try std.testing.expect(spawner.update(20.0));
    try std.testing.expect(!spawner.update(10.0));
    try std.testing.expect(spawner.update(10.0));
}

test "hostile spawns only at night" {
    var spawner = MobSpawner.init(123);
    const results = spawner.getSpawnAttempts(0, 0, true, 0, 0);

    var count: usize = 0;
    for (results) |maybe| {
        if (maybe) |attempt| {
            // All spawned types must be hostile
            try std.testing.expect(
                attempt.entity_type == entity_zombie or
                    attempt.entity_type == entity_skeleton or
                    attempt.entity_type == entity_creeper,
            );
            count += 1;
        }
    }
    try std.testing.expect(count == max_spawns);
}

test "passive spawns only during day" {
    var spawner = MobSpawner.init(456);
    const results = spawner.getSpawnAttempts(0, 0, false, 0, 0);

    var count: usize = 0;
    for (results) |maybe| {
        if (maybe) |attempt| {
            // All spawned types must be passive
            try std.testing.expect(
                attempt.entity_type == entity_pig or
                    attempt.entity_type == entity_cow or
                    attempt.entity_type == entity_sheep or
                    attempt.entity_type == entity_chicken,
            );
            count += 1;
        }
    }
    try std.testing.expect(count == max_spawns);
}

test "respects hostile cap" {
    var spawner = MobSpawner.init(789);
    const results = spawner.getSpawnAttempts(0, 0, true, 70, 0);
    for (results) |maybe| {
        try std.testing.expect(maybe == null);
    }
}

test "respects passive cap" {
    var spawner = MobSpawner.init(789);
    const results = spawner.getSpawnAttempts(0, 0, false, 0, 10);
    for (results) |maybe| {
        try std.testing.expect(maybe == null);
    }
}

test "spawns within distance ring" {
    var spawner = MobSpawner.init(1001);
    const px: f32 = 100.0;
    const pz: f32 = 200.0;
    const results = spawner.getSpawnAttempts(px, pz, true, 0, 0);

    for (results) |maybe| {
        if (maybe) |attempt| {
            const dx = attempt.x - px;
            const dz = attempt.z - pz;
            const dist = @sqrt(dx * dx + dz * dz);
            try std.testing.expect(dist >= spawner.rules.min_distance - 0.1);
            try std.testing.expect(dist <= spawner.rules.max_distance + 0.1);
        }
    }
}

test "despawn distance check" {
    const spawner = MobSpawner.init(42);
    // Entity at exactly despawn distance
    try std.testing.expect(spawner.shouldDespawn(128, 0, 0, 0));
    // Entity well beyond despawn distance
    try std.testing.expect(spawner.shouldDespawn(200, 0, 0, 0));
    // Entity within despawn distance
    try std.testing.expect(!spawner.shouldDespawn(50, 0, 0, 0));
    // Entity just under despawn distance
    try std.testing.expect(!spawner.shouldDespawn(90, 90, 0, 0));
}

test "isNightTick boundaries" {
    try std.testing.expect(!isNightTick(0));
    try std.testing.expect(!isNightTick(12999));
    try std.testing.expect(isNightTick(13000));
    try std.testing.expect(isNightTick(18000));
    try std.testing.expect(isNightTick(22999));
    try std.testing.expect(!isNightTick(23000));
}

test "deterministic spawn positions" {
    var s1 = MobSpawner.init(42);
    var s2 = MobSpawner.init(42);
    const r1 = s1.getSpawnAttempts(10, 20, true, 0, 0);
    const r2 = s2.getSpawnAttempts(10, 20, true, 0, 0);
    for (r1, r2) |a, b| {
        if (a) |aa| {
            const bb = b.?;
            try std.testing.expectEqual(aa.entity_type, bb.entity_type);
            try std.testing.expectEqual(aa.x, bb.x);
            try std.testing.expectEqual(aa.z, bb.z);
        } else {
            try std.testing.expect(b == null);
        }
    }
}

test "hostile distribution covers all types" {
    // Run enough iterations that all three types should appear
    var saw_zombie = false;
    var saw_skeleton = false;
    var saw_creeper = false;
    for (0..200) |i| {
        const t = pickHostile(splitmix64(@as(u64, i) *% 31337));
        if (t == entity_zombie) saw_zombie = true;
        if (t == entity_skeleton) saw_skeleton = true;
        if (t == entity_creeper) saw_creeper = true;
    }
    try std.testing.expect(saw_zombie);
    try std.testing.expect(saw_skeleton);
    try std.testing.expect(saw_creeper);
}

test "passive distribution covers all types" {
    var saw_pig = false;
    var saw_cow = false;
    var saw_sheep = false;
    var saw_chicken = false;
    for (0..200) |i| {
        const t = pickPassive(splitmix64(@as(u64, i) *% 31337));
        if (t == entity_pig) saw_pig = true;
        if (t == entity_cow) saw_cow = true;
        if (t == entity_sheep) saw_sheep = true;
        if (t == entity_chicken) saw_chicken = true;
    }
    try std.testing.expect(saw_pig);
    try std.testing.expect(saw_cow);
    try std.testing.expect(saw_sheep);
    try std.testing.expect(saw_chicken);
}
