/// Brewing stand UI state management.
/// Handles slot interactions, brew progress, fuel consumption, and recipe matching
/// for potions brewed in the brewing stand interface. Only depends on `std`.

const std = @import("std");

pub const Slot = struct {
    item: u16,
    count: u8,

    pub const empty = Slot{ .item = 0, .count = 0 };

    pub fn isEmpty(self: Slot) bool {
        return self.count == 0;
    }

    /// Decrement count by one; returns empty if count reaches zero.
    pub fn consumeOne(self: Slot) Slot {
        if (self.count <= 1) return Slot.empty;
        return Slot{ .item = self.item, .count = self.count - 1 };
    }
};

pub const BrewRecipe = struct {
    ingredient: u16,
    input_potion: u16,
    output_potion: u16,
};

pub const BLAZE_POWDER_ID: u16 = 320;
pub const FUEL_PER_POWDER: u8 = 20;

pub const RECIPES = [_]BrewRecipe{
    .{ .ingredient = 375, .input_potion = 400, .output_potion = 401 }, // nether_wart + water -> awkward
    .{ .ingredient = 376, .input_potion = 401, .output_potion = 402 }, // spider_eye + awkward -> poison
    .{ .ingredient = 320, .input_potion = 401, .output_potion = 403 }, // blaze_powder + awkward -> strength
    .{ .ingredient = 355, .input_potion = 401, .output_potion = 404 }, // sugar + awkward -> speed
    .{ .ingredient = 377, .input_potion = 401, .output_potion = 405 }, // glistering_melon + awkward -> healing
    .{ .ingredient = 378, .input_potion = 401, .output_potion = 406 }, // ghast_tear + awkward -> regen
    .{ .ingredient = 379, .input_potion = 401, .output_potion = 407 }, // magma_cream + awkward -> fire_resist
    .{ .ingredient = 380, .input_potion = 401, .output_potion = 408 }, // rabbit_foot + awkward -> leaping
    .{ .ingredient = 381, .input_potion = 401, .output_potion = 409 }, // turtle_shell + awkward -> turtle_master
    .{ .ingredient = 382, .input_potion = 401, .output_potion = 410 }, // phantom_membrane + awkward -> slow_falling
};

fn findRecipe(ingredient: u16, input_potion: u16) ?*const BrewRecipe {
    for (&RECIPES) |*r| {
        if (r.ingredient == ingredient and r.input_potion == input_potion) return r;
    }
    return null;
}

pub const BrewingUI = struct {
    potion_slots: [3]Slot = [_]Slot{Slot.empty} ** 3,
    ingredient_slot: Slot = Slot.empty,
    fuel_slot: Slot = Slot.empty,
    fuel_charges: u8 = 0,
    brew_progress: f32 = 0.0,
    brew_time: f32 = 20.0,
    is_brewing: bool = false,

    pub fn init() BrewingUI {
        return .{};
    }

    /// Click a slot in the brewing UI. Returns the previous slot contents (swapped with cursor).
    /// Slot indices: 0-2 potion, 3 ingredient, 4 fuel.
    pub fn clickSlot(self: *BrewingUI, slot_idx: u8, cursor: Slot) Slot {
        const slot_ptr = switch (slot_idx) {
            0 => &self.potion_slots[0],
            1 => &self.potion_slots[1],
            2 => &self.potion_slots[2],
            3 => &self.ingredient_slot,
            4 => &self.fuel_slot,
            else => return cursor,
        };
        const prev = slot_ptr.*;
        slot_ptr.* = cursor;
        return prev;
    }

    /// Advance brewing. If conditions are met, progress the brew; when complete, transform potions.
    pub fn update(self: *BrewingUI, dt: f32) void {
        if (!self.is_brewing) {
            if (self.canBrew() and self.fuel_charges > 0) {
                self.is_brewing = true;
                self.brew_progress = 0.0;
            } else {
                return;
            }
        }

        if (!self.canBrew()) {
            self.is_brewing = false;
            self.brew_progress = 0.0;
            return;
        }

        self.brew_progress += dt;

        if (self.brew_progress >= self.brew_time) {
            for (&self.potion_slots) |*slot| {
                if (!slot.isEmpty()) {
                    if (findRecipe(self.ingredient_slot.item, slot.item)) |recipe| {
                        slot.* = Slot{ .item = recipe.output_potion, .count = slot.count };
                    }
                }
            }
            self.ingredient_slot = self.ingredient_slot.consumeOne();
            self.fuel_charges -= 1;
            self.is_brewing = false;
            self.brew_progress = 0.0;
        }
    }

    /// Check if current ingredient matches any potion slot via a valid recipe.
    pub fn canBrew(self: *const BrewingUI) bool {
        if (self.ingredient_slot.isEmpty()) return false;
        for (self.potion_slots) |slot| {
            if (!slot.isEmpty()) {
                if (findRecipe(self.ingredient_slot.item, slot.item) != null) return true;
            }
        }
        return false;
    }

    /// Consume one blaze powder from fuel_slot, adding 20 fuel charges.
    pub fn addFuel(self: *BrewingUI) void {
        if (self.fuel_slot.isEmpty()) return;
        if (self.fuel_slot.item != BLAZE_POWDER_ID) return;
        self.fuel_slot = self.fuel_slot.consumeOne();
        self.fuel_charges += FUEL_PER_POWDER;
    }

    /// Return all items to the player inventory on close.
    pub fn close(self: *BrewingUI, inv_slots: []Slot) void {
        var dest: usize = 0;
        const sources = [_]*Slot{
            &self.potion_slots[0],
            &self.potion_slots[1],
            &self.potion_slots[2],
            &self.ingredient_slot,
            &self.fuel_slot,
        };
        for (sources) |src| {
            if (!src.isEmpty()) {
                while (dest < inv_slots.len) : (dest += 1) {
                    if (inv_slots[dest].isEmpty()) {
                        inv_slots[dest] = src.*;
                        src.* = Slot.empty;
                        dest += 1;
                        break;
                    }
                }
            }
        }
    }

    pub fn getBrewProgress(self: *const BrewingUI) f32 {
        return self.brew_progress / self.brew_time;
    }
};

// ─── Tests ───────────────────────────────────────────────────────────────────

test "init returns default state" {
    const ui = BrewingUI.init();
    try std.testing.expect(ui.ingredient_slot.isEmpty());
    try std.testing.expect(!ui.is_brewing);
    try std.testing.expectEqual(@as(u8, 0), ui.fuel_charges);
}

test "clickSlot swaps potion slot" {
    var ui = BrewingUI.init();
    const potion = Slot{ .item = 400, .count = 1 };
    const prev = ui.clickSlot(0, potion);
    try std.testing.expect(prev.isEmpty());
    try std.testing.expectEqual(@as(u16, 400), ui.potion_slots[0].item);
}

test "clickSlot swaps ingredient slot" {
    var ui = BrewingUI.init();
    const ingredient = Slot{ .item = 375, .count = 1 };
    _ = ui.clickSlot(3, ingredient);
    try std.testing.expectEqual(@as(u16, 375), ui.ingredient_slot.item);
}

test "clickSlot invalid index returns cursor unchanged" {
    var ui = BrewingUI.init();
    const cursor = Slot{ .item = 999, .count = 1 };
    const result = ui.clickSlot(99, cursor);
    try std.testing.expectEqual(@as(u16, 999), result.item);
}

test "canBrew returns false with no ingredient" {
    var ui = BrewingUI.init();
    ui.potion_slots[0] = Slot{ .item = 400, .count = 1 };
    try std.testing.expect(!ui.canBrew());
}

test "canBrew returns true with valid recipe" {
    var ui = BrewingUI.init();
    ui.ingredient_slot = Slot{ .item = 375, .count = 1 };
    ui.potion_slots[0] = Slot{ .item = 400, .count = 1 };
    try std.testing.expect(ui.canBrew());
}

test "canBrew returns false with mismatched recipe" {
    var ui = BrewingUI.init();
    ui.ingredient_slot = Slot{ .item = 376, .count = 1 }; // spider_eye needs awkward, not water
    ui.potion_slots[0] = Slot{ .item = 400, .count = 1 }; // water
    try std.testing.expect(!ui.canBrew());
}

test "addFuel consumes blaze powder and adds charges" {
    var ui = BrewingUI.init();
    ui.fuel_slot = Slot{ .item = BLAZE_POWDER_ID, .count = 2 };
    ui.addFuel();
    try std.testing.expectEqual(@as(u8, 20), ui.fuel_charges);
    try std.testing.expectEqual(@as(u8, 1), ui.fuel_slot.count);
    ui.addFuel();
    try std.testing.expectEqual(@as(u8, 40), ui.fuel_charges);
    try std.testing.expect(ui.fuel_slot.isEmpty());
}

test "addFuel ignores non-blaze-powder items" {
    var ui = BrewingUI.init();
    ui.fuel_slot = Slot{ .item = 999, .count = 1 };
    ui.addFuel();
    try std.testing.expectEqual(@as(u8, 0), ui.fuel_charges);
}

test "update completes brew and transforms potions" {
    var ui = BrewingUI.init();
    ui.ingredient_slot = Slot{ .item = 375, .count = 1 };
    ui.potion_slots[0] = Slot{ .item = 400, .count = 1 };
    ui.potion_slots[1] = Slot{ .item = 400, .count = 1 };
    ui.fuel_charges = 1;

    // Advance to completion
    ui.update(20.0);
    try std.testing.expect(!ui.is_brewing);
    try std.testing.expectEqual(@as(u16, 401), ui.potion_slots[0].item);
    try std.testing.expectEqual(@as(u16, 401), ui.potion_slots[1].item);
    try std.testing.expect(ui.ingredient_slot.isEmpty());
    try std.testing.expectEqual(@as(u8, 0), ui.fuel_charges);
}

test "update does not brew without fuel" {
    var ui = BrewingUI.init();
    ui.ingredient_slot = Slot{ .item = 375, .count = 1 };
    ui.potion_slots[0] = Slot{ .item = 400, .count = 1 };
    ui.fuel_charges = 0;
    ui.update(20.0);
    try std.testing.expect(!ui.is_brewing);
    try std.testing.expectEqual(@as(u16, 400), ui.potion_slots[0].item);
}

test "close returns items to inventory" {
    var ui = BrewingUI.init();
    ui.potion_slots[0] = Slot{ .item = 401, .count = 1 };
    ui.ingredient_slot = Slot{ .item = 375, .count = 3 };
    var inv = [_]Slot{Slot.empty} ** 5;
    ui.close(&inv);
    try std.testing.expectEqual(@as(u16, 401), inv[0].item);
    try std.testing.expectEqual(@as(u16, 375), inv[1].item);
    try std.testing.expect(ui.potion_slots[0].isEmpty());
    try std.testing.expect(ui.ingredient_slot.isEmpty());
}

test "getBrewProgress returns normalized value" {
    var ui = BrewingUI.init();
    ui.brew_progress = 10.0;
    ui.brew_time = 20.0;
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), ui.getBrewProgress(), 0.001);
}

test "partial brew advances progress without completing" {
    var ui = BrewingUI.init();
    ui.ingredient_slot = Slot{ .item = 375, .count = 1 };
    ui.potion_slots[0] = Slot{ .item = 400, .count = 1 };
    ui.fuel_charges = 1;
    ui.update(5.0); // partial
    try std.testing.expect(ui.is_brewing);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), ui.brew_progress, 0.001);
    try std.testing.expectEqual(@as(u16, 400), ui.potion_slots[0].item); // not yet transformed
}
