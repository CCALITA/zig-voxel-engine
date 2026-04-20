const std = @import("std");

pub const BedColor = enum(u4) {
    white = 0,
    orange = 1,
    magenta = 2,
    light_blue = 3,
    yellow = 4,
    lime = 5,
    pink = 6,
    gray = 7,
    light_gray = 8,
    cyan = 9,
    purple = 10,
    blue = 11,
    brown = 12,
    green = 13,
    red = 14,
    black = 15,
};

pub const BedBlock = struct {
    color: BedColor,
    head: bool,
    occupied: bool,
    facing: u2,
};

pub const BedResult = enum {
    sleeping,
    monster_nearby,
    not_night,
    wrong_dimension_explode,
    obstructed,
};

pub const SpawnPoint = struct {
    x: i32,
    y: i32,
    z: i32,
    valid: bool,
};

pub const SleepState = struct {
    sleeping: bool,
    sleep_timer: f32,

    pub fn startSleep(self: *SleepState) void {
        self.sleeping = true;
        self.sleep_timer = 0.0;
    }

    pub fn tickSleep(self: *SleepState, dt: f32) bool {
        if (!self.sleeping) return false;
        self.sleep_timer += dt;
        if (self.sleep_timer >= 5.0) {
            self.sleeping = false;
            return true;
        }
        return false;
    }
};

pub fn tryUseBed(is_night: bool, dimension: u8, hostile_within_8: bool, bed_obstructed: bool) BedResult {
    if (isExplosiveDimension(dimension)) return .wrong_dimension_explode;
    if (!is_night) return .not_night;
    if (hostile_within_8) return .monster_nearby;
    if (bed_obstructed) return .obstructed;
    return .sleeping;
}

pub fn setSpawnPoint(x: i32, y: i32, z: i32) SpawnPoint {
    return SpawnPoint{ .x = x, .y = y, .z = z, .valid = true };
}

pub fn isExplosiveDimension(dimension: u8) bool {
    return dimension == 1 or dimension == 2;
}

pub fn getExplosionPower() f32 {
    return 5.0;
}

pub fn canAllSleep(player_count: u8, sleeping_count: u8) bool {
    if (player_count == 0) return false;
    const threshold = (player_count + 1) / 2;
    return sleeping_count >= threshold;
}

test "sleep at night succeeds" {
    const result = tryUseBed(true, 0, false, false);
    try std.testing.expectEqual(BedResult.sleeping, result);
}

test "no sleep with monsters nearby" {
    const result = tryUseBed(true, 0, true, false);
    try std.testing.expectEqual(BedResult.monster_nearby, result);
}

test "nether explosion" {
    const result = tryUseBed(true, 1, false, false);
    try std.testing.expectEqual(BedResult.wrong_dimension_explode, result);
    try std.testing.expect(isExplosiveDimension(1));
    try std.testing.expect(isExplosiveDimension(2));
    try std.testing.expect(!isExplosiveDimension(0));
    try std.testing.expectEqual(@as(f32, 5.0), getExplosionPower());
}

test "spawn point set" {
    const spawn = setSpawnPoint(100, 64, -200);
    try std.testing.expectEqual(@as(i32, 100), spawn.x);
    try std.testing.expectEqual(@as(i32, 64), spawn.y);
    try std.testing.expectEqual(@as(i32, -200), spawn.z);
    try std.testing.expect(spawn.valid);
}

test "all-player sleep check" {
    try std.testing.expect(canAllSleep(4, 2));
    try std.testing.expect(canAllSleep(4, 4));
    try std.testing.expect(!canAllSleep(4, 1));
    try std.testing.expect(canAllSleep(1, 1));
    try std.testing.expect(!canAllSleep(0, 0));
}

test "sleep state timer" {
    var state = SleepState{ .sleeping = false, .sleep_timer = 0.0 };
    state.startSleep();
    try std.testing.expect(state.sleeping);
    try std.testing.expect(!state.tickSleep(2.0));
    try std.testing.expect(state.sleeping);
    try std.testing.expect(state.tickSleep(3.0));
    try std.testing.expect(!state.sleeping);
}
