const std = @import("std");

pub const XpOrb = struct {
    x: f32,
    y: f32,
    z: f32,
    vx: f32 = 0,
    vy: f32 = 0,
    vz: f32 = 0,
    xp_value: u16,
    lifetime: f32 = 0,
    active: bool = true,
};

pub const MAX_ORBS: usize = 128;

const GRAVITY: f32 = 15.0;
const MAGNET_RANGE_SQ: f32 = 25.0; // 5 blocks squared
const MAGNET_SPEED: f32 = 3.0;
const COLLECT_RANGE_SQ: f32 = 1.5;
const DESPAWN_TIME: f32 = 300.0; // 5 minutes
const SPAWN_VY: f32 = 3.0;
const MIN_DIST: f32 = 0.1;

pub const XpOrbManager = struct {
    orbs: [MAX_ORBS]XpOrb = undefined,
    count: u32 = 0,

    pub fn init() XpOrbManager {
        return .{ .count = 0 };
    }

    pub fn spawn(self: *XpOrbManager, x: f32, y: f32, z: f32, xp: u16) void {
        if (self.count >= MAX_ORBS) return;
        self.orbs[self.count] = .{ .x = x, .y = y, .z = z, .vy = SPAWN_VY, .xp_value = xp };
        self.count += 1;
    }

    pub fn update(self: *XpOrbManager, dt: f32, px: f32, py: f32, pz: f32) u32 {
        var collected_xp: u32 = 0;

        for (self.orbs[0..self.count]) |*orb| {
            if (!orb.active) continue;

            orb.lifetime += dt;
            if (orb.lifetime > DESPAWN_TIME) {
                orb.active = false;
                continue;
            }

            // Gravity
            orb.vy -= GRAVITY * dt;

            // Integrate position
            orb.x += orb.vx * dt;
            orb.y += orb.vy * dt;
            orb.z += orb.vz * dt;

            // Ground collision
            if (orb.y < 0) {
                orb.y = 0;
                orb.vy = 0;
            }

            // Magnetic attraction within range
            const dx = px - orb.x;
            const dy = py - orb.y;
            const dz = pz - orb.z;
            const dist_sq = dx * dx + dy * dy + dz * dz;

            if (dist_sq < COLLECT_RANGE_SQ) {
                collected_xp += orb.xp_value;
                orb.active = false;
            } else if (dist_sq < MAGNET_RANGE_SQ) {
                const inv = MAGNET_SPEED / @max(@sqrt(dist_sq), MIN_DIST);
                orb.vx = dx * inv;
                orb.vy = dy * inv;
                orb.vz = dz * inv;
            }
        }

        self.compact();
        return collected_xp;
    }

    fn compact(self: *XpOrbManager) void {
        var w: u32 = 0;
        for (self.orbs[0..self.count]) |orb| {
            if (orb.active) {
                self.orbs[w] = orb;
                w += 1;
            }
        }
        self.count = w;
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "init returns zero count" {
    const mgr = XpOrbManager.init();
    try std.testing.expectEqual(@as(u32, 0), mgr.count);
}

test "spawn adds orb with correct position and xp" {
    var mgr = XpOrbManager.init();
    mgr.spawn(1.0, 2.0, 3.0, 10);

    try std.testing.expectEqual(@as(u32, 1), mgr.count);
    try std.testing.expectEqual(@as(f32, 1.0), mgr.orbs[0].x);
    try std.testing.expectEqual(@as(f32, 2.0), mgr.orbs[0].y);
    try std.testing.expectEqual(@as(f32, 3.0), mgr.orbs[0].z);
    try std.testing.expectEqual(@as(u16, 10), mgr.orbs[0].xp_value);
    try std.testing.expect(mgr.orbs[0].active);
}

test "spawn gives upward velocity" {
    var mgr = XpOrbManager.init();
    mgr.spawn(0, 0, 0, 5);
    try std.testing.expectEqual(SPAWN_VY, mgr.orbs[0].vy);
}

test "spawn respects MAX_ORBS limit" {
    var mgr = XpOrbManager.init();
    for (0..MAX_ORBS) |_| {
        mgr.spawn(0, 0, 0, 1);
    }
    try std.testing.expectEqual(@as(u32, MAX_ORBS), mgr.count);

    // One more should be silently ignored
    mgr.spawn(0, 0, 0, 1);
    try std.testing.expectEqual(@as(u32, MAX_ORBS), mgr.count);
}

test "update applies gravity" {
    var mgr = XpOrbManager.init();
    mgr.spawn(0, 50.0, 0, 1);
    mgr.orbs[0].vy = 0; // zero out initial pop

    _ = mgr.update(0.1, 999, 999, 999);
    try std.testing.expect(mgr.orbs[0].y < 50.0);
}

test "ground collision prevents negative y" {
    var mgr = XpOrbManager.init();
    mgr.spawn(0, 0.5, 0, 1);
    mgr.orbs[0].vy = -100.0; // large downward velocity

    _ = mgr.update(1.0, 999, 999, 999);
    try std.testing.expect(mgr.orbs[0].y >= 0);
}

test "orb collected when player is close" {
    var mgr = XpOrbManager.init();
    mgr.spawn(0, 0, 0, 25);
    // Zero velocity so orb stays at origin
    mgr.orbs[0].vy = 0;

    const xp = mgr.update(0.001, 0, 0, 0);
    try std.testing.expectEqual(@as(u32, 25), xp);
    try std.testing.expectEqual(@as(u32, 0), mgr.count); // compacted away
}

test "multiple orbs collected in single update" {
    var mgr = XpOrbManager.init();
    mgr.spawn(0, 0, 0, 10);
    mgr.spawn(0, 0, 0, 15);
    mgr.orbs[0].vy = 0;
    mgr.orbs[1].vy = 0;

    const xp = mgr.update(0.001, 0, 0, 0);
    try std.testing.expectEqual(@as(u32, 25), xp);
    try std.testing.expectEqual(@as(u32, 0), mgr.count);
}

test "magnetic attraction within 5 blocks" {
    var mgr = XpOrbManager.init();
    mgr.spawn(4.0, 0, 0, 1); // 4 blocks away (< 5)
    mgr.orbs[0].vy = 0;

    _ = mgr.update(0.01, 0, 0, 0);
    // Orb should have negative vx (moving toward player at origin)
    try std.testing.expect(mgr.orbs[0].vx < 0);
}

test "no magnetic attraction beyond 5 blocks" {
    var mgr = XpOrbManager.init();
    mgr.spawn(10.0, 0, 0, 1); // 10 blocks away (> 5)
    mgr.orbs[0].vy = 0;

    _ = mgr.update(0.01, 0, 0, 0);
    // vx should remain 0 (default) — no attraction
    try std.testing.expectEqual(@as(f32, 0), mgr.orbs[0].vx);
}

test "despawn after 300 seconds" {
    var mgr = XpOrbManager.init();
    mgr.spawn(0, 0, 0, 1);
    mgr.orbs[0].vy = 0;
    mgr.orbs[0].lifetime = DESPAWN_TIME - 0.01;

    _ = mgr.update(0.02, 999, 999, 999);
    try std.testing.expectEqual(@as(u32, 0), mgr.count); // compacted away
}

test "compact preserves active orbs and removes inactive" {
    var mgr = XpOrbManager.init();
    mgr.spawn(1.0, 0, 0, 5);
    mgr.spawn(2.0, 0, 0, 10);
    mgr.spawn(3.0, 0, 0, 15);

    // Deactivate the middle orb
    mgr.orbs[1].active = false;
    mgr.compact();

    try std.testing.expectEqual(@as(u32, 2), mgr.count);
    try std.testing.expectEqual(@as(f32, 1.0), mgr.orbs[0].x);
    try std.testing.expectEqual(@as(f32, 3.0), mgr.orbs[1].x);
}

test "update returns zero xp when no orbs collected" {
    var mgr = XpOrbManager.init();
    mgr.spawn(100, 100, 100, 50);
    mgr.orbs[0].vy = 0;

    const xp = mgr.update(0.01, 0, 0, 0);
    try std.testing.expectEqual(@as(u32, 0), xp);
    try std.testing.expectEqual(@as(u32, 1), mgr.count);
}

test "lifetime accumulates across updates" {
    var mgr = XpOrbManager.init();
    mgr.spawn(100, 50, 100, 1);

    _ = mgr.update(1.0, 999, 999, 999);
    _ = mgr.update(1.0, 999, 999, 999);
    _ = mgr.update(1.0, 999, 999, 999);

    try std.testing.expectApproxEqAbs(@as(f32, 3.0), mgr.orbs[0].lifetime, 0.001);
}
