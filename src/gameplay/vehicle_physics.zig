const std = @import("std");
const math = std.math;

pub const VehicleType = enum { minecart, boat };

pub const Vehicle = struct {
    vtype: VehicleType,
    x: f32,
    y: f32,
    z: f32,
    vx: f32,
    vy: f32,
    vz: f32,
    yaw: f32 = 0,
    rider: bool = false,
    on_rail: bool = false,
    on_water: bool = false,
    on_ice: bool = false,
};

// -- Physics constants --------------------------------------------------------

const gravity: f32 = -9.8;
const minecart_friction: f32 = 0.98;
const minecart_base_speed: f32 = 8.0;
const minecart_powered_boost: f32 = 4.0;
const minecart_slope_accel: f32 = 5.0;

const boat_base_speed: f32 = 4.0;
const boat_turn_rate: f32 = 2.0;
const boat_water_drag: f32 = 0.90;
const boat_land_drag: f32 = 0.50;
const boat_ice_multiplier: f32 = 5.0;

// -- Helpers ------------------------------------------------------------------

/// Rail direction unit vector.  Encoding: 0 = +X, 1 = -X, 2 = +Z, 3 = -Z.
fn railDir(dir: u2) struct { x: f32, z: f32 } {
    return switch (dir) {
        0 => .{ .x = 1.0, .z = 0.0 },
        1 => .{ .x = -1.0, .z = 0.0 },
        2 => .{ .x = 0.0, .z = 1.0 },
        3 => .{ .x = 0.0, .z = -1.0 },
    };
}

fn integrate(v: *Vehicle, dt: f32) void {
    v.x += v.vx * dt;
    v.y += v.vy * dt;
    v.z += v.vz * dt;
}

// -- Minecart update ----------------------------------------------------------

pub fn updateMinecart(v: *Vehicle, dt: f32, rail_dir: ?u2, powered: bool) void {
    if (rail_dir) |dir| {
        v.on_rail = true;
        const rd = railDir(dir);

        // Project velocity onto rail axis
        var speed = v.vx * rd.x + v.vz * rd.z;

        if (powered) {
            speed += minecart_powered_boost * dt;
        }

        const max = if (powered) minecart_base_speed + minecart_powered_boost else minecart_base_speed;
        speed = math.clamp(speed, -max, max);
        speed *= minecart_friction;

        // Slope boost when above y=0 (downhill acceleration)
        if (v.y > 0) {
            speed += minecart_slope_accel * dt;
        }

        v.vx = rd.x * speed;
        v.vz = rd.z * speed;
        v.vy = 0;
    } else {
        v.on_rail = false;
        v.vy += gravity * dt;
        v.vx *= 0.5;
        v.vz *= 0.5;
    }

    integrate(v, dt);
}

// -- Boat update --------------------------------------------------------------

pub fn updateBoat(v: *Vehicle, dt: f32, forward: f32, turn: f32) void {
    v.yaw += turn * boat_turn_rate * dt;

    const speed_mult: f32 = if (v.on_ice) boat_ice_multiplier else 1.0;
    const accel = forward * boat_base_speed * speed_mult;

    v.vx += @sin(v.yaw) * accel * dt;
    v.vz += @cos(v.yaw) * accel * dt;

    const drag: f32 = if (v.on_water or v.on_ice) boat_water_drag else boat_land_drag;
    v.vx *= drag;
    v.vz *= drag;

    if (v.on_water or v.on_ice) {
        v.vy = 0;
    } else {
        v.vy += gravity * dt;
    }

    integrate(v, dt);
}

// -- Mount / Dismount ---------------------------------------------------------

pub fn mount(v: *Vehicle) void {
    v.rider = true;
}

pub fn dismount(v: *Vehicle) void {
    v.rider = false;
    v.vx = 0;
    v.vy = 0;
    v.vz = 0;
}

// =============================================================================
// Tests
// =============================================================================

test "minecart follows rail in +X direction" {
    var v = Vehicle{ .vtype = .minecart, .x = 0, .y = 0, .z = 0, .vx = 4, .vy = 0, .vz = 0 };
    updateMinecart(&v, 0.1, 0, false);

    try std.testing.expect(v.on_rail);
    try std.testing.expect(v.x > 0);
    try std.testing.expectApproxEqAbs(@as(f32, 0), v.vz, 0.001);
}

test "minecart follows rail in +Z direction" {
    var v = Vehicle{ .vtype = .minecart, .x = 0, .y = 0, .z = 0, .vx = 0, .vy = 0, .vz = 5 };
    updateMinecart(&v, 0.1, 2, false);

    try std.testing.expect(v.z > 0);
    try std.testing.expectApproxEqAbs(@as(f32, 0), v.vx, 0.001);
}

test "powered rail boosts minecart speed" {
    var normal = Vehicle{ .vtype = .minecart, .x = 0, .y = 0, .z = 0, .vx = 2, .vy = 0, .vz = 0 };
    var boosted = Vehicle{ .vtype = .minecart, .x = 0, .y = 0, .z = 0, .vx = 2, .vy = 0, .vz = 0 };

    updateMinecart(&normal, 0.1, 0, false);
    updateMinecart(&boosted, 0.1, 0, true);

    try std.testing.expect(boosted.vx > normal.vx);
}

test "minecart applies gravity off-rail" {
    var v = Vehicle{ .vtype = .minecart, .x = 0, .y = 10, .z = 0, .vx = 0, .vy = 0, .vz = 0 };
    updateMinecart(&v, 0.1, null, false);

    try std.testing.expect(!v.on_rail);
    try std.testing.expect(v.vy < 0);
    try std.testing.expect(v.y < 10);
}

test "minecart friction slows down" {
    var v = Vehicle{ .vtype = .minecart, .x = 0, .y = 0, .z = 0, .vx = 5, .vy = 0, .vz = 0 };
    const initial_vx = v.vx;
    updateMinecart(&v, 0.1, 0, false);

    // After friction the along-rail speed component should be less
    try std.testing.expect(@abs(v.vx) < @abs(initial_vx));
}

test "boat turns with turn input" {
    var v = Vehicle{ .vtype = .boat, .x = 0, .y = 0, .z = 0, .vx = 0, .vy = 0, .vz = 0, .on_water = true };
    const initial_yaw = v.yaw;
    updateBoat(&v, 0.1, 0, 1.0);

    try std.testing.expect(v.yaw > initial_yaw);
}

test "boat accelerates forward on water" {
    var v = Vehicle{ .vtype = .boat, .x = 0, .y = 0, .z = 0, .vx = 0, .vy = 0, .vz = 0, .yaw = 0, .on_water = true };
    updateBoat(&v, 0.1, 1.0, 0);

    // yaw=0 => thrust along +Z
    try std.testing.expect(v.vz > 0);
}

test "boat floats on water — no gravity" {
    var v = Vehicle{ .vtype = .boat, .x = 0, .y = 5, .z = 0, .vx = 0, .vy = 0, .vz = 0, .on_water = true };
    updateBoat(&v, 0.5, 0, 0);

    try std.testing.expectApproxEqAbs(@as(f32, 0), v.vy, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 5), v.y, 0.001);
}

test "boat sinks on land — gravity applies" {
    var v = Vehicle{ .vtype = .boat, .x = 0, .y = 5, .z = 0, .vx = 0, .vy = 0, .vz = 0 };
    updateBoat(&v, 0.1, 0, 0);

    try std.testing.expect(v.vy < 0);
    try std.testing.expect(v.y < 5);
}

test "ice boat is 5x faster than water boat" {
    var water = Vehicle{ .vtype = .boat, .x = 0, .y = 0, .z = 0, .vx = 0, .vy = 0, .vz = 0, .yaw = 0, .on_water = true };
    var ice = Vehicle{ .vtype = .boat, .x = 0, .y = 0, .z = 0, .vx = 0, .vy = 0, .vz = 0, .yaw = 0, .on_water = true, .on_ice = true };

    updateBoat(&water, 0.1, 1.0, 0);
    updateBoat(&ice, 0.1, 1.0, 0);

    // Ice velocity should be ~5x the water velocity (same drag)
    const ratio = ice.vz / water.vz;
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), ratio, 0.01);
}

test "mount sets rider flag" {
    var v = Vehicle{ .vtype = .minecart, .x = 0, .y = 0, .z = 0, .vx = 0, .vy = 0, .vz = 0 };
    try std.testing.expect(!v.rider);

    mount(&v);
    try std.testing.expect(v.rider);
}

test "dismount clears rider and stops velocity" {
    var v = Vehicle{ .vtype = .boat, .x = 0, .y = 0, .z = 0, .vx = 3, .vy = 1, .vz = 2, .rider = true };
    dismount(&v);

    try std.testing.expect(!v.rider);
    try std.testing.expectApproxEqAbs(@as(f32, 0), v.vx, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), v.vy, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), v.vz, 0.001);
}

test "mount then dismount round-trips correctly" {
    var v = Vehicle{ .vtype = .minecart, .x = 5, .y = 10, .z = 15, .vx = 1, .vy = 2, .vz = 3 };
    mount(&v);
    try std.testing.expect(v.rider);
    // Position unchanged by mount
    try std.testing.expectApproxEqAbs(@as(f32, 5), v.x, 0.001);

    dismount(&v);
    try std.testing.expect(!v.rider);
    // Position still unchanged, velocity zeroed
    try std.testing.expectApproxEqAbs(@as(f32, 5), v.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), v.vx, 0.001);
}

test "boat land drag is heavier than water drag" {
    var water = Vehicle{ .vtype = .boat, .x = 0, .y = 0, .z = 0, .vx = 0, .vy = 0, .vz = 5, .on_water = true };
    var land = Vehicle{ .vtype = .boat, .x = 0, .y = 0, .z = 0, .vx = 0, .vy = 0, .vz = 5 };

    updateBoat(&water, 0.1, 0, 0);
    updateBoat(&land, 0.1, 0, 0);

    // Water retains more speed than land
    try std.testing.expect(water.vz > land.vz);
}

test "minecart speed clamped to max" {
    var v = Vehicle{ .vtype = .minecart, .x = 0, .y = 0, .z = 0, .vx = 20, .vy = 0, .vz = 0 };
    updateMinecart(&v, 0.1, 0, false);

    try std.testing.expect(@abs(v.vx) <= minecart_base_speed + 0.01);
}
