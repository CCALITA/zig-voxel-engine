const std = @import("std");

pub const StewEffect = enum {
    saturation,
    regeneration,
    poison,
    wither,
    night_vision,
    jump_boost,
    weakness,
    blindness,
    fire_resistance,
};

pub const FlowerEffect = struct {
    flower_name: [20]u8,
    name_len: u8,
    effect_type: StewEffect,
    duration: f32,
};

fn makeFlowerEffect(comptime name: []const u8, effect: StewEffect, duration: f32) FlowerEffect {
    var flower_name: [20]u8 = .{0} ** 20;
    for (name, 0..) |c, i| {
        flower_name[i] = c;
    }
    return FlowerEffect{
        .flower_name = flower_name,
        .name_len = @intCast(name.len),
        .effect_type = effect,
        .duration = duration,
    };
}

pub const FLOWER_EFFECTS: [9]FlowerEffect = .{
    makeFlowerEffect("dandelion", .saturation, 7.0),
    makeFlowerEffect("poppy", .night_vision, 5.0),
    makeFlowerEffect("blue_orchid", .saturation, 7.0),
    makeFlowerEffect("allium", .fire_resistance, 4.0),
    makeFlowerEffect("azure_bluet", .blindness, 8.0),
    makeFlowerEffect("red_tulip", .weakness, 9.0),
    makeFlowerEffect("oxeye_daisy", .regeneration, 8.0),
    makeFlowerEffect("cornflower", .jump_boost, 6.0),
    makeFlowerEffect("wither_rose", .wither, 8.0),
};

pub const EatResult = struct {
    hunger: f32,
    saturation: f32,
    effect: StewEffect,
    duration: f32,
};

pub const SuspiciousStew = struct {
    effect: StewEffect,
    duration: f32,
    hunger_restore: f32 = 6.0,
    saturation_restore: f32 = 7.2,

    pub fn craft(flower_index: u8) ?SuspiciousStew {
        if (flower_index >= FLOWER_EFFECTS.len) return null;
        const flower = FLOWER_EFFECTS[flower_index];
        return SuspiciousStew{
            .effect = flower.effect_type,
            .duration = flower.duration,
        };
    }

    pub fn eat(self: SuspiciousStew) EatResult {
        return EatResult{
            .hunger = self.hunger_restore,
            .saturation = self.saturation_restore,
            .effect = self.effect,
            .duration = self.duration,
        };
    }
};

pub fn getEffectForFlower(flower_name: []const u8) ?FlowerEffect {
    for (FLOWER_EFFECTS) |entry| {
        const stored_name = entry.flower_name[0..entry.name_len];
        if (std.mem.eql(u8, stored_name, flower_name)) {
            return entry;
        }
    }
    return null;
}

test "all 9 flowers map correctly" {
    const expected = [_]struct { name: []const u8, effect: StewEffect, duration: f32 }{
        .{ .name = "dandelion", .effect = .saturation, .duration = 7.0 },
        .{ .name = "poppy", .effect = .night_vision, .duration = 5.0 },
        .{ .name = "blue_orchid", .effect = .saturation, .duration = 7.0 },
        .{ .name = "allium", .effect = .fire_resistance, .duration = 4.0 },
        .{ .name = "azure_bluet", .effect = .blindness, .duration = 8.0 },
        .{ .name = "red_tulip", .effect = .weakness, .duration = 9.0 },
        .{ .name = "oxeye_daisy", .effect = .regeneration, .duration = 8.0 },
        .{ .name = "cornflower", .effect = .jump_boost, .duration = 6.0 },
        .{ .name = "wither_rose", .effect = .wither, .duration = 8.0 },
    };

    for (expected) |e| {
        const result = getEffectForFlower(e.name) orelse {
            return error.FlowerNotFound;
        };
        try std.testing.expectEqual(e.effect, result.effect_type);
        try std.testing.expectApproxEqAbs(e.duration, result.duration, 0.001);
    }
}

test "wither rose is dangerous" {
    const wither = getEffectForFlower("wither_rose") orelse {
        return error.FlowerNotFound;
    };
    try std.testing.expectEqual(StewEffect.wither, wither.effect_type);
    try std.testing.expect(wither.duration >= 8.0);
}

test "eating restores hunger" {
    const stew = SuspiciousStew{
        .effect = .saturation,
        .duration = 7.0,
    };
    const result = stew.eat();
    try std.testing.expectApproxEqAbs(@as(f32, 6.0), result.hunger, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 7.2), result.saturation, 0.001);
    try std.testing.expectEqual(StewEffect.saturation, result.effect);
    try std.testing.expectApproxEqAbs(@as(f32, 7.0), result.duration, 0.001);
}

test "craft valid flower index" {
    const stew = SuspiciousStew.craft(0) orelse {
        return error.CraftFailed;
    };
    try std.testing.expectEqual(StewEffect.saturation, stew.effect);
    try std.testing.expectApproxEqAbs(@as(f32, 7.0), stew.duration, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 6.0), stew.hunger_restore, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 7.2), stew.saturation_restore, 0.001);
}

test "craft invalid flower index" {
    const result = SuspiciousStew.craft(9);
    try std.testing.expect(result == null);
    const result2 = SuspiciousStew.craft(255);
    try std.testing.expect(result2 == null);
}
