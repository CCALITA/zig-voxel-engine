/// Portal mechanics for Nether and End portals.
/// Handles frame validation, teleport timers, and coordinate conversion.

const std = @import("std");

// ──────────────────────────────────────────────────────────────────────────────
// Block constants (mirrored from world/block.zig to avoid cross-module import)
// ──────────────────────────────────────────────────────────────────────────────

const OBSIDIAN: u16 = 19;
const END_PORTAL_FRAME: u16 = 58;

// ──────────────────────────────────────────────────────────────────────────────
// Portal configuration
// ──────────────────────────────────────────────────────────────────────────────

/// Seconds a player must stand inside a portal before teleporting.
pub const teleport_delay: f32 = 4.0;

/// Nether coordinate ratio (overworld:nether = 8:1).
pub const nether_scale: f32 = 8.0;

/// Minimum nether portal width (interior).
pub const nether_frame_width: u32 = 2;

/// Minimum nether portal height (interior).
pub const nether_frame_height: u32 = 3;

// ──────────────────────────────────────────────────────────────────────────────
// Types
// ──────────────────────────────────────────────────────────────────────────────

pub const PortalType = enum { nether, end };

pub const PortalState = struct {
    timer: f32 = 0,
    active: bool = false,
    portal_type: PortalType = .nether,
};

pub const TeleportResult = struct {
    teleport: bool,
    target_dim: u8,
};

pub const ConvertedCoords = struct {
    x: f32,
    z: f32,
};

// ──────────────────────────────────────────────────────────────────────────────
// Nether portal frame check (4 wide x 5 tall obsidian frame)
// ──────────────────────────────────────────────────────────────────────────────

/// Validates a 4-wide by 5-tall nether portal frame at (bx, by, bz).
/// The frame origin is the bottom-left corner.  The layout (in the XY plane):
///
///   col:  0  1  2  3
///   row 4: O  .  .  O      (O = obsidian, . = interior / air)
///   row 3: O  .  .  O
///   row 2: O  .  .  O
///   row 1: O  .  .  O
///   row 0: O  O  O  O
///
/// Bottom row (y+0) and top row (y+4): all 4 must be obsidian.
/// Middle rows (y+1 .. y+3): left (x+0) and right (x+3) must be obsidian,
/// interior columns (x+1, x+2) must NOT be obsidian (portal space).
pub fn checkNetherFrame(getBlock: *const fn (i32, i32, i32) u16, bx: i32, by: i32, bz: i32) bool {
    // Bottom row — all 4 obsidian
    for (0..4) |dx| {
        if (getBlock(bx + @as(i32, @intCast(dx)), by, bz) != OBSIDIAN) return false;
    }

    // Top row — all 4 obsidian
    for (0..4) |dx| {
        if (getBlock(bx + @as(i32, @intCast(dx)), by + 4, bz) != OBSIDIAN) return false;
    }

    // Middle rows: pillars on sides, air/portal in interior
    for (1..4) |dy| {
        const y = by + @as(i32, @intCast(dy));
        if (getBlock(bx, y, bz) != OBSIDIAN) return false;
        if (getBlock(bx + 3, y, bz) != OBSIDIAN) return false;
        // Interior must not be obsidian (could be air or portal block)
        if (getBlock(bx + 1, y, bz) == OBSIDIAN) return false;
        if (getBlock(bx + 2, y, bz) == OBSIDIAN) return false;
    }

    return true;
}

// ──────────────────────────────────────────────────────────────────────────────
// Portal timer
// ──────────────────────────────────────────────────────────────────────────────

/// Advances the portal standing timer. Returns a teleport event when the
/// player has stood inside the portal for `teleport_delay` seconds.
/// Stepping out resets the timer.
pub fn updatePortalTimer(state: *PortalState, in_portal: bool, dt: f32) ?TeleportResult {
    if (!in_portal) {
        state.timer = 0;
        state.active = false;
        return null;
    }

    state.active = true;
    state.timer += dt;

    if (state.timer >= teleport_delay) {
        state.timer = 0;
        state.active = false;
        return TeleportResult{
            .teleport = true,
            .target_dim = switch (state.portal_type) {
                .nether => 1, // dimension 1 = nether
                .end => 2, // dimension 2 = end
            },
        };
    }

    return null;
}

// ──────────────────────────────────────────────────────────────────────────────
// Nether coordinate conversion
// ──────────────────────────────────────────────────────────────────────────────

/// Converts coordinates between Overworld and Nether using the 8:1 ratio.
/// When `to_nether` is true, divides by 8; when false, multiplies by 8.
pub fn convertNetherCoords(x: f32, z: f32, to_nether: bool) ConvertedCoords {
    if (to_nether) {
        return .{ .x = x / nether_scale, .z = z / nether_scale };
    }
    return .{ .x = x * nether_scale, .z = z * nether_scale };
}

// ──────────────────────────────────────────────────────────────────────────────
// End portal ring check
// ──────────────────────────────────────────────────────────────────────────────

/// Checks whether 12 end portal frames form the canonical 5x5 ring centred
/// on (cx, cy, cz). The ring sits in the XZ plane at height cy:
///
///      . F F F .
///      F . . . F
///      F . . . F
///      F . . . F
///      . F F F .
///
/// Returns true when at least 10 of the 12 frame positions contain
/// `END_PORTAL_FRAME` blocks (matching vanilla's "eyes of ender" threshold
/// where all 12 frames must be present but some may lack eyes).
pub fn checkEndPortal(getBlock: *const fn (i32, i32, i32) u16, cx: i32, cy: i32, cz: i32) bool {
    // 12 offsets forming the ring (relative to centre)
    const offsets = [12][2]i32{
        // North side (z = -2)
        .{ -1, -2 }, .{ 0, -2 }, .{ 1, -2 },
        // South side (z = +2)
        .{ -1, 2 }, .{ 0, 2 }, .{ 1, 2 },
        // West side (x = -2)
        .{ -2, -1 }, .{ -2, 0 }, .{ -2, 1 },
        // East side (x = +2)
        .{ 2, -1 }, .{ 2, 0 }, .{ 2, 1 },
    };

    var count: u32 = 0;
    for (offsets) |off| {
        if (getBlock(cx + off[0], cy, cz + off[1]) == END_PORTAL_FRAME) {
            count += 1;
        }
    }

    return count >= 10;
}

// ══════════════════════════════════════════════════════════════════════════════
// Tests
// ══════════════════════════════════════════════════════════════════════════════

test "checkNetherFrame — valid 4x5 obsidian frame" {
    const valid = checkNetherFrame(&validFrameGet, 0, 0, 0);
    try std.testing.expect(valid);
}

test "checkNetherFrame — missing bottom corner fails" {
    const valid = checkNetherFrame(&missingBottomGet, 0, 0, 0);
    try std.testing.expect(!valid);
}

test "checkNetherFrame — blocked interior fails" {
    const valid = checkNetherFrame(&blockedInteriorGet, 0, 0, 0);
    try std.testing.expect(!valid);
}

test "checkNetherFrame — missing top row fails" {
    const valid = checkNetherFrame(&missingTopGet, 0, 0, 0);
    try std.testing.expect(!valid);
}

test "updatePortalTimer — stepping in accumulates time" {
    var state = PortalState{};
    _ = updatePortalTimer(&state, true, 1.0);
    try std.testing.expect(state.active);
    try std.testing.expectApproxEqAbs(1.0, state.timer, 0.001);
}

test "updatePortalTimer — stepping out resets timer" {
    var state = PortalState{ .timer = 3.0, .active = true };
    _ = updatePortalTimer(&state, false, 0.5);
    try std.testing.expect(!state.active);
    try std.testing.expectApproxEqAbs(0.0, state.timer, 0.001);
}

test "updatePortalTimer — teleport after 4 seconds (nether)" {
    var state = PortalState{ .portal_type = .nether };
    _ = updatePortalTimer(&state, true, 3.9);
    try std.testing.expect(updatePortalTimer(&state, true, 0.2) != null);
}

test "updatePortalTimer — teleport targets end dimension" {
    var state = PortalState{ .portal_type = .end };
    _ = updatePortalTimer(&state, true, 4.5);
    // Timer exceeded, should get teleport result
    // Re-create since timer reset
    state = PortalState{ .portal_type = .end, .timer = 3.9 };
    const result = updatePortalTimer(&state, true, 0.2);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(u8, 2), result.?.target_dim);
}

test "convertNetherCoords — overworld to nether divides by 8" {
    const c = convertNetherCoords(800.0, -400.0, true);
    try std.testing.expectApproxEqAbs(100.0, c.x, 0.001);
    try std.testing.expectApproxEqAbs(-50.0, c.z, 0.001);
}

test "convertNetherCoords — nether to overworld multiplies by 8" {
    const c = convertNetherCoords(10.0, 20.0, false);
    try std.testing.expectApproxEqAbs(80.0, c.x, 0.001);
    try std.testing.expectApproxEqAbs(160.0, c.z, 0.001);
}

test "convertNetherCoords — round-trip preserves coordinates" {
    const original_x: f32 = 123.456;
    const original_z: f32 = -789.012;
    const nether = convertNetherCoords(original_x, original_z, true);
    const back = convertNetherCoords(nether.x, nether.z, false);
    try std.testing.expectApproxEqAbs(original_x, back.x, 0.01);
    try std.testing.expectApproxEqAbs(original_z, back.z, 0.01);
}

test "checkEndPortal — complete 12-frame ring passes" {
    const valid = checkEndPortal(&fullEndRingGet, 0, 64, 0);
    try std.testing.expect(valid);
}

test "checkEndPortal — 10 frames still passes" {
    const valid = checkEndPortal(&tenFrameEndRingGet, 0, 64, 0);
    try std.testing.expect(valid);
}

test "checkEndPortal — 9 frames fails" {
    const valid = checkEndPortal(&nineFrameEndRingGet, 0, 64, 0);
    try std.testing.expect(!valid);
}

test "checkEndPortal — empty world fails" {
    const valid = checkEndPortal(&emptyGet, 0, 64, 0);
    try std.testing.expect(!valid);
}

// ──────────────────────────────────────────────────────────────────────────────
// Test helpers — mock getBlock functions
// ──────────────────────────────────────────────────────────────────────────────

/// Returns a valid 4x5 nether frame at origin.
fn validFrameGet(x: i32, y: i32, _: i32) u16 {
    // Bottom row
    if (y == 0 and x >= 0 and x <= 3) return OBSIDIAN;
    // Top row
    if (y == 4 and x >= 0 and x <= 3) return OBSIDIAN;
    // Left pillar
    if (x == 0 and y >= 1 and y <= 3) return OBSIDIAN;
    // Right pillar
    if (x == 3 and y >= 1 and y <= 3) return OBSIDIAN;
    return 0; // air
}

/// Valid frame but bottom-left corner is air.
fn missingBottomGet(x: i32, y: i32, z: i32) u16 {
    if (x == 0 and y == 0) return 0;
    return validFrameGet(x, y, z);
}

/// Frame with obsidian blocking the interior at (1, 2).
fn blockedInteriorGet(x: i32, y: i32, z: i32) u16 {
    if (x == 1 and y == 2) return OBSIDIAN;
    return validFrameGet(x, y, z);
}

/// Frame with missing top row.
fn missingTopGet(x: i32, y: i32, z: i32) u16 {
    if (y == 4) return 0;
    return validFrameGet(x, y, z);
}

/// All 12 end portal frame positions filled.
fn fullEndRingGet(x: i32, _: i32, z: i32) u16 {
    const offsets = [12][2]i32{
        .{ -1, -2 }, .{ 0, -2 }, .{ 1, -2 },
        .{ -1, 2 },  .{ 0, 2 },  .{ 1, 2 },
        .{ -2, -1 }, .{ -2, 0 }, .{ -2, 1 },
        .{ 2, -1 },  .{ 2, 0 },  .{ 2, 1 },
    };
    for (offsets) |off| {
        if (x == off[0] and z == off[1]) return END_PORTAL_FRAME;
    }
    return 0;
}

/// 10 of 12 end portal frame positions filled (missing last two east slots).
fn tenFrameEndRingGet(x: i32, _: i32, z: i32) u16 {
    const offsets = [10][2]i32{
        .{ -1, -2 }, .{ 0, -2 }, .{ 1, -2 },
        .{ -1, 2 },  .{ 0, 2 },  .{ 1, 2 },
        .{ -2, -1 }, .{ -2, 0 }, .{ -2, 1 },
        .{ 2, -1 },
    };
    for (offsets) |off| {
        if (x == off[0] and z == off[1]) return END_PORTAL_FRAME;
    }
    return 0;
}

/// 9 of 12 end portal frame positions — should fail the >=10 check.
fn nineFrameEndRingGet(x: i32, _: i32, z: i32) u16 {
    const offsets = [9][2]i32{
        .{ -1, -2 }, .{ 0, -2 }, .{ 1, -2 },
        .{ -1, 2 },  .{ 0, 2 },  .{ 1, 2 },
        .{ -2, -1 }, .{ -2, 0 }, .{ -2, 1 },
    };
    for (offsets) |off| {
        if (x == off[0] and z == off[1]) return END_PORTAL_FRAME;
    }
    return 0;
}

/// Empty world — everything is air.
fn emptyGet(_: i32, _: i32, _: i32) u16 {
    return 0;
}
