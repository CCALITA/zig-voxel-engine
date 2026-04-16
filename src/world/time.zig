/// Day/night time system for the voxel engine.
/// Maps 24000 ticks to a 20-minute real-time day cycle with smooth
/// lighting, sky colour, and fog colour transitions.
const std = @import("std");
const math = std.math;

pub const TICKS_PER_DAY: u32 = 24000;
pub const SECONDS_PER_DAY: f64 = 1200.0; // 20 minutes real-time

pub const DayPhase = enum { dawn, day, dusk, night };

pub const GameTime = struct {
    tick: u32 = 0, // 0-23999
    real_time: f64 = 0.0, // accumulated real seconds

    /// Advance the clock by `dt` real seconds.
    const ticks_per_sec: f64 = @as(f64, @floatFromInt(TICKS_PER_DAY)) / SECONDS_PER_DAY;

    pub fn update(self: *GameTime, dt: f64) void {
        self.real_time += dt;
        const new_tick: u64 = @intFromFloat(@floor(self.real_time * ticks_per_sec));
        self.tick = @intCast(new_tick % TICKS_PER_DAY);
    }

    /// Return the current phase of the day.
    ///   Dawn:  23000-24000 and 0-1000
    ///   Day:   1000-11000
    ///   Dusk:  11000-13000
    ///   Night: 13000-23000
    pub fn getPhase(self: *const GameTime) DayPhase {
        const t = self.tick;
        if (t >= 23000 or t < 1000) return .dawn;
        if (t < 11000) return .day;
        if (t < 13000) return .dusk;
        return .night;
    }

    /// Sun angle in degrees [0, 360).
    /// Tick 0 = sunrise = 0 degrees, tick 6000 = noon = 90 degrees,
    /// tick 12000 = sunset = 180, tick 18000 = midnight = 270.
    pub fn getSunAngle(self: *const GameTime) f32 {
        const fraction: f32 = @as(f32, @floatFromInt(self.tick)) / @as(f32, @floatFromInt(TICKS_PER_DAY));
        return fraction * 360.0;
    }

    /// Ambient light intensity on a smooth sine curve.
    /// Ranges from 0.15 (midnight, tick 18000) to 1.0 (noon, tick 6000).
    pub fn getAmbientLight(self: *const GameTime) f32 {
        const angle_rad: f32 = self.getSunAngle() * (math.pi / 180.0);
        // sin(angle_rad) is 1.0 at 90 deg (noon) and -1.0 at 270 deg (midnight).
        const sine: f32 = @sin(angle_rad);
        // Map [-1, 1] to [0.15, 1.0].
        return 0.575 + 0.425 * sine;
    }

    /// Sky colour (RGB) interpolated between day, dawn/dusk, and night palettes.
    pub fn getSkyColor(self: *const GameTime) [3]f32 {
        return blendColor(self.tick, sky_day, sky_transition, sky_night);
    }

    /// Fog colour (RGB) — slightly desaturated variant of the sky colour.
    pub fn getFogColor(self: *const GameTime) [3]f32 {
        return blendColor(self.tick, fog_day, fog_transition, fog_night);
    }
};

// -- Colour palettes --------------------------------------------------------

const sky_day = [3]f32{ 0.53, 0.81, 0.92 };
const sky_transition = [3]f32{ 0.85, 0.45, 0.25 };
const sky_night = [3]f32{ 0.01, 0.01, 0.05 };

const fog_day = [3]f32{ 0.60, 0.82, 0.90 };
const fog_transition = [3]f32{ 0.80, 0.50, 0.30 };
const fog_night = [3]f32{ 0.02, 0.02, 0.06 };

// -- Helpers ----------------------------------------------------------------

/// Linear interpolation between two RGB colours.
fn lerpColor(a: [3]f32, b: [3]f32, t: f32) [3]f32 {
    return .{
        a[0] + (b[0] - a[0]) * t,
        a[1] + (b[1] - a[1]) * t,
        a[2] + (b[2] - a[2]) * t,
    };
}

/// Blend day/transition/night colours based on the current tick.
///
/// Transition zones (each 2000 ticks wide):
///   Dawn  : 23000..1000  — night -> transition -> day
///   Dusk  : 11000..13000 — day   -> transition -> night
/// Outside these zones the colour is pure day or pure night.
fn blendColor(tick: u32, day: [3]f32, transition: [3]f32, night: [3]f32) [3]f32 {
    // Dawn: 23000 -> 0 -> 1000  (total 2000 ticks)
    // Remap to a linear 0..2000 range.
    const dawn_t = blk: {
        if (tick >= 23000) break :blk tick - 23000; // 0..999
        if (tick < 1000) break :blk tick + 1000; // 1000..1999
        break :blk @as(u32, 2001); // sentinel: not in dawn window
    };

    if (dawn_t <= 2000) {
        const f: f32 = @as(f32, @floatFromInt(dawn_t)) / 2000.0;
        // 0.0 = full night, 0.5 = peak transition, 1.0 = full day
        if (f < 0.5) {
            return lerpColor(night, transition, f * 2.0);
        }
        return lerpColor(transition, day, (f - 0.5) * 2.0);
    }

    // Dusk: 11000 -> 13000 (2000 ticks)
    if (tick >= 11000 and tick < 13000) {
        const f: f32 = @as(f32, @floatFromInt(tick - 11000)) / 2000.0;
        if (f < 0.5) {
            return lerpColor(day, transition, f * 2.0);
        }
        return lerpColor(transition, night, (f - 0.5) * 2.0);
    }

    // Pure day or pure night
    if (tick >= 1000 and tick < 11000) return day;
    return night;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

fn approxEq(a: f32, b: f32) bool {
    return @abs(a - b) < 0.02;
}

fn approxEqColor(a: [3]f32, b: [3]f32) bool {
    return approxEq(a[0], b[0]) and approxEq(a[1], b[1]) and approxEq(a[2], b[2]);
}

test "time advances with dt" {
    var gt = GameTime{};
    try std.testing.expectEqual(@as(u32, 0), gt.tick);

    gt.update(1.0); // 1 second = 20 ticks
    try std.testing.expectEqual(@as(u32, 20), gt.tick);

    gt.update(59.0); // total 60 s = 1200 ticks
    try std.testing.expectEqual(@as(u32, 1200), gt.tick);
}

test "time wraps around at TICKS_PER_DAY" {
    var gt = GameTime{};
    // A full day is 1200 seconds.
    gt.update(1200.0);
    try std.testing.expectEqual(@as(u32, 0), gt.tick);

    // 1.5 days
    gt = GameTime{};
    gt.update(1800.0);
    try std.testing.expectEqual(@as(u32, 12000), gt.tick);
}

test "noon = maximum ambient light" {
    const gt = GameTime{ .tick = 6000 };
    const light = gt.getAmbientLight();
    try std.testing.expect(approxEq(light, 1.0));
}

test "midnight = minimum ambient light" {
    const gt = GameTime{ .tick = 18000 };
    const light = gt.getAmbientLight();
    try std.testing.expect(approxEq(light, 0.15));
}

test "sky colour at noon is blue" {
    const gt = GameTime{ .tick = 6000 };
    const color = gt.getSkyColor();
    try std.testing.expect(approxEqColor(color, sky_day));
}

test "sky colour at midnight is dark" {
    const gt = GameTime{ .tick = 18000 };
    const color = gt.getSkyColor();
    try std.testing.expect(approxEqColor(color, sky_night));
}

test "phase transitions at correct ticks" {
    // Dawn spans 23000..1000
    try std.testing.expectEqual(DayPhase.dawn, (GameTime{ .tick = 0 }).getPhase());
    try std.testing.expectEqual(DayPhase.dawn, (GameTime{ .tick = 500 }).getPhase());
    try std.testing.expectEqual(DayPhase.dawn, (GameTime{ .tick = 23500 }).getPhase());

    // Day: 1000..11000
    try std.testing.expectEqual(DayPhase.day, (GameTime{ .tick = 1000 }).getPhase());
    try std.testing.expectEqual(DayPhase.day, (GameTime{ .tick = 6000 }).getPhase());
    try std.testing.expectEqual(DayPhase.day, (GameTime{ .tick = 10999 }).getPhase());

    // Dusk: 11000..13000
    try std.testing.expectEqual(DayPhase.dusk, (GameTime{ .tick = 11000 }).getPhase());
    try std.testing.expectEqual(DayPhase.dusk, (GameTime{ .tick = 12000 }).getPhase());
    try std.testing.expectEqual(DayPhase.dusk, (GameTime{ .tick = 12999 }).getPhase());

    // Night: 13000..23000
    try std.testing.expectEqual(DayPhase.night, (GameTime{ .tick = 13000 }).getPhase());
    try std.testing.expectEqual(DayPhase.night, (GameTime{ .tick = 18000 }).getPhase());
    try std.testing.expectEqual(DayPhase.night, (GameTime{ .tick = 22999 }).getPhase());
}

test "sun angle at key ticks" {
    try std.testing.expect(approxEq((GameTime{ .tick = 0 }).getSunAngle(), 0.0));
    try std.testing.expect(approxEq((GameTime{ .tick = 6000 }).getSunAngle(), 90.0));
    try std.testing.expect(approxEq((GameTime{ .tick = 12000 }).getSunAngle(), 180.0));
    try std.testing.expect(approxEq((GameTime{ .tick = 18000 }).getSunAngle(), 270.0));
}

test "ambient light is monotonic sunrise to noon" {
    var prev: f32 = 0.0;
    var tick: u32 = 0;
    while (tick <= 6000) : (tick += 500) {
        const light = (GameTime{ .tick = tick }).getAmbientLight();
        try std.testing.expect(light >= prev);
        prev = light;
    }
}

test "fog colour at noon is close to day fog" {
    const gt = GameTime{ .tick = 6000 };
    const color = gt.getFogColor();
    try std.testing.expect(approxEqColor(color, fog_day));
}
