const std = @import("std");

pub const FallTracker = struct {
    fall_start_y: f32 = 0,
    is_falling: bool = false,
    max_fall: f32 = 0,

    pub fn startFall(self: *FallTracker, y: f32) void {
        self.fall_start_y = y;
        self.is_falling = true;
        self.max_fall = 0;
    }

    /// Updates fall tracking. Returns damage on landing, or null if still falling / no damage.
    pub fn updateFall(self: *FallTracker, y: f32, on_ground: bool, in_water: bool) ?f32 {
        if (!self.is_falling) return null;

        const distance = self.fall_start_y - y;
        self.max_fall = @max(self.max_fall, distance);

        if (in_water) {
            self.is_falling = false;
            self.max_fall = 0;
            return null;
        }

        if (on_ground) {
            self.is_falling = false;
            const fall_distance = self.max_fall;
            self.max_fall = 0;
            const damage = calculateDamage(fall_distance);
            return if (damage > 0) damage else null;
        }

        return null;
    }
};

/// Calculates fall damage for a given distance. Damage = distance - 3, minimum 0.
pub fn calculateDamage(distance: f32) f32 {
    if (distance <= 3.0) return 0;
    return distance - 3.0;
}

/// Returns true if the fall damage from the given distance would kill (>= health).
pub fn isLethal(distance: f32, health: f32) bool {
    return calculateDamage(distance) >= health;
}

/// Applies Feather Falling enchantment reduction: 12% per level.
pub fn applyFeatherFalling(damage: f32, level: u8) f32 {
    if (level == 0) return damage;
    const reduction = @min(0.12 * @as(f32, @floatFromInt(level)), 1.0);
    return damage * (1.0 - reduction);
}

// ── Tests ───────────────────────────────────────────────────────────────────

test "calculateDamage zero for short falls" {
    try std.testing.expectEqual(@as(f32, 0), calculateDamage(0));
    try std.testing.expectEqual(@as(f32, 0), calculateDamage(1.5));
    try std.testing.expectEqual(@as(f32, 0), calculateDamage(3.0));
}

test "calculateDamage correct for longer falls" {
    try std.testing.expectEqual(@as(f32, 1.0), calculateDamage(4.0));
    try std.testing.expectEqual(@as(f32, 7.0), calculateDamage(10.0));
    try std.testing.expectEqual(@as(f32, 20.0), calculateDamage(23.0));
}

test "isLethal true when damage meets or exceeds health" {
    try std.testing.expect(isLethal(23.0, 20.0));
    try std.testing.expect(isLethal(24.0, 20.0));
}

test "isLethal false when damage is below health" {
    try std.testing.expect(!isLethal(10.0, 20.0));
    try std.testing.expect(!isLethal(3.0, 1.0));
}

test "feather falling reduces damage by 12 percent per level" {
    const base = calculateDamage(10.0);
    const reduced = applyFeatherFalling(base, 1);
    try std.testing.expectApproxEqAbs(base * 0.88, reduced, 0.001);
}

test "feather falling level 4 reduces by 48 percent" {
    const base = calculateDamage(10.0);
    const reduced = applyFeatherFalling(base, 4);
    try std.testing.expectApproxEqAbs(base * 0.52, reduced, 0.001);
}

test "feather falling level 0 no reduction" {
    const base = calculateDamage(10.0);
    try std.testing.expectEqual(base, applyFeatherFalling(base, 0));
}

test "FallTracker startFall and landing with damage" {
    var tracker = FallTracker{};
    tracker.startFall(100.0);
    try std.testing.expect(tracker.is_falling);

    // Mid-air update
    const mid = tracker.updateFall(95.0, false, false);
    try std.testing.expect(mid == null);

    // Landing
    const dmg = tracker.updateFall(90.0, true, false);
    try std.testing.expect(dmg != null);
    try std.testing.expectEqual(@as(f32, 7.0), dmg.?);
    try std.testing.expect(!tracker.is_falling);
}

test "FallTracker water cancels fall damage" {
    var tracker = FallTracker{};
    tracker.startFall(100.0);
    _ = tracker.updateFall(80.0, false, false);
    const dmg = tracker.updateFall(75.0, false, true);
    try std.testing.expect(dmg == null);
    try std.testing.expect(!tracker.is_falling);
}

test "FallTracker short fall no damage" {
    var tracker = FallTracker{};
    tracker.startFall(10.0);
    const dmg = tracker.updateFall(8.0, true, false);
    try std.testing.expect(dmg == null);
}

test "FallTracker not falling returns null" {
    var tracker = FallTracker{};
    const dmg = tracker.updateFall(50.0, true, false);
    try std.testing.expect(dmg == null);
}

test "feather falling high level caps at 100 percent reduction" {
    const base = calculateDamage(20.0);
    const reduced = applyFeatherFalling(base, 10);
    try std.testing.expectEqual(@as(f32, 0), reduced);
}

test "isLethal boundary exact health equals damage" {
    // 23 blocks fall -> 20 damage, 20 health -> lethal
    try std.testing.expect(isLethal(23.0, 20.0));
    // 22.9 blocks -> 19.9 damage, 20 health -> not lethal
    try std.testing.expect(!isLethal(22.9, 20.0));
}
