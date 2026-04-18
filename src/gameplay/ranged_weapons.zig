const std = @import("std");

// ─── Trident ────────────────────────────────────────────────────────────────

pub const TridentState = struct {
    durability: u16 = 250,
    loyalty_level: u3 = 0,
    riptide_level: u3 = 0,
    channeling: bool = false,
    thrown: bool = false,
    return_timer: f32 = 0,

    pub const melee_damage: f32 = 8;
    pub const thrown_damage: f32 = 8;

    pub fn throwTrident(self: *TridentState) ThrowResult {
        if (self.durability == 0) {
            return ThrowResult{ .success = false, .damage = 0, .riptide = false };
        }
        self.thrown = true;
        self.durability -= 1;
        const riptide = self.riptide_level > 0;
        return ThrowResult{
            .success = true,
            .damage = thrown_damage,
            .riptide = riptide,
        };
    }

    pub fn updateThrown(self: *TridentState, dt: f32, in_rain: bool) TridentUpdate {
        if (!self.thrown) return .stuck;

        if (self.riptide_level > 0 and in_rain) {
            self.thrown = false;
            return .riptide_launch;
        }

        if (self.loyalty_level > 0) {
            self.return_timer += dt;
            const return_threshold = 3.0 - @as(f32, @floatFromInt(self.loyalty_level)) * 0.5;
            if (self.return_timer >= return_threshold) {
                self.thrown = false;
                self.return_timer = 0;
                return .returning;
            }
        }

        return .flying;
    }

    pub fn shouldChannelLightning(self: TridentState, target_in_rain: bool) bool {
        return self.channeling and target_in_rain;
    }
};

pub const ThrowResult = struct {
    success: bool,
    damage: f32,
    riptide: bool,
};

pub const TridentUpdate = enum {
    flying,
    stuck,
    returning,
    riptide_launch,
};

pub fn getRiptideVelocity(level: u3) f32 {
    return @as(f32, @floatFromInt(level)) * 3.0;
}

// ─── Crossbow ───────────────────────────────────────────────────────────────

pub const CrossbowProjectile = enum {
    arrow,
    firework,
};

pub const CrossbowState = struct {
    loaded: bool = false,
    load_progress: f32 = 0,
    multishot: bool = false,
    piercing: u3 = 0,
    projectile: ?CrossbowProjectile = null,

    pub const load_time: f32 = 1.25;
    pub const base_damage: f32 = 9;

    pub fn startLoading(self: *CrossbowState) void {
        if (!self.loaded) {
            self.load_progress = 0;
        }
    }

    pub fn tickLoading(self: *CrossbowState, dt: f32) bool {
        if (self.loaded) return true;

        self.load_progress += dt;
        if (self.load_progress >= load_time) {
            self.loaded = true;
            self.load_progress = load_time;
            if (self.projectile == null) {
                self.projectile = .arrow;
            }
            return true;
        }
        return false;
    }

    pub fn shoot(self: *CrossbowState) ShootResult {
        if (!self.loaded) {
            return ShootResult{ .count = 0, .damage = 0, .piercing_level = 0 };
        }
        self.loaded = false;
        self.load_progress = 0;
        self.projectile = null;

        const count: u8 = if (self.multishot) 3 else 1;
        return ShootResult{
            .count = count,
            .damage = base_damage,
            .piercing_level = self.piercing,
        };
    }
};

pub const ShootResult = struct {
    count: u8,
    damage: f32,
    piercing_level: u3,
};

// ─── Tests ──────────────────────────────────────────────────────────────────

test "trident throw deals correct damage" {
    var trident = TridentState{};
    const result = trident.throwTrident();
    try std.testing.expect(result.success);
    try std.testing.expectEqual(@as(f32, 8), result.damage);
    try std.testing.expect(trident.thrown);
}

test "trident loyalty causes return" {
    var trident = TridentState{ .loyalty_level = 3, .thrown = true };
    // loyalty 3 → threshold = 3.0 - 1.5 = 1.5s
    const update1 = trident.updateThrown(1.0, false);
    try std.testing.expectEqual(TridentUpdate.flying, update1);

    const update2 = trident.updateThrown(0.6, false);
    try std.testing.expectEqual(TridentUpdate.returning, update2);
    try std.testing.expect(!trident.thrown);
}

test "trident riptide launches in rain" {
    var trident = TridentState{ .riptide_level = 2, .thrown = true };
    const update = trident.updateThrown(0.1, true);
    try std.testing.expectEqual(TridentUpdate.riptide_launch, update);
    try std.testing.expect(!trident.thrown);
}

test "trident channeling requires rain on target" {
    const trident_with_channeling = TridentState{ .channeling = true };
    try std.testing.expect(trident_with_channeling.shouldChannelLightning(true));
    try std.testing.expect(!trident_with_channeling.shouldChannelLightning(false));

    const trident_without = TridentState{ .channeling = false };
    try std.testing.expect(!trident_without.shouldChannelLightning(true));
}

test "riptide velocity scales with level" {
    try std.testing.expectEqual(@as(f32, 0), getRiptideVelocity(0));
    try std.testing.expectEqual(@as(f32, 3), getRiptideVelocity(1));
    try std.testing.expectEqual(@as(f32, 6), getRiptideVelocity(2));
    try std.testing.expectEqual(@as(f32, 9), getRiptideVelocity(3));
}

test "crossbow load time is 1.25 seconds" {
    var crossbow = CrossbowState{};
    crossbow.startLoading();
    try std.testing.expect(!crossbow.tickLoading(0.5));
    try std.testing.expect(!crossbow.tickLoading(0.5));
    try std.testing.expect(crossbow.tickLoading(0.25));
    try std.testing.expect(crossbow.loaded);
}

test "crossbow multishot fires 3 arrows" {
    var crossbow = CrossbowState{ .multishot = true, .loaded = true, .projectile = .arrow };
    const result = crossbow.shoot();
    try std.testing.expectEqual(@as(u8, 3), result.count);
    try std.testing.expectEqual(@as(f32, 9), result.damage);
    try std.testing.expect(!crossbow.loaded);
}

test "crossbow piercing level propagates to shot" {
    var crossbow = CrossbowState{ .piercing = 4, .loaded = true, .projectile = .arrow };
    const result = crossbow.shoot();
    try std.testing.expectEqual(@as(u3, 4), result.piercing_level);
    try std.testing.expectEqual(@as(u8, 1), result.count);
}
