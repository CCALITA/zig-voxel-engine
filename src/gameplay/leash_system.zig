const std = @import("std");

/// Item ID for the lead (leash) item.
pub const LEAD_ITEM: u16 = 310;

/// Distance threshold beyond which a pull force is applied.
const pull_threshold: f32 = 5.0;

/// Represents a leash connection between an entity and an anchor point.
pub const LeashState = struct {
    entity_id: u32 = 0,
    anchor_x: f32 = 0,
    anchor_y: f32 = 0,
    anchor_z: f32 = 0,
    active: bool = false,
    max_distance: f32 = 10.0,

    /// Attach the leash to an entity at the given anchor position.
    pub fn attach(self: *LeashState, id: u32, x: f32, y: f32, z: f32) void {
        self.entity_id = id;
        self.anchor_x = x;
        self.anchor_y = y;
        self.anchor_z = z;
        self.active = true;
    }

    /// Detach the leash, resetting all fields to defaults.
    pub fn detach(self: *LeashState) void {
        self.entity_id = 0;
        self.anchor_x = 0;
        self.anchor_y = 0;
        self.anchor_z = 0;
        self.active = false;
    }

    /// Return the offset vector and Euclidean distance from the entity to
    /// the anchor.  Returns `null` when the leash is inactive.
    fn delta(self: LeashState, ex: f32, ey: f32, ez: f32) ?struct { dx: f32, dy: f32, dz: f32, dist: f32 } {
        if (!self.active) return null;

        const dx = self.anchor_x - ex;
        const dy = self.anchor_y - ey;
        const dz = self.anchor_z - ez;

        return .{
            .dx = dx,
            .dy = dy,
            .dz = dz,
            .dist = @sqrt(dx * dx + dy * dy + dz * dz),
        };
    }

    /// Compute the pull force toward the anchor when the entity is farther
    /// than `pull_threshold` blocks away.  Returns `null` when the leash is
    /// inactive or the entity is close enough that no pull is needed.
    pub fn getPullForce(self: LeashState, ex: f32, ey: f32, ez: f32) ?struct { fx: f32, fy: f32, fz: f32 } {
        const d = self.delta(ex, ey, ez) orelse return null;
        if (d.dist <= pull_threshold) return null;

        // Force magnitude scales linearly with distance beyond the threshold.
        const strength = (d.dist - pull_threshold) / (self.max_distance - pull_threshold);

        return .{
            .fx = d.dx / d.dist * strength,
            .fy = d.dy / d.dist * strength,
            .fz = d.dz / d.dist * strength,
        };
    }

    /// Returns `true` when the entity is farther than `max_distance` from the
    /// anchor and the leash should break.
    pub fn shouldBreak(self: LeashState, ex: f32, ey: f32, ez: f32) bool {
        const d = self.delta(ex, ey, ez) orelse return false;
        return d.dist > self.max_distance;
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "attach sets fields and activates leash" {
    var ls = LeashState{};
    ls.attach(42, 1.0, 2.0, 3.0);

    try std.testing.expectEqual(@as(u32, 42), ls.entity_id);
    try std.testing.expectEqual(@as(f32, 1.0), ls.anchor_x);
    try std.testing.expectEqual(@as(f32, 2.0), ls.anchor_y);
    try std.testing.expectEqual(@as(f32, 3.0), ls.anchor_z);
    try std.testing.expect(ls.active);
}

test "detach resets all fields" {
    var ls = LeashState{};
    ls.attach(7, 5.0, 6.0, 7.0);
    ls.detach();

    try std.testing.expectEqual(@as(u32, 0), ls.entity_id);
    try std.testing.expectEqual(@as(f32, 0), ls.anchor_x);
    try std.testing.expectEqual(@as(f32, 0), ls.anchor_y);
    try std.testing.expectEqual(@as(f32, 0), ls.anchor_z);
    try std.testing.expect(!ls.active);
}

test "getPullForce returns null when inactive" {
    const ls = LeashState{};
    try std.testing.expect(ls.getPullForce(100.0, 100.0, 100.0) == null);
}

test "getPullForce returns null when within pull threshold" {
    var ls = LeashState{};
    ls.attach(1, 0.0, 0.0, 0.0);

    // Entity at distance 3 (< 5 threshold)
    try std.testing.expect(ls.getPullForce(3.0, 0.0, 0.0) == null);
}

test "getPullForce returns null at exactly pull threshold" {
    var ls = LeashState{};
    ls.attach(1, 0.0, 0.0, 0.0);

    try std.testing.expect(ls.getPullForce(5.0, 0.0, 0.0) == null);
}

test "getPullForce returns force when beyond pull threshold" {
    var ls = LeashState{};
    ls.attach(1, 0.0, 0.0, 0.0);

    // Entity at distance 8 along the x-axis (> 5 threshold)
    const force = ls.getPullForce(8.0, 0.0, 0.0);
    try std.testing.expect(force != null);

    const f = force.?;
    // Force should pull toward anchor (negative x direction)
    try std.testing.expect(f.fx < 0);
    try std.testing.expectEqual(@as(f32, 0), f.fy);
    try std.testing.expectEqual(@as(f32, 0), f.fz);
}

test "getPullForce strength increases with distance" {
    var ls = LeashState{};
    ls.attach(1, 0.0, 0.0, 0.0);

    const f1 = ls.getPullForce(6.0, 0.0, 0.0).?;
    const f2 = ls.getPullForce(9.0, 0.0, 0.0).?;

    // Farther entity should have stronger pull (larger magnitude)
    try std.testing.expect(@abs(f2.fx) > @abs(f1.fx));
}

test "getPullForce works in 3D" {
    var ls = LeashState{};
    ls.attach(1, 10.0, 20.0, 30.0);

    // Entity far from anchor in all three axes
    const force = ls.getPullForce(0.0, 0.0, 0.0);
    try std.testing.expect(force != null);

    const f = force.?;
    // Force should point toward anchor (positive direction)
    try std.testing.expect(f.fx > 0);
    try std.testing.expect(f.fy > 0);
    try std.testing.expect(f.fz > 0);
}

test "shouldBreak returns false when inactive" {
    const ls = LeashState{};
    try std.testing.expect(!ls.shouldBreak(100.0, 100.0, 100.0));
}

test "shouldBreak returns false when within max distance" {
    var ls = LeashState{};
    ls.attach(1, 0.0, 0.0, 0.0);

    // Entity at distance 8 (< 10 max_distance)
    try std.testing.expect(!ls.shouldBreak(8.0, 0.0, 0.0));
}

test "shouldBreak returns false at exactly max distance" {
    var ls = LeashState{};
    ls.attach(1, 0.0, 0.0, 0.0);

    // Entity at exactly 10 blocks (== max_distance)
    try std.testing.expect(!ls.shouldBreak(10.0, 0.0, 0.0));
}

test "shouldBreak returns true beyond max distance" {
    var ls = LeashState{};
    ls.attach(1, 0.0, 0.0, 0.0);

    // Entity at distance 11 (> 10 max_distance)
    try std.testing.expect(ls.shouldBreak(11.0, 0.0, 0.0));
}

test "shouldBreak works with custom max distance" {
    var ls = LeashState{ .max_distance = 5.0 };
    ls.attach(1, 0.0, 0.0, 0.0);

    try std.testing.expect(!ls.shouldBreak(4.0, 0.0, 0.0));
    try std.testing.expect(ls.shouldBreak(6.0, 0.0, 0.0));
}

test "LEAD_ITEM constant is 310" {
    try std.testing.expectEqual(@as(u16, 310), LEAD_ITEM);
}

test "attach then detach then re-attach" {
    var ls = LeashState{};
    ls.attach(1, 1.0, 2.0, 3.0);
    ls.detach();
    ls.attach(2, 4.0, 5.0, 6.0);

    try std.testing.expectEqual(@as(u32, 2), ls.entity_id);
    try std.testing.expectEqual(@as(f32, 4.0), ls.anchor_x);
    try std.testing.expect(ls.active);
}

test "shouldBreak 3D diagonal distance" {
    var ls = LeashState{};
    ls.attach(1, 0.0, 0.0, 0.0);

    // sqrt(6^2 + 6^2 + 6^2) = sqrt(108) ~= 10.39 > 10
    try std.testing.expect(ls.shouldBreak(6.0, 6.0, 6.0));

    // sqrt(5^2 + 5^2 + 5^2) = sqrt(75) ~= 8.66 < 10
    try std.testing.expect(!ls.shouldBreak(5.0, 5.0, 5.0));
}
