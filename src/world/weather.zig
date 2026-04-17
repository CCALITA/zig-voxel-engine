/// Weather system for the voxel engine.
/// Manages weather state transitions (clear, rain, thunder) with
/// smooth intensity ramping and lightning strikes. Only uses `std`.
const std = @import("std");

pub const WeatherType = enum { clear, rain, thunder };

pub const WeatherState = struct {
    current: WeatherType = .clear,
    timer: f32 = 600.0, // seconds until next transition
    rain_intensity: f32 = 0.0, // 0-1, ramps up/down
    lightning_timer: f32 = 0.0,

    // Internal PRNG state for deterministic weather variation
    rng: std.Random.DefaultPrng,

    // Whether a lightning strike should occur this frame
    lightning_strike: bool = false,

    /// Create a new WeatherState starting at clear weather.
    pub fn init() WeatherState {
        return initWithSeed(0);
    }

    /// Create a new WeatherState with a specific seed (useful for testing).
    pub fn initWithSeed(seed: u64) WeatherState {
        var rng = std.Random.DefaultPrng.init(seed);
        const timer = randomRange(&rng, clear_duration[0], clear_duration[1]);
        return .{
            .current = .clear,
            .timer = timer,
            .rain_intensity = 0.0,
            .lightning_timer = 0.0,
            .rng = rng,
            .lightning_strike = false,
        };
    }

    /// Advance the weather simulation by `dt` seconds.
    pub fn update(self: *WeatherState, dt: f32) void {
        self.lightning_strike = false;

        // Ramp rain intensity toward the target
        const target_intensity: f32 = switch (self.current) {
            .clear => intensity_clear,
            .rain => intensity_rain,
            .thunder => intensity_thunder,
        };
        const ramp_speed: f32 = 0.1; // per second
        if (self.rain_intensity < target_intensity) {
            self.rain_intensity = @min(self.rain_intensity + ramp_speed * dt, target_intensity);
        } else if (self.rain_intensity > target_intensity) {
            self.rain_intensity = @max(self.rain_intensity - ramp_speed * dt, target_intensity);
        }

        // Lightning during thunder
        if (self.current == .thunder) {
            self.lightning_timer -= dt;
            if (self.lightning_timer <= 0.0) {
                self.lightning_strike = true;
                self.lightning_timer = randomRange(&self.rng, lightning_interval[0], lightning_interval[1]);
            }
        }

        // Count down transition timer
        self.timer -= dt;
        if (self.timer <= 0.0) {
            self.transition();
        }
    }

    /// Sky darkening factor: 0.0 = clear, 0.3 = rain, 0.5 = thunder.
    /// Interpolated based on rain_intensity for smooth transitions.
    pub fn getSkyDarkening(self: *const WeatherState) f32 {
        const thunder_extra = darkening_thunder - darkening_rain;
        const thunder_ramp = intensity_thunder - intensity_rain;
        return switch (self.current) {
            .clear => darkening_rain * self.rain_intensity,
            .rain => darkening_rain * self.rain_intensity / intensity_rain,
            .thunder => darkening_rain + thunder_extra * (self.rain_intensity - intensity_rain) / thunder_ramp,
        };
    }

    /// Returns true on the frame when a lightning strike occurs.
    pub fn shouldLightningStrike(self: *const WeatherState) bool {
        return self.lightning_strike;
    }

    /// Returns true when it is raining (rain or thunder weather).
    pub fn isRaining(self: *const WeatherState) bool {
        return self.current == .rain or self.current == .thunder;
    }

    /// Returns true when thunder is active.
    pub fn isThundering(self: *const WeatherState) bool {
        return self.current == .thunder;
    }

    /// Returns true if rain is falling (snow in cold biomes).
    pub fn getSnowBiomeAccumulation(self: *const WeatherState) bool {
        return self.isRaining();
    }

    // -- Private helpers ------------------------------------------------------

    // Sky darkening levels per weather type
    const darkening_rain: f32 = 0.3;
    const darkening_thunder: f32 = 0.5;

    // Rain intensity targets per weather type
    const intensity_clear: f32 = 0.0;
    const intensity_rain: f32 = 0.7;
    const intensity_thunder: f32 = 1.0;

    // Transition duration ranges (seconds) [min, max] -- avg is midpoint
    const clear_duration = [2]f32{ 480.0, 720.0 }; // avg 10 min
    const rain_to_thunder_duration = [2]f32{ 240.0, 360.0 }; // avg 5 min
    const rain_to_clear_duration = [2]f32{ 384.0, 576.0 }; // avg 8 min
    const thunder_duration = [2]f32{ 144.0, 216.0 }; // avg 3 min
    const lightning_interval = [2]f32{ 5.0, 15.0 };

    fn transition(self: *WeatherState) void {
        switch (self.current) {
            .clear => {
                self.current = .rain;
                if (self.rng.random().boolean()) {
                    self.timer = randomRange(&self.rng, rain_to_thunder_duration[0], rain_to_thunder_duration[1]);
                } else {
                    self.timer = randomRange(&self.rng, rain_to_clear_duration[0], rain_to_clear_duration[1]);
                }
            },
            .rain => {
                if (self.rain_intensity >= 0.5 and self.rng.random().boolean()) {
                    self.current = .thunder;
                    self.timer = randomRange(&self.rng, thunder_duration[0], thunder_duration[1]);
                    self.lightning_timer = randomRange(&self.rng, lightning_interval[0], lightning_interval[1]);
                } else {
                    self.current = .clear;
                    self.timer = randomRange(&self.rng, clear_duration[0], clear_duration[1]);
                }
            },
            .thunder => {
                self.current = .rain;
                self.timer = randomRange(&self.rng, rain_to_clear_duration[0], rain_to_clear_duration[1]);
                self.lightning_timer = 0.0;
            },
        }
    }
};

/// Generate a random f32 in [min, max) using the given PRNG.
fn randomRange(rng: *std.Random.DefaultPrng, min: f32, max: f32) f32 {
    const random = rng.random();
    return min + random.float(f32) * (max - min);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "init returns clear weather" {
    const ws = WeatherState.init();
    try std.testing.expectEqual(WeatherType.clear, ws.current);
    try std.testing.expect(ws.rain_intensity == 0.0);
    try std.testing.expect(!ws.isRaining());
    try std.testing.expect(!ws.isThundering());
    try std.testing.expect(!ws.shouldLightningStrike());
}

test "time advances and timer decreases" {
    var ws = WeatherState.init();
    const initial_timer = ws.timer;
    ws.update(10.0);
    try std.testing.expect(ws.timer < initial_timer);
    try std.testing.expect(ws.timer > 0.0); // 10s is not enough to exhaust ~600s timer
}

test "transitions occur when timer expires" {
    var ws = WeatherState.initWithSeed(42);
    // Force timer to near zero and advance past it
    ws.timer = 0.5;
    ws.update(1.0);
    // Should have transitioned away from clear
    try std.testing.expectEqual(WeatherType.rain, ws.current);
}

test "sky darkening is zero for clear weather" {
    const ws = WeatherState.init();
    try std.testing.expect(ws.getSkyDarkening() == 0.0);
}

test "sky darkening increases during rain" {
    var ws = WeatherState.initWithSeed(42);
    ws.current = .rain;
    ws.rain_intensity = 0.7;
    const darkening = ws.getSkyDarkening();
    try std.testing.expect(darkening > 0.0);
    try std.testing.expect(darkening <= 0.3 + 0.01); // approximately 0.3
}

test "sky darkening is highest during thunder" {
    var ws = WeatherState.initWithSeed(42);
    ws.current = .thunder;
    ws.rain_intensity = 1.0;
    const darkening = ws.getSkyDarkening();
    try std.testing.expect(darkening >= 0.45); // close to 0.5
    try std.testing.expect(darkening <= 0.55);
}

test "lightning only during thunder" {
    // Clear weather: no lightning
    var ws_clear = WeatherState.initWithSeed(99);
    var i: u32 = 0;
    while (i < 100) : (i += 1) {
        ws_clear.update(0.016);
        if (ws_clear.current != .clear) break;
        try std.testing.expect(!ws_clear.shouldLightningStrike());
    }

    // Thunder weather: lightning should fire eventually
    var ws_thunder = WeatherState.initWithSeed(7);
    ws_thunder.current = .thunder;
    ws_thunder.rain_intensity = 1.0;
    ws_thunder.lightning_timer = 0.5;
    ws_thunder.timer = 999.0; // long timer so we stay in thunder

    var found_strike = false;
    var step: u32 = 0;
    while (step < 2000) : (step += 1) {
        ws_thunder.update(0.016);
        if (ws_thunder.shouldLightningStrike()) {
            found_strike = true;
            break;
        }
    }
    try std.testing.expect(found_strike);
}

test "rain intensity ramps up when entering rain" {
    var ws = WeatherState.initWithSeed(42);
    ws.current = .rain;
    ws.rain_intensity = 0.0;
    ws.timer = 999.0;

    // After some time, intensity should increase
    ws.update(5.0); // 5s * 0.1/s = 0.5 increase
    try std.testing.expect(ws.rain_intensity > 0.0);
    try std.testing.expect(ws.rain_intensity <= 0.7);
}

test "rain intensity ramps down when clearing" {
    var ws = WeatherState.initWithSeed(42);
    ws.current = .clear;
    ws.rain_intensity = 0.7;
    ws.timer = 999.0;

    ws.update(5.0); // 5s * 0.1/s = 0.5 decrease
    try std.testing.expect(ws.rain_intensity < 0.7);
    try std.testing.expect(ws.rain_intensity >= 0.0);
}

test "snow biome accumulation matches rain state" {
    var ws = WeatherState.init();
    try std.testing.expect(!ws.getSnowBiomeAccumulation());

    ws.current = .rain;
    try std.testing.expect(ws.getSnowBiomeAccumulation());

    ws.current = .thunder;
    try std.testing.expect(ws.getSnowBiomeAccumulation());

    ws.current = .clear;
    try std.testing.expect(!ws.getSnowBiomeAccumulation());
}

test "full weather cycle: clear -> rain -> thunder -> rain -> clear" {
    var ws = WeatherState.initWithSeed(123);
    try std.testing.expectEqual(WeatherType.clear, ws.current);

    // Force transition: clear -> rain
    ws.timer = 0.1;
    ws.update(0.2);
    try std.testing.expectEqual(WeatherType.rain, ws.current);

    // Force transition: rain -> (thunder or clear)
    ws.timer = 0.1;
    // Set high intensity to favor thunder path
    ws.rain_intensity = 0.7;
    ws.update(0.2);
    const after_rain = ws.current;
    try std.testing.expect(after_rain == .thunder or after_rain == .clear);

    if (after_rain == .thunder) {
        // Force transition: thunder -> rain
        ws.timer = 0.1;
        ws.update(0.2);
        try std.testing.expectEqual(WeatherType.rain, ws.current);
    }

    // Force transition back to clear eventually
    ws.timer = 0.1;
    ws.rain_intensity = 0.0; // low intensity favors clear path
    ws.update(0.2);
    // Should be rain or clear depending on current state
    try std.testing.expect(ws.current == .rain or ws.current == .clear);
}
