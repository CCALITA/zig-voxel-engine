/// Status-effect manager.
/// Tracks up to 8 concurrent effects on an entity, ticking durations each
/// frame and producing an EffectTick that summarises speed, damage, and
/// healing contributions for the current update.

const std = @import("std");

// ──────────────────────────────────────────────────────────────────────────────
// Types
// ──────────────────────────────────────────────────────────────────────────────

pub const EffectType = enum(u4) {
    speed,
    slowness,
    haste,
    fatigue,
    strength,
    weakness,
    poison,
    regeneration,
    fire_resistance,
    water_breathing,
    invisibility,
    night_vision,
    jump_boost,
    absorption,
};

pub const ActiveEffect = struct {
    effect: EffectType,
    level: u8,
    remaining: f32,

    pub fn isExpired(self: *const ActiveEffect) bool {
        return self.remaining <= 0.0;
    }
};

pub const EffectTick = struct {
    speed_mult: f32 = 1.0,
    damage: f32 = 0.0,
    heal: f32 = 0.0,
};

const MAX_SLOTS = 8;

// ──────────────────────────────────────────────────────────────────────────────
// Effect constants
// ──────────────────────────────────────────────────────────────────────────────

const speed_bonus_per_level: f32 = 0.20;
const slowness_penalty_per_level: f32 = 0.15;
const poison_dps_per_level: f32 = 1.0;
const regen_hps_per_level: f32 = 0.5;

// ──────────────────────────────────────────────────────────────────────────────
// EffectManager
// ──────────────────────────────────────────────────────────────────────────────

pub const EffectManager = struct {
    effects: [MAX_SLOTS]?ActiveEffect = [_]?ActiveEffect{null} ** MAX_SLOTS,

    /// Add or refresh an effect.  If the same EffectType is already active the
    /// slot is overwritten (level and duration are replaced).  Otherwise the
    /// first empty slot is used.  If no slot is available the call is silently
    /// ignored.
    pub fn addEffect(self: *EffectManager, effect: EffectType, level: u8, duration: f32) void {
        // Replace existing effect of the same type.
        for (&self.effects) |*slot| {
            if (slot.*) |*existing| {
                if (existing.effect == effect) {
                    existing.level = level;
                    existing.remaining = duration;
                    return;
                }
            }
        }
        // Fill first empty slot.
        for (&self.effects) |*slot| {
            if (slot.* == null) {
                slot.* = .{ .effect = effect, .level = level, .remaining = duration };
                return;
            }
        }
    }

    /// Remove the first effect matching the given type.
    pub fn removeEffect(self: *EffectManager, effect: EffectType) void {
        for (&self.effects) |*slot| {
            if (slot.*) |e| {
                if (e.effect == effect) {
                    slot.* = null;
                    return;
                }
            }
        }
    }

    /// Returns true when the entity has an active effect of the given type.
    pub fn hasEffect(self: *const EffectManager, effect: EffectType) bool {
        for (self.effects) |maybe| {
            if (maybe) |e| {
                if (e.effect == effect) return true;
            }
        }
        return false;
    }

    /// Returns the level of the given effect, or 0 when absent.
    pub fn getLevel(self: *const EffectManager, effect: EffectType) u8 {
        for (self.effects) |maybe| {
            if (maybe) |e| {
                if (e.effect == effect) return e.level;
            }
        }
        return 0;
    }

    /// Tick all active effects by `dt` seconds, expire finished ones, and
    /// return an EffectTick summarising this frame's contributions.
    pub fn update(self: *EffectManager, dt: f32) EffectTick {
        var tick = EffectTick{};

        for (&self.effects) |*slot| {
            if (slot.*) |*e| {
                e.remaining -= dt;

                const lvl: f32 = @floatFromInt(@as(u32, e.level));

                switch (e.effect) {
                    .speed => tick.speed_mult += speed_bonus_per_level * lvl,
                    .slowness => tick.speed_mult -= slowness_penalty_per_level * lvl,
                    .poison => tick.damage += poison_dps_per_level * lvl * dt,
                    .regeneration => tick.heal += regen_hps_per_level * lvl * dt,
                    else => {},
                }

                if (e.remaining <= 0.0) {
                    slot.* = null;
                }
            }
        }

        tick.speed_mult = @max(tick.speed_mult, 0.0);
        return tick;
    }

    /// Remove every active effect.
    pub fn clearAll(self: *EffectManager) void {
        self.effects = [_]?ActiveEffect{null} ** MAX_SLOTS;
    }

    /// Number of currently active effects.
    pub fn activeCount(self: *const EffectManager) u32 {
        var count: u32 = 0;
        for (self.effects) |maybe| {
            if (maybe != null) count += 1;
        }
        return count;
    }
};

// ──────────────────────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────────────────────

test "default EffectManager has no active effects" {
    const mgr = EffectManager{};
    try std.testing.expectEqual(@as(u32, 0), mgr.activeCount());
    for (mgr.effects) |e| {
        try std.testing.expect(e == null);
    }
}

test "addEffect stores an effect and activeCount reflects it" {
    var mgr = EffectManager{};
    mgr.addEffect(.speed, 1, 30.0);
    try std.testing.expectEqual(@as(u32, 1), mgr.activeCount());
    try std.testing.expect(mgr.hasEffect(.speed));
}

test "addEffect replaces existing effect of same type" {
    var mgr = EffectManager{};
    mgr.addEffect(.speed, 1, 30.0);
    mgr.addEffect(.speed, 2, 60.0);

    try std.testing.expectEqual(@as(u32, 1), mgr.activeCount());
    try std.testing.expectEqual(@as(u8, 2), mgr.getLevel(.speed));
}

test "addEffect silently ignores when all slots full" {
    var mgr = EffectManager{};
    // Fill all 8 slots with distinct effect types.
    mgr.addEffect(.speed, 1, 10.0);
    mgr.addEffect(.slowness, 1, 10.0);
    mgr.addEffect(.haste, 1, 10.0);
    mgr.addEffect(.fatigue, 1, 10.0);
    mgr.addEffect(.strength, 1, 10.0);
    mgr.addEffect(.weakness, 1, 10.0);
    mgr.addEffect(.poison, 1, 10.0);
    mgr.addEffect(.regeneration, 1, 10.0);

    try std.testing.expectEqual(@as(u32, 8), mgr.activeCount());

    // 9th distinct effect should be silently dropped.
    mgr.addEffect(.fire_resistance, 1, 10.0);
    try std.testing.expectEqual(@as(u32, 8), mgr.activeCount());
    try std.testing.expect(!mgr.hasEffect(.fire_resistance));
}

test "removeEffect clears a specific effect" {
    var mgr = EffectManager{};
    mgr.addEffect(.strength, 1, 60.0);
    mgr.addEffect(.speed, 1, 60.0);

    mgr.removeEffect(.strength);
    try std.testing.expectEqual(@as(u32, 1), mgr.activeCount());
    try std.testing.expect(!mgr.hasEffect(.strength));
    try std.testing.expect(mgr.hasEffect(.speed));
}

test "removeEffect is no-op for absent effect" {
    var mgr = EffectManager{};
    mgr.addEffect(.speed, 1, 60.0);
    mgr.removeEffect(.poison);
    try std.testing.expectEqual(@as(u32, 1), mgr.activeCount());
}

test "hasEffect returns false when absent" {
    const mgr = EffectManager{};
    try std.testing.expect(!mgr.hasEffect(.fire_resistance));
}

test "getLevel returns 0 when absent" {
    const mgr = EffectManager{};
    try std.testing.expectEqual(@as(u8, 0), mgr.getLevel(.night_vision));
}

test "getLevel returns correct level" {
    var mgr = EffectManager{};
    mgr.addEffect(.regeneration, 3, 45.0);
    try std.testing.expectEqual(@as(u8, 3), mgr.getLevel(.regeneration));
}

test "update ticks durations and removes expired effects" {
    var mgr = EffectManager{};
    mgr.addEffect(.speed, 1, 2.0);
    mgr.addEffect(.strength, 1, 10.0);

    _ = mgr.update(3.0);
    // speed (2s) should have expired; strength (10s) still active.
    try std.testing.expect(!mgr.hasEffect(.speed));
    try std.testing.expect(mgr.hasEffect(.strength));
    try std.testing.expectEqual(@as(u32, 1), mgr.activeCount());
}

test "update returns speed multiplier from speed/slowness" {
    var mgr = EffectManager{};
    mgr.addEffect(.speed, 2, 60.0); // +0.20 * 2 = +0.40
    mgr.addEffect(.slowness, 1, 60.0); // -0.15 * 1 = -0.15

    const tick = mgr.update(0.0);
    // 1.0 + 0.40 - 0.15 = 1.25
    try std.testing.expectApproxEqAbs(@as(f32, 1.25), tick.speed_mult, 0.001);
}

test "update returns poison damage" {
    var mgr = EffectManager{};
    mgr.addEffect(.poison, 2, 10.0); // 1.0 * 2 * dt

    const tick = mgr.update(1.0);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), tick.damage, 0.001);
}

test "update returns regeneration healing" {
    var mgr = EffectManager{};
    mgr.addEffect(.regeneration, 1, 10.0); // 0.5 * 1 * dt

    const tick = mgr.update(2.0);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), tick.heal, 0.001);
}

test "update clamps speed_mult to zero" {
    var mgr = EffectManager{};
    // Slowness level 10 => -1.50, should clamp to 0.
    mgr.addEffect(.slowness, 10, 60.0);

    const tick = mgr.update(0.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), tick.speed_mult, 0.001);
}

test "update with no effects returns neutral tick" {
    var mgr = EffectManager{};
    const tick = mgr.update(1.0);

    try std.testing.expectApproxEqAbs(@as(f32, 1.0), tick.speed_mult, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), tick.damage, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), tick.heal, 0.001);
}

test "clearAll removes every effect" {
    var mgr = EffectManager{};
    mgr.addEffect(.speed, 1, 30.0);
    mgr.addEffect(.poison, 2, 15.0);
    mgr.addEffect(.regeneration, 1, 10.0);

    try std.testing.expectEqual(@as(u32, 3), mgr.activeCount());
    mgr.clearAll();
    try std.testing.expectEqual(@as(u32, 0), mgr.activeCount());
}

test "ActiveEffect.isExpired" {
    const alive = ActiveEffect{ .effect = .speed, .level = 1, .remaining = 5.0 };
    try std.testing.expect(!alive.isExpired());

    const dead = ActiveEffect{ .effect = .speed, .level = 1, .remaining = 0.0 };
    try std.testing.expect(dead.isExpired());

    const negative = ActiveEffect{ .effect = .speed, .level = 1, .remaining = -1.0 };
    try std.testing.expect(negative.isExpired());
}

test "non-combat effects do not contribute damage or heal" {
    var mgr = EffectManager{};
    mgr.addEffect(.fire_resistance, 1, 60.0);
    mgr.addEffect(.water_breathing, 1, 60.0);
    mgr.addEffect(.invisibility, 1, 60.0);
    mgr.addEffect(.night_vision, 1, 60.0);
    mgr.addEffect(.jump_boost, 1, 60.0);
    mgr.addEffect(.absorption, 1, 60.0);

    const tick = mgr.update(1.0);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), tick.speed_mult, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), tick.damage, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), tick.heal, 0.001);
}
