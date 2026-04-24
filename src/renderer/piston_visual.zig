const std = @import("std");

/// Visual state for an animated piston block.
/// Tracks extension amount and computes spatial offsets for the piston head
/// and any block being pushed, based on a facing direction encoded as a u3.
///
/// Facing encoding:
///   0 = -X, 1 = +X, 2 = -Y, 3 = +Y, 4 = -Z, 5 = +Z
pub const PistonVisual = struct {
    extension: f32 = 0,
    target: f32 = 0,
    facing: u3 = 0,

    /// Animation speed: full stroke in 0.15 s  =>  1 / 0.15 = 6.666... per second.
    const speed: f32 = 1.0 / 0.15;

    /// Begin extending the piston.
    pub fn extend(self: *PistonVisual) void {
        self.target = 1;
    }

    /// Begin retracting the piston.
    pub fn retract(self: *PistonVisual) void {
        self.target = 0;
    }

    /// Advance animation by `dt` seconds, moving `extension` toward `target`.
    pub fn update(self: *PistonVisual, dt: f32) void {
        if (self.extension < self.target) {
            self.extension = @min(self.extension + speed * dt, self.target);
        } else if (self.extension > self.target) {
            self.extension = @max(self.extension - speed * dt, self.target);
        }
    }

    /// Unit direction vector for the current facing.
    fn directionVector(self: PistonVisual) [3]f32 {
        return switch (self.facing) {
            0 => .{ -1, 0, 0 },
            1 => .{ 1, 0, 0 },
            2 => .{ 0, -1, 0 },
            3 => .{ 0, 1, 0 },
            4 => .{ 0, 0, -1 },
            5 => .{ 0, 0, 1 },
            else => .{ 0, 0, 0 },
        };
    }

    /// Scale the facing direction by `t`.
    fn scaledDir(self: PistonVisual, t: f32) [3]f32 {
        const d = self.directionVector();
        return .{ d[0] * t, d[1] * t, d[2] * t };
    }

    /// Offset of the piston head from the base block, in world units.
    pub fn getHeadOffset(self: PistonVisual) [3]f32 {
        return self.scaledDir(self.extension);
    }

    /// Offset of a pushed block — one full block ahead of the head.
    pub fn getPushedBlockOffset(self: PistonVisual) [3]f32 {
        return self.scaledDir(self.extension + 1);
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

const expectEqual = std.testing.expectEqual;
const expectApproxEqAbs = std.testing.expectApproxEqAbs;
const eps = 1e-5;

test "default state is fully retracted" {
    const p = PistonVisual{};
    try expectEqual(@as(f32, 0), p.extension);
    try expectEqual(@as(f32, 0), p.target);
    try expectEqual(@as(u3, 0), p.facing);
}

test "extend sets target to 1" {
    var p = PistonVisual{};
    p.extend();
    try expectEqual(@as(f32, 1), p.target);
    try expectEqual(@as(f32, 0), p.extension);
}

test "retract sets target to 0" {
    var p = PistonVisual{ .extension = 1, .target = 1 };
    p.retract();
    try expectEqual(@as(f32, 0), p.target);
}

test "update moves extension toward target" {
    var p = PistonVisual{};
    p.extend();
    p.update(0.05);
    // 6.667 * 0.05 ≈ 0.3333
    try expectApproxEqAbs(@as(f32, 1.0 / 3.0), p.extension, eps);
}

test "update clamps extension at target when extending" {
    var p = PistonVisual{};
    p.extend();
    p.update(1.0); // way past 0.15 s
    try expectEqual(@as(f32, 1), p.extension);
}

test "update retracts toward zero" {
    var p = PistonVisual{ .extension = 1, .target = 0 };
    p.update(0.05);
    try expectApproxEqAbs(@as(f32, 1.0 - 1.0 / 3.0), p.extension, eps);
}

test "update clamps extension at zero when retracting" {
    var p = PistonVisual{ .extension = 0.5, .target = 0 };
    p.update(1.0);
    try expectEqual(@as(f32, 0), p.extension);
}

test "full extend then full retract cycle" {
    var p = PistonVisual{};
    p.extend();
    // Step to full extension in 0.15 s
    p.update(0.15);
    try expectApproxEqAbs(@as(f32, 1.0), p.extension, eps);
    p.retract();
    p.update(0.15);
    try expectApproxEqAbs(@as(f32, 0.0), p.extension, eps);
}

test "getHeadOffset positive X fully extended" {
    const p = PistonVisual{ .extension = 1, .facing = 1 };
    const off = p.getHeadOffset();
    try expectApproxEqAbs(@as(f32, 1), off[0], eps);
    try expectApproxEqAbs(@as(f32, 0), off[1], eps);
    try expectApproxEqAbs(@as(f32, 0), off[2], eps);
}

test "getHeadOffset negative Y half extended" {
    const p = PistonVisual{ .extension = 0.5, .facing = 2 };
    const off = p.getHeadOffset();
    try expectApproxEqAbs(@as(f32, 0), off[0], eps);
    try expectApproxEqAbs(@as(f32, -0.5), off[1], eps);
    try expectApproxEqAbs(@as(f32, 0), off[2], eps);
}

test "getPushedBlockOffset positive Z fully extended" {
    const p = PistonVisual{ .extension = 1, .facing = 5 };
    const off = p.getPushedBlockOffset();
    try expectApproxEqAbs(@as(f32, 0), off[0], eps);
    try expectApproxEqAbs(@as(f32, 0), off[1], eps);
    try expectApproxEqAbs(@as(f32, 2), off[2], eps);
}

test "getPushedBlockOffset retracted is 1 block ahead" {
    const p = PistonVisual{ .extension = 0, .facing = 0 };
    const off = p.getPushedBlockOffset();
    try expectApproxEqAbs(@as(f32, -1), off[0], eps);
    try expectApproxEqAbs(@as(f32, 0), off[1], eps);
    try expectApproxEqAbs(@as(f32, 0), off[2], eps);
}

test "no motion when already at target" {
    var p = PistonVisual{ .extension = 1, .target = 1 };
    p.update(0.1);
    try expectEqual(@as(f32, 1), p.extension);
}

test "all six facing directions produce unit vectors" {
    const facings = [_]u3{ 0, 1, 2, 3, 4, 5 };
    for (facings) |f| {
        const p = PistonVisual{ .extension = 1, .facing = f };
        const off = p.getHeadOffset();
        const len = @sqrt(off[0] * off[0] + off[1] * off[1] + off[2] * off[2]);
        try expectApproxEqAbs(@as(f32, 1), len, eps);
    }
}
