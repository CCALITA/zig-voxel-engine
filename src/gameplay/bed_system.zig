const std = @import("std");

pub const Dimension = enum(u2) { overworld, nether, the_end };

pub const BedResult = struct {
    success: bool = false,
    explode: bool = false,
    message: []const u8 = "",
    set_spawn: bool = false,
    skip_night: bool = false,
};

pub const BedState = struct {
    spawn_set: bool = false,
    spawn_x: i32 = 0,
    spawn_y: i32 = 0,
    spawn_z: i32 = 0,

    pub fn init() BedState {
        return .{};
    }

    pub fn interact(self: *BedState, bed_x: i32, bed_y: i32, bed_z: i32, dim: Dimension, is_night: bool, hostile_nearby: bool) BedResult {
        if (dim != .overworld) return .{ .explode = true, .message = "Bed explodes!" };
        if (!is_night) return .{ .message = "You can only sleep at night" };
        if (hostile_nearby) return .{ .message = "Monsters nearby" };

        self.spawn_set = true;
        self.spawn_x = bed_x;
        self.spawn_y = bed_y + 1;
        self.spawn_z = bed_z;

        return .{ .success = true, .set_spawn = true, .skip_night = true };
    }

    pub fn getSpawnPoint(self: BedState) ?struct { x: i32, y: i32, z: i32 } {
        if (!self.spawn_set) return null;
        return .{ .x = self.spawn_x, .y = self.spawn_y, .z = self.spawn_z };
    }

    pub fn clearSpawn(self: *BedState) void {
        self.spawn_set = false;
    }
};

test "init returns default state with no spawn" {
    const state = BedState.init();
    try std.testing.expect(!state.spawn_set);
    try std.testing.expectEqual(@as(i32, 0), state.spawn_x);
    try std.testing.expectEqual(@as(i32, 0), state.spawn_y);
    try std.testing.expectEqual(@as(i32, 0), state.spawn_z);
    try std.testing.expect(state.getSpawnPoint() == null);
}

test "successful sleep in overworld at night" {
    var state = BedState.init();
    const result = state.interact(10, 64, -30, .overworld, true, false);

    try std.testing.expect(result.success);
    try std.testing.expect(!result.explode);
    try std.testing.expect(result.set_spawn);
    try std.testing.expect(result.skip_night);
    try std.testing.expectEqualStrings("", result.message);
}

test "spawn point is set one block above bed" {
    var state = BedState.init();
    _ = state.interact(10, 64, -30, .overworld, true, false);

    const spawn = state.getSpawnPoint().?;
    try std.testing.expectEqual(@as(i32, 10), spawn.x);
    try std.testing.expectEqual(@as(i32, 65), spawn.y);
    try std.testing.expectEqual(@as(i32, -30), spawn.z);
}

test "bed explodes in nether" {
    var state = BedState.init();
    const result = state.interact(0, 100, 0, .nether, true, false);

    try std.testing.expect(result.explode);
    try std.testing.expect(!result.success);
    try std.testing.expect(!result.set_spawn);
    try std.testing.expectEqualStrings("Bed explodes!", result.message);
}

test "bed explodes in the end" {
    var state = BedState.init();
    const result = state.interact(0, 100, 0, .the_end, true, false);

    try std.testing.expect(result.explode);
    try std.testing.expect(!result.success);
    try std.testing.expectEqualStrings("Bed explodes!", result.message);
}

test "cannot sleep during day" {
    var state = BedState.init();
    const result = state.interact(0, 64, 0, .overworld, false, false);

    try std.testing.expect(!result.success);
    try std.testing.expect(!result.explode);
    try std.testing.expectEqualStrings("You can only sleep at night", result.message);
}

test "cannot sleep with hostile mobs nearby" {
    var state = BedState.init();
    const result = state.interact(0, 64, 0, .overworld, true, true);

    try std.testing.expect(!result.success);
    try std.testing.expect(!result.explode);
    try std.testing.expectEqualStrings("Monsters nearby", result.message);
}

test "clearSpawn removes spawn point" {
    var state = BedState.init();
    _ = state.interact(5, 70, 5, .overworld, true, false);
    try std.testing.expect(state.getSpawnPoint() != null);

    state.clearSpawn();
    try std.testing.expect(state.getSpawnPoint() == null);
}

test "interact updates spawn when called multiple times" {
    var state = BedState.init();
    _ = state.interact(1, 10, 1, .overworld, true, false);
    _ = state.interact(99, 200, -99, .overworld, true, false);

    const spawn = state.getSpawnPoint().?;
    try std.testing.expectEqual(@as(i32, 99), spawn.x);
    try std.testing.expectEqual(@as(i32, 201), spawn.y);
    try std.testing.expectEqual(@as(i32, -99), spawn.z);
}

test "explosion does not set spawn" {
    var state = BedState.init();
    _ = state.interact(10, 64, 10, .nether, true, false);

    try std.testing.expect(!state.spawn_set);
    try std.testing.expect(state.getSpawnPoint() == null);
}

test "daytime rejection does not set spawn" {
    var state = BedState.init();
    _ = state.interact(10, 64, 10, .overworld, false, false);

    try std.testing.expect(!state.spawn_set);
}

test "hostile rejection does not set spawn" {
    var state = BedState.init();
    _ = state.interact(10, 64, 10, .overworld, true, true);

    try std.testing.expect(!state.spawn_set);
}

test "dimension priority over night check" {
    var state = BedState.init();
    // In nether during daytime: should still explode (dimension checked first)
    const result = state.interact(0, 64, 0, .nether, false, false);
    try std.testing.expect(result.explode);
    try std.testing.expectEqualStrings("Bed explodes!", result.message);
}

test "negative coordinates work correctly" {
    var state = BedState.init();
    _ = state.interact(-500, -60, -1000, .overworld, true, false);

    const spawn = state.getSpawnPoint().?;
    try std.testing.expectEqual(@as(i32, -500), spawn.x);
    try std.testing.expectEqual(@as(i32, -59), spawn.y);
    try std.testing.expectEqual(@as(i32, -1000), spawn.z);
}
