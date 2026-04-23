const std = @import("std");

pub const AUTO_SAVE_INTERVAL: f32 = 300.0;

pub const PlayerSaveData = struct {
    x: f32,
    y: f32,
    z: f32,
    health: u8 = 20,
    hunger: u8 = 20,
    xp: u32 = 0,
    xp_level: u32 = 0,
    dimension: u8 = 0,
    game_time: u64 = 0,
    difficulty: u8 = 2,
    spawn_x: i32 = 0,
    spawn_y: i32 = 64,
    spawn_z: i32 = 0,
};

pub const SaveTimer = struct {
    elapsed: f32 = 0,

    pub fn update(self: *SaveTimer, dt: f32) bool {
        self.elapsed += dt;
        if (self.elapsed >= AUTO_SAVE_INTERVAL) {
            self.elapsed -= AUTO_SAVE_INTERVAL;
            return true;
        }
        return false;
    }
};

/// Pack PlayerSaveData into a 128-byte little-endian buffer.
pub fn serialize(data: PlayerSaveData) [128]u8 {
    var buf = [_]u8{0} ** 128;
    var offset: usize = 0;

    writeF32(&buf, &offset, data.x);
    writeF32(&buf, &offset, data.y);
    writeF32(&buf, &offset, data.z);
    buf[offset] = data.health;
    offset += 1;
    buf[offset] = data.hunger;
    offset += 1;
    writeU32(&buf, &offset, data.xp);
    writeU32(&buf, &offset, data.xp_level);
    buf[offset] = data.dimension;
    offset += 1;
    writeU64(&buf, &offset, data.game_time);
    buf[offset] = data.difficulty;
    offset += 1;
    writeI32(&buf, &offset, data.spawn_x);
    writeI32(&buf, &offset, data.spawn_y);
    writeI32(&buf, &offset, data.spawn_z);

    return buf;
}

/// Unpack a 128-byte little-endian buffer into PlayerSaveData.
pub fn deserialize(bytes: [128]u8) PlayerSaveData {
    var offset: usize = 0;

    const x = readF32(&bytes, &offset);
    const y = readF32(&bytes, &offset);
    const z = readF32(&bytes, &offset);
    const health = bytes[offset];
    offset += 1;
    const hunger = bytes[offset];
    offset += 1;
    const xp = readU32(&bytes, &offset);
    const xp_level = readU32(&bytes, &offset);
    const dimension = bytes[offset];
    offset += 1;
    const game_time = readU64(&bytes, &offset);
    const difficulty = bytes[offset];
    offset += 1;
    const spawn_x = readI32(&bytes, &offset);
    const spawn_y = readI32(&bytes, &offset);
    const spawn_z = readI32(&bytes, &offset);

    return .{
        .x = x,
        .y = y,
        .z = z,
        .health = health,
        .hunger = hunger,
        .xp = xp,
        .xp_level = xp_level,
        .dimension = dimension,
        .game_time = game_time,
        .difficulty = difficulty,
        .spawn_x = spawn_x,
        .spawn_y = spawn_y,
        .spawn_z = spawn_z,
    };
}

// -- Little-endian helpers --------------------------------------------------

fn writeF32(buf: []u8, offset: *usize, val: f32) void {
    const bits: u32 = @bitCast(val);
    writeU32(buf, offset, bits);
}

fn writeU32(buf: []u8, offset: *usize, val: u32) void {
    const le = std.mem.nativeToLittle(u32, val);
    const bytes: [4]u8 = @bitCast(le);
    @memcpy(buf[offset.*..][0..4], &bytes);
    offset.* += 4;
}

fn writeI32(buf: []u8, offset: *usize, val: i32) void {
    const bits: u32 = @bitCast(val);
    writeU32(buf, offset, bits);
}

fn writeU64(buf: []u8, offset: *usize, val: u64) void {
    const le = std.mem.nativeToLittle(u64, val);
    const bytes: [8]u8 = @bitCast(le);
    @memcpy(buf[offset.*..][0..8], &bytes);
    offset.* += 8;
}

fn readF32(buf: []const u8, offset: *usize) f32 {
    const bits = readU32(buf, offset);
    return @bitCast(bits);
}

fn readU32(buf: []const u8, offset: *usize) u32 {
    const bytes = buf[offset.*..][0..4];
    const le: u32 = @bitCast(bytes.*);
    offset.* += 4;
    return std.mem.littleToNative(u32, le);
}

fn readI32(buf: []const u8, offset: *usize) i32 {
    const bits = readU32(buf, offset);
    return @bitCast(bits);
}

fn readU64(buf: []const u8, offset: *usize) u64 {
    const bytes = buf[offset.*..][0..8];
    const le: u64 = @bitCast(bytes.*);
    offset.* += 8;
    return std.mem.littleToNative(u64, le);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "round-trip default values" {
    const data = PlayerSaveData{ .x = 0, .y = 0, .z = 0 };
    const restored = deserialize(serialize(data));
    try std.testing.expectEqual(data, restored);
}

test "round-trip with custom position" {
    const data = PlayerSaveData{ .x = 1.5, .y = -42.0, .z = 999.125 };
    const restored = deserialize(serialize(data));
    try std.testing.expectEqual(data.x, restored.x);
    try std.testing.expectEqual(data.y, restored.y);
    try std.testing.expectEqual(data.z, restored.z);
}

test "round-trip all fields populated" {
    const data = PlayerSaveData{
        .x = -100.25,
        .y = 64.0,
        .z = 200.75,
        .health = 10,
        .hunger = 5,
        .xp = 12345,
        .xp_level = 30,
        .dimension = 1,
        .game_time = 1_000_000,
        .difficulty = 3,
        .spawn_x = -50,
        .spawn_y = 70,
        .spawn_z = 100,
    };
    const restored = deserialize(serialize(data));
    try std.testing.expectEqual(data, restored);
}

test "round-trip negative spawn coordinates" {
    const data = PlayerSaveData{
        .x = 0,
        .y = 0,
        .z = 0,
        .spawn_x = -1000,
        .spawn_y = -64,
        .spawn_z = -9999,
    };
    const restored = deserialize(serialize(data));
    try std.testing.expectEqual(data.spawn_x, restored.spawn_x);
    try std.testing.expectEqual(data.spawn_y, restored.spawn_y);
    try std.testing.expectEqual(data.spawn_z, restored.spawn_z);
}

test "round-trip large game_time" {
    const data = PlayerSaveData{
        .x = 0,
        .y = 0,
        .z = 0,
        .game_time = std.math.maxInt(u64),
    };
    const restored = deserialize(serialize(data));
    try std.testing.expectEqual(data.game_time, restored.game_time);
}

test "round-trip max xp" {
    const data = PlayerSaveData{
        .x = 0,
        .y = 0,
        .z = 0,
        .xp = std.math.maxInt(u32),
        .xp_level = std.math.maxInt(u32),
    };
    const restored = deserialize(serialize(data));
    try std.testing.expectEqual(data.xp, restored.xp);
    try std.testing.expectEqual(data.xp_level, restored.xp_level);
}

test "round-trip boundary health and hunger" {
    const data = PlayerSaveData{
        .x = 0,
        .y = 0,
        .z = 0,
        .health = 0,
        .hunger = 0,
    };
    const restored = deserialize(serialize(data));
    try std.testing.expectEqual(@as(u8, 0), restored.health);
    try std.testing.expectEqual(@as(u8, 0), restored.hunger);
}

test "round-trip nether dimension" {
    const data = PlayerSaveData{
        .x = 0,
        .y = 0,
        .z = 0,
        .dimension = 1,
    };
    const restored = deserialize(serialize(data));
    try std.testing.expectEqual(@as(u8, 1), restored.dimension);
}

test "serialize produces little-endian bytes for x" {
    const data = PlayerSaveData{ .x = 1.0, .y = 0, .z = 0 };
    const buf = serialize(data);
    // IEEE 754 1.0f = 0x3F800000, LE = 00 00 80 3F
    try std.testing.expectEqual(@as(u8, 0x00), buf[0]);
    try std.testing.expectEqual(@as(u8, 0x00), buf[1]);
    try std.testing.expectEqual(@as(u8, 0x80), buf[2]);
    try std.testing.expectEqual(@as(u8, 0x3F), buf[3]);
}

test "save timer fires at 300 seconds" {
    var timer = SaveTimer{};
    // Advance 299 seconds in 1-second steps -- should not fire.
    for (0..299) |_| {
        try std.testing.expect(!timer.update(1.0));
    }
    // The 300th second should trigger.
    try std.testing.expect(timer.update(1.0));
}

test "save timer resets after firing" {
    var timer = SaveTimer{};
    _ = timer.update(300.0);
    // After firing, elapsed should be near 0 and next tick should not fire.
    try std.testing.expect(!timer.update(1.0));
}

test "auto save interval constant" {
    try std.testing.expectEqual(@as(f32, 300.0), AUTO_SAVE_INTERVAL);
}
