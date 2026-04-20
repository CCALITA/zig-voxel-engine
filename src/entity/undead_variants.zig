const std = @import("std");

// ─── Shared types ────────────────────────────────────────────────────────────

pub const TridentThrow = struct {
    damage: f32 = 8.0,
    range: f32 = 20.0,
    origin_x: f32,
    origin_y: f32,
    origin_z: f32,
};

pub const ArrowShot = struct {
    damage: f32 = 2.0,
    slowness_duration_secs: f32 = 30.0,
    slowness_level: u8 = 1,
    origin_x: f32,
    origin_y: f32,
    origin_z: f32,
};

pub const HuskAttack = struct {
    damage: f32 = 3.0,
    hunger_duration_secs: f32 = 10.0,
    origin_x: f32,
    origin_y: f32,
    origin_z: f32,
};

// ─── DrownedEntity ───────────────────────────────────────────────────────────

pub const DrownedEntity = struct {
    x: f32,
    y: f32,
    z: f32,
    health: f32 = 20.0,
    has_trident: bool,
    throw_cooldown: f32 = 0.0,

    const trident_chance: f32 = 0.15;
    const trident_cooldown_secs: f32 = 3.0;

    /// Create a new DrownedEntity with trident determined by the given RNG.
    pub fn init(x: f32, y: f32, z: f32, rng: std.Random) DrownedEntity {
        return .{
            .x = x,
            .y = y,
            .z = z,
            .has_trident = rng.float(f32) < trident_chance,
        };
    }

    /// Create a DrownedEntity with explicit trident state.
    pub fn initWithTrident(x: f32, y: f32, z: f32, has_trident: bool) DrownedEntity {
        return .{
            .x = x,
            .y = y,
            .z = z,
            .has_trident = has_trident,
        };
    }

    pub fn update(self: *DrownedEntity, dt: f32) void {
        if (self.throw_cooldown > 0) {
            self.throw_cooldown = @max(0.0, self.throw_cooldown - dt);
        }
    }

    /// Attempt to throw a trident. Returns null if the drowned has no trident
    /// or is still on cooldown.
    pub fn throwTrident(self: *DrownedEntity) ?TridentThrow {
        if (!self.has_trident) return null;
        if (self.throw_cooldown > 0) return null;

        self.throw_cooldown = trident_cooldown_secs;
        return TridentThrow{
            .origin_x = self.x,
            .origin_y = self.y,
            .origin_z = self.z,
        };
    }

    pub fn canSpawnInWater() bool {
        return true;
    }
};

// ─── StrayEntity ─────────────────────────────────────────────────────────────

pub const StrayEntity = struct {
    x: f32,
    y: f32,
    z: f32,
    health: f32 = 20.0,
    shoot_cooldown: f32 = 0.0,

    const shoot_cooldown_secs: f32 = 2.0;

    pub fn init(x: f32, y: f32, z: f32) StrayEntity {
        return .{ .x = x, .y = y, .z = z };
    }

    /// Shoot a slowness-tipped arrow. Returns null when on cooldown.
    pub fn shootSlownessArrow(self: *StrayEntity) ?ArrowShot {
        if (self.shoot_cooldown > 0) return null;

        self.shoot_cooldown = shoot_cooldown_secs;
        return ArrowShot{
            .origin_x = self.x,
            .origin_y = self.y,
            .origin_z = self.z,
        };
    }

    pub fn spawnsInIceBiome() bool {
        return true;
    }
};

// ─── HuskEntity ──────────────────────────────────────────────────────────────

pub const HuskEntity = struct {
    x: f32,
    y: f32,
    z: f32,
    health: f32 = 20.0,
    attack_cooldown: f32 = 0.0,

    const attack_cooldown_secs: f32 = 1.0;

    pub fn init(x: f32, y: f32, z: f32) HuskEntity {
        return .{ .x = x, .y = y, .z = z };
    }

    /// Perform a melee attack that inflicts hunger. Returns null when on cooldown.
    pub fn meleeAttack(self: *HuskEntity) ?HuskAttack {
        if (self.attack_cooldown > 0) return null;

        self.attack_cooldown = attack_cooldown_secs;
        return HuskAttack{
            .origin_x = self.x,
            .origin_y = self.y,
            .origin_z = self.z,
        };
    }

    pub fn burnInSunlight() bool {
        return false;
    }
};

// ─── Tests ───────────────────────────────────────────────────────────────────

test "drowned trident chance is approximately 15%" {
    var prng = std.Random.DefaultPrng.init(42);
    const rng = prng.random();

    const sample_size: u32 = 10_000;
    var trident_count: u32 = 0;
    for (0..sample_size) |_| {
        const d = DrownedEntity.init(0, 0, 0, rng);
        if (d.has_trident) trident_count += 1;
    }

    const ratio: f32 = @as(f32, @floatFromInt(trident_count)) / @as(f32, @floatFromInt(sample_size));
    // Allow reasonable tolerance: 10% – 20%
    try std.testing.expect(ratio > 0.10);
    try std.testing.expect(ratio < 0.20);
}

test "drowned with trident can throw and respects cooldown" {
    var d = DrownedEntity.initWithTrident(1, 2, 3, true);

    const throw1 = d.throwTrident();
    try std.testing.expect(throw1 != null);
    try std.testing.expectEqual(@as(f32, 8.0), throw1.?.damage);
    try std.testing.expectEqual(@as(f32, 20.0), throw1.?.range);

    // On cooldown — should return null
    const throw2 = d.throwTrident();
    try std.testing.expect(throw2 == null);

    // After cooldown expires
    d.update(DrownedEntity.trident_cooldown_secs);
    const throw3 = d.throwTrident();
    try std.testing.expect(throw3 != null);
}

test "drowned without trident cannot throw" {
    var d = DrownedEntity.initWithTrident(0, 0, 0, false);
    try std.testing.expect(d.throwTrident() == null);
}

test "drowned can spawn in water" {
    try std.testing.expect(DrownedEntity.canSpawnInWater());
}

test "stray shoots slowness arrow with correct properties" {
    var s = StrayEntity.init(5, 6, 7);

    const shot = s.shootSlownessArrow();
    try std.testing.expect(shot != null);
    try std.testing.expectEqual(@as(f32, 30.0), shot.?.slowness_duration_secs);
    try std.testing.expectEqual(@as(u8, 1), shot.?.slowness_level);

    // On cooldown
    try std.testing.expect(s.shootSlownessArrow() == null);
}

test "stray spawns in ice biome" {
    try std.testing.expect(StrayEntity.spawnsInIceBiome());
}

test "husk melee attack inflicts hunger effect" {
    var h = HuskEntity.init(10, 11, 12);

    const atk = h.meleeAttack();
    try std.testing.expect(atk != null);
    try std.testing.expectEqual(@as(f32, 3.0), atk.?.damage);
    try std.testing.expectEqual(@as(f32, 10.0), atk.?.hunger_duration_secs);

    // On cooldown
    try std.testing.expect(h.meleeAttack() == null);
}

test "husk does not burn in sunlight" {
    try std.testing.expect(!HuskEntity.burnInSunlight());
}
