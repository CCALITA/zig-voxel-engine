const std = @import("std");

pub const FrogVariant = enum {
    temperate,
    warm,
    cold,
};

pub const FroglightColor = enum {
    ochre,
    verdant,
    pearlescent,
};

pub const TongueResult = struct {
    target_consumed: bool,
    drop: ?FroglightColor,
};

fn variantFromTemperature(biome_temp: f32) FrogVariant {
    if (biome_temp > 0.8) return .warm;
    if (biome_temp < 0.2) return .cold;
    return .temperate;
}

pub const FrogEntity = struct {
    x: f32,
    y: f32,
    z: f32,
    health: f32,
    variant: FrogVariant,
    tongue_cooldown: f32,

    pub fn init(x: f32, y: f32, z: f32, biome_temp: f32) FrogEntity {
        return FrogEntity{
            .x = x,
            .y = y,
            .z = z,
            .health = 10.0,
            .variant = variantFromTemperature(biome_temp),
            .tongue_cooldown = 0.0,
        };
    }

    pub fn tongueAttack(self: *FrogEntity) ?TongueResult {
        if (self.tongue_cooldown > 0.0) {
            return null;
        }
        self.tongue_cooldown = 1.0;

        const color: FroglightColor = switch (self.variant) {
            .temperate => .ochre,
            .warm => .verdant,
            .cold => .pearlescent,
        };

        return TongueResult{
            .target_consumed = true,
            .drop = color,
        };
    }
};

pub const TadpoleEntity = struct {
    x: f32,
    y: f32,
    z: f32,
    growth_timer: f32,
    in_water: bool,

    pub fn init(x: f32, y: f32, z: f32) TadpoleEntity {
        return TadpoleEntity{
            .x = x,
            .y = y,
            .z = z,
            .growth_timer = 1200.0,
            .in_water = true,
        };
    }

    pub fn update(self: *TadpoleEntity, dt: f32, biome_temp: f32) ?FrogVariant {
        if (!self.in_water) {
            return null;
        }

        self.growth_timer -= dt;
        if (self.growth_timer <= 0.0) {
            return variantFromTemperature(biome_temp);
        }

        return null;
    }
};

test "variant selection by temperature" {
    const warm_frog = FrogEntity.init(0, 0, 0, 0.9);
    try std.testing.expectEqual(FrogVariant.warm, warm_frog.variant);

    const cold_frog = FrogEntity.init(0, 0, 0, 0.1);
    try std.testing.expectEqual(FrogVariant.cold, cold_frog.variant);

    const temperate_frog = FrogEntity.init(0, 0, 0, 0.5);
    try std.testing.expectEqual(FrogVariant.temperate, temperate_frog.variant);
}

test "froglight color matches variant" {
    var warm = FrogEntity.init(0, 0, 0, 0.9);
    const warm_result = warm.tongueAttack().?;
    try std.testing.expectEqual(FroglightColor.verdant, warm_result.drop.?);

    var cold = FrogEntity.init(0, 0, 0, 0.1);
    const cold_result = cold.tongueAttack().?;
    try std.testing.expectEqual(FroglightColor.pearlescent, cold_result.drop.?);

    var temperate = FrogEntity.init(0, 0, 0, 0.5);
    const temp_result = temperate.tongueAttack().?;
    try std.testing.expectEqual(FroglightColor.ochre, temp_result.drop.?);
}

test "tadpole matures into frog variant" {
    var tadpole = TadpoleEntity.init(5, 10, 5);
    try std.testing.expectEqual(@as(?FrogVariant, null), tadpole.update(600.0, 0.5));
    const result = tadpole.update(601.0, 0.5);
    try std.testing.expectEqual(FrogVariant.temperate, result.?);
}

test "tongue cooldown prevents repeated attacks" {
    var frog = FrogEntity.init(0, 0, 0, 0.5);
    const first = frog.tongueAttack();
    try std.testing.expect(first != null);

    const second = frog.tongueAttack();
    try std.testing.expectEqual(@as(?TongueResult, null), second);
}
