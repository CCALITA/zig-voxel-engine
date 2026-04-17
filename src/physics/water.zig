/// Water physics: swimming, oxygen, and drowning mechanics.
/// Tracks whether the player is in water, manages oxygen depletion
/// and recovery, and adjusts movement parameters for underwater physics.
const std = @import("std");

pub const MAX_OXYGEN: f32 = 300.0; // 15 seconds (300 ticks at 20 TPS)
pub const DROWN_DAMAGE: f32 = 2.0; // 1 heart per second
pub const DROWN_INTERVAL: f32 = 1.0;
pub const SWIM_SPEED_MULT: f32 = 0.5;
pub const WATER_GRAVITY: f32 = -5.0; // reduced from normal -20
pub const SWIM_UP_SPEED: f32 = 3.0;

const NORMAL_GRAVITY: f32 = -20.0;
const OXYGEN_DRAIN_RATE: f32 = 1.0; // per second when submerged
const OXYGEN_RECOVER_RATE: f32 = 5.0; // per second when surfaced

pub const WaterState = struct {
    in_water: bool = false,
    submerged: bool = false, // head underwater (for oxygen)
    oxygen: f32 = MAX_OXYGEN,
    drown_timer: f32 = 0.0,

    pub fn init() WaterState {
        return .{};
    }

    /// Check if position is in a water block. The callback checks block type at world coords.
    pub fn updateWaterContact(
        self: *WaterState,
        feet_x: f32,
        feet_y: f32,
        feet_z: f32,
        eye_y: f32,
        isWater: *const fn (i32, i32, i32) bool,
    ) void {
        const bx = floatToBlock(feet_x);
        const bz = floatToBlock(feet_z);
        self.in_water = isWater(bx, floatToBlock(feet_y), bz);
        self.submerged = isWater(bx, floatToBlock(eye_y), bz);
    }

    /// Update oxygen and drowning. Returns damage to apply (0 if not drowning).
    pub fn updateOxygen(self: *WaterState, dt: f32) f32 {
        if (self.submerged) {
            self.oxygen = @max(self.oxygen - OXYGEN_DRAIN_RATE * dt, 0.0);
        } else {
            self.oxygen = @min(self.oxygen + OXYGEN_RECOVER_RATE * dt, MAX_OXYGEN);
            self.drown_timer = 0.0;
            return 0.0;
        }

        if (self.oxygen <= 0.0) {
            self.drown_timer += dt;
            if (self.drown_timer >= DROWN_INTERVAL) {
                self.drown_timer -= DROWN_INTERVAL;
                return DROWN_DAMAGE;
            }
        }

        return 0.0;
    }

    /// Get swim gravity (reduced when in water).
    pub fn getGravity(self: *const WaterState) f32 {
        return if (self.in_water) WATER_GRAVITY else NORMAL_GRAVITY;
    }

    /// Get movement speed multiplier.
    pub fn getSpeedMultiplier(self: *const WaterState) f32 {
        return if (self.in_water) SWIM_SPEED_MULT else 1.0;
    }

    /// Get upward swim velocity when space is pressed in water.
    pub fn getSwimUpSpeed(self: *const WaterState) f32 {
        return if (self.in_water) SWIM_UP_SPEED else 0.0;
    }

    /// Get oxygen as fraction (0.0-1.0) for HUD bubble display.
    pub fn getOxygenFraction(self: *const WaterState) f32 {
        return self.oxygen / MAX_OXYGEN;
    }
};

fn floatToBlock(v: f32) i32 {
    return @intFromFloat(@floor(v));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

fn alwaysWater(_: i32, _: i32, _: i32) bool {
    return true;
}

fn neverWater(_: i32, _: i32, _: i32) bool {
    return false;
}

fn feetOnlyWater(_: i32, y: i32, _: i32) bool {
    // Water at y=0 (feet level), air at y=1 (eye level)
    return y == 0;
}

test "init returns default state" {
    const ws = WaterState.init();
    try std.testing.expect(!ws.in_water);
    try std.testing.expect(!ws.submerged);
    try std.testing.expectApproxEqAbs(MAX_OXYGEN, ws.oxygen, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), ws.drown_timer, 0.001);
}

test "not in water: normal gravity, full speed, full oxygen" {
    var ws = WaterState.init();
    ws.updateWaterContact(0.0, 0.0, 0.0, 1.6, &neverWater);

    try std.testing.expect(!ws.in_water);
    try std.testing.expect(!ws.submerged);
    try std.testing.expectApproxEqAbs(NORMAL_GRAVITY, ws.getGravity(), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), ws.getSpeedMultiplier(), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), ws.getOxygenFraction(), 0.001);

    const dmg = ws.updateOxygen(1.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), dmg, 0.001);
}

test "in water: reduced gravity, reduced speed" {
    var ws = WaterState.init();
    ws.updateWaterContact(0.0, 0.0, 0.0, 1.6, &alwaysWater);

    try std.testing.expect(ws.in_water);
    try std.testing.expectApproxEqAbs(WATER_GRAVITY, ws.getGravity(), 0.001);
    try std.testing.expectApproxEqAbs(SWIM_SPEED_MULT, ws.getSpeedMultiplier(), 0.001);
    try std.testing.expectApproxEqAbs(SWIM_UP_SPEED, ws.getSwimUpSpeed(), 0.001);
}

test "swim up speed is zero when not in water" {
    const ws = WaterState.init();
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), ws.getSwimUpSpeed(), 0.001);
}

test "submerged: oxygen drains" {
    var ws = WaterState.init();
    ws.updateWaterContact(0.0, 0.0, 0.0, 1.6, &alwaysWater);

    // Drain for 5 seconds at 1.0/sec
    const dmg = ws.updateOxygen(5.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), dmg, 0.001);
    try std.testing.expectApproxEqAbs(MAX_OXYGEN - 5.0, ws.oxygen, 0.001);
}

test "oxygen depleted: drowning damage returned" {
    var ws = WaterState.init();
    ws.updateWaterContact(0.0, 0.0, 0.0, 1.6, &alwaysWater);
    ws.oxygen = 0.0; // fully depleted

    // Accumulate 1.0 second of drown timer -> should trigger damage
    const dmg = ws.updateOxygen(1.0);
    try std.testing.expectApproxEqAbs(DROWN_DAMAGE, dmg, 0.001);
}

test "oxygen depleted: no damage before interval" {
    var ws = WaterState.init();
    ws.updateWaterContact(0.0, 0.0, 0.0, 1.6, &alwaysWater);
    ws.oxygen = 0.0;

    const dmg = ws.updateOxygen(0.5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), dmg, 0.001);
}

test "surface: oxygen recovers" {
    var ws = WaterState.init();
    ws.oxygen = 100.0;
    ws.submerged = false;
    ws.in_water = false;

    // Recover for 2 seconds at 5.0/sec -> gain 10
    const dmg = ws.updateOxygen(2.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), dmg, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 110.0), ws.oxygen, 0.001);
}

test "oxygen does not exceed maximum" {
    var ws = WaterState.init();
    ws.oxygen = MAX_OXYGEN - 1.0;
    ws.submerged = false;

    _ = ws.updateOxygen(10.0); // would add 50 but capped
    try std.testing.expectApproxEqAbs(MAX_OXYGEN, ws.oxygen, 0.001);
}

test "oxygen does not go below zero" {
    var ws = WaterState.init();
    ws.updateWaterContact(0.0, 0.0, 0.0, 1.6, &alwaysWater);
    ws.oxygen = 0.5;

    _ = ws.updateOxygen(10.0); // would drain 10 but floored at 0
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), ws.oxygen, 0.001);
}

test "speed multiplier correct values" {
    var ws = WaterState.init();

    // Out of water
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), ws.getSpeedMultiplier(), 0.001);

    // In water
    ws.in_water = true;
    try std.testing.expectApproxEqAbs(SWIM_SPEED_MULT, ws.getSpeedMultiplier(), 0.001);
}

test "feet in water but head above: in_water true, submerged false" {
    var ws = WaterState.init();
    ws.updateWaterContact(0.5, 0.5, 0.5, 1.6, &feetOnlyWater);

    try std.testing.expect(ws.in_water);
    try std.testing.expect(!ws.submerged);

    // Gravity and speed should be water values
    try std.testing.expectApproxEqAbs(WATER_GRAVITY, ws.getGravity(), 0.001);
    try std.testing.expectApproxEqAbs(SWIM_SPEED_MULT, ws.getSpeedMultiplier(), 0.001);

    // Oxygen should recover (not submerged)
    ws.oxygen = 200.0;
    const dmg = ws.updateOxygen(1.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), dmg, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 205.0), ws.oxygen, 0.001);
}

test "drown timer resets on surfacing" {
    var ws = WaterState.init();
    ws.submerged = true;
    ws.oxygen = 0.0;
    ws.drown_timer = 0.5;

    // Surface
    ws.submerged = false;
    _ = ws.updateOxygen(0.1);

    try std.testing.expectApproxEqAbs(@as(f32, 0.0), ws.drown_timer, 0.001);
}

test "floatToBlock conversion" {
    try std.testing.expectEqual(@as(i32, 0), floatToBlock(0.5));
    try std.testing.expectEqual(@as(i32, -1), floatToBlock(-0.1));
    try std.testing.expectEqual(@as(i32, 3), floatToBlock(3.9));
    try std.testing.expectEqual(@as(i32, -2), floatToBlock(-1.5));
}
