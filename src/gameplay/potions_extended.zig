/// Extended potion system: splash/lingering potions, tipped arrows, and missing effects.
const std = @import("std");

pub const ExtendedEffect = enum(u8) {
    slow_falling,
    wither,
    levitation,
    bad_omen,
    hero_of_village,
    conduit_power,
    turtle_master,
    luck,
    bad_luck,
    darkness,
    weakness,
    dolphins_grace,
};

pub const EffectInstance = struct {
    effect: ExtendedEffect,
    level: u8 = 0,
    duration_ticks: u32,
    remaining_ticks: u32,

    pub fn tick(self: *EffectInstance) bool {
        if (self.remaining_ticks == 0) return false;
        self.remaining_ticks -= 1;
        return self.remaining_ticks > 0;
    }

    pub fn getMultiplier(self: *const EffectInstance) f32 {
        return switch (self.effect) {
            .slow_falling => 0.01 * @as(f32, @floatFromInt(self.level + 1)),
            .levitation => 0.9 * @as(f32, @floatFromInt(self.level + 1)),
            .weakness => -4.0,
            .turtle_master => if (self.level == 0) 0.4 else 0.6,
            .luck => 1.0 + @as(f32, @floatFromInt(self.level)),
            .bad_luck => -1.0 * @as(f32, @floatFromInt(self.level + 1)),
            else => 1.0,
        };
    }
};

pub const PotionType = enum(u8) { normal, splash, lingering };

pub const PotionVariant = enum(u8) { base, extended, enhanced };

pub const ThrowablePotion = struct {
    x: f32,
    y: f32,
    z: f32,
    vx: f32,
    vy: f32,
    vz: f32,
    effect: ExtendedEffect,
    level: u8,
    duration_ticks: u32,
    potion_type: PotionType,
    alive: bool = true,

    pub fn update(self: *ThrowablePotion, dt: f32) void {
        if (!self.alive) return;
        self.x += self.vx * dt;
        self.y += self.vy * dt;
        self.z += self.vz * dt;
        self.vy -= 20.0 * dt; // gravity
        if (self.y < 0) self.alive = false;
    }

    pub fn getEffectRadius(_: *const ThrowablePotion) f32 {
        return 4.0;
    }

    pub fn getDurationAtDistance(self: *const ThrowablePotion, dist: f32) u32 {
        const radius = self.getEffectRadius();
        if (dist >= radius) return 0;
        const factor = 1.0 - (dist / radius) * 0.25;
        return @intFromFloat(@as(f32, @floatFromInt(self.duration_ticks)) * factor);
    }
};

pub const EffectCloud = struct {
    x: f32,
    y: f32,
    z: f32,
    effect: ExtendedEffect,
    level: u8,
    duration_ticks: u32,
    radius: f32,
    initial_radius: f32,
    remaining_ticks: u32,
    reapply_cooldown: u32 = 0,

    pub fn init(x: f32, y: f32, z: f32, effect: ExtendedEffect, level: u8, duration: u32) EffectCloud {
        return .{
            .x = x, .y = y, .z = z,
            .effect = effect, .level = level,
            .duration_ticks = duration, .radius = 3.0,
            .initial_radius = 3.0, .remaining_ticks = 600,
        };
    }

    pub fn update(self: *EffectCloud) bool {
        if (self.remaining_ticks == 0) return false;
        self.remaining_ticks -= 1;
        self.radius = self.initial_radius * (@as(f32, @floatFromInt(self.remaining_ticks)) / 600.0);
        if (self.reapply_cooldown > 0) self.reapply_cooldown -= 1;
        return self.remaining_ticks > 0;
    }

    pub fn shouldApply(self: *EffectCloud) bool {
        return self.reapply_cooldown == 0;
    }

    pub fn markApplied(self: *EffectCloud) void {
        self.reapply_cooldown = 10; // 0.5s at 20tps
    }

    pub fn isInRange(self: *const EffectCloud, px: f32, py: f32, pz: f32) bool {
        const dx = px - self.x;
        const dy = py - self.y;
        const dz = pz - self.z;
        return dx * dx + dy * dy + dz * dz <= self.radius * self.radius;
    }
};

pub const TippedArrow = struct {
    effect: ExtendedEffect,
    level: u8,
    base_duration: u32,

    pub fn getAppliedDuration(self: *const TippedArrow) u32 {
        return self.base_duration / 8;
    }
};

pub fn getExtendedDuration(base: u32, variant: PotionVariant) u32 {
    return switch (variant) {
        .base => base,
        .extended => base * 8 / 3,
        .enhanced => base / 2,
    };
}

pub fn getEnhancedLevel(base_level: u8, variant: PotionVariant) u8 {
    return switch (variant) {
        .enhanced => base_level + 1,
        else => base_level,
    };
}

pub const DragonsBreath = struct {
    count: u8 = 0,

    pub fn collect(self: *DragonsBreath) void {
        if (self.count < 64) self.count += 1;
    }

    pub fn craftLingering(self: *DragonsBreath) bool {
        if (self.count == 0) return false;
        self.count -= 1;
        return true;
    }
};

pub const EffectDamagePerTick = struct {
    pub fn getDamage(effect: ExtendedEffect, level: u8) f32 {
        return switch (effect) {
            .wither => 0.5 * @as(f32, @floatFromInt(level + 1)),
            .weakness => 0.0,
            .bad_omen => 0.0,
            else => 0.0,
        };
    }

    pub fn getSpeedModifier(effect: ExtendedEffect, level: u8) f32 {
        return switch (effect) {
            .slow_falling => -0.07,
            .levitation => 0.9 * @as(f32, @floatFromInt(level + 1)),
            .turtle_master => -0.6,
            .dolphins_grace => 3.0,
            else => 0.0,
        };
    }
};

test "throwable potion update" {
    var p = ThrowablePotion{
        .x = 0, .y = 10, .z = 0,
        .vx = 5, .vy = 10, .vz = 0,
        .effect = .weakness, .level = 0,
        .duration_ticks = 1800, .potion_type = .splash,
    };
    p.update(0.05);
    try std.testing.expect(p.y > 10);
    try std.testing.expect(p.alive);
}

test "effect cloud shrinks" {
    var cloud = EffectCloud.init(0, 0, 0, .darkness, 0, 200);
    _ = cloud.update();
    try std.testing.expect(cloud.radius < cloud.initial_radius);
}

test "tipped arrow duration" {
    const arrow = TippedArrow{ .effect = .slow_falling, .level = 0, .base_duration = 1800 };
    try std.testing.expectEqual(@as(u32, 225), arrow.getAppliedDuration());
}

test "extended variant duration" {
    const base: u32 = 3600;
    try std.testing.expectEqual(@as(u32, 9600), getExtendedDuration(base, .extended));
    try std.testing.expectEqual(@as(u32, 1800), getExtendedDuration(base, .enhanced));
}
