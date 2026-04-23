/// Smooth hotbar slot scrolling with mouse wheel support.
/// Provides lerp-based animation for visual slot transitions.
const std = @import("std");

pub const ScrollState = struct {
    target: u8 = 0,
    current: f32 = 0,

    const lerp_rate: f32 = 20.0;
    const max_slot: u8 = 8;

    pub fn setTarget(self: *ScrollState, slot: u8) void {
        self.target = @min(slot, max_slot);
    }

    pub fn update(self: *ScrollState, dt: f32) void {
        const target_f: f32 = @floatFromInt(self.target);
        const alpha = 1.0 - @exp(-lerp_rate * dt);
        self.current = self.current + (target_f - self.current) * alpha;
    }

    pub fn getCurrentSlot(self: ScrollState) u8 {
        const rounded = @round(self.current);
        const clamped = std.math.clamp(rounded, 0.0, @as(f32, @floatFromInt(max_slot)));
        return @intFromFloat(clamped);
    }

    pub fn getAnimOffset(self: ScrollState) f32 {
        const target_f: f32 = @floatFromInt(self.target);
        return self.current - target_f;
    }

    pub fn handleScroll(self: *ScrollState, delta: i32) void {
        const slots: i32 = @as(i32, max_slot) + 1;
        const current_i: i32 = @intCast(self.target);
        const raw = @mod(current_i - delta, slots);
        self.target = @intCast(raw);
    }
};

// -- Tests --

test "default state is slot 0" {
    const s = ScrollState{};
    try std.testing.expectEqual(@as(u8, 0), s.target);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), s.current, 0.001);
}

test "setTarget clamps to max slot" {
    var s = ScrollState{};
    s.setTarget(5);
    try std.testing.expectEqual(@as(u8, 5), s.target);
    s.setTarget(20);
    try std.testing.expectEqual(@as(u8, 8), s.target);
}

test "getCurrentSlot rounds current position" {
    var s = ScrollState{ .current = 2.3 };
    try std.testing.expectEqual(@as(u8, 2), s.getCurrentSlot());

    s.current = 2.7;
    try std.testing.expectEqual(@as(u8, 3), s.getCurrentSlot());

    s.current = 4.5;
    try std.testing.expectEqual(@as(u8, 5), s.getCurrentSlot());
}

test "getCurrentSlot clamps negative and overflow" {
    var s = ScrollState{ .current = -1.0 };
    try std.testing.expectEqual(@as(u8, 0), s.getCurrentSlot());

    s.current = 100.0;
    try std.testing.expectEqual(@as(u8, 8), s.getCurrentSlot());
}

test "getAnimOffset returns fractional distance from target" {
    var s = ScrollState{ .target = 3, .current = 3.0 };
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), s.getAnimOffset(), 0.001);

    s.current = 2.5;
    try std.testing.expectApproxEqAbs(@as(f32, -0.5), s.getAnimOffset(), 0.001);

    s.current = 3.8;
    try std.testing.expectApproxEqAbs(@as(f32, 0.8), s.getAnimOffset(), 0.001);
}

test "update lerps toward target" {
    var s = ScrollState{ .target = 5, .current = 0.0 };
    s.update(0.05);
    try std.testing.expect(s.current > 0.0);
    try std.testing.expect(s.current < 5.0);
}

test "update converges to target over time" {
    var s = ScrollState{ .target = 7, .current = 0.0 };
    for (0..200) |_| {
        s.update(0.016);
    }
    try std.testing.expectApproxEqAbs(@as(f32, 7.0), s.current, 0.01);
}

test "update with zero dt does not change current" {
    var s = ScrollState{ .target = 5, .current = 2.0 };
    s.update(0.0);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), s.current, 0.001);
}

test "handleScroll wraps forward through slots" {
    var s = ScrollState{};
    s.target = 8;
    s.handleScroll(-1);
    try std.testing.expectEqual(@as(u8, 0), s.target);
}

test "handleScroll wraps backward through slots" {
    var s = ScrollState{};
    s.target = 0;
    s.handleScroll(1);
    try std.testing.expectEqual(@as(u8, 8), s.target);
}

test "handleScroll increments and decrements within range" {
    var s = ScrollState{};
    s.target = 4;
    s.handleScroll(-1);
    try std.testing.expectEqual(@as(u8, 5), s.target);

    s.handleScroll(1);
    try std.testing.expectEqual(@as(u8, 4), s.target);
}

test "handleScroll with large delta wraps correctly" {
    var s = ScrollState{};
    s.target = 3;
    s.handleScroll(-11);
    try std.testing.expectEqual(@as(u8, 5), s.target);
}

test "full cycle: scroll, update, read slot and offset" {
    var s = ScrollState{};
    s.handleScroll(-3);
    try std.testing.expectEqual(@as(u8, 3), s.target);

    for (0..300) |_| {
        s.update(0.016);
    }
    try std.testing.expectEqual(@as(u8, 3), s.getCurrentSlot());
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), s.getAnimOffset(), 0.01);
}
