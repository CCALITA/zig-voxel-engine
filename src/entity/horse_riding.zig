/// Horse riding system: mounting, dismounting, WASD steering, and charged jumps.
const std = @import("std");

// ── Horse Stats ─────────────────────────────────────────────────────

pub const HorseStats = struct {
    speed: f32 = 0.225,
    jump_strength: f32 = 0.7,
    hp: f32 = 20,
};

// ── Riding State ────────────────────────────────────────────────────

pub const RidingState = struct {
    mounted: bool = false,
    jump_charge: f32 = 0,

    pub fn mount(self: *RidingState) void {
        self.mounted = true;
        self.jump_charge = 0;
    }

    pub fn dismount(self: *RidingState) void {
        self.mounted = false;
        self.jump_charge = 0;
    }

    /// Tick the riding state and return the velocity vector for this frame.
    ///
    /// `dt`        – delta time in seconds
    /// `forward`   – forward/backward input in [-1, 1]
    /// `turn`      – left/right turn input in [-1, 1]
    /// `jump_held` – whether the jump key (space) is held
    /// `stats`     – the horse's base stats
    ///
    /// Steering applies a turn rate of 2.5 rad/s to an internal yaw that is
    /// decomposed into vx/vz.  When `jump_held` is true the charge rises
    /// linearly from 0 to 1 over one second.  On release the horse jumps
    /// with a vertical velocity derived from `getJumpHeight`.
    pub fn update(
        self: *RidingState,
        dt: f32,
        forward: f32,
        turn: f32,
        jump_held: bool,
        stats: HorseStats,
    ) struct { vx: f32, vz: f32, vy: f32 } {
        if (!self.mounted) return .{ .vx = 0, .vz = 0, .vy = 0 };

        // --- horizontal movement ---
        const turn_rate: f32 = 2.5; // rad/s
        const yaw = turn * turn_rate * dt;
        const move_speed = forward * stats.speed;
        const vx = move_speed * @sin(yaw);
        const vz = move_speed * @cos(yaw);

        // --- jump charge / release ---
        var vy: f32 = 0;
        if (jump_held) {
            self.jump_charge = @min(self.jump_charge + dt, 1.0);
        } else if (self.jump_charge > 0) {
            vy = getJumpHeight(self.jump_charge, stats.jump_strength);
            self.jump_charge = 0;
        }

        return .{ .vx = vx, .vz = vz, .vy = vy };
    }
};

/// Compute the vertical velocity for a jump given a charge level (0..1)
/// and the horse's jump strength.
///
/// Uses a quadratic curve: `strength * (charge^2 + charge) / 2` so that
/// a quick tap yields a small hop while a full charge gives maximum
/// height.
pub fn getJumpHeight(charge: f32, strength: f32) f32 {
    const c = std.math.clamp(charge, 0, 1);
    return strength * (c * c + c) / 2.0;
}

// ── Tests ───────────────────────────────────────────────────────────

test "default HorseStats values" {
    const stats = HorseStats{};
    try std.testing.expectApproxEqAbs(@as(f32, 0.225), stats.speed, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.7), stats.jump_strength, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 20), stats.hp, 0.001);
}

test "default RidingState is unmounted" {
    const state = RidingState{};
    try std.testing.expect(!state.mounted);
    try std.testing.expectApproxEqAbs(@as(f32, 0), state.jump_charge, 0.001);
}

test "mount sets mounted true and resets charge" {
    var state = RidingState{ .jump_charge = 0.5 };
    state.mount();
    try std.testing.expect(state.mounted);
    try std.testing.expectApproxEqAbs(@as(f32, 0), state.jump_charge, 0.001);
}

test "dismount sets mounted false and resets charge" {
    var state = RidingState{ .mounted = true, .jump_charge = 0.8 };
    state.dismount();
    try std.testing.expect(!state.mounted);
    try std.testing.expectApproxEqAbs(@as(f32, 0), state.jump_charge, 0.001);
}

test "update returns zero velocity when not mounted" {
    var state = RidingState{};
    const v = state.update(0.016, 1.0, 0.0, false, HorseStats{});
    try std.testing.expectApproxEqAbs(@as(f32, 0), v.vx, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), v.vz, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), v.vy, 0.001);
}

test "forward movement produces positive vz" {
    var state = RidingState{ .mounted = true };
    const v = state.update(0.016, 1.0, 0.0, false, HorseStats{});
    // No turn means yaw=0, so vz = speed * cos(0) = speed, vx ~ 0
    try std.testing.expectApproxEqAbs(@as(f32, 0.225), v.vz, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), v.vx, 0.01);
}

test "backward movement produces negative vz" {
    var state = RidingState{ .mounted = true };
    const v = state.update(0.016, -1.0, 0.0, false, HorseStats{});
    try std.testing.expectApproxEqAbs(@as(f32, -0.225), v.vz, 0.001);
}

test "turning produces non-zero vx" {
    var state = RidingState{ .mounted = true };
    const v = state.update(0.5, 1.0, 1.0, false, HorseStats{});
    // yaw = 1.0 * 2.5 * 0.5 = 1.25 rad, vx = 0.225 * sin(1.25) != 0
    try std.testing.expect(v.vx != 0);
}

test "holding jump charges over time and caps at 1" {
    var state = RidingState{ .mounted = true };
    // Hold for 0.5s
    _ = state.update(0.5, 0.0, 0.0, true, HorseStats{});
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), state.jump_charge, 0.01);
    // Hold for another 0.8s -> should cap at 1.0
    _ = state.update(0.8, 0.0, 0.0, true, HorseStats{});
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), state.jump_charge, 0.001);
}

test "releasing jump produces vy and resets charge" {
    var state = RidingState{ .mounted = true };
    // Charge for 0.5s
    _ = state.update(0.5, 0.0, 0.0, true, HorseStats{});
    try std.testing.expect(state.jump_charge > 0);
    // Release
    const v = state.update(0.016, 0.0, 0.0, false, HorseStats{});
    try std.testing.expect(v.vy > 0);
    try std.testing.expectApproxEqAbs(@as(f32, 0), state.jump_charge, 0.001);
}

test "getJumpHeight zero charge gives zero" {
    try std.testing.expectApproxEqAbs(@as(f32, 0), getJumpHeight(0, 0.7), 0.001);
}

test "getJumpHeight full charge" {
    // charge=1 => strength * (1 + 1) / 2 = strength
    const h = getJumpHeight(1.0, 0.7);
    try std.testing.expectApproxEqAbs(@as(f32, 0.7), h, 0.001);
}

test "getJumpHeight clamps charge above 1" {
    const h = getJumpHeight(5.0, 0.7);
    try std.testing.expectApproxEqAbs(@as(f32, 0.7), h, 0.001);
}

test "getJumpHeight half charge" {
    // charge=0.5 => 0.7 * (0.25 + 0.5) / 2 = 0.7 * 0.375 = 0.2625
    const h = getJumpHeight(0.5, 0.7);
    try std.testing.expectApproxEqAbs(@as(f32, 0.2625), h, 0.001);
}

test "mount then dismount round-trip" {
    var state = RidingState{};
    state.mount();
    try std.testing.expect(state.mounted);
    _ = state.update(0.3, 0.0, 0.0, true, HorseStats{});
    try std.testing.expect(state.jump_charge > 0);
    state.dismount();
    try std.testing.expect(!state.mounted);
    try std.testing.expectApproxEqAbs(@as(f32, 0), state.jump_charge, 0.001);
}

test "custom HorseStats affect movement speed" {
    var state = RidingState{ .mounted = true };
    const fast = HorseStats{ .speed = 0.5, .jump_strength = 1.0, .hp = 30 };
    const v = state.update(0.016, 1.0, 0.0, false, fast);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), v.vz, 0.001);
}
