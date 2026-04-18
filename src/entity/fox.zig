const std = @import("std");

pub const FoxVariant = enum {
    red,
    snow,
};

pub const FoxState = enum {
    idle,
    sleep,
    hunt,
    flee,
    eat,
};

const max_health: f32 = 10;
const sleep_threshold: f32 = 100;
const flee_trigger_dist: f32 = 8;
const flee_safe_dist: f32 = 16;
const flee_speed: f32 = 4;
const hunt_speed: f32 = 2;
const feed_heal_amount: f32 = 2;

pub const FoxEntity = struct {
    x: f32,
    y: f32,
    z: f32,
    health: f32 = max_health,
    variant: FoxVariant,
    held_item: ?u16 = null,
    trusts_player: bool = false,
    sleep_timer: f32 = 0,
    state: FoxState = .idle,

    pub fn update(self: *FoxEntity, dt: f32, is_night: bool, player_dist: f32) void {
        switch (self.state) {
            .sleep => {
                if (is_night) {
                    self.sleep_timer = 0;
                    self.state = .idle;
                } else {
                    self.sleep_timer += dt;
                }
            },
            .idle => {
                if (!is_night and self.sleep_timer < sleep_threshold) {
                    self.sleep_timer += dt;
                    if (self.sleep_timer >= sleep_threshold) {
                        self.state = .sleep;
                    }
                }
                if (player_dist < flee_trigger_dist and !self.trusts_player) {
                    self.state = .flee;
                }
            },
            .flee => {
                if (player_dist >= flee_safe_dist or self.trusts_player) {
                    self.state = .idle;
                } else {
                    self.x += dt * flee_speed;
                }
            },
            .hunt => {
                self.x += dt * hunt_speed;
            },
            .eat => {
                if (self.held_item == null) {
                    self.state = .idle;
                }
            },
        }
    }

    pub fn pickUpItem(self: *FoxEntity, item_id: u16) void {
        if (self.held_item == null) {
            self.held_item = item_id;
            self.state = .eat;
        }
    }

    pub fn dropItem(self: *FoxEntity) ?u16 {
        const item = self.held_item;
        self.held_item = null;
        if (self.state == .eat) {
            self.state = .idle;
        }
        return item;
    }

    pub fn feed(self: *FoxEntity, sweet_berry: bool) void {
        if (sweet_berry) {
            self.trusts_player = true;
            self.health = @min(self.health + feed_heal_amount, max_health);
        }
    }

    pub fn isSleeping(self: FoxEntity) bool {
        return self.state == .sleep;
    }
};

fn makeFox(variant: FoxVariant) FoxEntity {
    return .{ .x = 0, .y = 0, .z = 0, .variant = variant };
}

test "fox picks up items" {
    var fox = makeFox(.red);
    try std.testing.expect(fox.held_item == null);

    fox.pickUpItem(42);
    try std.testing.expectEqual(@as(u16, 42), fox.held_item.?);
    try std.testing.expectEqual(FoxState.eat, fox.state);
}

test "fox sleeps during day" {
    var fox = makeFox(.snow);
    try std.testing.expect(!fox.isSleeping());

    // Simulate daytime updates until sleep_timer reaches threshold
    var i: u32 = 0;
    while (i < 200) : (i += 1) {
        fox.update(1.0, false, 100);
    }
    try std.testing.expect(fox.isSleeping());
}

test "fox trusts player after feeding sweet berries" {
    var fox = makeFox(.red);
    try std.testing.expect(!fox.trusts_player);

    fox.feed(true);
    try std.testing.expect(fox.trusts_player);
}

test "fox drops item on damage" {
    var fox = makeFox(.red);
    fox.pickUpItem(7);
    try std.testing.expectEqual(@as(u16, 7), fox.held_item.?);

    // Simulate damage causing item drop
    const dropped = fox.dropItem();
    try std.testing.expectEqual(@as(u16, 7), dropped.?);
    try std.testing.expect(fox.held_item == null);
    try std.testing.expectEqual(FoxState.idle, fox.state);
}

test "fox feeding without sweet berries does not build trust" {
    var fox = makeFox(.red);
    fox.feed(false);
    try std.testing.expect(!fox.trusts_player);
}

test "fox wakes up at night" {
    var fox = makeFox(.snow);
    // Put fox to sleep during day
    var i: u32 = 0;
    while (i < 200) : (i += 1) {
        fox.update(1.0, false, 100);
    }
    try std.testing.expect(fox.isSleeping());

    // Night arrives
    fox.update(1.0, true, 100);
    try std.testing.expect(!fox.isSleeping());
}
