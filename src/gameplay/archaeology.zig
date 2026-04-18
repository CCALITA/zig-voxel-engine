const std = @import("std");
const loot_tables = @import("loot_tables.zig");

pub const ItemDrop = loot_tables.ItemDrop;

pub const SuspiciousBlockType = enum {
    sand,
    gravel,
};

pub const BrushResult = enum {
    in_progress,
    complete,
    collapsed,
};

pub const BrushState = struct {
    block_type: SuspiciousBlockType,
    progress: u4,
    x: i32,
    y: i32,
    z: i32,

    pub fn brush(self: *BrushState) BrushResult {
        if (self.progress >= 10) return .collapsed;
        self.progress += 1;
        if (self.progress == 10) return .complete;
        return .in_progress;
    }

    pub fn isComplete(self: BrushState) bool {
        return self.progress >= 10;
    }

    pub fn reset(self: *BrushState) void {
        self.progress = 0;
    }
};

// ── Archaeology item IDs ─────────────────────────────────────────────────
const POTTERY_SHERD_ARMS_UP: u16 = 1001;
const POTTERY_SHERD_SKULL: u16 = 1002;
const POTTERY_SHERD_PRIZE: u16 = 1003;
const POTTERY_SHERD_ARCHER: u16 = 1004;
const POTTERY_SHERD_HOWL: u16 = 1005;
const POTTERY_SHERD_SHEAF: u16 = 1006;
const POTTERY_SHERD_MINER: u16 = 1007;
const POTTERY_SHERD_HEART: u16 = 1008;
const ITEM_EMERALD: u16 = 2001;
const ITEM_WHEAT_SEEDS: u16 = 2002;
const ITEM_CLAY_BALL: u16 = 2003;
const ITEM_GOLD_NUGGET: u16 = 2004;
const ITEM_IRON_NUGGET: u16 = 2005;
const ITEM_FLINT: u16 = 2006;
const ITEM_COAL: u16 = 2007;

// ── Loot tables ──────────────────────────────────────────────────────────
const SAND_LOOT = [_]ItemDrop{
    .{ .id = POTTERY_SHERD_ARMS_UP, .count = 1 },
    .{ .id = POTTERY_SHERD_SKULL, .count = 1 },
    .{ .id = POTTERY_SHERD_PRIZE, .count = 1 },
    .{ .id = POTTERY_SHERD_ARCHER, .count = 1 },
    .{ .id = ITEM_EMERALD, .count = 1 },
    .{ .id = ITEM_WHEAT_SEEDS, .count = 4 },
    .{ .id = ITEM_CLAY_BALL, .count = 1 },
    .{ .id = ITEM_GOLD_NUGGET, .count = 1 },
};

const GRAVEL_LOOT = [_]ItemDrop{
    .{ .id = POTTERY_SHERD_HOWL, .count = 1 },
    .{ .id = POTTERY_SHERD_SHEAF, .count = 1 },
    .{ .id = POTTERY_SHERD_MINER, .count = 1 },
    .{ .id = POTTERY_SHERD_HEART, .count = 1 },
    .{ .id = ITEM_IRON_NUGGET, .count = 1 },
    .{ .id = ITEM_FLINT, .count = 1 },
    .{ .id = ITEM_COAL, .count = 1 },
    .{ .id = ITEM_EMERALD, .count = 1 },
};

pub fn getLoot(block_type: SuspiciousBlockType, seed: u64) ItemDrop {
    const table = switch (block_type) {
        .sand => &SAND_LOOT,
        .gravel => &GRAVEL_LOOT,
    };
    const index = seed % table.len;
    return table[index];
}

// ── Tests ────────────────────────────────────────────────────────────────
test "brush increments progress" {
    var state = BrushState{
        .block_type = .sand,
        .progress = 0,
        .x = 10,
        .y = 64,
        .z = -20,
    };
    const result = state.brush();
    try std.testing.expectEqual(BrushResult.in_progress, result);
    try std.testing.expectEqual(@as(u4, 1), state.progress);
}

test "brush completes at progress 10" {
    var state = BrushState{
        .block_type = .gravel,
        .progress = 0,
        .x = 0,
        .y = 0,
        .z = 0,
    };
    var i: u4 = 0;
    while (i < 9) : (i += 1) {
        const result = state.brush();
        try std.testing.expectEqual(BrushResult.in_progress, result);
    }
    const final_result = state.brush();
    try std.testing.expectEqual(BrushResult.complete, final_result);
    try std.testing.expect(state.isComplete());
}

test "brush collapses when already complete" {
    var state = BrushState{
        .block_type = .sand,
        .progress = 10,
        .x = 5,
        .y = 30,
        .z = 5,
    };
    const result = state.brush();
    try std.testing.expectEqual(BrushResult.collapsed, result);
}

test "loot is deterministic for same seed" {
    const loot_a = getLoot(.sand, 42);
    const loot_b = getLoot(.sand, 42);
    try std.testing.expectEqual(loot_a.id, loot_b.id);
    try std.testing.expectEqual(loot_a.count, loot_b.count);
}

test "loot varies by block type" {
    const sand_loot = getLoot(.sand, 0);
    const gravel_loot = getLoot(.gravel, 0);
    try std.testing.expect(sand_loot.id != gravel_loot.id);
}

test "isComplete returns false when progress below 10" {
    const state = BrushState{
        .block_type = .sand,
        .progress = 5,
        .x = 0,
        .y = 0,
        .z = 0,
    };
    try std.testing.expect(!state.isComplete());
}

test "reset sets progress to zero" {
    var state = BrushState{
        .block_type = .gravel,
        .progress = 7,
        .x = 0,
        .y = 0,
        .z = 0,
    };
    state.reset();
    try std.testing.expectEqual(@as(u4, 0), state.progress);
}
