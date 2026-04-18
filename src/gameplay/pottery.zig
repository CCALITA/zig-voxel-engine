const std = @import("std");

pub const PotteryPattern = enum {
    angler,
    archer,
    arms_up,
    blade,
    brewer,
    burn,
    danger,
    explorer,
    friend,
    heart,
    heartbreak,
    howl,
    miner,
    mourner,
    plenty,
    prize,
    sheaf,
    shelter,
    skull,
    snort,
};

pub const DecoratedPot = struct {
    patterns: [4]?PotteryPattern,

    pub fn combineSherds(sherds: [4]?PotteryPattern) DecoratedPot {
        return .{ .patterns = sherds };
    }

    pub fn getPatternForSide(pot: DecoratedPot, side: u2) ?PotteryPattern {
        return pot.patterns[side];
    }

    pub fn isEmpty(pot: DecoratedPot) bool {
        for (pot.patterns) |p| {
            if (p != null) return false;
        }
        return true;
    }
};

test "combine 4 sherds" {
    const pot = DecoratedPot.combineSherds(.{
        .angler,
        .archer,
        .blade,
        .heart,
    });
    try std.testing.expectEqual(PotteryPattern.angler, pot.patterns[0].?);
    try std.testing.expectEqual(PotteryPattern.archer, pot.patterns[1].?);
    try std.testing.expectEqual(PotteryPattern.blade, pot.patterns[2].?);
    try std.testing.expectEqual(PotteryPattern.heart, pot.patterns[3].?);
}

test "partial sherds - 2 sherds and 2 blank" {
    const pot = DecoratedPot.combineSherds(.{
        .brewer,
        null,
        .skull,
        null,
    });
    try std.testing.expectEqual(PotteryPattern.brewer, pot.patterns[0].?);
    try std.testing.expect(pot.patterns[1] == null);
    try std.testing.expectEqual(PotteryPattern.skull, pot.patterns[2].?);
    try std.testing.expect(pot.patterns[3] == null);
}

test "all patterns valid" {
    const all_patterns = [_]PotteryPattern{
        .angler,    .archer, .arms_up,    .blade,
        .brewer,    .burn,   .danger,     .explorer,
        .friend,    .heart,  .heartbreak, .howl,
        .miner,     .mourner,.plenty,     .prize,
        .sheaf,     .shelter,.skull,      .snort,
    };
    try std.testing.expectEqual(@as(usize, 20), all_patterns.len);
    for (all_patterns, 0..) |pattern, i| {
        const pot = DecoratedPot.combineSherds(.{ pattern, null, null, null });
        try std.testing.expectEqual(all_patterns[i], pot.getPatternForSide(0).?);
    }
}

test "empty check" {
    const empty_pot = DecoratedPot.combineSherds(.{ null, null, null, null });
    try std.testing.expect(empty_pot.isEmpty());

    const non_empty = DecoratedPot.combineSherds(.{ .snort, null, null, null });
    try std.testing.expect(!non_empty.isEmpty());
}

test "getPatternForSide" {
    const pot = DecoratedPot.combineSherds(.{
        .explorer,
        .mourner,
        null,
        .plenty,
    });
    try std.testing.expectEqual(PotteryPattern.explorer, pot.getPatternForSide(0).?);
    try std.testing.expectEqual(PotteryPattern.mourner, pot.getPatternForSide(1).?);
    try std.testing.expect(pot.getPatternForSide(2) == null);
    try std.testing.expectEqual(PotteryPattern.plenty, pot.getPatternForSide(3).?);
}
