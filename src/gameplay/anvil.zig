/// Anvil system for repairing, combining, and renaming items.
/// Supports enchantment merging with XP cost calculations and
/// a maximum cost cap of 39 levels. Only depends on `std`.

const std = @import("std");

pub const MAX_COST: u32 = 39;
pub const RENAME_COST: u32 = 1;
pub const MAX_NAME_LEN = 35;
pub const MAX_ENCHANTMENTS = 5;

pub const EnchantmentType = enum {
    sharpness,
    smite,
    efficiency,
    unbreaking,
    fortune,
    silk_touch,
    protection,
    fire_protection,
    mending,
};

pub const Enchantment = struct {
    enchant_type: EnchantmentType,
    level: u8,
};

pub const AnvilItem = struct {
    item_id: u16,
    damage: u16 = 0,
    max_damage: u16 = 100,
    enchantments: [MAX_ENCHANTMENTS]?Enchantment = [_]?Enchantment{null} ** MAX_ENCHANTMENTS,
    name: [MAX_NAME_LEN]u8 = [_]u8{0} ** MAX_NAME_LEN,
    name_len: u8 = 0,

    pub fn init(item_id: u16) AnvilItem {
        return .{ .item_id = item_id };
    }

    pub fn withDamage(item_id: u16, damage: u16, max_damage: u16) AnvilItem {
        return .{ .item_id = item_id, .damage = damage, .max_damage = max_damage };
    }

    pub fn addEnchantment(self: *AnvilItem, enchant: Enchantment) bool {
        for (&self.enchantments) |*slot| {
            if (slot.* == null) {
                slot.* = enchant;
                return true;
            }
        }
        return false;
    }

    pub fn hasEnchantment(self: *const AnvilItem, enchant_type: EnchantmentType) ?Enchantment {
        for (self.enchantments) |maybe| {
            if (maybe) |e| {
                if (e.enchant_type == enchant_type) return e;
            }
        }
        return null;
    }

    pub fn enchantmentCount(self: *const AnvilItem) u8 {
        var count: u8 = 0;
        for (self.enchantments) |maybe| {
            if (maybe != null) count += 1;
        }
        return count;
    }

    pub fn enchantLevelSum(self: *const AnvilItem) u32 {
        var total: u32 = 0;
        for (self.enchantments) |maybe| {
            if (maybe) |e| {
                total += e.level;
            }
        }
        return total;
    }
};

pub const AnvilResult = struct {
    item: AnvilItem,
    xp_cost: u32,
};

pub const AnvilState = struct {
    input: ?AnvilItem = null,
    material: ?AnvilItem = null,
    output: ?AnvilItem = null,

    pub fn init() AnvilState {
        return .{};
    }

    pub fn clear(self: *AnvilState) void {
        self.input = null;
        self.material = null;
        self.output = null;
    }
};

/// Repair an item using a material. Cost = base_repair_cost * 2.
/// Each repair restores 25% of max durability.
pub fn repairItem(base: AnvilItem, material: AnvilItem) ?AnvilResult {
    if (base.item_id != material.item_id) return null;
    if (base.damage == 0) return null;

    const base_repair_cost: u32 = 2;
    const xp_cost = base_repair_cost * 2;

    if (xp_cost > MAX_COST) return null;

    var result = base;
    const restore = base.max_damage / 4;
    if (result.damage <= restore) {
        result.damage = 0;
    } else {
        result.damage -= restore;
    }

    return .{ .item = result, .xp_cost = xp_cost };
}

/// Combine enchantments from sacrifice onto base.
/// Cost = sum of all enchantment levels on the sacrifice.
pub fn combineEnchantments(base: AnvilItem, sacrifice: AnvilItem) ?AnvilResult {
    const xp_cost = sacrifice.enchantLevelSum();
    if (xp_cost == 0) return null;
    if (xp_cost > MAX_COST) return null;

    var result = base;

    for (sacrifice.enchantments) |maybe| {
        if (maybe) |sac_enchant| {
            var found = false;
            for (&result.enchantments) |*slot| {
                if (slot.*) |*existing| {
                    if (existing.enchant_type == sac_enchant.enchant_type) {
                        if (sac_enchant.level > existing.level) {
                            existing.level = sac_enchant.level;
                        } else if (sac_enchant.level == existing.level and existing.level < 5) {
                            existing.level += 1;
                        }
                        found = true;
                        break;
                    }
                }
            }
            if (!found) {
                _ = result.addEnchantment(sac_enchant);
            }
        }
    }

    return .{ .item = result, .xp_cost = xp_cost };
}

/// Rename an item. Always costs 1 XP level.
pub fn renameItem(item: AnvilItem, name: []const u8) ?AnvilResult {
    if (name.len == 0 or name.len > MAX_NAME_LEN) return null;

    var result = item;
    @memcpy(result.name[0..name.len], name);
    if (name.len < MAX_NAME_LEN) {
        @memset(result.name[name.len..], 0);
    }
    result.name_len = @intCast(name.len);

    return .{ .item = result, .xp_cost = RENAME_COST };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "repair item restores durability" {
    const base = AnvilItem.withDamage(1, 50, 100);
    const material = AnvilItem.init(1);

    const result = repairItem(base, material).?;
    try std.testing.expectEqual(@as(u16, 25), result.item.damage);
    try std.testing.expectEqual(@as(u32, 4), result.xp_cost);
}

test "repair fully damaged item" {
    const base = AnvilItem.withDamage(1, 20, 100);
    const material = AnvilItem.init(1);

    const result = repairItem(base, material).?;
    // 20 - 25 clamped to 0
    try std.testing.expectEqual(@as(u16, 0), result.item.damage);
}

test "repair rejects mismatched items" {
    const base = AnvilItem.withDamage(1, 50, 100);
    const material = AnvilItem.init(2);

    try std.testing.expect(repairItem(base, material) == null);
}

test "repair rejects undamaged item" {
    const base = AnvilItem.init(1);
    const material = AnvilItem.init(1);

    try std.testing.expect(repairItem(base, material) == null);
}

test "combine enchantments merges from sacrifice" {
    var base = AnvilItem.init(1);
    _ = base.addEnchantment(.{ .enchant_type = .sharpness, .level = 2 });

    var sacrifice = AnvilItem.init(1);
    _ = sacrifice.addEnchantment(.{ .enchant_type = .unbreaking, .level = 3 });

    const result = combineEnchantments(base, sacrifice).?;
    try std.testing.expectEqual(@as(u32, 3), result.xp_cost);
    try std.testing.expect(result.item.hasEnchantment(.sharpness) != null);
    try std.testing.expect(result.item.hasEnchantment(.unbreaking) != null);
    try std.testing.expectEqual(@as(u8, 3), result.item.hasEnchantment(.unbreaking).?.level);
}

test "combine same enchantment upgrades level" {
    var base = AnvilItem.init(1);
    _ = base.addEnchantment(.{ .enchant_type = .sharpness, .level = 2 });

    var sacrifice = AnvilItem.init(1);
    _ = sacrifice.addEnchantment(.{ .enchant_type = .sharpness, .level = 2 });

    const result = combineEnchantments(base, sacrifice).?;
    try std.testing.expectEqual(@as(u8, 3), result.item.hasEnchantment(.sharpness).?.level);
}

test "combine higher sacrifice level overrides" {
    var base = AnvilItem.init(1);
    _ = base.addEnchantment(.{ .enchant_type = .sharpness, .level = 1 });

    var sacrifice = AnvilItem.init(1);
    _ = sacrifice.addEnchantment(.{ .enchant_type = .sharpness, .level = 3 });

    const result = combineEnchantments(base, sacrifice).?;
    try std.testing.expectEqual(@as(u8, 3), result.item.hasEnchantment(.sharpness).?.level);
}

test "combine rejects empty sacrifice" {
    const base = AnvilItem.init(1);
    const sacrifice = AnvilItem.init(1);

    try std.testing.expect(combineEnchantments(base, sacrifice) == null);
}

test "rename item costs 1 level" {
    const item = AnvilItem.init(1);
    const result = renameItem(item, "My Sword").?;

    try std.testing.expectEqual(@as(u32, RENAME_COST), result.xp_cost);
    try std.testing.expectEqual(@as(u8, 8), result.item.name_len);
}

test "rename rejects empty name" {
    const item = AnvilItem.init(1);
    try std.testing.expect(renameItem(item, "") == null);
}

test "over-cost rejection for combine" {
    const base = AnvilItem.init(1);

    // Forge a sacrifice whose enchant_level_sum exceeds MAX_COST (39).
    // We bypass addEnchantment to set artificially high levels.
    var sacrifice = AnvilItem.init(1);
    sacrifice.enchantments[0] = .{ .enchant_type = .sharpness, .level = 20 };
    sacrifice.enchantments[1] = .{ .enchant_type = .unbreaking, .level = 20 };
    // Sum = 40, exceeds MAX_COST.

    try std.testing.expect(combineEnchantments(base, sacrifice) == null);
}

test "combine at exactly MAX_COST succeeds" {
    const base = AnvilItem.init(1);

    var sacrifice = AnvilItem.init(1);
    sacrifice.enchantments[0] = .{ .enchant_type = .sharpness, .level = 20 };
    sacrifice.enchantments[1] = .{ .enchant_type = .unbreaking, .level = 19 };
    // Sum = 39, exactly at MAX_COST.

    const result = combineEnchantments(base, sacrifice);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(u32, 39), result.?.xp_cost);
}

test "AnvilState init and clear" {
    var state = AnvilState.init();
    try std.testing.expect(state.input == null);
    try std.testing.expect(state.material == null);
    try std.testing.expect(state.output == null);

    state.input = AnvilItem.init(1);
    state.clear();
    try std.testing.expect(state.input == null);
}
