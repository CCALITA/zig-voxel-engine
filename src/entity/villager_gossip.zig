const std = @import("std");

pub const GossipType = enum(u3) {
    major_positive,
    minor_positive,
    minor_negative,
    major_negative,
    trading,
};

pub const Reputation = struct {
    scores: [5]i16 = [_]i16{0} ** 5,

    pub fn addGossip(self: *Reputation, gtype: GossipType, value: i16) void {
        self.scores[@intFromEnum(gtype)] += value;
    }

    pub fn getTotal(self: Reputation) i32 {
        var total: i32 = 0;
        for (self.scores) |s| {
            total += s;
        }
        return total;
    }

    pub fn getPriceMultiplier(self: Reputation) f32 {
        const total = self.getTotal();
        const raw: f32 = 1.0 - @as(f32, @floatFromInt(total)) * 0.01;
        return std.math.clamp(raw, 0.7, 1.5);
    }

    pub fn shouldShareGossip(distance: f32) bool {
        return distance <= 10.0;
    }

    pub fn spreadGossip(from: Reputation, to: *Reputation, gtype: GossipType) void {
        const idx = @intFromEnum(gtype);
        const half = @divTrunc(from.scores[idx], 2);
        to.scores[idx] += half;
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "default scores are all zero" {
    const rep = Reputation{};
    for (rep.scores) |s| {
        try std.testing.expectEqual(@as(i16, 0), s);
    }
}

test "addGossip increments correct slot" {
    var rep = Reputation{};
    rep.addGossip(.trading, 10);
    try std.testing.expectEqual(@as(i16, 10), rep.scores[@intFromEnum(GossipType.trading)]);
    try std.testing.expectEqual(@as(i16, 0), rep.scores[@intFromEnum(GossipType.major_positive)]);
}

test "addGossip accumulates values" {
    var rep = Reputation{};
    rep.addGossip(.minor_positive, 5);
    rep.addGossip(.minor_positive, 3);
    try std.testing.expectEqual(@as(i16, 8), rep.scores[@intFromEnum(GossipType.minor_positive)]);
}

test "getTotal sums all scores" {
    var rep = Reputation{};
    rep.addGossip(.major_positive, 10);
    rep.addGossip(.minor_negative, -5);
    rep.addGossip(.trading, 3);
    try std.testing.expectEqual(@as(i32, 8), rep.getTotal());
}

test "getPriceMultiplier with positive reputation" {
    var rep = Reputation{};
    rep.addGossip(.major_positive, 20);
    // 1.0 - 20*0.01 = 0.8
    try std.testing.expectApproxEqAbs(@as(f32, 0.8), rep.getPriceMultiplier(), 0.001);
}

test "getPriceMultiplier with negative reputation" {
    var rep = Reputation{};
    rep.addGossip(.major_negative, -20);
    // 1.0 - (-20)*0.01 = 1.2
    try std.testing.expectApproxEqAbs(@as(f32, 1.2), rep.getPriceMultiplier(), 0.001);
}

test "getPriceMultiplier clamps to minimum 0.7" {
    var rep = Reputation{};
    rep.addGossip(.major_positive, 100);
    // 1.0 - 100*0.01 = 0.0 -> clamped to 0.7
    try std.testing.expectApproxEqAbs(@as(f32, 0.7), rep.getPriceMultiplier(), 0.001);
}

test "getPriceMultiplier clamps to maximum 1.5" {
    var rep = Reputation{};
    rep.addGossip(.major_negative, -200);
    // 1.0 - (-200)*0.01 = 3.0 -> clamped to 1.5
    try std.testing.expectApproxEqAbs(@as(f32, 1.5), rep.getPriceMultiplier(), 0.001);
}

test "shouldShareGossip within and beyond range" {
    try std.testing.expect(Reputation.shouldShareGossip(5.0));
    try std.testing.expect(Reputation.shouldShareGossip(10.0));
    try std.testing.expect(!Reputation.shouldShareGossip(10.1));
}

test "spreadGossip halves score from source to target" {
    var from = Reputation{};
    from.addGossip(.trading, 20);
    var to = Reputation{};
    Reputation.spreadGossip(from, &to, .trading);
    try std.testing.expectEqual(@as(i16, 10), to.scores[@intFromEnum(GossipType.trading)]);
}

test "spreadGossip does not affect other types" {
    var from = Reputation{};
    from.addGossip(.trading, 20);
    from.addGossip(.major_positive, 50);
    var to = Reputation{};
    Reputation.spreadGossip(from, &to, .trading);
    try std.testing.expectEqual(@as(i16, 0), to.scores[@intFromEnum(GossipType.major_positive)]);
}

test "spreadGossip with odd value truncates toward zero" {
    var from = Reputation{};
    from.addGossip(.minor_positive, 7);
    var to = Reputation{};
    Reputation.spreadGossip(from, &to, .minor_positive);
    // 7 / 2 = 3 (truncated)
    try std.testing.expectEqual(@as(i16, 3), to.scores[@intFromEnum(GossipType.minor_positive)]);
}

test "getTotal on default reputation is zero" {
    const rep = Reputation{};
    try std.testing.expectEqual(@as(i32, 0), rep.getTotal());
}
