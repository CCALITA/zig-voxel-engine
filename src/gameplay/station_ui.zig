/// UI routing framework for crafting stations.
/// Provides layout, slot positioning, and state management for all
/// workbench-style UIs. Only depends on `std`.

const std = @import("std");

// ── Station mode ────────────────────────────────────────────────────────

pub const StationMode = enum(u8) {
    none,
    crafting_3x3,
    furnace,
    anvil,
    stonecutter,
    grindstone,
    loom,
    cartography,
    smithing,
    brewing,
};

// ── Position & state ────────────────────────────────────────────────────

pub const StationPos = struct { x: i32, y: i32, z: i32 };

pub const StationState = struct {
    mode: StationMode = .none,
    pos: StationPos = .{ .x = 0, .y = 0, .z = 0 },

    pub fn isOpen(self: *const StationState) bool {
        return self.mode != .none;
    }

    pub fn open(self: *StationState, mode: StationMode, x: i32, y: i32, z: i32) void {
        self.mode = mode;
        self.pos = .{ .x = x, .y = y, .z = z };
    }

    pub fn close(self: *StationState) void {
        self.mode = .none;
    }
};

// ── Slot layout ─────────────────────────────────────────────────────────

pub const SlotType = enum {
    input,
    output,
    fuel,
    ingredient,
    result,
};

pub const SlotLayout = struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,
    slot_type: SlotType,
};

pub const Bounds = struct { x: f32, y: f32, w: f32, h: f32 };

// ── Constants ───────────────────────────────────────────────────────────

const SLOT_SIZE: f32 = 36.0;
const SLOT_GAP: f32 = 4.0;
const PADDING: f32 = 16.0;
const TITLE_BAR_H: f32 = 24.0;
const ARROW_GAP: f32 = 24.0;

// ── Title lookup ────────────────────────────────────────────────────────

pub fn getStationTitle(mode: StationMode) []const u8 {
    return switch (mode) {
        .none => "",
        .crafting_3x3 => "Crafting Table",
        .furnace => "Furnace",
        .anvil => "Anvil",
        .stonecutter => "Stonecutter",
        .grindstone => "Grindstone",
        .loom => "Loom",
        .cartography => "Cartography Table",
        .smithing => "Smithing Table",
        .brewing => "Brewing Stand",
    };
}

// ── Slot count ──────────────────────────────────────────────────────────

pub fn getStationSlotCount(mode: StationMode) u8 {
    return switch (mode) {
        .none => 0,
        .crafting_3x3 => 10, // 9 grid + 1 output
        .furnace => 3, // input, fuel, output
        .anvil => 3, // input, material, output
        .stonecutter => 2, // input, output
        .grindstone => 3, // input1, input2, output
        .loom => 4, // banner, pattern, dye, output
        .cartography => 3, // map, additive, output
        .smithing => 3, // template, input, additive (output replaces input)
        .brewing => 5, // 3 bottles, ingredient, fuel
    };
}

// ── Slot layout per mode ────────────────────────────────────────────────

pub fn getStationSlotLayout(mode: StationMode, slot_idx: u8, sw: f32, sh: f32) ?SlotLayout {
    if (slot_idx >= getStationSlotCount(mode)) return null;

    const bounds = getStationBounds(mode, sw, sh);
    const ox = bounds.x + PADDING;
    const oy = bounds.y + PADDING + TITLE_BAR_H;
    const step = SLOT_SIZE + SLOT_GAP;

    return switch (mode) {
        .none => null,
        .crafting_3x3 => layoutCrafting3x3(slot_idx, ox, oy, step),
        .furnace => layoutFurnace(slot_idx, ox, oy, step),
        .anvil => layoutAnvil(slot_idx, ox, oy, step),
        .stonecutter => layoutStonecutter(slot_idx, ox, oy, step),
        .grindstone => layoutGrindstone(slot_idx, ox, oy, step),
        .loom => layoutLoom(slot_idx, ox, oy, step),
        .cartography => layoutCartography(slot_idx, ox, oy, step),
        .smithing => layoutSmithing(slot_idx, ox, oy, step),
        .brewing => layoutBrewing(slot_idx, ox, oy, step),
    };
}

fn layoutCrafting3x3(idx: u8, ox: f32, oy: f32, step: f32) SlotLayout {
    if (idx < 9) {
        const row: f32 = @floatFromInt(idx / 3);
        const col: f32 = @floatFromInt(idx % 3);
        return .{ .x = ox + col * step, .y = oy + row * step, .w = SLOT_SIZE, .h = SLOT_SIZE, .slot_type = .input };
    }
    // output slot: right of grid with arrow gap
    return .{ .x = ox + 3.0 * step + ARROW_GAP, .y = oy + 1.0 * step, .w = SLOT_SIZE, .h = SLOT_SIZE, .slot_type = .output };
}

fn layoutFurnace(idx: u8, ox: f32, oy: f32, step: f32) SlotLayout {
    return switch (idx) {
        0 => .{ .x = ox, .y = oy, .w = SLOT_SIZE, .h = SLOT_SIZE, .slot_type = .input },
        1 => .{ .x = ox, .y = oy + 2.0 * step, .w = SLOT_SIZE, .h = SLOT_SIZE, .slot_type = .fuel },
        2 => .{ .x = ox + 2.0 * step + ARROW_GAP, .y = oy + 1.0 * step, .w = SLOT_SIZE, .h = SLOT_SIZE, .slot_type = .output },
        else => unreachable,
    };
}

fn layoutAnvil(idx: u8, ox: f32, oy: f32, step: f32) SlotLayout {
    return switch (idx) {
        0 => .{ .x = ox, .y = oy + step, .w = SLOT_SIZE, .h = SLOT_SIZE, .slot_type = .input },
        1 => .{ .x = ox + 2.0 * step, .y = oy + step, .w = SLOT_SIZE, .h = SLOT_SIZE, .slot_type = .ingredient },
        2 => .{ .x = ox + 4.0 * step, .y = oy + step, .w = SLOT_SIZE, .h = SLOT_SIZE, .slot_type = .output },
        else => unreachable,
    };
}

fn layoutStonecutter(idx: u8, ox: f32, oy: f32, step: f32) SlotLayout {
    return switch (idx) {
        0 => .{ .x = ox, .y = oy + step, .w = SLOT_SIZE, .h = SLOT_SIZE, .slot_type = .input },
        1 => .{ .x = ox + 3.0 * step, .y = oy + step, .w = SLOT_SIZE, .h = SLOT_SIZE, .slot_type = .output },
        else => unreachable,
    };
}

fn layoutGrindstone(idx: u8, ox: f32, oy: f32, step: f32) SlotLayout {
    return switch (idx) {
        0 => .{ .x = ox, .y = oy, .w = SLOT_SIZE, .h = SLOT_SIZE, .slot_type = .input },
        1 => .{ .x = ox, .y = oy + 2.0 * step, .w = SLOT_SIZE, .h = SLOT_SIZE, .slot_type = .input },
        2 => .{ .x = ox + 3.0 * step, .y = oy + step, .w = SLOT_SIZE, .h = SLOT_SIZE, .slot_type = .output },
        else => unreachable,
    };
}

fn layoutLoom(idx: u8, ox: f32, oy: f32, step: f32) SlotLayout {
    return switch (idx) {
        0 => .{ .x = ox, .y = oy, .w = SLOT_SIZE, .h = SLOT_SIZE, .slot_type = .input },
        1 => .{ .x = ox + step, .y = oy, .w = SLOT_SIZE, .h = SLOT_SIZE, .slot_type = .ingredient },
        2 => .{ .x = ox + 2.0 * step, .y = oy, .w = SLOT_SIZE, .h = SLOT_SIZE, .slot_type = .ingredient },
        3 => .{ .x = ox + 3.0 * step + ARROW_GAP, .y = oy, .w = SLOT_SIZE, .h = SLOT_SIZE, .slot_type = .output },
        else => unreachable,
    };
}

fn layoutCartography(idx: u8, ox: f32, oy: f32, step: f32) SlotLayout {
    return switch (idx) {
        0 => .{ .x = ox, .y = oy, .w = SLOT_SIZE, .h = SLOT_SIZE, .slot_type = .input },
        1 => .{ .x = ox, .y = oy + 2.0 * step, .w = SLOT_SIZE, .h = SLOT_SIZE, .slot_type = .ingredient },
        2 => .{ .x = ox + 3.0 * step, .y = oy + step, .w = SLOT_SIZE, .h = SLOT_SIZE, .slot_type = .output },
        else => unreachable,
    };
}

fn layoutSmithing(idx: u8, ox: f32, oy: f32, step: f32) SlotLayout {
    return switch (idx) {
        0 => .{ .x = ox, .y = oy + step, .w = SLOT_SIZE, .h = SLOT_SIZE, .slot_type = .input },
        1 => .{ .x = ox + step, .y = oy + step, .w = SLOT_SIZE, .h = SLOT_SIZE, .slot_type = .ingredient },
        2 => .{ .x = ox + 2.0 * step, .y = oy + step, .w = SLOT_SIZE, .h = SLOT_SIZE, .slot_type = .result },
        else => unreachable,
    };
}

fn layoutBrewing(idx: u8, ox: f32, oy: f32, step: f32) SlotLayout {
    return switch (idx) {
        // 3 bottle slots across the bottom
        0 => .{ .x = ox, .y = oy + 2.0 * step, .w = SLOT_SIZE, .h = SLOT_SIZE, .slot_type = .input },
        1 => .{ .x = ox + step, .y = oy + 2.0 * step, .w = SLOT_SIZE, .h = SLOT_SIZE, .slot_type = .input },
        2 => .{ .x = ox + 2.0 * step, .y = oy + 2.0 * step, .w = SLOT_SIZE, .h = SLOT_SIZE, .slot_type = .input },
        // ingredient top-center
        3 => .{ .x = ox + step, .y = oy, .w = SLOT_SIZE, .h = SLOT_SIZE, .slot_type = .ingredient },
        // fuel top-left
        4 => .{ .x = ox, .y = oy, .w = SLOT_SIZE, .h = SLOT_SIZE, .slot_type = .fuel },
        else => unreachable,
    };
}

// ── Station bounds ──────────────────────────────────────────────────────

pub fn getStationBounds(mode: StationMode, sw: f32, sh: f32) Bounds {
    const size = getStationSize(mode);
    return .{
        .x = (sw - size.w) / 2.0,
        .y = (sh - size.h) / 2.0,
        .w = size.w,
        .h = size.h,
    };
}

fn getStationSize(mode: StationMode) struct { w: f32, h: f32 } {
    const step = SLOT_SIZE + SLOT_GAP;
    const title_h = TITLE_BAR_H;
    const pad2 = PADDING * 2.0;

    return switch (mode) {
        .none => .{ .w = 0.0, .h = 0.0 },
        .crafting_3x3 => .{
            .w = 3.0 * step + ARROW_GAP + SLOT_SIZE + pad2,
            .h = 3.0 * step + title_h + pad2,
        },
        .furnace => .{
            .w = 2.0 * step + ARROW_GAP + SLOT_SIZE + pad2,
            .h = 3.0 * step + title_h + pad2,
        },
        .anvil => .{
            .w = 5.0 * step + pad2,
            .h = 3.0 * step + title_h + pad2,
        },
        .stonecutter => .{
            .w = 4.0 * step + pad2,
            .h = 3.0 * step + title_h + pad2,
        },
        .grindstone => .{
            .w = 4.0 * step + pad2,
            .h = 3.0 * step + title_h + pad2,
        },
        .loom => .{
            .w = 3.0 * step + ARROW_GAP + SLOT_SIZE + pad2,
            .h = step + title_h + pad2,
        },
        .cartography => .{
            .w = 4.0 * step + pad2,
            .h = 3.0 * step + title_h + pad2,
        },
        .smithing => .{
            .w = 3.0 * step + pad2,
            .h = 3.0 * step + title_h + pad2,
        },
        .brewing => .{
            .w = 3.0 * step + pad2,
            .h = 3.0 * step + title_h + pad2,
        },
    };
}

// ── Tests ───────────────────────────────────────────────────────────────

test "slot counts are correct" {
    try std.testing.expectEqual(@as(u8, 0), getStationSlotCount(.none));
    try std.testing.expectEqual(@as(u8, 10), getStationSlotCount(.crafting_3x3));
    try std.testing.expectEqual(@as(u8, 3), getStationSlotCount(.furnace));
    try std.testing.expectEqual(@as(u8, 3), getStationSlotCount(.anvil));
    try std.testing.expectEqual(@as(u8, 2), getStationSlotCount(.stonecutter));
    try std.testing.expectEqual(@as(u8, 5), getStationSlotCount(.brewing));
}

test "titles are non-empty for active modes" {
    try std.testing.expectEqualStrings("", getStationTitle(.none));
    try std.testing.expectEqualStrings("Crafting Table", getStationTitle(.crafting_3x3));
    try std.testing.expectEqualStrings("Furnace", getStationTitle(.furnace));
    try std.testing.expectEqualStrings("Brewing Stand", getStationTitle(.brewing));
}

test "station state open and close" {
    var state = StationState{};
    try std.testing.expect(!state.isOpen());

    state.open(.furnace, 10, 20, 30);
    try std.testing.expect(state.isOpen());
    try std.testing.expectEqual(StationMode.furnace, state.mode);
    try std.testing.expectEqual(@as(i32, 10), state.pos.x);

    state.close();
    try std.testing.expect(!state.isOpen());
}

test "slot layout returns null for out-of-range index" {
    try std.testing.expect(getStationSlotLayout(.crafting_3x3, 10, 800, 600) == null);
    try std.testing.expect(getStationSlotLayout(.crafting_3x3, 255, 800, 600) == null);
    try std.testing.expect(getStationSlotLayout(.none, 0, 800, 600) == null);
}

test "crafting 3x3 layout has 10 valid slots" {
    var count: u8 = 0;
    var idx: u8 = 0;
    while (idx < 12) : (idx += 1) {
        if (getStationSlotLayout(.crafting_3x3, idx, 800, 600)) |_| {
            count += 1;
        }
    }
    try std.testing.expectEqual(@as(u8, 10), count);
}

test "crafting 3x3 output slot is to the right of grid" {
    const grid_last = getStationSlotLayout(.crafting_3x3, 8, 800, 600).?;
    const output = getStationSlotLayout(.crafting_3x3, 9, 800, 600).?;
    try std.testing.expect(output.x > grid_last.x);
    try std.testing.expectEqual(SlotType.output, output.slot_type);
}

test "furnace slot types" {
    const input = getStationSlotLayout(.furnace, 0, 800, 600).?;
    const fuel = getStationSlotLayout(.furnace, 1, 800, 600).?;
    const output = getStationSlotLayout(.furnace, 2, 800, 600).?;
    try std.testing.expectEqual(SlotType.input, input.slot_type);
    try std.testing.expectEqual(SlotType.fuel, fuel.slot_type);
    try std.testing.expectEqual(SlotType.output, output.slot_type);
}

test "bounds are centered on screen" {
    const sw: f32 = 1920.0;
    const sh: f32 = 1080.0;
    const b = getStationBounds(.crafting_3x3, sw, sh);
    const cx = b.x + b.w / 2.0;
    const cy = b.y + b.h / 2.0;
    try std.testing.expectApproxEqAbs(sw / 2.0, cx, 0.01);
    try std.testing.expectApproxEqAbs(sh / 2.0, cy, 0.01);
}

test "bounds width and height are positive for all active modes" {
    const modes = [_]StationMode{ .crafting_3x3, .furnace, .anvil, .stonecutter, .grindstone, .loom, .cartography, .smithing, .brewing };
    for (modes) |m| {
        const b = getStationBounds(m, 800, 600);
        try std.testing.expect(b.w > 0);
        try std.testing.expect(b.h > 0);
    }
}

test "all slots within bounds" {
    const modes = [_]StationMode{ .crafting_3x3, .furnace, .anvil, .stonecutter, .grindstone, .loom, .cartography, .smithing, .brewing };
    for (modes) |m| {
        const b = getStationBounds(m, 800, 600);
        var idx: u8 = 0;
        while (idx < getStationSlotCount(m)) : (idx += 1) {
            const s = getStationSlotLayout(m, idx, 800, 600).?;
            try std.testing.expect(s.x >= b.x);
            try std.testing.expect(s.y >= b.y);
            try std.testing.expect(s.x + s.w <= b.x + b.w);
            try std.testing.expect(s.y + s.h <= b.y + b.h);
        }
    }
}
