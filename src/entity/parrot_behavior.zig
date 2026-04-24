/// Parrot entity behavior: perching on shoulders, dancing near jukeboxes,
/// and mimicking sounds of nearby mobs.
/// Parrots come in 5 color variants matching vanilla Minecraft.
const std = @import("std");

// ---------------------------------------------------------------------------
// Color Variants
// ---------------------------------------------------------------------------

pub const ParrotColor = enum(u3) {
    red,
    blue,
    green,
    cyan,
    gray,
};

// ---------------------------------------------------------------------------
// Shoulder Side
// ---------------------------------------------------------------------------

pub const ShoulderSide = enum(u1) {
    left,
    right,
};

// ---------------------------------------------------------------------------
// Mob type constants (used for mimic sound mapping)
// ---------------------------------------------------------------------------

pub const MOB_ZOMBIE: u8 = 1;
pub const MOB_CREEPER: u8 = 2;
pub const MOB_SPIDER: u8 = 3;
pub const MOB_SKELETON: u8 = 4;
pub const MOB_ENDERMAN: u8 = 5;
pub const MOB_BLAZE: u8 = 6;
pub const MOB_GHAST: u8 = 7;

// Mimic sound IDs returned by getMimicSound
pub const SOUND_ZOMBIE_MIMIC: u8 = 101;
pub const SOUND_CREEPER_MIMIC: u8 = 102;
pub const SOUND_SPIDER_MIMIC: u8 = 103;
pub const SOUND_SKELETON_MIMIC: u8 = 104;
pub const SOUND_ENDERMAN_MIMIC: u8 = 105;
pub const SOUND_BLAZE_MIMIC: u8 = 106;
pub const SOUND_GHAST_MIMIC: u8 = 107;

// ---------------------------------------------------------------------------
// Parrot
// ---------------------------------------------------------------------------

pub const Parrot = struct {
    color: ParrotColor = .red,
    is_tamed: bool = false,
    shoulder_side: ?ShoulderSide = null,
    is_dancing: bool = false,

    // -- Constants --
    const jukebox_dance_range: f32 = 3.0;

    /// Place this parrot on the player's shoulder. Only tamed parrots can perch.
    /// Returns a new Parrot with the shoulder_side set, or the original if untamed.
    pub fn perchOnShoulder(self: Parrot, side: ShoulderSide) Parrot {
        if (!self.is_tamed) return self;
        return Parrot{
            .color = self.color,
            .is_tamed = self.is_tamed,
            .shoulder_side = side,
            .is_dancing = self.is_dancing,
        };
    }

    /// Remove the parrot from the player's shoulder.
    /// Returns a new Parrot with shoulder_side cleared.
    pub fn dismount(self: Parrot) Parrot {
        return Parrot{
            .color = self.color,
            .is_tamed = self.is_tamed,
            .shoulder_side = null,
            .is_dancing = self.is_dancing,
        };
    }

    /// Begin dancing. Returns a new Parrot with is_dancing set.
    pub fn startDancing(self: Parrot) Parrot {
        return Parrot{
            .color = self.color,
            .is_tamed = self.is_tamed,
            .shoulder_side = self.shoulder_side,
            .is_dancing = true,
        };
    }

    /// Stop dancing. Returns a new Parrot with is_dancing cleared.
    pub fn stopDancing(self: Parrot) Parrot {
        return Parrot{
            .color = self.color,
            .is_tamed = self.is_tamed,
            .shoulder_side = self.shoulder_side,
            .is_dancing = false,
        };
    }

    /// Returns true when the jukebox is within 3 blocks (the dance range).
    pub fn shouldDance(jukebox_distance: f32) bool {
        return jukebox_distance <= jukebox_dance_range;
    }

    /// Maps a nearby mob type to the corresponding mimic sound ID.
    /// Returns null for unknown mob types.
    pub fn getMimicSound(nearby_mob_type: u8) ?u8 {
        return switch (nearby_mob_type) {
            MOB_ZOMBIE => SOUND_ZOMBIE_MIMIC,
            MOB_CREEPER => SOUND_CREEPER_MIMIC,
            MOB_SPIDER => SOUND_SPIDER_MIMIC,
            MOB_SKELETON => SOUND_SKELETON_MIMIC,
            MOB_ENDERMAN => SOUND_ENDERMAN_MIMIC,
            MOB_BLAZE => SOUND_BLAZE_MIMIC,
            MOB_GHAST => SOUND_GHAST_MIMIC,
            else => null,
        };
    }
};

// ===========================================================================
// Tests
// ===========================================================================

test "default parrot is untamed red, not perched, not dancing" {
    const parrot = Parrot{};
    try std.testing.expectEqual(ParrotColor.red, parrot.color);
    try std.testing.expectEqual(false, parrot.is_tamed);
    try std.testing.expectEqual(@as(?ShoulderSide, null), parrot.shoulder_side);
    try std.testing.expectEqual(false, parrot.is_dancing);
}

test "perchOnShoulder sets side for tamed parrot" {
    const parrot = Parrot{ .is_tamed = true };
    const perched = parrot.perchOnShoulder(.left);
    try std.testing.expectEqual(@as(?ShoulderSide, .left), perched.shoulder_side);
    try std.testing.expectEqual(true, perched.is_tamed);
}

test "perchOnShoulder is no-op for untamed parrot" {
    const parrot = Parrot{};
    const result = parrot.perchOnShoulder(.right);
    try std.testing.expectEqual(@as(?ShoulderSide, null), result.shoulder_side);
}

test "dismount clears shoulder side" {
    const parrot = Parrot{ .is_tamed = true, .shoulder_side = .right };
    const dismounted = parrot.dismount();
    try std.testing.expectEqual(@as(?ShoulderSide, null), dismounted.shoulder_side);
    try std.testing.expectEqual(true, dismounted.is_tamed);
}

test "startDancing sets dancing flag" {
    const parrot = Parrot{ .color = .blue };
    const dancing = parrot.startDancing();
    try std.testing.expectEqual(true, dancing.is_dancing);
    try std.testing.expectEqual(ParrotColor.blue, dancing.color);
}

test "stopDancing clears dancing flag" {
    const parrot = Parrot{ .is_dancing = true };
    const stopped = parrot.stopDancing();
    try std.testing.expectEqual(false, stopped.is_dancing);
}

test "shouldDance returns true within 3 blocks" {
    try std.testing.expectEqual(true, Parrot.shouldDance(0.0));
    try std.testing.expectEqual(true, Parrot.shouldDance(2.5));
    try std.testing.expectEqual(true, Parrot.shouldDance(3.0));
}

test "shouldDance returns false beyond 3 blocks" {
    try std.testing.expectEqual(false, Parrot.shouldDance(3.1));
    try std.testing.expectEqual(false, Parrot.shouldDance(10.0));
}

test "getMimicSound returns correct sound for known mobs" {
    try std.testing.expectEqual(@as(?u8, SOUND_ZOMBIE_MIMIC), Parrot.getMimicSound(MOB_ZOMBIE));
    try std.testing.expectEqual(@as(?u8, SOUND_CREEPER_MIMIC), Parrot.getMimicSound(MOB_CREEPER));
    try std.testing.expectEqual(@as(?u8, SOUND_SPIDER_MIMIC), Parrot.getMimicSound(MOB_SPIDER));
    try std.testing.expectEqual(@as(?u8, SOUND_SKELETON_MIMIC), Parrot.getMimicSound(MOB_SKELETON));
    try std.testing.expectEqual(@as(?u8, SOUND_ENDERMAN_MIMIC), Parrot.getMimicSound(MOB_ENDERMAN));
    try std.testing.expectEqual(@as(?u8, SOUND_BLAZE_MIMIC), Parrot.getMimicSound(MOB_BLAZE));
    try std.testing.expectEqual(@as(?u8, SOUND_GHAST_MIMIC), Parrot.getMimicSound(MOB_GHAST));
}

test "getMimicSound returns null for unknown mob type" {
    try std.testing.expectEqual(@as(?u8, null), Parrot.getMimicSound(0));
    try std.testing.expectEqual(@as(?u8, null), Parrot.getMimicSound(255));
}

test "perch preserves color and dancing state" {
    const parrot = Parrot{ .color = .cyan, .is_tamed = true, .is_dancing = true };
    const perched = parrot.perchOnShoulder(.right);
    try std.testing.expectEqual(ParrotColor.cyan, perched.color);
    try std.testing.expectEqual(true, perched.is_dancing);
    try std.testing.expectEqual(@as(?ShoulderSide, .right), perched.shoulder_side);
}

test "parrot color enum values" {
    try std.testing.expectEqual(@as(u3, 0), @intFromEnum(ParrotColor.red));
    try std.testing.expectEqual(@as(u3, 1), @intFromEnum(ParrotColor.blue));
    try std.testing.expectEqual(@as(u3, 2), @intFromEnum(ParrotColor.green));
    try std.testing.expectEqual(@as(u3, 3), @intFromEnum(ParrotColor.cyan));
    try std.testing.expectEqual(@as(u3, 4), @intFromEnum(ParrotColor.gray));
}

test "dismount preserves color and tame status" {
    const parrot = Parrot{ .color = .green, .is_tamed = true, .shoulder_side = .left, .is_dancing = true };
    const dismounted = parrot.dismount();
    try std.testing.expectEqual(ParrotColor.green, dismounted.color);
    try std.testing.expectEqual(true, dismounted.is_tamed);
    try std.testing.expectEqual(true, dismounted.is_dancing);
}
