/// Loom station UI for applying banner patterns.
/// Manages banner, dye, and output slots, pattern selection, scrolling,
/// and the item encoding scheme for banners and dyes.

const std = @import("std");
const inventory_mod = @import("inventory.zig");

pub const Slot = inventory_mod.Slot;

// ── Item encoding ───────────────────────────────────────────────────────
// Base banners:    600 + @intFromEnum(DyeColor)  → 600..615
// Decorated:       620 + @intFromEnum(DyeColor)  → 620..635 (pattern metadata stored externally)
// Dyes:            700 + @intFromEnum(DyeColor)  → 700..715

pub const BANNER_BASE: u16 = 600;
pub const BANNER_DECORATED: u16 = 620;
pub const DYE_BASE: u16 = 700;

pub fn isBanner(item: u16) bool {
    return (item >= BANNER_BASE and item < BANNER_BASE + 16) or
        (item >= BANNER_DECORATED and item < BANNER_DECORATED + 16);
}

pub fn isDye(item: u16) bool {
    return item >= DYE_BASE and item < DYE_BASE + 16;
}

pub fn getBannerColor(item: u16) ?DyeColor {
    if (item >= BANNER_BASE and item < BANNER_BASE + 16) {
        return @enumFromInt(@as(u4, @intCast(item - BANNER_BASE)));
    }
    if (item >= BANNER_DECORATED and item < BANNER_DECORATED + 16) {
        return @enumFromInt(@as(u4, @intCast(item - BANNER_DECORATED)));
    }
    return null;
}

pub fn getDyeColor(item: u16) ?DyeColor {
    if (!isDye(item)) return null;
    return @enumFromInt(@as(u4, @intCast(item - DYE_BASE)));
}

fn makeDecoratedBanner(color: DyeColor) u16 {
    return BANNER_DECORATED + @as(u16, @intFromEnum(color));
}

// ── Enums ───────────────────────────────────────────────────────────────

pub const BannerPattern = enum(u8) {
    stripe_bottom,
    stripe_top,
    stripe_left,
    stripe_right,
    stripe_center,
    stripe_middle,
    stripe_downright,
    stripe_downleft,
    cross,
    straight_cross,
    diagonal_left,
    diagonal_right,
    half_top,
    half_bottom,
    half_left,
    half_right,
    triangle_bottom,
    triangle_top,
    circle,
    rhombus,
};

pub const DyeColor = enum(u4) {
    white,
    orange,
    magenta,
    light_blue,
    yellow,
    lime,
    pink,
    gray,
    light_gray,
    cyan,
    purple,
    blue,
    brown,
    green,
    red,
    black,
};

const all_patterns: [std.meta.fields(BannerPattern).len]BannerPattern = blk: {
    const fields = std.meta.fields(BannerPattern);
    var vals: [fields.len]BannerPattern = undefined;
    for (fields, 0..) |f, i| {
        vals[i] = @enumFromInt(f.value);
    }
    break :blk vals;
};

// ── Loom UI ─────────────────────────────────────────────────────────────

pub const LoomUI = struct {
    banner_slot: Slot = Slot.empty,
    dye_slot: Slot = Slot.empty,
    output_slot: Slot = Slot.empty,
    selected_pattern: ?BannerPattern = null,
    scroll_offset: u8 = 0,

    pub fn init() LoomUI {
        return .{};
    }

    /// Swap the cursor item with the banner slot. Only accepts banner items.
    pub fn clickBannerSlot(self: *LoomUI, cursor: Slot) Slot {
        return self.swapInputSlot(&self.banner_slot, cursor, isBanner);
    }

    /// Swap the cursor item with the dye slot. Only accepts dye items.
    pub fn clickDyeSlot(self: *LoomUI, cursor: Slot) Slot {
        return self.swapInputSlot(&self.dye_slot, cursor, isDye);
    }

    /// Select a pattern and, if all inputs are present, produce the output.
    pub fn selectPattern(self: *LoomUI, pattern: BannerPattern) void {
        self.selected_pattern = pattern;
        self.updateOutput();
    }

    /// Take the output slot contents. Consumes 1 dye and 1 banner from
    /// the input slots. Returns null if no output is available.
    pub fn takeOutput(self: *LoomUI) ?Slot {
        if (self.output_slot.isEmpty()) return null;

        const result = self.output_slot;
        self.output_slot = Slot.empty;
        consumeOne(&self.banner_slot);
        consumeOne(&self.dye_slot);
        return result;
    }

    /// Return remaining banner and dye items to the player inventory, then reset.
    pub fn close(self: *LoomUI, inv_slots: []Slot) void {
        returnToInventory(&self.banner_slot, inv_slots);
        returnToInventory(&self.dye_slot, inv_slots);
        self.* = LoomUI.init();
    }

    /// All patterns available in the loom (no special banner pattern items needed).
    pub fn getAvailablePatterns() []const BannerPattern {
        return &all_patterns;
    }

    // ── internal ────────────────────────────────────────────────────────

    fn swapInputSlot(self: *LoomUI, slot: *Slot, cursor: Slot, validator: *const fn (u16) bool) Slot {
        if (!cursor.isEmpty() and !validator(cursor.item)) return cursor;
        const prev = slot.*;
        slot.* = cursor;
        self.output_slot = Slot.empty;
        return prev;
    }

    fn updateOutput(self: *LoomUI) void {
        self.output_slot = Slot.empty;

        if (self.banner_slot.isEmpty()) return;
        if (self.dye_slot.isEmpty()) return;
        if (self.selected_pattern == null) return;

        const banner_color = getBannerColor(self.banner_slot.item) orelse return;
        self.output_slot = Slot{ .item = makeDecoratedBanner(banner_color), .count = 1 };
    }
};

fn consumeOne(slot: *Slot) void {
    slot.count -= 1;
    if (slot.count == 0) {
        slot.* = Slot.empty;
    }
}

fn returnToInventory(slot: *Slot, inv_slots: []Slot) void {
    if (slot.isEmpty()) return;
    for (inv_slots) |*s| {
        if (s.isEmpty()) {
            s.* = slot.*;
            slot.* = Slot.empty;
            return;
        }
    }
}

// ── Tests ───────────────────────────────────────────────────────────────

test "init returns empty state" {
    const ui = LoomUI.init();
    try std.testing.expect(ui.banner_slot.isEmpty());
    try std.testing.expect(ui.dye_slot.isEmpty());
    try std.testing.expect(ui.output_slot.isEmpty());
    try std.testing.expectEqual(@as(?BannerPattern, null), ui.selected_pattern);
    try std.testing.expectEqual(@as(u8, 0), ui.scroll_offset);
}

test "clickBannerSlot accepts banner and returns previous" {
    var ui = LoomUI.init();
    const white_banner = Slot{ .item = BANNER_BASE + 0, .count = 1 };
    const prev = ui.clickBannerSlot(white_banner);
    try std.testing.expect(prev.isEmpty());
    try std.testing.expectEqual(white_banner.item, ui.banner_slot.item);
}

test "clickBannerSlot rejects non-banner item" {
    var ui = LoomUI.init();
    const stone = Slot{ .item = 1, .count = 1 };
    const returned = ui.clickBannerSlot(stone);
    try std.testing.expectEqual(@as(u16, 1), returned.item);
    try std.testing.expect(ui.banner_slot.isEmpty());
}

test "clickDyeSlot accepts dye and returns previous" {
    var ui = LoomUI.init();
    const red_dye = Slot{ .item = DYE_BASE + 14, .count = 3 };
    const prev = ui.clickDyeSlot(red_dye);
    try std.testing.expect(prev.isEmpty());
    try std.testing.expectEqual(red_dye.item, ui.dye_slot.item);
    try std.testing.expectEqual(@as(u8, 3), ui.dye_slot.count);
}

test "clickDyeSlot rejects non-dye item" {
    var ui = LoomUI.init();
    const stone = Slot{ .item = 1, .count = 1 };
    const returned = ui.clickDyeSlot(stone);
    try std.testing.expectEqual(@as(u16, 1), returned.item);
    try std.testing.expect(ui.dye_slot.isEmpty());
}

test "selectPattern produces output when both inputs present" {
    var ui = LoomUI.init();
    _ = ui.clickBannerSlot(Slot{ .item = BANNER_BASE + 0, .count = 1 });
    _ = ui.clickDyeSlot(Slot{ .item = DYE_BASE + 14, .count = 1 });
    ui.selectPattern(.cross);
    try std.testing.expect(!ui.output_slot.isEmpty());
    try std.testing.expectEqual(BANNER_DECORATED + 0, ui.output_slot.item);
}

test "selectPattern does nothing without dye" {
    var ui = LoomUI.init();
    _ = ui.clickBannerSlot(Slot{ .item = BANNER_BASE + 0, .count = 1 });
    ui.selectPattern(.cross);
    try std.testing.expect(ui.output_slot.isEmpty());
}

test "takeOutput consumes one banner and one dye" {
    var ui = LoomUI.init();
    _ = ui.clickBannerSlot(Slot{ .item = BANNER_BASE + 5, .count = 3 });
    _ = ui.clickDyeSlot(Slot{ .item = DYE_BASE + 0, .count = 2 });
    ui.selectPattern(.stripe_top);

    const result = ui.takeOutput();
    try std.testing.expect(result != null);
    try std.testing.expectEqual(BANNER_DECORATED + 5, result.?.item);
    try std.testing.expectEqual(@as(u8, 1), result.?.count);
    try std.testing.expectEqual(@as(u8, 2), ui.banner_slot.count);
    try std.testing.expectEqual(@as(u8, 1), ui.dye_slot.count);
}

test "takeOutput returns null when output empty" {
    var ui = LoomUI.init();
    try std.testing.expect(ui.takeOutput() == null);
}

test "takeOutput clears slots when last item consumed" {
    var ui = LoomUI.init();
    _ = ui.clickBannerSlot(Slot{ .item = BANNER_BASE + 0, .count = 1 });
    _ = ui.clickDyeSlot(Slot{ .item = DYE_BASE + 0, .count = 1 });
    ui.selectPattern(.rhombus);

    _ = ui.takeOutput();
    try std.testing.expect(ui.banner_slot.isEmpty());
    try std.testing.expect(ui.dye_slot.isEmpty());
}

test "close returns items to inventory" {
    var ui = LoomUI.init();
    _ = ui.clickBannerSlot(Slot{ .item = BANNER_BASE + 15, .count = 2 });
    _ = ui.clickDyeSlot(Slot{ .item = DYE_BASE + 3, .count = 5 });

    var inv = [_]Slot{ Slot.empty, Slot.empty, Slot.empty };
    ui.close(&inv);

    try std.testing.expectEqual(BANNER_BASE + 15, inv[0].item);
    try std.testing.expectEqual(@as(u8, 2), inv[0].count);
    try std.testing.expectEqual(DYE_BASE + 3, inv[1].item);
    try std.testing.expectEqual(@as(u8, 5), inv[1].count);
    try std.testing.expect(ui.banner_slot.isEmpty());
    try std.testing.expect(ui.dye_slot.isEmpty());
}

test "isBanner recognizes base and decorated banners" {
    try std.testing.expect(isBanner(BANNER_BASE + 0));
    try std.testing.expect(isBanner(BANNER_BASE + 15));
    try std.testing.expect(isBanner(BANNER_DECORATED + 7));
    try std.testing.expect(!isBanner(0));
    try std.testing.expect(!isBanner(DYE_BASE + 5));
}

test "isDye recognizes dye items" {
    try std.testing.expect(isDye(DYE_BASE + 0));
    try std.testing.expect(isDye(DYE_BASE + 15));
    try std.testing.expect(!isDye(BANNER_BASE + 0));
    try std.testing.expect(!isDye(0));
}

test "getBannerColor extracts color from base and decorated" {
    try std.testing.expectEqual(DyeColor.white, getBannerColor(BANNER_BASE + 0).?);
    try std.testing.expectEqual(DyeColor.black, getBannerColor(BANNER_BASE + 15).?);
    try std.testing.expectEqual(DyeColor.red, getBannerColor(BANNER_DECORATED + 14).?);
    try std.testing.expect(getBannerColor(0) == null);
}

test "getAvailablePatterns returns all 20 patterns" {
    const patterns = LoomUI.getAvailablePatterns();
    try std.testing.expectEqual(@as(usize, 20), patterns.len);
    try std.testing.expectEqual(BannerPattern.stripe_bottom, patterns[0]);
    try std.testing.expectEqual(BannerPattern.rhombus, patterns[19]);
}

test "clickBannerSlot accepts decorated banner" {
    var ui = LoomUI.init();
    const decorated = Slot{ .item = BANNER_DECORATED + 3, .count = 1 };
    const prev = ui.clickBannerSlot(decorated);
    try std.testing.expect(prev.isEmpty());
    try std.testing.expectEqual(BANNER_DECORATED + 3, ui.banner_slot.item);
}

test "clickBannerSlot clears output on swap" {
    var ui = LoomUI.init();
    _ = ui.clickBannerSlot(Slot{ .item = BANNER_BASE + 0, .count = 1 });
    _ = ui.clickDyeSlot(Slot{ .item = DYE_BASE + 0, .count = 1 });
    ui.selectPattern(.cross);
    try std.testing.expect(!ui.output_slot.isEmpty());

    // Swap banner — output must be cleared
    _ = ui.clickBannerSlot(Slot{ .item = BANNER_BASE + 1, .count = 1 });
    try std.testing.expect(ui.output_slot.isEmpty());
}
