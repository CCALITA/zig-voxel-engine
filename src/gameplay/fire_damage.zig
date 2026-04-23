pub const FireDamageState = struct {
    in_fire: bool = false,
    in_lava: bool = false,
    in_water: bool = false,
    fire_ticks: u16 = 0,
    fire_resistance: bool = false,
    damage_timer: f32 = 0,

    pub fn init() FireDamageState {
        return .{};
    }

    pub fn setContact(self: *FireDamageState, fire: bool, lava: bool, water: bool) void {
        self.in_fire = fire;
        self.in_lava = lava;
        self.in_water = water;
        if (water) {
            self.fire_ticks = 0;
            self.in_fire = false;
        }
        if (fire and !self.fire_resistance) self.fire_ticks = 160;
        if (lava and !self.fire_resistance) self.fire_ticks = 300;
    }

    pub fn update(self: *FireDamageState, dt: f32) f32 {
        if (self.fire_resistance) return 0;
        var damage: f32 = 0;
        if (self.in_lava) {
            self.damage_timer += dt;
            while (self.damage_timer >= 0.5) {
                self.damage_timer -= 0.5;
                damage += 4.0;
            }
        } else if (self.fire_ticks > 0 or self.in_fire) {
            self.damage_timer += dt;
            while (self.damage_timer >= 1.0) {
                self.damage_timer -= 1.0;
                damage += 1.0;
            }
        } else {
            self.damage_timer = 0;
        }
        if (self.fire_ticks > 0 and !self.in_fire and !self.in_lava) self.fire_ticks -= 1;
        return damage;
    }

    pub fn isOnFire(self: FireDamageState) bool {
        return self.fire_ticks > 0 or self.in_fire or self.in_lava;
    }

    pub fn getFireTicksRemaining(self: FireDamageState) u16 {
        return self.fire_ticks;
    }
};

test "init returns default state" {
    const state = FireDamageState.init();
    try std.testing.expect(!state.in_fire);
    try std.testing.expect(!state.in_lava);
    try std.testing.expect(!state.in_water);
    try std.testing.expectEqual(@as(u16, 0), state.fire_ticks);
    try std.testing.expect(!state.fire_resistance);
    try std.testing.expectEqual(@as(f32, 0), state.damage_timer);
    try std.testing.expect(!state.isOnFire());
}

test "lava deals 4 damage per 0.5s tick" {
    var state = FireDamageState.init();
    state.setContact(false, true, false);
    const damage = state.update(1.0);
    try std.testing.expectEqual(@as(f32, 8.0), damage);
}

test "lava deals 4 damage for a single half-second" {
    var state = FireDamageState.init();
    state.setContact(false, true, false);
    const damage = state.update(0.5);
    try std.testing.expectEqual(@as(f32, 4.0), damage);
}

test "fire deals 1 damage per 1.0s tick" {
    var state = FireDamageState.init();
    state.setContact(true, false, false);
    const damage = state.update(1.0);
    try std.testing.expectEqual(@as(f32, 1.0), damage);
}

test "fire deals no damage before 1.0s elapsed" {
    var state = FireDamageState.init();
    state.setContact(true, false, false);
    const damage = state.update(0.5);
    try std.testing.expectEqual(@as(f32, 0.0), damage);
}

test "water extinguishes fire and resets fire_ticks" {
    var state = FireDamageState.init();
    state.setContact(true, false, false);
    try std.testing.expectEqual(@as(u16, 160), state.fire_ticks);
    state.setContact(false, false, true);
    try std.testing.expectEqual(@as(u16, 0), state.fire_ticks);
    try std.testing.expect(!state.in_fire);
    try std.testing.expect(!state.isOnFire());
}

test "fire_resistance blocks all damage from lava" {
    var state = FireDamageState.init();
    state.fire_resistance = true;
    state.setContact(false, true, false);
    const damage = state.update(2.0);
    try std.testing.expectEqual(@as(f32, 0.0), damage);
}

test "fire_resistance blocks all damage from fire" {
    var state = FireDamageState.init();
    state.fire_resistance = true;
    state.setContact(true, false, false);
    const damage = state.update(2.0);
    try std.testing.expectEqual(@as(f32, 0.0), damage);
}

test "fire_ticks decay when not in fire or lava" {
    var state = FireDamageState.init();
    state.setContact(true, false, false);
    try std.testing.expectEqual(@as(u16, 160), state.fire_ticks);
    state.setContact(false, false, false);
    _ = state.update(0.0);
    try std.testing.expectEqual(@as(u16, 159), state.fire_ticks);
    _ = state.update(0.0);
    try std.testing.expectEqual(@as(u16, 158), state.fire_ticks);
}

test "isOnFire returns true for fire, lava, and lingering fire_ticks" {
    var state = FireDamageState.init();
    try std.testing.expect(!state.isOnFire());

    state.setContact(true, false, false);
    try std.testing.expect(state.isOnFire());

    state = FireDamageState.init();
    state.setContact(false, true, false);
    try std.testing.expect(state.isOnFire());

    state = FireDamageState.init();
    state.fire_ticks = 10;
    try std.testing.expect(state.isOnFire());
}

test "setContact transitions: fire to lava increases fire_ticks" {
    var state = FireDamageState.init();
    state.setContact(true, false, false);
    try std.testing.expectEqual(@as(u16, 160), state.fire_ticks);
    state.setContact(false, true, false);
    try std.testing.expectEqual(@as(u16, 300), state.fire_ticks);
    try std.testing.expect(state.in_lava);
    try std.testing.expect(!state.in_fire);
}

test "fire_resistance prevents fire_ticks from being set" {
    var state = FireDamageState.init();
    state.fire_resistance = true;
    state.setContact(true, false, false);
    try std.testing.expectEqual(@as(u16, 0), state.fire_ticks);
    state.setContact(false, true, false);
    try std.testing.expectEqual(@as(u16, 0), state.fire_ticks);
}

test "getFireTicksRemaining reflects current state" {
    var state = FireDamageState.init();
    try std.testing.expectEqual(@as(u16, 0), state.getFireTicksRemaining());
    state.setContact(true, false, false);
    try std.testing.expectEqual(@as(u16, 160), state.getFireTicksRemaining());
    state.setContact(false, true, false);
    try std.testing.expectEqual(@as(u16, 300), state.getFireTicksRemaining());
}

const std = @import("std");
