const std = @import("std");

pub const BlockResult = struct {
    blocked: bool,
    knockback: f32,
    damage_taken: f32,
};

pub const ShieldState = struct {
    blocking: bool = false,
    warmup_timer: f32 = 0,
    cooldown: f32 = 0,
    disabled: bool = false,

    const warmup_duration: f32 = 0.25;
    const disable_duration: f32 = 5.0;

    pub fn startBlocking(self: *ShieldState) void {
        if (self.disabled or self.cooldown > 0) return;
        self.blocking = true;
        self.warmup_timer = warmup_duration;
    }

    pub fn stopBlocking(self: *ShieldState) void {
        self.blocking = false;
        self.warmup_timer = 0;
    }

    pub fn update(self: *ShieldState, dt: f32) void {
        self.warmup_timer = @max(self.warmup_timer - dt, 0.0);
        if (self.cooldown > 0) {
            self.cooldown = @max(self.cooldown - dt, 0.0);
            if (self.cooldown == 0) self.disabled = false;
        }
    }

    pub fn isActivelyBlocking(self: ShieldState) bool {
        return self.blocking and self.warmup_timer <= 0 and !self.disabled;
    }

    pub fn blockAttack(self: *ShieldState, damage: f32, from_front: bool) BlockResult {
        if (!self.isActivelyBlocking() or !from_front) {
            return BlockResult{
                .blocked = false,
                .knockback = 0,
                .damage_taken = damage,
            };
        }
        return BlockResult{
            .blocked = true,
            .knockback = 0.5,
            .damage_taken = 0,
        };
    }

    pub fn disableFromAxe(self: *ShieldState) void {
        self.disabled = true;
        self.blocking = false;
        self.warmup_timer = 0;
        self.cooldown = disable_duration;
    }

    pub fn canBlockProjectile(self: ShieldState, angle: f32) bool {
        if (!self.isActivelyBlocking()) return false;
        return angle < std.math.pi / 2.0;
    }
};

test "warmup delay prevents immediate blocking" {
    var shield = ShieldState{};
    shield.startBlocking();

    try std.testing.expect(!shield.isActivelyBlocking());

    shield.update(0.25);
    try std.testing.expect(shield.isActivelyBlocking());
}

test "full block from front negates damage" {
    var shield = ShieldState{};
    shield.startBlocking();
    shield.update(0.25);

    const result = shield.blockAttack(10.0, true);
    try std.testing.expect(result.blocked);
    try std.testing.expectEqual(@as(f32, 0), result.damage_taken);
}

test "no block from behind" {
    var shield = ShieldState{};
    shield.startBlocking();
    shield.update(0.25);

    const result = shield.blockAttack(10.0, false);
    try std.testing.expect(!result.blocked);
    try std.testing.expectEqual(@as(f32, 10.0), result.damage_taken);
}

test "axe disables shield for 5 seconds" {
    var shield = ShieldState{};
    shield.startBlocking();
    shield.update(0.25);
    try std.testing.expect(shield.isActivelyBlocking());

    shield.disableFromAxe();
    try std.testing.expect(!shield.isActivelyBlocking());
    try std.testing.expect(shield.disabled);

    shield.update(4.9);
    try std.testing.expect(shield.disabled);

    shield.update(0.2);
    try std.testing.expect(!shield.disabled);
}

test "projectile angle check blocks front 180 degrees" {
    var shield = ShieldState{};
    shield.startBlocking();
    shield.update(0.25);

    try std.testing.expect(shield.canBlockProjectile(0.0));
    try std.testing.expect(shield.canBlockProjectile(1.0));
    try std.testing.expect(!shield.canBlockProjectile(std.math.pi / 2.0));
    try std.testing.expect(!shield.canBlockProjectile(std.math.pi));
}

test "knockback applied on successful block" {
    var shield = ShieldState{};
    shield.startBlocking();
    shield.update(0.25);

    const result = shield.blockAttack(8.0, true);
    try std.testing.expect(result.blocked);
    try std.testing.expect(result.knockback > 0);
}
