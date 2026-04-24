/// Phantom mob behavior: circles above the player at y+20, swoops every 10s
/// to deal 6 damage, burns in daylight at 1 dmg/s, and spawns after 72000
/// ticks of player insomnia.
const std = @import("std");

/// Result returned when a swoop lands a hit on the player.
pub const SwoopHit = struct {
    damage: f32,
};

pub const Phase = enum(u2) {
    circling,
    swooping,
    retreating,
};

pub const Phantom = struct {
    hp: f32 = max_hp,
    swoop_cooldown: f32 = 0,
    target_x: f32 = 0,
    target_y: f32 = 0,
    target_z: f32 = 0,
    phase: Phase = .circling,

    const max_hp: f32 = 20.0;
    const circle_altitude: f32 = 20.0;
    const swoop_interval: f32 = 10.0;
    const swoop_damage: f32 = 6.0;
    const hit_radius: f32 = 1.5;
    const daylight_dps: f32 = 1.0;
    const spawn_threshold: u64 = 72_000;

    /// Advance the phantom by `dt` seconds. The player is at (px, py, pz) and
    /// the phantom is at (phx, phy, phz). Returns a `SwoopHit` when the
    /// phantom deals damage during a swoop, or null otherwise.
    pub fn update(
        self: *Phantom,
        dt: f32,
        px: f32,
        py: f32,
        pz: f32,
        phx: f32,
        phy: f32,
        phz: f32,
    ) ?SwoopHit {
        switch (self.phase) {
            .circling => {
                self.target_x = px;
                self.target_y = py + circle_altitude;
                self.target_z = pz;
                self.swoop_cooldown = @max(self.swoop_cooldown - dt, 0);
                if (self.swoop_cooldown <= 0) {
                    self.phase = .swooping;
                    self.target_x = px;
                    self.target_y = py;
                    self.target_z = pz;
                }
                return null;
            },
            .swooping => {
                self.target_x = px;
                self.target_y = py;
                self.target_z = pz;
                const dist = distance(phx, phy, phz, px, py, pz);
                if (dist <= hit_radius) {
                    self.phase = .retreating;
                    self.swoop_cooldown = swoop_interval;
                    return SwoopHit{ .damage = swoop_damage };
                }
                // If the swoop has been going for long enough that we
                // overshot, retreat without dealing damage.
                if (phy < py - 2.0) {
                    self.phase = .retreating;
                    self.swoop_cooldown = swoop_interval;
                }
                return null;
            },
            .retreating => {
                self.target_x = px;
                self.target_y = py + circle_altitude;
                self.target_z = pz;
                const altitude_diff = @abs(phy - (py + circle_altitude));
                if (altitude_diff < 1.0) {
                    self.phase = .circling;
                }
                return null;
            },
        }
    }

    /// Whether a phantom should spawn based on the number of ticks the player
    /// has been awake (without sleeping).
    pub fn shouldSpawn(ticks_awake: u64) bool {
        return ticks_awake >= spawn_threshold;
    }

    /// Damage dealt to the phantom per second when exposed to daylight.
    /// Returns 1 dmg/s in daytime, 0 otherwise.
    pub fn burnInDaylight(is_day: bool) f32 {
        return if (is_day) daylight_dps else 0;
    }

    fn distance(ax: f32, ay: f32, az: f32, bx: f32, by: f32, bz: f32) f32 {
        const dx = ax - bx;
        const dy = ay - by;
        const dz = az - bz;
        return @sqrt(dx * dx + dy * dy + dz * dz);
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "default phantom starts in circling phase with full hp" {
    const p = Phantom{};
    try std.testing.expectEqual(Phase.circling, p.phase);
    try std.testing.expectEqual(@as(f32, 20.0), p.hp);
    try std.testing.expectEqual(@as(f32, 0), p.swoop_cooldown);
}

test "circling sets target above player" {
    var p = Phantom{ .swoop_cooldown = 5.0 };
    _ = p.update(1.0, 10.0, 64.0, 10.0, 10.0, 84.0, 10.0);
    try std.testing.expectEqual(@as(f32, 10.0), p.target_x);
    try std.testing.expectEqual(@as(f32, 84.0), p.target_y);
    try std.testing.expectEqual(@as(f32, 10.0), p.target_z);
}

test "circling decrements swoop_cooldown" {
    var p = Phantom{ .swoop_cooldown = 5.0 };
    _ = p.update(2.0, 0, 0, 0, 0, 20, 0);
    try std.testing.expectEqual(@as(f32, 3.0), p.swoop_cooldown);
}

test "transitions to swooping when cooldown reaches zero" {
    var p = Phantom{ .swoop_cooldown = 1.0 };
    _ = p.update(1.0, 5.0, 60.0, 5.0, 5.0, 80.0, 5.0);
    try std.testing.expectEqual(Phase.swooping, p.phase);
}

test "swooping returns damage on hit within radius" {
    var p = Phantom{ .phase = .swooping };
    const result = p.update(0.1, 10.0, 64.0, 10.0, 10.0, 64.0, 10.0);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(f32, 6.0), result.?.damage);
    try std.testing.expectEqual(Phase.retreating, p.phase);
}

test "swooping returns null when far from player" {
    var p = Phantom{ .phase = .swooping };
    const result = p.update(0.1, 10.0, 64.0, 10.0, 10.0, 74.0, 10.0);
    try std.testing.expect(result == null);
    try std.testing.expectEqual(Phase.swooping, p.phase);
}

test "swooping retreats without damage when below player" {
    var p = Phantom{ .phase = .swooping };
    // phantom is well below the player (py=64, phy=60 → 60 < 64-2)
    const result = p.update(0.1, 10.0, 64.0, 10.0, 10.0, 60.0, 10.0);
    try std.testing.expect(result == null);
    try std.testing.expectEqual(Phase.retreating, p.phase);
}

test "retreating transitions to circling near target altitude" {
    var p = Phantom{ .phase = .retreating };
    // phantom is at py+20 already → altitude_diff < 1
    _ = p.update(0.1, 0, 64.0, 0, 0, 84.0, 0);
    try std.testing.expectEqual(Phase.circling, p.phase);
}

test "shouldSpawn returns false below threshold" {
    try std.testing.expect(!Phantom.shouldSpawn(71_999));
    try std.testing.expect(!Phantom.shouldSpawn(0));
}

test "shouldSpawn returns true at and above threshold" {
    try std.testing.expect(Phantom.shouldSpawn(72_000));
    try std.testing.expect(Phantom.shouldSpawn(100_000));
}

test "burnInDaylight returns 1 during day and 0 at night" {
    try std.testing.expectEqual(@as(f32, 1.0), Phantom.burnInDaylight(true));
    try std.testing.expectEqual(@as(f32, 0.0), Phantom.burnInDaylight(false));
}

test "swoop cooldown resets after hit" {
    var p = Phantom{ .phase = .swooping, .swoop_cooldown = 0 };
    _ = p.update(0.1, 0, 0, 0, 0, 0, 0);
    try std.testing.expectEqual(@as(f32, 10.0), p.swoop_cooldown);
}
