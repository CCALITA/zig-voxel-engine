/// Ender Dragon entity with phase-based AI.
/// The dragon circles the End at y=70, periodically dives toward the player,
/// perches on the center pillar, and drops 12000 XP on death.
const std = @import("std");

pub const EnderDragon = struct {
    x: f32,
    y: f32,
    z: f32,
    yaw: f32,
    health: f32 = 200.0,
    max_health: f32 = 200.0,
    phase: DragonPhase = .circling,
    phase_timer: f32 = 0.0,
    circle_angle: f32 = 0.0,
    alive: bool = true,

    pub const DragonPhase = enum {
        circling,
        diving,
        perching,
        dying,
    };

    /// Circle altitude and radius.
    const CIRCLE_Y: f32 = 70.0;
    const CIRCLE_RADIUS: f32 = 40.0;
    const CIRCLE_SPEED: f32 = 0.3;

    /// Phase durations in seconds.
    const CIRCLE_DURATION: f32 = 30.0;
    const PERCH_DURATION: f32 = 10.0;
    const DYING_DURATION: f32 = 5.0;

    /// Dive movement speed.
    const DIVE_SPEED: f32 = 12.0;
    /// Distance threshold to consider dive complete.
    const DIVE_ARRIVE_DIST: f32 = 3.0;

    /// XP dropped on death.
    const XP_DROP: u32 = 12000;

    pub fn init(x: f32, y: f32, z: f32) EnderDragon {
        return .{
            .x = x,
            .y = y,
            .z = z,
            .yaw = 0.0,
        };
    }

    pub fn update(self: *EnderDragon, dt: f32, player_x: f32, player_y: f32, player_z: f32) void {
        if (!self.alive) return;

        self.phase_timer += dt;

        switch (self.phase) {
            .circling => self.updateCircling(dt),
            .diving => self.updateDiving(dt, player_x, player_y, player_z),
            .perching => self.updatePerching(dt),
            .dying => self.updateDying(),
        }
    }

    pub fn takeDamage(self: *EnderDragon, amount: f32) void {
        if (!self.alive) return;
        if (self.phase == .dying) return;

        self.health -= amount;
        if (self.health <= 0) {
            self.health = 0;
            self.phase = .dying;
            self.phase_timer = 0.0;
        }
    }

    pub fn isDead(self: *const EnderDragon) bool {
        return !self.alive;
    }

    pub fn getXPDrop(_: *const EnderDragon) u32 {
        return XP_DROP;
    }

    // -- Phase update logic --------------------------------------------------

    fn updateCircling(self: *EnderDragon, dt: f32) void {
        self.circle_angle += CIRCLE_SPEED * dt;
        if (self.circle_angle > 2.0 * std.math.pi) {
            self.circle_angle -= 2.0 * std.math.pi;
        }

        self.x = @cos(self.circle_angle) * CIRCLE_RADIUS;
        self.z = @sin(self.circle_angle) * CIRCLE_RADIUS;
        self.y = CIRCLE_Y;
        self.yaw = self.circle_angle + std.math.pi / 2.0;

        if (self.phase_timer >= CIRCLE_DURATION) {
            self.phase = .diving;
            self.phase_timer = 0.0;
        }
    }

    fn updateDiving(self: *EnderDragon, dt: f32, px: f32, py: f32, pz: f32) void {
        const dx = px - self.x;
        const dy = py - self.y;
        const dz = pz - self.z;
        const dist = @sqrt(dx * dx + dy * dy + dz * dz);

        if (dist < DIVE_ARRIVE_DIST) {
            // Dive complete, transition to perching at center
            self.phase = .perching;
            self.phase_timer = 0.0;
            self.x = 0.0;
            self.y = CIRCLE_Y;
            self.z = 0.0;
            return;
        }

        // Move toward player
        const inv_dist = 1.0 / dist;
        self.x += dx * inv_dist * DIVE_SPEED * dt;
        self.y += dy * inv_dist * DIVE_SPEED * dt;
        self.z += dz * inv_dist * DIVE_SPEED * dt;
        self.yaw = std.math.atan2(dz, dx);
    }

    fn updatePerching(self: *EnderDragon, dt: f32) void {
        // Sit at center
        _ = dt;
        self.x = 0.0;
        self.z = 0.0;
        self.y = CIRCLE_Y;

        if (self.phase_timer >= PERCH_DURATION) {
            self.phase = .circling;
            self.phase_timer = 0.0;
        }
    }

    fn updateDying(self: *EnderDragon) void {
        if (self.phase_timer >= DYING_DURATION) {
            self.alive = false;
        }
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "dragon init sets position and defaults" {
    const dragon = EnderDragon.init(10.0, 70.0, 5.0);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), dragon.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 70.0), dragon.y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), dragon.z, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 200.0), dragon.health, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 200.0), dragon.max_health, 0.001);
    try std.testing.expect(dragon.phase == .circling);
    try std.testing.expect(dragon.alive);
    try std.testing.expect(!dragon.isDead());
}

test "dragon takes damage" {
    var dragon = EnderDragon.init(0, 70, 0);
    dragon.takeDamage(50);
    try std.testing.expectApproxEqAbs(@as(f32, 150.0), dragon.health, 0.001);
    try std.testing.expect(dragon.alive);
    try std.testing.expect(!dragon.isDead());
}

test "dragon dies at zero health and enters dying phase" {
    var dragon = EnderDragon.init(0, 70, 0);
    dragon.takeDamage(200);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), dragon.health, 0.001);
    try std.testing.expect(dragon.phase == .dying);
    // Not yet dead -- dying animation still playing
    try std.testing.expect(dragon.alive);
}

test "dragon becomes dead after dying duration" {
    var dragon = EnderDragon.init(0, 70, 0);
    dragon.takeDamage(200);
    try std.testing.expect(dragon.phase == .dying);

    // Simulate time passing through the dying animation
    dragon.update(6.0, 0, 0, 0);
    try std.testing.expect(!dragon.alive);
    try std.testing.expect(dragon.isDead());
}

test "dragon overkill clamps health to zero" {
    var dragon = EnderDragon.init(0, 70, 0);
    dragon.takeDamage(500);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), dragon.health, 0.001);
    try std.testing.expect(dragon.phase == .dying);
}

test "dragon XP drop is 12000" {
    const dragon = EnderDragon.init(0, 70, 0);
    try std.testing.expectEqual(@as(u32, 12000), dragon.getXPDrop());
}

test "dragon circling phase transitions to diving after 30s" {
    var dragon = EnderDragon.init(0, 70, 0);
    try std.testing.expect(dragon.phase == .circling);

    // Simulate 31 seconds of circling
    var elapsed: f32 = 0;
    while (elapsed < 31.0) : (elapsed += 0.5) {
        dragon.update(0.5, 100, 50, 100);
    }
    try std.testing.expect(dragon.phase == .diving);
}

test "dragon diving transitions to perching near player" {
    var dragon = EnderDragon.init(0, 70, 0);
    // Force into diving phase
    dragon.phase = .diving;
    dragon.phase_timer = 0.0;

    // Place player very close so dive completes immediately
    dragon.update(0.1, dragon.x + 1.0, dragon.y, dragon.z);
    try std.testing.expect(dragon.phase == .perching);
}

test "dragon perching transitions back to circling after 10s" {
    var dragon = EnderDragon.init(0, 70, 0);
    dragon.phase = .perching;
    dragon.phase_timer = 0.0;

    var elapsed: f32 = 0;
    while (elapsed < 11.0) : (elapsed += 0.5) {
        dragon.update(0.5, 100, 50, 100);
    }
    try std.testing.expect(dragon.phase == .circling);
}

test "dragon ignores damage when dead" {
    var dragon = EnderDragon.init(0, 70, 0);
    dragon.takeDamage(200);
    // Finish dying
    dragon.update(6.0, 0, 0, 0);
    try std.testing.expect(dragon.isDead());

    // Further damage is ignored
    dragon.takeDamage(50);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), dragon.health, 0.001);
}

test "dragon ignores damage during dying phase" {
    var dragon = EnderDragon.init(0, 70, 0);
    dragon.takeDamage(200);
    try std.testing.expect(dragon.phase == .dying);

    // Additional damage during dying is no-op
    dragon.takeDamage(50);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), dragon.health, 0.001);
}

test "dragon circling moves position" {
    var dragon = EnderDragon.init(0, 70, 0);
    const start_x = dragon.x;
    const start_z = dragon.z;

    dragon.update(1.0, 100, 50, 100);

    // Position should have changed from circling
    const moved = (dragon.x != start_x) or (dragon.z != start_z);
    try std.testing.expect(moved);
    // Should be at circle altitude
    try std.testing.expectApproxEqAbs(@as(f32, 70.0), dragon.y, 0.001);
}

test "dragon update is no-op when dead" {
    var dragon = EnderDragon.init(0, 70, 0);
    dragon.alive = false;
    const x_before = dragon.x;
    const y_before = dragon.y;
    const z_before = dragon.z;

    dragon.update(1.0, 100, 50, 100);

    try std.testing.expectApproxEqAbs(x_before, dragon.x, 0.001);
    try std.testing.expectApproxEqAbs(y_before, dragon.y, 0.001);
    try std.testing.expectApproxEqAbs(z_before, dragon.z, 0.001);
}
