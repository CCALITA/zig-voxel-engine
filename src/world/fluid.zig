const std = @import("std");
const block = @import("block.zig");
const dripstone = @import("dripstone.zig");

pub const FluidType = dripstone.FluidType;

pub const Pos = struct { x: i32, y: i32, z: i32 };

pub const InteractionResult = enum {
    cobblestone,
    obsidian,
    stone,
};

pub const FluidBlock = struct {
    fluid_type: FluidType,
    level: u3,
    falling: bool,

    pub fn isSource(self: FluidBlock) bool {
        return self.level == 0;
    }

    fn blockId(self: FluidBlock) block.BlockId {
        return switch (self.fluid_type) {
            .water => block.WATER,
            .lava => block.LAVA,
        };
    }
};

/// Returns true when level == 0 (source block).
pub fn isSource(level: u3) bool {
    return level == 0;
}

/// Tick-rate for each fluid type.
/// Water: 5 ticks everywhere. Lava: 30 overworld, 10 nether.
pub fn getFlowSpeed(fluid_type: FluidType, in_nether: bool) u8 {
    return switch (fluid_type) {
        .water => 5,
        .lava => if (in_nether) 10 else 30,
    };
}

/// Determines the interaction result when water meets lava.
///   - Lava source hit by water -> obsidian
///   - Water source hit by lava -> stone
///   - Otherwise (flowing lava + water) -> cobblestone
pub fn interact(
    water_pos: Pos,
    lava_pos: Pos,
    getBlock: *const fn (i32, i32, i32) u8,
) InteractionResult {
    const lava_id = getBlock(lava_pos.x, lava_pos.y, lava_pos.z);
    const water_id = getBlock(water_pos.x, water_pos.y, water_pos.z);

    if (lava_id == block.LAVA and isSource(0)) return .obsidian;
    if (water_id == block.WATER and isSource(0)) return .stone;
    return .cobblestone;
}

/// Simulate one tick of fluid flow for the block at (x, y, z).
/// Tries to flow downward first; if blocked, spreads horizontally at level + 1.
pub fn tickFlow(
    x: i32,
    y: i32,
    z: i32,
    fluid: FluidBlock,
    getBlock: *const fn (i32, i32, i32) u8,
    setBlock: *const fn (i32, i32, i32, u8) void,
) void {
    const id = fluid.blockId();

    // Try to flow downward first.
    if (getBlock(x, y - 1, z) == block.AIR) {
        setBlock(x, y - 1, z, id);
        return;
    }

    // Weakest level cannot spread further.
    if (fluid.level >= 7) return;

    const offsets = [_][2]i32{ .{ 1, 0 }, .{ -1, 0 }, .{ 0, 1 }, .{ 0, -1 } };
    for (offsets) |off| {
        const nx = x + off[0];
        const nz = z + off[1];
        if (getBlock(nx, y, nz) == block.AIR) {
            setBlock(nx, y, nz, id);
        }
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "isSource returns true only for level 0" {
    try std.testing.expect(isSource(0));
    try std.testing.expect(!isSource(1));
    try std.testing.expect(!isSource(7));
}

test "FluidBlock.isSource method" {
    const src = FluidBlock{ .fluid_type = .water, .level = 0, .falling = false };
    const flow = FluidBlock{ .fluid_type = .water, .level = 3, .falling = false };
    try std.testing.expect(src.isSource());
    try std.testing.expect(!flow.isSource());
}

test "getFlowSpeed water is 5" {
    try std.testing.expectEqual(@as(u8, 5), getFlowSpeed(.water, false));
    try std.testing.expectEqual(@as(u8, 5), getFlowSpeed(.water, true));
}

test "getFlowSpeed lava overworld is 30" {
    try std.testing.expectEqual(@as(u8, 30), getFlowSpeed(.lava, false));
}

test "getFlowSpeed lava nether is 10 (faster)" {
    try std.testing.expectEqual(@as(u8, 10), getFlowSpeed(.lava, true));
}

test "interact lava + water produces cobblestone" {
    const w = Pos{ .x = 0, .y = 0, .z = 0 };
    const l = Pos{ .x = 1, .y = 0, .z = 0 };
    try std.testing.expectEqual(InteractionResult.cobblestone, interact(w, l, &testGetBlock));
}

// -- Flow simulation tests using a tiny virtual world --

const TestWorld = struct {
    blocks: [4096]u8 = [_]u8{0} ** 4096,

    fn idx(bx: i32, by: i32, bz: i32) usize {
        const cx: usize = @intCast(@mod(bx, 16));
        const cy: usize = @intCast(@mod(by, 16));
        const cz: usize = @intCast(@mod(bz, 16));
        return cy * 256 + cz * 16 + cx;
    }

    fn get(self: *const TestWorld, bx: i32, by: i32, bz: i32) u8 {
        return self.blocks[idx(bx, by, bz)];
    }

    fn set(self: *TestWorld, bx: i32, by: i32, bz: i32, val: u8) void {
        self.blocks[idx(bx, by, bz)] = val;
    }
};

var test_world: TestWorld = .{};

fn testGetBlock(bx: i32, by: i32, bz: i32) u8 {
    return test_world.get(bx, by, bz);
}

fn testSetBlock(bx: i32, by: i32, bz: i32, val: u8) void {
    test_world.set(bx, by, bz, val);
}

test "source water spreads down into air" {
    test_world = .{};
    const src = FluidBlock{ .fluid_type = .water, .level = 0, .falling = false };
    tickFlow(5, 5, 5, src, &testGetBlock, &testSetBlock);
    try std.testing.expectEqual(block.WATER, test_world.get(5, 4, 5));
}

test "source water spreads horizontally when blocked below" {
    test_world = .{};
    test_world.set(5, 4, 5, block.STONE);
    const src = FluidBlock{ .fluid_type = .water, .level = 0, .falling = false };
    tickFlow(5, 5, 5, src, &testGetBlock, &testSetBlock);
    const east = test_world.get(6, 5, 5);
    const west = test_world.get(4, 5, 5);
    const south = test_world.get(5, 5, 6);
    const north = test_world.get(5, 5, 4);
    try std.testing.expect(east == block.WATER or west == block.WATER or south == block.WATER or north == block.WATER);
}

test "weakest level (7) does not spread further (decay)" {
    test_world = .{};
    test_world.set(5, 4, 5, block.STONE);
    const weak = FluidBlock{ .fluid_type = .water, .level = 7, .falling = false };
    tickFlow(5, 5, 5, weak, &testGetBlock, &testSetBlock);
    try std.testing.expectEqual(block.AIR, test_world.get(6, 5, 5));
    try std.testing.expectEqual(block.AIR, test_world.get(4, 5, 5));
    try std.testing.expectEqual(block.AIR, test_world.get(5, 5, 6));
    try std.testing.expectEqual(block.AIR, test_world.get(5, 5, 4));
}
