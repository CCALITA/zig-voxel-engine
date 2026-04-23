const std = @import("std");

/// A single dust particle kicked up by sprinting feet.
pub const DustParticle = struct {
    x: f32,
    y: f32,
    z: f32,
    vx: f32,
    vy: f32,
    vz: f32,
    life: f32,
    size: f32,
    r: f32,
    g: f32,
    b: f32,
    a: f32,
};

const Color = struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32,
};

// Well-known block IDs (mirroring src/world/block.zig constants).
const DIRT: u16 = 2;
const GRASS: u16 = 3;
const SAND: u16 = 6;
const GRAVEL: u16 = 7;
const SNOW: u16 = 24;
const CLAY: u16 = 25;
const NETHERRACK: u16 = 30;
const SOUL_SAND: u16 = 31;
const END_STONE: u16 = 45;

/// Return dust color based on the ground block beneath the player's feet.
fn groundColor(ground_block: u16) Color {
    return switch (ground_block) {
        DIRT, GRASS => .{ .r = 0.55, .g = 0.35, .b = 0.18, .a = 0.8 }, // brown
        SAND => .{ .r = 0.82, .g = 0.73, .b = 0.55, .a = 0.7 }, // tan
        SNOW => .{ .r = 0.95, .g = 0.95, .b = 0.98, .a = 0.6 }, // white
        GRAVEL => .{ .r = 0.55, .g = 0.54, .b = 0.52, .a = 0.75 }, // grey
        CLAY => .{ .r = 0.62, .g = 0.58, .b = 0.54, .a = 0.7 }, // clay
        NETHERRACK => .{ .r = 0.55, .g = 0.18, .b = 0.15, .a = 0.8 }, // dark red
        SOUL_SAND => .{ .r = 0.40, .g = 0.30, .b = 0.20, .a = 0.8 }, // dark brown
        END_STONE => .{ .r = 0.85, .g = 0.83, .b = 0.65, .a = 0.7 }, // pale yellow
        else => .{ .r = 0.50, .g = 0.45, .b = 0.40, .a = 0.6 }, // generic grey-brown
    };
}

/// Deterministic xorshift hash used for particle spread.
fn xorshift(state: u32) u32 {
    var s = state;
    s ^= s << 13;
    s ^= s >> 17;
    s ^= s << 5;
    return s;
}

/// Convert a u32 hash to a float in [0, 1).
fn hashToFloat01(h: u32) f32 {
    return @as(f32, @floatFromInt(h & 0xFFFF)) / 65536.0;
}

const GRAVITY: f32 = 6.0;
const DRAG: f32 = 2.0;
const PARTICLE_COUNT = 4;
const BASE_LIFE: f32 = 0.4;
const LIFE_VARIANCE: f32 = 0.3;
const BASE_SIZE: f32 = 0.06;
const SIZE_VARIANCE: f32 = 0.04;
const SPREAD: f32 = 0.15;
const KICK_SPEED: f32 = 1.2;
const UPWARD_SPEED: f32 = 1.8;

/// Spawn 4 dust particles behind the player's feet.
///
/// `foot_x`, `foot_y`, `foot_z` — world-space foot position.
/// `move_dir_x`, `move_dir_z` — normalized movement direction (particles fly opposite).
/// `ground_block` — block ID under feet, used to pick dust color.
pub fn spawnSprintDust(
    foot_x: f32,
    foot_y: f32,
    foot_z: f32,
    move_dir_x: f32,
    move_dir_z: f32,
    ground_block: u16,
) [4]DustParticle {
    const color = groundColor(ground_block);

    // Build a deterministic seed from the foot position.
    const seed_a: u32 = @bitCast(foot_x);
    const seed_b: u32 = @bitCast(foot_y);
    const seed_c: u32 = @bitCast(foot_z);
    var state: u32 = seed_a ^ (seed_b *% 2654435761) ^ (seed_c *% 2246822519);
    if (state == 0) state = 1;

    var result: [PARTICLE_COUNT]DustParticle = undefined;

    for (0..PARTICLE_COUNT) |i| {
        state = xorshift(state);
        const fx = hashToFloat01(state) * 2.0 - 1.0;
        state = xorshift(state);
        const fz = hashToFloat01(state) * 2.0 - 1.0;
        state = xorshift(state);
        const life_t = hashToFloat01(state);
        state = xorshift(state);
        const size_t = hashToFloat01(state);

        const offset_x = -move_dir_x * SPREAD + fx * SPREAD;
        const offset_z = -move_dir_z * SPREAD + fz * SPREAD;

        result[i] = .{
            .x = foot_x + offset_x,
            .y = foot_y,
            .z = foot_z + offset_z,
            .vx = -move_dir_x * KICK_SPEED + fx * KICK_SPEED * 0.5,
            .vy = UPWARD_SPEED + life_t * 0.6,
            .vz = -move_dir_z * KICK_SPEED + fz * KICK_SPEED * 0.5,
            .life = BASE_LIFE + LIFE_VARIANCE * life_t,
            .size = BASE_SIZE + SIZE_VARIANCE * size_t,
            .r = color.r,
            .g = color.g,
            .b = color.b,
            .a = color.a,
        };
    }

    return result;
}

/// Advance a single dust particle by `dt` seconds.
///
/// Returns `true` while the particle is still alive, `false` when it has expired
/// and should be removed.
pub fn updateDust(p: *DustParticle, dt: f32) bool {
    p.life -= dt;
    if (p.life <= 0.0) {
        p.life = 0.0;
        p.a = 0.0;
        return false;
    }

    p.vy -= GRAVITY * dt;

    p.vx -= p.vx * DRAG * dt;
    p.vz -= p.vz * DRAG * dt;

    p.x += p.vx * dt;
    p.y += p.vy * dt;
    p.z += p.vz * dt;

    // Fade alpha linearly over the remaining life.
    const max_life = BASE_LIFE + LIFE_VARIANCE; // upper bound
    p.a *= p.life / max_life;

    // Shrink the particle as it dies.
    p.size *= (0.98 + 0.02 * (p.life / max_life));

    return true;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "spawnSprintDust returns 4 particles" {
    const result = spawnSprintDust(0.0, 0.0, 0.0, 1.0, 0.0, DIRT);
    try std.testing.expectEqual(@as(usize, 4), result.len);
    for (result) |p| {
        try std.testing.expect(p.life > 0.0);
    }
}

test "dirt gives brown dust color" {
    const result = spawnSprintDust(5.0, 1.0, 5.0, 0.0, 1.0, DIRT);
    for (result) |p| {
        try std.testing.expectApproxEqAbs(@as(f32, 0.55), p.r, 0.001);
        try std.testing.expectApproxEqAbs(@as(f32, 0.35), p.g, 0.001);
        try std.testing.expectApproxEqAbs(@as(f32, 0.18), p.b, 0.001);
    }
}

test "sand gives tan dust color" {
    const result = spawnSprintDust(0.0, 0.0, 0.0, 1.0, 0.0, SAND);
    for (result) |p| {
        try std.testing.expectApproxEqAbs(@as(f32, 0.82), p.r, 0.001);
        try std.testing.expectApproxEqAbs(@as(f32, 0.73), p.g, 0.001);
        try std.testing.expectApproxEqAbs(@as(f32, 0.55), p.b, 0.001);
    }
}

test "snow gives white dust color" {
    const result = spawnSprintDust(0.0, 0.0, 0.0, 1.0, 0.0, SNOW);
    for (result) |p| {
        try std.testing.expectApproxEqAbs(@as(f32, 0.95), p.r, 0.001);
        try std.testing.expectApproxEqAbs(@as(f32, 0.95), p.g, 0.001);
        try std.testing.expectApproxEqAbs(@as(f32, 0.98), p.b, 0.001);
    }
}

test "grass uses same color as dirt" {
    const dirt_result = spawnSprintDust(1.0, 0.0, 1.0, 1.0, 0.0, DIRT);
    const grass_result = spawnSprintDust(1.0, 0.0, 1.0, 1.0, 0.0, GRASS);
    for (0..4) |i| {
        try std.testing.expectApproxEqAbs(dirt_result[i].r, grass_result[i].r, 0.001);
        try std.testing.expectApproxEqAbs(dirt_result[i].g, grass_result[i].g, 0.001);
        try std.testing.expectApproxEqAbs(dirt_result[i].b, grass_result[i].b, 0.001);
    }
}

test "unknown block gets fallback color" {
    const result = spawnSprintDust(0.0, 0.0, 0.0, 1.0, 0.0, 9999);
    for (result) |p| {
        try std.testing.expectApproxEqAbs(@as(f32, 0.50), p.r, 0.001);
        try std.testing.expectApproxEqAbs(@as(f32, 0.45), p.g, 0.001);
        try std.testing.expectApproxEqAbs(@as(f32, 0.40), p.b, 0.001);
    }
}

test "particles kick backward relative to move direction" {
    // Moving in +X direction: particles should have -X velocity component
    const result = spawnSprintDust(0.0, 0.0, 0.0, 1.0, 0.0, DIRT);
    var sum_vx: f32 = 0.0;
    for (result) |p| {
        sum_vx += p.vx;
    }
    // Average velocity should be negative (backward)
    try std.testing.expect(sum_vx / 4.0 < 0.0);
}

test "particles spawn near foot position" {
    const fx: f32 = 10.0;
    const fy: f32 = 5.0;
    const fz: f32 = 20.0;
    const result = spawnSprintDust(fx, fy, fz, 0.0, 1.0, SAND);
    for (result) |p| {
        try std.testing.expect(@abs(p.x - fx) < 1.0);
        try std.testing.expectApproxEqAbs(fy, p.y, 0.001);
        try std.testing.expect(@abs(p.z - fz) < 1.0);
    }
}

test "all particles have upward initial velocity" {
    const result = spawnSprintDust(0.0, 0.0, 0.0, 1.0, 0.0, DIRT);
    for (result) |p| {
        try std.testing.expect(p.vy > 0.0);
    }
}

test "updateDust decreases life" {
    var p = spawnSprintDust(0.0, 0.0, 0.0, 1.0, 0.0, DIRT)[0];
    const before = p.life;
    _ = updateDust(&p, 0.05);
    try std.testing.expect(p.life < before);
}

test "updateDust returns false when particle expires" {
    var p = spawnSprintDust(0.0, 0.0, 0.0, 1.0, 0.0, DIRT)[0];
    // Force a short life
    p.life = 0.01;
    const alive = updateDust(&p, 0.1);
    try std.testing.expect(!alive);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), p.life, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), p.a, 0.001);
}

test "updateDust applies gravity (vy decreases)" {
    var p = spawnSprintDust(0.0, 0.0, 0.0, 1.0, 0.0, DIRT)[0];
    const vy_before = p.vy;
    _ = updateDust(&p, 0.05);
    try std.testing.expect(p.vy < vy_before);
}

test "updateDust moves particle position" {
    var p = spawnSprintDust(0.0, 0.0, 0.0, 1.0, 0.0, DIRT)[0];
    const x0 = p.x;
    const y0 = p.y;
    _ = updateDust(&p, 0.05);
    const moved = @abs(p.x - x0) > 0.0001 or @abs(p.y - y0) > 0.0001;
    try std.testing.expect(moved);
}

test "updateDust fades alpha over time" {
    var p = spawnSprintDust(0.0, 0.0, 0.0, 1.0, 0.0, SAND)[0];
    const a_before = p.a;
    _ = updateDust(&p, 0.1);
    try std.testing.expect(p.a < a_before);
}

test "deterministic: same inputs produce same particles" {
    const a = spawnSprintDust(3.0, 1.0, 7.0, 0.7, 0.7, GRAVEL);
    const b = spawnSprintDust(3.0, 1.0, 7.0, 0.7, 0.7, GRAVEL);
    for (0..4) |i| {
        try std.testing.expectApproxEqAbs(a[i].x, b[i].x, 0.0001);
        try std.testing.expectApproxEqAbs(a[i].vx, b[i].vx, 0.0001);
        try std.testing.expectApproxEqAbs(a[i].life, b[i].life, 0.0001);
        try std.testing.expectApproxEqAbs(a[i].size, b[i].size, 0.0001);
    }
}

test "particle size is within expected range" {
    const result = spawnSprintDust(0.0, 0.0, 0.0, 1.0, 0.0, SNOW);
    for (result) |p| {
        try std.testing.expect(p.size >= BASE_SIZE - 0.001);
        try std.testing.expect(p.size <= BASE_SIZE + SIZE_VARIANCE + 0.001);
    }
}

test "particle life is within expected range" {
    const result = spawnSprintDust(0.0, 0.0, 0.0, 0.0, 1.0, CLAY);
    for (result) |p| {
        try std.testing.expect(p.life >= BASE_LIFE - 0.001);
        try std.testing.expect(p.life <= BASE_LIFE + LIFE_VARIANCE + 0.001);
    }
}
