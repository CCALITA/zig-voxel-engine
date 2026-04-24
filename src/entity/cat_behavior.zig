/// Cat entity behavior: variant selection, taming, sitting, creeper scaring,
/// and gift-giving when a player wakes from sleep.
/// Cats have 11 variants matching vanilla Minecraft, scare creepers within
/// 6 blocks, and deliver a morning gift with a 70 % probability.
const std = @import("std");

// ---------------------------------------------------------------------------
// Variants
// ---------------------------------------------------------------------------

pub const CatVariant = enum(u4) {
    tabby,
    tuxedo,
    red,
    siamese,
    british,
    calico,
    persian,
    ragdoll,
    white,
    jellie,
    black,
};

// ---------------------------------------------------------------------------
// Gift item IDs
// ---------------------------------------------------------------------------

pub const ITEM_STRING: u16 = 287;
pub const ITEM_FEATHER: u16 = 207;
pub const ITEM_RAW_CHICKEN: u16 = 206;
pub const ITEM_RABBIT_HIDE: u16 = 415;

const gift_items = [_]u16{
    ITEM_STRING,
    ITEM_FEATHER,
    ITEM_RAW_CHICKEN,
    ITEM_RABBIT_HIDE,
};

// ---------------------------------------------------------------------------
// Cat
// ---------------------------------------------------------------------------

pub const Cat = struct {
    variant: CatVariant = .tabby,
    is_tamed: bool = false,
    is_sitting: bool = false,
    owner_id: u32 = 0,

    // -- Constants --
    const creeper_flee_range: f32 = 6.0;
    const gift_chance_percent: u32 = 70;

    /// Tame this cat, assigning it to `owner`.
    pub fn tame(self: *Cat, owner: u32) void {
        self.is_tamed = true;
        self.owner_id = owner;
    }

    /// Toggle the sitting state of a tamed cat.  Untamed cats ignore the call.
    pub fn toggleSit(self: *Cat) void {
        if (!self.is_tamed) return;
        self.is_sitting = !self.is_sitting;
    }

    /// Returns `true` when the creeper is within 6 blocks of the cat
    /// (Euclidean distance on the XZ plane), meaning the creeper should flee.
    pub fn scareCreeper(cat_x: f32, cat_z: f32, creeper_x: f32, creeper_z: f32) bool {
        const dx = cat_x - creeper_x;
        const dz = cat_z - creeper_z;
        return @sqrt(dx * dx + dz * dz) <= creeper_flee_range;
    }

    /// Determines whether the cat should produce a gift when the player wakes.
    /// Uses a simple modular hash of `rng` to decide (70 % chance).
    pub fn shouldGiftItem(rng: u32) bool {
        return (rng % 100) < gift_chance_percent;
    }

    /// Selects a random gift item from the gift table.
    pub fn getGiftItem(rng: u32) u16 {
        return gift_items[rng % gift_items.len];
    }
};

// ===========================================================================
// Tests
// ===========================================================================

test "default cat is untamed tabby" {
    const cat = Cat{};
    try std.testing.expectEqual(CatVariant.tabby, cat.variant);
    try std.testing.expectEqual(false, cat.is_tamed);
    try std.testing.expectEqual(false, cat.is_sitting);
    try std.testing.expectEqual(@as(u32, 0), cat.owner_id);
}

test "tame assigns owner and sets tamed flag" {
    var cat = Cat{};
    cat.tame(42);
    try std.testing.expectEqual(true, cat.is_tamed);
    try std.testing.expectEqual(@as(u32, 42), cat.owner_id);
}

test "toggleSit flips sitting for tamed cat" {
    var cat = Cat{};
    cat.tame(1);
    try std.testing.expectEqual(false, cat.is_sitting);
    cat.toggleSit();
    try std.testing.expectEqual(true, cat.is_sitting);
    cat.toggleSit();
    try std.testing.expectEqual(false, cat.is_sitting);
}

test "toggleSit is no-op for untamed cat" {
    var cat = Cat{};
    cat.toggleSit();
    try std.testing.expectEqual(false, cat.is_sitting);
}

test "scareCreeper returns true within 6 blocks" {
    try std.testing.expectEqual(true, Cat.scareCreeper(0.0, 0.0, 3.0, 4.0)); // dist = 5
    try std.testing.expectEqual(true, Cat.scareCreeper(0.0, 0.0, 0.0, 6.0)); // dist = 6
}

test "scareCreeper returns false beyond 6 blocks" {
    try std.testing.expectEqual(false, Cat.scareCreeper(0.0, 0.0, 0.0, 6.1)); // > 6
    try std.testing.expectEqual(false, Cat.scareCreeper(0.0, 0.0, 10.0, 10.0));
}

test "scareCreeper at zero distance" {
    try std.testing.expectEqual(true, Cat.scareCreeper(5.0, 5.0, 5.0, 5.0));
}

test "shouldGiftItem 70 percent chance" {
    var gifts: u32 = 0;
    for (0..100) |i| {
        if (Cat.shouldGiftItem(@intCast(i))) gifts += 1;
    }
    try std.testing.expectEqual(@as(u32, 70), gifts);
}

test "getGiftItem returns valid items" {
    for (0..4) |i| {
        const item = Cat.getGiftItem(@intCast(i));
        const valid = item == ITEM_STRING or
            item == ITEM_FEATHER or
            item == ITEM_RAW_CHICKEN or
            item == ITEM_RABBIT_HIDE;
        try std.testing.expect(valid);
    }
}

test "getGiftItem covers all items" {
    // With modulo 4, inputs 0-3 map to each item exactly once.
    try std.testing.expectEqual(ITEM_STRING, Cat.getGiftItem(0));
    try std.testing.expectEqual(ITEM_FEATHER, Cat.getGiftItem(1));
    try std.testing.expectEqual(ITEM_RAW_CHICKEN, Cat.getGiftItem(2));
    try std.testing.expectEqual(ITEM_RABBIT_HIDE, Cat.getGiftItem(3));
}

test "cat variant enum values" {
    try std.testing.expectEqual(@as(u4, 0), @intFromEnum(CatVariant.tabby));
    try std.testing.expectEqual(@as(u4, 10), @intFromEnum(CatVariant.black));
}

test "tame preserves variant" {
    var cat = Cat{ .variant = .siamese };
    cat.tame(99);
    try std.testing.expectEqual(CatVariant.siamese, cat.variant);
    try std.testing.expectEqual(true, cat.is_tamed);
}
