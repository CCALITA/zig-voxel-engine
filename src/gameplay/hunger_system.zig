const std = @import("std");

pub const HungerState = struct {
    hunger: u8 = 20,
    saturation: f32 = 5.0,
    exhaustion: f32 = 0.0,
    regen_timer: f32 = 0.0,

    pub fn init() HungerState {
        return .{};
    }

    pub fn addExhaustion(self: *HungerState, amount: f32) void {
        self.exhaustion += amount;
    }

    pub fn update(self: *HungerState, dt: f32) struct { should_damage: bool, should_heal: bool } {
        // Process exhaustion: each 4.0 units drains 1 saturation or 1 hunger
        while (self.exhaustion >= 4.0) {
            self.exhaustion -= 4.0;
            if (self.saturation > 0) {
                self.saturation = @max(0, self.saturation - 1);
            } else if (self.hunger > 0) {
                self.hunger -= 1;
            }
        }

        var dmg = false;
        var heal = false;

        // Starvation damage at 0 hunger
        if (self.hunger == 0) {
            self.regen_timer += dt;
            if (self.regen_timer >= 1.0) {
                self.regen_timer -= 1.0;
                dmg = true;
            }
        }

        // Natural regen at 18+ hunger
        if (self.hunger >= 18) {
            self.regen_timer += dt;
            if (self.regen_timer >= 4.0) {
                self.regen_timer -= 4.0;
                heal = true;
            }
        }

        return .{ .should_damage = dmg, .should_heal = heal };
    }

    pub fn eat(self: *HungerState, food_hunger: u8, food_saturation: f32) void {
        self.hunger = @min(20, self.hunger + food_hunger);
        self.saturation = @min(
            @as(f32, @floatFromInt(self.hunger)),
            self.saturation + food_saturation,
        );
    }

    pub fn getHungerHearts(self: HungerState) u8 {
        return (self.hunger + 1) / 2;
    }
};

// Exhaustion costs per action
pub const WALK_EXHAUSTION: f32 = 0.01;
pub const SPRINT_EXHAUSTION: f32 = 0.1;
pub const JUMP_EXHAUSTION: f32 = 0.05;
pub const SWIM_EXHAUSTION: f32 = 0.01;
pub const ATTACK_EXHAUSTION: f32 = 0.1;
pub const MINE_EXHAUSTION: f32 = 0.005;

// Tests
// ──────────────────────────────────────────────────────────────────────────────

test "init returns default state" {
    const state = HungerState.init();
    try std.testing.expectEqual(@as(u8, 20), state.hunger);
    try std.testing.expectEqual(@as(f32, 5.0), state.saturation);
    try std.testing.expectEqual(@as(f32, 0.0), state.exhaustion);
    try std.testing.expectEqual(@as(f32, 0.0), state.regen_timer);
}

test "addExhaustion accumulates" {
    var state = HungerState.init();
    state.addExhaustion(1.5);
    try std.testing.expectEqual(@as(f32, 1.5), state.exhaustion);
    state.addExhaustion(2.0);
    try std.testing.expectEqual(@as(f32, 3.5), state.exhaustion);
}

test "exhaustion drains saturation first" {
    var state = HungerState.init();
    state.addExhaustion(4.0);
    _ = state.update(0.0);
    try std.testing.expectEqual(@as(f32, 4.0), state.saturation);
    try std.testing.expectEqual(@as(u8, 20), state.hunger);
}

test "exhaustion drains hunger when saturation is zero" {
    var state = HungerState.init();
    state.saturation = 0.0;
    state.addExhaustion(4.0);
    _ = state.update(0.0);
    try std.testing.expectEqual(@as(u8, 19), state.hunger);
    try std.testing.expectEqual(@as(f32, 0.0), state.saturation);
}

test "multiple exhaustion ticks in single update" {
    var state = HungerState.init();
    state.addExhaustion(12.0); // 3 ticks of 4.0
    _ = state.update(0.0);
    // saturation was 5.0, now 5.0 - 3 = 2.0
    try std.testing.expectEqual(@as(f32, 2.0), state.saturation);
    try std.testing.expectEqual(@as(u8, 20), state.hunger);
}

test "exhaustion overflow drains saturation then hunger" {
    var state = HungerState.init();
    state.saturation = 1.0;
    state.addExhaustion(8.0); // 2 ticks: first drains saturation to 0, second drains hunger
    _ = state.update(0.0);
    try std.testing.expectEqual(@as(f32, 0.0), state.saturation);
    try std.testing.expectEqual(@as(u8, 19), state.hunger);
}

test "starvation damage at zero hunger" {
    var state = HungerState.init();
    state.hunger = 0;
    state.saturation = 0.0;
    const result = state.update(1.0);
    try std.testing.expect(result.should_damage);
    try std.testing.expect(!result.should_heal);
}

test "no starvation damage below timer threshold" {
    var state = HungerState.init();
    state.hunger = 0;
    state.saturation = 0.0;
    const result = state.update(0.5);
    try std.testing.expect(!result.should_damage);
}

test "natural regen at hunger 18 or above" {
    var state = HungerState.init();
    state.hunger = 18;
    const result = state.update(4.0);
    try std.testing.expect(result.should_heal);
    try std.testing.expect(!result.should_damage);
}

test "no regen below hunger 18" {
    var state = HungerState.init();
    state.hunger = 17;
    const result = state.update(4.0);
    try std.testing.expect(!result.should_heal);
}

test "eat restores hunger and saturation" {
    var state = HungerState.init();
    state.hunger = 10;
    state.saturation = 0.0;
    state.eat(4, 2.4);
    try std.testing.expectEqual(@as(u8, 14), state.hunger);
    try std.testing.expectEqual(@as(f32, 2.4), state.saturation);
}

test "eat clamps hunger to 20" {
    var state = HungerState.init();
    state.hunger = 18;
    state.saturation = 0.0;
    state.eat(5, 6.0);
    try std.testing.expectEqual(@as(u8, 20), state.hunger);
}

test "eat clamps saturation to hunger level" {
    var state = HungerState.init();
    state.hunger = 10;
    state.saturation = 0.0;
    state.eat(4, 20.0); // hunger becomes 14, saturation capped at 14
    try std.testing.expectEqual(@as(u8, 14), state.hunger);
    try std.testing.expectEqual(@as(f32, 14.0), state.saturation);
}

test "getHungerHearts full hunger" {
    const state = HungerState.init();
    try std.testing.expectEqual(@as(u8, 10), state.getHungerHearts()); // (20+1)/2 = 10
}

test "getHungerHearts zero hunger" {
    var state = HungerState.init();
    state.hunger = 0;
    try std.testing.expectEqual(@as(u8, 0), state.getHungerHearts());
}

test "getHungerHearts odd hunger rounds up" {
    var state = HungerState.init();
    state.hunger = 1;
    try std.testing.expectEqual(@as(u8, 1), state.getHungerHearts());
    state.hunger = 7;
    try std.testing.expectEqual(@as(u8, 4), state.getHungerHearts());
}

test "exhaustion constants are positive" {
    try std.testing.expect(WALK_EXHAUSTION > 0);
    try std.testing.expect(SPRINT_EXHAUSTION > 0);
    try std.testing.expect(JUMP_EXHAUSTION > 0);
    try std.testing.expect(SWIM_EXHAUSTION > 0);
    try std.testing.expect(ATTACK_EXHAUSTION > 0);
    try std.testing.expect(MINE_EXHAUSTION > 0);
}

test "sprint costs more exhaustion than walk" {
    try std.testing.expect(SPRINT_EXHAUSTION > WALK_EXHAUSTION);
}

test "hunger does not underflow past zero" {
    var state = HungerState.init();
    state.hunger = 1;
    state.saturation = 0.0;
    state.addExhaustion(8.0); // 2 ticks, but hunger should stop at 0
    _ = state.update(0.0);
    try std.testing.expectEqual(@as(u8, 0), state.hunger);
}

test "regen timer accumulates across updates" {
    var state = HungerState.init();
    state.hunger = 20;
    var healed = false;
    // 4 updates of 1.0s each should trigger heal at 4.0
    for (0..4) |_| {
        const result = state.update(1.0);
        if (result.should_heal) healed = true;
    }
    try std.testing.expect(healed);
}

test "no events at full hunger with small dt" {
    var state = HungerState.init();
    const result = state.update(0.1);
    try std.testing.expect(!result.should_damage);
    try std.testing.expect(!result.should_heal);
}
