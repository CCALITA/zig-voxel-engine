/// Water surface renderer with lowered top face, animated UV offset,
/// biome-tinted semi-transparent color, and per-face quad generation.
const std = @import("std");

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

pub const WaterVertex = struct {
    x: f32,
    y: f32,
    z: f32,
    u: f32,
    v: f32,
    alpha: f32,
};

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/// Water block IDs recognized by this renderer.
const WATER_STILL: u16 = 8;
const WATER_FLOWING: u16 = 9;

/// Default water alpha for unknown biomes.
const default_alpha: f32 = 0.7;

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Height of the water surface (top face Y offset within a block).
/// Standard blocks use 1.0; water sits 1/8 block lower.
pub fn getWaterTopY() f32 {
    return 0.875;
}

/// Animated UV offset driven by a slow sinusoidal drift.
/// Returns `[2]f32` with U and V offsets suitable for scrolling a water texture.
pub fn getWaterUVOffset(time: f32) [2]f32 {
    return .{
        @sin(time * 0.3) * 0.05,
        @cos(time * 0.2) * 0.05,
    };
}

/// Biome-tinted water color as RGBA.  Alpha is always 0.7.
///
/// Biome IDs:
///   0 = plains (default blue)
///   1 = swamp  (murky green)
///   2 = ocean  (deep blue)
///   3 = warm ocean (turquoise)
///   4 = frozen (icy pale blue)
pub fn getWaterColor(biome: u8) [4]f32 {
    return switch (biome) {
        1 => .{ 0.24, 0.38, 0.16, default_alpha }, // swamp
        2 => .{ 0.10, 0.20, 0.60, default_alpha }, // ocean
        3 => .{ 0.17, 0.65, 0.68, default_alpha }, // warm ocean
        4 => .{ 0.58, 0.72, 0.86, default_alpha }, // frozen
        else => .{ 0.24, 0.46, 0.92, default_alpha }, // plains / default
    };
}

/// Returns `true` when `block_id` represents a water block (still or flowing).
pub fn isWaterBlock(block_id: u16) bool {
    return block_id == WATER_STILL or block_id == WATER_FLOWING;
}

/// Generate the four corner vertices of a single face for a water block
/// located at world position (`wx`, `wy`, `wz`).
///
/// Face indices follow the engine convention:
///   0 = north (-Z), 1 = south (+Z), 2 = east (+X),
///   3 = west (-X),  4 = top (+Y),   5 = bottom (-Y).
///
/// The top face (4) uses a lowered Y of `wy + 0.875` instead of `wy + 1.0`
/// and applies the animated UV offset derived from `time`.
pub fn generateWaterFace(wx: f32, wy: f32, wz: f32, face: u3, time: f32) [4]WaterVertex {
    const uv_off = getWaterUVOffset(time);
    const top_y = wy + getWaterTopY();

    return switch (face) {
        // north (-Z)
        0 => makeFace(
            .{ wx, wy, wz },
            .{ wx + 1, wy, wz },
            .{ wx + 1, top_y, wz },
            .{ wx, top_y, wz },
            uv_off,
        ),
        // south (+Z)
        1 => makeFace(
            .{ wx + 1, wy, wz + 1 },
            .{ wx, wy, wz + 1 },
            .{ wx, top_y, wz + 1 },
            .{ wx + 1, top_y, wz + 1 },
            uv_off,
        ),
        // east (+X)
        2 => makeFace(
            .{ wx + 1, wy, wz },
            .{ wx + 1, wy, wz + 1 },
            .{ wx + 1, top_y, wz + 1 },
            .{ wx + 1, top_y, wz },
            uv_off,
        ),
        // west (-X)
        3 => makeFace(
            .{ wx, wy, wz + 1 },
            .{ wx, wy, wz },
            .{ wx, top_y, wz },
            .{ wx, top_y, wz + 1 },
            uv_off,
        ),
        // top (+Y)  --  lowered surface
        4 => makeFace(
            .{ wx, top_y, wz },
            .{ wx + 1, top_y, wz },
            .{ wx + 1, top_y, wz + 1 },
            .{ wx, top_y, wz + 1 },
            uv_off,
        ),
        // bottom (-Y)
        5 => makeFace(
            .{ wx, wy, wz + 1 },
            .{ wx + 1, wy, wz + 1 },
            .{ wx + 1, wy, wz },
            .{ wx, wy, wz },
            uv_off,
        ),
        else => unreachable,
    };
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/// Build four `WaterVertex` values from four corner positions and a UV offset.
/// UVs are assigned as a unit quad (0..1) then shifted by the animated offset.
fn makeFace(
    bl: [3]f32,
    br: [3]f32,
    tr: [3]f32,
    tl: [3]f32,
    uv_off: [2]f32,
) [4]WaterVertex {
    return .{
        .{ .x = bl[0], .y = bl[1], .z = bl[2], .u = uv_off[0], .v = uv_off[1], .alpha = default_alpha },
        .{ .x = br[0], .y = br[1], .z = br[2], .u = 1.0 + uv_off[0], .v = uv_off[1], .alpha = default_alpha },
        .{ .x = tr[0], .y = tr[1], .z = tr[2], .u = 1.0 + uv_off[0], .v = 1.0 + uv_off[1], .alpha = default_alpha },
        .{ .x = tl[0], .y = tl[1], .z = tl[2], .u = uv_off[0], .v = 1.0 + uv_off[1], .alpha = default_alpha },
    };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "getWaterTopY returns 0.875" {
    try std.testing.expectEqual(@as(f32, 0.875), getWaterTopY());
}

test "getWaterUVOffset returns zero at time zero" {
    const off = getWaterUVOffset(0.0);
    // sin(0) == 0, cos(0) == 1 -> second component is non-zero
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), off[0], 0.001);
    // cos(0) * 0.05 == 0.05
    try std.testing.expectApproxEqAbs(@as(f32, 0.05), off[1], 0.001);
}

test "getWaterUVOffset varies with time" {
    const a = getWaterUVOffset(0.0);
    const b = getWaterUVOffset(5.0);
    // At least one component must differ meaningfully
    const differs = @abs(a[0] - b[0]) > 0.001 or @abs(a[1] - b[1]) > 0.001;
    try std.testing.expect(differs);
}

test "getWaterUVOffset stays within bounds" {
    // Amplitude is 0.05 for both axes, so values stay in [-0.05, 0.05]
    var t: f32 = 0.0;
    while (t < 100.0) : (t += 0.7) {
        const off = getWaterUVOffset(t);
        try std.testing.expect(@abs(off[0]) <= 0.0501);
        try std.testing.expect(@abs(off[1]) <= 0.0501);
    }
}

test "getWaterColor plains default has alpha 0.7" {
    const c = getWaterColor(0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.7), c[3], 0.001);
}

test "getWaterColor biomes return distinct tints" {
    const plains = getWaterColor(0);
    const swamp = getWaterColor(1);
    const ocean = getWaterColor(2);
    const warm = getWaterColor(3);
    const frozen = getWaterColor(4);

    // All must have alpha 0.7
    for ([_][4]f32{ plains, swamp, ocean, warm, frozen }) |c| {
        try std.testing.expectApproxEqAbs(@as(f32, 0.7), c[3], 0.001);
    }

    // Biome tints must be distinct from one another in RGB
    const colors = [_][4]f32{ plains, swamp, ocean, warm, frozen };
    for (0..colors.len) |i| {
        for (i + 1..colors.len) |j| {
            const dr = @abs(colors[i][0] - colors[j][0]);
            const dg = @abs(colors[i][1] - colors[j][1]);
            const db = @abs(colors[i][2] - colors[j][2]);
            try std.testing.expect(dr + dg + db > 0.01);
        }
    }
}

test "getWaterColor unknown biome falls back to plains" {
    const plains = getWaterColor(0);
    const unknown = getWaterColor(255);
    try std.testing.expectApproxEqAbs(plains[0], unknown[0], 0.001);
    try std.testing.expectApproxEqAbs(plains[1], unknown[1], 0.001);
    try std.testing.expectApproxEqAbs(plains[2], unknown[2], 0.001);
    try std.testing.expectApproxEqAbs(plains[3], unknown[3], 0.001);
}

test "isWaterBlock identifies still and flowing water" {
    try std.testing.expect(isWaterBlock(8));
    try std.testing.expect(isWaterBlock(9));
}

test "isWaterBlock rejects non-water blocks" {
    try std.testing.expect(!isWaterBlock(0));
    try std.testing.expect(!isWaterBlock(1));
    try std.testing.expect(!isWaterBlock(7));
    try std.testing.expect(!isWaterBlock(10));
    try std.testing.expect(!isWaterBlock(255));
    try std.testing.expect(!isWaterBlock(65535));
}

test "generateWaterFace top face uses lowered Y" {
    const verts = generateWaterFace(0.0, 10.0, 0.0, 4, 0.0);
    for (verts) |v| {
        try std.testing.expectApproxEqAbs(@as(f32, 10.875), v.y, 0.001);
    }
}

test "generateWaterFace bottom face uses block base Y" {
    const verts = generateWaterFace(5.0, 3.0, 7.0, 5, 0.0);
    for (verts) |v| {
        try std.testing.expectApproxEqAbs(@as(f32, 3.0), v.y, 0.001);
    }
}

test "generateWaterFace all faces have alpha 0.7" {
    var face: u3 = 0;
    while (face < 6) : (face += 1) {
        const verts = generateWaterFace(0.0, 0.0, 0.0, face, 1.23);
        for (verts) |v| {
            try std.testing.expectApproxEqAbs(@as(f32, 0.7), v.alpha, 0.001);
        }
    }
}

test "generateWaterFace UV animated offset applied" {
    const verts_t0 = generateWaterFace(0.0, 0.0, 0.0, 4, 0.0);
    const verts_t5 = generateWaterFace(0.0, 0.0, 0.0, 4, 5.0);
    // At different times the UVs should shift
    var uv_differs = false;
    for (verts_t0, verts_t5) |a, b| {
        if (@abs(a.u - b.u) > 0.001 or @abs(a.v - b.v) > 0.001) {
            uv_differs = true;
        }
    }
    try std.testing.expect(uv_differs);
}

test "generateWaterFace produces four distinct vertices per face" {
    const verts = generateWaterFace(0.0, 0.0, 0.0, 0, 0.0);
    // At least two vertices must differ in position
    var unique_count: u32 = 0;
    for (0..4) |i| {
        var is_unique = true;
        for (0..i) |j| {
            if (@abs(verts[i].x - verts[j].x) < 0.001 and
                @abs(verts[i].y - verts[j].y) < 0.001 and
                @abs(verts[i].z - verts[j].z) < 0.001)
            {
                is_unique = false;
            }
        }
        if (is_unique) unique_count += 1;
    }
    try std.testing.expect(unique_count >= 3);
}

test "generateWaterFace side faces span from base to lowered top" {
    const wy: f32 = 4.0;
    const verts = generateWaterFace(0.0, wy, 0.0, 0, 0.0); // north face
    var min_y: f32 = std.math.inf(f32);
    var max_y: f32 = -std.math.inf(f32);
    for (verts) |v| {
        if (v.y < min_y) min_y = v.y;
        if (v.y > max_y) max_y = v.y;
    }
    try std.testing.expectApproxEqAbs(wy, min_y, 0.001);
    try std.testing.expectApproxEqAbs(wy + 0.875, max_y, 0.001);
}

test "WaterVertex struct has expected fields" {
    const v = WaterVertex{
        .x = 1.0,
        .y = 2.0,
        .z = 3.0,
        .u = 0.5,
        .v = 0.5,
        .alpha = 0.7,
    };
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), v.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), v.y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), v.z, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), v.u, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), v.v, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.7), v.alpha, 0.001);
}
