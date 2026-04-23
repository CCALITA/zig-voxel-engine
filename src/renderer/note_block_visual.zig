const std = @import("std");

/// A colored note particle emitted by a note block.
/// Color is determined by pitch via HSV mapping.
pub const NoteParticle = struct {
    x: f32,
    y: f32,
    z: f32,
    r: f32,
    g: f32,
    b: f32,
    a: f32,
    size: f32,
    vy: f32,
};

/// Initial size of a freshly spawned note particle.
const initial_size: f32 = 0.25;

/// Rate at which alpha fades per second.
const fade_rate: f32 = 0.5;

/// Rate at which the particle shrinks per second.
const shrink_rate: f32 = 0.12;

/// Convert a note block pitch (0..24) to an RGB color.
///
/// The mapping follows Minecraft's note block behavior:
///   pitch 0  = green  (hue 120)
///   pitch 6  = yellow (hue 60)
///   pitch 12 = red    (hue 0)
///   pitch 18 = blue   (hue 240)
///   pitch 24 = green  (hue 120, wraps around)
///
/// First half (0..12): hue sweeps 120 -> 0 (green through yellow to red).
/// Second half (12..24): hue sweeps 360 -> 120 (red through blue back to green).
pub fn pitchToColor(pitch: u5) [3]f32 {
    const p: f32 = @floatFromInt(pitch);

    // Piecewise linear hue mapping to satisfy 0=green, 12=red, 24=green.
    const hue = if (p <= 12.0)
        // 120 -> 0 over pitches 0..12
        120.0 * (1.0 - p / 12.0)
    else
        // 360 -> 120 over pitches 12..24
        120.0 + (360.0 - 120.0) * (1.0 - (p - 12.0) / 12.0);

    return hsvToRgb(@mod(hue, 360.0), 1.0, 1.0);
}

/// Convert HSV (h in [0,360), s in [0,1], v in [0,1]) to RGB [0,1].
fn hsvToRgb(h: f32, s: f32, v: f32) [3]f32 {
    const c = v * s;
    const h_prime = h / 60.0;
    const x = c * (1.0 - @abs(@mod(h_prime, 2.0) - 1.0));
    const m = v - c;

    const sector: u32 = @intFromFloat(@floor(h_prime));
    const rgb: [3]f32 = switch (sector) {
        0 => .{ c, x, 0.0 },
        1 => .{ x, c, 0.0 },
        2 => .{ 0.0, c, x },
        3 => .{ 0.0, x, c },
        4 => .{ x, 0.0, c },
        else => .{ c, 0.0, x },
    };

    return .{ rgb[0] + m, rgb[1] + m, rgb[2] + m };
}

/// Spawn a note particle above a note block at the given block position.
pub fn spawnNote(bx: f32, by: f32, bz: f32, pitch: u5) NoteParticle {
    const color = pitchToColor(pitch);
    return .{
        .x = bx + 0.5,
        .y = by + 1.2,
        .z = bz + 0.5,
        .r = color[0],
        .g = color[1],
        .b = color[2],
        .a = 1.0,
        .size = initial_size,
        .vy = 1.0,
    };
}

/// Update a note particle by `dt` seconds. Returns true if the particle
/// is still alive, false when it has fully faded and should be removed.
pub fn updateNote(p: *NoteParticle, dt: f32) bool {
    p.y += p.vy * dt;
    p.a -= fade_rate * dt;
    p.size -= shrink_rate * dt;

    if (p.a <= 0.0 or p.size <= 0.0) {
        p.a = 0.0;
        p.size = 0.0;
        return false;
    }

    return true;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "pitchToColor pitch 0 is green" {
    const c = pitchToColor(0);
    try std.testing.expect(c[1] > 0.9); // green channel high
    try std.testing.expect(c[0] < 0.01); // red channel near zero
    try std.testing.expect(c[2] < 0.01); // blue channel near zero
}

test "pitchToColor pitch 12 is red" {
    const c = pitchToColor(12);
    try std.testing.expect(c[0] > 0.9); // red channel high
    try std.testing.expect(c[1] < 0.01); // green channel near zero
}

test "pitchToColor pitch 24 wraps back to green" {
    const c = pitchToColor(24);
    try std.testing.expect(c[1] > 0.9);
    try std.testing.expect(c[0] < 0.01);
    try std.testing.expect(c[2] < 0.01);
}

test "pitchToColor all values in [0,1]" {
    for (0..25) |i| {
        const pitch: u5 = @intCast(i);
        const c = pitchToColor(pitch);
        try std.testing.expect(c[0] >= 0.0 and c[0] <= 1.0);
        try std.testing.expect(c[1] >= 0.0 and c[1] <= 1.0);
        try std.testing.expect(c[2] >= 0.0 and c[2] <= 1.0);
    }
}

test "pitchToColor pitch 6 is yellow-ish (between green and red)" {
    const c = pitchToColor(6);
    // At pitch 6 (hue=60), expect yellow: high red, high green, low blue
    try std.testing.expect(c[0] > 0.9);
    try std.testing.expect(c[1] > 0.9);
    try std.testing.expect(c[2] < 0.01);
}

test "pitchToColor pitch 18 is blue-ish" {
    const c = pitchToColor(18);
    // At pitch 18 (hue=240), expect blue: low red, low green, high blue
    try std.testing.expect(c[2] > 0.9);
    try std.testing.expect(c[0] < 0.01);
    try std.testing.expect(c[1] < 0.01);
}

test "spawnNote positions particle above block center" {
    const p = spawnNote(10.0, 20.0, 30.0, 0);
    try std.testing.expectApproxEqAbs(@as(f32, 10.5), p.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 21.2), p.y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 30.5), p.z, 0.001);
}

test "spawnNote sets vy to 1.0 and full alpha" {
    const p = spawnNote(0.0, 0.0, 0.0, 12);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), p.vy, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), p.a, 0.001);
}

test "spawnNote applies pitch color" {
    const p = spawnNote(0.0, 0.0, 0.0, 0);
    // pitch 0 = green
    try std.testing.expect(p.g > 0.9);
    try std.testing.expect(p.r < 0.01);
}

test "updateNote particle rises" {
    var p = spawnNote(0.0, 0.0, 0.0, 5);
    const y_before = p.y;
    _ = updateNote(&p, 0.1);
    try std.testing.expect(p.y > y_before);
}

test "updateNote particle fades and shrinks" {
    var p = spawnNote(0.0, 0.0, 0.0, 5);
    const a_before = p.a;
    const size_before = p.size;
    _ = updateNote(&p, 0.1);
    try std.testing.expect(p.a < a_before);
    try std.testing.expect(p.size < size_before);
}

test "updateNote returns false when fully faded" {
    var p = spawnNote(0.0, 0.0, 0.0, 5);
    // Advance far enough to fully fade (alpha starts at 1.0, fades at 0.5/s)
    const alive = updateNote(&p, 3.0);
    try std.testing.expect(!alive);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), p.a, 0.001);
}

test "updateNote returns true while alive" {
    var p = spawnNote(0.0, 0.0, 0.0, 5);
    const alive = updateNote(&p, 0.01);
    try std.testing.expect(alive);
}

test "hsvToRgb pure red" {
    const c = hsvToRgb(0.0, 1.0, 1.0);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), c[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), c[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), c[2], 0.001);
}

test "hsvToRgb pure green" {
    const c = hsvToRgb(120.0, 1.0, 1.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), c[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), c[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), c[2], 0.001);
}

test "hsvToRgb pure blue" {
    const c = hsvToRgb(240.0, 1.0, 1.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), c[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), c[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), c[2], 0.001);
}
