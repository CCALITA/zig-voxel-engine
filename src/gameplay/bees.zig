const std = @import("std");

pub const Coord = struct {
    x: i32,
    y: i32,
    z: i32,
};

pub const HarvestResult = struct {
    honey_bottles: u8,
    bees_angered: bool,
};

pub const StingResult = struct {
    damage: f32,
    bee_died: bool,
    poison_seconds: f32,
};

pub const BeehiveState = struct {
    bee_count: u2 = 0,
    honey_level: u3 = 0,
    smoked: bool = false,
    smoke_timer: f32 = 0.0,
    /// Seconds of bee-presence accumulated toward the next honey level.
    production_accumulator: f32 = 0.0,

    const max_bees: u2 = 3;
    const max_honey: u3 = 5;
    const smoke_duration: f32 = 300.0; // 5 minutes
    const seconds_per_honey: f32 = 120.0; // 2 min per level (with ≥1 bee)

    /// Try to add a bee. Returns true on success, false if hive is full.
    pub fn addBee(self: *BeehiveState) bool {
        if (self.bee_count >= max_bees) return false;
        self.bee_count +|= 1;
        return true;
    }

    /// Try to remove a bee. Returns true on success, false if hive is empty.
    pub fn removeBee(self: *BeehiveState) bool {
        if (self.bee_count == 0) return false;
        self.bee_count -|= 1;
        return true;
    }

    /// Harvest honey (requires a bottle). Returns null when honey_level < 5.
    /// If the hive is not smoked the bees become angry (caller must handle).
    pub fn harvestHoney(self: *BeehiveState) ?HarvestResult {
        if (!self.isReadyToHarvest()) return null;

        const angered = !self.smoked;
        self.resetHarvest();

        return HarvestResult{
            .honey_bottles = 3,
            .bees_angered = angered,
        };
    }

    /// Harvest honeycomb (requires shears). Returns null when honey_level < 5.
    pub fn harvestComb(self: *BeehiveState) ?u8 {
        if (!self.isReadyToHarvest()) return null;
        self.resetHarvest();
        return 3;
    }

    fn isReadyToHarvest(self: *const BeehiveState) bool {
        return self.honey_level >= max_honey;
    }

    fn resetHarvest(self: *BeehiveState) void {
        self.honey_level = 0;
        self.production_accumulator = 0.0;
    }

    /// Smoke the hive (e.g. campfire below). Bees stay calm for 5 minutes.
    pub fn smoke(self: *BeehiveState) void {
        self.smoked = true;
        self.smoke_timer = smoke_duration;
    }

    /// Advance time. Honey production increases while bees are present.
    pub fn tickProduction(self: *BeehiveState, dt: f32) void {
        // Tick smoke timer
        if (self.smoked) {
            self.smoke_timer -= dt;
            if (self.smoke_timer <= 0.0) {
                self.smoked = false;
                self.smoke_timer = 0.0;
            }
        }

        // Produce honey only when bees are inside and honey is not full
        if (self.bee_count == 0 or self.honey_level >= max_honey) return;

        const bee_factor: f32 = @floatFromInt(self.bee_count);
        self.production_accumulator += dt * bee_factor;

        while (self.production_accumulator >= seconds_per_honey) {
            self.production_accumulator -= seconds_per_honey;
            if (self.honey_level < max_honey) {
                self.honey_level +|= 1;
            }
            if (self.honey_level >= max_honey) {
                self.production_accumulator = 0.0;
                break;
            }
        }
    }
};

pub const BeeState = struct {
    has_pollen: bool = false,
    angry: bool = false,
    anger_timer: f32 = 0.0,
    hive_pos: ?Coord = null,

    const anger_duration: f32 = 30.0; // seconds

    /// Mark the bee as carrying pollen (visited a flower).
    pub fn pollinate(self: *BeeState) void {
        self.has_pollen = true;
    }

    /// Sting a target. The bee dies after stinging (returns result).
    pub fn sting(self: *BeeState) StingResult {
        const result = StingResult{
            .damage = 2.0,
            .bee_died = true,
            .poison_seconds = if (self.angry) 18.0 else 10.0,
        };
        self.has_pollen = false;
        self.angry = false;
        self.anger_timer = 0.0;
        return result;
    }

    /// Make the bee angry for the default duration.
    pub fn enrage(self: *BeeState) void {
        self.angry = true;
        self.anger_timer = anger_duration;
    }

    /// Tick anger timer. Anger fades when timer expires.
    pub fn tickAnger(self: *BeeState, dt: f32) void {
        if (!self.angry) return;
        self.anger_timer -= dt;
        if (self.anger_timer <= 0.0) {
            self.angry = false;
            self.anger_timer = 0.0;
        }
    }
};

test "honey production over time" {
    var hive = BeehiveState{};
    _ = hive.addBee();
    _ = hive.addBee();

    // 2 bees × 120 s / bee = 60 s real-time per honey level
    // After 300 s → 5 levels
    hive.tickProduction(300.0);
    try std.testing.expectEqual(@as(u3, 5), hive.honey_level);
}

test "honey production stops at max" {
    var hive = BeehiveState{};
    _ = hive.addBee();

    // Way more time than needed
    hive.tickProduction(99999.0);
    try std.testing.expectEqual(@as(u3, 5), hive.honey_level);
}

test "no production without bees" {
    var hive = BeehiveState{};
    hive.tickProduction(99999.0);
    try std.testing.expectEqual(@as(u3, 0), hive.honey_level);
}

test "harvest honey when full" {
    var hive = BeehiveState{};
    hive.honey_level = 5;
    _ = hive.addBee();

    const result = hive.harvestHoney();
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(u8, 3), result.?.honey_bottles);
    try std.testing.expect(result.?.bees_angered); // not smoked
    try std.testing.expectEqual(@as(u3, 0), hive.honey_level);
}

test "harvest honey returns null when not full" {
    var hive = BeehiveState{};
    hive.honey_level = 4;
    try std.testing.expect(hive.harvestHoney() == null);
}

test "harvest comb returns 3 honeycombs" {
    var hive = BeehiveState{};
    hive.honey_level = 5;
    const combs = hive.harvestComb();
    try std.testing.expect(combs != null);
    try std.testing.expectEqual(@as(u8, 3), combs.?);
    try std.testing.expectEqual(@as(u3, 0), hive.honey_level);
}

test "smoke calms bees during harvest" {
    var hive = BeehiveState{};
    hive.honey_level = 5;
    _ = hive.addBee();
    hive.smoke();

    const result = hive.harvestHoney();
    try std.testing.expect(result != null);
    try std.testing.expect(!result.?.bees_angered);
}

test "smoke expires after 5 minutes" {
    var hive = BeehiveState{};
    hive.smoke();
    try std.testing.expect(hive.smoked);

    hive.tickProduction(301.0);
    try std.testing.expect(!hive.smoked);
}

test "bee add and remove limits" {
    var hive = BeehiveState{};
    try std.testing.expect(hive.addBee());
    try std.testing.expect(hive.addBee());
    try std.testing.expect(hive.addBee());
    try std.testing.expect(!hive.addBee()); // full

    try std.testing.expect(hive.removeBee());
    try std.testing.expect(hive.removeBee());
    try std.testing.expect(hive.removeBee());
    try std.testing.expect(!hive.removeBee()); // empty
}

test "sting kills the bee" {
    var bee = BeeState{};
    bee.enrage();
    bee.has_pollen = true;

    const result = bee.sting();
    try std.testing.expect(result.bee_died);
    try std.testing.expectEqual(@as(f32, 2.0), result.damage);
    try std.testing.expectEqual(@as(f32, 18.0), result.poison_seconds); // angry → 18s
    // Bee state reset after death
    try std.testing.expect(!bee.angry);
    try std.testing.expect(!bee.has_pollen);
}

test "sting poison shorter when not angry" {
    var bee = BeeState{};
    const result = bee.sting();
    try std.testing.expectEqual(@as(f32, 10.0), result.poison_seconds);
}

test "pollinate sets pollen flag" {
    var bee = BeeState{};
    try std.testing.expect(!bee.has_pollen);
    bee.pollinate();
    try std.testing.expect(bee.has_pollen);
}

test "anger fades over time" {
    var bee = BeeState{};
    bee.enrage();
    try std.testing.expect(bee.angry);

    bee.tickAnger(31.0);
    try std.testing.expect(!bee.angry);
}
