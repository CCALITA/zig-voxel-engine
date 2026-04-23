/// Ender Pearl throwing, flight simulation, and teleport-on-landing logic.
/// Handles projectile physics (gravity, velocity), ground collision via a
/// caller-supplied solidity check, and the 5 % endermite spawn chance.

const std = @import("std");

// ──────────────────────────────────────────────────────────────────────────────
// Constants
// ──────────────────────────────────────────────────────────────────────────────

pub const ENDER_PEARL: u16 = 319;

pub const TELEPORT_DAMAGE: f32 = 5.0;

const launch_speed: f32 = 1.5;
const gravity: f32 = -20.0;
const upward_arc: f32 = 0.4;
const endermite_chance: f32 = 0.05;

// ──────────────────────────────────────────────────────────────────────────────
// Projectile
// ──────────────────────────────────────────────────────────────────────────────

pub const PearlProjectile = struct {
    x: f32,
    y: f32,
    z: f32,
    vx: f32,
    vy: f32,
    vz: f32,
    active: bool = true,
    cooldown: f32 = 0,
};

pub const LandingResult = struct {
    x: f32,
    y: f32,
    z: f32,
    spawn_endermite: bool,
};

// ──────────────────────────────────────────────────────────────────────────────
// Public API
// ──────────────────────────────────────────────────────────────────────────────

/// Launch an ender pearl at `launch_speed` along the look direction with an
/// upward arc bias so the pearl follows a realistic parabolic trajectory.
pub fn throwPearl(
    px: f32,
    py: f32,
    pz: f32,
    look_x: f32,
    look_y: f32,
    look_z: f32,
) PearlProjectile {
    return .{
        .x = px,
        .y = py,
        .z = pz,
        .vx = look_x * launch_speed,
        .vy = look_y * launch_speed + upward_arc,
        .vz = look_z * launch_speed,
    };
}

/// Apply gravity and integrate position for one tick of `dt` seconds.
pub fn updatePearl(p: *PearlProjectile, dt: f32) void {
    if (!p.active) return;

    p.vy += gravity * dt;
    p.x += p.vx * dt;
    p.y += p.vy * dt;
    p.z += p.vz * dt;

    if (p.cooldown > 0) {
        p.cooldown = @max(p.cooldown - dt, 0);
    }
}

/// Check whether the pearl has hit a solid block.  Uses a deterministic
/// position-based hash for the 5 % endermite roll so the result is
/// reproducible for any given landing spot.
pub fn checkLanding(
    p: PearlProjectile,
    is_solid: *const fn (i32, i32, i32) bool,
) ?LandingResult {
    if (!p.active) return null;

    const bx = floatToBlock(p.x);
    const by = floatToBlock(p.y);
    const bz = floatToBlock(p.z);

    if (is_solid(bx, by, bz)) {
        // Use a simple deterministic hash of position for the endermite roll
        // so the result is reproducible for any given landing spot.
        const hash = positionHash(p.x, p.y, p.z);
        const spawn = hash < endermite_chance;

        return .{
            .x = p.x,
            .y = p.y,
            .z = p.z,
            .spawn_endermite = spawn,
        };
    }

    return null;
}

// ──────────────────────────────────────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────────────────────────────────────

fn floatToBlock(v: f32) i32 {
    return @intFromFloat(@floor(v));
}

/// Produce a pseudo-random f32 in [0, 1) from three float coordinates.
fn positionHash(x: f32, y: f32, z: f32) f32 {
    const ix: u32 = @bitCast(x);
    const iy: u32 = @bitCast(y);
    const iz: u32 = @bitCast(z);
    const combined = ix *% 374761393 +% iy *% 668265263 +% iz *% 2147483647;
    return @as(f32, @floatFromInt(combined % 10000)) / 10000.0;
}

// ──────────────────────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────────────────────

fn solidGround(_: i32, y: i32, _: i32) bool {
    return y < 0;
}

fn neverSolid(_: i32, _: i32, _: i32) bool {
    return false;
}

fn alwaysSolid(_: i32, _: i32, _: i32) bool {
    return true;
}

test "ENDER_PEARL item id is 319" {
    try std.testing.expectEqual(@as(u16, 319), ENDER_PEARL);
}

test "TELEPORT_DAMAGE is 5" {
    try std.testing.expectEqual(@as(f32, 5.0), TELEPORT_DAMAGE);
}

test "throwPearl sets initial position" {
    const p = throwPearl(1.0, 2.0, 3.0, 0.0, 1.0, 0.0);
    try std.testing.expectEqual(@as(f32, 1.0), p.x);
    try std.testing.expectEqual(@as(f32, 2.0), p.y);
    try std.testing.expectEqual(@as(f32, 3.0), p.z);
    try std.testing.expect(p.active);
}

test "throwPearl velocity follows look direction at launch_speed" {
    const p = throwPearl(0, 0, 0, 1.0, 0.0, 0.0);
    try std.testing.expectApproxEqAbs(launch_speed, p.vx, 0.001);
    try std.testing.expectApproxEqAbs(upward_arc, p.vy, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), p.vz, 0.001);
}

test "throwPearl adds upward arc to vy" {
    const p = throwPearl(0, 0, 0, 0.0, 0.0, 1.0);
    // vy should include the upward arc even when looking horizontally
    try std.testing.expect(p.vy > 0.0);
    try std.testing.expectApproxEqAbs(upward_arc, p.vy, 0.001);
}

test "updatePearl applies gravity" {
    var p = throwPearl(0, 10.0, 0, 1.0, 0.0, 0.0);
    const initial_vy = p.vy;
    updatePearl(&p, 1.0);
    // vy should decrease by gravity * dt
    try std.testing.expectApproxEqAbs(initial_vy + gravity, p.vy, 0.001);
}

test "updatePearl integrates position" {
    var p = throwPearl(0, 10.0, 0, 1.0, 0.0, 0.0);
    const expected_x = p.vx * 0.5;
    const initial_vy = p.vy;
    const expected_y = 10.0 + (initial_vy + gravity * 0.5) * 0.5;
    updatePearl(&p, 0.5);
    try std.testing.expectApproxEqAbs(expected_x, p.x, 0.001);
    try std.testing.expectApproxEqAbs(expected_y, p.y, 0.01);
}

test "updatePearl skips inactive pearl" {
    var p = throwPearl(0, 10.0, 0, 1.0, 0.0, 0.0);
    p.active = false;
    updatePearl(&p, 1.0);
    // Position should remain unchanged
    try std.testing.expectEqual(@as(f32, 0.0), p.x);
    try std.testing.expectEqual(@as(f32, 10.0), p.y);
}

test "updatePearl decrements cooldown" {
    var p = throwPearl(0, 10.0, 0, 1.0, 0.0, 0.0);
    p.cooldown = 2.0;
    updatePearl(&p, 0.5);
    try std.testing.expectApproxEqAbs(@as(f32, 1.5), p.cooldown, 0.001);
}

test "updatePearl cooldown does not go negative" {
    var p = throwPearl(0, 10.0, 0, 1.0, 0.0, 0.0);
    p.cooldown = 0.1;
    updatePearl(&p, 1.0);
    try std.testing.expectEqual(@as(f32, 0.0), p.cooldown);
}

test "checkLanding returns null when not in solid block" {
    const p = throwPearl(5.0, 10.0, 5.0, 0.0, 0.0, 1.0);
    const result = checkLanding(p, &neverSolid);
    try std.testing.expect(result == null);
}

test "checkLanding returns landing result when hitting solid" {
    const p = throwPearl(3.0, 5.0, 7.0, 1.0, 0.0, 0.0);
    const result = checkLanding(p, &alwaysSolid);
    try std.testing.expect(result != null);
    const r = result.?;
    try std.testing.expectEqual(@as(f32, 3.0), r.x);
    try std.testing.expectEqual(@as(f32, 5.0), r.y);
    try std.testing.expectEqual(@as(f32, 7.0), r.z);
}

test "checkLanding returns null for inactive pearl" {
    var p = throwPearl(0, 0, 0, 1.0, 0.0, 0.0);
    p.active = false;
    const result = checkLanding(p, &alwaysSolid);
    try std.testing.expect(result == null);
}

test "checkLanding landing coordinates match pearl position" {
    const p = throwPearl(3.0, 5.0, 7.0, 1.0, 0.0, 0.0);
    const result = checkLanding(p, &alwaysSolid);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(p.x, result.?.x);
    try std.testing.expectEqual(p.y, result.?.y);
    try std.testing.expectEqual(p.z, result.?.z);
}

test "pearl falls to ground with gravity simulation" {
    var p = throwPearl(0, 20.0, 0, 1.0, 0.0, 0.0);
    var landed = false;
    var ticks: u32 = 0;
    while (ticks < 2000) : (ticks += 1) {
        updatePearl(&p, 0.01);
        const result = checkLanding(p, &solidGround);
        if (result != null) {
            landed = true;
            // Pearl moved forward on x-axis
            try std.testing.expect(result.?.x > 0.0);
            break;
        }
    }
    try std.testing.expect(landed);
}

test "floatToBlock converts correctly" {
    try std.testing.expectEqual(@as(i32, 3), floatToBlock(3.7));
    try std.testing.expectEqual(@as(i32, -1), floatToBlock(-0.1));
    try std.testing.expectEqual(@as(i32, 0), floatToBlock(0.0));
    try std.testing.expectEqual(@as(i32, -2), floatToBlock(-1.5));
}
