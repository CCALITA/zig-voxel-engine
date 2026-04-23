const std = @import("std");

/// A floating glyph particle orbiting an enchanting table.
pub const GlyphParticle = struct {
    x: f32,
    y: f32,
    z: f32,
    glyph_id: u8,
    alpha: f32,
    size: f32,
};

/// Number of glyph particles generated per call.
const glyph_count = 16;

/// Base orbit radius range: glyphs orbit between 2 and 4 blocks from center.
const min_radius: f32 = 2.0;
const max_radius: f32 = 4.0;

/// Vertical bobbing amplitude in blocks.
const bob_amplitude: f32 = 0.5;

/// Base angular speed in radians per second (slow drift).
const base_angular_speed: f32 = 0.3;

/// The enchanting purple color: (r=0.5, g=0.2, b=0.8).
const glyph_color: [3]f32 = .{ 0.5, 0.2, 0.8 };

/// Book oscillation angular frequency (radians per second).
const book_frequency: f32 = 0.8;

/// Book oscillation amplitude in radians (~17 degrees).
const book_amplitude: f32 = 0.3;

/// Generate 16 glyph particles orbiting the enchanting table center.
///
/// Each glyph occupies a unique angular slot (evenly spaced around the circle).
/// More bookshelves increase alpha, size, and angular speed, making the effect
/// more active. Particles orbit at radii between 2 and 4 blocks and bob
/// vertically with a sinusoidal offset.
pub fn generateGlyphs(tx: f32, ty: f32, tz: f32, time: f32, bookshelf_count: u8) [glyph_count]GlyphParticle {
    var result: [glyph_count]GlyphParticle = undefined;

    // Bookshelf influence: 0 shelves = minimal activity, 15 shelves = full.
    const shelves: f32 = @floatFromInt(@min(bookshelf_count, 15));
    const shelf_ratio = shelves / 15.0;
    const activity = 0.3 + 0.7 * shelf_ratio;

    const angular_speed = base_angular_speed * (1.0 + shelf_ratio);

    for (0..glyph_count) |i| {
        const idx: f32 = @floatFromInt(i);

        // Each particle gets an evenly-spaced base angle plus a time-driven rotation.
        const slot_angle = (idx / @as(f32, @floatFromInt(glyph_count))) * 2.0 * std.math.pi;
        const angle = slot_angle + time * angular_speed;

        // Radius varies per particle using a simple deterministic pattern.
        const radius_t = @mod(idx * 0.618, 1.0); // golden-ratio spacing in [0,1)
        const radius = min_radius + radius_t * (max_radius - min_radius);

        // Vertical bobbing: each particle bobs at a different phase.
        const bob_phase = slot_angle * 2.0 + time * 1.5;
        const y_offset = bob_amplitude * @sin(bob_phase);

        result[i] = .{
            .x = tx + radius * @cos(angle),
            .y = ty + 1.0 + y_offset,
            .z = tz + radius * @sin(angle),
            .glyph_id = @as(u8, @intCast(i)) *% 16 +% 1,
            .alpha = activity,
            .size = 0.15 + 0.10 * activity,
        };
    }

    return result;
}

/// Return the book opening angle at the given time.
///
/// The book slowly oscillates using a sinusoidal wave, simulating the
/// enchanting table book gently opening and closing.
pub fn getBookAngle(time: f32) f32 {
    return book_amplitude * @sin(time * book_frequency);
}

/// Return the canonical enchanting glyph color: purple (0.5, 0.2, 0.8).
pub fn getGlyphColor() [3]f32 {
    return glyph_color;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "generateGlyphs returns 16 particles" {
    const glyphs = generateGlyphs(0.0, 0.0, 0.0, 0.0, 0);
    try std.testing.expectEqual(@as(usize, 16), glyphs.len);
}

test "generateGlyphs particles orbit within radius 2-4" {
    const glyphs = generateGlyphs(5.0, 10.0, 5.0, 1.0, 8);
    for (glyphs) |g| {
        const dx = g.x - 5.0;
        const dz = g.z - 5.0;
        const dist = @sqrt(dx * dx + dz * dz);
        try std.testing.expect(dist >= min_radius - 0.01);
        try std.testing.expect(dist <= max_radius + 0.01);
    }
}

test "generateGlyphs particles are near table y" {
    const glyphs = generateGlyphs(0.0, 10.0, 0.0, 0.0, 0);
    for (glyphs) |g| {
        // y should be around ty + 1.0, within bob_amplitude
        try std.testing.expect(g.y >= 10.0 + 1.0 - bob_amplitude - 0.01);
        try std.testing.expect(g.y <= 10.0 + 1.0 + bob_amplitude + 0.01);
    }
}

test "generateGlyphs more bookshelves increase alpha" {
    const low = generateGlyphs(0.0, 0.0, 0.0, 0.0, 0);
    const high = generateGlyphs(0.0, 0.0, 0.0, 0.0, 15);
    try std.testing.expect(high[0].alpha > low[0].alpha);
}

test "generateGlyphs more bookshelves increase size" {
    const low = generateGlyphs(0.0, 0.0, 0.0, 0.0, 0);
    const high = generateGlyphs(0.0, 0.0, 0.0, 0.0, 15);
    try std.testing.expect(high[0].size > low[0].size);
}

test "generateGlyphs positions change with time" {
    const a = generateGlyphs(0.0, 0.0, 0.0, 0.0, 5);
    const b = generateGlyphs(0.0, 0.0, 0.0, 1.0, 5);
    var any_diff = false;
    for (0..glyph_count) |i| {
        if (@abs(a[i].x - b[i].x) > 0.001) any_diff = true;
    }
    try std.testing.expect(any_diff);
}

test "generateGlyphs bookshelf_count capped at 15" {
    const capped = generateGlyphs(0.0, 0.0, 0.0, 0.0, 255);
    const max_shelf = generateGlyphs(0.0, 0.0, 0.0, 0.0, 15);
    // Both should produce identical alpha (capped to 15 shelves)
    try std.testing.expectApproxEqAbs(max_shelf[0].alpha, capped[0].alpha, 0.0001);
}

test "generateGlyphs each particle has a unique glyph_id" {
    const glyphs = generateGlyphs(0.0, 0.0, 0.0, 0.0, 0);
    for (0..glyph_count) |i| {
        for (i + 1..glyph_count) |j| {
            try std.testing.expect(glyphs[i].glyph_id != glyphs[j].glyph_id);
        }
    }
}

test "getBookAngle oscillates within amplitude" {
    for (0..100) |i| {
        const t: f32 = @as(f32, @floatFromInt(i)) * 0.1;
        const angle = getBookAngle(t);
        try std.testing.expect(angle >= -book_amplitude - 0.001);
        try std.testing.expect(angle <= book_amplitude + 0.001);
    }
}

test "getBookAngle is zero at time zero" {
    const angle = getBookAngle(0.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), angle, 0.0001);
}

test "getGlyphColor returns purple" {
    const c = getGlyphColor();
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), c[0], 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.2), c[1], 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.8), c[2], 0.0001);
}

test "getBookAngle changes over time" {
    const a = getBookAngle(0.0);
    const b = getBookAngle(1.0);
    try std.testing.expect(@abs(a - b) > 0.001);
}

test "generateGlyphs alpha and size are positive" {
    const glyphs = generateGlyphs(0.0, 0.0, 0.0, 0.0, 0);
    for (glyphs) |g| {
        try std.testing.expect(g.alpha > 0.0);
        try std.testing.expect(g.size > 0.0);
    }
}
