/// Skeleton archer AI with aim-then-fire cycle, arrow arc gravity compensation,
/// and slight target leading. Skeletons aim for 1.5 seconds, fire every 2 seconds,
/// and lob arrows with an upward arc to compensate for gravity over distance.
const std = @import("std");
const math = std.math;

/// Arrow velocity in blocks per second.
const arrow_speed: f32 = 25.0;

/// Gravitational acceleration applied to arrows (blocks/s^2).
const gravity: f32 = 20.0;

/// Duration the skeleton must aim before releasing (seconds).
const aim_duration: f32 = 1.5;

/// Minimum time between successive shots (seconds).
const fire_cooldown_duration: f32 = 2.0;

/// Base arrow damage.
const base_damage: f32 = 3.0;

/// Maximum detection range (blocks).
const max_range: f32 = 16.0;

/// Fraction of target velocity used for leading.
const lead_factor: f32 = 0.15;

/// Result of a skeleton firing an arrow.
pub const ArrowShot = struct {
    vx: f32,
    vy: f32,
    vz: f32,
    damage: f32,
};

pub const SkeletonAI = struct {
    fire_cooldown: f32 = 0,
    is_aiming: bool = false,
    aim_time: f32 = 0,

    // Previous target position for velocity estimation.
    prev_target_x: f32 = 0,
    prev_target_y: f32 = 0,
    prev_target_z: f32 = 0,
    has_prev_target: bool = false,

    /// Advance the skeleton AI by `dt` seconds.
    /// Returns an `ArrowShot` when the skeleton fires, otherwise `null`.
    pub fn update(
        self: *SkeletonAI,
        dt: f32,
        skel_x: f32,
        skel_y: f32,
        skel_z: f32,
        target_x: f32,
        target_y: f32,
        target_z: f32,
    ) ?ArrowShot {
        defer self.recordTarget(target_x, target_y, target_z);

        const dx = target_x - skel_x;
        const dy = target_y - skel_y;
        const dz = target_z - skel_z;
        const dist = @sqrt(dx * dx + dy * dy + dz * dz);

        if (self.fire_cooldown > 0) {
            self.fire_cooldown = @max(0, self.fire_cooldown - dt);
        }

        // Out of range -- abort aim.
        if (dist > max_range or dist < 0.01) {
            self.is_aiming = false;
            self.aim_time = 0;
            return null;
        }

        // Aim accumulates only after cooldown elapses.
        if (self.fire_cooldown <= 0) {
            if (!self.is_aiming) {
                self.is_aiming = true;
                self.aim_time = 0;
            }
            self.aim_time += dt;
        }

        if (self.is_aiming and self.aim_time >= aim_duration) {
            self.is_aiming = false;
            self.aim_time = 0;
            self.fire_cooldown = fire_cooldown_duration;
            return self.computeShot(skel_x, skel_y, skel_z, target_x, target_y, target_z, dt);
        }

        return null;
    }

    /// Compute arrow velocity toward the (possibly led) target with arc compensation.
    fn computeShot(
        self: *const SkeletonAI,
        skel_x: f32,
        skel_y: f32,
        skel_z: f32,
        target_x: f32,
        target_y: f32,
        target_z: f32,
        dt: f32,
    ) ArrowShot {
        // Estimate target velocity for leading.
        var tvx: f32 = 0;
        var tvy: f32 = 0;
        var tvz: f32 = 0;
        if (self.has_prev_target and dt > 0) {
            tvx = (target_x - self.prev_target_x) / dt;
            tvy = (target_y - self.prev_target_y) / dt;
            tvz = (target_z - self.prev_target_z) / dt;
        }

        // Lead the target.
        const led_x = target_x + tvx * lead_factor;
        const led_y = target_y + tvy * lead_factor;
        const led_z = target_z + tvz * lead_factor;

        const dx = led_x - skel_x;
        const dy = led_y - skel_y;
        const dz = led_z - skel_z;
        const horiz_dist = @sqrt(dx * dx + dz * dz);

        // Apply gravity arc compensation.
        const arc_angle = calculateArc(horiz_dist, dy);

        // Horizontal direction.
        const horiz = @max(horiz_dist, 0.001);
        const dir_x = dx / horiz;
        const dir_z = dz / horiz;

        const cos_a = @cos(arc_angle);
        const sin_a = @sin(arc_angle);

        return .{
            .vx = dir_x * arrow_speed * cos_a,
            .vy = arrow_speed * sin_a,
            .vz = dir_z * arrow_speed * cos_a,
            .damage = base_damage,
        };
    }

    fn recordTarget(self: *SkeletonAI, x: f32, y: f32, z: f32) void {
        self.prev_target_x = x;
        self.prev_target_y = y;
        self.prev_target_z = z;
        self.has_prev_target = true;
    }
};

/// Calculate the upward launch angle (radians) to compensate for gravity.
///
/// Given the horizontal distance `dist` and vertical offset `dy` to the target,
/// returns an angle that lobs the arrow in a parabolic arc.  For short distances
/// the correction is small; for longer distances the arc becomes more pronounced.
pub fn calculateArc(dist: f32, dy: f32) f32 {
    if (dist < 0.01) return 0;

    // Time of flight along the horizontal.
    const flight_time = dist / arrow_speed;

    // Vertical velocity needed to reach dy while subject to gravity:
    //   dy = vy*t - 0.5*g*t^2  =>  vy = dy/t + 0.5*g*t
    const vy_needed = dy / flight_time + 0.5 * gravity * flight_time;

    // Convert to angle.
    return math.atan2(vy_needed, arrow_speed);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
const testing = std.testing;

test "default initialization" {
    const ai = SkeletonAI{};
    try testing.expectEqual(@as(f32, 0), ai.fire_cooldown);
    try testing.expect(!ai.is_aiming);
    try testing.expectEqual(@as(f32, 0), ai.aim_time);
}

test "begins aiming when target in range" {
    var ai = SkeletonAI{};
    // Target 10 blocks away on x-axis.
    const result = ai.update(0.1, 0, 0, 0, 10, 0, 0);
    try testing.expect(result == null);
    try testing.expect(ai.is_aiming);
    try testing.expect(ai.aim_time > 0);
}

test "does not aim when target out of range" {
    var ai = SkeletonAI{};
    const result = ai.update(0.1, 0, 0, 0, 100, 0, 0);
    try testing.expect(result == null);
    try testing.expect(!ai.is_aiming);
}

test "fires after aim duration" {
    var ai = SkeletonAI{};
    // Accumulate aim time just past the threshold.
    _ = ai.update(0.5, 0, 0, 0, 10, 0, 0);
    _ = ai.update(0.5, 0, 0, 0, 10, 0, 0);
    _ = ai.update(0.4, 0, 0, 0, 10, 0, 0);
    // This tick should push aim_time past 1.5.
    const shot = ai.update(0.2, 0, 0, 0, 10, 0, 0);
    try testing.expect(shot != null);
    try testing.expect(!ai.is_aiming);
}

test "cooldown prevents immediate re-fire" {
    var ai = SkeletonAI{};
    // Fire once.
    _ = ai.update(aim_duration + 0.01, 0, 0, 0, 10, 0, 0);
    try testing.expect(ai.fire_cooldown > 0);

    // Subsequent updates within cooldown should not fire.
    const result = ai.update(0.5, 0, 0, 0, 10, 0, 0);
    try testing.expect(result == null);
    try testing.expect(!ai.is_aiming);
}

test "arrow shot has positive damage" {
    var ai = SkeletonAI{};
    const shot = ai.update(aim_duration + 0.01, 0, 0, 0, 10, 0, 0);
    try testing.expect(shot != null);
    try testing.expect(shot.?.damage > 0);
}

test "arrow velocity points toward target" {
    var ai = SkeletonAI{};
    // Target at (10, 0, 0) from origin.
    const shot = ai.update(aim_duration + 0.01, 0, 0, 0, 10, 0, 0).?;
    // vx should be positive (toward target).
    try testing.expect(shot.vx > 0);
    // vz should be ~0 since target is purely along x.
    try testing.expect(@abs(shot.vz) < 0.01);
}

test "calculateArc returns zero for zero distance" {
    const angle = calculateArc(0, 5);
    try testing.expectEqual(@as(f32, 0), angle);
}

test "calculateArc returns positive angle for flat shot" {
    // Flat shot (dy=0) at 10 blocks -- gravity still needs compensation.
    const angle = calculateArc(10, 0);
    try testing.expect(angle > 0);
}

test "calculateArc increases with distance" {
    const short = calculateArc(5, 0);
    const long = calculateArc(15, 0);
    try testing.expect(long > short);
}

test "calculateArc adjusts for negative dy" {
    // Shooting downward should need less arc than shooting upward.
    const up = calculateArc(10, 5);
    const down = calculateArc(10, -5);
    try testing.expect(up > down);
}

test "full fire cycle with cooldown recovery" {
    var ai = SkeletonAI{};
    // First shot.
    const first = ai.update(aim_duration + 0.01, 0, 0, 0, 10, 0, 0);
    try testing.expect(first != null);
    try testing.expect(ai.fire_cooldown > 0);

    // Drain cooldown in small ticks (so we don't accidentally fire again).
    var ticks: u32 = 0;
    while (ai.fire_cooldown > 0 and ticks < 100) : (ticks += 1) {
        _ = ai.update(0.05, 0, 0, 0, 10, 0, 0);
    }
    try testing.expectEqual(@as(f32, 0), ai.fire_cooldown);

    // Eventually fire a second shot.
    var fired_again = false;
    var safety: u32 = 0;
    while (!fired_again and safety < 100) : (safety += 1) {
        if (ai.update(0.1, 0, 0, 0, 10, 0, 0)) |_| {
            fired_again = true;
        }
    }
    try testing.expect(fired_again);
}

test "target leading adjusts velocity" {
    var ai = SkeletonAI{};
    // Simulate a target moving along +x.
    _ = ai.update(0.1, 0, 0, 0, 8, 0, 0);
    // Target moved from 8 to 10 in next tick (moving right).
    const shot = ai.update(aim_duration, 0, 0, 0, 10, 0, 0);
    try testing.expect(shot != null);
    // The vx should be positive (toward the target direction).
    try testing.expect(shot.?.vx > 0);
}

test "arrow speed magnitude is consistent" {
    var ai = SkeletonAI{};
    const shot = ai.update(aim_duration + 0.01, 0, 0, 0, 10, 0, 0).?;
    const speed = @sqrt(shot.vx * shot.vx + shot.vy * shot.vy + shot.vz * shot.vz);
    // Speed should be close to arrow_speed (within 1% tolerance).
    try testing.expect(@abs(speed - arrow_speed) < arrow_speed * 0.01);
}

test "diagonal target produces nonzero vx and vz" {
    var ai = SkeletonAI{};
    const shot = ai.update(aim_duration + 0.01, 0, 0, 0, 8, 0, 8).?;
    try testing.expect(shot.vx > 0);
    try testing.expect(shot.vz > 0);
}
