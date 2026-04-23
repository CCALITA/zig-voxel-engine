/// Hostile mob targeting and attack logic for melee, ranged, and explosive combat types.
/// Each mob type has a CombatConfig defining detection range, attack range, damage,
/// knockback, and cooldown. The updateCombat function returns a CombatAction
/// (idle/chase/attack/explode) based on distance to the player and cooldown state.
const std = @import("std");

pub const MobCombatType = enum {
    melee_zombie,
    melee_spider,
    ranged_skeleton,
    ranged_blaze,
    creeper_explode,
};

pub const CombatConfig = struct {
    detection_range: f32,
    attack_range: f32,
    damage: f32,
    knockback: f32,
    cooldown: f32,
};

pub fn getConfig(t: MobCombatType) CombatConfig {
    return switch (t) {
        .melee_zombie => .{
            .detection_range = 35.0,
            .attack_range = 2.0,
            .damage = 4.0,
            .knockback = 1.0,
            .cooldown = 1.0,
        },
        .melee_spider => .{
            .detection_range = 16.0,
            .attack_range = 2.5,
            .damage = 3.0,
            .knockback = 0.5,
            .cooldown = 0.8,
        },
        .ranged_skeleton => .{
            .detection_range = 16.0,
            .attack_range = 15.0,
            .damage = 3.0,
            .knockback = 0.4,
            .cooldown = 2.0,
        },
        .ranged_blaze => .{
            .detection_range = 48.0,
            .attack_range = 16.0,
            .damage = 5.0,
            .knockback = 0.3,
            .cooldown = 3.0,
        },
        .creeper_explode => .{
            .detection_range = 16.0,
            .attack_range = 3.0,
            .damage = 43.0,
            .knockback = 2.0,
            .cooldown = 1.5,
        },
    };
}

pub const CombatAction = enum {
    idle,
    chase,
    attack,
    explode,
};

pub const CombatState = struct {
    target_x: f32,
    target_y: f32,
    target_z: f32,
    attack_cooldown: f32,
    is_engaged: bool,
    chase_speed: f32,

    pub fn init() CombatState {
        return .{
            .target_x = 0,
            .target_y = 0,
            .target_z = 0,
            .attack_cooldown = 0,
            .is_engaged = false,
            .chase_speed = 1.0,
        };
    }
};

/// Compute the Euclidean distance between mob and player positions.
fn distance(mx: f32, my: f32, mz: f32, px: f32, py: f32, pz: f32) f32 {
    const dx = px - mx;
    const dy = py - my;
    const dz = pz - mz;
    return @sqrt(dx * dx + dy * dy + dz * dz);
}

/// Advance combat state by dt seconds and return the action the game loop
/// should execute. The returned CombatState is a new value (immutable update).
pub fn updateCombat(
    state: CombatState,
    mob_x: f32,
    mob_y: f32,
    mob_z: f32,
    player_x: f32,
    player_y: f32,
    player_z: f32,
    dt: f32,
    combat_type: MobCombatType,
) struct { state: CombatState, action: CombatAction } {
    const config = getConfig(combat_type);
    const dist = distance(mob_x, mob_y, mob_z, player_x, player_y, player_z);

    var next = state;

    // Tick cooldown.
    next.attack_cooldown = @max(next.attack_cooldown - dt, 0);

    // Player outside detection range: disengage.
    if (dist > config.detection_range) {
        next.is_engaged = false;
        return .{ .state = next, .action = .idle };
    }

    // Player inside detection range: engage and track.
    next.is_engaged = true;
    next.target_x = player_x;
    next.target_y = player_y;
    next.target_z = player_z;

    // Player inside attack range and cooldown ready.
    if (dist <= config.attack_range and next.attack_cooldown <= 0) {
        next.attack_cooldown = config.cooldown;
        if (combat_type == .creeper_explode) {
            return .{ .state = next, .action = .explode };
        }
        return .{ .state = next, .action = .attack };
    }

    // Player inside detection range but outside attack range (or on cooldown): chase.
    return .{ .state = next, .action = .chase };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "zombie config has correct values" {
    const cfg = getConfig(.melee_zombie);
    try std.testing.expectApproxEqAbs(@as(f32, 35.0), cfg.detection_range, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), cfg.attack_range, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), cfg.damage, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), cfg.knockback, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), cfg.cooldown, 0.001);
}

test "spider config has shorter cooldown than zombie" {
    const spider = getConfig(.melee_spider);
    const zombie = getConfig(.melee_zombie);
    try std.testing.expect(spider.cooldown < zombie.cooldown);
}

test "skeleton config is ranged" {
    const cfg = getConfig(.ranged_skeleton);
    try std.testing.expect(cfg.attack_range > 10.0);
}

test "blaze has longest detection range" {
    const blaze = getConfig(.ranged_blaze);
    const zombie = getConfig(.melee_zombie);
    const spider = getConfig(.melee_spider);
    const skeleton = getConfig(.ranged_skeleton);
    const creeper = getConfig(.creeper_explode);
    try std.testing.expect(blaze.detection_range >= zombie.detection_range);
    try std.testing.expect(blaze.detection_range >= spider.detection_range);
    try std.testing.expect(blaze.detection_range >= skeleton.detection_range);
    try std.testing.expect(blaze.detection_range >= creeper.detection_range);
}

test "idle when player out of detection range" {
    const state = CombatState.init();
    const result = updateCombat(state, 0, 0, 0, 100, 0, 100, 0.1, .melee_zombie);
    try std.testing.expectEqual(CombatAction.idle, result.action);
    try std.testing.expect(!result.state.is_engaged);
}

test "chase when player in detection range but outside attack range" {
    const state = CombatState.init();
    const result = updateCombat(state, 0, 0, 0, 10, 0, 0, 0.1, .melee_zombie);
    try std.testing.expectEqual(CombatAction.chase, result.action);
    try std.testing.expect(result.state.is_engaged);
}

test "attack when player in attack range and cooldown ready" {
    const state = CombatState.init();
    const result = updateCombat(state, 0, 0, 0, 1, 0, 0, 0.1, .melee_zombie);
    try std.testing.expectEqual(CombatAction.attack, result.action);
    try std.testing.expect(result.state.attack_cooldown > 0);
}

test "chase when player in attack range but on cooldown" {
    var state = CombatState.init();
    state.attack_cooldown = 0.5;
    const result = updateCombat(state, 0, 0, 0, 1, 0, 0, 0.1, .melee_zombie);
    try std.testing.expectEqual(CombatAction.chase, result.action);
}

test "cooldown decrements over time" {
    var state = CombatState.init();
    state.attack_cooldown = 1.0;
    // Player far away so we just tick cooldown.
    const result = updateCombat(state, 0, 0, 0, 100, 0, 100, 0.3, .melee_zombie);
    try std.testing.expectApproxEqAbs(@as(f32, 0.7), result.state.attack_cooldown, 0.001);
}

test "creeper explodes instead of attacks" {
    const state = CombatState.init();
    const result = updateCombat(state, 0, 0, 0, 2, 0, 0, 0.1, .creeper_explode);
    try std.testing.expectEqual(CombatAction.explode, result.action);
}

test "target tracks player position on engage" {
    const state = CombatState.init();
    const result = updateCombat(state, 0, 0, 0, 5, 3, 7, 0.1, .melee_spider);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), result.state.target_x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), result.state.target_y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 7.0), result.state.target_z, 0.001);
}

test "skeleton attacks at long range" {
    const state = CombatState.init();
    const result = updateCombat(state, 0, 0, 0, 14, 0, 0, 0.1, .ranged_skeleton);
    try std.testing.expectEqual(CombatAction.attack, result.action);
}

test "attack resets cooldown then chase until ready" {
    const state = CombatState.init();
    // First tick: attack.
    const r1 = updateCombat(state, 0, 0, 0, 1, 0, 0, 0.1, .melee_zombie);
    try std.testing.expectEqual(CombatAction.attack, r1.action);
    try std.testing.expect(r1.state.attack_cooldown > 0);

    // Second tick with remaining cooldown: chase.
    const r2 = updateCombat(r1.state, 0, 0, 0, 1, 0, 0, 0.1, .melee_zombie);
    try std.testing.expectEqual(CombatAction.chase, r2.action);
}

test "combat state init defaults" {
    const state = CombatState.init();
    try std.testing.expectApproxEqAbs(@as(f32, 0), state.target_x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), state.target_y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), state.target_z, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), state.attack_cooldown, 0.001);
    try std.testing.expect(!state.is_engaged);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), state.chase_speed, 0.001);
}

test "disengage when player leaves detection range" {
    var state = CombatState.init();
    state.is_engaged = true;
    const result = updateCombat(state, 0, 0, 0, 200, 0, 200, 0.1, .melee_zombie);
    try std.testing.expectEqual(CombatAction.idle, result.action);
    try std.testing.expect(!result.state.is_engaged);
}

test "cooldown does not go below zero" {
    var state = CombatState.init();
    state.attack_cooldown = 0.1;
    const result = updateCombat(state, 0, 0, 0, 200, 0, 200, 1.0, .melee_zombie);
    try std.testing.expectApproxEqAbs(@as(f32, 0), result.state.attack_cooldown, 0.001);
}

test "blaze attacks at 16 block range" {
    const state = CombatState.init();
    const result = updateCombat(state, 0, 0, 0, 15, 0, 0, 0.1, .ranged_blaze);
    try std.testing.expectEqual(CombatAction.attack, result.action);
}

test "immutable update does not modify input state" {
    const state = CombatState.init();
    const result = updateCombat(state, 0, 0, 0, 1, 0, 0, 0.1, .melee_zombie);
    // Original state should still be disengaged with zero cooldown.
    try std.testing.expect(!state.is_engaged);
    try std.testing.expectApproxEqAbs(@as(f32, 0), state.attack_cooldown, 0.001);
    // Result state should be engaged with nonzero cooldown.
    try std.testing.expect(result.state.is_engaged);
    try std.testing.expect(result.state.attack_cooldown > 0);
}
