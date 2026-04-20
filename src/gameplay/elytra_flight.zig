const std = @import("std");
const math = std.math;

pub const FlightOutput = struct {
    vx: f32,
    vy: f32,
    vz: f32,
    speed: f32,
    stalling: bool,
};

pub const FlightController = struct {
    active: bool = false,
    speed: f32 = 0,
    pitch: f32 = 0,
    yaw: f32 = 0,
    altitude: f32 = 0,
    stalling: bool = false,
    firework_boost: f32 = 0,
    durability_drain_timer: f32 = 0,

    const max_speed: f32 = 30.0;
    const stall_speed: f32 = 0.5;
    const stall_fall_vy: f32 = -3.0;
    const nose_down_accel: f32 = 0.5;
    const cruise_drag: f32 = -0.01;
    const max_pitch_angle: f32 = math.pi / 4.0;

    pub fn startFlight(self: *FlightController, initial_speed: f32) void {
        self.active = true;
        self.speed = initial_speed;
        self.stalling = false;
        self.firework_boost = 0;
        self.durability_drain_timer = 0;
    }

    pub fn update(self: *FlightController, dt: f32, input_pitch: f32, input_yaw: f32) FlightOutput {
        if (!self.active) {
            return .{ .vx = 0, .vy = 0, .vz = 0, .speed = 0, .stalling = false };
        }

        self.pitch = input_pitch;
        self.yaw = input_yaw;

        // Apply firework boost decay
        if (self.firework_boost > 0) {
            self.firework_boost -= dt;
            if (self.firework_boost < 0) self.firework_boost = 0;
        }

        const pitch_ratio = -input_pitch / max_pitch_angle;
        const clamped_ratio = math.clamp(pitch_ratio, -1.0, 1.0);

        if (clamped_ratio != 0) {
            self.speed += clamped_ratio * nose_down_accel * dt;
        } else {
            self.speed += cruise_drag * dt;
        }

        self.speed = math.clamp(self.speed, 0, max_speed);
        self.stalling = self.speed < stall_speed;

        const vy: f32 = if (self.stalling) stall_fall_vy else self.speed * @sin(input_pitch);

        const horizontal_speed = self.speed * @cos(input_pitch);
        const vx = horizontal_speed * @sin(self.yaw);
        const vz = horizontal_speed * @cos(self.yaw);

        self.altitude += vy * dt;

        return .{
            .vx = vx,
            .vy = vy,
            .vz = vz,
            .speed = self.speed,
            .stalling = self.stalling,
        };
    }

    pub fn applyFireworkBoost(self: *FlightController, duration: u2) void {
        const boost: f32 = @floatFromInt(duration);
        self.speed += boost * 12.0;
        if (self.speed > max_speed) self.speed = max_speed;
        self.firework_boost = boost;
    }

    pub fn getKineticDamage(wall_hit_speed: f32) f32 {
        if (wall_hit_speed < 10.0) return 0;
        return wall_hit_speed - 10.0;
    }

    pub fn getDurabilityLoss(self: *FlightController, dt: f32) u16 {
        if (!self.active) return 0;
        self.durability_drain_timer += dt;
        const loss: u16 = @intFromFloat(self.durability_drain_timer);
        self.durability_drain_timer -= @floatFromInt(loss);
        return loss;
    }

    pub fn endFlight(self: *FlightController) void {
        self.* = .{};
    }
};

test "pitch to speed conversion - nose down accelerates" {
    var fc = FlightController{};
    fc.startFlight(5.0);

    // Negative pitch = nose down = acceleration
    const result = fc.update(1.0, -FlightController.max_pitch_angle, 0);

    try std.testing.expect(result.speed > 5.0);
    try std.testing.expect(!result.stalling);
}

test "pitch to speed conversion - level flight applies drag" {
    var fc = FlightController{};
    fc.startFlight(5.0);

    const result = fc.update(1.0, 0, 0);

    try std.testing.expectApproxEqAbs(@as(f32, 4.99), result.speed, 0.01);
}

test "pitch to speed conversion - nose up decelerates" {
    var fc = FlightController{};
    fc.startFlight(5.0);

    // Positive pitch = nose up = deceleration
    const result = fc.update(1.0, FlightController.max_pitch_angle, 0);

    try std.testing.expect(result.speed < 5.0);
}

test "stall at low speed" {
    var fc = FlightController{};
    fc.startFlight(0.3);

    const result = fc.update(0.01, 0, 0);

    try std.testing.expect(result.stalling);
    try std.testing.expectApproxEqAbs(@as(f32, -3.0), result.vy, 0.01);
}

test "no stall above threshold" {
    var fc = FlightController{};
    fc.startFlight(5.0);

    const result = fc.update(0.016, 0, 0);

    try std.testing.expect(!result.stalling);
}

test "firework boost adds speed" {
    var fc = FlightController{};
    fc.startFlight(5.0);

    fc.applyFireworkBoost(2);

    try std.testing.expectApproxEqAbs(@as(f32, 29.0), fc.speed, 0.01);
}

test "firework boost capped at max speed" {
    var fc = FlightController{};
    fc.startFlight(20.0);

    fc.applyFireworkBoost(3);

    try std.testing.expectApproxEqAbs(@as(f32, 30.0), fc.speed, 0.01);
}

test "kinetic damage zero below threshold" {
    const damage = FlightController.getKineticDamage(5.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0), damage, 0.01);
}

test "kinetic damage scales above threshold" {
    const damage = FlightController.getKineticDamage(15.0);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), damage, 0.01);
}

test "kinetic damage at exact threshold" {
    const damage = FlightController.getKineticDamage(10.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0), damage, 0.01);
}

test "durability drain one per second" {
    var fc = FlightController{};
    fc.startFlight(5.0);

    const loss1 = fc.getDurabilityLoss(0.5);
    try std.testing.expectEqual(@as(u16, 0), loss1);

    const loss2 = fc.getDurabilityLoss(0.5);
    try std.testing.expectEqual(@as(u16, 1), loss2);

    const loss3 = fc.getDurabilityLoss(2.5);
    try std.testing.expectEqual(@as(u16, 2), loss3);
}

test "durability drain inactive returns zero" {
    var fc = FlightController{};

    const loss = fc.getDurabilityLoss(5.0);
    try std.testing.expectEqual(@as(u16, 0), loss);
}

test "end flight resets all state" {
    var fc = FlightController{};
    fc.startFlight(10.0);
    _ = fc.update(1.0, 0.5, 0.3);
    fc.applyFireworkBoost(2);

    fc.endFlight();

    try std.testing.expect(!fc.active);
    try std.testing.expectApproxEqAbs(@as(f32, 0), fc.speed, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0), fc.pitch, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0), fc.yaw, 0.01);
    try std.testing.expect(!fc.stalling);
    try std.testing.expectApproxEqAbs(@as(f32, 0), fc.firework_boost, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0), fc.durability_drain_timer, 0.01);
}

test "inactive controller returns zero output" {
    var fc = FlightController{};

    const result = fc.update(1.0, 0.5, 0.3);

    try std.testing.expectApproxEqAbs(@as(f32, 0), result.vx, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0), result.vy, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0), result.vz, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0), result.speed, 0.01);
    try std.testing.expect(!result.stalling);
}
