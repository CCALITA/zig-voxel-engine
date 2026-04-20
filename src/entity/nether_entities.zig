const std = @import("std");

// ─── Shared types ────────────────────────────────────────────────────────────

pub const Dimension = enum {
    overworld,
    nether,
    end,
};

pub const BarterItem = enum {
    iron_nuggets,
    fire_charge,
    ender_pearl,
    string,
    obsidian,
    crying_obsidian,
    gravel,
    leather,
    nether_brick,
    spectral_arrow,
    water_bottle,
    potion_fire_resistance,
    splash_potion_fire_resistance,
    nether_quartz,
    soul_speed_enchant,
    iron_boots_soul_speed,
    blackstone,
};

pub const AggroTrigger = enum {
    attacked_piglin,
    opened_chest,
    mined_gold_block,
    not_wearing_gold,
};

// ─── PiglinAction ────────────────────────────────────────────────────────────

pub const PiglinAction = enum {
    idle,
    attack,
    barter,
    hunt_hoglin,
    flee_soul_fire,
    transform_to_zombified,
    admire_gold,
};

// ─── PiglinEntity ────────────────────────────────────────────────────────────

pub const PiglinEntity = struct {
    x: f32,
    y: f32,
    z: f32,
    health: f32 = 16.0,
    is_baby: bool = false,
    is_bartering: bool = false,
    barter_timer: f32 = 0.0,
    aggro: bool = false,
    transform_timer: f32 = 0.0,
    is_transforming: bool = false,
    admiring_gold: bool = false,

    const max_health: f32 = 16.0;
    const barter_duration: f32 = 6.0;
    const transform_duration: f32 = 15.0;
    const attack_damage: f32 = 5.0;

    const barter_table = [_]BarterItem{
        .iron_nuggets,
        .fire_charge,
        .ender_pearl,
        .string,
        .obsidian,
        .crying_obsidian,
        .gravel,
        .leather,
        .nether_brick,
        .spectral_arrow,
        .water_bottle,
        .potion_fire_resistance,
        .splash_potion_fire_resistance,
        .nether_quartz,
        .soul_speed_enchant,
        .iron_boots_soul_speed,
        .blackstone,
    };

    pub fn init(x: f32, y: f32, z: f32, is_baby: bool) PiglinEntity {
        return .{
            .x = x,
            .y = y,
            .z = z,
            .is_baby = is_baby,
        };
    }

    pub fn update(self: *PiglinEntity, dt: f32, context: PiglinContext) PiglinAction {
        // Dimension transformation check
        if (context.dimension != .nether) {
            if (!self.is_transforming) {
                self.is_transforming = true;
                self.transform_timer = transform_duration;
            }
            self.transform_timer = @max(0.0, self.transform_timer - dt);
            if (self.transform_timer <= 0.0) {
                return .transform_to_zombified;
            }
        } else {
            self.is_transforming = false;
            self.transform_timer = 0.0;
        }

        // Flee soul fire
        if (context.near_soul_fire) {
            return .flee_soul_fire;
        }

        // Baby piglins admire gold but do not barter
        if (self.is_baby and self.admiring_gold) {
            return .admire_gold;
        }

        // Bartering in progress
        if (self.is_bartering) {
            self.barter_timer = @max(0.0, self.barter_timer - dt);
            if (self.barter_timer <= 0.0) {
                self.is_bartering = false;
                return .barter;
            }
            return .idle;
        }

        // Aggro from triggers
        if (context.aggro_trigger) |trigger| {
            switch (trigger) {
                .not_wearing_gold => {
                    self.aggro = true;
                },
                .attacked_piglin, .opened_chest, .mined_gold_block => {
                    self.aggro = true;
                },
            }
        }

        // Hunt hoglins
        if (context.hoglin_nearby and !self.aggro) {
            return .hunt_hoglin;
        }

        // Attack when aggroed
        if (self.aggro) {
            return .attack;
        }

        return .idle;
    }

    /// Start bartering when a gold ingot is given. Baby piglins admire instead.
    pub fn offerGoldIngot(self: *PiglinEntity) bool {
        if (self.is_baby) {
            self.admiring_gold = true;
            return false;
        }
        if (self.is_bartering) return false;
        self.is_bartering = true;
        self.barter_timer = barter_duration;
        return true;
    }

    /// Resolve a barter trade using the given random source.
    pub fn getBarterResult(rng: std.Random) BarterItem {
        const index = rng.intRangeAtMost(usize, 0, barter_table.len - 1);
        return barter_table[index];
    }

    /// Check whether the piglin should be hostile given the player's equipment.
    pub fn isHostileTo(self: PiglinEntity, player_wearing_gold: bool) bool {
        if (self.aggro) return true;
        return !player_wearing_gold;
    }

    pub fn getAttackDamage() f32 {
        return attack_damage;
    }

    pub fn getDrops() struct { gold_sword_chance: f32, gold_ingot_chance: f32 } {
        return .{ .gold_sword_chance = 0.5, .gold_ingot_chance = 0.1 };
    }
};

pub const PiglinContext = struct {
    dimension: Dimension = .nether,
    near_soul_fire: bool = false,
    hoglin_nearby: bool = false,
    aggro_trigger: ?AggroTrigger = null,
};

// ─── PiglinBruteAction ───────────────────────────────────────────────────────

pub const PiglinBruteAction = enum {
    idle,
    attack,
    patrol,
};

// ─── PiglinBruteEntity ───────────────────────────────────────────────────────

pub const PiglinBruteEntity = struct {
    x: f32,
    y: f32,
    z: f32,
    health: f32 = 50.0,
    attack_cooldown: f32 = 0.0,

    const max_health: f32 = 50.0;
    const attack_damage: f32 = 7.0;
    const attack_cooldown_secs: f32 = 1.0;

    pub fn init(x: f32, y: f32, z: f32) PiglinBruteEntity {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn update(self: *PiglinBruteEntity, dt: f32, player_dist: ?f32) PiglinBruteAction {
        if (self.attack_cooldown > 0) {
            self.attack_cooldown = @max(0.0, self.attack_cooldown - dt);
        }

        if (player_dist) |dist| {
            if (dist < 16.0) {
                return .attack;
            }
        }

        return .patrol;
    }

    /// Perform a melee attack with the golden axe. Returns damage or null if on cooldown.
    pub fn meleeAttack(self: *PiglinBruteEntity) ?f32 {
        if (self.attack_cooldown > 0) return null;
        self.attack_cooldown = attack_cooldown_secs;
        return attack_damage;
    }

    /// Always hostile regardless of gold armor.
    pub fn isHostileTo(_: PiglinBruteEntity, _: bool) bool {
        return true;
    }

    /// Does not barter.
    pub fn canBarter() bool {
        return false;
    }

    /// Does not retreat.
    pub fn canRetreat() bool {
        return false;
    }

    pub fn getDrops() struct { golden_axe_chance: f32 } {
        return .{ .golden_axe_chance = 0.085 };
    }
};

// ─── HoglinAction ────────────────────────────────────────────────────────────

pub const HoglinAction = enum {
    idle,
    attack,
    flee_warped_fungi,
    flee_nether_portal,
    breed,
    transform_to_zoglin,
};

// ─── HoglinEntity ────────────────────────────────────────────────────────────

pub const HoglinEntity = struct {
    x: f32,
    y: f32,
    z: f32,
    health: f32 = 40.0,
    is_baby: bool = false,
    attack_cooldown: f32 = 0.0,
    breeding_cooldown: f32 = 0.0,
    transform_timer: f32 = 0.0,
    is_transforming: bool = false,

    const max_health: f32 = 40.0;
    const attack_damage: f32 = 6.0;
    const baby_attack_damage: f32 = 0.5;
    const knockback_strength: f32 = 1.5;
    const knockback_upward: f32 = 0.8;
    const attack_cooldown_secs: f32 = 1.5;
    const breeding_cooldown_secs: f32 = 300.0;
    const transform_duration: f32 = 15.0;

    pub fn init(x: f32, y: f32, z: f32, is_baby: bool) HoglinEntity {
        return .{
            .x = x,
            .y = y,
            .z = z,
            .is_baby = is_baby,
        };
    }

    pub fn update(self: *HoglinEntity, dt: f32, context: HoglinContext) HoglinAction {
        if (self.attack_cooldown > 0) {
            self.attack_cooldown = @max(0.0, self.attack_cooldown - dt);
        }
        if (self.breeding_cooldown > 0) {
            self.breeding_cooldown = @max(0.0, self.breeding_cooldown - dt);
        }

        // Transformation in Overworld/End
        if (context.dimension != .nether) {
            if (!self.is_transforming) {
                self.is_transforming = true;
                self.transform_timer = transform_duration;
            }
            self.transform_timer = @max(0.0, self.transform_timer - dt);
            if (self.transform_timer <= 0.0) {
                return .transform_to_zoglin;
            }
        } else {
            self.is_transforming = false;
            self.transform_timer = 0.0;
        }

        // Flee warped fungi
        if (context.near_warped_fungi) {
            return .flee_warped_fungi;
        }

        // Flee nether portal / respawn anchor
        if (context.near_nether_portal or context.near_respawn_anchor) {
            return .flee_nether_portal;
        }

        // Breeding
        if (context.offered_crimson_fungi and self.breeding_cooldown <= 0.0) {
            self.breeding_cooldown = breeding_cooldown_secs;
            return .breed;
        }

        // Babies do not attack
        if (self.is_baby) {
            return .idle;
        }

        // Attack player if close
        if (context.player_dist) |dist| {
            if (dist < 16.0) {
                return .attack;
            }
        }

        return .idle;
    }

    /// Perform a knockback attack. Returns null if baby or on cooldown.
    pub fn knockbackAttack(self: *HoglinEntity) ?KnockbackResult {
        if (self.is_baby) return null;
        if (self.attack_cooldown > 0) return null;
        self.attack_cooldown = attack_cooldown_secs;
        return KnockbackResult{
            .damage = attack_damage,
            .horizontal_strength = knockback_strength,
            .vertical_strength = knockback_upward,
        };
    }

    pub fn getDrops(self: HoglinEntity) struct { porkchop_count: u8, leather_count: u8 } {
        if (self.is_baby) return .{ .porkchop_count = 0, .leather_count = 0 };
        return .{ .porkchop_count = 4, .leather_count = 2 };
    }
};

pub const KnockbackResult = struct {
    damage: f32,
    horizontal_strength: f32,
    vertical_strength: f32,
};

pub const HoglinContext = struct {
    dimension: Dimension = .nether,
    near_warped_fungi: bool = false,
    near_nether_portal: bool = false,
    near_respawn_anchor: bool = false,
    offered_crimson_fungi: bool = false,
    player_dist: ?f32 = null,
};

// ─── ZoglinAction ────────────────────────────────────────────────────────────

pub const ZoglinAction = enum {
    idle,
    attack,
};

// ─── ZoglinEntity (zombified hoglin) ─────────────────────────────────────────

pub const ZoglinEntity = struct {
    x: f32,
    y: f32,
    z: f32,
    health: f32 = 40.0,
    attack_cooldown: f32 = 0.0,

    const max_health: f32 = 40.0;
    const attack_damage: f32 = 6.0;
    const knockback_strength: f32 = 1.5;
    const knockback_upward: f32 = 0.8;
    const attack_cooldown_secs: f32 = 1.5;

    pub fn init(x: f32, y: f32, z: f32) ZoglinEntity {
        return .{ .x = x, .y = y, .z = z };
    }

    /// Create a zoglin from a transforming hoglin.
    pub fn fromHoglin(hoglin: HoglinEntity) ZoglinEntity {
        return .{
            .x = hoglin.x,
            .y = hoglin.y,
            .z = hoglin.z,
            .health = hoglin.health,
        };
    }

    pub fn update(self: *ZoglinEntity, dt: f32, nearest_entity_dist: ?f32) ZoglinAction {
        if (self.attack_cooldown > 0) {
            self.attack_cooldown = @max(0.0, self.attack_cooldown - dt);
        }

        // Hostile to everything within range
        if (nearest_entity_dist) |dist| {
            if (dist < 16.0) {
                return .attack;
            }
        }

        return .idle;
    }

    /// Perform a knockback attack identical to hoglin's.
    pub fn knockbackAttack(self: *ZoglinEntity) ?KnockbackResult {
        if (self.attack_cooldown > 0) return null;
        self.attack_cooldown = attack_cooldown_secs;
        return KnockbackResult{
            .damage = attack_damage,
            .horizontal_strength = knockback_strength,
            .vertical_strength = knockback_upward,
        };
    }

    /// Zoglins cannot be bred.
    pub fn canBreed() bool {
        return false;
    }

    /// Zoglins do not avoid any items.
    pub fn avoidsItem(_: []const u8) bool {
        return false;
    }

    pub fn getDrops() struct { rotten_flesh_count: u8 } {
        return .{ .rotten_flesh_count = 1 };
    }
};

// ─── StriderAction ───────────────────────────────────────────────────────────

pub const StriderAction = enum {
    idle,
    walk_on_lava,
    follow_warped_fungus,
    shiver,
};

// ─── StriderEntity ───────────────────────────────────────────────────────────

pub const StriderEntity = struct {
    x: f32,
    y: f32,
    z: f32,
    health: f32 = 20.0,
    is_baby: bool = false,
    is_saddled: bool = false,
    on_lava: bool = true,
    is_shivering: bool = false,
    rider: ?StriderRider = null,
    baby_rider: ?*StriderEntity = null,

    const max_health: f32 = 20.0;
    const lava_speed: f32 = 4.0;
    const land_speed: f32 = 1.0;
    const boost_speed: f32 = 8.0;

    pub const StriderRider = struct {
        has_warped_fungus_stick: bool = false,
    };

    pub fn init(x: f32, y: f32, z: f32, is_baby: bool) StriderEntity {
        return .{
            .x = x,
            .y = y,
            .z = z,
            .is_baby = is_baby,
        };
    }

    pub fn update(self: *StriderEntity, dt: f32, context: StriderContext) StriderAction {
        _ = dt;

        self.on_lava = context.on_lava;

        // Shivering state when outside lava
        if (!context.on_lava) {
            self.is_shivering = true;
            return .shiver;
        }

        self.is_shivering = false;

        // Rider controlling with warped fungus on a stick
        if (self.rider) |r| {
            if (r.has_warped_fungus_stick) {
                return .follow_warped_fungus;
            }
        }

        if (context.on_lava) {
            return .walk_on_lava;
        }

        return .idle;
    }

    pub fn getSpeed(self: StriderEntity) f32 {
        if (!self.on_lava) return land_speed;
        if (self.rider) |r| {
            if (r.has_warped_fungus_stick) return boost_speed;
        }
        return lava_speed;
    }

    pub fn saddle(self: *StriderEntity) bool {
        if (self.is_saddled) return false;
        self.is_saddled = true;
        return true;
    }

    pub fn mount(self: *StriderEntity) bool {
        if (!self.is_saddled) return false;
        if (self.rider != null) return false;
        self.rider = .{ .has_warped_fungus_stick = false };
        return true;
    }

    pub fn mountWithFungusStick(self: *StriderEntity) bool {
        if (!self.is_saddled) return false;
        if (self.rider != null) return false;
        self.rider = .{ .has_warped_fungus_stick = true };
        return true;
    }

    pub fn dismount(self: *StriderEntity) void {
        self.rider = null;
    }

    /// Attach a baby strider on top.
    pub fn attachBabyRider(self: *StriderEntity, baby: *StriderEntity) bool {
        if (self.is_baby) return false;
        if (self.baby_rider != null) return false;
        if (!baby.is_baby) return false;
        self.baby_rider = baby;
        return true;
    }

    pub fn takeDamageOutsideLava(self: *StriderEntity, dt: f32) f32 {
        if (self.on_lava) return 0.0;
        const damage = dt * 1.0;
        self.health = @max(0.0, self.health - damage);
        return damage;
    }

    pub fn getDrops(self: StriderEntity) struct { string_count: u8, saddle: bool } {
        return .{
            .string_count = if (self.is_baby) 0 else 5,
            .saddle = self.is_saddled,
        };
    }
};

pub const StriderContext = struct {
    on_lava: bool = true,
};

// ─── Tests ───────────────────────────────────────────────────────────────────

// -- Piglin tests --

test "piglin has 16 HP" {
    const piglin = PiglinEntity.init(0, 0, 0, false);
    try std.testing.expectEqual(@as(f32, 16.0), piglin.health);
}

test "piglin is hostile when player not wearing gold" {
    const piglin = PiglinEntity.init(0, 0, 0, false);
    try std.testing.expect(piglin.isHostileTo(false));
    try std.testing.expect(!piglin.isHostileTo(true));
}

test "piglin barters gold ingot" {
    var piglin = PiglinEntity.init(0, 0, 0, false);
    try std.testing.expect(piglin.offerGoldIngot());
    try std.testing.expect(piglin.is_bartering);

    // Cannot start a second barter while already bartering
    try std.testing.expect(!piglin.offerGoldIngot());
}

test "piglin barter produces valid item" {
    var prng = std.Random.DefaultPrng.init(42);
    const rng = prng.random();
    const item = PiglinEntity.getBarterResult(rng);
    // Ensure the result is a valid BarterItem (it compiles and does not panic)
    _ = @intFromEnum(item);
}

test "piglin update returns barter after timer expires" {
    var piglin = PiglinEntity.init(0, 0, 0, false);
    _ = piglin.offerGoldIngot();

    const ctx = PiglinContext{};

    // Not yet done bartering
    const action1 = piglin.update(3.0, ctx);
    try std.testing.expectEqual(PiglinAction.idle, action1);

    // Timer expires
    const action2 = piglin.update(4.0, ctx);
    try std.testing.expectEqual(PiglinAction.barter, action2);
    try std.testing.expect(!piglin.is_bartering);
}

test "piglin flees soul fire" {
    var piglin = PiglinEntity.init(0, 0, 0, false);
    const ctx = PiglinContext{ .near_soul_fire = true };
    const action = piglin.update(0.1, ctx);
    try std.testing.expectEqual(PiglinAction.flee_soul_fire, action);
}

test "piglin hunts hoglins when not aggroed" {
    var piglin = PiglinEntity.init(0, 0, 0, false);
    const ctx = PiglinContext{ .hoglin_nearby = true };
    const action = piglin.update(0.1, ctx);
    try std.testing.expectEqual(PiglinAction.hunt_hoglin, action);
}

test "piglin transforms outside nether after 15s" {
    var piglin = PiglinEntity.init(0, 0, 0, false);
    const ctx = PiglinContext{ .dimension = .overworld };

    // Partially through timer
    const action1 = piglin.update(10.0, ctx);
    try std.testing.expect(action1 != PiglinAction.transform_to_zombified);

    // Timer completes
    const action2 = piglin.update(6.0, ctx);
    try std.testing.expectEqual(PiglinAction.transform_to_zombified, action2);
}

test "piglin aggro from chest opening" {
    var piglin = PiglinEntity.init(0, 0, 0, false);
    const ctx = PiglinContext{ .aggro_trigger = .opened_chest };
    const action = piglin.update(0.1, ctx);
    try std.testing.expectEqual(PiglinAction.attack, action);
    try std.testing.expect(piglin.aggro);
}

test "baby piglin admires gold instead of bartering" {
    var baby = PiglinEntity.init(0, 0, 0, true);
    try std.testing.expect(!baby.offerGoldIngot());
    try std.testing.expect(baby.admiring_gold);
    try std.testing.expect(!baby.is_bartering);

    const ctx = PiglinContext{};
    const action = baby.update(0.1, ctx);
    try std.testing.expectEqual(PiglinAction.admire_gold, action);
}

// -- Piglin Brute tests --

test "piglin brute has 50 HP" {
    const brute = PiglinBruteEntity.init(0, 0, 0);
    try std.testing.expectEqual(@as(f32, 50.0), brute.health);
}

test "piglin brute is always hostile regardless of gold armor" {
    const brute = PiglinBruteEntity.init(0, 0, 0);
    try std.testing.expect(brute.isHostileTo(true));
    try std.testing.expect(brute.isHostileTo(false));
}

test "piglin brute deals 7 damage with golden axe" {
    var brute = PiglinBruteEntity.init(0, 0, 0);
    const dmg = brute.meleeAttack();
    try std.testing.expect(dmg != null);
    try std.testing.expectEqual(@as(f32, 7.0), dmg.?);
}

test "piglin brute attack respects cooldown" {
    var brute = PiglinBruteEntity.init(0, 0, 0);
    _ = brute.meleeAttack();
    try std.testing.expect(brute.meleeAttack() == null);

    brute.update(1.0, null);
    try std.testing.expect(brute.meleeAttack() != null);
}

test "piglin brute does not barter or retreat" {
    try std.testing.expect(!PiglinBruteEntity.canBarter());
    try std.testing.expect(!PiglinBruteEntity.canRetreat());
}

test "piglin brute attacks when player is near" {
    var brute = PiglinBruteEntity.init(0, 0, 0);
    const action = brute.update(0.1, @as(f32, 10.0));
    try std.testing.expectEqual(PiglinBruteAction.attack, action);
}

test "piglin brute patrols when no player nearby" {
    var brute = PiglinBruteEntity.init(0, 0, 0);
    const action = brute.update(0.1, null);
    try std.testing.expectEqual(PiglinBruteAction.patrol, action);
}

// -- Hoglin tests --

test "hoglin has 40 HP" {
    const hoglin = HoglinEntity.init(0, 0, 0, false);
    try std.testing.expectEqual(@as(f32, 40.0), hoglin.health);
}

test "hoglin knockback attack deals damage with upward launch" {
    var hoglin = HoglinEntity.init(0, 0, 0, false);
    const result = hoglin.knockbackAttack();
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(f32, 6.0), result.?.damage);
    try std.testing.expect(result.?.vertical_strength > 0);
}

test "hoglin knockback attack respects cooldown" {
    var hoglin = HoglinEntity.init(0, 0, 0, false);
    _ = hoglin.knockbackAttack();
    try std.testing.expect(hoglin.knockbackAttack() == null);
}

test "hoglin flees warped fungi" {
    var hoglin = HoglinEntity.init(0, 0, 0, false);
    const ctx = HoglinContext{ .near_warped_fungi = true };
    const action = hoglin.update(0.1, ctx);
    try std.testing.expectEqual(HoglinAction.flee_warped_fungi, action);
}

test "hoglin flees nether portal" {
    var hoglin = HoglinEntity.init(0, 0, 0, false);
    const ctx = HoglinContext{ .near_nether_portal = true };
    const action = hoglin.update(0.1, ctx);
    try std.testing.expectEqual(HoglinAction.flee_nether_portal, action);
}

test "hoglin flees respawn anchor" {
    var hoglin = HoglinEntity.init(0, 0, 0, false);
    const ctx = HoglinContext{ .near_respawn_anchor = true };
    const action = hoglin.update(0.1, ctx);
    try std.testing.expectEqual(HoglinAction.flee_nether_portal, action);
}

test "hoglin breeds with crimson fungi" {
    var hoglin = HoglinEntity.init(0, 0, 0, false);
    const ctx = HoglinContext{ .offered_crimson_fungi = true };
    const action = hoglin.update(0.1, ctx);
    try std.testing.expectEqual(HoglinAction.breed, action);
    try std.testing.expect(hoglin.breeding_cooldown > 0);
}

test "hoglin transforms to zoglin in overworld after 15s" {
    var hoglin = HoglinEntity.init(5, 10, 15, false);
    const ctx = HoglinContext{ .dimension = .overworld };

    const action1 = hoglin.update(10.0, ctx);
    try std.testing.expect(action1 != HoglinAction.transform_to_zoglin);

    const action2 = hoglin.update(6.0, ctx);
    try std.testing.expectEqual(HoglinAction.transform_to_zoglin, action2);
}

test "baby hoglin does not attack" {
    var baby = HoglinEntity.init(0, 0, 0, true);
    try std.testing.expect(baby.knockbackAttack() == null);

    const ctx = HoglinContext{ .player_dist = 5.0 };
    const action = baby.update(0.1, ctx);
    try std.testing.expectEqual(HoglinAction.idle, action);
}

test "hoglin attacks when player is close" {
    var hoglin = HoglinEntity.init(0, 0, 0, false);
    const ctx = HoglinContext{ .player_dist = 5.0 };
    const action = hoglin.update(0.1, ctx);
    try std.testing.expectEqual(HoglinAction.attack, action);
}

// -- Zoglin tests --

test "zoglin has 40 HP" {
    const zoglin = ZoglinEntity.init(0, 0, 0);
    try std.testing.expectEqual(@as(f32, 40.0), zoglin.health);
}

test "zoglin is hostile to everything" {
    var zoglin = ZoglinEntity.init(0, 0, 0);
    const action = zoglin.update(0.1, @as(f32, 5.0));
    try std.testing.expectEqual(ZoglinAction.attack, action);
}

test "zoglin knockback attack matches hoglin" {
    var zoglin = ZoglinEntity.init(0, 0, 0);
    const result = zoglin.knockbackAttack();
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(f32, 6.0), result.?.damage);
    try std.testing.expect(result.?.vertical_strength > 0);
    try std.testing.expect(result.?.horizontal_strength > 0);
}

test "zoglin cannot be bred" {
    try std.testing.expect(!ZoglinEntity.canBreed());
}

test "zoglin does not avoid items" {
    try std.testing.expect(!ZoglinEntity.avoidsItem("warped_fungi"));
}

test "zoglin created from hoglin preserves position and health" {
    const hoglin = HoglinEntity{
        .x = 10,
        .y = 20,
        .z = 30,
        .health = 35.0,
    };
    const zoglin = ZoglinEntity.fromHoglin(hoglin);
    try std.testing.expectEqual(@as(f32, 10.0), zoglin.x);
    try std.testing.expectEqual(@as(f32, 20.0), zoglin.y);
    try std.testing.expectEqual(@as(f32, 30.0), zoglin.z);
    try std.testing.expectEqual(@as(f32, 35.0), zoglin.health);
}

test "zoglin idle when no entities nearby" {
    var zoglin = ZoglinEntity.init(0, 0, 0);
    const action = zoglin.update(0.1, null);
    try std.testing.expectEqual(ZoglinAction.idle, action);
}

// -- Strider tests --

test "strider has 20 HP" {
    const strider = StriderEntity.init(0, 0, 0, false);
    try std.testing.expectEqual(@as(f32, 20.0), strider.health);
}

test "strider walks on lava at normal speed" {
    const strider = StriderEntity.init(0, 0, 0, false);
    try std.testing.expectEqual(@as(f32, 4.0), strider.getSpeed());
}

test "strider shivers outside lava" {
    var strider = StriderEntity.init(0, 0, 0, false);
    const ctx = StriderContext{ .on_lava = false };
    const action = strider.update(0.1, ctx);
    try std.testing.expectEqual(StriderAction.shiver, action);
    try std.testing.expect(strider.is_shivering);
}

test "strider stops shivering on lava" {
    var strider = StriderEntity.init(0, 0, 0, false);

    // Go off lava
    _ = strider.update(0.1, StriderContext{ .on_lava = false });
    try std.testing.expect(strider.is_shivering);

    // Return to lava
    _ = strider.update(0.1, StriderContext{ .on_lava = true });
    try std.testing.expect(!strider.is_shivering);
}

test "strider is rideable with saddle" {
    var strider = StriderEntity.init(0, 0, 0, false);

    // Cannot mount without saddle
    try std.testing.expect(!strider.mount());

    // Saddle and mount
    try std.testing.expect(strider.saddle());
    try std.testing.expect(strider.mount());

    // Cannot double-saddle or double-mount
    try std.testing.expect(!strider.saddle());
    try std.testing.expect(!strider.mount());
}

test "strider boosted with warped fungus on stick" {
    var strider = StriderEntity.init(0, 0, 0, false);
    _ = strider.saddle();
    _ = strider.mountWithFungusStick();

    try std.testing.expectEqual(@as(f32, 8.0), strider.getSpeed());
}

test "strider follow warped fungus action" {
    var strider = StriderEntity.init(0, 0, 0, false);
    _ = strider.saddle();
    _ = strider.mountWithFungusStick();

    const action = strider.update(0.1, StriderContext{ .on_lava = true });
    try std.testing.expectEqual(StriderAction.follow_warped_fungus, action);
}

test "strider dismount" {
    var strider = StriderEntity.init(0, 0, 0, false);
    _ = strider.saddle();
    _ = strider.mount();
    strider.dismount();
    try std.testing.expect(strider.rider == null);
}

test "strider slow on land" {
    var strider = StriderEntity.init(0, 0, 0, false);
    _ = strider.update(0.1, StriderContext{ .on_lava = false });
    try std.testing.expectEqual(@as(f32, 1.0), strider.getSpeed());
}

test "baby strider can ride adult" {
    var adult = StriderEntity.init(0, 0, 0, false);
    var baby = StriderEntity.init(0, 0, 0, true);
    try std.testing.expect(adult.attachBabyRider(&baby));
    try std.testing.expect(adult.baby_rider != null);

    // Cannot attach a second baby
    var baby2 = StriderEntity.init(0, 0, 0, true);
    try std.testing.expect(!adult.attachBabyRider(&baby2));
}

test "baby strider cannot carry another baby" {
    var baby1 = StriderEntity.init(0, 0, 0, true);
    var baby2 = StriderEntity.init(0, 0, 0, true);
    try std.testing.expect(!baby1.attachBabyRider(&baby2));
}

test "adult cannot ride as baby rider" {
    var adult1 = StriderEntity.init(0, 0, 0, false);
    var adult2 = StriderEntity.init(0, 0, 0, false);
    try std.testing.expect(!adult1.attachBabyRider(&adult2));
}

test "strider takes damage outside lava" {
    var strider = StriderEntity.init(0, 0, 0, false);
    _ = strider.update(0.1, StriderContext{ .on_lava = false });
    const dmg = strider.takeDamageOutsideLava(2.0);
    try std.testing.expect(dmg > 0);
    try std.testing.expect(strider.health < 20.0);
}

test "strider no damage on lava" {
    var strider = StriderEntity.init(0, 0, 0, false);
    const dmg = strider.takeDamageOutsideLava(2.0);
    try std.testing.expectEqual(@as(f32, 0.0), dmg);
    try std.testing.expectEqual(@as(f32, 20.0), strider.health);
}

test "strider drops string and saddle" {
    var strider = StriderEntity.init(0, 0, 0, false);
    _ = strider.saddle();
    const drops = strider.getDrops();
    try std.testing.expectEqual(@as(u8, 5), drops.string_count);
    try std.testing.expect(drops.saddle);
}

test "baby strider drops no string" {
    const baby = StriderEntity.init(0, 0, 0, true);
    const drops = baby.getDrops();
    try std.testing.expectEqual(@as(u8, 0), drops.string_count);
}
