/// Vehicle system for minecarts and boats.
/// Fixed 64-slot pool with mount/dismount, boat steering, and rail physics.
const std = @import("std");

pub const VehicleType = enum {
    minecart,
    boat,
    chest_minecart,
    hopper_minecart,
};

pub const Vehicle = struct {
    vehicle_type: VehicleType,
    x: f32,
    y: f32,
    z: f32,
    vx: f32,
    vy: f32,
    vz: f32,
    yaw: f32,
    rider_id: ?u32,

    /// Boat cruising speed (blocks/s).
    const BOAT_SPEED: f32 = 5.0;
    /// Boat turn rate (radians/s).
    const BOAT_TURN_RATE: f32 = 2.0;
    /// Minecart base rail speed (blocks/s).
    const MINECART_RAIL_SPEED: f32 = 8.0;
    /// Minecart deceleration on unpowered flat rail (blocks/s^2).
    const MINECART_DECEL: f32 = 2.0;
    /// Minecart acceleration on powered rail (blocks/s^2).
    const MINECART_ACCEL: f32 = 4.0;
    /// Gravity (blocks/s^2).
    const GRAVITY: f32 = 9.8;
    /// Water surface drag for boats.
    const BOAT_DRAG: f32 = 3.0;

    pub fn init(vehicle_type: VehicleType, x: f32, y: f32, z: f32) Vehicle {
        return .{
            .vehicle_type = vehicle_type,
            .x = x,
            .y = y,
            .z = z,
            .vx = 0,
            .vy = 0,
            .vz = 0,
            .yaw = 0,
            .rider_id = null,
        };
    }

    /// Attempt to seat a rider. Does nothing if already occupied.
    pub fn mount(self: *Vehicle, rider: u32) void {
        if (self.rider_id != null) return;
        self.rider_id = rider;
    }

    /// Remove the current rider. Returns the former rider id, or null.
    pub fn dismount(self: *Vehicle) ?u32 {
        const prev = self.rider_id;
        self.rider_id = null;
        return prev;
    }

    /// Returns true when a rider is seated.
    pub fn isOccupied(self: *const Vehicle) bool {
        return self.rider_id != null;
    }

    /// Integrate position from velocity.
    fn integrate(self: *Vehicle, dt: f32) void {
        self.x += self.vx * dt;
        self.y += self.vy * dt;
        self.z += self.vz * dt;
    }

    /// Tick boat physics.
    /// `forward` in [-1,1]: throttle.  `turn` in [-1,1]: steering.
    /// `on_water`: whether the boat is on the water surface.
    pub fn updateBoat(self: *Vehicle, dt: f32, forward: f32, turn: f32, on_water: bool) void {
        // Steering
        self.yaw += turn * BOAT_TURN_RATE * dt;

        if (on_water) {
            // No gravity on water surface
            self.vy = 0;

            // Thrust along yaw direction
            const thrust = forward * BOAT_SPEED;
            const target_vx = @cos(self.yaw) * thrust;
            const target_vz = @sin(self.yaw) * thrust;

            // Smooth toward target with drag
            const blend = @min(BOAT_DRAG * dt, 1.0);
            self.vx += (target_vx - self.vx) * blend;
            self.vz += (target_vz - self.vz) * blend;
        } else {
            // Falling — apply gravity
            self.vy -= GRAVITY * dt;
        }

        self.integrate(dt);
    }

    /// Tick minecart physics.
    /// `on_rail`: whether the cart is on a rail block.
    /// `powered`: whether the rail is a powered rail.
    pub fn updateMinecart(self: *Vehicle, dt: f32, on_rail: bool, powered: bool) void {
        if (on_rail) {
            // No gravity while on rails
            self.vy = 0;

            // Compute current horizontal speed
            const speed = @sqrt(self.vx * self.vx + self.vz * self.vz);

            if (powered) {
                // Accelerate toward rail speed
                const new_speed = @min(speed + MINECART_ACCEL * dt, MINECART_RAIL_SPEED);
                self.setHorizontalSpeed(speed, new_speed);
            } else {
                // Decelerate on flat unpowered rail
                const reduction = MINECART_DECEL * dt;
                if (speed <= reduction) {
                    self.vx = 0;
                    self.vz = 0;
                } else {
                    const new_speed = speed - reduction;
                    self.setHorizontalSpeed(speed, new_speed);
                }
            }
        } else {
            // Off-rail: apply gravity
            self.vy -= GRAVITY * dt;
        }

        self.integrate(dt);
    }

    /// Scale horizontal velocity to a new speed, preserving direction.
    /// If current speed is zero, push along the yaw direction.
    fn setHorizontalSpeed(self: *Vehicle, current_speed: f32, new_speed: f32) void {
        if (current_speed < 0.001) {
            // Kick-start along yaw
            self.vx = @cos(self.yaw) * new_speed;
            self.vz = @sin(self.yaw) * new_speed;
        } else {
            const scale = new_speed / current_speed;
            self.vx *= scale;
            self.vz *= scale;
        }
    }
};

pub const VehicleManager = struct {
    vehicles: [MAX_VEHICLES]Vehicle,
    count: u32,

    const MAX_VEHICLES: u32 = 64;

    pub fn init() VehicleManager {
        return .{
            .vehicles = undefined,
            .count = 0,
        };
    }

    /// Spawn a new vehicle. Returns its index, or null if the pool is full.
    pub fn spawn(self: *VehicleManager, vtype: VehicleType, x: f32, y: f32, z: f32) ?u32 {
        if (self.count >= MAX_VEHICLES) return null;
        const idx = self.count;
        self.vehicles[idx] = Vehicle.init(vtype, x, y, z);
        self.count += 1;
        return idx;
    }

    /// Remove a vehicle by index, swapping with the last entry.
    pub fn remove(self: *VehicleManager, index: u32) void {
        if (index >= self.count) return;
        self.count -= 1;
        if (index != self.count) {
            self.vehicles[index] = self.vehicles[self.count];
        }
    }

    /// Tick all vehicles (simplified: boats on water, minecarts on rail).
    pub fn update(self: *VehicleManager, dt: f32) void {
        for (self.vehicles[0..self.count]) |*v| {
            switch (v.vehicle_type) {
                .boat => v.updateBoat(dt, 0, 0, true),
                .minecart, .chest_minecart, .hopper_minecart => v.updateMinecart(dt, true, false),
            }
        }
    }

    /// Find the nearest vehicle within `range` of the xz position.
    /// Returns its index, or null if none qualifies.
    pub fn getNearest(self: *const VehicleManager, x: f32, z: f32, range: f32) ?u32 {
        var best_idx: ?u32 = null;
        var best_dist_sq: f32 = range * range;
        for (self.vehicles[0..self.count], 0..) |v, i| {
            const dx = v.x - x;
            const dz = v.z - z;
            const dist_sq = dx * dx + dz * dz;
            if (dist_sq < best_dist_sq) {
                best_dist_sq = dist_sq;
                best_idx = @intCast(i);
            }
        }
        return best_idx;
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "vehicle init sets defaults" {
    const v = Vehicle.init(.boat, 1.0, 2.0, 3.0);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), v.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), v.y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), v.z, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), v.vx, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), v.vy, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), v.vz, 0.001);
    try std.testing.expect(!v.isOccupied());
    try std.testing.expect(v.rider_id == null);
}

test "spawn returns sequential indices" {
    var mgr = VehicleManager.init();
    const a = mgr.spawn(.boat, 0, 0, 0);
    const b = mgr.spawn(.minecart, 1, 0, 1);
    try std.testing.expectEqual(@as(?u32, 0), a);
    try std.testing.expectEqual(@as(?u32, 1), b);
    try std.testing.expectEqual(@as(u32, 2), mgr.count);
}

test "spawn returns null when pool full" {
    var mgr = VehicleManager.init();
    for (0..64) |_| {
        _ = mgr.spawn(.boat, 0, 0, 0);
    }
    try std.testing.expectEqual(@as(u32, 64), mgr.count);
    try std.testing.expect(mgr.spawn(.boat, 0, 0, 0) == null);
}

test "mount and dismount" {
    var v = Vehicle.init(.boat, 0, 0, 0);
    try std.testing.expect(!v.isOccupied());

    v.mount(42);
    try std.testing.expect(v.isOccupied());
    try std.testing.expectEqual(@as(?u32, 42), v.rider_id);

    const prev = v.dismount();
    try std.testing.expectEqual(@as(?u32, 42), prev);
    try std.testing.expect(!v.isOccupied());
}

test "mount does nothing when already occupied" {
    var v = Vehicle.init(.boat, 0, 0, 0);
    v.mount(1);
    v.mount(2);
    try std.testing.expectEqual(@as(?u32, 1), v.rider_id);
}

test "dismount on empty returns null" {
    var v = Vehicle.init(.minecart, 0, 0, 0);
    try std.testing.expect(v.dismount() == null);
}

test "boat steering changes yaw" {
    var v = Vehicle.init(.boat, 0, 0, 0);
    const yaw_before = v.yaw;
    v.updateBoat(1.0, 0, 1.0, true);
    try std.testing.expect(v.yaw > yaw_before);
}

test "boat accelerates forward on water" {
    var v = Vehicle.init(.boat, 0, 0, 0);
    v.yaw = 0; // facing +x
    v.updateBoat(1.0, 1.0, 0, true);
    // Should have moved in +x direction
    try std.testing.expect(v.x > 0);
    // No vertical movement on water
    try std.testing.expectApproxEqAbs(@as(f32, 0), v.vy, 0.001);
}

test "boat falls when not on water" {
    var v = Vehicle.init(.boat, 0, 10, 0);
    v.updateBoat(1.0, 0, 0, false);
    // Should have fallen
    try std.testing.expect(v.y < 10.0);
}

test "minecart accelerates on powered rail" {
    var v = Vehicle.init(.minecart, 0, 0, 0);
    v.yaw = 0; // facing +x
    v.updateMinecart(1.0, true, true);
    // Should have speed from powered rail acceleration
    const speed = @sqrt(v.vx * v.vx + v.vz * v.vz);
    try std.testing.expect(speed > 0);
    try std.testing.expect(speed <= Vehicle.MINECART_RAIL_SPEED);
}

test "minecart decelerates on unpowered rail" {
    var v = Vehicle.init(.minecart, 0, 0, 0);
    v.vx = 6.0; // initial speed in +x
    const speed_before: f32 = 6.0;
    v.updateMinecart(1.0, true, false);
    const speed_after = @sqrt(v.vx * v.vx + v.vz * v.vz);
    try std.testing.expect(speed_after < speed_before);
}

test "minecart stops fully from low speed on unpowered rail" {
    var v = Vehicle.init(.minecart, 0, 0, 0);
    v.vx = 0.5; // very slow
    v.updateMinecart(1.0, true, false);
    try std.testing.expectApproxEqAbs(@as(f32, 0), v.vx, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), v.vz, 0.001);
}

test "minecart speed capped at rail speed" {
    var v = Vehicle.init(.minecart, 0, 0, 0);
    v.yaw = 0;
    // Simulate many ticks of powered rail
    for (0..100) |_| {
        v.updateMinecart(0.1, true, true);
    }
    const speed = @sqrt(v.vx * v.vx + v.vz * v.vz);
    try std.testing.expectApproxEqAbs(Vehicle.MINECART_RAIL_SPEED, speed, 0.1);
}

test "minecart falls off rail" {
    var v = Vehicle.init(.minecart, 0, 10, 0);
    v.updateMinecart(1.0, false, false);
    try std.testing.expect(v.y < 10.0);
}

test "remove swaps last entry" {
    var mgr = VehicleManager.init();
    _ = mgr.spawn(.boat, 0, 0, 0);
    _ = mgr.spawn(.minecart, 10, 0, 10);
    _ = mgr.spawn(.boat, 20, 0, 20);

    // Remove index 0 — the boat at (20,0,20) should move to index 0
    mgr.remove(0);
    try std.testing.expectEqual(@as(u32, 2), mgr.count);
    try std.testing.expectApproxEqAbs(@as(f32, 20.0), mgr.vehicles[0].x, 0.001);
}

test "remove last element" {
    var mgr = VehicleManager.init();
    _ = mgr.spawn(.boat, 0, 0, 0);
    mgr.remove(0);
    try std.testing.expectEqual(@as(u32, 0), mgr.count);
}

test "remove out of bounds is no-op" {
    var mgr = VehicleManager.init();
    _ = mgr.spawn(.boat, 0, 0, 0);
    mgr.remove(5);
    try std.testing.expectEqual(@as(u32, 1), mgr.count);
}

test "getNearest finds closest vehicle" {
    var mgr = VehicleManager.init();
    _ = mgr.spawn(.boat, 10, 0, 0);
    _ = mgr.spawn(.minecart, 3, 0, 0);
    _ = mgr.spawn(.boat, 50, 0, 0);

    const nearest = mgr.getNearest(0, 0, 100);
    try std.testing.expectEqual(@as(?u32, 1), nearest);
}

test "getNearest returns null when none in range" {
    var mgr = VehicleManager.init();
    _ = mgr.spawn(.boat, 100, 0, 100);
    try std.testing.expect(mgr.getNearest(0, 0, 5.0) == null);
}

test "getNearest on empty pool returns null" {
    const mgr = VehicleManager.init();
    try std.testing.expect(mgr.getNearest(0, 0, 100) == null);
}

test "manager update ticks all vehicles" {
    var mgr = VehicleManager.init();
    _ = mgr.spawn(.boat, 0, 0, 0);
    _ = mgr.spawn(.minecart, 0, 0, 0);
    mgr.vehicles[1].vx = 4.0; // give the minecart initial speed

    mgr.update(1.0);

    // Boat on water should stay at y=0
    try std.testing.expectApproxEqAbs(@as(f32, 0), mgr.vehicles[0].vy, 0.001);
    // Minecart should have moved (decelerated on default unpowered rail)
    try std.testing.expect(mgr.vehicles[1].x > 0);
}

test "chest and hopper minecart behave as minecart" {
    var chest = Vehicle.init(.chest_minecart, 0, 0, 0);
    chest.yaw = 0;
    chest.updateMinecart(1.0, true, true);
    const chest_speed = @sqrt(chest.vx * chest.vx + chest.vz * chest.vz);
    try std.testing.expect(chest_speed > 0);

    var hopper = Vehicle.init(.hopper_minecart, 0, 0, 0);
    hopper.yaw = 0;
    hopper.updateMinecart(1.0, true, true);
    const hopper_speed = @sqrt(hopper.vx * hopper.vx + hopper.vz * hopper.vz);
    try std.testing.expect(hopper_speed > 0);
}
