/// Perlin gradient noise (2D) and fractal Brownian motion (fBm).
/// Uses a permutation table seeded at comptime for deterministic results.
const std = @import("std");

/// Compute 2D noise in the range [-1, 1] using a gradient hash approach.
pub fn noise2d(x: f64, y: f64) f64 {
    return gradientNoise2d(x, y, &default_perm);
}

/// Fractal Brownian motion: sum multiple octaves of noise2d for richer terrain.
pub fn fbm2d(x: f64, y: f64, octaves: u32, lacunarity: f64, persistence: f64) f64 {
    var total: f64 = 0.0;
    var amplitude: f64 = 1.0;
    var frequency: f64 = 1.0;
    var max_amplitude: f64 = 0.0;

    for (0..octaves) |_| {
        total += noise2d(x * frequency, y * frequency) * amplitude;
        max_amplitude += amplitude;
        amplitude *= persistence;
        frequency *= lacunarity;
    }

    return total / max_amplitude;
}

/// Seed-aware fBm: offsets the coordinates by a seed-derived value.
pub fn fbm2dSeeded(seed: u64, x: f64, y: f64, octaves: u32, lacunarity: f64, persistence: f64) f64 {
    // Derive a pair of offsets from the seed so different seeds produce different terrain
    const sx: f64 = @floatFromInt(@as(i32, @truncate(@as(i64, @bitCast(seed *% 6364136223846793005 +% 1442695040888963407)))));
    const sy: f64 = @floatFromInt(@as(i32, @truncate(@as(i64, @bitCast(seed *% 1103515245 +% 12345)))));
    const offset_x = sx * 0.0001;
    const offset_y = sy * 0.0001;
    return fbm2d(x + offset_x, y + offset_y, octaves, lacunarity, persistence);
}

// --- Implementation details ---

/// Standard permutation table (Ken Perlin's original, doubled for wrapping).
const default_perm = buildPermTable();

fn buildPermTable() [512]u8 {
    const base = [256]u8{
        151, 160, 137, 91,  90,  15,  131, 13,  201, 95,  96,  53,  194, 233, 7,   225,
        140, 36,  103, 30,  69,  142, 8,   99,  37,  240, 21,  10,  23,  190, 6,   148,
        247, 120, 234, 75,  0,   26,  197, 62,  94,  252, 219, 203, 117, 35,  11,  32,
        57,  177, 33,  88,  237, 149, 56,  87,  174, 20,  125, 136, 171, 168, 68,  175,
        74,  165, 71,  134, 139, 48,  27,  166, 77,  146, 158, 231, 83,  111, 229, 122,
        60,  211, 133, 230, 220, 105, 92,  41,  55,  46,  245, 40,  244, 102, 143, 54,
        65,  25,  63,  161, 1,   216, 80,  73,  209, 76,  132, 187, 208, 89,  18,  169,
        200, 196, 135, 130, 116, 188, 159, 86,  164, 100, 109, 198, 173, 186, 3,   64,
        52,  217, 226, 250, 124, 123, 5,   202, 38,  147, 118, 126, 255, 82,  85,  212,
        207, 206, 59,  227, 47,  16,  58,  17,  182, 189, 28,  42,  223, 183, 170, 213,
        119, 248, 152, 2,   44,  154, 163, 70,  221, 153, 101, 155, 167, 43,  172, 9,
        129, 22,  39,  253, 19,  98,  108, 110, 79,  113, 224, 232, 178, 185, 112, 104,
        218, 246, 97,  228, 251, 34,  242, 193, 238, 210, 144, 12,  191, 179, 162, 241,
        81,  51,  145, 235, 249, 14,  239, 107, 49,  192, 214, 31,  181, 199, 106, 157,
        184, 84,  204, 176, 115, 121, 50,  45,  127, 4,   150, 254, 138, 236, 205, 93,
        222, 114, 67,  29,  24,  72,  243, 141, 128, 195, 78,  66,  215, 61,  156, 180,
    };
    var result: [512]u8 = undefined;
    for (0..512) |i| {
        result[i] = base[i & 255];
    }
    return result;
}

/// Gradient vectors for 2D (using 8 evenly-spaced unit-ish vectors)
const grad2 = [8][2]f64{
    .{ 1, 0 },  .{ -1, 0 },
    .{ 0, 1 },  .{ 0, -1 },
    .{ 1, 1 },  .{ -1, 1 },
    .{ 1, -1 }, .{ -1, -1 },
};

fn gradientNoise2d(x: f64, y: f64, perm: *const [512]u8) f64 {
    const floor_x = @floor(x);
    const floor_y = @floor(y);

    // Integer cell coordinates
    const xi: i32 = @intFromFloat(floor_x);
    const yi: i32 = @intFromFloat(floor_y);

    // Fractional position within cell
    const xf = x - floor_x;
    const yf = y - floor_y;

    // Smoothstep fade curves
    const u = fade(xf);
    const v = fade(yf);

    // Hash coordinates of the 4 cell corners
    const x0: usize = @intCast(xi & 255);
    const x1: usize = @intCast((xi + 1) & 255);
    const y0: usize = @intCast(yi & 255);
    const y1: usize = @intCast((yi + 1) & 255);

    const aa = perm[perm[x0] + y0];
    const ab = perm[perm[x0] + y1];
    const ba = perm[perm[x1] + y0];
    const bb = perm[perm[x1] + y1];

    // Gradient dot products
    const g_aa = dot2(grad2[aa & 7], xf, yf);
    const g_ba = dot2(grad2[ba & 7], xf - 1.0, yf);
    const g_ab = dot2(grad2[ab & 7], xf, yf - 1.0);
    const g_bb = dot2(grad2[bb & 7], xf - 1.0, yf - 1.0);

    // Bilinear interpolation
    const x1_interp = lerp(g_aa, g_ba, u);
    const x2_interp = lerp(g_ab, g_bb, u);
    return lerp(x1_interp, x2_interp, v);
}

fn fade(t: f64) f64 {
    // 6t^5 - 15t^4 + 10t^3
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

fn lerp(a: f64, b: f64, t: f64) f64 {
    return a + t * (b - a);
}

fn dot2(g: [2]f64, x: f64, y: f64) f64 {
    return g[0] * x + g[1] * y;
}

// --- Tests ---

test "noise2d returns values in roughly [-1, 1]" {
    var min_val: f64 = 1.0;
    var max_val: f64 = -1.0;

    var y: f64 = -10.0;
    while (y < 10.0) : (y += 0.37) {
        var x: f64 = -10.0;
        while (x < 10.0) : (x += 0.37) {
            const v = noise2d(x, y);
            if (v < min_val) min_val = v;
            if (v > max_val) max_val = v;
        }
    }

    try std.testing.expect(min_val >= -1.5);
    try std.testing.expect(max_val <= 1.5);
    // Should have some variation
    try std.testing.expect(max_val - min_val > 0.5);
}

test "fbm2d returns bounded values" {
    const v = fbm2d(3.14, 2.71, 4, 2.0, 0.5);
    try std.testing.expect(v >= -1.5 and v <= 1.5);
}

test "fbm2dSeeded produces different results for different seeds" {
    const v1 = fbm2dSeeded(42, 5.0, 5.0, 4, 2.0, 0.5);
    const v2 = fbm2dSeeded(123, 5.0, 5.0, 4, 2.0, 0.5);
    try std.testing.expect(v1 != v2);
}
