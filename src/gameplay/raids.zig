const std = @import("std");

pub const RaidWave = struct {
    pillagers: u8,
    vindicators: u8,
    ravagers: u8,
    evokers: u8,
    witches: u8,

    pub fn totalMobs(self: RaidWave) u8 {
        return self.pillagers + self.vindicators + self.ravagers + self.evokers + self.witches;
    }
};

/// Wave compositions roughly following Minecraft Java Edition raid scaling.
pub const WAVES = [7]RaidWave{
    .{ .pillagers = 4, .vindicators = 0, .ravagers = 0, .evokers = 0, .witches = 0 },
    .{ .pillagers = 3, .vindicators = 2, .ravagers = 0, .evokers = 0, .witches = 0 },
    .{ .pillagers = 3, .vindicators = 1, .ravagers = 1, .evokers = 0, .witches = 0 },
    .{ .pillagers = 3, .vindicators = 2, .ravagers = 1, .evokers = 0, .witches = 1 },
    .{ .pillagers = 4, .vindicators = 3, .ravagers = 1, .evokers = 1, .witches = 0 },
    .{ .pillagers = 4, .vindicators = 3, .ravagers = 1, .evokers = 1, .witches = 1 },
    .{ .pillagers = 5, .vindicators = 4, .ravagers = 2, .evokers = 2, .witches = 1 },
};

pub const RaidPhase = enum {
    countdown,
    fighting,
    victory,
    defeat,
};

pub const RaidState = struct {
    active: bool,
    wave: u8 = 0,
    remaining_mobs: u8,
    center_x: i32,
    center_z: i32,
    cooldown: f32 = 0,

    pub fn getCurrentWave(self: RaidState) RaidWave {
        if (self.wave >= WAVES.len) {
            return WAVES[WAVES.len - 1];
        }
        return WAVES[self.wave];
    }

    pub fn advanceWave(self: *RaidState) bool {
        if (self.wave + 1 >= WAVES.len) {
            return false;
        }
        self.wave += 1;
        self.remaining_mobs = WAVES[self.wave].totalMobs();
        self.cooldown = 5.0;
        return true;
    }

    pub fn killRaider(self: *RaidState) void {
        if (self.remaining_mobs > 0) {
            self.remaining_mobs -= 1;
        }
    }

    pub fn isVictory(self: RaidState) bool {
        return self.remaining_mobs == 0 and self.wave + 1 >= WAVES.len;
    }

    pub fn update(self: *RaidState, dt: f32) RaidPhase {
        if (!self.active) return .defeat;

        if (self.cooldown > 0) {
            self.cooldown -= dt;
            if (self.cooldown > 0) return .countdown;
        }

        if (self.remaining_mobs > 0) return .fighting;

        // Wave cleared -- either final victory or advance to next wave.
        if (self.wave + 1 >= WAVES.len) {
            self.active = false;
            return .victory;
        }

        _ = self.advanceWave();
        return .countdown;
    }
};

pub const Reward = struct {
    effect_type: u8,
    duration: f32,
};

/// Hero of the Village reward: effect type 32, duration 40 minutes (2400 seconds).
pub fn getReward() Reward {
    return .{ .effect_type = 32, .duration = 2400.0 };
}

pub fn startRaid(center_x: i32, center_z: i32, bad_omen_level: u8) RaidState {
    const starting_wave: u8 = if (bad_omen_level > 1 and bad_omen_level <= WAVES.len)
        bad_omen_level - 1
    else
        0;
    return .{
        .active = true,
        .wave = starting_wave,
        .remaining_mobs = WAVES[starting_wave].totalMobs(),
        .center_x = center_x,
        .center_z = center_z,
        .cooldown = 5.0,
    };
}

// Tests

test "WAVES has 7 entries" {
    try std.testing.expectEqual(@as(usize, 7), WAVES.len);
}

test "waves escalate in difficulty" {
    var prev_total: u8 = 0;
    for (WAVES) |wave| {
        const total = wave.totalMobs();
        try std.testing.expect(total >= prev_total);
        prev_total = total;
    }
}

test "startRaid initialises correctly" {
    const state = startRaid(100, -200, 1);
    try std.testing.expect(state.active);
    try std.testing.expectEqual(@as(u8, 0), state.wave);
    try std.testing.expectEqual(@as(i32, 100), state.center_x);
    try std.testing.expectEqual(@as(i32, -200), state.center_z);
    try std.testing.expectEqual(WAVES[0].totalMobs(), state.remaining_mobs);
}

test "bad omen level skips waves" {
    const state = startRaid(0, 0, 3);
    try std.testing.expectEqual(@as(u8, 2), state.wave);
}

test "advanceWave returns false on last wave" {
    var state = startRaid(0, 0, 1);
    state.wave = WAVES.len - 1;
    try std.testing.expect(!state.advanceWave());
}

test "killRaider decrements remaining" {
    var state = startRaid(0, 0, 1);
    const before = state.remaining_mobs;
    state.killRaider();
    try std.testing.expectEqual(before - 1, state.remaining_mobs);
}

test "victory condition after clearing all waves" {
    var state = startRaid(0, 0, 1);
    // fast-forward to last wave with 0 remaining
    state.wave = WAVES.len - 1;
    state.remaining_mobs = 0;
    try std.testing.expect(state.isVictory());
}

test "update returns victory and deactivates raid" {
    var state = startRaid(0, 0, 1);
    state.wave = WAVES.len - 1;
    state.remaining_mobs = 0;
    state.cooldown = 0;
    const phase = state.update(0.0);
    try std.testing.expectEqual(RaidPhase.victory, phase);
    try std.testing.expect(!state.active);
}

test "update countdown while cooldown positive" {
    var state = startRaid(0, 0, 1);
    state.cooldown = 3.0;
    const phase = state.update(1.0);
    try std.testing.expectEqual(RaidPhase.countdown, phase);
}

test "update returns fighting during combat" {
    var state = startRaid(0, 0, 1);
    state.cooldown = 0;
    const phase = state.update(0.0);
    try std.testing.expectEqual(RaidPhase.fighting, phase);
}

test "getReward returns hero of the village" {
    const reward = getReward();
    try std.testing.expectEqual(@as(u8, 32), reward.effect_type);
    try std.testing.expectEqual(@as(f32, 2400.0), reward.duration);
}

test "full raid lifecycle" {
    var state = startRaid(50, 50, 1);
    var waves_completed: u8 = 0;

    while (state.active) {
        // drain cooldown
        while (state.cooldown > 0) {
            _ = state.update(1.0);
        }
        // kill all remaining mobs
        while (state.remaining_mobs > 0) {
            state.killRaider();
        }
        const phase = state.update(0.0);
        if (phase == .victory) break;
        waves_completed += 1;
    }

    try std.testing.expect(!state.active);
    try std.testing.expect(state.isVictory());
    // Should have advanced through waves 1-6 (6 advances total)
    try std.testing.expectEqual(@as(u8, 6), waves_completed);
}
