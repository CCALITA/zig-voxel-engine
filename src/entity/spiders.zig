const std = @import("std");

pub const JumpAttack = struct {
    damage: f32,
    leap_velocity: f32,
};

pub const PoisonBite = struct {
    damage: f32,
    poison_seconds: f32,
};

pub const Difficulty = enum {
    normal,
    hard,
};

pub const SpiderEntity = struct {
    x: f32,
    y: f32,
    z: f32,
    health: f32 = 16,
    climbing: bool = false,
    attack_cooldown: f32 = 0,
    is_day: bool,

    pub fn update(self: *SpiderEntity, dt: f32, is_day: bool, target_dist: f32) void {
        self.is_day = is_day;
        if (self.attack_cooldown > 0) {
            self.attack_cooldown -= dt;
            if (self.attack_cooldown < 0) self.attack_cooldown = 0;
        }
        _ = target_dist;
    }

    pub fn isHostile(self: SpiderEntity) bool {
        return !self.is_day;
    }

    pub fn climbWall(self: *SpiderEntity) void {
        self.climbing = true;
    }

    pub fn jumpAttack(self: *SpiderEntity) ?JumpAttack {
        if (self.attack_cooldown > 0) return null;
        self.attack_cooldown = 1.0;
        return JumpAttack{
            .damage = 2.5,
            .leap_velocity = 0.4,
        };
    }

    pub fn getWidth() f32 {
        return 1.4;
    }
};

pub const CaveSpiderEntity = struct {
    x: f32,
    y: f32,
    z: f32,
    health: f32 = 12,
    attack_cooldown: f32 = 0,
    poison_duration: f32 = 7.0,

    pub fn poisonBite(self: *CaveSpiderEntity, difficulty: Difficulty) ?PoisonBite {
        if (self.attack_cooldown > 0) return null;
        self.attack_cooldown = 1.0;
        const poison_seconds: f32 = switch (difficulty) {
            .normal => self.poison_duration,
            .hard => 15.0,
        };
        return PoisonBite{
            .damage = 2.0,
            .poison_seconds = poison_seconds,
        };
    }

    pub fn getWidth() f32 {
        return 0.7;
    }

    pub fn spawnsInMineshaft() bool {
        return true;
    }
};

test "spider is hostile at night" {
    const spider = SpiderEntity{ .x = 0, .y = 0, .z = 0, .is_day = false };
    try std.testing.expect(spider.isHostile());
}

test "spider is neutral during day" {
    const spider = SpiderEntity{ .x = 0, .y = 0, .z = 0, .is_day = true };
    try std.testing.expect(!spider.isHostile());
}

test "spider wall climbing" {
    var spider = SpiderEntity{ .x = 0, .y = 0, .z = 0, .is_day = false };
    try std.testing.expect(!spider.climbing);
    spider.climbWall();
    try std.testing.expect(spider.climbing);
}

test "cave spider poison bite on normal" {
    var cave_spider = CaveSpiderEntity{ .x = 0, .y = 0, .z = 0 };
    const bite = cave_spider.poisonBite(.normal);
    try std.testing.expect(bite != null);
    try std.testing.expectEqual(@as(f32, 2.0), bite.?.damage);
    try std.testing.expectEqual(@as(f32, 7.0), bite.?.poison_seconds);
}

test "cave spider poison bite on hard" {
    var cave_spider = CaveSpiderEntity{ .x = 0, .y = 0, .z = 0 };
    const bite = cave_spider.poisonBite(.hard);
    try std.testing.expect(bite != null);
    try std.testing.expectEqual(@as(f32, 15.0), bite.?.poison_seconds);
}

test "size difference between spider and cave spider" {
    try std.testing.expect(SpiderEntity.getWidth() > CaveSpiderEntity.getWidth());
    try std.testing.expectEqual(@as(f32, 1.4), SpiderEntity.getWidth());
    try std.testing.expectEqual(@as(f32, 0.7), CaveSpiderEntity.getWidth());
}

test "cave spider spawns in mineshaft" {
    try std.testing.expect(CaveSpiderEntity.spawnsInMineshaft());
}
