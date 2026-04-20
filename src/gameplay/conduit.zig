const std = @import("std");

pub const ConduitEffects = struct {
    conduit_power: bool,
    hostile_damage: f32 = 4.0,
    effect_range: u8,
};

pub const ConduitState = struct {
    x: i32,
    y: i32,
    z: i32,
    active: bool = false,
    frame_blocks: u8 = 0,
    power_range: u8 = 0,

    pub fn checkFrame(self: *ConduitState, getBlock: *const fn (i32, i32, i32) u8) void {
        var count: u8 = 0;
        var dy: i32 = -2;
        while (dy <= 2) : (dy += 1) {
            var dx: i32 = -2;
            while (dx <= 2) : (dx += 1) {
                var dz: i32 = -2;
                while (dz <= 2) : (dz += 1) {
                    if (dx == 0 and dy == 0 and dz == 0) continue;
                    const block_id = getBlock(self.x + dx, self.y + dy, self.z + dz);
                    if (isPrismarine(block_id)) {
                        count += 1;
                    }
                }
            }
        }
        self.frame_blocks = count;
        self.active = count >= 16;
        self.power_range = getPowerRange(count);
    }

    pub fn isActive(self: ConduitState) bool {
        return self.active;
    }

    pub fn getEffects(self: ConduitState) ConduitEffects {
        return ConduitEffects{
            .conduit_power = self.active,
            .hostile_damage = 4.0,
            .effect_range = self.power_range,
        };
    }
};

pub fn getPowerRange(frame_count: u8) u8 {
    if (frame_count < 16) return 0;
    if (frame_count >= 42) return 96;
    const extra: u8 = (frame_count - 16) / 7;
    const range: u16 = @as(u16, 16) + @as(u16, extra) * 16;
    return @intCast(range);
}

fn isPrismarine(block_id: u8) bool {
    return block_id == 1;
}

pub const MobType = struct {
    pub const guardian: u8 = 1;
    pub const elder_guardian: u8 = 2;
    pub const drowned: u8 = 3;
};

pub fn isHostileInWater(mob_type: u8) bool {
    return mob_type == MobType.guardian or
        mob_type == MobType.elder_guardian or
        mob_type == MobType.drowned;
}

pub const LightningRodState = struct {
    x: i32,
    y: i32,
    z: i32,
    charged: bool = false,
    charge_timer: f32 = 0,

    pub fn onLightningStrike(self: *LightningRodState) void {
        self.charged = true;
        self.charge_timer = 8;
    }

    pub fn getRedstoneOutput(self: LightningRodState) u4 {
        if (self.charged) return 15;
        return 0;
    }
};

test "frame activation at 16 blocks" {
    var conduit = ConduitState{ .x = 0, .y = 0, .z = 0 };

    const getBlockBelow = struct {
        var call_count: u32 = 0;
        fn func(_: i32, _: i32, _: i32) u8 {
            call_count += 1;
            if (call_count <= 15) return 1;
            return 0;
        }
    };
    getBlockBelow.call_count = 0;
    conduit.checkFrame(&getBlockBelow.func);
    try std.testing.expect(!conduit.isActive());
    try std.testing.expectEqual(@as(u8, 0), conduit.power_range);

    const getBlockAtThreshold = struct {
        var call_count: u32 = 0;
        fn func(_: i32, _: i32, _: i32) u8 {
            call_count += 1;
            if (call_count <= 16) return 1;
            return 0;
        }
    };
    getBlockAtThreshold.call_count = 0;
    conduit.checkFrame(&getBlockAtThreshold.func);
    try std.testing.expect(conduit.isActive());
    try std.testing.expectEqual(@as(u8, 16), conduit.power_range);
}

test "range scaling" {
    try std.testing.expectEqual(@as(u8, 0), getPowerRange(0));
    try std.testing.expectEqual(@as(u8, 0), getPowerRange(15));
    try std.testing.expectEqual(@as(u8, 16), getPowerRange(16));
    try std.testing.expectEqual(@as(u8, 16), getPowerRange(22));
    try std.testing.expectEqual(@as(u8, 32), getPowerRange(23));
    try std.testing.expectEqual(@as(u8, 32), getPowerRange(29));
    try std.testing.expectEqual(@as(u8, 48), getPowerRange(30));
}

test "max range 96 at 42 blocks" {
    try std.testing.expectEqual(@as(u8, 96), getPowerRange(42));
    try std.testing.expectEqual(@as(u8, 96), getPowerRange(50));
    try std.testing.expectEqual(@as(u8, 96), getPowerRange(100));
}

test "lightning rod charge" {
    var rod = LightningRodState{ .x = 0, .y = 0, .z = 0 };
    try std.testing.expectEqual(@as(u4, 0), rod.getRedstoneOutput());
    try std.testing.expect(!rod.charged);

    rod.onLightningStrike();
    try std.testing.expect(rod.charged);
    try std.testing.expectEqual(@as(f32, 8), rod.charge_timer);
    try std.testing.expectEqual(@as(u4, 15), rod.getRedstoneOutput());
}

test "hostile detection" {
    try std.testing.expect(isHostileInWater(MobType.guardian));
    try std.testing.expect(isHostileInWater(MobType.elder_guardian));
    try std.testing.expect(isHostileInWater(MobType.drowned));
    try std.testing.expect(!isHostileInWater(0));
    try std.testing.expect(!isHostileInWater(4));
    try std.testing.expect(!isHostileInWater(255));
}
