/// Natural mob spawning rules.
/// Evaluates spawn candidates 24-128 blocks from the player every 20 ticks.
/// Hostile mobs require light <= 7; passive mobs require light >= 9 with a
/// grass block (solid) below.  Candidates must not occupy a solid block.
const std = @import("std");

// ──────────────────────────────────────────────────────────────────────────────
// Public types
// ──────────────────────────────────────────────────────────────────────────────

pub const MobCap = struct {
    hostile: u16 = 70,
    passive: u16 = 10,
    water: u16 = 15,
    ambient: u16 = 15,
};

pub const SpawnCandidate = struct {
    mob_type: u8,
    x: f32,
    y: f32,
    z: f32,
};

// ──────────────────────────────────────────────────────────────────────────────
// Mob-type constants (mirrors entity.zig values)
// ──────────────────────────────────────────────────────────────────────────────

const mob_zombie: u8 = 1;
const mob_skeleton: u8 = 2;
const mob_creeper: u8 = 3;
const mob_pig: u8 = 4;
const mob_cow: u8 = 5;
const mob_chicken: u8 = 6;
const mob_sheep: u8 = 7;

// ──────────────────────────────────────────────────────────────────────────────
// Spawn geometry
// ──────────────────────────────────────────────────────────────────────────────

const min_distance: f32 = 24.0;
const max_distance: f32 = 128.0;
const spawn_cycle_ticks: u64 = 20;

// ──────────────────────────────────────────────────────────────────────────────
// Core API
// ──────────────────────────────────────────────────────────────────────────────

/// Attempt to produce a natural spawn near the player.
///
/// Returns `null` when:
///   - the tick is not on a 20-tick spawn cycle,
///   - mob caps are full for the candidate category,
///   - light / block conditions are not met, or
///   - the candidate position is inside a solid block.
pub fn trySpawn(
    player_x: f32,
    player_y: f32,
    player_z: f32,
    light_at: *const fn (i32, i32, i32) u4,
    is_solid: *const fn (i32, i32, i32) bool,
    current_counts: MobCap,
    tick: u64,
) ?SpawnCandidate {
    // Only attempt spawns on the cycle boundary.
    if (tick % spawn_cycle_ticks != 0) return null;

    // Deterministic position from tick.
    const pos = candidatePosition(player_x, player_y, player_z, tick);

    const bx = floatToBlock(pos.x);
    const by = floatToBlock(pos.y);
    const bz = floatToBlock(pos.z);

    // Must not spawn inside a solid block.
    if (is_solid(bx, by, bz)) return null;

    const light = light_at(bx, by, bz);

    // Try hostile spawn.
    if (light <= 7 and current_counts.hostile < 70) {
        return SpawnCandidate{
            .mob_type = pickHostile(tick),
            .x = pos.x,
            .y = pos.y,
            .z = pos.z,
        };
    }

    // Try passive spawn (requires light >= 9 AND solid ground below).
    if (light >= 9 and current_counts.passive < 10) {
        if (is_solid(bx, by - 1, bz)) {
            return SpawnCandidate{
                .mob_type = pickPassive(tick),
                .x = pos.x,
                .y = pos.y,
                .z = pos.z,
            };
        }
    }

    return null;
}

// ──────────────────────────────────────────────────────────────────────────────
// Internal helpers
// ──────────────────────────────────────────────────────────────────────────────

const Vec3 = struct { x: f32, y: f32, z: f32 };

/// Derive a candidate position 24-128 blocks from the player using the tick
/// as a deterministic seed.
fn candidatePosition(px: f32, py: f32, pz: f32, tick: u64) Vec3 {
    const h1 = splitmix64(tick);
    const h2 = splitmix64(h1);

    const angle = hashToFloat(h1) * std.math.pi * 2.0;
    const distance = min_distance + hashToFloat(h2) * (max_distance - min_distance);

    return .{
        .x = px + @cos(angle) * distance,
        .y = py,
        .z = pz + @sin(angle) * distance,
    };
}

fn floatToBlock(v: f32) i32 {
    return @intFromFloat(@floor(v));
}

/// Pick a hostile mob: zombie 50 %, skeleton 30 %, creeper 20 %.
fn pickHostile(tick: u64) u8 {
    const roll = hashToPercent(splitmix64(tick *% 7));
    if (roll < 50) return mob_zombie;
    if (roll < 80) return mob_skeleton;
    return mob_creeper;
}

/// Pick a passive mob: pig 30 %, cow 25 %, sheep 25 %, chicken 20 %.
fn pickPassive(tick: u64) u8 {
    const roll = hashToPercent(splitmix64(tick *% 13));
    if (roll < 30) return mob_pig;
    if (roll < 55) return mob_cow;
    if (roll < 80) return mob_sheep;
    return mob_chicken;
}

// ──────────────────────────────────────────────────────────────────────────────
// PRNG helpers (splitmix64 — same as noise.zig / spawner.zig)
// ──────────────────────────────────────────────────────────────────────────────

fn splitmix64(state: u64) u64 {
    var s = state +% 0x9e3779b97f4a7c15;
    s = (s ^ (s >> 30)) *% 0xbf58476d1ce4e5b9;
    s = (s ^ (s >> 27)) *% 0x94d049bb133111eb;
    return s ^ (s >> 31);
}

fn hashToFloat(h: u64) f32 {
    return @as(f32, @floatFromInt(h & 0xFFFFFF)) / @as(f32, 0x1000000);
}

fn hashToPercent(h: u64) u32 {
    return @as(u32, @intCast(h % 100));
}

// ──────────────────────────────────────────────────────────────────────────────
// Test helpers — stub world callbacks
// ──────────────────────────────────────────────────────────────────────────────

fn darkLight(_: i32, _: i32, _: i32) u4 {
    return 4; // dark — hostile eligible
}

fn brightLight(_: i32, _: i32, _: i32) u4 {
    return 12; // bright — passive eligible
}

fn midLight(_: i32, _: i32, _: i32) u4 {
    return 8; // too bright for hostile, too dim for passive
}

fn neverSolid(_: i32, _: i32, _: i32) bool {
    return false;
}

fn alwaysSolid(_: i32, _: i32, _: i32) bool {
    return true;
}

/// Solid only at y-1 relative to y == 0 (i.e. block y == -1).
fn groundSolid(_: i32, y: i32, _: i32) bool {
    return y < 0;
}

// ──────────────────────────────────────────────────────────────────────────────
// Tests (12)
// ──────────────────────────────────────────────────────────────────────────────

test "spawn only on 20-tick cycle" {
    const result = trySpawn(0, 0, 0, &darkLight, &neverSolid, .{}, 10);
    try std.testing.expect(result == null);
}

test "spawn fires on cycle tick" {
    const result = trySpawn(0, 0, 0, &darkLight, &neverSolid, .{}, 20);
    try std.testing.expect(result != null);
}

test "hostile spawn when light <= 7" {
    const c = trySpawn(0, 0, 0, &darkLight, &neverSolid, .{}, 20).?;
    try std.testing.expect(c.mob_type == mob_zombie or
        c.mob_type == mob_skeleton or
        c.mob_type == mob_creeper);
}

test "no spawn when light is 8 (neither hostile nor passive)" {
    // midLight returns 8: too bright for hostile (needs <=7), too dim for passive (needs >=9).
    const result = trySpawn(0, 0, 0, &midLight, &groundSolid, .{}, 20);
    try std.testing.expect(result == null);
}

test "passive spawn when light >= 9 and ground below" {
    const c = trySpawn(0, 0, 0, &brightLight, &groundSolid, .{}, 40).?;
    try std.testing.expect(c.mob_type == mob_pig or
        c.mob_type == mob_cow or
        c.mob_type == mob_sheep or
        c.mob_type == mob_chicken);
}

test "no passive spawn without solid ground below" {
    const result = trySpawn(0, 0, 0, &brightLight, &neverSolid, .{}, 40);
    try std.testing.expect(result == null);
}

test "no spawn inside solid block" {
    const result = trySpawn(0, 0, 0, &darkLight, &alwaysSolid, .{}, 20);
    try std.testing.expect(result == null);
}

test "hostile cap blocks hostile spawn" {
    const full = MobCap{ .hostile = 70, .passive = 0, .water = 0, .ambient = 0 };
    const result = trySpawn(0, 0, 0, &darkLight, &neverSolid, full, 20);
    try std.testing.expect(result == null);
}

test "passive cap blocks passive spawn" {
    const full = MobCap{ .hostile = 0, .passive = 10, .water = 0, .ambient = 0 };
    const result = trySpawn(0, 0, 0, &brightLight, &groundSolid, full, 40);
    try std.testing.expect(result == null);
}

test "spawn position is 24-128 blocks from player" {
    const px: f32 = 100.0;
    const pz: f32 = 200.0;
    const c = trySpawn(px, 64, pz, &darkLight, &neverSolid, .{}, 60).?;

    const dx = c.x - px;
    const dz = c.z - pz;
    const dist = @sqrt(dx * dx + dz * dz);
    try std.testing.expect(dist >= min_distance - 0.5);
    try std.testing.expect(dist <= max_distance + 0.5);
}

test "deterministic: same tick same result" {
    const a = trySpawn(5, 10, 15, &darkLight, &neverSolid, .{}, 80);
    const b = trySpawn(5, 10, 15, &darkLight, &neverSolid, .{}, 80);
    try std.testing.expect(a != null and b != null);
    const ca = a.?;
    const cb = b.?;
    try std.testing.expectEqual(ca.mob_type, cb.mob_type);
    try std.testing.expectEqual(ca.x, cb.x);
    try std.testing.expectEqual(ca.y, cb.y);
    try std.testing.expectEqual(ca.z, cb.z);
}

test "hostile distribution covers all types over many ticks" {
    var saw_zombie = false;
    var saw_skeleton = false;
    var saw_creeper = false;
    for (0..300) |i| {
        const tick: u64 = @as(u64, i) * spawn_cycle_ticks;
        if (trySpawn(0, 0, 0, &darkLight, &neverSolid, .{}, tick)) |c| {
            if (c.mob_type == mob_zombie) saw_zombie = true;
            if (c.mob_type == mob_skeleton) saw_skeleton = true;
            if (c.mob_type == mob_creeper) saw_creeper = true;
        }
    }
    try std.testing.expect(saw_zombie);
    try std.testing.expect(saw_skeleton);
    try std.testing.expect(saw_creeper);
}
