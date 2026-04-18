const std = @import("std");

pub const WardenState = enum {
    emerging,
    idle,
    sniffing,
    roaring,
    attacking,
    digging,
};

pub const SonicBoomResult = struct {
    hit: bool,
    damage: f32,
    ignores_armor: bool,

    const miss = SonicBoomResult{ .hit = false, .damage = 0, .ignores_armor = false };
};

pub const WardenEntity = struct {
    x: f32,
    y: f32,
    z: f32,
    health: f32 = 500,
    anger: u8 = 0,
    anger_target_x: ?f32 = null,
    anger_target_y: ?f32 = null,
    anger_target_z: ?f32 = null,
    state: WardenState = .emerging,
    sonic_cooldown: f32 = 0,
    darkness_timer: f32 = 0,

    const max_anger: u8 = 150;
    const sonic_boom_damage: f32 = 10;
    const sonic_boom_range: f32 = 5;
    const sonic_boom_cooldown: f32 = 2;
    const anger_threshold: u8 = 80;
    const attack_threshold: u8 = 150;
    const darkness_radius: f32 = 20;

    pub fn init(x: f32, y: f32, z: f32) WardenEntity {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn update(
        self: *WardenEntity,
        dt: f32,
        vibration_x: ?f32,
        vibration_y: ?f32,
        vibration_z: ?f32,
        smell_x: ?f32,
        smell_y: ?f32,
        smell_z: ?f32,
    ) void {
        if (self.sonic_cooldown > 0) {
            self.sonic_cooldown = @max(0, self.sonic_cooldown - dt);
        }

        if (self.darkness_timer > 0) {
            self.darkness_timer = @max(0, self.darkness_timer - dt);
        }

        if (vibration_x) |vx| {
            if (vibration_y) |vy| {
                if (vibration_z) |vz| {
                    self.anger_target_x = vx;
                    self.anger_target_y = vy;
                    self.anger_target_z = vz;
                    self.addAnger(35);
                }
            }
        }

        if (smell_x) |sx| {
            if (smell_y) |sy| {
                if (smell_z) |sz| {
                    self.anger_target_x = sx;
                    self.anger_target_y = sy;
                    self.anger_target_z = sz;
                }
            }
        }

        if (self.shouldAttack()) {
            self.state = .attacking;
            self.darkness_timer = 2;
        } else if (self.isAngry()) {
            self.state = .roaring;
            self.darkness_timer = 1;
        } else if (vibration_x != null) {
            self.state = .sniffing;
        } else if (self.state != .emerging and self.state != .digging) {
            self.state = .idle;
        }
    }

    pub fn addAnger(self: *WardenEntity, amount: u8) void {
        self.anger = @min(self.anger +| amount, max_anger);
    }

    pub fn sonicBoom(self: *WardenEntity) SonicBoomResult {
        if (self.sonic_cooldown > 0) return SonicBoomResult.miss;

        const tx = self.anger_target_x orelse return SonicBoomResult.miss;
        const ty = self.anger_target_y orelse return SonicBoomResult.miss;
        const tz = self.anger_target_z orelse return SonicBoomResult.miss;

        const dx = tx - self.x;
        const dy = ty - self.y;
        const dz = tz - self.z;
        const dist = @sqrt(dx * dx + dy * dy + dz * dz);

        if (dist > sonic_boom_range) return SonicBoomResult.miss;

        self.sonic_cooldown = sonic_boom_cooldown;
        return .{ .hit = true, .damage = sonic_boom_damage, .ignores_armor = true };
    }

    pub fn isAngry(self: WardenEntity) bool {
        return self.anger > anger_threshold;
    }

    pub fn shouldAttack(self: WardenEntity) bool {
        return self.anger >= attack_threshold;
    }

    pub fn getDarknessRadius(self: WardenEntity) f32 {
        return if (self.isAngry()) darkness_radius else 0;
    }
};

test "anger accumulation from vibration" {
    var warden = WardenEntity.init(0, 0, 0);
    try std.testing.expectEqual(@as(u8, 0), warden.anger);

    warden.addAnger(35);
    try std.testing.expectEqual(@as(u8, 35), warden.anger);

    warden.addAnger(35);
    try std.testing.expectEqual(@as(u8, 70), warden.anger);
}

test "anger accumulation from projectile" {
    var warden = WardenEntity.init(0, 0, 0);

    warden.addAnger(10);
    try std.testing.expectEqual(@as(u8, 10), warden.anger);
}

test "anger accumulation from touch" {
    var warden = WardenEntity.init(0, 0, 0);

    warden.addAnger(100);
    try std.testing.expectEqual(@as(u8, 100), warden.anger);
}

test "anger caps at max 150" {
    var warden = WardenEntity.init(0, 0, 0);

    warden.addAnger(100);
    warden.addAnger(100);
    try std.testing.expectEqual(@as(u8, 150), warden.anger);
}

test "sonic boom deals 10 damage ignoring armor" {
    var warden = WardenEntity.init(0, 0, 0);
    warden.anger_target_x = 3;
    warden.anger_target_y = 0;
    warden.anger_target_z = 0;

    const result = warden.sonicBoom();
    try std.testing.expect(result.hit);
    try std.testing.expectEqual(@as(f32, 10), result.damage);
    try std.testing.expect(result.ignores_armor);
}

test "sonic boom respects 2s cooldown" {
    var warden = WardenEntity.init(0, 0, 0);
    warden.anger_target_x = 1;
    warden.anger_target_y = 0;
    warden.anger_target_z = 0;

    const first = warden.sonicBoom();
    try std.testing.expect(first.hit);

    const second = warden.sonicBoom();
    try std.testing.expect(!second.hit);
    try std.testing.expectEqual(@as(f32, 0), second.damage);
}

test "sonic boom out of range misses" {
    var warden = WardenEntity.init(0, 0, 0);
    warden.anger_target_x = 10;
    warden.anger_target_y = 0;
    warden.anger_target_z = 0;

    const result = warden.sonicBoom();
    try std.testing.expect(!result.hit);
}

test "isAngry threshold at 80" {
    var warden = WardenEntity.init(0, 0, 0);
    try std.testing.expect(!warden.isAngry());

    warden.anger = 80;
    try std.testing.expect(!warden.isAngry());

    warden.anger = 81;
    try std.testing.expect(warden.isAngry());
}

test "shouldAttack threshold at 150" {
    var warden = WardenEntity.init(0, 0, 0);
    try std.testing.expect(!warden.shouldAttack());

    warden.anger = 149;
    try std.testing.expect(!warden.shouldAttack());

    warden.anger = 150;
    try std.testing.expect(warden.shouldAttack());
}

test "darkness radius is 20 when angry" {
    var warden = WardenEntity.init(0, 0, 0);
    try std.testing.expectEqual(@as(f32, 0), warden.getDarknessRadius());

    warden.anger = 81;
    try std.testing.expectEqual(@as(f32, 20), warden.getDarknessRadius());
}

test "update processes vibration and transitions state" {
    var warden = WardenEntity.init(0, 0, 0);
    warden.state = .idle;

    warden.update(0.016, 5, 0, 5, null, null, null);

    try std.testing.expectEqual(@as(u8, 35), warden.anger);
    try std.testing.expectEqual(@as(?f32, 5), warden.anger_target_x);
    try std.testing.expectEqual(@as(?f32, 5), warden.anger_target_z);
}

test "update decrements sonic cooldown" {
    var warden = WardenEntity.init(0, 0, 0);
    warden.sonic_cooldown = 2;
    warden.state = .idle;

    warden.update(0.5, null, null, null, null, null, null);

    try std.testing.expectEqual(@as(f32, 1.5), warden.sonic_cooldown);
}

test "sonic boom with no target returns miss" {
    var warden = WardenEntity.init(0, 0, 0);

    const result = warden.sonicBoom();
    try std.testing.expect(!result.hit);
}
