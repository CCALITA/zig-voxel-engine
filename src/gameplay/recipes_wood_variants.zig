/// Wood variant crafting recipes for 6 wood types (birch, spruce, jungle,
/// acacia, dark oak, mangrove).  Each wood type produces 10 recipes, giving
/// 60 shaped recipes total.  All data is comptime-generated from a compact
/// wood-type descriptor so adding a new wood is a one-liner.

const std = @import("std");

pub const ShapedRecipe = struct {
    pattern: [3][3]u16,
    result_item: u16,
    result_count: u8,
};

// ---------------------------------------------------------------------------
// Shared item IDs
// ---------------------------------------------------------------------------

const E: u16 = 0; // empty cell
const STICK: u16 = 256;

// ---------------------------------------------------------------------------
// Wood type descriptor
// ---------------------------------------------------------------------------

const WoodType = struct {
    planks: u16,
    log: u16,
    stairs: u16,
    slab: u16,
    fence: u16,
    fence_gate: u16,
    door: u16,
    trapdoor: u16,
    sign: u16,
    boat: u16,
};

fn woodType(planks: u16, log: u16) WoodType {
    return .{
        .planks = planks,
        .log = log,
        .stairs = planks + 2,
        .slab = planks + 3,
        .fence = planks + 4,
        .fence_gate = planks + 5,
        .door = planks + 6,
        .trapdoor = planks + 7,
        .sign = planks + 8,
        .boat = planks + 9,
    };
}

const wood_types = [6]WoodType{
    woodType(111, 112), // Birch
    woodType(120, 121), // Spruce
    woodType(129, 130), // Jungle
    woodType(138, 139), // Acacia
    woodType(147, 148), // Dark Oak
    woodType(156, 157), // Mangrove
};

const recipes_per_wood = 10;

// ---------------------------------------------------------------------------
// Recipe builders (comptime)
// ---------------------------------------------------------------------------

fn logToPlanks(w: WoodType) ShapedRecipe {
    return .{
        .pattern = .{
            .{ w.log, E, E },
            .{ E, E, E },
            .{ E, E, E },
        },
        .result_item = w.planks,
        .result_count = 4,
    };
}

fn planksToSticks(w: WoodType) ShapedRecipe {
    return .{
        .pattern = .{
            .{ w.planks, E, E },
            .{ w.planks, E, E },
            .{ E, E, E },
        },
        .result_item = STICK,
        .result_count = 4,
    };
}

fn stairs(w: WoodType) ShapedRecipe {
    const P = w.planks;
    return .{
        .pattern = .{
            .{ P, E, E },
            .{ P, P, E },
            .{ P, P, P },
        },
        .result_item = w.stairs,
        .result_count = 4,
    };
}

fn slabs(w: WoodType) ShapedRecipe {
    const P = w.planks;
    return .{
        .pattern = .{
            .{ P, P, P },
            .{ E, E, E },
            .{ E, E, E },
        },
        .result_item = w.slab,
        .result_count = 6,
    };
}

fn fence(w: WoodType) ShapedRecipe {
    const P = w.planks;
    const S = STICK;
    return .{
        .pattern = .{
            .{ P, S, P },
            .{ P, S, P },
            .{ E, E, E },
        },
        .result_item = w.fence,
        .result_count = 3,
    };
}

fn fenceGate(w: WoodType) ShapedRecipe {
    const P = w.planks;
    const S = STICK;
    return .{
        .pattern = .{
            .{ S, P, S },
            .{ S, P, S },
            .{ E, E, E },
        },
        .result_item = w.fence_gate,
        .result_count = 1,
    };
}

fn door(w: WoodType) ShapedRecipe {
    const P = w.planks;
    return .{
        .pattern = .{
            .{ P, P, E },
            .{ P, P, E },
            .{ P, P, E },
        },
        .result_item = w.door,
        .result_count = 3,
    };
}

fn trapdoor(w: WoodType) ShapedRecipe {
    const P = w.planks;
    return .{
        .pattern = .{
            .{ P, P, P },
            .{ P, P, P },
            .{ E, E, E },
        },
        .result_item = w.trapdoor,
        .result_count = 2,
    };
}

fn sign(w: WoodType) ShapedRecipe {
    const P = w.planks;
    const S = STICK;
    return .{
        .pattern = .{
            .{ P, P, P },
            .{ P, P, P },
            .{ E, S, E },
        },
        .result_item = w.sign,
        .result_count = 3,
    };
}

fn boat(w: WoodType) ShapedRecipe {
    const P = w.planks;
    return .{
        .pattern = .{
            .{ P, E, P },
            .{ P, P, P },
            .{ E, E, E },
        },
        .result_item = w.boat,
        .result_count = 1,
    };
}

// ---------------------------------------------------------------------------
// Comptime recipe table generation
// ---------------------------------------------------------------------------

fn buildRecipesForWood(w: WoodType) [recipes_per_wood]ShapedRecipe {
    return .{
        logToPlanks(w),
        planksToSticks(w),
        stairs(w),
        slabs(w),
        fence(w),
        fenceGate(w),
        door(w),
        trapdoor(w),
        sign(w),
        boat(w),
    };
}

fn generateAllRecipes() [60]ShapedRecipe {
    var result: [60]ShapedRecipe = undefined;
    for (wood_types, 0..) |w, i| {
        const batch = buildRecipesForWood(w);
        for (batch, 0..) |r, j| {
            result[i * recipes_per_wood + j] = r;
        }
    }
    return result;
}

pub const recipes: [60]ShapedRecipe = generateAllRecipes();

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "recipe count is 60" {
    try std.testing.expectEqual(@as(usize, 60), recipes.len);
}

test "birch log to planks" {
    const r = recipes[0];
    try std.testing.expectEqual(@as(u16, 111), r.result_item);
    try std.testing.expectEqual(@as(u8, 4), r.result_count);
    try std.testing.expectEqual(@as(u16, 112), r.pattern[0][0]);
    try std.testing.expectEqual(@as(u16, 0), r.pattern[0][1]);
}

test "birch planks to sticks" {
    const r = recipes[1];
    try std.testing.expectEqual(@as(u16, STICK), r.result_item);
    try std.testing.expectEqual(@as(u8, 4), r.result_count);
    try std.testing.expectEqual(@as(u16, 111), r.pattern[0][0]);
    try std.testing.expectEqual(@as(u16, 111), r.pattern[1][0]);
    try std.testing.expectEqual(@as(u16, 0), r.pattern[2][0]);
}

test "birch stairs pattern" {
    const r = recipes[2];
    try std.testing.expectEqual(@as(u16, 113), r.result_item);
    try std.testing.expectEqual(@as(u8, 4), r.result_count);
    // P__ / PP_ / PPP
    try std.testing.expectEqual(@as(u16, 111), r.pattern[0][0]);
    try std.testing.expectEqual(@as(u16, 0), r.pattern[0][1]);
    try std.testing.expectEqual(@as(u16, 0), r.pattern[0][2]);
    try std.testing.expectEqual(@as(u16, 111), r.pattern[1][0]);
    try std.testing.expectEqual(@as(u16, 111), r.pattern[1][1]);
    try std.testing.expectEqual(@as(u16, 0), r.pattern[1][2]);
    try std.testing.expectEqual(@as(u16, 111), r.pattern[2][0]);
    try std.testing.expectEqual(@as(u16, 111), r.pattern[2][1]);
    try std.testing.expectEqual(@as(u16, 111), r.pattern[2][2]);
}

test "birch slab pattern" {
    const r = recipes[3];
    try std.testing.expectEqual(@as(u16, 114), r.result_item);
    try std.testing.expectEqual(@as(u8, 6), r.result_count);
    // PPP / ___ / ___
    try std.testing.expectEqual(@as(u16, 111), r.pattern[0][0]);
    try std.testing.expectEqual(@as(u16, 111), r.pattern[0][1]);
    try std.testing.expectEqual(@as(u16, 111), r.pattern[0][2]);
    try std.testing.expectEqual(@as(u16, 0), r.pattern[1][0]);
}

test "birch fence pattern" {
    const r = recipes[4];
    try std.testing.expectEqual(@as(u16, 115), r.result_item);
    try std.testing.expectEqual(@as(u8, 3), r.result_count);
    // PSP / PSP / ___
    try std.testing.expectEqual(@as(u16, 111), r.pattern[0][0]);
    try std.testing.expectEqual(@as(u16, STICK), r.pattern[0][1]);
    try std.testing.expectEqual(@as(u16, 111), r.pattern[0][2]);
    try std.testing.expectEqual(@as(u16, 111), r.pattern[1][0]);
    try std.testing.expectEqual(@as(u16, STICK), r.pattern[1][1]);
    try std.testing.expectEqual(@as(u16, 111), r.pattern[1][2]);
    try std.testing.expectEqual(@as(u16, 0), r.pattern[2][0]);
}

test "birch fence gate pattern" {
    const r = recipes[5];
    try std.testing.expectEqual(@as(u16, 116), r.result_item);
    try std.testing.expectEqual(@as(u8, 1), r.result_count);
    // SPS / SPS / ___
    try std.testing.expectEqual(@as(u16, STICK), r.pattern[0][0]);
    try std.testing.expectEqual(@as(u16, 111), r.pattern[0][1]);
    try std.testing.expectEqual(@as(u16, STICK), r.pattern[0][2]);
    try std.testing.expectEqual(@as(u16, STICK), r.pattern[1][0]);
    try std.testing.expectEqual(@as(u16, 111), r.pattern[1][1]);
    try std.testing.expectEqual(@as(u16, STICK), r.pattern[1][2]);
}

test "birch door pattern" {
    const r = recipes[6];
    try std.testing.expectEqual(@as(u16, 117), r.result_item);
    try std.testing.expectEqual(@as(u8, 3), r.result_count);
    // PP_ / PP_ / PP_
    try std.testing.expectEqual(@as(u16, 111), r.pattern[0][0]);
    try std.testing.expectEqual(@as(u16, 111), r.pattern[0][1]);
    try std.testing.expectEqual(@as(u16, 0), r.pattern[0][2]);
    try std.testing.expectEqual(@as(u16, 111), r.pattern[2][0]);
    try std.testing.expectEqual(@as(u16, 111), r.pattern[2][1]);
}

test "birch trapdoor pattern" {
    const r = recipes[7];
    try std.testing.expectEqual(@as(u16, 118), r.result_item);
    try std.testing.expectEqual(@as(u8, 2), r.result_count);
    // PPP / PPP / ___
    try std.testing.expectEqual(@as(u16, 111), r.pattern[0][0]);
    try std.testing.expectEqual(@as(u16, 111), r.pattern[0][2]);
    try std.testing.expectEqual(@as(u16, 111), r.pattern[1][0]);
    try std.testing.expectEqual(@as(u16, 0), r.pattern[2][0]);
}

test "birch sign pattern" {
    const r = recipes[8];
    try std.testing.expectEqual(@as(u16, 119), r.result_item);
    try std.testing.expectEqual(@as(u8, 3), r.result_count);
    // PPP / PPP / _S_
    try std.testing.expectEqual(@as(u16, 111), r.pattern[0][0]);
    try std.testing.expectEqual(@as(u16, 111), r.pattern[1][2]);
    try std.testing.expectEqual(@as(u16, 0), r.pattern[2][0]);
    try std.testing.expectEqual(@as(u16, STICK), r.pattern[2][1]);
    try std.testing.expectEqual(@as(u16, 0), r.pattern[2][2]);
}

test "birch boat pattern" {
    const r = recipes[9];
    try std.testing.expectEqual(@as(u16, 120), r.result_item);
    try std.testing.expectEqual(@as(u8, 1), r.result_count);
    // P_P / PPP / ___
    try std.testing.expectEqual(@as(u16, 111), r.pattern[0][0]);
    try std.testing.expectEqual(@as(u16, 0), r.pattern[0][1]);
    try std.testing.expectEqual(@as(u16, 111), r.pattern[0][2]);
    try std.testing.expectEqual(@as(u16, 111), r.pattern[1][0]);
    try std.testing.expectEqual(@as(u16, 111), r.pattern[1][1]);
    try std.testing.expectEqual(@as(u16, 111), r.pattern[1][2]);
    try std.testing.expectEqual(@as(u16, 0), r.pattern[2][0]);
}

test "spruce log to planks" {
    const r = recipes[10]; // second wood type, first recipe
    try std.testing.expectEqual(@as(u16, 120), r.result_item);
    try std.testing.expectEqual(@as(u8, 4), r.result_count);
    try std.testing.expectEqual(@as(u16, 121), r.pattern[0][0]);
}

test "spruce stairs ID" {
    const r = recipes[12];
    try std.testing.expectEqual(@as(u16, 122), r.result_item);
    try std.testing.expectEqual(@as(u8, 4), r.result_count);
}

test "jungle slab ID" {
    const r = recipes[23]; // wood index 2, recipe index 3
    try std.testing.expectEqual(@as(u16, 132), r.result_item);
    try std.testing.expectEqual(@as(u8, 6), r.result_count);
}

test "acacia fence ID" {
    const r = recipes[34]; // wood index 3, recipe index 4
    try std.testing.expectEqual(@as(u16, 142), r.result_item);
    try std.testing.expectEqual(@as(u8, 3), r.result_count);
}

test "dark oak door ID" {
    const r = recipes[46]; // wood index 4, recipe index 6
    try std.testing.expectEqual(@as(u16, 153), r.result_item);
    try std.testing.expectEqual(@as(u8, 3), r.result_count);
}

test "mangrove sign ID" {
    const r = recipes[58]; // wood index 5, recipe index 8
    try std.testing.expectEqual(@as(u16, 164), r.result_item);
    try std.testing.expectEqual(@as(u8, 3), r.result_count);
}

test "mangrove boat ID" {
    const r = recipes[59]; // last recipe
    try std.testing.expectEqual(@as(u16, 165), r.result_item);
    try std.testing.expectEqual(@as(u8, 1), r.result_count);
}

test "each wood type occupies 10 recipe slots" {
    // First recipe of each wood type should be a log-to-planks recipe
    for (wood_types, 0..) |w, i| {
        const r = recipes[i * recipes_per_wood];
        try std.testing.expectEqual(w.planks, r.result_item);
        try std.testing.expectEqual(@as(u8, 4), r.result_count);
        try std.testing.expectEqual(w.log, r.pattern[0][0]);
    }
}

test "no recipe has zero result item" {
    for (recipes) |r| {
        try std.testing.expect(r.result_item != 0);
    }
}

test "all patterns have at least one non-empty cell" {
    for (recipes) |r| {
        var has_item = false;
        for (0..3) |row| {
            for (0..3) |col| {
                if (r.pattern[row][col] != 0) has_item = true;
            }
        }
        try std.testing.expect(has_item);
    }
}
