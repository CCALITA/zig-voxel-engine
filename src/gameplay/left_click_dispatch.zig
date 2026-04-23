/// Left-click dispatch -- determines which action to take when the player
/// left-clicks, based on the held item, target block, target entity, and
/// distances.  Priority order:
///   1. Entity within 3 blocks -> attack_entity
///   2. Target block present -> mine_block
///   3. Holding a sword (ID 277-281), no other target -> use_sword_sweep
///   4. Fallback -> none

const std = @import("std");

// -- Left-click action enum -------------------------------------------------

pub const LeftClickAction = enum {
    none,
    mine_block,
    attack_entity,
    use_sword_sweep,
};

// -- Constants --------------------------------------------------------------

const max_entity_reach: f32 = 3.0;

const SwordId = struct {
    const WOODEN_SWORD: u16 = 277;
    const STONE_SWORD: u16 = 278;
    const IRON_SWORD: u16 = 279;
    const DIAMOND_SWORD: u16 = 280;
    const NETHERITE_SWORD: u16 = 281;
};

// -- Public API -------------------------------------------------------------

/// Determine the left-click action given the current context.
///
/// Priority:
///   1. Entity within reach (distance <= 3 blocks) -> attack_entity
///   2. Target block present -> mine_block
///   3. Holding a sword with attack ready -> use_sword_sweep
///   4. Otherwise -> none
pub fn dispatch(
    has_target_block: bool,
    has_target_entity: bool,
    held_item: u16,
    entity_distance: f32,
) LeftClickAction {
    if (has_target_entity and entity_distance <= max_entity_reach) {
        return .attack_entity;
    }

    if (has_target_block) {
        return .mine_block;
    }

    if (isSword(held_item)) {
        return .use_sword_sweep;
    }

    return .none;
}

/// Returns true when `item` is a sword (IDs 277 through 281 inclusive).
pub fn isSword(item: u16) bool {
    return item >= SwordId.WOODEN_SWORD and item <= SwordId.NETHERITE_SWORD;
}

/// Given distances to both an entity and a block, return which target
/// should receive priority.  Entities take priority when they are
/// closer than the block; otherwise the block wins.
pub fn getMiningPriority(entity_dist: f32, block_dist: f32) enum { entity, block } {
    if (entity_dist <= block_dist) {
        return .entity;
    }
    return .block;
}

// -- Tests ------------------------------------------------------------------

test "entity within reach triggers attack" {
    const action = dispatch(false, true, 0, 2.5);
    try std.testing.expectEqual(LeftClickAction.attack_entity, action);
}

test "entity at exact reach triggers attack" {
    const action = dispatch(false, true, 0, 3.0);
    try std.testing.expectEqual(LeftClickAction.attack_entity, action);
}

test "entity beyond reach does not trigger attack" {
    const action = dispatch(false, true, 0, 3.1);
    try std.testing.expectEqual(LeftClickAction.none, action);
}

test "entity attack takes priority over block mining" {
    const action = dispatch(true, true, 0, 2.0);
    try std.testing.expectEqual(LeftClickAction.attack_entity, action);
}

test "target block triggers mine" {
    const action = dispatch(true, false, 0, 10.0);
    try std.testing.expectEqual(LeftClickAction.mine_block, action);
}

test "sword sweep when no target block or entity" {
    const action = dispatch(false, false, SwordId.IRON_SWORD, 10.0);
    try std.testing.expectEqual(LeftClickAction.use_sword_sweep, action);
}

test "block mining takes priority over sword sweep" {
    const action = dispatch(true, false, SwordId.DIAMOND_SWORD, 10.0);
    try std.testing.expectEqual(LeftClickAction.mine_block, action);
}

test "no target and no sword returns none" {
    const action = dispatch(false, false, 0, 10.0);
    try std.testing.expectEqual(LeftClickAction.none, action);
}

test "isSword returns true for all sword IDs" {
    const sword_ids = [_]u16{
        SwordId.WOODEN_SWORD,
        SwordId.STONE_SWORD,
        SwordId.IRON_SWORD,
        SwordId.DIAMOND_SWORD,
        SwordId.NETHERITE_SWORD,
    };
    for (sword_ids) |id| {
        try std.testing.expect(isSword(id));
    }
}

test "isSword returns false for non-sword items" {
    try std.testing.expect(!isSword(0));
    try std.testing.expect(!isSword(276));
    try std.testing.expect(!isSword(282));
    try std.testing.expect(!isSword(999));
}

test "getMiningPriority prefers entity when closer" {
    const prio = getMiningPriority(2.0, 3.0);
    try std.testing.expectEqual(.entity, prio);
}

test "getMiningPriority prefers block when entity is farther" {
    const prio = getMiningPriority(5.0, 3.0);
    try std.testing.expectEqual(.block, prio);
}

test "getMiningPriority ties go to entity" {
    const prio = getMiningPriority(2.5, 2.5);
    try std.testing.expectEqual(.entity, prio);
}

test "entity out of reach with block still mines" {
    const action = dispatch(true, true, SwordId.WOODEN_SWORD, 4.0);
    try std.testing.expectEqual(LeftClickAction.mine_block, action);
}

test "all sword types trigger sweep when no targets" {
    const sword_ids = [_]u16{
        SwordId.WOODEN_SWORD,
        SwordId.STONE_SWORD,
        SwordId.IRON_SWORD,
        SwordId.DIAMOND_SWORD,
        SwordId.NETHERITE_SWORD,
    };
    for (sword_ids) |id| {
        const action = dispatch(false, false, id, 10.0);
        try std.testing.expectEqual(LeftClickAction.use_sword_sweep, action);
    }
}

test "non-sword held item with no targets returns none" {
    const action = dispatch(false, false, 303, 10.0);
    try std.testing.expectEqual(LeftClickAction.none, action);
}
