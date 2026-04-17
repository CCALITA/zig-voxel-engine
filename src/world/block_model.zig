/// Non-cube block model system.
/// Provides vertex/index data for various block shapes (slabs, stairs, fences,
/// cross-mesh plants, torches) along with collision boxes and full-cube queries.
///
/// All geometry is defined at comptime as arrays of ModelVertex/u32 indices,
/// positioned at the origin. Callers offset to world coordinates.
const std = @import("std");

pub const BlockShape = enum {
    full_cube,
    slab_bottom,
    slab_top,
    stairs_north,
    stairs_south,
    stairs_east,
    stairs_west,
    fence,
    glass_pane,
    cross,
    torch,
};

pub const ModelVertex = struct {
    x: f32,
    y: f32,
    z: f32,
    u: f32,
    v: f32,
    tex: u8,
    shade: f32,
};

pub const ModelData = struct {
    vertices: []const ModelVertex,
    indices: []const u32,
};

pub const AABB = struct {
    min_x: f32,
    max_x: f32,
    min_y: f32,
    max_y: f32,
    min_z: f32,
    max_z: f32,
};

// ---------------------------------------------------------------------------
// Helpers to build box geometry at comptime
// ---------------------------------------------------------------------------

/// A single quad (4 vertices, 6 index entries) on one face of an axis-aligned box.
const QuadVerts = struct {
    verts: [4]ModelVertex,
    idxs: [6]u32,
};

fn mkVert(x: f32, y: f32, z: f32, u: f32, v: f32, tex: u8, shade: f32) ModelVertex {
    return .{ .x = x, .y = y, .z = z, .u = u, .v = v, .tex = tex, .shade = shade };
}

/// Build a quad for one face of an axis-aligned box. `base` is the starting vertex index.
fn boxFaceQuad(
    comptime min_x: f32,
    comptime min_y: f32,
    comptime min_z: f32,
    comptime max_x: f32,
    comptime max_y: f32,
    comptime max_z: f32,
    comptime face: u3,
    comptime tex: u8,
    comptime base: u32,
) QuadVerts {
    // shade per face: top=1.0, bottom=0.5, north/south=0.7, east/west=0.8
    const shade: f32 = switch (face) {
        4 => 1.0, // top
        5 => 0.5, // bottom
        0, 1 => 0.7, // north, south
        else => 0.8, // east, west
    };
    const verts: [4]ModelVertex = switch (face) {
        // North (-Z)
        0 => .{
            mkVert(max_x, min_y, min_z, 0, 1, tex, shade),
            mkVert(min_x, min_y, min_z, 1, 1, tex, shade),
            mkVert(min_x, max_y, min_z, 1, 0, tex, shade),
            mkVert(max_x, max_y, min_z, 0, 0, tex, shade),
        },
        // South (+Z)
        1 => .{
            mkVert(min_x, min_y, max_z, 0, 1, tex, shade),
            mkVert(max_x, min_y, max_z, 1, 1, tex, shade),
            mkVert(max_x, max_y, max_z, 1, 0, tex, shade),
            mkVert(min_x, max_y, max_z, 0, 0, tex, shade),
        },
        // East (+X)
        2 => .{
            mkVert(max_x, min_y, max_z, 0, 1, tex, shade),
            mkVert(max_x, min_y, min_z, 1, 1, tex, shade),
            mkVert(max_x, max_y, min_z, 1, 0, tex, shade),
            mkVert(max_x, max_y, max_z, 0, 0, tex, shade),
        },
        // West (-X)
        3 => .{
            mkVert(min_x, min_y, min_z, 0, 1, tex, shade),
            mkVert(min_x, min_y, max_z, 1, 1, tex, shade),
            mkVert(min_x, max_y, max_z, 1, 0, tex, shade),
            mkVert(min_x, max_y, min_z, 0, 0, tex, shade),
        },
        // Top (+Y)
        4 => .{
            mkVert(min_x, max_y, min_z, 0, 0, tex, shade),
            mkVert(min_x, max_y, max_z, 0, 1, tex, shade),
            mkVert(max_x, max_y, max_z, 1, 1, tex, shade),
            mkVert(max_x, max_y, min_z, 1, 0, tex, shade),
        },
        // Bottom (-Y)
        5 => .{
            mkVert(min_x, min_y, max_z, 0, 0, tex, shade),
            mkVert(min_x, min_y, min_z, 0, 1, tex, shade),
            mkVert(max_x, min_y, min_z, 1, 1, tex, shade),
            mkVert(max_x, min_y, max_z, 1, 0, tex, shade),
        },
        else => unreachable,
    };
    const idxs: [6]u32 = .{
        base + 0, base + 1, base + 2,
        base + 2, base + 3, base + 0,
    };
    return .{ .verts = verts, .idxs = idxs };
}

/// Build all 6 faces for an axis-aligned box -> 24 vertices, 36 indices.
fn boxModel(
    comptime min_x: f32,
    comptime min_y: f32,
    comptime min_z: f32,
    comptime max_x: f32,
    comptime max_y: f32,
    comptime max_z: f32,
    comptime tex: u8,
) struct { verts: [24]ModelVertex, idxs: [36]u32 } {
    var verts: [24]ModelVertex = undefined;
    var idxs: [36]u32 = undefined;
    inline for (0..6) |f| {
        const q = boxFaceQuad(min_x, min_y, min_z, max_x, max_y, max_z, @intCast(f), tex, @intCast(f * 4));
        inline for (0..4) |i| verts[f * 4 + i] = q.verts[i];
        inline for (0..6) |i| idxs[f * 6 + i] = q.idxs[i];
    }
    return .{ .verts = verts, .idxs = idxs };
}

// ---------------------------------------------------------------------------
// Comptime model data for each shape
// ---------------------------------------------------------------------------

const full_cube = boxModel(0, 0, 0, 1, 1, 1, 0);
const slab_bottom = boxModel(0, 0, 0, 1, 0.5, 1, 0);
const slab_top = boxModel(0, 0.5, 0, 1, 1, 1, 0);
const fence = boxModel(0.375, 0, 0.375, 0.625, 1, 0.625, 0); // 4x16x4 px post
const glass_pane = boxModel(0, 0, 0.4375, 1, 1, 0.5625, 0); // thin Z-centered panel
const torch_box = boxModel(0.4375, 0, 0.4375, 0.5625, 0.625, 0.5625, 0); // 2x10x2 px pillar

// ---------------------------------------------------------------------------
// Stairs: L-shape = bottom slab + quarter block on one side (48 verts, 72 idxs)
// ---------------------------------------------------------------------------

const StairsData = struct { verts: [48]ModelVertex, idxs: [72]u32 };

fn stairsModel(
    comptime step_min_x: f32,
    comptime step_min_z: f32,
    comptime step_max_x: f32,
    comptime step_max_z: f32,
) StairsData {
    const a = boxModel(0, 0, 0, 1, 0.5, 1, 0); // bottom slab
    const b = boxModel(step_min_x, 0.5, step_min_z, step_max_x, 1, step_max_z, 0); // upper step

    var verts: [48]ModelVertex = undefined;
    var idxs: [72]u32 = undefined;

    inline for (0..24) |i| verts[i] = a.verts[i];
    inline for (0..36) |i| idxs[i] = a.idxs[i];

    inline for (0..24) |i| verts[24 + i] = b.verts[i];
    inline for (0..36) |i| idxs[36 + i] = b.idxs[i] + 24;

    return .{ .verts = verts, .idxs = idxs };
}

const stairs_north = stairsModel(0, 0, 1, 0.5); // step on -Z half
const stairs_south = stairsModel(0, 0.5, 1, 1); // step on +Z half
const stairs_east = stairsModel(0.5, 0, 1, 1); // step on +X half
const stairs_west = stairsModel(0, 0, 0.5, 1); // step on -X half

// ---------------------------------------------------------------------------
// Cross: two diagonal quads intersecting at center (8 vertices, 12 indices)
// ---------------------------------------------------------------------------

const cross_shade: f32 = 0.9;

const cross_verts = [8]ModelVertex{
    // Quad A: diagonal from (0,0,0) to (1,0,1) up to (1,1,1) and (0,1,0)
    mkVert(0, 0, 0, 0, 1, 0, cross_shade),
    mkVert(1, 0, 1, 1, 1, 0, cross_shade),
    mkVert(1, 1, 1, 1, 0, 0, cross_shade),
    mkVert(0, 1, 0, 0, 0, 0, cross_shade),
    // Quad B: diagonal from (1,0,0) to (0,0,1) up to (0,1,1) and (1,1,0)
    mkVert(1, 0, 0, 0, 1, 0, cross_shade),
    mkVert(0, 0, 1, 1, 1, 0, cross_shade),
    mkVert(0, 1, 1, 1, 0, 0, cross_shade),
    mkVert(1, 1, 0, 0, 0, 0, cross_shade),
};

const cross_idxs = [12]u32{
    0, 1, 2, 2, 3, 0, // quad A
    4, 5, 6, 6, 7, 4, // quad B
};

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Return the pre-built vertex and index data for the given block shape.
pub fn getModel(shape: BlockShape) ModelData {
    return switch (shape) {
        .full_cube => .{ .vertices = &full_cube.verts, .indices = &full_cube.idxs },
        .slab_bottom => .{ .vertices = &slab_bottom.verts, .indices = &slab_bottom.idxs },
        .slab_top => .{ .vertices = &slab_top.verts, .indices = &slab_top.idxs },
        .stairs_north => .{ .vertices = &stairs_north.verts, .indices = &stairs_north.idxs },
        .stairs_south => .{ .vertices = &stairs_south.verts, .indices = &stairs_south.idxs },
        .stairs_east => .{ .vertices = &stairs_east.verts, .indices = &stairs_east.idxs },
        .stairs_west => .{ .vertices = &stairs_west.verts, .indices = &stairs_west.idxs },
        .fence => .{ .vertices = &fence.verts, .indices = &fence.idxs },
        .glass_pane => .{ .vertices = &glass_pane.verts, .indices = &glass_pane.idxs },
        .cross => .{ .vertices = &cross_verts, .indices = &cross_idxs },
        .torch => .{ .vertices = &torch_box.verts, .indices = &torch_box.idxs },
    };
}

/// True only for full_cube -- the only shape that fully occludes all neighbours.
pub fn isFullCube(shape: BlockShape) bool {
    return shape == .full_cube;
}

/// Axis-aligned bounding box for collision detection.
pub fn getCollisionBox(shape: BlockShape) AABB {
    return switch (shape) {
        .full_cube => .{ .min_x = 0, .max_x = 1, .min_y = 0, .max_y = 1, .min_z = 0, .max_z = 1 },
        .slab_bottom => .{ .min_x = 0, .max_x = 1, .min_y = 0, .max_y = 0.5, .min_z = 0, .max_z = 1 },
        .slab_top => .{ .min_x = 0, .max_x = 1, .min_y = 0.5, .max_y = 1, .min_z = 0, .max_z = 1 },
        .stairs_north, .stairs_south, .stairs_east, .stairs_west, .cross => .{
            .min_x = 0, .max_x = 1, .min_y = 0, .max_y = 1, .min_z = 0, .max_z = 1,
        },
        .fence => .{ .min_x = 0.375, .max_x = 0.625, .min_y = 0, .max_y = 1, .min_z = 0.375, .max_z = 0.625 },
        .glass_pane => .{ .min_x = 0, .max_x = 1, .min_y = 0, .max_y = 1, .min_z = 0.4375, .max_z = 0.5625 },
        .torch => .{ .min_x = 0.4375, .max_x = 0.5625, .min_y = 0, .max_y = 0.625, .min_z = 0.4375, .max_z = 0.5625 },
    };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "full_cube has 24 vertices and 36 indices" {
    const m = getModel(.full_cube);
    try std.testing.expectEqual(@as(usize, 24), m.vertices.len);
    try std.testing.expectEqual(@as(usize, 36), m.indices.len);
}

test "slab_bottom has 24 vertices" {
    const m = getModel(.slab_bottom);
    try std.testing.expectEqual(@as(usize, 24), m.vertices.len);
}

test "slab_top has 24 vertices" {
    const m = getModel(.slab_top);
    try std.testing.expectEqual(@as(usize, 24), m.vertices.len);
}

test "stairs shapes have 48 vertices and 72 indices" {
    for ([_]BlockShape{ .stairs_north, .stairs_south, .stairs_east, .stairs_west }) |shape| {
        const m = getModel(shape);
        try std.testing.expectEqual(@as(usize, 48), m.vertices.len);
        try std.testing.expectEqual(@as(usize, 72), m.indices.len);
    }
}

test "fence has 24 vertices" {
    const m = getModel(.fence);
    try std.testing.expectEqual(@as(usize, 24), m.vertices.len);
}

test "cross has 8 vertices and 12 indices" {
    const m = getModel(.cross);
    try std.testing.expectEqual(@as(usize, 8), m.vertices.len);
    try std.testing.expectEqual(@as(usize, 12), m.indices.len);
}

test "torch has 24 vertices" {
    const m = getModel(.torch);
    try std.testing.expectEqual(@as(usize, 24), m.vertices.len);
}

test "slab_bottom collision box is half-height" {
    const box = getCollisionBox(.slab_bottom);
    try std.testing.expectApproxEqAbs(@as(f32, 0), box.min_y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), box.max_y, 0.001);
}

test "slab_top collision box starts at 0.5" {
    const box = getCollisionBox(.slab_top);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), box.min_y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), box.max_y, 0.001);
}

test "isFullCube true only for full_cube" {
    try std.testing.expect(isFullCube(.full_cube));
    try std.testing.expect(!isFullCube(.slab_bottom));
    try std.testing.expect(!isFullCube(.stairs_north));
    try std.testing.expect(!isFullCube(.fence));
    try std.testing.expect(!isFullCube(.cross));
    try std.testing.expect(!isFullCube(.torch));
    try std.testing.expect(!isFullCube(.glass_pane));
}

test "all indices are in bounds" {
    const shapes = [_]BlockShape{
        .full_cube,   .slab_bottom, .slab_top,
        .stairs_north, .stairs_south, .stairs_east,
        .stairs_west, .fence,       .glass_pane,
        .cross,       .torch,
    };
    for (shapes) |shape| {
        const m = getModel(shape);
        for (m.indices) |idx| {
            try std.testing.expect(idx < m.vertices.len);
        }
    }
}

test "glass_pane has 24 vertices" {
    const m = getModel(.glass_pane);
    try std.testing.expectEqual(@as(usize, 24), m.vertices.len);
}

test "torch collision box is thin and short" {
    const box = getCollisionBox(.torch);
    try std.testing.expectApproxEqAbs(@as(f32, 0.625), box.max_y, 0.001);
    try std.testing.expect(box.max_x - box.min_x < 0.2);
}
