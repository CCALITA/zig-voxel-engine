/// Copper and special block systems: oxidation, waxing, lightning rods,
/// amethyst growth, and sculk vibration detection. Only uses `std`.
const std = @import("std");

// ---------------------------------------------------------------------------
// Copper Oxidation
// ---------------------------------------------------------------------------

pub const OxidationStage = enum(u2) {
    normal = 0,
    exposed = 1,
    weathered = 2,
    oxidized = 3,

    /// Return the next oxidation stage, or null if already fully oxidized.
    pub fn next(self: OxidationStage) ?OxidationStage {
        return switch (self) {
            .normal => .exposed,
            .exposed => .weathered,
            .weathered => .oxidized,
            .oxidized => null,
        };
    }

    /// Return the previous oxidation stage, or null if already normal.
    pub fn prev(self: OxidationStage) ?OxidationStage {
        return switch (self) {
            .normal => null,
            .exposed => .normal,
            .weathered => .exposed,
            .oxidized => .weathered,
        };
    }
};

pub const CopperBlock = struct {
    stage: OxidationStage = .normal,
    waxed: bool = false,

    /// Attempt to advance oxidation by one stage.
    /// In Minecraft, copper has roughly a 1/1200 chance of advancing per
    /// random tick.  Returns a new CopperBlock when the stage advanced, or null.
    pub fn tickOxidation(self: *const CopperBlock, rng: *std.Random.DefaultPrng) ?CopperBlock {
        if (self.waxed) return null;
        const next_stage = self.stage.next() orelse return null;

        // ~1/1200 chance per random tick
        const roll = rng.random().intRangeAtMost(u32, 0, 1199);
        if (roll != 0) return null;

        return .{ .stage = next_stage, .waxed = false };
    }

    /// Apply wax to prevent further oxidation.
    pub fn wax(self: CopperBlock) CopperBlock {
        return .{ .stage = self.stage, .waxed = true };
    }

    /// Scrape one oxidation stage off (e.g. with an axe).
    /// Also removes wax if waxed.
    pub fn scrape(self: CopperBlock) CopperBlock {
        if (self.waxed) {
            return .{ .stage = self.stage, .waxed = false };
        }
        const prev_stage = self.stage.prev() orelse return self;
        return .{ .stage = prev_stage, .waxed = false };
    }
};

// ---------------------------------------------------------------------------
// Lightning Rod
// ---------------------------------------------------------------------------

pub const LightningRod = struct {
    /// Maximum distance (in blocks) at which a rod attracts lightning.
    pub const attraction_range: u32 = 64;
    /// Duration of the redstone signal after a strike (game ticks).
    pub const signal_duration: u32 = 8;

    charge_ticks_remaining: u32 = 0,

    /// Whether the rod is currently emitting a redstone signal.
    pub fn isCharged(self: *const LightningRod) bool {
        return self.charge_ticks_remaining > 0;
    }

    /// Record a lightning strike on this rod.
    pub fn strike(_: LightningRod) LightningRod {
        return .{ .charge_ticks_remaining = signal_duration };
    }

    /// Advance the rod by `dt` game ticks.
    pub fn update(self: LightningRod, dt: u32) LightningRod {
        if (self.charge_ticks_remaining == 0) return self;
        return .{
            .charge_ticks_remaining = if (dt >= self.charge_ticks_remaining) 0 else self.charge_ticks_remaining - dt,
        };
    }
};

// ---------------------------------------------------------------------------
// Amethyst Cluster
// ---------------------------------------------------------------------------

pub const GrowthStage = enum(u2) {
    small_bud = 0,
    medium_bud = 1,
    large_bud = 2,
    cluster = 3,

    pub fn next(self: GrowthStage) ?GrowthStage {
        return switch (self) {
            .small_bud => .medium_bud,
            .medium_bud => .large_bud,
            .large_bud => .cluster,
            .cluster => null,
        };
    }
};

pub const AmethystCluster = struct {
    growth_stage: GrowthStage = .small_bud,

    /// Attempt to advance the growth stage (called on random tick).
    /// Returns a new cluster if growth occurred, or null if not.
    pub fn tickGrowth(self: *const AmethystCluster, rng: *std.Random.DefaultPrng) ?AmethystCluster {
        const next_stage = self.growth_stage.next() orelse return null;
        // ~1/5 chance per random tick (Minecraft wiki approximation)
        const roll = rng.random().intRangeAtMost(u32, 0, 4);
        if (roll != 0) return null;
        return .{ .growth_stage = next_stage };
    }
};

pub const BuddingAmethyst = struct {
    /// A budding amethyst can only grow a bud on a face if that
    /// adjacent block is air.  `has_air` is indexed the same as
    /// a 6-element face array (north, south, east, west, top, bottom).
    pub fn canGrow(has_air: [6]bool, face: u3) bool {
        if (face >= 6) return false;
        return has_air[face];
    }
};

// ---------------------------------------------------------------------------
// Sculk Sensor
// ---------------------------------------------------------------------------

pub const SculkSensor = struct {
    /// Detection range in blocks.
    pub const detection_range: u32 = 8;
    /// Cooldown duration in game ticks after a detection.
    pub const cooldown_ticks: u32 = 40;
    /// Precomputed squared detection range.
    const range_sq: u32 = detection_range * detection_range;

    cooldown_remaining: u32 = 0,

    /// Whether the sensor is actively emitting a signal.
    pub fn isActive(self: SculkSensor) bool {
        return self.cooldown_remaining > 0;
    }

    /// Try to detect a vibration at the given squared distance.
    /// Returns a new SculkSensor if it detected (started cooldown), or null.
    pub fn detectVibration(self: *const SculkSensor, dist_sq: u32) ?SculkSensor {
        if (self.cooldown_remaining > 0) return null;
        if (dist_sq > range_sq) return null;
        return .{ .cooldown_remaining = cooldown_ticks };
    }

    /// Advance the sensor by `dt` game ticks.
    /// Returns a new SculkSensor with updated cooldown.
    pub fn update(self: SculkSensor, dt: u32) SculkSensor {
        if (self.cooldown_remaining == 0) return self;
        const remaining = if (dt >= self.cooldown_remaining) 0 else self.cooldown_remaining - dt;
        return .{ .cooldown_remaining = remaining };
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "oxidation stage progression" {
    try std.testing.expectEqual(OxidationStage.exposed, OxidationStage.normal.next().?);
    try std.testing.expectEqual(OxidationStage.weathered, OxidationStage.exposed.next().?);
    try std.testing.expectEqual(OxidationStage.oxidized, OxidationStage.weathered.next().?);
    try std.testing.expectEqual(@as(?OxidationStage, null), OxidationStage.oxidized.next());
}

test "oxidation stage regression" {
    try std.testing.expectEqual(@as(?OxidationStage, null), OxidationStage.normal.prev());
    try std.testing.expectEqual(OxidationStage.normal, OxidationStage.exposed.prev().?);
    try std.testing.expectEqual(OxidationStage.exposed, OxidationStage.weathered.prev().?);
    try std.testing.expectEqual(OxidationStage.weathered, OxidationStage.oxidized.prev().?);
}

test "copper block tickOxidation can advance stage" {
    // Use a seed that eventually produces a 0 roll
    var rng = std.Random.DefaultPrng.init(42);
    const block = CopperBlock{ .stage = .normal, .waxed = false };

    var advanced = false;
    var i: u32 = 0;
    while (i < 10000) : (i += 1) {
        if (block.tickOxidation(&rng)) |new_block| {
            try std.testing.expectEqual(OxidationStage.exposed, new_block.stage);
            advanced = true;
            break;
        }
    }
    try std.testing.expect(advanced);
}

test "waxed copper does not oxidize" {
    var rng = std.Random.DefaultPrng.init(0);
    const block = CopperBlock{ .stage = .normal, .waxed = true };

    var i: u32 = 0;
    while (i < 5000) : (i += 1) {
        const result = block.tickOxidation(&rng);
        try std.testing.expectEqual(@as(?CopperBlock, null), result);
    }
}

test "wax and scrape" {
    const normal = CopperBlock{ .stage = .exposed, .waxed = false };
    const waxed = normal.wax();
    try std.testing.expect(waxed.waxed);
    try std.testing.expectEqual(OxidationStage.exposed, waxed.stage);

    // Scraping a waxed block removes wax but keeps stage
    const unwaxed = waxed.scrape();
    try std.testing.expect(!unwaxed.waxed);
    try std.testing.expectEqual(OxidationStage.exposed, unwaxed.stage);

    // Scraping an unwaxed block reverses one stage
    const scraped = unwaxed.scrape();
    try std.testing.expectEqual(OxidationStage.normal, scraped.stage);
}

test "scrape at normal stage is no-op" {
    const block = CopperBlock{ .stage = .normal, .waxed = false };
    const scraped = block.scrape();
    try std.testing.expectEqual(OxidationStage.normal, scraped.stage);
    try std.testing.expect(!scraped.waxed);
}

test "fully oxidized copper does not advance" {
    var rng = std.Random.DefaultPrng.init(99);
    const block = CopperBlock{ .stage = .oxidized, .waxed = false };

    var i: u32 = 0;
    while (i < 3000) : (i += 1) {
        const result = block.tickOxidation(&rng);
        try std.testing.expectEqual(@as(?CopperBlock, null), result);
    }
}

test "lightning rod starts uncharged" {
    const rod = LightningRod{};
    try std.testing.expect(!rod.isCharged());
}

test "lightning rod charges on strike" {
    const rod = (LightningRod{}).strike();
    try std.testing.expect(rod.isCharged());
    try std.testing.expectEqual(@as(u32, 8), rod.charge_ticks_remaining);
}

test "lightning rod discharges over time" {
    var rod = (LightningRod{}).strike();
    try std.testing.expect(rod.isCharged());

    rod = rod.update(4);
    try std.testing.expect(rod.isCharged());
    try std.testing.expectEqual(@as(u32, 4), rod.charge_ticks_remaining);

    rod = rod.update(4);
    try std.testing.expect(!rod.isCharged());
}

test "lightning rod update clamps to zero" {
    const rod = (LightningRod{}).strike();
    const updated = rod.update(100);
    try std.testing.expect(!updated.isCharged());
    try std.testing.expectEqual(@as(u32, 0), updated.charge_ticks_remaining);
}

test "amethyst cluster growth stages" {
    try std.testing.expectEqual(GrowthStage.medium_bud, GrowthStage.small_bud.next().?);
    try std.testing.expectEqual(GrowthStage.large_bud, GrowthStage.medium_bud.next().?);
    try std.testing.expectEqual(GrowthStage.cluster, GrowthStage.large_bud.next().?);
    try std.testing.expectEqual(@as(?GrowthStage, null), GrowthStage.cluster.next());
}

test "amethyst cluster can grow" {
    var rng = std.Random.DefaultPrng.init(42);
    const cluster = AmethystCluster{ .growth_stage = .small_bud };

    var grew = false;
    var i: u32 = 0;
    while (i < 1000) : (i += 1) {
        if (cluster.tickGrowth(&rng)) |new_cluster| {
            try std.testing.expectEqual(GrowthStage.medium_bud, new_cluster.growth_stage);
            grew = true;
            break;
        }
    }
    try std.testing.expect(grew);
}

test "fully grown amethyst cluster does not grow" {
    var rng = std.Random.DefaultPrng.init(0);
    const cluster = AmethystCluster{ .growth_stage = .cluster };

    var i: u32 = 0;
    while (i < 500) : (i += 1) {
        const result = cluster.tickGrowth(&rng);
        try std.testing.expectEqual(@as(?AmethystCluster, null), result);
    }
}

test "budding amethyst canGrow checks air" {
    const faces_with_air = [6]bool{ true, false, true, false, true, false };
    try std.testing.expect(BuddingAmethyst.canGrow(faces_with_air, 0)); // north = air
    try std.testing.expect(!BuddingAmethyst.canGrow(faces_with_air, 1)); // south = blocked
    try std.testing.expect(BuddingAmethyst.canGrow(faces_with_air, 4)); // top = air
    try std.testing.expect(!BuddingAmethyst.canGrow(faces_with_air, 5)); // bottom = blocked
}

test "budding amethyst rejects invalid face" {
    const all_air = [6]bool{ true, true, true, true, true, true };
    try std.testing.expect(!BuddingAmethyst.canGrow(all_air, 6));
    try std.testing.expect(!BuddingAmethyst.canGrow(all_air, 7));
}

test "sculk sensor detects vibration in range" {
    const sensor = SculkSensor{};
    // Distance of 5 blocks => dist_sq = 25, within range_sq = 64
    const result = sensor.detectVibration(25);
    try std.testing.expect(result != null);
    try std.testing.expect(result.?.isActive());
    try std.testing.expectEqual(@as(u32, 40), result.?.cooldown_remaining);
}

test "sculk sensor ignores vibration outside range" {
    const sensor = SculkSensor{};
    // Distance > 8 blocks => dist_sq = 100
    const result = sensor.detectVibration(100);
    try std.testing.expectEqual(@as(?SculkSensor, null), result);
}

test "sculk sensor ignores vibration at boundary" {
    const sensor = SculkSensor{};
    // Exactly at range: 8*8 = 64
    const at_boundary = sensor.detectVibration(64);
    try std.testing.expect(at_boundary != null);

    // Just past range
    const past_boundary = sensor.detectVibration(65);
    try std.testing.expectEqual(@as(?SculkSensor, null), past_boundary);
}

test "sculk sensor cooldown prevents re-detection" {
    const sensor = SculkSensor{};
    const detected = sensor.detectVibration(10).?;
    // During cooldown, further vibrations are ignored
    const re_detect = detected.detectVibration(10);
    try std.testing.expectEqual(@as(?SculkSensor, null), re_detect);
}

test "sculk sensor update ticks down cooldown" {
    var sensor = (SculkSensor{}).detectVibration(10).?;
    try std.testing.expect(sensor.isActive());

    sensor = sensor.update(20);
    try std.testing.expect(sensor.isActive());
    try std.testing.expectEqual(@as(u32, 20), sensor.cooldown_remaining);

    sensor = sensor.update(20);
    try std.testing.expect(!sensor.isActive());
    try std.testing.expectEqual(@as(u32, 0), sensor.cooldown_remaining);
}

test "sculk sensor can detect again after cooldown" {
    var sensor = (SculkSensor{}).detectVibration(10).?;
    sensor = sensor.update(40); // cooldown expires
    try std.testing.expect(!sensor.isActive());

    const re_detect = sensor.detectVibration(10);
    try std.testing.expect(re_detect != null);
    try std.testing.expect(re_detect.?.isActive());
}
