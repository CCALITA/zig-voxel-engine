/// Potion and status-effect system.
/// Manages active effects on an entity, ticking durations and computing
/// aggregate multipliers for speed, damage, etc.

const std = @import("std");

pub const EffectType = enum {
    speed,
    slowness,
    haste,
    mining_fatigue,
    strength,
    instant_health,
    instant_damage,
    jump_boost,
    nausea,
    regeneration,
    resistance,
    fire_resistance,
    water_breathing,
    invisibility,
    night_vision,
    poison,
    wither,
};

pub const ActiveEffect = struct {
    effect_type: EffectType,
    amplifier: u8, // 0 = level I, 1 = level II, etc.
    duration: f32, // remaining seconds

    pub fn isExpired(self: *const ActiveEffect) bool {
        return self.duration <= 0.0;
    }
};

const MAX_ACTIVE_EFFECTS = 16;

pub const EffectManager = struct {
    effects: [MAX_ACTIVE_EFFECTS]?ActiveEffect,

    pub fn init() EffectManager {
        return .{
            .effects = [_]?ActiveEffect{null} ** MAX_ACTIVE_EFFECTS,
        };
    }

    /// Add or replace an effect. If the same effect type is already active,
    /// it is replaced (stronger or refreshed). Otherwise fills the first
    /// empty slot. If no slot is available the call is silently ignored.
    pub fn addEffect(self: *EffectManager, effect: ActiveEffect) void {
        // Replace existing effect of the same type.
        for (&self.effects) |*slot| {
            if (slot.*) |*existing| {
                if (existing.effect_type == effect.effect_type) {
                    existing.amplifier = effect.amplifier;
                    existing.duration = effect.duration;
                    return;
                }
            }
        }
        // Fill first empty slot.
        for (&self.effects) |*slot| {
            if (slot.* == null) {
                slot.* = effect;
                return;
            }
        }
    }

    /// Remove the first effect matching the given type.
    pub fn removeEffect(self: *EffectManager, effect_type: EffectType) void {
        for (&self.effects) |*slot| {
            if (slot.*) |e| {
                if (e.effect_type == effect_type) {
                    slot.* = null;
                    return;
                }
            }
        }
    }

    /// Look up an active effect by type.
    pub fn hasEffect(self: *const EffectManager, effect_type: EffectType) ?ActiveEffect {
        for (self.effects) |maybe| {
            if (maybe) |e| {
                if (e.effect_type == effect_type) return e;
            }
        }
        return null;
    }

    /// Tick all active effect durations and remove expired ones.
    pub fn update(self: *EffectManager, dt: f32) void {
        for (&self.effects) |*slot| {
            if (slot.*) |*e| {
                e.duration -= dt;
                if (e.duration <= 0.0) {
                    slot.* = null;
                }
            }
        }
    }

    /// Returns a multiplicative speed factor.
    /// Speed: +20% per amplifier level (amplifier 0 = +20%).
    /// Slowness: -15% per amplifier level.
    pub fn getSpeedMultiplier(self: *const EffectManager) f32 {
        var multiplier: f32 = 1.0;
        for (self.effects) |maybe| {
            if (maybe) |e| {
                const amp: f32 = @floatFromInt(@as(u32, e.amplifier) + 1);
                switch (e.effect_type) {
                    .speed => multiplier += 0.20 * amp,
                    .slowness => multiplier -= 0.15 * amp,
                    else => {},
                }
            }
        }
        return @max(multiplier, 0.0);
    }

    /// Returns a multiplicative damage factor.
    /// Strength: +30% per amplifier level.
    /// Weakness (mining_fatigue used as proxy): -20% per amplifier level.
    pub fn getDamageMultiplier(self: *const EffectManager) f32 {
        var multiplier: f32 = 1.0;
        for (self.effects) |maybe| {
            if (maybe) |e| {
                const amp: f32 = @floatFromInt(@as(u32, e.amplifier) + 1);
                switch (e.effect_type) {
                    .strength => multiplier += 0.30 * amp,
                    .mining_fatigue => multiplier -= 0.20 * amp,
                    else => {},
                }
            }
        }
        return @max(multiplier, 0.0);
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

pub const PotionRecipe = struct {
    base_effect: EffectType,
    amplifier: u8,
    duration: f32,
};

/// Return the brewing recipe for a given ingredient item id.
/// Only a handful of ingredients are recognized; returns null otherwise.
pub fn getBrewingRecipe(ingredient: u16) ?PotionRecipe {
    return switch (ingredient) {
        1 => .{ .base_effect = .speed, .amplifier = 0, .duration = 180.0 },
        2 => .{ .base_effect = .strength, .amplifier = 0, .duration = 180.0 },
        3 => .{ .base_effect = .instant_health, .amplifier = 0, .duration = 0.0 },
        4 => .{ .base_effect = .fire_resistance, .amplifier = 0, .duration = 180.0 },
        5 => .{ .base_effect = .regeneration, .amplifier = 0, .duration = 45.0 },
        6 => .{ .base_effect = .night_vision, .amplifier = 0, .duration = 180.0 },
        7 => .{ .base_effect = .invisibility, .amplifier = 0, .duration = 180.0 },
        8 => .{ .base_effect = .water_breathing, .amplifier = 0, .duration = 180.0 },
        9 => .{ .base_effect = .poison, .amplifier = 0, .duration = 45.0 },
        10 => .{ .base_effect = .slowness, .amplifier = 0, .duration = 90.0 },
        else => null,
    };
}

// ──────────────────────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────────────────────

test "EffectManager.init creates empty manager" {
    const mgr = EffectManager.init();
    try std.testing.expectEqual(@as(u32, 0), mgr.activeCount());
    for (mgr.effects) |e| {
        try std.testing.expect(e == null);
    }
}

test "addEffect stores an effect" {
    var mgr = EffectManager.init();
    mgr.addEffect(.{ .effect_type = .speed, .amplifier = 0, .duration = 60.0 });
    try std.testing.expectEqual(@as(u32, 1), mgr.activeCount());
}

test "addEffect replaces existing effect of same type" {
    var mgr = EffectManager.init();
    mgr.addEffect(.{ .effect_type = .speed, .amplifier = 0, .duration = 60.0 });
    mgr.addEffect(.{ .effect_type = .speed, .amplifier = 1, .duration = 120.0 });

    try std.testing.expectEqual(@as(u32, 1), mgr.activeCount());
    const found = mgr.hasEffect(.speed).?;
    try std.testing.expectEqual(@as(u8, 1), found.amplifier);
    try std.testing.expectApproxEqAbs(@as(f32, 120.0), found.duration, 0.001);
}

test "removeEffect clears a specific effect" {
    var mgr = EffectManager.init();
    mgr.addEffect(.{ .effect_type = .strength, .amplifier = 0, .duration = 60.0 });
    mgr.addEffect(.{ .effect_type = .speed, .amplifier = 0, .duration = 60.0 });

    mgr.removeEffect(.strength);
    try std.testing.expectEqual(@as(u32, 1), mgr.activeCount());
    try std.testing.expect(mgr.hasEffect(.strength) == null);
    try std.testing.expect(mgr.hasEffect(.speed) != null);
}

test "removeEffect is no-op for absent effect" {
    var mgr = EffectManager.init();
    mgr.addEffect(.{ .effect_type = .speed, .amplifier = 0, .duration = 60.0 });
    mgr.removeEffect(.poison);
    try std.testing.expectEqual(@as(u32, 1), mgr.activeCount());
}

test "hasEffect returns matching effect" {
    var mgr = EffectManager.init();
    mgr.addEffect(.{ .effect_type = .regeneration, .amplifier = 2, .duration = 30.0 });

    const found = mgr.hasEffect(.regeneration);
    try std.testing.expect(found != null);
    try std.testing.expectEqual(@as(u8, 2), found.?.amplifier);
}

test "hasEffect returns null when absent" {
    const mgr = EffectManager.init();
    try std.testing.expect(mgr.hasEffect(.fire_resistance) == null);
}

test "update ticks durations down" {
    var mgr = EffectManager.init();
    mgr.addEffect(.{ .effect_type = .speed, .amplifier = 0, .duration = 10.0 });

    mgr.update(3.0);
    const remaining = mgr.hasEffect(.speed).?.duration;
    try std.testing.expectApproxEqAbs(@as(f32, 7.0), remaining, 0.001);
}

test "update removes expired effects" {
    var mgr = EffectManager.init();
    mgr.addEffect(.{ .effect_type = .speed, .amplifier = 0, .duration = 2.0 });
    mgr.addEffect(.{ .effect_type = .strength, .amplifier = 0, .duration = 10.0 });

    mgr.update(3.0);
    try std.testing.expect(mgr.hasEffect(.speed) == null);
    try std.testing.expect(mgr.hasEffect(.strength) != null);
    try std.testing.expectEqual(@as(u32, 1), mgr.activeCount());
}

test "ActiveEffect.isExpired" {
    const alive = ActiveEffect{ .effect_type = .speed, .amplifier = 0, .duration = 5.0 };
    try std.testing.expect(!alive.isExpired());

    const dead = ActiveEffect{ .effect_type = .speed, .amplifier = 0, .duration = 0.0 };
    try std.testing.expect(dead.isExpired());

    const negative = ActiveEffect{ .effect_type = .speed, .amplifier = 0, .duration = -1.0 };
    try std.testing.expect(negative.isExpired());
}

test "getSpeedMultiplier with speed effect" {
    var mgr = EffectManager.init();
    mgr.addEffect(.{ .effect_type = .speed, .amplifier = 0, .duration = 60.0 }); // +20%

    try std.testing.expectApproxEqAbs(@as(f32, 1.20), mgr.getSpeedMultiplier(), 0.001);
}

test "getSpeedMultiplier with slowness effect" {
    var mgr = EffectManager.init();
    mgr.addEffect(.{ .effect_type = .slowness, .amplifier = 0, .duration = 60.0 }); // -15%

    try std.testing.expectApproxEqAbs(@as(f32, 0.85), mgr.getSpeedMultiplier(), 0.001);
}

test "getSpeedMultiplier clamps to zero" {
    var mgr = EffectManager.init();
    // Slowness amplifier 9 => -150%, clamped to 0
    mgr.addEffect(.{ .effect_type = .slowness, .amplifier = 9, .duration = 60.0 });

    try std.testing.expectApproxEqAbs(@as(f32, 0.0), mgr.getSpeedMultiplier(), 0.001);
}

test "getSpeedMultiplier with no effects returns 1.0" {
    const mgr = EffectManager.init();
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), mgr.getSpeedMultiplier(), 0.001);
}

test "getDamageMultiplier with strength effect" {
    var mgr = EffectManager.init();
    mgr.addEffect(.{ .effect_type = .strength, .amplifier = 1, .duration = 60.0 }); // +60%

    try std.testing.expectApproxEqAbs(@as(f32, 1.60), mgr.getDamageMultiplier(), 0.001);
}

test "getDamageMultiplier with no effects returns 1.0" {
    const mgr = EffectManager.init();
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), mgr.getDamageMultiplier(), 0.001);
}

test "getBrewingRecipe returns recipe for known ingredients" {
    const recipe = getBrewingRecipe(1).?;
    try std.testing.expectEqual(EffectType.speed, recipe.base_effect);
    try std.testing.expectEqual(@as(u8, 0), recipe.amplifier);
    try std.testing.expectApproxEqAbs(@as(f32, 180.0), recipe.duration, 0.001);
}

test "getBrewingRecipe returns null for unknown ingredient" {
    try std.testing.expect(getBrewingRecipe(999) == null);
}

test "multiple effects coexist and contribute" {
    var mgr = EffectManager.init();
    mgr.addEffect(.{ .effect_type = .speed, .amplifier = 1, .duration = 60.0 }); // +40%
    mgr.addEffect(.{ .effect_type = .slowness, .amplifier = 0, .duration = 30.0 }); // -15%
    mgr.addEffect(.{ .effect_type = .strength, .amplifier = 0, .duration = 60.0 }); // +30%

    try std.testing.expectEqual(@as(u32, 3), mgr.activeCount());
    // Speed: 1.0 + 0.40 - 0.15 = 1.25
    try std.testing.expectApproxEqAbs(@as(f32, 1.25), mgr.getSpeedMultiplier(), 0.001);
    // Damage: 1.0 + 0.30 = 1.30
    try std.testing.expectApproxEqAbs(@as(f32, 1.30), mgr.getDamageMultiplier(), 0.001);
}
