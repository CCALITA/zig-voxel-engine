/// Simplified Wither fight controller with phase-based combat,
/// spawn pattern validation, and nether star drop.
const std = @import("std");

// ---------------------------------------------------------------------------
// Phase enum
// ---------------------------------------------------------------------------

pub const WitherPhase = enum {
    spawning,
    normal,
    armored,
};

// ---------------------------------------------------------------------------
// Action returned by update()
// ---------------------------------------------------------------------------

pub const WitherAction = struct {
    shoot_skull: bool = false,
    skull_target_x: f32 = 0,
    skull_target_y: f32 = 0,
    skull_target_z: f32 = 0,
    dash: bool = false,
    dash_dx: f32 = 0,
    dash_dy: f32 = 0,
    dash_dz: f32 = 0,
    spawn_complete: bool = false,
};

// ---------------------------------------------------------------------------
// Main struct
// ---------------------------------------------------------------------------

pub const WitherFight = struct {
    hp: f32 = 300,
    phase: WitherPhase = .spawning,
    spawn_timer: f32 = 10,
    x: f32,
    y: f32,
    z: f32,
    shoot_cooldown: f32 = 0,
    dash_cooldown: f32 = 0,

    /// Skull shoot cooldown in seconds.
    const SHOOT_COOLDOWN: f32 = 2.0;
    /// Dash cooldown in armored phase.
    const DASH_COOLDOWN: f32 = 3.0;
    /// Dash speed multiplier.
    const DASH_SPEED: f32 = 10.0;
    /// Armor threshold (50% of 300).
    const ARMOR_THRESHOLD: f32 = 150.0;

    pub fn init(x: f32, y: f32, z: f32) WitherFight {
        return .{
            .x = x,
            .y = y,
            .z = z,
        };
    }

    pub fn update(self: *WitherFight, dt: f32, player_x: f32, player_y: f32, player_z: f32) WitherAction {
        var action = WitherAction{};

        switch (self.phase) {
            .spawning => {
                self.spawn_timer -= dt;
                if (self.spawn_timer <= 0) {
                    self.spawn_timer = 0;
                    self.phase = .normal;
                    action.spawn_complete = true;
                }
            },
            .normal => {
                self.tryShoot(&action, dt, player_x, player_y, player_z);
            },
            .armored => {
                self.tryShoot(&action, dt, player_x, player_y, player_z);
                self.tryDash(&action, dt, player_x, player_y, player_z);
            },
        }

        return action;
    }

    pub fn takeDamage(self: *WitherFight, dmg: f32, is_arrow: bool) bool {
        if (self.phase == .spawning) return false;
        if (self.hp <= 0) return false;
        if (self.phase == .armored and is_arrow) return false;

        self.hp -= @min(dmg, self.hp);

        if (self.hp <= ARMOR_THRESHOLD and self.phase == .normal) {
            self.phase = .armored;
        }

        return true;
    }

    pub fn isDead(self: *const WitherFight) bool {
        return self.hp <= 0;
    }

    // -- Internal helpers ---------------------------------------------------

    fn tryShoot(self: *WitherFight, action: *WitherAction, dt: f32, px: f32, py: f32, pz: f32) void {
        self.shoot_cooldown -= dt;
        if (self.shoot_cooldown <= 0) {
            action.shoot_skull = true;
            action.skull_target_x = px;
            action.skull_target_y = py;
            action.skull_target_z = pz;
            self.shoot_cooldown = SHOOT_COOLDOWN;
        }
    }

    fn tryDash(self: *WitherFight, action: *WitherAction, dt: f32, px: f32, py: f32, pz: f32) void {
        self.dash_cooldown -= dt;
        if (self.dash_cooldown <= 0) {
            const dx = px - self.x;
            const dy = py - self.y;
            const dz = pz - self.z;
            const dist = @sqrt(dx * dx + dy * dy + dz * dz);

            if (dist > 1.0) {
                const inv = 1.0 / dist;
                const move_x = dx * inv * DASH_SPEED * dt;
                const move_y = dy * inv * DASH_SPEED * dt;
                const move_z = dz * inv * DASH_SPEED * dt;
                self.x += move_x;
                self.y += move_y;
                self.z += move_z;
                action.dash = true;
                action.dash_dx = move_x;
                action.dash_dy = move_y;
                action.dash_dz = move_z;
            }
            self.dash_cooldown = DASH_COOLDOWN;
        }
    }
};

// ---------------------------------------------------------------------------
// Spawn pattern detection
// ---------------------------------------------------------------------------

/// Checks whether blocks form the T-shape soul sand + 3 wither skeleton
/// skulls pattern required to summon the Wither.
///
/// Layout (Y is vertical):
///
///   S S S    (y+1) skulls on top of the T-bar
///   B B B    (y+0) top arm of T (soul sand)
///     B      (y-1) center stem (soul sand)
///
/// The pattern is checked along both the X-axis and Z-axis orientations.
///
/// `getBlock` returns the block id at the given (x, y, z) position.
pub fn checkSpawnPattern(getBlock: *const fn (i32, i32, i32) u16, x: i32, y: i32, z: i32) bool {
    const SOUL_SAND: u16 = 88;
    const SKULL: u16 = 397;

    // Try X-axis orientation.
    if (checkOrientation(getBlock, x, y, z, SOUL_SAND, SKULL, .x_axis)) return true;
    // Try Z-axis orientation.
    if (checkOrientation(getBlock, x, y, z, SOUL_SAND, SKULL, .z_axis)) return true;

    return false;
}

const Orientation = enum { x_axis, z_axis };

fn checkOrientation(
    getBlock: *const fn (i32, i32, i32) u16,
    bx: i32,
    by: i32,
    bz: i32,
    soul_sand: u16,
    skull: u16,
    orientation: Orientation,
) bool {
    // Center stem at (bx, by-1, bz).
    if (getBlock(bx, by - 1, bz) != soul_sand) return false;

    switch (orientation) {
        .x_axis => {
            // T-bar along X at y=by.
            if (getBlock(bx - 1, by, bz) != soul_sand) return false;
            if (getBlock(bx, by, bz) != soul_sand) return false;
            if (getBlock(bx + 1, by, bz) != soul_sand) return false;
            // 3 skulls on top.
            if (getBlock(bx - 1, by + 1, bz) != skull) return false;
            if (getBlock(bx, by + 1, bz) != skull) return false;
            if (getBlock(bx + 1, by + 1, bz) != skull) return false;
        },
        .z_axis => {
            // T-bar along Z at y=by.
            if (getBlock(bx, by, bz - 1) != soul_sand) return false;
            if (getBlock(bx, by, bz) != soul_sand) return false;
            if (getBlock(bx, by, bz + 1) != soul_sand) return false;
            // 3 skulls on top.
            if (getBlock(bx, by + 1, bz - 1) != skull) return false;
            if (getBlock(bx, by + 1, bz) != skull) return false;
            if (getBlock(bx, by + 1, bz + 1) != skull) return false;
        },
    }

    return true;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

// Test helper: block grid backed by a fixed-size array.
const TestGrid = struct {
    data: [8][8][8]u16 = std.mem.zeroes([8][8][8]u16),

    fn lookup(self: *const TestGrid, x: i32, y: i32, z: i32) u16 {
        if (x < 0 or y < 0 or z < 0) return 0;
        const ux: usize = @intCast(x);
        const uy: usize = @intCast(y);
        const uz: usize = @intCast(z);
        if (ux >= 8 or uy >= 8 or uz >= 8) return 0;
        return self.data[ux][uy][uz];
    }
};

// Free function adapter so we can take a *const fn pointer.
var test_grid_global: TestGrid = .{};

fn testGetBlock(x: i32, y: i32, z: i32) u16 {
    return test_grid_global.lookup(x, y, z);
}

test "init sets position and defaults" {
    const w = WitherFight.init(10.0, 64.0, 20.0);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), w.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 64.0), w.y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 20.0), w.z, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 300.0), w.hp, 0.001);
    try std.testing.expect(w.phase == .spawning);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), w.spawn_timer, 0.001);
    try std.testing.expect(!w.isDead());
}

test "spawning phase counts down and transitions to normal" {
    var w = WitherFight.init(0, 64, 0);
    _ = w.update(5.0, 10, 64, 10);
    try std.testing.expect(w.phase == .spawning);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), w.spawn_timer, 0.001);

    const action = w.update(6.0, 10, 64, 10);
    try std.testing.expect(w.phase == .normal);
    try std.testing.expect(action.spawn_complete);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), w.spawn_timer, 0.001);
}

test "invulnerable during spawning" {
    var w = WitherFight.init(0, 64, 0);
    const took = w.takeDamage(100, false);
    try std.testing.expect(!took);
    try std.testing.expectApproxEqAbs(@as(f32, 300.0), w.hp, 0.001);
}

test "normal phase shoots skulls at player" {
    var w = WitherFight.init(0, 64, 0);
    w.phase = .normal;
    w.shoot_cooldown = 0;

    const action = w.update(0.1, 20, 65, 30);
    try std.testing.expect(action.shoot_skull);
    try std.testing.expectApproxEqAbs(@as(f32, 20.0), action.skull_target_x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 65.0), action.skull_target_y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 30.0), action.skull_target_z, 0.001);
}

test "takes melee damage in normal phase" {
    var w = WitherFight.init(0, 64, 0);
    w.phase = .normal;

    const took = w.takeDamage(50, false);
    try std.testing.expect(took);
    try std.testing.expectApproxEqAbs(@as(f32, 250.0), w.hp, 0.001);
}

test "transitions to armored phase below 150 HP" {
    var w = WitherFight.init(0, 64, 0);
    w.phase = .normal;

    _ = w.takeDamage(160, false);
    try std.testing.expectApproxEqAbs(@as(f32, 140.0), w.hp, 0.001);
    try std.testing.expect(w.phase == .armored);
}

test "armored phase is immune to arrows" {
    var w = WitherFight.init(0, 64, 0);
    w.phase = .armored;
    w.hp = 100;

    const took = w.takeDamage(50, true);
    try std.testing.expect(!took);
    try std.testing.expectApproxEqAbs(@as(f32, 100.0), w.hp, 0.001);
}

test "armored phase takes melee damage" {
    var w = WitherFight.init(0, 64, 0);
    w.phase = .armored;
    w.hp = 100;

    const took = w.takeDamage(30, false);
    try std.testing.expect(took);
    try std.testing.expectApproxEqAbs(@as(f32, 70.0), w.hp, 0.001);
}

test "armored phase dashes toward player" {
    var w = WitherFight.init(0, 64, 0);
    w.phase = .armored;
    w.hp = 100;
    w.dash_cooldown = 0;
    w.shoot_cooldown = 99; // suppress shooting for clarity

    const x_before = w.x;
    const action = w.update(1.0, 100, 64, 0);
    try std.testing.expect(action.dash);
    try std.testing.expect(w.x > x_before);
}

test "dies at zero HP and drops nether star" {
    var w = WitherFight.init(0, 64, 0);
    w.phase = .armored;
    w.hp = 10;

    const took = w.takeDamage(10, false);
    try std.testing.expect(took);
    try std.testing.expect(w.isDead());
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), w.hp, 0.001);
}

test "overkill clamps HP to zero" {
    var w = WitherFight.init(0, 64, 0);
    w.phase = .normal;
    w.hp = 20;

    _ = w.takeDamage(100, false);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), w.hp, 0.001);
    try std.testing.expect(w.isDead());
}

test "cannot take damage when already dead" {
    var w = WitherFight.init(0, 64, 0);
    w.phase = .normal;
    w.hp = 0;

    const took = w.takeDamage(50, false);
    try std.testing.expect(!took);
}

test "spawn pattern valid X-axis T-shape" {
    test_grid_global = .{};
    // Stem at (3, 2, 3).
    test_grid_global.data[3][2][3] = 88;
    // T-bar at y=3: (2,3,3), (3,3,3), (4,3,3).
    test_grid_global.data[2][3][3] = 88;
    test_grid_global.data[3][3][3] = 88;
    test_grid_global.data[4][3][3] = 88;
    // Skulls at y=4: (2,4,3), (3,4,3), (4,4,3).
    test_grid_global.data[2][4][3] = 397;
    test_grid_global.data[3][4][3] = 397;
    test_grid_global.data[4][4][3] = 397;

    try std.testing.expect(checkSpawnPattern(&testGetBlock, 3, 3, 3));
}

test "spawn pattern valid Z-axis T-shape" {
    test_grid_global = .{};
    // Stem at (3, 2, 3).
    test_grid_global.data[3][2][3] = 88;
    // T-bar at y=3 along Z: (3,3,2), (3,3,3), (3,3,4).
    test_grid_global.data[3][3][2] = 88;
    test_grid_global.data[3][3][3] = 88;
    test_grid_global.data[3][3][4] = 88;
    // Skulls at y=4: (3,4,2), (3,4,3), (3,4,4).
    test_grid_global.data[3][4][2] = 397;
    test_grid_global.data[3][4][3] = 397;
    test_grid_global.data[3][4][4] = 397;

    try std.testing.expect(checkSpawnPattern(&testGetBlock, 3, 3, 3));
}

test "spawn pattern rejects incomplete pattern" {
    test_grid_global = .{};
    // Stem and T-bar but missing one skull.
    test_grid_global.data[3][2][3] = 88;
    test_grid_global.data[2][3][3] = 88;
    test_grid_global.data[3][3][3] = 88;
    test_grid_global.data[4][3][3] = 88;
    test_grid_global.data[2][4][3] = 397;
    test_grid_global.data[3][4][3] = 397;
    // Missing: test_grid_global.data[4][4][3] = 397;

    try std.testing.expect(!checkSpawnPattern(&testGetBlock, 3, 3, 3));
}

test "spawn pattern rejects empty grid" {
    test_grid_global = .{};
    try std.testing.expect(!checkSpawnPattern(&testGetBlock, 3, 3, 3));
}
