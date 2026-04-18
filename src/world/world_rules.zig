/// World rules system: difficulty, spawn point, world border, mob damage scaling.
/// Controls global gameplay parameters that affect survival mechanics.

const std = @import("std");

pub const Difficulty = enum {
    peaceful,
    easy,
    normal,
    hard,
};

pub const WorldRules = struct {
    difficulty: Difficulty = .normal,
    spawn_x: f32 = 8.0,
    spawn_y: f32 = 70.0,
    spawn_z: f32 = 8.0,
    border_radius: f32 = 10000.0,
    border_damage_per_sec: f32 = 1.0,
    center_x: f32 = 0.0,
    center_z: f32 = 0.0,

    pub fn init() WorldRules {
        return .{};
    }

    /// Return the spawn point as three floats.
    pub fn getSpawnPoint(self: *const WorldRules) struct { x: f32, y: f32, z: f32 } {
        return .{ .x = self.spawn_x, .y = self.spawn_y, .z = self.spawn_z };
    }

    /// Check whether the given position is outside the world border.
    pub fn isOutsideBorder(self: *const WorldRules, x: f32, z: f32) bool {
        const dx = x - self.center_x;
        const dz = z - self.center_z;
        return (dx * dx + dz * dz) > (self.border_radius * self.border_radius);
    }

    /// Damage per second applied when outside the world border.
    pub fn getBorderDamage(self: *const WorldRules) f32 {
        return self.border_damage_per_sec;
    }

    /// Multiplier applied to mob melee damage based on difficulty.
    pub fn getMobDamageMultiplier(self: *const WorldRules) f32 {
        return switch (self.difficulty) {
            .peaceful => 0.0,
            .easy => 0.5,
            .normal => 1.0,
            .hard => 1.5,
        };
    }
};

// ──────────────────────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────────────────────

test "init returns sensible defaults" {
    const rules = WorldRules.init();
    try std.testing.expectEqual(Difficulty.normal, rules.difficulty);
    try std.testing.expectApproxEqAbs(@as(f32, 8.0), rules.spawn_x, 0.001);
}

test "getSpawnPoint returns configured spawn" {
    var rules = WorldRules.init();
    rules.spawn_x = 100.0;
    rules.spawn_y = 65.0;
    rules.spawn_z = -50.0;
    const sp = rules.getSpawnPoint();
    try std.testing.expectApproxEqAbs(@as(f32, 100.0), sp.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 65.0), sp.y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, -50.0), sp.z, 0.001);
}

test "isOutsideBorder detects outside" {
    var rules = WorldRules.init();
    rules.border_radius = 100.0;
    try std.testing.expect(!rules.isOutsideBorder(50.0, 50.0));
    try std.testing.expect(rules.isOutsideBorder(200.0, 200.0));
}

test "getMobDamageMultiplier varies by difficulty" {
    var rules = WorldRules.init();
    rules.difficulty = .peaceful;
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), rules.getMobDamageMultiplier(), 0.001);
    rules.difficulty = .easy;
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), rules.getMobDamageMultiplier(), 0.001);
    rules.difficulty = .normal;
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), rules.getMobDamageMultiplier(), 0.001);
    rules.difficulty = .hard;
    try std.testing.expectApproxEqAbs(@as(f32, 1.5), rules.getMobDamageMultiplier(), 0.001);
}

test "getBorderDamage returns configured value" {
    var rules = WorldRules.init();
    rules.border_damage_per_sec = 2.5;
    try std.testing.expectApproxEqAbs(@as(f32, 2.5), rules.getBorderDamage(), 0.001);
}
