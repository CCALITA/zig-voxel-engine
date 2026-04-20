const std = @import("std");

pub const TridentEnchant = enum(u8) {
    loyalty,
    riptide,
    channeling,
    impaling,
};

pub const MobType = enum(u8) {
    guardian,
    elder_guardian,
    squid,
    dolphin,
    drowned,
    turtle,
    axolotl,
    other,
};

pub const EnchantSlot = struct {
    enchant: TridentEnchant,
    level: u8,
};

pub const TridentState = struct {
    enchants: [4]?EnchantSlot = .{ null, null, null, null },
    enchant_count: u8 = 0,

    pub fn addEnchant(self: *TridentState, enchant: TridentEnchant, level: u8) bool {
        if (self.enchant_count >= 4) return false;

        for (0..self.enchant_count) |i| {
            if (self.enchants[i]) |existing| {
                if (!areCompatible(existing.enchant, enchant)) return false;
            }
        }

        self.enchants[self.enchant_count] = EnchantSlot{ .enchant = enchant, .level = level };
        self.enchant_count += 1;
        return true;
    }
};

pub fn areCompatible(a: TridentEnchant, b: TridentEnchant) bool {
    if (a == .loyalty and b == .riptide) return false;
    if (a == .riptide and b == .loyalty) return false;
    return true;
}

pub fn getLoyaltyReturnSpeed(level: u8) f32 {
    return switch (level) {
        1 => 8.0,
        2 => 12.0,
        3 => 16.0,
        else => 0.0,
    };
}

pub fn getRiptideLaunchVelocity(level: u8) f32 {
    return @as(f32, @floatFromInt(level)) * 3.0;
}

pub fn canUseRiptide(in_water: bool, in_rain: bool) bool {
    return in_water or in_rain;
}

pub fn shouldChannelLightning(level: u8, target_in_storm: bool, target_in_open: bool) bool {
    return level >= 1 and target_in_storm and target_in_open;
}

pub fn getImpalingDamage(level: u8) f32 {
    return @as(f32, @floatFromInt(level)) * 2.5;
}

pub fn isAquaticMob(mob_type: MobType) bool {
    return switch (mob_type) {
        .guardian, .elder_guardian, .squid, .dolphin, .drowned, .turtle, .axolotl => true,
        .other => false,
    };
}

test "loyalty and riptide are incompatible" {
    try std.testing.expect(!areCompatible(.loyalty, .riptide));
    try std.testing.expect(!areCompatible(.riptide, .loyalty));
}

test "other enchant combinations are compatible" {
    try std.testing.expect(areCompatible(.loyalty, .channeling));
    try std.testing.expect(areCompatible(.loyalty, .impaling));
    try std.testing.expect(areCompatible(.riptide, .channeling));
    try std.testing.expect(areCompatible(.riptide, .impaling));
    try std.testing.expect(areCompatible(.channeling, .impaling));
    try std.testing.expect(areCompatible(.impaling, .channeling));
}

test "riptide requires water or rain" {
    try std.testing.expect(canUseRiptide(true, false));
    try std.testing.expect(canUseRiptide(false, true));
    try std.testing.expect(canUseRiptide(true, true));
    try std.testing.expect(!canUseRiptide(false, false));
}

test "channeling requires storm and open sky" {
    try std.testing.expect(shouldChannelLightning(1, true, true));
    try std.testing.expect(!shouldChannelLightning(1, false, true));
    try std.testing.expect(!shouldChannelLightning(1, true, false));
    try std.testing.expect(!shouldChannelLightning(0, true, true));
}

test "impaling damage scales with level" {
    try std.testing.expectEqual(@as(f32, 2.5), getImpalingDamage(1));
    try std.testing.expectEqual(@as(f32, 5.0), getImpalingDamage(2));
    try std.testing.expectEqual(@as(f32, 7.5), getImpalingDamage(3));
    try std.testing.expectEqual(@as(f32, 12.5), getImpalingDamage(5));
}

test "aquatic mob identification" {
    try std.testing.expect(isAquaticMob(.guardian));
    try std.testing.expect(isAquaticMob(.elder_guardian));
    try std.testing.expect(isAquaticMob(.squid));
    try std.testing.expect(isAquaticMob(.dolphin));
    try std.testing.expect(isAquaticMob(.drowned));
    try std.testing.expect(isAquaticMob(.turtle));
    try std.testing.expect(isAquaticMob(.axolotl));
    try std.testing.expect(!isAquaticMob(.other));
}

test "loyalty return speed by level" {
    try std.testing.expectEqual(@as(f32, 8.0), getLoyaltyReturnSpeed(1));
    try std.testing.expectEqual(@as(f32, 12.0), getLoyaltyReturnSpeed(2));
    try std.testing.expectEqual(@as(f32, 16.0), getLoyaltyReturnSpeed(3));
    try std.testing.expectEqual(@as(f32, 0.0), getLoyaltyReturnSpeed(0));
}

test "riptide launch velocity scales with level" {
    try std.testing.expectEqual(@as(f32, 3.0), getRiptideLaunchVelocity(1));
    try std.testing.expectEqual(@as(f32, 6.0), getRiptideLaunchVelocity(2));
    try std.testing.expectEqual(@as(f32, 9.0), getRiptideLaunchVelocity(3));
}

test "trident state rejects incompatible enchants" {
    var state = TridentState{};
    try std.testing.expect(state.addEnchant(.loyalty, 3));
    try std.testing.expect(!state.addEnchant(.riptide, 1));
    try std.testing.expectEqual(@as(u8, 1), state.enchant_count);
}

test "trident state accepts compatible enchants" {
    var state = TridentState{};
    try std.testing.expect(state.addEnchant(.loyalty, 3));
    try std.testing.expect(state.addEnchant(.channeling, 1));
    try std.testing.expect(state.addEnchant(.impaling, 5));
    try std.testing.expectEqual(@as(u8, 3), state.enchant_count);
}
