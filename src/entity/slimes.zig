const std = @import("std");

pub const SlimeSize = enum(u2) {
    small = 0,
    medium = 1,
    large = 2,

    pub fn getValue(self: SlimeSize) f32 {
        return switch (self) {
            .small => 1.0,
            .medium => 2.0,
            .large => 4.0,
        };
    }

    pub fn smaller(self: SlimeSize) ?SlimeSize {
        return switch (self) {
            .small => null,
            .medium => .small,
            .large => .medium,
        };
    }
};

pub const SplitResult = struct {
    new_size: SlimeSize,
    count: u8,
};

pub const SlimeEntity = struct {
    x: f32,
    y: f32,
    z: f32,
    size: SlimeSize,
    health: f32,
    jump_cooldown: f32 = 0,

    pub fn init(size: SlimeSize, x: f32, y: f32, z: f32) SlimeEntity {
        const hp: f32 = switch (size) {
            .small => 1.0,
            .medium => 4.0,
            .large => 16.0,
        };
        return SlimeEntity{
            .x = x,
            .y = y,
            .z = z,
            .size = size,
            .health = hp,
            .jump_cooldown = 0,
        };
    }

    pub fn getAttackDamage(self: SlimeEntity) f32 {
        return switch (self.size) {
            .small => 0.0,
            .medium => 2.0,
            .large => 4.0,
        };
    }

    pub fn getWidth(self: SlimeEntity) f32 {
        return 0.51 * self.size.getValue();
    }

    pub fn onDeath(self: SlimeEntity) ?SplitResult {
        const new_size = self.size.smaller() orelse return null;
        return SplitResult{ .new_size = new_size, .count = 2 };
    }
};

pub fn canSpawnInChunk(chunk_x: i32, chunk_z: i32, seed: u64) bool {
    const cx: u64 = @bitCast(@as(i64, chunk_x));
    const cz: u64 = @bitCast(@as(i64, chunk_z));
    var hash = seed;
    hash ^= cx *% 0x5DEECE66D;
    hash ^= cz *% 0x27BB2EE687B;
    hash = hash *% 0x6C62272E07BB0142 +% 0x517CC1B727220A95;
    hash = (hash >> 32) ^ hash;
    return (hash % 10) == 0;
}

pub const MagmaCubeEntity = struct {
    x: f32,
    y: f32,
    z: f32,
    size: SlimeSize,
    health: f32,
    armor: f32,

    pub fn init(size: SlimeSize, x: f32, y: f32, z: f32) MagmaCubeEntity {
        const hp: f32 = switch (size) {
            .small => 3.0,
            .medium => 6.0,
            .large => 16.0,
        };
        return MagmaCubeEntity{
            .x = x,
            .y = y,
            .z = z,
            .size = size,
            .health = hp,
            .armor = getArmor(size),
        };
    }

    pub fn isFireImmune() bool {
        return true;
    }

    pub fn getArmor(size: SlimeSize) f32 {
        return switch (size) {
            .small => 3.0,
            .medium => 6.0,
            .large => 12.0,
        };
    }
};

test "slime size-based HP" {
    const small = SlimeEntity.init(.small, 0, 0, 0);
    const medium = SlimeEntity.init(.medium, 0, 0, 0);
    const large = SlimeEntity.init(.large, 0, 0, 0);

    try std.testing.expectEqual(@as(f32, 1.0), small.health);
    try std.testing.expectEqual(@as(f32, 4.0), medium.health);
    try std.testing.expectEqual(@as(f32, 16.0), large.health);
}

test "slime split on death" {
    const small = SlimeEntity.init(.small, 0, 0, 0);
    try std.testing.expect(small.onDeath() == null);

    const medium = SlimeEntity.init(.medium, 5, 10, 15);
    const medium_result = medium.onDeath().?;
    try std.testing.expectEqual(SlimeSize.small, medium_result.new_size);
    try std.testing.expectEqual(@as(u8, 2), medium_result.count);

    const large = SlimeEntity.init(.large, 5, 10, 15);
    const large_result = large.onDeath().?;
    try std.testing.expectEqual(SlimeSize.medium, large_result.new_size);
    try std.testing.expectEqual(@as(u8, 2), large_result.count);
}

test "chunk spawning deterministic" {
    const seed: u64 = 12345;
    const result1 = canSpawnInChunk(10, 20, seed);
    const result2 = canSpawnInChunk(10, 20, seed);
    try std.testing.expectEqual(result1, result2);

    var spawn_count: u32 = 0;
    var i: i32 = 0;
    while (i < 1000) : (i += 1) {
        if (canSpawnInChunk(i, i, seed)) {
            spawn_count += 1;
        }
    }
    try std.testing.expect(spawn_count > 0);
    try std.testing.expect(spawn_count < 1000);
}

test "magma cube fire immunity" {
    try std.testing.expect(MagmaCubeEntity.isFireImmune());
}

test "slime damage values" {
    const small = SlimeEntity.init(.small, 0, 0, 0);
    const medium = SlimeEntity.init(.medium, 0, 0, 0);
    const large = SlimeEntity.init(.large, 0, 0, 0);

    try std.testing.expectEqual(@as(f32, 0.0), small.getAttackDamage());
    try std.testing.expectEqual(@as(f32, 2.0), medium.getAttackDamage());
    try std.testing.expectEqual(@as(f32, 4.0), large.getAttackDamage());
}

test "magma cube size-based HP" {
    const small = MagmaCubeEntity.init(.small, 0, 0, 0);
    const medium = MagmaCubeEntity.init(.medium, 0, 0, 0);
    const large = MagmaCubeEntity.init(.large, 0, 0, 0);

    try std.testing.expectEqual(@as(f32, 3.0), small.health);
    try std.testing.expectEqual(@as(f32, 6.0), medium.health);
    try std.testing.expectEqual(@as(f32, 16.0), large.health);
}

test "magma cube armor values" {
    try std.testing.expectEqual(@as(f32, 3.0), MagmaCubeEntity.getArmor(.small));
    try std.testing.expectEqual(@as(f32, 6.0), MagmaCubeEntity.getArmor(.medium));
    try std.testing.expectEqual(@as(f32, 12.0), MagmaCubeEntity.getArmor(.large));
}

test "slime width based on size" {
    const small = SlimeEntity.init(.small, 0, 0, 0);
    const medium = SlimeEntity.init(.medium, 0, 0, 0);
    const large = SlimeEntity.init(.large, 0, 0, 0);

    try std.testing.expectApproxEqAbs(@as(f32, 0.51), small.getWidth(), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.02), medium.getWidth(), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 2.04), large.getWidth(), 0.001);
}
