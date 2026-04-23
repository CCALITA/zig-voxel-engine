const std = @import("std");

pub const DrowningState = struct {
    air_bubbles: u8 = 10,
    breath_timer: f32 = 0,
    damage_timer: f32 = 0,

    pub fn init() DrowningState {
        return .{};
    }

    pub fn update(self: *DrowningState, dt: f32, head_submerged: bool, respiration_level: u8) f32 {
        if (!head_submerged) {
            self.air_bubbles = 10;
            self.breath_timer = 0;
            self.damage_timer = 0;
            return 0;
        }
        const bubble_time: f32 = 1.5 + @as(f32, @floatFromInt(respiration_level)) * 15.0;
        self.breath_timer += dt;
        while (self.breath_timer >= bubble_time and self.air_bubbles > 0) {
            self.breath_timer -= bubble_time;
            self.air_bubbles -= 1;
        }
        var damage: f32 = 0;
        if (self.air_bubbles == 0) {
            self.damage_timer += dt;
            while (self.damage_timer >= 0.5) {
                self.damage_timer -= 0.5;
                damage += 2.0;
            }
        }
        return damage;
    }

    pub fn getAirBubbles(self: DrowningState) u8 {
        return self.air_bubbles;
    }

    pub fn isDrowning(self: DrowningState) bool {
        return self.air_bubbles == 0;
    }
};

test "init state" {
    const s = DrowningState.init();
    try std.testing.expectEqual(@as(u8, 10), s.air_bubbles);
    try std.testing.expect(!s.isDrowning());
}

test "not submerged no damage" {
    var s = DrowningState.init();
    const dmg = s.update(1.0, false, 0);
    try std.testing.expectEqual(@as(f32, 0), dmg);
    try std.testing.expectEqual(@as(u8, 10), s.air_bubbles);
}

test "submerged drains bubbles" {
    var s = DrowningState.init();
    _ = s.update(1.5, true, 0);
    try std.testing.expect(s.air_bubbles < 10);
}

test "surface restores bubbles" {
    var s = DrowningState.init();
    s.air_bubbles = 3;
    _ = s.update(0.1, false, 0);
    try std.testing.expectEqual(@as(u8, 10), s.air_bubbles);
}

test "drowning deals damage" {
    var s = DrowningState.init();
    s.air_bubbles = 0;
    const dmg = s.update(0.5, true, 0);
    try std.testing.expectEqual(@as(f32, 2.0), dmg);
}

test "respiration extends time" {
    var s1 = DrowningState.init();
    var s2 = DrowningState.init();
    _ = s1.update(1.5, true, 0);
    _ = s2.update(1.5, true, 1);
    try std.testing.expect(s2.air_bubbles > s1.air_bubbles);
}

test "isDrowning when zero bubbles" {
    var s = DrowningState.init();
    s.air_bubbles = 0;
    try std.testing.expect(s.isDrowning());
}

test "no damage with bubbles remaining" {
    var s = DrowningState.init();
    s.air_bubbles = 5;
    const dmg = s.update(0.5, true, 0);
    try std.testing.expectEqual(@as(f32, 0), dmg);
}

test "multiple damage ticks" {
    var s = DrowningState.init();
    s.air_bubbles = 0;
    const dmg = s.update(1.0, true, 0);
    try std.testing.expectEqual(@as(f32, 4.0), dmg);
}

test "respiration level 2 much slower drain" {
    var s = DrowningState.init();
    _ = s.update(10.0, true, 2);
    try std.testing.expect(s.air_bubbles > 5);
}
