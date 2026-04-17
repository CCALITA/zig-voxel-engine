const std = @import("std");

pub const StatType = enum(u8) {
    blocks_mined = 0,
    blocks_placed = 1,
    mobs_killed = 2,
    deaths = 3,
    distance_walked = 4,
    distance_sprinted = 5,
    jumps = 6,
    items_crafted = 7,
    items_smelted = 8,
    fish_caught = 9,
    play_time_seconds = 10,
    damage_dealt = 11,
    damage_taken = 12,
};

const stat_count = 13;

pub const StatTracker = struct {
    stats: [stat_count]u64,
    /// Fractional seconds accumulator for sub-second play time deltas.
    play_time_accumulator: f32 = 0.0,

    pub fn init() StatTracker {
        return .{
            .stats = [_]u64{0} ** stat_count,
        };
    }

    pub fn increment(self: *StatTracker, stat: StatType, amount: u64) void {
        self.stats[@intFromEnum(stat)] += amount;
    }

    pub fn get(self: *const StatTracker, stat: StatType) u64 {
        return self.stats[@intFromEnum(stat)];
    }

    /// Adds walked or sprinted distance from a horizontal displacement.
    /// Distance is computed as the Euclidean length of (dx, dz).
    pub fn addDistance(self: *StatTracker, dx: f32, dz: f32, sprinting: bool) void {
        const dist = @sqrt(dx * dx + dz * dz);
        const whole: u64 = @intFromFloat(dist);
        if (whole == 0) return;
        const stat: StatType = if (sprinting) .distance_sprinted else .distance_walked;
        self.increment(stat, whole);
    }

    /// Accumulates fractional seconds and flushes whole seconds to the stat.
    pub fn addPlayTime(self: *StatTracker, dt: f32) void {
        self.play_time_accumulator += dt;
        const whole: u64 = @intFromFloat(self.play_time_accumulator);
        if (whole > 0) {
            self.increment(.play_time_seconds, whole);
            self.play_time_accumulator -= @floatFromInt(whole);
        }
    }
};

pub const DisplayMode = enum { sidebar, below_name, player_list };

const max_name_len = 32;

pub const Objective = struct {
    name: [max_name_len]u8,
    name_len: u8,
    stat: StatType,
    display_mode: DisplayMode,

    fn nameSlice(self: *const Objective) []const u8 {
        return self.name[0..self.name_len];
    }
};

const max_objectives = 8;

pub const Scoreboard = struct {
    objectives: [max_objectives]?Objective,

    pub fn init() Scoreboard {
        return .{
            .objectives = [_]?Objective{null} ** max_objectives,
        };
    }

    /// Adds an objective. Returns false if the name is empty, too long,
    /// already exists, or the board is full.
    pub fn addObjective(self: *Scoreboard, name: []const u8, stat: StatType, mode: DisplayMode) bool {
        if (name.len == 0 or name.len > max_name_len) return false;

        // Single pass: reject duplicates and find the first empty slot.
        var first_empty: ?*?Objective = null;
        for (&self.objectives) |*slot| {
            if (slot.*) |*obj| {
                if (std.mem.eql(u8, obj.nameSlice(), name)) return false;
            } else if (first_empty == null) {
                first_empty = slot;
            }
        }

        const target = first_empty orelse return false; // board full
        var obj: Objective = .{
            .name = [_]u8{0} ** max_name_len,
            .name_len = @intCast(name.len),
            .stat = stat,
            .display_mode = mode,
        };
        @memcpy(obj.name[0..name.len], name);
        target.* = obj;
        return true;
    }

    /// Removes the objective with the given name. Returns false if not found.
    pub fn removeObjective(self: *Scoreboard, name: []const u8) bool {
        for (&self.objectives) |*slot| {
            if (slot.*) |*obj| {
                if (std.mem.eql(u8, obj.nameSlice(), name)) {
                    slot.* = null;
                    return true;
                }
            }
        }
        return false;
    }

    /// Returns a copy of the objective with the given name, or null.
    pub fn getObjective(self: *const Scoreboard, name: []const u8) ?Objective {
        for (&self.objectives) |*slot| {
            if (slot.*) |*obj| {
                if (std.mem.eql(u8, obj.nameSlice(), name)) return obj.*;
            }
        }
        return null;
    }
};

// ──────────────────────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────────────────────

test "StatTracker init returns all zeros" {
    const tracker = StatTracker.init();
    for (tracker.stats) |v| {
        try std.testing.expectEqual(@as(u64, 0), v);
    }
}

test "increment and get round-trip" {
    var tracker = StatTracker.init();
    tracker.increment(.blocks_mined, 5);
    tracker.increment(.blocks_mined, 3);
    try std.testing.expectEqual(@as(u64, 8), tracker.get(.blocks_mined));
    try std.testing.expectEqual(@as(u64, 0), tracker.get(.deaths));
}

test "increment all stat types" {
    var tracker = StatTracker.init();
    inline for (0..stat_count) |i| {
        const stat: StatType = @enumFromInt(i);
        tracker.increment(stat, @as(u64, i) + 1);
        try std.testing.expectEqual(@as(u64, i + 1), tracker.get(stat));
    }
}

test "addDistance walking" {
    var tracker = StatTracker.init();
    // 3-4-5 triangle: distance = 5
    tracker.addDistance(3.0, 4.0, false);
    try std.testing.expectEqual(@as(u64, 5), tracker.get(.distance_walked));
    try std.testing.expectEqual(@as(u64, 0), tracker.get(.distance_sprinted));
}

test "addDistance sprinting" {
    var tracker = StatTracker.init();
    tracker.addDistance(3.0, 4.0, true);
    try std.testing.expectEqual(@as(u64, 0), tracker.get(.distance_walked));
    try std.testing.expectEqual(@as(u64, 5), tracker.get(.distance_sprinted));
}

test "addDistance ignores tiny movements" {
    var tracker = StatTracker.init();
    tracker.addDistance(0.1, 0.1, false);
    try std.testing.expectEqual(@as(u64, 0), tracker.get(.distance_walked));
}

test "addPlayTime accumulates fractional seconds" {
    var tracker = StatTracker.init();
    tracker.addPlayTime(0.3);
    try std.testing.expectEqual(@as(u64, 0), tracker.get(.play_time_seconds));

    tracker.addPlayTime(0.8); // total 1.1
    try std.testing.expectEqual(@as(u64, 1), tracker.get(.play_time_seconds));

    tracker.addPlayTime(2.5); // total 3.6
    try std.testing.expectEqual(@as(u64, 3), tracker.get(.play_time_seconds));
}

test "Scoreboard init has no objectives" {
    const board = Scoreboard.init();
    for (board.objectives) |slot| {
        try std.testing.expect(slot == null);
    }
}

test "addObjective and getObjective" {
    var board = Scoreboard.init();
    try std.testing.expect(board.addObjective("kills", .mobs_killed, .sidebar));

    const obj = board.getObjective("kills").?;
    try std.testing.expect(std.mem.eql(u8, obj.nameSlice(), "kills"));
    try std.testing.expectEqual(StatType.mobs_killed, obj.stat);
    try std.testing.expectEqual(DisplayMode.sidebar, obj.display_mode);
}

test "getObjective returns null for missing name" {
    const board = Scoreboard.init();
    try std.testing.expect(board.getObjective("nope") == null);
}

test "addObjective rejects duplicate names" {
    var board = Scoreboard.init();
    try std.testing.expect(board.addObjective("kills", .mobs_killed, .sidebar));
    try std.testing.expect(!board.addObjective("kills", .deaths, .below_name));
}

test "addObjective rejects empty and oversized names" {
    var board = Scoreboard.init();
    try std.testing.expect(!board.addObjective("", .deaths, .sidebar));

    const long_name = "a" ** 33;
    try std.testing.expect(!board.addObjective(long_name, .deaths, .sidebar));
}

test "addObjective fails when board is full" {
    var board = Scoreboard.init();
    for (0..8) |i| {
        var buf: [8]u8 = undefined;
        const name = std.fmt.bufPrint(&buf, "obj{d}", .{i}) catch unreachable;
        try std.testing.expect(board.addObjective(name, .deaths, .sidebar));
    }
    try std.testing.expect(!board.addObjective("overflow", .deaths, .sidebar));
}

test "removeObjective succeeds for existing" {
    var board = Scoreboard.init();
    try std.testing.expect(board.addObjective("kills", .mobs_killed, .sidebar));
    try std.testing.expect(board.removeObjective("kills"));
    try std.testing.expect(board.getObjective("kills") == null);
}

test "removeObjective fails for missing" {
    var board = Scoreboard.init();
    try std.testing.expect(!board.removeObjective("nope"));
}

test "slot reuse after removeObjective" {
    var board = Scoreboard.init();
    // Fill all slots
    for (0..8) |i| {
        var buf: [8]u8 = undefined;
        const name = std.fmt.bufPrint(&buf, "obj{d}", .{i}) catch unreachable;
        try std.testing.expect(board.addObjective(name, .deaths, .sidebar));
    }
    // Remove one and add a new one
    try std.testing.expect(board.removeObjective("obj3"));
    try std.testing.expect(board.addObjective("new_obj", .jumps, .player_list));

    const obj = board.getObjective("new_obj").?;
    try std.testing.expectEqual(StatType.jumps, obj.stat);
}
