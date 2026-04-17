const std = @import("std");

pub const GameMode = enum {
    survival,
    creative,
    adventure,
    spectator,
};

pub const GameModeRules = struct {
    can_break_blocks: bool,
    can_place_blocks: bool,
    has_health: bool,
    has_hunger: bool,
    instant_break: bool,
    can_fly: bool,
    takes_damage: bool,
    mob_spawning: bool,
    drops_items: bool,
    has_inventory_limit: bool,
    collision: bool,
};

pub fn getRules(mode: GameMode) GameModeRules {
    return switch (mode) {
        .survival => .{
            .can_break_blocks = true,
            .can_place_blocks = true,
            .has_health = true,
            .has_hunger = true,
            .instant_break = false,
            .can_fly = false,
            .takes_damage = true,
            .mob_spawning = true,
            .drops_items = true,
            .has_inventory_limit = true,
            .collision = true,
        },
        .creative => .{
            .can_break_blocks = true,
            .can_place_blocks = true,
            .has_health = false,
            .has_hunger = false,
            .instant_break = true,
            .can_fly = true,
            .takes_damage = false,
            .mob_spawning = false,
            .drops_items = false,
            .has_inventory_limit = false,
            .collision = true,
        },
        .adventure => .{
            .can_break_blocks = false,
            .can_place_blocks = false,
            .has_health = true,
            .has_hunger = true,
            .instant_break = false,
            .can_fly = false,
            .takes_damage = true,
            .mob_spawning = true,
            .drops_items = true,
            .has_inventory_limit = true,
            .collision = true,
        },
        .spectator => .{
            .can_break_blocks = false,
            .can_place_blocks = false,
            .has_health = false,
            .has_hunger = false,
            .instant_break = false,
            .can_fly = true,
            .takes_damage = false,
            .mob_spawning = false,
            .drops_items = false,
            .has_inventory_limit = false,
            .collision = false,
        },
    };
}

pub const GameModeManager = struct {
    current: GameMode = .survival,
    is_flying: bool = false,

    pub fn init(mode: GameMode) GameModeManager {
        return .{
            .current = mode,
            .is_flying = false,
        };
    }

    pub fn setMode(self: *GameModeManager, mode: GameMode) void {
        self.current = mode;
        const rules = getRules(mode);
        if (!rules.can_fly) {
            self.is_flying = false;
        }
    }

    pub fn toggleFlight(self: *GameModeManager) void {
        const rules = getRules(self.current);
        if (rules.can_fly) {
            self.is_flying = !self.is_flying;
        }
    }

    pub fn canBreak(self: *const GameModeManager) bool {
        return getRules(self.current).can_break_blocks;
    }

    pub fn canPlace(self: *const GameModeManager) bool {
        return getRules(self.current).can_place_blocks;
    }

    pub fn takesBlockDamage(self: *const GameModeManager) bool {
        return getRules(self.current).takes_damage;
    }

    pub fn hasCollision(self: *const GameModeManager) bool {
        return getRules(self.current).collision;
    }
};

// --- Tests ---

test "survival mode rules" {
    const rules = getRules(.survival);
    try std.testing.expect(rules.can_break_blocks);
    try std.testing.expect(rules.can_place_blocks);
    try std.testing.expect(rules.has_health);
    try std.testing.expect(rules.has_hunger);
    try std.testing.expect(!rules.instant_break);
    try std.testing.expect(!rules.can_fly);
    try std.testing.expect(rules.takes_damage);
    try std.testing.expect(rules.mob_spawning);
    try std.testing.expect(rules.drops_items);
    try std.testing.expect(rules.has_inventory_limit);
    try std.testing.expect(rules.collision);
}

test "creative mode rules" {
    const rules = getRules(.creative);
    try std.testing.expect(rules.can_break_blocks);
    try std.testing.expect(rules.can_place_blocks);
    try std.testing.expect(!rules.has_health);
    try std.testing.expect(!rules.has_hunger);
    try std.testing.expect(rules.instant_break);
    try std.testing.expect(rules.can_fly);
    try std.testing.expect(!rules.takes_damage);
    try std.testing.expect(!rules.mob_spawning);
    try std.testing.expect(!rules.drops_items);
    try std.testing.expect(!rules.has_inventory_limit);
    try std.testing.expect(rules.collision);
}

test "adventure mode rules" {
    const rules = getRules(.adventure);
    try std.testing.expect(!rules.can_break_blocks);
    try std.testing.expect(!rules.can_place_blocks);
    try std.testing.expect(rules.has_health);
    try std.testing.expect(rules.has_hunger);
    try std.testing.expect(!rules.instant_break);
    try std.testing.expect(!rules.can_fly);
    try std.testing.expect(rules.takes_damage);
    try std.testing.expect(rules.mob_spawning);
    try std.testing.expect(rules.drops_items);
    try std.testing.expect(rules.has_inventory_limit);
    try std.testing.expect(rules.collision);
}

test "spectator mode rules" {
    const rules = getRules(.spectator);
    try std.testing.expect(!rules.can_break_blocks);
    try std.testing.expect(!rules.can_place_blocks);
    try std.testing.expect(!rules.has_health);
    try std.testing.expect(!rules.has_hunger);
    try std.testing.expect(!rules.instant_break);
    try std.testing.expect(rules.can_fly);
    try std.testing.expect(!rules.takes_damage);
    try std.testing.expect(!rules.mob_spawning);
    try std.testing.expect(!rules.drops_items);
    try std.testing.expect(!rules.has_inventory_limit);
    try std.testing.expect(!rules.collision);
}

test "toggle flight in creative mode" {
    var mgr = GameModeManager.init(.creative);
    try std.testing.expect(!mgr.is_flying);

    mgr.toggleFlight();
    try std.testing.expect(mgr.is_flying);

    mgr.toggleFlight();
    try std.testing.expect(!mgr.is_flying);
}

test "cannot fly in survival mode" {
    var mgr = GameModeManager.init(.survival);
    try std.testing.expect(!mgr.is_flying);

    mgr.toggleFlight();
    try std.testing.expect(!mgr.is_flying);
}

test "switching from creative to survival disables flight" {
    var mgr = GameModeManager.init(.creative);
    mgr.toggleFlight();
    try std.testing.expect(mgr.is_flying);

    mgr.setMode(.survival);
    try std.testing.expect(!mgr.is_flying);
}

test "manager canBreak and canPlace" {
    const creative_mgr = GameModeManager.init(.creative);
    try std.testing.expect(creative_mgr.canBreak());
    try std.testing.expect(creative_mgr.canPlace());

    const adventure_mgr = GameModeManager.init(.adventure);
    try std.testing.expect(!adventure_mgr.canBreak());
    try std.testing.expect(!adventure_mgr.canPlace());
}

test "manager takesBlockDamage" {
    const survival_mgr = GameModeManager.init(.survival);
    try std.testing.expect(survival_mgr.takesBlockDamage());

    const creative_mgr = GameModeManager.init(.creative);
    try std.testing.expect(!creative_mgr.takesBlockDamage());
}

test "manager hasCollision" {
    const survival_mgr = GameModeManager.init(.survival);
    try std.testing.expect(survival_mgr.hasCollision());

    const spectator_mgr = GameModeManager.init(.spectator);
    try std.testing.expect(!spectator_mgr.hasCollision());
}

test "spectator can toggle flight" {
    var mgr = GameModeManager.init(.spectator);
    mgr.toggleFlight();
    try std.testing.expect(mgr.is_flying);
}
