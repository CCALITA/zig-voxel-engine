/// Interactive block logic for beds, doors, ladders, chests, and trapdoors.
/// Provides interaction type detection, execution, and block state helpers.
const std = @import("std");
const block = @import("block.zig");

// ---------------------------------------------------------------------------
// Interaction types and results
// ---------------------------------------------------------------------------

pub const InteractionType = enum {
    none,
    toggle_door,
    sleep_bed,
    climb_ladder,
    open_chest,
    toggle_trapdoor,
};

pub const SpawnPoint = struct {
    x: i32,
    y: i32,
    z: i32,
};

pub const InteractionResult = struct {
    interaction: InteractionType,
    success: bool,
    set_time: ?u32 = null,
    spawn_point: ?SpawnPoint = null,
    climb_speed: ?f32 = null,
    open_inventory: bool = false,
};

// ---------------------------------------------------------------------------
// Core interaction functions
// ---------------------------------------------------------------------------

/// Check what interaction a block supports.
pub fn getInteraction(block_id: block.BlockId) InteractionType {
    return switch (block_id) {
        block.DOOR => .toggle_door,
        block.BED => .sleep_bed,
        block.LADDER => .climb_ladder,
        block.CHEST => .open_chest,
        block.TRAPDOOR => .toggle_trapdoor,
        else => .none,
    };
}

/// Execute the interaction for a block.
/// For beds, `is_night` must be true for sleep to succeed.
pub fn interact(block_id: block.BlockId, is_night: bool) InteractionResult {
    return switch (block_id) {
        block.DOOR => .{
            .interaction = .toggle_door,
            .success = true,
        },
        block.BED => interactBed(is_night),
        block.LADDER => .{
            .interaction = .climb_ladder,
            .success = true,
            .climb_speed = ladder_climb_speed,
        },
        block.CHEST => .{
            .interaction = .open_chest,
            .success = true,
            .open_inventory = true,
        },
        block.TRAPDOOR => .{
            .interaction = .toggle_trapdoor,
            .success = true,
        },
        else => .{
            .interaction = .none,
            .success = false,
        },
    };
}

fn interactBed(is_night: bool) InteractionResult {
    if (!is_night) {
        return .{
            .interaction = .sleep_bed,
            .success = false,
        };
    }
    return .{
        .interaction = .sleep_bed,
        .success = true,
        .set_time = 0,
        .spawn_point = .{ .x = 0, .y = 64, .z = 0 },
    };
}

// ---------------------------------------------------------------------------
// Block state helpers
// ---------------------------------------------------------------------------

pub const DoorState = struct {
    open: bool,
    facing: u2, // 0=N, 1=E, 2=S, 3=W

    pub fn toggle(self: DoorState) DoorState {
        return .{
            .open = !self.open,
            .facing = self.facing,
        };
    }
};

pub const BedState = struct {
    occupied: bool,
    head: bool, // true = head part, false = foot part
    facing: u2,
};

// ---------------------------------------------------------------------------
// Ladder climbing
// ---------------------------------------------------------------------------

const ladder_climb_speed: f32 = 2.35;
const ladder_sneak_speed: f32 = 0.0;
const ladder_descend_speed: f32 = -0.6;

/// Returns climb velocity when a player is against a ladder block.
/// Positive = up, negative = down, zero = hold position.
pub fn getLadderClimbSpeed(pressing_forward: bool, pressing_sneak: bool) f32 {
    if (pressing_sneak) return ladder_sneak_speed;
    if (pressing_forward) return ladder_climb_speed;
    return ladder_descend_speed;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "door toggles between open and closed" {
    const closed = DoorState{ .open = false, .facing = 0 };
    const opened = closed.toggle();
    try std.testing.expect(opened.open);
    try std.testing.expectEqual(@as(u2, 0), opened.facing);

    const closed_again = opened.toggle();
    try std.testing.expect(!closed_again.open);
}

test "door interaction succeeds" {
    const result = interact(block.DOOR, false);
    try std.testing.expectEqual(InteractionType.toggle_door, result.interaction);
    try std.testing.expect(result.success);
}

test "bed sleep succeeds at night" {
    const result = interact(block.BED, true);
    try std.testing.expectEqual(InteractionType.sleep_bed, result.interaction);
    try std.testing.expect(result.success);
    try std.testing.expectEqual(@as(u32, 0), result.set_time.?);
    try std.testing.expect(result.spawn_point != null);
}

test "bed sleep fails during day" {
    const result = interact(block.BED, false);
    try std.testing.expectEqual(InteractionType.sleep_bed, result.interaction);
    try std.testing.expect(!result.success);
    try std.testing.expect(result.set_time == null);
    try std.testing.expect(result.spawn_point == null);
}

test "ladder climb speed when pressing forward" {
    const speed = getLadderClimbSpeed(true, false);
    try std.testing.expect(speed > 0.0);
    try std.testing.expect(@abs(speed - 2.35) < 0.001);
}

test "ladder hold position when sneaking" {
    const speed = getLadderClimbSpeed(false, true);
    try std.testing.expect(@abs(speed) < 0.001);
}

test "ladder descend slowly when idle" {
    const speed = getLadderClimbSpeed(false, false);
    try std.testing.expect(speed < 0.0);
}

test "ladder sneak overrides forward" {
    const speed = getLadderClimbSpeed(true, true);
    try std.testing.expect(@abs(speed) < 0.001);
}

test "chest opens inventory" {
    const result = interact(block.CHEST, false);
    try std.testing.expectEqual(InteractionType.open_chest, result.interaction);
    try std.testing.expect(result.success);
    try std.testing.expect(result.open_inventory);
}

test "trapdoor toggles" {
    const result = interact(block.TRAPDOOR, false);
    try std.testing.expectEqual(InteractionType.toggle_trapdoor, result.interaction);
    try std.testing.expect(result.success);
}

test "non-interactive block returns none" {
    const result = interact(block.STONE, false);
    try std.testing.expectEqual(InteractionType.none, result.interaction);
    try std.testing.expect(!result.success);
}

test "getInteraction maps block IDs correctly" {
    try std.testing.expectEqual(InteractionType.toggle_door, getInteraction(block.DOOR));
    try std.testing.expectEqual(InteractionType.sleep_bed, getInteraction(block.BED));
    try std.testing.expectEqual(InteractionType.climb_ladder, getInteraction(block.LADDER));
    try std.testing.expectEqual(InteractionType.open_chest, getInteraction(block.CHEST));
    try std.testing.expectEqual(InteractionType.toggle_trapdoor, getInteraction(block.TRAPDOOR));
    try std.testing.expectEqual(InteractionType.none, getInteraction(block.AIR));
}

test "bed state tracks head and foot" {
    const head = BedState{ .occupied = false, .head = true, .facing = 2 };
    const foot = BedState{ .occupied = false, .head = false, .facing = 2 };
    try std.testing.expect(head.head);
    try std.testing.expect(!foot.head);
    try std.testing.expectEqual(@as(u2, 2), head.facing);
}

test "door state preserves facing on toggle" {
    const door = DoorState{ .open = false, .facing = 3 };
    const toggled = door.toggle();
    try std.testing.expectEqual(@as(u2, 3), toggled.facing);
    try std.testing.expect(toggled.open);
}
