const std = @import("std");

pub const SculkType = enum {
    sculk,
    sculk_vein,
    sculk_sensor,
    sculk_shrieker,
};

pub const ConvertedBlock = struct {
    x: i32,
    y: i32,
    z: i32,
    to_type: SculkType,
};

pub const SculkSpreadResult = struct {
    blocks_converted: [32]?ConvertedBlock = [_]?ConvertedBlock{null} ** 32,
    count: u8 = 0,
};

pub const SculkCatalyst = struct {
    x: i32,
    y: i32,
    z: i32,
    active: bool,

    pub fn onMobDeath(self: *SculkCatalyst, death_x: i32, death_y: i32, death_z: i32, xp: u32) SculkSpreadResult {
        if (!self.active or xp == 0) {
            return SculkSpreadResult{};
        }
        return spreadSculk(death_x, death_y, death_z, xp, @as(u64, @bitCast(@as(i64, self.x) *% 31 +% @as(i64, self.z) *% 17)));
    }
};

pub const SculkShrieker = struct {
    x: i32,
    y: i32,
    z: i32,
    activation_count: u8 = 0,
    cooldown: f32 = 0,

    pub fn activate(self: *SculkShrieker) ShriekerResult {
        if (self.cooldown > 0) {
            return .warn;
        }
        self.activation_count += 1;
        self.cooldown = 10.0;
        if (self.shouldSummonWarden()) {
            return .summon_warden;
        }
        return .warn;
    }

    pub fn shouldSummonWarden(self: SculkShrieker) bool {
        return self.activation_count >= 3;
    }
};

pub const ShriekerResult = enum {
    warn,
    summon_warden,
};

fn xorshift64(state: u64) u64 {
    var s = state;
    s ^= s << 13;
    s ^= s >> 7;
    s ^= s << 17;
    return s;
}

fn rollSculkType(roll: u64) SculkType {
    const r = roll % 100;
    if (r < 60) return .sculk;
    if (r < 85) return .sculk_vein;
    if (r < 95) return .sculk_sensor;
    return .sculk_shrieker;
}

pub fn spreadSculk(origin_x: i32, origin_y: i32, origin_z: i32, xp: u32, seed: u64) SculkSpreadResult {
    var result = SculkSpreadResult{};
    if (xp == 0) {
        return result;
    }

    const radius: i32 = @intCast(@min(xp / 10 + 1, 8));
    var rng = seed ^ @as(u64, @bitCast(@as(i64, origin_x))) ^ (@as(u64, @bitCast(@as(i64, origin_z))) << 16);

    var dy: i32 = -1;
    while (dy <= 0) : (dy += 1) {
        var dx: i32 = -radius;
        while (dx <= radius) : (dx += 1) {
            var dz: i32 = -radius;
            while (dz <= radius) : (dz += 1) {
                if (result.count >= 32) return result;

                const dist_sq = dx * dx + dy * dy + dz * dz;
                if (dist_sq > radius * radius) continue;

                rng = xorshift64(rng);

                result.blocks_converted[result.count] = ConvertedBlock{
                    .x = origin_x + dx,
                    .y = origin_y + dy,
                    .z = origin_z + dz,
                    .to_type = rollSculkType(rng),
                };
                result.count += 1;
            }
        }
    }
    return result;
}

test "catalyst converts blocks on mob death" {
    var catalyst = SculkCatalyst{ .x = 0, .y = -10, .z = 0, .active = true };
    const result = catalyst.onMobDeath(5, -10, 5, 50);
    try std.testing.expect(result.count > 0);

    var has_sculk = false;
    for (result.blocks_converted) |maybe_block| {
        if (maybe_block) |block| {
            if (block.to_type == .sculk) {
                has_sculk = true;
                break;
            }
        }
    }
    try std.testing.expect(has_sculk);
}

test "inactive catalyst produces no blocks" {
    var catalyst = SculkCatalyst{ .x = 0, .y = 0, .z = 0, .active = false };
    const result = catalyst.onMobDeath(5, 0, 5, 50);
    try std.testing.expectEqual(@as(u8, 0), result.count);
}

test "shrieker activation count increments" {
    var shrieker = SculkShrieker{ .x = 0, .y = 0, .z = 0 };
    try std.testing.expectEqual(@as(u8, 0), shrieker.activation_count);

    _ = shrieker.activate();
    try std.testing.expectEqual(@as(u8, 1), shrieker.activation_count);

    shrieker.cooldown = 0;
    _ = shrieker.activate();
    try std.testing.expectEqual(@as(u8, 2), shrieker.activation_count);
}

test "warden summoned at activation count 3" {
    var shrieker = SculkShrieker{ .x = 0, .y = 0, .z = 0 };
    try std.testing.expect(!shrieker.shouldSummonWarden());

    _ = shrieker.activate();
    shrieker.cooldown = 0;
    _ = shrieker.activate();
    shrieker.cooldown = 0;

    const result = shrieker.activate();
    try std.testing.expect(shrieker.shouldSummonWarden());
    try std.testing.expectEqual(ShriekerResult.summon_warden, result);
}

test "spread radius scales with XP" {
    const low_xp_result = spreadSculk(0, 0, 0, 10, 42);
    const high_xp_result = spreadSculk(0, 0, 0, 80, 42);
    try std.testing.expect(high_xp_result.count > low_xp_result.count);
}

test "zero XP produces no spread" {
    const result = spreadSculk(0, 0, 0, 0, 42);
    try std.testing.expectEqual(@as(u8, 0), result.count);
}
