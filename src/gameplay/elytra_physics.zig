const std = @import("std");
const math = std.math;

pub const ElytraState = struct {
    is_gliding: bool = false,
    pitch: f32 = 0,
    speed: f32 = 0,
    flight_time: f32 = 0,

    const max_speed: f32 = 3.0;
    const gravity_descent: f32 = -0.2;
    const pitch_down_accel: f32 = 0.8;
    const pitch_up_decel: f32 = 0.4;
    const level_drag: f32 = 0.02;
    const max_pitch: f32 = math.pi / 2.0;

    pub fn startGlide(self: *ElytraState) void {
        self.* = .{ .is_gliding = true, .speed = 0.5 };
    }

    pub fn stopGlide(self: *ElytraState) void {
        self.* = .{};
    }

    pub fn update(self: *ElytraState, pitch_input: f32, dt: f32) struct { vx: f32, vy: f32, vz: f32 } {
        if (!self.is_gliding) {
            return .{ .vx = 0, .vy = 0, .vz = 0 };
        }

        self.flight_time += dt;
        self.pitch = math.clamp(pitch_input, -max_pitch, max_pitch);

        if (pitch_input > 0) {
            self.speed += (pitch_input / max_pitch) * pitch_down_accel * dt;
        } else if (pitch_input < 0) {
            self.speed -= (-pitch_input / max_pitch) * pitch_up_decel * dt;
        } else {
            self.speed -= level_drag * dt;
        }

        self.speed = math.clamp(self.speed, 0, max_speed);

        const pitch_ratio = pitch_input / max_pitch;
        const vy: f32 = if (pitch_input > 0)
            gravity_descent * (1.0 + pitch_ratio)
        else if (pitch_input < 0)
            self.speed * (-pitch_ratio) * 0.5
        else
            gravity_descent;

        return .{
            .vx = self.speed * @cos(self.pitch),
            .vy = vy,
            .vz = 0,
        };
    }

    pub fn applyFireworkBoost(self: *ElytraState, duration: u8) void {
        self.speed += @as(f32, @floatFromInt(duration)) * 1.5;
        if (self.speed > max_speed) {
            self.speed = max_speed;
        }
    }

    pub fn calculateKineticDamage(speed: f32) f32 {
        if (speed <= 10.0) return 0;
        return speed - 10.0;
    }

    pub fn getDurabilityLoss(dt: f32) f32 {
        return dt;
    }
};

// -- Tests --------------------------------------------------------------------

test "startGlide activates gliding" {
    var state = ElytraState{};
    state.startGlide();

    try std.testing.expect(state.is_gliding);
    try std.testing.expect(state.speed > 0);
    try std.testing.expectApproxEqAbs(@as(f32, 0), state.flight_time, 0.001);
}

test "stopGlide deactivates gliding" {
    var state = ElytraState{};
    state.startGlide();
    state.stopGlide();

    try std.testing.expect(!state.is_gliding);
    try std.testing.expectApproxEqAbs(@as(f32, 0), state.speed, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), state.flight_time, 0.001);
}

test "update returns zero velocity when not gliding" {
    var state = ElytraState{};

    const vel = state.update(0, 1.0);

    try std.testing.expectApproxEqAbs(@as(f32, 0), vel.vx, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), vel.vy, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), vel.vz, 0.001);
}

test "pitch down increases speed" {
    var state = ElytraState{};
    state.startGlide();
    const initial_speed = state.speed;

    _ = state.update(0.5, 1.0);

    try std.testing.expect(state.speed > initial_speed);
}

test "pitch down speed capped at max" {
    var state = ElytraState{};
    state.startGlide();
    state.speed = 2.9;

    _ = state.update(ElytraState.max_pitch, 10.0);

    try std.testing.expectApproxEqAbs(ElytraState.max_speed, state.speed, 0.001);
}

test "pitch up decreases speed and produces climb" {
    var state = ElytraState{};
    state.startGlide();
    state.speed = 2.0;

    const vel = state.update(-0.5, 1.0);

    try std.testing.expect(state.speed < 2.0);
    try std.testing.expect(vel.vy > 0);
}

test "level flight applies gentle descent" {
    var state = ElytraState{};
    state.startGlide();
    state.speed = 1.5;

    const vel = state.update(0, 1.0);

    try std.testing.expect(vel.vy < 0);
    try std.testing.expect(state.speed < 1.5);
}

test "flight time accumulates" {
    var state = ElytraState{};
    state.startGlide();

    _ = state.update(0, 0.5);
    _ = state.update(0, 0.5);

    try std.testing.expectApproxEqAbs(@as(f32, 1.0), state.flight_time, 0.001);
}

test "firework boost increases speed" {
    var state = ElytraState{};
    state.startGlide();
    state.speed = 0.5;

    state.applyFireworkBoost(1);

    try std.testing.expectApproxEqAbs(@as(f32, 2.0), state.speed, 0.001);
}

test "firework boost capped at max speed" {
    var state = ElytraState{};
    state.startGlide();
    state.speed = 2.0;

    state.applyFireworkBoost(3);

    try std.testing.expectApproxEqAbs(ElytraState.max_speed, state.speed, 0.001);
}

test "kinetic damage zero at or below threshold" {
    try std.testing.expectApproxEqAbs(@as(f32, 0), ElytraState.calculateKineticDamage(5.0), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), ElytraState.calculateKineticDamage(10.0), 0.001);
}

test "kinetic damage scales above threshold" {
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), ElytraState.calculateKineticDamage(15.0), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), ElytraState.calculateKineticDamage(20.0), 0.001);
}

test "durability loss equals elapsed time" {
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), ElytraState.getDurabilityLoss(1.0), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), ElytraState.getDurabilityLoss(0.5), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), ElytraState.getDurabilityLoss(3.0), 0.001);
}

test "speed never goes below zero" {
    var state = ElytraState{};
    state.startGlide();
    state.speed = 0.01;

    _ = state.update(-ElytraState.max_pitch, 10.0);

    try std.testing.expect(state.speed >= 0);
}
