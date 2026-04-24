/// Snow Golem entity — throws snowballs at hostile mobs within 10 blocks every 1.5s,
/// melts in warm biomes (temperature > 1.0), and leaves a snow trail in cold biomes
/// (temperature < 0.8).
const std = @import("std");

/// Projectile launched by a snow golem toward a hostile mob.
pub const Snowball = struct {
    vx: f32,
    vy: f32,
    vz: f32,
};

pub const SnowGolem = struct {
    hp: f32 = max_hp,
    is_melting: bool = false,

    /// Accumulated time since last snowball throw (seconds).
    throw_cooldown: f32 = 0,

    // -- Constants --
    const max_hp: f32 = 4.0;
    const attack_range: f32 = 10.0;
    const throw_interval: f32 = 1.5;
    const melt_rate: f32 = 1.0;
    const melt_temp_threshold: f32 = 1.0;
    const snow_trail_temp_threshold: f32 = 0.8;
    const snowball_speed: f32 = 1.5;
    const snowball_arc_vy: f32 = 0.3;

    /// Main update tick.
    /// Returns a Snowball aimed at the nearest hostile if one is within range
    /// and the throw cooldown has elapsed; otherwise returns null.
    pub fn update(
        self: *SnowGolem,
        dt: f32,
        gx: f32,
        gy: f32,
        gz: f32,
        biome_temp: f32,
        nearest_hostile_x: f32,
        nearest_hostile_z: f32,
        hostile_dist: f32,
    ) ?Snowball {
        _ = gy;

        // Dead golems do nothing.
        if (self.hp <= 0) return null;

        // Melt in warm biomes.
        if (biome_temp > melt_temp_threshold) {
            self.is_melting = true;
            self.hp -= melt_rate * dt;
            if (self.hp <= 0) {
                self.hp = 0;
                return null;
            }
        } else {
            self.is_melting = false;
        }

        // Advance throw cooldown.
        self.throw_cooldown += dt;

        // Attempt to throw a snowball at the nearest hostile.
        if (hostile_dist <= attack_range and self.throw_cooldown >= throw_interval) {
            self.throw_cooldown = 0;
            return aimSnowball(gx, gz, nearest_hostile_x, nearest_hostile_z);
        }

        return null;
    }

    /// Whether this golem is still alive.
    pub fn isAlive(self: *const SnowGolem) bool {
        return self.hp > 0;
    }

    // -- Internal helpers --

    fn aimSnowball(gx: f32, gz: f32, tx: f32, tz: f32) Snowball {
        const dx = tx - gx;
        const dz = tz - gz;
        const dist = @sqrt(dx * dx + dz * dz);
        if (dist < 0.001) {
            return .{ .vx = 0, .vy = snowball_arc_vy, .vz = 0 };
        }
        return .{
            .vx = (dx / dist) * snowball_speed,
            .vy = snowball_arc_vy,
            .vz = (dz / dist) * snowball_speed,
        };
    }
};

/// Returns true when the biome temperature is cold enough for the snow golem
/// to leave a snow trail on the ground beneath it.
pub fn shouldLeaveSnowTrail(biome_temp: f32) bool {
    return biome_temp < SnowGolem.snow_trail_temp_threshold;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "default snow golem has 4 hp and is not melting" {
    const g = SnowGolem{};
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), g.hp, 0.001);
    try std.testing.expect(!g.is_melting);
    try std.testing.expect(g.isAlive());
}

test "throws snowball at hostile within 10 blocks after 1.5s cooldown" {
    var g = SnowGolem{};
    // First tick with enough dt to pass the cooldown.
    const result = g.update(1.5, 0, 0, 0, 0.5, 5, 0, 5);
    try std.testing.expect(result != null);
    const sb = result.?;
    // Snowball should head toward +x direction.
    try std.testing.expect(sb.vx > 0);
    try std.testing.expect(sb.vy > 0);
}

test "no snowball before cooldown elapses" {
    var g = SnowGolem{};
    const result = g.update(0.5, 0, 0, 0, 0.5, 5, 0, 5);
    try std.testing.expect(result == null);
}

test "no snowball when hostile is out of range" {
    var g = SnowGolem{};
    const result = g.update(2.0, 0, 0, 0, 0.5, 100, 0, 100);
    try std.testing.expect(result == null);
}

test "cooldown resets after throwing" {
    var g = SnowGolem{};
    // First throw.
    _ = g.update(1.5, 0, 0, 0, 0.5, 5, 0, 5);
    try std.testing.expectApproxEqAbs(@as(f32, 0), g.throw_cooldown, 0.001);

    // Immediately after, should not throw again.
    const result = g.update(0.1, 0, 0, 0, 0.5, 5, 0, 5);
    try std.testing.expect(result == null);
}

test "melts when biome temp exceeds 1.0" {
    var g = SnowGolem{};
    _ = g.update(1.0, 0, 0, 0, 1.5, 100, 0, 100);
    try std.testing.expect(g.is_melting);
    try std.testing.expect(g.hp < 4.0);
}

test "does not melt in cold biome" {
    var g = SnowGolem{};
    _ = g.update(1.0, 0, 0, 0, 0.5, 100, 0, 100);
    try std.testing.expect(!g.is_melting);
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), g.hp, 0.001);
}

test "melting kills golem when hp reaches zero" {
    var g = SnowGolem{};
    // Melt for 5 seconds in a hot biome (rate = 1.0/s, hp = 4).
    _ = g.update(5.0, 0, 0, 0, 1.5, 100, 0, 100);
    try std.testing.expect(!g.isAlive());
    try std.testing.expectApproxEqAbs(@as(f32, 0), g.hp, 0.001);
}

test "dead golem returns null" {
    var g = SnowGolem{};
    g.hp = 0;
    const result = g.update(2.0, 0, 0, 0, 0.5, 5, 0, 5);
    try std.testing.expect(result == null);
}

test "snowball velocity is normalized to speed" {
    var g = SnowGolem{};
    const result = g.update(1.5, 0, 0, 0, 0.5, 3, 4, 5);
    try std.testing.expect(result != null);
    const sb = result.?;
    const horiz_speed = @sqrt(sb.vx * sb.vx + sb.vz * sb.vz);
    try std.testing.expectApproxEqAbs(@as(f32, 1.5), horiz_speed, 0.01);
}

test "shouldLeaveSnowTrail returns true below 0.8" {
    try std.testing.expect(shouldLeaveSnowTrail(0.0));
    try std.testing.expect(shouldLeaveSnowTrail(0.5));
    try std.testing.expect(shouldLeaveSnowTrail(0.79));
}

test "shouldLeaveSnowTrail returns false at or above 0.8" {
    try std.testing.expect(!shouldLeaveSnowTrail(0.8));
    try std.testing.expect(!shouldLeaveSnowTrail(1.0));
    try std.testing.expect(!shouldLeaveSnowTrail(2.0));
}

test "snowball aimed at coincident target has zero horizontal velocity" {
    var g = SnowGolem{};
    const result = g.update(1.5, 5, 0, 5, 0.5, 5, 5, 0);
    try std.testing.expect(result != null);
    const sb = result.?;
    try std.testing.expectApproxEqAbs(@as(f32, 0), sb.vx, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), sb.vz, 0.001);
    try std.testing.expect(sb.vy > 0);
}

test "biome temp exactly 1.0 does not trigger melting" {
    var g = SnowGolem{};
    _ = g.update(1.0, 0, 0, 0, 1.0, 100, 0, 100);
    try std.testing.expect(!g.is_melting);
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), g.hp, 0.001);
}

test "multiple throws with accumulated cooldown" {
    var g = SnowGolem{};
    // First throw.
    const r1 = g.update(1.5, 0, 0, 0, 0.5, 5, 0, 5);
    try std.testing.expect(r1 != null);
    // Accumulate 1.5s again.
    const r2 = g.update(1.5, 0, 0, 0, 0.5, 5, 0, 5);
    try std.testing.expect(r2 != null);
}
