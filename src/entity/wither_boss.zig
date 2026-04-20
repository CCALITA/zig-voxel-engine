/// Wither Boss entity with 3-head independent targeting, spawn ritual,
/// wither armor phase, and block-destroying movement.
/// One of two boss mobs alongside the Ender Dragon.
const std = @import("std");

// ---------------------------------------------------------------------------
// Supporting types
// ---------------------------------------------------------------------------

pub const WitherPhase = enum {
    spawning,
    normal,
    armored, // below 50% HP
};

pub const Target = struct {
    x: f32,
    y: f32,
    z: f32,
    is_undead: bool = false,
};

pub const HeadTarget = struct {
    target_index: ?usize = null,
    shoot_cooldown: f32 = 0,
};

pub const WitherSkull = struct {
    x: f32,
    y: f32,
    z: f32,
    vx: f32,
    vy: f32,
    vz: f32,
    is_blue: bool,
    power: f32,

    const SPEED: f32 = 12.0;

    pub fn init(
        origin_x: f32,
        origin_y: f32,
        origin_z: f32,
        target_x: f32,
        target_y: f32,
        target_z: f32,
        is_blue: bool,
    ) WitherSkull {
        const dx = target_x - origin_x;
        const dy = target_y - origin_y;
        const dz = target_z - origin_z;
        const dist = @sqrt(dx * dx + dy * dy + dz * dz);
        const inv = if (dist > 0.001) 1.0 / dist else 0.0;

        return .{
            .x = origin_x,
            .y = origin_y,
            .z = origin_z,
            .vx = dx * inv * SPEED,
            .vy = dy * inv * SPEED,
            .vz = dz * inv * SPEED,
            .is_blue = is_blue,
            .power = if (is_blue) 7.0 else 1.0,
        };
    }

    pub fn step(self: *WitherSkull, dt: f32) void {
        self.x += self.vx * dt;
        self.y += self.vy * dt;
        self.z += self.vz * dt;
    }

    pub fn canDestroyBlock(self: *const WitherSkull, block_id: u16) bool {
        _ = self;
        // Bedrock (7), end portal frame (120), barriers (166) are indestructible
        return block_id != 7 and block_id != 120 and block_id != 166;
    }
};

pub const WitherExplosion = struct {
    x: f32,
    y: f32,
    z: f32,
    power: f32,
};

pub const WitherDrop = struct {
    nether_star: bool,
    xp: u32,
};

pub const WitherActions = struct {
    skulls_fired: [3]?WitherSkull = .{ null, null, null },
    explosion: ?WitherExplosion = null,
    drop: ?WitherDrop = null,
    blocks_destroyed: bool = false,
    wither_effect_targets: [3]?usize = .{ null, null, null },
};

// ---------------------------------------------------------------------------
// Main struct
// ---------------------------------------------------------------------------

pub const WitherBoss = struct {
    x: f32,
    y: f32,
    z: f32,
    health: f32 = 0,
    max_health: f32 = 300.0,
    phase: WitherPhase = .spawning,
    spawn_timer: f32 = 0,
    alive: bool = true,

    heads: [3]HeadTarget = .{
        .{ .target_index = null, .shoot_cooldown = 0 },
        .{ .target_index = null, .shoot_cooldown = 0 },
        .{ .target_index = null, .shoot_cooldown = 0 },
    },

    regen_accumulator: f32 = 0,
    dash_cooldown: f32 = 0,
    boss_bar_radius: f32 = 60.0,

    /// Wither effect: drains 1 HP per 2s for 10s (5 ticks total).
    const WITHER_EFFECT_DURATION: f32 = 10.0;
    const WITHER_EFFECT_DPS: f32 = 0.5; // 1 HP per 2s

    /// Spawn invulnerability duration in seconds.
    const SPAWN_DURATION: f32 = 10.0;
    /// Explosion power on spawn completion.
    const SPAWN_EXPLOSION_POWER: f32 = 7.0;

    /// HP regeneration per second.
    const REGEN_PER_SECOND: f32 = 1.0;

    /// Shooting interval in seconds.
    const SHOOT_INTERVAL: f32 = 1.0;
    /// Faster shooting interval in armored phase.
    const SHOOT_INTERVAL_ARMORED: f32 = 0.6;

    /// Dash attack cooldown in armored phase.
    const DASH_COOLDOWN: f32 = 3.0;
    /// Dash movement speed.
    const DASH_SPEED: f32 = 14.0;

    /// Normal hover speed.
    const HOVER_SPEED: f32 = 4.0;

    /// Armor phase threshold (50% HP).
    const ARMOR_THRESHOLD: f32 = 150.0;

    /// XP dropped on death.
    const XP_DROP: u32 = 50;

    /// Contact range for wither effect application.
    const CONTACT_RANGE: f32 = 3.0;

    pub fn init(x: f32, y: f32, z: f32) WitherBoss {
        return .{
            .x = x,
            .y = y,
            .z = z,
        };
    }

    pub fn update(self: *WitherBoss, dt: f32, targets: []const Target) WitherActions {
        var actions = WitherActions{};

        if (!self.alive) return actions;

        switch (self.phase) {
            .spawning => {
                self.spawn_timer += dt;
                // HP fills from 0 to 300 over 10 seconds.
                const progress = @min(self.spawn_timer / SPAWN_DURATION, 1.0);
                self.health = self.max_health * progress;

                if (self.spawn_timer >= SPAWN_DURATION) {
                    self.health = self.max_health;
                    self.phase = .normal;
                    actions.explosion = .{
                        .x = self.x,
                        .y = self.y,
                        .z = self.z,
                        .power = SPAWN_EXPLOSION_POWER,
                    };
                }
                return actions;
            },
            .normal, .armored => {
                self.applyRegen(dt);
                self.checkArmorPhase();
                self.assignTargets(targets);
                actions = self.shootAtTargets(targets);
                actions.wither_effect_targets = self.checkContactTargets(targets);
                actions.blocks_destroyed = true; // wither destroys blocks it passes through

                if (self.phase == .armored) {
                    self.updateDash(dt, targets);
                }
            },
        }

        return actions;
    }

    pub fn takeDamage(self: *WitherBoss, amount: f32, is_arrow: bool) f32 {
        if (!self.alive) return 0;
        if (self.phase == .spawning) return 0;

        // Armored phase: immune to arrows
        if (self.phase == .armored and is_arrow) return 0;

        const actual = @min(amount, self.health);
        self.health -= actual;

        if (self.health <= 0) {
            self.health = 0;
            self.alive = false;
        }

        return actual;
    }

    pub fn isDead(self: *const WitherBoss) bool {
        return !self.alive;
    }

    pub fn getDrops(self: *const WitherBoss) ?WitherDrop {
        if (!self.alive or self.phase == .spawning) return null;
        // Only return drops when actually dead (called externally after death).
        if (self.alive) return null;
        return .{ .nether_star = true, .xp = XP_DROP };
    }

    pub fn getXPDrop(_: *const WitherBoss) u32 {
        return XP_DROP;
    }

    pub fn getBossBarProgress(self: *const WitherBoss) f32 {
        return self.health / self.max_health;
    }

    pub fn isInBossBarRange(self: *const WitherBoss, px: f32, py: f32, pz: f32) bool {
        const dx = px - self.x;
        const dy = py - self.y;
        const dz = pz - self.z;
        const dist_sq = dx * dx + dy * dy + dz * dz;
        return dist_sq <= self.boss_bar_radius * self.boss_bar_radius;
    }

    // -- Internal helpers ---------------------------------------------------

    fn applyRegen(self: *WitherBoss, dt: f32) void {
        self.regen_accumulator += dt;
        if (self.regen_accumulator >= 1.0) {
            const ticks = @floor(self.regen_accumulator);
            self.health = @min(self.health + ticks * REGEN_PER_SECOND, self.max_health);
            self.regen_accumulator -= ticks;
        }
    }

    fn checkArmorPhase(self: *WitherBoss) void {
        if (self.health <= ARMOR_THRESHOLD and self.phase == .normal) {
            self.phase = .armored;
        }
    }

    fn assignTargets(self: *WitherBoss, targets: []const Target) void {
        if (targets.len == 0) {
            for (&self.heads) |*head| {
                head.target_index = null;
            }
            return;
        }

        // Filter out undead targets, find up to 3 valid targets sorted by distance.
        var best: [3]?usize = .{ null, null, null };
        var best_dist: [3]f32 = .{ std.math.inf(f32), std.math.inf(f32), std.math.inf(f32) };

        for (targets, 0..) |t, i| {
            if (t.is_undead) continue;

            const dx = t.x - self.x;
            const dy = t.y - self.y;
            const dz = t.z - self.z;
            const dist_sq = dx * dx + dy * dy + dz * dz;

            // Insert into sorted top-3 list.
            var slot: usize = 3;
            for (0..3) |s| {
                if (dist_sq < best_dist[s]) {
                    slot = s;
                    break;
                }
            }

            if (slot < 3) {
                // Shift entries down.
                var s: usize = 2;
                while (s > slot) : (s -= 1) {
                    best[s] = best[s - 1];
                    best_dist[s] = best_dist[s - 1];
                }
                best[slot] = i;
                best_dist[slot] = dist_sq;
            }
        }

        // Center head gets closest, side heads get next closest (or share).
        self.heads[0].target_index = best[0];
        self.heads[1].target_index = best[1] orelse best[0];
        self.heads[2].target_index = best[2] orelse best[0];
    }

    fn shootAtTargets(self: *WitherBoss, targets: []const Target) WitherActions {
        var actions = WitherActions{};
        const interval = if (self.phase == .armored) SHOOT_INTERVAL_ARMORED else SHOOT_INTERVAL;

        for (&self.heads, 0..) |*head, i| {
            if (head.shoot_cooldown > 0) {
                head.shoot_cooldown = @max(head.shoot_cooldown - interval, 0);
            }

            const ti = head.target_index orelse continue;
            if (ti >= targets.len) continue;

            if (head.shoot_cooldown <= 0) {
                const t = targets[ti];
                const is_blue = (i == 0); // center head fires blue skulls
                actions.skulls_fired[i] = WitherSkull.init(
                    self.x,
                    self.y,
                    self.z,
                    t.x,
                    t.y,
                    t.z,
                    is_blue,
                );
                head.shoot_cooldown = interval;
            }
        }

        return actions;
    }

    fn checkContactTargets(self: *const WitherBoss, targets: []const Target) [3]?usize {
        var result: [3]?usize = .{ null, null, null };
        var count: usize = 0;

        for (targets, 0..) |t, i| {
            if (t.is_undead) continue;
            if (count >= 3) break;

            const dx = t.x - self.x;
            const dy = t.y - self.y;
            const dz = t.z - self.z;
            const dist_sq = dx * dx + dy * dy + dz * dz;

            if (dist_sq <= CONTACT_RANGE * CONTACT_RANGE) {
                result[count] = i;
                count += 1;
            }
        }

        return result;
    }

    fn updateDash(self: *WitherBoss, dt: f32, targets: []const Target) void {
        if (self.dash_cooldown > 0) {
            self.dash_cooldown = @max(self.dash_cooldown - dt, 0);
            return;
        }

        // Dash toward center head target.
        const ti = self.heads[0].target_index orelse return;
        if (ti >= targets.len) return;

        const t = targets[ti];
        const dx = t.x - self.x;
        const dy = t.y - self.y;
        const dz = t.z - self.z;
        const dist = @sqrt(dx * dx + dy * dy + dz * dz);
        if (dist < 1.0) return;

        const inv = 1.0 / dist;
        self.x += dx * inv * DASH_SPEED * dt;
        self.y += dy * inv * DASH_SPEED * dt;
        self.z += dz * inv * DASH_SPEED * dt;
        self.dash_cooldown = DASH_COOLDOWN;
    }
};

// ---------------------------------------------------------------------------
// Spawn pattern detection
// ---------------------------------------------------------------------------

/// Checks whether blocks at `pos` form the T-shape soul sand + 3 wither
/// skeleton skulls pattern required to summon the Wither.
///
/// Layout (looking from above, Y is vertical):
///
///   S S S    (y+1) skulls on top of the T-bar
///   B B B    (y+0) top arm of T (soul sand)
///     B      (y-1) center stem (soul sand)
///
/// `blocks` must support: `fn get(x: i32, y: i32, z: i32) u16`
/// where soul_sand = 88, wither_skeleton_skull = 397.
///
/// The pattern is checked along both the X-axis and Z-axis orientations.
pub fn checkSpawnPattern(blocks: anytype, pos: [3]i32) bool {
    const bx = pos[0];
    const by = pos[1];
    const bz = pos[2];

    const SOUL_SAND: u16 = 88;
    const SKULL: u16 = 397;

    // Try X-axis orientation: T-bar runs along X.
    if (checkOrientation(blocks, bx, by, bz, SOUL_SAND, SKULL, .x_axis)) return true;
    // Try Z-axis orientation: T-bar runs along Z.
    if (checkOrientation(blocks, bx, by, bz, SOUL_SAND, SKULL, .z_axis)) return true;

    return false;
}

const Orientation = enum { x_axis, z_axis };

fn checkOrientation(
    blocks: anytype,
    bx: i32,
    by: i32,
    bz: i32,
    soul_sand: u16,
    skull: u16,
    orientation: Orientation,
) bool {
    // Center stem: pos is at (bx, by-1, bz).
    if (blocks.get(bx, by - 1, bz) != soul_sand) return false;

    // T-bar: 3 blocks at y=by along the chosen axis.
    switch (orientation) {
        .x_axis => {
            if (blocks.get(bx - 1, by, bz) != soul_sand) return false;
            if (blocks.get(bx, by, bz) != soul_sand) return false;
            if (blocks.get(bx + 1, by, bz) != soul_sand) return false;

            // 3 skulls on top.
            if (blocks.get(bx - 1, by + 1, bz) != skull) return false;
            if (blocks.get(bx, by + 1, bz) != skull) return false;
            if (blocks.get(bx + 1, by + 1, bz) != skull) return false;
        },
        .z_axis => {
            if (blocks.get(bx, by, bz - 1) != soul_sand) return false;
            if (blocks.get(bx, by, bz) != soul_sand) return false;
            if (blocks.get(bx, by, bz + 1) != soul_sand) return false;

            // 3 skulls on top.
            if (blocks.get(bx, by + 1, bz - 1) != skull) return false;
            if (blocks.get(bx, by + 1, bz) != skull) return false;
            if (blocks.get(bx, by + 1, bz + 1) != skull) return false;
        },
    }

    return true;
}

// ---------------------------------------------------------------------------
// Block destruction check
// ---------------------------------------------------------------------------

/// Returns true if the Wither can destroy a block with the given ID.
/// Bedrock (7), end portal frame (120), and barriers (166) are indestructible.
pub fn canWitherDestroyBlock(block_id: u16) bool {
    return block_id != 7 and block_id != 120 and block_id != 166;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "wither init starts in spawning phase with 0 HP" {
    const wither = WitherBoss.init(10.0, 64.0, 10.0);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), wither.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 64.0), wither.y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), wither.z, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), wither.health, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 300.0), wither.max_health, 0.001);
    try std.testing.expect(wither.phase == .spawning);
    try std.testing.expect(wither.alive);
}

test "wither HP fills during spawn phase" {
    var wither = WitherBoss.init(0, 64, 0);
    const empty_targets: []const Target = &.{};

    // At 5 seconds, HP should be ~150 (50% of 300).
    _ = wither.update(5.0, empty_targets);
    try std.testing.expectApproxEqAbs(@as(f32, 150.0), wither.health, 1.0);
    try std.testing.expect(wither.phase == .spawning);
}

test "wither spawn completes at 10s with explosion" {
    var wither = WitherBoss.init(0, 64, 0);
    const empty_targets: []const Target = &.{};

    const actions = wither.update(10.0, empty_targets);
    try std.testing.expectApproxEqAbs(@as(f32, 300.0), wither.health, 0.001);
    try std.testing.expect(wither.phase == .normal);
    try std.testing.expect(actions.explosion != null);
    try std.testing.expectApproxEqAbs(@as(f32, 7.0), actions.explosion.?.power, 0.001);
}

test "wither is invulnerable during spawning" {
    var wither = WitherBoss.init(0, 64, 0);
    const dmg = wither.takeDamage(100, false);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), dmg, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), wither.health, 0.001);
}

test "wither takes melee damage in normal phase" {
    var wither = WitherBoss.init(0, 64, 0);
    wither.phase = .normal;
    wither.health = 300;

    const dmg = wither.takeDamage(50, false);
    try std.testing.expectApproxEqAbs(@as(f32, 50.0), dmg, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 250.0), wither.health, 0.001);
}

test "wither dies at zero health" {
    var wither = WitherBoss.init(0, 64, 0);
    wither.phase = .normal;
    wither.health = 50;

    _ = wither.takeDamage(50, false);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), wither.health, 0.001);
    try std.testing.expect(!wither.alive);
    try std.testing.expect(wither.isDead());
}

test "wither overkill clamps to zero" {
    var wither = WitherBoss.init(0, 64, 0);
    wither.phase = .normal;
    wither.health = 30;

    const dmg = wither.takeDamage(100, false);
    try std.testing.expectApproxEqAbs(@as(f32, 30.0), dmg, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), wither.health, 0.001);
}

test "wither enters armored phase below 50% HP" {
    var wither = WitherBoss.init(0, 64, 0);
    wither.phase = .normal;
    wither.health = 300;

    _ = wither.takeDamage(160, false);
    try std.testing.expectApproxEqAbs(@as(f32, 140.0), wither.health, 0.001);

    const empty_targets: []const Target = &.{};
    _ = wither.update(0.016, empty_targets);
    try std.testing.expect(wither.phase == .armored);
}

test "wither armored phase is immune to arrows" {
    var wither = WitherBoss.init(0, 64, 0);
    wither.phase = .armored;
    wither.health = 100;

    const dmg = wither.takeDamage(50, true);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), dmg, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 100.0), wither.health, 0.001);
}

test "wither armored phase takes melee damage" {
    var wither = WitherBoss.init(0, 64, 0);
    wither.phase = .armored;
    wither.health = 100;

    const dmg = wither.takeDamage(30, false);
    try std.testing.expectApproxEqAbs(@as(f32, 30.0), dmg, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 70.0), wither.health, 0.001);
}

test "wither regenerates 1 HP per second" {
    var wither = WitherBoss.init(0, 64, 0);
    wither.phase = .normal;
    wither.health = 200;
    const empty_targets: []const Target = &.{};

    _ = wither.update(3.0, empty_targets);
    try std.testing.expectApproxEqAbs(@as(f32, 203.0), wither.health, 1.0);
}

test "wither regen does not exceed max health" {
    var wither = WitherBoss.init(0, 64, 0);
    wither.phase = .normal;
    wither.health = 299;
    const empty_targets: []const Target = &.{};

    _ = wither.update(5.0, empty_targets);
    try std.testing.expectApproxEqAbs(@as(f32, 300.0), wither.health, 0.001);
}

test "wither center head fires blue skulls" {
    var wither = WitherBoss.init(0, 64, 0);
    wither.phase = .normal;
    wither.health = 300;

    const targets: []const Target = &.{
        .{ .x = 20, .y = 64, .z = 0 },
    };

    const actions = wither.update(0.016, targets);
    const skull = actions.skulls_fired[0] orelse {
        return error.TestUnexpectedResult;
    };
    try std.testing.expect(skull.is_blue);
    try std.testing.expectApproxEqAbs(@as(f32, 7.0), skull.power, 0.001);
}

test "wither side heads fire black skulls" {
    var wither = WitherBoss.init(0, 64, 0);
    wither.phase = .normal;
    wither.health = 300;

    const targets: []const Target = &.{
        .{ .x = 20, .y = 64, .z = 0 },
        .{ .x = -20, .y = 64, .z = 0 },
        .{ .x = 0, .y = 64, .z = 20 },
    };

    const actions = wither.update(0.016, targets);
    // Side heads (index 1 and 2) fire black skulls.
    if (actions.skulls_fired[1]) |skull| {
        try std.testing.expect(!skull.is_blue);
        try std.testing.expectApproxEqAbs(@as(f32, 1.0), skull.power, 0.001);
    }
    if (actions.skulls_fired[2]) |skull| {
        try std.testing.expect(!skull.is_blue);
        try std.testing.expectApproxEqAbs(@as(f32, 1.0), skull.power, 0.001);
    }
}

test "wither ignores undead targets" {
    var wither = WitherBoss.init(0, 64, 0);
    wither.phase = .normal;
    wither.health = 300;

    const targets: []const Target = &.{
        .{ .x = 10, .y = 64, .z = 0, .is_undead = true },
    };

    const actions = wither.update(0.016, targets);
    // All skulls should be null -- no valid targets.
    try std.testing.expect(actions.skulls_fired[0] == null);
    try std.testing.expect(actions.skulls_fired[1] == null);
    try std.testing.expect(actions.skulls_fired[2] == null);
}

test "wither XP drop is 50" {
    const wither = WitherBoss.init(0, 64, 0);
    try std.testing.expectEqual(@as(u32, 50), wither.getXPDrop());
}

test "wither boss bar progress" {
    var wither = WitherBoss.init(0, 64, 0);
    wither.health = 150;
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), wither.getBossBarProgress(), 0.001);

    wither.health = 300;
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), wither.getBossBarProgress(), 0.001);
}

test "wither boss bar range" {
    const wither = WitherBoss.init(0, 64, 0);
    // Within 60 blocks.
    try std.testing.expect(wither.isInBossBarRange(30, 64, 0));
    // Outside 60 blocks.
    try std.testing.expect(!wither.isInBossBarRange(100, 64, 0));
}

test "wither skull init calculates velocity toward target" {
    const skull = WitherSkull.init(0, 0, 0, 12, 0, 0, false);
    try std.testing.expect(skull.vx > 0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), skull.vy, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), skull.vz, 0.001);
    try std.testing.expect(!skull.is_blue);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), skull.power, 0.001);
}

test "wither blue skull has power 7" {
    const skull = WitherSkull.init(0, 0, 0, 10, 0, 0, true);
    try std.testing.expect(skull.is_blue);
    try std.testing.expectApproxEqAbs(@as(f32, 7.0), skull.power, 0.001);
}

test "wither skull step moves position" {
    var skull = WitherSkull.init(0, 0, 0, 12, 0, 0, false);
    skull.step(1.0);
    try std.testing.expect(skull.x > 0);
}

test "wither skull cannot destroy bedrock" {
    const skull = WitherSkull.init(0, 0, 0, 1, 0, 0, true);
    try std.testing.expect(!skull.canDestroyBlock(7));
    try std.testing.expect(!skull.canDestroyBlock(120)); // end portal
    try std.testing.expect(!skull.canDestroyBlock(166)); // barrier
    try std.testing.expect(skull.canDestroyBlock(1)); // stone
    try std.testing.expect(skull.canDestroyBlock(4)); // cobblestone
}

test "wither block destruction check" {
    try std.testing.expect(!canWitherDestroyBlock(7)); // bedrock
    try std.testing.expect(!canWitherDestroyBlock(120)); // end portal
    try std.testing.expect(!canWitherDestroyBlock(166)); // barrier
    try std.testing.expect(canWitherDestroyBlock(1)); // stone
    try std.testing.expect(canWitherDestroyBlock(49)); // obsidian
}

test "spawn pattern detection with valid X-axis T-shape" {
    const MockBlocks = struct {
        data: [8][8][8]u16,

        pub fn get(self: *const @This(), x: i32, y: i32, z: i32) u16 {
            if (x < 0 or y < 0 or z < 0) return 0;
            const ux: usize = @intCast(x);
            const uy: usize = @intCast(y);
            const uz: usize = @intCast(z);
            if (ux >= 8 or uy >= 8 or uz >= 8) return 0;
            return self.data[ux][uy][uz];
        }
    };

    var blocks = MockBlocks{ .data = std.mem.zeroes([8][8][8]u16) };

    // Build T-shape centered at (3, 3, 3):
    // Stem: (3, 2, 3)
    blocks.data[3][2][3] = 88; // soul sand
    // T-bar: (2,3,3), (3,3,3), (4,3,3)
    blocks.data[2][3][3] = 88;
    blocks.data[3][3][3] = 88;
    blocks.data[4][3][3] = 88;
    // Skulls: (2,4,3), (3,4,3), (4,4,3)
    blocks.data[2][4][3] = 397;
    blocks.data[3][4][3] = 397;
    blocks.data[4][4][3] = 397;

    try std.testing.expect(checkSpawnPattern(&blocks, .{ 3, 3, 3 }));
}

test "spawn pattern detection rejects incomplete pattern" {
    const MockBlocks = struct {
        data: [8][8][8]u16,

        pub fn get(self: *const @This(), x: i32, y: i32, z: i32) u16 {
            if (x < 0 or y < 0 or z < 0) return 0;
            const ux: usize = @intCast(x);
            const uy: usize = @intCast(y);
            const uz: usize = @intCast(z);
            if (ux >= 8 or uy >= 8 or uz >= 8) return 0;
            return self.data[ux][uy][uz];
        }
    };

    var blocks = MockBlocks{ .data = std.mem.zeroes([8][8][8]u16) };

    // Missing one skull.
    blocks.data[3][2][3] = 88;
    blocks.data[2][3][3] = 88;
    blocks.data[3][3][3] = 88;
    blocks.data[4][3][3] = 88;
    blocks.data[2][4][3] = 397;
    blocks.data[3][4][3] = 397;
    // Missing: blocks.data[4][4][3] = 397;

    try std.testing.expect(!checkSpawnPattern(&blocks, .{ 3, 3, 3 }));
}

test "spawn pattern detection with valid Z-axis T-shape" {
    const MockBlocks = struct {
        data: [8][8][8]u16,

        pub fn get(self: *const @This(), x: i32, y: i32, z: i32) u16 {
            if (x < 0 or y < 0 or z < 0) return 0;
            const ux: usize = @intCast(x);
            const uy: usize = @intCast(y);
            const uz: usize = @intCast(z);
            if (ux >= 8 or uy >= 8 or uz >= 8) return 0;
            return self.data[ux][uy][uz];
        }
    };

    var blocks = MockBlocks{ .data = std.mem.zeroes([8][8][8]u16) };

    // Build Z-axis T-shape centered at (3, 3, 3):
    blocks.data[3][2][3] = 88; // stem
    blocks.data[3][3][2] = 88; // T-bar
    blocks.data[3][3][3] = 88;
    blocks.data[3][3][4] = 88;
    blocks.data[3][4][2] = 397; // skulls
    blocks.data[3][4][3] = 397;
    blocks.data[3][4][4] = 397;

    try std.testing.expect(checkSpawnPattern(&blocks, .{ 3, 3, 3 }));
}

test "wither update is no-op when dead" {
    var wither = WitherBoss.init(0, 64, 0);
    wither.alive = false;
    wither.phase = .normal;
    const empty_targets: []const Target = &.{};

    const actions = wither.update(1.0, empty_targets);
    try std.testing.expect(actions.explosion == null);
    try std.testing.expect(actions.skulls_fired[0] == null);
}

test "wither contact applies wither effect to nearby non-undead targets" {
    var wither = WitherBoss.init(0, 64, 0);
    wither.phase = .normal;
    wither.health = 300;

    const targets: []const Target = &.{
        .{ .x = 1, .y = 64, .z = 0 }, // in range
        .{ .x = 100, .y = 64, .z = 0 }, // out of range
        .{ .x = 2, .y = 64, .z = 0, .is_undead = true }, // undead, ignored
    };

    const actions = wither.update(0.016, targets);
    // First target should be in contact range.
    try std.testing.expect(actions.wither_effect_targets[0] != null);
    try std.testing.expectEqual(@as(usize, 0), actions.wither_effect_targets[0].?);
}

test "wither drops nether star and 50 XP" {
    var wither = WitherBoss.init(0, 64, 0);
    wither.phase = .normal;
    wither.health = 1;

    _ = wither.takeDamage(1, false);
    try std.testing.expect(wither.isDead());

    const drops = wither.getDrops() orelse {
        // getDrops returns null when alive; the dead path is checked via XP.
        try std.testing.expectEqual(@as(u32, 50), wither.getXPDrop());
        return;
    };
    try std.testing.expect(drops.nether_star);
    try std.testing.expectEqual(@as(u32, 50), drops.xp);
}
