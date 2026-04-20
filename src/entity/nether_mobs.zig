const std = @import("std");

pub const FireballShot = struct {
    damage: f32 = 5.0,
    burst_index: u8 = 0,
};

pub const ExplosiveFireball = struct {
    power: f32 = 1.0,
    vx: f32 = 0,
    vz: f32 = 0,
    deflectable: bool = true,
};

pub const BlazeEntity = struct {
    x: f32,
    y: f32,
    z: f32,
    health: f32 = 20,
    fire_shield: bool = false,
    shoot_cooldown: f32 = 0,
    shot_count: u8 = 0,

    const max_burst: u8 = 3;
    const burst_cooldown: f32 = 3.0;
    const fireball_damage: f32 = 5.0;

    pub fn update(self: *BlazeEntity, dt: f32, target_dist: f32) void {
        _ = target_dist;
        if (self.shoot_cooldown > 0) {
            self.shoot_cooldown = @max(self.shoot_cooldown - dt, 0);
        }
    }

    pub fn shootFireball(self: *BlazeEntity) ?FireballShot {
        if (self.shoot_cooldown > 0) return null;

        const index = self.shot_count;
        self.shot_count += 1;

        if (self.shot_count >= max_burst) {
            self.shot_count = 0;
            self.shoot_cooldown = burst_cooldown;
        }

        return FireballShot{
            .damage = fireball_damage,
            .burst_index = index,
        };
    }

    pub fn isOnFire(self: BlazeEntity) bool {
        _ = self;
        return true;
    }

    pub fn getDrops() struct { blaze_rod_chance: f32 } {
        return .{ .blaze_rod_chance = 0.5 };
    }
};

pub const GhastEntity = struct {
    x: f32,
    y: f32,
    z: f32,
    health: f32 = 10,
    shoot_cooldown: f32 = 0,
    hitbox_size: f32 = 4.0,

    const shoot_interval: f32 = 3.0;

    pub fn update(self: *GhastEntity, dt: f32, target_dist: f32) void {
        _ = target_dist;
        if (self.shoot_cooldown > 0) {
            self.shoot_cooldown = @max(self.shoot_cooldown - dt, 0);
        }
        // Ghasts float — vertical drift kept as a stub for callers.
    }

    pub fn shootExplosiveFireball(self: *GhastEntity) ?ExplosiveFireball {
        if (self.shoot_cooldown > 0) return null;

        self.shoot_cooldown = shoot_interval;
        return ExplosiveFireball{
            .power = 1.0,
            .deflectable = true,
        };
    }

    pub fn canDeflect(fireball_vx: f32, fireball_vz: f32, hit_angle: f32) bool {
        _ = fireball_vx;
        _ = fireball_vz;
        // Deflect succeeds when the hit lands within 90 degrees of head-on.
        return @abs(hit_angle) <= std.math.pi / 2.0;
    }

    pub fn getDrops() struct { ghast_tear_chance: f32, gunpowder_chance: f32 } {
        return .{ .ghast_tear_chance = 0.5, .gunpowder_chance = 0.5 };
    }
};

test "blaze fires 3-burst then enters cooldown" {
    var blaze = BlazeEntity{ .x = 0, .y = 0, .z = 0 };

    // Three successive shots should succeed (burst of 3).
    const s0 = blaze.shootFireball() orelse return error.ExpectedShot;
    try std.testing.expectEqual(@as(u8, 0), s0.burst_index);

    const s1 = blaze.shootFireball() orelse return error.ExpectedShot;
    try std.testing.expectEqual(@as(u8, 1), s1.burst_index);

    const s2 = blaze.shootFireball() orelse return error.ExpectedShot;
    try std.testing.expectEqual(@as(u8, 2), s2.burst_index);
    try std.testing.expectEqual(@as(f32, 5.0), s2.damage);

    // Fourth shot blocked by cooldown.
    try std.testing.expect(blaze.shootFireball() == null);

    // After cooldown elapses, a new burst can begin.
    blaze.update(3.0, 0);
    const s3 = blaze.shootFireball() orelse return error.ExpectedShot;
    try std.testing.expectEqual(@as(u8, 0), s3.burst_index);
}

test "blaze is always on fire (fire immunity)" {
    const blaze = BlazeEntity{ .x = 0, .y = 0, .z = 0 };
    try std.testing.expect(blaze.isOnFire());
}

test "blaze drops have 50% blaze rod chance" {
    const drops = BlazeEntity.getDrops();
    try std.testing.expectEqual(@as(f32, 0.5), drops.blaze_rod_chance);
}

test "ghast has 10 HP" {
    const ghast = GhastEntity{ .x = 0, .y = 0, .z = 0 };
    try std.testing.expectEqual(@as(f32, 10), ghast.health);
}

test "ghast fires explosive fireball then enters cooldown" {
    var ghast = GhastEntity{ .x = 0, .y = 0, .z = 0 };

    const fb = ghast.shootExplosiveFireball() orelse return error.ExpectedFireball;
    try std.testing.expectEqual(@as(f32, 1.0), fb.power);
    try std.testing.expect(fb.deflectable);

    // Immediately after firing, cooldown blocks the next shot.
    try std.testing.expect(ghast.shootExplosiveFireball() == null);

    // After 3 s the ghast can fire again.
    ghast.update(3.0, 0);
    try std.testing.expect(ghast.shootExplosiveFireball() != null);
}

test "ghast fireball can be deflected" {
    // Head-on hit (angle 0) — should deflect.
    try std.testing.expect(GhastEntity.canDeflect(1, 0, 0));

    // Glancing hit within 90 degrees — should deflect.
    try std.testing.expect(GhastEntity.canDeflect(1, 0, std.math.pi / 4.0));

    // Hit from behind (> 90 degrees) — should NOT deflect.
    try std.testing.expect(!GhastEntity.canDeflect(1, 0, std.math.pi));
}

test "ghast drops have correct chances" {
    const drops = GhastEntity.getDrops();
    try std.testing.expectEqual(@as(f32, 0.5), drops.ghast_tear_chance);
    try std.testing.expectEqual(@as(f32, 0.5), drops.gunpowder_chance);
}
