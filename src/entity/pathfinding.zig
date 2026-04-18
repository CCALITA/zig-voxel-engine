/// A* grid-based pathfinding for mob navigation around obstacles.
/// Operates on integer block coordinates in the XZ plane, with a Y check
/// to ensure walkability (solid ground below, no solid block at feet/head).
///
/// The caller supplies an `isWalkable(x, y, z) -> bool` callback via a
/// static bridge pattern (same approach as RaycastBridge in engine.zig).
const std = @import("std");

pub const PathNode = struct {
    x: i32,
    y: i32,
    z: i32,
};

/// Maximum nodes in a returned path.
pub const MAX_PATH_LEN: u8 = 64;

/// Result of a pathfinding query.
pub const PathResult = struct {
    nodes: [MAX_PATH_LEN]PathNode,
    length: u8,
};

/// Static bridge for world walkability queries.
/// The engine sets the callback before AI updates and clears it afterward.
pub const WalkabilityBridge = struct {
    pub var isWalkableFn: ?*const fn (i32, i32, i32) bool = null;

    pub fn isWalkable(x: i32, y: i32, z: i32) bool {
        const func = isWalkableFn orelse return false;
        return func(x, y, z);
    }
};

/// Find a path from (sx, sy, sz) to (gx, gy, gz) using A* on the XZ grid.
/// Returns a PathResult with the sequence of block positions to walk through.
/// Falls back to a straight-line path when no walkability callback is set or
/// when the search space is exhausted.
pub fn findPath(
    sx: i32,
    sy: i32,
    sz: i32,
    gx: i32,
    gy: i32,
    gz: i32,
) PathResult {
    // If no walkability callback, return straight-line fallback.
    if (WalkabilityBridge.isWalkableFn == null) {
        return straightLinePath(sx, sy, sz, gx, gy, gz);
    }

    // Clamp search distance to avoid huge searches.
    const dx_abs = absI32(gx - sx);
    const dz_abs = absI32(gz - sz);
    if (dx_abs + dz_abs > 48) {
        return straightLinePath(sx, sy, sz, gx, gy, gz);
    }

    // A* with fixed-size open/closed sets.
    const MAX_OPEN = 256;
    const MAX_CLOSED = 512;

    var open: [MAX_OPEN]AStarNode = undefined;
    var open_len: usize = 0;
    var closed: [MAX_CLOSED]AStarNode = undefined;
    var closed_len: usize = 0;

    // Seed the open list with the start node.
    const h_start = heuristic(sx, sz, gx, gz);
    open[0] = .{
        .x = sx,
        .y = sy,
        .z = sz,
        .g = 0,
        .f = h_start,
        .parent_idx = -1,
    };
    open_len = 1;

    // Neighbor offsets: 4-connected grid (N, S, E, W).
    const offsets = [_][2]i32{
        .{ 1, 0 },
        .{ -1, 0 },
        .{ 0, 1 },
        .{ 0, -1 },
    };

    while (open_len > 0) {
        // Find the node with the lowest f score in the open list.
        var best_idx: usize = 0;
        var best_f: u16 = open[0].f;
        for (1..open_len) |i| {
            if (open[i].f < best_f) {
                best_f = open[i].f;
                best_idx = i;
            }
        }

        const current = open[best_idx];

        // Move current from open to closed.
        open[best_idx] = open[open_len - 1];
        open_len -= 1;

        if (closed_len >= MAX_CLOSED) {
            return straightLinePath(sx, sy, sz, gx, gy, gz);
        }
        closed[closed_len] = current;
        const current_closed_idx: i16 = @intCast(closed_len);
        closed_len += 1;

        // Goal reached?
        if (current.x == gx and current.z == gz) {
            return reconstructPath(closed[0..closed_len], current_closed_idx);
        }

        // Expand neighbors.
        for (offsets) |off| {
            const nx = current.x + off[0];
            const nz = current.z + off[1];

            // Try same Y, or step up/down by 1 block.
            const ny = findWalkableY(nx, current.y, nz) orelse continue;

            // Skip if already in closed list.
            if (inClosed(closed[0..closed_len], nx, nz)) continue;

            const new_g = current.g + 1;
            const new_f = new_g + heuristic(nx, nz, gx, gz);

            // Check if already in open with a better g.
            var in_open = false;
            for (open[0..open_len]) |*o| {
                if (o.x == nx and o.z == nz) {
                    in_open = true;
                    if (new_g < o.g) {
                        o.g = new_g;
                        o.f = new_f;
                        o.y = ny;
                        o.parent_idx = current_closed_idx;
                    }
                    break;
                }
            }

            if (!in_open) {
                if (open_len >= MAX_OPEN) continue; // open list full, skip
                open[open_len] = .{
                    .x = nx,
                    .y = ny,
                    .z = nz,
                    .g = new_g,
                    .f = new_f,
                    .parent_idx = current_closed_idx,
                };
                open_len += 1;
            }
        }
    }

    // No path found; fall back to straight line.
    return straightLinePath(sx, sy, sz, gx, gy, gz);
}

/// Check if a position is walkable at the given Y, or one block above or below.
/// Returns the walkable Y level, or null if none found.
fn findWalkableY(x: i32, base_y: i32, z: i32) ?i32 {
    // Try same level first.
    if (WalkabilityBridge.isWalkable(x, base_y, z)) return base_y;
    // Step up by 1 (climbing a block).
    if (WalkabilityBridge.isWalkable(x, base_y + 1, z)) return base_y + 1;
    // Step down by 1 (descending).
    if (WalkabilityBridge.isWalkable(x, base_y - 1, z)) return base_y - 1;
    return null;
}

/// Manhattan distance heuristic.
fn heuristic(ax: i32, az: i32, bx: i32, bz: i32) u16 {
    const dx: u16 = @intCast(absI32(ax - bx));
    const dz: u16 = @intCast(absI32(az - bz));
    return dx + dz;
}

fn absI32(v: i32) u32 {
    return @abs(v);
}

const AStarNode = struct {
    x: i32,
    y: i32,
    z: i32,
    g: u16,
    f: u16,
    parent_idx: i16, // -1 = start node
};

fn inClosed(closed: []const AStarNode, x: i32, z: i32) bool {
    for (closed) |c| {
        if (c.x == x and c.z == z) return true;
    }
    return false;
}

/// Reconstruct the path from the closed list by following parent indices.
fn reconstructPath(
    closed: []const AStarNode,
    goal_idx: i16,
) PathResult {
    var result = PathResult{
        .nodes = undefined,
        .length = 0,
    };

    // Walk backwards from goal to start, collecting nodes in reverse.
    var temp: [MAX_PATH_LEN]PathNode = undefined;
    var temp_len: u8 = 0;
    var idx = goal_idx;
    while (idx >= 0 and temp_len < MAX_PATH_LEN) {
        const uidx: usize = @intCast(idx);
        temp[temp_len] = .{
            .x = closed[uidx].x,
            .y = closed[uidx].y,
            .z = closed[uidx].z,
        };
        temp_len += 1;
        idx = closed[uidx].parent_idx;
    }

    // Reverse into result, skipping the start node (mob is already there).
    if (temp_len > 1) {
        const count = temp_len - 1; // exclude start node
        for (0..count) |i| {
            result.nodes[i] = temp[count - 1 - i];
        }
        result.length = @intCast(count);
    }

    return result;
}

/// Fallback: produce a straight-line path from start to goal using simple stepping.
fn straightLinePath(
    sx: i32,
    sy: i32,
    sz: i32,
    gx: i32,
    _: i32,
    gz: i32,
) PathResult {
    var result = PathResult{
        .nodes = undefined,
        .length = 0,
    };

    var cx: i32 = sx;
    var cz: i32 = sz;

    while (result.length < MAX_PATH_LEN) {
        if (cx == gx and cz == gz) break;

        const dx = gx - cx;
        const dz = gz - cz;

        // Step along the axis with the larger remaining distance.
        if (absI32(dx) >= absI32(dz)) {
            cx += if (dx > 0) @as(i32, 1) else @as(i32, -1);
        } else {
            cz += if (dz > 0) @as(i32, 1) else @as(i32, -1);
        }

        result.nodes[result.length] = .{ .x = cx, .y = sy, .z = cz };
        result.length += 1;
    }

    return result;
}

// -------------------------------------------------------------------------
// Tests
// -------------------------------------------------------------------------

test "straightLinePath produces correct path" {
    const result = straightLinePath(0, 0, 0, 3, 0, 0);
    try std.testing.expectEqual(@as(u8, 3), result.length);
    try std.testing.expectEqual(@as(i32, 1), result.nodes[0].x);
    try std.testing.expectEqual(@as(i32, 2), result.nodes[1].x);
    try std.testing.expectEqual(@as(i32, 3), result.nodes[2].x);
}

test "straightLinePath handles zero distance" {
    const result = straightLinePath(5, 0, 5, 5, 0, 5);
    try std.testing.expectEqual(@as(u8, 0), result.length);
}

test "findPath without callback returns straight line" {
    // Ensure no callback is set.
    WalkabilityBridge.isWalkableFn = null;
    const result = findPath(0, 0, 0, 3, 0, 0);
    try std.testing.expectEqual(@as(u8, 3), result.length);
}

test "findPath with callback finds path" {
    // Simple callback: everything is walkable.
    const Helper = struct {
        fn alwaysWalkable(_: i32, _: i32, _: i32) bool {
            return true;
        }
    };
    WalkabilityBridge.isWalkableFn = &Helper.alwaysWalkable;
    defer WalkabilityBridge.isWalkableFn = null;

    const result = findPath(0, 0, 0, 3, 0, 0);
    // Should find a path of length 3 (Manhattan distance).
    try std.testing.expect(result.length > 0);
    try std.testing.expect(result.length <= 6); // allow minor detours
    // Last node should be the goal.
    const last = result.nodes[result.length - 1];
    try std.testing.expectEqual(@as(i32, 3), last.x);
    try std.testing.expectEqual(@as(i32, 0), last.z);
}

test "findPath navigates around obstacle" {
    // Create a wall at x=1, z=0..2 -- walkable everywhere except x=1, z=0 and x=1,z=1.
    const Helper = struct {
        fn isWalkable(x: i32, _: i32, z: i32) bool {
            if (x == 1 and z >= 0 and z <= 1) return false;
            return true;
        }
    };
    WalkabilityBridge.isWalkableFn = &Helper.isWalkable;
    defer WalkabilityBridge.isWalkableFn = null;

    const result = findPath(0, 0, 0, 2, 0, 0);
    // Should find a path that goes around the obstacle.
    try std.testing.expect(result.length > 0);
    // Last node should be the goal.
    const last = result.nodes[result.length - 1];
    try std.testing.expectEqual(@as(i32, 2), last.x);
    try std.testing.expectEqual(@as(i32, 0), last.z);
    // Path should be longer than 2 (straight line blocked).
    try std.testing.expect(result.length > 2);
}

test "heuristic returns manhattan distance" {
    try std.testing.expectEqual(@as(u16, 5), heuristic(0, 0, 3, 2));
    try std.testing.expectEqual(@as(u16, 0), heuristic(1, 1, 1, 1));
}

test "absI32 works for positive and negative" {
    try std.testing.expectEqual(@as(u32, 5), absI32(-5));
    try std.testing.expectEqual(@as(u32, 5), absI32(5));
    try std.testing.expectEqual(@as(u32, 0), absI32(0));
}
