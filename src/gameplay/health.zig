const std = @import("std");

pub const MAX_HEALTH: f32 = 20.0; // 10 hearts
pub const MAX_HUNGER: f32 = 20.0; // 10 drumsticks
pub const MAX_SATURATION: f32 = 20.0;

const hunger_drain_rate: f32 = 0.1; // per second
const health_regen_rate: f32 = 0.5; // per second when hunger >= 18
const starvation_rate: f32 = 0.5; // per second when hunger == 0
const regen_hunger_threshold: f32 = 18.0;
const invulnerability_duration: f32 = 0.5; // seconds after taking damage
const attack_cooldown_duration: f32 = 0.625; // Minecraft 1.9+ combat
const base_attack_damage: f32 = 1.0; // fist damage

pub const PlayerStats = struct {
    health: f32 = MAX_HEALTH,
    hunger: f32 = MAX_HUNGER,
    saturation: f32 = 5.0,
    attack_cooldown: f32 = 0.0,
    invulnerable_timer: f32 = 0.0,
    is_dead: bool = false,

    pub fn init() PlayerStats {
        return .{};
    }

    /// Drains hunger (saturation first), regenerates health when well-fed,
    /// and applies starvation damage when starving. Ticks cooldown timers.
    pub fn update(self: *PlayerStats, dt: f32) void {
        if (self.is_dead) return;

        // Tick cooldown timers
        self.attack_cooldown = @max(self.attack_cooldown - dt, 0.0);
        self.invulnerable_timer = @max(self.invulnerable_timer - dt, 0.0);

        // Drain hunger: consume saturation first, then hunger
        const drain = hunger_drain_rate * dt;
        if (self.saturation > 0.0) {
            self.saturation = @max(self.saturation - drain, 0.0);
        } else {
            self.hunger = @max(self.hunger - drain, 0.0);
        }

        // Regenerate health when hunger >= 18
        if (self.hunger >= regen_hunger_threshold) {
            self.health = @min(self.health + health_regen_rate * dt, MAX_HEALTH);
        }

        // Starvation damage when hunger == 0
        if (self.hunger <= 0.0) {
            self.health = @max(self.health - starvation_rate * dt, 0.0);
            if (self.health <= 0.0) {
                self.is_dead = true;
            }
        }
    }

    pub fn takeDamage(self: *PlayerStats, amount: f32) void {
        if (self.is_dead) return;
        if (self.invulnerable_timer > 0.0) return;

        self.health = @max(self.health - amount, 0.0);
        self.invulnerable_timer = invulnerability_duration;

        if (self.health <= 0.0) {
            self.is_dead = true;
        }
    }

    pub fn heal(self: *PlayerStats, amount: f32) void {
        if (self.is_dead) return;
        self.health = @min(self.health + amount, MAX_HEALTH);
    }

    pub fn eat(self: *PlayerStats, hunger_restore: f32, saturation_restore: f32) void {
        if (self.is_dead) return;
        self.hunger = @min(self.hunger + hunger_restore, MAX_HUNGER);
        self.saturation = @min(self.saturation + saturation_restore, MAX_SATURATION);
    }

    pub fn canAttack(self: *const PlayerStats) bool {
        return !self.is_dead and self.attack_cooldown <= 0.0;
    }

    /// Returns damage dealt and starts the attack cooldown.
    /// Returns 0 if attack is on cooldown or player is dead.
    pub fn attack(self: *PlayerStats) f32 {
        if (!self.canAttack()) return 0.0;
        self.attack_cooldown = attack_cooldown_duration;
        return base_attack_damage;
    }

    /// Returns 0-10 representing full hearts for the HUD.
    pub fn getHealthHearts(self: *const PlayerStats) u8 {
        const hearts = self.health / 2.0;
        return @intFromFloat(@ceil(hearts));
    }

    /// Returns 0-10 representing full drumsticks for the HUD.
    pub fn getHungerDrumsticks(self: *const PlayerStats) u8 {
        const drumsticks = self.hunger / 2.0;
        return @intFromFloat(@ceil(drumsticks));
    }
};

// ──────────────────────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────────────────────

test "init returns default stats" {
    const stats = PlayerStats.init();
    try std.testing.expectEqual(MAX_HEALTH, stats.health);
    try std.testing.expectEqual(MAX_HUNGER, stats.hunger);
    try std.testing.expectEqual(@as(f32, 5.0), stats.saturation);
    try std.testing.expect(!stats.is_dead);
}

test "takeDamage reduces health and sets invulnerable_timer" {
    var stats = PlayerStats.init();
    stats.takeDamage(5.0);
    try std.testing.expectEqual(@as(f32, 15.0), stats.health);
    try std.testing.expectEqual(@as(f32, 0.5), stats.invulnerable_timer);
    try std.testing.expect(!stats.is_dead);
}

test "no damage during invulnerability window" {
    var stats = PlayerStats.init();
    stats.takeDamage(5.0);
    try std.testing.expectEqual(@as(f32, 15.0), stats.health);

    // Second hit should be ignored
    stats.takeDamage(5.0);
    try std.testing.expectEqual(@as(f32, 15.0), stats.health);
}

test "heal caps at MAX_HEALTH" {
    var stats = PlayerStats.init();
    stats.health = 10.0;
    stats.heal(5.0);
    try std.testing.expectEqual(@as(f32, 15.0), stats.health);

    stats.heal(100.0);
    try std.testing.expectEqual(MAX_HEALTH, stats.health);
}

test "hunger drains over time (saturation consumed first)" {
    var stats = PlayerStats.init();
    const initial_saturation = stats.saturation;
    const initial_hunger = stats.hunger;

    // After 1 second, saturation should drain by 0.1
    stats.update(1.0);
    try std.testing.expect(stats.saturation < initial_saturation);
    try std.testing.expectEqual(initial_hunger, stats.hunger);

    // Exhaust saturation completely
    stats.saturation = 0.0;
    stats.update(1.0);
    try std.testing.expect(stats.hunger < initial_hunger);
}

test "health regenerates when hunger >= 18" {
    var stats = PlayerStats.init();
    stats.health = 10.0;
    stats.hunger = 20.0;
    stats.saturation = 0.0;

    // After 1 second at regen rate 0.5/s: health should increase
    // hunger drains 0.1 but stays >= 18
    stats.update(1.0);
    try std.testing.expect(stats.health > 10.0);
}

test "no regen when hunger below threshold" {
    var stats = PlayerStats.init();
    stats.health = 10.0;
    stats.hunger = 10.0;
    stats.saturation = 0.0;

    stats.update(1.0);
    try std.testing.expectEqual(@as(f32, 10.0), stats.health);
}

test "starvation damage when hunger == 0" {
    var stats = PlayerStats.init();
    stats.hunger = 0.0;
    stats.saturation = 0.0;
    const initial_health = stats.health;

    stats.update(1.0);
    try std.testing.expect(stats.health < initial_health);
}

test "starvation causes death" {
    var stats = PlayerStats.init();
    stats.hunger = 0.0;
    stats.saturation = 0.0;
    stats.health = 0.1;

    stats.update(1.0);
    try std.testing.expect(stats.is_dead);
    try std.testing.expect(stats.health <= 0.0);
}

test "eat restores hunger and saturation" {
    var stats = PlayerStats.init();
    stats.hunger = 10.0;
    stats.saturation = 0.0;

    stats.eat(6.0, 6.0);
    try std.testing.expectEqual(@as(f32, 16.0), stats.hunger);
    try std.testing.expectEqual(@as(f32, 6.0), stats.saturation);
}

test "eat caps at max values" {
    var stats = PlayerStats.init();
    stats.eat(100.0, 100.0);
    try std.testing.expectEqual(MAX_HUNGER, stats.hunger);
    try std.testing.expectEqual(MAX_SATURATION, stats.saturation);
}

test "attack cooldown prevents rapid attacks" {
    var stats = PlayerStats.init();

    // First attack should succeed
    const damage1 = stats.attack();
    try std.testing.expectEqual(@as(f32, 1.0), damage1);
    try std.testing.expect(!stats.canAttack());

    // Second attack should fail (on cooldown)
    const damage2 = stats.attack();
    try std.testing.expectEqual(@as(f32, 0.0), damage2);

    // Wait for cooldown to expire
    stats.update(0.625);
    try std.testing.expect(stats.canAttack());

    // Third attack should succeed
    const damage3 = stats.attack();
    try std.testing.expectEqual(@as(f32, 1.0), damage3);
}

test "death at health <= 0" {
    var stats = PlayerStats.init();
    stats.takeDamage(20.0);
    try std.testing.expect(stats.is_dead);
    try std.testing.expectEqual(@as(f32, 0.0), stats.health);
}

test "dead player cannot act" {
    var stats = PlayerStats.init();
    stats.takeDamage(20.0);
    try std.testing.expect(stats.is_dead);

    // Cannot heal
    stats.heal(10.0);
    try std.testing.expectEqual(@as(f32, 0.0), stats.health);

    // Cannot eat
    stats.hunger = 0.0;
    stats.eat(10.0, 10.0);
    try std.testing.expectEqual(@as(f32, 0.0), stats.hunger);

    // Cannot attack
    try std.testing.expect(!stats.canAttack());
    try std.testing.expectEqual(@as(f32, 0.0), stats.attack());
}

test "getHealthHearts returns 0-10" {
    var stats = PlayerStats.init();
    try std.testing.expectEqual(@as(u8, 10), stats.getHealthHearts());

    stats.health = 10.0;
    try std.testing.expectEqual(@as(u8, 5), stats.getHealthHearts());

    stats.health = 1.0;
    try std.testing.expectEqual(@as(u8, 1), stats.getHealthHearts());

    stats.health = 0.0;
    try std.testing.expectEqual(@as(u8, 0), stats.getHealthHearts());
}

test "getHungerDrumsticks returns 0-10" {
    var stats = PlayerStats.init();
    try std.testing.expectEqual(@as(u8, 10), stats.getHungerDrumsticks());

    stats.hunger = 10.0;
    try std.testing.expectEqual(@as(u8, 5), stats.getHungerDrumsticks());

    stats.hunger = 0.0;
    try std.testing.expectEqual(@as(u8, 0), stats.getHungerDrumsticks());
}

test "invulnerability timer ticks down" {
    var stats = PlayerStats.init();
    stats.hunger = 10.0; // below regen threshold so health stays constant
    stats.saturation = 0.0;
    stats.takeDamage(5.0);
    try std.testing.expectEqual(@as(f32, 0.5), stats.invulnerable_timer);

    stats.update(0.3);
    try std.testing.expect(stats.invulnerable_timer > 0.0);

    // Still invulnerable
    stats.takeDamage(5.0);
    try std.testing.expectEqual(@as(f32, 15.0), stats.health);

    // Timer expires
    stats.update(0.3);
    try std.testing.expect(stats.invulnerable_timer <= 0.0);

    // Now damage works
    stats.takeDamage(5.0);
    try std.testing.expectEqual(@as(f32, 10.0), stats.health);
}
