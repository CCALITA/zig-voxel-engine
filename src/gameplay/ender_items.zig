/// Ender item systems: Ender Pearl teleportation, Eye of Ender stronghold
/// locating, and End Portal frame completion detection.

const std = @import("std");

// ──────────────────────────────────────────────────────────────────────────────
// Constants
// ──────────────────────────────────────────────────────────────────────────────

const pearl_speed: f32 = 20.0;
const pearl_gravity: f32 = -20.0;
const pearl_damage: f32 = 5.0;
const pearl_lifetime: f32 = 5.0;

const eye_rise_speed: f32 = 4.0;
const eye_horizontal_speed: f32 = 8.0;
const eye_rise_duration: f32 = 1.5;
const eye_lifetime: f32 = 3.0;
const eye_break_chance: f32 = 0.2;

/// Block id for an End Portal Frame with an Eye of Ender inserted.
const END_PORTAL_FRAME_WITH_EYE: u8 = 120;

// ──────────────────────────────────────────────────────────────────────────────
// Ender Pearl
// ──────────────────────────────────────────────────────────────────────────────

pub const Projectile = struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,
    vx: f32 = 0.0,
    vy: f32 = 0.0,
    vz: f32 = 0.0,
    active: bool = false,
    lifetime: f32 = pearl_lifetime,
};

pub const TeleportResult = struct {
    x: f32,
    y: f32,
    z: f32,
    damage: f32,
};

/// Launch an ender pearl from `origin` in `dir` (unit vector) at `speed`.
pub fn throwPearl(
    origin_x: f32,
    origin_y: f32,
    origin_z: f32,
    dir_x: f32,
    dir_y: f32,
    dir_z: f32,
    speed: f32,
) Projectile {
    return .{
        .x = origin_x,
        .y = origin_y,
        .z = origin_z,
        .vx = dir_x * speed,
        .vy = dir_y * speed,
        .vz = dir_z * speed,
        .active = true,
        .lifetime = pearl_lifetime,
    };
}

/// Advance a pearl by `dt` seconds. Returns a TeleportResult when the pearl
/// hits the ground (y <= 0) or its lifetime expires; null otherwise.
pub fn updatePearl(p: *Projectile, dt: f32) ?TeleportResult {
    if (!p.active) return null;

    p.vy += pearl_gravity * dt;
    p.x += p.vx * dt;
    p.y += p.vy * dt;
    p.z += p.vz * dt;
    p.lifetime -= dt;

    if (p.y <= 0.0 or p.lifetime <= 0.0) {
        p.active = false;
        return .{
            .x = p.x,
            .y = @max(p.y, 0.0),
            .z = p.z,
            .damage = pearl_damage,
        };
    }

    return null;
}

// ──────────────────────────────────────────────────────────────────────────────
// Eye of Ender
// ──────────────────────────────────────────────────────────────────────────────

pub const EyeProjectile = struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,
    vx: f32 = 0.0,
    vy: f32 = 0.0,
    vz: f32 = 0.0,
    active: bool = false,
    lifetime: f32 = eye_lifetime,
    rising: bool = true,
    rise_timer: f32 = eye_rise_duration,
};

pub const EyeLandingResult = struct {
    x: f32,
    y: f32,
    z: f32,
    survived: bool,
};

/// Throw an Eye of Ender from `origin` toward the stronghold at (target_x, target_z).
/// The eye rises, then drops; it floats horizontally toward the target.
pub fn throwEye(
    origin_x: f32,
    origin_y: f32,
    origin_z: f32,
    target_x: f32,
    target_z: f32,
) EyeProjectile {
    const dx = target_x - origin_x;
    const dz = target_z - origin_z;
    const dist = @sqrt(dx * dx + dz * dz);

    var nx: f32 = 0.0;
    var nz: f32 = 0.0;
    if (dist > 0.0) {
        nx = dx / dist;
        nz = dz / dist;
    }

    return .{
        .x = origin_x,
        .y = origin_y,
        .z = origin_z,
        .vx = nx * eye_horizontal_speed,
        .vy = eye_rise_speed,
        .vz = nz * eye_horizontal_speed,
        .active = true,
        .lifetime = eye_lifetime,
        .rising = true,
        .rise_timer = eye_rise_duration,
    };
}

/// Advance an Eye of Ender by `dt` seconds. Uses `rand` (0.0..1.0) to
/// determine whether the eye breaks on landing. Returns a landing result
/// when the eye finishes its arc; null while still in flight.
pub fn updateEye(eye: *EyeProjectile, dt: f32, rand: f32) ?EyeLandingResult {
    if (!eye.active) return null;

    if (eye.rising) {
        eye.rise_timer -= dt;
        if (eye.rise_timer <= 0.0) {
            eye.rising = false;
            eye.vy = -eye_rise_speed;
        }
    }

    eye.x += eye.vx * dt;
    eye.y += eye.vy * dt;
    eye.z += eye.vz * dt;
    eye.lifetime -= dt;

    if (eye.y <= 0.0 or eye.lifetime <= 0.0) {
        eye.active = false;
        const survived = rand >= eye_break_chance;
        return .{
            .x = eye.x,
            .y = @max(eye.y, 0.0),
            .z = eye.z,
            .survived = survived,
        };
    }

    return null;
}

// ──────────────────────────────────────────────────────────────────────────────
// End Portal
// ──────────────────────────────────────────────────────────────────────────────

pub const Facing = enum { north, south, east, west };

pub const FrameOffset = struct {
    dx: i32,
    dz: i32,
    facing: Facing,
};

/// The 12 End Portal Frame positions arranged in a 5x5 ring (3 per side),
/// relative to the portal centre.
pub const PORTAL_FRAME_POSITIONS: [12]FrameOffset = .{
    // North side (z = -2): facing south
    .{ .dx = -1, .dz = -2, .facing = .south },
    .{ .dx = 0, .dz = -2, .facing = .south },
    .{ .dx = 1, .dz = -2, .facing = .south },
    // South side (z = 2): facing north
    .{ .dx = -1, .dz = 2, .facing = .north },
    .{ .dx = 0, .dz = 2, .facing = .north },
    .{ .dx = 1, .dz = 2, .facing = .north },
    // East side (x = 2): facing west
    .{ .dx = 2, .dz = -1, .facing = .west },
    .{ .dx = 2, .dz = 0, .facing = .west },
    .{ .dx = 2, .dz = 1, .facing = .west },
    // West side (x = -2): facing east
    .{ .dx = -2, .dz = -1, .facing = .east },
    .{ .dx = -2, .dz = 0, .facing = .east },
    .{ .dx = -2, .dz = 1, .facing = .east },
};

pub const EndPortalFrame = struct {
    center_x: i32,
    center_y: i32,
    center_z: i32,

    pub fn init(x: i32, y: i32, z: i32) EndPortalFrame {
        return .{ .center_x = x, .center_y = y, .center_z = z };
    }

    pub fn getPortalCenter(self: *const EndPortalFrame) struct { x: i32, z: i32 } {
        return .{ .x = self.center_x, .z = self.center_z };
    }

    /// Check whether all 12 frames contain an Eye of Ender.
    /// `getBlock` reads the block id at a given world position.
    pub fn checkComplete(self: *const EndPortalFrame, getBlock: *const fn (i32, i32, i32) u8) bool {
        for (PORTAL_FRAME_POSITIONS) |offset| {
            const wx = self.center_x + offset.dx;
            const wz = self.center_z + offset.dz;
            if (getBlock(wx, self.center_y, wz) != END_PORTAL_FRAME_WITH_EYE) {
                return false;
            }
        }
        return true;
    }
};

// ──────────────────────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────────────────────

test "pearl teleport position after landing" {
    var p = throwPearl(0, 10.0, 0, 1.0, 0.0, 0.0, pearl_speed);
    try std.testing.expect(p.active);

    // Tick until the pearl lands (y <= 0)
    var result: ?TeleportResult = null;
    var ticks: u32 = 0;
    while (ticks < 1000) : (ticks += 1) {
        result = updatePearl(&p, 0.05);
        if (result != null) break;
    }

    try std.testing.expect(result != null);
    const r = result.?;
    // Pearl moved forward on the x-axis
    try std.testing.expect(r.x > 0.0);
    // Landed at ground level
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), r.y, 0.5);
    // Deals 5 fall damage
    try std.testing.expectEqual(pearl_damage, r.damage);
    try std.testing.expect(!p.active);
}

test "pearl stationary drop lands at origin" {
    var p = throwPearl(5.0, 2.0, 3.0, 0.0, 0.0, 0.0, 0.0);

    var result: ?TeleportResult = null;
    var ticks: u32 = 0;
    while (ticks < 1000) : (ticks += 1) {
        result = updatePearl(&p, 0.05);
        if (result != null) break;
    }

    try std.testing.expect(result != null);
    const r = result.?;
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), r.x, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), r.z, 0.01);
}

test "eye direction toward stronghold" {
    const eye = throwEye(0.0, 64.0, 0.0, 100.0, 0.0);

    // Should move toward positive x
    try std.testing.expect(eye.vx > 0.0);
    // Z component should be negligible (target is along x-axis)
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), eye.vz, 0.01);
    // Initially rising
    try std.testing.expect(eye.vy > 0.0);
    try std.testing.expect(eye.rising);
}

test "eye direction diagonal" {
    const eye = throwEye(0.0, 64.0, 0.0, 100.0, 100.0);

    // Both components should be positive and roughly equal
    try std.testing.expect(eye.vx > 0.0);
    try std.testing.expect(eye.vz > 0.0);
    try std.testing.expectApproxEqAbs(eye.vx, eye.vz, 0.01);
}

test "eye break chance statistics" {
    // Run many trials: eye should break ~20% of the time.
    // We simulate by passing controlled random values.
    var broken: u32 = 0;
    var survived: u32 = 0;
    const trials: u32 = 1000;

    for (0..trials) |i| {
        // Generate a deterministic pseudo-random value in 0..1
        const rand_val: f32 = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(trials));

        var eye = throwEye(0.0, 1.0, 0.0, 100.0, 0.0);
        // Force immediate landing
        eye.lifetime = 0.0;

        const result = updateEye(&eye, 0.01, rand_val);
        try std.testing.expect(result != null);

        if (result.?.survived) {
            survived += 1;
        } else {
            broken += 1;
        }
    }

    // Break chance is 20%, so ~200 should break out of 1000.
    // With deterministic input: values < 0.2 break, values >= 0.2 survive.
    // Indices 0..199 -> rand < 0.2 -> broken = 200
    // Indices 200..999 -> rand >= 0.2 -> survived = 800
    try std.testing.expectEqual(@as(u32, 200), broken);
    try std.testing.expectEqual(@as(u32, 800), survived);
}

test "eye rises then falls" {
    var eye = throwEye(0.0, 5.0, 0.0, 100.0, 0.0);
    const initial_vy = eye.vy;
    try std.testing.expect(initial_vy > 0.0);

    // Tick past the rise duration
    var ticks: u32 = 0;
    while (eye.rising and ticks < 1000) : (ticks += 1) {
        _ = updateEye(&eye, 0.05, 1.0);
    }

    // After rising phase, vy should be negative (falling)
    try std.testing.expect(eye.vy < 0.0);
}

// --- Portal frame helpers for tests ------------------------------------------

const TestPortalMap = struct {
    const SIZE = 16;
    const OFFSET = 8;
    data: [SIZE][SIZE]u8,

    fn init() TestPortalMap {
        return .{ .data = [_][SIZE]u8{[_]u8{0} ** SIZE} ** SIZE };
    }

    fn set(self: *TestPortalMap, x: i32, z: i32, id: u8) void {
        const ux: usize = @intCast(x + OFFSET);
        const uz: usize = @intCast(z + OFFSET);
        self.data[ux][uz] = id;
    }

    fn get(self: *const TestPortalMap, x: i32, z: i32) u8 {
        const ux: usize = @intCast(x + OFFSET);
        const uz: usize = @intCast(z + OFFSET);
        return self.data[ux][uz];
    }
};

var test_portal_map: TestPortalMap = undefined;

fn testGetBlock(x: i32, _: i32, z: i32) u8 {
    return test_portal_map.get(x, z);
}

test "portal frame detection - complete" {
    test_portal_map = TestPortalMap.init();
    const frame = EndPortalFrame.init(0, 0, 0);

    // Place eyes in all 12 positions
    for (PORTAL_FRAME_POSITIONS) |offset| {
        test_portal_map.set(offset.dx, offset.dz, END_PORTAL_FRAME_WITH_EYE);
    }

    try std.testing.expect(frame.checkComplete(&testGetBlock));
}

test "portal frame detection - incomplete" {
    test_portal_map = TestPortalMap.init();
    const frame = EndPortalFrame.init(0, 0, 0);

    // Place eyes in only 11 of 12 positions
    for (PORTAL_FRAME_POSITIONS[0..11]) |offset| {
        test_portal_map.set(offset.dx, offset.dz, END_PORTAL_FRAME_WITH_EYE);
    }

    try std.testing.expect(!frame.checkComplete(&testGetBlock));
}

test "portal frame detection - empty" {
    test_portal_map = TestPortalMap.init();
    const frame = EndPortalFrame.init(0, 0, 0);

    try std.testing.expect(!frame.checkComplete(&testGetBlock));
}

test "portal center returns configured coordinates" {
    const frame = EndPortalFrame.init(100, 40, -200);
    const center = frame.getPortalCenter();
    try std.testing.expectEqual(@as(i32, 100), center.x);
    try std.testing.expectEqual(@as(i32, -200), center.z);
}

test "portal frame positions has 12 entries with 3 per side" {
    var north: u32 = 0;
    var south: u32 = 0;
    var east: u32 = 0;
    var west: u32 = 0;

    for (PORTAL_FRAME_POSITIONS) |offset| {
        switch (offset.facing) {
            .south => north += 1,
            .north => south += 1,
            .west => east += 1,
            .east => west += 1,
        }
    }

    try std.testing.expectEqual(@as(u32, 3), north);
    try std.testing.expectEqual(@as(u32, 3), south);
    try std.testing.expectEqual(@as(u32, 3), east);
    try std.testing.expectEqual(@as(u32, 3), west);
}
