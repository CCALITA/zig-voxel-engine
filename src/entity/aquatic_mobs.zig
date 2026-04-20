/// Aquatic mobs: Dolphin, Turtle, Glow Squid, Squid, Guardian.
const std = @import("std");

pub const Dolphin = struct {
    x: f32, y: f32, z: f32,
    hp: f32 = 10.0,
    alive: bool = true,
    speed: f32 = 8.0,
    grace_timer: f32 = 0.0,
    out_of_water_timer: f32 = 0.0,
    hostile: bool = false,
    max_air_time: f32 = 240.0,

    pub fn update(self: *Dolphin, dt: f32, in_water: bool) void {
        if (!self.alive) return;
        if (!in_water) {
            self.out_of_water_timer += dt;
            if (self.out_of_water_timer >= self.max_air_time) {
                self.hp -= 1.0;
                self.out_of_water_timer = 0;
            }
        } else {
            self.out_of_water_timer = 0;
        }
        if (self.grace_timer > 0) self.grace_timer -= dt;
        if (self.hp <= 0) self.alive = false;
    }

    pub fn grantDolphinsGrace(self: *Dolphin, player_dist: f32) bool {
        return self.alive and player_dist < 10.0 and self.grace_timer <= 0;
    }

    pub fn getGraceDuration() f32 { return 7.0; }

    pub fn onAttacked(self: *Dolphin, dmg: f32) void {
        self.hp -= dmg;
        self.hostile = true;
        if (self.hp <= 0) self.alive = false;
    }
};

pub const TurtleEgg = struct {
    x: i32, y: i32, z: i32,
    count: u8 = 1,
    hatch_progress: f32 = 0.0,
    hatched: bool = false,

    pub fn update(self: *TurtleEgg, dt: f32, is_night: bool) void {
        if (self.hatched) return;
        if (is_night) self.hatch_progress += dt;
        if (self.hatch_progress >= 4800.0) self.hatched = true; // ~4 day cycles
    }

    pub fn trample(self: *TurtleEgg) bool {
        if (self.count > 1) { self.count -= 1; return false; }
        self.hatched = true; // destroyed
        return true;
    }
};

pub const Turtle = struct {
    x: f32, y: f32, z: f32,
    hp: f32 = 30.0,
    alive: bool = true,
    is_baby: bool = false,
    home_x: f32, home_z: f32,
    has_egg: bool = false,
    growth_timer: f32 = 0.0,

    pub fn init(x: f32, y: f32, z: f32) Turtle {
        return .{ .x = x, .y = y, .z = z, .home_x = x, .home_z = z };
    }

    pub fn update(self: *Turtle, dt: f32) void {
        if (!self.alive) return;
        if (self.is_baby) {
            self.growth_timer += dt;
            if (self.growth_timer >= 24000.0) self.is_baby = false; // 20 min
        }
        if (self.hp <= 0) self.alive = false;
    }

    pub fn getSpeed(self: *const Turtle, in_water: bool) f32 {
        if (self.is_baby) return if (in_water) 0.8 else 0.08;
        return if (in_water) 1.0 else 0.1;
    }

    pub fn getDrops(self: *const Turtle) struct { scute: bool, seagrass: u8 } {
        return .{ .scute = !self.is_baby, .seagrass = if (self.is_baby) 0 else 2 };
    }
};

pub const GlowSquid = struct {
    x: f32, y: f32, z: f32,
    hp: f32 = 10.0,
    alive: bool = true,
    glowing: bool = true,
    dark_timer: f32 = 0.0,

    pub fn update(self: *GlowSquid, dt: f32, in_water: bool) void {
        if (!self.alive) return;
        if (self.dark_timer > 0) {
            self.dark_timer -= dt;
            self.glowing = self.dark_timer <= 0;
        }
        if (!in_water) { self.hp -= dt * 0.5; }
        if (self.hp <= 0) self.alive = false;
    }

    pub fn onHit(self: *GlowSquid, dmg: f32) void {
        self.hp -= dmg;
        self.glowing = false;
        self.dark_timer = 5.0;
        if (self.hp <= 0) self.alive = false;
    }

    pub fn getDrops(rng: u32) u8 {
        return @intCast(1 + rng % 3); // 1-3 glow ink sacs
    }
};

pub const Squid = struct {
    x: f32, y: f32, z: f32,
    hp: f32 = 10.0,
    alive: bool = true,
    suffocate_timer: f32 = 0.0,

    pub fn update(self: *Squid, dt: f32, in_water: bool) void {
        if (!self.alive) return;
        if (!in_water) {
            self.suffocate_timer += dt;
            if (self.suffocate_timer >= 15.0) { self.hp -= 1.0; self.suffocate_timer = 0; }
        } else {
            self.suffocate_timer = 0;
        }
        if (self.hp <= 0) self.alive = false;
    }

    pub fn onHit(self: *Squid, dmg: f32) struct { ink_cloud: bool } {
        self.hp -= dmg;
        if (self.hp <= 0) self.alive = false;
        return .{ .ink_cloud = true };
    }

    pub fn getDrops(rng: u32) u8 {
        return @intCast(1 + rng % 3); // 1-3 ink sacs
    }
};

pub const GuardianState = enum { idle, targeting, firing, cooldown };

pub const Guardian = struct {
    x: f32, y: f32, z: f32,
    hp: f32 = 30.0,
    alive: bool = true,
    state: GuardianState = .idle,
    laser_charge: f32 = 0.0,
    cooldown_timer: f32 = 0.0,
    target_x: f32 = 0, target_y: f32 = 0, target_z: f32 = 0,
    is_elder: bool = false,
    spikes_out: bool = false,

    pub fn init(x: f32, y: f32, z: f32, elder: bool) Guardian {
        return .{
            .x = x, .y = y, .z = z,
            .is_elder = elder,
            .hp = if (elder) 80.0 else 30.0,
        };
    }

    pub fn update(self: *Guardian, dt: f32, px: f32, py: f32, pz: f32) GuardianState {
        if (!self.alive) return .idle;
        if (self.hp <= 0) { self.alive = false; return .idle; }

        const dx = px - self.x;
        const dy = py - self.y;
        const dz = pz - self.z;
        const dist = @sqrt(dx * dx + dy * dy + dz * dz);

        switch (self.state) {
            .idle => {
                if (dist < 16.0) {
                    self.state = .targeting;
                    self.target_x = px; self.target_y = py; self.target_z = pz;
                }
            },
            .targeting => {
                self.laser_charge += dt;
                self.target_x = px; self.target_y = py; self.target_z = pz;
                if (self.laser_charge >= 2.0) {
                    self.state = .firing;
                    self.laser_charge = 0;
                }
                if (dist > 20.0) { self.state = .idle; self.laser_charge = 0; }
            },
            .firing => {
                self.state = .cooldown;
                self.cooldown_timer = 3.0;
            },
            .cooldown => {
                self.cooldown_timer -= dt;
                if (self.cooldown_timer <= 0) self.state = .idle;
            },
        }

        self.spikes_out = (@as(u32, @intFromFloat(self.x * 7)) % 40) < 20;
        return self.state;
    }

    pub fn getLaserDamage(self: *const Guardian, difficulty_hard: bool) f32 {
        const base: f32 = if (self.is_elder) 8.0 else 6.0;
        return if (difficulty_hard) base + 2.0 else base;
    }

    pub fn getThornsDamage(self: *const Guardian) f32 {
        return if (self.spikes_out) 2.0 else 0.0;
    }

    pub fn getDrops(self: *const Guardian, rng: u32) struct { shards: u8, crystals: u8, cod: u8 } {
        _ = self;
        return .{
            .shards = @intCast(rng % 3),
            .crystals = @intCast((rng / 3) % 2),
            .cod = if (rng % 3 == 0) 1 else 0,
        };
    }
};

test "dolphin grace" {
    var d = Dolphin{ .x = 0, .y = 0, .z = 0 };
    try std.testing.expect(d.grantDolphinsGrace(5.0));
    try std.testing.expect(!d.grantDolphinsGrace(15.0));
}

test "guardian laser charging" {
    var g = Guardian.init(0, 0, 0, false);
    _ = g.update(0.0, 5, 0, 0);
    try std.testing.expectEqual(GuardianState.targeting, g.state);
}

test "squid suffocates" {
    var s = Squid{ .x = 0, .y = 0, .z = 0 };
    for (0..16) |_| s.update(1.0, false);
    try std.testing.expect(s.hp < 10.0);
}
