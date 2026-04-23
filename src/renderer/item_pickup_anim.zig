const std = @import("std");

// ---------------------------------------------------------------------------
// Data types
// ---------------------------------------------------------------------------

/// Animation state for an item being picked up by a player.
/// The item travels from its world position to the player via
/// a parabolic arc with ease-in timing.
pub const PickupAnim = struct {
    item_id: u16,
    start_x: f32,
    start_y: f32,
    start_z: f32,
    target_x: f32,
    target_y: f32,
    target_z: f32,
    timer: f32,
    duration: f32,
};

/// Interpolated 3D position returned by `getPosition`.
pub const Position = struct { x: f32, y: f32, z: f32 };

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/// Default pickup animation duration in seconds.
const default_duration: f32 = 0.4;

/// Height of the parabolic arc as a fraction of the horizontal distance.
const arc_height_factor: f32 = 0.5;

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Create a new pickup animation from item position to player position.
pub fn startPickup(
    item: u16,
    ix: f32,
    iy: f32,
    iz: f32,
    px: f32,
    py: f32,
    pz: f32,
) PickupAnim {
    return .{
        .item_id = item,
        .start_x = ix,
        .start_y = iy,
        .start_z = iz,
        .target_x = px,
        .target_y = py,
        .target_z = pz,
        .timer = 0.0,
        .duration = default_duration,
    };
}

/// Advance the animation by `dt` seconds.
/// Returns `true` when the animation has finished (timer >= duration).
pub fn updatePickup(a: *PickupAnim, dt: f32) bool {
    a.timer = @min(a.timer + dt, a.duration);
    return a.timer >= a.duration;
}

/// Compute the interpolated position with ease-in timing and a parabolic arc.
///
/// The ease-in curve is `t^2`, producing slow departure and fast arrival.
/// A vertical parabola (`4 * h * t * (1 - t)`) is added on top of the
/// linearly interpolated Y to make the item arc upward in the middle.
pub fn getPosition(a: PickupAnim) Position {
    const raw_t = if (a.duration > 0.0) @min(a.timer / a.duration, 1.0) else 1.0;

    // Ease-in: t^2
    const t = raw_t * raw_t;

    const x = a.start_x + (a.target_x - a.start_x) * t;
    const z = a.start_z + (a.target_z - a.start_z) * t;

    // Base linear interpolation for Y.
    const base_y = a.start_y + (a.target_y - a.start_y) * t;

    // Horizontal distance determines arc height.
    const dx = a.target_x - a.start_x;
    const dz = a.target_z - a.start_z;
    const horiz_dist = @sqrt(dx * dx + dz * dz);
    const arc_h = @max(horiz_dist * arc_height_factor, 0.3);

    // Parabolic arc: peaks at raw_t = 0.5, zero at endpoints.
    const arc_offset = 4.0 * arc_h * raw_t * (1.0 - raw_t);
    const y = base_y + arc_offset;

    return .{ .x = x, .y = y, .z = z };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "startPickup initialises all fields correctly" {
    const a = startPickup(42, 1.0, 2.0, 3.0, 10.0, 11.0, 12.0);
    try std.testing.expectEqual(@as(u16, 42), a.item_id);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), a.start_x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), a.start_y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), a.start_z, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), a.target_x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 11.0), a.target_y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 12.0), a.target_z, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), a.timer, 0.001);
    try std.testing.expect(a.duration > 0.0);
}

test "startPickup timer starts at zero" {
    const a = startPickup(1, 0.0, 0.0, 0.0, 5.0, 5.0, 5.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), a.timer, 0.001);
}

test "updatePickup returns false while in progress" {
    var a = startPickup(1, 0.0, 0.0, 0.0, 10.0, 0.0, 0.0);
    const done = updatePickup(&a, 0.1);
    try std.testing.expect(!done);
    try std.testing.expect(a.timer > 0.0);
}

test "updatePickup returns true when finished" {
    var a = startPickup(1, 0.0, 0.0, 0.0, 10.0, 0.0, 0.0);
    const done = updatePickup(&a, 10.0);
    try std.testing.expect(done);
    try std.testing.expectApproxEqAbs(a.duration, a.timer, 0.001);
}

test "updatePickup clamps timer to duration" {
    var a = startPickup(1, 0.0, 0.0, 0.0, 10.0, 0.0, 0.0);
    _ = updatePickup(&a, 100.0);
    try std.testing.expectApproxEqAbs(a.duration, a.timer, 0.001);
}

test "updatePickup accumulates across multiple calls" {
    var a = startPickup(1, 0.0, 0.0, 0.0, 10.0, 0.0, 0.0);
    _ = updatePickup(&a, 0.05);
    _ = updatePickup(&a, 0.05);
    try std.testing.expectApproxEqAbs(@as(f32, 0.1), a.timer, 0.001);
}

test "getPosition at t=0 returns start position" {
    const a = startPickup(1, 5.0, 10.0, 15.0, 20.0, 25.0, 30.0);
    const pos = getPosition(a);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), pos.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), pos.y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 15.0), pos.z, 0.001);
}

test "getPosition at t=1 reaches target XZ" {
    var a = startPickup(1, 0.0, 0.0, 0.0, 10.0, 5.0, 10.0);
    _ = updatePickup(&a, a.duration);
    const pos = getPosition(a);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), pos.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), pos.y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), pos.z, 0.001);
}

test "getPosition mid-animation has arc above linear path" {
    var a = startPickup(1, 0.0, 0.0, 0.0, 10.0, 0.0, 0.0);
    // Advance to roughly mid-animation
    _ = updatePickup(&a, a.duration * 0.5);
    const pos = getPosition(a);
    // Linear Y would be ~0 (start and target are both 0).
    // Arc should lift Y above zero.
    try std.testing.expect(pos.y > 0.0);
}

test "getPosition ease-in is slower at start" {
    var a1 = startPickup(1, 0.0, 0.0, 0.0, 10.0, 0.0, 0.0);
    _ = updatePickup(&a1, a1.duration * 0.25);
    const pos_early = getPosition(a1);

    // At raw_t = 0.25, ease-in t = 0.0625, so X should be about 0.625
    // (much less than the linear 2.5).
    try std.testing.expect(pos_early.x < 2.5);
}

test "getPosition with zero-distance still works" {
    const a = startPickup(1, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0);
    const pos = getPosition(a);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), pos.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), pos.z, 0.001);
}

test "getPosition arc height scales with horizontal distance" {
    // Short horizontal distance
    var a_short = startPickup(1, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0);
    _ = updatePickup(&a_short, a_short.duration * 0.5);
    const pos_short = getPosition(a_short);

    // Long horizontal distance
    var a_long = startPickup(1, 0.0, 0.0, 0.0, 20.0, 0.0, 0.0);
    _ = updatePickup(&a_long, a_long.duration * 0.5);
    const pos_long = getPosition(a_long);

    // Longer distance should produce higher arc
    try std.testing.expect(pos_long.y > pos_short.y);
}

test "getPosition with zero duration returns target" {
    var a = startPickup(1, 0.0, 0.0, 0.0, 10.0, 5.0, 10.0);
    a.duration = 0.0;
    const pos = getPosition(a);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), pos.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), pos.y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), pos.z, 0.001);
}

test "full animation lifecycle from start to finish" {
    var a = startPickup(99, 1.0, 2.0, 3.0, 11.0, 7.0, 13.0);

    // Step through the animation in small increments
    var steps: u32 = 0;
    while (!updatePickup(&a, 0.02)) {
        steps += 1;
        const pos = getPosition(a);
        // Position should always be finite
        try std.testing.expect(!std.math.isNan(pos.x));
        try std.testing.expect(!std.math.isNan(pos.y));
        try std.testing.expect(!std.math.isNan(pos.z));
    }

    // Should have taken multiple steps
    try std.testing.expect(steps > 0);

    // Final position should be at target
    const final = getPosition(a);
    try std.testing.expectApproxEqAbs(@as(f32, 11.0), final.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 7.0), final.y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 13.0), final.z, 0.001);
}
