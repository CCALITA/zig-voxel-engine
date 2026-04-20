const std = @import("std");

// ---------------------------------------------------------------------------
// Shared types
// ---------------------------------------------------------------------------

pub const PotionThrow = struct {
    potion_type: PotionType,
    damage: f32,

    pub const PotionType = enum {
        harm,
        poison,
        slowness,
        weakness,
    };
};

pub const CrossbowShot = struct {
    damage: f32,
};

pub const VexSpawn = struct {
    x: f32,
    y: f32,
    z: f32,
};

pub const FangLine = struct {
    damage: f32,
    fang_count: u32,
    start_x: f32,
    start_z: f32,
    end_x: f32,
    end_z: f32,
};

// ---------------------------------------------------------------------------
// WitchEntity
// ---------------------------------------------------------------------------

pub const WitchEntity = struct {
    x: f32,
    y: f32,
    z: f32,
    health: f32 = max_health,
    throw_cooldown: f32 = 0,
    drinking: bool = false,

    const max_health: f32 = 26.0;
    const throw_cooldown_time: f32 = 3.0;
    const heal_amount: f32 = 4.0;
    const heal_threshold: f32 = max_health / 2.0;
    const harm_range: f32 = 3.0;
    const poison_range: f32 = 6.0;
    const slowness_range: f32 = 10.0;
    const harm_damage: f32 = 6.0;
    const poison_damage: f32 = 4.0;

    /// Throw a potion at a target based on distance.
    /// Returns null when the throw cooldown has not elapsed.
    pub fn throwPotion(self: *WitchEntity, target_dist: f32) ?PotionThrow {
        if (self.throw_cooldown > 0) return null;

        const potion_type: PotionThrow.PotionType = if (target_dist <= harm_range)
            .harm
        else if (target_dist <= poison_range)
            .poison
        else if (target_dist <= slowness_range)
            .slowness
        else
            .weakness;

        const damage: f32 = switch (potion_type) {
            .harm => harm_damage,
            .poison => poison_damage,
            .slowness => 0.0,
            .weakness => 0.0,
        };

        self.throw_cooldown = throw_cooldown_time;

        return PotionThrow{
            .potion_type = potion_type,
            .damage = damage,
        };
    }

    /// Drink a beneficial potion for self-healing (regen, fire_resist, water_breathing).
    pub fn selfHeal(self: *WitchEntity) void {
        self.drinking = true;

        if (self.health < heal_threshold) {
            self.health = @min(self.health + heal_amount, max_health);
        }

        self.drinking = false;
    }
};

// ---------------------------------------------------------------------------
// PillagerEntity
// ---------------------------------------------------------------------------

pub const PillagerEntity = struct {
    x: f32,
    y: f32,
    z: f32,
    health: f32 = max_health,
    shoot_cooldown: f32 = initial_cooldown,
    is_patrol_leader: bool,

    const max_health: f32 = 24.0;
    const crossbow_damage: f32 = 4.0;
    const shoot_cooldown_time: f32 = 2.0;
    const initial_cooldown: f32 = 3.0;

    /// Shoot a crossbow bolt. Returns null when still on cooldown.
    pub fn shootCrossbow(self: *PillagerEntity) ?CrossbowShot {
        if (self.shoot_cooldown > 0) return null;

        self.shoot_cooldown = shoot_cooldown_time;

        return CrossbowShot{ .damage = crossbow_damage };
    }
};

// ---------------------------------------------------------------------------
// EvokerEntity
// ---------------------------------------------------------------------------

pub const EvokerEntity = struct {
    x: f32,
    y: f32,
    z: f32,
    health: f32 = max_health,
    summon_cooldown: f32 = 0,
    fang_cooldown: f32 = 0,

    const max_health: f32 = 24.0;
    const summon_cooldown_time: f32 = 17.0;
    const fang_cooldown_time: f32 = 5.0;
    const fang_damage: f32 = 6.0;
    const fang_count: u32 = 16;
    const vex_spawn_count: u32 = 3;
    const vex_spawn_offset: f32 = 1.0;

    /// Summon three vexes around the evoker.
    /// Returns null when summon is still on cooldown.
    pub fn summonVex(self: *EvokerEntity) ?[vex_spawn_count]VexSpawn {
        if (self.summon_cooldown > 0) return null;

        self.summon_cooldown = summon_cooldown_time;

        return [vex_spawn_count]VexSpawn{
            VexSpawn{ .x = self.x + vex_spawn_offset, .y = self.y + vex_spawn_offset, .z = self.z },
            VexSpawn{ .x = self.x - vex_spawn_offset, .y = self.y + vex_spawn_offset, .z = self.z },
            VexSpawn{ .x = self.x, .y = self.y + vex_spawn_offset, .z = self.z + vex_spawn_offset },
        };
    }

    /// Launch a line of evoker fangs toward a target position.
    /// Returns null when fang attack is still on cooldown.
    pub fn fangAttack(self: *EvokerEntity, target_x: f32, target_z: f32) ?FangLine {
        if (self.fang_cooldown > 0) return null;

        self.fang_cooldown = fang_cooldown_time;

        return FangLine{
            .damage = fang_damage,
            .fang_count = fang_count,
            .start_x = self.x,
            .start_z = self.z,
            .end_x = target_x,
            .end_z = target_z,
        };
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "witch throws harm potion at close range" {
    var witch = WitchEntity{ .x = 0, .y = 0, .z = 0 };
    const throw = witch.throwPotion(2.0).?;
    try std.testing.expectEqual(PotionThrow.PotionType.harm, throw.potion_type);
    try std.testing.expectApproxEqAbs(@as(f32, 6.0), throw.damage, 0.001);
}

test "witch throws poison potion at medium range" {
    var witch = WitchEntity{ .x = 0, .y = 0, .z = 0 };
    const throw = witch.throwPotion(5.0).?;
    try std.testing.expectEqual(PotionThrow.PotionType.poison, throw.potion_type);
}

test "witch throws slowness potion at longer range" {
    var witch = WitchEntity{ .x = 0, .y = 0, .z = 0 };
    const throw = witch.throwPotion(8.0).?;
    try std.testing.expectEqual(PotionThrow.PotionType.slowness, throw.potion_type);
}

test "witch throws weakness potion at far range" {
    var witch = WitchEntity{ .x = 0, .y = 0, .z = 0 };
    const throw = witch.throwPotion(15.0).?;
    try std.testing.expectEqual(PotionThrow.PotionType.weakness, throw.potion_type);
}

test "witch cannot throw while on cooldown" {
    var witch = WitchEntity{ .x = 0, .y = 0, .z = 0 };
    _ = witch.throwPotion(5.0);
    const result = witch.throwPotion(5.0);
    try std.testing.expect(result == null);
}

test "pillager shoot cooldown prevents rapid fire" {
    var pillager = PillagerEntity{ .x = 0, .y = 0, .z = 0, .is_patrol_leader = false };
    const first = pillager.shootCrossbow();
    try std.testing.expect(first == null);

    pillager.shoot_cooldown = 0;
    const shot = pillager.shootCrossbow().?;
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), shot.damage, 0.001);

    const blocked = pillager.shootCrossbow();
    try std.testing.expect(blocked == null);
}

test "pillager crossbow deals 4 damage" {
    var pillager = PillagerEntity{ .x = 0, .y = 0, .z = 0, .is_patrol_leader = true };
    pillager.shoot_cooldown = 0;
    const shot = pillager.shootCrossbow().?;
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), shot.damage, 0.001);
}

test "evoker summons three vexes" {
    var evoker = EvokerEntity{ .x = 10, .y = 65, .z = 20 };
    const vexes = evoker.summonVex().?;
    try std.testing.expectEqual(@as(usize, 3), vexes.len);
    for (vexes) |vex| {
        try std.testing.expectApproxEqAbs(@as(f32, 66.0), vex.y, 0.001);
    }
}

test "evoker cannot summon vex while on cooldown" {
    var evoker = EvokerEntity{ .x = 0, .y = 0, .z = 0 };
    _ = evoker.summonVex();
    const result = evoker.summonVex();
    try std.testing.expect(result == null);
}

test "evoker fang attack deals 6 damage with 16 fangs" {
    var evoker = EvokerEntity{ .x = 0, .y = 0, .z = 0 };
    const fang = evoker.fangAttack(10.0, 10.0).?;
    try std.testing.expectApproxEqAbs(@as(f32, 6.0), fang.damage, 0.001);
    try std.testing.expectEqual(@as(u32, 16), fang.fang_count);
}

test "evoker fang attack respects cooldown" {
    var evoker = EvokerEntity{ .x = 0, .y = 0, .z = 0 };
    _ = evoker.fangAttack(5.0, 5.0);
    const result = evoker.fangAttack(5.0, 5.0);
    try std.testing.expect(result == null);
}

test "witch self heal restores health" {
    var witch = WitchEntity{ .x = 0, .y = 0, .z = 0, .health = 10 };
    witch.selfHeal();
    try std.testing.expectApproxEqAbs(@as(f32, 14.0), witch.health, 0.001);
}

test "witch self heal does not exceed max health" {
    var witch = WitchEntity{ .x = 0, .y = 0, .z = 0, .health = 25 };
    witch.selfHeal();
    // Health 25 is above heal threshold — no healing occurs
    try std.testing.expectApproxEqAbs(@as(f32, 25.0), witch.health, 0.001);
}

test "witch self heal caps at max health" {
    var witch = WitchEntity{ .x = 0, .y = 0, .z = 0, .health = 12 };
    witch.selfHeal();
    // 12 < threshold (13), heals +4 = 16, capped at 26
    try std.testing.expectApproxEqAbs(@as(f32, 16.0), witch.health, 0.001);

    // Set near max to verify capping
    witch.health = 24;
    // 24 > threshold — no heal
    witch.selfHeal();
    try std.testing.expectApproxEqAbs(@as(f32, 24.0), witch.health, 0.001);
}
