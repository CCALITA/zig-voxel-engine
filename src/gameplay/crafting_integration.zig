/// Crafting integration layer.
/// Bridges the recipe discovery system with gameplay events such as item
/// pickups, providing a thin, testable facade over `RecipeBook`.

const std = @import("std");
const rd = @import("recipe_discovery.zig");

/// Notify the recipe book that the player picked up an item.
/// Returns the number of newly discovered recipes.
pub fn onItemPickup(book: *rd.RecipeBook, item_id: u16) u16 {
    return book.discoverByItem(item_id);
}

/// Return the total number of recipes the player has discovered so far.
pub fn getDiscoveredCount(book: *const rd.RecipeBook) u16 {
    return book.getDiscoveredCount();
}

/// Check whether a specific recipe has been unlocked.
pub fn isRecipeUnlocked(book: *const rd.RecipeBook, recipe_id: u16) bool {
    return book.isDiscovered(recipe_id);
}

// ===========================================================================
// Tests
// ===========================================================================

test "onItemPickup discovers recipes for known item" {
    var book = rd.RecipeBook.init();
    // Stick (256) appears in tool recipes
    const count = onItemPickup(&book, 256);
    try std.testing.expect(count > 0);
}

test "onItemPickup returns zero for unknown item" {
    var book = rd.RecipeBook.init();
    const count = onItemPickup(&book, 9999);
    try std.testing.expectEqual(@as(u16, 0), count);
}

test "onItemPickup does not double-count on repeated pickup" {
    var book = rd.RecipeBook.init();
    const first = onItemPickup(&book, 256);
    const second = onItemPickup(&book, 256);
    try std.testing.expect(first > 0);
    try std.testing.expectEqual(@as(u16, 0), second);
}

test "getDiscoveredCount starts at zero" {
    const book = rd.RecipeBook.init();
    try std.testing.expectEqual(@as(u16, 0), getDiscoveredCount(&book));
}

test "getDiscoveredCount reflects pickups" {
    var book = rd.RecipeBook.init();
    _ = onItemPickup(&book, 256);
    try std.testing.expect(getDiscoveredCount(&book) > 0);
}

test "isRecipeUnlocked returns false before discovery" {
    const book = rd.RecipeBook.init();
    try std.testing.expect(!isRecipeUnlocked(&book, 0));
}

test "isRecipeUnlocked returns true after discovery" {
    var book = rd.RecipeBook.init();
    _ = book.discover(0);
    try std.testing.expect(isRecipeUnlocked(&book, 0));
}

test "isRecipeUnlocked rejects out-of-range id" {
    const book = rd.RecipeBook.init();
    try std.testing.expect(!isRecipeUnlocked(&book, rd.MAX_RECIPES));
    try std.testing.expect(!isRecipeUnlocked(&book, rd.MAX_RECIPES + 1));
}

test "onItemPickup updates discovered count correctly" {
    var book = rd.RecipeBook.init();
    const before = getDiscoveredCount(&book);
    const newly = onItemPickup(&book, 256);
    const after = getDiscoveredCount(&book);
    try std.testing.expectEqual(before + newly, after);
}

test "multiple different pickups accumulate discoveries" {
    var book = rd.RecipeBook.init();
    _ = onItemPickup(&book, 256);
    const count_after_first = getDiscoveredCount(&book);
    // Pick up a different item (iron ingot = 265 used in armor recipes)
    const second = onItemPickup(&book, 265);
    const count_after_second = getDiscoveredCount(&book);
    try std.testing.expectEqual(count_after_first + second, count_after_second);
}

test "isRecipeUnlocked consistent with onItemPickup" {
    var book = rd.RecipeBook.init();
    // Before pickup, first tool recipe should be undiscovered
    try std.testing.expect(!isRecipeUnlocked(&book, rd.RECIPE_OFFSET_TOOLS));
    _ = onItemPickup(&book, 256);
    // After picking up stick, at least the first tool recipe should be unlocked
    try std.testing.expect(isRecipeUnlocked(&book, rd.RECIPE_OFFSET_TOOLS));
}

test "getDiscoveredCount after discoverAll" {
    var book = rd.RecipeBook.init();
    book.discoverAll();
    try std.testing.expectEqual(rd.MAX_RECIPES, getDiscoveredCount(&book));
    try std.testing.expect(isRecipeUnlocked(&book, 0));
    try std.testing.expect(isRecipeUnlocked(&book, rd.MAX_RECIPES - 1));
}

test "onItemPickup returns zero after discoverAll" {
    var book = rd.RecipeBook.init();
    book.discoverAll();
    const count = onItemPickup(&book, 256);
    try std.testing.expectEqual(@as(u16, 0), count);
}
