/// Creeper entity with fuse mechanic, charged state from lightning, and cat avoidance.
/// Creepers silently approach the player, start a 1.5s fuse within 3 blocks,
/// swell visually during the fuse, and abort if the player moves beyond 7 blocks.
/// Lightning within 4 blocks creates a charged creeper with doubled explosion power.
const std = @import("std");

/// Result of a creeper update tick, consumed by the game loop to drive
/// explosions, movement, and rendering.
pub const CreeperAction = enum {
    idle,
    approach,
    fusing,
    explode,
    flee,
};

/// Loot produced on creeper death.
pub const CreeperDrop = struct {
    gunpowder: u8,
    music_disc: bool,
};

/// Damage result from a creeper explosion at a given distance.
pub const ExplosionDamageResult = struct {
    damage: f32,
    blocks_destroyed: bool,
};

pub const Creeper = struct {
    // -- Position --
    x: f32,
    y: f32,
    z: f32,

    // -- Target tracking --
    target_x: f32 = 0,
    target_y: f32 = 0,
    target_z: f32 = 0,

    // -- Stats --
    hp: f32 = max_hp,
    fuse_timer: f32 = 0,
    is_charged: bool = false,
    is_ignited: bool = false,

    // -- Cat avoidance --
    flee_timer: f32 = 0,
    flee_x: f32 = 0,
    flee_z: f32 = 0,

    // -- Constants --
    const max_hp: f32 = 20.0;
    const detection_range: f32 = 16.0;
    const fuse_start_range: f32 = 3.0;
    const fuse_abort_range: f32 = 7.0;
    const fuse_duration: f32 = 1.5;
    const speed: f32 = 0.25;
    const normal_power: f32 = 3.0;
    const charged_power: f32 = 6.0;
    const normal_max_damage: f32 = 43.0;
    const charged_max_damage: f32 = 85.0;
    const lightning_charge_range: f32 = 4.0;
    const cat_flee_range: f32 = 6.0;
    const cat_flee_duration: f32 = 3.0;

    pub fn init(x: f32, y: f32, z: f32) Creeper {
        return .{
            .x = x,
            .y = y,
            .z = z,
        };
    }

    /// Main update tick. Returns the action the game loop should execute.
    pub fn update(
        self: *Creeper,
        dt: f32,
        player_x: f32,
        player_y: f32,
        player_z: f32,
    ) CreeperAction {
        // Dead creepers do nothing.
        if (self.hp <= 0) return .idle;

        // Cat avoidance takes priority over all hostile behavior.
        if (self.flee_timer > 0) {
            self.flee_timer -= dt;
            self.moveAwayFrom(self.flee_x, self.flee_z, dt);
            // Abort any active fuse when fleeing.
            self.is_ignited = false;
            self.fuse_timer = 0;
            return .flee;
        }

        self.target_x = player_x;
        self.target_y = player_y;
        self.target_z = player_z;

        const dist = self.distanceToPlayer(player_x, player_y, player_z);

        // If already fusing, check abort condition or advance timer.
        if (self.is_ignited) {
            if (dist > fuse_abort_range) {
                self.abortFuse();
                return .idle;
            }
            self.fuse_timer += dt;
            if (self.fuse_timer >= fuse_duration) {
                return .explode;
            }
            return .fusing;
        }

        // Start fuse when close enough.
        if (dist <= fuse_start_range) {
            self.startFuse();
            return .fusing;
        }

        // Approach player within detection range.
        if (dist <= detection_range) {
            self.moveToward(player_x, player_z, dt);
            return .approach;
        }

        return .idle;
    }

    /// Notify the creeper of a nearby cat or ocelot.
    /// If within 6 blocks, the creeper flees.
    pub fn onCatNearby(self: *Creeper, cat_x: f32, cat_y: f32, cat_z: f32) void {
        const dx = self.x - cat_x;
        const dy = self.y - cat_y;
        const dz = self.z - cat_z;
        const dist = @sqrt(dx * dx + dy * dy + dz * dz);

        if (dist <= cat_flee_range) {
            self.flee_timer = cat_flee_duration;
            self.flee_x = cat_x;
            self.flee_z = cat_z;
            // Immediately abort any active fuse.
            self.abortFuse();
        }
    }

    /// Apply a lightning strike at the given position.
    /// If within 4 blocks, the creeper becomes charged.
    pub fn onLightningStrike(self: *Creeper, strike_x: f32, strike_y: f32, strike_z: f32) void {
        const dx = self.x - strike_x;
        const dy = self.y - strike_y;
        const dz = self.z - strike_z;
        const dist = @sqrt(dx * dx + dy * dy + dz * dz);

        if (dist <= lightning_charge_range) {
            self.is_charged = true;
        }
    }

    /// Convenience overload: lightning strikes directly on the creeper.
    pub fn chargeFromLightning(self: *Creeper) void {
        self.is_charged = true;
    }

    /// Explosion power: 3 for normal, 6 for charged.
    pub fn getExplosionPower(self: *const Creeper) f32 {
        return if (self.is_charged) charged_power else normal_power;
    }

    /// Maximum possible damage at point blank.
    pub fn getMaxDamage(self: *const Creeper) f32 {
        return if (self.is_charged) charged_max_damage else normal_max_damage;
    }

    /// Calculate explosion damage at a given distance.
    /// Damage decreases linearly from max at distance 0 to 0 at the explosion radius.
    pub fn calculateExplosionDamage(self: *const Creeper, distance: f32) ExplosionDamageResult {
        const power = self.getExplosionPower();
        const max_damage = self.getMaxDamage();

        if (distance >= power) {
            return .{ .damage = 0, .blocks_destroyed = false };
        }

        const factor = 1.0 - (distance / power);
        return .{
            .damage = max_damage * factor,
            .blocks_destroyed = distance < power,
        };
    }

    /// Reduce HP. The creeper dies at 0 HP.
    pub fn takeDamage(self: *Creeper, amount: f32) void {
        self.hp -= amount;
        if (self.hp <= 0) {
            self.hp = 0;
        }
    }

    /// Current swell factor (0.0 = normal, 1.0 = fully swollen at detonation).
    /// Used by the renderer to scale the model.
    pub fn getSwellFactor(self: *const Creeper) f32 {
        if (!self.is_ignited) return 0;
        return @min(self.fuse_timer / fuse_duration, 1.0);
    }

    /// Determine loot on death.
    /// `killed_by_skeleton_arrow` should be true when the killing blow came
    /// from a skeleton or stray arrow.
    pub fn getDrops(killed_by_skeleton_arrow: bool, seed: u32) CreeperDrop {
        // Gunpowder: 0-2, derived from seed.
        const gunpowder: u8 = @intCast(seed % 3);
        return .{
            .gunpowder = gunpowder,
            .music_disc = killed_by_skeleton_arrow,
        };
    }

    /// Whether this creeper is alive.
    pub fn isAlive(self: *const Creeper) bool {
        return self.hp > 0;
    }

    /// Whether this creeper has an active fuse.
    pub fn isFusing(self: *const Creeper) bool {
        return self.is_ignited;
    }

    // -- Internal helpers ------------------------------------------------

    fn startFuse(self: *Creeper) void {
        self.is_ignited = true;
        self.fuse_timer = 0;
    }

    fn abortFuse(self: *Creeper) void {
        self.is_ignited = false;
        self.fuse_timer = 0;
    }

    fn distanceToPlayer(self: *const Creeper, px: f32, py: f32, pz: f32) f32 {
        const dx = self.x - px;
        const dy = self.y - py;
        const dz = self.z - pz;
        return @sqrt(dx * dx + dy * dy + dz * dz);
    }

    fn moveToward(self: *Creeper, tx: f32, tz: f32, dt: f32) void {
        const dx = tx - self.x;
        const dz = tz - self.z;
        const dist = @sqrt(dx * dx + dz * dz);
        if (dist > 0.001) {
            self.x += (dx / dist) * speed * dt;
            self.z += (dz / dist) * speed * dt;
        }
    }

    fn moveAwayFrom(self: *Creeper, threat_x: f32, threat_z: f32, dt: f32) void {
        const dx = self.x - threat_x;
        const dz = self.z - threat_z;
        const dist = @sqrt(dx * dx + dz * dz);
        if (dist > 0.001) {
            self.x += (dx / dist) * speed * dt;
            self.z += (dz / dist) * speed * dt;
        }
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "init sets correct defaults" {
    const c = Creeper.init(10, 20, 30);
    try std.testing.expectApproxEqAbs(@as(f32, 10), c.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 20), c.y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 30), c.z, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 20), c.hp, 0.001);
    try std.testing.expect(!c.is_charged);
    try std.testing.expect(!c.is_ignited);
    try std.testing.expect(c.isAlive());
}

test "idle when player out of detection range" {
    var c = Creeper.init(0, 0, 0);
    const action = c.update(0.1, 20, 0, 0);
    try std.testing.expectEqual(CreeperAction.idle, action);
}

test "approach when player within detection range" {
    var c = Creeper.init(0, 0, 0);
    const action = c.update(0.1, 10, 0, 0);
    try std.testing.expectEqual(CreeperAction.approach, action);
    // Should have moved toward the player.
    try std.testing.expect(c.x > 0);
}

test "fuse starts within 3 blocks" {
    var c = Creeper.init(0, 0, 0);
    const action = c.update(0.1, 2, 0, 0);
    try std.testing.expectEqual(CreeperAction.fusing, action);
    try std.testing.expect(c.is_ignited);
}

test "fuse aborts when player moves beyond 7 blocks" {
    var c = Creeper.init(0, 0, 0);
    // Start the fuse.
    _ = c.update(0.1, 2, 0, 0);
    try std.testing.expect(c.is_ignited);

    // Player retreats beyond 7 blocks.
    const action = c.update(0.1, 10, 0, 0);
    try std.testing.expectEqual(CreeperAction.idle, action);
    try std.testing.expect(!c.is_ignited);
    try std.testing.expectApproxEqAbs(@as(f32, 0), c.fuse_timer, 0.001);
}

test "explode after 1.5s fuse" {
    var c = Creeper.init(0, 0, 0);

    // Tick in small increments while player stays close.
    var total: f32 = 0;
    var action: CreeperAction = .idle;
    while (total < 2.0) {
        action = c.update(0.05, 2, 0, 0);
        total += 0.05;
        if (action == .explode) break;
    }
    try std.testing.expectEqual(CreeperAction.explode, action);
}

test "normal explosion power is 3" {
    const c = Creeper.init(0, 0, 0);
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), c.getExplosionPower(), 0.001);
}

test "charged explosion power is 6" {
    var c = Creeper.init(0, 0, 0);
    c.is_charged = true;
    try std.testing.expectApproxEqAbs(@as(f32, 6.0), c.getExplosionPower(), 0.001);
}

test "lightning strike within 4 blocks charges creeper" {
    var c = Creeper.init(5, 0, 5);
    c.onLightningStrike(5, 0, 7);
    try std.testing.expect(c.is_charged);
}

test "lightning strike beyond 4 blocks does not charge" {
    var c = Creeper.init(0, 0, 0);
    c.onLightningStrike(10, 0, 10);
    try std.testing.expect(!c.is_charged);
}

test "chargeFromLightning directly sets charged" {
    var c = Creeper.init(0, 0, 0);
    c.chargeFromLightning();
    try std.testing.expect(c.is_charged);
}

test "explosion damage decreases with distance" {
    const c = Creeper.init(0, 0, 0);

    const close = c.calculateExplosionDamage(0);
    const mid = c.calculateExplosionDamage(1.5);
    const far = c.calculateExplosionDamage(3.0);

    try std.testing.expectApproxEqAbs(@as(f32, 43.0), close.damage, 0.001);
    try std.testing.expect(mid.damage > 0);
    try std.testing.expect(mid.damage < close.damage);
    try std.testing.expectApproxEqAbs(@as(f32, 0), far.damage, 0.001);
}

test "charged explosion max damage is 85" {
    var c = Creeper.init(0, 0, 0);
    c.is_charged = true;
    const result = c.calculateExplosionDamage(0);
    try std.testing.expectApproxEqAbs(@as(f32, 85.0), result.damage, 0.001);
}

test "cat avoidance triggers flee" {
    var c = Creeper.init(0, 0, 0);
    c.onCatNearby(3, 0, 0);
    try std.testing.expect(c.flee_timer > 0);

    const action = c.update(0.1, 2, 0, 0);
    try std.testing.expectEqual(CreeperAction.flee, action);
    // Should move away from the cat (negative x since cat is at +3).
    try std.testing.expect(c.x < 0);
}

test "cat aborts active fuse" {
    var c = Creeper.init(0, 0, 0);
    // Start fuse.
    _ = c.update(0.1, 2, 0, 0);
    try std.testing.expect(c.is_ignited);

    // Cat approaches.
    c.onCatNearby(3, 0, 0);
    try std.testing.expect(!c.is_ignited);
}

test "cat beyond 6 blocks does not trigger flee" {
    var c = Creeper.init(0, 0, 0);
    c.onCatNearby(10, 0, 0);
    try std.testing.expectApproxEqAbs(@as(f32, 0), c.flee_timer, 0.001);
}

test "takeDamage reduces hp" {
    var c = Creeper.init(0, 0, 0);
    c.takeDamage(5);
    try std.testing.expectApproxEqAbs(@as(f32, 15), c.hp, 0.001);
    try std.testing.expect(c.isAlive());
}

test "takeDamage clamps to zero" {
    var c = Creeper.init(0, 0, 0);
    c.takeDamage(100);
    try std.testing.expectApproxEqAbs(@as(f32, 0), c.hp, 0.001);
    try std.testing.expect(!c.isAlive());
}

test "dead creeper returns idle" {
    var c = Creeper.init(0, 0, 0);
    c.takeDamage(20);
    const action = c.update(0.1, 2, 0, 0);
    try std.testing.expectEqual(CreeperAction.idle, action);
}

test "swell factor during fuse" {
    var c = Creeper.init(0, 0, 0);
    try std.testing.expectApproxEqAbs(@as(f32, 0), c.getSwellFactor(), 0.001);

    // Start fuse and advance halfway.
    _ = c.update(0.75, 2, 0, 0);
    try std.testing.expect(c.getSwellFactor() > 0);
    try std.testing.expect(c.getSwellFactor() < 1.0);
}

test "drops gunpowder 0-2" {
    const drop0 = Creeper.getDrops(false, 0);
    try std.testing.expectEqual(@as(u8, 0), drop0.gunpowder);
    try std.testing.expect(!drop0.music_disc);

    const drop1 = Creeper.getDrops(false, 1);
    try std.testing.expectEqual(@as(u8, 1), drop1.gunpowder);

    const drop2 = Creeper.getDrops(false, 2);
    try std.testing.expectEqual(@as(u8, 2), drop2.gunpowder);
}

test "music disc drops when killed by skeleton arrow" {
    const drop = Creeper.getDrops(true, 0);
    try std.testing.expect(drop.music_disc);
}

test "no music disc when not killed by skeleton" {
    const drop = Creeper.getDrops(false, 0);
    try std.testing.expect(!drop.music_disc);
}

test "speed is faster than zombie (0.25 > 0.23)" {
    // Creeper speed constant.
    try std.testing.expect(Creeper.speed >= 0.25);
}

test "getMaxDamage normal is 43" {
    const c = Creeper.init(0, 0, 0);
    try std.testing.expectApproxEqAbs(@as(f32, 43.0), c.getMaxDamage(), 0.001);
}

test "getMaxDamage charged is 85" {
    var c = Creeper.init(0, 0, 0);
    c.is_charged = true;
    try std.testing.expectApproxEqAbs(@as(f32, 85.0), c.getMaxDamage(), 0.001);
}

test "blocks destroyed within explosion radius" {
    const c = Creeper.init(0, 0, 0);
    const result = c.calculateExplosionDamage(1.5);
    try std.testing.expect(result.blocks_destroyed);
}

test "no blocks destroyed outside explosion radius" {
    const c = Creeper.init(0, 0, 0);
    const result = c.calculateExplosionDamage(3.0);
    try std.testing.expect(!result.blocks_destroyed);
}
