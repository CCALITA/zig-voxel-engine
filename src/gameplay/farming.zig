/// Crop farming system.
/// Supports planting, growth via random ticks, bone meal, hydration checks,
/// and harvest drops. Growth follows Minecraft-style random-tick mechanics:
/// each crop has a 1/3 chance to advance one stage per tick (~68 s interval).
/// Hydrated farmland (water within 4 blocks) doubles the tick rate.

const std = @import("std");

pub const CropType = enum { wheat, carrot, potato, beetroot };
pub const MAX_GROWTH: u8 = 7;

const TICK_INTERVAL: f32 = 68.0;
const HYDRATED_TICK_INTERVAL: f32 = TICK_INTERVAL / 2.0;
const GROWTH_CHANCE_NUM: u32 = 1;
const GROWTH_CHANCE_DEN: u32 = 3;

/// Build a deterministic seed from a crop's position and growth stage.
fn cropSeed(x: i32, y: i32, z: i32, growth: u8) u64 {
    return @bitCast([2]u32{
        @bitCast([_]u8{
            @truncate(@as(u32, @bitCast(x))),
            @truncate(@as(u32, @bitCast(y))),
            @truncate(@as(u32, @bitCast(z))),
            growth,
        }),
        @truncate(@as(u32, @bitCast(x)) +% @as(u32, @bitCast(y)) +% @as(u32, @bitCast(z)) +% growth),
    });
}

pub const CropState = struct {
    crop_type: CropType,
    growth: u8,
    x: i32,
    y: i32,
    z: i32,

    pub fn init(crop_type: CropType, x: i32, y: i32, z: i32) CropState {
        return .{
            .crop_type = crop_type,
            .growth = 0,
            .x = x,
            .y = y,
            .z = z,
        };
    }

    /// Attempt to grow one stage. Returns true if the crop advanced.
    pub fn grow(self: *CropState) bool {
        if (self.growth >= MAX_GROWTH) return false;
        self.growth += 1;
        return true;
    }

    pub fn isFullyGrown(self: *const CropState) bool {
        return self.growth >= MAX_GROWTH;
    }

    /// Apply bone meal: instantly advance 2-5 growth stages (capped at MAX_GROWTH).
    pub fn applyBoneMeal(self: *CropState) void {
        var rng = std.Random.DefaultPrng.init(cropSeed(self.x, self.y, self.z, self.growth));
        const advance: u8 = @intCast(rng.random().intRangeAtMost(u8, 2, 5));
        self.growth = @min(self.growth + advance, MAX_GROWTH);
    }
};

pub const FarmManager = struct {
    crops: std.ArrayList(CropState),
    tick_timer: f32,

    pub fn init() FarmManager {
        return .{
            .crops = .empty,
            .tick_timer = 0,
        };
    }

    pub fn deinit(self: *FarmManager, allocator: std.mem.Allocator) void {
        self.crops.deinit(allocator);
    }

    pub fn plantCrop(self: *FarmManager, allocator: std.mem.Allocator, crop_type: CropType, x: i32, y: i32, z: i32) !void {
        try self.crops.append(allocator, CropState.init(crop_type, x, y, z));
    }

    /// Remove and return the crop at the given position, or null if none exists.
    pub fn removeCrop(self: *FarmManager, x: i32, y: i32, z: i32) ?CropState {
        for (self.crops.items, 0..) |crop, i| {
            if (crop.x == x and crop.y == y and crop.z == z) {
                return self.crops.orderedRemove(i);
            }
        }
        return null;
    }

    /// Advance the tick timer by `dt` seconds. Each elapsed tick gives every
    /// crop a 1/3 chance to grow. Hydrated crops (via callback) tick at 2x rate.
    pub fn update(self: *FarmManager, dt: f32) void {
        self.updateWithHydration(dt, null);
    }

    pub fn updateWithHydration(self: *FarmManager, dt: f32, hydration_fn: ?*const fn (i32, i32, i32) bool) void {
        self.tick_timer += dt;

        const interval = if (hydration_fn != null) HYDRATED_TICK_INTERVAL else TICK_INTERVAL;

        while (self.tick_timer >= interval) {
            self.tick_timer -= interval;
            self.runTick(hydration_fn);
        }
    }

    fn runTick(self: *FarmManager, hydration_fn: ?*const fn (i32, i32, i32) bool) void {
        for (self.crops.items) |*crop| {
            if (crop.growth >= MAX_GROWTH) continue;

            // When hydration callback is provided, only hydrated crops grow at the faster rate.
            // Non-hydrated crops still grow but at the normal rate; however since we call
            // runTick for every interval tick, non-hydrated crops would be ticked too often
            // with the halved interval. So we give non-hydrated crops a 50% skip to
            // approximate the normal rate when using the hydrated interval.
            if (hydration_fn) |hfn| {
                if (!hfn(crop.x, crop.y, crop.z)) {
                    // Non-hydrated: skip every other tick to approximate normal rate.
                    // Use growth + position parity as a simple deterministic toggle.
                    const parity = @as(u32, @bitCast(crop.x)) +% @as(u32, @bitCast(crop.z)) +% crop.growth;
                    if (parity % 2 == 0) continue;
                }
            }

            var rng = std.Random.DefaultPrng.init(cropSeed(crop.x, crop.y, crop.z, crop.growth));
            if (rng.random().intRangeLessThan(u32, 0, GROWTH_CHANCE_DEN) < GROWTH_CHANCE_NUM) {
                _ = crop.grow();
            }
        }
    }

    pub fn getCropAt(self: *const FarmManager, x: i32, y: i32, z: i32) ?*const CropState {
        for (self.crops.items) |*crop| {
            if (crop.x == x and crop.y == y and crop.z == z) {
                return crop;
            }
        }
        return null;
    }
};

// ---------------------------------------------------------------------------
// Free functions
// ---------------------------------------------------------------------------

/// Check whether the block at (x, y, z) is within 4 blocks of water
/// on the XZ plane at the same Y level.
pub fn isHydrated(x: i32, y: i32, z: i32, water_fn: *const fn (i32, i32, i32) bool) bool {
    const range: i32 = 4;
    var dx: i32 = -range;
    while (dx <= range) : (dx += 1) {
        var dz: i32 = -range;
        while (dz <= range) : (dz += 1) {
            if (water_fn(x + dx, y, z + dz)) return true;
        }
    }
    return false;
}

pub const CropDrops = struct {
    item: u16,
    count: u8,
};

/// Return the drop table entry for a fully-grown crop.
/// Item IDs start at 512 to avoid collision with block IDs.
pub fn getDrops(crop_type: CropType) CropDrops {
    return switch (crop_type) {
        .wheat => .{ .item = 512, .count = 1 },
        .carrot => .{ .item = 513, .count = 3 },
        .potato => .{ .item = 514, .count = 3 },
        .beetroot => .{ .item = 515, .count = 1 },
    };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "CropState.init starts at growth 0" {
    const crop = CropState.init(.wheat, 1, 2, 3);
    try std.testing.expectEqual(@as(u8, 0), crop.growth);
    try std.testing.expectEqual(CropType.wheat, crop.crop_type);
}

test "CropState.grow advances growth" {
    var crop = CropState.init(.carrot, 0, 0, 0);
    try std.testing.expect(crop.grow());
    try std.testing.expectEqual(@as(u8, 1), crop.growth);
}

test "CropState.grow returns false at max" {
    var crop = CropState.init(.potato, 0, 0, 0);
    crop.growth = MAX_GROWTH;
    try std.testing.expect(!crop.grow());
    try std.testing.expectEqual(MAX_GROWTH, crop.growth);
}

test "CropState.isFullyGrown" {
    var crop = CropState.init(.wheat, 0, 0, 0);
    try std.testing.expect(!crop.isFullyGrown());
    crop.growth = MAX_GROWTH;
    try std.testing.expect(crop.isFullyGrown());
}

test "CropState.applyBoneMeal advances 2-5 stages" {
    var crop = CropState.init(.beetroot, 5, 10, 15);
    crop.applyBoneMeal();
    try std.testing.expect(crop.growth >= 2);
    try std.testing.expect(crop.growth <= MAX_GROWTH);
}

test "CropState.applyBoneMeal caps at MAX_GROWTH" {
    var crop = CropState.init(.wheat, 0, 0, 0);
    crop.growth = 6;
    crop.applyBoneMeal();
    try std.testing.expectEqual(MAX_GROWTH, crop.growth);
}

test "FarmManager plant and retrieve" {
    const allocator = std.testing.allocator;
    var fm = FarmManager.init();
    defer fm.deinit(allocator);

    try fm.plantCrop(allocator, .wheat, 10, 64, 20);

    const found = fm.getCropAt(10, 64, 20);
    try std.testing.expect(found != null);
    try std.testing.expectEqual(CropType.wheat, found.?.crop_type);
}

test "FarmManager getCropAt returns null for missing" {
    const allocator = std.testing.allocator;
    var fm = FarmManager.init();
    defer fm.deinit(allocator);

    try std.testing.expectEqual(@as(?*const CropState, null), fm.getCropAt(0, 0, 0));
}

test "FarmManager removeCrop" {
    const allocator = std.testing.allocator;
    var fm = FarmManager.init();
    defer fm.deinit(allocator);

    try fm.plantCrop(allocator, .carrot, 1, 2, 3);
    const removed = fm.removeCrop(1, 2, 3);
    try std.testing.expect(removed != null);
    try std.testing.expectEqual(CropType.carrot, removed.?.crop_type);
    try std.testing.expectEqual(@as(?*const CropState, null), fm.getCropAt(1, 2, 3));
}

test "FarmManager removeCrop returns null for missing" {
    const allocator = std.testing.allocator;
    var fm = FarmManager.init();
    defer fm.deinit(allocator);

    try std.testing.expectEqual(@as(?CropState, null), fm.removeCrop(99, 99, 99));
}

test "getDrops returns correct items" {
    const wheat_drops = getDrops(.wheat);
    try std.testing.expectEqual(@as(u16, 512), wheat_drops.item);
    try std.testing.expectEqual(@as(u8, 1), wheat_drops.count);

    const carrot_drops = getDrops(.carrot);
    try std.testing.expectEqual(@as(u16, 513), carrot_drops.item);
    try std.testing.expectEqual(@as(u8, 3), carrot_drops.count);

    const potato_drops = getDrops(.potato);
    try std.testing.expectEqual(@as(u16, 514), potato_drops.item);
    try std.testing.expectEqual(@as(u8, 3), potato_drops.count);

    const beetroot_drops = getDrops(.beetroot);
    try std.testing.expectEqual(@as(u16, 515), beetroot_drops.item);
    try std.testing.expectEqual(@as(u8, 1), beetroot_drops.count);
}

fn alwaysWater(_: i32, _: i32, _: i32) bool {
    return true;
}

fn neverWater(_: i32, _: i32, _: i32) bool {
    return false;
}

fn waterAtOrigin(x: i32, _: i32, z: i32) bool {
    return x == 0 and z == 0;
}

test "isHydrated with water nearby" {
    try std.testing.expect(isHydrated(0, 64, 0, &alwaysWater));
}

test "isHydrated with no water" {
    try std.testing.expect(!isHydrated(0, 64, 0, &neverWater));
}

test "isHydrated within 4 blocks" {
    try std.testing.expect(isHydrated(3, 64, 0, &waterAtOrigin));
    try std.testing.expect(isHydrated(4, 64, 0, &waterAtOrigin));
    try std.testing.expect(!isHydrated(5, 64, 0, &waterAtOrigin));
}

test "FarmManager update grows crops over time" {
    const allocator = std.testing.allocator;
    var fm = FarmManager.init();
    defer fm.deinit(allocator);

    try fm.plantCrop(allocator, .wheat, 0, 0, 0);

    for (0..50) |_| {
        fm.update(TICK_INTERVAL);
    }

    const crop = fm.getCropAt(0, 0, 0);
    try std.testing.expect(crop != null);
    try std.testing.expect(crop.?.growth > 0);
}
