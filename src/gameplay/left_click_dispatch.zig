/// Left-click action dispatch: determines whether a left click should mine a
/// block, attack an entity, or trigger a sword sweep based on target state,
/// held item, and distance thresholds.

const std = @import("std");

// ── Action enum ──────────────────────────────────────────────────────────

pub const LeftClickAction = enum {
    none,
    mine_block,
    attack_entity,
    use_sword_sweep,
};

// ── Mining priority ──────────────────────────────────────────────────────

pub const MiningPriority = enum { entity, block };

/// When both an entity and a block are targeted, the closer target wins.
pub fn getMiningPriority(entity_dist: f32, block_dist: f32) MiningPriority {
    return if (entity_dist <= block_dist) .entity else .block;
}

// ── Sword detection ──────────────────────────────────────────────────────

/// Minecraft sword item IDs: wooden (277), stone (278), iron (279),
/// golden (280), diamond (281).
pub fn isSword(item: u16) bool {
    return item >= 277 and item <= 281;
}

// ── Constants ────────────────────────────────────────────────────────────

const entity_attack_range: f32 = 3.0;

// ── Dispatch ─────────────────────────────────────────────────────────────

/// Decide which left-click action to perform.
///
/// Priority rules:
///   1. Entity within attack range (3 blocks) and targeted -> attack_entity.
///   2. Holding a sword and entity targeted (beyond melee) -> use_sword_sweep.
///   3. Block targeted -> mine_block.
///   4. Otherwise -> none.
pub fn dispatch(
    has_target_block: bool,
    has_target_entity: bool,
    held_item: u16,
    entity_distance: f32,
) LeftClickAction {
    // Entity in melee range takes top priority.
    if (has_target_entity and entity_distance <= entity_attack_range) {
        return .attack_entity;
    }

    // Sword sweep when holding a sword and an entity is targeted
    // beyond melee range.
    if (has_target_entity and isSword(held_item)) {
        return .use_sword_sweep;
    }

    // Fall back to mining a block if one is targeted.
    if (has_target_block) {
        return .mine_block;
    }

    return .none;
}

// ── Tests ────────────────────────────────────────────────────────────────

test "dispatch — entity within range returns attack_entity" {
    const action = dispatch(false, true, 0, 2.5);
    try std.testing.expectEqual(LeftClickAction.attack_entity, action);
}

test "dispatch — entity at exact range boundary returns attack_entity" {
    const action = dispatch(true, true, 280, 3.0);
    try std.testing.expectEqual(LeftClickAction.attack_entity, action);
}

test "dispatch — entity beyond range with sword returns sword_sweep" {
    const action = dispatch(false, true, 279, 4.0);
    try std.testing.expectEqual(LeftClickAction.use_sword_sweep, action);
}

test "dispatch — entity beyond range without sword and block targeted returns mine_block" {
    const action = dispatch(true, true, 100, 5.0);
    try std.testing.expectEqual(LeftClickAction.mine_block, action);
}

test "dispatch — block targeted with no entity returns mine_block" {
    const action = dispatch(true, false, 0, 0);
    try std.testing.expectEqual(LeftClickAction.mine_block, action);
}

test "dispatch — nothing targeted returns none" {
    const action = dispatch(false, false, 0, 0);
    try std.testing.expectEqual(LeftClickAction.none, action);
}

test "dispatch — entity beyond range without sword and no block returns none" {
    const action = dispatch(false, true, 100, 5.0);
    try std.testing.expectEqual(LeftClickAction.none, action);
}

test "isSword — valid sword IDs 277-281" {
    try std.testing.expect(isSword(277));
    try std.testing.expect(isSword(279));
    try std.testing.expect(isSword(281));
}

test "isSword — non-sword IDs return false" {
    try std.testing.expect(!isSword(0));
    try std.testing.expect(!isSword(276));
    try std.testing.expect(!isSword(282));
    try std.testing.expect(!isSword(1000));
}

test "getMiningPriority — entity closer returns entity" {
    const p = getMiningPriority(2.0, 3.0);
    try std.testing.expectEqual(MiningPriority.entity, p);
}

test "getMiningPriority — block closer returns block" {
    const p = getMiningPriority(5.0, 2.5);
    try std.testing.expectEqual(MiningPriority.block, p);
}

test "getMiningPriority — equal distances returns entity" {
    const p = getMiningPriority(3.0, 3.0);
    try std.testing.expectEqual(MiningPriority.entity, p);
}

test "dispatch — sword sweep with each sword type" {
    // All five sword IDs should produce sweep when entity is beyond melee range.
    var id: u16 = 277;
    while (id <= 281) : (id += 1) {
        const action = dispatch(false, true, id, 4.0);
        try std.testing.expectEqual(LeftClickAction.use_sword_sweep, action);
    }
}
