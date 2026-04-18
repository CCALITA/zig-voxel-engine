const std = @import("std");

pub const ParrotColor = enum(u3) {
    red = 0,
    blue = 1,
    green = 2,
    cyan = 3,
    gray = 4,
};

pub const ShoulderSide = enum(u1) {
    left = 0,
    right = 1,
};

pub const ParrotEntity = struct {
    x: f32,
    y: f32,
    z: f32,
    color: ParrotColor,
    on_shoulder: bool,
    shoulder_side: ShoulderSide,
    dancing: bool,
    imitating: ?u8,

    pub fn init(x: f32, y: f32, z: f32, color: ParrotColor) ParrotEntity {
        return .{
            .x = x,
            .y = y,
            .z = z,
            .color = color,
            .on_shoulder = false,
            .shoulder_side = .left,
            .dancing = false,
            .imitating = null,
        };
    }

    pub fn perch(self: *ParrotEntity, side: ShoulderSide) void {
        self.on_shoulder = true;
        self.shoulder_side = side;
        self.dancing = false;
    }

    pub fn dismount(self: *ParrotEntity) void {
        self.on_shoulder = false;
    }

    pub fn dance(self: *ParrotEntity) void {
        if (!self.on_shoulder) {
            self.dancing = true;
        }
    }

    pub fn imitateSound(self: *ParrotEntity, mob_type: u8) ?u8 {
        self.imitating = mob_type;
        return switch (mob_type) {
            0 => @as(u8, 10), // zombie -> groan
            1 => @as(u8, 11), // skeleton -> rattle
            2 => @as(u8, 12), // creeper -> hiss
            3 => @as(u8, 13), // spider -> hiss
            4 => @as(u8, 14), // ghast -> scream
            5 => @as(u8, 15), // blaze -> breath
            else => null,
        };
    }
};

pub const WolfVariant = enum(u4) {
    pale = 0,
    timber = 1,
    ashen = 2,
    black = 3,
    chestnut = 4,
    rusty = 5,
    snowy = 6,
    spotted = 7,
    striped = 8,
};

pub const WolfEntity = struct {
    variant: WolfVariant,
    collar_color: u4 = 14,
    health: f32 = 20,
    sitting: bool,
    angry: bool,
    owner_id: ?u32,

    pub fn init(variant: WolfVariant) WolfEntity {
        return .{
            .variant = variant,
            .collar_color = 14,
            .health = 20,
            .sitting = false,
            .angry = false,
            .owner_id = null,
        };
    }

    pub fn getVariantForBiome(biome: u8) WolfVariant {
        return switch (biome) {
            0 => .pale, // plains
            1 => .timber, // taiga
            2 => .ashen, // snowy_taiga
            3 => .black, // old_growth_pine_taiga
            4 => .chestnut, // old_growth_spruce_taiga
            5 => .rusty, // jungle
            6 => .snowy, // grove
            7 => .spotted, // savanna
            8 => .striped, // wooded_badlands
            else => .pale,
        };
    }

    pub fn dyeCollar(self: *WolfEntity, color: u4) void {
        self.collar_color = color;
    }

    pub fn getTextureName(self: WolfEntity) [32]u8 {
        var buf: [32]u8 = [_]u8{0} ** 32;
        const prefix = "wolf_";
        const suffix = @tagName(self.variant);
        @memcpy(buf[0..prefix.len], prefix);
        @memcpy(buf[prefix.len .. prefix.len + suffix.len], suffix);
        return buf;
    }
};

test "parrot has 5 colors" {
    const colors = [_]ParrotColor{ .red, .blue, .green, .cyan, .gray };
    try std.testing.expectEqual(@as(usize, 5), colors.len);
    try std.testing.expectEqual(@as(u3, 0), @intFromEnum(ParrotColor.red));
    try std.testing.expectEqual(@as(u3, 4), @intFromEnum(ParrotColor.gray));
}

test "parrot shoulder perch and dismount" {
    var parrot = ParrotEntity.init(1.0, 2.0, 3.0, .red);
    try std.testing.expect(!parrot.on_shoulder);

    parrot.perch(.left);
    try std.testing.expect(parrot.on_shoulder);
    try std.testing.expectEqual(ShoulderSide.left, parrot.shoulder_side);

    parrot.perch(.right);
    try std.testing.expect(parrot.on_shoulder);
    try std.testing.expectEqual(ShoulderSide.right, parrot.shoulder_side);

    parrot.dismount();
    try std.testing.expect(!parrot.on_shoulder);
}

test "parrot dancing stops when perched" {
    var parrot = ParrotEntity.init(0, 0, 0, .blue);
    parrot.dance();
    try std.testing.expect(parrot.dancing);

    parrot.perch(.left);
    try std.testing.expect(!parrot.dancing);
}

test "parrot imitate sound returns correct event IDs" {
    var parrot = ParrotEntity.init(0, 0, 0, .green);
    try std.testing.expectEqual(@as(?u8, 10), parrot.imitateSound(0));
    try std.testing.expectEqual(@as(?u8, 11), parrot.imitateSound(1));
    try std.testing.expectEqual(@as(?u8, null), parrot.imitateSound(255));
}

test "wolf has 9 variants" {
    const variants = [_]WolfVariant{ .pale, .timber, .ashen, .black, .chestnut, .rusty, .snowy, .spotted, .striped };
    try std.testing.expectEqual(@as(usize, 9), variants.len);
    try std.testing.expectEqual(@as(u4, 0), @intFromEnum(WolfVariant.pale));
    try std.testing.expectEqual(@as(u4, 8), @intFromEnum(WolfVariant.striped));
}

test "wolf biome mapping returns correct variants" {
    try std.testing.expectEqual(WolfVariant.pale, WolfEntity.getVariantForBiome(0));
    try std.testing.expectEqual(WolfVariant.timber, WolfEntity.getVariantForBiome(1));
    try std.testing.expectEqual(WolfVariant.ashen, WolfEntity.getVariantForBiome(2));
    try std.testing.expectEqual(WolfVariant.black, WolfEntity.getVariantForBiome(3));
    try std.testing.expectEqual(WolfVariant.chestnut, WolfEntity.getVariantForBiome(4));
    try std.testing.expectEqual(WolfVariant.rusty, WolfEntity.getVariantForBiome(5));
    try std.testing.expectEqual(WolfVariant.snowy, WolfEntity.getVariantForBiome(6));
    try std.testing.expectEqual(WolfVariant.spotted, WolfEntity.getVariantForBiome(7));
    try std.testing.expectEqual(WolfVariant.striped, WolfEntity.getVariantForBiome(8));
    try std.testing.expectEqual(WolfVariant.pale, WolfEntity.getVariantForBiome(99));
}

test "wolf collar dye changes color" {
    var wolf = WolfEntity.init(.pale);
    try std.testing.expectEqual(@as(u4, 14), wolf.collar_color);

    wolf.dyeCollar(1);
    try std.testing.expectEqual(@as(u4, 1), wolf.collar_color);

    wolf.dyeCollar(11);
    try std.testing.expectEqual(@as(u4, 11), wolf.collar_color);
}

test "wolf texture name" {
    const wolf = WolfEntity.init(.timber);
    const name = wolf.getTextureName();
    const expected = "wolf_timber";
    try std.testing.expectEqualSlices(u8, expected, name[0..expected.len]);
    try std.testing.expectEqual(@as(u8, 0), name[expected.len]);
}

test "wolf default values" {
    const wolf = WolfEntity.init(.pale);
    try std.testing.expectEqual(@as(f32, 20), wolf.health);
    try std.testing.expectEqual(@as(u4, 14), wolf.collar_color);
    try std.testing.expect(!wolf.sitting);
    try std.testing.expect(!wolf.angry);
    try std.testing.expectEqual(@as(?u32, null), wolf.owner_id);
}
