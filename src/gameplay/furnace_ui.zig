/// Unified furnace UI supporting regular furnace, smoker, and blast furnace.
/// Handles slot interaction, fuel consumption, smelting progress, and XP accumulation.
/// Only depends on `std`.

const std = @import("std");

const STACK_MAX: u8 = 64;

pub const Slot = struct {
    item: u16,
    count: u8,

    pub const empty = Slot{ .item = 0, .count = 0 };

    pub fn isEmpty(self: Slot) bool {
        return self.count == 0;
    }
};

pub const FurnaceType = enum {
    regular,
    smoker,
    blast_furnace,
};

pub const SmeltEntry = struct {
    input: u16,
    output: u16,
    xp: f32,
};

pub const FURNACE_RECIPES = [_]SmeltEntry{
    .{ .input = 4, .output = 1, .xp = 0.1 },
    .{ .input = 6, .output = 17, .xp = 0.1 },
    .{ .input = 13, .output = 322, .xp = 0.7 },
    .{ .input = 14, .output = 323, .xp = 1.0 },
    .{ .input = 15, .output = 324, .xp = 1.0 },
    .{ .input = 8, .output = 321, .xp = 0.15 },
    .{ .input = 27, .output = 341, .xp = 0.3 },
};

pub const FuelEntry = struct {
    item: u16,
    burn_ticks: u16,
};

pub const FUEL_VALUES = [_]FuelEntry{
    .{ .item = 5, .burn_ticks = 300 },
    .{ .item = 8, .burn_ticks = 300 },
    .{ .item = 321, .burn_ticks = 1600 },
    .{ .item = 256, .burn_ticks = 100 },
};

pub const FurnaceUI = struct {
    furnace_type: FurnaceType = .regular,
    input_slot: Slot = Slot.empty,
    fuel_slot: Slot = Slot.empty,
    output_slot: Slot = Slot.empty,
    burn_remaining: f32 = 0.0,
    burn_total: f32 = 0.0,
    smelt_progress: f32 = 0.0,
    xp_stored: f32 = 0.0,

    pub fn init(ft: FurnaceType) FurnaceUI {
        return .{ .furnace_type = ft };
    }

    pub fn getSmeltTime(self: *const FurnaceUI) f32 {
        return switch (self.furnace_type) {
            .regular => 10.0,
            .smoker, .blast_furnace => 5.0,
        };
    }

    /// Click a slot with a cursor item. Returns the new cursor item.
    /// slot_idx: 0=input, 1=fuel, 2=output (output only allows taking).
    pub fn clickSlot(self: *FurnaceUI, slot_idx: u8, cursor: Slot) Slot {
        switch (slot_idx) {
            0 => return swapSlot(&self.input_slot, cursor),
            1 => return swapSlot(&self.fuel_slot, cursor),
            2 => {
                // Output slot: only allow taking, never placing
                if (cursor.isEmpty()) {
                    const taken = self.output_slot;
                    self.output_slot = Slot.empty;
                    return taken;
                }
                return cursor;
            },
            else => return cursor,
        }
    }

    /// Advance furnace simulation by dt seconds.
    pub fn update(self: *FurnaceUI, dt: f32) void {
        const recipe = self.getRecipeOutput();

        // Try to ignite fuel if not burning, input has a valid recipe, and output is compatible
        if (self.burn_remaining <= 0 and recipe != null) {
            if (self.canProduceOutput(recipe.?)) {
                _ = self.tryConsumeFuel();
            }
        }

        if (self.burn_remaining > 0) {
            self.burn_remaining -= dt;
            if (self.burn_remaining < 0) self.burn_remaining = 0;
        }

        // Advance smelting if burning and recipe is valid
        if (recipe != null and self.isBurning() and self.canProduceOutput(recipe.?)) {
            self.smelt_progress += dt;
            if (self.smelt_progress >= self.getSmeltTime()) {
                // Produce output
                const entry = recipe.?;
                self.input_slot.count -= 1;
                if (self.input_slot.count == 0) self.input_slot = Slot.empty;

                if (self.output_slot.isEmpty()) {
                    self.output_slot = .{ .item = entry.output, .count = 1 };
                } else {
                    self.output_slot.count += 1;
                }
                self.xp_stored += entry.xp;
                self.smelt_progress = 0;
            }
        } else {
            // Reset progress if conditions no longer met
            if (recipe == null or !self.isBurning()) {
                self.smelt_progress = 0;
            }
        }
    }

    pub fn isBurning(self: *const FurnaceUI) bool {
        return self.burn_remaining > 0;
    }

    pub fn getBurnProgress(self: *const FurnaceUI) f32 {
        if (self.burn_total <= 0) return 0;
        return self.burn_remaining / self.burn_total;
    }

    pub fn getSmeltProgress(self: *const FurnaceUI) f32 {
        const smelt_time = self.getSmeltTime();
        if (smelt_time <= 0) return 0;
        return self.smelt_progress / smelt_time;
    }

    pub fn collectXP(self: *FurnaceUI) f32 {
        const xp = self.xp_stored;
        self.xp_stored = 0;
        return xp;
    }

    /// Return input and fuel slots to inventory. Output stays.
    pub fn close(self: *FurnaceUI, inv_slots: []Slot) void {
        returnSlotToInventory(&self.input_slot, inv_slots);
        returnSlotToInventory(&self.fuel_slot, inv_slots);
    }

    pub fn getRecipeOutput(self: *const FurnaceUI) ?SmeltEntry {
        if (self.input_slot.isEmpty()) return null;
        for (FURNACE_RECIPES) |entry| {
            if (entry.input == self.input_slot.item) return entry;
        }
        return null;
    }

    pub fn getFuelValue(item: u16) ?u16 {
        for (FUEL_VALUES) |entry| {
            if (entry.item == item) return entry.burn_ticks;
        }
        return null;
    }

    // -- Private helpers --

    fn canProduceOutput(self: *const FurnaceUI, entry: SmeltEntry) bool {
        if (self.output_slot.isEmpty()) return true;
        return self.output_slot.item == entry.output and self.output_slot.count < STACK_MAX;
    }

    fn tryConsumeFuel(self: *FurnaceUI) bool {
        if (self.fuel_slot.isEmpty()) return false;
        const burn_ticks = getFuelValue(self.fuel_slot.item) orelse return false;
        self.fuel_slot.count -= 1;
        if (self.fuel_slot.count == 0) self.fuel_slot = Slot.empty;
        const burn_time: f32 = @as(f32, @floatFromInt(burn_ticks)) / 20.0;
        self.burn_remaining = burn_time;
        self.burn_total = burn_time;
        return true;
    }
};

fn swapSlot(slot: *Slot, cursor: Slot) Slot {
    const old = slot.*;
    slot.* = cursor;
    return old;
}

fn returnSlotToInventory(slot: *Slot, inv_slots: []Slot) void {
    if (slot.isEmpty()) return;
    for (inv_slots) |*inv| {
        if (inv.item == slot.item and inv.count < STACK_MAX) {
            const space = STACK_MAX - inv.count;
            const transfer = @min(slot.count, space);
            inv.count += transfer;
            slot.count -= transfer;
            if (slot.count == 0) {
                slot.* = Slot.empty;
                return;
            }
        }
    }
    // Try empty slots
    for (inv_slots) |*inv| {
        if (inv.isEmpty()) {
            inv.* = slot.*;
            slot.* = Slot.empty;
            return;
        }
    }
}

// =============================================================================
// Tests
// =============================================================================

test "init creates empty furnace" {
    const f = FurnaceUI.init(.regular);
    try std.testing.expect(f.input_slot.isEmpty());
    try std.testing.expect(f.fuel_slot.isEmpty());
    try std.testing.expect(f.output_slot.isEmpty());
    try std.testing.expectEqual(@as(f32, 0.0), f.smelt_progress);
}

test "getSmeltTime varies by furnace type" {
    const regular = FurnaceUI.init(.regular);
    const smoker = FurnaceUI.init(.smoker);
    const blast = FurnaceUI.init(.blast_furnace);
    try std.testing.expectEqual(@as(f32, 10.0), regular.getSmeltTime());
    try std.testing.expectEqual(@as(f32, 5.0), smoker.getSmeltTime());
    try std.testing.expectEqual(@as(f32, 5.0), blast.getSmeltTime());
}

test "getFuelValue returns correct burn ticks" {
    try std.testing.expectEqual(@as(?u16, 300), FurnaceUI.getFuelValue(5));
    try std.testing.expectEqual(@as(?u16, 1600), FurnaceUI.getFuelValue(321));
    try std.testing.expectEqual(@as(?u16, null), FurnaceUI.getFuelValue(999));
}

test "getRecipeOutput finds valid recipe" {
    var f = FurnaceUI.init(.regular);
    f.input_slot = .{ .item = 4, .count = 1 };
    const entry = f.getRecipeOutput();
    try std.testing.expect(entry != null);
    try std.testing.expectEqual(@as(u16, 1), entry.?.output);
}

test "getRecipeOutput returns null for unknown item" {
    var f = FurnaceUI.init(.regular);
    f.input_slot = .{ .item = 999, .count = 1 };
    try std.testing.expect(f.getRecipeOutput() == null);
}

test "smelting produces output and consumes input" {
    var f = FurnaceUI.init(.regular);
    f.input_slot = .{ .item = 4, .count = 2 };
    f.fuel_slot = .{ .item = 321, .count = 1 };
    // Simulate enough time to complete one smelt (10s for regular)
    f.update(10.5);
    try std.testing.expectEqual(@as(u8, 1), f.output_slot.count);
    try std.testing.expectEqual(@as(u16, 1), f.output_slot.item);
    try std.testing.expectEqual(@as(u8, 1), f.input_slot.count);
}

test "fuel is consumed when smelting starts" {
    var f = FurnaceUI.init(.regular);
    f.input_slot = .{ .item = 4, .count = 1 };
    f.fuel_slot = .{ .item = 256, .count = 1 }; // stick = 100 ticks = 5s
    f.update(0.1);
    try std.testing.expect(f.isBurning());
    try std.testing.expect(f.fuel_slot.isEmpty());
}

test "xp is stored after smelting" {
    var f = FurnaceUI.init(.regular);
    f.input_slot = .{ .item = 13, .count = 1 }; // iron ore
    f.fuel_slot = .{ .item = 321, .count = 1 }; // coal
    f.update(10.5);
    try std.testing.expect(f.xp_stored > 0.5);
    const xp = f.collectXP();
    try std.testing.expect(xp > 0.5);
    try std.testing.expectEqual(@as(f32, 0.0), f.xp_stored);
}

test "smoker smelts faster than regular" {
    var smoker = FurnaceUI.init(.smoker);
    smoker.input_slot = .{ .item = 4, .count = 1 };
    smoker.fuel_slot = .{ .item = 321, .count = 1 };
    smoker.update(5.5);
    try std.testing.expect(!smoker.output_slot.isEmpty());

    var regular = FurnaceUI.init(.regular);
    regular.input_slot = .{ .item = 4, .count = 1 };
    regular.fuel_slot = .{ .item = 321, .count = 1 };
    regular.update(5.5);
    try std.testing.expect(regular.output_slot.isEmpty());
}

test "clickSlot swaps input and fuel slots" {
    var f = FurnaceUI.init(.regular);
    const cursor = Slot{ .item = 4, .count = 10 };
    const returned = f.clickSlot(0, cursor);
    try std.testing.expect(returned.isEmpty());
    try std.testing.expectEqual(@as(u16, 4), f.input_slot.item);
    try std.testing.expectEqual(@as(u8, 10), f.input_slot.count);
}

test "clickSlot output only allows taking" {
    var f = FurnaceUI.init(.regular);
    f.output_slot = .{ .item = 1, .count = 5 };
    // Take with empty cursor
    const taken = f.clickSlot(2, Slot.empty);
    try std.testing.expectEqual(@as(u16, 1), taken.item);
    try std.testing.expectEqual(@as(u8, 5), taken.count);
    try std.testing.expect(f.output_slot.isEmpty());

    // Try placing into output — should be rejected
    f.output_slot = Slot.empty;
    const rejected = f.clickSlot(2, Slot{ .item = 50, .count = 1 });
    try std.testing.expectEqual(@as(u16, 50), rejected.item);
    try std.testing.expect(f.output_slot.isEmpty());
}

test "close returns input and fuel to inventory" {
    var f = FurnaceUI.init(.regular);
    f.input_slot = .{ .item = 4, .count = 3 };
    f.fuel_slot = .{ .item = 5, .count = 2 };
    f.output_slot = .{ .item = 1, .count = 1 };

    var inv = [_]Slot{Slot.empty} ** 9;
    f.close(&inv);

    try std.testing.expect(f.input_slot.isEmpty());
    try std.testing.expect(f.fuel_slot.isEmpty());
    // Output stays
    try std.testing.expectEqual(@as(u8, 1), f.output_slot.count);
    // Items went to inventory
    try std.testing.expectEqual(@as(u16, 4), inv[0].item);
    try std.testing.expectEqual(@as(u16, 5), inv[1].item);
}

test "burn progress decreases over time" {
    var f = FurnaceUI.init(.regular);
    f.input_slot = .{ .item = 4, .count = 1 };
    f.fuel_slot = .{ .item = 256, .count = 1 }; // stick = 5s
    f.update(0.1);
    const prog1 = f.getBurnProgress();
    try std.testing.expect(prog1 > 0.0);
    try std.testing.expect(prog1 <= 1.0);
    f.update(2.0);
    const prog2 = f.getBurnProgress();
    try std.testing.expect(prog2 < prog1);
}

test "output stacks when smelting same item repeatedly" {
    var f = FurnaceUI.init(.smoker);
    f.input_slot = .{ .item = 4, .count = 3 };
    f.fuel_slot = .{ .item = 321, .count = 3 }; // plenty of fuel
    // Smelt 3 items (smoker = 5s each)
    f.update(5.5);
    f.update(5.5);
    f.update(5.5);
    try std.testing.expectEqual(@as(u8, 3), f.output_slot.count);
    try std.testing.expectEqual(@as(u16, 1), f.output_slot.item);
    try std.testing.expect(f.input_slot.isEmpty());
}
