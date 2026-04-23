const std = @import("std");

pub const Difficulty = enum(u2) {
    peaceful,
    easy,
    normal,
    hard,
};

pub const Stat = enum {
    mob_damage,
    hunger_drain,
    spawn_rate,
    mob_hp,
};

/// Returns the difficulty multiplier for a given stat.
/// Peaceful zeroes out damage/hunger/spawns; normal is the 1.0 baseline.
pub fn getMultiplier(diff: Difficulty, stat: Stat) f32 {
    const table = [4][4]f32{
        // peaceful: mob_damage, hunger_drain, spawn_rate, mob_hp
        .{ 0.0, 0.0, 0.0, 0.0 },
        // easy
        .{ 0.5, 0.5, 0.75, 0.75 },
        // normal
        .{ 1.0, 1.0, 1.0, 1.0 },
        // hard
        .{ 1.5, 1.5, 1.5, 1.25 },
    };
    return table[@intFromEnum(diff)][@intFromEnum(stat)];
}

/// Hostile mobs can spawn on every difficulty except peaceful.
pub fn mobsCanSpawn(diff: Difficulty) bool {
    return diff != .peaceful;
}

/// The player can starve to death only on normal and hard.
pub fn playerStarves(diff: Difficulty) bool {
    return switch (diff) {
        .peaceful, .easy => false,
        .normal, .hard => true,
    };
}

// --- Tests ---

test "peaceful multipliers are all zero" {
    try std.testing.expectEqual(@as(f32, 0.0), getMultiplier(.peaceful, .mob_damage));
    try std.testing.expectEqual(@as(f32, 0.0), getMultiplier(.peaceful, .hunger_drain));
    try std.testing.expectEqual(@as(f32, 0.0), getMultiplier(.peaceful, .spawn_rate));
    try std.testing.expectEqual(@as(f32, 0.0), getMultiplier(.peaceful, .mob_hp));
}

test "easy multipliers" {
    try std.testing.expectEqual(@as(f32, 0.5), getMultiplier(.easy, .mob_damage));
    try std.testing.expectEqual(@as(f32, 0.5), getMultiplier(.easy, .hunger_drain));
    try std.testing.expectEqual(@as(f32, 0.75), getMultiplier(.easy, .spawn_rate));
    try std.testing.expectEqual(@as(f32, 0.75), getMultiplier(.easy, .mob_hp));
}

test "normal multipliers are all 1.0" {
    inline for (std.meta.fields(Stat)) |field| {
        const stat: Stat = @enumFromInt(field.value);
        try std.testing.expectEqual(@as(f32, 1.0), getMultiplier(.normal, stat));
    }
}

test "hard multipliers" {
    try std.testing.expectEqual(@as(f32, 1.5), getMultiplier(.hard, .mob_damage));
    try std.testing.expectEqual(@as(f32, 1.5), getMultiplier(.hard, .hunger_drain));
    try std.testing.expectEqual(@as(f32, 1.5), getMultiplier(.hard, .spawn_rate));
    try std.testing.expectEqual(@as(f32, 1.25), getMultiplier(.hard, .mob_hp));
}

test "mobs cannot spawn in peaceful" {
    try std.testing.expect(!mobsCanSpawn(.peaceful));
}

test "mobs can spawn on easy, normal, and hard" {
    try std.testing.expect(mobsCanSpawn(.easy));
    try std.testing.expect(mobsCanSpawn(.normal));
    try std.testing.expect(mobsCanSpawn(.hard));
}

test "player does not starve in peaceful" {
    try std.testing.expect(!playerStarves(.peaceful));
}

test "player does not starve on easy" {
    try std.testing.expect(!playerStarves(.easy));
}

test "player starves on normal and hard" {
    try std.testing.expect(playerStarves(.normal));
    try std.testing.expect(playerStarves(.hard));
}

test "difficulty enum has exactly four values" {
    const fields = std.meta.fields(Difficulty);
    try std.testing.expectEqual(@as(usize, 4), fields.len);
}

test "multipliers increase monotonically for mob_damage" {
    const p = getMultiplier(.peaceful, .mob_damage);
    const e = getMultiplier(.easy, .mob_damage);
    const n = getMultiplier(.normal, .mob_damage);
    const h = getMultiplier(.hard, .mob_damage);
    try std.testing.expect(p <= e);
    try std.testing.expect(e <= n);
    try std.testing.expect(n <= h);
}

test "multipliers increase monotonically for spawn_rate" {
    const p = getMultiplier(.peaceful, .spawn_rate);
    const e = getMultiplier(.easy, .spawn_rate);
    const n = getMultiplier(.normal, .spawn_rate);
    const h = getMultiplier(.hard, .spawn_rate);
    try std.testing.expect(p <= e);
    try std.testing.expect(e <= n);
    try std.testing.expect(n <= h);
}
