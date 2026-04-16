/// Axis-Aligned Bounding Box for voxel collision detection.
const std = @import("std");

pub const AABB = struct {
    min_x: f32,
    min_y: f32,
    min_z: f32,
    max_x: f32,
    max_y: f32,
    max_z: f32,

    /// Create an AABB centered at (cx, cy, cz) with given full extents.
    /// The box spans from (cx - w/2, cy - h/2, cz - d/2) to (cx + w/2, cy + h/2, cz + d/2).
    pub fn fromCenterSize(cx: f32, cy: f32, cz: f32, w: f32, h: f32, d: f32) AABB {
        const hw = w * 0.5;
        const hh = h * 0.5;
        const hd = d * 0.5;
        return .{
            .min_x = cx - hw,
            .min_y = cy - hh,
            .min_z = cz - hd,
            .max_x = cx + hw,
            .max_y = cy + hh,
            .max_z = cz + hd,
        };
    }

    /// Check whether two AABBs overlap (strict inequality — touching edges do not intersect).
    pub fn intersects(a: AABB, b: AABB) bool {
        return a.min_x < b.max_x and a.max_x > b.min_x and
            a.min_y < b.max_y and a.max_y > b.min_y and
            a.min_z < b.max_z and a.max_z > b.min_z;
    }

    /// Check whether the point (x, y, z) is inside the AABB (inclusive).
    pub fn contains(a: AABB, x: f32, y: f32, z: f32) bool {
        return x >= a.min_x and x <= a.max_x and
            y >= a.min_y and y <= a.max_y and
            z >= a.min_z and z <= a.max_z;
    }

    /// Return a new AABB translated by (dx, dy, dz).
    pub fn offset(self: AABB, dx: f32, dy: f32, dz: f32) AABB {
        return .{
            .min_x = self.min_x + dx,
            .min_y = self.min_y + dy,
            .min_z = self.min_z + dz,
            .max_x = self.max_x + dx,
            .max_y = self.max_y + dy,
            .max_z = self.max_z + dz,
        };
    }

    /// Expand the AABB in the direction of motion (dx, dy, dz).
    /// Positive values expand the max side; negative values expand the min side.
    pub fn expand(self: AABB, dx: f32, dy: f32, dz: f32) AABB {
        return .{
            .min_x = if (dx < 0) self.min_x + dx else self.min_x,
            .min_y = if (dy < 0) self.min_y + dy else self.min_y,
            .min_z = if (dz < 0) self.min_z + dz else self.min_z,
            .max_x = if (dx > 0) self.max_x + dx else self.max_x,
            .max_y = if (dy > 0) self.max_y + dy else self.max_y,
            .max_z = if (dz > 0) self.max_z + dz else self.max_z,
        };
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "intersection: overlapping boxes" {
    const a = AABB{ .min_x = 0, .min_y = 0, .min_z = 0, .max_x = 2, .max_y = 2, .max_z = 2 };
    const b = AABB{ .min_x = 1, .min_y = 1, .min_z = 1, .max_x = 3, .max_y = 3, .max_z = 3 };
    try std.testing.expect(a.intersects(b));
    try std.testing.expect(b.intersects(a));
}

test "non-intersection: separated boxes" {
    const a = AABB{ .min_x = 0, .min_y = 0, .min_z = 0, .max_x = 1, .max_y = 1, .max_z = 1 };
    const b = AABB{ .min_x = 2, .min_y = 2, .min_z = 2, .max_x = 3, .max_y = 3, .max_z = 3 };
    try std.testing.expect(!a.intersects(b));
}

test "non-intersection: touching edges are not intersecting" {
    const a = AABB{ .min_x = 0, .min_y = 0, .min_z = 0, .max_x = 1, .max_y = 1, .max_z = 1 };
    const b = AABB{ .min_x = 1, .min_y = 0, .min_z = 0, .max_x = 2, .max_y = 1, .max_z = 1 };
    try std.testing.expect(!a.intersects(b));
}

test "containment: point inside" {
    const a = AABB{ .min_x = 0, .min_y = 0, .min_z = 0, .max_x = 2, .max_y = 2, .max_z = 2 };
    try std.testing.expect(a.contains(1, 1, 1));
}

test "containment: point on boundary is inside" {
    const a = AABB{ .min_x = 0, .min_y = 0, .min_z = 0, .max_x = 2, .max_y = 2, .max_z = 2 };
    try std.testing.expect(a.contains(0, 0, 0));
    try std.testing.expect(a.contains(2, 2, 2));
}

test "containment: point outside" {
    const a = AABB{ .min_x = 0, .min_y = 0, .min_z = 0, .max_x = 2, .max_y = 2, .max_z = 2 };
    try std.testing.expect(!a.contains(3, 1, 1));
}

test "offset: shifts AABB correctly" {
    const a = AABB{ .min_x = 0, .min_y = 0, .min_z = 0, .max_x = 1, .max_y = 1, .max_z = 1 };
    const b = a.offset(5, -3, 2);
    try std.testing.expectApproxEqAbs(@as(f32, 5), b.min_x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, -3), b.min_y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 2), b.min_z, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 6), b.max_x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, -2), b.max_y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 3), b.max_z, 0.001);
}

test "fromCenterSize: produces correct extents" {
    const a = AABB.fromCenterSize(5, 10, 3, 2, 4, 6);
    try std.testing.expectApproxEqAbs(@as(f32, 4), a.min_x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 8), a.min_y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), a.min_z, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 6), a.max_x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 12), a.max_y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 6), a.max_z, 0.001);
}

test "expand: positive direction grows max" {
    const a = AABB{ .min_x = 0, .min_y = 0, .min_z = 0, .max_x = 1, .max_y = 1, .max_z = 1 };
    const b = a.expand(2, 0, 0);
    try std.testing.expectApproxEqAbs(@as(f32, 0), b.min_x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 3), b.max_x, 0.001);
}

test "expand: negative direction grows min" {
    const a = AABB{ .min_x = 0, .min_y = 0, .min_z = 0, .max_x = 1, .max_y = 1, .max_z = 1 };
    const b = a.expand(-2, 0, 0);
    try std.testing.expectApproxEqAbs(@as(f32, -2), b.min_x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1), b.max_x, 0.001);
}
