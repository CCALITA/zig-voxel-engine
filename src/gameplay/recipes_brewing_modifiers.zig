/// Brewing potion modifier system.
/// Extends base potions with duration, power, type, and delivery changes.
/// Modifiers transform existing potions via the brewing stand (e.g. adding
/// redstone dust to extend duration, gunpowder to create splash variants).

const std = @import("std");

// ---------------------------------------------------------------------------
// Modifier types
// ---------------------------------------------------------------------------

pub const ModifierType = enum {
    extend_duration,
    amplify,
    corrupt,
    splash,
    lingering,
};

pub const BrewModifier = struct {
    ingredient: u16,
    modifier_type: ModifierType,
};

pub const MODIFIERS = [_]BrewModifier{
    .{ .ingredient = 330, .modifier_type = .extend_duration }, // redstone dust
    .{ .ingredient = 383, .modifier_type = .amplify }, // glowstone dust
    .{ .ingredient = 384, .modifier_type = .corrupt }, // fermented spider eye
    .{ .ingredient = 317, .modifier_type = .splash }, // gunpowder
    .{ .ingredient = 385, .modifier_type = .lingering }, // dragon's breath
};

// ---------------------------------------------------------------------------
// Base potion IDs
// ---------------------------------------------------------------------------

const BASE_SPEED: u16 = 401;
const BASE_STRENGTH: u16 = 402;
const BASE_HEALING: u16 = 403;
const BASE_POISON: u16 = 404;
const BASE_REGEN: u16 = 405;
const BASE_FIRE_RESIST: u16 = 406;
const BASE_LEAPING: u16 = 407;
const BASE_SLOW_FALLING: u16 = 408;
const BASE_TURTLE_MASTER: u16 = 409;
const BASE_NIGHT_VISION: u16 = 410;

// Corruption target IDs (negative-effect potions).
// Placed at 470+ to avoid collisions with the modifier offset range (401-460).
const BASE_SLOWNESS: u16 = 470;
const BASE_WEAKNESS: u16 = 471;
const BASE_HARMING: u16 = 472;
const BASE_INVISIBILITY: u16 = 473;

// Offsets applied to the *base* ID for each modifier category
const OFFSET_EXTENDED: u16 = 10;
const OFFSET_AMPLIFIED: u16 = 20;
const OFFSET_CORRUPTED: u16 = 30;
const OFFSET_SPLASH: u16 = 40;
const OFFSET_LINGERING: u16 = 50;

// ---------------------------------------------------------------------------
// Potion transform table
// ---------------------------------------------------------------------------

pub const PotionTransform = struct {
    input: u16, // base potion ID
    output: u16, // modified potion ID
    modifier: ModifierType,
};

/// A single entry describing a base potion, its corruption inverse (0 = none),
/// and whether it supports extended / amplified variants.
const PotionSpec = struct {
    base: u16,
    corrupt_target: u16, // 0 means corruption is not applicable
    can_extend: bool,
    can_amplify: bool,
};

const POTION_SPECS = [_]PotionSpec{
    .{ .base = BASE_SPEED, .corrupt_target = BASE_SLOWNESS, .can_extend = true, .can_amplify = true },
    .{ .base = BASE_STRENGTH, .corrupt_target = BASE_WEAKNESS, .can_extend = true, .can_amplify = true },
    .{ .base = BASE_HEALING, .corrupt_target = BASE_HARMING, .can_extend = false, .can_amplify = true },
    .{ .base = BASE_POISON, .corrupt_target = BASE_HARMING, .can_extend = true, .can_amplify = true },
    .{ .base = BASE_REGEN, .corrupt_target = BASE_WEAKNESS, .can_extend = true, .can_amplify = true },
    .{ .base = BASE_FIRE_RESIST, .corrupt_target = BASE_SLOWNESS, .can_extend = true, .can_amplify = false },
    .{ .base = BASE_LEAPING, .corrupt_target = BASE_SLOW_FALLING, .can_extend = true, .can_amplify = true },
    .{ .base = BASE_SLOW_FALLING, .corrupt_target = 0, .can_extend = true, .can_amplify = false },
    .{ .base = BASE_TURTLE_MASTER, .corrupt_target = 0, .can_extend = true, .can_amplify = true },
    .{ .base = BASE_NIGHT_VISION, .corrupt_target = BASE_INVISIBILITY, .can_extend = true, .can_amplify = false },
};

/// Compute the number of transforms we will generate at comptime.
fn countTransforms() comptime_int {
    var n: comptime_int = 0;
    for (POTION_SPECS) |spec| {
        if (spec.can_extend) n += 1; // extend_duration
        if (spec.can_amplify) n += 1; // amplify
        if (spec.corrupt_target != 0) n += 1; // corrupt
        n += 1; // splash
        n += 1; // lingering
    }
    return n;
}

const TRANSFORM_COUNT = countTransforms();

fn buildTransforms() [TRANSFORM_COUNT]PotionTransform {
    var out: [TRANSFORM_COUNT]PotionTransform = undefined;
    var idx: usize = 0;
    for (POTION_SPECS) |spec| {
        if (spec.can_extend) {
            out[idx] = .{ .input = spec.base, .output = spec.base + OFFSET_EXTENDED, .modifier = .extend_duration };
            idx += 1;
        }
        if (spec.can_amplify) {
            out[idx] = .{ .input = spec.base, .output = spec.base + OFFSET_AMPLIFIED, .modifier = .amplify };
            idx += 1;
        }
        if (spec.corrupt_target != 0) {
            out[idx] = .{ .input = spec.base, .output = spec.base + OFFSET_CORRUPTED, .modifier = .corrupt };
            idx += 1;
        }
        out[idx] = .{ .input = spec.base, .output = spec.base + OFFSET_SPLASH, .modifier = .splash };
        idx += 1;
        out[idx] = .{ .input = spec.base, .output = spec.base + OFFSET_LINGERING, .modifier = .lingering };
        idx += 1;
    }
    return out;
}

pub const ALL_TRANSFORMS: [TRANSFORM_COUNT]PotionTransform = buildTransforms();

// ---------------------------------------------------------------------------
// Public helpers
// ---------------------------------------------------------------------------

/// Look up the modifier type for a given ingredient item ID.
fn findModifier(ingredient: u16) ?ModifierType {
    for (MODIFIERS) |m| {
        if (m.ingredient == ingredient) return m.modifier_type;
    }
    return null;
}

/// Apply a modifier ingredient to a potion and return the resulting potion ID.
/// Returns `null` when the combination is invalid.
pub fn applyModifier(potion_id: u16, ingredient: u16) ?u16 {
    const mod_type = findModifier(ingredient) orelse return null;
    for (ALL_TRANSFORMS) |t| {
        if (t.input == potion_id and t.modifier == mod_type) return t.output;
    }
    return null;
}

/// Return a human-readable name for a potion ID.
pub fn getPotionName(id: u16) []const u8 {
    return switch (id) {
        BASE_SPEED => "Potion of Swiftness",
        BASE_SPEED + OFFSET_EXTENDED => "Potion of Swiftness (Extended)",
        BASE_SPEED + OFFSET_AMPLIFIED => "Potion of Swiftness II",
        BASE_SPEED + OFFSET_CORRUPTED => "Potion of Swiftness (Corrupted)",
        BASE_SPEED + OFFSET_SPLASH => "Splash Potion of Swiftness",
        BASE_SPEED + OFFSET_LINGERING => "Lingering Potion of Swiftness",

        BASE_STRENGTH => "Potion of Strength",
        BASE_STRENGTH + OFFSET_EXTENDED => "Potion of Strength (Extended)",
        BASE_STRENGTH + OFFSET_AMPLIFIED => "Potion of Strength II",
        BASE_STRENGTH + OFFSET_CORRUPTED => "Potion of Strength (Corrupted)",
        BASE_STRENGTH + OFFSET_SPLASH => "Splash Potion of Strength",
        BASE_STRENGTH + OFFSET_LINGERING => "Lingering Potion of Strength",

        BASE_HEALING => "Potion of Healing",
        BASE_HEALING + OFFSET_AMPLIFIED => "Potion of Healing II",
        BASE_HEALING + OFFSET_CORRUPTED => "Potion of Healing (Corrupted)",
        BASE_HEALING + OFFSET_SPLASH => "Splash Potion of Healing",
        BASE_HEALING + OFFSET_LINGERING => "Lingering Potion of Healing",

        BASE_POISON => "Potion of Poison",
        BASE_POISON + OFFSET_EXTENDED => "Potion of Poison (Extended)",
        BASE_POISON + OFFSET_AMPLIFIED => "Potion of Poison II",
        BASE_POISON + OFFSET_CORRUPTED => "Potion of Poison (Corrupted)",
        BASE_POISON + OFFSET_SPLASH => "Splash Potion of Poison",
        BASE_POISON + OFFSET_LINGERING => "Lingering Potion of Poison",

        BASE_REGEN => "Potion of Regeneration",
        BASE_REGEN + OFFSET_EXTENDED => "Potion of Regeneration (Extended)",
        BASE_REGEN + OFFSET_AMPLIFIED => "Potion of Regeneration II",
        BASE_REGEN + OFFSET_CORRUPTED => "Potion of Regeneration (Corrupted)",
        BASE_REGEN + OFFSET_SPLASH => "Splash Potion of Regeneration",
        BASE_REGEN + OFFSET_LINGERING => "Lingering Potion of Regeneration",

        BASE_FIRE_RESIST => "Potion of Fire Resistance",
        BASE_FIRE_RESIST + OFFSET_EXTENDED => "Potion of Fire Resistance (Extended)",
        BASE_FIRE_RESIST + OFFSET_SPLASH => "Splash Potion of Fire Resistance",
        BASE_FIRE_RESIST + OFFSET_LINGERING => "Lingering Potion of Fire Resistance",

        BASE_LEAPING => "Potion of Leaping",
        BASE_LEAPING + OFFSET_EXTENDED => "Potion of Leaping (Extended)",
        BASE_LEAPING + OFFSET_AMPLIFIED => "Potion of Leaping II",
        BASE_LEAPING + OFFSET_CORRUPTED => "Potion of Leaping (Corrupted)",
        BASE_LEAPING + OFFSET_SPLASH => "Splash Potion of Leaping",
        BASE_LEAPING + OFFSET_LINGERING => "Lingering Potion of Leaping",

        BASE_SLOW_FALLING => "Potion of Slow Falling",
        BASE_SLOW_FALLING + OFFSET_EXTENDED => "Potion of Slow Falling (Extended)",
        BASE_SLOW_FALLING + OFFSET_SPLASH => "Splash Potion of Slow Falling",
        BASE_SLOW_FALLING + OFFSET_LINGERING => "Lingering Potion of Slow Falling",

        BASE_TURTLE_MASTER => "Potion of the Turtle Master",
        BASE_TURTLE_MASTER + OFFSET_EXTENDED => "Potion of the Turtle Master (Extended)",
        BASE_TURTLE_MASTER + OFFSET_AMPLIFIED => "Potion of the Turtle Master II",
        BASE_TURTLE_MASTER + OFFSET_SPLASH => "Splash Potion of the Turtle Master",
        BASE_TURTLE_MASTER + OFFSET_LINGERING => "Lingering Potion of the Turtle Master",

        BASE_NIGHT_VISION => "Potion of Night Vision",
        BASE_NIGHT_VISION + OFFSET_EXTENDED => "Potion of Night Vision (Extended)",
        BASE_NIGHT_VISION + OFFSET_CORRUPTED => "Potion of Night Vision (Corrupted)",
        BASE_NIGHT_VISION + OFFSET_SPLASH => "Splash Potion of Night Vision",
        BASE_NIGHT_VISION + OFFSET_LINGERING => "Lingering Potion of Night Vision",

        // Negative-effect base potions
        BASE_SLOWNESS => "Potion of Slowness",
        BASE_WEAKNESS => "Potion of Weakness",
        BASE_HARMING => "Potion of Harming",
        BASE_INVISIBILITY => "Potion of Invisibility",

        else => "Unknown Potion",
    };
}

/// Returns `true` when the potion ID is a splash variant.
pub fn isSplash(id: u16) bool {
    for (ALL_TRANSFORMS) |t| {
        if (t.output == id and t.modifier == .splash) return true;
    }
    return false;
}

/// Returns `true` when the potion ID is a lingering variant.
pub fn isLingering(id: u16) bool {
    for (ALL_TRANSFORMS) |t| {
        if (t.output == id and t.modifier == .lingering) return true;
    }
    return false;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "modifier count" {
    // 5 known modifier ingredients
    try std.testing.expectEqual(@as(usize, 5), MODIFIERS.len);
}

test "transform table is populated" {
    try std.testing.expect(ALL_TRANSFORMS.len > 0);
    // Every transform must have distinct input and output
    for (ALL_TRANSFORMS) |t| {
        try std.testing.expect(t.input != t.output);
    }
}

test "apply extend_duration to speed potion" {
    const result = applyModifier(BASE_SPEED, 330); // redstone dust
    try std.testing.expectEqual(@as(?u16, BASE_SPEED + OFFSET_EXTENDED), result);
}

test "apply amplify to strength potion" {
    const result = applyModifier(BASE_STRENGTH, 383); // glowstone dust
    try std.testing.expectEqual(@as(?u16, BASE_STRENGTH + OFFSET_AMPLIFIED), result);
}

test "apply corrupt to healing potion" {
    const result = applyModifier(BASE_HEALING, 384); // fermented spider eye
    try std.testing.expectEqual(@as(?u16, BASE_HEALING + OFFSET_CORRUPTED), result);
}

test "apply splash to poison potion" {
    const result = applyModifier(BASE_POISON, 317); // gunpowder
    try std.testing.expectEqual(@as(?u16, BASE_POISON + OFFSET_SPLASH), result);
}

test "apply lingering to regen potion" {
    const result = applyModifier(BASE_REGEN, 385); // dragon's breath
    try std.testing.expectEqual(@as(?u16, BASE_REGEN + OFFSET_LINGERING), result);
}

test "invalid ingredient returns null" {
    const result = applyModifier(BASE_SPEED, 999);
    try std.testing.expectEqual(@as(?u16, null), result);
}

test "invalid potion id returns null" {
    const result = applyModifier(9999, 330);
    try std.testing.expectEqual(@as(?u16, null), result);
}

test "isSplash identifies splash potions" {
    try std.testing.expect(isSplash(BASE_SPEED + OFFSET_SPLASH));
    try std.testing.expect(isSplash(BASE_TURTLE_MASTER + OFFSET_SPLASH));
    try std.testing.expect(!isSplash(BASE_SPEED));
    try std.testing.expect(!isSplash(BASE_SPEED + OFFSET_EXTENDED));
}

test "isLingering identifies lingering potions" {
    try std.testing.expect(isLingering(BASE_LEAPING + OFFSET_LINGERING));
    try std.testing.expect(!isLingering(BASE_LEAPING));
    try std.testing.expect(!isLingering(BASE_LEAPING + OFFSET_SPLASH));
}

test "getPotionName returns correct names" {
    try std.testing.expectEqualStrings("Potion of Swiftness", getPotionName(BASE_SPEED));
    try std.testing.expectEqualStrings("Potion of Strength II", getPotionName(BASE_STRENGTH + OFFSET_AMPLIFIED));
    try std.testing.expectEqualStrings("Splash Potion of Healing", getPotionName(BASE_HEALING + OFFSET_SPLASH));
    try std.testing.expectEqualStrings("Lingering Potion of Regeneration", getPotionName(BASE_REGEN + OFFSET_LINGERING));
    try std.testing.expectEqualStrings("Unknown Potion", getPotionName(9999));
}

test "healing has no extended variant" {
    const result = applyModifier(BASE_HEALING, 330); // redstone dust
    try std.testing.expectEqual(@as(?u16, null), result);
}

test "fire_resist has no amplified variant" {
    const result = applyModifier(BASE_FIRE_RESIST, 383); // glowstone dust
    try std.testing.expectEqual(@as(?u16, null), result);
}

test "slow_falling and turtle_master have no corrupt variant" {
    try std.testing.expectEqual(@as(?u16, null), applyModifier(BASE_SLOW_FALLING, 384));
    try std.testing.expectEqual(@as(?u16, null), applyModifier(BASE_TURTLE_MASTER, 384));
}
