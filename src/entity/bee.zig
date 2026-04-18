const std = @import("std");

pub const BeeState = enum {
    idle,
    fly_to_flower,
    pollinate,
    return_to_hive,
    attack,
};

pub const StingResult = struct {
    damage: f32,
    poison_duration: f32,
    bee_died: bool,
};

pub const BeeEntity = struct {
    x: f32,
    y: f32,
    z: f32,
    health: f32 = 10,
    has_pollen: bool = false,
    angry: bool = false,
    anger_timer: f32 = 0,
    hive_x: ?i32 = null,
    hive_y: ?i32 = null,
    hive_z: ?i32 = null,
    target_flower_x: ?i32 = null,
    target_flower_y: ?i32 = null,
    target_flower_z: ?i32 = null,
    state: BeeState = .idle,

    pub fn update(self: *BeeEntity, dt: f32, player_x: f32, player_y: f32, player_z: f32) void {
        if (self.angry and self.anger_timer > 0) {
            self.anger_timer -= dt;
            if (self.anger_timer <= 0) {
                self.anger_timer = 0;
                self.angry = false;
                if (self.state == .attack) {
                    self.state = .idle;
                    return;
                }
            }
        }

        switch (self.state) {
            .idle => {
                if (self.angry) {
                    self.state = .attack;
                } else if (!self.has_pollen and self.target_flower_x != null) {
                    self.state = .fly_to_flower;
                } else if (self.has_pollen and self.hive_x != null) {
                    self.state = .return_to_hive;
                }
            },
            .fly_to_flower => {
                if (self.angry) {
                    self.state = .attack;
                } else if (self.target_flower_x) |fx| {
                    const fy = self.target_flower_y orelse return;
                    const fz = self.target_flower_z orelse return;
                    const dist = self.distanceTo(@floatFromInt(fx), @floatFromInt(fy), @floatFromInt(fz));
                    if (dist < arrival_distance) {
                        self.state = .pollinate;
                    } else {
                        moveToward(self, @floatFromInt(fx), @floatFromInt(fy), @floatFromInt(fz), dt);
                    }
                } else {
                    self.state = .idle;
                }
            },
            .pollinate => {
                if (self.angry) {
                    self.state = .attack;
                } else {
                    self.has_pollen = true;
                    self.target_flower_x = null;
                    self.target_flower_y = null;
                    self.target_flower_z = null;
                    if (self.hive_x != null) {
                        self.state = .return_to_hive;
                    } else {
                        self.state = .idle;
                    }
                }
            },
            .return_to_hive => {
                if (self.angry) {
                    self.state = .attack;
                } else if (self.hive_x) |hx| {
                    const hy = self.hive_y orelse return;
                    const hz = self.hive_z orelse return;
                    const dist = self.distanceTo(@floatFromInt(hx), @floatFromInt(hy), @floatFromInt(hz));
                    if (dist < arrival_distance) {
                        self.has_pollen = false;
                        self.state = .idle;
                    } else {
                        moveToward(self, @floatFromInt(hx), @floatFromInt(hy), @floatFromInt(hz), dt);
                    }
                } else {
                    self.state = .idle;
                }
            },
            .attack => {
                if (!self.angry) {
                    self.state = .idle;
                } else {
                    moveToward(self, player_x, player_y, player_z, dt);
                }
            },
        }
    }

    pub fn sting(self: *BeeEntity) StingResult {
        self.health = 0;
        return StingResult{
            .damage = 1,
            .poison_duration = 10,
            .bee_died = true,
        };
    }

    pub fn provoke(self: *BeeEntity) void {
        self.angry = true;
        self.anger_timer = 25;
    }

    pub fn canPollinate(self: BeeEntity) bool {
        return !self.has_pollen and self.state != .attack and !self.angry;
    }

    pub fn distanceTo(self: BeeEntity, tx: f32, ty: f32, tz: f32) f32 {
        const dx = self.x - tx;
        const dy = self.y - ty;
        const dz = self.z - tz;
        return @sqrt(dx * dx + dy * dy + dz * dz);
    }
};

const fly_speed: f32 = 4.0;
const arrival_distance: f32 = 1.5;

fn moveToward(bee: *BeeEntity, tx: f32, ty: f32, tz: f32, dt: f32) void {
    const dx = tx - bee.x;
    const dy = ty - bee.y;
    const dz = tz - bee.z;
    const dist = @sqrt(dx * dx + dy * dy + dz * dz);
    if (dist < 0.01) return;
    const step = fly_speed * dt;
    const ratio = if (step > dist) 1.0 else step / dist;
    bee.x += dx * ratio;
    bee.y += dy * ratio;
    bee.z += dz * ratio;
}

test "provoke sets angry and timer" {
    var bee = BeeEntity{ .x = 0, .y = 0, .z = 0 };
    try std.testing.expect(!bee.angry);
    try std.testing.expectEqual(@as(f32, 0), bee.anger_timer);

    bee.provoke();

    try std.testing.expect(bee.angry);
    try std.testing.expectEqual(@as(f32, 25), bee.anger_timer);
}

test "sting kills bee and returns result" {
    var bee = BeeEntity{ .x = 0, .y = 0, .z = 0 };
    try std.testing.expectEqual(@as(f32, 10), bee.health);

    const result = bee.sting();

    try std.testing.expectEqual(@as(f32, 0), bee.health);
    try std.testing.expectEqual(@as(f32, 1), result.damage);
    try std.testing.expectEqual(@as(f32, 10), result.poison_duration);
    try std.testing.expect(result.bee_died);
}

test "pollinate cycle: fly_to_flower -> pollinate -> return_to_hive -> idle" {
    var bee = BeeEntity{
        .x = 0,
        .y = 0,
        .z = 0,
        .target_flower_x = 1,
        .target_flower_y = 0,
        .target_flower_z = 0,
        .hive_x = -1,
        .hive_y = 0,
        .hive_z = 0,
    };

    // idle -> fly_to_flower
    bee.update(0.016, 100, 100, 100);
    try std.testing.expectEqual(BeeState.fly_to_flower, bee.state);

    // Move bee close to flower
    bee.x = 0.9;
    bee.update(0.016, 100, 100, 100);
    // Should transition to pollinate since within 1.5
    try std.testing.expectEqual(BeeState.pollinate, bee.state);

    // pollinate -> return_to_hive (has hive)
    bee.update(0.016, 100, 100, 100);
    try std.testing.expectEqual(BeeState.return_to_hive, bee.state);
    try std.testing.expect(bee.has_pollen);

    // Move bee close to hive
    bee.x = -0.9;
    bee.update(0.016, 100, 100, 100);
    // Should deposit pollen and go idle
    try std.testing.expectEqual(BeeState.idle, bee.state);
    try std.testing.expect(!bee.has_pollen);
}

test "state transitions: provoke interrupts to attack, anger expiry returns to idle" {
    var bee = BeeEntity{
        .x = 0,
        .y = 0,
        .z = 0,
        .target_flower_x = 10,
        .target_flower_y = 0,
        .target_flower_z = 0,
    };

    // Start flying to flower
    bee.update(0.016, 50, 0, 0);
    try std.testing.expectEqual(BeeState.fly_to_flower, bee.state);

    // Provoke mid-flight
    bee.provoke();
    bee.update(0.016, 50, 0, 0);
    try std.testing.expectEqual(BeeState.attack, bee.state);
    try std.testing.expect(bee.angry);

    // Expire anger timer
    bee.anger_timer = 0.01;
    bee.update(0.02, 50, 0, 0);
    try std.testing.expect(!bee.angry);
    try std.testing.expectEqual(BeeState.idle, bee.state);
}

test "canPollinate returns correct values" {
    var bee = BeeEntity{ .x = 0, .y = 0, .z = 0 };
    try std.testing.expect(bee.canPollinate());

    bee.has_pollen = true;
    try std.testing.expect(!bee.canPollinate());

    bee.has_pollen = false;
    bee.angry = true;
    try std.testing.expect(!bee.canPollinate());

    bee.angry = false;
    bee.state = .attack;
    try std.testing.expect(!bee.canPollinate());
}

test "distanceTo calculates correctly" {
    const bee = BeeEntity{ .x = 0, .y = 0, .z = 0 };
    const dist = bee.distanceTo(3, 4, 0);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), dist, 0.001);
}
