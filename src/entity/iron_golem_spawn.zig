/// Iron golem spawning logic for villages.
///
/// Iron golems naturally spawn in villages when enough villagers, beds, and
/// workstations are present and the village has recently been panicked (for
/// example after a zombie siege or a villager taking damage). This module
/// encodes those conditions plus the spiral search pattern used to find a
/// valid spawn offset around the village center, and a few combat-stat
/// constants that other systems can import.
const std = @import("std");

// ---------------------------------------------------------------------------
// Combat / stat constants
// ---------------------------------------------------------------------------

pub const GOLEM_HP: f32 = 100;
pub const GOLEM_DAMAGE: f32 = 7;
pub const GOLEM_ATTACK_RANGE: f32 = 2.5;

// ---------------------------------------------------------------------------
// Spawn requirements
// ---------------------------------------------------------------------------

/// Minimum village population required before an iron golem will consider
/// spawning.
const MIN_VILLAGERS: u8 = 3;
/// Minimum claimed beds required. Matches villager-count floor.
const MIN_BEDS: u8 = 3;
/// At least one workstation (job block) must exist in the village.
const MIN_WORKSTATIONS: u8 = 1;

/// Radius (in blocks) of the spiral spawn search around the village center.
const SPAWN_RADIUS: f32 = 6.0;
/// Vertical jitter applied as the spiral winds outward; keeps spawns close
/// to the caller's Y while still exploring a little above/below.
const VERTICAL_JITTER: f32 = 1.5;

/// Snapshot of the village state the spawn algorithm cares about.
pub const SpawnCondition = struct {
    villager_count: u8,
    bed_count: u8,
    workstation_count: u8,
    recent_panic: bool,
};

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Returns true when the village satisfies every iron-golem spawn prerequisite.
pub fn canSpawn(cond: SpawnCondition) bool {
    return cond.villager_count >= MIN_VILLAGERS and
        cond.bed_count >= MIN_BEDS and
        cond.workstation_count >= MIN_WORKSTATIONS and
        cond.recent_panic;
}

/// Return the Nth candidate spawn position around the village center
/// `(cx, cy, cz)`. Successive attempts trace an outward Archimedean spiral
/// so the caller can try again when the first slot is blocked.
pub fn getSpawnPosition(cx: f32, cy: f32, cz: f32, attempt: u8) [3]f32 {
    const a: f32 = @floatFromInt(attempt);
    // Golden-angle step keeps the spiral visually even without clustering.
    const angle: f32 = a * 2.3999632;
    // Radius grows with sqrt(attempt) so early tries stay close to center.
    const radius: f32 = SPAWN_RADIUS * @sqrt((a + 1.0) / 16.0);
    const dx: f32 = radius * std.math.cos(angle);
    const dz: f32 = radius * std.math.sin(angle);
    const dy: f32 = VERTICAL_JITTER * std.math.sin(a * 0.5);
    return .{ cx + dx, cy + dy, cz + dz };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

const testing = std.testing;

fn base() SpawnCondition {
    return .{
        .villager_count = 3,
        .bed_count = 3,
        .workstation_count = 1,
        .recent_panic = true,
    };
}

test "canSpawn: baseline conditions allow spawn" {
    try testing.expect(canSpawn(base()));
}

test "canSpawn: too few villagers blocks spawn" {
    var c = base();
    c.villager_count = 2;
    try testing.expect(!canSpawn(c));
}

test "canSpawn: too few beds blocks spawn" {
    var c = base();
    c.bed_count = 2;
    try testing.expect(!canSpawn(c));
}

test "canSpawn: missing workstation blocks spawn" {
    var c = base();
    c.workstation_count = 0;
    try testing.expect(!canSpawn(c));
}

test "canSpawn: no recent panic blocks spawn" {
    var c = base();
    c.recent_panic = false;
    try testing.expect(!canSpawn(c));
}

test "canSpawn: abundant resources still spawn" {
    const c = SpawnCondition{
        .villager_count = 50,
        .bed_count = 50,
        .workstation_count = 20,
        .recent_panic = true,
    };
    try testing.expect(canSpawn(c));
}

test "canSpawn: all zero blocks spawn" {
    const c = SpawnCondition{
        .villager_count = 0,
        .bed_count = 0,
        .workstation_count = 0,
        .recent_panic = false,
    };
    try testing.expect(!canSpawn(c));
}

test "getSpawnPosition: first attempt sits near center" {
    const p = getSpawnPosition(0, 64, 0, 0);
    // sqrt(1/16) = 0.25, radius = 1.5
    try testing.expect(@abs(p[0]) <= SPAWN_RADIUS);
    try testing.expect(@abs(p[2]) <= SPAWN_RADIUS);
    try testing.expect(@abs(p[1] - 64.0) <= VERTICAL_JITTER + 0.01);
}

test "getSpawnPosition: later attempts move outward" {
    const near = getSpawnPosition(0, 0, 0, 0);
    const far = getSpawnPosition(0, 0, 0, 30);
    const near_r = @sqrt(near[0] * near[0] + near[2] * near[2]);
    const far_r = @sqrt(far[0] * far[0] + far[2] * far[2]);
    try testing.expect(far_r > near_r);
}

test "getSpawnPosition: preserves world origin offset" {
    const p = getSpawnPosition(100, 70, -50, 5);
    // Should stay within SPAWN_RADIUS (+ small tolerance) of the center.
    const dx = p[0] - 100;
    const dz = p[2] + 50;
    try testing.expect(@sqrt(dx * dx + dz * dz) <= SPAWN_RADIUS + 0.01);
    try testing.expect(@abs(p[1] - 70.0) <= VERTICAL_JITTER + 0.01);
}

test "getSpawnPosition: deterministic for same inputs" {
    const a = getSpawnPosition(1, 2, 3, 7);
    const b = getSpawnPosition(1, 2, 3, 7);
    try testing.expectEqual(a[0], b[0]);
    try testing.expectEqual(a[1], b[1]);
    try testing.expectEqual(a[2], b[2]);
}

test "getSpawnPosition: distinct attempts differ" {
    const a = getSpawnPosition(0, 0, 0, 1);
    const b = getSpawnPosition(0, 0, 0, 2);
    try testing.expect(a[0] != b[0] or a[2] != b[2]);
}

test "constants: HP, damage, and attack range match spec" {
    try testing.expectEqual(@as(f32, 100), GOLEM_HP);
    try testing.expectEqual(@as(f32, 7), GOLEM_DAMAGE);
    try testing.expectEqual(@as(f32, 2.5), GOLEM_ATTACK_RANGE);
}

test "SpawnCondition: struct is trivially copyable" {
    const c1 = base();
    const c2 = c1;
    try testing.expectEqual(c1.villager_count, c2.villager_count);
    try testing.expectEqual(c1.recent_panic, c2.recent_panic);
}
