/// Mob variant entities: IronGolem, SnowGolem, Wither, WitherSkull,
/// Guardian, ElderGuardian, and Phantom.
/// Each has init, update(dt, targets), and getAttackDamage.
const std = @import("std");

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

/// Represents a potential target with position and hostility flag.
pub const Target = struct {
    x: f32,
    y: f32,
    z: f32,
    hostile: bool,
    health: f32,
};

fn distance3d(ax: f32, ay: f32, az: f32, bx: f32, by: f32, bz: f32) f32 {
    const dx = ax - bx;
    const dy = ay - by;
    const dz = az - bz;
    return @sqrt(dx * dx + dy * dy + dz * dz);
}

/// Returns true if any target matching the filter is within range.
fn anyTargetInRange(
    sx: f32,
    sy: f32,
    sz: f32,
    targets: []const Target,
    range: f32,
    hostile_only: bool,
) bool {
    for (targets) |t| {
        if (hostile_only and !t.hostile) continue;
        const dist = distance3d(sx, sy, sz, t.x, t.y, t.z);
        if (dist <= range) return true;
    }
    return false;
}

/// Standard damage logic shared by most mob variants.
fn applyDamage(health: *f32, alive: *bool, amount: f32) void {
    if (!alive.*) return;
    health.* -= amount;
    if (health.* <= 0) {
        health.* = 0;
        alive.* = false;
    }
}

/// Shared laser-attack update logic used by Guardian and ElderGuardian.
fn updateLaser(
    laser_charge: *f32,
    laser_firing: *bool,
    laser_target_acquired: *bool,
    dt: f32,
    has_target: bool,
    charge_time: f32,
) void {
    if (has_target) {
        laser_target_acquired.* = true;
        laser_charge.* += dt;
        if (laser_charge.* >= charge_time) {
            laser_firing.* = true;
            laser_charge.* = 0.0;
        }
    } else {
        laser_target_acquired.* = false;
        laser_charge.* = 0.0;
        laser_firing.* = false;
    }
}

// ---------------------------------------------------------------------------
// Biome type for SnowGolem melting logic
// ---------------------------------------------------------------------------

pub const Biome = enum {
    plains,
    forest,
    desert,
    jungle,
    tundra,
    ocean,
    swamp,

    pub fn isWarm(self: Biome) bool {
        return switch (self) {
            .desert, .jungle => true,
            else => false,
        };
    }
};

// ---------------------------------------------------------------------------
// IronGolem
// ---------------------------------------------------------------------------

pub const IronGolem = struct {
    x: f32,
    y: f32,
    z: f32,
    health: f32 = 100.0,
    max_health: f32 = 100.0,
    alive: bool = true,
    attack_cooldown: f32 = 0.0,

    const ATTACK_DAMAGE: f32 = 15.0;
    const ATTACK_RANGE: f32 = 16.0;
    const ATTACK_COOLDOWN: f32 = 1.5;
    const VILLAGER_THRESHOLD: u32 = 10;

    /// Iron golems are immune to drowning and fall damage.
    pub const immune_to_drowning = true;
    pub const immune_to_fall_damage = true;

    pub fn init(x: f32, y: f32, z: f32) IronGolem {
        return .{ .x = x, .y = y, .z = z };
    }

    /// Returns true when a village has enough villagers to spawn an iron golem.
    pub fn canSpawnInVillage(villager_count: u32) bool {
        return villager_count >= VILLAGER_THRESHOLD;
    }

    pub fn update(self: *IronGolem, dt: f32, targets: []const Target) void {
        if (!self.alive) return;

        if (self.attack_cooldown > 0) {
            self.attack_cooldown -= dt;
            if (self.attack_cooldown < 0) self.attack_cooldown = 0;
        }

        if (self.hasHostileInRange(targets) and self.attack_cooldown <= 0) {
            self.attack_cooldown = ATTACK_COOLDOWN;
        }
    }

    pub fn getAttackDamage(_: *const IronGolem) f32 {
        return ATTACK_DAMAGE;
    }

    pub fn takeDamage(self: *IronGolem, amount: f32) void {
        applyDamage(&self.health, &self.alive, amount);
    }

    /// Returns true when a hostile target is within attack range.
    pub fn hasHostileInRange(self: *const IronGolem, targets: []const Target) bool {
        return anyTargetInRange(self.x, self.y, self.z, targets, ATTACK_RANGE, true);
    }
};

// ---------------------------------------------------------------------------
// SnowGolem
// ---------------------------------------------------------------------------

pub const SnowGolem = struct {
    x: f32,
    y: f32,
    z: f32,
    health: f32 = 4.0,
    max_health: f32 = 4.0,
    alive: bool = true,
    snowball_timer: f32 = 0.0,
    snowballs_thrown: u32 = 0,
    snow_trail_count: u32 = 0,

    const SNOWBALL_INTERVAL: f32 = 1.5;
    const SNOWBALL_RANGE: f32 = 10.0;
    const SNOWBALL_DAMAGE: f32 = 0.0; // snowballs deal no damage, only knockback
    const MELT_DAMAGE_PER_SEC: f32 = 1.0;

    pub fn init(x: f32, y: f32, z: f32) SnowGolem {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn update(self: *SnowGolem, dt: f32, targets: []const Target, biome: Biome) void {
        if (!self.alive) return;

        // Melt in warm biomes.
        if (biome.isWarm()) {
            self.health -= MELT_DAMAGE_PER_SEC * dt;
            if (self.health <= 0) {
                self.health = 0;
                self.alive = false;
                return;
            }
        }

        // Leave snow trail in non-warm biomes.
        if (!biome.isWarm()) {
            self.snow_trail_count += 1;
        }

        // Throw snowballs at hostiles.
        self.snowball_timer += dt;

        if (self.snowball_timer >= SNOWBALL_INTERVAL) {
            if (anyTargetInRange(self.x, self.y, self.z, targets, SNOWBALL_RANGE, true)) {
                self.snowballs_thrown += 1;
                self.snowball_timer = 0.0;
            }
        }
    }

    pub fn getAttackDamage(_: *const SnowGolem) f32 {
        return SNOWBALL_DAMAGE;
    }

    pub fn takeDamage(self: *SnowGolem, amount: f32) void {
        applyDamage(&self.health, &self.alive, amount);
    }
};

// ---------------------------------------------------------------------------
// Wither
// ---------------------------------------------------------------------------

pub const Wither = struct {
    x: f32,
    y: f32,
    z: f32,
    health: f32 = 300.0,
    max_health: f32 = 300.0,
    alive: bool = true,
    phase: WitherPhase = .phase1,
    phase_timer: f32 = 0.0,
    skull_cooldown: f32 = 0.0,
    skulls_fired: u32 = 0,
    shield_active: bool = false,

    const SKULL_COOLDOWN: f32 = 2.0;
    const SKULL_RANGE: f32 = 32.0;
    const SKULL_DAMAGE: f32 = 8.0;
    const WITHER_EFFECT_DURATION: f32 = 10.0;
    const WITHER_EFFECT_DPS: f32 = 1.0;
    const CHARGE_DAMAGE: f32 = 15.0;
    const CHARGE_SPEED: f32 = 8.0;
    const CHARGE_HIT_RANGE: f32 = 3.0;
    const PHASE2_THRESHOLD: f32 = 0.5;
    const PHASE2_DURATION: f32 = 5.0;

    pub const WitherPhase = enum {
        phase1, // shoots skulls at mobs
        phase2, // shield at 50% HP
        phase3, // charges at targets
    };

    pub fn init(x: f32, y: f32, z: f32) Wither {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn update(self: *Wither, dt: f32, targets: []const Target) void {
        if (!self.alive) return;

        self.phase_timer += dt;

        // Phase transitions based on health.
        const health_pct = self.health / self.max_health;
        if (self.phase == .phase1 and health_pct <= PHASE2_THRESHOLD) {
            self.phase = .phase2;
            self.shield_active = true;
            self.phase_timer = 0.0;
        }
        if (self.phase == .phase2 and self.phase_timer >= PHASE2_DURATION) {
            self.phase = .phase3;
            self.shield_active = false;
            self.phase_timer = 0.0;
        }

        switch (self.phase) {
            .phase1 => self.updatePhase1(dt, targets),
            .phase2 => {},
            .phase3 => self.updatePhase3(dt, targets),
        }
    }

    fn updatePhase1(self: *Wither, dt: f32, targets: []const Target) void {
        if (self.skull_cooldown > 0) {
            self.skull_cooldown -= dt;
            if (self.skull_cooldown < 0) self.skull_cooldown = 0;
        }

        if (self.skull_cooldown <= 0) {
            if (anyTargetInRange(self.x, self.y, self.z, targets, SKULL_RANGE, false)) {
                self.skulls_fired += 1;
                self.skull_cooldown = SKULL_COOLDOWN;
            }
        }
    }

    fn updatePhase3(self: *Wither, dt: f32, targets: []const Target) void {
        var closest_dist: f32 = SKULL_RANGE + 1.0;
        var closest_x: f32 = self.x;
        var closest_z: f32 = self.z;
        var found = false;

        for (targets) |t| {
            const dist = distance3d(self.x, self.y, self.z, t.x, t.y, t.z);
            if (dist < closest_dist) {
                closest_dist = dist;
                closest_x = t.x;
                closest_z = t.z;
                found = true;
            }
        }

        if (found) {
            const dx = closest_x - self.x;
            const dz = closest_z - self.z;
            const dist = @sqrt(dx * dx + dz * dz);
            if (dist > 0.001) {
                self.x += (dx / dist) * CHARGE_SPEED * dt;
                self.z += (dz / dist) * CHARGE_SPEED * dt;
            }
        }
    }

    pub fn getAttackDamage(self: *const Wither) f32 {
        return switch (self.phase) {
            .phase1 => SKULL_DAMAGE,
            .phase2 => 0,
            .phase3 => CHARGE_DAMAGE,
        };
    }

    pub fn takeDamage(self: *Wither, amount: f32) void {
        if (!self.alive) return;
        const effective = if (self.shield_active) amount * 0.5 else amount;
        self.health -= effective;
        if (self.health <= 0) {
            self.health = 0;
            self.alive = false;
        }
    }

    pub fn getWitherEffectDPS(_: *const Wither) f32 {
        return WITHER_EFFECT_DPS;
    }

    pub fn getWitherEffectDuration(_: *const Wither) f32 {
        return WITHER_EFFECT_DURATION;
    }
};

// ---------------------------------------------------------------------------
// WitherSkull
// ---------------------------------------------------------------------------

pub const WitherSkull = struct {
    x: f32,
    y: f32,
    z: f32,
    vx: f32,
    vy: f32,
    vz: f32,
    alive: bool = true,
    exploded: bool = false,

    const SPEED: f32 = 12.0;
    const EXPLOSION_RADIUS: f32 = 3.0;
    const EXPLOSION_DAMAGE: f32 = 8.0;
    const HIT_RADIUS: f32 = 1.5;

    pub fn init(x: f32, y: f32, z: f32, target_x: f32, target_y: f32, target_z: f32) WitherSkull {
        const dx = target_x - x;
        const dy = target_y - y;
        const dz = target_z - z;
        const dist = @sqrt(dx * dx + dy * dy + dz * dz);
        const inv = if (dist > 0.001) 1.0 / dist else 0.0;
        return .{
            .x = x,
            .y = y,
            .z = z,
            .vx = dx * inv * SPEED,
            .vy = dy * inv * SPEED,
            .vz = dz * inv * SPEED,
        };
    }

    pub fn update(self: *WitherSkull, dt: f32, targets: []const Target) void {
        if (!self.alive) return;

        self.x += self.vx * dt;
        self.y += self.vy * dt;
        self.z += self.vz * dt;

        if (anyTargetInRange(self.x, self.y, self.z, targets, HIT_RADIUS, false)) {
            self.exploded = true;
            self.alive = false;
        }
    }

    pub fn getAttackDamage(_: *const WitherSkull) f32 {
        return EXPLOSION_DAMAGE;
    }

    pub fn getExplosionRadius(_: *const WitherSkull) f32 {
        return EXPLOSION_RADIUS;
    }
};

// ---------------------------------------------------------------------------
// Guardian
// ---------------------------------------------------------------------------

pub const Guardian = struct {
    x: f32,
    y: f32,
    z: f32,
    health: f32 = 30.0,
    max_health: f32 = 30.0,
    alive: bool = true,
    laser_charge: f32 = 0.0,
    laser_firing: bool = false,
    laser_target_acquired: bool = false,

    const LASER_CHARGE_TIME: f32 = 3.0;
    const LASER_DAMAGE: f32 = 6.0;
    const LASER_RANGE: f32 = 15.0;

    pub fn init(x: f32, y: f32, z: f32) Guardian {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn update(self: *Guardian, dt: f32, targets: []const Target) void {
        if (!self.alive) return;
        const has_target = anyTargetInRange(self.x, self.y, self.z, targets, LASER_RANGE, false);
        updateLaser(&self.laser_charge, &self.laser_firing, &self.laser_target_acquired, dt, has_target, LASER_CHARGE_TIME);
    }

    pub fn getAttackDamage(self: *const Guardian) f32 {
        return if (self.laser_firing) LASER_DAMAGE else 0;
    }

    pub fn takeDamage(self: *Guardian, amount: f32) void {
        applyDamage(&self.health, &self.alive, amount);
    }

    pub fn isLaserCharging(self: *const Guardian) bool {
        return self.laser_target_acquired and !self.laser_firing;
    }

    pub fn getLaserChargeProgress(self: *const Guardian) f32 {
        return self.laser_charge / LASER_CHARGE_TIME;
    }
};

// ---------------------------------------------------------------------------
// ElderGuardian
// ---------------------------------------------------------------------------

pub const ElderGuardian = struct {
    x: f32,
    y: f32,
    z: f32,
    health: f32 = 80.0,
    max_health: f32 = 80.0,
    alive: bool = true,
    laser_charge: f32 = 0.0,
    laser_firing: bool = false,
    laser_target_acquired: bool = false,

    const LASER_CHARGE_TIME: f32 = 3.0;
    const LASER_DAMAGE: f32 = 8.0;
    const LASER_RANGE: f32 = 15.0;
    const MINING_FATIGUE_RADIUS: f32 = 50.0;
    const MINING_FATIGUE_LEVEL: u8 = 3;

    pub fn init(x: f32, y: f32, z: f32) ElderGuardian {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn update(self: *ElderGuardian, dt: f32, targets: []const Target) void {
        if (!self.alive) return;
        const has_target = anyTargetInRange(self.x, self.y, self.z, targets, LASER_RANGE, false);
        updateLaser(&self.laser_charge, &self.laser_firing, &self.laser_target_acquired, dt, has_target, LASER_CHARGE_TIME);
    }

    pub fn getAttackDamage(self: *const ElderGuardian) f32 {
        return if (self.laser_firing) LASER_DAMAGE else 0;
    }

    pub fn takeDamage(self: *ElderGuardian, amount: f32) void {
        applyDamage(&self.health, &self.alive, amount);
    }

    /// Returns true if a player at the given position is affected by mining fatigue.
    pub fn inflictsMiningFatigue(self: *const ElderGuardian, px: f32, py: f32, pz: f32) bool {
        if (!self.alive) return false;
        const dist = distance3d(self.x, self.y, self.z, px, py, pz);
        return dist <= MINING_FATIGUE_RADIUS;
    }

    pub fn getMiningFatigueLevel(_: *const ElderGuardian) u8 {
        return MINING_FATIGUE_LEVEL;
    }
};

// ---------------------------------------------------------------------------
// Phantom
// ---------------------------------------------------------------------------

pub const Phantom = struct {
    x: f32,
    y: f32,
    z: f32,
    health: f32 = 20.0,
    max_health: f32 = 20.0,
    alive: bool = true,
    dive_timer: f32 = 0.0,
    is_diving: bool = false,
    is_daylight: bool = false,

    const DIVE_DAMAGE: f32 = 6.0;
    const DIVE_COOLDOWN: f32 = 4.0;
    const DIVE_SPEED: f32 = 10.0;
    const DIVE_RANGE: f32 = 20.0;
    const DIVE_ARRIVE_DIST: f32 = 2.0;
    const BURN_DPS: f32 = 2.0;
    const MIN_SLEEPLESS_DAYS: u32 = 3;

    pub fn init(x: f32, y: f32, z: f32) Phantom {
        return .{ .x = x, .y = y, .z = z };
    }

    /// Whether a phantom should spawn based on days without sleep.
    pub fn shouldSpawn(days_without_sleep: u32) bool {
        return days_without_sleep >= MIN_SLEEPLESS_DAYS;
    }

    pub fn update(self: *Phantom, dt: f32, targets: []const Target) void {
        if (!self.alive) return;

        // Burn in daylight.
        if (self.is_daylight) {
            self.health -= BURN_DPS * dt;
            if (self.health <= 0) {
                self.health = 0;
                self.alive = false;
                return;
            }
        }

        // Dive attack logic.
        self.dive_timer += dt;

        if (!self.is_diving and self.dive_timer >= DIVE_COOLDOWN) {
            if (anyTargetInRange(self.x, self.y, self.z, targets, DIVE_RANGE, false)) {
                self.is_diving = true;
                self.dive_timer = 0.0;
            }
        }

        if (self.is_diving) {
            if (targets.len > 0) {
                const t = targets[0];
                const dx = t.x - self.x;
                const dy = t.y - self.y;
                const dz = t.z - self.z;
                const dist = @sqrt(dx * dx + dy * dy + dz * dz);
                if (dist > 0.001) {
                    self.x += (dx / dist) * DIVE_SPEED * dt;
                    self.y += (dy / dist) * DIVE_SPEED * dt;
                    self.z += (dz / dist) * DIVE_SPEED * dt;
                }
                if (dist < DIVE_ARRIVE_DIST) {
                    self.is_diving = false;
                }
            } else {
                self.is_diving = false;
            }
        }
    }

    pub fn getAttackDamage(self: *const Phantom) f32 {
        return if (self.is_diving) DIVE_DAMAGE else 0;
    }

    pub fn takeDamage(self: *Phantom, amount: f32) void {
        applyDamage(&self.health, &self.alive, amount);
    }

    pub fn setDaylight(self: *Phantom, daylight: bool) void {
        self.is_daylight = daylight;
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "iron golem init and stats" {
    const golem = IronGolem.init(5, 10, 15);
    try std.testing.expectApproxEqAbs(@as(f32, 100.0), golem.health, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 15.0), golem.getAttackDamage(), 0.001);
    try std.testing.expect(golem.alive);
    try std.testing.expect(IronGolem.immune_to_drowning);
    try std.testing.expect(IronGolem.immune_to_fall_damage);
}

test "iron golem targets hostile mobs within range" {
    var golem = IronGolem.init(0, 0, 0);
    const targets = [_]Target{
        .{ .x = 10, .y = 0, .z = 0, .hostile = true, .health = 20 },
        .{ .x = 5, .y = 0, .z = 0, .hostile = false, .health = 10 },
    };
    try std.testing.expect(golem.hasHostileInRange(&targets));

    golem.update(0.1, &targets);
    try std.testing.expect(golem.attack_cooldown > 0);
}

test "iron golem ignores non-hostile targets" {
    var golem = IronGolem.init(0, 0, 0);
    const targets = [_]Target{
        .{ .x = 5, .y = 0, .z = 0, .hostile = false, .health = 10 },
    };
    try std.testing.expect(!golem.hasHostileInRange(&targets));
    golem.update(0.1, &targets);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), golem.attack_cooldown, 0.001);
}

test "iron golem ignores hostiles beyond 16 blocks" {
    const golem = IronGolem.init(0, 0, 0);
    const targets = [_]Target{
        .{ .x = 20, .y = 0, .z = 0, .hostile = true, .health = 20 },
    };
    try std.testing.expect(!golem.hasHostileInRange(&targets));
}

test "iron golem village spawn threshold" {
    try std.testing.expect(!IronGolem.canSpawnInVillage(9));
    try std.testing.expect(IronGolem.canSpawnInVillage(10));
    try std.testing.expect(IronGolem.canSpawnInVillage(15));
}

test "snow golem init and stats" {
    const golem = SnowGolem.init(0, 0, 0);
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), golem.health, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), golem.getAttackDamage(), 0.001);
    try std.testing.expect(golem.alive);
}

test "snow golem snowball fire rate" {
    var golem = SnowGolem.init(0, 0, 0);
    const targets = [_]Target{
        .{ .x = 5, .y = 0, .z = 0, .hostile = true, .health = 20 },
    };

    // Advance just under 1.5s -- should not fire yet.
    golem.update(1.4, &targets, .plains);
    try std.testing.expectEqual(@as(u32, 0), golem.snowballs_thrown);

    // Cross the 1.5s threshold.
    golem.update(0.2, &targets, .plains);
    try std.testing.expectEqual(@as(u32, 1), golem.snowballs_thrown);

    // Fire again after another 1.5s.
    golem.update(1.5, &targets, .plains);
    try std.testing.expectEqual(@as(u32, 2), golem.snowballs_thrown);
}

test "snow golem melts in warm biome" {
    var golem = SnowGolem.init(0, 0, 0);
    const targets = [_]Target{};

    golem.update(5.0, &targets, .desert);
    try std.testing.expect(!golem.alive);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), golem.health, 0.001);
}

test "snow golem does not melt in cold biome" {
    var golem = SnowGolem.init(0, 0, 0);
    const targets = [_]Target{};
    golem.update(10.0, &targets, .tundra);
    try std.testing.expect(golem.alive);
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), golem.health, 0.001);
}

test "snow golem leaves snow trail" {
    var golem = SnowGolem.init(0, 0, 0);
    const targets = [_]Target{};
    golem.update(1.0, &targets, .plains);
    try std.testing.expect(golem.snow_trail_count > 0);
}

test "wither init and stats" {
    const wither = Wither.init(0, 50, 0);
    try std.testing.expectApproxEqAbs(@as(f32, 300.0), wither.health, 0.001);
    try std.testing.expect(wither.phase == .phase1);
    try std.testing.expect(wither.alive);
}

test "wither phase1 shoots skulls" {
    var wither = Wither.init(0, 0, 0);
    const targets = [_]Target{
        .{ .x = 10, .y = 0, .z = 0, .hostile = false, .health = 20 },
    };
    wither.update(0.1, &targets);
    try std.testing.expect(wither.skulls_fired > 0);
    try std.testing.expectApproxEqAbs(@as(f32, 8.0), wither.getAttackDamage(), 0.001);
}

test "wither phase transitions at 50% HP" {
    var wither = Wither.init(0, 0, 0);
    try std.testing.expect(wither.phase == .phase1);

    wither.takeDamage(150.0);
    try std.testing.expectApproxEqAbs(@as(f32, 150.0), wither.health, 0.001);

    const targets = [_]Target{};
    wither.update(0.1, &targets);
    try std.testing.expect(wither.phase == .phase2);
    try std.testing.expect(wither.shield_active);
}

test "wither phase2 to phase3 transition" {
    var wither = Wither.init(0, 0, 0);
    wither.health = 150.0;
    const targets = [_]Target{};

    wither.update(0.1, &targets);
    try std.testing.expect(wither.phase == .phase2);

    wither.update(5.0, &targets);
    try std.testing.expect(wither.phase == .phase3);
    try std.testing.expect(!wither.shield_active);
}

test "wither shield reduces damage in phase2" {
    var wither = Wither.init(0, 0, 0);
    wither.shield_active = true;
    const health_before = wither.health;
    wither.takeDamage(20.0);
    try std.testing.expectApproxEqAbs(health_before - 10.0, wither.health, 0.001);
}

test "wither effect DPS and duration" {
    const wither = Wither.init(0, 0, 0);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), wither.getWitherEffectDPS(), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), wither.getWitherEffectDuration(), 0.001);
}

test "wither skull init and movement" {
    var skull = WitherSkull.init(0, 0, 0, 12, 0, 0);
    try std.testing.expect(skull.alive);
    try std.testing.expect(!skull.exploded);

    const targets = [_]Target{};
    skull.update(1.0, &targets);

    try std.testing.expect(skull.x > 0);
}

test "wither skull explodes on hit" {
    var skull = WitherSkull.init(0, 0, 0, 2, 0, 0);
    const targets = [_]Target{
        .{ .x = 1, .y = 0, .z = 0, .hostile = false, .health = 20 },
    };
    skull.update(0.1, &targets);
    try std.testing.expect(skull.exploded);
    try std.testing.expect(!skull.alive);
    try std.testing.expectApproxEqAbs(@as(f32, 8.0), skull.getAttackDamage(), 0.001);
}

test "guardian init and stats" {
    const guardian = Guardian.init(0, 0, 0);
    try std.testing.expectApproxEqAbs(@as(f32, 30.0), guardian.health, 0.001);
    try std.testing.expect(guardian.alive);
    try std.testing.expect(!guardian.laser_firing);
}

test "guardian laser charge timing" {
    var guardian = Guardian.init(0, 0, 0);
    const targets = [_]Target{
        .{ .x = 5, .y = 0, .z = 0, .hostile = false, .health = 20 },
    };

    guardian.update(2.0, &targets);
    try std.testing.expect(guardian.isLaserCharging());
    try std.testing.expect(!guardian.laser_firing);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), guardian.getAttackDamage(), 0.001);

    guardian.update(1.5, &targets);
    try std.testing.expect(guardian.laser_firing);
    try std.testing.expectApproxEqAbs(@as(f32, 6.0), guardian.getAttackDamage(), 0.001);
}

test "guardian laser resets without target" {
    var guardian = Guardian.init(0, 0, 0);
    const near = [_]Target{
        .{ .x = 5, .y = 0, .z = 0, .hostile = false, .health = 20 },
    };

    guardian.update(2.0, &near);
    try std.testing.expect(guardian.laser_charge > 0);

    const far = [_]Target{
        .{ .x = 100, .y = 0, .z = 0, .hostile = false, .health = 20 },
    };
    guardian.update(0.1, &far);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), guardian.laser_charge, 0.001);
    try std.testing.expect(!guardian.laser_target_acquired);
}

test "elder guardian init and mining fatigue" {
    const elder = ElderGuardian.init(0, 0, 0);
    try std.testing.expectApproxEqAbs(@as(f32, 80.0), elder.health, 0.001);
    try std.testing.expectEqual(@as(u8, 3), elder.getMiningFatigueLevel());

    try std.testing.expect(elder.inflictsMiningFatigue(30, 0, 0));
    try std.testing.expect(!elder.inflictsMiningFatigue(60, 0, 0));
}

test "elder guardian mining fatigue stops when dead" {
    var elder = ElderGuardian.init(0, 0, 0);
    elder.takeDamage(80);
    try std.testing.expect(!elder.alive);
    try std.testing.expect(!elder.inflictsMiningFatigue(5, 0, 0));
}

test "phantom init and stats" {
    const phantom = Phantom.init(0, 30, 0);
    try std.testing.expectApproxEqAbs(@as(f32, 20.0), phantom.health, 0.001);
    try std.testing.expect(phantom.alive);
    try std.testing.expect(!phantom.is_diving);
}

test "phantom burns in daylight" {
    var phantom = Phantom.init(0, 30, 0);
    phantom.setDaylight(true);
    const targets = [_]Target{};

    phantom.update(11.0, &targets);
    try std.testing.expect(!phantom.alive);
}

test "phantom does not burn at night" {
    var phantom = Phantom.init(0, 30, 0);
    phantom.setDaylight(false);
    const targets = [_]Target{};

    phantom.update(20.0, &targets);
    try std.testing.expect(phantom.alive);
    try std.testing.expectApproxEqAbs(@as(f32, 20.0), phantom.health, 0.001);
}

test "phantom dive attack" {
    var phantom = Phantom.init(0, 30, 0);
    const targets = [_]Target{
        .{ .x = 0, .y = 10, .z = 0, .hostile = false, .health = 20 },
    };

    phantom.update(5.0, &targets);
    try std.testing.expect(phantom.is_diving);
    try std.testing.expectApproxEqAbs(@as(f32, 6.0), phantom.getAttackDamage(), 0.001);
}

test "phantom spawn threshold" {
    try std.testing.expect(!Phantom.shouldSpawn(2));
    try std.testing.expect(Phantom.shouldSpawn(3));
    try std.testing.expect(Phantom.shouldSpawn(5));
}

test "iron golem takes damage and dies" {
    var golem = IronGolem.init(0, 0, 0);
    golem.takeDamage(50);
    try std.testing.expectApproxEqAbs(@as(f32, 50.0), golem.health, 0.001);
    try std.testing.expect(golem.alive);

    golem.takeDamage(60);
    try std.testing.expect(!golem.alive);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), golem.health, 0.001);
}

test "wither dies at zero health" {
    var wither = Wither.init(0, 0, 0);
    wither.takeDamage(300);
    try std.testing.expect(!wither.alive);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), wither.health, 0.001);
}

test "guardian takes damage and dies" {
    var guardian = Guardian.init(0, 0, 0);
    guardian.takeDamage(30);
    try std.testing.expect(!guardian.alive);
}

test "phantom takes damage" {
    var phantom = Phantom.init(0, 30, 0);
    phantom.takeDamage(10);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), phantom.health, 0.001);
    try std.testing.expect(phantom.alive);
}

test "wither phase3 charges toward target" {
    var wither = Wither.init(0, 0, 0);
    wither.phase = .phase3;
    wither.shield_active = false;

    const targets = [_]Target{
        .{ .x = 20, .y = 0, .z = 0, .hostile = false, .health = 20 },
    };

    const x_before = wither.x;
    wither.update(1.0, &targets);
    try std.testing.expect(wither.x > x_before);
}
