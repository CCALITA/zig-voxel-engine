const std = @import("std");

pub const EndermanEntity = struct {
    x: f32,
    y: f32,
    z: f32,
    health: f32 = max_health,
    held_block: ?u8 = null,
    angry: bool = false,
    teleport_cooldown: f32 = 0,
    target_x: ?f32 = null,
    target_y: ?f32 = null,
    target_z: ?f32 = null,

    const max_health: f32 = 40.0;
    const teleport_range: f32 = 32.0;
    const teleport_cooldown_duration: f32 = 1.0;
    const water_damage_per_tick: f32 = 1.0;
    const eye_contact_range: f32 = 64.0;
    const eye_contact_dot_threshold: f32 = 0.98;
    const ender_pearl_id: u16 = 1;

    pub fn init(x: f32, y: f32, z: f32) EndermanEntity {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn update(self: *EndermanEntity, dt: f32, player_looking_at: bool, is_raining: bool) void {
        if (self.teleport_cooldown > 0) {
            self.teleport_cooldown = @max(0, self.teleport_cooldown - dt);
        }

        if (is_raining) {
            self.takeDamageFromWater();
        }

        if (player_looking_at and !self.angry) {
            self.angry = true;
        }

        if (self.angry and is_raining and self.teleport_cooldown <= 0) {
            self.teleportRandom(@as(u64, @bitCast(@as(i64, @intFromFloat(self.x * 1000 + self.z)))));
        }
    }

    pub fn teleportRandom(self: *EndermanEntity, seed: u64) void {
        var rng = std.Random.DefaultPrng.init(seed);
        const random = rng.random();

        const range = teleport_range * 2.0;
        const offset_x = random.float(f32) * range - teleport_range;
        const offset_y = random.float(f32) * range - teleport_range;
        const offset_z = random.float(f32) * range - teleport_range;

        self.x += offset_x;
        self.y += offset_y;
        self.z += offset_z;
        self.teleport_cooldown = teleport_cooldown_duration;
    }

    pub fn pickUpBlock(self: *EndermanEntity, block_id: u8) void {
        if (self.held_block == null) {
            self.held_block = block_id;
        }
    }

    pub fn placeBlock(self: *EndermanEntity) ?u8 {
        const block = self.held_block;
        self.held_block = null;
        return block;
    }

    pub fn isProvoked(self: EndermanEntity) bool {
        return self.angry;
    }

    pub fn checkEyeContact(player_yaw: f32, player_pitch: f32, dx: f32, dy: f32, dz: f32) bool {
        const distance_sq = dx * dx + dy * dy + dz * dz;
        if (distance_sq > eye_contact_range * eye_contact_range) {
            return false;
        }

        const distance = @sqrt(distance_sq);
        if (distance < 0.001) {
            return false;
        }

        const norm_dx = dx / distance;
        const norm_dy = dy / distance;
        const norm_dz = dz / distance;

        const yaw_rad = player_yaw * std.math.pi / 180.0;
        const pitch_rad = player_pitch * std.math.pi / 180.0;

        const look_x = -@sin(yaw_rad) * @cos(pitch_rad);
        const look_y = -@sin(pitch_rad);
        const look_z = @cos(yaw_rad) * @cos(pitch_rad);

        const dot = look_x * norm_dx + look_y * norm_dy + look_z * norm_dz;

        return dot > eye_contact_dot_threshold;
    }

    pub fn takeDamageFromWater(self: *EndermanEntity) void {
        self.health = @max(0, self.health - water_damage_per_tick);
    }

    pub fn getDrops() u16 {
        return ender_pearl_id;
    }
};

test "eye contact provokes enderman" {
    var enderman = EndermanEntity.init(0, 0, 0);

    try std.testing.expect(!enderman.isProvoked());

    const looking = EndermanEntity.checkEyeContact(0, 0, 0, 0, 10);
    try std.testing.expect(looking);

    enderman.update(0.05, true, false);
    try std.testing.expect(enderman.isProvoked());
}

test "teleport changes position" {
    var enderman = EndermanEntity.init(100, 64, 100);

    const orig_x = enderman.x;
    const orig_y = enderman.y;
    const orig_z = enderman.z;

    enderman.teleportRandom(42);

    const moved = (enderman.x != orig_x) or (enderman.y != orig_y) or (enderman.z != orig_z);
    try std.testing.expect(moved);

    const range = EndermanEntity.teleport_range;
    const dx = enderman.x - orig_x;
    const dy = enderman.y - orig_y;
    const dz = enderman.z - orig_z;
    try std.testing.expect(dx >= -range and dx <= range);
    try std.testing.expect(dy >= -range and dy <= range);
    try std.testing.expect(dz >= -range and dz <= range);
}

test "water damage reduces health" {
    var enderman = EndermanEntity.init(0, 0, 0);

    try std.testing.expectEqual(EndermanEntity.max_health, enderman.health);

    enderman.takeDamageFromWater();
    try std.testing.expectEqual(@as(f32, 39), enderman.health);

    enderman.update(0.05, false, true);
    try std.testing.expectEqual(@as(f32, 38), enderman.health);
}

test "block pickup and place" {
    var enderman = EndermanEntity.init(0, 0, 0);

    try std.testing.expect(enderman.held_block == null);

    enderman.pickUpBlock(3);
    try std.testing.expectEqual(@as(?u8, 3), enderman.held_block);

    enderman.pickUpBlock(5);
    try std.testing.expectEqual(@as(?u8, 3), enderman.held_block);

    const placed = enderman.placeBlock();
    try std.testing.expectEqual(@as(?u8, 3), placed);
    try std.testing.expect(enderman.held_block == null);

    const empty_place = enderman.placeBlock();
    try std.testing.expect(empty_place == null);
}

test "enderman has 40 HP" {
    const enderman = EndermanEntity.init(0, 0, 0);
    try std.testing.expectEqual(EndermanEntity.max_health, enderman.health);
}

test "getDrops returns ender pearl" {
    const drops = EndermanEntity.getDrops();
    try std.testing.expectEqual(EndermanEntity.ender_pearl_id, drops);
}

test "eye contact beyond 64 blocks returns false" {
    const result = EndermanEntity.checkEyeContact(0, 0, 0, 0, 65);
    try std.testing.expect(!result);
}
