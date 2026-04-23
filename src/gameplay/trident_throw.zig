/// Trident throwing, flight simulation, loyalty return, riptide launch, and
/// channeling lightning logic. Handles projectile physics (gravity, velocity),
/// loyalty-based return after a timer, and enchantment-driven special effects.

const std = @import("std");

// ──────────────────────────────────────────────────────────────────────────────
// Constants
// ──────────────────────────────────────────────────────────────────────────────

const throw_speed: f32 = 2.5;
const gravity: f32 = -20.0;
const loyalty_return_delay: f32 = 1.0;
const loyalty_base_speed: f32 = 8.0;
const loyalty_speed_per_level: f32 = 4.0;

// ──────────────────────────────────────────────────────────────────────────────
// Types
// ──────────────────────────────────────────────────────────────────────────────

pub const TridentProjectile = struct {
    x: f32,
    y: f32,
    z: f32,
    vx: f32,
    vy: f32,
    vz: f32,
    active: bool = true,
    loyalty_level: u8 = 0,
    riptide_level: u8 = 0,
    channeling: bool = false,
    return_timer: f32 = 0,
};

pub const UpdateResult = struct {
    returned: bool,
    lightning: bool,
};

// ──────────────────────────────────────────────────────────────────────────────
// Public API
// ──────────────────────────────────────────────────────────────────────────────

/// Launch a trident along the look direction with the configured throw speed.
pub fn throwTrident(
    px: f32,
    py: f32,
    pz: f32,
    lx: f32,
    ly: f32,
    lz: f32,
    loyalty: u8,
    riptide: u8,
    channeling: bool,
) TridentProjectile {
    return .{
        .x = px,
        .y = py,
        .z = pz,
        .vx = lx * throw_speed,
        .vy = ly * throw_speed,
        .vz = lz * throw_speed,
        .loyalty_level = loyalty,
        .riptide_level = riptide,
        .channeling = channeling,
    };
}

/// Advance a trident projectile by `dt` seconds.
///
/// - Applies gravity and integrates position each tick.
/// - When the trident stops (hits ground), the return timer begins.
/// - After `loyalty_return_delay` seconds, loyalty tridents fly back toward the
///   player at a speed that scales with loyalty level.
/// - Channeling tridents trigger lightning on the first stop.
/// - Riptide tridents are not thrown as projectiles; the flag is carried for
///   upstream systems to read.
///
/// Returns `null` while the trident is still in flight. Returns an
/// `UpdateResult` when the trident returns to the player or triggers lightning.
pub fn updateTrident(
    t: *TridentProjectile,
    dt: f32,
    player_x: f32,
    player_y: f32,
    player_z: f32,
) ?UpdateResult {
    if (!t.active) return null;

    // Phase 1: outbound flight — apply gravity and move.
    if (t.return_timer == 0) {
        t.vy += gravity * dt;
        t.x += t.vx * dt;
        t.y += t.vy * dt;
        t.z += t.vz * dt;

        // Ground collision: trident sticks when it falls below y = 0.
        if (t.y <= 0) {
            t.y = 0;
            t.vx = 0;
            t.vy = 0;
            t.vz = 0;

            // Start return sequence (even if loyalty is 0 — timer just runs).
            t.return_timer = std.math.floatMin(f32);

            if (t.channeling) {
                t.channeling = false;
                if (t.loyalty_level > 0) {
                    return .{ .returned = false, .lightning = true };
                }
                // No loyalty: deactivate after lightning.
                t.active = false;
                return .{ .returned = false, .lightning = true };
            }

            // No loyalty means trident stays stuck.
            if (t.loyalty_level == 0) {
                t.active = false;
                return null;
            }
        }
        return null;
    }

    // Phase 2: waiting / returning — trident is stuck, timer counts up.
    t.return_timer += dt;

    if (t.return_timer < loyalty_return_delay) return null;

    // Phase 3: fly back toward the player.
    const dx = player_x - t.x;
    const dy = player_y - t.y;
    const dz = player_z - t.z;
    const dist = @sqrt(dx * dx + dy * dy + dz * dz);

    const arrival_threshold: f32 = 0.5;
    if (dist < arrival_threshold) {
        t.active = false;
        return .{ .returned = true, .lightning = false };
    }

    const speed = loyalty_base_speed + loyalty_speed_per_level * @as(f32, @floatFromInt(t.loyalty_level));
    const step = @min(speed * dt, dist);
    const inv_dist = 1.0 / dist;
    t.vx = dx * inv_dist * speed;
    t.vy = dy * inv_dist * speed;
    t.vz = dz * inv_dist * speed;

    t.x += dx * inv_dist * step;
    t.y += dy * inv_dist * step;
    t.z += dz * inv_dist * step;

    if (step >= dist - arrival_threshold) {
        t.active = false;
        return .{ .returned = true, .lightning = false };
    }

    return null;
}

// ──────────────────────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────────────────────

test "throwTrident sets initial position" {
    const t = throwTrident(1.0, 2.0, 3.0, 0.0, 0.0, 1.0, 0, 0, false);
    try std.testing.expectEqual(@as(f32, 1.0), t.x);
    try std.testing.expectEqual(@as(f32, 2.0), t.y);
    try std.testing.expectEqual(@as(f32, 3.0), t.z);
}

test "throwTrident sets velocity from look direction" {
    const t = throwTrident(0, 0, 0, 1.0, 0.0, 0.0, 0, 0, false);
    try std.testing.expectEqual(@as(f32, throw_speed), t.vx);
    try std.testing.expectEqual(@as(f32, 0.0), t.vy);
    try std.testing.expectEqual(@as(f32, 0.0), t.vz);
}

test "throwTrident stores enchantment fields" {
    const t = throwTrident(0, 0, 0, 0, 1.0, 0, 3, 2, true);
    try std.testing.expectEqual(@as(u8, 3), t.loyalty_level);
    try std.testing.expectEqual(@as(u8, 2), t.riptide_level);
    try std.testing.expect(t.channeling);
    try std.testing.expect(t.active);
}

test "trident falls under gravity" {
    var t = throwTrident(0, 10.0, 0, 1.0, 0.0, 0.0, 0, 0, false);
    _ = updateTrident(&t, 0.1, 0, 0, 0);
    try std.testing.expect(t.vy < 0.0);
    try std.testing.expect(t.x > 0.0);
}

test "trident without loyalty deactivates on ground hit" {
    var t = throwTrident(0, 0.5, 0, 1.0, -1.0, 0.0, 0, 0, false);
    // Simulate until ground hit
    var i: u32 = 0;
    while (t.active and i < 1000) : (i += 1) {
        _ = updateTrident(&t, 0.016, 0, 0, 0);
    }
    try std.testing.expect(!t.active);
}

test "trident with loyalty returns after delay" {
    var t = throwTrident(0, 0.5, 0, 1.0, -1.0, 0.0, 3, 0, false);
    const px: f32 = 0.0;
    const py: f32 = 0.0;
    const pz: f32 = 0.0;

    // Fly until ground hit
    var result: ?UpdateResult = null;
    var i: u32 = 0;
    while (t.active and i < 5000) : (i += 1) {
        result = updateTrident(&t, 0.016, px, py, pz);
        if (result) |r| {
            if (r.returned) break;
        }
    }
    // Should eventually return
    try std.testing.expect(result != null);
    try std.testing.expect(result.?.returned);
    try std.testing.expect(!t.active);
}

test "loyalty return does not happen before 1 second" {
    var t = throwTrident(0, 0.1, 0, 0.0, -1.0, 0.0, 3, 0, false);
    // Hit ground quickly
    _ = updateTrident(&t, 0.5, 0, 0, 0);
    // return_timer should have started but not yet reached delay
    // Step just under 1 second more
    const result = updateTrident(&t, 0.4, 0, 0, 0);
    // Should still be null (waiting)
    try std.testing.expect(result == null);
    try std.testing.expect(t.active);
}

test "channeling triggers lightning on ground hit" {
    var t = throwTrident(0, 0.1, 0, 0.0, -1.0, 0.0, 3, 0, true);
    const result = updateTrident(&t, 0.5, 0, 0, 0);
    try std.testing.expect(result != null);
    try std.testing.expect(result.?.lightning);
    try std.testing.expect(!result.?.returned);
}

test "channeling without loyalty deactivates after lightning" {
    var t = throwTrident(0, 0.1, 0, 0.0, -1.0, 0.0, 0, 0, true);
    const result = updateTrident(&t, 0.5, 0, 0, 0);
    try std.testing.expect(result != null);
    try std.testing.expect(result.?.lightning);
    try std.testing.expect(!t.active);
}

test "riptide level is stored for upstream systems" {
    const t = throwTrident(0, 0, 0, 0, 0, 1.0, 0, 3, false);
    try std.testing.expectEqual(@as(u8, 3), t.riptide_level);
}

test "inactive trident returns null on update" {
    var t = throwTrident(0, 0, 0, 1.0, 0, 0, 0, 0, false);
    t.active = false;
    const result = updateTrident(&t, 0.1, 0, 0, 0);
    try std.testing.expect(result == null);
}

test "trident position integrates correctly over time" {
    var t = throwTrident(0, 100.0, 0, 0.0, 0.0, 1.0, 0, 0, false);
    _ = updateTrident(&t, 1.0, 0, 0, 0);
    try std.testing.expectApproxEqAbs(throw_speed, t.z, 0.01);
    try std.testing.expect(t.y < 100.0);
}

test "loyalty speed scales with enchantment level" {
    // Level 1 vs level 3 at a large distance so neither arrives in one step.
    var t1 = throwTrident(100.0, 0.1, 0, 0.0, -1.0, 0.0, 1, 0, false);
    var t3 = throwTrident(100.0, 0.1, 0, 0.0, -1.0, 0.0, 3, 0, false);

    // Hit ground
    _ = updateTrident(&t1, 0.5, 0, 0, 0);
    _ = updateTrident(&t3, 0.5, 0, 0, 0);

    // Wait past delay, then take a small return step
    _ = updateTrident(&t1, 1.5, 0, 0, 0);
    _ = updateTrident(&t3, 1.5, 0, 0, 0);

    const d1 = @sqrt(t1.x * t1.x + t1.y * t1.y + t1.z * t1.z);
    const d3 = @sqrt(t3.x * t3.x + t3.y * t3.y + t3.z * t3.z);
    try std.testing.expect(d3 < d1);
}
