/// Wolf entity behavior: tamed follow/sit AI and wild pack behavior.
/// Tamed wolves follow their owner within 10 blocks or sit on command.
/// Wild wolves deal 2 damage; tamed wolves deal 4. Wolves defend their
/// owner by targeting any entity that attacks them.
const std = @import("std");

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

pub const WolfState = enum(u2) {
    wild,
    tamed_follow,
    tamed_sit,
};

// ---------------------------------------------------------------------------
// Vec3 helper (integer block coordinates)
// ---------------------------------------------------------------------------

pub const Vec3 = struct {
    x: i32,
    y: i32,
    z: i32,
};

// ---------------------------------------------------------------------------
// Move direction returned by update
// ---------------------------------------------------------------------------

pub const MoveDirection = struct {
    dx: i32,
    dy: i32,
    dz: i32,

    const zero = MoveDirection{ .dx = 0, .dy = 0, .dz = 0 };
};

// ---------------------------------------------------------------------------
// Wolf
// ---------------------------------------------------------------------------

pub const Wolf = struct {
    hp: i32 = 8,
    owner_id: u32 = 0,
    state: WolfState = .wild,
    target_id: u32 = 0,

    // -- Constants --
    const max_hp: i32 = 20;
    const wild_damage: i32 = 2;
    const tamed_damage: i32 = 4;
    const follow_range: i32 = 10;

    /// Tame this wolf, assigning it to `owner`. Sets state to follow and
    /// raises HP to the tamed maximum (20).
    pub fn tame(self: Wolf, owner: u32) Wolf {
        return Wolf{
            .hp = max_hp,
            .owner_id = owner,
            .state = .tamed_follow,
            .target_id = self.target_id,
        };
    }

    /// Toggle between sitting and following for a tamed wolf.
    /// Wild wolves ignore the call and are returned unchanged.
    pub fn toggleSit(self: Wolf) Wolf {
        return switch (self.state) {
            .tamed_follow => self.withStateAndTarget(.tamed_sit, self.target_id),
            .tamed_sit => self.withStateAndTarget(.tamed_follow, self.target_id),
            .wild => self,
        };
    }

    /// Compute a one-step move direction toward the owner.
    /// Returns a unit-step vector (each component is -1, 0, or 1).
    /// Sitting or wild wolves return zero movement.
    pub fn update(self: Wolf, wolf_pos: Vec3, owner_pos: Vec3) MoveDirection {
        if (self.state != .tamed_follow) {
            return MoveDirection.zero;
        }

        const dx = owner_pos.x - wolf_pos.x;
        const dy = owner_pos.y - wolf_pos.y;
        const dz = owner_pos.z - wolf_pos.z;

        // Already close enough -- stay put.
        const dist_sq = dx * dx + dy * dy + dz * dz;
        if (dist_sq <= 4) {
            return MoveDirection.zero;
        }

        return MoveDirection{
            .dx = std.math.sign(dx),
            .dy = std.math.sign(dy),
            .dz = std.math.sign(dz),
        };
    }

    /// React to the owner being attacked: target the attacker and switch
    /// out of sitting. Wild wolves are returned unchanged.
    pub fn onOwnerAttacked(self: Wolf, attacker_id: u32) Wolf {
        if (self.state == .wild) return self;
        return self.withStateAndTarget(.tamed_follow, attacker_id);
    }

    /// Return the damage this wolf deals per attack.
    pub fn getDamage(self: Wolf) i32 {
        return switch (self.state) {
            .wild => wild_damage,
            .tamed_follow, .tamed_sit => tamed_damage,
        };
    }

    /// Return `true` when the given distance (in blocks) is within
    /// follow range.
    pub fn isWithinFollowRange(distance: i32) bool {
        return distance <= follow_range;
    }

    fn withStateAndTarget(self: Wolf, new_state: WolfState, new_target: u32) Wolf {
        return Wolf{
            .hp = self.hp,
            .owner_id = self.owner_id,
            .state = new_state,
            .target_id = new_target,
        };
    }
};

// ===========================================================================
// Tests
// ===========================================================================

test "default wolf is wild with 8 hp" {
    const w = Wolf{};
    try std.testing.expectEqual(WolfState.wild, w.state);
    try std.testing.expectEqual(@as(i32, 8), w.hp);
    try std.testing.expectEqual(@as(u32, 0), w.owner_id);
}

test "tame changes state to tamed_follow and sets owner" {
    const w = Wolf{};
    const tamed = w.tame(42);
    try std.testing.expectEqual(WolfState.tamed_follow, tamed.state);
    try std.testing.expectEqual(@as(u32, 42), tamed.owner_id);
    try std.testing.expectEqual(@as(i32, 20), tamed.hp);
}

test "tame does not mutate original wolf" {
    const w = Wolf{};
    _ = w.tame(42);
    try std.testing.expectEqual(WolfState.wild, w.state);
}

test "toggleSit switches tamed_follow to tamed_sit" {
    const w = (Wolf{}).tame(1);
    const sitting = w.toggleSit();
    try std.testing.expectEqual(WolfState.tamed_sit, sitting.state);
}

test "toggleSit switches tamed_sit back to tamed_follow" {
    const w = (Wolf{}).tame(1).toggleSit();
    const following = w.toggleSit();
    try std.testing.expectEqual(WolfState.tamed_follow, following.state);
}

test "toggleSit is no-op for wild wolf" {
    const w = Wolf{};
    const result = w.toggleSit();
    try std.testing.expectEqual(WolfState.wild, result.state);
}

test "follow moves toward owner within 10 blocks" {
    const w = (Wolf{}).tame(1);
    const wolf_pos = Vec3{ .x = 0, .y = 0, .z = 0 };
    const owner_pos = Vec3{ .x = 8, .y = 0, .z = 0 };
    const dir = w.update(wolf_pos, owner_pos);
    try std.testing.expectEqual(@as(i32, 1), dir.dx);
    try std.testing.expectEqual(@as(i32, 0), dir.dy);
    try std.testing.expectEqual(@as(i32, 0), dir.dz);
}

test "follow stays still when very close to owner" {
    const w = (Wolf{}).tame(1);
    const wolf_pos = Vec3{ .x = 5, .y = 0, .z = 5 };
    const owner_pos = Vec3{ .x = 6, .y = 0, .z = 5 };
    const dir = w.update(wolf_pos, owner_pos);
    try std.testing.expectEqual(@as(i32, 0), dir.dx);
    try std.testing.expectEqual(@as(i32, 0), dir.dy);
    try std.testing.expectEqual(@as(i32, 0), dir.dz);
}

test "sitting wolf does not move" {
    const w = (Wolf{}).tame(1).toggleSit();
    const dir = w.update(Vec3{ .x = 0, .y = 0, .z = 0 }, Vec3{ .x = 10, .y = 0, .z = 0 });
    try std.testing.expectEqual(@as(i32, 0), dir.dx);
}

test "wild wolf getDamage returns 2" {
    const w = Wolf{};
    try std.testing.expectEqual(@as(i32, 2), w.getDamage());
}

test "tamed wolf getDamage returns 4" {
    const w = (Wolf{}).tame(1);
    try std.testing.expectEqual(@as(i32, 4), w.getDamage());
}

test "onOwnerAttacked targets attacker and leaves sit" {
    const w = (Wolf{}).tame(1).toggleSit();
    try std.testing.expectEqual(WolfState.tamed_sit, w.state);
    const defending = w.onOwnerAttacked(99);
    try std.testing.expectEqual(@as(u32, 99), defending.target_id);
    try std.testing.expectEqual(WolfState.tamed_follow, defending.state);
}

test "onOwnerAttacked is no-op for wild wolf" {
    const w = Wolf{};
    const result = w.onOwnerAttacked(99);
    try std.testing.expectEqual(@as(u32, 0), result.target_id);
    try std.testing.expectEqual(WolfState.wild, result.state);
}

test "isWithinFollowRange boundary" {
    try std.testing.expectEqual(true, Wolf.isWithinFollowRange(10));
    try std.testing.expectEqual(false, Wolf.isWithinFollowRange(11));
    try std.testing.expectEqual(true, Wolf.isWithinFollowRange(0));
}
