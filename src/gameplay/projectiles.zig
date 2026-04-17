const std = @import("std");

pub const pool_capacity: usize = 256;

const default_gravity: f32 = -20.0;

const arrow_min_damage: f32 = 2.0;
const arrow_max_damage: f32 = 6.0;
const arrow_max_speed: f32 = 3.0;

const default_lifetime: f32 = 5.0; // seconds

pub const ProjectileType = enum {
    arrow,
    ender_pearl,
    snowball,
    egg,
    fireball,
};

pub const Projectile = struct {
    projectile_type: ProjectileType = .arrow,
    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,
    vx: f32 = 0.0,
    vy: f32 = 0.0,
    vz: f32 = 0.0,
    damage: f32 = 0.0,
    lifetime: f32 = default_lifetime,
    active: bool = false,

    pub fn speed(self: *const Projectile) f32 {
        return @sqrt(self.vx * self.vx + self.vy * self.vy + self.vz * self.vz);
    }
};

pub const ProjectileManager = struct {
    pool: [pool_capacity]Projectile = [_]Projectile{.{}} ** pool_capacity,

    pub fn init() ProjectileManager {
        return .{};
    }

    /// Spawn a projectile at `pos` flying in `dir` (unit vector) at `spd`.
    /// Returns the slot index, or null when the pool is full.
    pub fn spawn(
        self: *ProjectileManager,
        projectile_type: ProjectileType,
        pos: [3]f32,
        dir: [3]f32,
        spd: f32,
    ) ?usize {
        for (&self.pool, 0..) |*slot, i| {
            if (!slot.active) {
                slot.* = .{
                    .projectile_type = projectile_type,
                    .x = pos[0],
                    .y = pos[1],
                    .z = pos[2],
                    .vx = dir[0] * spd,
                    .vy = dir[1] * spd,
                    .vz = dir[2] * spd,
                    .damage = computeDamage(projectile_type, spd),
                    .lifetime = default_lifetime,
                    .active = true,
                };
                return i;
            }
        }
        return null;
    }

    /// Advance every active projectile by `dt` seconds:
    ///   1. Apply gravity to vertical velocity.
    ///   2. Integrate position.
    ///   3. Recalculate speed-dependent damage (arrows).
    ///   4. Expire when lifetime runs out.
    pub fn update(self: *ProjectileManager, dt: f32) void {
        for (&self.pool) |*p| {
            if (!p.active) continue;

            const g = gravityFor(p.projectile_type);
            p.vy += g * dt;

            p.x += p.vx * dt;
            p.y += p.vy * dt;
            p.z += p.vz * dt;

            if (p.projectile_type == .arrow) {
                p.damage = computeDamage(.arrow, p.speed());
            }

            p.lifetime -= dt;
            if (p.lifetime <= 0.0) {
                p.active = false;
            }
        }
    }

    /// Return a count of currently active projectiles.
    pub fn activeCount(self: *const ProjectileManager) usize {
        var count: usize = 0;
        for (self.pool) |p| {
            if (p.active) count += 1;
        }
        return count;
    }

    /// Return a bounded slice containing copies of every active projectile.
    pub fn getActive(self: *const ProjectileManager, buf: []Projectile) []Projectile {
        var n: usize = 0;
        for (self.pool) |p| {
            if (p.active) {
                if (n >= buf.len) break;
                buf[n] = p;
                n += 1;
            }
        }
        return buf[0..n];
    }
};

// ── helpers ──────────────────────────────────────────────────────────────────

fn gravityFor(t: ProjectileType) f32 {
    return switch (t) {
        .fireball => 0.0,
        .arrow, .ender_pearl, .snowball, .egg => default_gravity,
    };
}

/// Arrow damage scales linearly from 2 to 6 based on speed (0..arrow_max_speed).
/// Snowball: 0.  Others: fixed per-type value.
fn computeDamage(t: ProjectileType, spd: f32) f32 {
    return switch (t) {
        .arrow => blk: {
            const clamped = @min(spd, arrow_max_speed);
            const ratio = clamped / arrow_max_speed;
            break :blk arrow_min_damage + ratio * (arrow_max_damage - arrow_min_damage);
        },
        .snowball => 0.0,
        .egg => 0.0,
        .ender_pearl => 5.0,
        .fireball => 6.0,
    };
}

// ──────────────────────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────────────────────

test "spawn places an active projectile in the pool" {
    var mgr = ProjectileManager.init();
    const idx = mgr.spawn(.arrow, .{ 1.0, 2.0, 3.0 }, .{ 0.0, 1.0, 0.0 }, 2.0);
    try std.testing.expect(idx != null);

    const p = mgr.pool[idx.?];
    try std.testing.expect(p.active);
    try std.testing.expectEqual(@as(f32, 1.0), p.x);
    try std.testing.expectEqual(@as(f32, 2.0), p.y);
    try std.testing.expectEqual(@as(f32, 3.0), p.z);
    try std.testing.expectEqual(ProjectileType.arrow, p.projectile_type);
}

test "spawn returns null when pool is full" {
    var mgr = ProjectileManager.init();
    for (0..pool_capacity) |_| {
        _ = mgr.spawn(.snowball, .{ 0, 0, 0 }, .{ 1, 0, 0 }, 1.0);
    }
    const result = mgr.spawn(.snowball, .{ 0, 0, 0 }, .{ 1, 0, 0 }, 1.0);
    try std.testing.expect(result == null);
}

test "gravity applies to vertical velocity over time" {
    var mgr = ProjectileManager.init();
    _ = mgr.spawn(.arrow, .{ 0, 10.0, 0 }, .{ 0, 0, 0 }, 0.0);

    mgr.update(1.0);

    const p = mgr.pool[0];
    // vy should have changed by gravity * dt = -20
    try std.testing.expectApproxEqAbs(@as(f32, -20.0), p.vy, 0.001);
    // y should have moved by vy * dt = -20
    try std.testing.expectApproxEqAbs(@as(f32, -10.0), p.y, 0.001);
}

test "fireball has no gravity" {
    var mgr = ProjectileManager.init();
    _ = mgr.spawn(.fireball, .{ 0, 5.0, 0 }, .{ 1.0, 0, 0 }, 10.0);

    mgr.update(1.0);

    const p = mgr.pool[0];
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), p.vy, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), p.y, 0.001);
}

test "lifetime expires and deactivates projectile" {
    var mgr = ProjectileManager.init();
    _ = mgr.spawn(.egg, .{ 0, 0, 0 }, .{ 1, 0, 0 }, 1.0);
    try std.testing.expectEqual(@as(usize, 1), mgr.activeCount());

    // Advance past default lifetime
    mgr.update(default_lifetime + 0.1);

    try std.testing.expectEqual(@as(usize, 0), mgr.activeCount());
    try std.testing.expect(!mgr.pool[0].active);
}

test "activeCount tracks live projectiles" {
    var mgr = ProjectileManager.init();
    try std.testing.expectEqual(@as(usize, 0), mgr.activeCount());

    _ = mgr.spawn(.arrow, .{ 0, 0, 0 }, .{ 1, 0, 0 }, 1.0);
    _ = mgr.spawn(.snowball, .{ 0, 0, 0 }, .{ 0, 1, 0 }, 1.0);
    try std.testing.expectEqual(@as(usize, 2), mgr.activeCount());

    // Expire all
    mgr.update(default_lifetime + 1.0);
    try std.testing.expectEqual(@as(usize, 0), mgr.activeCount());
}

test "getActive returns only live projectiles" {
    var mgr = ProjectileManager.init();
    _ = mgr.spawn(.arrow, .{ 1, 0, 0 }, .{ 1, 0, 0 }, 1.0);
    _ = mgr.spawn(.ender_pearl, .{ 2, 0, 0 }, .{ 0, 1, 0 }, 1.0);

    var buf: [pool_capacity]Projectile = undefined;
    const active = mgr.getActive(&buf);
    try std.testing.expectEqual(@as(usize, 2), active.len);
    try std.testing.expectEqual(ProjectileType.arrow, active[0].projectile_type);
    try std.testing.expectEqual(ProjectileType.ender_pearl, active[1].projectile_type);
}

test "arrow damage scales with speed" {
    // At zero speed: min damage (2)
    const low = computeDamage(.arrow, 0.0);
    try std.testing.expectApproxEqAbs(arrow_min_damage, low, 0.001);

    // At max speed: max damage (6)
    const high = computeDamage(.arrow, arrow_max_speed);
    try std.testing.expectApproxEqAbs(arrow_max_damage, high, 0.001);

    // At half speed: midpoint (4)
    const mid = computeDamage(.arrow, arrow_max_speed / 2.0);
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), mid, 0.001);

    // Above max speed: clamped to max damage
    const over = computeDamage(.arrow, arrow_max_speed * 2.0);
    try std.testing.expectApproxEqAbs(arrow_max_damage, over, 0.001);
}

test "snowball deals zero damage" {
    const dmg = computeDamage(.snowball, 5.0);
    try std.testing.expectEqual(@as(f32, 0.0), dmg);
}

test "ender pearl deals fixed damage" {
    const dmg = computeDamage(.ender_pearl, 1.0);
    try std.testing.expectEqual(@as(f32, 5.0), dmg);
}

test "position integrates correctly over multiple steps" {
    var mgr = ProjectileManager.init();
    _ = mgr.spawn(.fireball, .{ 0, 0, 0 }, .{ 1.0, 0, 0 }, 10.0);

    mgr.update(0.5);
    mgr.update(0.5);

    const p = mgr.pool[0];
    // 10 units/s * 1.0s total = 10
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), p.x, 0.001);
}

test "spawning reuses expired slot" {
    var mgr = ProjectileManager.init();
    const idx1 = mgr.spawn(.egg, .{ 0, 0, 0 }, .{ 1, 0, 0 }, 1.0);

    // Expire it
    mgr.update(default_lifetime + 1.0);
    try std.testing.expectEqual(@as(usize, 0), mgr.activeCount());

    // Spawn again, should reuse the same slot
    const idx2 = mgr.spawn(.arrow, .{ 5, 5, 5 }, .{ 0, 1, 0 }, 2.0);
    try std.testing.expectEqual(idx1.?, idx2.?);
    try std.testing.expect(mgr.pool[idx2.?].active);
    try std.testing.expectEqual(ProjectileType.arrow, mgr.pool[idx2.?].projectile_type);
}
