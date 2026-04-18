const std = @import("std");

pub const GoatEntity = struct {
    x: f32,
    y: f32,
    z: f32,
    health: f32,
    is_screaming: bool,
    ram_cooldown: f32,
    ram_target: ?RamTarget,
    jump_boost: f32,
    horns_dropped: u8,

    const RamTarget = struct { x: f32, z: f32 };

    const ram_cooldown_duration: f32 = 10.0;
    const max_horns: u8 = 2;
    const ram_speed: f32 = 8.0;

    pub fn init(x: f32, y: f32, z: f32, seed: u64) GoatEntity {
        var rng = std.Random.DefaultPrng.init(seed);
        const random = rng.random();
        const is_screaming = random.intRangeAtMost(u32, 1, 100) <= 2;

        return GoatEntity{
            .x = x,
            .y = y,
            .z = z,
            .health = 10.0,
            .is_screaming = is_screaming,
            .ram_cooldown = 0.0,
            .ram_target = null,
            .jump_boost = 10.0,
            .horns_dropped = 0,
        };
    }

    pub fn update(self: *GoatEntity, dt: f32) void {
        if (self.ram_cooldown > 0) {
            self.ram_cooldown = @max(self.ram_cooldown - dt, 0.0);
        }

        if (self.ram_target) |target| {
            const dx = target.x - self.x;
            const dz = target.z - self.z;
            const dist = @sqrt(dx * dx + dz * dz);

            if (dist < 0.5) {
                self.ram_target = null;
                self.ram_cooldown = ram_cooldown_duration;
            } else {
                const inv = 1.0 / dist;
                self.x += dx * inv * ram_speed * dt;
                self.z += dz * inv * ram_speed * dt;
            }
        }
    }

    pub fn startRam(self: *GoatEntity, target_x: f32, target_z: f32) void {
        if (!self.canRam()) return;
        self.ram_target = .{ .x = target_x, .z = target_z };
    }

    pub fn getRamDamage(self: GoatEntity) f32 {
        return if (self.is_screaming) 3.0 else 2.0;
    }

    pub fn canRam(self: GoatEntity) bool {
        return self.ram_cooldown <= 0.0;
    }

    pub fn getJumpHeight(self: GoatEntity) f32 {
        return self.jump_boost;
    }

    pub fn dropGoatHorn(self: *GoatEntity) bool {
        if (self.horns_dropped >= max_horns) return false;
        self.horns_dropped += 1;
        return true;
    }
};

test "screaming goat has 2% chance" {
    const total: u32 = 10_000;
    var screaming_count: u32 = 0;

    for (0..total) |i| {
        const goat = GoatEntity.init(0, 0, 0, @intCast(i));
        if (goat.is_screaming) screaming_count += 1;
    }

    const pct = @as(f32, @floatFromInt(screaming_count)) / @as(f32, @floatFromInt(total)) * 100.0;
    try std.testing.expect(pct > 0.5);
    try std.testing.expect(pct < 5.0);
}

test "ram cooldown prevents consecutive rams" {
    var goat = GoatEntity.init(0, 0, 0, 42);
    try std.testing.expect(goat.canRam());

    goat.startRam(10, 10);
    // Simulate reaching target
    goat.ram_target = null;
    goat.ram_cooldown = GoatEntity.ram_cooldown_duration;

    try std.testing.expect(!goat.canRam());

    // Tick away partial cooldown
    goat.update(5.0);
    try std.testing.expect(!goat.canRam());

    // Tick away remaining cooldown
    goat.update(5.0);
    try std.testing.expect(goat.canRam());
}

test "jump height is 10 blocks (double normal)" {
    const goat = GoatEntity.init(0, 0, 0, 1);
    try std.testing.expectEqual(@as(f32, 10.0), goat.getJumpHeight());
}

test "horn drop limited to 2" {
    var goat = GoatEntity.init(0, 0, 0, 1);
    try std.testing.expect(goat.dropGoatHorn());
    try std.testing.expect(goat.dropGoatHorn());
    try std.testing.expect(!goat.dropGoatHorn());
    try std.testing.expectEqual(@as(u8, 2), goat.horns_dropped);
}

test "ram damage depends on screaming" {
    var normal = GoatEntity.init(0, 0, 0, 1);
    normal.is_screaming = false;
    try std.testing.expectEqual(@as(f32, 2.0), normal.getRamDamage());

    var screamer = GoatEntity.init(0, 0, 0, 1);
    screamer.is_screaming = true;
    try std.testing.expectEqual(@as(f32, 3.0), screamer.getRamDamage());
}

test "update moves goat toward ram target" {
    var goat = GoatEntity.init(0, 0, 0, 1);
    goat.startRam(10, 0);
    goat.update(0.5);
    try std.testing.expect(goat.x > 0.0);
}
