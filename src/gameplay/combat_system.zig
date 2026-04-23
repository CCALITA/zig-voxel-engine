/// Core combat system: melee damage calculation, armor/protection reduction,
/// knockback physics, attack cooldowns, and invulnerability frames.

const std = @import("std");

// ── Attack result ──────────────────────────────────────────────────────────

pub const AttackResult = struct {
    damage: f32 = 0,
    knockback_x: f32 = 0,
    knockback_z: f32 = 0,
    is_critical: bool = false,
    is_sweep: bool = false,
};

// ── Melee damage ───────────────────────────────────────────────────────────

/// Compute melee attack damage with strength bonus, cooldown scaling, and
/// critical-hit detection (falling + cooldown >= 90%).
pub fn calculateMeleeDamage(
    base_dmg: f32,
    weapon_dmg: f32,
    strength_level: u8,
    is_falling: bool,
    cooldown_pct: f32,
) AttackResult {
    const strength_bonus = @as(f32, @floatFromInt(strength_level)) * 3.0;
    var dmg = (base_dmg + weapon_dmg + strength_bonus) * cooldown_pct;

    var result = AttackResult{};

    if (is_falling and cooldown_pct >= 0.9) {
        dmg *= 1.5;
        result.is_critical = true;
    }

    result.damage = dmg;
    return result;
}

// ── Armor reduction ────────────────────────────────────────────────────────

/// Apply Minecraft-style armor damage reduction.
/// `armor_defense` is total armor points (0-20), `armor_toughness` adds
/// resistance to high-damage hits.
pub fn applyArmor(damage: f32, armor_defense: f32, armor_toughness: f32) f32 {
    const def = @min(
        20.0,
        @max(armor_defense / 5.0, armor_defense - (4.0 * damage) / (armor_toughness + 8.0)),
    );
    return damage * (1.0 - def / 25.0);
}

// ── Enchantment protection ─────────────────────────────────────────────────

/// Apply protection-enchantment damage reduction (capped at level 5 / 80%).
pub fn applyProtection(damage: f32, protection_level: u8) f32 {
    const reduction = @min(
        @as(f32, 20.0),
        @as(f32, @floatFromInt(protection_level)) * 4.0,
    );
    return damage * (1.0 - reduction / 25.0);
}

// ── Knockback ──────────────────────────────────────────────────────────────

pub const KnockbackVector = struct { x: f32, z: f32 };

/// Compute knockback direction and magnitude from attacker to target.
/// `kb_level` adds 0.5 per level on top of a 0.4 base.
pub fn calculateKnockback(
    attacker_x: f32,
    attacker_z: f32,
    target_x: f32,
    target_z: f32,
    kb_level: u8,
) KnockbackVector {
    const dx = target_x - attacker_x;
    const dz = target_z - attacker_z;
    const dist = @max(@sqrt(dx * dx + dz * dz), 0.01);
    const strength = 0.4 + @as(f32, @floatFromInt(kb_level)) * 0.5;
    return .{
        .x = dx / dist * strength,
        .z = dz / dist * strength,
    };
}

// ── Cooldown / i-frame state ───────────────────────────────────────────────

pub const ATTACK_COOLDOWN: f32 = 0.625;
pub const IFRAME_DURATION: f32 = 0.5;

pub const CombatState = struct {
    cooldown: f32 = 0,
    iframes: f32 = 0,

    pub fn canAttack(self: CombatState) bool {
        return self.cooldown <= 0;
    }

    pub fn canTakeDamage(self: CombatState) bool {
        return self.iframes <= 0;
    }

    pub fn attack(self: *CombatState) void {
        self.cooldown = ATTACK_COOLDOWN;
    }

    pub fn takeDamage(self: *CombatState) void {
        self.iframes = IFRAME_DURATION;
    }

    pub fn update(self: *CombatState, dt: f32) void {
        self.cooldown = @max(0, self.cooldown - dt);
        self.iframes = @max(0, self.iframes - dt);
    }

    pub fn getCooldownPercent(self: CombatState) f32 {
        return 1.0 - self.cooldown / ATTACK_COOLDOWN;
    }
};

// ── Tests ──────────────────────────────────────────────────────────────────

const tolerance: f32 = 0.001;

fn approxEq(a: f32, b: f32) bool {
    return @abs(a - b) < tolerance;
}

test "melee damage base only" {
    const r = calculateMeleeDamage(1.0, 0.0, 0, false, 1.0);
    try std.testing.expect(approxEq(r.damage, 1.0));
    try std.testing.expect(!r.is_critical);
}

test "melee damage with weapon" {
    const r = calculateMeleeDamage(1.0, 6.0, 0, false, 1.0);
    try std.testing.expect(approxEq(r.damage, 7.0));
}

test "melee damage with strength" {
    const r = calculateMeleeDamage(1.0, 0.0, 2, false, 1.0);
    // (1 + 0 + 2*3) * 1.0 = 7
    try std.testing.expect(approxEq(r.damage, 7.0));
}

test "melee damage cooldown scaling" {
    const r = calculateMeleeDamage(10.0, 0.0, 0, false, 0.5);
    try std.testing.expect(approxEq(r.damage, 5.0));
}

test "melee damage critical hit" {
    const r = calculateMeleeDamage(1.0, 5.0, 0, true, 1.0);
    // (1+5)*1.0*1.5 = 9
    try std.testing.expect(approxEq(r.damage, 9.0));
    try std.testing.expect(r.is_critical);
}

test "melee damage falling but low cooldown is not critical" {
    const r = calculateMeleeDamage(1.0, 5.0, 0, true, 0.5);
    // (1+5)*0.5 = 3, no crit because cooldown < 0.9
    try std.testing.expect(approxEq(r.damage, 3.0));
    try std.testing.expect(!r.is_critical);
}

test "armor reduces damage" {
    const reduced = applyArmor(10.0, 20.0, 0.0);
    try std.testing.expect(reduced < 10.0);
    try std.testing.expect(reduced > 0.0);
}

test "armor with zero defense passes full damage" {
    const reduced = applyArmor(10.0, 0.0, 0.0);
    try std.testing.expect(approxEq(reduced, 10.0));
}

test "protection reduces damage" {
    const reduced = applyProtection(10.0, 4);
    // reduction = min(20, 16) = 16 => 10 * (1 - 16/25) = 10 * 0.36 = 3.6
    try std.testing.expect(approxEq(reduced, 3.6));
}

test "protection capped at level 5" {
    const at5 = applyProtection(10.0, 5);
    const at10 = applyProtection(10.0, 10);
    // Both should be capped: min(20, level*4) = 20 for level >= 5
    try std.testing.expect(approxEq(at5, at10));
    // 10 * (1 - 20/25) = 10 * 0.2 = 2.0
    try std.testing.expect(approxEq(at5, 2.0));
}

test "knockback direction and magnitude" {
    const kb = calculateKnockback(0.0, 0.0, 1.0, 0.0, 0);
    try std.testing.expect(approxEq(kb.x, 0.4));
    try std.testing.expect(approxEq(kb.z, 0.0));
}

test "knockback with enchantment level" {
    const kb = calculateKnockback(0.0, 0.0, 0.0, 1.0, 2);
    // strength = 0.4 + 2*0.5 = 1.4, direction is pure +z
    try std.testing.expect(approxEq(kb.x, 0.0));
    try std.testing.expect(approxEq(kb.z, 1.4));
}

test "combat state fresh can attack and take damage" {
    const state = CombatState{};
    try std.testing.expect(state.canAttack());
    try std.testing.expect(state.canTakeDamage());
    try std.testing.expect(approxEq(state.getCooldownPercent(), 1.0));
}

test "combat state cooldown after attack" {
    var state = CombatState{};
    state.attack();
    try std.testing.expect(!state.canAttack());
    try std.testing.expect(approxEq(state.getCooldownPercent(), 0.0));

    // Tick half the cooldown
    state.update(ATTACK_COOLDOWN / 2.0);
    try std.testing.expect(!state.canAttack());
    try std.testing.expect(approxEq(state.getCooldownPercent(), 0.5));

    // Tick remaining
    state.update(ATTACK_COOLDOWN);
    try std.testing.expect(state.canAttack());
}

test "combat state iframes after taking damage" {
    var state = CombatState{};
    state.takeDamage();
    try std.testing.expect(!state.canTakeDamage());

    state.update(IFRAME_DURATION);
    try std.testing.expect(state.canTakeDamage());
}

test "combat state update clamps to zero" {
    var state = CombatState{};
    state.attack();
    state.takeDamage();
    state.update(100.0);
    try std.testing.expect(approxEq(state.cooldown, 0.0));
    try std.testing.expect(approxEq(state.iframes, 0.0));
}
