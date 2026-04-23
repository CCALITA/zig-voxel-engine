/// Harvest rules — tool tier requirements and mining speed multipliers for blocks.
///
/// Determines whether a given tool tier can harvest a block, the mining speed
/// multiplier for a tool/tier/block combination, and whether a block should
/// drop items when broken at a given tier.

const std = @import("std");

// -------------------------------------------------------------------------
// Block IDs (kept in sync with src/world/block.zig)
// -------------------------------------------------------------------------

const BlockId = struct {
    const STONE: u16 = 1;
    const COBBLESTONE: u16 = 4;
    const OAK_PLANKS: u16 = 5;
    const OAK_LOG: u16 = 8;
    const OAK_LEAVES: u16 = 9;
    const COAL_ORE: u16 = 12;
    const IRON_ORE: u16 = 13;
    const GOLD_ORE: u16 = 14;
    const DIAMOND_ORE: u16 = 15;
    const REDSTONE_ORE: u16 = 16;
    const OBSIDIAN: u16 = 19;
    const NETHERRACK: u16 = 30;
    // Forward-declared; not yet in block.zig.
    const EMERALD_ORE: u16 = 200;
};

// -------------------------------------------------------------------------
// Public types
// -------------------------------------------------------------------------

pub const ToolTier = enum(u3) {
    none = 0,
    wood = 1,
    stone = 2,
    iron = 3,
    gold = 4,
    diamond = 5,
    netherite = 6,
};

pub const ToolType = enum(u3) {
    none = 0,
    pickaxe = 1,
    axe = 2,
    shovel = 3,
    hoe = 4,
    sword = 5,
    shears = 6,
};

// -------------------------------------------------------------------------
// Tool tier / type lookup from item IDs
// -------------------------------------------------------------------------

/// Returns the tool tier for an item ID, or `.none` for non-tool items.
/// Item ID ranges (5 items each, wood through diamond):
///   257-261  pickaxes
///   262-266  axes
///   267-271  shovels
///   272-276  hoes
///   277-281  swords
pub fn getToolTierForItem(item_id: u16) ToolTier {
    const tier_order = [_]ToolTier{ .wood, .stone, .iron, .gold, .diamond };
    const ranges = [_][2]u16{
        .{ 257, 261 },
        .{ 262, 266 },
        .{ 267, 271 },
        .{ 272, 276 },
        .{ 277, 281 },
    };
    for (ranges) |r| {
        if (item_id >= r[0] and item_id <= r[1]) {
            return tier_order[item_id - r[0]];
        }
    }
    return .none;
}

/// Returns the tool type for an item ID, or `.none` for non-tool items.
pub fn getToolTypeForItem(item_id: u16) ToolType {
    if (item_id >= 257 and item_id <= 261) return .pickaxe;
    if (item_id >= 262 and item_id <= 266) return .axe;
    if (item_id >= 267 and item_id <= 271) return .shovel;
    if (item_id >= 272 and item_id <= 276) return .hoe;
    if (item_id >= 277 and item_id <= 281) return .sword;
    return .none;
}

// -------------------------------------------------------------------------
// Block classification helpers
// -------------------------------------------------------------------------

/// True for blocks that require a pickaxe to harvest.
fn requiresPickaxe(block_id: u16) bool {
    return switch (block_id) {
        BlockId.STONE,
        BlockId.COBBLESTONE,
        BlockId.COAL_ORE,
        BlockId.IRON_ORE,
        BlockId.GOLD_ORE,
        BlockId.DIAMOND_ORE,
        BlockId.REDSTONE_ORE,
        BlockId.EMERALD_ORE,
        BlockId.OBSIDIAN,
        BlockId.NETHERRACK,
        => true,
        else => false,
    };
}

/// Minimum tier required to harvest a block.  Returns `.none` when any tier
/// (including bare hand) suffices.
fn minimumTierForBlock(block_id: u16) ToolTier {
    return switch (block_id) {
        BlockId.IRON_ORE => .stone,
        BlockId.GOLD_ORE,
        BlockId.DIAMOND_ORE,
        BlockId.REDSTONE_ORE,
        BlockId.EMERALD_ORE,
        => .iron,
        BlockId.OBSIDIAN => .diamond,
        else => .none,
    };
}

/// True when `tier` meets or exceeds `required`.
fn tierAtLeast(tier: ToolTier, required: ToolTier) bool {
    // Gold has a high speed but a low harvest level (equivalent to wood).
    const effective_level = tierToHarvestLevel(tier);
    const required_level = tierToHarvestLevel(required);
    return effective_level >= required_level;
}

/// Maps a ToolTier to its harvest level (0-4).  Gold is equivalent to wood (0).
fn tierToHarvestLevel(tier: ToolTier) u8 {
    return switch (tier) {
        .none => 0,
        .wood => 0,
        .stone => 1,
        .iron => 2,
        .gold => 0,
        .diamond => 3,
        .netherite => 4,
    };
}

/// True when `tool_type` is the correct tool for `block_id`.
fn isCorrectTool(tool_type: ToolType, block_id: u16) bool {
    return switch (tool_type) {
        .pickaxe => requiresPickaxe(block_id),
        .axe => block_id == BlockId.OAK_PLANKS or block_id == BlockId.OAK_LOG,
        else => false,
    };
}

// -------------------------------------------------------------------------
// Public query functions
// -------------------------------------------------------------------------

/// Returns true when the player can break the block and collect it.
/// Stone, cobblestone, and all ores require a pickaxe.  Higher-tier ores
/// require a minimum tool tier (e.g. iron ore needs stone+, diamond ore
/// needs iron+, obsidian needs diamond+).  Most other blocks can be
/// harvested with any tool or bare hand.
pub fn canHarvest(tier: ToolTier, block_id: u16) bool {
    if (!requiresPickaxe(block_id)) return true;

    const min_tier = minimumTierForBlock(block_id);
    if (min_tier == .none) {
        // Block requires a pickaxe but any tier works (stone, cobble, coal ore).
        return tier != .none;
    }
    return tierAtLeast(tier, min_tier);
}

/// Returns the mining speed multiplier for the given tool/tier against a block.
/// The right tool type returns the tier's speed bonus; otherwise returns 1.0.
pub fn getMiningSpeedMultiplier(tool_type: ToolType, tier: ToolTier, block_id: u16) f32 {
    if (tool_type == .none or tier == .none) return 1.0;
    if (!isCorrectTool(tool_type, block_id)) return 1.0;
    return tierToSpeed(tier);
}

/// Maps a tier to its base speed multiplier.
fn tierToSpeed(tier: ToolTier) f32 {
    return switch (tier) {
        .none => 1.0,
        .wood => 2.0,
        .stone => 4.0,
        .iron => 6.0,
        .gold => 12.0,
        .diamond => 8.0,
        .netherite => 9.0,
    };
}

/// Returns true when the block should drop its item at the given tier.
/// Certain ores and obsidian only drop when mined with a sufficiently
/// high-tier pickaxe.
pub fn shouldDropItem(tier: ToolTier, block_id: u16) bool {
    const min_tier = minimumTierForBlock(block_id);
    if (min_tier == .none) return true;
    return tierAtLeast(tier, min_tier);
}

// -------------------------------------------------------------------------
// Tests
// -------------------------------------------------------------------------

test "canHarvest — bare hand on normal block" {
    try std.testing.expect(canHarvest(.none, 2)); // dirt
    try std.testing.expect(canHarvest(.none, 5)); // oak planks
}

test "canHarvest — bare hand cannot mine stone/ores" {
    try std.testing.expect(!canHarvest(.none, BlockId.STONE));
    try std.testing.expect(!canHarvest(.none, BlockId.COAL_ORE));
    try std.testing.expect(!canHarvest(.none, BlockId.IRON_ORE));
}

test "canHarvest — wood pickaxe mines stone and coal ore" {
    try std.testing.expect(canHarvest(.wood, BlockId.STONE));
    try std.testing.expect(canHarvest(.wood, BlockId.COBBLESTONE));
    try std.testing.expect(canHarvest(.wood, BlockId.COAL_ORE));
}

test "canHarvest — wood pickaxe cannot mine iron ore" {
    try std.testing.expect(!canHarvest(.wood, BlockId.IRON_ORE));
}

test "canHarvest — stone pickaxe mines iron ore" {
    try std.testing.expect(canHarvest(.stone, BlockId.IRON_ORE));
}

test "canHarvest — stone pickaxe cannot mine diamond ore" {
    try std.testing.expect(!canHarvest(.stone, BlockId.DIAMOND_ORE));
    try std.testing.expect(!canHarvest(.stone, BlockId.GOLD_ORE));
}

test "canHarvest — iron pickaxe mines diamond and gold ore" {
    try std.testing.expect(canHarvest(.iron, BlockId.DIAMOND_ORE));
    try std.testing.expect(canHarvest(.iron, BlockId.GOLD_ORE));
    try std.testing.expect(canHarvest(.iron, BlockId.REDSTONE_ORE));
    try std.testing.expect(canHarvest(.iron, BlockId.EMERALD_ORE));
}

test "canHarvest — iron pickaxe cannot mine obsidian" {
    try std.testing.expect(!canHarvest(.iron, BlockId.OBSIDIAN));
}

test "canHarvest — diamond pickaxe mines obsidian" {
    try std.testing.expect(canHarvest(.diamond, BlockId.OBSIDIAN));
}

test "canHarvest — netherite pickaxe mines everything" {
    try std.testing.expect(canHarvest(.netherite, BlockId.OBSIDIAN));
    try std.testing.expect(canHarvest(.netherite, BlockId.DIAMOND_ORE));
    try std.testing.expect(canHarvest(.netherite, BlockId.IRON_ORE));
}

test "canHarvest — gold pickaxe has wood-level harvest" {
    try std.testing.expect(canHarvest(.gold, BlockId.STONE));
    try std.testing.expect(canHarvest(.gold, BlockId.COAL_ORE));
    try std.testing.expect(!canHarvest(.gold, BlockId.IRON_ORE));
    try std.testing.expect(!canHarvest(.gold, BlockId.DIAMOND_ORE));
}

test "getMiningSpeedMultiplier — correct tool returns tier speed" {
    try std.testing.expectEqual(@as(f32, 2.0), getMiningSpeedMultiplier(.pickaxe, .wood, BlockId.STONE));
    try std.testing.expectEqual(@as(f32, 4.0), getMiningSpeedMultiplier(.pickaxe, .stone, BlockId.STONE));
    try std.testing.expectEqual(@as(f32, 6.0), getMiningSpeedMultiplier(.pickaxe, .iron, BlockId.COBBLESTONE));
    try std.testing.expectEqual(@as(f32, 12.0), getMiningSpeedMultiplier(.pickaxe, .gold, BlockId.COAL_ORE));
    try std.testing.expectEqual(@as(f32, 8.0), getMiningSpeedMultiplier(.pickaxe, .diamond, BlockId.OBSIDIAN));
    try std.testing.expectEqual(@as(f32, 9.0), getMiningSpeedMultiplier(.pickaxe, .netherite, BlockId.DIAMOND_ORE));
}

test "getMiningSpeedMultiplier — wrong tool returns 1.0" {
    try std.testing.expectEqual(@as(f32, 1.0), getMiningSpeedMultiplier(.axe, .diamond, BlockId.STONE));
    try std.testing.expectEqual(@as(f32, 1.0), getMiningSpeedMultiplier(.shovel, .iron, BlockId.COBBLESTONE));
    try std.testing.expectEqual(@as(f32, 1.0), getMiningSpeedMultiplier(.sword, .diamond, BlockId.STONE));
}

test "getMiningSpeedMultiplier — no tool returns 1.0" {
    try std.testing.expectEqual(@as(f32, 1.0), getMiningSpeedMultiplier(.none, .none, BlockId.STONE));
    try std.testing.expectEqual(@as(f32, 1.0), getMiningSpeedMultiplier(.pickaxe, .none, BlockId.STONE));
}

test "shouldDropItem — normal blocks always drop" {
    try std.testing.expect(shouldDropItem(.none, 2)); // dirt
    try std.testing.expect(shouldDropItem(.none, BlockId.STONE));
    try std.testing.expect(shouldDropItem(.wood, BlockId.COAL_ORE));
}

test "shouldDropItem — diamond ore needs iron+" {
    try std.testing.expect(!shouldDropItem(.stone, BlockId.DIAMOND_ORE));
    try std.testing.expect(shouldDropItem(.iron, BlockId.DIAMOND_ORE));
    try std.testing.expect(shouldDropItem(.diamond, BlockId.DIAMOND_ORE));
}

test "shouldDropItem — iron ore needs stone+" {
    try std.testing.expect(!shouldDropItem(.wood, BlockId.IRON_ORE));
    try std.testing.expect(shouldDropItem(.stone, BlockId.IRON_ORE));
}

test "shouldDropItem — obsidian needs diamond+" {
    try std.testing.expect(!shouldDropItem(.iron, BlockId.OBSIDIAN));
    try std.testing.expect(shouldDropItem(.diamond, BlockId.OBSIDIAN));
    try std.testing.expect(shouldDropItem(.netherite, BlockId.OBSIDIAN));
}

test "shouldDropItem — gold and emerald ore need iron+" {
    try std.testing.expect(!shouldDropItem(.stone, BlockId.GOLD_ORE));
    try std.testing.expect(shouldDropItem(.iron, BlockId.GOLD_ORE));
    try std.testing.expect(!shouldDropItem(.stone, BlockId.EMERALD_ORE));
    try std.testing.expect(shouldDropItem(.iron, BlockId.EMERALD_ORE));
}

test "shouldDropItem — redstone ore needs iron+" {
    try std.testing.expect(!shouldDropItem(.stone, BlockId.REDSTONE_ORE));
    try std.testing.expect(shouldDropItem(.iron, BlockId.REDSTONE_ORE));
}

test "getToolTierForItem — pickaxe range 257-261" {
    try std.testing.expectEqual(ToolTier.wood, getToolTierForItem(257));
    try std.testing.expectEqual(ToolTier.stone, getToolTierForItem(258));
    try std.testing.expectEqual(ToolTier.iron, getToolTierForItem(259));
    try std.testing.expectEqual(ToolTier.gold, getToolTierForItem(260));
    try std.testing.expectEqual(ToolTier.diamond, getToolTierForItem(261));
}

test "getToolTierForItem — axe range 262-266" {
    try std.testing.expectEqual(ToolTier.wood, getToolTierForItem(262));
    try std.testing.expectEqual(ToolTier.diamond, getToolTierForItem(266));
}

test "getToolTierForItem — shovel, hoe, sword ranges" {
    try std.testing.expectEqual(ToolTier.wood, getToolTierForItem(267)); // shovel
    try std.testing.expectEqual(ToolTier.iron, getToolTierForItem(274)); // hoe
    try std.testing.expectEqual(ToolTier.diamond, getToolTierForItem(281)); // sword
}

test "getToolTierForItem — non-tool returns none" {
    try std.testing.expectEqual(ToolTier.none, getToolTierForItem(0));
    try std.testing.expectEqual(ToolTier.none, getToolTierForItem(256));
    try std.testing.expectEqual(ToolTier.none, getToolTierForItem(282));
}

test "getToolTypeForItem — all ranges" {
    try std.testing.expectEqual(ToolType.pickaxe, getToolTypeForItem(257));
    try std.testing.expectEqual(ToolType.pickaxe, getToolTypeForItem(261));
    try std.testing.expectEqual(ToolType.axe, getToolTypeForItem(262));
    try std.testing.expectEqual(ToolType.axe, getToolTypeForItem(266));
    try std.testing.expectEqual(ToolType.shovel, getToolTypeForItem(267));
    try std.testing.expectEqual(ToolType.shovel, getToolTypeForItem(271));
    try std.testing.expectEqual(ToolType.hoe, getToolTypeForItem(272));
    try std.testing.expectEqual(ToolType.hoe, getToolTypeForItem(276));
    try std.testing.expectEqual(ToolType.sword, getToolTypeForItem(277));
    try std.testing.expectEqual(ToolType.sword, getToolTypeForItem(281));
}

test "getToolTypeForItem — non-tool returns none" {
    try std.testing.expectEqual(ToolType.none, getToolTypeForItem(0));
    try std.testing.expectEqual(ToolType.none, getToolTypeForItem(300));
}
