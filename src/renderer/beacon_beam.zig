const std = @import("std");

/// A single visual segment of a beacon beam column.
pub const BeamSegment = struct {
    x: f32,
    z: f32,
    y_bottom: f32,
    y_top: f32,
    r: f32,
    g: f32,
    b: f32,
    a: f32,
    width: f32,
};

/// Minecraft stained glass color palette (16 colors).
/// Index maps to dye/glass color metadata values 0-15.
const glass_colors = [16][3]f32{
    .{ 1.0, 1.0, 1.0 }, // 0: white
    .{ 0.85, 0.52, 0.24 }, // 1: orange
    .{ 0.70, 0.33, 0.85 }, // 2: magenta
    .{ 0.40, 0.60, 0.85 }, // 3: light blue
    .{ 0.90, 0.90, 0.20 }, // 4: yellow
    .{ 0.50, 0.80, 0.10 }, // 5: lime
    .{ 0.85, 0.55, 0.70 }, // 6: pink
    .{ 0.30, 0.30, 0.30 }, // 7: gray
    .{ 0.60, 0.60, 0.60 }, // 8: light gray
    .{ 0.25, 0.50, 0.60 }, // 9: cyan
    .{ 0.50, 0.25, 0.70 }, // 10: purple
    .{ 0.20, 0.30, 0.70 }, // 11: blue
    .{ 0.40, 0.30, 0.20 }, // 12: brown
    .{ 0.30, 0.50, 0.10 }, // 13: green
    .{ 0.80, 0.25, 0.25 }, // 14: red
    .{ 0.10, 0.10, 0.10 }, // 15: black
};

/// Return the RGB color for a stained glass color id (0-15).
/// Unknown ids fall back to white.
pub fn getBeamColor(glass_color_id: u8) [3]f32 {
    if (glass_color_id >= glass_colors.len) {
        return glass_colors[0]; // white fallback
    }
    return glass_colors[glass_color_id];
}

/// Generate four beacon beam segments at the given block position.
///
/// The beam is divided into 4 vertical segments of increasing height.
/// Each segment alternates between inner (bright, narrow) and outer
/// (faint, wider) layers:
///   - Segment 0: inner, y  [by, by + height*0.1)
///   - Segment 1: outer, y  [by + height*0.1, by + height*0.3)
///   - Segment 2: inner, y  [by + height*0.3, by + height*0.6)
///   - Segment 3: outer, y  [by + height*0.6, by + height)
///
/// `time` drives a subtle pulsing effect on alpha.
pub fn generateBeam(
    bx: f32,
    bz: f32,
    by: f32,
    height: f32,
    cr: f32,
    cg: f32,
    cb: f32,
    time: f32,
) [4]BeamSegment {
    const h = @max(height, 0.0);
    const pulse = 0.5 + 0.5 * @cos(time * 2.0);

    // Fractional boundaries for the 4 segments (increasing height).
    const fracs = [5]f32{ 0.0, 0.1, 0.3, 0.6, 1.0 };

    // Inner vs outer properties per segment.
    const inner_width: f32 = 0.2;
    const outer_width: f32 = 0.6;
    const inner_alpha_base: f32 = 0.9;
    const outer_alpha_base: f32 = 0.35;

    var segments: [4]BeamSegment = undefined;
    for (0..4) |i| {
        const is_inner = (i % 2 == 0);
        const width = if (is_inner) inner_width else outer_width;
        const alpha_base = if (is_inner) inner_alpha_base else outer_alpha_base;
        const alpha = alpha_base + pulse * 0.1;

        segments[i] = .{
            .x = bx,
            .z = bz,
            .y_bottom = by + fracs[i] * h,
            .y_top = by + fracs[i + 1] * h,
            .r = cr,
            .g = cg,
            .b = cb,
            .a = clamp01(alpha),
            .width = width,
        };
    }
    return segments;
}

fn clamp01(v: f32) f32 {
    return @max(0.0, @min(1.0, v));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

const expectApprox = std.testing.expectApproxEqAbs;
const expect = std.testing.expect;
const tolerance: f32 = 0.001;

test "generateBeam returns 4 segments" {
    const segs = generateBeam(0, 0, 0, 100, 1, 1, 1, 0);
    try std.testing.expectEqual(@as(usize, 4), segs.len);
}

test "segments span full height without gaps" {
    const by: f32 = 10.0;
    const height: f32 = 200.0;
    const segs = generateBeam(5, 7, by, height, 1, 1, 1, 0);

    // First segment starts at by
    try expectApprox(by, segs[0].y_bottom, tolerance);
    // Last segment ends at by + height
    try expectApprox(by + height, segs[3].y_top, tolerance);
    // Each segment connects to the next
    for (0..3) |i| {
        try expectApprox(segs[i].y_top, segs[i + 1].y_bottom, tolerance);
    }
}

test "segment heights increase" {
    const segs = generateBeam(0, 0, 0, 100, 1, 1, 1, 0);
    var prev_height: f32 = 0.0;
    for (segs) |s| {
        const seg_h = s.y_top - s.y_bottom;
        try expect(seg_h > prev_height);
        prev_height = seg_h;
    }
}

test "inner segments are narrow, outer segments are wide" {
    const segs = generateBeam(0, 0, 0, 100, 1, 1, 1, 0);
    // Segments 0, 2 are inner (narrow); 1, 3 are outer (wide)
    try expect(segs[0].width < segs[1].width);
    try expect(segs[2].width < segs[3].width);
    try expectApprox(segs[0].width, segs[2].width, tolerance);
    try expectApprox(segs[1].width, segs[3].width, tolerance);
}

test "inner segments are brighter than outer" {
    const segs = generateBeam(0, 0, 0, 100, 1, 1, 1, 0);
    try expect(segs[0].a > segs[1].a);
    try expect(segs[2].a > segs[3].a);
}

test "beam carries provided color" {
    const segs = generateBeam(0, 0, 0, 50, 0.2, 0.4, 0.8, 0);
    for (segs) |s| {
        try expectApprox(0.2, s.r, tolerance);
        try expectApprox(0.4, s.g, tolerance);
        try expectApprox(0.8, s.b, tolerance);
    }
}

test "beam position matches input" {
    const segs = generateBeam(3.5, -2.0, 64.0, 100, 1, 1, 1, 0);
    for (segs) |s| {
        try expectApprox(3.5, s.x, tolerance);
        try expectApprox(-2.0, s.z, tolerance);
    }
}

test "alpha is clamped to 0-1" {
    // Test with different time values to exercise pulse range
    for ([_]f32{ 0.0, 1.0, 3.14, 100.0 }) |t| {
        const segs = generateBeam(0, 0, 0, 100, 1, 1, 1, t);
        for (segs) |s| {
            try expect(s.a >= 0.0 and s.a <= 1.0);
        }
    }
}

test "zero height produces zero-height segments" {
    const segs = generateBeam(0, 0, 0, 0, 1, 1, 1, 0);
    for (segs) |s| {
        try expectApprox(s.y_bottom, s.y_top, tolerance);
    }
}

test "negative height is treated as zero" {
    const segs = generateBeam(0, 0, 5.0, -10.0, 1, 1, 1, 0);
    for (segs) |s| {
        try expectApprox(5.0, s.y_bottom, tolerance);
        try expectApprox(5.0, s.y_top, tolerance);
    }
}

test "getBeamColor returns correct white" {
    const c = getBeamColor(0);
    try expectApprox(1.0, c[0], tolerance);
    try expectApprox(1.0, c[1], tolerance);
    try expectApprox(1.0, c[2], tolerance);
}

test "getBeamColor returns correct orange" {
    const c = getBeamColor(1);
    try expectApprox(0.85, c[0], tolerance);
    try expectApprox(0.52, c[1], tolerance);
    try expectApprox(0.24, c[2], tolerance);
}

test "getBeamColor returns correct blue" {
    const c = getBeamColor(11);
    try expectApprox(0.20, c[0], tolerance);
    try expectApprox(0.30, c[1], tolerance);
    try expectApprox(0.70, c[2], tolerance);
}

test "getBeamColor returns correct red" {
    const c = getBeamColor(14);
    try expectApprox(0.80, c[0], tolerance);
    try expectApprox(0.25, c[1], tolerance);
    try expectApprox(0.25, c[2], tolerance);
}

test "getBeamColor falls back to white for invalid id" {
    const c = getBeamColor(16);
    try expectApprox(1.0, c[0], tolerance);
    try expectApprox(1.0, c[1], tolerance);
    try expectApprox(1.0, c[2], tolerance);

    const c2 = getBeamColor(255);
    try expectApprox(1.0, c2[0], tolerance);
}

test "all 16 glass colors are unique" {
    for (0..16) |i| {
        for (i + 1..16) |j| {
            const ci = glass_colors[i];
            const cj = glass_colors[j];
            const same = (@abs(ci[0] - cj[0]) < 0.01 and
                @abs(ci[1] - cj[1]) < 0.01 and
                @abs(ci[2] - cj[2]) < 0.01);
            try expect(!same);
        }
    }
}

test "time pulse affects alpha" {
    const segs_a = generateBeam(0, 0, 0, 100, 1, 1, 1, 0.0);
    const segs_b = generateBeam(0, 0, 0, 100, 1, 1, 1, std.math.pi / 2.0);
    // At time=0, cos(0)=1 so pulse=1. At time=pi/2, cos(pi)=-1 so pulse=0.
    // The alpha values should differ.
    var any_diff = false;
    for (0..4) |i| {
        if (@abs(segs_a[i].a - segs_b[i].a) > 0.01) any_diff = true;
    }
    try expect(any_diff);
}
