/// Redstone components: observer, daylight detector, redstone torch, lamp,
/// target block, note block, and sculk sensor.
///
/// Each component is a self-contained struct with its own state and an `update`
/// method that returns an optional `Signal` for integration with the wire
/// network (see wire.zig).

const std = @import("std");
const math = std.math;

// ──────────────────────────────────────────────────────────────────────────────
// Shared types
// ──────────────────────────────────────────────────────────────────────────────

/// Signal emitted by a component, compatible with wire.zig `Source`.
pub const Signal = struct {
    strength: u4,
    x: i32,
    y: i32,
    z: i32,
};

/// Cardinal facing direction used by directional components.
pub const Facing = enum(u3) {
    north = 0, // -Z
    south = 1, // +Z
    east = 2, // +X
    west = 3, // -X
    up = 4, // +Y
    down = 5, // -Y
};

/// Offset deltas for a facing direction.
const Offset = struct { dx: i32, dy: i32, dz: i32 };

fn facingOffset(f: Facing) Offset {
    return switch (f) {
        .north => .{ .dx = 0, .dy = 0, .dz = -1 },
        .south => .{ .dx = 0, .dy = 0, .dz = 1 },
        .east => .{ .dx = 1, .dy = 0, .dz = 0 },
        .west => .{ .dx = -1, .dy = 0, .dz = 0 },
        .up => .{ .dx = 0, .dy = 1, .dz = 0 },
        .down => .{ .dx = 0, .dy = -1, .dz = 0 },
    };
}

fn oppositeFacing(f: Facing) Facing {
    return switch (f) {
        .north => .south,
        .south => .north,
        .east => .west,
        .west => .east,
        .up => .down,
        .down => .up,
    };
}

/// Minimal world context passed into `update`. Components read block states and
/// timing information through this interface so they remain dependency-free.
pub const WorldContext = struct {
    /// Current world tick (20 ticks per second).
    tick: u64,
    /// Sun angle in radians [0, pi] where 0 = sunrise, pi/2 = noon, pi = sunset.
    sun_angle: f32,
    /// Whether the block at (x,y,z) is receiving redstone power.
    isPowered: *const fn (i32, i32, i32) bool,
    /// Read a block-state hash at position — used by observer to detect changes.
    getBlockState: *const fn (i32, i32, i32) u32,
};

// ──────────────────────────────────────────────────────────────────────────────
// Observer
// ──────────────────────────────────────────────────────────────────────────────

/// Detects block-state changes on its face and emits a 1-tick (2 game ticks,
/// 0.1 s) pulse of strength 15 from its back.
///
/// Detectable changes: block placement/removal, crop growth stages, water level
/// changes, piston movement, and redstone state changes.
pub const Observer = struct {
    x: i32,
    y: i32,
    z: i32,
    /// Direction the observer *face* looks at (detection side).
    facing: Facing,
    /// Last observed block-state hash on the watched face.
    last_state: u32,
    /// Tick at which the current pulse started, 0 means no active pulse.
    pulse_start_tick: u64,

    /// Duration of the output pulse in game ticks (2 game ticks = 1 redstone tick).
    const PULSE_DURATION: u64 = 2;

    pub fn init(x: i32, y: i32, z: i32, facing: Facing) Observer {
        return .{
            .x = x,
            .y = y,
            .z = z,
            .facing = facing,
            .last_state = 0,
            .pulse_start_tick = 0,
        };
    }

    pub fn update(self: *Observer, ctx: WorldContext) ?Signal {
        const off = facingOffset(self.facing);
        const watched_x = self.x + off.dx;
        const watched_y = self.y + off.dy;
        const watched_z = self.z + off.dz;

        const current_state = ctx.getBlockState(watched_x, watched_y, watched_z);

        // Detect change on the watched face.
        if (current_state != self.last_state and self.pulse_start_tick == 0) {
            self.pulse_start_tick = ctx.tick;
        }
        self.last_state = current_state;

        // Emit pulse from the back face.
        if (self.pulse_start_tick > 0) {
            if (ctx.tick - self.pulse_start_tick < PULSE_DURATION) {
                const back = oppositeFacing(self.facing);
                const back_off = facingOffset(back);
                return Signal{
                    .strength = 15,
                    .x = self.x + back_off.dx,
                    .y = self.y + back_off.dy,
                    .z = self.z + back_off.dz,
                };
            }
            // Pulse expired.
            self.pulse_start_tick = 0;
        }

        return null;
    }
};

// ──────────────────────────────────────────────────────────────────────────────
// Daylight Detector
// ──────────────────────────────────────────────────────────────────────────────

/// Outputs a signal proportional to the sun angle. In inverted mode the output
/// is complementary (15 at night, 0 at noon).
///
/// Formula: signal = floor(15 * sin(sun_angle)) clamped to [0, 15].
/// Not affected by weather — only time-of-day matters.
pub const DaylightDetector = struct {
    x: i32,
    y: i32,
    z: i32,
    inverted: bool,

    pub fn init(x: i32, y: i32, z: i32) DaylightDetector {
        return .{ .x = x, .y = y, .z = z, .inverted = false };
    }

    /// Toggle between normal and inverted mode (right-click interaction).
    pub fn toggleMode(self: DaylightDetector) DaylightDetector {
        return .{
            .x = self.x,
            .y = self.y,
            .z = self.z,
            .inverted = !self.inverted,
        };
    }

    pub fn update(self: *const DaylightDetector, ctx: WorldContext) ?Signal {
        const raw = computeDaylightSignal(ctx.sun_angle);
        const strength: u4 = if (self.inverted) 15 -| raw else raw;
        if (strength == 0) return null;
        return Signal{ .strength = strength, .x = self.x, .y = self.y, .z = self.z };
    }
};

/// Pure helper so tests can verify the formula independently.
fn computeDaylightSignal(sun_angle: f32) u4 {
    const sine = @sin(sun_angle);
    if (sine <= 0) return 0;
    const scaled = sine * 15.0;
    const floored: u4 = @intFromFloat(@min(scaled, 15.0));
    return floored;
}

// ──────────────────────────────────────────────────────────────────────────────
// Redstone Torch
// ──────────────────────────────────────────────────────────────────────────────

/// Always-on signal source (strength 15) that turns OFF when the block it is
/// mounted on receives power (NOT-gate behavior).
///
/// Burnout protection: if toggled more than 8 times within 60 game ticks (3 s)
/// the torch burns out for 160 ticks (8 s).
pub const RedstoneTorch = struct {
    x: i32,
    y: i32,
    z: i32,
    /// Direction the torch faces away from the mounting block. `.down` means
    /// the torch sits on top of a block (ground placement).
    mount_facing: Facing,
    /// Whether the torch is currently lit.
    lit: bool,
    /// Burnout tracking: ring buffer of the last BURNOUT_THRESHOLD toggle ticks.
    toggle_ticks: [BURNOUT_THRESHOLD]u64,
    toggle_count: u8,
    toggle_write_idx: u8,
    /// Tick at which burnout started; 0 = not burned out.
    burnout_start: u64,

    const BURNOUT_THRESHOLD: u8 = 8;
    const BURNOUT_WINDOW: u64 = 60;
    const BURNOUT_COOLDOWN: u64 = 160;

    pub fn init(x: i32, y: i32, z: i32, mount_facing: Facing) RedstoneTorch {
        return .{
            .x = x,
            .y = y,
            .z = z,
            .mount_facing = mount_facing,
            .lit = true,
            .toggle_ticks = [_]u64{0} ** BURNOUT_THRESHOLD,
            .toggle_count = 0,
            .toggle_write_idx = 0,
            .burnout_start = 0,
        };
    }

    pub fn update(self: *RedstoneTorch, ctx: WorldContext) ?Signal {
        // Handle active burnout cooldown.
        if (self.burnout_start > 0) {
            if (ctx.tick - self.burnout_start >= BURNOUT_COOLDOWN) {
                self.burnout_start = 0;
                // Reset toggle history after recovery.
                self.toggle_count = 0;
            } else {
                return null; // Still burned out.
            }
        }

        // Determine mounting block position. mount_facing points toward the
        // surface the torch is attached to (e.g. `.down` means floor-mounted).
        const mount_off = facingOffset(self.mount_facing);
        const mount_x = self.x + mount_off.dx;
        const mount_y = self.y + mount_off.dy;
        const mount_z = self.z + mount_off.dz;

        const block_powered = ctx.isPowered(mount_x, mount_y, mount_z);
        const should_be_lit = !block_powered;

        if (should_be_lit != self.lit) {
            // Record toggle for burnout detection.
            self.toggle_ticks[self.toggle_write_idx] = ctx.tick;
            self.toggle_write_idx = (self.toggle_write_idx + 1) % BURNOUT_THRESHOLD;
            if (self.toggle_count < BURNOUT_THRESHOLD) {
                self.toggle_count += 1;
            }

            // Check burnout: if all BURNOUT_THRESHOLD slots are within the window.
            if (self.toggle_count >= BURNOUT_THRESHOLD) {
                const oldest_idx = (self.toggle_write_idx) % BURNOUT_THRESHOLD;
                const oldest_tick = self.toggle_ticks[oldest_idx];
                if (ctx.tick - oldest_tick < BURNOUT_WINDOW) {
                    self.lit = false;
                    self.burnout_start = ctx.tick;
                    return null;
                }
            }

            self.lit = should_be_lit;
        }

        if (!self.lit) return null;

        // Torch provides power to the block above it.
        return Signal{
            .strength = 15,
            .x = self.x,
            .y = self.y + 1,
            .z = self.z,
        };
    }
};

// ──────────────────────────────────────────────────────────────────────────────
// Redstone Lamp
// ──────────────────────────────────────────────────────────────────────────────

/// Lights up (light level 15) when receiving any redstone signal. Has a 2-tick
/// (0.1 s) delay when turning off, staying lit briefly after power is removed.
pub const RedstoneLamp = struct {
    x: i32,
    y: i32,
    z: i32,
    lit: bool,
    /// Tick at which power was last removed; 0 = still powered or never was.
    power_lost_tick: u64,

    /// Turn-off delay in game ticks.
    const OFF_DELAY: u64 = 2;

    pub fn init(x: i32, y: i32, z: i32) RedstoneLamp {
        return .{ .x = x, .y = y, .z = z, .lit = false, .power_lost_tick = 0 };
    }

    pub fn update(self: *RedstoneLamp, ctx: WorldContext) ?Signal {
        const powered = ctx.isPowered(self.x, self.y, self.z);

        if (powered) {
            self.lit = true;
            self.power_lost_tick = 0;
        } else if (self.lit) {
            // Start or continue the off-delay timer.
            if (self.power_lost_tick == 0) {
                self.power_lost_tick = ctx.tick;
            }
            if (ctx.tick - self.power_lost_tick >= OFF_DELAY) {
                self.lit = false;
                self.power_lost_tick = 0;
            }
        }

        // Lamps do not output redstone signal; they produce light.
        // Return a zero-strength signal placeholder so callers can read light state.
        return null;
    }

    /// Current light level (0 or 15).
    pub fn lightLevel(self: RedstoneLamp) u4 {
        return if (self.lit) 15 else 0;
    }
};

// ──────────────────────────────────────────────────────────────────────────────
// Target Block
// ──────────────────────────────────────────────────────────────────────────────

/// Outputs a redstone signal when hit by a projectile. Signal strength is
/// proportional to accuracy (15 at bullseye center, 1 at edge).
///
/// Non-arrow projectiles produce an 8-tick (0.4 s) pulse. Arrows stuck in the
/// block maintain signal until removed.
pub const TargetBlock = struct {
    x: i32,
    y: i32,
    z: i32,
    /// Current signal strength from a hit (0 = no hit).
    hit_strength: u4,
    /// Tick at which the current hit was registered.
    hit_tick: u64,
    /// Whether the projectile is an arrow (permanent signal until removed).
    arrow_stuck: bool,

    /// Duration of non-arrow hit signal in game ticks.
    const HIT_DURATION: u64 = 8;
    /// Radius of the bullseye center zone (in 1/16 block units).
    const CENTER_RADIUS: f32 = 2.0;
    /// Outer radius of the target face (in 1/16 block units).
    const OUTER_RADIUS: f32 = 8.0;

    pub fn init(x: i32, y: i32, z: i32) TargetBlock {
        return .{
            .x = x,
            .y = y,
            .z = z,
            .hit_strength = 0,
            .hit_tick = 0,
            .arrow_stuck = false,
        };
    }

    /// Register a projectile hit at the given distance from center (0..OUTER_RADIUS).
    pub fn hit(self: TargetBlock, distance: f32, is_arrow: bool, tick: u64) TargetBlock {
        const clamped = @min(distance, OUTER_RADIUS);
        const ratio = 1.0 - (clamped / OUTER_RADIUS);
        const raw: u8 = @intFromFloat(ratio * 14.0 + 1.0);
        const strength: u4 = @intCast(@min(raw, 15));
        return .{
            .x = self.x,
            .y = self.y,
            .z = self.z,
            .hit_strength = strength,
            .hit_tick = tick,
            .arrow_stuck = is_arrow,
        };
    }

    /// Remove a stuck arrow, clearing the signal.
    pub fn removeArrow(self: TargetBlock) TargetBlock {
        return .{
            .x = self.x,
            .y = self.y,
            .z = self.z,
            .hit_strength = 0,
            .hit_tick = 0,
            .arrow_stuck = false,
        };
    }

    pub fn update(self: *TargetBlock, ctx: WorldContext) ?Signal {
        if (self.hit_strength == 0) return null;

        if (!self.arrow_stuck) {
            if (ctx.tick - self.hit_tick >= HIT_DURATION) {
                self.hit_strength = 0;
                return null;
            }
        }

        return Signal{
            .strength = self.hit_strength,
            .x = self.x,
            .y = self.y,
            .z = self.z,
        };
    }
};

// ──────────────────────────────────────────────────────────────────────────────
// Note Block
// ──────────────────────────────────────────────────────────────────────────────

/// Plays a note on redstone pulse or player interaction. The instrument is
/// determined by the block below; there are 25 pitches (F#3 to F#5) spanning
/// two octaves.
pub const NoteBlock = struct {
    x: i32,
    y: i32,
    z: i32,
    pitch: u5,
    instrument: Instrument,
    /// Whether the block was powered on the previous tick (for edge detection).
    was_powered: bool,

    pub const Instrument = enum(u4) {
        harp = 0,
        bass = 1,
        snare = 2,
        hat = 3,
        bass_drum = 4,
        bell = 5,
        flute = 6,
        chime = 7,
        guitar = 8,
        xylophone = 9,
        iron_xylophone = 10,
        cow_bell = 11,
        didgeridoo = 12,
        bit = 13,
        banjo = 14,
        pling = 15,
    };

    /// Total number of distinct pitches.
    pub const PITCH_COUNT: u5 = 25;

    pub fn init(x: i32, y: i32, z: i32) NoteBlock {
        return .{
            .x = x,
            .y = y,
            .z = z,
            .pitch = 0,
            .instrument = .harp,
            .was_powered = false,
        };
    }

    /// Cycle the pitch upward by one semitone, wrapping at 24 back to 0.
    pub fn cyclePitch(self: NoteBlock) NoteBlock {
        return .{
            .x = self.x,
            .y = self.y,
            .z = self.z,
            .pitch = if (self.pitch >= PITCH_COUNT - 1) 0 else self.pitch + 1,
            .instrument = self.instrument,
            .was_powered = self.was_powered,
        };
    }

    /// Set instrument based on the block-below material identifier.
    pub fn setInstrument(self: NoteBlock, instr: Instrument) NoteBlock {
        return .{
            .x = self.x,
            .y = self.y,
            .z = self.z,
            .pitch = self.pitch,
            .instrument = instr,
            .was_powered = self.was_powered,
        };
    }

    /// Particle color mapped from pitch (0 = green, 12 = cyan, 24 = red).
    pub fn particleColor(self: NoteBlock) [3]f32 {
        const t: f32 = @as(f32, @floatFromInt(self.pitch)) / 24.0;
        // Simple HSV-like hue sweep: R-G-B mapped to 0-1 range.
        return .{
            @max(0.0, @min(1.0, @abs(t * 6.0 - 3.0) - 1.0)),
            @max(0.0, @min(1.0, 2.0 - @abs(t * 6.0 - 2.0))),
            @max(0.0, @min(1.0, 2.0 - @abs(t * 6.0 - 4.0))),
        };
    }

    /// Returns null always; the note block does not propagate redstone signal.
    /// Triggers a note event internally when a rising power edge is detected.
    pub fn update(self: *NoteBlock, ctx: WorldContext) ?Signal {
        const powered = ctx.isPowered(self.x, self.y, self.z);
        const rising_edge = powered and !self.was_powered;
        self.was_powered = powered;

        if (rising_edge) {
            // In a real engine this would trigger the audio system. We compute
            // the particle color for downstream use.
            _ = self.particleColor();
        }

        // Note blocks do not output redstone signal.
        return null;
    }
};

// ──────────────────────────────────────────────────────────────────────────────
// Sculk Sensor
// ──────────────────────────────────────────────────────────────────────────────

/// Detects vibrations within an 8-block spherical radius and outputs a signal
/// whose strength corresponds to the vibration type (1-15). After detection
/// there is a 40-tick (2 s) cooldown. Wool blocks between the sensor and source
/// block the vibration.
pub const SculkSensor = struct {
    x: i32,
    y: i32,
    z: i32,
    /// Current output strength (0 = idle).
    output_strength: u4,
    /// Tick at which the last vibration was detected.
    last_detection_tick: u64,

    /// Detection radius in blocks.
    pub const RADIUS: i32 = 8;
    /// Cooldown between detections in game ticks.
    const COOLDOWN: u64 = 40;

    pub const VibrationKind = enum(u4) {
        walking = 1,
        swimming = 3,
        block_break = 6,
        block_place = 7,
        eat = 8,
        projectile_land = 10,
        container_open = 11,
        entity_damage = 12,
        equip = 13,
        shear = 14,
        explosion = 15,
    };

    pub fn init(x: i32, y: i32, z: i32) SculkSensor {
        return .{ .x = x, .y = y, .z = z, .output_strength = 0, .last_detection_tick = 0 };
    }

    /// Register a vibration event. Returns a new sensor state with updated output
    /// if the vibration is within range, not blocked by wool, and the sensor is
    /// off cooldown. `wool_between` should be true when a wool block exists on
    /// the line between source and sensor.
    pub fn onVibration(
        self: SculkSensor,
        source_x: i32,
        source_y: i32,
        source_z: i32,
        kind: VibrationKind,
        wool_between: bool,
        current_tick: u64,
    ) SculkSensor {
        // Blocked by wool.
        if (wool_between) return self;

        // Check cooldown.
        if (self.last_detection_tick > 0 and current_tick - self.last_detection_tick < COOLDOWN) {
            return self;
        }

        // Check distance (squared to avoid sqrt).
        const dx = source_x - self.x;
        const dy = source_y - self.y;
        const dz = source_z - self.z;
        const dist_sq = dx * dx + dy * dy + dz * dz;
        if (dist_sq > RADIUS * RADIUS) return self;

        return .{
            .x = self.x,
            .y = self.y,
            .z = self.z,
            .output_strength = @intFromEnum(kind),
            .last_detection_tick = current_tick,
        };
    }

    pub fn update(self: *SculkSensor, ctx: WorldContext) ?Signal {
        if (self.output_strength == 0) return null;

        // Signal lasts for the cooldown duration.
        if (ctx.tick - self.last_detection_tick >= COOLDOWN) {
            self.output_strength = 0;
            return null;
        }

        return Signal{
            .strength = self.output_strength,
            .x = self.x,
            .y = self.y,
            .z = self.z,
        };
    }
};

// ──────────────────────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────────────────────

// --- Test world context helpers -----------------------------------------------

var test_powered_pos: [3]i32 = .{ 0, 0, 0 };
var test_powered_flag: bool = false;
var test_block_state_value: u32 = 0;

fn testIsPowered(x: i32, y: i32, z: i32) bool {
    if (x == test_powered_pos[0] and y == test_powered_pos[1] and z == test_powered_pos[2]) {
        return test_powered_flag;
    }
    return false;
}

fn testGetBlockState(_: i32, _: i32, _: i32) u32 {
    return test_block_state_value;
}

fn makeCtx(tick: u64, sun_angle: f32) WorldContext {
    return .{
        .tick = tick,
        .sun_angle = sun_angle,
        .isPowered = testIsPowered,
        .getBlockState = testGetBlockState,
    };
}

// --- Observer tests -----------------------------------------------------------

test "observer emits pulse on block state change" {
    test_block_state_value = 0;
    var obs = Observer.init(5, 5, 5, .north);

    // First update establishes baseline — no signal.
    const s0 = obs.update(makeCtx(0, 0));
    try std.testing.expect(s0 == null);

    // Change block state.
    test_block_state_value = 42;
    const s1 = obs.update(makeCtx(1, 0));
    try std.testing.expect(s1 != null);
    try std.testing.expectEqual(@as(u4, 15), s1.?.strength);
    // Signal should come from the back (south, +Z for north-facing observer).
    try std.testing.expectEqual(@as(i32, 6), s1.?.z);
}

test "observer pulse lasts 2 ticks" {
    test_block_state_value = 0;
    var obs = Observer.init(0, 0, 0, .east);

    // Establish baseline.
    _ = obs.update(makeCtx(0, 0));

    test_block_state_value = 1;
    const s1 = obs.update(makeCtx(1, 0));
    try std.testing.expect(s1 != null);

    // Still within 2-tick window.
    test_block_state_value = 1; // no further change
    const s2 = obs.update(makeCtx(2, 0));
    try std.testing.expect(s2 != null);

    // Past the pulse duration.
    const s3 = obs.update(makeCtx(3, 0));
    try std.testing.expect(s3 == null);
}

test "observer does not emit without change" {
    test_block_state_value = 7;
    var obs = Observer.init(0, 0, 0, .up);

    _ = obs.update(makeCtx(0, 0));
    const s1 = obs.update(makeCtx(1, 0));
    try std.testing.expect(s1 == null);
}

// --- Daylight Detector tests --------------------------------------------------

test "daylight detector at noon outputs 15" {
    var dd = DaylightDetector.init(0, 64, 0);
    const half_pi = math.pi / 2.0;
    const sig = dd.update(makeCtx(0, half_pi));
    try std.testing.expect(sig != null);
    try std.testing.expectEqual(@as(u4, 15), sig.?.strength);
}

test "daylight detector at night outputs null" {
    var dd = DaylightDetector.init(0, 64, 0);
    const sig = dd.update(makeCtx(0, 0));
    try std.testing.expect(sig == null);
}

test "daylight detector inverted mode" {
    const dd = DaylightDetector.init(0, 64, 0);
    var inv = dd.toggleMode();
    try std.testing.expect(inv.inverted);

    // At noon, inverted should output 0 (null).
    const half_pi = math.pi / 2.0;
    const sig_noon = inv.update(makeCtx(0, half_pi));
    try std.testing.expect(sig_noon == null);

    // At night, inverted should output 15.
    const sig_night = inv.update(makeCtx(0, 0));
    try std.testing.expect(sig_night != null);
    try std.testing.expectEqual(@as(u4, 15), sig_night.?.strength);
}

test "daylight signal formula" {
    try std.testing.expectEqual(@as(u4, 0), computeDaylightSignal(0));
    try std.testing.expectEqual(@as(u4, 15), computeDaylightSignal(math.pi / 2.0));
    // Negative sine (past sunset) should clamp to 0.
    try std.testing.expectEqual(@as(u4, 0), computeDaylightSignal(math.pi + 0.1));
}

// --- Redstone Torch tests -----------------------------------------------------

test "torch outputs 15 when mounting block is unpowered" {
    test_powered_flag = false;
    test_powered_pos = .{ 0, -1, 0 };
    var torch = RedstoneTorch.init(0, 0, 0, .down);

    const sig = torch.update(makeCtx(0, 0));
    try std.testing.expect(sig != null);
    try std.testing.expectEqual(@as(u4, 15), sig.?.strength);
    // Signal at block above (0, 1, 0).
    try std.testing.expectEqual(@as(i32, 1), sig.?.y);
}

test "torch turns off when mounting block is powered (NOT gate)" {
    test_powered_pos = .{ 0, -1, 0 };
    test_powered_flag = false;
    var torch = RedstoneTorch.init(0, 0, 0, .down);

    // First update with no power — torch is lit.
    _ = torch.update(makeCtx(0, 0));

    // Now power the mounting block.
    test_powered_flag = true;
    const sig = torch.update(makeCtx(1, 0));
    try std.testing.expect(sig == null);
    try std.testing.expect(!torch.lit);
}

test "torch burnout after rapid toggling" {
    test_powered_pos = .{ 0, -1, 0 };
    var torch = RedstoneTorch.init(0, 0, 0, .down);

    // Toggle rapidly 8 times within 60 ticks.
    var tick: u64 = 0;
    var i: u8 = 0;
    while (i < 8) : (i += 1) {
        test_powered_flag = (i % 2 == 0);
        _ = torch.update(makeCtx(tick, 0));
        tick += 2;
    }

    // Should be burned out now.
    try std.testing.expect(torch.burnout_start > 0);

    // During burnout, output is null.
    test_powered_flag = false;
    const sig = torch.update(makeCtx(tick + 1, 0));
    try std.testing.expect(sig == null);

    // After 160 ticks, should recover.
    const recovery_tick = torch.burnout_start + RedstoneTorch.BURNOUT_COOLDOWN;
    test_powered_flag = false;
    const sig2 = torch.update(makeCtx(recovery_tick, 0));
    try std.testing.expect(sig2 != null);
    try std.testing.expectEqual(@as(u4, 15), sig2.?.strength);
}

// --- Redstone Lamp tests ------------------------------------------------------

test "lamp lights up when powered" {
    test_powered_pos = .{ 3, 3, 3 };
    test_powered_flag = true;
    var lamp = RedstoneLamp.init(3, 3, 3);

    _ = lamp.update(makeCtx(0, 0));
    try std.testing.expect(lamp.lit);
    try std.testing.expectEqual(@as(u4, 15), lamp.lightLevel());
}

test "lamp turns off after 2-tick delay" {
    test_powered_pos = .{ 0, 0, 0 };
    test_powered_flag = true;
    var lamp = RedstoneLamp.init(0, 0, 0);

    // Power on.
    _ = lamp.update(makeCtx(0, 0));
    try std.testing.expect(lamp.lit);

    // Remove power.
    test_powered_flag = false;
    _ = lamp.update(makeCtx(1, 0));
    // Should still be lit (within delay).
    try std.testing.expect(lamp.lit);

    _ = lamp.update(makeCtx(2, 0));
    // Still within delay (tick 1 to tick 2 = 1 tick elapsed).
    try std.testing.expect(lamp.lit);

    _ = lamp.update(makeCtx(3, 0));
    // Now 2 ticks have elapsed since power loss at tick 1.
    try std.testing.expect(!lamp.lit);
    try std.testing.expectEqual(@as(u4, 0), lamp.lightLevel());
}

test "lamp stays lit when power is restored during delay" {
    test_powered_pos = .{ 0, 0, 0 };
    test_powered_flag = true;
    var lamp = RedstoneLamp.init(0, 0, 0);

    _ = lamp.update(makeCtx(0, 0));
    try std.testing.expect(lamp.lit);

    // Remove power.
    test_powered_flag = false;
    _ = lamp.update(makeCtx(1, 0));
    try std.testing.expect(lamp.lit);

    // Restore power before delay expires.
    test_powered_flag = true;
    _ = lamp.update(makeCtx(2, 0));
    try std.testing.expect(lamp.lit);

    // Remove again and wait.
    test_powered_flag = false;
    _ = lamp.update(makeCtx(3, 0));
    _ = lamp.update(makeCtx(4, 0));
    _ = lamp.update(makeCtx(5, 0));
    try std.testing.expect(!lamp.lit);
}

// --- Target Block tests -------------------------------------------------------

test "target block hit at center gives 15" {
    var tb = TargetBlock.init(0, 0, 0);
    tb = tb.hit(0.0, false, 10);
    try std.testing.expectEqual(@as(u4, 15), tb.hit_strength);
}

test "target block hit at edge gives 1" {
    var tb = TargetBlock.init(0, 0, 0);
    tb = tb.hit(TargetBlock.OUTER_RADIUS, false, 10);
    try std.testing.expectEqual(@as(u4, 1), tb.hit_strength);
}

test "target block non-arrow signal expires after 8 ticks" {
    var tb = TargetBlock.init(0, 0, 0);
    tb = tb.hit(0.0, false, 10);

    const s1 = tb.update(makeCtx(17, 0));
    try std.testing.expect(s1 != null);

    const s2 = tb.update(makeCtx(18, 0));
    try std.testing.expect(s2 == null);
}

test "target block arrow signal persists until removed" {
    var tb = TargetBlock.init(0, 0, 0);
    tb = tb.hit(0.0, true, 10);

    const s1 = tb.update(makeCtx(1000, 0));
    try std.testing.expect(s1 != null);

    tb = tb.removeArrow();
    try std.testing.expectEqual(@as(u4, 0), tb.hit_strength);
}

// --- Note Block tests ---------------------------------------------------------

test "note block pitch cycles through 25 values" {
    var nb = NoteBlock.init(0, 0, 0);
    try std.testing.expectEqual(@as(u5, 0), nb.pitch);

    // Cycle 25 times to wrap.
    var i: u8 = 0;
    while (i < 25) : (i += 1) {
        nb = nb.cyclePitch();
    }
    try std.testing.expectEqual(@as(u5, 0), nb.pitch);
}

test "note block instrument can be set" {
    var nb = NoteBlock.init(0, 0, 0);
    nb = nb.setInstrument(.bell);
    try std.testing.expectEqual(NoteBlock.Instrument.bell, nb.instrument);
}

test "note block particle color at pitch 0" {
    const nb = NoteBlock.init(0, 0, 0);
    const color = nb.particleColor();
    // Verify all color components are in the valid [0,1] range.
    try std.testing.expect(color[0] >= 0.0 and color[0] <= 1.0);
    try std.testing.expect(color[1] >= 0.0 and color[1] <= 1.0);
    try std.testing.expect(color[2] >= 0.0 and color[2] <= 1.0);
}

test "note block does not output redstone signal" {
    test_powered_pos = .{ 0, 0, 0 };
    test_powered_flag = false;
    var nb = NoteBlock.init(0, 0, 0);
    const sig = nb.update(makeCtx(0, 0));
    try std.testing.expect(sig == null);
}

// --- Sculk Sensor tests -------------------------------------------------------

test "sculk sensor detects vibration within range" {
    var sensor = SculkSensor.init(0, 0, 0);
    sensor = sensor.onVibration(3, 0, 0, .block_place, false, 100);
    try std.testing.expectEqual(@as(u4, 7), sensor.output_strength);
}

test "sculk sensor ignores vibration beyond 8 blocks" {
    var sensor = SculkSensor.init(0, 0, 0);
    sensor = sensor.onVibration(9, 0, 0, .explosion, false, 100);
    try std.testing.expectEqual(@as(u4, 0), sensor.output_strength);
}

test "sculk sensor blocked by wool" {
    var sensor = SculkSensor.init(0, 0, 0);
    sensor = sensor.onVibration(3, 0, 0, .explosion, true, 100);
    try std.testing.expectEqual(@as(u4, 0), sensor.output_strength);
}

test "sculk sensor cooldown prevents rapid re-detection" {
    var sensor = SculkSensor.init(0, 0, 0);
    sensor = sensor.onVibration(1, 0, 0, .walking, false, 100);
    try std.testing.expectEqual(@as(u4, 1), sensor.output_strength);

    // Try again within cooldown window.
    sensor = sensor.onVibration(1, 0, 0, .explosion, false, 110);
    // Should still show previous detection strength.
    try std.testing.expectEqual(@as(u4, 1), sensor.output_strength);

    // After cooldown (40 ticks).
    sensor = sensor.onVibration(1, 0, 0, .explosion, false, 140);
    try std.testing.expectEqual(@as(u4, 15), sensor.output_strength);
}

test "sculk sensor signal expires after cooldown" {
    var sensor = SculkSensor.init(0, 0, 0);
    sensor = sensor.onVibration(1, 0, 0, .block_break, false, 100);

    const s1 = sensor.update(makeCtx(120, 0));
    try std.testing.expect(s1 != null);
    try std.testing.expectEqual(@as(u4, 6), s1.?.strength);

    // After cooldown.
    const s2 = sensor.update(makeCtx(140, 0));
    try std.testing.expect(s2 == null);
    try std.testing.expectEqual(@as(u4, 0), sensor.output_strength);
}

test "sculk sensor vibration kind signal strengths" {
    try std.testing.expectEqual(@as(u4, 1), @intFromEnum(SculkSensor.VibrationKind.walking));
    try std.testing.expectEqual(@as(u4, 3), @intFromEnum(SculkSensor.VibrationKind.swimming));
    try std.testing.expectEqual(@as(u4, 6), @intFromEnum(SculkSensor.VibrationKind.block_break));
    try std.testing.expectEqual(@as(u4, 7), @intFromEnum(SculkSensor.VibrationKind.block_place));
    try std.testing.expectEqual(@as(u4, 15), @intFromEnum(SculkSensor.VibrationKind.explosion));
}
