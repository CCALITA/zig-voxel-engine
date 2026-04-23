/// Tool-use items — shears and flint & steel right-click interactions.
///
/// Shears can shear sheep (drop wool), harvest leaves, cut cobwebs (drop string),
/// and collect tall grass.  Flint & steel places fire adjacent to a block, ignites
/// TNT, or charges a creeper.  All values follow vanilla Minecraft conventions.

const std = @import("std");

// -------------------------------------------------------------------------
// Item IDs
// -------------------------------------------------------------------------

pub const SHEARS: u16 = 307;
pub const FLINT_STEEL: u16 = 308;

// -------------------------------------------------------------------------
// Block IDs (kept in sync with src/world/block.zig)
// -------------------------------------------------------------------------

const BlockId = struct {
    const AIR: u16 = 0;
    const GRASS: u16 = 3;
    const OAK_LEAVES: u16 = 9;
    const TNT: u16 = 20;
    const COBWEB: u16 = 100;
    const FIRE: u16 = 51;
    const WHITE_WOOL: u16 = 71;
};

// -------------------------------------------------------------------------
// Item IDs (kept in sync with src/gameplay/item_registry.zig)
// -------------------------------------------------------------------------

const ItemId = struct {
    const STRING: u16 = 315;
    const GRASS_ITEM: u16 = 3;
    const OAK_LEAVES_ITEM: u16 = 9;
    const WHITE_WOOL_ITEM: u16 = 71;
};

// -------------------------------------------------------------------------
// Entity types (kept in sync with src/entity/entity.zig)
// -------------------------------------------------------------------------

const EntityTypeId = struct {
    const SHEEP: u8 = 91;
    const CREEPER: u8 = 50;
};

// -------------------------------------------------------------------------
// Public types
// -------------------------------------------------------------------------

pub const ToolUseResult = struct {
    success: bool,
    drop_item: u16 = 0,
    drop_count: u8 = 0,
    place_block: u16 = 0,
    durability_cost: u8 = 1,
};

const failure = ToolUseResult{ .success = false, .durability_cost = 0 };

// -------------------------------------------------------------------------
// Shears
// -------------------------------------------------------------------------

/// Use shears on a block or entity.
///
/// - Sheep entity  -> drop 1-3 wool (returns 1 as base; caller may randomise).
/// - Leaves block  -> drop leaf block item.
/// - Cobweb block  -> drop string.
/// - Grass block   -> drop grass item.
/// - Otherwise     -> failure (no durability cost).
pub fn useShears(target_block: u16, target_entity_type: ?u8) ToolUseResult {
    // Entity interactions take priority.
    if (target_entity_type) |etype| {
        if (etype == EntityTypeId.SHEEP) {
            return .{
                .success = true,
                .drop_item = ItemId.WHITE_WOOL_ITEM,
                .drop_count = 1,
            };
        }
        return failure;
    }

    return switch (target_block) {
        BlockId.OAK_LEAVES => .{
            .success = true,
            .drop_item = ItemId.OAK_LEAVES_ITEM,
            .drop_count = 1,
        },
        BlockId.COBWEB => .{
            .success = true,
            .drop_item = ItemId.STRING,
            .drop_count = 1,
        },
        BlockId.GRASS => .{
            .success = true,
            .drop_item = ItemId.GRASS_ITEM,
            .drop_count = 1,
        },
        else => failure,
    };
}

// -------------------------------------------------------------------------
// Flint & Steel
// -------------------------------------------------------------------------

/// Use flint & steel on a block.
///
/// - TNT block     -> ignite TNT (place_block = TNT to signal ignition).
/// - Any other solid block (non-air) -> place fire adjacent.
/// - Air           -> failure.
///
/// Creeper charging is handled via the entity overload below.
pub fn useFlintSteel(target_block: u16) ToolUseResult {
    if (target_block == BlockId.AIR) return failure;

    if (target_block == BlockId.TNT) {
        return .{
            .success = true,
            .place_block = BlockId.TNT,
        };
    }

    // Default: place fire adjacent to the target block.
    return .{
        .success = true,
        .place_block = BlockId.FIRE,
    };
}

/// Use flint & steel on an entity (e.g. creeper).
///
/// - Creeper -> charge the creeper.
/// - Others  -> failure.
pub fn useFlintSteelOnEntity(target_entity_type: u8) ToolUseResult {
    if (target_entity_type == EntityTypeId.CREEPER) {
        return .{
            .success = true,
        };
    }
    return failure;
}

// -------------------------------------------------------------------------
// Tests
// -------------------------------------------------------------------------

test "shears on sheep drops wool" {
    const result = useShears(BlockId.AIR, EntityTypeId.SHEEP);
    try std.testing.expect(result.success);
    try std.testing.expectEqual(@as(u16, ItemId.WHITE_WOOL_ITEM), result.drop_item);
    try std.testing.expectEqual(@as(u8, 1), result.drop_count);
    try std.testing.expectEqual(@as(u8, 1), result.durability_cost);
}

test "shears on leaves drops leaf block" {
    const result = useShears(BlockId.OAK_LEAVES, null);
    try std.testing.expect(result.success);
    try std.testing.expectEqual(@as(u16, ItemId.OAK_LEAVES_ITEM), result.drop_item);
    try std.testing.expectEqual(@as(u8, 1), result.drop_count);
}

test "shears on cobweb drops string" {
    const result = useShears(BlockId.COBWEB, null);
    try std.testing.expect(result.success);
    try std.testing.expectEqual(@as(u16, ItemId.STRING), result.drop_item);
    try std.testing.expectEqual(@as(u8, 1), result.drop_count);
}

test "shears on grass drops grass item" {
    const result = useShears(BlockId.GRASS, null);
    try std.testing.expect(result.success);
    try std.testing.expectEqual(@as(u16, ItemId.GRASS_ITEM), result.drop_item);
    try std.testing.expectEqual(@as(u8, 1), result.drop_count);
}

test "shears on unrecognised block fails" {
    const result = useShears(BlockId.AIR, null);
    try std.testing.expect(!result.success);
    try std.testing.expectEqual(@as(u8, 0), result.durability_cost);
}

test "shears on non-sheep entity fails" {
    const result = useShears(BlockId.AIR, EntityTypeId.CREEPER);
    try std.testing.expect(!result.success);
    try std.testing.expectEqual(@as(u8, 0), result.durability_cost);
}

test "flint and steel on block places fire" {
    const result = useFlintSteel(BlockId.GRASS);
    try std.testing.expect(result.success);
    try std.testing.expectEqual(@as(u16, BlockId.FIRE), result.place_block);
    try std.testing.expectEqual(@as(u8, 1), result.durability_cost);
}

test "flint and steel on TNT ignites" {
    const result = useFlintSteel(BlockId.TNT);
    try std.testing.expect(result.success);
    try std.testing.expectEqual(@as(u16, BlockId.TNT), result.place_block);
    try std.testing.expectEqual(@as(u8, 1), result.durability_cost);
}

test "flint and steel on creeper charges" {
    const result = useFlintSteelOnEntity(EntityTypeId.CREEPER);
    try std.testing.expect(result.success);
    try std.testing.expectEqual(@as(u8, 1), result.durability_cost);
}

test "flint and steel on air fails" {
    const result = useFlintSteel(BlockId.AIR);
    try std.testing.expect(!result.success);
    try std.testing.expectEqual(@as(u8, 0), result.durability_cost);
}

test "flint and steel on non-creeper entity fails" {
    const result = useFlintSteelOnEntity(EntityTypeId.SHEEP);
    try std.testing.expect(!result.success);
    try std.testing.expectEqual(@as(u8, 0), result.durability_cost);
}

test "shears entity priority over block" {
    // When both entity and block are provided, entity takes priority.
    const result = useShears(BlockId.OAK_LEAVES, EntityTypeId.SHEEP);
    try std.testing.expect(result.success);
    try std.testing.expectEqual(@as(u16, ItemId.WHITE_WOOL_ITEM), result.drop_item);
}

test "tool use result default values" {
    const result = ToolUseResult{ .success = true };
    try std.testing.expectEqual(@as(u16, 0), result.drop_item);
    try std.testing.expectEqual(@as(u8, 0), result.drop_count);
    try std.testing.expectEqual(@as(u16, 0), result.place_block);
    try std.testing.expectEqual(@as(u8, 1), result.durability_cost);
}
