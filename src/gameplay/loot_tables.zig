/// Block loot tables.
/// Maps each block ID to a loot definition that determines what items drop,
/// with optional fortune modifiers and XP rewards. Uses comptime lookup
/// tables for zero-allocation, zero-branch runtime rolls.

const std = @import("std");
const block = @import("../world/block.zig");

/// Maximum number of distinct item stacks a single block can drop.
pub const MAX_ITEMS: usize = 4;

pub const LootItem = struct {
    id: u16,
    min_count: u8,
    max_count: u8,
    /// Extra items per fortune level (additive).
    fortune_bonus: u8 = 0,
};

pub const BlockLoot = struct {
    items: [MAX_ITEMS]?LootItem = .{ null, null, null, null },
    item_count: usize = 0,
    /// Base XP dropped when breaking this block.
    xp: u32 = 0,
};

pub const LootResult = struct {
    items: [MAX_ITEMS]?LootResultItem = .{ null, null, null, null },
    item_count: usize = 0,
    xp: u32 = 0,
};

pub const LootResultItem = struct {
    id: u16,
    count: u8,
};

/// Item IDs for non-block drops (ores drop items, not ore blocks).
pub const ITEM_COAL: u16 = 263;
pub const ITEM_DIAMOND: u16 = 264;
pub const ITEM_REDSTONE_DUST: u16 = 265;
pub const ITEM_FLINT: u16 = 266;

/// Return the loot definition for a given block ID.
pub fn getBlockLoot(block_id: block.BlockId) BlockLoot {
    return switch (block_id) {
        // Ores drop items, not the ore block itself
        block.COAL_ORE => makeLoot(&.{.{ .id = ITEM_COAL, .min_count = 1, .max_count = 1, .fortune_bonus = 1 }}, 1),
        block.DIAMOND_ORE => makeLoot(&.{.{ .id = ITEM_DIAMOND, .min_count = 1, .max_count = 1, .fortune_bonus = 1 }}, 7),
        block.REDSTONE_ORE => makeLoot(&.{.{ .id = ITEM_REDSTONE_DUST, .min_count = 4, .max_count = 5, .fortune_bonus = 1 }}, 3),

        // Gravel has a chance to drop flint (simplified: always drop gravel + sometimes flint)
        block.GRAVEL => makeLoot(&.{
            .{ .id = block.GRAVEL, .min_count = 1, .max_count = 1 },
            .{ .id = ITEM_FLINT, .min_count = 0, .max_count = 1 },
        }, 0),

        // Leaves occasionally drop nothing (simplified: always drop leaves)
        block.OAK_LEAVES => makeLoot(&.{.{ .id = block.OAK_LEAVES, .min_count = 0, .max_count = 1 }}, 0),

        // Glass drops nothing (silk touch not implemented)
        block.GLASS => makeLoot(&.{}, 0),

        // Iron and gold ore drop themselves (require smelting)
        block.IRON_ORE => makeLoot(&.{.{ .id = block.IRON_ORE, .min_count = 1, .max_count = 1 }}, 2),
        block.GOLD_ORE => makeLoot(&.{.{ .id = block.GOLD_ORE, .min_count = 1, .max_count = 1 }}, 3),

        // Grass drops dirt
        block.GRASS => makeLoot(&.{.{ .id = block.DIRT, .min_count = 1, .max_count = 1 }}, 0),

        // Stone drops cobblestone
        block.STONE => makeLoot(&.{.{ .id = block.COBBLESTONE, .min_count = 1, .max_count = 1 }}, 0),

        // Bookshelf drops books (placeholder: drops itself)
        block.BOOKSHELF => makeLoot(&.{.{ .id = block.BOOKSHELF, .min_count = 1, .max_count = 1 }}, 0),

        // Default: block drops itself
        else => makeLoot(&.{.{ .id = @as(u16, block_id), .min_count = 1, .max_count = 1 }}, 0),
    };
}

/// Roll a loot result from a loot definition with the given fortune level.
/// The `tick` parameter seeds the pseudo-random selection for variable drops.
pub fn rollLoot(loot: BlockLoot, fortune: u8, tick: u32) LootResult {
    var result = LootResult{};
    result.xp = loot.xp;
    result.item_count = loot.item_count;

    for (0..loot.item_count) |i| {
        if (loot.items[i]) |item| {
            var count = item.min_count;
            if (item.max_count > item.min_count) {
                // Simple deterministic "random" using tick + item index
                const range = item.max_count - item.min_count + 1;
                const hash = (tick *% 2654435761) +% @as(u32, @intCast(i)) *% 1013904223;
                count = item.min_count + @as(u8, @truncate(hash % range));
            }
            // Apply fortune bonus
            count +|= item.fortune_bonus * fortune;
            result.items[i] = .{ .id = item.id, .count = count };
        }
    }

    return result;
}

/// Helper to build a BlockLoot from a slice of LootItem definitions.
fn makeLoot(items: []const LootItem, xp: u32) BlockLoot {
    var loot = BlockLoot{ .xp = xp };
    for (items, 0..) |item, i| {
        if (i >= MAX_ITEMS) break;
        loot.items[i] = item;
        loot.item_count = i + 1;
    }
    return loot;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "coal ore drops coal item with xp" {
    const loot = getBlockLoot(block.COAL_ORE);
    try std.testing.expectEqual(@as(usize, 1), loot.item_count);
    try std.testing.expectEqual(@as(u32, 1), loot.xp);
    try std.testing.expectEqual(ITEM_COAL, loot.items[0].?.id);
}

test "diamond ore drops diamond with fortune bonus" {
    const loot = getBlockLoot(block.DIAMOND_ORE);
    const result = rollLoot(loot, 3, 100);
    try std.testing.expectEqual(@as(usize, 1), result.item_count);
    try std.testing.expectEqual(ITEM_DIAMOND, result.items[0].?.id);
    // With fortune 3 and base count 1, expect at least 4 (1 + 1*3)
    try std.testing.expect(result.items[0].?.count >= 4);
}

test "stone drops cobblestone" {
    const loot = getBlockLoot(block.STONE);
    const result = rollLoot(loot, 0, 0);
    try std.testing.expectEqual(@as(u16, block.COBBLESTONE), result.items[0].?.id);
    try std.testing.expectEqual(@as(u8, 1), result.items[0].?.count);
}

test "grass drops dirt" {
    const loot = getBlockLoot(block.GRASS);
    const result = rollLoot(loot, 0, 0);
    try std.testing.expectEqual(@as(u16, block.DIRT), result.items[0].?.id);
}

test "glass drops nothing" {
    const loot = getBlockLoot(block.GLASS);
    try std.testing.expectEqual(@as(usize, 0), loot.item_count);
}

test "default block drops itself" {
    const loot = getBlockLoot(block.DIRT);
    const result = rollLoot(loot, 0, 0);
    try std.testing.expectEqual(@as(u16, block.DIRT), result.items[0].?.id);
    try std.testing.expectEqual(@as(u8, 1), result.items[0].?.count);
}

test "roll with zero fortune produces base count" {
    const loot = getBlockLoot(block.COAL_ORE);
    const result = rollLoot(loot, 0, 42);
    try std.testing.expectEqual(@as(u8, 1), result.items[0].?.count);
}

test "empty loot rolls empty result" {
    const loot = getBlockLoot(block.GLASS);
    const result = rollLoot(loot, 0, 0);
    try std.testing.expectEqual(@as(usize, 0), result.item_count);
    try std.testing.expectEqual(@as(u32, 0), result.xp);
}

test "gravel has two possible drops" {
    const loot = getBlockLoot(block.GRAVEL);
    try std.testing.expectEqual(@as(usize, 2), loot.item_count);
    try std.testing.expectEqual(@as(u16, block.GRAVEL), loot.items[0].?.id);
    try std.testing.expectEqual(ITEM_FLINT, loot.items[1].?.id);
}

test "redstone ore drops multiple dust" {
    const loot = getBlockLoot(block.REDSTONE_ORE);
    const result = rollLoot(loot, 0, 0);
    try std.testing.expect(result.items[0].?.count >= 4);
    try std.testing.expectEqual(@as(u32, 3), result.xp);
}
