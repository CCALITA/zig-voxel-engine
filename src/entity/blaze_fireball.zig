/// Blaze fireball AI with 3-burst firing every 5 seconds, hovering above the
/// target, and an orbiting fire shield particle effect.
const std = @import("std");
const math = std.math;

/// Number of fireballs per burst.
const burst_count: u8 = 3;

/// Total cooldown between bursts (seconds).
const burst_cooldown: f32 = 5.0;

/// Delay between successive fireballs within a burst (seconds).
const burst_interval: f32 = 0.3;

/// Fireball flight speed (blocks per second).
const fireball_speed: f32 = 20.0;

/// Base fireball damage.
const fireball_damage: f32 = 5.0;

/// Hover offset above the target's y position (blocks).
const hover_offset: f32 = 3.0;

/// Number of orbiting fire-shield particles.
const particle_count: usize = 4;

/// Orbit radius for fire-shield particles (blocks).
const orbit_radius: f32 = 0.8;

/// Orbit angular speed (radians per second).
const orbit_speed: f32 = 2.0;

/// Vertical offset of fire-shield particles above the blaze center (blocks).
const particle_y_offset: f32 = 0.5;

/// Angular separation between adjacent particles (radians).
const particle_angle_step: f32 = 2.0 * math.pi / @as(f32, @floatFromInt(particle_count));

/// A single fireball projectile.
pub const Fireball = struct {
    vx: f32,
    vy: f32,
    vz: f32,
    damage: f32,
};

/// Blaze AI state machine that manages burst-fire timing and target tracking.
pub const BlazeAI = struct {
    cooldown: f32 = 0,
    burst: u8 = 0,
    hover_y: f32 = 0,

    /// Advance the blaze AI by `dt` seconds.
    /// Returns a `Fireball` when the blaze fires, otherwise `null`.
    pub fn update(
        self: *BlazeAI,
        dt: f32,
        bx: f32,
        by: f32,
        bz: f32,
        tx: f32,
        ty: f32,
        tz: f32,
    ) ?Fireball {
        self.hover_y = getHoverTarget(ty);

        // Mid-burst: count down the short interval between shots.
        if (self.burst > 0) {
            self.cooldown -= dt;
            if (self.cooldown <= 0) {
                self.burst -= 1;
                self.cooldown = if (self.burst > 0) burst_interval else burst_cooldown;
                return aimAt(bx, by, bz, tx, ty, tz);
            }
            return null;
        }

        // Waiting for next burst.
        self.cooldown -= dt;
        if (self.cooldown <= 0) {
            self.burst = burst_count - 1;
            self.cooldown = burst_interval;
            return aimAt(bx, by, bz, tx, ty, tz);
        }

        return null;
    }

    /// Return the desired hover y-position for a given target y.
    pub fn getHoverTarget(ty: f32) f32 {
        return ty + hover_offset;
    }

    /// Compute 4 orbiting fire-shield particle positions around the blaze.
    pub fn getFireShieldParticles(bx: f32, by: f32, bz: f32, time: f32) [particle_count][3]f32 {
        var particles: [particle_count][3]f32 = undefined;
        const base_angle = time * orbit_speed;

        for (0..particle_count) |i| {
            const offset_angle = base_angle + @as(f32, @floatFromInt(i)) * particle_angle_step;
            particles[i] = .{
                bx + orbit_radius * @cos(offset_angle),
                by + particle_y_offset,
                bz + orbit_radius * @sin(offset_angle),
            };
        }

        return particles;
    }
};

/// Compute a fireball velocity vector aimed from (bx,by,bz) toward (tx,ty,tz).
fn aimAt(bx: f32, by: f32, bz: f32, tx: f32, ty: f32, tz: f32) Fireball {
    const dx = tx - bx;
    const dy = ty - by;
    const dz = tz - bz;
    const dist = @sqrt(dx * dx + dy * dy + dz * dz);
    const inv = if (dist > 0.001) fireball_speed / dist else 0.0;

    return .{
        .vx = dx * inv,
        .vy = dy * inv,
        .vz = dz * inv,
        .damage = fireball_damage,
    };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
const testing = std.testing;

test "default initialization" {
    const ai = BlazeAI{};
    try testing.expectEqual(@as(f32, 0), ai.cooldown);
    try testing.expectEqual(@as(u8, 0), ai.burst);
    try testing.expectEqual(@as(f32, 0), ai.hover_y);
}

test "first update fires immediately when cooldown is zero" {
    var ai = BlazeAI{};
    const shot = ai.update(0.1, 0, 5, 0, 10, 2, 0);
    try testing.expect(shot != null);
}

test "fireball has correct damage" {
    var ai = BlazeAI{};
    const shot = ai.update(0.1, 0, 5, 0, 10, 2, 0).?;
    try testing.expectEqual(fireball_damage, shot.damage);
}

test "fireball velocity points toward target" {
    var ai = BlazeAI{};
    // Target at +x direction.
    const shot = ai.update(0.1, 0, 0, 0, 10, 0, 0).?;
    try testing.expect(shot.vx > 0);
    try testing.expect(@abs(shot.vy) < 0.01);
    try testing.expect(@abs(shot.vz) < 0.01);
}

test "3-burst fires three shots in quick succession" {
    var ai = BlazeAI{};
    var fired: u32 = 0;
    // Simulate many small ticks to collect all burst shots.
    var tick: u32 = 0;
    while (tick < 200) : (tick += 1) {
        if (ai.update(0.05, 0, 5, 0, 10, 2, 0) != null) {
            fired += 1;
        }
        // Stop after burst completes (before next burst starts).
        if (fired == burst_count and ai.burst == 0) break;
    }
    try testing.expectEqual(@as(u32, burst_count), fired);
}

test "cooldown prevents immediate re-burst" {
    var ai = BlazeAI{};
    // Fire full burst.
    var fired: u32 = 0;
    var tick: u32 = 0;
    while (tick < 200) : (tick += 1) {
        if (ai.update(0.05, 0, 5, 0, 10, 2, 0) != null) {
            fired += 1;
        }
        if (fired == burst_count and ai.burst == 0) break;
    }
    // Immediately after burst, next update should not fire.
    const next = ai.update(0.05, 0, 5, 0, 10, 2, 0);
    try testing.expect(next == null);
    try testing.expect(ai.cooldown > 0);
}

test "second burst fires after full cooldown" {
    var ai = BlazeAI{};
    var total_fired: u32 = 0;
    var tick: u32 = 0;
    // Run long enough to get two full bursts (burst + 5s cooldown + burst).
    while (tick < 5000) : (tick += 1) {
        if (ai.update(0.01, 0, 5, 0, 10, 2, 0) != null) {
            total_fired += 1;
        }
        if (total_fired >= burst_count * 2) break;
    }
    try testing.expect(total_fired >= burst_count * 2);
}

test "getHoverTarget returns target y plus offset" {
    try testing.expectEqual(@as(f32, 13.0), BlazeAI.getHoverTarget(10.0));
    try testing.expectEqual(@as(f32, 3.0), BlazeAI.getHoverTarget(0.0));
    try testing.expectEqual(@as(f32, -2.0), BlazeAI.getHoverTarget(-5.0));
}

test "hover_y updated on each tick" {
    var ai = BlazeAI{};
    _ = ai.update(0.1, 0, 5, 0, 10, 7, 0);
    try testing.expectEqual(@as(f32, 10.0), ai.hover_y);
    _ = ai.update(0.1, 0, 5, 0, 10, 20, 0);
    try testing.expectEqual(@as(f32, 23.0), ai.hover_y);
}

test "fire shield returns 4 particles" {
    const particles = BlazeAI.getFireShieldParticles(0, 5, 0, 0);
    try testing.expectEqual(@as(usize, particle_count), particles.len);
}

test "fire shield particles orbit around blaze position" {
    const bx: f32 = 10.0;
    const by: f32 = 5.0;
    const bz: f32 = 3.0;
    const particles = BlazeAI.getFireShieldParticles(bx, by, bz, 0);
    for (particles) |p| {
        const dx = p[0] - bx;
        const dz = p[2] - bz;
        const dist = @sqrt(dx * dx + dz * dz);
        // Each particle should be at orbit_radius from the blaze center.
        try testing.expect(@abs(dist - orbit_radius) < 0.01);
        // y should be offset above blaze y.
        try testing.expectEqual(by + particle_y_offset, p[1]);
    }
}

test "fire shield particles change position over time" {
    const p1 = BlazeAI.getFireShieldParticles(0, 0, 0, 0.0);
    const p2 = BlazeAI.getFireShieldParticles(0, 0, 0, 1.0);
    // At least one coordinate should differ between time=0 and time=1.
    var differs = false;
    for (0..particle_count) |i| {
        if (@abs(p1[i][0] - p2[i][0]) > 0.01 or @abs(p1[i][2] - p2[i][2]) > 0.01) {
            differs = true;
        }
    }
    try testing.expect(differs);
}

test "fireball speed magnitude is consistent" {
    var ai = BlazeAI{};
    const shot = ai.update(0.1, 0, 0, 0, 5, 5, 5).?;
    const speed = @sqrt(shot.vx * shot.vx + shot.vy * shot.vy + shot.vz * shot.vz);
    try testing.expect(@abs(speed - fireball_speed) < fireball_speed * 0.01);
}

test "diagonal fireball has nonzero components in all axes" {
    var ai = BlazeAI{};
    const shot = ai.update(0.1, 0, 0, 0, 5, 3, 7).?;
    try testing.expect(shot.vx > 0);
    try testing.expect(shot.vy > 0);
    try testing.expect(shot.vz > 0);
}

test "fire shield particles are evenly spaced" {
    const particles = BlazeAI.getFireShieldParticles(0, 0, 0, 0);
    // Compute angles of each particle relative to center.
    var angles: [particle_count]f32 = undefined;
    for (0..particle_count) |i| {
        angles[i] = math.atan2(particles[i][2], particles[i][0]);
    }
    // Sort angles.
    std.mem.sort(f32, &angles, {}, std.sort.asc(f32));
    // Check angular gaps are approximately equal (2*pi/4 = ~1.5708).
    const expected_gap = 2.0 * math.pi / @as(f32, @floatFromInt(particle_count));
    for (0..particle_count - 1) |i| {
        const gap = angles[i + 1] - angles[i];
        try testing.expect(@abs(gap - expected_gap) < 0.1);
    }
}
