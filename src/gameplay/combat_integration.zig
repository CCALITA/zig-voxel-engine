/// Gameplay bridge that unifies combat_system, durability_system, and
/// enchant_apply into high-level functions suitable for game-loop callsites.

const std = @import("std");
const combat = @import("combat_system.zig");
const durability = @import("durability_system.zig");
const enchant = @import("enchant_apply.zig");

// ── Mining ────────────────────────────────────────────────────────────────

pub const MineResult = struct {
    speed_multiplier: f32,
    durability_consumed: bool,
    tool_broke: bool,
};

/// Resolve a block-mine event: compute the enchantment-adjusted mining speed
/// and apply a durability tick (respecting Unbreaking).
pub fn onBlockMined(tool_durability: u16, enchants: u32, rng_val: u32) MineResult {
    const speed = enchant.getAdjustedMiningSpeed(1.0, enchants);
    const dur = durability.onToolUse(tool_durability, getUnbreakingLevel(enchants), rng_val);
    return .{
        .speed_multiplier = speed,
        .durability_consumed = dur.consumed,
        .tool_broke = dur.broke,
    };
}

// ── Melee attack ──────────────────────────────────────────────────────────

pub const AttackContext = struct {
    weapon_dmg: f32,
    enchants: u32 = 0,
    is_falling: bool = false,
    cooldown_pct: f32 = 1.0,
    x: f32,
    z: f32,
};

pub const TargetContext = struct {
    armor: f32 = 0,
    toughness: f32 = 0,
    protection: u8 = 0,
    x: f32,
    z: f32,
};

pub const AttackResult = struct {
    damage: f32,
    knockback_x: f32,
    knockback_z: f32,
    is_critical: bool,
};

/// Resolve a full melee-attack event: base damage -> enchant bonus -> armor
/// reduction -> protection reduction, plus knockback vector.
pub fn onAttack(attacker: AttackContext, target: TargetContext) AttackResult {
    const melee = combat.calculateMeleeDamage(1.0, attacker.weapon_dmg, 0, attacker.is_falling, attacker.cooldown_pct);
    var dmg = enchant.getAdjustedDamage(melee.damage, attacker.enchants);
    dmg = combat.applyArmor(dmg, target.armor, target.toughness);
    dmg = combat.applyProtection(dmg, target.protection);
    const kb = combat.calculateKnockback(attacker.x, attacker.z, target.x, target.z, 0);
    return .{
        .damage = dmg,
        .knockback_x = kb.x,
        .knockback_z = kb.z,
        .is_critical = melee.is_critical,
    };
}

// ── Helpers ───────────────────────────────────────────────────────────────

const bits_per_slot: u5 = 5;

/// Extract the Unbreaking enchantment level from a packed enchant word.
/// Unbreaking is enchant id 2 in the 6-slot x 5-bit encoding used by
/// enchant_apply.
fn getUnbreakingLevel(enchants: u32) u8 {
    var i: u3 = 0;
    while (i < 6) : (i += 1) {
        const shift: u5 = @as(u5, i) * bits_per_slot;
        const raw: u5 = @truncate(enchants >> shift);
        const slot_id: u3 = @truncate(raw);
        const slot_level: u2 = @truncate(raw >> 3);
        if (slot_id == 2) return @as(u8, slot_level) + 1;
    }
    return 0;
}

/// Build a packed enchant slot for test construction.
fn packSlot(enchants: u32, slot: u3, id: u3, level: u2) u32 {
    const shift: u5 = @as(u5, slot) * bits_per_slot;
    const raw: u32 = @as(u32, level) << 3 | @as(u32, id);
    const mask: u32 = ~(@as(u32, 0x1F) << shift);
    return (enchants & mask) | (raw << shift);
}

// ── Tests ─────────────────────────────────────────────────────────────────

const t = std.testing;
const tol: f32 = 0.01;

fn atk(x: f32, z: f32) AttackContext {
    return .{ .weapon_dmg = 5.0, .x = x, .z = z };
}

fn tgt(x: f32, z: f32) TargetContext {
    return .{ .x = x, .z = z };
}

// -- onBlockMined tests --

test "mine: base speed without enchants is 1.0" {
    const r = onBlockMined(100, 0, 0);
    try t.expectApproxEqAbs(@as(f32, 1.0), r.speed_multiplier, tol);
}

test "mine: efficiency increases speed" {
    const enc = packSlot(0, 0, 1, 0); // Efficiency I => bonus 1+1 = 2
    const r = onBlockMined(100, enc, 0);
    try t.expectApproxEqAbs(@as(f32, 3.0), r.speed_multiplier, tol);
}

test "mine: durability consumed without unbreaking" {
    const r = onBlockMined(50, 0, 0);
    try t.expect(r.durability_consumed);
    try t.expect(!r.tool_broke);
}

test "mine: tool breaks at durability 1" {
    const r = onBlockMined(1, 0, 0);
    try t.expect(r.durability_consumed);
    try t.expect(r.tool_broke);
}

test "mine: unbreaking can prevent consumption" {
    // Unbreaking I: threshold=50, rng 75 >= 50 => skip
    const enc = packSlot(0, 0, 2, 0);
    const r = onBlockMined(50, enc, 75);
    try t.expect(!r.durability_consumed);
    try t.expect(!r.tool_broke);
}

test "mine: efficiency + unbreaking combined" {
    var enc: u32 = 0;
    enc = packSlot(enc, 0, 1, 1); // Efficiency II => bonus 4+1 = 5
    enc = packSlot(enc, 1, 2, 0); // Unbreaking I
    const r = onBlockMined(100, enc, 75);
    try t.expectApproxEqAbs(@as(f32, 6.0), r.speed_multiplier, tol);
    try t.expect(!r.durability_consumed);
}

// -- onAttack tests --

test "attack: basic damage flows through pipeline" {
    const r = onAttack(atk(0, 0), tgt(1, 0));
    // melee=(1+5)*1.0=6, enchant adds 0.5=6.5, no armor/prot
    try t.expectApproxEqAbs(@as(f32, 6.5), r.damage, tol);
    try t.expect(!r.is_critical);
}

test "attack: critical hit while falling" {
    var a = atk(0, 0);
    a.is_falling = true;
    const r = onAttack(a, tgt(1, 0));
    // melee=(1+5)*1.5=9, enchant=9.5
    try t.expectApproxEqAbs(@as(f32, 9.5), r.damage, tol);
    try t.expect(r.is_critical);
}

test "attack: armor reduces damage" {
    const no_armor = onAttack(atk(0, 0), tgt(1, 0));
    var armored = tgt(1, 0);
    armored.armor = 20.0;
    const with_armor = onAttack(atk(0, 0), armored);
    try t.expect(with_armor.damage < no_armor.damage);
}

test "attack: protection reduces damage" {
    const no_prot = onAttack(atk(0, 0), tgt(1, 0));
    var protected = tgt(1, 0);
    protected.protection = 4;
    const with_prot = onAttack(atk(0, 0), protected);
    try t.expect(with_prot.damage < no_prot.damage);
}

test "attack: sharpness increases damage" {
    var a = atk(0, 0);
    a.enchants = packSlot(0, 0, 5, 2); // Sharpness III
    const r = onAttack(a, tgt(1, 0));
    // melee=6, enchant=6+0.5+3*0.5=8.0
    try t.expectApproxEqAbs(@as(f32, 8.0), r.damage, tol);
}

test "attack: knockback points from attacker to target" {
    const r = onAttack(atk(0, 0), tgt(1, 0));
    try t.expect(r.knockback_x > 0);
    try t.expectApproxEqAbs(@as(f32, 0.0), r.knockback_z, tol);
}

test "attack: cooldown scales damage down" {
    const full = onAttack(atk(0, 0), tgt(1, 0));
    var half_cd = atk(0, 0);
    half_cd.cooldown_pct = 0.5;
    const half = onAttack(half_cd, tgt(1, 0));
    try t.expect(half.damage < full.damage);
}

// -- getUnbreakingLevel helper tests --

test "getUnbreakingLevel returns 0 when absent" {
    try t.expectEqual(@as(u8, 0), getUnbreakingLevel(0));
}

test "getUnbreakingLevel returns correct level" {
    const enc = packSlot(0, 1, 2, 2); // Unbreaking III in slot 1
    try t.expectEqual(@as(u8, 3), getUnbreakingLevel(enc));
}
