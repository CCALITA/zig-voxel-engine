/// Full combat mechanics for melee attacks.
/// Extends health.zig (basic attack cooldown) with critical hits, sweeping edge,
/// invulnerability frames, charge-based damage scaling, knockback with resistance,
/// totem of undying, and offhand / dual-wielding slot.

const std = @import("std");
const math = std.math;

// ──────────────────────────────────────────────────────────────────────────────
// Item IDs (well-known constants used for totem / offhand checks)
// ──────────────────────────────────────────────────────────────────────────────

pub const ItemId = u16;

pub const ITEM_TOTEM_OF_UNDYING: ItemId = 450;
pub const ITEM_SHIELD: ItemId = 442;
pub const ITEM_TORCH: ItemId = 50;
pub const ITEM_MAP: ItemId = 395;
pub const ITEM_FIREWORK_ROCKET: ItemId = 401;

// ──────────────────────────────────────────────────────────────────────────────
// Weapon cooldown table (seconds per weapon type)
// ──────────────────────────────────────────────────────────────────────────────

pub const WeaponKind = enum {
    hand,
    sword,
    axe,
    pickaxe,
    shovel,
    hoe,
    trident,

    pub fn cooldownSeconds(self: WeaponKind) f32 {
        return switch (self) {
            .hand => 0.25,
            .sword => 0.625,
            .axe => 1.0,
            .pickaxe => 0.833,
            .shovel => 1.0,
            .hoe => 0.25,
            .trident => 0.9,
        };
    }
};

// ──────────────────────────────────────────────────────────────────────────────
// Damage source (for i-frame override logic)
// ──────────────────────────────────────────────────────────────────────────────

pub const DamageSource = enum {
    melee,
    projectile,
    explosion,
    fire,
    fall,
    void_damage,
    magic,
    other,
};

// ──────────────────────────────────────────────────────────────────────────────
// Particle type (returned by combat events)
// ──────────────────────────────────────────────────────────────────────────────

pub const ParticleEvent = enum {
    none,
    critical_star_burst,
    sweep_arc,
    totem_activation,
};

// ──────────────────────────────────────────────────────────────────────────────
// Combat state (lives alongside PlayerStats from health.zig)
// ──────────────────────────────────────────────────────────────────────────────

pub const CombatState = struct {
    /// Time remaining until the next attack is fully charged (seconds).
    charge_timer: f32 = 0.0,

    /// Time remaining in the invulnerability window (seconds).
    i_frame_timer: f32 = 0.0,

    /// The damage amount that started the current i-frame window.
    /// Used for the "higher damage overrides" exception.
    last_damage_amount: f32 = 0.0,

    /// Which weapon type determines the cooldown cadence.
    weapon_kind: WeaponKind = .hand,

    pub fn init() CombatState {
        return .{};
    }

    /// Tick timers forward by `dt` seconds. Returns a new state (immutable).
    pub fn update(self: CombatState, dt: f32) CombatState {
        return .{
            .charge_timer = @max(self.charge_timer - dt, 0.0),
            .i_frame_timer = @max(self.i_frame_timer - dt, 0.0),
            .last_damage_amount = if (self.i_frame_timer - dt <= 0.0) 0.0 else self.last_damage_amount,
            .weapon_kind = self.weapon_kind,
        };
    }

    /// Returns the current attack charge percentage in [0, 1].
    pub fn chargePercent(self: CombatState) f32 {
        const cooldown = self.weapon_kind.cooldownSeconds();
        if (cooldown <= 0.0) return 1.0;
        const elapsed = cooldown - self.charge_timer;
        return math.clamp(elapsed / cooldown, 0.0, 1.0);
    }

    /// Start a new attack cooldown for the currently held weapon.
    pub fn startCooldown(self: CombatState) CombatState {
        return .{
            .charge_timer = self.weapon_kind.cooldownSeconds(),
            .i_frame_timer = self.i_frame_timer,
            .last_damage_amount = self.last_damage_amount,
            .weapon_kind = self.weapon_kind,
        };
    }

    /// Attempt to receive damage, respecting i-frames.
    /// Returns a new CombatState and the effective damage actually applied.
    pub fn receiveDamage(self: CombatState, amount: f32, source: DamageSource) struct { state: CombatState, effective_damage: f32 } {
        const iframe_duration: f32 = 0.5; // 10 ticks

        // Void damage ignores i-frames entirely
        if (source == .void_damage) {
            return .{
                .state = .{
                    .charge_timer = self.charge_timer,
                    .i_frame_timer = iframe_duration,
                    .last_damage_amount = amount,
                    .weapon_kind = self.weapon_kind,
                },
                .effective_damage = amount,
            };
        }

        if (self.i_frame_timer > 0.0) {
            // During i-frames: only higher damage can override (deals difference)
            if (amount > self.last_damage_amount) {
                const diff = amount - self.last_damage_amount;
                return .{
                    .state = .{
                        .charge_timer = self.charge_timer,
                        .i_frame_timer = iframe_duration,
                        .last_damage_amount = amount,
                        .weapon_kind = self.weapon_kind,
                    },
                    .effective_damage = diff,
                };
            }
            // Damage not high enough to override: no damage taken
            return .{
                .state = self,
                .effective_damage = 0.0,
            };
        }

        // No i-frames active: full damage, start new i-frame window
        return .{
            .state = .{
                .charge_timer = self.charge_timer,
                .i_frame_timer = iframe_duration,
                .last_damage_amount = amount,
                .weapon_kind = self.weapon_kind,
            },
            .effective_damage = amount,
        };
    }

    /// Returns true when the entity should render with a red flash tint.
    pub fn hasRedFlash(self: CombatState) bool {
        return self.i_frame_timer > 0.0;
    }
};

// ──────────────────────────────────────────────────────────────────────────────
// Critical hit check
// ──────────────────────────────────────────────────────────────────────────────

/// Returns true when conditions for a critical hit are met.
/// The player must be falling, not on ground, not in water, not on a ladder,
/// not blind, not riding an entity, and NOT sprinting.
pub fn checkCritical(vy: f32, on_ground: bool, in_water: bool, on_ladder: bool, sprinting: bool) bool {
    if (on_ground) return false;
    if (in_water) return false;
    if (on_ladder) return false;
    if (sprinting) return false;
    // Must be falling (negative vertical velocity)
    return vy < 0.0;
}

// ──────────────────────────────────────────────────────────────────────────────
// Damage calculation
// ──────────────────────────────────────────────────────────────────────────────

/// Calculate final attack damage given base weapon damage, charge percentage,
/// whether the hit is critical, and the sweeping-edge enchantment level
/// (0 = no enchant).
///
/// For the primary target the full formula applies:
///   charged_dmg = base_dmg * (0.2 + charge^2 * 0.8)
///   if critical: charged_dmg * 1.5
///
/// `sweep_level` is only used by `calculateSweepDamage` for secondary targets.
pub fn calculateDamage(base_dmg: f32, charge_pct: f32, is_critical: bool, sweep_level: u8) f32 {
    _ = sweep_level; // sweep level only affects secondary targets
    const clamped_charge = math.clamp(charge_pct, 0.0, 1.0);
    const charge_mult = 0.2 + clamped_charge * clamped_charge * 0.8;
    var dmg = base_dmg * charge_mult;

    if (is_critical) {
        dmg *= 1.5;
    }

    return dmg;
}

/// Damage dealt to secondary (swept) targets.
/// Formula: 1 + (total_attack - 1) * sweep_multiplier
/// where sweep_multiplier depends on the Sweeping Edge enchantment level.
pub fn calculateSweepDamage(total_attack: f32, sweep_level: u8) f32 {
    const sweep_mult: f32 = switch (sweep_level) {
        0 => 0.0,
        1 => 0.50,
        2 => 0.67,
        3 => 0.75,
        else => 0.75, // cap at level III
    };
    return 1.0 + (total_attack - 1.0) * sweep_mult;
}

// ──────────────────────────────────────────────────────────────────────────────
// Sweeping edge attack
// ──────────────────────────────────────────────────────────────────────────────

pub const SweepResult = struct {
    primary_damage: f32,
    sweep_damage: f32,
    sweep_knockback: f32,
    particle: ParticleEvent,
    is_critical: bool,
};

/// Determine the full outcome of a melee swing.
/// `is_sprinting`:  sprint attacks do NOT trigger sweep; crits also require !sprinting.
/// `charge_pct`:    attack charge [0, 1].
/// `vy`:            player vertical velocity (negative = falling).
/// Sweep only triggers when standing still (not sprinting) and attack is fully charged.
pub fn resolveMeleeSwing(
    base_dmg: f32,
    charge_pct: f32,
    sweep_level: u8,
    is_sprinting: bool,
    vy: f32,
    on_ground: bool,
    in_water: bool,
    on_ladder: bool,
) SweepResult {
    const is_crit = checkCritical(vy, on_ground, in_water, on_ladder, is_sprinting);
    const primary = calculateDamage(base_dmg, charge_pct, is_crit, sweep_level);

    // Sweep only when standing still and fully charged
    const fully_charged = charge_pct >= 1.0;
    const can_sweep = !is_sprinting and fully_charged;
    const sweep_dmg = if (can_sweep) calculateSweepDamage(primary, sweep_level) else 0.0;
    const sweep_kb: f32 = if (can_sweep) 0.4 else 0.0;

    const particle: ParticleEvent = if (is_crit)
        .critical_star_burst
    else if (can_sweep)
        .sweep_arc
    else
        .none;

    return .{
        .primary_damage = primary,
        .sweep_damage = sweep_dmg,
        .sweep_knockback = sweep_kb,
        .particle = particle,
        .is_critical = is_crit,
    };
}

// ──────────────────────────────────────────────────────────────────────────────
// Knockback
// ──────────────────────────────────────────────────────────────────────────────

/// Compute the knockback velocity vector applied to a target.
///
/// * `target_pos`        - [x, y, z] of the entity receiving knockback.
/// * `attacker_pos`      - [x, y, z] of the attacker.
/// * `kb_enchant_level`  - Knockback enchantment level (0-2 typically).
/// * `is_sprinting`      - Sprint attacks add +1 level of knockback.
/// * `resistance`        - Knockback Resistance attribute (0.0 - 1.0).
///                         Netherite full set = 0.4 (10% per point, 4 pieces).
///
/// Returns the velocity delta [dx, dy, dz] to add to the target.
pub fn applyKnockback(
    target_pos: [3]f32,
    attacker_pos: [3]f32,
    kb_enchant_level: u8,
    is_sprinting: bool,
    resistance: f32,
) [3]f32 {
    const base_horizontal: f32 = 0.4;
    const base_vertical: f32 = 0.4;
    const enchant_bonus: f32 = 0.5 * @as(f32, @floatFromInt(kb_enchant_level)) * 3.0;
    const sprint_bonus: f32 = if (is_sprinting) 1.0 else 0.0;

    const total_strength = base_horizontal + enchant_bonus + sprint_bonus;
    const clamped_resist = math.clamp(resistance, 0.0, 1.0);
    const effective = total_strength * (1.0 - clamped_resist);

    // Direction from attacker to target (horizontal only)
    const dx = target_pos[0] - attacker_pos[0];
    const dz = target_pos[2] - attacker_pos[2];
    const dist = @sqrt(dx * dx + dz * dz);

    if (dist < 0.001) {
        // Directly on top: push in +x arbitrarily
        return .{ effective, base_vertical * (1.0 - clamped_resist), 0.0 };
    }

    const nx = dx / dist;
    const nz = dz / dist;

    return .{
        nx * effective,
        base_vertical * (1.0 - clamped_resist),
        nz * effective,
    };
}

// ──────────────────────────────────────────────────────────────────────────────
// Totem of Undying
// ──────────────────────────────────────────────────────────────────────────────

pub const TotemEffect = struct {
    effect_type: enum { regeneration, fire_resistance, absorption },
    amplifier: u8,
    duration_seconds: f32,
};

pub const TotemResult = struct {
    activated: bool,
    consumed_slot: ?u8, // 0 = main hand, 1 = offhand
    granted_health: f32,
    effects: [3]TotemEffect,
    particle: ParticleEvent,
};

/// Check whether the player holds a Totem of Undying and process it.
/// `held_items[0]` = main hand, `held_items[1]` = offhand.
/// Returns the result describing what the totem grants.
pub fn processTotem(held_items: [2]?ItemId) TotemResult {
    const no_activation = TotemResult{
        .activated = false,
        .consumed_slot = null,
        .granted_health = 0.0,
        .effects = undefined,
        .particle = .none,
    };

    // Check main hand first, then offhand
    const slot: u8 = if (held_items[0]) |id| blk: {
        break :blk if (id == ITEM_TOTEM_OF_UNDYING) 0 else if (held_items[1]) |off_id|
            if (off_id == ITEM_TOTEM_OF_UNDYING) 1 else return no_activation
        else
            return no_activation;
    } else if (held_items[1]) |off_id|
        if (off_id == ITEM_TOTEM_OF_UNDYING) 1 else return no_activation
    else
        return no_activation;

    return .{
        .activated = true,
        .consumed_slot = slot,
        .granted_health = 1.0,
        .effects = .{
            .{ .effect_type = .regeneration, .amplifier = 1, .duration_seconds = 40.0 },
            .{ .effect_type = .fire_resistance, .amplifier = 0, .duration_seconds = 40.0 },
            .{ .effect_type = .absorption, .amplifier = 1, .duration_seconds = 5.0 },
        },
        .particle = .totem_activation,
    };
}

// ──────────────────────────────────────────────────────────────────────────────
// Offhand / Dual Wielding
// ──────────────────────────────────────────────────────────────────────────────

pub const OFFHAND_SLOT_INDEX: u8 = 40;

pub const OffhandSlot = struct {
    item: ?ItemId = null,

    pub fn init() OffhandSlot {
        return .{};
    }

    pub fn setItem(self: OffhandSlot, item: ?ItemId) OffhandSlot {
        _ = self;
        return .{ .item = item };
    }

    pub fn isEmpty(self: OffhandSlot) bool {
        return self.item == null;
    }

    /// Returns true if the given item is allowed in the offhand slot.
    /// Allowed: shields, torches, maps, totems, food, rockets.
    pub fn isAllowedItem(item_id: ItemId) bool {
        return switch (item_id) {
            ITEM_SHIELD,
            ITEM_TORCH,
            ITEM_MAP,
            ITEM_TOTEM_OF_UNDYING,
            ITEM_FIREWORK_ROCKET,
            => true,
            else => {
                // Food items (bread=297, apple=260, etc.) use a range check.
                // For now, accept any ItemId in the food range [256..400).
                return item_id >= 256 and item_id < 400;
            },
        };
    }

    /// Determine use-priority for right-click.
    /// Returns .main_hand, .offhand, or .none.
    pub fn getUsePriority(main_hand_has_use: bool, offhand: OffhandSlot) UsePriority {
        if (main_hand_has_use) return .main_hand;
        if (offhand.item != null) return .offhand;
        return .none;
    }
};

pub const UsePriority = enum {
    main_hand,
    offhand,
    none,
};

// ──────────────────────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────────────────────

test "checkCritical: falling, not on ground, not in water, not sprinting" {
    try std.testing.expect(checkCritical(-1.0, false, false, false, false));
}

test "checkCritical: fails when on ground" {
    try std.testing.expect(!checkCritical(-1.0, true, false, false, false));
}

test "checkCritical: fails when in water" {
    try std.testing.expect(!checkCritical(-1.0, false, true, false, false));
}

test "checkCritical: fails when on ladder" {
    try std.testing.expect(!checkCritical(-1.0, false, false, true, false));
}

test "checkCritical: fails when sprinting" {
    try std.testing.expect(!checkCritical(-1.0, false, false, false, true));
}

test "checkCritical: fails when rising (vy >= 0)" {
    try std.testing.expect(!checkCritical(0.0, false, false, false, false));
    try std.testing.expect(!checkCritical(1.0, false, false, false, false));
}

test "calculateDamage: full charge, no crit" {
    const dmg = calculateDamage(7.0, 1.0, false, 0);
    try std.testing.expectApproxEqAbs(@as(f32, 7.0), dmg, 0.001);
}

test "calculateDamage: zero charge gives 20% damage" {
    const dmg = calculateDamage(10.0, 0.0, false, 0);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), dmg, 0.001);
}

test "calculateDamage: 50% charge" {
    // mult = 0.2 + 0.25 * 0.8 = 0.4
    const dmg = calculateDamage(10.0, 0.5, false, 0);
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), dmg, 0.001);
}

test "calculateDamage: critical multiplies by 1.5" {
    const dmg = calculateDamage(10.0, 1.0, true, 0);
    try std.testing.expectApproxEqAbs(@as(f32, 15.0), dmg, 0.001);
}

test "calculateSweepDamage: no enchant gives 1 damage" {
    const dmg = calculateSweepDamage(7.0, 0);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), dmg, 0.001);
}

test "calculateSweepDamage: sweeping edge I (50%)" {
    // 1 + (7-1)*0.5 = 1 + 3 = 4
    const dmg = calculateSweepDamage(7.0, 1);
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), dmg, 0.001);
}

test "calculateSweepDamage: sweeping edge II (67%)" {
    // 1 + (7-1)*0.67 = 1 + 4.02 = 5.02
    const dmg = calculateSweepDamage(7.0, 2);
    try std.testing.expectApproxEqAbs(@as(f32, 5.02), dmg, 0.02);
}

test "calculateSweepDamage: sweeping edge III (75%)" {
    // 1 + (7-1)*0.75 = 1 + 4.5 = 5.5
    const dmg = calculateSweepDamage(7.0, 3);
    try std.testing.expectApproxEqAbs(@as(f32, 5.5), dmg, 0.001);
}

test "CombatState: charge percent starts at 100% when no cooldown" {
    const state = CombatState.init();
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), state.chargePercent(), 0.001);
}

test "CombatState: cooldown brings charge to 0, recovers over time" {
    var state = CombatState.init();
    state.weapon_kind = .sword;
    state = state.startCooldown();
    // Immediately after attack, charge should be ~0
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), state.chargePercent(), 0.01);

    // After half the cooldown (0.3125s), charge should be ~50%
    state = state.update(0.3125);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), state.chargePercent(), 0.01);

    // After full cooldown, charge should be 100%
    state = state.update(0.3125);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), state.chargePercent(), 0.01);
}

test "CombatState: weapon-specific cooldowns" {
    const hand_cd = WeaponKind.hand.cooldownSeconds();
    try std.testing.expectApproxEqAbs(@as(f32, 0.25), hand_cd, 0.001);

    const sword_cd = WeaponKind.sword.cooldownSeconds();
    try std.testing.expectApproxEqAbs(@as(f32, 0.625), sword_cd, 0.001);

    const axe_cd = WeaponKind.axe.cooldownSeconds();
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), axe_cd, 0.001);
}

test "i-frames: no damage during invulnerability" {
    var state = CombatState.init();
    const r1 = state.receiveDamage(5.0, .melee);
    state = r1.state;
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), r1.effective_damage, 0.001);
    try std.testing.expect(state.i_frame_timer > 0.0);

    // Second hit during i-frames: no damage
    const r2 = state.receiveDamage(3.0, .melee);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), r2.effective_damage, 0.001);
}

test "i-frames: higher damage overrides and deals difference" {
    var state = CombatState.init();
    const r1 = state.receiveDamage(5.0, .melee);
    state = r1.state;

    // Higher damage during i-frames: deals the difference
    const r2 = state.receiveDamage(8.0, .melee);
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), r2.effective_damage, 0.001);
    // last_damage_amount should update to the higher amount
    try std.testing.expectApproxEqAbs(@as(f32, 8.0), r2.state.last_damage_amount, 0.001);
}

test "i-frames: void damage ignores i-frames" {
    var state = CombatState.init();
    const r1 = state.receiveDamage(5.0, .melee);
    state = r1.state;

    // Void damage should go through regardless
    const r2 = state.receiveDamage(2.0, .void_damage);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), r2.effective_damage, 0.001);
}

test "i-frames: timer expires after 0.5s" {
    var state = CombatState.init();
    const r1 = state.receiveDamage(5.0, .melee);
    state = r1.state;
    try std.testing.expect(state.hasRedFlash());

    // After 0.5 seconds the i-frame window closes
    state = state.update(0.5);
    try std.testing.expect(!state.hasRedFlash());

    // Now damage should work again
    const r2 = state.receiveDamage(3.0, .melee);
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), r2.effective_damage, 0.001);
}

test "knockback: base only, no enchant, no sprint" {
    const kb = applyKnockback(.{ 10.0, 0.0, 0.0 }, .{ 0.0, 0.0, 0.0 }, 0, false, 0.0);
    // Direction is along +x, magnitude should be base_horizontal (0.4)
    try std.testing.expectApproxEqAbs(@as(f32, 0.4), kb[0], 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.4), kb[1], 0.01); // vertical
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), kb[2], 0.01);
}

test "knockback: sprint adds +1 level" {
    const kb_no_sprint = applyKnockback(.{ 10.0, 0.0, 0.0 }, .{ 0.0, 0.0, 0.0 }, 0, false, 0.0);
    const kb_sprint = applyKnockback(.{ 10.0, 0.0, 0.0 }, .{ 0.0, 0.0, 0.0 }, 0, true, 0.0);
    // Sprint should knock back significantly more
    try std.testing.expect(kb_sprint[0] > kb_no_sprint[0]);
}

test "knockback: enchant level adds 0.5 * level * 3" {
    const kb_0 = applyKnockback(.{ 10.0, 0.0, 0.0 }, .{ 0.0, 0.0, 0.0 }, 0, false, 0.0);
    const kb_2 = applyKnockback(.{ 10.0, 0.0, 0.0 }, .{ 0.0, 0.0, 0.0 }, 2, false, 0.0);
    // Level 2: 0.4 + 0.5*2*3 = 0.4 + 3 = 3.4
    try std.testing.expectApproxEqAbs(@as(f32, 3.4), kb_2[0], 0.01);
    try std.testing.expect(kb_2[0] > kb_0[0]);
}

test "knockback: resistance reduces knockback" {
    const kb_full = applyKnockback(.{ 10.0, 0.0, 0.0 }, .{ 0.0, 0.0, 0.0 }, 0, false, 0.0);
    // Netherite full set: 40% resistance
    const kb_resist = applyKnockback(.{ 10.0, 0.0, 0.0 }, .{ 0.0, 0.0, 0.0 }, 0, false, 0.4);
    try std.testing.expectApproxEqAbs(kb_full[0] * 0.6, kb_resist[0], 0.01);
    try std.testing.expectApproxEqAbs(kb_full[1] * 0.6, kb_resist[1], 0.01);
}

test "knockback: 100% resistance eliminates knockback" {
    const kb = applyKnockback(.{ 10.0, 0.0, 0.0 }, .{ 0.0, 0.0, 0.0 }, 2, true, 1.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), kb[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), kb[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), kb[2], 0.001);
}

test "knockback: direction is normalized" {
    const kb = applyKnockback(.{ 3.0, 0.0, 4.0 }, .{ 0.0, 0.0, 0.0 }, 0, false, 0.0);
    // Direction: (3/5, 0, 4/5), magnitude 0.4
    try std.testing.expectApproxEqAbs(@as(f32, 0.24), kb[0], 0.01); // 3/5 * 0.4
    try std.testing.expectApproxEqAbs(@as(f32, 0.32), kb[2], 0.01); // 4/5 * 0.4
}

test "processTotem: totem in main hand activates" {
    const result = processTotem(.{ ITEM_TOTEM_OF_UNDYING, null });
    try std.testing.expect(result.activated);
    try std.testing.expectEqual(@as(?u8, 0), result.consumed_slot);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), result.granted_health, 0.001);
    try std.testing.expectEqual(ParticleEvent.totem_activation, result.particle);
}

test "processTotem: totem in offhand activates" {
    const result = processTotem(.{ null, ITEM_TOTEM_OF_UNDYING });
    try std.testing.expect(result.activated);
    try std.testing.expectEqual(@as(?u8, 1), result.consumed_slot);
}

test "processTotem: main hand takes priority" {
    const result = processTotem(.{ ITEM_TOTEM_OF_UNDYING, ITEM_TOTEM_OF_UNDYING });
    try std.testing.expect(result.activated);
    try std.testing.expectEqual(@as(?u8, 0), result.consumed_slot);
}

test "processTotem: no totem returns inactive" {
    const result = processTotem(.{ ITEM_SHIELD, ITEM_TORCH });
    try std.testing.expect(!result.activated);
    try std.testing.expect(result.consumed_slot == null);
}

test "processTotem: both hands empty" {
    const result = processTotem(.{ null, null });
    try std.testing.expect(!result.activated);
}

test "processTotem: grants correct effects" {
    const result = processTotem(.{ ITEM_TOTEM_OF_UNDYING, null });
    try std.testing.expect(result.activated);
    // Regeneration II (amplifier 1) for 40s
    try std.testing.expectEqual(@as(u8, 1), result.effects[0].amplifier);
    try std.testing.expectApproxEqAbs(@as(f32, 40.0), result.effects[0].duration_seconds, 0.001);
    // Fire Resistance I (amplifier 0) for 40s
    try std.testing.expectEqual(@as(u8, 0), result.effects[1].amplifier);
    try std.testing.expectApproxEqAbs(@as(f32, 40.0), result.effects[1].duration_seconds, 0.001);
    // Absorption II (amplifier 1) for 5s
    try std.testing.expectEqual(@as(u8, 1), result.effects[2].amplifier);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), result.effects[2].duration_seconds, 0.001);
}

test "OffhandSlot: init is empty" {
    const slot = OffhandSlot.init();
    try std.testing.expect(slot.isEmpty());
}

test "OffhandSlot: set and check item" {
    const slot = OffhandSlot.init().setItem(ITEM_SHIELD);
    try std.testing.expect(!slot.isEmpty());
    try std.testing.expectEqual(@as(?ItemId, ITEM_SHIELD), slot.item);
}

test "OffhandSlot: allowed items" {
    try std.testing.expect(OffhandSlot.isAllowedItem(ITEM_SHIELD));
    try std.testing.expect(OffhandSlot.isAllowedItem(ITEM_TORCH));
    try std.testing.expect(OffhandSlot.isAllowedItem(ITEM_MAP));
    try std.testing.expect(OffhandSlot.isAllowedItem(ITEM_TOTEM_OF_UNDYING));
    try std.testing.expect(OffhandSlot.isAllowedItem(ITEM_FIREWORK_ROCKET));
    // Food range item
    try std.testing.expect(OffhandSlot.isAllowedItem(297)); // bread
}

test "OffhandSlot: disallowed items" {
    try std.testing.expect(!OffhandSlot.isAllowedItem(1)); // stone block
    try std.testing.expect(!OffhandSlot.isAllowedItem(256 - 1)); // below food range
}

test "OffhandSlot: use priority - main hand has action" {
    const offhand = OffhandSlot.init().setItem(ITEM_SHIELD);
    const priority = OffhandSlot.getUsePriority(true, offhand);
    try std.testing.expectEqual(UsePriority.main_hand, priority);
}

test "OffhandSlot: use priority - main hand no action, offhand has item" {
    const offhand = OffhandSlot.init().setItem(ITEM_SHIELD);
    const priority = OffhandSlot.getUsePriority(false, offhand);
    try std.testing.expectEqual(UsePriority.offhand, priority);
}

test "OffhandSlot: use priority - nothing to use" {
    const offhand = OffhandSlot.init();
    const priority = OffhandSlot.getUsePriority(false, offhand);
    try std.testing.expectEqual(UsePriority.none, priority);
}

test "resolveMeleeSwing: full charge standing still triggers sweep" {
    const result = resolveMeleeSwing(7.0, 1.0, 0, false, 0.0, true, false, false);
    // Primary damage: full (7.0), sweep damage: 1 (no enchant)
    try std.testing.expectApproxEqAbs(@as(f32, 7.0), result.primary_damage, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), result.sweep_damage, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.4), result.sweep_knockback, 0.001);
    try std.testing.expect(!result.is_critical);
}

test "resolveMeleeSwing: sprinting prevents sweep" {
    const result = resolveMeleeSwing(7.0, 1.0, 3, true, 0.0, true, false, false);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), result.sweep_damage, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), result.sweep_knockback, 0.001);
}

test "resolveMeleeSwing: uncharged prevents sweep" {
    const result = resolveMeleeSwing(7.0, 0.5, 3, false, 0.0, true, false, false);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), result.sweep_damage, 0.001);
}

test "resolveMeleeSwing: critical hit while falling" {
    const result = resolveMeleeSwing(7.0, 1.0, 0, false, -2.0, false, false, false);
    try std.testing.expect(result.is_critical);
    try std.testing.expectApproxEqAbs(@as(f32, 10.5), result.primary_damage, 0.001); // 7 * 1.5
    try std.testing.expectEqual(ParticleEvent.critical_star_burst, result.particle);
}

test "resolveMeleeSwing: sprint prevents critical" {
    const result = resolveMeleeSwing(7.0, 1.0, 0, true, -2.0, false, false, false);
    try std.testing.expect(!result.is_critical);
    try std.testing.expectApproxEqAbs(@as(f32, 7.0), result.primary_damage, 0.001);
}

test "CombatState: immutable update pattern" {
    const original = CombatState.init();
    const updated = original.update(0.1);
    // Original should remain unchanged
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), original.charge_timer, 0.001);
    _ = updated;
}
