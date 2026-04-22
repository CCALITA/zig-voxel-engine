/// Stonecutter UI for cutting stone variants into slabs, stairs, walls, etc.
/// Manages an input slot, recipe lookup, output selection grid, and scrolling.

const std = @import("std");
const inventory_mod = @import("inventory.zig");

pub const Slot = inventory_mod.Slot;

pub const CutRecipe = struct {
    input: u16,
    output: u16,
    output_count: u8 = 1,
};

pub const RECIPES = [_]CutRecipe{
    .{ .input = 1, .output = 500 }, // stone -> stone slab
    .{ .input = 1, .output = 501 }, // stone -> stone stairs
    .{ .input = 1, .output = 502 }, // stone -> stone bricks
    .{ .input = 1, .output = 503 }, // stone -> chiseled stone bricks
    .{ .input = 4, .output = 504 }, // cobble -> cobble slab
    .{ .input = 4, .output = 505 }, // cobble -> cobble stairs
    .{ .input = 4, .output = 506 }, // cobble -> cobble wall
    .{ .input = 19, .output = 507 }, // brick -> brick slab
    .{ .input = 19, .output = 508 }, // brick -> brick stairs
    .{ .input = 19, .output = 509 }, // brick -> brick wall
    .{ .input = 6, .output = 510 }, // sandstone -> sandstone slab
    .{ .input = 6, .output = 511 }, // sandstone -> sandstone stairs
    .{ .input = 10, .output = 512 }, // granite -> granite slab
    .{ .input = 10, .output = 513 }, // granite -> granite stairs
    .{ .input = 10, .output = 514 }, // granite -> granite wall
    .{ .input = 10, .output = 515 }, // granite -> polished granite
    .{ .input = 11, .output = 516 }, // diorite -> diorite slab
    .{ .input = 11, .output = 517 }, // diorite -> diorite stairs
    .{ .input = 11, .output = 518 }, // diorite -> diorite wall
    .{ .input = 11, .output = 519 }, // diorite -> polished diorite
    .{ .input = 12, .output = 520 }, // andesite -> andesite slab
    .{ .input = 12, .output = 521 }, // andesite -> andesite stairs
    .{ .input = 12, .output = 522 }, // andesite -> andesite wall
    .{ .input = 12, .output = 523 }, // andesite -> polished andesite
    .{ .input = 6, .output = 524 }, // sandstone -> cut sandstone
    .{ .input = 6, .output = 525 }, // sandstone -> sandstone wall
};

pub const MAX_OUTPUTS = 16;

pub const StonecutterUI = struct {
    input_slot: Slot = Slot.empty,
    selected_output: ?u8 = null,
    available_outputs: [MAX_OUTPUTS]?CutRecipe = [_]?CutRecipe{null} ** MAX_OUTPUTS,
    output_count: u8 = 0,
    scroll_offset: u8 = 0,

    pub fn init() StonecutterUI {
        return .{};
    }

    /// Find all recipes matching the input item and populate available_outputs.
    pub fn setInput(self: *StonecutterUI, slot: Slot) void {
        self.input_slot = slot;
        self.selected_output = null;
        self.scroll_offset = 0;
        self.output_count = 0;
        for (&self.available_outputs) |*o| o.* = null;

        if (slot.isEmpty()) return;

        for (RECIPES) |recipe| {
            if (recipe.input == slot.item and self.output_count < MAX_OUTPUTS) {
                self.available_outputs[self.output_count] = recipe;
                self.output_count += 1;
            }
        }
    }

    /// Swap cursor with input_slot, recalculate outputs.
    pub fn clickInput(self: *StonecutterUI, cursor: Slot) Slot {
        const prev = self.input_slot;
        self.setInput(cursor);
        return prev;
    }

    /// Set selected_output if idx is valid.
    pub fn selectOutput(self: *StonecutterUI, idx: u8) void {
        if (idx < self.output_count) {
            self.selected_output = idx;
        }
    }

    /// Consume 1 input and return the selected output item.
    pub fn takeOutput(self: *StonecutterUI) ?Slot {
        const sel = self.selected_output orelse return null;
        if (self.input_slot.isEmpty()) return null;
        const recipe = self.available_outputs[sel] orelse return null;

        const result = Slot{ .item = recipe.output, .count = recipe.output_count };
        self.input_slot.count -= 1;
        if (self.input_slot.count == 0) {
            self.setInput(Slot.empty);
        }
        return result;
    }

    /// Return remaining input items to inventory, then reset.
    pub fn close(self: *StonecutterUI, inv_slots: []Slot) void {
        if (!self.input_slot.isEmpty()) {
            for (inv_slots) |*s| {
                if (s.isEmpty()) {
                    s.* = self.input_slot;
                    break;
                }
            }
        }
        self.* = StonecutterUI.init();
    }

    /// Return a slice of available outputs.
    pub fn getAvailableOutputs(self: *const StonecutterUI) []const ?CutRecipe {
        return self.available_outputs[0..self.output_count];
    }
};

// ── Tests ────────────────────────────────────────────────────────────

test "init returns empty state" {
    const ui = StonecutterUI.init();
    try std.testing.expect(ui.input_slot.isEmpty());
    try std.testing.expectEqual(@as(?u8, null), ui.selected_output);
    try std.testing.expectEqual(@as(u8, 0), ui.output_count);
}

test "setInput populates outputs for stone" {
    var ui = StonecutterUI.init();
    ui.setInput(Slot{ .item = 1, .count = 5 });
    try std.testing.expectEqual(@as(u8, 4), ui.output_count);
    try std.testing.expectEqual(@as(u16, 500), ui.available_outputs[0].?.output);
}

test "setInput clears on empty slot" {
    var ui = StonecutterUI.init();
    ui.setInput(Slot{ .item = 1, .count = 3 });
    ui.setInput(Slot.empty);
    try std.testing.expectEqual(@as(u8, 0), ui.output_count);
}

test "clickInput swaps cursor and input" {
    var ui = StonecutterUI.init();
    const prev = ui.clickInput(Slot{ .item = 4, .count = 2 });
    try std.testing.expect(prev.isEmpty());
    try std.testing.expectEqual(@as(u16, 4), ui.input_slot.item);
    try std.testing.expectEqual(@as(u8, 3), ui.output_count); // cobble has 3 recipes
}

test "selectOutput sets valid index" {
    var ui = StonecutterUI.init();
    ui.setInput(Slot{ .item = 1, .count = 1 });
    ui.selectOutput(2);
    try std.testing.expectEqual(@as(?u8, 2), ui.selected_output);
}

test "selectOutput rejects invalid index" {
    var ui = StonecutterUI.init();
    ui.setInput(Slot{ .item = 1, .count = 1 });
    ui.selectOutput(10);
    try std.testing.expectEqual(@as(?u8, null), ui.selected_output);
}

test "takeOutput consumes input and returns item" {
    var ui = StonecutterUI.init();
    ui.setInput(Slot{ .item = 1, .count = 3 });
    ui.selectOutput(0);
    const result = ui.takeOutput();
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(u16, 500), result.?.item);
    try std.testing.expectEqual(@as(u8, 2), ui.input_slot.count);
}

test "takeOutput returns null without selection" {
    var ui = StonecutterUI.init();
    ui.setInput(Slot{ .item = 1, .count = 1 });
    try std.testing.expectEqual(@as(?Slot, null), ui.takeOutput());
}

test "takeOutput clears outputs when input depleted" {
    var ui = StonecutterUI.init();
    ui.setInput(Slot{ .item = 1, .count = 1 });
    ui.selectOutput(0);
    _ = ui.takeOutput();
    try std.testing.expect(ui.input_slot.isEmpty());
    try std.testing.expectEqual(@as(u8, 0), ui.output_count);
}

test "close returns input to inventory" {
    var ui = StonecutterUI.init();
    ui.setInput(Slot{ .item = 4, .count = 5 });
    var inv = [_]Slot{ Slot.empty, Slot.empty };
    ui.close(&inv);
    try std.testing.expectEqual(@as(u16, 4), inv[0].item);
    try std.testing.expectEqual(@as(u8, 5), inv[0].count);
    try std.testing.expect(ui.input_slot.isEmpty());
}

test "getAvailableOutputs returns correct slice" {
    var ui = StonecutterUI.init();
    ui.setInput(Slot{ .item = 19, .count = 1 });
    const outputs = ui.getAvailableOutputs();
    try std.testing.expectEqual(@as(usize, 3), outputs.len);
}

test "Slot.empty is empty" {
    try std.testing.expect(Slot.empty.isEmpty());
    const non_empty = Slot{ .item = 1, .count = 1 };
    try std.testing.expect(!non_empty.isEmpty());
}
