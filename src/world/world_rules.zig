/// World rules for the voxel engine.
/// Manages difficulty settings, world border, spawn points, and
/// gameplay modifiers (mob damage, hunger, hostile spawning).
/// Also provides a respawn anchor with glowstone charges.
const std = @import("std");

pub const Difficulty = enum {
    peaceful,
    easy,
    normal,
    hard,
};

pub const Pos3 = struct { x: i32, y: i32, z: i32 };

pub const WorldRules = struct {
    difficulty: Difficulty = .normal,
    world_border_radius: f32 = 30_000_000,
    spawn_x: i32 = 0,
    spawn_y: i32 = 70,
    spawn_z: i32 = 0,
    bed_spawn: ?Pos3 = null,

    /// Create a new WorldRules with default values.
    pub fn init() WorldRules {
        return .{};
    }

    /// Set the difficulty level.
    pub fn setDifficulty(self: *WorldRules, diff: Difficulty) void {
        self.difficulty = diff;
    }

    /// Returns true when the given (x, z) position lies outside the world border.
    pub fn isOutsideBorder(self: *const WorldRules, x: f32, z: f32) bool {
        return @abs(x) > self.world_border_radius or
            @abs(z) > self.world_border_radius;
    }

    /// Returns damage per tick for positions outside the border.
    /// 0 inside the border, scales linearly with distance outside.
    pub fn getBorderDamage(self: *const WorldRules, x: f32, z: f32) f32 {
        const dx = @max(@abs(x) - self.world_border_radius, 0.0);
        const dz = @max(@abs(z) - self.world_border_radius, 0.0);
        const dist = @max(dx, dz);
        return dist * damage_per_block;
    }

    /// Returns the active spawn point, preferring the bed spawn if set.
    pub fn getSpawnPoint(self: *const WorldRules) Pos3 {
        return self.bed_spawn orelse .{
            .x = self.spawn_x,
            .y = self.spawn_y,
            .z = self.spawn_z,
        };
    }

    /// Record a bed location as the player's respawn point.
    pub fn setBedSpawn(self: *WorldRules, x: i32, y: i32, z: i32) void {
        self.bed_spawn = .{ .x = x, .y = y, .z = z };
    }

    /// Mob damage multiplier based on difficulty.
    /// peaceful=0, easy=0.5, normal=1, hard=1.5
    pub fn getMobDamageMultiplier(self: *const WorldRules) f32 {
        return switch (self.difficulty) {
            .peaceful => 0.0,
            .easy => 0.5,
            .normal => 1.0,
            .hard => 1.5,
        };
    }

    /// Whether hostile mobs should spawn. False on peaceful.
    pub fn shouldSpawnHostile(self: *const WorldRules) bool {
        return self.difficulty != .peaceful;
    }

    /// Whether the hunger bar should drain. False on peaceful.
    pub fn getHungerDrain(self: *const WorldRules) bool {
        return self.difficulty != .peaceful;
    }

    // -- Constants ------------------------------------------------------------

    /// Damage per block outside the world border, per tick.
    const damage_per_block: f32 = 0.2;
};

pub const RespawnAnchor = struct {
    charges: u8 = 0,
    x: i32,
    y: i32,
    z: i32,

    /// Maximum number of charges a respawn anchor can hold.
    const max_charges: u8 = 4;

    /// Create a new uncharged respawn anchor at the given position.
    pub fn init(x: i32, y: i32, z: i32) RespawnAnchor {
        return .{ .charges = 0, .x = x, .y = y, .z = z };
    }

    /// Add one charge (glowstone). Returns true on success, false if already full.
    pub fn charge(self: *RespawnAnchor) bool {
        if (self.charges >= max_charges) return false;
        self.charges += 1;
        return true;
    }

    /// Consume one charge on respawn. Returns false if empty.
    pub fn useCharge(self: *RespawnAnchor) bool {
        if (self.charges == 0) return false;
        self.charges -= 1;
        return true;
    }

    /// Current number of charges (0-4).
    pub fn getCharges(self: *const RespawnAnchor) u8 {
        return self.charges;
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "init returns default world rules" {
    const wr = WorldRules.init();
    try std.testing.expectEqual(Difficulty.normal, wr.difficulty);
    try std.testing.expectApproxEqAbs(@as(f32, 30_000_000), wr.world_border_radius, 1.0);
    try std.testing.expectEqual(@as(i32, 0), wr.spawn_x);
    try std.testing.expectEqual(@as(i32, 70), wr.spawn_y);
    try std.testing.expectEqual(@as(i32, 0), wr.spawn_z);
    try std.testing.expect(wr.bed_spawn == null);
}

test "position inside border is not outside" {
    const wr = WorldRules{ .world_border_radius = 100.0 };
    try std.testing.expect(!wr.isOutsideBorder(50.0, 50.0));
    try std.testing.expect(!wr.isOutsideBorder(-100.0, 100.0));
    try std.testing.expect(!wr.isOutsideBorder(0.0, 0.0));
}

test "position outside border is detected" {
    const wr = WorldRules{ .world_border_radius = 100.0 };
    try std.testing.expect(wr.isOutsideBorder(101.0, 0.0));
    try std.testing.expect(wr.isOutsideBorder(0.0, -101.0));
    try std.testing.expect(wr.isOutsideBorder(200.0, 200.0));
}

test "border damage is zero inside" {
    const wr = WorldRules{ .world_border_radius = 100.0 };
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), wr.getBorderDamage(50.0, 50.0), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), wr.getBorderDamage(100.0, 100.0), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), wr.getBorderDamage(-80.0, 0.0), 0.001);
}

test "border damage scales with distance outside" {
    const wr = WorldRules{ .world_border_radius = 100.0 };
    // 10 blocks outside on x axis
    const dmg_10 = wr.getBorderDamage(110.0, 0.0);
    // 20 blocks outside on x axis
    const dmg_20 = wr.getBorderDamage(120.0, 0.0);
    try std.testing.expect(dmg_10 > 0.0);
    try std.testing.expect(dmg_20 > dmg_10);
    // 10 blocks * 0.2 = 2.0
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), dmg_10, 0.001);
    // 20 blocks * 0.2 = 4.0
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), dmg_20, 0.001);
}

test "border damage works with negative coordinates" {
    const wr = WorldRules{ .world_border_radius = 100.0 };
    const dmg = wr.getBorderDamage(-115.0, 0.0);
    // 15 blocks outside * 0.2 = 3.0
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), dmg, 0.001);
}

test "difficulty multipliers for all levels" {
    const cases = [_]struct { diff: Difficulty, expected: f32 }{
        .{ .diff = .peaceful, .expected = 0.0 },
        .{ .diff = .easy, .expected = 0.5 },
        .{ .diff = .normal, .expected = 1.0 },
        .{ .diff = .hard, .expected = 1.5 },
    };
    for (cases) |c| {
        const wr = WorldRules{ .difficulty = c.diff };
        try std.testing.expectApproxEqAbs(c.expected, wr.getMobDamageMultiplier(), 0.001);
    }
}

test "setDifficulty changes difficulty" {
    var wr = WorldRules.init();
    try std.testing.expectEqual(Difficulty.normal, wr.difficulty);
    wr.setDifficulty(.hard);
    try std.testing.expectEqual(Difficulty.hard, wr.difficulty);
    try std.testing.expectApproxEqAbs(@as(f32, 1.5), wr.getMobDamageMultiplier(), 0.001);
}

test "hostile mobs spawn on non-peaceful difficulties" {
    try std.testing.expect(!(WorldRules{ .difficulty = .peaceful }).shouldSpawnHostile());
    try std.testing.expect((WorldRules{ .difficulty = .easy }).shouldSpawnHostile());
    try std.testing.expect((WorldRules{ .difficulty = .normal }).shouldSpawnHostile());
    try std.testing.expect((WorldRules{ .difficulty = .hard }).shouldSpawnHostile());
}

test "hunger drains on non-peaceful difficulties" {
    try std.testing.expect(!(WorldRules{ .difficulty = .peaceful }).getHungerDrain());
    try std.testing.expect((WorldRules{ .difficulty = .easy }).getHungerDrain());
    try std.testing.expect((WorldRules{ .difficulty = .normal }).getHungerDrain());
    try std.testing.expect((WorldRules{ .difficulty = .hard }).getHungerDrain());
}

test "spawn point returns default without bed" {
    const wr = WorldRules.init();
    const sp = wr.getSpawnPoint();
    try std.testing.expectEqual(@as(i32, 0), sp.x);
    try std.testing.expectEqual(@as(i32, 70), sp.y);
    try std.testing.expectEqual(@as(i32, 0), sp.z);
}

test "spawn point returns bed when set" {
    var wr = WorldRules.init();
    wr.setBedSpawn(100, 65, -200);
    const sp = wr.getSpawnPoint();
    try std.testing.expectEqual(@as(i32, 100), sp.x);
    try std.testing.expectEqual(@as(i32, 65), sp.y);
    try std.testing.expectEqual(@as(i32, -200), sp.z);
}

test "respawn anchor starts with zero charges" {
    const anchor = RespawnAnchor.init(10, 20, 30);
    try std.testing.expectEqual(@as(u8, 0), anchor.getCharges());
    try std.testing.expectEqual(@as(i32, 10), anchor.x);
    try std.testing.expectEqual(@as(i32, 20), anchor.y);
    try std.testing.expectEqual(@as(i32, 30), anchor.z);
}

test "respawn anchor charges up to max" {
    var anchor = RespawnAnchor.init(0, 0, 0);
    try std.testing.expect(anchor.charge()); // 1
    try std.testing.expect(anchor.charge()); // 2
    try std.testing.expect(anchor.charge()); // 3
    try std.testing.expect(anchor.charge()); // 4
    try std.testing.expectEqual(@as(u8, 4), anchor.getCharges());
    // Cannot exceed max
    try std.testing.expect(!anchor.charge());
    try std.testing.expectEqual(@as(u8, 4), anchor.getCharges());
}

test "respawn anchor useCharge decrements" {
    var anchor = RespawnAnchor.init(0, 0, 0);
    _ = anchor.charge();
    _ = anchor.charge();
    try std.testing.expectEqual(@as(u8, 2), anchor.getCharges());

    try std.testing.expect(anchor.useCharge());
    try std.testing.expectEqual(@as(u8, 1), anchor.getCharges());

    try std.testing.expect(anchor.useCharge());
    try std.testing.expectEqual(@as(u8, 0), anchor.getCharges());

    // Cannot use when empty
    try std.testing.expect(!anchor.useCharge());
    try std.testing.expectEqual(@as(u8, 0), anchor.getCharges());
}
