/// Crafting station systems for specialized workbenches.
/// Covers Grindstone, Stonecutter, Loom, Cartography Table,
/// Smithing Table, and Fletching Table. Only depends on `std`.

const std = @import("std");
const dyes = @import("dyes.zig");

// ── Shared types ─────────────────────────────────────────────────────────

pub const ItemId = u16;

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

pub const StationItem = struct {
    item_id: ItemId,
    enchantments: [MAX_ENCHANTMENTS]?Enchantment = [_]?Enchantment{null} ** MAX_ENCHANTMENTS,

    pub fn init(item_id: ItemId) StationItem {
        return .{ .item_id = item_id };
    }

    pub fn addEnchantment(self: *StationItem, enchant: Enchantment) bool {
        for (&self.enchantments) |*slot| {
            if (slot.* == null) {
                slot.* = enchant;
                return true;
            }
        }
        return false;
    }

    pub fn enchantmentCount(self: *const StationItem) u8 {
        var count: u8 = 0;
        for (self.enchantments) |maybe| {
            if (maybe != null) count += 1;
        }
        return count;
    }

    pub fn hasEnchantment(self: *const StationItem, enchant_type: EnchantmentType) ?Enchantment {
        for (self.enchantments) |maybe| {
            if (maybe) |e| {
                if (e.enchant_type == enchant_type) return e;
            }
        }
        return null;
    }
};

// ── Grindstone ───────────────────────────────────────────────────────────

/// Remove all enchantments from an item. Returns the disenchanted item
/// and an XP reward proportional to the enchantment levels removed.
/// XP per enchantment level = 2 (simplified from vanilla random range).
/// Returns null if the item has no enchantments.
pub fn removeEnchantments(item: StationItem) ?struct { item: StationItem, xp: u32 } {
    var total_levels: u32 = 0;
    for (item.enchantments) |maybe| {
        if (maybe) |e| {
            total_levels += e.level;
        }
    }
    if (total_levels == 0) return null;

    var result = item;
    result.enchantments = [_]?Enchantment{null} ** MAX_ENCHANTMENTS;

    return .{ .item = result, .xp = total_levels * 2 };
}

// ── Stonecutter ──────────────────────────────────────────────────────────

pub const StonecutterRecipe = struct {
    input: ItemId,
    output: ItemId,
    count: u8,
};

pub const BlockId = struct {
    pub const stone: ItemId = 1;
    pub const cobblestone: ItemId = 4;
    pub const stone_bricks: ItemId = 100;
    pub const smooth_stone: ItemId = 101;
    pub const sandstone: ItemId = 102;
    pub const red_sandstone: ItemId = 103;
    pub const quartz_block: ItemId = 104;
    pub const purpur_block: ItemId = 105;
    pub const prismarine: ItemId = 106;
    pub const end_stone_bricks: ItemId = 107;
    pub const granite: ItemId = 108;
    pub const diorite: ItemId = 109;
    pub const andesite: ItemId = 110;

    pub const stone_slab: ItemId = 200;
    pub const stone_stairs: ItemId = 201;
    pub const stone_wall: ItemId = 202;
    pub const stone_brick_slab: ItemId = 203;
    pub const stone_brick_stairs: ItemId = 204;
    pub const stone_brick_wall: ItemId = 205;
    pub const cobblestone_slab: ItemId = 206;
    pub const cobblestone_stairs: ItemId = 207;
    pub const cobblestone_wall: ItemId = 208;
    pub const smooth_stone_slab: ItemId = 209;
    pub const sandstone_slab: ItemId = 210;
    pub const sandstone_stairs: ItemId = 211;
    pub const sandstone_wall: ItemId = 212;
    pub const red_sandstone_slab: ItemId = 213;
    pub const red_sandstone_stairs: ItemId = 214;
    pub const red_sandstone_wall: ItemId = 215;
    pub const granite_slab: ItemId = 216;
    pub const granite_stairs: ItemId = 217;
    pub const granite_wall: ItemId = 218;
    pub const diorite_slab: ItemId = 219;
    pub const diorite_stairs: ItemId = 220;
    pub const diorite_wall: ItemId = 221;
    pub const andesite_slab: ItemId = 222;
    pub const andesite_stairs: ItemId = 223;
    pub const andesite_wall: ItemId = 224;
    pub const chiseled_stone_bricks: ItemId = 225;
    pub const quartz_slab: ItemId = 226;
    pub const quartz_stairs: ItemId = 227;
    pub const quartz_pillar: ItemId = 228;
    pub const purpur_slab: ItemId = 229;
    pub const purpur_stairs: ItemId = 230;
    pub const purpur_pillar: ItemId = 231;
    pub const prismarine_slab: ItemId = 232;
    pub const prismarine_stairs: ItemId = 233;
    pub const prismarine_wall: ItemId = 234;
};

const stonecutter_recipes = [_]StonecutterRecipe{
    // Stone variants
    .{ .input = BlockId.stone, .output = BlockId.stone_slab, .count = 2 },
    .{ .input = BlockId.stone, .output = BlockId.stone_stairs, .count = 1 },
    .{ .input = BlockId.stone, .output = BlockId.stone_wall, .count = 1 },
    .{ .input = BlockId.stone, .output = BlockId.stone_bricks, .count = 1 },
    .{ .input = BlockId.stone, .output = BlockId.chiseled_stone_bricks, .count = 1 },
    // Stone bricks
    .{ .input = BlockId.stone_bricks, .output = BlockId.stone_brick_slab, .count = 2 },
    .{ .input = BlockId.stone_bricks, .output = BlockId.stone_brick_stairs, .count = 1 },
    .{ .input = BlockId.stone_bricks, .output = BlockId.stone_brick_wall, .count = 1 },
    .{ .input = BlockId.stone_bricks, .output = BlockId.chiseled_stone_bricks, .count = 1 },
    // Cobblestone
    .{ .input = BlockId.cobblestone, .output = BlockId.cobblestone_slab, .count = 2 },
    .{ .input = BlockId.cobblestone, .output = BlockId.cobblestone_stairs, .count = 1 },
    .{ .input = BlockId.cobblestone, .output = BlockId.cobblestone_wall, .count = 1 },
    // Smooth stone
    .{ .input = BlockId.smooth_stone, .output = BlockId.smooth_stone_slab, .count = 2 },
    // Sandstone
    .{ .input = BlockId.sandstone, .output = BlockId.sandstone_slab, .count = 2 },
    .{ .input = BlockId.sandstone, .output = BlockId.sandstone_stairs, .count = 1 },
    .{ .input = BlockId.sandstone, .output = BlockId.sandstone_wall, .count = 1 },
    // Red sandstone
    .{ .input = BlockId.red_sandstone, .output = BlockId.red_sandstone_slab, .count = 2 },
    .{ .input = BlockId.red_sandstone, .output = BlockId.red_sandstone_stairs, .count = 1 },
    .{ .input = BlockId.red_sandstone, .output = BlockId.red_sandstone_wall, .count = 1 },
    // Granite
    .{ .input = BlockId.granite, .output = BlockId.granite_slab, .count = 2 },
    .{ .input = BlockId.granite, .output = BlockId.granite_stairs, .count = 1 },
    .{ .input = BlockId.granite, .output = BlockId.granite_wall, .count = 1 },
    // Diorite
    .{ .input = BlockId.diorite, .output = BlockId.diorite_slab, .count = 2 },
    .{ .input = BlockId.diorite, .output = BlockId.diorite_stairs, .count = 1 },
    .{ .input = BlockId.diorite, .output = BlockId.diorite_wall, .count = 1 },
    // Andesite
    .{ .input = BlockId.andesite, .output = BlockId.andesite_slab, .count = 2 },
    .{ .input = BlockId.andesite, .output = BlockId.andesite_stairs, .count = 1 },
    .{ .input = BlockId.andesite, .output = BlockId.andesite_wall, .count = 1 },
};

/// Return all stonecutter recipes whose input matches `input_block`.
/// Result is a bounded slice into a caller-provided buffer.
pub fn getRecipes(input_block: ItemId, buf: *[stonecutter_recipes.len]StonecutterRecipe) []const StonecutterRecipe {
    var count: usize = 0;
    for (stonecutter_recipes) |r| {
        if (r.input == input_block) {
            buf[count] = r;
            count += 1;
        }
    }
    return buf[0..count];
}

/// Total number of stonecutter recipes registered.
pub fn stonecutterRecipeCount() usize {
    return stonecutter_recipes.len;
}

// ── Loom ─────────────────────────────────────────────────────────────────

pub const MAX_BANNER_LAYERS = 6;

pub const DyeColor = dyes.DyeColor;

pub const BannerPattern = enum {
    stripe_top,
    stripe_bottom,
    stripe_left,
    stripe_right,
    stripe_center,
    stripe_middle,
    cross,
    straight_cross,
    diagonal_left,
    diagonal_right,
    triangle_bottom,
    triangle_top,
    border,
    gradient,
    gradient_up,
    bricks,
    creeper,
    skull,
    flower,
    mojang,
};

pub const BannerLayer = struct {
    pattern: BannerPattern,
    color: DyeColor,
};

pub const BannerState = struct {
    base_color: DyeColor,
    layers: [MAX_BANNER_LAYERS]?BannerLayer = [_]?BannerLayer{null} ** MAX_BANNER_LAYERS,

    pub fn init(base_color: DyeColor) BannerState {
        return .{ .base_color = base_color };
    }

    pub fn layerCount(self: *const BannerState) u8 {
        var count: u8 = 0;
        for (self.layers) |maybe| {
            if (maybe != null) count += 1;
        }
        return count;
    }
};

/// Apply a pattern layer to a banner. Returns null if the banner already
/// has the maximum number of layers (6).
pub fn applyPattern(banner: BannerState, pattern: BannerPattern, color: DyeColor) ?BannerState {
    var result = banner;
    for (&result.layers) |*slot| {
        if (slot.* == null) {
            slot.* = .{ .pattern = pattern, .color = color };
            return result;
        }
    }
    return null; // max layers reached
}

// ── Cartography Table ────────────────────────────────────────────────────

pub const MapScale = enum(u3) {
    scale_0 = 0,
    scale_1 = 1,
    scale_2 = 2,
    scale_3 = 3,
    scale_4 = 4,
};

pub const MapState = struct {
    scale: MapScale,
    locked: bool = false,
    map_id: u32 = 0,

    pub fn init(map_id: u32) MapState {
        return .{ .map_id = map_id, .scale = .scale_0 };
    }
};

/// Zoom out a map by one scale level. Returns null if the map is already
/// at maximum scale (4) or is locked.
pub fn zoomMap(map: MapState) ?MapState {
    if (map.locked) return null;
    const raw = @intFromEnum(map.scale);
    if (raw >= 4) return null;

    return .{
        .scale = @enumFromInt(raw + 1),
        .locked = false,
        .map_id = map.map_id,
    };
}

/// Create a copy of a map with a new map_id. Returns null if the source
/// map is locked.
pub fn copyMap(map: MapState, new_id: u32) ?MapState {
    if (map.locked) return null;
    return .{
        .scale = map.scale,
        .locked = false,
        .map_id = new_id,
    };
}

/// Lock a map so it can no longer be modified. Returns null if already locked.
pub fn lockMap(map: MapState) ?MapState {
    if (map.locked) return null;
    return .{
        .scale = map.scale,
        .locked = true,
        .map_id = map.map_id,
    };
}

// ── Smithing Table ───────────────────────────────────────────────────────

const UpgradeMapping = struct {
    diamond_id: ItemId,
    netherite_id: ItemId,
};

const diamond_to_netherite = [_]UpgradeMapping{
    .{ .diamond_id = 300, .netherite_id = 400 },
    .{ .diamond_id = 301, .netherite_id = 401 },
    .{ .diamond_id = 302, .netherite_id = 402 },
    .{ .diamond_id = 303, .netherite_id = 403 },
    .{ .diamond_id = 304, .netherite_id = 404 },
    .{ .diamond_id = 305, .netherite_id = 405 },
    .{ .diamond_id = 306, .netherite_id = 406 },
    .{ .diamond_id = 307, .netherite_id = 407 },
    .{ .diamond_id = 308, .netherite_id = 408 },
};

/// Upgrade a diamond item to netherite, preserving all enchantments.
/// Returns null if the item is not a recognized diamond tool or armor piece.
pub fn upgrade(item: StationItem) ?StationItem {
    for (diamond_to_netherite) |mapping| {
        if (item.item_id == mapping.diamond_id) {
            return .{
                .item_id = mapping.netherite_id,
                .enchantments = item.enchantments,
            };
        }
    }
    return null;
}

// ── Fletching Table ──────────────────────────────────────────────────────

/// Placeholder — the fletching table has no vanilla recipes.
/// Returns false to indicate no action was taken.
pub fn fletchingInteract() bool {
    return false;
}

// ─────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────

test "grindstone removes enchantments and returns XP" {
    var item = StationItem.init(1);
    _ = item.addEnchantment(.{ .enchant_type = .sharpness, .level = 3 });
    _ = item.addEnchantment(.{ .enchant_type = .unbreaking, .level = 2 });

    const result = removeEnchantments(item).?;
    try std.testing.expectEqual(@as(u32, 10), result.xp);
    try std.testing.expectEqual(@as(u8, 0), result.item.enchantmentCount());
}

test "grindstone returns null for unenchanted item" {
    const item = StationItem.init(1);
    try std.testing.expect(removeEnchantments(item) == null);
}

test "grindstone single enchantment XP" {
    var item = StationItem.init(1);
    _ = item.addEnchantment(.{ .enchant_type = .mending, .level = 1 });

    const result = removeEnchantments(item).?;
    try std.testing.expectEqual(@as(u32, 2), result.xp);
    try std.testing.expectEqual(@as(u8, 0), result.item.enchantmentCount());
    try std.testing.expect(result.item.hasEnchantment(.mending) == null);
}

test "stonecutter returns recipes for stone" {
    var buf: [stonecutter_recipes.len]StonecutterRecipe = undefined;
    const recipes = getRecipes(BlockId.stone, &buf);
    try std.testing.expectEqual(@as(usize, 5), recipes.len);
}

test "stonecutter returns empty for unknown block" {
    var buf: [stonecutter_recipes.len]StonecutterRecipe = undefined;
    const recipes = getRecipes(9999, &buf);
    try std.testing.expectEqual(@as(usize, 0), recipes.len);
}

test "stonecutter slab recipe yields 2" {
    var buf: [stonecutter_recipes.len]StonecutterRecipe = undefined;
    const recipes = getRecipes(BlockId.stone, &buf);
    try std.testing.expectEqual(BlockId.stone_slab, recipes[0].output);
    try std.testing.expectEqual(@as(u8, 2), recipes[0].count);
}

test "stonecutter cobblestone recipes" {
    var buf: [stonecutter_recipes.len]StonecutterRecipe = undefined;
    const recipes = getRecipes(BlockId.cobblestone, &buf);
    try std.testing.expectEqual(@as(usize, 3), recipes.len);
}

test "stonecutter has at least 20 recipes total" {
    try std.testing.expect(stonecutterRecipeCount() >= 20);
}

test "loom apply pattern adds layer" {
    const banner = BannerState.init(.white);
    const result = applyPattern(banner, .cross, .red).?;
    try std.testing.expectEqual(@as(u8, 1), result.layerCount());
    try std.testing.expectEqual(BannerPattern.cross, result.layers[0].?.pattern);
    try std.testing.expectEqual(DyeColor.red, result.layers[0].?.color);
}

test "loom max layers rejects seventh pattern" {
    var banner = BannerState.init(.white);
    for (0..MAX_BANNER_LAYERS) |_| {
        banner = applyPattern(banner, .stripe_top, .blue).?;
    }
    try std.testing.expectEqual(@as(u8, MAX_BANNER_LAYERS), banner.layerCount());
    try std.testing.expect(applyPattern(banner, .creeper, .black) == null);
}

test "loom preserves base color" {
    const banner = BannerState.init(.green);
    const result = applyPattern(banner, .bricks, .yellow).?;
    try std.testing.expectEqual(DyeColor.green, result.base_color);
}

test "cartography zoom increases scale" {
    const map = MapState.init(1);
    const zoomed = zoomMap(map).?;
    try std.testing.expectEqual(MapScale.scale_1, zoomed.scale);
}

test "cartography zoom rejects max scale" {
    var map = MapState.init(1);
    map.scale = .scale_4;
    try std.testing.expect(zoomMap(map) == null);
}

test "cartography zoom rejects locked map" {
    var map = MapState.init(1);
    map.locked = true;
    try std.testing.expect(zoomMap(map) == null);
}

test "cartography copy creates clone with new id" {
    var map = MapState.init(1);
    map.scale = .scale_2;
    const copy = copyMap(map, 42).?;
    try std.testing.expectEqual(@as(u32, 42), copy.map_id);
    try std.testing.expectEqual(MapScale.scale_2, copy.scale);
    try std.testing.expect(!copy.locked);
}

test "cartography copy rejects locked map" {
    var map = MapState.init(1);
    map.locked = true;
    try std.testing.expect(copyMap(map, 2) == null);
}

test "cartography lock sets locked flag" {
    const map = MapState.init(1);
    const locked = lockMap(map).?;
    try std.testing.expect(locked.locked);
    try std.testing.expectEqual(@as(u32, 1), locked.map_id);
}

test "cartography lock rejects already locked map" {
    var map = MapState.init(1);
    map.locked = true;
    try std.testing.expect(lockMap(map) == null);
}

test "smithing upgrade diamond sword to netherite" {
    var item = StationItem.init(300);
    _ = item.addEnchantment(.{ .enchant_type = .sharpness, .level = 5 });

    const result = upgrade(item).?;
    try std.testing.expectEqual(@as(ItemId, 400), result.item_id);
    try std.testing.expectEqual(@as(u8, 1), result.enchantmentCount());
    try std.testing.expectEqual(@as(u8, 5), result.hasEnchantment(.sharpness).?.level);
}

test "smithing upgrade rejects non-diamond item" {
    const item = StationItem.init(999);
    try std.testing.expect(upgrade(item) == null);
}

test "smithing upgrade preserves all enchantments" {
    var item = StationItem.init(305);
    _ = item.addEnchantment(.{ .enchant_type = .protection, .level = 4 });
    _ = item.addEnchantment(.{ .enchant_type = .unbreaking, .level = 3 });
    _ = item.addEnchantment(.{ .enchant_type = .mending, .level = 1 });

    const result = upgrade(item).?;
    try std.testing.expectEqual(@as(ItemId, 405), result.item_id);
    try std.testing.expectEqual(@as(u8, 3), result.enchantmentCount());
    try std.testing.expect(result.hasEnchantment(.protection) != null);
    try std.testing.expect(result.hasEnchantment(.unbreaking) != null);
    try std.testing.expect(result.hasEnchantment(.mending) != null);
}

test "fletching table is a no-op placeholder" {
    try std.testing.expect(!fletchingInteract());
}

test "cartography zoom chain reaches max" {
    var map = MapState.init(1);
    for (0..4) |_| {
        map = zoomMap(map).?;
    }
    try std.testing.expectEqual(MapScale.scale_4, map.scale);
    try std.testing.expect(zoomMap(map) == null);
}

test "loom multiple patterns accumulate" {
    var banner = BannerState.init(.black);
    banner = applyPattern(banner, .stripe_top, .white).?;
    banner = applyPattern(banner, .cross, .red).?;
    banner = applyPattern(banner, .border, .blue).?;

    try std.testing.expectEqual(@as(u8, 3), banner.layerCount());
    try std.testing.expectEqual(BannerPattern.stripe_top, banner.layers[0].?.pattern);
    try std.testing.expectEqual(BannerPattern.cross, banner.layers[1].?.pattern);
    try std.testing.expectEqual(BannerPattern.border, banner.layers[2].?.pattern);
}

test "smithing upgrade each diamond piece" {
    for (diamond_to_netherite) |mapping| {
        const item = StationItem.init(mapping.diamond_id);
        const result = upgrade(item).?;
        try std.testing.expectEqual(mapping.netherite_id, result.item_id);
    }
}
