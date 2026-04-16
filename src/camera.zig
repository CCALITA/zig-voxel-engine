/// FPS-style camera with mouse look and WASD movement.
const std = @import("std");
const zm = @import("zmath");

pos: zm.Vec,
yaw: f32, // radians, 0 = looking down -Z
pitch: f32, // radians, clamped to [-89, 89] degrees
fov: f32, // vertical FOV in degrees
aspect: f32,
speed: f32 = 10.0,
sensitivity: f32 = 0.003,

const Self = @This();

pub fn init(aspect: f32) Self {
    return .{
        .pos = zm.f32x4(8.0, 12.0, 8.0, 1.0),
        .yaw = 0.0,
        .pitch = 0.0,
        .fov = 70.0,
        .aspect = aspect,
    };
}

pub fn forward(self: *const Self) zm.Vec {
    const cy = @cos(self.yaw);
    const sy = @sin(self.yaw);
    const cp = @cos(self.pitch);
    const sp = @sin(self.pitch);
    return zm.f32x4(sy * cp, sp, -cy * cp, 0.0);
}

pub fn right(self: *const Self) zm.Vec {
    const cy = @cos(self.yaw);
    const sy = @sin(self.yaw);
    return zm.f32x4(cy, 0.0, sy, 0.0);
}

pub fn processMouseDelta(self: *Self, dx: f64, dy: f64) void {
    self.yaw -= @floatCast(dx * self.sensitivity);
    self.pitch -= @floatCast(dy * self.sensitivity);

    const max_pitch = std.math.degreesToRadians(89.0);
    self.pitch = std.math.clamp(self.pitch, -max_pitch, max_pitch);
}

pub fn processMovement(self: *Self, dt: f32, forward_input: f32, right_input: f32, up_input: f32) void {
    const fwd = self.forward();
    const rt = self.right();
    const up = zm.f32x4(0.0, 1.0, 0.0, 0.0);

    const velocity = zm.splat(zm.Vec, self.speed * dt);
    self.pos += fwd * zm.splat(zm.Vec, forward_input) * velocity;
    self.pos += rt * zm.splat(zm.Vec, right_input) * velocity;
    self.pos += up * zm.splat(zm.Vec, up_input) * velocity;
}

pub fn viewMatrix(self: *const Self) zm.Mat {
    const target = self.pos + self.forward();
    return zm.lookAtRh(self.pos, target, zm.f32x4(0.0, 1.0, 0.0, 0.0));
}

pub fn projectionMatrix(self: *const Self) zm.Mat {
    var proj = zm.perspectiveFovRh(
        std.math.degreesToRadians(self.fov),
        self.aspect,
        0.1,
        1000.0,
    );
    // Vulkan clip space has Y pointing down; negate Y to flip
    proj[1] = -proj[1];
    return proj;
}

pub fn vpMatrix(self: *const Self) zm.Mat {
    return zm.mul(self.viewMatrix(), self.projectionMatrix());
}

/// Convert zmath Mat (column-major SIMD) to a [4][4]f32 for push constants
pub fn matToArray(m: zm.Mat) [4][4]f32 {
    return .{
        .{ m[0][0], m[0][1], m[0][2], m[0][3] },
        .{ m[1][0], m[1][1], m[1][2], m[1][3] },
        .{ m[2][0], m[2][1], m[2][2], m[2][3] },
        .{ m[3][0], m[3][1], m[3][2], m[3][3] },
    };
}
