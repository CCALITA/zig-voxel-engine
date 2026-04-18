/// A* pathfinding on a voxel grid for mob navigation.
/// Uses fixed-size open set (256 entries) and hash-based closed set.
/// Supports horizontal, diagonal, and step-up/down movement.
const std = @import("std");

pub const PathNode = struct { x: i32, y: i32, z: i32 };

pub const PathResult = struct {
    path: [64]PathNode,
    length: u8,
    found: bool,
};

const max_open: usize = 256;
const max_iterations: usize = 1000;
const max_path_nodes: usize = 64;

/// Internal node used during A* search.
const AStarNode = struct {
    x: i32,
    y: i32,
    z: i32,
    g_cost: u32,
    f_cost: u32,
    parent_index: u16, // index into open set, 0xFFFF = no parent
};

/// Pack coordinates into a single u64 for the closed set.
fn packCoord(x: i32, y: i32, z: i32) u64 {
    const ux: u64 = @bitCast(@as(i64, x));
    const uy: u64 = @bitCast(@as(i64, y));
    const uz: u64 = @bitCast(@as(i64, z));
    return (ux & 0x1FFFFF) | ((uy & 0x1FFFFF) << 21) | ((uz & 0x1FFFFF) << 42);
}

/// Manhattan distance heuristic.
fn heuristic(x: i32, y: i32, z: i32, gx: i32, gy: i32, gz: i32) u32 {
    const dx = @abs(x - gx);
    const dy = @abs(y - gy);
    const dz = @abs(z - gz);
    return @intCast(dx + dy + dz);
}

/// Remove unnecessary intermediate nodes on straight lines.
fn smoothPath(raw: []const PathNode, out: *[max_path_nodes]PathNode) u8 {
    if (raw.len <= 2) {
        for (raw, 0..) |node, i| {
            out[i] = node;
        }
        return @intCast(raw.len);
    }

    var count: u8 = 0;
    out[count] = raw[0];
    count += 1;

    var i: usize = 1;
    while (i < raw.len - 1) : (i += 1) {
        const prev = raw[i - 1];
        const curr = raw[i];
        const next = raw[i + 1];

        // Direction from prev to curr
        const dx1 = curr.x - prev.x;
        const dy1 = curr.y - prev.y;
        const dz1 = curr.z - prev.z;

        // Direction from curr to next
        const dx2 = next.x - curr.x;
        const dy2 = next.y - curr.y;
        const dz2 = next.z - curr.z;

        // Keep the node if direction changes
        if (dx1 != dx2 or dy1 != dy2 or dz1 != dz2) {
            if (count < max_path_nodes) {
                out[count] = curr;
                count += 1;
            }
        }
    }

    // Always include the last node
    if (count < max_path_nodes) {
        out[count] = raw[raw.len - 1];
        count += 1;
    }

    return count;
}

/// Neighbor offsets: 4 cardinal + 4 diagonal, each with optional step-up/down.
const Neighbor = struct { dx: i32, dz: i32, cost: u32 };

const neighbors = [_]Neighbor{
    // Cardinal (cost 10)
    .{ .dx = 1, .dz = 0, .cost = 10 },
    .{ .dx = -1, .dz = 0, .cost = 10 },
    .{ .dx = 0, .dz = 1, .cost = 10 },
    .{ .dx = 0, .dz = -1, .cost = 10 },
    // Diagonal (cost 14 ~ sqrt(2)*10)
    .{ .dx = 1, .dz = 1, .cost = 14 },
    .{ .dx = 1, .dz = -1, .cost = 14 },
    .{ .dx = -1, .dz = 1, .cost = 14 },
    .{ .dx = -1, .dz = -1, .cost = 14 },
};

pub fn findPath(
    start_x: i32,
    start_y: i32,
    start_z: i32,
    goal_x: i32,
    goal_y: i32,
    goal_z: i32,
    isWalkable: *const fn (i32, i32, i32) bool,
    max_distance: u8,
) PathResult {
    var result = PathResult{
        .path = undefined,
        .length = 0,
        .found = false,
    };

    // Quick check: start and goal are the same
    if (start_x == goal_x and start_y == goal_y and start_z == goal_z) {
        result.path[0] = .{ .x = start_x, .y = start_y, .z = start_z };
        result.length = 1;
        result.found = true;
        return result;
    }

    // Quick check: goal out of max_distance (Manhattan)
    const dist_to_goal = heuristic(start_x, start_y, start_z, goal_x, goal_y, goal_z);
    if (dist_to_goal > @as(u32, max_distance) * 10) {
        return result;
    }

    // Open set (fixed-size priority queue sorted by f_cost)
    var open: [max_open]AStarNode = undefined;
    var open_count: usize = 0;

    // Closed set using a fixed-size hash map
    // Key: packed coordinate, Value: parent packed coordinate
    const closed_capacity = 512;
    var closed_keys: [closed_capacity]u64 = [_]u64{0} ** closed_capacity;
    var closed_occupied: [closed_capacity]bool = [_]bool{false} ** closed_capacity;

    // All visited nodes for path reconstruction (store in a flat array)
    const visited_capacity = 1024;
    var visited_nodes: [visited_capacity]AStarNode = undefined;
    var visited_count: usize = 0;

    // Insert start into open set
    const start_h = heuristic(start_x, start_y, start_z, goal_x, goal_y, goal_z) * 10;
    open[0] = .{
        .x = start_x,
        .y = start_y,
        .z = start_z,
        .g_cost = 0,
        .f_cost = start_h,
        .parent_index = 0xFFFF,
    };
    open_count = 1;

    var iterations: usize = 0;
    while (iterations < max_iterations and open_count > 0) {
        iterations += 1;

        // Find the node with lowest f_cost in open set
        var best_idx: usize = 0;
        var best_f: u32 = open[0].f_cost;
        for (1..open_count) |oi| {
            if (open[oi].f_cost < best_f) {
                best_f = open[oi].f_cost;
                best_idx = oi;
            }
        }

        const current = open[best_idx];

        // Remove current from open set (swap with last)
        open_count -= 1;
        if (best_idx < open_count) {
            open[best_idx] = open[open_count];
        }

        // Store in visited for reconstruction
        const current_visited_idx: u16 = @intCast(visited_count);
        if (visited_count < visited_capacity) {
            visited_nodes[visited_count] = current;
            visited_count += 1;
        } else {
            // Out of visited storage, stop search
            break;
        }

        // Add to closed set
        const current_packed = packCoord(current.x, current.y, current.z);
        const closed_slot = @as(usize, @intCast(current_packed % closed_capacity));
        var slot = closed_slot;
        for (0..closed_capacity) |_| {
            if (!closed_occupied[slot]) {
                closed_keys[slot] = current_packed;
                closed_occupied[slot] = true;
                break;
            }
            if (closed_keys[slot] == current_packed) break;
            slot = (slot + 1) % closed_capacity;
        }

        // Goal reached
        if (current.x == goal_x and current.y == goal_y and current.z == goal_z) {
            // Reconstruct path by walking parent indices through visited_nodes
            var raw_path: [max_path_nodes]PathNode = undefined;
            var path_len: usize = 0;

            var trace_idx = current_visited_idx;
            while (path_len < max_path_nodes) {
                const node = visited_nodes[trace_idx];
                raw_path[path_len] = .{ .x = node.x, .y = node.y, .z = node.z };
                path_len += 1;
                if (node.parent_index == 0xFFFF) break;
                trace_idx = node.parent_index;
            }

            // Reverse the path (it was built goal->start)
            var left: usize = 0;
            var right: usize = path_len - 1;
            while (left < right) {
                const tmp = raw_path[left];
                raw_path[left] = raw_path[right];
                raw_path[right] = tmp;
                left += 1;
                right -= 1;
            }

            // Smooth and store result
            result.length = smoothPath(raw_path[0..path_len], &result.path);
            result.found = true;
            return result;
        }

        // Expand neighbors
        for (neighbors) |nbr| {
            // Try same level, step-up (+1), and step-down (-1)
            const y_offsets = [_]i32{ 0, 1, -1 };
            for (y_offsets) |dy| {
                const nx = current.x + nbr.dx;
                const ny = current.y + dy;
                const nz = current.z + nbr.dz;

                // Check distance from start
                const dist_from_start = heuristic(start_x, start_y, start_z, nx, ny, nz);
                if (dist_from_start > @as(u32, max_distance)) continue;

                // For step-up, check that the block above current head is clear
                if (dy == 1) {
                    if (isWalkable(current.x, current.y + 2, current.z)) continue;
                }

                // Check walkability of neighbor position using the safe position check
                // isWalkable returns true for solid blocks.
                // Safe: solid below feet, not solid at feet, not solid at head.
                const solid_below = isWalkable(nx, ny - 1, nz);
                const air_at_feet = !isWalkable(nx, ny, nz);
                const air_at_head = !isWalkable(nx, ny + 1, nz);
                if (!(solid_below and air_at_feet and air_at_head)) continue;

                // Check closed set
                const npacked = packCoord(nx, ny, nz);
                var in_closed = false;
                var cslot = @as(usize, @intCast(npacked % closed_capacity));
                for (0..closed_capacity) |_| {
                    if (!closed_occupied[cslot]) break;
                    if (closed_keys[cslot] == npacked) {
                        in_closed = true;
                        break;
                    }
                    cslot = (cslot + 1) % closed_capacity;
                }
                if (in_closed) continue;

                const step_cost: u32 = if (dy != 0) nbr.cost + 5 else nbr.cost;
                const new_g = current.g_cost + step_cost;
                const new_h = heuristic(nx, ny, nz, goal_x, goal_y, goal_z) * 10;
                const new_f = new_g + new_h;

                // Check if already in open set with lower cost
                var found_in_open = false;
                for (0..open_count) |oi| {
                    if (open[oi].x == nx and open[oi].y == ny and open[oi].z == nz) {
                        if (new_g < open[oi].g_cost) {
                            open[oi].g_cost = new_g;
                            open[oi].f_cost = new_f;
                            open[oi].parent_index = current_visited_idx;
                        }
                        found_in_open = true;
                        break;
                    }
                }

                if (!found_in_open and open_count < max_open) {
                    open[open_count] = .{
                        .x = nx,
                        .y = ny,
                        .z = nz,
                        .g_cost = new_g,
                        .f_cost = new_f,
                        .parent_index = current_visited_idx,
                    };
                    open_count += 1;
                }
            }
        }
    }

    return result;
}

// -------------------------------------------------------------------------
// Tests
// -------------------------------------------------------------------------

/// Test helper: creates a walkability function for a flat ground at y=0.
/// Solid at y <= 0, air above.
fn flatGroundWalkable(x: i32, y: i32, z: i32) bool {
    _ = x;
    _ = z;
    return y <= 0;
}

/// Test helper: flat ground with a wall at x=3 from z=-10 to z=10.
fn wallObstacleWalkable(x: i32, y: i32, z: i32) bool {
    // Ground
    if (y <= 0) return true;
    // Wall at x=3, y=1..2
    if (x == 3 and (y == 1 or y == 2) and z >= -10 and z <= 5) return true;
    return false;
}

/// Test helper: flat ground with a 1-block ledge at x=3, y=0 -> y=1.
/// Ground at y<=0 everywhere; extra solid block at (3, 1, *) making
/// the ground one step higher for x>=3.
fn stepUpWalkable(x: i32, y: i32, z: i32) bool {
    _ = z;
    if (y <= 0) return true;
    // Raised platform at x >= 3: solid at y=1
    if (x >= 3 and y == 1) return true;
    return false;
}

/// Test helper: completely blocked (solid everywhere except y > 100).
fn blockedWalkable(_: i32, y: i32, _: i32) bool {
    return y <= 100;
}

test "straight-line path on flat ground" {
    const r = findPath(0, 1, 0, 5, 1, 0, &flatGroundWalkable, 20);
    try std.testing.expect(r.found);
    try std.testing.expect(r.length >= 2);
    // First node is start
    try std.testing.expectEqual(@as(i32, 0), r.path[0].x);
    try std.testing.expectEqual(@as(i32, 1), r.path[0].y);
    try std.testing.expectEqual(@as(i32, 0), r.path[0].z);
    // Last node is goal
    const last = r.path[r.length - 1];
    try std.testing.expectEqual(@as(i32, 5), last.x);
    try std.testing.expectEqual(@as(i32, 1), last.y);
    try std.testing.expectEqual(@as(i32, 0), last.z);
}

test "path around obstacle" {
    // Start at (0,1,0), goal at (5,1,0). Wall at x=3 blocks direct path.
    const r = findPath(0, 1, 0, 5, 1, 0, &wallObstacleWalkable, 30);
    try std.testing.expect(r.found);
    // Path should go around the wall, so length > straight-line distance
    try std.testing.expect(r.length >= 3);
    // Verify start and goal
    try std.testing.expectEqual(@as(i32, 0), r.path[0].x);
    const last = r.path[r.length - 1];
    try std.testing.expectEqual(@as(i32, 5), last.x);
    try std.testing.expectEqual(@as(i32, 1), last.y);
}

test "unreachable goal returns found=false" {
    // blockedWalkable has solid blocks everywhere up to y=100, so no walkable position
    const r = findPath(0, 1, 0, 5, 1, 0, &blockedWalkable, 20);
    try std.testing.expect(!r.found);
    try std.testing.expectEqual(@as(u8, 0), r.length);
}

test "step-up over 1-block ledge" {
    // Start on flat ground at y=1, goal on raised platform at y=2 (x>=3)
    const r = findPath(0, 1, 0, 5, 2, 0, &stepUpWalkable, 20);
    try std.testing.expect(r.found);
    // Start
    try std.testing.expectEqual(@as(i32, 0), r.path[0].x);
    try std.testing.expectEqual(@as(i32, 1), r.path[0].y);
    // Goal
    const last = r.path[r.length - 1];
    try std.testing.expectEqual(@as(i32, 5), last.x);
    try std.testing.expectEqual(@as(i32, 2), last.y);
}

test "max distance limit prevents long paths" {
    // Goal is 15 blocks away but max_distance is 5
    const r = findPath(0, 1, 0, 15, 1, 0, &flatGroundWalkable, 5);
    try std.testing.expect(!r.found);
}

test "path length within max nodes" {
    const r = findPath(0, 1, 0, 10, 1, 0, &flatGroundWalkable, 30);
    try std.testing.expect(r.found);
    try std.testing.expect(r.length <= 64);
    try std.testing.expect(r.length >= 2);
}

test "same start and goal" {
    const r = findPath(3, 1, 3, 3, 1, 3, &flatGroundWalkable, 10);
    try std.testing.expect(r.found);
    try std.testing.expectEqual(@as(u8, 1), r.length);
    try std.testing.expectEqual(@as(i32, 3), r.path[0].x);
}

test "diagonal path is shorter than cardinal-only" {
    // Going diagonally from (0,1,0) to (3,1,3) should use fewer nodes
    // than pure cardinal movement
    const r = findPath(0, 1, 0, 3, 1, 3, &flatGroundWalkable, 20);
    try std.testing.expect(r.found);
    // With smoothing, a diagonal should be very short (start + end = 2 nodes)
    try std.testing.expect(r.length <= 4);
}

test "heuristic returns correct manhattan distance" {
    try std.testing.expectEqual(@as(u32, 6), heuristic(0, 0, 0, 2, 1, 3));
    try std.testing.expectEqual(@as(u32, 0), heuristic(5, 5, 5, 5, 5, 5));
    try std.testing.expectEqual(@as(u32, 3), heuristic(-1, 0, 0, 0, 1, 1));
}

test "path smoothing removes collinear nodes" {
    var raw = [_]PathNode{
        .{ .x = 0, .y = 1, .z = 0 },
        .{ .x = 1, .y = 1, .z = 0 },
        .{ .x = 2, .y = 1, .z = 0 },
        .{ .x = 3, .y = 1, .z = 0 },
        .{ .x = 4, .y = 1, .z = 0 },
    };
    var smoothed: [max_path_nodes]PathNode = undefined;
    const len = smoothPath(&raw, &smoothed);
    // Collinear nodes removed: only start and end remain
    try std.testing.expectEqual(@as(u8, 2), len);
    try std.testing.expectEqual(@as(i32, 0), smoothed[0].x);
    try std.testing.expectEqual(@as(i32, 4), smoothed[1].x);
}

test "path smoothing keeps direction changes" {
    var raw = [_]PathNode{
        .{ .x = 0, .y = 1, .z = 0 },
        .{ .x = 1, .y = 1, .z = 0 },
        .{ .x = 1, .y = 1, .z = 1 },
        .{ .x = 1, .y = 1, .z = 2 },
    };
    var smoothed: [max_path_nodes]PathNode = undefined;
    const len = smoothPath(&raw, &smoothed);
    // Direction changes at (1,1,0), so 3 nodes: start, corner, end
    try std.testing.expectEqual(@as(u8, 3), len);
    try std.testing.expectEqual(@as(i32, 0), smoothed[0].x);
    try std.testing.expectEqual(@as(i32, 1), smoothed[1].x);
    try std.testing.expectEqual(@as(i32, 0), smoothed[1].z);
    try std.testing.expectEqual(@as(i32, 2), smoothed[2].z);
}
