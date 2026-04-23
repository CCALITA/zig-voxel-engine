const std = @import("std");

/// A single footstep dust particle with position, color, size, and remaining life.
pub const FootstepParticle = struct {
    x: f32,
    y: f32,
    z: f32,
    r: f32,
    g: f32,
    b: f32,
    a: f32,
    size: f32,
    life: f32,
};

/// Block surface material categories that determine particle color.
pub const Material = enum {
    stone,
    dirt,
    sand,
    wood,
    snow,
    grass,
    gravel,
};

/// RGBA color for a material's footstep dust.
const MaterialColor = struct { r: f32, g: f32, b: f32, a: f32 };

fn materialColor(mat: Material) MaterialColor {
    return switch (mat) {
        .stone => .{ .r = 0.55, .g = 0.55, .b = 0.55, .a = 0.7 },
        .dirt => .{ .r = 0.45, .g = 0.30, .b = 0.15, .a = 0.7 },
        .sand => .{ .r = 0.82, .g = 0.75, .b = 0.55, .a = 0.6 },
        .wood => .{ .r = 0.65, .g = 0.50, .b = 0.30, .a = 0.6 },
        .snow => .{ .r = 0.95, .g = 0.95, .b = 0.98, .a = 0.8 },
        .grass => .{ .r = 0.35, .g = 0.50, .b = 0.20, .a = 0.6 },
        .gravel => .{ .r = 0.50, .g = 0.48, .b = 0.45, .a = 0.7 },
    };
}

/// Map a block ID to its surface material.
///
/// Uses the block registry conventions from `src/world/block.zig`:
///   1 = stone, 2 = dirt, 3 = grass, 4 = cobblestone, 5 = planks,
///   6 = sand, 7 = gravel, 24 = snow, etc.
pub fn getBlockMaterial(block_id: u16) Material {
    return switch (block_id) {
        1, 4, 14, 15, 16, 22, 45 => .stone, // stone, cobble, ores, end_stone
        2 => .dirt,
        3 => .grass,
        5 => .wood, // planks
        6 => .sand,
        7 => .gravel,
        24 => .snow,
        else => .stone, // default fallback
    };
}

const particle_size: f32 = 0.08;
const particle_life: f32 = 0.4;
const foot_offset: f32 = 0.1;

/// Spawn two small dust particles at the given foot position.
///
/// The pair is slightly offset along X so the left and right edges of
/// the foot each get a puff.
pub fn spawnFootstep(foot_x: f32, foot_y: f32, foot_z: f32, material: Material) [2]FootstepParticle {
    const col = materialColor(material);
    const offsets = [2]f32{ -foot_offset, foot_offset };
    var result: [2]FootstepParticle = undefined;
    for (&result, offsets) |*p, dx| {
        p.* = .{
            .x = foot_x + dx,
            .y = foot_y,
            .z = foot_z,
            .r = col.r,
            .g = col.g,
            .b = col.b,
            .a = col.a,
            .size = particle_size,
            .life = particle_life,
        };
    }
    return result;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "FootstepParticle struct has expected fields" {
    const p = FootstepParticle{
        .x = 1.0,
        .y = 2.0,
        .z = 3.0,
        .r = 0.5,
        .g = 0.5,
        .b = 0.5,
        .a = 1.0,
        .size = 0.1,
        .life = 0.5,
    };
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), p.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), p.life, 0.001);
}

test "Material enum has 7 variants" {
    const fields = std.meta.fields(Material);
    try std.testing.expectEqual(@as(usize, 7), fields.len);
}

test "getBlockMaterial maps stone correctly" {
    try std.testing.expectEqual(Material.stone, getBlockMaterial(1));
    try std.testing.expectEqual(Material.stone, getBlockMaterial(4)); // cobblestone
}

test "getBlockMaterial maps dirt correctly" {
    try std.testing.expectEqual(Material.dirt, getBlockMaterial(2));
}

test "getBlockMaterial maps grass correctly" {
    try std.testing.expectEqual(Material.grass, getBlockMaterial(3));
}

test "getBlockMaterial maps sand correctly" {
    try std.testing.expectEqual(Material.sand, getBlockMaterial(6));
}

test "getBlockMaterial maps gravel correctly" {
    try std.testing.expectEqual(Material.gravel, getBlockMaterial(7));
}

test "getBlockMaterial maps wood correctly" {
    try std.testing.expectEqual(Material.wood, getBlockMaterial(5));
}

test "getBlockMaterial maps snow correctly" {
    try std.testing.expectEqual(Material.snow, getBlockMaterial(24));
}

test "getBlockMaterial returns stone for unknown block IDs" {
    try std.testing.expectEqual(Material.stone, getBlockMaterial(999));
    try std.testing.expectEqual(Material.stone, getBlockMaterial(0));
}

test "spawnFootstep returns two particles" {
    const pair = spawnFootstep(5.0, 10.0, 5.0, .dirt);
    try std.testing.expectEqual(@as(usize, 2), pair.len);
}

test "spawnFootstep particles are at foot position with offset" {
    const pair = spawnFootstep(5.0, 10.0, 3.0, .stone);
    // First particle is offset left, second offset right
    try std.testing.expect(pair[0].x < 5.0);
    try std.testing.expect(pair[1].x > 5.0);
    // Both share the same Y and Z
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), pair[0].y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), pair[1].y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), pair[0].z, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), pair[1].z, 0.001);
}

test "spawnFootstep stone particles are gray" {
    const pair = spawnFootstep(0.0, 0.0, 0.0, .stone);
    // Gray: R, G, B should be similar and in the mid-range
    for (pair) |p| {
        try std.testing.expect(p.r > 0.4 and p.r < 0.7);
        try std.testing.expect(p.g > 0.4 and p.g < 0.7);
        try std.testing.expect(p.b > 0.4 and p.b < 0.7);
        try std.testing.expectApproxEqAbs(p.r, p.g, 0.01);
    }
}

test "spawnFootstep dirt particles are brown" {
    const pair = spawnFootstep(0.0, 0.0, 0.0, .dirt);
    for (pair) |p| {
        // Brown: R > G > B
        try std.testing.expect(p.r > p.g);
        try std.testing.expect(p.g > p.b);
    }
}

test "spawnFootstep snow particles are near-white" {
    const pair = spawnFootstep(0.0, 0.0, 0.0, .snow);
    for (pair) |p| {
        try std.testing.expect(p.r > 0.9);
        try std.testing.expect(p.g > 0.9);
        try std.testing.expect(p.b > 0.9);
    }
}

test "spawnFootstep sand particles are tan" {
    const pair = spawnFootstep(0.0, 0.0, 0.0, .sand);
    for (pair) |p| {
        // Tan: R > G > B, all fairly high
        try std.testing.expect(p.r > 0.7);
        try std.testing.expect(p.g > 0.6);
        try std.testing.expect(p.r > p.g);
        try std.testing.expect(p.g > p.b);
    }
}

test "spawnFootstep wood particles are light brown" {
    const pair = spawnFootstep(0.0, 0.0, 0.0, .wood);
    for (pair) |p| {
        // Light brown: R > G > B
        try std.testing.expect(p.r > p.g);
        try std.testing.expect(p.g > p.b);
        try std.testing.expect(p.r > 0.5);
    }
}

test "spawnFootstep particles have positive life and size" {
    inline for (std.meta.fields(Material)) |field| {
        const mat: Material = @enumFromInt(field.value);
        const pair = spawnFootstep(0.0, 0.0, 0.0, mat);
        for (pair) |p| {
            try std.testing.expect(p.life > 0.0);
            try std.testing.expect(p.size > 0.0);
            try std.testing.expect(p.a > 0.0 and p.a <= 1.0);
        }
    }
}

test "materialColor returns valid RGBA for all materials" {
    inline for (std.meta.fields(Material)) |field| {
        const mat: Material = @enumFromInt(field.value);
        const col = materialColor(mat);
        try std.testing.expect(col.r >= 0.0 and col.r <= 1.0);
        try std.testing.expect(col.g >= 0.0 and col.g <= 1.0);
        try std.testing.expect(col.b >= 0.0 and col.b <= 1.0);
        try std.testing.expect(col.a >= 0.0 and col.a <= 1.0);
    }
}
