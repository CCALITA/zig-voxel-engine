/// Extended enchantment system for items not covered by the base enchanting module.
/// Adds mending, looting, thorns, fire aspect, sweeping edge, crossbow enchantments,
/// movement enchantments, fishing enchantments, and curses.

const std = @import("std");

// ---------------------------------------------------------------------------
// Applicable-item bitflags
// ---------------------------------------------------------------------------

pub const ApplicableItems = packed struct(u16) {
    sword: bool = false,
    axe: bool = false,
    pickaxe: bool = false,
    shovel: bool = false,
    hoe: bool = false,
    bow: bool = false,
    crossbow: bool = false,
    trident: bool = false,
    helmet: bool = false,
    chestplate: bool = false,
    leggings: bool = false,
    boots: bool = false,
    fishing_rod: bool = false,
    elytra: bool = false,
    shield: bool = false,
    _padding: bool = false,

    pub const all_armor = ApplicableItems{
        .helmet = true,
        .chestplate = true,
        .leggings = true,
        .boots = true,
    };
    pub const all_melee = ApplicableItems{
        .sword = true,
        .axe = true,
    };
    pub const all_tools = ApplicableItems{
        .pickaxe = true,
        .shovel = true,
        .hoe = true,
        .axe = true,
    };
    pub const boots_only = ApplicableItems{ .boots = true };
    pub const sword_only = ApplicableItems{ .sword = true };
    pub const crossbow_only = ApplicableItems{ .crossbow = true };
    pub const fishing_rod_only = ApplicableItems{ .fishing_rod = true };
    pub const leggings_only = ApplicableItems{ .leggings = true };

    /// Any equippable / holdable item (used for mending and curses).
    pub const any = ApplicableItems{
        .sword = true,
        .axe = true,
        .pickaxe = true,
        .shovel = true,
        .hoe = true,
        .bow = true,
        .crossbow = true,
        .trident = true,
        .helmet = true,
        .chestplate = true,
        .leggings = true,
        .boots = true,
        .fishing_rod = true,
        .elytra = true,
        .shield = true,
    };
};

// ---------------------------------------------------------------------------
// Enchantment identifiers
// ---------------------------------------------------------------------------

pub const ExtendedEnchantId = enum(u8) {
    mending,
    looting,
    luck_of_the_sea,
    lure,
    depth_strider,
    frost_walker,
    thorns,
    fire_aspect,
    sweeping_edge,
    piercing,
    multishot,
    quick_charge,
    soul_speed,
    swift_sneak,
    knockback,
    curse_of_vanishing,
    curse_of_binding,
};

// ---------------------------------------------------------------------------
// Enchantment descriptor (compile-time metadata)
// ---------------------------------------------------------------------------

pub const EnchantDescriptor = struct {
    id: ExtendedEnchantId,
    max_level: u8,
    applicable_items: ApplicableItems,
    is_treasure: bool,
    is_curse: bool,
};

pub const enchant_descriptors = [_]EnchantDescriptor{
    .{ .id = .mending, .max_level = 1, .applicable_items = ApplicableItems.any, .is_treasure = true, .is_curse = false },
    .{ .id = .looting, .max_level = 3, .applicable_items = ApplicableItems.sword_only, .is_treasure = false, .is_curse = false },
    .{ .id = .luck_of_the_sea, .max_level = 3, .applicable_items = ApplicableItems.fishing_rod_only, .is_treasure = false, .is_curse = false },
    .{ .id = .lure, .max_level = 3, .applicable_items = ApplicableItems.fishing_rod_only, .is_treasure = false, .is_curse = false },
    .{ .id = .depth_strider, .max_level = 3, .applicable_items = ApplicableItems.boots_only, .is_treasure = false, .is_curse = false },
    .{ .id = .frost_walker, .max_level = 2, .applicable_items = ApplicableItems.boots_only, .is_treasure = true, .is_curse = false },
    .{ .id = .thorns, .max_level = 3, .applicable_items = ApplicableItems.all_armor, .is_treasure = false, .is_curse = false },
    .{ .id = .fire_aspect, .max_level = 2, .applicable_items = ApplicableItems.sword_only, .is_treasure = false, .is_curse = false },
    .{ .id = .sweeping_edge, .max_level = 3, .applicable_items = ApplicableItems.sword_only, .is_treasure = false, .is_curse = false },
    .{ .id = .piercing, .max_level = 4, .applicable_items = ApplicableItems.crossbow_only, .is_treasure = false, .is_curse = false },
    .{ .id = .multishot, .max_level = 1, .applicable_items = ApplicableItems.crossbow_only, .is_treasure = false, .is_curse = false },
    .{ .id = .quick_charge, .max_level = 3, .applicable_items = ApplicableItems.crossbow_only, .is_treasure = false, .is_curse = false },
    .{ .id = .soul_speed, .max_level = 3, .applicable_items = ApplicableItems.boots_only, .is_treasure = true, .is_curse = false },
    .{ .id = .swift_sneak, .max_level = 3, .applicable_items = ApplicableItems.leggings_only, .is_treasure = true, .is_curse = false },
    .{ .id = .knockback, .max_level = 2, .applicable_items = ApplicableItems.sword_only, .is_treasure = false, .is_curse = false },
    .{ .id = .curse_of_vanishing, .max_level = 1, .applicable_items = ApplicableItems.any, .is_treasure = true, .is_curse = true },
    .{ .id = .curse_of_binding, .max_level = 1, .applicable_items = ApplicableItems.all_armor, .is_treasure = true, .is_curse = true },
};

/// Look up the descriptor for a given enchantment id.
pub fn getDescriptor(id: ExtendedEnchantId) EnchantDescriptor {
    return enchant_descriptors[@intFromEnum(id)];
}

// ---------------------------------------------------------------------------
// Effect context and result
// ---------------------------------------------------------------------------

pub const EffectContext = struct {
    /// Experience points available (used by mending).
    xp_available: u32 = 0,
    /// Current item durability damage (0 = pristine).
    durability_damage: u32 = 0,
    /// Base drop count before modifiers (used by looting).
    base_drop_count: u32 = 0,
    /// Base fishing wait time in seconds.
    base_fishing_wait_s: f32 = 20.0,
    /// Fishing junk chance percentage (0-100).
    fishing_junk_pct: f32 = 10.0,
    /// Fishing treasure chance percentage (0-100).
    fishing_treasure_pct: f32 = 5.0,
    /// Base movement speed multiplier (1.0 = normal).
    base_speed_multiplier: f32 = 1.0,
    /// Whether the entity is underwater.
    is_underwater: bool = false,
    /// Whether the entity is standing on soul sand or soul soil.
    on_soul_block: bool = false,
    /// Whether the entity is sneaking.
    is_sneaking: bool = false,
    /// Base crossbow reload time in seconds.
    base_reload_time_s: f32 = 1.25,
    /// Base damage dealt by attacker (used by sweeping edge).
    base_damage: f32 = 0.0,
    /// Random value in [0, 1) for probabilistic effects (thorns).
    random_roll: f32 = 0.0,
    /// Whether the player died (used by curse of vanishing).
    player_died: bool = false,
};

pub const EffectResult = struct {
    /// Durability repaired via mending (subtracted from durability_damage).
    durability_repaired: u32 = 0,
    /// XP consumed by mending.
    xp_consumed: u32 = 0,
    /// Maximum extra drops added by looting.
    extra_max_drops: u32 = 0,
    /// Adjusted fishing wait time in seconds.
    fishing_wait_s: f32 = 0.0,
    /// Adjusted fishing junk percentage.
    fishing_junk_pct: f32 = 0.0,
    /// Adjusted fishing treasure percentage.
    fishing_treasure_pct: f32 = 0.0,
    /// Resulting speed multiplier.
    speed_multiplier: f32 = 1.0,
    /// Radius in blocks for frost walker ice creation.
    frost_walker_radius: u8 = 0,
    /// Damage reflected by thorns (0 if no proc).
    thorns_damage: f32 = 0.0,
    /// Duration target is set on fire (seconds), 0 if none.
    fire_duration_s: f32 = 0.0,
    /// Sweeping attack damage applied to nearby entities.
    sweeping_damage: f32 = 0.0,
    /// Number of entities an arrow can pass through.
    pierce_count: u8 = 0,
    /// Number of arrows / projectiles fired.
    projectile_count: u8 = 1,
    /// Adjusted crossbow reload time.
    reload_time_s: f32 = 0.0,
    /// Additional knockback in blocks.
    knockback_blocks: f32 = 0.0,
    /// True if the item should be destroyed (curse of vanishing).
    item_destroyed: bool = false,
    /// True if the item cannot be unequipped (curse of binding).
    cannot_unequip: bool = false,
};

// ---------------------------------------------------------------------------
// Core effect computation
// ---------------------------------------------------------------------------

/// Compute the gameplay effect of `enchant` at `level` given `context`.
/// Returns an `EffectResult` with only the fields relevant to the enchantment
/// populated; all other fields retain their defaults.
pub fn applyEffect(enchant: ExtendedEnchantId, level: u8, context: EffectContext) EffectResult {
    const desc = getDescriptor(enchant);
    const clamped = @min(level, desc.max_level);
    const lvl_f: f32 = @floatFromInt(clamped);

    return switch (enchant) {
        // Mending: 2 durability points per 1 XP consumed.
        .mending => blk: {
            const repairable = context.durability_damage;
            // Each XP point repairs 2 durability.
            const xp_needed = (repairable + 1) / 2; // ceil division
            const xp_used = @min(xp_needed, context.xp_available);
            const repaired = @min(xp_used * 2, repairable);
            break :blk EffectResult{
                .durability_repaired = repaired,
                .xp_consumed = xp_used,
            };
        },

        // Looting I-III: +1 max drops per level.
        .looting => EffectResult{
            .extra_max_drops = clamped,
        },

        // Luck of the Sea I-III: -1% junk per level, +1% treasure per level.
        .luck_of_the_sea => EffectResult{
            .fishing_junk_pct = @max(0.0, context.fishing_junk_pct - lvl_f),
            .fishing_treasure_pct = context.fishing_treasure_pct + lvl_f,
        },

        // Lure I-III: -5s fishing wait per level (minimum 1s).
        .lure => EffectResult{
            .fishing_wait_s = @max(1.0, context.base_fishing_wait_s - 5.0 * lvl_f),
        },

        // Depth Strider I-III: underwater speed +33% per level.
        .depth_strider => blk: {
            const multiplier = if (context.is_underwater)
                context.base_speed_multiplier * (1.0 + 0.33 * lvl_f)
            else
                context.base_speed_multiplier;
            break :blk EffectResult{
                .speed_multiplier = multiplier,
            };
        },

        // Frost Walker I-II: creates frosted ice within 2+level block radius.
        .frost_walker => EffectResult{
            .frost_walker_radius = @intCast(2 + clamped),
        },

        // Thorns I-III: 15% * level chance to deal 1-4 damage.
        .thorns => blk: {
            const proc_chance = 0.15 * lvl_f;
            const damage: f32 = if (context.random_roll < proc_chance)
                // Damage range 1-4; use random_roll scaled within proc window.
                1.0 + (context.random_roll / proc_chance) * 3.0
            else
                0.0;
            break :blk EffectResult{
                .thorns_damage = damage,
            };
        },

        // Fire Aspect I-II: sets target on fire for 4s per level.
        .fire_aspect => EffectResult{
            .fire_duration_s = 4.0 * lvl_f,
        },

        // Sweeping Edge I-III: 50/67/75% of attack damage as sweep.
        .sweeping_edge => blk: {
            const pct: f32 = switch (clamped) {
                1 => 0.50,
                2 => 0.67,
                3 => 0.75,
                else => 0.0,
            };
            break :blk EffectResult{
                .sweeping_damage = context.base_damage * pct,
            };
        },

        // Piercing I-IV: arrows pass through `level` entities.
        .piercing => EffectResult{
            .pierce_count = clamped,
        },

        // Multishot: fires 3 arrows instead of 1.
        .multishot => EffectResult{
            .projectile_count = 3,
        },

        // Quick Charge I-III: -0.25s crossbow reload per level.
        .quick_charge => EffectResult{
            .reload_time_s = @max(0.0, context.base_reload_time_s - 0.25 * lvl_f),
        },

        // Soul Speed I-III: +speed on soul sand/soil (+40% per level base).
        .soul_speed => blk: {
            const multiplier = if (context.on_soul_block)
                context.base_speed_multiplier * (1.0 + 0.40 * lvl_f)
            else
                context.base_speed_multiplier;
            break :blk EffectResult{
                .speed_multiplier = multiplier,
            };
        },

        // Swift Sneak I-III: sneak speed 45/60/75% of walk speed.
        .swift_sneak => blk: {
            const pct: f32 = switch (clamped) {
                1 => 0.45,
                2 => 0.60,
                3 => 0.75,
                else => 0.30, // vanilla default sneak speed
            };
            const multiplier = if (context.is_sneaking)
                context.base_speed_multiplier * pct
            else
                context.base_speed_multiplier;
            break :blk EffectResult{
                .speed_multiplier = multiplier,
            };
        },

        // Knockback I-II: +3 blocks knockback per level.
        .knockback => EffectResult{
            .knockback_blocks = 3.0 * lvl_f,
        },

        // Curse of Vanishing: item destroyed on death.
        .curse_of_vanishing => EffectResult{
            .item_destroyed = context.player_died,
        },

        // Curse of Binding: cannot unequip the item.
        .curse_of_binding => EffectResult{
            .cannot_unequip = true,
        },
    };
}

/// Return the enchanting-table XP cost for a given extended enchantment and level.
pub fn getEnchantCost(id: ExtendedEnchantId, level: u8) u32 {
    const desc = getDescriptor(id);
    const clamped: u32 = @min(level, desc.max_level);
    const base: u32 = switch (id) {
        .mending => 20,
        .looting => 8,
        .luck_of_the_sea => 8,
        .lure => 5,
        .depth_strider => 6,
        .frost_walker => 10,
        .thorns => 8,
        .fire_aspect => 10,
        .sweeping_edge => 5,
        .piercing => 5,
        .multishot => 10,
        .quick_charge => 5,
        .soul_speed => 10,
        .swift_sneak => 12,
        .knockback => 5,
        .curse_of_vanishing => 1,
        .curse_of_binding => 1,
    };
    return base * clamped;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "getDescriptor returns correct metadata" {
    const mending = getDescriptor(.mending);
    try std.testing.expectEqual(ExtendedEnchantId.mending, mending.id);
    try std.testing.expectEqual(@as(u8, 1), mending.max_level);
    try std.testing.expect(mending.is_treasure);
    try std.testing.expect(!mending.is_curse);

    const looting = getDescriptor(.looting);
    try std.testing.expectEqual(@as(u8, 3), looting.max_level);
    try std.testing.expect(looting.applicable_items.sword);
    try std.testing.expect(!looting.applicable_items.bow);

    const curse_v = getDescriptor(.curse_of_vanishing);
    try std.testing.expect(curse_v.is_curse);
    try std.testing.expect(curse_v.is_treasure);
}

test "mending repairs 2 durability per 1 XP" {
    const result = applyEffect(.mending, 1, .{
        .xp_available = 5,
        .durability_damage = 8,
    });
    // 5 XP repairs 10 durability, but only 8 is damaged.
    try std.testing.expectEqual(@as(u32, 8), result.durability_repaired);
    try std.testing.expectEqual(@as(u32, 4), result.xp_consumed);
}

test "mending with no damage consumes no XP" {
    const result = applyEffect(.mending, 1, .{
        .xp_available = 10,
        .durability_damage = 0,
    });
    try std.testing.expectEqual(@as(u32, 0), result.durability_repaired);
    try std.testing.expectEqual(@as(u32, 0), result.xp_consumed);
}

test "looting adds extra max drops per level" {
    const r1 = applyEffect(.looting, 1, .{});
    try std.testing.expectEqual(@as(u32, 1), r1.extra_max_drops);
    const r3 = applyEffect(.looting, 3, .{});
    try std.testing.expectEqual(@as(u32, 3), r3.extra_max_drops);
}

test "luck of the sea adjusts fishing chances" {
    const result = applyEffect(.luck_of_the_sea, 3, .{
        .fishing_junk_pct = 10.0,
        .fishing_treasure_pct = 5.0,
    });
    try std.testing.expectApproxEqAbs(@as(f32, 7.0), result.fishing_junk_pct, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 8.0), result.fishing_treasure_pct, 0.001);
}

test "lure reduces fishing wait time" {
    const result = applyEffect(.lure, 2, .{
        .base_fishing_wait_s = 20.0,
    });
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), result.fishing_wait_s, 0.001);
}

test "lure clamps minimum wait to 1s" {
    const result = applyEffect(.lure, 3, .{
        .base_fishing_wait_s = 10.0,
    });
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), result.fishing_wait_s, 0.001);
}

test "depth strider increases underwater speed" {
    const result = applyEffect(.depth_strider, 3, .{
        .base_speed_multiplier = 1.0,
        .is_underwater = true,
    });
    // 1.0 * (1 + 0.33 * 3) = 1.99
    try std.testing.expectApproxEqAbs(@as(f32, 1.99), result.speed_multiplier, 0.01);
}

test "depth strider no effect on land" {
    const result = applyEffect(.depth_strider, 3, .{
        .base_speed_multiplier = 1.0,
        .is_underwater = false,
    });
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), result.speed_multiplier, 0.001);
}

test "frost walker radius is 2 + level" {
    const r1 = applyEffect(.frost_walker, 1, .{});
    try std.testing.expectEqual(@as(u8, 3), r1.frost_walker_radius);
    const r2 = applyEffect(.frost_walker, 2, .{});
    try std.testing.expectEqual(@as(u8, 4), r2.frost_walker_radius);
}

test "thorns damage procs on low random roll" {
    const result = applyEffect(.thorns, 3, .{
        .random_roll = 0.10, // < 0.45 threshold
    });
    try std.testing.expect(result.thorns_damage >= 1.0);
    try std.testing.expect(result.thorns_damage <= 4.0);
}

test "thorns no damage on high random roll" {
    const result = applyEffect(.thorns, 1, .{
        .random_roll = 0.90, // > 0.15 threshold
    });
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), result.thorns_damage, 0.001);
}

test "fire aspect sets fire duration" {
    const r1 = applyEffect(.fire_aspect, 1, .{});
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), r1.fire_duration_s, 0.001);
    const r2 = applyEffect(.fire_aspect, 2, .{});
    try std.testing.expectApproxEqAbs(@as(f32, 8.0), r2.fire_duration_s, 0.001);
}

test "sweeping edge computes correct damage percentages" {
    const ctx = EffectContext{ .base_damage = 10.0 };
    const r1 = applyEffect(.sweeping_edge, 1, ctx);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), r1.sweeping_damage, 0.01);
    const r2 = applyEffect(.sweeping_edge, 2, ctx);
    try std.testing.expectApproxEqAbs(@as(f32, 6.7), r2.sweeping_damage, 0.01);
    const r3 = applyEffect(.sweeping_edge, 3, ctx);
    try std.testing.expectApproxEqAbs(@as(f32, 7.5), r3.sweeping_damage, 0.01);
}

test "piercing sets pierce count" {
    const result = applyEffect(.piercing, 4, .{});
    try std.testing.expectEqual(@as(u8, 4), result.pierce_count);
}

test "multishot fires 3 projectiles" {
    const result = applyEffect(.multishot, 1, .{});
    try std.testing.expectEqual(@as(u8, 3), result.projectile_count);
}

test "quick charge reduces reload time" {
    const result = applyEffect(.quick_charge, 3, .{
        .base_reload_time_s = 1.25,
    });
    try std.testing.expectApproxEqAbs(@as(f32, 0.50), result.reload_time_s, 0.001);
}

test "soul speed boosts on soul blocks" {
    const result = applyEffect(.soul_speed, 2, .{
        .base_speed_multiplier = 1.0,
        .on_soul_block = true,
    });
    // 1.0 * (1 + 0.40 * 2) = 1.80
    try std.testing.expectApproxEqAbs(@as(f32, 1.80), result.speed_multiplier, 0.01);
}

test "soul speed no effect off soul blocks" {
    const result = applyEffect(.soul_speed, 3, .{
        .base_speed_multiplier = 1.0,
        .on_soul_block = false,
    });
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), result.speed_multiplier, 0.001);
}

test "swift sneak adjusts sneak speed" {
    const r1 = applyEffect(.swift_sneak, 1, .{ .is_sneaking = true });
    try std.testing.expectApproxEqAbs(@as(f32, 0.45), r1.speed_multiplier, 0.001);
    const r2 = applyEffect(.swift_sneak, 2, .{ .is_sneaking = true });
    try std.testing.expectApproxEqAbs(@as(f32, 0.60), r2.speed_multiplier, 0.001);
    const r3 = applyEffect(.swift_sneak, 3, .{ .is_sneaking = true });
    try std.testing.expectApproxEqAbs(@as(f32, 0.75), r3.speed_multiplier, 0.001);
}

test "swift sneak no effect when not sneaking" {
    const result = applyEffect(.swift_sneak, 3, .{
        .is_sneaking = false,
        .base_speed_multiplier = 1.0,
    });
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), result.speed_multiplier, 0.001);
}

test "knockback adds 3 blocks per level" {
    const r1 = applyEffect(.knockback, 1, .{});
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), r1.knockback_blocks, 0.001);
    const r2 = applyEffect(.knockback, 2, .{});
    try std.testing.expectApproxEqAbs(@as(f32, 6.0), r2.knockback_blocks, 0.001);
}

test "curse of vanishing destroys item on death" {
    const alive = applyEffect(.curse_of_vanishing, 1, .{ .player_died = false });
    try std.testing.expect(!alive.item_destroyed);

    const dead = applyEffect(.curse_of_vanishing, 1, .{ .player_died = true });
    try std.testing.expect(dead.item_destroyed);
}

test "curse of binding prevents unequip" {
    const result = applyEffect(.curse_of_binding, 1, .{});
    try std.testing.expect(result.cannot_unequip);
}

test "level is clamped to max_level" {
    // Looting max is 3; passing 10 should behave as 3.
    const result = applyEffect(.looting, 10, .{});
    try std.testing.expectEqual(@as(u32, 3), result.extra_max_drops);
}

test "getEnchantCost returns base * clamped level" {
    try std.testing.expectEqual(@as(u32, 20), getEnchantCost(.mending, 1));
    try std.testing.expectEqual(@as(u32, 24), getEnchantCost(.looting, 3));
    try std.testing.expectEqual(@as(u32, 10), getEnchantCost(.fire_aspect, 1));
    try std.testing.expectEqual(@as(u32, 1), getEnchantCost(.curse_of_vanishing, 1));
    // Clamped: soul_speed max 3, passing 5 -> cost = 10 * 3 = 30
    try std.testing.expectEqual(@as(u32, 30), getEnchantCost(.soul_speed, 5));
}
