/// Furnace and smelting system.
/// Manages fuel consumption, smelt progress, and item transformation
/// via a static recipe table. Only depends on `std`.

const std = @import("std");
const inventory = @import("inventory.zig");

const ItemId = inventory.ItemId;
const STACK_MAX = inventory.STACK_MAX;

pub const SMELT_TIME: f32 = 10.0;

pub const SmeltRecipe = struct {
    input: ItemId,
    output: ItemId,
};

pub const FuelValue = struct {
    item: ItemId,
    burn_time: f32,
};

pub const smelt_recipes = [_]SmeltRecipe{
    .{ .input = 4, .output = 1 }, // cobblestone(4) -> stone(1)
    .{ .input = 6, .output = 17 }, // sand(6) -> glass(17)
    .{ .input = 13, .output = 50 }, // iron_ore(13) -> iron_ingot(50)
    .{ .input = 14, .output = 51 }, // gold_ore(14) -> gold_ingot(51)
};

pub const fuel_values = [_]FuelValue{
    .{ .item = 5, .burn_time = 15.0 }, // oak_planks
    .{ .item = 8, .burn_time = 15.0 }, // oak_log
    .{ .item = 50, .burn_time = 80.0 }, // coal
};

pub fn findRecipe(input: ItemId) ?SmeltRecipe {
    for (smelt_recipes) |recipe| {
        if (recipe.input == input) return recipe;
    }
    return null;
}

pub fn getFuelValue(item: ItemId) ?f32 {
    for (fuel_values) |fv| {
        if (fv.item == item) return fv.burn_time;
    }
    return null;
}

pub const FurnaceState = struct {
    input_item: ItemId = 0,
    input_count: u8 = 0,
    fuel_item: ItemId = 0,
    fuel_count: u8 = 0,
    output_item: ItemId = 0,
    output_count: u8 = 0,
    smelt_progress: f32 = 0.0,
    fuel_remaining: f32 = 0.0,
    is_burning: bool = false,

    pub fn init() FurnaceState {
        return .{};
    }

    /// Advance the furnace simulation by `dt` seconds.
    pub fn update(self: *FurnaceState, dt: f32) void {
        if (dt <= 0.0) return;

        const recipe = if (self.input_count > 0) findRecipe(self.input_item) else null;
        const can_output = if (recipe) |r|
            self.output_count == 0 or
                (self.output_item == r.output and self.output_count < STACK_MAX)
        else
            false;

        // Try to ignite new fuel if needed and there is work to do.
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

            if (self.smelt_progress >= SMELT_TIME) {
                const r = recipe.?;
                self.input_count -= 1;
                if (self.input_count == 0) self.input_item = 0;

                if (self.output_count == 0) {
                    self.output_item = r.output;
                }
                self.output_count += 1;
                self.smelt_progress = 0.0;
            }
        }

        if (self.fuel_remaining <= 0.0) {
            self.is_burning = false;
        }
    }

    /// Add items to the input slot. Returns the number of items that did not fit.
    pub fn addInput(self: *FurnaceState, item: ItemId, count: u8) u8 {
        return addToSlot(&self.input_item, &self.input_count, item, count);
    }

    /// Add fuel to the fuel slot. Returns the number of items that did not fit.
    pub fn addFuel(self: *FurnaceState, item: ItemId, count: u8) u8 {
        return addToSlot(&self.fuel_item, &self.fuel_count, item, count);
    }

    pub const OutputResult = struct { item: ItemId, count: u8 };

    /// Remove all items from the output slot and return them.
    pub fn takeOutput(self: *FurnaceState) OutputResult {
        const result = OutputResult{ .item = self.output_item, .count = self.output_count };
        self.output_item = 0;
        self.output_count = 0;
        return result;
    }

    /// Returns smelt progress as a fraction in [0.0, 1.0].
    pub fn getSmeltProgress(self: *const FurnaceState) f32 {
        return self.smelt_progress / SMELT_TIME;
    }
};

/// Shared helper for adding items to a single-slot stack.
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

test "smelt cobblestone to stone" {
    var f = FurnaceState.init();
    _ = f.addInput(4, 1); // cobblestone
    _ = f.addFuel(5, 1); // oak_planks (15s burn)

    // Simulate smelting to completion.
    f.update(SMELT_TIME);

    try std.testing.expectEqual(@as(ItemId, 1), f.output_item); // stone
    try std.testing.expectEqual(@as(u8, 1), f.output_count);
    try std.testing.expectEqual(@as(u8, 0), f.input_count);
}

test "fuel consumption" {
    var f = FurnaceState.init();
    _ = f.addInput(4, 2); // 2 cobblestone
    _ = f.addFuel(5, 1); // 1 oak_planks (15s)

    f.update(1.0);

    try std.testing.expect(f.is_burning);
    try std.testing.expectEqual(@as(u8, 0), f.fuel_count); // consumed from slot
    try std.testing.expect(f.fuel_remaining > 0.0);
    try std.testing.expect(f.fuel_remaining < 15.0);
}

test "progress advances with dt" {
    var f = FurnaceState.init();
    _ = f.addInput(4, 1);
    _ = f.addFuel(5, 1);

    f.update(3.0);
    const progress = f.getSmeltProgress();
    try std.testing.expect(progress > 0.0);
    try std.testing.expect(progress < 1.0);
    // 3.0 / 10.0 = 0.3
    try std.testing.expectApproxEqAbs(@as(f32, 0.3), progress, 0.001);
}

test "output collection" {
    var f = FurnaceState.init();
    _ = f.addInput(4, 1);
    _ = f.addFuel(5, 1);

    f.update(SMELT_TIME);

    const out = f.takeOutput();
    try std.testing.expectEqual(@as(ItemId, 1), out.item);
    try std.testing.expectEqual(@as(u8, 1), out.count);
    // After collection the output slot is empty.
    try std.testing.expectEqual(@as(u8, 0), f.output_count);
}

test "no smelting without fuel" {
    var f = FurnaceState.init();
    _ = f.addInput(4, 1);
    // No fuel added.

    f.update(SMELT_TIME);

    try std.testing.expect(!f.is_burning);
    try std.testing.expectEqual(@as(f32, 0.0), f.smelt_progress);
    try std.testing.expectEqual(@as(u8, 0), f.output_count);
}

test "no smelting without valid recipe" {
    var f = FurnaceState.init();
    _ = f.addInput(999, 1); // unknown item
    _ = f.addFuel(5, 1);

    f.update(SMELT_TIME);

    try std.testing.expect(!f.is_burning);
    try std.testing.expectEqual(@as(u8, 0), f.output_count);
}

test "fuel value lookup" {
    // Known fuels.
    try std.testing.expectEqual(@as(?f32, 15.0), getFuelValue(5));
    try std.testing.expectEqual(@as(?f32, 15.0), getFuelValue(8));
    try std.testing.expectEqual(@as(?f32, 80.0), getFuelValue(50));
    // Unknown item.
    try std.testing.expectEqual(@as(?f32, null), getFuelValue(999));
}

test "recipe lookup" {
    const r = findRecipe(4);
    try std.testing.expect(r != null);
    try std.testing.expectEqual(@as(ItemId, 1), r.?.output);

    try std.testing.expectEqual(@as(?SmeltRecipe, null), findRecipe(999));
}

test "fuel runs out mid-smelt pauses progress" {
    var f = FurnaceState.init();
    _ = f.addInput(4, 1);
    // Give fuel that lasts only 3 seconds (need a custom scenario).
    // Use oak_planks which lasts 15s, but we'll only progress partially.
    _ = f.addFuel(5, 1);

    // Advance 5s — should be at 50% progress, fuel at 10s remaining.
    f.update(5.0);
    try std.testing.expect(f.is_burning);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), f.getSmeltProgress(), 0.001);

    // Burn the remaining fuel (10s more), smelt completes at 10s.
    f.update(10.0);
    // After total 15s: item smelted (10s), fuel ran out (15s).
    try std.testing.expectEqual(@as(u8, 1), f.output_count);
}

test "output stacks up to 64" {
    var f = FurnaceState.init();
    _ = f.addInput(4, 64);
    _ = f.addFuel(5, 64); // plenty of fuel

    // Smelt all 64 items.
    var i: u8 = 0;
    while (i < 64) : (i += 1) {
        f.update(SMELT_TIME);
    }

    try std.testing.expectEqual(@as(u8, 64), f.output_count);
    try std.testing.expectEqual(@as(u8, 0), f.input_count);
}

test "output full prevents further smelting" {
    var f = FurnaceState.init();
    // Manually set output to nearly full.
    f.output_item = 1; // stone
    f.output_count = 64;
    _ = f.addInput(4, 1);
    _ = f.addFuel(5, 1);

    f.update(SMELT_TIME);

    // Should not have smelted because output is full.
    try std.testing.expectEqual(@as(u8, 1), f.input_count);
    try std.testing.expectEqual(@as(u8, 64), f.output_count);
}

test "addInput returns leftover on full" {
    var f = FurnaceState.init();
    const leftover1 = f.addInput(4, 60);
    try std.testing.expectEqual(@as(u8, 0), leftover1);

    const leftover2 = f.addInput(4, 10);
    try std.testing.expectEqual(@as(u8, 6), leftover2);
    try std.testing.expectEqual(@as(u8, 64), f.input_count);
}

test "addFuel rejects different item type" {
    var f = FurnaceState.init();
    _ = f.addFuel(5, 10);
    const leftover = f.addFuel(8, 5); // different fuel type
    try std.testing.expectEqual(@as(u8, 5), leftover);
    try std.testing.expectEqual(@as(u8, 10), f.fuel_count);
}
