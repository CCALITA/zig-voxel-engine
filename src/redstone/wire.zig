const std = @import("std");

/// A source of redstone power at a specific position.
pub const Source = struct {
    x: u4,
    y: u4,
    z: u4,
    power: u4,
};

/// Comparator operating mode.
pub const ComparatorMode = enum {
    compare,
    subtract,
};

const chunk_side = 16;
const volume = chunk_side * chunk_side * chunk_side;

/// Six cardinal neighbor offsets (dx, dy, dz).
const neighbors = [6][3]i8{
    .{ 1, 0, 0 },
    .{ -1, 0, 0 },
    .{ 0, 1, 0 },
    .{ 0, -1, 0 },
    .{ 0, 0, 1 },
    .{ 0, 0, -1 },
};

/// Try to offset a u4 coordinate by a signed delta, returning null if out of bounds.
fn offsetCoord(base: u4, delta: i8) ?u4 {
    const result = @as(i8, base) + delta;
    if (result < 0 or result >= chunk_side) return null;
    return @intCast(@as(u8, @intCast(result)));
}

fn index(x: u4, y: u4, z: u4) usize {
    return (@as(usize, x) << 8) | (@as(usize, y) << 4) | @as(usize, z);
}

/// Redstone wire network tracking power levels across a 16x16x16 chunk volume.
/// Positions are indexed as power_levels[x << 8 | y << 4 | z].
pub const WireNetwork = struct {
    power_levels: [volume]u4,

    pub fn init() WireNetwork {
        return .{ .power_levels = [_]u4{0} ** volume };
    }

    /// BFS propagation from all sources. Signal decays by 1 per block distance.
    pub fn propagate(self: *WireNetwork, sources: []const Source) void {
        @memset(&self.power_levels, 0);

        var queue_buf: [volume]Source = undefined;
        var head: usize = 0;
        var tail: usize = 0;

        for (sources) |src| {
            const idx = index(src.x, src.y, src.z);
            if (src.power > self.power_levels[idx]) {
                self.power_levels[idx] = src.power;
                queue_buf[tail] = src;
                tail += 1;
            }
        }

        while (head < tail) {
            const cur = queue_buf[head];
            head += 1;

            if (cur.power <= 1) continue;
            const new_power = cur.power - 1;

            for (neighbors) |off| {
                const nx = offsetCoord(cur.x, off[0]) orelse continue;
                const ny = offsetCoord(cur.y, off[1]) orelse continue;
                const nz = offsetCoord(cur.z, off[2]) orelse continue;

                const nidx = index(nx, ny, nz);
                if (new_power > self.power_levels[nidx]) {
                    self.power_levels[nidx] = new_power;
                    if (tail < queue_buf.len) {
                        queue_buf[tail] = .{ .x = nx, .y = ny, .z = nz, .power = new_power };
                        tail += 1;
                    }
                }
            }
        }
    }

    /// Returns the signal strength at the given position.
    pub fn getSignalStrength(self: WireNetwork, x: u4, y: u4, z: u4) u4 {
        return self.power_levels[index(x, y, z)];
    }

    /// Returns true if the position has any redstone power.
    pub fn isPowered(self: WireNetwork, x: u4, y: u4, z: u4) bool {
        return self.power_levels[index(x, y, z)] > 0;
    }
};

/// Comparator output: in compare mode returns back if back >= side, else 0.
/// In subtract mode returns saturating back - side.
pub fn comparatorOutput(back: u4, side: u4, mode: ComparatorMode) u4 {
    return switch (mode) {
        .compare => if (back >= side) back else 0,
        .subtract => back -| side,
    };
}

/// Repeater output: emits full power (15) when input > 0, else 0.
/// The delay parameter is accepted for interface completeness but does not
/// affect the combinational output value.
pub fn repeaterOutput(input: u4, delay: u2) u4 {
    _ = delay;
    return if (input > 0) 15 else 0;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "propagation decay from single source" {
    var net = WireNetwork.init();
    const sources = [_]Source{.{ .x = 8, .y = 8, .z = 8, .power = 15 }};
    net.propagate(&sources);

    // Source block itself should be 15.
    try std.testing.expectEqual(@as(u4, 15), net.getSignalStrength(8, 8, 8));

    // One block away should be 14.
    try std.testing.expectEqual(@as(u4, 14), net.getSignalStrength(9, 8, 8));
    try std.testing.expectEqual(@as(u4, 14), net.getSignalStrength(7, 8, 8));

    // Two blocks away (same axis) should be 13.
    try std.testing.expectEqual(@as(u4, 13), net.getSignalStrength(10, 8, 8));

    // At the edge of the chunk, far from source, power should be 0.
    try std.testing.expectEqual(@as(u4, 0), net.getSignalStrength(0, 0, 0));
}

test "source at 15 spreads to adjacent blocks" {
    var net = WireNetwork.init();
    const sources = [_]Source{.{ .x = 0, .y = 0, .z = 0, .power = 15 }};
    net.propagate(&sources);

    try std.testing.expect(net.isPowered(0, 0, 0));
    try std.testing.expect(net.isPowered(1, 0, 0));
    try std.testing.expect(net.isPowered(0, 1, 0));
    try std.testing.expect(net.isPowered(0, 0, 1));

    // 15 blocks away along x should have power 0.
    try std.testing.expectEqual(@as(u4, 0), net.getSignalStrength(15, 0, 0));
}

test "multiple sources pick strongest signal" {
    var net = WireNetwork.init();
    const sources = [_]Source{
        .{ .x = 0, .y = 0, .z = 0, .power = 10 },
        .{ .x = 2, .y = 0, .z = 0, .power = 15 },
    };
    net.propagate(&sources);

    // Block at (1,0,0) is 1 away from source@15 -> 14 and 1 away from source@10 -> 9.
    // Should take the stronger signal.
    try std.testing.expectEqual(@as(u4, 14), net.getSignalStrength(1, 0, 0));
}

test "isPowered returns false for unpowered block" {
    var net = WireNetwork.init();
    try std.testing.expect(!net.isPowered(0, 0, 0));
}

test "comparator compare mode" {
    // back >= side -> output back
    try std.testing.expectEqual(@as(u4, 10), comparatorOutput(10, 5, .compare));
    // back < side -> output 0
    try std.testing.expectEqual(@as(u4, 0), comparatorOutput(5, 10, .compare));
    // equal -> output back
    try std.testing.expectEqual(@as(u4, 7), comparatorOutput(7, 7, .compare));
}

test "comparator subtract mode" {
    try std.testing.expectEqual(@as(u4, 5), comparatorOutput(10, 5, .subtract));
    // Saturates at 0 when side > back.
    try std.testing.expectEqual(@as(u4, 0), comparatorOutput(3, 10, .subtract));
    try std.testing.expectEqual(@as(u4, 0), comparatorOutput(0, 15, .subtract));
}

test "repeater output" {
    // Any nonzero input produces 15.
    try std.testing.expectEqual(@as(u4, 15), repeaterOutput(1, 0));
    try std.testing.expectEqual(@as(u4, 15), repeaterOutput(8, 3));
    // Zero input produces 0.
    try std.testing.expectEqual(@as(u4, 0), repeaterOutput(0, 2));
}
