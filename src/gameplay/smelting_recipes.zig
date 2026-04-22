/// Unified smelting recipe registry for furnace, smoker, and blast furnace.
/// Centralizes all smelting/cooking recipes with station validity, XP rewards,
/// and cook times. Only depends on `std`.

const std = @import("std");

// ── Item / Block ID constants ────────────────────────────────────────────────
// Block-range IDs (0–255) matching src/world/block.zig

const STONE: u16 = 1;
const COBBLESTONE: u16 = 4;
const SAND: u16 = 6;
const OAK_LOG: u16 = 8;
const COAL_ORE: u16 = 12;
const IRON_ORE: u16 = 13;
const GOLD_ORE: u16 = 14;
const GLASS: u16 = 17;
const SANDSTONE: u16 = 24;
const CACTUS: u16 = 30;
const CLAY_BALL: u16 = 31;
const NETHERRACK: u16 = 87;
const WET_SPONGE: u16 = 90;
const STONE_BRICKS: u16 = 98;

// Non-block item IDs (>=256) matching src/gameplay/food.zig
const RAW_PORKCHOP: u16 = 259;
const COOKED_PORKCHOP: u16 = 258;
const RAW_BEEF: u16 = 261;
const COOKED_BEEF: u16 = 260;
const RAW_CHICKEN: u16 = 263;
const COOKED_CHICKEN: u16 = 262;
const RAW_COD: u16 = 266;
const COOKED_COD: u16 = 265;
const POTATO: u16 = 270;
const BAKED_POTATO: u16 = 271;

// Extended item IDs for smelting products and inputs
const IRON_INGOT: u16 = 322;
const GOLD_INGOT: u16 = 323;
const COPPER_ORE: u16 = 324;
const COPPER_INGOT: u16 = 325;
const ANCIENT_DEBRIS: u16 = 326;
const NETHERITE_SCRAP: u16 = 327;
const RAW_SALMON: u16 = 328;
const COOKED_SALMON: u16 = 329;
const KELP: u16 = 330;
const DRIED_KELP: u16 = 331;
const RAW_MUTTON: u16 = 332;
const COOKED_MUTTON: u16 = 333;
const RAW_RABBIT: u16 = 334;
const COOKED_RABBIT: u16 = 335;
const BRICK: u16 = 336;
const NETHER_BRICK: u16 = 337;
const SMOOTH_STONE: u16 = 338;
const SMOOTH_SANDSTONE: u16 = 339;
const CHARCOAL: u16 = 340;
const GREEN_DYE: u16 = 341;
const SPONGE: u16 = 342;
const CRACKED_STONE_BRICKS: u16 = 343;
const COAL_ITEM: u16 = 344;
const LAPIS_ORE: u16 = 345;
const LAPIS_LAZULI: u16 = 346;
const RAW_IRON: u16 = 347;
const RAW_GOLD: u16 = 348;
const QUARTZ_ORE: u16 = 349;
const QUARTZ: u16 = 350;
const RED_SAND: u16 = 351;
const RED_SANDSTONE: u16 = 352;
const SMOOTH_RED_SANDSTONE: u16 = 353;

// ── Public types ─────────────────────────────────────────────────────────────

pub const StationType = enum { furnace, smoker, blast_furnace };

pub const StationFlags = packed struct {
    furnace: bool = true,
    smoker: bool = false,
    blast: bool = false,
};

pub const SmeltRecipe = struct {
    input: u16,
    output: u16,
    output_count: u8 = 1,
    xp: f32,
    cook_time: f32,
    valid_in: StationFlags,
};

// ── Helper constructors ──────────────────────────────────────────────────────

fn oreRecipe(input: u16, output: u16, xp: f32) SmeltRecipe {
    return .{ .input = input, .output = output, .xp = xp, .cook_time = 10.0, .valid_in = .{ .furnace = true, .smoker = false, .blast = true } };
}

fn foodRecipe(input: u16, output: u16, xp: f32) SmeltRecipe {
    return .{ .input = input, .output = output, .xp = xp, .cook_time = 10.0, .valid_in = .{ .furnace = true, .smoker = true, .blast = false } };
}

fn furnaceOnly(input: u16, output: u16, xp: f32) SmeltRecipe {
    return .{ .input = input, .output = output, .xp = xp, .cook_time = 10.0, .valid_in = .{ .furnace = true, .smoker = false, .blast = false } };
}

// ── Recipe table ─────────────────────────────────────────────────────────────

pub const ALL_RECIPES = [_]SmeltRecipe{
    // Ores (furnace + blast furnace)
    oreRecipe(IRON_ORE, IRON_INGOT, 0.7),
    oreRecipe(GOLD_ORE, GOLD_INGOT, 1.0),
    oreRecipe(COPPER_ORE, COPPER_INGOT, 0.7),
    oreRecipe(ANCIENT_DEBRIS, NETHERITE_SCRAP, 2.0),

    // Food (furnace + smoker)
    foodRecipe(RAW_PORKCHOP, COOKED_PORKCHOP, 0.35),
    foodRecipe(RAW_BEEF, COOKED_BEEF, 0.35),
    foodRecipe(RAW_CHICKEN, COOKED_CHICKEN, 0.35),
    foodRecipe(RAW_COD, COOKED_COD, 0.35),
    foodRecipe(RAW_SALMON, COOKED_SALMON, 0.35),
    foodRecipe(POTATO, BAKED_POTATO, 0.35),
    foodRecipe(KELP, DRIED_KELP, 0.1),
    foodRecipe(RAW_MUTTON, COOKED_MUTTON, 0.35),
    foodRecipe(RAW_RABBIT, COOKED_RABBIT, 0.35),

    // Blocks (furnace only)
    furnaceOnly(COBBLESTONE, STONE, 0.1),
    furnaceOnly(SAND, GLASS, 0.1),
    furnaceOnly(CLAY_BALL, BRICK, 0.3),
    furnaceOnly(NETHERRACK, NETHER_BRICK, 0.1),
    furnaceOnly(STONE, SMOOTH_STONE, 0.1),
    furnaceOnly(SANDSTONE, SMOOTH_SANDSTONE, 0.1),
    furnaceOnly(OAK_LOG, CHARCOAL, 0.15),
    furnaceOnly(CACTUS, GREEN_DYE, 0.2),
    furnaceOnly(WET_SPONGE, SPONGE, 0.15),
    furnaceOnly(STONE_BRICKS, CRACKED_STONE_BRICKS, 0.1),

    // Additional ores (furnace + blast furnace)
    oreRecipe(COAL_ORE, COAL_ITEM, 0.1),
    oreRecipe(LAPIS_ORE, LAPIS_LAZULI, 0.2),
    oreRecipe(RAW_IRON, IRON_INGOT, 0.7),
    oreRecipe(RAW_GOLD, GOLD_INGOT, 1.0),
    oreRecipe(QUARTZ_ORE, QUARTZ, 0.2),

    // Additional blocks (furnace only)
    furnaceOnly(RED_SAND, GLASS, 0.1),
    furnaceOnly(RED_SANDSTONE, SMOOTH_RED_SANDSTONE, 0.1),
};

// ── Public API ───────────────────────────────────────────────────────────────

/// Returns the effective cook time for a recipe at a given station.
/// Smoker and blast furnace cook at half time (5s) for their valid recipes.
fn effectiveCookTime(recipe: SmeltRecipe, station: StationType) f32 {
    return switch (station) {
        .furnace => recipe.cook_time,
        .smoker => recipe.cook_time * 0.5,
        .blast_furnace => recipe.cook_time * 0.5,
    };
}

/// Returns whether a recipe is valid for a given station type.
fn isValidForStation(recipe: SmeltRecipe, station: StationType) bool {
    return switch (station) {
        .furnace => recipe.valid_in.furnace,
        .smoker => recipe.valid_in.smoker,
        .blast_furnace => recipe.valid_in.blast,
    };
}

/// Look up the smelting result for a given input item at a specific station.
/// Returns a copy of the recipe with the cook_time adjusted for the station,
/// or null if no valid recipe exists.
pub fn getSmeltResult(input: u16, station: StationType) ?SmeltRecipe {
    for (ALL_RECIPES) |recipe| {
        if (recipe.input == input and isValidForStation(recipe, station)) {
            return SmeltRecipe{
                .input = recipe.input,
                .output = recipe.output,
                .output_count = recipe.output_count,
                .xp = recipe.xp,
                .cook_time = effectiveCookTime(recipe, station),
                .valid_in = recipe.valid_in,
            };
        }
    }
    return null;
}

/// Comptime helper: count recipes matching a station flag.
fn countForStation(comptime flag: enum { furnace, smoker, blast }) usize {
    var n: usize = 0;
    for (ALL_RECIPES) |r| {
        switch (flag) {
            .furnace => if (r.valid_in.furnace) {
                n += 1;
            },
            .smoker => if (r.valid_in.smoker) {
                n += 1;
            },
            .blast => if (r.valid_in.blast) {
                n += 1;
            },
        }
    }
    return n;
}

/// Comptime helper: collect recipes matching a station flag into a fixed array.
fn collectForStation(comptime flag: enum { furnace, smoker, blast }, comptime len: usize) [len]SmeltRecipe {
    var out: [len]SmeltRecipe = undefined;
    var idx: usize = 0;
    for (ALL_RECIPES) |r| {
        const matches = switch (flag) {
            .furnace => r.valid_in.furnace,
            .smoker => r.valid_in.smoker,
            .blast => r.valid_in.blast,
        };
        if (matches) {
            out[idx] = r;
            idx += 1;
        }
    }
    return out;
}

const FURNACE_RECIPES = collectForStation(.furnace, countForStation(.furnace));
const SMOKER_RECIPES = collectForStation(.smoker, countForStation(.smoker));
const BLAST_RECIPES = collectForStation(.blast, countForStation(.blast));

/// Returns a slice of all recipes valid for a given station type.
pub fn getAllRecipesForStation(station: StationType) []const SmeltRecipe {
    return switch (station) {
        .furnace => &FURNACE_RECIPES,
        .smoker => &SMOKER_RECIPES,
        .blast_furnace => &BLAST_RECIPES,
    };
}

// ── Tests ────────────────────────────────────────────────────────────────────

test "recipe count is at least 30" {
    try std.testing.expect(ALL_RECIPES.len >= 30);
}

test "iron ore smelts in furnace" {
    const r = getSmeltResult(IRON_ORE, .furnace);
    try std.testing.expect(r != null);
    try std.testing.expectEqual(@as(u16, IRON_INGOT), r.?.output);
    try std.testing.expectApproxEqAbs(@as(f32, 0.7), r.?.xp, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), r.?.cook_time, 0.001);
}

test "iron ore smelts in blast furnace at half time" {
    const r = getSmeltResult(IRON_ORE, .blast_furnace);
    try std.testing.expect(r != null);
    try std.testing.expectEqual(@as(u16, IRON_INGOT), r.?.output);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), r.?.cook_time, 0.001);
}

test "iron ore cannot smelt in smoker" {
    const r = getSmeltResult(IRON_ORE, .smoker);
    try std.testing.expectEqual(@as(?SmeltRecipe, null), r);
}

test "raw beef smelts in furnace" {
    const r = getSmeltResult(RAW_BEEF, .furnace);
    try std.testing.expect(r != null);
    try std.testing.expectEqual(@as(u16, COOKED_BEEF), r.?.output);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), r.?.cook_time, 0.001);
}

test "raw beef smelts in smoker at half time" {
    const r = getSmeltResult(RAW_BEEF, .smoker);
    try std.testing.expect(r != null);
    try std.testing.expectEqual(@as(u16, COOKED_BEEF), r.?.output);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), r.?.cook_time, 0.001);
}

test "raw beef cannot smelt in blast furnace" {
    const r = getSmeltResult(RAW_BEEF, .blast_furnace);
    try std.testing.expectEqual(@as(?SmeltRecipe, null), r);
}

test "cobblestone smelts only in furnace" {
    const r_furnace = getSmeltResult(COBBLESTONE, .furnace);
    try std.testing.expect(r_furnace != null);
    try std.testing.expectEqual(@as(u16, STONE), r_furnace.?.output);

    try std.testing.expectEqual(@as(?SmeltRecipe, null), getSmeltResult(COBBLESTONE, .smoker));
    try std.testing.expectEqual(@as(?SmeltRecipe, null), getSmeltResult(COBBLESTONE, .blast_furnace));
}

test "gold ore gives 1.0 xp" {
    const r = getSmeltResult(GOLD_ORE, .furnace);
    try std.testing.expect(r != null);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), r.?.xp, 0.001);
    try std.testing.expectEqual(@as(u16, GOLD_INGOT), r.?.output);
}

test "ancient debris gives 2.0 xp" {
    const r = getSmeltResult(ANCIENT_DEBRIS, .blast_furnace);
    try std.testing.expect(r != null);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), r.?.xp, 0.001);
    try std.testing.expectEqual(@as(u16, NETHERITE_SCRAP), r.?.output);
}

test "unknown item returns null for all stations" {
    try std.testing.expectEqual(@as(?SmeltRecipe, null), getSmeltResult(9999, .furnace));
    try std.testing.expectEqual(@as(?SmeltRecipe, null), getSmeltResult(9999, .smoker));
    try std.testing.expectEqual(@as(?SmeltRecipe, null), getSmeltResult(9999, .blast_furnace));
}

test "all recipes have output_count of 1" {
    for (ALL_RECIPES) |recipe| {
        try std.testing.expectEqual(@as(u8, 1), recipe.output_count);
    }
}

test "furnace accepts all recipes" {
    for (ALL_RECIPES) |recipe| {
        try std.testing.expect(recipe.valid_in.furnace);
    }
}

test "smoker recipes are food only" {
    for (ALL_RECIPES) |recipe| {
        if (recipe.valid_in.smoker) {
            // Food items have IDs >= 256 or are potato (270)
            try std.testing.expect(recipe.input >= 256);
        }
    }
}

test "blast furnace recipes are ores only" {
    for (ALL_RECIPES) |recipe| {
        if (recipe.valid_in.blast) {
            // Ore recipes should not also be smoker recipes
            try std.testing.expect(!recipe.valid_in.smoker);
        }
    }
}

test "getAllRecipesForStation returns correct counts" {
    const furnace_recipes = getAllRecipesForStation(.furnace);
    const smoker_recipes = getAllRecipesForStation(.smoker);
    const blast_recipes = getAllRecipesForStation(.blast_furnace);

    try std.testing.expectEqual(ALL_RECIPES.len, furnace_recipes.len);
    try std.testing.expectEqual(@as(usize, 9), smoker_recipes.len);
    try std.testing.expectEqual(@as(usize, 9), blast_recipes.len);
}

test "no duplicate inputs in recipe table" {
    for (ALL_RECIPES, 0..) |a, i| {
        for (ALL_RECIPES[i + 1 ..]) |b| {
            try std.testing.expect(a.input != b.input);
        }
    }
}
