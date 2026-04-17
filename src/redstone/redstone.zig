/// Redstone signal propagation system.
/// Manages power levels per block within a chunk and propagates signals
/// from sources (torches, active levers/buttons) through wires with decay.
const std = @import("std");
const block = @import("block");
const BlockId = block.BlockId;
const Chunk = @import("chunk");

pub const components = @import("components.zig");

pub const SIGNAL_MAX: u4 = 15;

pub const RedstoneState = struct {
    power_levels: [4096]u4,

    pub fn init() RedstoneState {
        return .{ .power_levels = .{0} ** 4096 };
    }

    pub fn getPower(self: *const RedstoneState, x: u4, y: u4, z: u4) u4 {
        return self.power_levels[toIndex(x, y, z)];
    }

    pub fn setPower(self: *RedstoneState, x: u4, y: u4, z: u4, level: u4) void {
        self.power_levels[toIndex(x, y, z)] = level;
    }
};

/// Check if a block is a redstone power source.
pub fn isSource(block_id: BlockId) bool {
    return block_id == block.REDSTONE_TORCH or
        block_id == block.LEVER or
        block_id == block.BUTTON;
}

/// Check if a block conducts redstone signal (wire or repeater).
pub fn isConductor(block_id: BlockId) bool {
    return block_id == block.REDSTONE_WIRE or
        block_id == block.REPEATER;
}

/// Check if a position is powered (power level > 0).
pub fn isPowered(state: *const RedstoneState, x: u4, y: u4, z: u4) bool {
    return state.getPower(x, y, z) > 0;
}

/// Propagate redstone signals from all sources through wires in the chunk.
/// Uses breadth-first propagation: sources emit at power 15, wires decay by 1
/// per block. Each position keeps the maximum power it receives.
pub fn propagate(state: *RedstoneState, chunk: *const Chunk) void {
    state.power_levels = .{0} ** 4096;

    // 16384 entries: safely exceeds the worst case for a 16^3 chunk where
    // positions may be re-enqueued when a shorter path from another source
    // raises their power level.
    const QueueEntry = struct { x: u4, y: u4, z: u4, power: u4 };
    const QUEUE_CAP = 16384;
    var queue: [QUEUE_CAP]QueueEntry = undefined;
    var head: usize = 0;
    var tail: usize = 0;

    // Seed queue with all source blocks.
    for (0..16) |yi| {
        for (0..16) |zi| {
            for (0..16) |xi| {
                const x: u4 = @intCast(xi);
                const y: u4 = @intCast(yi);
                const z: u4 = @intCast(zi);
                if (isSource(chunk.getBlock(x, y, z))) {
                    state.setPower(x, y, z, SIGNAL_MAX);
                    queue[tail] = .{ .x = x, .y = y, .z = z, .power = SIGNAL_MAX };
                    tail += 1;
                }
            }
        }
    }

    const offsets = [_][3]i8{
        .{ 1, 0, 0 },
        .{ -1, 0, 0 },
        .{ 0, 1, 0 },
        .{ 0, -1, 0 },
        .{ 0, 0, 1 },
        .{ 0, 0, -1 },
    };

    while (head < tail) {
        const entry = queue[head];
        head += 1;

        if (entry.power <= 1) continue;

        const next_power: u4 = entry.power - 1;

        for (offsets) |off| {
            const nx_i32: i32 = @as(i32, entry.x) + off[0];
            const ny_i32: i32 = @as(i32, entry.y) + off[1];
            const nz_i32: i32 = @as(i32, entry.z) + off[2];

            if (nx_i32 < 0 or nx_i32 >= 16 or
                ny_i32 < 0 or ny_i32 >= 16 or
                nz_i32 < 0 or nz_i32 >= 16) continue;

            const nx: u4 = @intCast(nx_i32);
            const ny: u4 = @intCast(ny_i32);
            const nz: u4 = @intCast(nz_i32);

            const neighbor_block = chunk.getBlock(nx, ny, nz);

            if (!isConductor(neighbor_block)) continue;

            // Only update if this path provides more power.
            if (next_power > state.getPower(nx, ny, nz)) {
                state.setPower(nx, ny, nz, next_power);
                if (tail < QUEUE_CAP) {
                    queue[tail] = .{ .x = nx, .y = ny, .z = nz, .power = next_power };
                    tail += 1;
                }
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

fn toIndex(x: u4, y: u4, z: u4) usize {
    return @as(usize, y) * 256 + @as(usize, z) * 16 + @as(usize, x);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "init state has all zero power" {
    const state = RedstoneState.init();
    try std.testing.expectEqual(@as(u4, 0), state.getPower(0, 0, 0));
    try std.testing.expectEqual(@as(u4, 0), state.getPower(15, 15, 15));
}

test "set and get power" {
    var state = RedstoneState.init();
    state.setPower(3, 7, 12, 10);
    try std.testing.expectEqual(@as(u4, 10), state.getPower(3, 7, 12));
}

test "torch is a source" {
    try std.testing.expect(isSource(block.REDSTONE_TORCH));
}

test "lever is a source" {
    try std.testing.expect(isSource(block.LEVER));
}

test "button is a source" {
    try std.testing.expect(isSource(block.BUTTON));
}

test "wire is not a source" {
    try std.testing.expect(!isSource(block.REDSTONE_WIRE));
}

test "wire is a conductor" {
    try std.testing.expect(isConductor(block.REDSTONE_WIRE));
}

test "repeater is a conductor" {
    try std.testing.expect(isConductor(block.REPEATER));
}

test "stone is not a conductor" {
    try std.testing.expect(!isConductor(block.STONE));
}

test "isPowered returns true when power > 0" {
    var state = RedstoneState.init();
    try std.testing.expect(!isPowered(&state, 5, 5, 5));
    state.setPower(5, 5, 5, 1);
    try std.testing.expect(isPowered(&state, 5, 5, 5));
}

test "torch outputs power 15" {
    var chunk = Chunk.init();
    chunk.setBlock(5, 5, 5, block.REDSTONE_TORCH);

    var state = RedstoneState.init();
    propagate(&state, &chunk);

    try std.testing.expectEqual(@as(u4, 15), state.getPower(5, 5, 5));
}

test "wire propagates with decay" {
    var chunk = Chunk.init();
    // Place torch at (0,0,0) and a line of wire from (1,0,0) to (4,0,0).
    chunk.setBlock(0, 0, 0, block.REDSTONE_TORCH);
    chunk.setBlock(1, 0, 0, block.REDSTONE_WIRE);
    chunk.setBlock(2, 0, 0, block.REDSTONE_WIRE);
    chunk.setBlock(3, 0, 0, block.REDSTONE_WIRE);
    chunk.setBlock(4, 0, 0, block.REDSTONE_WIRE);

    var state = RedstoneState.init();
    propagate(&state, &chunk);

    try std.testing.expectEqual(@as(u4, 15), state.getPower(0, 0, 0)); // torch
    try std.testing.expectEqual(@as(u4, 14), state.getPower(1, 0, 0)); // wire 1
    try std.testing.expectEqual(@as(u4, 13), state.getPower(2, 0, 0)); // wire 2
    try std.testing.expectEqual(@as(u4, 12), state.getPower(3, 0, 0)); // wire 3
    try std.testing.expectEqual(@as(u4, 11), state.getPower(4, 0, 0)); // wire 4
}

test "unpowered wire has power 0" {
    var chunk = Chunk.init();
    chunk.setBlock(8, 8, 8, block.REDSTONE_WIRE);

    var state = RedstoneState.init();
    propagate(&state, &chunk);

    try std.testing.expectEqual(@as(u4, 0), state.getPower(8, 8, 8));
}

test "propagation stops at 0" {
    var chunk = Chunk.init();
    // Torch at (0,0,0), wire from (1,0,0) through (15,0,0) -- 15 wires.
    chunk.setBlock(0, 0, 0, block.REDSTONE_TORCH);
    for (1..16) |xi| {
        chunk.setBlock(@intCast(xi), 0, 0, block.REDSTONE_WIRE);
    }

    var state = RedstoneState.init();
    propagate(&state, &chunk);

    // Torch = 15, wire at x=1 = 14, ..., wire at x=14 = 1, wire at x=15 = 0.
    try std.testing.expectEqual(@as(u4, 15), state.getPower(0, 0, 0));
    try std.testing.expectEqual(@as(u4, 1), state.getPower(14, 0, 0));
    try std.testing.expectEqual(@as(u4, 0), state.getPower(15, 0, 0));
}

test "lever as source powers adjacent wire" {
    var chunk = Chunk.init();
    chunk.setBlock(5, 5, 5, block.LEVER);
    chunk.setBlock(6, 5, 5, block.REDSTONE_WIRE);

    var state = RedstoneState.init();
    propagate(&state, &chunk);

    try std.testing.expectEqual(@as(u4, 15), state.getPower(5, 5, 5));
    try std.testing.expectEqual(@as(u4, 14), state.getPower(6, 5, 5));
}

test "signal does not pass through air" {
    var chunk = Chunk.init();
    // Torch at (0,0,0), air at (1,0,0), wire at (2,0,0).
    chunk.setBlock(0, 0, 0, block.REDSTONE_TORCH);
    // (1,0,0) is air by default
    chunk.setBlock(2, 0, 0, block.REDSTONE_WIRE);

    var state = RedstoneState.init();
    propagate(&state, &chunk);

    try std.testing.expectEqual(@as(u4, 0), state.getPower(2, 0, 0));
}

test "propagation resets state before running" {
    var chunk = Chunk.init();
    chunk.setBlock(0, 0, 0, block.REDSTONE_TORCH);
    chunk.setBlock(1, 0, 0, block.REDSTONE_WIRE);

    var state = RedstoneState.init();
    state.setPower(10, 10, 10, 15); // stale data

    propagate(&state, &chunk);

    // Stale data should be cleared.
    try std.testing.expectEqual(@as(u4, 0), state.getPower(10, 10, 10));
    // Propagated data should be present.
    try std.testing.expectEqual(@as(u4, 14), state.getPower(1, 0, 0));
}
