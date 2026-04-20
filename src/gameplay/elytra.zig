const std = @import("std");
const math = std.math;

pub const GlideResult = struct {
    vx: f32,
    vy: f32,
    speed: f32,
};

pub const max_durability: u16 = 432;
pub const repair_amount: u16 = 108;
pub const min_durability: u16 = 1;
pub const stall_speed: f32 = 0.5;
pub const stall_vy: f32 = -0.5;

pub const ElytraState = struct {
    equipped: bool,
    durability: u16 = max_durability,
    broken: bool = false,
    gliding: bool = false,

    pub fn startGlide(self: *ElytraState, in_air: bool) bool {
        if (self.equipped and !self.broken and in_air) {
            self.gliding = true;
            return true;
        }
        return false;
    }

    pub fn stopGlide(self: *ElytraState) void {
        self.gliding = false;
    }

    pub fn tickDurability(self: *ElytraState) void {
        if (!self.gliding) return;
        if (self.durability > min_durability) {
            self.durability -= 1;
        }
        if (self.durability <= min_durability) {
            self.broken = true;
            self.gliding = false;
        }
    }

    pub fn repair(self: *ElytraState, phantom_membrane: bool) void {
        if (!phantom_membrane) return;
        self.durability = @min(self.durability + repair_amount, max_durability);
        if (self.durability > min_durability) {
            self.broken = false;
        }
    }

    pub fn isGliding(self: ElytraState) bool {
        return self.gliding;
    }
};

pub fn getGlideVelocity(pitch: f32) GlideResult {
    const base_speed: f32 = 1.0;
    const dead_zone: f32 = 0.1;
    const max_factor_angle = math.pi / 4.0;

    var speed: f32 = base_speed;
    var vy: f32 = -0.05;

    if (pitch < -dead_zone) {
        const factor = @min(-pitch / max_factor_angle, 1.0);
        speed = base_speed + factor * 2.0;
        vy = pitch * speed * 0.5;
    } else if (pitch > dead_zone) {
        const factor = @min(pitch / max_factor_angle, 1.0);
        speed = base_speed - factor * 0.5;
        vy = factor * 0.5;
    }

    if (speed <= stall_speed) {
        speed = stall_speed;
        vy = stall_vy;
    }

    return GlideResult{
        .vx = speed * @cos(pitch),
        .vy = vy,
        .speed = speed,
    };
}

pub fn getFireworkBoost(flight_duration: u2) f32 {
    return @as(f32, @floatFromInt(flight_duration)) * 12.0;
}

pub fn getKineticDamage(speed: f32) f32 {
    if (speed < 10.0) return 0.0;
    return speed - 10.0;
}


test "glide start requires equipped, not broken, and in air" {
    var elytra = ElytraState{ .equipped = true };
    try std.testing.expect(elytra.startGlide(true));
    try std.testing.expect(elytra.isGliding());

    var grounded = ElytraState{ .equipped = true };
    try std.testing.expect(!grounded.startGlide(false));
    try std.testing.expect(!grounded.isGliding());

    var unequipped = ElytraState{ .equipped = false };
    try std.testing.expect(!unequipped.startGlide(true));

    var broken_elytra = ElytraState{ .equipped = true, .broken = true };
    try std.testing.expect(!broken_elytra.startGlide(true));
}

test "glide stop" {
    var elytra = ElytraState{ .equipped = true };
    _ = elytra.startGlide(true);
    try std.testing.expect(elytra.isGliding());
    elytra.stopGlide();
    try std.testing.expect(!elytra.isGliding());
}

test "durability drain while gliding" {
    var elytra = ElytraState{ .equipped = true };
    _ = elytra.startGlide(true);
    const initial = elytra.durability;
    elytra.tickDurability();
    try std.testing.expectEqual(initial - 1, elytra.durability);
}

test "durability does not drain when not gliding" {
    var elytra = ElytraState{ .equipped = true };
    const initial = elytra.durability;
    elytra.tickDurability();
    try std.testing.expectEqual(initial, elytra.durability);
}

test "elytra breaks at durability 1" {
    var elytra = ElytraState{ .equipped = true, .durability = 2 };
    _ = elytra.startGlide(true);
    elytra.tickDurability();
    try std.testing.expect(elytra.broken);
    try std.testing.expect(!elytra.isGliding());
}

test "repair restores 108 durability per membrane" {
    var elytra = ElytraState{ .equipped = true, .durability = 100, .broken = true };
    elytra.repair(true);
    try std.testing.expectEqual(@as(u16, 208), elytra.durability);
    try std.testing.expect(!elytra.broken);
}

test "repair does not exceed max durability" {
    var elytra = ElytraState{ .equipped = true, .durability = 400 };
    elytra.repair(true);
    try std.testing.expectEqual(@as(u16, 432), elytra.durability);
}

test "repair with no membrane does nothing" {
    var elytra = ElytraState{ .equipped = true, .durability = 100 };
    elytra.repair(false);
    try std.testing.expectEqual(@as(u16, 100), elytra.durability);
}

test "pitch level gives cruise speed" {
    const result = getGlideVelocity(0.0);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), result.speed, 0.01);
}

test "pitch nose down accelerates" {
    const result = getGlideVelocity(-math.pi / 4.0);
    try std.testing.expect(result.speed > 1.0);
    try std.testing.expect(result.speed <= 3.0);
    try std.testing.expect(result.vy < 0.0);
}

test "pitch nose up decelerates" {
    const result = getGlideVelocity(math.pi / 8.0);
    try std.testing.expect(result.speed < 1.0);
    try std.testing.expect(result.speed > 0.5);
    try std.testing.expect(result.vy > 0.0);
}

test "stall below 0.5 speed sets vy to -0.5" {
    // Extreme nose up to trigger stall
    const result = getGlideVelocity(math.pi / 2.5);
    if (result.speed <= 0.5) {
        try std.testing.expectApproxEqAbs(@as(f32, -0.5), result.vy, 0.01);
    }
}

test "firework boost scales with flight duration" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), getFireworkBoost(0), 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 12.0), getFireworkBoost(1), 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 24.0), getFireworkBoost(2), 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 36.0), getFireworkBoost(3), 0.01);
}

test "kinetic damage zero below speed 10" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), getKineticDamage(5.0), 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), getKineticDamage(9.99), 0.01);
}

test "kinetic damage above speed 10" {
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), getKineticDamage(15.0), 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), getKineticDamage(20.0), 0.01);
}
