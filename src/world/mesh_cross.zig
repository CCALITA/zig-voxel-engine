/// Cross mesh generator for vegetation blocks (flowers, tall grass, crops, saplings).
/// Two vertical quads arranged in an X shape, each spanning diagonally from
/// corner to corner of the block. Each quad has 4 vertices and 6 indices,
/// giving 8 vertices and 12 indices total.
const std = @import("std");
const mesh_indexed = @import("mesh_indexed.zig");

pub const Vertex = mesh_indexed.Vertex;

pub const makeVertex = mesh_indexed.makeVertex;

/// Result of generating two crossed quads for a single block.
pub const CrossMesh = struct {
    vertices: [8]Vertex,
    indices: [12]u32,
};

/// Diagonal quad vertex offsets: (dx, dy, dz) for each corner.
/// Quad A runs from (0,0,0) to (1,0,1) along the bottom, standing upright.
/// Quad B runs from (1,0,0) to (0,0,1) along the bottom, standing upright.
const quad_a_corners = [4][3]u1{
    .{ 0, 0, 0 }, // bottom-left
    .{ 1, 0, 1 }, // bottom-right
    .{ 1, 1, 1 }, // top-right
    .{ 0, 1, 0 }, // top-left
};

const quad_b_corners = [4][3]u1{
    .{ 1, 0, 0 }, // bottom-left
    .{ 0, 0, 1 }, // bottom-right
    .{ 0, 1, 1 }, // top-right
    .{ 1, 1, 0 }, // top-left
};

/// Reuse the standard quad winding from mesh_indexed (0,1,2,2,3,0).
const quad_indices = mesh_indexed.quad_indices;

/// Generate cross mesh geometry for a vegetation block at the given position.
/// `bx`, `by`, `bz` are the block-local coordinates (0..15).
/// `tex` is the texture index for the plant.
/// `light` is the light level at the block position.
pub fn generateCross(bx: u5, by: u5, bz: u5, tex: u16, light: u4) CrossMesh {
    var vertices: [8]Vertex = undefined;
    var indices: [12]u32 = undefined;

    const diagonals = [2][4][3]u1{ quad_a_corners, quad_b_corners };

    for (0..2) |qi| {
        const corners = diagonals[qi];
        const base: u32 = @intCast(qi * 4);

        for (0..4) |ci| {
            const corner = corners[ci];
            vertices[base + ci] = makeVertex(
                @as(u5, bx) + corner[0],
                @as(u5, by) + corner[1],
                @as(u5, bz) + corner[2],
                0, // face: not used for cross meshes (no culling)
                @intCast(ci),
                0, // ao: no ambient occlusion for cross meshes
                light,
                tex,
            );
        }

        for (0..6) |ii| {
            indices[qi * 6 + ii] = base + quad_indices[ii];
        }
    }

    return .{ .vertices = vertices, .indices = indices };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "cross mesh produces 8 vertices and 12 indices" {
    const mesh = generateCross(8, 0, 8, 42, 15);
    try std.testing.expectEqual(@as(usize, 8), mesh.vertices.len);
    try std.testing.expectEqual(@as(usize, 12), mesh.indices.len);
}

test "all indices reference valid vertices" {
    const mesh = generateCross(4, 2, 4, 100, 10);
    for (mesh.indices) |idx| {
        try std.testing.expect(idx < mesh.vertices.len);
    }
}

test "texture index is preserved in vertex data" {
    const tex: u16 = 2047;
    const mesh = generateCross(0, 0, 0, tex, 0);
    for (mesh.vertices) |v| {
        try std.testing.expectEqual(@as(u32, tex), v.tex_data & 0xFFF);
    }
}

test "light level is encoded in vertex pos_data" {
    const light: u4 = 12;
    const mesh = generateCross(0, 0, 0, 1, light);
    for (mesh.vertices) |v| {
        const extracted: u4 = @intCast((v.pos_data >> 22) & 0xF);
        try std.testing.expectEqual(light, extracted);
    }
}

test "vertices span two diagonals of the block" {
    const mesh = generateCross(0, 0, 0, 1, 0);

    // Quad A: bottom corners at (0,0,0) and (1,0,1)
    const v0_x: u5 = @intCast(mesh.vertices[0].pos_data & 0x1F);
    const v0_z: u5 = @intCast((mesh.vertices[0].pos_data >> 10) & 0x1F);
    const v1_x: u5 = @intCast(mesh.vertices[1].pos_data & 0x1F);
    const v1_z: u5 = @intCast((mesh.vertices[1].pos_data >> 10) & 0x1F);
    try std.testing.expectEqual(@as(u5, 0), v0_x);
    try std.testing.expectEqual(@as(u5, 0), v0_z);
    try std.testing.expectEqual(@as(u5, 1), v1_x);
    try std.testing.expectEqual(@as(u5, 1), v1_z);

    // Quad B: bottom corners at (1,0,0) and (0,0,1)
    const v4_x: u5 = @intCast(mesh.vertices[4].pos_data & 0x1F);
    const v4_z: u5 = @intCast((mesh.vertices[4].pos_data >> 10) & 0x1F);
    const v5_x: u5 = @intCast(mesh.vertices[5].pos_data & 0x1F);
    const v5_z: u5 = @intCast((mesh.vertices[5].pos_data >> 10) & 0x1F);
    try std.testing.expectEqual(@as(u5, 1), v4_x);
    try std.testing.expectEqual(@as(u5, 0), v4_z);
    try std.testing.expectEqual(@as(u5, 0), v5_x);
    try std.testing.expectEqual(@as(u5, 1), v5_z);
}

test "corner index is encoded in vertex pos_data" {
    const mesh = generateCross(0, 0, 0, 1, 0);
    for (0..2) |qi| {
        for (0..4) |ci| {
            const v = mesh.vertices[qi * 4 + ci];
            const extracted: u2 = @intCast((v.pos_data >> 18) & 0x3);
            try std.testing.expectEqual(@as(u2, @intCast(ci)), extracted);
        }
    }
}

test "offset block position is encoded correctly" {
    const bx: u5 = 15;
    const by: u5 = 7;
    const bz: u5 = 10;
    const mesh = generateCross(bx, by, bz, 0, 0);

    // First vertex of quad A: offset (0,0,0), so position = (15,7,10)
    const v = mesh.vertices[0];
    const x: u5 = @intCast(v.pos_data & 0x1F);
    const y: u5 = @intCast((v.pos_data >> 5) & 0x1F);
    const z: u5 = @intCast((v.pos_data >> 10) & 0x1F);
    try std.testing.expectEqual(bx, x);
    try std.testing.expectEqual(by, y);
    try std.testing.expectEqual(bz, z);
}
