const std = @import("std");

/// State for a guardian's charging laser beam.
pub const BeamState = struct {
    charge: f32 = 0,
    max_charge: f32 = 2.0,
    active: bool = false,
    target_x: f32 = 0,
    target_y: f32 = 0,
    target_z: f32 = 0,
};

/// Begin charging a beam toward the given target position.
pub fn startBeam(state: *BeamState, tx: f32, ty: f32, tz: f32) void {
    state.* = .{
        .charge = 0,
        .max_charge = state.max_charge,
        .active = true,
        .target_x = tx,
        .target_y = ty,
        .target_z = tz,
    };
}

/// Advance the beam charge by `dt` seconds.
/// Returns `true` when the beam has fully charged and fires (charge >= max_charge).
pub fn updateBeam(state: *BeamState, dt: f32) bool {
    if (!state.active) return false;

    state.charge = @min(state.charge + dt, state.max_charge);
    if (state.charge >= state.max_charge) {
        state.active = false;
        return true;
    }
    return false;
}

/// Return the beam color interpolated from purple (0%) to orange (100%).
pub fn getBeamColor(charge_pct: f32) [3]f32 {
    const t = clamp01(charge_pct);

    // Purple: (0.5, 0.0, 0.8)  ->  Orange: (1.0, 0.5, 0.0)
    return .{
        0.5 + t * 0.5,
        0.0 + t * 0.5,
        0.8 - t * 0.8,
    };
}

/// Return the beam width interpolated from 0.1 (0%) to 0.3 (100%).
pub fn getBeamWidth(charge_pct: f32) f32 {
    const t = clamp01(charge_pct);
    return 0.1 + t * 0.2;
}

fn clamp01(v: f32) f32 {
    return @max(0.0, @min(1.0, v));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

const expectApprox = std.testing.expectApproxEqAbs;
const expect = std.testing.expect;
const tolerance: f32 = 0.001;

test "startBeam sets target and activates" {
    var s = BeamState{};
    startBeam(&s, 1.0, 2.0, 3.0);
    try expect(s.active);
    try expectApprox(1.0, s.target_x, tolerance);
    try expectApprox(2.0, s.target_y, tolerance);
    try expectApprox(3.0, s.target_z, tolerance);
    try expectApprox(0.0, s.charge, tolerance);
}

test "startBeam resets charge to zero" {
    var s = BeamState{ .charge = 1.5, .active = true };
    startBeam(&s, 0, 0, 0);
    try expectApprox(0.0, s.charge, tolerance);
}

test "updateBeam accumulates charge" {
    var s = BeamState{};
    startBeam(&s, 0, 0, 0);
    _ = updateBeam(&s, 0.5);
    try expectApprox(0.5, s.charge, tolerance);
    try expect(s.active);
}

test "updateBeam fires after max_charge" {
    var s = BeamState{};
    startBeam(&s, 0, 0, 0);
    const fired = updateBeam(&s, 2.0);
    try expect(fired);
    try expect(!s.active);
}

test "updateBeam does not overshoot max_charge" {
    var s = BeamState{};
    startBeam(&s, 0, 0, 0);
    _ = updateBeam(&s, 5.0);
    try expectApprox(2.0, s.charge, tolerance);
}

test "updateBeam returns false when inactive" {
    var s = BeamState{};
    const fired = updateBeam(&s, 1.0);
    try expect(!fired);
    try expectApprox(0.0, s.charge, tolerance);
}

test "updateBeam fires across multiple steps" {
    var s = BeamState{};
    startBeam(&s, 0, 0, 0);
    try expect(!updateBeam(&s, 0.5));
    try expect(!updateBeam(&s, 0.5));
    try expect(!updateBeam(&s, 0.5));
    try expect(updateBeam(&s, 0.5));
}

test "getBeamColor at 0 pct is purple" {
    const c = getBeamColor(0.0);
    try expectApprox(0.5, c[0], tolerance);
    try expectApprox(0.0, c[1], tolerance);
    try expectApprox(0.8, c[2], tolerance);
}

test "getBeamColor at 100 pct is orange" {
    const c = getBeamColor(1.0);
    try expectApprox(1.0, c[0], tolerance);
    try expectApprox(0.5, c[1], tolerance);
    try expectApprox(0.0, c[2], tolerance);
}

test "getBeamColor at 50 pct is midpoint" {
    const c = getBeamColor(0.5);
    try expectApprox(0.75, c[0], tolerance);
    try expectApprox(0.25, c[1], tolerance);
    try expectApprox(0.40, c[2], tolerance);
}

test "getBeamColor clamps below 0" {
    const c = getBeamColor(-1.0);
    try expectApprox(0.5, c[0], tolerance);
    try expectApprox(0.0, c[1], tolerance);
    try expectApprox(0.8, c[2], tolerance);
}

test "getBeamColor clamps above 1" {
    const c = getBeamColor(2.0);
    try expectApprox(1.0, c[0], tolerance);
    try expectApprox(0.5, c[1], tolerance);
    try expectApprox(0.0, c[2], tolerance);
}

test "getBeamWidth at 0 pct is 0.1" {
    try expectApprox(0.1, getBeamWidth(0.0), tolerance);
}

test "getBeamWidth at 100 pct is 0.3" {
    try expectApprox(0.3, getBeamWidth(1.0), tolerance);
}

test "getBeamWidth at 50 pct is 0.2" {
    try expectApprox(0.2, getBeamWidth(0.5), tolerance);
}

test "getBeamWidth clamps input" {
    try expectApprox(0.1, getBeamWidth(-5.0), tolerance);
    try expectApprox(0.3, getBeamWidth(10.0), tolerance);
}

test "startBeam preserves custom max_charge" {
    var s = BeamState{ .max_charge = 5.0 };
    startBeam(&s, 1, 2, 3);
    try expectApprox(5.0, s.max_charge, tolerance);
}
