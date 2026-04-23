const std = @import("std");

pub const max_air_bubbles: u8 = 10;
const damage_interval: f32 = 0.5;
const damage_per_tick: f32 = 2.0;
const base_bubble_time: f32 = 1.5;
const respiration_bonus: f32 = 15.0;

pub const DrowningState = struct {
    air_bubbles: u8 = max_air_bubbles,
    breath_timer: f32 = 0,
    damage_timer: f32 = 0,

    pub fn init() DrowningState {
        return .{};
    }

    /// Advance the drowning simulation by `dt` seconds.
    /// Returns the total drowning damage dealt this tick.
    pub fn update(self: *DrowningState, dt: f32, head_submerged: bool, respiration_level: u8) f32 {
        if (!head_submerged) {
            self.reset();
            return 0;
        }

        self.consumeAir(dt, respiration_level);
        return self.applyDrowningDamage(dt);
    }

    pub fn getAirBubbles(self: DrowningState) u8 {
        return self.air_bubbles;
    }

    pub fn isDrowning(self: DrowningState) bool {
        return self.air_bubbles == 0;
    }

    // -- private helpers --

    fn reset(self: *DrowningState) void {
        self.air_bubbles = max_air_bubbles;
        self.breath_timer = 0;
        self.damage_timer = 0;
    }

    fn bubbleTime(respiration_level: u8) f32 {
        return base_bubble_time + @as(f32, @floatFromInt(respiration_level)) * respiration_bonus;
    }

    fn consumeAir(self: *DrowningState, dt: f32, respiration_level: u8) void {
        const interval = bubbleTime(respiration_level);
        self.breath_timer += dt;
        while (self.breath_timer >= interval and self.air_bubbles > 0) {
            self.breath_timer -= interval;
            self.air_bubbles -= 1;
        }
    }

    fn applyDrowningDamage(self: *DrowningState, dt: f32) f32 {
        if (self.air_bubbles > 0) return 0;

        self.damage_timer += dt;
        var damage: f32 = 0;
        while (self.damage_timer >= damage_interval) {
            self.damage_timer -= damage_interval;
            damage += damage_per_tick;
        }
        return damage;
    }
};

// Tests
// ──────────────────────────────────────────────────────────────────────────────

test "init returns default state" {
    const state = DrowningState.init();
    try std.testing.expectEqual(@as(u8, 10), state.air_bubbles);
    try std.testing.expectEqual(@as(f32, 0.0), state.breath_timer);
    try std.testing.expectEqual(@as(f32, 0.0), state.damage_timer);
}

test "surfacing resets all state" {
    var state = DrowningState.init();
    state.air_bubbles = 3;
    state.breath_timer = 1.0;
    state.damage_timer = 0.3;
    const damage = state.update(0.1, false, 0);
    try std.testing.expectEqual(@as(f32, 0.0), damage);
    try std.testing.expectEqual(@as(u8, 10), state.air_bubbles);
    try std.testing.expectEqual(@as(f32, 0.0), state.breath_timer);
    try std.testing.expectEqual(@as(f32, 0.0), state.damage_timer);
}

test "submerged but timer not elapsed keeps full air" {
    var state = DrowningState.init();
    const damage = state.update(1.0, true, 0);
    try std.testing.expectEqual(@as(f32, 0.0), damage);
    try std.testing.expectEqual(@as(u8, 10), state.air_bubbles);
}

test "one bubble lost at base interval" {
    var state = DrowningState.init();
    _ = state.update(1.5, true, 0);
    try std.testing.expectEqual(@as(u8, 9), state.air_bubbles);
}

test "multiple bubbles lost in single update" {
    var state = DrowningState.init();
    // 3.0s = 2 intervals of 1.5s
    _ = state.update(3.0, true, 0);
    try std.testing.expectEqual(@as(u8, 8), state.air_bubbles);
}

test "respiration extends bubble time" {
    var state = DrowningState.init();
    // respiration 1 → bubble_time = 1.5 + 15 = 16.5s
    _ = state.update(16.0, true, 1);
    try std.testing.expectEqual(@as(u8, 10), state.air_bubbles);
    _ = state.update(0.5, true, 1);
    try std.testing.expectEqual(@as(u8, 9), state.air_bubbles);
}

test "isDrowning false with air remaining" {
    var state = DrowningState.init();
    try std.testing.expect(!state.isDrowning());
    _ = state.update(1.5, true, 0);
    try std.testing.expect(!state.isDrowning());
}

test "isDrowning true at zero bubbles" {
    var state = DrowningState.init();
    state.air_bubbles = 0;
    try std.testing.expect(state.isDrowning());
}

test "drowning damage dealt when air is zero" {
    var state = DrowningState.init();
    state.air_bubbles = 0;
    const damage = state.update(0.5, true, 0);
    try std.testing.expectEqual(@as(f32, 2.0), damage);
}

test "multiple damage ticks in one update" {
    var state = DrowningState.init();
    state.air_bubbles = 0;
    const damage = state.update(1.5, true, 0);
    // 1.5s / 0.5s = 3 ticks × 2.0 = 6.0
    try std.testing.expectEqual(@as(f32, 6.0), damage);
}

test "no damage before interval elapses at zero air" {
    var state = DrowningState.init();
    state.air_bubbles = 0;
    const damage = state.update(0.4, true, 0);
    try std.testing.expectEqual(@as(f32, 0.0), damage);
}

test "getAirBubbles matches internal state" {
    var state = DrowningState.init();
    try std.testing.expectEqual(@as(u8, 10), state.getAirBubbles());
    _ = state.update(1.5, true, 0);
    try std.testing.expectEqual(@as(u8, 9), state.getAirBubbles());
}

test "full drain then damage across updates" {
    var state = DrowningState.init();
    // drain all 10 bubbles: 10 × 1.5s = 15s
    _ = state.update(15.0, true, 0);
    try std.testing.expectEqual(@as(u8, 0), state.air_bubbles);
    // next update should deal damage
    const damage = state.update(1.0, true, 0);
    // 1.0 / 0.5 = 2 ticks × 2.0 = 4.0
    try std.testing.expectEqual(@as(f32, 4.0), damage);
}

test "respiration level 3 greatly extends breath" {
    var state = DrowningState.init();
    // bubble_time = 1.5 + 3×15 = 46.5s
    _ = state.update(46.0, true, 3);
    try std.testing.expectEqual(@as(u8, 10), state.air_bubbles);
}

test "damage timer resets on surface" {
    var state = DrowningState.init();
    state.air_bubbles = 0;
    _ = state.update(0.3, true, 0); // accumulate partial damage timer
    _ = state.update(0.0, false, 0); // surface
    try std.testing.expectEqual(@as(f32, 0.0), state.damage_timer);
    try std.testing.expectEqual(@as(u8, 10), state.air_bubbles);
}
