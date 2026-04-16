/// Perlin noise implementation for terrain generation.
/// Pure math, only depends on `std`. Provides 2D and 3D noise plus
/// fractal Brownian motion (fBm) with configurable octaves.
const std = @import("std");

// ---------------------------------------------------------------------------
// Permutation table (seeded)
// ---------------------------------------------------------------------------

pub const PermTable = struct {
    perm: [512]u8,

    pub fn init(seed: u64) PermTable {
        var p: [256]u8 = undefined;
        for (0..256) |i| {
            p[i] = @intCast(i);
        }

        // Fisher-Yates shuffle driven by a simple splitmix64 PRNG
        var s = seed;
        var i: usize = 255;
        while (i > 0) : (i -= 1) {
            s = splitmix64(s);
            const j = s % (i + 1);
            const tmp = p[i];
            p[i] = p[j];
            p[j] = tmp;
        }

        var perm: [512]u8 = undefined;
        for (0..512) |idx| {
            perm[idx] = p[idx & 255];
        }
        return .{ .perm = perm };
    }
};

fn splitmix64(state: u64) u64 {
    var s = state +% 0x9e3779b97f4a7c15;
    s = (s ^ (s >> 30)) *% 0xbf58476d1ce4e5b9;
    s = (s ^ (s >> 27)) *% 0x94d049bb133111eb;
    return s ^ (s >> 31);
}

// ---------------------------------------------------------------------------
// Gradient tables
// ---------------------------------------------------------------------------

const grad3 = [12][3]f64{
    .{ 1, 1, 0 },  .{ -1, 1, 0 },  .{ 1, -1, 0 },  .{ -1, -1, 0 },
    .{ 1, 0, 1 },  .{ -1, 0, 1 },  .{ 1, 0, -1 },  .{ -1, 0, -1 },
    .{ 0, 1, 1 },  .{ 0, -1, 1 },  .{ 0, 1, -1 },  .{ 0, -1, -1 },
};

fn dot2(g: [3]f64, x: f64, y: f64) f64 {
    return g[0] * x + g[1] * y;
}

fn dot3(g: [3]f64, x: f64, y: f64, z: f64) f64 {
    return g[0] * x + g[1] * y + g[2] * z;
}

// ---------------------------------------------------------------------------
// 2D Perlin noise
// ---------------------------------------------------------------------------

fn fade(t: f64) f64 {
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

fn lerp(t: f64, a: f64, b: f64) f64 {
    return a + t * (b - a);
}

/// 2D Perlin noise. Returns a value in approximately [-1, 1].
pub fn noise2d(pt: *const PermTable, x: f64, y: f64) f64 {
    const xi: i32 = floorToInt(x);
    const yi: i32 = floorToInt(y);

    const xf = x - @as(f64, @floatFromInt(xi));
    const yf = y - @as(f64, @floatFromInt(yi));

    const u = fade(xf);
    const v = fade(yf);

    const px: usize = @intCast(xi & 255);
    const py: usize = @intCast(yi & 255);

    const aa = pt.perm[pt.perm[px] +% py];
    const ab = pt.perm[pt.perm[px] +% py +% 1];
    const ba = pt.perm[pt.perm[px +% 1] +% py];
    const bb = pt.perm[pt.perm[px +% 1] +% py +% 1];

    const g_aa = grad3[aa % 12];
    const g_ba = grad3[ba % 12];
    const g_ab = grad3[ab % 12];
    const g_bb = grad3[bb % 12];

    const n00 = dot2(g_aa, xf, yf);
    const n10 = dot2(g_ba, xf - 1.0, yf);
    const n01 = dot2(g_ab, xf, yf - 1.0);
    const n11 = dot2(g_bb, xf - 1.0, yf - 1.0);

    const nx0 = lerp(u, n00, n10);
    const nx1 = lerp(u, n01, n11);
    return lerp(v, nx0, nx1);
}

// ---------------------------------------------------------------------------
// 3D Perlin noise
// ---------------------------------------------------------------------------

/// 3D Perlin noise. Returns a value in approximately [-1, 1].
pub fn noise3d(pt: *const PermTable, x: f64, y: f64, z: f64) f64 {
    const xi: i32 = floorToInt(x);
    const yi: i32 = floorToInt(y);
    const zi: i32 = floorToInt(z);

    const xf = x - @as(f64, @floatFromInt(xi));
    const yf = y - @as(f64, @floatFromInt(yi));
    const zf = z - @as(f64, @floatFromInt(zi));

    const u = fade(xf);
    const v = fade(yf);
    const w = fade(zf);

    const px: usize = @intCast(xi & 255);
    const py: usize = @intCast(yi & 255);
    const pz: usize = @intCast(zi & 255);

    const a = pt.perm[px] +% py;
    const aa = pt.perm[a] +% pz;
    const ab = pt.perm[a +% 1] +% pz;
    const b = pt.perm[px +% 1] +% py;
    const ba = pt.perm[b] +% pz;
    const bb = pt.perm[b +% 1] +% pz;

    const g_aaa = grad3[pt.perm[aa] % 12];
    const g_baa = grad3[pt.perm[ba] % 12];
    const g_aba = grad3[pt.perm[ab] % 12];
    const g_bba = grad3[pt.perm[bb] % 12];
    const g_aab = grad3[pt.perm[aa +% 1] % 12];
    const g_bab = grad3[pt.perm[ba +% 1] % 12];
    const g_abb = grad3[pt.perm[ab +% 1] % 12];
    const g_bbb = grad3[pt.perm[bb +% 1] % 12];

    const n000 = dot3(g_aaa, xf, yf, zf);
    const n100 = dot3(g_baa, xf - 1.0, yf, zf);
    const n010 = dot3(g_aba, xf, yf - 1.0, zf);
    const n110 = dot3(g_bba, xf - 1.0, yf - 1.0, zf);
    const n001 = dot3(g_aab, xf, yf, zf - 1.0);
    const n101 = dot3(g_bab, xf - 1.0, yf, zf - 1.0);
    const n011 = dot3(g_abb, xf, yf - 1.0, zf - 1.0);
    const n111 = dot3(g_bbb, xf - 1.0, yf - 1.0, zf - 1.0);

    const nx00 = lerp(u, n000, n100);
    const nx10 = lerp(u, n010, n110);
    const nx01 = lerp(u, n001, n101);
    const nx11 = lerp(u, n011, n111);

    const nxy0 = lerp(v, nx00, nx10);
    const nxy1 = lerp(v, nx01, nx11);

    return lerp(w, nxy0, nxy1);
}

// ---------------------------------------------------------------------------
// Fractal Brownian motion (fBm)
// ---------------------------------------------------------------------------

/// Fractal Brownian motion using 2D Perlin noise.
/// `octaves`     -- number of noise layers (typically 1..8)
/// `lacunarity`  -- frequency multiplier per octave (typically 2.0)
/// `persistence` -- amplitude multiplier per octave (typically 0.5)
/// Returns a value whose range grows with octaves but stays near [-1, 1] for
/// typical parameters.
pub fn fbm2d(
    pt: *const PermTable,
    x: f64,
    y: f64,
    octaves: u32,
    lacunarity: f64,
    persistence: f64,
) f64 {
    var total: f64 = 0.0;
    var frequency: f64 = 1.0;
    var amplitude: f64 = 1.0;
    var max_amplitude: f64 = 0.0;

    for (0..octaves) |_| {
        total += noise2d(pt, x * frequency, y * frequency) * amplitude;
        max_amplitude += amplitude;
        amplitude *= persistence;
        frequency *= lacunarity;
    }

    // Normalize so result stays in [-1, 1]
    return total / max_amplitude;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

fn floorToInt(v: f64) i32 {
    const floored = @floor(v);
    return @intFromFloat(floored);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "noise2d determinism" {
    const pt = PermTable.init(42);
    const a = noise2d(&pt, 1.5, 2.7);
    const b = noise2d(&pt, 1.5, 2.7);
    try std.testing.expectEqual(a, b);
}

test "noise3d determinism" {
    const pt = PermTable.init(42);
    const a = noise3d(&pt, 1.5, 2.7, 3.3);
    const b = noise3d(&pt, 1.5, 2.7, 3.3);
    try std.testing.expectEqual(a, b);
}

test "noise2d output range" {
    const pt = PermTable.init(123);
    var min_val: f64 = 1.0;
    var max_val: f64 = -1.0;
    var y: f64 = -10.0;
    while (y < 10.0) : (y += 0.37) {
        var x: f64 = -10.0;
        while (x < 10.0) : (x += 0.37) {
            const v = noise2d(&pt, x, y);
            if (v < min_val) min_val = v;
            if (v > max_val) max_val = v;
        }
    }
    try std.testing.expect(min_val >= -1.0);
    try std.testing.expect(max_val <= 1.0);
}

test "noise3d output range" {
    const pt = PermTable.init(456);
    var min_val: f64 = 1.0;
    var max_val: f64 = -1.0;
    var z: f64 = -5.0;
    while (z < 5.0) : (z += 0.97) {
        var y: f64 = -5.0;
        while (y < 5.0) : (y += 0.97) {
            var x: f64 = -5.0;
            while (x < 5.0) : (x += 0.97) {
                const v = noise3d(&pt, x, y, z);
                if (v < min_val) min_val = v;
                if (v > max_val) max_val = v;
            }
        }
    }
    try std.testing.expect(min_val >= -1.0);
    try std.testing.expect(max_val <= 1.0);
}

test "fbm2d determinism" {
    const pt = PermTable.init(42);
    const a = fbm2d(&pt, 3.14, 2.71, 4, 2.0, 0.5);
    const b = fbm2d(&pt, 3.14, 2.71, 4, 2.0, 0.5);
    try std.testing.expectEqual(a, b);
}

test "fbm2d output range" {
    const pt = PermTable.init(789);
    var min_val: f64 = 1.0;
    var max_val: f64 = -1.0;
    var y: f64 = -10.0;
    while (y < 10.0) : (y += 0.73) {
        var x: f64 = -10.0;
        while (x < 10.0) : (x += 0.73) {
            const v = fbm2d(&pt, x, y, 6, 2.0, 0.5);
            if (v < min_val) min_val = v;
            if (v > max_val) max_val = v;
        }
    }
    try std.testing.expect(min_val >= -1.0);
    try std.testing.expect(max_val <= 1.0);
}

test "frequency scaling changes output" {
    const pt = PermTable.init(42);
    // Sample the same world point at two different frequencies
    const base_x: f64 = 3.7;
    const base_y: f64 = 5.3;
    const lo = noise2d(&pt, base_x * 1.0, base_y * 1.0);
    const hi = noise2d(&pt, base_x * 4.0, base_y * 4.0);
    // Different frequencies should produce different values
    try std.testing.expect(lo != hi);
}

test "different seeds produce different tables" {
    const pt_a = PermTable.init(1);
    const pt_b = PermTable.init(2);
    var diffs: u32 = 0;
    for (0..256) |i| {
        if (pt_a.perm[i] != pt_b.perm[i]) diffs += 1;
    }
    // The vast majority of entries should differ between two different seeds
    try std.testing.expect(diffs > 100);
}
