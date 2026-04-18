/// Brewing stand system: converts water bottles + ingredients into potions.
/// Brewing takes a fixed duration and consumes blaze powder as fuel.

const std = @import("std");

pub const BREW_DURATION: f32 = 20.0; // seconds to brew one batch
pub const FUEL_PER_BREW: u8 = 1;

pub const BrewingState = struct {
    fuel: u8,
    ingredient: u16, // 0 = empty
    progress: f32, // 0.0 .. BREW_DURATION
    active: bool,

    pub fn init() BrewingState {
        return .{
            .fuel = 0,
            .ingredient = 0,
            .progress = 0.0,
            .active = false,
        };
    }

    /// Add blaze powder fuel. Returns the amount actually added.
    pub fn addFuel(self: *BrewingState, amount: u8) u8 {
        const max_fuel: u8 = 20;
        const space = max_fuel - self.fuel;
        const added = @min(amount, space);
        self.fuel += added;
        return added;
    }

    /// Set the ingredient for brewing. Returns false if already occupied.
    pub fn setIngredient(self: *BrewingState, item_id: u16) bool {
        if (self.ingredient != 0) return false;
        self.ingredient = item_id;
        return true;
    }

    /// Start brewing if fuel and ingredient are present.
    pub fn startBrewing(self: *BrewingState) bool {
        if (self.active) return false;
        if (self.fuel < FUEL_PER_BREW or self.ingredient == 0) return false;
        self.fuel -= FUEL_PER_BREW;
        self.active = true;
        self.progress = 0.0;
        return true;
    }

    /// Tick the brewing process. Returns true when brewing completes.
    pub fn update(self: *BrewingState, dt: f32) bool {
        if (!self.active) return false;
        self.progress += dt;
        if (self.progress >= BREW_DURATION) {
            self.active = false;
            self.progress = 0.0;
            self.ingredient = 0;
            return true;
        }
        return false;
    }
};

// ──────────────────────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────────────────────

test "init creates idle state" {
    const bs = BrewingState.init();
    try std.testing.expect(!bs.active);
    try std.testing.expectEqual(@as(u8, 0), bs.fuel);
    try std.testing.expectEqual(@as(u16, 0), bs.ingredient);
}

test "addFuel caps at 20" {
    var bs = BrewingState.init();
    _ = bs.addFuel(15);
    const added = bs.addFuel(10);
    try std.testing.expectEqual(@as(u8, 5), added);
    try std.testing.expectEqual(@as(u8, 20), bs.fuel);
}

test "startBrewing requires fuel and ingredient" {
    var bs = BrewingState.init();
    try std.testing.expect(!bs.startBrewing()); // no fuel or ingredient
    _ = bs.addFuel(1);
    try std.testing.expect(!bs.startBrewing()); // no ingredient
    _ = bs.setIngredient(5);
    try std.testing.expect(bs.startBrewing());
    try std.testing.expect(bs.active);
}

test "update completes after BREW_DURATION" {
    var bs = BrewingState.init();
    _ = bs.addFuel(1);
    _ = bs.setIngredient(3);
    _ = bs.startBrewing();

    // Not done yet
    try std.testing.expect(!bs.update(10.0));
    // Now done
    try std.testing.expect(bs.update(11.0));
    try std.testing.expect(!bs.active);
}

test "setIngredient rejects when occupied" {
    var bs = BrewingState.init();
    try std.testing.expect(bs.setIngredient(5));
    try std.testing.expect(!bs.setIngredient(6));
}
