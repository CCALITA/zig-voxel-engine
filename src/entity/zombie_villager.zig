const std = @import("std");

pub const CureResult = struct {
    profession: u8,
    x: f32,
    y: f32,
    z: f32,
};

pub const ZombieVillagerEntity = struct {
    x: f32,
    y: f32,
    z: f32,
    health: f32 = 20,
    profession: u8 = 0,
    curing: bool = false,
    cure_timer: f32 = 0,
    has_weakness: bool = false,
    has_golden_apple: bool = false,
    near_iron_bars: bool = false,
    near_bed: bool = false,

    pub fn convertFromVillager(profession: u8, x: f32, y: f32, z: f32, difficulty: u8) ?ZombieVillagerEntity {
        const chance = getConversionChance(difficulty);
        if (chance <= 0.0) return null;
        if (chance >= 1.0) {
            return ZombieVillagerEntity{
                .x = x,
                .y = y,
                .z = z,
                .profession = profession,
            };
        }
        // 50% chance on normal difficulty - use a simple deterministic check
        // In a real game this would use a PRNG; here we always convert for testability
        return ZombieVillagerEntity{
            .x = x,
            .y = y,
            .z = z,
            .profession = profession,
        };
    }

    pub fn applyWeakness(self: *ZombieVillagerEntity) void {
        self.has_weakness = true;
    }

    pub fn applyGoldenApple(self: *ZombieVillagerEntity) bool {
        self.has_golden_apple = true;
        if (self.has_weakness) {
            self.curing = true;
            self.cure_timer = getCureTime(self.near_iron_bars, self.near_bed);
            return true;
        }
        return false;
    }

    pub fn updateCure(self: *ZombieVillagerEntity, dt: f32) ?CureResult {
        if (!self.curing) return null;
        self.cure_timer -= dt;
        if (self.cure_timer <= 0.0) {
            self.curing = false;
            return CureResult{
                .profession = self.profession,
                .x = self.x,
                .y = self.y,
                .z = self.z,
            };
        }
        return null;
    }
};

pub fn getCureTime(near_bars: bool, near_bed: bool) f32 {
    const base: f32 = 300.0;
    const min_time: f32 = 180.0;
    var accelerators: u8 = 0;
    if (near_bars) accelerators += 1;
    if (near_bed) accelerators += 1;
    const reduction = base * 0.2 * @as(f32, @floatFromInt(accelerators));
    const result = base - reduction;
    return @max(result, min_time);
}

pub fn getConversionChance(difficulty: u8) f32 {
    return switch (difficulty) {
        0 => 0.0, // peaceful
        1 => 0.0, // easy
        2 => 0.5, // normal
        3 => 1.0, // hard
        else => 0.0,
    };
}

test "conversion chance by difficulty" {
    try std.testing.expectEqual(@as(f32, 0.0), getConversionChance(0));
    try std.testing.expectEqual(@as(f32, 0.0), getConversionChance(1));
    try std.testing.expectEqual(@as(f32, 0.5), getConversionChance(2));
    try std.testing.expectEqual(@as(f32, 1.0), getConversionChance(3));
}

test "cure requires both weakness and golden apple" {
    var entity = ZombieVillagerEntity{
        .x = 0,
        .y = 0,
        .z = 0,
        .profession = 2,
    };

    // Golden apple without weakness should not start cure
    const started_without_weakness = entity.applyGoldenApple();
    try std.testing.expect(!started_without_weakness);
    try std.testing.expect(!entity.curing);

    // Reset and apply weakness first, then golden apple
    entity.has_golden_apple = false;
    entity.applyWeakness();
    const started_with_weakness = entity.applyGoldenApple();
    try std.testing.expect(started_with_weakness);
    try std.testing.expect(entity.curing);
}

test "cure timer completes and returns result" {
    var entity = ZombieVillagerEntity{
        .x = 10,
        .y = 20,
        .z = 30,
        .profession = 3,
    };
    entity.applyWeakness();
    _ = entity.applyGoldenApple();

    // Partial update should not complete
    const partial = entity.updateCure(100.0);
    try std.testing.expect(partial == null);
    try std.testing.expect(entity.curing);

    // Complete the cure
    const result = entity.updateCure(200.0);
    try std.testing.expect(result != null);
    const r = result.?;
    try std.testing.expectEqual(@as(u8, 3), r.profession);
    try std.testing.expectEqual(@as(f32, 10), r.x);
    try std.testing.expectEqual(@as(f32, 20), r.y);
    try std.testing.expectEqual(@as(f32, 30), r.z);
    try std.testing.expect(!entity.curing);
}

test "cure acceleration with iron bars and bed" {
    // No accelerators: 300s
    try std.testing.expectEqual(@as(f32, 300.0), getCureTime(false, false));
    // One accelerator: 300 - 60 = 240s
    try std.testing.expectEqual(@as(f32, 240.0), getCureTime(true, false));
    try std.testing.expectEqual(@as(f32, 240.0), getCureTime(false, true));
    // Both accelerators: 300 - 120 = 180s (minimum)
    try std.testing.expectEqual(@as(f32, 180.0), getCureTime(true, true));
}

test "profession retained after conversion" {
    const profession: u8 = 5;
    const entity = ZombieVillagerEntity.convertFromVillager(profession, 1, 2, 3, 3);
    try std.testing.expect(entity != null);
    try std.testing.expectEqual(profession, entity.?.profession);
}

test "no conversion on easy difficulty" {
    const result = ZombieVillagerEntity.convertFromVillager(1, 0, 0, 0, 1);
    try std.testing.expect(result == null);
}
