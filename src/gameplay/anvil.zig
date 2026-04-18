/// Anvil system: item repair and renaming.
/// Combines two items of the same type, restoring durability.
/// XP cost scales with the repair amount.

const std = @import("std");

pub const RepairResult = struct {
    repaired_durability: u16,
    xp_cost: u32,
};

/// Calculate the repair result from combining two items.
/// base_durability: max durability of the item type.
/// current_durability: remaining durability on the target item.
/// sacrifice_durability: remaining durability on the sacrifice item.
pub fn calculateRepair(base_durability: u16, current_durability: u16, sacrifice_durability: u16) RepairResult {
    const bonus: u16 = base_durability / 4; // 25% bonus on top of sacrifice
    const restore = @min(sacrifice_durability + bonus, base_durability - current_durability);
    const xp_cost: u32 = @max(1, @as(u32, restore) / 10);
    return .{
        .repaired_durability = current_durability + restore,
        .xp_cost = xp_cost,
    };
}

/// XP cost to rename an item on the anvil.
pub fn renameCost() u32 {
    return 1;
}

// ──────────────────────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────────────────────

test "calculateRepair restores durability" {
    const result = calculateRepair(100, 30, 40);
    try std.testing.expect(result.repaired_durability > 30);
    try std.testing.expect(result.repaired_durability <= 100);
}

test "calculateRepair does not exceed max" {
    const result = calculateRepair(100, 90, 100);
    try std.testing.expectEqual(@as(u16, 100), result.repaired_durability);
}

test "calculateRepair has xp cost" {
    const result = calculateRepair(100, 10, 50);
    try std.testing.expect(result.xp_cost >= 1);
}

test "renameCost returns 1" {
    try std.testing.expectEqual(@as(u32, 1), renameCost());
}
