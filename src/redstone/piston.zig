/// Piston mechanics: extension/retraction of piston blocks based on
/// redstone signal. Can push up to 12 blocks in a line.
/// Full wiring requires redstone signal detection (future integration).

const std = @import("std");

pub const PistonType = enum {
    normal,
    sticky,
};

pub const PistonState = struct {
    piston_type: PistonType,
    extended: bool,
    facing: Direction,

    pub fn init(piston_type: PistonType, facing: Direction) PistonState {
        return .{
            .piston_type = piston_type,
            .extended = false,
            .facing = facing,
        };
    }

    /// Attempt to extend the piston. Returns true if extension is possible.
    /// In the full system this would check for pushable blocks.
    pub fn extend(self: *PistonState) bool {
        if (self.extended) return false;
        self.extended = true;
        return true;
    }

    /// Attempt to retract the piston. Returns true if retraction occurred.
    /// Sticky pistons pull the adjacent block on retraction.
    pub fn retract(self: *PistonState) bool {
        if (!self.extended) return false;
        self.extended = false;
        return true;
    }

    /// Whether this piston can pull blocks on retraction.
    pub fn canPull(self: *const PistonState) bool {
        return self.piston_type == .sticky;
    }
};

pub const Direction = enum {
    up,
    down,
    north,
    south,
    east,
    west,

    /// Get the block offset for this direction.
    pub fn offset(self: Direction) struct { dx: i32, dy: i32, dz: i32 } {
        return switch (self) {
            .up => .{ .dx = 0, .dy = 1, .dz = 0 },
            .down => .{ .dx = 0, .dy = -1, .dz = 0 },
            .north => .{ .dx = 0, .dy = 0, .dz = -1 },
            .south => .{ .dx = 0, .dy = 0, .dz = 1 },
            .east => .{ .dx = 1, .dy = 0, .dz = 0 },
            .west => .{ .dx = -1, .dy = 0, .dz = 0 },
        };
    }
};

/// Maximum number of blocks a piston can push.
pub const MAX_PUSH_BLOCKS = 12;

/// Check whether a block ID is pushable by a piston.
/// Bedrock, obsidian, and other immovable blocks return false.
pub fn isPushable(block_id: u8) bool {
    // Block IDs: 0=air, 11=bedrock, 19=obsidian
    return switch (block_id) {
        0 => false, // air -- nothing to push
        11 => false, // bedrock
        19 => false, // obsidian
        else => true,
    };
}

// ──────────────────────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────────────────────

test "PistonState init is retracted" {
    const ps = PistonState.init(.normal, .up);
    try std.testing.expect(!ps.extended);
}

test "extend and retract" {
    var ps = PistonState.init(.normal, .north);
    try std.testing.expect(ps.extend());
    try std.testing.expect(ps.extended);
    try std.testing.expect(!ps.extend()); // already extended
    try std.testing.expect(ps.retract());
    try std.testing.expect(!ps.extended);
    try std.testing.expect(!ps.retract()); // already retracted
}

test "sticky piston can pull" {
    const sticky = PistonState.init(.sticky, .up);
    const normal = PistonState.init(.normal, .up);
    try std.testing.expect(sticky.canPull());
    try std.testing.expect(!normal.canPull());
}

test "isPushable rejects bedrock and obsidian" {
    try std.testing.expect(!isPushable(0)); // air
    try std.testing.expect(!isPushable(11)); // bedrock
    try std.testing.expect(!isPushable(19)); // obsidian
    try std.testing.expect(isPushable(1)); // stone
    try std.testing.expect(isPushable(2)); // dirt
}

test "Direction offsets are unit vectors" {
    const dirs = [_]Direction{ .up, .down, .north, .south, .east, .west };
    for (dirs) |d| {
        const o = d.offset();
        const mag = @abs(o.dx) + @abs(o.dy) + @abs(o.dz);
        try std.testing.expectEqual(@as(i32, 1), mag);
    }
}
