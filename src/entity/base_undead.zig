/// Base undead mobs: Zombie (baby, reinforcement, door-breaking, villager conversion)
/// and Skeleton (ranged AI, strafing, arrow mechanics). Shared undead sunlight/potion traits.
const std = @import("std");

pub const UndeadTraits = struct {
    burns_in_sun: bool = true,
    has_helmet: bool = false,
    in_water: bool = false,

    pub fn shouldBurn(self: *const UndeadTraits, is_day: bool) bool {
        if (!self.burns_in_sun) return false;
        if (self.has_helmet or self.in_water) return false;
        return is_day;
    }

    pub fn takePotionDamage(effect_type: PotionEffect) f32 {
        return switch (effect_type) {
            .instant_health => 6.0, // damages undead
            .instant_damage => -6.0, // heals undead (negative = heal)
            .poison => 0.0, // immune
            .regeneration => 0.0, // immune
        };
    }
};

pub const PotionEffect = enum { instant_health, instant_damage, poison, regeneration };
pub const Difficulty = enum(u8) { peaceful = 0, easy = 1, normal = 2, hard = 3 };

pub const ZombieAction = enum { idle, chase, attack, break_door, burn, die };

pub const Zombie = struct {
    x: f32,
    y: f32,
    z: f32,
    hp: f32 = 20.0,
    max_hp: f32 = 20.0,
    damage: f32 = 3.0,
    speed: f32 = 0.23,
    is_baby: bool = false,
    alive: bool = true,
    attack_cooldown: f32 = 0.0,
    undead: UndeadTraits = .{},
    burn_timer: f32 = 0.0,
    reinforcement_chance: f32 = 0.05,

    pub fn init(x: f32, y: f32, z: f32, rng_val: u32) Zombie {
        const is_baby = (rng_val % 20) == 0; // 5% baby
        return .{
            .x = x, .y = y, .z = z,
            .is_baby = is_baby,
            .speed = if (is_baby) 0.46 else 0.23,
            .undead = .{ .burns_in_sun = !is_baby },
        };
    }

    pub fn update(self: *Zombie, dt: f32, px: f32, py: f32, pz: f32, is_day: bool, difficulty: Difficulty) ZombieAction {
        if (!self.alive) return .die;
        if (self.hp <= 0) { self.alive = false; return .die; }

        if (self.undead.shouldBurn(is_day)) {
            self.burn_timer += dt;
            if (self.burn_timer >= 1.0) {
                self.hp -= 1.0;
                self.burn_timer = 0;
            }
            return .burn;
        }

        self.attack_cooldown = @max(0, self.attack_cooldown - dt);

        const dx = px - self.x;
        const dy = py - self.y;
        const dz = pz - self.z;
        const dist_sq = dx * dx + dy * dy + dz * dz;

        if (dist_sq > 40 * 40) return .idle;
        if (dist_sq < 2.0 and self.attack_cooldown <= 0) {
            self.attack_cooldown = 1.0;
            return .attack;
        }

        // Move toward player
        const dist = @sqrt(dist_sq);
        if (dist > 0.1) {
            self.x += (dx / dist) * self.speed * dt;
            self.z += (dz / dist) * self.speed * dt;
        }
        _ = difficulty;
        return .chase;
    }

    pub fn getAttackDamage(self: *const Zombie, difficulty: Difficulty) f32 {
        return switch (difficulty) {
            .easy => self.damage * 0.5,
            .normal => self.damage,
            .hard => self.damage * 1.5,
            .peaceful => 0,
        };
    }

    pub fn getVillagerConversionChance(difficulty: Difficulty) f32 {
        return switch (difficulty) {
            .hard => 1.0,
            .normal => 0.5,
            .easy => 0.0,
            .peaceful => 0.0,
        };
    }

    pub fn shouldReinforce(self: *const Zombie, rng_val: f32) bool {
        return rng_val < self.reinforcement_chance;
    }

    pub fn takeDamage(self: *Zombie, dmg: f32) void {
        self.hp -= dmg;
        if (self.hp <= 0) self.alive = false;
    }

    pub fn getDrops(rng_val: u32) struct { rotten_flesh: u8, rare_drop: ?u8 } {
        const flesh = @as(u8, @intCast(rng_val % 3));
        const rare: ?u8 = if (rng_val % 40 == 0) @as(u8, @intCast(rng_val % 3)) else null;
        return .{ .rotten_flesh = flesh, .rare_drop = rare };
    }
};

pub const SkeletonAction = enum { idle, strafe, shoot, retreat, burn, die };

pub const Skeleton = struct {
    x: f32,
    y: f32,
    z: f32,
    hp: f32 = 20.0,
    alive: bool = true,
    speed: f32 = 0.25,
    shoot_cooldown: f32 = 0.0,
    strafe_dir: f32 = 1.0,
    strafe_timer: f32 = 0.0,
    undead: UndeadTraits = .{},
    burn_timer: f32 = 0.0,

    pub fn init(x: f32, y: f32, z: f32) Skeleton {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn update(self: *Skeleton, dt: f32, px: f32, py: f32, pz: f32, is_day: bool, difficulty: Difficulty) SkeletonAction {
        if (!self.alive) return .die;
        if (self.hp <= 0) { self.alive = false; return .die; }

        if (self.undead.shouldBurn(is_day)) {
            self.burn_timer += dt;
            if (self.burn_timer >= 1.0) { self.hp -= 1.0; self.burn_timer = 0; }
            return .burn;
        }

        self.shoot_cooldown = @max(0, self.shoot_cooldown - dt);

        const dx = px - self.x;
        const dz = pz - self.z;
        const dist_sq = dx * dx + dz * dz;
        const dist = @sqrt(dist_sq);
        _ = py;

        if (dist > 40) return .idle;

        // Retreat if player is very close
        if (dist < 4.0) {
            if (dist > 0.1) {
                self.x -= (dx / dist) * self.speed * dt;
                self.z -= (dz / dist) * self.speed * dt;
            }
            return .retreat;
        }

        // Shoot if in range and cooldown ready
        if (dist < 15.0 and self.shoot_cooldown <= 0) {
            self.shoot_cooldown = switch (difficulty) {
                .hard => 1.0,
                else => 2.0,
            };
            return .shoot;
        }

        // Strafe while waiting to shoot
        self.strafe_timer += dt;
        if (self.strafe_timer > 3.0) {
            self.strafe_dir = -self.strafe_dir;
            self.strafe_timer = 0;
        }
        if (dist > 0.1) {
            const perp_x = -dz / dist;
            const perp_z = dx / dist;
            self.x += perp_x * self.strafe_dir * self.speed * dt;
            self.z += perp_z * self.strafe_dir * self.speed * dt;
        }
        return .strafe;
    }

    pub fn getArrowDamage(difficulty: Difficulty) f32 {
        return switch (difficulty) {
            .easy => 2.0,
            .normal => 3.0,
            .hard => 4.0,
            .peaceful => 0,
        };
    }

    pub fn takeDamage(self: *Skeleton, dmg: f32) void {
        self.hp -= dmg;
        if (self.hp <= 0) self.alive = false;
    }

    pub fn getDrops(rng_val: u32) struct { bones: u8, arrows: u8, drops_bow: bool } {
        return .{
            .bones = @intCast(rng_val % 3),
            .arrows = @intCast((rng_val / 3) % 3),
            .drops_bow = (rng_val % 12) == 0,
        };
    }
};

test "zombie baby speed" {
    const z = Zombie.init(0, 0, 0, 20); // rng%20==0 → baby
    try std.testing.expect(z.is_baby);
    try std.testing.expectApproxEqAbs(@as(f32, 0.46), z.speed, 0.01);
}

test "skeleton strafe direction flips" {
    var s = Skeleton.init(0, 0, 0);
    const initial_dir = s.strafe_dir;
    s.strafe_timer = 3.1;
    _ = s.update(0.1, 10, 0, 0, false, .normal);
    try std.testing.expect(s.strafe_dir != initial_dir);
}

test "undead burns in sun without helmet" {
    const traits = UndeadTraits{};
    try std.testing.expect(traits.shouldBurn(true));
    const armored = UndeadTraits{ .has_helmet = true };
    try std.testing.expect(!armored.shouldBurn(true));
}
