/// Copper oxidation system.
/// Copper blocks progress through 4 oxidation stages over time via random ticks.
const std = @import("std");
const block = @import("../world/block.zig");

pub const OxidationStage = enum(u2) {
    unaffected = 0,
    exposed = 1,
    weathered = 2,
    oxidized = 3,
};

/// Average random ticks per stage transition (in-game concept).
pub const TICKS_PER_STAGE: u32 = 1200;

/// Return the oxidation stage for a given block ID, or null if not copper.
pub fn getOxidationStage(block_id: block.BlockId) ?OxidationStage {
    return switch (block_id) {
        block.COPPER_BLOCK => .unaffected,
        block.EXPOSED_COPPER => .exposed,
        block.WEATHERED_COPPER => .weathered,
        block.OXIDIZED_COPPER => .oxidized,
        else => null,
    };
}

/// Return the next oxidation stage block ID, or null if already fully oxidized.
pub fn getNextStage(block_id: block.BlockId) ?block.BlockId {
    return switch (block_id) {
        block.COPPER_BLOCK => block.EXPOSED_COPPER,
        block.EXPOSED_COPPER => block.WEATHERED_COPPER,
        block.WEATHERED_COPPER => block.OXIDIZED_COPPER,
        else => null,
    };
}

/// Determine whether a random tick should cause oxidation (probabilistic).
/// `random_value` should be in [0, max) where max is the period.
pub fn shouldOxidize(random_value: u32) bool {
    return random_value == 0;
}

test "copper stages" {
    try std.testing.expectEqual(OxidationStage.unaffected, getOxidationStage(block.COPPER_BLOCK).?);
    try std.testing.expectEqual(OxidationStage.exposed, getOxidationStage(block.EXPOSED_COPPER).?);
    try std.testing.expectEqual(OxidationStage.weathered, getOxidationStage(block.WEATHERED_COPPER).?);
    try std.testing.expectEqual(OxidationStage.oxidized, getOxidationStage(block.OXIDIZED_COPPER).?);
    try std.testing.expectEqual(@as(?OxidationStage, null), getOxidationStage(block.STONE));
}

test "next stage progression" {
    try std.testing.expectEqual(@as(?block.BlockId, block.EXPOSED_COPPER), getNextStage(block.COPPER_BLOCK));
    try std.testing.expectEqual(@as(?block.BlockId, block.WEATHERED_COPPER), getNextStage(block.EXPOSED_COPPER));
    try std.testing.expectEqual(@as(?block.BlockId, block.OXIDIZED_COPPER), getNextStage(block.WEATHERED_COPPER));
    try std.testing.expectEqual(@as(?block.BlockId, null), getNextStage(block.OXIDIZED_COPPER));
}

test "should oxidize probability" {
    try std.testing.expect(shouldOxidize(0));
    try std.testing.expect(!shouldOxidize(1));
    try std.testing.expect(!shouldOxidize(100));
}
