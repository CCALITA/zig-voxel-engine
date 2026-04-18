/// Brewing stand system for potion creation.
/// Manages a 3-slot potion rack, ingredient slot, and blaze powder fuel.
/// Recipes transform base potions into result potions over a 20-second
/// brew cycle. Only depends on `std`.

const std = @import("std");

pub const BREW_TIME: f32 = 20.0;
pub const FUEL_PER_BLAZE_POWDER: u8 = 20;

pub const PotionId = enum(u8) {
    empty = 0,
    water = 1,
    awkward = 2,
    poison = 3,
    strength = 4,
    speed = 5,
    healing = 6,
};

pub const IngredientId = enum(u8) {
    none = 0,
    nether_wart = 1,
    spider_eye = 2,
    blaze_powder = 3,
    sugar = 4,
    glistering_melon = 5,
};

pub const BrewRecipe = struct {
    ingredient: IngredientId,
    base: PotionId,
    result: PotionId,
};

pub const recipes = [_]BrewRecipe{
    .{ .ingredient = .nether_wart, .base = .water, .result = .awkward },
    .{ .ingredient = .spider_eye, .base = .awkward, .result = .poison },
    .{ .ingredient = .blaze_powder, .base = .awkward, .result = .strength },
    .{ .ingredient = .sugar, .base = .awkward, .result = .speed },
    .{ .ingredient = .glistering_melon, .base = .awkward, .result = .healing },
};

pub fn findRecipe(ingredient: IngredientId, base: PotionId) ?BrewRecipe {
    for (recipes) |recipe| {
        if (recipe.ingredient == ingredient and recipe.base == base) return recipe;
    }
    return null;
}

pub const POTION_SLOTS = 3;

pub const BrewingStand = struct {
    potion_slots: [POTION_SLOTS]PotionId = [_]PotionId{.empty} ** POTION_SLOTS,
    ingredient: IngredientId = .none,
    fuel: u8 = 0,
    brew_progress: f32 = 0.0,
    is_brewing: bool = false,

    pub fn init() BrewingStand {
        return .{};
    }

    /// Add blaze powder fuel. Each blaze powder provides 20 fuel charges.
    pub fn addFuel(self: *BrewingStand, count: u8) void {
        const add: u16 = @as(u16, count) * FUEL_PER_BLAZE_POWDER;
        const new_fuel = @as(u16, self.fuel) + add;
        self.fuel = @intCast(@min(new_fuel, 255));
    }

    /// Set the ingredient slot.
    pub fn setIngredient(self: *BrewingStand, ingredient: IngredientId) void {
        self.ingredient = ingredient;
    }

    /// Set a specific potion slot (0-2).
    pub fn setPotion(self: *BrewingStand, slot: usize, potion: PotionId) void {
        if (slot < POTION_SLOTS) {
            self.potion_slots[slot] = potion;
        }
    }

    /// Check if at least one potion slot has a valid recipe with the current ingredient.
    fn canBrew(self: *const BrewingStand) bool {
        if (self.ingredient == .none) return false;
        if (self.fuel == 0) return false;

        for (self.potion_slots) |potion| {
            if (potion != .empty) {
                if (findRecipe(self.ingredient, potion) != null) return true;
            }
        }
        return false;
    }

    /// Advance the brewing simulation by `dt` seconds.
    pub fn update(self: *BrewingStand, dt: f32) void {
        if (dt <= 0.0) return;

        // Start brewing if not already and conditions are met.
        if (!self.is_brewing) {
            if (self.canBrew()) {
                self.is_brewing = true;
                self.brew_progress = 0.0;
            } else {
                return;
            }
        }

        // Abort if conditions changed mid-brew.
        if (self.ingredient == .none or self.fuel == 0) {
            self.is_brewing = false;
            self.brew_progress = 0.0;
            return;
        }

        self.brew_progress += dt;

        if (self.brew_progress >= BREW_TIME) {
            self.completeBrew();
        }
    }

    fn completeBrew(self: *BrewingStand) void {
        for (&self.potion_slots) |*potion| {
            if (potion.* != .empty) {
                if (findRecipe(self.ingredient, potion.*)) |recipe| {
                    potion.* = recipe.result;
                }
            }
        }

        self.fuel -= 1;
        self.ingredient = .none;
        self.is_brewing = false;
        self.brew_progress = 0.0;
    }

    /// Returns brew progress as a fraction in [0.0, 1.0].
    pub fn getBrewProgress(self: *const BrewingStand) f32 {
        if (!self.is_brewing) return 0.0;
        return @min(self.brew_progress / BREW_TIME, 1.0);
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "recipe lookup for nether_wart + water" {
    const recipe = findRecipe(.nether_wart, .water).?;
    try std.testing.expectEqual(PotionId.awkward, recipe.result);
}

test "recipe lookup for spider_eye + awkward" {
    const recipe = findRecipe(.spider_eye, .awkward).?;
    try std.testing.expectEqual(PotionId.poison, recipe.result);
}

test "recipe lookup for blaze_powder + awkward" {
    const recipe = findRecipe(.blaze_powder, .awkward).?;
    try std.testing.expectEqual(PotionId.strength, recipe.result);
}

test "recipe lookup for sugar + awkward" {
    const recipe = findRecipe(.sugar, .awkward).?;
    try std.testing.expectEqual(PotionId.speed, recipe.result);
}

test "recipe lookup for glistering_melon + awkward" {
    const recipe = findRecipe(.glistering_melon, .awkward).?;
    try std.testing.expectEqual(PotionId.healing, recipe.result);
}

test "recipe lookup returns null for invalid combo" {
    try std.testing.expect(findRecipe(.sugar, .water) == null);
    try std.testing.expect(findRecipe(.nether_wart, .awkward) == null);
}

test "brew cycle produces correct potion" {
    var stand = BrewingStand.init();
    stand.addFuel(1); // 20 charges
    stand.setPotion(0, .water);
    stand.setIngredient(.nether_wart);

    stand.update(BREW_TIME);

    try std.testing.expectEqual(PotionId.awkward, stand.potion_slots[0]);
    try std.testing.expect(!stand.is_brewing);
    try std.testing.expectEqual(IngredientId.none, stand.ingredient);
}

test "brew cycle brews all matching slots" {
    var stand = BrewingStand.init();
    stand.addFuel(1);
    stand.setPotion(0, .water);
    stand.setPotion(1, .water);
    stand.setPotion(2, .water);
    stand.setIngredient(.nether_wart);

    stand.update(BREW_TIME);

    try std.testing.expectEqual(PotionId.awkward, stand.potion_slots[0]);
    try std.testing.expectEqual(PotionId.awkward, stand.potion_slots[1]);
    try std.testing.expectEqual(PotionId.awkward, stand.potion_slots[2]);
}

test "brew cycle only transforms matching potions" {
    var stand = BrewingStand.init();
    stand.addFuel(1);
    stand.setPotion(0, .awkward);
    stand.setPotion(1, .water); // no recipe for sugar+water
    stand.setIngredient(.sugar);

    stand.update(BREW_TIME);

    try std.testing.expectEqual(PotionId.speed, stand.potion_slots[0]);
    try std.testing.expectEqual(PotionId.water, stand.potion_slots[1]);
}

test "fuel consumption decrements by 1 per brew" {
    var stand = BrewingStand.init();
    stand.addFuel(1); // 20 charges
    try std.testing.expectEqual(@as(u8, 20), stand.fuel);

    stand.setPotion(0, .water);
    stand.setIngredient(.nether_wart);
    stand.update(BREW_TIME);

    try std.testing.expectEqual(@as(u8, 19), stand.fuel);
}

test "no brewing without fuel" {
    var stand = BrewingStand.init();
    stand.setPotion(0, .water);
    stand.setIngredient(.nether_wart);

    stand.update(BREW_TIME);

    try std.testing.expectEqual(PotionId.water, stand.potion_slots[0]);
    try std.testing.expect(!stand.is_brewing);
}

test "no brewing without ingredient" {
    var stand = BrewingStand.init();
    stand.addFuel(1);
    stand.setPotion(0, .water);

    stand.update(BREW_TIME);

    try std.testing.expectEqual(PotionId.water, stand.potion_slots[0]);
    try std.testing.expect(!stand.is_brewing);
}

test "no brewing with empty potion slots" {
    var stand = BrewingStand.init();
    stand.addFuel(1);
    stand.setIngredient(.nether_wart);

    stand.update(BREW_TIME);

    try std.testing.expect(!stand.is_brewing);
}

test "partial brew progress" {
    var stand = BrewingStand.init();
    stand.addFuel(1);
    stand.setPotion(0, .water);
    stand.setIngredient(.nether_wart);

    stand.update(10.0); // half way

    try std.testing.expect(stand.is_brewing);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), stand.getBrewProgress(), 0.001);
    try std.testing.expectEqual(PotionId.water, stand.potion_slots[0]); // not done yet
}

test "brew completes after accumulated updates" {
    var stand = BrewingStand.init();
    stand.addFuel(1);
    stand.setPotion(0, .water);
    stand.setIngredient(.nether_wart);

    stand.update(10.0);
    stand.update(10.0);

    try std.testing.expectEqual(PotionId.awkward, stand.potion_slots[0]);
    try std.testing.expect(!stand.is_brewing);
}

test "addFuel accumulates charges" {
    var stand = BrewingStand.init();
    stand.addFuel(1);
    try std.testing.expectEqual(@as(u8, 20), stand.fuel);
    stand.addFuel(1);
    try std.testing.expectEqual(@as(u8, 40), stand.fuel);
}

test "init creates empty stand" {
    const stand = BrewingStand.init();
    try std.testing.expectEqual(@as(u8, 0), stand.fuel);
    try std.testing.expect(!stand.is_brewing);
    try std.testing.expectEqual(IngredientId.none, stand.ingredient);
    for (stand.potion_slots) |p| {
        try std.testing.expectEqual(PotionId.empty, p);
    }
}
