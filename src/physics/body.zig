/// Physics body with gravity and jump support.
/// Represents a player or entity with position, velocity, and dimensions.
const std = @import("std");
const aabb_mod = @import("aabb.zig");
const AABB = aabb_mod.AABB;

pub const Body = struct {
    x: f32,
    y: f32,
    z: f32,
    vx: f32,
    vy: f32,
    vz: f32,
    on_ground: bool,
    width: f32,
    height: f32,

    /// Apply gravity to vy and integrate position.
    /// Call this each tick *before* collision resolution.
    pub fn update(self: *Body, dt: f32, gravity: f32) void {
        self.vy += gravity * dt;
        self.x += self.vx * dt;
        self.y += self.vy * dt;
        self.z += self.vz * dt;
    }

    /// Attempt a jump.  Sets vy to `impulse` only when on the ground.
    pub fn jump(self: *Body, impulse: f32) void {
        if (self.on_ground) {
            self.vy = impulse;
            self.on_ground = false;
        }
    }

    /// Return the AABB for this body.
    /// The body is centered on (x, z) with feet at y.
    pub fn getAABB(self: *const Body) AABB {
        const hw = self.width * 0.5;
        return .{
            .min_x = self.x - hw,
            .min_y = self.y,
            .min_z = self.z - hw,
            .max_x = self.x + hw,
            .max_y = self.y + self.height,
            .max_z = self.z + hw,
        };
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

fn makeBody() Body {
    return .{
        .x = 0,
        .y = 10,
        .z = 0,
        .vx = 0,
        .vy = 0,
        .vz = 0,
        .on_ground = false,
        .width = 0.6,
        .height = 1.8,
    };
}

test "body falls under gravity" {
    var b = makeBody();
    const gravity: f32 = -9.8;
    const dt: f32 = 1.0;

    b.update(dt, gravity);

    // vy should be gravity * dt = -9.8
    try std.testing.expectApproxEqAbs(@as(f32, -9.8), b.vy, 0.01);
    // y should be 10 + (-9.8 * 1) = 0.2 (vy applied after gravity added)
    try std.testing.expectApproxEqAbs(@as(f32, 0.2), b.y, 0.01);
}

test "jump sets vy when on ground" {
    var b = makeBody();
    b.on_ground = true;

    b.jump(8.0);

    try std.testing.expectApproxEqAbs(@as(f32, 8.0), b.vy, 0.001);
    try std.testing.expect(!b.on_ground);
}

test "jump does nothing when airborne" {
    var b = makeBody();
    b.on_ground = false;
    b.vy = -2.0;

    b.jump(8.0);

    // vy should be unchanged
    try std.testing.expectApproxEqAbs(@as(f32, -2.0), b.vy, 0.001);
}

test "getAABB: correct dimensions" {
    const b = Body{
        .x = 5,
        .y = 10,
        .z = 3,
        .vx = 0,
        .vy = 0,
        .vz = 0,
        .on_ground = false,
        .width = 0.6,
        .height = 1.8,
    };
    const box = b.getAABB();

    // x centered: 5 +/- 0.3
    try std.testing.expectApproxEqAbs(@as(f32, 4.7), box.min_x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 5.3), box.max_x, 0.001);
    // y: feet at 10, head at 11.8
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), box.min_y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 11.8), box.max_y, 0.001);
    // z centered: 3 +/- 0.3
    try std.testing.expectApproxEqAbs(@as(f32, 2.7), box.min_z, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 3.3), box.max_z, 0.001);
}
