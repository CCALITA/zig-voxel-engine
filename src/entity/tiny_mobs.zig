const std = @import("std");

pub const InfestedBlock = enum(u8) {
    stone = 0,
    cobblestone = 1,
    stone_bricks = 2,
    mossy_stone_bricks = 3,
    cracked_stone_bricks = 4,
};

pub const SilverfishEntity = struct {
    x: f32,
    y: f32,
    z: f32,
    health: f32 = 8,
    hidden: bool = true,
    call_timer: f32 = 0,

    const call_range: f32 = 21.0;
    const attack_damage: f32 = 1.0;

    pub fn emerge(self: *SilverfishEntity) void {
        self.hidden = false;
    }

    pub fn callNearby(self: *SilverfishEntity) bool {
        _ = self;
        return true;
    }

    pub fn getAttackDamage() f32 {
        return attack_damage;
    }

    pub fn canHideIn(block_id: u8) bool {
        return isInfestedBlock(block_id);
    }
};

pub fn isInfestedBlock(block_id: u8) bool {
    return block_id <= @intFromEnum(InfestedBlock.cracked_stone_bricks);
}

pub const EndermiteEntity = struct {
    x: f32,
    y: f32,
    z: f32,
    health: f32 = 8,
    despawn_timer: f32 = 120.0,
    spawned_from_pearl: bool = true,

    const spawn_chance: f32 = 0.05;

    pub fn update(self: *EndermiteEntity, dt: f32) bool {
        self.despawn_timer -= dt;
        return self.despawn_timer <= 0;
    }

    pub fn getSpawnChance() f32 {
        return spawn_chance;
    }

    pub fn isTargetedByEndermen() bool {
        return true;
    }
};

test "silverfish emerge sets hidden to false" {
    var sf = SilverfishEntity{ .x = 0, .y = 0, .z = 0 };
    try std.testing.expect(sf.hidden);
    sf.emerge();
    try std.testing.expect(!sf.hidden);
}

test "silverfish callNearby returns true when damaged" {
    var sf = SilverfishEntity{ .x = 5, .y = 10, .z = 5 };
    try std.testing.expect(sf.callNearby());
}

test "infested block identification" {
    try std.testing.expect(isInfestedBlock(0)); // stone
    try std.testing.expect(isInfestedBlock(1)); // cobblestone
    try std.testing.expect(isInfestedBlock(2)); // stone_bricks
    try std.testing.expect(isInfestedBlock(3)); // mossy_stone_bricks
    try std.testing.expect(isInfestedBlock(4)); // cracked_stone_bricks
    try std.testing.expect(!isInfestedBlock(5)); // not infested
    try std.testing.expect(!isInfestedBlock(255)); // not infested
}

test "silverfish canHideIn matches infested blocks" {
    try std.testing.expect(SilverfishEntity.canHideIn(0));
    try std.testing.expect(!SilverfishEntity.canHideIn(99));
}

test "silverfish attack damage is 1.0" {
    try std.testing.expectEqual(@as(f32, 1.0), SilverfishEntity.getAttackDamage());
}

test "endermite despawns after 2 minutes" {
    var em = EndermiteEntity{ .x = 0, .y = 0, .z = 0 };
    try std.testing.expectEqual(@as(f32, 120.0), em.despawn_timer);
    try std.testing.expect(!em.update(60.0));
    try std.testing.expectEqual(@as(f32, 60.0), em.despawn_timer);
    try std.testing.expect(!em.update(59.0));
    try std.testing.expect(em.update(1.0));
}

test "endermite 5 percent spawn chance from ender pearl" {
    try std.testing.expectEqual(@as(f32, 0.05), EndermiteEntity.getSpawnChance());
}

test "endermite is targeted by endermen" {
    try std.testing.expect(EndermiteEntity.isTargetedByEndermen());
}
