/// Piston mechanics for normal and sticky pistons.
/// Pistons push up to MAX_PUSH blocks in a line. Sticky pistons also pull one
/// block back on retraction. Immovable blocks (bedrock, obsidian, etc.) and
/// tile-entity blocks (chest, furnace) cannot be pushed.

const std = @import("std");

// ──────────────────────────────────────────────────────────────────────────────
// Block constants (mirrored from world/block.zig to stay dependency-free)
// ──────────────────────────────────────────────────────────────────────────────

const AIR: u8 = 0;
const BEDROCK: u8 = 11;
const OBSIDIAN: u8 = 19;
const FURNACE: u8 = 39;
const CHEST: u8 = 43;

// ──────────────────────────────────────────────────────────────────────────────
// Public types
// ──────────────────────────────────────────────────────────────────────────────

pub const PistonType = enum { normal, sticky };

pub const PistonState = struct {
    ptype: PistonType,
    facing: u3,
    extended: bool,
};

pub const MAX_PUSH = 12;

pub const BlockEntry = struct { x: i32, y: i32, z: i32, id: u8 };

pub const PushResult = struct {
    blocks: [MAX_PUSH]BlockEntry,
    count: u8,
    success: bool,
};

// ──────────────────────────────────────────────────────────────────────────────
// Facing helpers
// ──────────────────────────────────────────────────────────────────────────────

const Offset = struct { dx: i32, dy: i32, dz: i32 };

fn facingOffset(facing: u3) Offset {
    return switch (facing) {
        0 => .{ .dx = 0, .dy = 0, .dz = -1 }, // north (-Z)
        1 => .{ .dx = 0, .dy = 0, .dz = 1 }, // south (+Z)
        2 => .{ .dx = 1, .dy = 0, .dz = 0 }, // east  (+X)
        3 => .{ .dx = -1, .dy = 0, .dz = 0 }, // west  (-X)
        4 => .{ .dx = 0, .dy = 1, .dz = 0 }, // up    (+Y)
        5 => .{ .dx = 0, .dy = -1, .dz = 0 }, // down  (-Y)
        else => .{ .dx = 0, .dy = 0, .dz = 0 },
    };
}

// ──────────────────────────────────────────────────────────────────────────────
// Pushability
// ──────────────────────────────────────────────────────────────────────────────

/// Returns true when a block can be moved by a piston.
/// Bedrock, obsidian, and tile-entity blocks (chest, furnace) cannot be pushed.
pub fn canPush(block_id: u8) bool {
    return switch (block_id) {
        BEDROCK, OBSIDIAN, FURNACE, CHEST => false,
        else => true,
    };
}

// ──────────────────────────────────────────────────────────────────────────────
// Push-list calculation
// ──────────────────────────────────────────────────────────────────────────────

/// Walk from the block immediately in front of the piston along the facing
/// direction, collecting every movable block until air, an immovable block,
/// or the MAX_PUSH limit is reached.
pub fn calculatePushList(
    facing: u3,
    piston_x: i32,
    piston_y: i32,
    piston_z: i32,
    getBlock: *const fn (i32, i32, i32) u8,
) PushResult {
    const off = facingOffset(facing);
    var result = PushResult{
        .blocks = undefined,
        .count = 0,
        .success = true,
    };

    // Start one step in front of the piston.
    var cx = piston_x + off.dx;
    var cy = piston_y + off.dy;
    var cz = piston_z + off.dz;

    while (result.count < MAX_PUSH) {
        const id = getBlock(cx, cy, cz);

        if (id == AIR) break;

        if (!canPush(id)) {
            result.success = false;
            return result;
        }

        result.blocks[result.count] = .{ .x = cx, .y = cy, .z = cz, .id = id };
        result.count += 1;

        cx += off.dx;
        cy += off.dy;
        cz += off.dz;
    }

    // If we filled MAX_PUSH entries and the next block is still not air,
    // the push fails.
    if (result.count == MAX_PUSH) {
        const next_id = getBlock(cx, cy, cz);
        if (next_id != AIR) {
            result.success = false;
        }
    }

    return result;
}

// ──────────────────────────────────────────────────────────────────────────────
// Extend / Retract
// ──────────────────────────────────────────────────────────────────────────────

/// Extend the piston: shift every block in the push list forward by one in the
/// facing direction, then place the piston head (represented by the piston
/// block id 37) in the space vacated by the first block.
pub fn extend(
    state: *PistonState,
    push_list: PushResult,
    setBlock: *const fn (i32, i32, i32, u8) void,
) void {
    if (state.extended) return;
    if (!push_list.success) return;

    const off = facingOffset(state.facing);

    // Move blocks back-to-front so we never overwrite an un-moved block.
    var i: usize = push_list.count;
    while (i > 0) {
        i -= 1;
        const b = push_list.blocks[i];
        setBlock(b.x + off.dx, b.y + off.dy, b.z + off.dz, b.id);
        setBlock(b.x, b.y, b.z, AIR);
    }

    state.extended = true;
}

/// Retract the piston. Sticky pistons pull the block directly in front of the
/// piston head back by one position; normal pistons simply retract.
pub fn retract(
    state: *PistonState,
    piston_x: i32,
    piston_y: i32,
    piston_z: i32,
    getBlock: *const fn (i32, i32, i32) u8,
    setBlock: *const fn (i32, i32, i32, u8) void,
) void {
    if (!state.extended) return;

    if (state.ptype == .sticky) {
        const off = facingOffset(state.facing);
        // The block to pull is two steps from the piston base in the facing
        // direction (one step = head, two steps = target block).
        const pull_x = piston_x + off.dx * 2;
        const pull_y = piston_y + off.dy * 2;
        const pull_z = piston_z + off.dz * 2;

        const pull_id = getBlock(pull_x, pull_y, pull_z);
        if (pull_id != AIR and canPush(pull_id)) {
            setBlock(pull_x, pull_y, pull_z, AIR);
            setBlock(pull_x - off.dx, pull_y - off.dy, pull_z - off.dz, pull_id);
        }
    }

    state.extended = false;
}

// ──────────────────────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────────────────────

const TestBlockMap = struct {
    const SIZE = 32;
    const OFFSET = 16;
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

var test_map: TestBlockMap = undefined;

fn testGetBlock(x: i32, y: i32, z: i32) u8 {
    return test_map.get(x, y, z);
}

fn testSetBlock(x: i32, y: i32, z: i32, id: u8) void {
    test_map.set(x, y, z, id);
}

// --- canPush tests ----------------------------------------------------------

test "canPush allows normal blocks" {
    const STONE: u8 = 1;
    const DIRT: u8 = 2;
    try std.testing.expect(canPush(STONE));
    try std.testing.expect(canPush(DIRT));
    try std.testing.expect(canPush(AIR));
}

test "canPush rejects immovable blocks" {
    try std.testing.expect(!canPush(BEDROCK));
    try std.testing.expect(!canPush(OBSIDIAN));
}

test "canPush rejects tile entity blocks" {
    try std.testing.expect(!canPush(FURNACE));
    try std.testing.expect(!canPush(CHEST));
}

// --- push single block ------------------------------------------------------

test "push single block forward" {
    test_map = TestBlockMap.init();
    const STONE: u8 = 1;

    // Piston at (0,0,0) facing east (+X). Block at (1,0,0).
    test_map.set(1, 0, 0, STONE);

    const result = calculatePushList(2, 0, 0, 0, testGetBlock);
    try std.testing.expect(result.success);
    try std.testing.expectEqual(@as(u8, 1), result.count);
    try std.testing.expectEqual(@as(u8, STONE), result.blocks[0].id);
    try std.testing.expectEqual(@as(i32, 1), result.blocks[0].x);

    var state = PistonState{ .ptype = .normal, .facing = 2, .extended = false };
    extend(&state, result, testSetBlock);

    try std.testing.expect(state.extended);
    try std.testing.expectEqual(AIR, test_map.get(1, 0, 0));
    try std.testing.expectEqual(STONE, test_map.get(2, 0, 0));
}

// --- push chain of blocks ---------------------------------------------------

test "push chain of 3 blocks" {
    test_map = TestBlockMap.init();
    const STONE: u8 = 1;

    // Piston at (0,0,0) facing east. Blocks at x=1,2,3.
    test_map.set(1, 0, 0, STONE);
    test_map.set(2, 0, 0, STONE);
    test_map.set(3, 0, 0, STONE);

    const result = calculatePushList(2, 0, 0, 0, testGetBlock);
    try std.testing.expect(result.success);
    try std.testing.expectEqual(@as(u8, 3), result.count);

    var state = PistonState{ .ptype = .normal, .facing = 2, .extended = false };
    extend(&state, result, testSetBlock);

    // Original positions cleared, new positions filled.
    try std.testing.expectEqual(AIR, test_map.get(1, 0, 0));
    try std.testing.expectEqual(STONE, test_map.get(2, 0, 0));
    try std.testing.expectEqual(STONE, test_map.get(3, 0, 0));
    try std.testing.expectEqual(STONE, test_map.get(4, 0, 0));
}

// --- immovable block stops push ---------------------------------------------

test "immovable block stops push" {
    test_map = TestBlockMap.init();
    const STONE: u8 = 1;

    // Stone then obsidian in the push line.
    test_map.set(1, 0, 0, STONE);
    test_map.set(2, 0, 0, OBSIDIAN);

    const result = calculatePushList(2, 0, 0, 0, testGetBlock);
    try std.testing.expect(!result.success);
}

// --- more than 12 blocks fails ----------------------------------------------

test "more than 12 blocks fails" {
    test_map = TestBlockMap.init();
    const STONE: u8 = 1;

    // Place 13 blocks in a row starting at x=1.
    var i: i32 = 1;
    while (i <= 13) : (i += 1) {
        test_map.set(i, 0, 0, STONE);
    }

    const result = calculatePushList(2, 0, 0, 0, testGetBlock);
    try std.testing.expect(!result.success);
}

// --- exactly 12 blocks succeeds when followed by air -------------------------

test "exactly 12 blocks succeeds" {
    test_map = TestBlockMap.init();
    const STONE: u8 = 1;

    var i: i32 = 1;
    while (i <= 12) : (i += 1) {
        test_map.set(i, 0, 0, STONE);
    }

    const result = calculatePushList(2, 0, 0, 0, testGetBlock);
    try std.testing.expect(result.success);
    try std.testing.expectEqual(@as(u8, 12), result.count);
}

// --- sticky piston pull test ------------------------------------------------

test "sticky piston pulls block on retract" {
    test_map = TestBlockMap.init();
    const STONE: u8 = 1;

    // Simulate: piston base at origin, facing east (+X).
    // The block to pull sits at relative +2 (two steps from base).
    test_map.set(2, 0, 0, STONE);

    var state = PistonState{ .ptype = .sticky, .facing = 2, .extended = true };
    retract(&state, 0, 0, 0, testGetBlock, testSetBlock);

    try std.testing.expect(!state.extended);
    // Block should have moved from (2,0,0) to (1,0,0).
    try std.testing.expectEqual(AIR, test_map.get(2, 0, 0));
    try std.testing.expectEqual(STONE, test_map.get(1, 0, 0));
}

// --- normal piston retract does not pull ------------------------------------

test "normal piston retract does not pull" {
    test_map = TestBlockMap.init();
    const STONE: u8 = 1;

    test_map.set(2, 0, 0, STONE);

    var state = PistonState{ .ptype = .normal, .facing = 2, .extended = true };
    retract(&state, 0, 0, 0, testGetBlock, testSetBlock);

    try std.testing.expect(!state.extended);
    // Block stays in place.
    try std.testing.expectEqual(STONE, test_map.get(2, 0, 0));
}

// --- extend is idempotent when already extended ------------------------------

test "extend is no-op when already extended" {
    test_map = TestBlockMap.init();

    var state = PistonState{ .ptype = .normal, .facing = 2, .extended = true };
    const result = PushResult{ .blocks = undefined, .count = 0, .success = true };
    extend(&state, result, testSetBlock);
    try std.testing.expect(state.extended);
}

// --- retract is idempotent when already retracted ----------------------------

test "retract is no-op when already retracted" {
    test_map = TestBlockMap.init();

    var state = PistonState{ .ptype = .sticky, .facing = 2, .extended = false };
    retract(&state, 0, 0, 0, testGetBlock, testSetBlock);
    try std.testing.expect(!state.extended);
}

// --- push into air (no blocks) succeeds with count 0 -----------------------

test "push into empty space succeeds" {
    test_map = TestBlockMap.init();

    const result = calculatePushList(2, 0, 0, 0, testGetBlock);
    try std.testing.expect(result.success);
    try std.testing.expectEqual(@as(u8, 0), result.count);
}

// --- sticky piston will not pull immovable block ----------------------------

test "sticky piston does not pull immovable block" {
    test_map = TestBlockMap.init();

    test_map.set(2, 0, 0, OBSIDIAN);

    var state = PistonState{ .ptype = .sticky, .facing = 2, .extended = true };
    retract(&state, 0, 0, 0, testGetBlock, testSetBlock);

    try std.testing.expect(!state.extended);
    // Obsidian stays put.
    try std.testing.expectEqual(OBSIDIAN, test_map.get(2, 0, 0));
    try std.testing.expectEqual(AIR, test_map.get(1, 0, 0));
}
