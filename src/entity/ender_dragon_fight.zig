/// Ender Dragon boss fight manager with crystal healing, phase-based AI,
/// and action-oriented update loop. Coordinates the full fight sequence:
/// circling at y=70, strafing runs, perching with breath attacks,
/// charging the player, and the death/XP-drop sequence.
const std = @import("std");

// ---------------------------------------------------------------------------
// Supporting types
// ---------------------------------------------------------------------------

pub const DragonPhase = enum {
    circling,
    strafing,
    perching,
    charging,
    dying,
};

pub const DragonAction = enum {
    idle,
    fly_to,
    breath_attack,
    charge,
    drop_xp,
};

// ---------------------------------------------------------------------------
// Main struct
// ---------------------------------------------------------------------------

pub const DragonFight = struct {
    hp: f32 = 200.0,
    phase: DragonPhase = .circling,
    phase_timer: f32 = 0,
    crystals_alive: u8 = 10,
    x: f32,
    y: f32,
    z: f32,
    target_x: f32 = 0,
    target_y: f32 = 0,
    target_z: f32 = 0,

    /// Maximum hit points.
    const MAX_HP: f32 = 200.0;

    /// Circling altitude.
    const CIRCLE_Y: f32 = 70.0;

    /// Crystal heal rate: 1 HP per second per crystal.
    const CRYSTAL_HEAL_PER_SEC: f32 = 1.0;

    /// Phase durations (seconds).
    const CIRCLE_DURATION: f32 = 20.0;
    const STRAFE_DURATION: f32 = 6.0;
    const PERCH_DURATION: f32 = 8.0;
    const CHARGE_DURATION: f32 = 4.0;
    const DYING_DURATION: f32 = 5.0;

    /// Movement speed while charging.
    const CHARGE_SPEED: f32 = 16.0;

    /// XP dropped on death.
    const XP_DROP: u32 = 12000;

    pub fn init(x: f32, y: f32, z: f32) DragonFight {
        return .{
            .x = x,
            .y = y,
            .z = z,
        };
    }

    /// Advance the fight by `dt` seconds given the player position.
    /// Returns the action the dragon is performing this tick.
    pub fn update(self: *DragonFight, dt: f32, player_x: f32, player_y: f32, player_z: f32) DragonAction {
        // Apply crystal healing before phase logic (not while dying).
        if (self.phase != .dying) {
            self.applyCrystalHealing(dt);
        }

        self.phase_timer += dt;

        return switch (self.phase) {
            .circling => self.updateCircling(),
            .strafing => self.updateStrafing(player_x, player_y, player_z),
            .perching => self.updatePerching(),
            .charging => self.updateCharging(dt, player_x, player_y, player_z),
            .dying => self.updateDying(),
        };
    }

    /// Apply damage to the dragon. Transitions to dying when HP reaches zero.
    pub fn takeDamage(self: *DragonFight, dmg: f32) void {
        if (self.phase == .dying) return;
        if (self.hp <= 0) return;

        self.hp -= dmg;
        if (self.hp <= 0) {
            self.hp = 0;
            self.phase = .dying;
            self.phase_timer = 0;
        }
    }

    /// Remove one end crystal. Clamped at zero.
    pub fn destroyCrystal(self: *DragonFight) void {
        if (self.crystals_alive > 0) {
            self.crystals_alive -= 1;
        }
    }

    /// Returns true once the dying animation has completed.
    pub fn isDead(self: *const DragonFight) bool {
        return self.phase == .dying and self.phase_timer >= DYING_DURATION;
    }

    // -- Phase update helpers -----------------------------------------------

    fn applyCrystalHealing(self: *DragonFight, dt: f32) void {
        if (self.crystals_alive == 0) return;
        const heal = @as(f32, @floatFromInt(self.crystals_alive)) * CRYSTAL_HEAL_PER_SEC * dt;
        self.hp = @min(self.hp + heal, MAX_HP);
    }

    fn updateCircling(self: *DragonFight) DragonAction {
        // Stay at circle altitude.
        self.target_y = CIRCLE_Y;

        if (self.phase_timer >= CIRCLE_DURATION) {
            self.phase = .strafing;
            self.phase_timer = 0;
            return .fly_to;
        }
        return .fly_to;
    }

    fn updateStrafing(self: *DragonFight, player_x: f32, player_y: f32, player_z: f32) DragonAction {
        // Fly toward the player at strafe speed (movement applied externally
        // via the returned action; we just record the target here).
        self.target_x = player_x;
        self.target_y = player_y;
        self.target_z = player_z;

        if (self.phase_timer >= STRAFE_DURATION) {
            self.phase = .perching;
            self.phase_timer = 0;
        }
        return .fly_to;
    }

    fn updatePerching(self: *DragonFight) DragonAction {
        // Perch at the center fountain and use breath attack.
        self.target_x = 0;
        self.target_y = CIRCLE_Y;
        self.target_z = 0;

        if (self.phase_timer >= PERCH_DURATION) {
            self.phase = .charging;
            self.phase_timer = 0;
            return .breath_attack;
        }
        return .breath_attack;
    }

    fn updateCharging(self: *DragonFight, dt: f32, player_x: f32, player_y: f32, player_z: f32) DragonAction {
        // Charge directly at the player.
        self.target_x = player_x;
        self.target_y = player_y;
        self.target_z = player_z;

        const dx = player_x - self.x;
        const dy = player_y - self.y;
        const dz = player_z - self.z;
        const dist = @sqrt(dx * dx + dy * dy + dz * dz);

        if (dist > 1.0) {
            const inv = 1.0 / dist;
            self.x += dx * inv * CHARGE_SPEED * dt;
            self.y += dy * inv * CHARGE_SPEED * dt;
            self.z += dz * inv * CHARGE_SPEED * dt;
        }

        if (self.phase_timer >= CHARGE_DURATION) {
            self.phase = .circling;
            self.phase_timer = 0;
            return .idle;
        }
        return .charge;
    }

    fn updateDying(self: *const DragonFight) DragonAction {
        if (self.phase_timer >= DYING_DURATION) {
            return .drop_xp;
        }
        return .idle;
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "init sets position and defaults" {
    const fight = DragonFight.init(10.0, 70.0, 5.0);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), fight.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 70.0), fight.y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), fight.z, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 200.0), fight.hp, 0.001);
    try std.testing.expect(fight.phase == .circling);
    try std.testing.expectEqual(@as(u8, 10), fight.crystals_alive);
    try std.testing.expect(!fight.isDead());
}

test "takeDamage reduces HP" {
    var fight = DragonFight.init(0, 70, 0);
    fight.crystals_alive = 0; // disable healing for clean test
    fight.takeDamage(50);
    try std.testing.expectApproxEqAbs(@as(f32, 150.0), fight.hp, 0.001);
}

test "takeDamage transitions to dying at zero HP" {
    var fight = DragonFight.init(0, 70, 0);
    fight.crystals_alive = 0;
    fight.takeDamage(200);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), fight.hp, 0.001);
    try std.testing.expect(fight.phase == .dying);
}

test "overkill clamps HP to zero" {
    var fight = DragonFight.init(0, 70, 0);
    fight.crystals_alive = 0;
    fight.takeDamage(500);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), fight.hp, 0.001);
    try std.testing.expect(fight.phase == .dying);
}

test "takeDamage ignored during dying phase" {
    var fight = DragonFight.init(0, 70, 0);
    fight.crystals_alive = 0;
    fight.takeDamage(200);
    try std.testing.expect(fight.phase == .dying);

    fight.takeDamage(50);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), fight.hp, 0.001);
}

test "isDead only after dying duration elapses" {
    var fight = DragonFight.init(0, 70, 0);
    fight.crystals_alive = 0;
    fight.takeDamage(200);
    try std.testing.expect(fight.phase == .dying);
    try std.testing.expect(!fight.isDead());

    // Advance past dying duration
    _ = fight.update(6.0, 0, 0, 0);
    try std.testing.expect(fight.isDead());
}

test "crystals heal 1 HP/s each" {
    var fight = DragonFight.init(0, 70, 0);
    fight.hp = 100;
    fight.crystals_alive = 5;

    // 5 crystals * 1 HP/s * 2s = 10 HP healed
    _ = fight.update(2.0, 0, 0, 0);
    try std.testing.expectApproxEqAbs(@as(f32, 110.0), fight.hp, 0.1);
}

test "crystal healing capped at max HP" {
    var fight = DragonFight.init(0, 70, 0);
    fight.hp = 195;
    fight.crystals_alive = 10;

    // 10 crystals * 1 HP/s * 2s = 20 HP, but capped at 200
    _ = fight.update(2.0, 0, 0, 0);
    try std.testing.expectApproxEqAbs(@as(f32, 200.0), fight.hp, 0.001);
}

test "destroyCrystal reduces count and stops healing at zero" {
    var fight = DragonFight.init(0, 70, 0);
    try std.testing.expectEqual(@as(u8, 10), fight.crystals_alive);

    for (0..10) |_| {
        fight.destroyCrystal();
    }
    try std.testing.expectEqual(@as(u8, 0), fight.crystals_alive);

    // Extra destroy is safe
    fight.destroyCrystal();
    try std.testing.expectEqual(@as(u8, 0), fight.crystals_alive);

    // No healing when no crystals
    fight.hp = 100;
    _ = fight.update(5.0, 0, 0, 0);
    try std.testing.expectApproxEqAbs(@as(f32, 100.0), fight.hp, 0.001);
}

test "circling transitions to strafing after duration" {
    var fight = DragonFight.init(0, 70, 0);
    fight.crystals_alive = 0;
    try std.testing.expect(fight.phase == .circling);

    var elapsed: f32 = 0;
    while (elapsed < 21.0) : (elapsed += 0.5) {
        _ = fight.update(0.5, 100, 50, 100);
    }
    try std.testing.expect(fight.phase == .strafing);
}

test "full phase cycle: circling -> strafing -> perching -> charging -> circling" {
    var fight = DragonFight.init(0, 70, 0);
    fight.crystals_alive = 0;

    // Circling -> strafing (20s)
    var elapsed: f32 = 0;
    while (elapsed < 21.0) : (elapsed += 0.5) {
        _ = fight.update(0.5, 100, 50, 100);
    }
    try std.testing.expect(fight.phase == .strafing);

    // Strafing -> perching (6s)
    elapsed = 0;
    while (elapsed < 7.0) : (elapsed += 0.5) {
        _ = fight.update(0.5, 100, 50, 100);
    }
    try std.testing.expect(fight.phase == .perching);

    // Perching -> charging (8s)
    elapsed = 0;
    while (elapsed < 9.0) : (elapsed += 0.5) {
        _ = fight.update(0.5, 100, 50, 100);
    }
    try std.testing.expect(fight.phase == .charging);

    // Charging -> circling (4s)
    elapsed = 0;
    while (elapsed < 5.0) : (elapsed += 0.5) {
        _ = fight.update(0.5, 100, 50, 100);
    }
    try std.testing.expect(fight.phase == .circling);
}

test "charging moves dragon toward player" {
    var fight = DragonFight.init(0, 70, 0);
    fight.crystals_alive = 0;
    fight.phase = .charging;
    fight.phase_timer = 0;

    const start_x = fight.x;
    _ = fight.update(1.0, 100, 70, 0);

    // Dragon should have moved toward the player (positive x)
    try std.testing.expect(fight.x > start_x);
}

test "perching returns breath_attack action" {
    var fight = DragonFight.init(0, 70, 0);
    fight.crystals_alive = 0;
    fight.phase = .perching;
    fight.phase_timer = 0;

    const action = fight.update(1.0, 0, 0, 0);
    try std.testing.expect(action == .breath_attack);
}

test "dying returns drop_xp once duration elapses" {
    var fight = DragonFight.init(0, 70, 0);
    fight.crystals_alive = 0;
    fight.takeDamage(200);

    // Before dying duration
    const action1 = fight.update(1.0, 0, 0, 0);
    try std.testing.expect(action1 == .idle);

    // After dying duration
    const action2 = fight.update(5.0, 0, 0, 0);
    try std.testing.expect(action2 == .drop_xp);
}

test "no crystal healing during dying phase" {
    var fight = DragonFight.init(0, 70, 0);
    fight.crystals_alive = 10;
    fight.takeDamage(200);
    try std.testing.expect(fight.phase == .dying);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), fight.hp, 0.001);

    // Update should NOT heal
    _ = fight.update(5.0, 0, 0, 0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), fight.hp, 0.001);
}
