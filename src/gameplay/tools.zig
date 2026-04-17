/// Tool and weapon system.
/// Defines tool materials, kinds, stats, durability, mining speed, and harvest-level
/// checks against block types.  All values follow vanilla Minecraft conventions.

const std = @import("std");

// Block IDs referenced for harvest-level and mining-speed logic.
// Kept in sync with src/world/block.zig.
const block = struct {
    const AIR: u8 = 0;
    const STONE: u8 = 1;
    const DIRT: u8 = 2;
    const GRASS: u8 = 3;
    const COBBLESTONE: u8 = 4;
    const OAK_PLANKS: u8 = 5;
    const SAND: u8 = 6;
    const GRAVEL: u8 = 7;
    const OAK_LOG: u8 = 8;
    const OAK_LEAVES: u8 = 9;
    const COAL_ORE: u8 = 12;
    const IRON_ORE: u8 = 13;
    const GOLD_ORE: u8 = 14;
    const DIAMOND_ORE: u8 = 15;
    const REDSTONE_ORE: u8 = 16;
    const OBSIDIAN: u8 = 19;
    const NETHERRACK: u8 = 30;
};

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

pub const ToolMaterial = enum { wood, stone, iron, gold, diamond };
pub const ToolKind = enum { pickaxe, axe, shovel, sword, hoe };

pub const ToolDef = struct {
    material: ToolMaterial,
    kind: ToolKind,
    mining_speed: f32, // base mining speed multiplier
    attack_damage: f32, // melee damage
    max_durability: u16,
    harvest_level: u8, // 0=wood, 1=stone, 2=iron, 3=diamond
};

pub const ToolInstance = struct {
    def: ToolDef,
    durability: u16,

    pub fn init(material: ToolMaterial, kind: ToolKind) ToolInstance {
        const def = getToolDef(material, kind);
        return .{ .def = def, .durability = def.max_durability };
    }

    /// Decrement durability by one use.  Returns false when the tool breaks
    /// (durability reaches zero).
    pub fn use(self: *ToolInstance) bool {
        if (self.durability == 0) return false;
        self.durability -= 1;
        return self.durability > 0;
    }

    pub fn isBroken(self: *const ToolInstance) bool {
        return self.durability == 0;
    }

    /// Returns durability as a fraction in [0, 1].
    pub fn getDurabilityFraction(self: *const ToolInstance) f32 {
        if (self.def.max_durability == 0) return 0.0;
        return @as(f32, @floatFromInt(self.durability)) /
            @as(f32, @floatFromInt(self.def.max_durability));
    }
};

// ---------------------------------------------------------------------------
// Material base stats
// ---------------------------------------------------------------------------

const MaterialStats = struct {
    speed: f32,
    durability: u16,
    harvest_level: u8,
    base_sword_damage: f32,
};

fn materialStats(mat: ToolMaterial) MaterialStats {
    return switch (mat) {
        .wood => .{ .speed = 2, .durability = 59, .harvest_level = 0, .base_sword_damage = 4 },
        .stone => .{ .speed = 4, .durability = 131, .harvest_level = 1, .base_sword_damage = 5 },
        .iron => .{ .speed = 6, .durability = 250, .harvest_level = 2, .base_sword_damage = 6 },
        .gold => .{ .speed = 12, .durability = 32, .harvest_level = 0, .base_sword_damage = 4 },
        .diamond => .{ .speed = 8, .durability = 1561, .harvest_level = 3, .base_sword_damage = 7 },
    };
}

/// Derive attack damage for a tool kind from the material's base sword damage.
fn attackDamageForKind(base_sword: f32, kind: ToolKind) f32 {
    return switch (kind) {
        .sword => base_sword,
        .axe => base_sword - 1,
        .pickaxe => base_sword - 2,
        .shovel => base_sword - 2.5,
        .hoe => 1, // hoes always deal 1 damage
    };
}

/// Build the canonical ToolDef for a given material + kind.
pub fn getToolDef(material: ToolMaterial, kind: ToolKind) ToolDef {
    const stats = materialStats(material);
    return .{
        .material = material,
        .kind = kind,
        .mining_speed = stats.speed,
        .attack_damage = attackDamageForKind(stats.base_sword_damage, kind),
        .max_durability = stats.durability,
        .harvest_level = stats.harvest_level,
    };
}

// ---------------------------------------------------------------------------
// Block classification helpers
// ---------------------------------------------------------------------------

fn isPickaxeBlock(block_id: u8) bool {
    return switch (block_id) {
        block.STONE,
        block.COBBLESTONE,
        block.COAL_ORE,
        block.IRON_ORE,
        block.GOLD_ORE,
        block.DIAMOND_ORE,
        block.REDSTONE_ORE,
        block.OBSIDIAN,
        block.NETHERRACK,
        => true,
        else => false,
    };
}

fn isAxeBlock(block_id: u8) bool {
    return switch (block_id) {
        block.OAK_PLANKS, block.OAK_LOG => true,
        else => false,
    };
}

fn isShovelBlock(block_id: u8) bool {
    return switch (block_id) {
        block.DIRT, block.GRASS, block.SAND, block.GRAVEL => true,
        else => false,
    };
}

/// Minimum harvest level required to obtain drops from a block.
/// Returns 0 for blocks that any tool (or bare hand) can harvest.
fn requiredHarvestLevel(block_id: u8) u8 {
    return switch (block_id) {
        block.IRON_ORE => 1, // stone+
        block.GOLD_ORE, block.DIAMOND_ORE, block.REDSTONE_ORE => 2, // iron+
        block.OBSIDIAN => 3, // diamond only
        else => 0,
    };
}

// ---------------------------------------------------------------------------
// Public query functions
// ---------------------------------------------------------------------------

/// Get the effective mining speed of `tool` (or bare hand if null) against
/// `block_id`.  A tool that is the correct kind for the block type applies its
/// full speed multiplier; otherwise it mines at bare-hand speed (1.0).
pub fn getMiningSpeed(tool: ?ToolDef, block_id: u8) f32 {
    const bare_hand: f32 = 1.0;
    const t = tool orelse return bare_hand;

    const correct_kind = switch (t.kind) {
        .pickaxe => isPickaxeBlock(block_id),
        .axe => isAxeBlock(block_id),
        .shovel => isShovelBlock(block_id),
        .sword, .hoe => false,
    };

    return if (correct_kind) t.mining_speed else bare_hand;
}

/// Returns true when the given tool (or bare hand) is able to harvest
/// `block_id` — i.e. the player will actually receive a drop.
pub fn canHarvest(tool: ?ToolDef, block_id: u8) bool {
    const required = requiredHarvestLevel(block_id);
    if (required == 0) return true;

    const t = tool orelse return false;

    // Only pickaxes count for harvest-level comparisons on ore/obsidian.
    if (t.kind != .pickaxe) return false;

    return t.harvest_level >= required;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "getToolDef returns correct stats for each material" {
    const wood_pick = getToolDef(.wood, .pickaxe);
    try std.testing.expectEqual(@as(f32, 2), wood_pick.mining_speed);
    try std.testing.expectEqual(@as(u16, 59), wood_pick.max_durability);
    try std.testing.expectEqual(@as(u8, 0), wood_pick.harvest_level);

    const stone_pick = getToolDef(.stone, .pickaxe);
    try std.testing.expectEqual(@as(f32, 4), stone_pick.mining_speed);
    try std.testing.expectEqual(@as(u16, 131), stone_pick.max_durability);
    try std.testing.expectEqual(@as(u8, 1), stone_pick.harvest_level);

    const iron_pick = getToolDef(.iron, .pickaxe);
    try std.testing.expectEqual(@as(f32, 6), iron_pick.mining_speed);
    try std.testing.expectEqual(@as(u16, 250), iron_pick.max_durability);
    try std.testing.expectEqual(@as(u8, 2), iron_pick.harvest_level);

    const gold_pick = getToolDef(.gold, .pickaxe);
    try std.testing.expectEqual(@as(f32, 12), gold_pick.mining_speed);
    try std.testing.expectEqual(@as(u16, 32), gold_pick.max_durability);
    try std.testing.expectEqual(@as(u8, 0), gold_pick.harvest_level);

    const diamond_pick = getToolDef(.diamond, .pickaxe);
    try std.testing.expectEqual(@as(f32, 8), diamond_pick.mining_speed);
    try std.testing.expectEqual(@as(u16, 1561), diamond_pick.max_durability);
    try std.testing.expectEqual(@as(u8, 3), diamond_pick.harvest_level);
}

test "sword damage per material" {
    try std.testing.expectEqual(@as(f32, 4), getToolDef(.wood, .sword).attack_damage);
    try std.testing.expectEqual(@as(f32, 5), getToolDef(.stone, .sword).attack_damage);
    try std.testing.expectEqual(@as(f32, 6), getToolDef(.iron, .sword).attack_damage);
    try std.testing.expectEqual(@as(f32, 4), getToolDef(.gold, .sword).attack_damage);
    try std.testing.expectEqual(@as(f32, 7), getToolDef(.diamond, .sword).attack_damage);
}

test "mining speed: correct tool for block" {
    const iron_pick = getToolDef(.iron, .pickaxe);
    // Pickaxe against stone -> full speed
    try std.testing.expectEqual(@as(f32, 6), getMiningSpeed(iron_pick, block.STONE));
    // Pickaxe against dirt -> bare hand speed
    try std.testing.expectEqual(@as(f32, 1.0), getMiningSpeed(iron_pick, block.DIRT));

    const iron_shovel = getToolDef(.iron, .shovel);
    // Shovel against dirt -> full speed
    try std.testing.expectEqual(@as(f32, 6), getMiningSpeed(iron_shovel, block.DIRT));
    // Shovel against stone -> bare hand speed
    try std.testing.expectEqual(@as(f32, 1.0), getMiningSpeed(iron_shovel, block.STONE));

    const iron_axe = getToolDef(.iron, .axe);
    // Axe against wood -> full speed
    try std.testing.expectEqual(@as(f32, 6), getMiningSpeed(iron_axe, block.OAK_LOG));
}

test "mining speed: bare hand is 1.0" {
    try std.testing.expectEqual(@as(f32, 1.0), getMiningSpeed(null, block.STONE));
    try std.testing.expectEqual(@as(f32, 1.0), getMiningSpeed(null, block.DIRT));
}

test "canHarvest: stone needs wood+ pickaxe" {
    // Stone has harvest level 0, so even bare hand succeeds.
    try std.testing.expect(canHarvest(null, block.STONE));
    try std.testing.expect(canHarvest(getToolDef(.wood, .pickaxe), block.STONE));
}

test "canHarvest: iron ore needs stone+ pickaxe" {
    try std.testing.expect(!canHarvest(null, block.IRON_ORE));
    try std.testing.expect(!canHarvest(getToolDef(.wood, .pickaxe), block.IRON_ORE));
    try std.testing.expect(canHarvest(getToolDef(.stone, .pickaxe), block.IRON_ORE));
    try std.testing.expect(canHarvest(getToolDef(.iron, .pickaxe), block.IRON_ORE));
}

test "canHarvest: diamond ore needs iron+ pickaxe" {
    try std.testing.expect(!canHarvest(null, block.DIAMOND_ORE));
    try std.testing.expect(!canHarvest(getToolDef(.wood, .pickaxe), block.DIAMOND_ORE));
    try std.testing.expect(!canHarvest(getToolDef(.stone, .pickaxe), block.DIAMOND_ORE));
    try std.testing.expect(canHarvest(getToolDef(.iron, .pickaxe), block.DIAMOND_ORE));
    try std.testing.expect(canHarvest(getToolDef(.diamond, .pickaxe), block.DIAMOND_ORE));
}

test "canHarvest: gold and redstone ore need iron+ pickaxe" {
    try std.testing.expect(!canHarvest(getToolDef(.stone, .pickaxe), block.GOLD_ORE));
    try std.testing.expect(canHarvest(getToolDef(.iron, .pickaxe), block.GOLD_ORE));

    try std.testing.expect(!canHarvest(getToolDef(.stone, .pickaxe), block.REDSTONE_ORE));
    try std.testing.expect(canHarvest(getToolDef(.iron, .pickaxe), block.REDSTONE_ORE));
}

test "canHarvest: obsidian needs diamond pickaxe" {
    try std.testing.expect(!canHarvest(getToolDef(.iron, .pickaxe), block.OBSIDIAN));
    try std.testing.expect(canHarvest(getToolDef(.diamond, .pickaxe), block.OBSIDIAN));
}

test "canHarvest: non-pickaxe cannot harvest ore" {
    try std.testing.expect(!canHarvest(getToolDef(.iron, .sword), block.IRON_ORE));
    try std.testing.expect(!canHarvest(getToolDef(.diamond, .axe), block.DIAMOND_ORE));
}

test "durability decrements on use" {
    var tool = ToolInstance.init(.wood, .pickaxe);
    try std.testing.expectEqual(@as(u16, 59), tool.durability);
    try std.testing.expect(!tool.isBroken());

    const ok = tool.use();
    try std.testing.expect(ok);
    try std.testing.expectEqual(@as(u16, 58), tool.durability);
}

test "tool breaks at zero durability" {
    var tool = ToolInstance.init(.gold, .pickaxe);
    // Use all 32 durability points.  The last use returns false.
    var i: u16 = 0;
    while (i < 31) : (i += 1) {
        try std.testing.expect(tool.use());
    }
    // 32nd use: durability goes from 1 -> 0, returns false (broken).
    try std.testing.expect(!tool.use());
    try std.testing.expect(tool.isBroken());

    // Further use while broken also returns false.
    try std.testing.expect(!tool.use());
}

test "getDurabilityFraction" {
    var tool = ToolInstance.init(.iron, .pickaxe);
    try std.testing.expectEqual(@as(f32, 1.0), tool.getDurabilityFraction());

    _ = tool.use();
    const expected: f32 = 249.0 / 250.0;
    try std.testing.expectApproxEqAbs(expected, tool.getDurabilityFraction(), 0.0001);

    // Drain completely.
    tool.durability = 0;
    try std.testing.expectEqual(@as(f32, 0.0), tool.getDurabilityFraction());
}

test "ToolInstance init sets full durability and correct def" {
    const tool = ToolInstance.init(.diamond, .sword);
    try std.testing.expectEqual(@as(u16, 1561), tool.durability);
    try std.testing.expectEqual(@as(f32, 7), tool.def.attack_damage);
    try std.testing.expectEqual(ToolMaterial.diamond, tool.def.material);
    try std.testing.expectEqual(ToolKind.sword, tool.def.kind);
}
