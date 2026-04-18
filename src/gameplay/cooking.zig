/// Specialized cooking blocks: Smoker, Blast Furnace, Campfire, Soul Campfire.
/// Smoker and Blast Furnace smelt at half the normal furnace time (5.0s vs 10.0s)
/// but only accept food items or ores/raw metals respectively.
/// Campfires have 4 independent cooking slots, need no fuel, and cook in 30.0s.
/// Soul Campfires behave like campfires but deal 2.0 contact damage instead of 1.0.
/// Only depends on `std`.

const std = @import("std");

// ── Item ID constants ──────────────────────────────────────────────────────
// Block-range IDs (0-255) matching src/world/block.zig
const COAL_ORE: u16 = 12;
const IRON_ORE: u16 = 13;
const GOLD_ORE: u16 = 14;
const DIAMOND_ORE: u16 = 15;
const REDSTONE_ORE: u16 = 16;

// Non-block item IDs (>=256) matching src/gameplay/food.zig
const RAW_PORKCHOP: u16 = 259;
const COOKED_PORKCHOP: u16 = 258;
const RAW_BEEF: u16 = 261;
const COOKED_BEEF: u16 = 260;
const RAW_CHICKEN: u16 = 263;
const COOKED_CHICKEN: u16 = 262;
const RAW_FISH: u16 = 266;
const COOKED_FISH: u16 = 265;
const POTATO: u16 = 270;
const BAKED_POTATO: u16 = 271;

// Smelting product IDs matching src/gameplay/furnace.zig
const IRON_INGOT: u16 = 50;
const GOLD_INGOT: u16 = 51;
const DIAMOND: u16 = 52;
const REDSTONE_DUST: u16 = 53;
const COAL: u16 = 54;

pub const ItemId = u16;
const STACK_MAX: u8 = 64;

// ── Cooking Recipe ─────────────────────────────────────────────────────────

pub const CookingRecipe = struct {
    input_item: ItemId,
    output_item: ItemId,
};

pub const SMOKER_RECIPES = [_]CookingRecipe{
    .{ .input_item = RAW_PORKCHOP, .output_item = COOKED_PORKCHOP },
    .{ .input_item = RAW_BEEF, .output_item = COOKED_BEEF },
    .{ .input_item = RAW_CHICKEN, .output_item = COOKED_CHICKEN },
    .{ .input_item = RAW_FISH, .output_item = COOKED_FISH },
    .{ .input_item = POTATO, .output_item = BAKED_POTATO },
};

pub const BLAST_FURNACE_RECIPES = [_]CookingRecipe{
    .{ .input_item = IRON_ORE, .output_item = IRON_INGOT },
    .{ .input_item = GOLD_ORE, .output_item = GOLD_INGOT },
    .{ .input_item = DIAMOND_ORE, .output_item = DIAMOND },
    .{ .input_item = REDSTONE_ORE, .output_item = REDSTONE_DUST },
    .{ .input_item = COAL_ORE, .output_item = COAL },
};

// ── Recipe lookup ──────────────────────────────────────────────────────────

fn findRecipe(comptime recipes: []const CookingRecipe, input: ItemId) ?CookingRecipe {
    for (recipes) |recipe| {
        if (recipe.input_item == input) return recipe;
    }
    return null;
}

pub fn findSmokerRecipe(input: ItemId) ?CookingRecipe {
    return findRecipe(&SMOKER_RECIPES, input);
}

pub fn findBlastFurnaceRecipe(input: ItemId) ?CookingRecipe {
    return findRecipe(&BLAST_FURNACE_RECIPES, input);
}

// ── Fuel values ────────────────────────────────────────────────────────────

const FuelValue = struct { item: ItemId, burn_time: f32 };

const fuel_values = [_]FuelValue{
    .{ .item = 5, .burn_time = 15.0 }, // oak_planks
    .{ .item = 8, .burn_time = 15.0 }, // oak_log
    .{ .item = 54, .burn_time = 80.0 }, // coal
};

fn getFuelValue(item: ItemId) ?f32 {
    for (fuel_values) |fv| {
        if (fv.item == item) return fv.burn_time;
    }
    return null;
}

// ── Generic fueled smelter ─────────────────────────────────────────────────
// Shared logic for Smoker and Blast Furnace which differ only in recipe
// table and smelt time.

fn FueledSmelter(
    comptime recipes: []const CookingRecipe,
    comptime smelt_time: f32,
) type {
    return struct {
        const Self = @This();

        input_item: ItemId = 0,
        input_count: u8 = 0,
        fuel_item: ItemId = 0,
        fuel_count: u8 = 0,
        output_item: ItemId = 0,
        output_count: u8 = 0,
        smelt_progress: f32 = 0.0,
        fuel_remaining: f32 = 0.0,
        is_burning: bool = false,

        pub fn init() Self {
            return .{};
        }

        pub fn update(self: *Self, dt: f32) void {
            if (dt <= 0.0) return;

            const recipe = if (self.input_count > 0) findRecipe(recipes, self.input_item) else null;
            const can_output = if (recipe) |r|
                self.output_count == 0 or
                    (self.output_item == r.output_item and self.output_count < STACK_MAX)
            else
                false;

            if (self.fuel_remaining <= 0.0) {
                self.is_burning = false;
                if (recipe != null and can_output and self.fuel_count > 0) {
                    if (getFuelValue(self.fuel_item)) |burn| {
                        self.fuel_remaining = burn;
                        self.fuel_count -= 1;
                        if (self.fuel_count == 0) self.fuel_item = 0;
                        self.is_burning = true;
                    }
                }
            }

            if (!self.is_burning) return;

            self.fuel_remaining -= dt;
            if (self.fuel_remaining < 0.0) self.fuel_remaining = 0.0;

            if (recipe != null and can_output) {
                self.smelt_progress += dt;

                if (self.smelt_progress >= smelt_time) {
                    const r = recipe.?;
                    self.input_count -= 1;
                    if (self.input_count == 0) self.input_item = 0;

                    if (self.output_count == 0) {
                        self.output_item = r.output_item;
                    }
                    self.output_count += 1;
                    self.smelt_progress = 0.0;
                }
            }

            if (self.fuel_remaining <= 0.0) {
                self.is_burning = false;
            }
        }

        /// Only accepts items that have a matching recipe.
        pub fn addInput(self: *Self, item: ItemId, count: u8) u8 {
            if (findRecipe(recipes, item) == null) return count;
            return addToSlot(&self.input_item, &self.input_count, item, count);
        }

        pub fn addFuel(self: *Self, item: ItemId, count: u8) u8 {
            return addToSlot(&self.fuel_item, &self.fuel_count, item, count);
        }

        pub const OutputResult = struct { item: ItemId, count: u8 };

        pub fn takeOutput(self: *Self) OutputResult {
            const result = OutputResult{ .item = self.output_item, .count = self.output_count };
            self.output_item = 0;
            self.output_count = 0;
            return result;
        }
    };
}

pub const SMOKER_SMELT_TIME: f32 = 5.0;
pub const BLAST_FURNACE_SMELT_TIME: f32 = 5.0;

pub const SmokerState = FueledSmelter(&SMOKER_RECIPES, SMOKER_SMELT_TIME);
pub const BlastFurnaceState = FueledSmelter(&BLAST_FURNACE_RECIPES, BLAST_FURNACE_SMELT_TIME);

// ── Campfire ───────────────────────────────────────────────────────────────

pub const CAMPFIRE_COOK_TIME: f32 = 30.0;
pub const CAMPFIRE_SLOT_COUNT: u8 = 4;
pub const CAMPFIRE_CONTACT_DAMAGE: f32 = 1.0;
pub const SOUL_CAMPFIRE_CONTACT_DAMAGE: f32 = 2.0;

pub const CookResult = struct {
    slot_index: u8,
    output_item: ItemId,
};

const CampfireSlot = struct {
    input_item: ItemId = 0,
    progress: f32 = 0.0,
    occupied: bool = false,
};

fn updateCampfireSlots(slots: *[CAMPFIRE_SLOT_COUNT]CampfireSlot, dt: f32) [CAMPFIRE_SLOT_COUNT]?CookResult {
    var results = [_]?CookResult{null} ** CAMPFIRE_SLOT_COUNT;
    if (dt <= 0.0) return results;

    for (slots, 0..) |*slot, i| {
        if (!slot.occupied) continue;

        const recipe = findSmokerRecipe(slot.input_item) orelse continue;

        slot.progress += dt;
        if (slot.progress >= CAMPFIRE_COOK_TIME) {
            results[i] = CookResult{
                .slot_index = @intCast(i),
                .output_item = recipe.output_item,
            };
            slot.* = .{};
        }
    }

    return results;
}

fn placeCampfireItem(slots: *[CAMPFIRE_SLOT_COUNT]CampfireSlot, slot: u8, item: ItemId) bool {
    if (slot >= CAMPFIRE_SLOT_COUNT) return false;
    if (slots[slot].occupied) return false;
    if (findSmokerRecipe(item) == null) return false;

    slots[slot] = .{ .input_item = item, .progress = 0.0, .occupied = true };
    return true;
}

pub const CampfireState = struct {
    slots: [CAMPFIRE_SLOT_COUNT]CampfireSlot = [_]CampfireSlot{.{}} ** CAMPFIRE_SLOT_COUNT,

    pub fn init() CampfireState {
        return .{};
    }

    pub fn update(self: *CampfireState, dt: f32) [CAMPFIRE_SLOT_COUNT]?CookResult {
        return updateCampfireSlots(&self.slots, dt);
    }

    pub fn placeFoodItem(self: *CampfireState, slot: u8, item: ItemId) bool {
        return placeCampfireItem(&self.slots, slot, item);
    }

    pub fn getContactDamage() f32 {
        return CAMPFIRE_CONTACT_DAMAGE;
    }
};

pub const SoulCampfireState = struct {
    slots: [CAMPFIRE_SLOT_COUNT]CampfireSlot = [_]CampfireSlot{.{}} ** CAMPFIRE_SLOT_COUNT,

    pub fn init() SoulCampfireState {
        return .{};
    }

    pub fn update(self: *SoulCampfireState, dt: f32) [CAMPFIRE_SLOT_COUNT]?CookResult {
        return updateCampfireSlots(&self.slots, dt);
    }

    pub fn placeFoodItem(self: *SoulCampfireState, slot: u8, item: ItemId) bool {
        return placeCampfireItem(&self.slots, slot, item);
    }

    pub fn getContactDamage() f32 {
        return SOUL_CAMPFIRE_CONTACT_DAMAGE;
    }
};

// ── Shared helper ──────────────────────────────────────────────────────────

fn addToSlot(slot_item: *ItemId, slot_count: *u8, item: ItemId, count: u8) u8 {
    if (count == 0) return 0;
    if (slot_count.* == 0) {
        slot_item.* = item;
        const to_add = @min(count, STACK_MAX);
        slot_count.* = to_add;
        return count - to_add;
    }
    if (slot_item.* != item) return count;
    const space = STACK_MAX - slot_count.*;
    const to_add = @min(count, space);
    slot_count.* += to_add;
    return count - to_add;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "smoker smelts food at half speed (5s)" {
    var s = SmokerState.init();
    _ = s.addInput(RAW_BEEF, 1);
    _ = s.addFuel(5, 1); // oak_planks

    s.update(4.9);
    try std.testing.expectEqual(@as(u8, 0), s.output_count);

    s.update(0.1);
    try std.testing.expectEqual(@as(u8, 1), s.output_count);
    try std.testing.expectEqual(COOKED_BEEF, s.output_item);
    try std.testing.expectEqual(@as(u8, 0), s.input_count);
}

test "smoker rejects non-food items" {
    var s = SmokerState.init();
    const leftover = s.addInput(IRON_ORE, 1);
    try std.testing.expectEqual(@as(u8, 1), leftover);
    try std.testing.expectEqual(@as(u8, 0), s.input_count);
}

test "smoker accepts all food recipes" {
    var s = SmokerState.init();
    try std.testing.expectEqual(@as(u8, 0), s.addInput(RAW_PORKCHOP, 1));
    s = SmokerState.init();
    try std.testing.expectEqual(@as(u8, 0), s.addInput(RAW_CHICKEN, 1));
    s = SmokerState.init();
    try std.testing.expectEqual(@as(u8, 0), s.addInput(POTATO, 1));
}

test "blast furnace smelts ores at half speed (5s)" {
    var bf = BlastFurnaceState.init();
    _ = bf.addInput(IRON_ORE, 1);
    _ = bf.addFuel(5, 1);

    bf.update(4.9);
    try std.testing.expectEqual(@as(u8, 0), bf.output_count);

    bf.update(0.1);
    try std.testing.expectEqual(@as(u8, 1), bf.output_count);
    try std.testing.expectEqual(IRON_INGOT, bf.output_item);
}

test "blast furnace rejects food items" {
    var bf = BlastFurnaceState.init();
    const leftover = bf.addInput(RAW_BEEF, 1);
    try std.testing.expectEqual(@as(u8, 1), leftover);
    try std.testing.expectEqual(@as(u8, 0), bf.input_count);
}

test "blast furnace accepts all ore recipes" {
    var bf = BlastFurnaceState.init();
    try std.testing.expectEqual(@as(u8, 0), bf.addInput(GOLD_ORE, 1));
    bf = BlastFurnaceState.init();
    try std.testing.expectEqual(@as(u8, 0), bf.addInput(DIAMOND_ORE, 1));
    bf = BlastFurnaceState.init();
    try std.testing.expectEqual(@as(u8, 0), bf.addInput(COAL_ORE, 1));
}

test "campfire has 4 cooking slots" {
    var c = CampfireState.init();
    try std.testing.expect(c.placeFoodItem(0, RAW_BEEF));
    try std.testing.expect(c.placeFoodItem(1, RAW_CHICKEN));
    try std.testing.expect(c.placeFoodItem(2, RAW_PORKCHOP));
    try std.testing.expect(c.placeFoodItem(3, RAW_FISH));
    try std.testing.expect(!c.placeFoodItem(4, RAW_BEEF));
}

test "campfire cooks in 30s with no fuel" {
    var c = CampfireState.init();
    try std.testing.expect(c.placeFoodItem(0, RAW_BEEF));

    const r1 = c.update(29.9);
    try std.testing.expectEqual(@as(?CookResult, null), r1[0]);

    const r2 = c.update(0.1);
    try std.testing.expect(r2[0] != null);
    try std.testing.expectEqual(@as(u8, 0), r2[0].?.slot_index);
    try std.testing.expectEqual(COOKED_BEEF, r2[0].?.output_item);
}

test "campfire rejects non-food items" {
    var c = CampfireState.init();
    try std.testing.expect(!c.placeFoodItem(0, IRON_ORE));
}

test "campfire rejects placement in occupied slot" {
    var c = CampfireState.init();
    try std.testing.expect(c.placeFoodItem(0, RAW_BEEF));
    try std.testing.expect(!c.placeFoodItem(0, RAW_CHICKEN));
}

test "campfire multiple slots cook independently" {
    var c = CampfireState.init();
    try std.testing.expect(c.placeFoodItem(0, RAW_BEEF));
    _ = c.update(15.0);
    try std.testing.expect(c.placeFoodItem(1, RAW_CHICKEN));
    _ = c.update(15.0);

    try std.testing.expect(!c.slots[0].occupied);
    try std.testing.expect(c.slots[1].occupied);

    const r = c.update(15.0);
    try std.testing.expect(r[1] != null);
    try std.testing.expectEqual(COOKED_CHICKEN, r[1].?.output_item);
}

test "soul campfire deals 2.0 contact damage" {
    try std.testing.expectEqual(@as(f32, 2.0), SoulCampfireState.getContactDamage());
    try std.testing.expectEqual(@as(f32, 1.0), CampfireState.getContactDamage());
}

test "soul campfire cooks same as regular campfire" {
    var sc = SoulCampfireState.init();
    try std.testing.expect(sc.placeFoodItem(0, RAW_BEEF));
    const r = sc.update(CAMPFIRE_COOK_TIME);
    try std.testing.expect(r[0] != null);
    try std.testing.expectEqual(COOKED_BEEF, r[0].?.output_item);
}

test "smoker recipe lookup" {
    const r = findSmokerRecipe(RAW_BEEF);
    try std.testing.expect(r != null);
    try std.testing.expectEqual(COOKED_BEEF, r.?.output_item);
    try std.testing.expectEqual(@as(?CookingRecipe, null), findSmokerRecipe(999));
}

test "blast furnace recipe lookup" {
    const r = findBlastFurnaceRecipe(IRON_ORE);
    try std.testing.expect(r != null);
    try std.testing.expectEqual(IRON_INGOT, r.?.output_item);
    try std.testing.expectEqual(@as(?CookingRecipe, null), findBlastFurnaceRecipe(RAW_BEEF));
}

test "smoker no smelting without fuel" {
    var s = SmokerState.init();
    _ = s.addInput(RAW_BEEF, 1);
    s.update(SMOKER_SMELT_TIME);
    try std.testing.expect(!s.is_burning);
    try std.testing.expectEqual(@as(u8, 0), s.output_count);
}

test "blast furnace no smelting without fuel" {
    var bf = BlastFurnaceState.init();
    _ = bf.addInput(IRON_ORE, 1);
    bf.update(BLAST_FURNACE_SMELT_TIME);
    try std.testing.expect(!bf.is_burning);
    try std.testing.expectEqual(@as(u8, 0), bf.output_count);
}
