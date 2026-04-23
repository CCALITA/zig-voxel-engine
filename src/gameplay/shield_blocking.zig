/// Shield blocking system: warmup timing, axe-disable mechanic,
/// directional damage blocking based on attacker/defender facing angles.

const std = @import("std");

// ── Constants ─────────────────────────────────────────────────────────────

const warmup_duration: f32 = 0.25; // 5 ticks at 20 tps
const axe_disable_duration: f32 = 5.0;
const block_half_arc: f32 = std.math.pi / 2.0; // 90 degrees each side = 180 total

// ── Shield state ──────────────────────────────────────────────────────────

pub const ShieldState = struct {
    is_blocking: bool = false,
    warmup: f32 = 0,
    cooldown: f32 = 0,
    disabled_timer: f32 = 0,

    /// Begin raising the shield. Ignored while disabled or on cooldown.
    pub fn startBlock(self: *ShieldState) void {
        if (self.disabled_timer > 0 or self.cooldown > 0) return;
        self.is_blocking = true;
        self.warmup = warmup_duration;
    }

    /// Lower the shield immediately.
    pub fn stopBlock(self: *ShieldState) void {
        self.is_blocking = false;
        self.warmup = 0;
    }

    /// Tick timers forward by `dt` seconds.
    pub fn update(self: *ShieldState, dt: f32) void {
        self.warmup = tickDown(self.warmup, dt);
        self.cooldown = tickDown(self.cooldown, dt);
        self.disabled_timer = tickDown(self.disabled_timer, dt);
    }

    /// True when shield is raised, warmed up, and not disabled.
    pub fn canBlock(self: ShieldState) bool {
        return self.is_blocking and self.warmup <= 0 and self.disabled_timer <= 0;
    }

    /// Axe hit disables the shield for 5 seconds.
    pub fn onAxeHit(self: *ShieldState) void {
        self.is_blocking = false;
        self.warmup = 0;
        self.disabled_timer = axe_disable_duration;
    }
};

// ── Directional check ─────────────────────────────────────────────────────

/// Returns true when the attack comes from the defender's front 180-degree arc.
/// Both angles are in radians. The function normalises the difference to [-pi, pi]
/// and checks whether the absolute value is within 90 degrees of the defender's
/// facing direction (i.e. a 180-degree cone centred on the facing direction).
pub fn shouldBlockDamage(attacker_angle: f32, defender_facing: f32) bool {
    const diff = normaliseAngle(attacker_angle - defender_facing);
    return @abs(diff) <= block_half_arc;
}

// ── Damage calculation ────────────────────────────────────────────────────

/// A successful shield block absorbs 100% of incoming damage.
pub fn getBlockedDamage(incoming: f32) f32 {
    _ = incoming;
    return 0;
}

// ── Helpers ───────────────────────────────────────────────────────────────

/// Decrement a timer by `dt`, clamping at zero.
fn tickDown(value: f32, dt: f32) f32 {
    return @max(value - dt, 0.0);
}

/// Wrap an angle into the [-pi, pi] range in constant time.
fn normaliseAngle(angle: f32) f32 {
    const tau = 2.0 * std.math.pi;
    return angle - tau * @round(angle / tau);
}

// ── Tests ─────────────────────────────────────────────────────────────────

test "shield starts in non-blocking state" {
    const shield = ShieldState{};
    try std.testing.expect(!shield.is_blocking);
    try std.testing.expect(!shield.canBlock());
}

test "startBlock sets blocking with warmup" {
    var shield = ShieldState{};
    shield.startBlock();
    try std.testing.expect(shield.is_blocking);
    try std.testing.expect(!shield.canBlock()); // warmup not elapsed
}

test "canBlock returns true after warmup elapses" {
    var shield = ShieldState{};
    shield.startBlock();
    shield.update(0.25);
    try std.testing.expect(shield.canBlock());
}

test "stopBlock lowers shield immediately" {
    var shield = ShieldState{};
    shield.startBlock();
    shield.update(0.25);
    try std.testing.expect(shield.canBlock());

    shield.stopBlock();
    try std.testing.expect(!shield.is_blocking);
    try std.testing.expect(!shield.canBlock());
}

test "onAxeHit disables shield for 5 seconds" {
    var shield = ShieldState{};
    shield.startBlock();
    shield.update(0.25);
    try std.testing.expect(shield.canBlock());

    shield.onAxeHit();
    try std.testing.expect(!shield.canBlock());
    try std.testing.expect(shield.disabled_timer > 0);

    // Still disabled after 4.9 seconds
    shield.update(4.9);
    try std.testing.expect(shield.disabled_timer > 0);

    // Recovered after full 5 seconds
    shield.update(0.2);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), shield.disabled_timer, 0.01);
}

test "cannot startBlock while disabled" {
    var shield = ShieldState{};
    shield.onAxeHit();
    shield.startBlock();
    try std.testing.expect(!shield.is_blocking);
}

test "shouldBlockDamage blocks within front 180 arc" {
    // Defender facing north (0 rad), attacker from the front
    try std.testing.expect(shouldBlockDamage(0.0, 0.0));
    // Attacker slightly left (89 degrees)
    try std.testing.expect(shouldBlockDamage(1.5, 0.0));
    // Attacker slightly right (-89 degrees)
    try std.testing.expect(shouldBlockDamage(-1.5, 0.0));
}

test "shouldBlockDamage fails for attacks from behind" {
    // Attacker from directly behind (pi radians offset)
    try std.testing.expect(!shouldBlockDamage(std.math.pi, 0.0));
    // Attacker from 135 degrees behind
    try std.testing.expect(!shouldBlockDamage(2.5, 0.0));
    try std.testing.expect(!shouldBlockDamage(-2.5, 0.0));
}

test "shouldBlockDamage works with non-zero defender facing" {
    const facing = std.math.pi / 2.0; // facing east
    // Attack from east (same direction) — should block
    try std.testing.expect(shouldBlockDamage(std.math.pi / 2.0, facing));
    // Attack from west (behind) — should not block
    try std.testing.expect(!shouldBlockDamage(-std.math.pi / 2.0, facing));
}

test "shouldBlockDamage handles angle wrapping" {
    // Defender facing near pi, attacker near -pi (close in reality)
    try std.testing.expect(shouldBlockDamage(std.math.pi - 0.1, -(std.math.pi - 0.1)));
}

test "getBlockedDamage returns zero (100% block)" {
    try std.testing.expectEqual(@as(f32, 0), getBlockedDamage(10.0));
    try std.testing.expectEqual(@as(f32, 0), getBlockedDamage(0.5));
    try std.testing.expectEqual(@as(f32, 0), getBlockedDamage(100.0));
}

test "warmup partially elapsed still prevents blocking" {
    var shield = ShieldState{};
    shield.startBlock();
    shield.update(0.10); // only 0.10 of 0.25
    try std.testing.expect(!shield.canBlock());
    shield.update(0.15); // now 0.25 total
    try std.testing.expect(shield.canBlock());
}

test "disabled timer counts down independently of cooldown" {
    var shield = ShieldState{};
    shield.cooldown = 2.0;
    shield.disabled_timer = 3.0;
    shield.update(2.5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), shield.cooldown, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), shield.disabled_timer, 0.01);
}
