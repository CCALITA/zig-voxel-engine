const std = @import("std");

pub const DurabilityResult = struct { consumed: bool, broke: bool };
pub const DurabilityBar = struct { width_pct: f32, r: f32, g: f32, b: f32 };

/// Returns the maximum durability for the given item id, or 0 if the item has no durability.
pub fn getMaxDurability(item_id: u16) u16 {
    return switch (item_id) {
        // Wood tools
        257, 262, 267, 272, 277 => 59,
        // Stone tools
        258, 263, 268, 273, 278 => 131,
        // Iron tools
        259, 264, 269, 274, 279 => 250,
        // Gold tools
        260, 265, 270, 275, 280 => 32,
        // Diamond tools
        261, 266, 271, 276, 281 => 1561,
        // Shears
        307 => 238,
        // Fishing rod
        308 => 64,
        // Flint and steel
        309 => 64,
        // Bow
        333 => 384,
        else => 0,
    };
}

/// Determines whether a tool-use event consumes durability, accounting for the
/// Unbreaking enchantment. Returns whether durability was consumed and whether the
/// item broke (durability reached zero).
pub fn onToolUse(current_durability: u16, enchant_unbreaking_level: u8, rng_val: u32) DurabilityResult {
    if (enchant_unbreaking_level > 0) {
        const threshold = 100 / (@as(u32, enchant_unbreaking_level) + 1);
        if (rng_val % 100 >= threshold) return .{ .consumed = false, .broke = false };
    }
    if (current_durability <= 1) return .{ .consumed = true, .broke = true };
    return .{ .consumed = true, .broke = false };
}

/// Computes the durability bar colour and width percentage for HUD rendering.
/// Colour transitions green -> yellow -> red as durability decreases.
pub fn getDurabilityBar(current: u16, max_dur: u16) DurabilityBar {
    if (max_dur == 0) return .{ .width_pct = 1, .r = 0, .g = 0, .b = 0 };
    const pct = @as(f32, @floatFromInt(current)) / @as(f32, @floatFromInt(max_dur));
    const r = if (pct < 0.5) 1.0 else 1.0 - (pct - 0.5) * 2;
    const g = @min(1.0, pct * 2);
    return .{ .width_pct = pct, .r = r, .g = g, .b = 0 };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

const testing = std.testing;

test "getMaxDurability returns correct values for wood tools" {
    const wood_ids = [_]u16{ 257, 262, 267, 272, 277 };
    for (wood_ids) |id| {
        try testing.expectEqual(@as(u16, 59), getMaxDurability(id));
    }
}

test "getMaxDurability returns correct values for stone tools" {
    const stone_ids = [_]u16{ 258, 263, 268, 273, 278 };
    for (stone_ids) |id| {
        try testing.expectEqual(@as(u16, 131), getMaxDurability(id));
    }
}

test "getMaxDurability returns correct values for iron tools" {
    try testing.expectEqual(@as(u16, 250), getMaxDurability(259));
}

test "getMaxDurability returns correct values for gold tools" {
    try testing.expectEqual(@as(u16, 32), getMaxDurability(260));
}

test "getMaxDurability returns correct values for diamond tools" {
    try testing.expectEqual(@as(u16, 1561), getMaxDurability(261));
}

test "getMaxDurability returns correct values for special items" {
    try testing.expectEqual(@as(u16, 238), getMaxDurability(307)); // shears
    try testing.expectEqual(@as(u16, 64), getMaxDurability(308)); // fishing rod
    try testing.expectEqual(@as(u16, 64), getMaxDurability(309)); // flint and steel
    try testing.expectEqual(@as(u16, 384), getMaxDurability(333)); // bow
}

test "getMaxDurability returns 0 for unknown items" {
    try testing.expectEqual(@as(u16, 0), getMaxDurability(0));
    try testing.expectEqual(@as(u16, 0), getMaxDurability(9999));
}

test "onToolUse consumes durability without enchantment" {
    const result = onToolUse(100, 0, 42);
    try testing.expect(result.consumed);
    try testing.expect(!result.broke);
}

test "onToolUse breaks item at durability 1" {
    const result = onToolUse(1, 0, 0);
    try testing.expect(result.consumed);
    try testing.expect(result.broke);
}

test "onToolUse breaks item at durability 0" {
    const result = onToolUse(0, 0, 0);
    try testing.expect(result.consumed);
    try testing.expect(result.broke);
}

test "onToolUse unbreaking prevents consumption when rng exceeds threshold" {
    // Unbreaking I: threshold = 100/2 = 50. rng_val % 100 = 75 >= 50 => skip
    const result = onToolUse(100, 1, 75);
    try testing.expect(!result.consumed);
    try testing.expect(!result.broke);
}

test "onToolUse unbreaking allows consumption when rng below threshold" {
    // Unbreaking I: threshold = 50. rng_val % 100 = 10 < 50 => consume
    const result = onToolUse(100, 1, 10);
    try testing.expect(result.consumed);
    try testing.expect(!result.broke);
}

test "onToolUse unbreaking III has 25% consumption chance" {
    // Unbreaking III: threshold = 100/4 = 25. rng_val % 100 = 10 < 25 => consume
    const consumed = onToolUse(50, 3, 10);
    try testing.expect(consumed.consumed);
    // rng_val % 100 = 30 >= 25 => skip
    const skipped = onToolUse(50, 3, 30);
    try testing.expect(!skipped.consumed);
}

test "getDurabilityBar full durability is green" {
    const bar = getDurabilityBar(100, 100);
    try testing.expectApproxEqAbs(@as(f32, 1.0), bar.width_pct, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 0.0), bar.r, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 1.0), bar.g, 0.001);
    try testing.expectEqual(@as(f32, 0), bar.b);
}

test "getDurabilityBar half durability is yellow" {
    const bar = getDurabilityBar(50, 100);
    try testing.expectApproxEqAbs(@as(f32, 0.5), bar.width_pct, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 1.0), bar.r, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 1.0), bar.g, 0.001);
}

test "getDurabilityBar low durability is red" {
    const bar = getDurabilityBar(1, 100);
    try testing.expectApproxEqAbs(@as(f32, 0.01), bar.width_pct, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 1.0), bar.r, 0.05);
    try testing.expect(bar.g < 0.1);
}

test "getDurabilityBar zero max returns black bar" {
    const bar = getDurabilityBar(10, 0);
    try testing.expectEqual(@as(f32, 1), bar.width_pct);
    try testing.expectEqual(@as(f32, 0), bar.r);
    try testing.expectEqual(@as(f32, 0), bar.g);
    try testing.expectEqual(@as(f32, 0), bar.b);
}
