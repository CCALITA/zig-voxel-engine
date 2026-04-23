const std = @import("std");
const hunger_system = @import("hunger_system.zig");
const fire_damage = @import("fire_damage.zig");
const drowning_system = @import("drowning_system.zig");

pub const HungerState = hunger_system.HungerState;
pub const FireDamageState = fire_damage.FireDamageState;
pub const DrowningState = drowning_system.DrowningState;

pub const TickResult = struct {
    damage: f32,
    heal: f32,
    hunger: u8,
    air_bubbles: u8,
    on_fire: bool,
};

/// Aggregate all per-tick damage sources (hunger/starvation, fire/lava, drowning)
/// into a single TickResult. Callers pass mutable pointers to the three subsystem
/// states; each is advanced by `dt` seconds and the results are merged.
pub fn tickPlayerDamage(
    dt: f32,
    in_fire: bool,
    in_lava: bool,
    in_water: bool,
    head_submerged: bool,
    respiration_level: u8,
    exhaustion: f32,
    hunger: *HungerState,
    fire: *FireDamageState,
    drown: *DrowningState,
) TickResult {
    // 1. Hunger: apply incoming exhaustion, then tick
    hunger.addExhaustion(exhaustion);
    const hunger_result = hunger.update(dt);

    var total_damage: f32 = 0;
    var total_heal: f32 = 0;

    if (hunger_result.should_damage) total_damage += 1.0;
    if (hunger_result.should_heal) total_heal += 1.0;

    // 2. Fire / lava
    fire.setContact(in_fire, in_lava, in_water);
    total_damage += fire.update(dt);

    // 3. Drowning
    total_damage += drown.update(dt, head_submerged, respiration_level);

    return .{
        .damage = total_damage,
        .heal = total_heal,
        .hunger = hunger.hunger,
        .air_bubbles = drown.getAirBubbles(),
        .on_fire = fire.isOnFire(),
    };
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

test "idle tick: no hazards, full hunger, no damage" {
    var h = HungerState.init();
    var f = FireDamageState.init();
    var d = DrowningState.init();
    const r = tickPlayerDamage(0.1, false, false, false, false, 0, 0, &h, &f, &d);
    try std.testing.expectEqual(@as(f32, 0), r.damage);
    try std.testing.expectEqual(@as(f32, 0), r.heal);
    try std.testing.expectEqual(@as(u8, 20), r.hunger);
    try std.testing.expectEqual(@as(u8, 10), r.air_bubbles);
    try std.testing.expect(!r.on_fire);
}

test "fire only: 1 damage per second" {
    var h = HungerState.init();
    var f = FireDamageState.init();
    var d = DrowningState.init();
    const r = tickPlayerDamage(1.0, true, false, false, false, 0, 0, &h, &f, &d);
    try std.testing.expectEqual(@as(f32, 1.0), r.damage);
    try std.testing.expect(r.on_fire);
}

test "lava only: 8 damage per second" {
    var h = HungerState.init();
    var f = FireDamageState.init();
    var d = DrowningState.init();
    const r = tickPlayerDamage(1.0, false, true, false, false, 0, 0, &h, &f, &d);
    try std.testing.expectEqual(@as(f32, 8.0), r.damage);
    try std.testing.expect(r.on_fire);
}

test "drowning only: 2 damage per 0.5s when no air" {
    var h = HungerState.init();
    var f = FireDamageState.init();
    var d = DrowningState.init();
    d.air_bubbles = 0;
    const r = tickPlayerDamage(0.5, false, false, false, true, 0, 0, &h, &f, &d);
    try std.testing.expectEqual(@as(f32, 2.0), r.damage);
    try std.testing.expectEqual(@as(u8, 0), r.air_bubbles);
}

test "starvation only: 1 damage per second at zero hunger" {
    var h = HungerState.init();
    h.hunger = 0;
    h.saturation = 0;
    var f = FireDamageState.init();
    var d = DrowningState.init();
    const r = tickPlayerDamage(1.0, false, false, false, false, 0, 0, &h, &f, &d);
    try std.testing.expectEqual(@as(f32, 1.0), r.damage);
    try std.testing.expectEqual(@as(u8, 0), r.hunger);
}

test "fire plus drowning: damage aggregates" {
    var h = HungerState.init();
    var f = FireDamageState.init();
    var d = DrowningState.init();
    d.air_bubbles = 0;
    // in_fire=true but also head_submerged (in_water=false so fire not extinguished)
    const r = tickPlayerDamage(1.0, true, false, false, true, 0, 0, &h, &f, &d);
    // fire: 1.0 + drowning: 4.0 (1.0s / 0.5 = 2 ticks * 2.0)
    try std.testing.expectEqual(@as(f32, 5.0), r.damage);
    try std.testing.expect(r.on_fire);
}

test "starvation plus lava: damage aggregates" {
    var h = HungerState.init();
    h.hunger = 0;
    h.saturation = 0;
    var f = FireDamageState.init();
    var d = DrowningState.init();
    const r = tickPlayerDamage(1.0, false, true, false, false, 0, 0, &h, &f, &d);
    // starvation: 1.0 + lava: 8.0
    try std.testing.expectEqual(@as(f32, 9.0), r.damage);
}

test "natural regen at high hunger" {
    var h = HungerState.init();
    h.hunger = 20;
    h.regen_timer = 3.5;
    var f = FireDamageState.init();
    var d = DrowningState.init();
    const r = tickPlayerDamage(0.5, false, false, false, false, 0, 0, &h, &f, &d);
    try std.testing.expectEqual(@as(f32, 1.0), r.heal);
    try std.testing.expectEqual(@as(f32, 0), r.damage);
}

test "water extinguishes fire: no fire damage" {
    var h = HungerState.init();
    var f = FireDamageState.init();
    f.fire_ticks = 100;
    var d = DrowningState.init();
    const r = tickPlayerDamage(1.0, false, false, true, false, 0, 0, &h, &f, &d);
    try std.testing.expectEqual(@as(f32, 0), r.damage);
    try std.testing.expect(!r.on_fire);
}

test "exhaustion parameter drains hunger over time" {
    var h = HungerState.init();
    h.saturation = 0;
    var f = FireDamageState.init();
    var d = DrowningState.init();
    // 4.0 exhaustion = 1 hunger point drained
    const r = tickPlayerDamage(0.1, false, false, false, false, 0, 4.0, &h, &f, &d);
    try std.testing.expectEqual(@as(u8, 19), r.hunger);
    try std.testing.expectEqual(@as(f32, 0), r.damage);
}

test "respiration delays drowning damage" {
    var h = HungerState.init();
    var f = FireDamageState.init();
    var d1 = DrowningState.init();
    var d2 = DrowningState.init();
    // Without respiration, 15s submerged drains all 10 bubbles (1.5s each)
    const r1 = tickPlayerDamage(15.0, false, false, false, true, 0, 0, &h, &f, &d1);
    // With respiration level 3, bubble_time = 1.5 + 45 = 46.5s per bubble
    h = HungerState.init();
    f = FireDamageState.init();
    const r2 = tickPlayerDamage(15.0, false, false, false, true, 3, 0, &h, &f, &d2);
    // r1 should have taken drowning damage, r2 should not
    try std.testing.expect(r1.damage > 0);
    try std.testing.expectEqual(@as(f32, 0), r2.damage);
    try std.testing.expect(r2.air_bubbles > r1.air_bubbles);
}

test "all three damage sources simultaneously" {
    var h = HungerState.init();
    h.hunger = 0;
    h.saturation = 0;
    var f = FireDamageState.init();
    var d = DrowningState.init();
    d.air_bubbles = 0;
    // starvation(1.0) + fire(1.0) + drowning(4.0) over 1 second
    const r = tickPlayerDamage(1.0, true, false, false, true, 0, 0, &h, &f, &d);
    try std.testing.expectEqual(@as(f32, 6.0), r.damage);
    try std.testing.expect(r.on_fire);
    try std.testing.expectEqual(@as(u8, 0), r.hunger);
    try std.testing.expectEqual(@as(u8, 0), r.air_bubbles);
}

test "zero dt produces no damage and no heal" {
    var h = HungerState.init();
    var f = FireDamageState.init();
    var d = DrowningState.init();
    const r = tickPlayerDamage(0, true, false, false, true, 0, 0, &h, &f, &d);
    try std.testing.expectEqual(@as(f32, 0), r.damage);
    try std.testing.expectEqual(@as(f32, 0), r.heal);
}
