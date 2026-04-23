/// BFS-based redstone signal propagation across arbitrary world coordinates.
///
/// Unlike `wire.zig` which operates within a fixed 16x16x16 chunk volume, this
/// module propagates signals through unbounded world-space using an `is_wire`
/// callback to determine which blocks carry redstone current.  Repeaters reset
/// signal strength to 15, allowing signals to travel beyond the usual 15-block
/// limit.
const std = @import("std");

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

/// A source of redstone power at a world position.
pub const SignalSource = struct {
    x: i32,
    y: i32,
    z: i32,
    strength: u4,
};

/// A block that has been powered by signal propagation.
pub const PoweredBlock = struct {
    x: i32,
    y: i32,
    z: i32,
    strength: u4,
};

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/// Compact key for visited-set lookups.
const PosKey = struct {
    x: i32,
    y: i32,
    z: i32,
};

/// Six cardinal neighbor offsets.
const cardinal_offsets = [6][3]i32{
    .{ 1, 0, 0 },
    .{ -1, 0, 0 },
    .{ 0, 1, 0 },
    .{ 0, -1, 0 },
    .{ 0, 0, 1 },
    .{ 0, 0, -1 },
};

/// BFS queue entry carrying position and remaining signal strength.
const QueueEntry = struct {
    x: i32,
    y: i32,
    z: i32,
    strength: u4,
};

// ---------------------------------------------------------------------------
// Propagation
// ---------------------------------------------------------------------------

/// Propagate redstone signals outward from every source using BFS.
///
/// Signal strength decays by 1 for each wire block traversed and propagation
/// stops when strength reaches 0.
///
/// Returns a fixed-size array of `PoweredBlock` results.  The caller passes
/// `max_results` to cap how many entries are written (clamped to 64); unused
/// slots have strength 0.
pub fn propagate(
    sources: []const SignalSource,
    is_wire: *const fn (i32, i32, i32) bool,
    max_results: usize,
) [64]PoweredBlock {
    return propagateWithRepeater(sources, is_wire, null, max_results);
}

/// Extended propagation that also accepts an optional `is_repeater` callback.
/// When a wire block is also a repeater, its strength is reset to 15 instead
/// of decaying.
pub fn propagateWithRepeater(
    sources: []const SignalSource,
    is_wire: *const fn (i32, i32, i32) bool,
    is_repeater: ?*const fn (i32, i32, i32) bool,
    max_results: usize,
) [64]PoweredBlock {
    const cap: usize = if (max_results > 64) 64 else max_results;

    var result: [64]PoweredBlock = [_]PoweredBlock{
        .{ .x = 0, .y = 0, .z = 0, .strength = 0 },
    } ** 64;
    var result_count: usize = 0;

    // Visited map: position -> best strength seen so far.
    var visited = std.AutoHashMap(PosKey, u4).init(std.heap.page_allocator);
    defer visited.deinit();

    // Dynamic BFS queue backed by an ArrayList.
    var queue = std.ArrayList(QueueEntry).init(std.heap.page_allocator);
    defer queue.deinit();

    // Helper: record or update a block in the results array.
    const recordResult = struct {
        fn call(
            res: *[64]PoweredBlock,
            count: *usize,
            limit: usize,
            x: i32,
            y: i32,
            z: i32,
            s: u4,
        ) void {
            for (res[0..count.*]) |*r| {
                if (r.x == x and r.y == y and r.z == z) {
                    r.strength = s;
                    return;
                }
            }
            if (count.* < limit) {
                res[count.*] = .{ .x = x, .y = y, .z = z, .strength = s };
                count.* += 1;
            }
        }
    }.call;

    // Seed the queue with all sources.
    for (sources) |src| {
        const key = PosKey{ .x = src.x, .y = src.y, .z = src.z };
        const existing = visited.get(key);
        if (existing == null or existing.? < src.strength) {
            visited.put(key, src.strength) catch continue;
            queue.append(.{
                .x = src.x,
                .y = src.y,
                .z = src.z,
                .strength = src.strength,
            }) catch continue;
            recordResult(&result, &result_count, cap, src.x, src.y, src.z, src.strength);
        }
    }

    // BFS loop using an index cursor over the growing list.
    var head: usize = 0;
    while (head < queue.items.len) {
        const cur = queue.items[head];
        head += 1;

        if (cur.strength == 0) continue;

        for (cardinal_offsets) |off| {
            const nx = @as(i64, cur.x) + @as(i64, off[0]);
            const ny = @as(i64, cur.y) + @as(i64, off[1]);
            const nz = @as(i64, cur.z) + @as(i64, off[2]);

            // Bounds check for i32.
            if (nx > std.math.maxInt(i32) or nx < std.math.minInt(i32)) continue;
            if (ny > std.math.maxInt(i32) or ny < std.math.minInt(i32)) continue;
            if (nz > std.math.maxInt(i32) or nz < std.math.minInt(i32)) continue;

            const nxi: i32 = @intCast(nx);
            const nyi: i32 = @intCast(ny);
            const nzi: i32 = @intCast(nz);

            if (!is_wire(nxi, nyi, nzi)) continue;

            // Repeater resets to 15; normal wire decays by 1.
            const new_strength: u4 = if (is_repeater) |rep_fn| blk: {
                break :blk if (rep_fn(nxi, nyi, nzi)) 15 else cur.strength - 1;
            } else cur.strength - 1;

            const nkey = PosKey{ .x = nxi, .y = nyi, .z = nzi };
            const prev = visited.get(nkey);
            if (prev == null or prev.? < new_strength) {
                visited.put(nkey, new_strength) catch continue;
                queue.append(.{
                    .x = nxi,
                    .y = nyi,
                    .z = nzi,
                    .strength = new_strength,
                }) catch continue;
                recordResult(&result, &result_count, cap, nxi, nyi, nzi, new_strength);
            }
        }
    }

    return result;
}

/// Count the number of powered blocks (strength > 0) in a result array.
pub fn countPowered(results: [64]PoweredBlock) usize {
    var n: usize = 0;
    for (results) |b| {
        if (b.strength > 0) n += 1;
    }
    return n;
}

/// Find a powered block at the given position, returning its strength or null.
pub fn findBlock(results: [64]PoweredBlock, x: i32, y: i32, z: i32) ?u4 {
    for (results) |b| {
        if (b.strength > 0 and b.x == x and b.y == y and b.z == z) {
            return b.strength;
        }
    }
    return null;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

fn alwaysWire(_: i32, _: i32, _: i32) bool {
    return true;
}

fn neverWire(_: i32, _: i32, _: i32) bool {
    return false;
}

test "single source propagates with decay" {
    const sources = [_]SignalSource{.{ .x = 0, .y = 0, .z = 0, .strength = 15 }};
    const result = propagate(&sources, &alwaysWire, 64);

    // Source itself at strength 15.
    try std.testing.expectEqual(@as(?u4, 15), findBlock(result, 0, 0, 0));
    // One step away => 14.
    try std.testing.expectEqual(@as(?u4, 14), findBlock(result, 1, 0, 0));
    try std.testing.expectEqual(@as(?u4, 14), findBlock(result, -1, 0, 0));
    try std.testing.expectEqual(@as(?u4, 14), findBlock(result, 0, 1, 0));
}

test "signal stops at strength 0" {
    const sources = [_]SignalSource{.{ .x = 0, .y = 0, .z = 0, .strength = 3 }};
    const result = propagate(&sources, &alwaysWire, 64);

    try std.testing.expectEqual(@as(?u4, 3), findBlock(result, 0, 0, 0));
    try std.testing.expectEqual(@as(?u4, 2), findBlock(result, 1, 0, 0));
    try std.testing.expectEqual(@as(?u4, 1), findBlock(result, 2, 0, 0));
    // Three steps away: strength would be 0 — not powered.
    const at3 = findBlock(result, 3, 0, 0);
    if (at3) |s| {
        try std.testing.expectEqual(@as(u4, 0), s);
    }
}

test "no wire blocks means no propagation beyond source" {
    const sources = [_]SignalSource{.{ .x = 0, .y = 0, .z = 0, .strength = 15 }};
    const result = propagate(&sources, &neverWire, 64);

    try std.testing.expectEqual(@as(?u4, 15), findBlock(result, 0, 0, 0));
    try std.testing.expectEqual(@as(usize, 1), countPowered(result));
}

test "multiple sources take strongest signal" {
    const sources = [_]SignalSource{
        .{ .x = 0, .y = 0, .z = 0, .strength = 5 },
        .{ .x = 2, .y = 0, .z = 0, .strength = 15 },
    };
    const result = propagate(&sources, &alwaysWire, 64);

    // Block at (1,0,0): 1 away from strength-15 => 14.
    try std.testing.expectEqual(@as(?u4, 14), findBlock(result, 1, 0, 0));
}

test "propagation respects is_wire callback" {
    // Only blocks on the x-axis at y=0, z=0 are wire.
    const xAxisOnly = struct {
        fn call(_: i32, y: i32, z: i32) bool {
            return y == 0 and z == 0;
        }
    }.call;

    const sources = [_]SignalSource{.{ .x = 0, .y = 0, .z = 0, .strength = 10 }};
    const result = propagate(&sources, &xAxisOnly, 64);

    try std.testing.expectEqual(@as(?u4, 9), findBlock(result, 1, 0, 0));
    try std.testing.expectEqual(@as(?u4, 8), findBlock(result, 2, 0, 0));
    // y=1 is not wire — should not be powered.
    try std.testing.expectEqual(@as(?u4, null), findBlock(result, 0, 1, 0));
}

test "repeater resets strength to 15" {
    // Place a repeater at (5, 0, 0) along a 1-D wire.
    const repeaterAt5 = struct {
        fn call(x: i32, y: i32, z: i32) bool {
            return x == 5 and y == 0 and z == 0;
        }
    }.call;
    const xAxisOnly = struct {
        fn call(_: i32, y: i32, z: i32) bool {
            return y == 0 and z == 0;
        }
    }.call;

    const sources = [_]SignalSource{.{ .x = 0, .y = 0, .z = 0, .strength = 15 }};
    const result = propagateWithRepeater(&sources, &xAxisOnly, &repeaterAt5, 64);

    // At x=5 the repeater resets strength to 15.
    try std.testing.expectEqual(@as(?u4, 15), findBlock(result, 5, 0, 0));
    // One step past repeater should be 14.
    try std.testing.expectEqual(@as(?u4, 14), findBlock(result, 6, 0, 0));
}

test "max_results caps output" {
    const sources = [_]SignalSource{.{ .x = 0, .y = 0, .z = 0, .strength = 15 }};
    const result = propagate(&sources, &alwaysWire, 2);

    try std.testing.expect(countPowered(result) <= 2);
}

test "empty sources returns all zero" {
    const empty = [_]SignalSource{};
    const result = propagate(&empty, &alwaysWire, 64);
    try std.testing.expectEqual(@as(usize, 0), countPowered(result));
}

test "source with strength 1 powers only source block" {
    const sources = [_]SignalSource{.{ .x = 0, .y = 0, .z = 0, .strength = 1 }};
    const result = propagate(&sources, &alwaysWire, 64);

    try std.testing.expectEqual(@as(?u4, 1), findBlock(result, 0, 0, 0));
    // strength-1 = 0 so no neighbors get powered.
    try std.testing.expectEqual(@as(usize, 1), countPowered(result));
}

test "diagonal not reached directly — only cardinal neighbors" {
    const sources = [_]SignalSource{.{ .x = 0, .y = 0, .z = 0, .strength = 15 }};
    const result = propagate(&sources, &alwaysWire, 64);

    // (1,1,0) is 2 cardinal steps away => strength 13, not 14.
    const diag = findBlock(result, 1, 1, 0);
    if (diag) |s| {
        try std.testing.expectEqual(@as(u4, 13), s);
    }
}

test "two repeaters in series extend range" {
    // 1-D wire along x-axis with repeaters at x=10 and x=20.
    const twoRepeaters = struct {
        fn call(x: i32, y: i32, z: i32) bool {
            _ = y;
            _ = z;
            return x == 10 or x == 20;
        }
    }.call;
    const xAxisOnly = struct {
        fn call(_: i32, y: i32, z: i32) bool {
            return y == 0 and z == 0;
        }
    }.call;

    const sources = [_]SignalSource{.{ .x = 0, .y = 0, .z = 0, .strength = 15 }};
    const result = propagateWithRepeater(&sources, &xAxisOnly, &twoRepeaters, 64);

    // After first repeater at x=10: strength = 15.
    try std.testing.expectEqual(@as(?u4, 15), findBlock(result, 10, 0, 0));
    // x=15: 5 steps from repeater => 15 - 5 = 10.
    try std.testing.expectEqual(@as(?u4, 10), findBlock(result, 15, 0, 0));
    // After second repeater at x=20: strength = 15 again.
    try std.testing.expectEqual(@as(?u4, 15), findBlock(result, 20, 0, 0));
}

test "propagateWithRepeater with null repeater matches propagate" {
    const xAxisOnly = struct {
        fn call(_: i32, y: i32, z: i32) bool {
            return y == 0 and z == 0;
        }
    }.call;

    const sources = [_]SignalSource{.{ .x = 0, .y = 0, .z = 0, .strength = 10 }};
    const r1 = propagate(&sources, &xAxisOnly, 64);
    const r2 = propagateWithRepeater(&sources, &xAxisOnly, null, 64);

    try std.testing.expectEqual(findBlock(r1, 0, 0, 0), findBlock(r2, 0, 0, 0));
    try std.testing.expectEqual(findBlock(r1, 1, 0, 0), findBlock(r2, 1, 0, 0));
    try std.testing.expectEqual(findBlock(r1, 5, 0, 0), findBlock(r2, 5, 0, 0));
}

test "countPowered returns correct count for linear wire" {
    const sources = [_]SignalSource{.{ .x = 0, .y = 0, .z = 0, .strength = 3 }};
    const xOnly = struct {
        fn call(_: i32, y: i32, z: i32) bool {
            return y == 0 and z == 0;
        }
    }.call;

    const result = propagate(&sources, &xOnly, 64);

    // Source(3) + x=1(2) + x=2(1) + x=-1(2) + x=-2(1) = 5 powered blocks.
    try std.testing.expectEqual(@as(usize, 5), countPowered(result));
}

test "3D propagation through L-shaped wire" {
    // Wire: (0,0,0)..(3,0,0) then (3,0,0)..(3,3,0).
    const lShaped = struct {
        fn call(x: i32, y: i32, z: i32) bool {
            if (z != 0) return false;
            if (y == 0 and x >= 0 and x <= 3) return true;
            if (x == 3 and y >= 0 and y <= 3) return true;
            return false;
        }
    }.call;

    const sources = [_]SignalSource{.{ .x = 0, .y = 0, .z = 0, .strength = 15 }};
    const result = propagate(&sources, &lShaped, 64);

    // End of L at (3,3,0) is 6 steps away => 15 - 6 = 9.
    try std.testing.expectEqual(@as(?u4, 9), findBlock(result, 3, 3, 0));
}
