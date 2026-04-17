/// Environmental hazard system: contact damage, flammability, and fire spread.
/// Uses u8 block ID constants matching src/world/block.zig.

const std = @import("std");

// ── Block ID constants (mirrors src/world/block.zig) ────────────────────────
const LAVA: u8 = 32;
const CACTUS: u8 = 26;
const OAK_LOG: u8 = 8;
const OAK_PLANKS: u8 = 5;
const OAK_LEAVES: u8 = 9;

// Block IDs not yet in block.zig — reserved local constants.
const FIRE: u8 = 50;
const TALL_GRASS: u8 = 51;
const FERN: u8 = 52;
const WOOL: u8 = 53;

// ── Contact damage ──────────────────────────────────────────────────────────

/// Damage per second for standing in / touching the given block.
/// LAVA = 4.0/s, FIRE = 1.0/s, CACTUS = 1.0 on touch, else 0.
pub fn getContactDamage(block_id: u8) f32 {
    return switch (block_id) {
        LAVA => 4.0,
        FIRE => 1.0,
        CACTUS => 1.0,
        else => 0.0,
    };
}

// ── Flammability ────────────────────────────────────────────────────────────

/// Returns true when the block can catch fire.
pub fn isFlammable(block_id: u8) bool {
    return switch (block_id) {
        OAK_LOG, OAK_PLANKS, OAK_LEAVES, TALL_GRASS, FERN, WOOL => true,
        else => false,
    };
}

// ── Fire spread ─────────────────────────────────────────────────────────────

/// Signed 32-bit coordinate — matches the rest of the engine.
pub const Coord = i32;

pub const GetBlockFn = *const fn (x: Coord, y: Coord, z: Coord) u8;
pub const SetBlockFn = *const fn (x: Coord, y: Coord, z: Coord, block_id: u8) void;

const spread_offsets = [_][3]Coord{
    .{ 1, 0, 0 },
    .{ -1, 0, 0 },
    .{ 0, 1, 0 },
    .{ 0, -1, 0 },
    .{ 0, 0, 1 },
    .{ 0, 0, -1 },
};

/// Monotonic tick counter used to vary the RNG seed across calls.
var tick_counter: u64 = 0;

/// Per-tick fire spread from a single fire source block.
/// Each adjacent flammable block has a 20 % chance of catching fire.
/// The RNG is seeded from position + tick counter so results vary per call
/// while remaining deterministic for a given sequence.
pub fn tickFireSpread(
    fire_x: Coord,
    fire_y: Coord,
    fire_z: Coord,
    getBlock: GetBlockFn,
    setBlock: SetBlockFn,
) void {
    const tick = tick_counter;
    tick_counter +%= 1;

    const pos_hash = @as(u32, @bitCast(fire_x)) +%
        @as(u32, @bitCast(fire_y)) *% 31 +%
        @as(u32, @bitCast(fire_z)) *% 997;
    const seed: u64 = @as(u64, pos_hash) +% tick *% 6364136223846793005;
    var rng = std.Random.DefaultPrng.init(seed);
    const random = rng.random();

    for (spread_offsets) |off| {
        const nx = fire_x + off[0];
        const ny = fire_y + off[1];
        const nz = fire_z + off[2];
        const neighbor = getBlock(nx, ny, nz);
        if (isFlammable(neighbor)) {
            if (random.float(f32) < 0.2) {
                setBlock(nx, ny, nz, FIRE);
            }
        }
    }
}

// ── HazardManager ───────────────────────────────────────────────────────────

pub const FirePos = struct { x: Coord, y: Coord, z: Coord };

pub const HazardManager = struct {
    fires: std.ArrayList(FirePos),

    pub fn init() HazardManager {
        return .{ .fires = .empty };
    }

    pub fn deinit(self: *HazardManager, allocator: std.mem.Allocator) void {
        self.fires.deinit(allocator);
    }

    /// Register a fire block to be tracked for spread updates.
    pub fn addFire(self: *HazardManager, allocator: std.mem.Allocator, x: Coord, y: Coord, z: Coord) !void {
        try self.fires.append(allocator, .{ .x = x, .y = y, .z = z });
    }

    /// Remove a tracked fire at the given position (first match).
    pub fn removeFire(self: *HazardManager, x: Coord, y: Coord, z: Coord) void {
        for (self.fires.items, 0..) |f, i| {
            if (f.x == x and f.y == y and f.z == z) {
                _ = self.fires.orderedRemove(i);
                return;
            }
        }
    }

    /// Tick fire spread for every tracked fire block.
    /// Snapshots the current count so fires added by callbacks during
    /// this tick are not iterated until the next tick.
    pub fn updateSpread(
        self: *HazardManager,
        getBlock: GetBlockFn,
        setBlock: SetBlockFn,
    ) void {
        const count = self.fires.items.len;
        for (self.fires.items[0..count]) |fire| {
            tickFireSpread(fire.x, fire.y, fire.z, getBlock, setBlock);
        }
    }

    pub fn fireCount(self: *const HazardManager) usize {
        return self.fires.items.len;
    }
};

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

test "lava deals 4.0 damage per second" {
    try std.testing.expectEqual(@as(f32, 4.0), getContactDamage(LAVA));
}

test "fire deals 1.0 damage per second" {
    try std.testing.expectEqual(@as(f32, 1.0), getContactDamage(FIRE));
}

test "cactus deals 1.0 damage on touch" {
    try std.testing.expectEqual(@as(f32, 1.0), getContactDamage(CACTUS));
}

test "non-hazard blocks deal no damage" {
    try std.testing.expectEqual(@as(f32, 0.0), getContactDamage(0)); // AIR
    try std.testing.expectEqual(@as(f32, 0.0), getContactDamage(1)); // STONE
    try std.testing.expectEqual(@as(f32, 0.0), getContactDamage(OAK_LOG));
}

test "flammable blocks are identified correctly" {
    try std.testing.expect(isFlammable(OAK_LOG));
    try std.testing.expect(isFlammable(OAK_PLANKS));
    try std.testing.expect(isFlammable(OAK_LEAVES));
    try std.testing.expect(isFlammable(TALL_GRASS));
    try std.testing.expect(isFlammable(FERN));
    try std.testing.expect(isFlammable(WOOL));
}

test "non-flammable blocks are rejected" {
    try std.testing.expect(!isFlammable(0)); // AIR
    try std.testing.expect(!isFlammable(1)); // STONE
    try std.testing.expect(!isFlammable(LAVA));
    try std.testing.expect(!isFlammable(CACTUS));
}

// ── Fire-spread integration test ────────────────────────────────────────────

// Mutable shared state for the test callbacks.
var test_world: [5][5][5]u8 = undefined;

fn testGetBlock(x: Coord, y: Coord, z: Coord) u8 {
    const ux = std.math.cast(usize, x) orelse return 0;
    const uy = std.math.cast(usize, y) orelse return 0;
    const uz = std.math.cast(usize, z) orelse return 0;
    if (ux >= 5 or uy >= 5 or uz >= 5) return 0;
    return test_world[ux][uy][uz];
}

fn testSetBlock(x: Coord, y: Coord, z: Coord, block_id: u8) void {
    const ux = std.math.cast(usize, x) orelse return;
    const uy = std.math.cast(usize, y) orelse return;
    const uz = std.math.cast(usize, z) orelse return;
    if (ux >= 5 or uy >= 5 or uz >= 5) return;
    test_world[ux][uy][uz] = block_id;
}

fn resetTestWorld() void {
    for (&test_world) |*plane| {
        for (plane) |*row| {
            @memset(row, 0);
        }
    }
    tick_counter = 0;
}

test "fire spreads to adjacent flammable blocks" {
    resetTestWorld();

    // Place fire at (2,2,2) surrounded by flammable blocks.
    test_world[2][2][2] = FIRE;
    test_world[3][2][2] = OAK_PLANKS;
    test_world[1][2][2] = OAK_LOG;
    test_world[2][3][2] = OAK_LEAVES;
    test_world[2][1][2] = TALL_GRASS;
    test_world[2][2][3] = FERN;
    test_world[2][2][1] = WOOL;

    // Run enough ticks that (at 20 % per tick) every neighbor is
    // almost certain to have caught fire.
    var i: usize = 0;
    while (i < 200) : (i += 1) {
        tickFireSpread(2, 2, 2, &testGetBlock, &testSetBlock);
    }

    // Verify at least one neighbor converted to FIRE.
    const any_spread = (test_world[3][2][2] == FIRE) or
        (test_world[1][2][2] == FIRE) or
        (test_world[2][3][2] == FIRE) or
        (test_world[2][1][2] == FIRE) or
        (test_world[2][2][3] == FIRE) or
        (test_world[2][2][1] == FIRE);
    try std.testing.expect(any_spread);
}

test "fire does not spread to non-flammable blocks" {
    resetTestWorld();

    // Fire at (2,2,2) surrounded by stone (id=1).
    test_world[2][2][2] = FIRE;
    test_world[3][2][2] = 1;
    test_world[1][2][2] = 1;
    test_world[2][3][2] = 1;
    test_world[2][1][2] = 1;
    test_world[2][2][3] = 1;
    test_world[2][2][1] = 1;

    var i: usize = 0;
    while (i < 200) : (i += 1) {
        tickFireSpread(2, 2, 2, &testGetBlock, &testSetBlock);
    }

    // No neighbor should become fire.
    try std.testing.expectEqual(@as(u8, 1), test_world[3][2][2]);
    try std.testing.expectEqual(@as(u8, 1), test_world[1][2][2]);
    try std.testing.expectEqual(@as(u8, 1), test_world[2][3][2]);
    try std.testing.expectEqual(@as(u8, 1), test_world[2][1][2]);
    try std.testing.expectEqual(@as(u8, 1), test_world[2][2][3]);
    try std.testing.expectEqual(@as(u8, 1), test_world[2][2][1]);
}

test "HazardManager tracks and removes fires" {
    var hm = HazardManager.init();
    defer hm.deinit(std.testing.allocator);

    try hm.addFire(std.testing.allocator, 0, 0, 0);
    try hm.addFire(std.testing.allocator, 1, 2, 3);
    try std.testing.expectEqual(@as(usize, 2), hm.fireCount());

    hm.removeFire(0, 0, 0);
    try std.testing.expectEqual(@as(usize, 1), hm.fireCount());
}
