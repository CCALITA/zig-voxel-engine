/// Explosion system for TNT and Creeper detonations.
/// Iterates a sphere of blocks around the center, destroying non-bedrock blocks
/// within radius (weighted by distance). Entities receive damage that falls off
/// linearly with distance from the center.

const std = @import("std");

// ──────────────────────────────────────────────────────────────────────────────
// Block constants (mirrored from world/block.zig to avoid cross-module import)
// ──────────────────────────────────────────────────────────────────────────────

const BEDROCK: u8 = 11;
const AIR: u8 = 0;

// ──────────────────────────────────────────────────────────────────────────────
// Explosion source presets
// ──────────────────────────────────────────────────────────────────────────────

pub const tnt_radius: f32 = 4.0;
pub const tnt_power: f32 = 4.0;
pub const tnt_fuse_time: f32 = 4.0;

pub const creeper_radius: f32 = 3.0;
pub const creeper_power: f32 = 3.0;

// ──────────────────────────────────────────────────────────────────────────────
// Result types
// ──────────────────────────────────────────────────────────────────────────────

pub const DestroyedBlock = struct {
    x: i32,
    y: i32,
    z: i32,
    block_id: u8,
};

pub const EntityDamage = struct {
    entity_idx: u32,
    damage: f32,
};

pub const ExplosionResult = struct {
    destroyed_blocks: std.ArrayList(DestroyedBlock),
    entity_damage: std.ArrayList(EntityDamage),

    pub fn deinit(self: *ExplosionResult, allocator: std.mem.Allocator) void {
        self.destroyed_blocks.deinit(allocator);
        self.entity_damage.deinit(allocator);
    }
};

// ──────────────────────────────────────────────────────────────────────────────
// Entity position (lightweight input for damage calculation)
// ──────────────────────────────────────────────────────────────────────────────

pub const EntityPos = struct {
    x: f32,
    y: f32,
    z: f32,
};

// ──────────────────────────────────────────────────────────────────────────────
// Block lookup callback
// ──────────────────────────────────────────────────────────────────────────────

/// Called to read the block id at a given world position.
pub const GetBlockFn = *const fn (x: i32, y: i32, z: i32) u8;

// ──────────────────────────────────────────────────────────────────────────────
// Core explosion logic
// ──────────────────────────────────────────────────────────────────────────────

/// Compute an explosion centred at (cx, cy, cz) with the given radius and power.
///
/// `get_block` is called once per candidate position to read the current block.
/// `entities` supplies the positions of entities that may take damage.
///
/// Returns an ExplosionResult whose lists are allocated with `allocator`.
/// The caller owns the result and must call `result.deinit(allocator)`.
pub fn explode(
    cx: f32,
    cy: f32,
    cz: f32,
    radius: f32,
    power: f32,
    get_block: GetBlockFn,
    entities: []const EntityPos,
    allocator: std.mem.Allocator,
) ExplosionResult {
    var destroyed: std.ArrayList(DestroyedBlock) = .empty;
    var damages: std.ArrayList(EntityDamage) = .empty;

    const r_int: i32 = @intFromFloat(@ceil(radius));
    const radius_sq = radius * radius;

    // Iterate every integer block position within the bounding cube, then
    // test whether the block centre falls within the sphere.
    var bz: i32 = -r_int;
    while (bz <= r_int) : (bz += 1) {
        var by: i32 = -r_int;
        while (by <= r_int) : (by += 1) {
            var bx: i32 = -r_int;
            while (bx <= r_int) : (bx += 1) {
                const fx: f32 = @floatFromInt(bx);
                const fy: f32 = @floatFromInt(by);
                const fz: f32 = @floatFromInt(bz);
                const dist_sq = fx * fx + fy * fy + fz * fz;

                if (dist_sq > radius_sq) continue;

                const wx: i32 = @as(i32, @intFromFloat(@floor(cx))) + bx;
                const wy: i32 = @as(i32, @intFromFloat(@floor(cy))) + by;
                const wz: i32 = @as(i32, @intFromFloat(@floor(cz))) + bz;

                const block_id = get_block(wx, wy, wz);

                if (block_id == AIR) continue;
                if (block_id == BEDROCK) continue;

                destroyed.append(allocator, .{
                    .x = wx,
                    .y = wy,
                    .z = wz,
                    .block_id = block_id,
                }) catch {};
            }
        }
    }

    // Entity damage: linear fall-off from full power at centre to 0 at radius.
    for (entities, 0..) |ent, idx| {
        const dx = ent.x - cx;
        const dy = ent.y - cy;
        const dz = ent.z - cz;
        const dist = @sqrt(dx * dx + dy * dy + dz * dz);

        if (dist >= radius) continue;

        const damage = power * (1.0 - dist / radius);
        damages.append(allocator, .{
            .entity_idx = @intCast(idx),
            .damage = damage,
        }) catch {};
    }

    return .{
        .destroyed_blocks = destroyed,
        .entity_damage = damages,
    };
}

// ──────────────────────────────────────────────────────────────────────────────
// TNT fuse state machine
// ──────────────────────────────────────────────────────────────────────────────

pub const TNTState = struct {
    x: f32,
    y: f32,
    z: f32,
    fuse_timer: f32,
    active: bool,

    pub fn init(x: f32, y: f32, z: f32) TNTState {
        return .{
            .x = x,
            .y = y,
            .z = z,
            .fuse_timer = tnt_fuse_time,
            .active = true,
        };
    }

    /// Tick the fuse by `dt` seconds. Returns `true` the instant the fuse
    /// expires (i.e. the TNT should now explode). After detonation `active`
    /// is set to false and subsequent calls are no-ops.
    pub fn update(self: *TNTState, dt: f32) bool {
        if (!self.active) return false;

        self.fuse_timer = @max(self.fuse_timer - dt, 0.0);
        if (self.fuse_timer <= 0.0) {
            self.active = false;
            return true;
        }
        return false;
    }
};

// ──────────────────────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────────────────────

// --- helpers for tests -------------------------------------------------------

const TestBlockMap = struct {
    const SIZE = 32;
    const OFFSET = 16; // shift so negative coords map to valid indices
    data: [SIZE][SIZE][SIZE]u8,

    fn init() TestBlockMap {
        return .{ .data = [_][SIZE][SIZE]u8{[_][SIZE]u8{[_]u8{AIR} ** SIZE} ** SIZE} ** SIZE };
    }

    fn set(self: *TestBlockMap, x: i32, y: i32, z: i32, id: u8) void {
        const ux: usize = @intCast(x + OFFSET);
        const uy: usize = @intCast(y + OFFSET);
        const uz: usize = @intCast(z + OFFSET);
        self.data[ux][uy][uz] = id;
    }

    fn get(self: *const TestBlockMap, x: i32, y: i32, z: i32) u8 {
        const ux: usize = @intCast(x + OFFSET);
        const uy: usize = @intCast(y + OFFSET);
        const uz: usize = @intCast(z + OFFSET);
        return self.data[ux][uy][uz];
    }
};

var test_block_map: TestBlockMap = undefined;

fn testGetBlock(x: i32, y: i32, z: i32) u8 {
    return test_block_map.get(x, y, z);
}

// --- block destruction tests ------------------------------------------------

test "blocks within radius are destroyed" {
    test_block_map = TestBlockMap.init();
    const STONE: u8 = 1;

    // Place a 3x3x3 cube of stone centred at (0,0,0)
    var z: i32 = -1;
    while (z <= 1) : (z += 1) {
        var y: i32 = -1;
        while (y <= 1) : (y += 1) {
            var x: i32 = -1;
            while (x <= 1) : (x += 1) {
                test_block_map.set(x, y, z, STONE);
            }
        }
    }

    var result = explode(0, 0, 0, 4.0, 4.0, testGetBlock, &.{}, std.testing.allocator);
    defer result.deinit(std.testing.allocator);

    // All 27 stone blocks should be destroyed (all within radius 4)
    try std.testing.expectEqual(@as(usize, 27), result.destroyed_blocks.items.len);

    // Verify every destroyed block was stone
    for (result.destroyed_blocks.items) |db| {
        try std.testing.expectEqual(STONE, db.block_id);
    }
}

test "bedrock survives explosion" {
    test_block_map = TestBlockMap.init();
    const STONE: u8 = 1;

    // Place stone and bedrock at known positions
    test_block_map.set(0, 0, 0, STONE);
    test_block_map.set(1, 0, 0, BEDROCK);
    test_block_map.set(0, 1, 0, STONE);

    var result = explode(0, 0, 0, 4.0, 4.0, testGetBlock, &.{}, std.testing.allocator);
    defer result.deinit(std.testing.allocator);

    // Only the two stone blocks should be destroyed; bedrock survives
    try std.testing.expectEqual(@as(usize, 2), result.destroyed_blocks.items.len);
    for (result.destroyed_blocks.items) |db| {
        try std.testing.expect(db.block_id != BEDROCK);
    }
}

test "blocks outside radius are not destroyed" {
    test_block_map = TestBlockMap.init();
    const STONE: u8 = 1;

    // Place a block at distance > radius
    test_block_map.set(5, 5, 5, STONE); // dist ~8.66, well outside radius 4

    var result = explode(0, 0, 0, 4.0, 4.0, testGetBlock, &.{}, std.testing.allocator);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 0), result.destroyed_blocks.items.len);
}

// --- entity damage tests ----------------------------------------------------

test "damage falls off with distance" {
    test_block_map = TestBlockMap.init();

    const entities = [_]EntityPos{
        .{ .x = 0, .y = 0, .z = 0 }, // at centre
        .{ .x = 2, .y = 0, .z = 0 }, // mid-range
        .{ .x = 3.5, .y = 0, .z = 0 }, // near edge
    };

    var result = explode(0, 0, 0, 4.0, 4.0, testGetBlock, &entities, std.testing.allocator);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), result.entity_damage.items.len);

    const dmg_centre = result.entity_damage.items[0].damage;
    const dmg_mid = result.entity_damage.items[1].damage;
    const dmg_edge = result.entity_damage.items[2].damage;

    // Centre should receive full power
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), dmg_centre, 0.001);

    // Mid-range gets power * (1 - 2/4) = 2.0
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), dmg_mid, 0.001);

    // Damage should decrease with distance
    try std.testing.expect(dmg_centre > dmg_mid);
    try std.testing.expect(dmg_mid > dmg_edge);
}

test "entity outside radius takes no damage" {
    test_block_map = TestBlockMap.init();

    const entities = [_]EntityPos{
        .{ .x = 10, .y = 0, .z = 0 }, // way outside
    };

    var result = explode(0, 0, 0, 4.0, 4.0, testGetBlock, &entities, std.testing.allocator);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 0), result.entity_damage.items.len);
}

test "entity at exact radius boundary takes no damage" {
    test_block_map = TestBlockMap.init();

    const entities = [_]EntityPos{
        .{ .x = 4, .y = 0, .z = 0 }, // exactly at radius
    };

    var result = explode(0, 0, 0, 4.0, 4.0, testGetBlock, &entities, std.testing.allocator);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 0), result.entity_damage.items.len);
}

// --- TNT fuse tests ---------------------------------------------------------

test "TNT fuse timing" {
    var tnt = TNTState.init(5.0, 10.0, 3.0);

    try std.testing.expect(tnt.active);
    try std.testing.expectApproxEqAbs(tnt_fuse_time, tnt.fuse_timer, 0.001);

    // Tick 3 seconds -- should NOT explode yet
    try std.testing.expect(!tnt.update(3.0));
    try std.testing.expect(tnt.active);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), tnt.fuse_timer, 0.001);

    // Tick 1 more second -- should explode exactly now
    try std.testing.expect(tnt.update(1.0));
    try std.testing.expect(!tnt.active);
}

test "TNT does not fire again after detonation" {
    var tnt = TNTState.init(0, 0, 0);

    // Expire the fuse
    _ = tnt.update(5.0);
    try std.testing.expect(!tnt.active);

    // Further updates are no-ops
    try std.testing.expect(!tnt.update(1.0));
}

test "TNT init stores position" {
    const tnt = TNTState.init(1.5, 2.5, 3.5);
    try std.testing.expectApproxEqAbs(@as(f32, 1.5), tnt.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 2.5), tnt.y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 3.5), tnt.z, 0.001);
}

// --- preset constants tests -------------------------------------------------

test "TNT constants match Minecraft values" {
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), tnt_radius, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), tnt_power, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), tnt_fuse_time, 0.001);
}

test "Creeper constants" {
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), creeper_radius, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), creeper_power, 0.001);
}

// --- creeper explosion test -------------------------------------------------

test "creeper explosion has smaller radius than TNT" {
    test_block_map = TestBlockMap.init();
    const STONE: u8 = 1;

    // Fill a 9x9x9 cube with stone centred at origin
    var z: i32 = -4;
    while (z <= 4) : (z += 1) {
        var y: i32 = -4;
        while (y <= 4) : (y += 1) {
            var x: i32 = -4;
            while (x <= 4) : (x += 1) {
                test_block_map.set(x, y, z, STONE);
            }
        }
    }

    var tnt_result = explode(0, 0, 0, tnt_radius, tnt_power, testGetBlock, &.{}, std.testing.allocator);
    defer tnt_result.deinit(std.testing.allocator);

    var creeper_result = explode(0, 0, 0, creeper_radius, creeper_power, testGetBlock, &.{}, std.testing.allocator);
    defer creeper_result.deinit(std.testing.allocator);

    try std.testing.expect(creeper_result.destroyed_blocks.items.len < tnt_result.destroyed_blocks.items.len);
}
