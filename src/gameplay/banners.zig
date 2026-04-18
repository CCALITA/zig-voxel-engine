/// Banner and shield system.
/// Manages banner patterns, colors, layered designs, and shield blocking.

const std = @import("std");

// ──────────────────────────────────────────────────────────────────────────────
// Enums
// ──────────────────────────────────────────────────────────────────────────────

pub const BannerColor = enum(u4) {
    white = 0,
    orange = 1,
    magenta = 2,
    light_blue = 3,
    yellow = 4,
    lime = 5,
    pink = 6,
    gray = 7,
    light_gray = 8,
    cyan = 9,
    purple = 10,
    blue = 11,
    brown = 12,
    green = 13,
    red = 14,
    black = 15,
};

pub const BannerPattern = enum {
    stripe_bottom,
    stripe_top,
    stripe_left,
    stripe_right,
    stripe_center,
    stripe_middle,
    stripe_downright,
    stripe_downleft,
    stripe_small,
    cross,
    straight_cross,
    triangle_bottom,
    triangle_top,
    triangles_bottom,
    triangles_top,
    diagonal_left,
    diagonal_right,
    diagonal_up_left,
    diagonal_up_right,
    half_vertical,
    half_horizontal,
    half_vertical_mirror,
    half_horizontal_mirror,
    border,
    curly_border,
    creeper,
    skull,
    flower,
    mojang,
    globe,
    piglin,
    gradient,
    gradient_up,
    bricks,
    rhombus,
    circle,
    square_bottom_left,
    square_bottom_right,
    square_top_left,
    square_top_right,
    thing,
};

// ──────────────────────────────────────────────────────────────────────────────
// Pattern layer & banner state
// ──────────────────────────────────────────────────────────────────────────────

pub const PatternLayer = struct {
    pattern: BannerPattern,
    color: BannerColor,
};

pub const MAX_LAYERS = 6;

pub const BannerState = struct {
    base_color: BannerColor,
    layers: [MAX_LAYERS]?PatternLayer,

    pub fn init(base_color: BannerColor) BannerState {
        return .{
            .base_color = base_color,
            .layers = [_]?PatternLayer{null} ** MAX_LAYERS,
        };
    }

    /// Add a pattern layer. Returns true on success, false if the banner
    /// already has the maximum number of layers.
    pub fn addLayer(self: *BannerState, layer: PatternLayer) bool {
        for (&self.layers) |*slot| {
            if (slot.* == null) {
                slot.* = layer;
                return true;
            }
        }
        return false;
    }

    /// Remove the topmost (last) pattern layer. Returns the removed layer,
    /// or null if no layers are present.
    pub fn removeLayer(self: *BannerState) ?PatternLayer {
        var last_idx: ?usize = null;
        for (self.layers, 0..) |maybe, i| {
            if (maybe != null) {
                last_idx = i;
            }
        }
        if (last_idx) |idx| {
            const removed = self.layers[idx];
            self.layers[idx] = null;
            return removed;
        }
        return null;
    }

    /// Number of currently applied pattern layers.
    pub fn layerCount(self: *const BannerState) u32 {
        var count: u32 = 0;
        for (self.layers) |maybe| {
            if (maybe != null) count += 1;
        }
        return count;
    }
};

// ──────────────────────────────────────────────────────────────────────────────
// Shield state
// ──────────────────────────────────────────────────────────────────────────────

const SHIELD_COOLDOWN_SECONDS: f32 = 5.0;

pub const ShieldState = struct {
    active: bool,
    cooldown: f32,
    banner: ?BannerState,

    pub fn init() ShieldState {
        return .{
            .active = false,
            .cooldown = 0.0,
            .banner = null,
        };
    }

    pub fn initWithBanner(banner: BannerState) ShieldState {
        return .{
            .active = false,
            .cooldown = 0.0,
            .banner = banner,
        };
    }

    /// Raise the shield. Only succeeds when cooldown has expired.
    pub fn activate(self: *ShieldState) void {
        if (self.cooldown <= 0.0) {
            self.active = true;
        }
    }

    /// Lower the shield and start the cooldown timer.
    pub fn deactivate(self: *ShieldState) void {
        if (self.active) {
            self.active = false;
            self.cooldown = SHIELD_COOLDOWN_SECONDS;
        }
    }

    /// Tick the cooldown timer.
    pub fn update(self: *ShieldState, dt: f32) void {
        if (self.cooldown > 0.0) {
            self.cooldown -= dt;
            if (self.cooldown < 0.0) {
                self.cooldown = 0.0;
            }
        }
    }

    /// Whether the shield is currently blocking damage.
    pub fn canBlock(self: *const ShieldState) bool {
        return self.active;
    }

    /// Fraction of incoming damage absorbed (1.0 when blocking, 0.0 otherwise).
    pub fn getDamageReduction(self: *const ShieldState) f32 {
        return if (self.active) 1.0 else 0.0;
    }
};

// ──────────────────────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────────────────────

test "BannerState.init creates empty banner" {
    const banner = BannerState.init(.white);
    try std.testing.expectEqual(BannerColor.white, banner.base_color);
    try std.testing.expectEqual(@as(u32, 0), banner.layerCount());
}

test "addLayer stores a pattern" {
    var banner = BannerState.init(.red);
    const ok = banner.addLayer(.{ .pattern = .cross, .color = .blue });
    try std.testing.expect(ok);
    try std.testing.expectEqual(@as(u32, 1), banner.layerCount());
}

test "addLayer fills up to max layers" {
    var banner = BannerState.init(.black);
    var i: u32 = 0;
    while (i < MAX_LAYERS) : (i += 1) {
        try std.testing.expect(banner.addLayer(.{ .pattern = .bricks, .color = .white }));
    }
    try std.testing.expectEqual(@as(u32, MAX_LAYERS), banner.layerCount());
    // One more should fail
    try std.testing.expect(!banner.addLayer(.{ .pattern = .creeper, .color = .green }));
}

test "removeLayer removes the topmost layer" {
    var banner = BannerState.init(.blue);
    _ = banner.addLayer(.{ .pattern = .stripe_top, .color = .white });
    _ = banner.addLayer(.{ .pattern = .skull, .color = .black });

    const removed = banner.removeLayer();
    try std.testing.expect(removed != null);
    try std.testing.expectEqual(BannerPattern.skull, removed.?.pattern);
    try std.testing.expectEqual(BannerColor.black, removed.?.color);
    try std.testing.expectEqual(@as(u32, 1), banner.layerCount());
}

test "removeLayer on empty banner returns null" {
    var banner = BannerState.init(.white);
    try std.testing.expect(banner.removeLayer() == null);
}

test "layerCount reflects additions and removals" {
    var banner = BannerState.init(.yellow);
    try std.testing.expectEqual(@as(u32, 0), banner.layerCount());

    _ = banner.addLayer(.{ .pattern = .flower, .color = .pink });
    _ = banner.addLayer(.{ .pattern = .mojang, .color = .red });
    try std.testing.expectEqual(@as(u32, 2), banner.layerCount());

    _ = banner.removeLayer();
    try std.testing.expectEqual(@as(u32, 1), banner.layerCount());
}

test "ShieldState.init creates inactive shield" {
    const shield = ShieldState.init();
    try std.testing.expect(!shield.active);
    try std.testing.expect(!shield.canBlock());
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), shield.cooldown, 0.001);
    try std.testing.expect(shield.banner == null);
}

test "shield activate and deactivate" {
    var shield = ShieldState.init();
    shield.activate();
    try std.testing.expect(shield.active);
    try std.testing.expect(shield.canBlock());

    shield.deactivate();
    try std.testing.expect(!shield.active);
    try std.testing.expect(!shield.canBlock());
}

test "shield getDamageReduction when active" {
    var shield = ShieldState.init();
    shield.activate();
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), shield.getDamageReduction(), 0.001);
}

test "shield getDamageReduction when inactive" {
    const shield = ShieldState.init();
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), shield.getDamageReduction(), 0.001);
}

test "shield cooldown prevents activation" {
    var shield = ShieldState.init();
    shield.activate();
    shield.deactivate();

    // Cooldown is active; activate should be a no-op
    shield.activate();
    try std.testing.expect(!shield.active);
}

test "shield cooldown ticks down" {
    var shield = ShieldState.init();
    shield.activate();
    shield.deactivate();

    try std.testing.expect(shield.cooldown > 0.0);
    shield.update(3.0);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), shield.cooldown, 0.001);
}

test "shield can reactivate after cooldown expires" {
    var shield = ShieldState.init();
    shield.activate();
    shield.deactivate();

    // Tick past the full cooldown
    shield.update(6.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), shield.cooldown, 0.001);

    shield.activate();
    try std.testing.expect(shield.active);
    try std.testing.expect(shield.canBlock());
}

test "shield with banner" {
    var banner = BannerState.init(.red);
    _ = banner.addLayer(.{ .pattern = .creeper, .color = .green });

    const shield = ShieldState.initWithBanner(banner);
    try std.testing.expect(shield.banner != null);
    try std.testing.expectEqual(BannerColor.red, shield.banner.?.base_color);
    try std.testing.expectEqual(@as(u32, 1), shield.banner.?.layerCount());
}

test "deactivate on inactive shield is no-op" {
    var shield = ShieldState.init();
    shield.deactivate();
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), shield.cooldown, 0.001);
    try std.testing.expect(!shield.active);
}

test "update with zero cooldown is no-op" {
    var shield = ShieldState.init();
    shield.update(1.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), shield.cooldown, 0.001);
}

test "BannerColor has 16 variants" {
    const fields = std.meta.fields(BannerColor);
    try std.testing.expectEqual(@as(usize, 16), fields.len);
}

test "BannerPattern has at least 34 variants" {
    const fields = std.meta.fields(BannerPattern);
    try std.testing.expect(fields.len >= 34);
}
