/// Advancement system organised into tabs (Minecraft, Nether, End, Adventure, Husbandry).
/// Each advancement has a criteria type that the game fires when the player performs an
/// action; the manager checks all advancements and unlocks those whose criteria and
/// parent prerequisites are satisfied.

const std = @import("std");

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

pub const AdvancementTab = enum(u8) {
    minecraft = 0,
    nether = 1,
    end = 2,
    adventure = 3,
    husbandry = 4,
};

pub const CriteriaType = enum(u8) {
    inventory_changed = 0,
    enter_dimension = 1,
    kill_entity = 2,
    breed_animal = 3,
    enter_biome = 4,
    mine_block = 5,
    craft_item = 6,
    smelt_item = 7,
    enchant_item = 8,
    brew_potion = 9,
    trade_villager = 10,
    tame_animal = 11,
    fish_item = 12,
    ride_entity = 13,
    eat_food = 14,
    sleep_in_bed = 15,
    nether_portal = 16,
    end_portal = 17,
    kill_dragon = 18,
    kill_wither = 19,
};

// ---------------------------------------------------------------------------
// Advancement definition
// ---------------------------------------------------------------------------

pub const Advancement = struct {
    id: u8,
    tab: AdvancementTab,
    name: [64]u8,
    name_len: u8,
    description: [128]u8,
    desc_len: u8,
    parent: ?u8,
    criteria_type: CriteriaType,
    criteria_param: u16,
    hidden: bool,

    pub fn getName(self: *const Advancement) []const u8 {
        return self.name[0..self.name_len];
    }

    pub fn getDescription(self: *const Advancement) []const u8 {
        return self.description[0..self.desc_len];
    }
};

// ---------------------------------------------------------------------------
// Compile-time helpers
// ---------------------------------------------------------------------------

fn copyBuf(comptime N: usize, comptime src: []const u8) [N]u8 {
    @setEvalBranchQuota(10_000);
    var buf: [N]u8 = [_]u8{0} ** N;
    for (src, 0..) |c, i| buf[i] = c;
    return buf;
}

fn makeAdv(
    id: u8,
    tab: AdvancementTab,
    comptime name: []const u8,
    comptime desc: []const u8,
    parent: ?u8,
    criteria_type: CriteriaType,
    criteria_param: u16,
    hidden: bool,
) Advancement {
    return .{
        .id = id,
        .tab = tab,
        .name = copyBuf(64, name),
        .name_len = @intCast(name.len),
        .description = copyBuf(128, desc),
        .desc_len = @intCast(desc.len),
        .parent = parent,
        .criteria_type = criteria_type,
        .criteria_param = criteria_param,
        .hidden = hidden,
    };
}

// ---------------------------------------------------------------------------
// Criteria-param constants (arbitrary but consistent ids)
// ---------------------------------------------------------------------------

const PARAM_ANY: u16 = 0;
const PARAM_OAK_LOG: u16 = 1;
const PARAM_CRAFTING_TABLE: u16 = 3;
const PARAM_WOODEN_PICKAXE: u16 = 4;
const PARAM_FURNACE: u16 = 6;
const PARAM_IRON_INGOT: u16 = 7;
const PARAM_DIAMOND: u16 = 8;
const PARAM_IRON_ARMOR: u16 = 9;
const PARAM_DIAMOND_ARMOR: u16 = 10;
const PARAM_ENCHANT_TABLE: u16 = 11;
const PARAM_BOOKSHELF: u16 = 12;
const PARAM_OBSIDIAN: u16 = 13;
const PARAM_NETHER: u16 = 14;
const PARAM_EYE_ENDER: u16 = 15;
const PARAM_END: u16 = 16;
const PARAM_BREWING_STAND: u16 = 17;
const PARAM_GHAST: u16 = 19;
const PARAM_WITHER_SKELETON: u16 = 20;
const PARAM_WITHER: u16 = 24;
const PARAM_BEACON: u16 = 25;
const PARAM_ENDERMAN: u16 = 26;
const PARAM_SHULKER: u16 = 27;
const PARAM_ELYTRA: u16 = 28;
const PARAM_DRAGON_EGG: u16 = 29;
const PARAM_END_CRYSTAL: u16 = 30;
const PARAM_ZOMBIE: u16 = 31;
const PARAM_SKELETON: u16 = 32;
const PARAM_SPIDER: u16 = 34;
const PARAM_WOLF: u16 = 39;
const PARAM_CAT: u16 = 40;
const PARAM_FISH_COD: u16 = 43;
const PARAM_WHEAT: u16 = 44;
const PARAM_BED: u16 = 50;
const PARAM_SHIELD: u16 = 51;
const PARAM_CROSSBOW: u16 = 53;
const PARAM_TRIDENT: u16 = 54;
const PARAM_IRON_GOLEM: u16 = 55;
const PARAM_PILLAGER: u16 = 56;
const PARAM_PARROT: u16 = 59;
const PARAM_BOAT: u16 = 66;
const PARAM_DRAGON: u16 = 68;
const PARAM_NETHERITE: u16 = 69;
const PARAM_RESPAWN_ANCHOR: u16 = 70;
const PARAM_CHORUS_FRUIT: u16 = 73;
const PARAM_END_GATEWAY: u16 = 74;
const PARAM_ENDER_CHEST: u16 = 75;
const PARAM_WITCH: u16 = 76;
const PARAM_POTION_ANY: u16 = 77;
const PARAM_TOTEM: u16 = 78;
const PARAM_SNIPER_DIST: u16 = 79;
const PARAM_HONEY_BOTTLE: u16 = 80;
const PARAM_BEEHIVE: u16 = 82;

// ---------------------------------------------------------------------------
// All advancements (80 total across 5 tabs)
// ---------------------------------------------------------------------------

pub const ADVANCEMENT_COUNT: u8 = 80;

pub const ADVANCEMENTS = [ADVANCEMENT_COUNT]Advancement{
    // =====================================================================
    // Minecraft tab (ids 0-19)
    // =====================================================================
    makeAdv(0, .minecraft, "Minecraft", "The heart and story of the game", null, .inventory_changed, PARAM_ANY, false),
    makeAdv(1, .minecraft, "Getting Wood", "Punch a tree until a block of wood pops out", 0, .mine_block, PARAM_OAK_LOG, false),
    makeAdv(2, .minecraft, "Benchmarking", "Craft a crafting table from planks", 1, .craft_item, PARAM_CRAFTING_TABLE, false),
    makeAdv(3, .minecraft, "Time to Mine!", "Craft a wooden pickaxe", 2, .craft_item, PARAM_WOODEN_PICKAXE, false),
    makeAdv(4, .minecraft, "Hot Topic", "Craft a furnace from cobblestone", 3, .craft_item, PARAM_FURNACE, false),
    makeAdv(5, .minecraft, "Acquire Hardware", "Smelt an iron ingot", 4, .smelt_item, PARAM_IRON_INGOT, false),
    makeAdv(6, .minecraft, "Suit Up", "Craft a piece of iron armor", 5, .craft_item, PARAM_IRON_ARMOR, false),
    makeAdv(7, .minecraft, "Diamonds!", "Find diamonds deep underground", 5, .mine_block, PARAM_DIAMOND, false),
    makeAdv(8, .minecraft, "Enchanter", "Enchant an item at an enchanting table", 7, .enchant_item, PARAM_ENCHANT_TABLE, false),
    makeAdv(9, .minecraft, "Cover Me With Diamonds", "Craft a full set of diamond armor", 7, .craft_item, PARAM_DIAMOND_ARMOR, false),
    makeAdv(10, .minecraft, "Ice Bucket Challenge", "Obtain obsidian", 5, .mine_block, PARAM_OBSIDIAN, false),
    makeAdv(11, .minecraft, "We Need to Go Deeper", "Build and light a Nether Portal", 10, .nether_portal, PARAM_NETHER, false),
    makeAdv(12, .minecraft, "Eye Spy", "Find a stronghold", 11, .inventory_changed, PARAM_EYE_ENDER, false),
    makeAdv(13, .minecraft, "The End?", "Enter the End dimension", 12, .end_portal, PARAM_END, false),
    makeAdv(14, .minecraft, "Zombie Doctor", "Cure a zombie villager", 5, .kill_entity, PARAM_ZOMBIE, true),
    makeAdv(15, .minecraft, "Into the Nether", "Enter the Nether dimension", 11, .enter_dimension, PARAM_NETHER, false),
    makeAdv(16, .minecraft, "Cover Me in Debris", "Obtain full netherite armor", 9, .craft_item, PARAM_NETHERITE, true),
    makeAdv(17, .minecraft, "Serious Dedication", "Use a netherite ingot to upgrade", 16, .craft_item, PARAM_NETHERITE, true),
    makeAdv(18, .minecraft, "Librarian", "Build a bookshelf collection", 8, .craft_item, PARAM_BOOKSHELF, false),
    makeAdv(19, .minecraft, "Sleep Tight", "Sleep in a bed to set respawn", 0, .sleep_in_bed, PARAM_BED, false),

    // =====================================================================
    // Nether tab (ids 20-35)
    // =====================================================================
    makeAdv(20, .nether, "Into Fire", "Survive the Nether dimension", null, .enter_dimension, PARAM_NETHER, false),
    makeAdv(21, .nether, "Subspace Bubble", "Use the Nether to travel great distances", 20, .nether_portal, PARAM_NETHER, false),
    makeAdv(22, .nether, "A Terrible Fortress", "Find a Nether Fortress", 20, .enter_biome, PARAM_NETHER, false),
    makeAdv(23, .nether, "Return to Sender", "Kill a ghast with its own fireball", 22, .kill_entity, PARAM_GHAST, false),
    makeAdv(24, .nether, "Withering Heights", "Defeat a wither skeleton", 22, .kill_entity, PARAM_WITHER_SKELETON, false),
    makeAdv(25, .nether, "Uneasy Alliance", "Rescue a ghast from the Nether", 23, .kill_entity, PARAM_GHAST, true),
    makeAdv(26, .nether, "Spooky Scary Skeleton", "Obtain a wither skeleton skull", 24, .inventory_changed, PARAM_WITHER_SKELETON, false),
    makeAdv(27, .nether, "Summon the Wither", "Summon the Wither boss", 26, .kill_wither, PARAM_WITHER, false),
    makeAdv(28, .nether, "Bring Home the Beacon", "Craft and place a beacon", 27, .craft_item, PARAM_BEACON, false),
    makeAdv(29, .nether, "A Furious Cocktail", "Have every potion effect at once", 22, .brew_potion, PARAM_POTION_ANY, true),
    makeAdv(30, .nether, "Local Brewery", "Brew a potion", 22, .brew_potion, PARAM_BREWING_STAND, false),
    makeAdv(31, .nether, "Hot Tourist Destination", "Explore all Nether biomes", 20, .enter_biome, PARAM_NETHER, true),
    makeAdv(32, .nether, "Those Were the Days", "Enter a bastion remnant", 20, .enter_biome, PARAM_NETHER, false),
    makeAdv(33, .nether, "War Pigs", "Loot a bastion chest", 32, .inventory_changed, PARAM_ANY, false),
    makeAdv(34, .nether, "Oh Shiny", "Distract piglins with gold", 32, .trade_villager, PARAM_ANY, false),
    makeAdv(35, .nether, "Not Quite Nine Lives", "Use a respawn anchor", 20, .craft_item, PARAM_RESPAWN_ANCHOR, false),

    // =====================================================================
    // End tab (ids 36-49)
    // =====================================================================
    makeAdv(36, .end, "The End", "Enter the End dimension", null, .end_portal, PARAM_END, false),
    makeAdv(37, .end, "Free the End", "Defeat the Ender Dragon", 36, .kill_dragon, PARAM_DRAGON, false),
    makeAdv(38, .end, "The Next Generation", "Collect the dragon egg", 37, .inventory_changed, PARAM_DRAGON_EGG, false),
    makeAdv(39, .end, "Remote Getaway", "Escape the island through an end gateway", 37, .enter_dimension, PARAM_END_GATEWAY, false),
    makeAdv(40, .end, "The City at the End", "Find an End City", 39, .enter_biome, PARAM_END, false),
    makeAdv(41, .end, "Skys the Limit", "Find elytra wings", 40, .inventory_changed, PARAM_ELYTRA, false),
    makeAdv(42, .end, "Great View From Here", "Levitate up 50 blocks with a shulker", 40, .kill_entity, PARAM_SHULKER, true),
    makeAdv(43, .end, "Youre Mean", "Kill an enderman", 36, .kill_entity, PARAM_ENDERMAN, false),
    makeAdv(44, .end, "End Again", "Respawn the Ender Dragon", 37, .kill_dragon, PARAM_END_CRYSTAL, true),
    makeAdv(45, .end, "You Need a Mint", "Collect dragon breath", 37, .inventory_changed, PARAM_DRAGON, true),
    makeAdv(46, .end, "The End Again", "Enter the End dimension again", 37, .end_portal, PARAM_END, false),
    makeAdv(47, .end, "Ender Chest", "Craft an ender chest", 36, .craft_item, PARAM_ENDER_CHEST, false),
    makeAdv(48, .end, "Chorus Fruit", "Eat chorus fruit", 39, .eat_food, PARAM_CHORUS_FRUIT, false),
    makeAdv(49, .end, "End Explorer", "Explore all End biomes", 39, .enter_biome, PARAM_END, true),

    // =====================================================================
    // Adventure tab (ids 50-65)
    // =====================================================================
    makeAdv(50, .adventure, "Adventure", "Adventure, exploration, and combat", null, .kill_entity, PARAM_ANY, false),
    makeAdv(51, .adventure, "Monster Hunter", "Kill any hostile mob", 50, .kill_entity, PARAM_ZOMBIE, false),
    makeAdv(52, .adventure, "What a Deal!", "Trade with a villager", 50, .trade_villager, PARAM_ANY, false),
    makeAdv(53, .adventure, "Sweet Dreams", "Sleep in a bed", 50, .sleep_in_bed, PARAM_BED, false),
    makeAdv(54, .adventure, "Sticky Situation", "Kill a spider", 51, .kill_entity, PARAM_SPIDER, false),
    makeAdv(55, .adventure, "Ol Betsy", "Fire a crossbow", 51, .craft_item, PARAM_CROSSBOW, false),
    makeAdv(56, .adventure, "Sniper Duel", "Kill a skeleton from 50 meters", 51, .kill_entity, PARAM_SNIPER_DIST, true),
    makeAdv(57, .adventure, "Hired Help", "Summon an iron golem", 50, .kill_entity, PARAM_IRON_GOLEM, false),
    makeAdv(58, .adventure, "Take Aim", "Shoot an arrow at a target", 51, .kill_entity, PARAM_SKELETON, false),
    makeAdv(59, .adventure, "Monsters Hunted", "Kill one of every hostile mob", 51, .kill_entity, PARAM_ANY, true),
    makeAdv(60, .adventure, "A Throwaway Joke", "Throw a trident at something", 51, .kill_entity, PARAM_TRIDENT, false),
    makeAdv(61, .adventure, "Very Very Frightening", "Strike a villager with lightning", 55, .kill_entity, PARAM_WITCH, true),
    makeAdv(62, .adventure, "Totem of Undying", "Use a totem of undying to cheat death", 50, .inventory_changed, PARAM_TOTEM, true),
    makeAdv(63, .adventure, "Voluntary Exile", "Kill a pillager captain", 50, .kill_entity, PARAM_PILLAGER, false),
    makeAdv(64, .adventure, "Hero of the Village", "Defend a village from a raid", 63, .kill_entity, PARAM_PILLAGER, true),
    makeAdv(65, .adventure, "Craft a Shield", "Craft a shield for protection", 50, .craft_item, PARAM_SHIELD, false),

    // =====================================================================
    // Husbandry tab (ids 66-79)
    // =====================================================================
    makeAdv(66, .husbandry, "Husbandry", "The world is full of friends and food", null, .eat_food, PARAM_ANY, false),
    makeAdv(67, .husbandry, "Bee Our Guest", "Use a campfire to collect honey", 66, .inventory_changed, PARAM_HONEY_BOTTLE, false),
    makeAdv(68, .husbandry, "Two by Two", "Breed all animal types", 66, .breed_animal, PARAM_ANY, true),
    makeAdv(69, .husbandry, "Balanced Diet", "Eat every food item", 66, .eat_food, PARAM_ANY, true),
    makeAdv(70, .husbandry, "A Seedy Place", "Plant a seed and watch it grow", 66, .mine_block, PARAM_WHEAT, false),
    makeAdv(71, .husbandry, "Best Friends Forever", "Tame a wolf", 66, .tame_animal, PARAM_WOLF, false),
    makeAdv(72, .husbandry, "Fishy Business", "Catch a fish", 66, .fish_item, PARAM_FISH_COD, false),
    makeAdv(73, .husbandry, "A Complete Catalogue", "Tame all cat variants", 71, .tame_animal, PARAM_CAT, true),
    makeAdv(74, .husbandry, "Tactical Fishing", "Catch a fish without a rod", 72, .fish_item, PARAM_FISH_COD, true),
    makeAdv(75, .husbandry, "The Parrots and the Bats", "Tame a parrot", 71, .tame_animal, PARAM_PARROT, false),
    makeAdv(76, .husbandry, "Total Beelocation", "Move a bee nest with silk touch", 67, .mine_block, PARAM_BEEHIVE, true),
    makeAdv(77, .husbandry, "Serious Dedication", "Use a hoe on netherite", 70, .craft_item, PARAM_NETHERITE, true),
    makeAdv(78, .husbandry, "Wax On", "Apply honeycomb to a copper block", 67, .craft_item, PARAM_HONEY_BOTTLE, false),
    makeAdv(79, .husbandry, "Whatever Floats Your Goat", "Ride a boat with a goat", 66, .ride_entity, PARAM_BOAT, true),
};

// ---------------------------------------------------------------------------
// AdvancementManager
// ---------------------------------------------------------------------------

pub const Progress = struct {
    completed: u32,
    total: u32,
};

pub const AdvancementManager = struct {
    completed: [ADVANCEMENT_COUNT]bool,

    pub fn init() AdvancementManager {
        return .{ .completed = [_]bool{false} ** ADVANCEMENT_COUNT };
    }

    /// Fire a criteria event. Any advancement whose criteria matches **and** whose
    /// parent is already completed (or has no parent) will be unlocked.
    pub fn checkCriteria(self: *AdvancementManager, criteria_type: CriteriaType, param: u16) void {
        for (0..ADVANCEMENT_COUNT) |i| {
            if (self.completed[i]) continue;
            const adv = ADVANCEMENTS[i];
            if (adv.criteria_type != criteria_type) continue;
            if (adv.criteria_param != param and adv.criteria_param != PARAM_ANY and param != PARAM_ANY) continue;

            // Check parent prerequisite
            if (adv.parent) |pid| {
                if (!self.completed[pid]) continue;
            }

            self.completed[i] = true;
        }
    }

    pub fn isCompleted(self: *const AdvancementManager, id: u8) bool {
        if (id >= ADVANCEMENT_COUNT) return false;
        return self.completed[id];
    }

    pub fn getProgress(self: *const AdvancementManager) Progress {
        var count: u32 = 0;
        for (self.completed) |c| {
            if (c) count += 1;
        }
        return .{ .completed = count, .total = ADVANCEMENT_COUNT };
    }

    /// Return a slice of all advancements belonging to the given tab.
    /// Uses a comptime-built index so there is no allocator needed at runtime.
    pub fn getTab(tab: AdvancementTab) []const Advancement {
        return tabSlice(tab);
    }
};

// ---------------------------------------------------------------------------
// Comptime tab indexing
// ---------------------------------------------------------------------------

// The largest tab (minecraft) has 20 entries. Fixed max avoids comptime
// mutable-variable-across-struct-boundary issues.
const MAX_PER_TAB: u8 = 20;

const TabData = struct {
    slices: [5][MAX_PER_TAB]Advancement,
    lens: [5]u8,
};

const tab_data: TabData = blk: {
    @setEvalBranchQuota(200_000);
    var data: TabData = .{
        .slices = undefined,
        .lens = [_]u8{0} ** 5,
    };
    // Zero-init all slots
    for (&data.slices) |*tab_arr| {
        for (tab_arr) |*slot| {
            slot.* = makeAdv(0, .minecraft, "", "", null, .inventory_changed, 0, false);
        }
    }
    for (&ADVANCEMENTS) |*a| {
        const ti = @intFromEnum(a.tab);
        data.slices[ti][data.lens[ti]] = a.*;
        data.lens[ti] += 1;
    }
    break :blk data;
};

fn tabSlice(tab: AdvancementTab) []const Advancement {
    const ti = @intFromEnum(tab);
    return tab_data.slices[ti][0..tab_data.lens[ti]];
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "advancement count is 80" {
    try std.testing.expectEqual(@as(u8, 80), ADVANCEMENT_COUNT);
    try std.testing.expectEqual(@as(usize, 80), ADVANCEMENTS.len);
}

test "ids are unique and sequential" {
    for (ADVANCEMENTS, 0..) |adv, i| {
        try std.testing.expectEqual(@as(u8, @intCast(i)), adv.id);
    }
}

test "init: nothing completed" {
    const mgr = AdvancementManager.init();
    const prog = mgr.getProgress();
    try std.testing.expectEqual(@as(u32, 0), prog.completed);
    try std.testing.expectEqual(@as(u32, 80), prog.total);
}

test "unlock root advancement via criteria" {
    var mgr = AdvancementManager.init();
    // Advancement 0 (Minecraft root) has criteria inventory_changed / PARAM_ANY
    mgr.checkCriteria(.inventory_changed, PARAM_ANY);
    try std.testing.expect(mgr.isCompleted(0));
    try std.testing.expectEqual(@as(u32, 1), mgr.getProgress().completed);
}

test "parent required: child not unlocked without parent" {
    var mgr = AdvancementManager.init();
    // Advancement 1 (Getting Wood) requires parent 0 to be completed
    mgr.checkCriteria(.mine_block, PARAM_OAK_LOG);
    try std.testing.expect(!mgr.isCompleted(1));
}

test "unlock chain: parent then child" {
    var mgr = AdvancementManager.init();
    // Unlock root first
    mgr.checkCriteria(.inventory_changed, PARAM_ANY);
    try std.testing.expect(mgr.isCompleted(0));

    // Now child (Getting Wood) can unlock
    mgr.checkCriteria(.mine_block, PARAM_OAK_LOG);
    try std.testing.expect(mgr.isCompleted(1));

    // Continue chain: Benchmarking (craft crafting table)
    mgr.checkCriteria(.craft_item, PARAM_CRAFTING_TABLE);
    try std.testing.expect(mgr.isCompleted(2));

    // Time to Mine!
    mgr.checkCriteria(.craft_item, PARAM_WOODEN_PICKAXE);
    try std.testing.expect(mgr.isCompleted(3));
}

test "progress tracking across multiple unlocks" {
    var mgr = AdvancementManager.init();
    try std.testing.expectEqual(@as(u32, 0), mgr.getProgress().completed);

    mgr.checkCriteria(.inventory_changed, PARAM_ANY);
    const p1 = mgr.getProgress();
    try std.testing.expect(p1.completed > 0);

    mgr.checkCriteria(.mine_block, PARAM_OAK_LOG);
    const p2 = mgr.getProgress();
    try std.testing.expect(p2.completed > p1.completed);

    mgr.checkCriteria(.craft_item, PARAM_CRAFTING_TABLE);
    const p3 = mgr.getProgress();
    try std.testing.expect(p3.completed > p2.completed);
}

test "tab filtering: minecraft tab" {
    const mc = AdvancementManager.getTab(.minecraft);
    try std.testing.expectEqual(@as(usize, 20), mc.len);
    for (mc) |adv| {
        try std.testing.expectEqual(AdvancementTab.minecraft, adv.tab);
    }
}

test "tab filtering: nether tab" {
    const neth = AdvancementManager.getTab(.nether);
    try std.testing.expectEqual(@as(usize, 16), neth.len);
    for (neth) |adv| {
        try std.testing.expectEqual(AdvancementTab.nether, adv.tab);
    }
}

test "tab filtering: end tab" {
    const end = AdvancementManager.getTab(.end);
    try std.testing.expectEqual(@as(usize, 14), end.len);
    for (end) |adv| {
        try std.testing.expectEqual(AdvancementTab.end, adv.tab);
    }
}

test "tab filtering: adventure tab" {
    const adv_tab = AdvancementManager.getTab(.adventure);
    try std.testing.expectEqual(@as(usize, 16), adv_tab.len);
    for (adv_tab) |adv| {
        try std.testing.expectEqual(AdvancementTab.adventure, adv.tab);
    }
}

test "tab filtering: husbandry tab" {
    const hus = AdvancementManager.getTab(.husbandry);
    try std.testing.expectEqual(@as(usize, 14), hus.len);
    for (hus) |adv| {
        try std.testing.expectEqual(AdvancementTab.husbandry, adv.tab);
    }
}

test "tab counts sum to total" {
    const total = AdvancementManager.getTab(.minecraft).len +
        AdvancementManager.getTab(.nether).len +
        AdvancementManager.getTab(.end).len +
        AdvancementManager.getTab(.adventure).len +
        AdvancementManager.getTab(.husbandry).len;
    try std.testing.expectEqual(@as(usize, ADVANCEMENT_COUNT), total);
}

test "duplicate criteria fire does not double-count" {
    var mgr = AdvancementManager.init();
    mgr.checkCriteria(.inventory_changed, PARAM_ANY);
    const c1 = mgr.getProgress().completed;
    mgr.checkCriteria(.inventory_changed, PARAM_ANY);
    const c2 = mgr.getProgress().completed;
    try std.testing.expectEqual(c1, c2);
}

test "hidden advancements exist" {
    var hidden_count: u32 = 0;
    for (&ADVANCEMENTS) |*adv| {
        if (adv.hidden) hidden_count += 1;
    }
    try std.testing.expect(hidden_count > 0);
}

test "getName and getDescription return correct slices" {
    const adv = &ADVANCEMENTS[1]; // Getting Wood
    try std.testing.expectEqualStrings("Getting Wood", adv.getName());
    try std.testing.expectEqualStrings("Punch a tree until a block of wood pops out", adv.getDescription());
}

test "parent references are valid" {
    for (&ADVANCEMENTS) |*adv| {
        if (adv.parent) |pid| {
            try std.testing.expect(pid < ADVANCEMENT_COUNT);
        }
    }
}

test "nether tab root has no parent" {
    const neth = AdvancementManager.getTab(.nether);
    try std.testing.expect(neth[0].parent == null);
}

test "end tab root has no parent" {
    const end = AdvancementManager.getTab(.end);
    try std.testing.expect(end[0].parent == null);
}

test "cross-tab: unlocking nether root" {
    var mgr = AdvancementManager.init();
    // Nether root (id 20) has criteria enter_dimension / PARAM_NETHER
    mgr.checkCriteria(.enter_dimension, PARAM_NETHER);
    try std.testing.expect(mgr.isCompleted(20));
}

test "isCompleted returns false for out of range id" {
    const mgr = AdvancementManager.init();
    try std.testing.expect(!mgr.isCompleted(255));
}
