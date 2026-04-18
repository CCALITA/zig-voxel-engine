const std = @import("std");

pub const SnifferDrop = enum {
    torchflower_seed,
    pitcher_pod,
};

pub const SnifferEntity = struct {
    x: f32,
    y: f32,
    z: f32,
    health: f32 = 14,
    dig_cooldown: f32 = 0,
    dig_progress: f32 = 0,
    is_digging: bool = false,
    baby: bool = false,
    growth_timer: f32 = 24000,

    const dig_cooldown_duration: f32 = 480.0; // 8 minutes in seconds
    const dig_duration: f32 = 4.25;

    pub fn update(self: *SnifferEntity, dt: f32) void {
        if (self.dig_cooldown > 0) {
            self.dig_cooldown = @max(self.dig_cooldown - dt, 0);
        }
        if (self.baby) {
            self.growth_timer = @max(self.growth_timer - dt, 0);
            if (self.growth_timer <= 0) {
                self.baby = false;
            }
        }
    }

    pub fn startDigging(self: *SnifferEntity) bool {
        if (self.dig_cooldown > 0 or self.is_digging) return false;
        self.is_digging = true;
        self.dig_progress = 0;
        return true;
    }

    pub fn tickDig(self: *SnifferEntity, dt: f32) ?SnifferDrop {
        if (!self.is_digging) return null;
        self.dig_progress += dt;
        if (self.dig_progress < dig_duration) return null;

        self.is_digging = false;
        self.dig_progress = 0;
        self.dig_cooldown = dig_cooldown_duration;

        // Deterministic 50/50 based on fractional part of x position
        const frac = self.x - @floor(self.x);
        if (frac < 0.5) {
            return .torchflower_seed;
        } else {
            return .pitcher_pod;
        }
    }

    pub fn isAdult(self: SnifferEntity) bool {
        return !self.baby;
    }

    pub fn canBreed(self: SnifferEntity) bool {
        return self.isAdult();
    }

    pub fn breed(self: *SnifferEntity) void {
        _ = self;
    }
};

test "dig cooldown prevents immediate re-dig" {
    var sniffer = SnifferEntity{ .x = 0.3, .y = 0, .z = 0 };
    try std.testing.expect(sniffer.startDigging());

    const drop = sniffer.tickDig(5.0);
    try std.testing.expect(drop != null);
    try std.testing.expect(!sniffer.is_digging);
    try std.testing.expectApproxEqAbs(@as(f32, 480.0), sniffer.dig_cooldown, 0.001);

    try std.testing.expect(!sniffer.startDigging());

    sniffer.update(200.0);
    try std.testing.expect(!sniffer.startDigging());

    sniffer.update(280.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), sniffer.dig_cooldown, 0.001);
    try std.testing.expect(sniffer.startDigging());
}

test "dig produces a drop after dig duration" {
    var s1 = SnifferEntity{ .x = 0.2, .y = 0, .z = 0 };
    try std.testing.expect(s1.startDigging());
    try std.testing.expect(s1.tickDig(2.0) == null);
    try std.testing.expect(s1.tickDig(3.0).? == .torchflower_seed);

    var s2 = SnifferEntity{ .x = 0.7, .y = 0, .z = 0 };
    try std.testing.expect(s2.startDigging());
    try std.testing.expect(s2.tickDig(5.0).? == .pitcher_pod);
}

test "baby grows into adult" {
    var sniffer = SnifferEntity{ .x = 0, .y = 0, .z = 0, .baby = true };
    try std.testing.expect(!sniffer.isAdult());

    sniffer.update(12000.0);
    try std.testing.expect(!sniffer.isAdult());

    sniffer.update(12000.0);
    try std.testing.expect(sniffer.isAdult());
    try std.testing.expect(!sniffer.baby);
}

test "breeding requires adult" {
    const baby = SnifferEntity{ .x = 0, .y = 0, .z = 0, .baby = true };
    try std.testing.expect(!baby.canBreed());

    const adult = SnifferEntity{ .x = 0, .y = 0, .z = 0, .baby = false };
    try std.testing.expect(adult.canBreed());
}
