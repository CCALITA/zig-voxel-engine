/// Advancement / progression tracking system.
/// Tracks tree-structured advancements with prerequisites and criteria.
const std = @import("std");

pub const AdvancementCategory = enum {
    story,
    adventure,
    husbandry,
    nether,
    the_end,
};

pub const AdvancementId = enum(u8) {
    // Story
    mine_stone = 0,
    upgrade_tools = 1,
    acquire_hardware = 2,
    suit_up = 3,
    hot_stuff = 4,
    isnt_it_iron_pick = 5,
    diamonds = 6,
    ice_bucket_challenge = 7,

    // Adventure
    voluntary_exile = 8,
    kill_a_mob = 9,
    trade = 10,
    sleep_in_bed = 11,

    // Husbandry
    plant_seed = 12,
    breed_animal = 13,
    fishy_business = 14,
    balanced_diet = 15,

    // Nether
    enter_nether = 16,
    find_fortress = 17,
    brew_potion = 18,
    summon_wither = 19,

    // The End
    enter_end = 20,
    kill_dragon = 21,
    find_end_city = 22,
    find_elytra = 23,
};

pub const Advancement = struct {
    id: AdvancementId,
    name: []const u8,
    description: []const u8,
    category: AdvancementCategory,
    parent: ?AdvancementId,
};

pub const AdvancementState = struct {
    unlocked: [24]bool,

    pub fn init() AdvancementState {
        return .{
            .unlocked = [_]bool{false} ** 24,
        };
    }

    pub fn unlock(self: *AdvancementState, id: AdvancementId) bool {
        const idx = @intFromEnum(id);
        if (self.unlocked[idx]) return false;
        self.unlocked[idx] = true;
        return true;
    }

    pub fn isUnlocked(self: *const AdvancementState, id: AdvancementId) bool {
        return self.unlocked[@intFromEnum(id)];
    }

    pub fn countUnlocked(self: *const AdvancementState) u32 {
        var count: u32 = 0;
        for (self.unlocked) |u| {
            if (u) count += 1;
        }
        return count;
    }
};

test "advancement state init" {
    const state = AdvancementState.init();
    try std.testing.expectEqual(@as(u32, 0), state.countUnlocked());
}

test "unlock advancement" {
    var state = AdvancementState.init();
    try std.testing.expect(state.unlock(.mine_stone));
    try std.testing.expect(state.isUnlocked(.mine_stone));
    try std.testing.expectEqual(@as(u32, 1), state.countUnlocked());
}

test "double unlock returns false" {
    var state = AdvancementState.init();
    try std.testing.expect(state.unlock(.diamonds));
    try std.testing.expect(!state.unlock(.diamonds));
}
