/// Generates mesh vertex data for half-slab blocks.
/// A bottom slab occupies y=[by..by+8], a top slab occupies y=[by+8..by+16]
/// within the 16-unit block coordinate space.
///
/// Vertex format (two u32 attributes):
///   pos_data: x(5) y(5) z(5) face(3) corner(2) ao(2) light(4) pad(6) = 32 bits
///   tex_data: tex(12) reserved(20) = 32 bits
const std = @import("std");
const mesh_indexed = @import("mesh_indexed.zig");

pub const Vertex = mesh_indexed.Vertex;
pub const makeVertex = mesh_indexed.makeVertex;

/// Extract the x coordinate (bits 0..4) from a packed pos_data field.
fn extractX(pos_data: u32) u5 {
    return @intCast(pos_data & 0x1F);
}

/// Extract the y coordinate (bits 5..9) from a packed pos_data field.
fn extractY(pos_data: u32) u5 {
    return @intCast((pos_data >> 5) & 0x1F);
}

/// Extract the z coordinate (bits 10..14) from a packed pos_data field.
fn extractZ(pos_data: u32) u5 {
    return @intCast((pos_data >> 10) & 0x1F);
}

/// Extract the face index (bits 15..17) from a packed pos_data field.
fn extractFace(pos_data: u32) u3 {
    return @intCast((pos_data >> 15) & 0x7);
}

/// Extract the corner index (bits 18..19) from a packed pos_data field.
fn extractCorner(pos_data: u32) u2 {
    return @intCast((pos_data >> 18) & 0x3);
}

pub const SlabMesh = struct {
    vertices: [40]Vertex,
    indices: [60]u32,
    vertex_count: u32,
    index_count: u32,
};

/// Face indices: 0=North(-Z), 1=South(+Z), 2=East(+X), 3=West(-X), 4=Top(+Y), 5=Bottom(-Y)
const FACE_NORTH: u3 = 0;
const FACE_SOUTH: u3 = 1;
const FACE_EAST: u3 = 2;
const FACE_WEST: u3 = 3;
const FACE_TOP: u3 = 4;
const FACE_BOTTOM: u3 = 5;

/// Half-slab height in block coordinate units (half of a 16-unit block).
const SLAB_HEIGHT: u5 = 8;

/// Two triangles per quad: indices into the 4 corners.
const quad_indices = [6]u32{ 0, 1, 2, 2, 3, 0 };

/// Generate mesh data for a half-slab block.
///
/// - bx, by, bz: block position within chunk (in 0..31 vertex coordinate space)
/// - tex: texture index for all faces
/// - light: light level
/// - is_top: if true, slab occupies [by+8..by+16]; if false, [by..by+8]
///
/// Produces 6 faces (bottom, top, north, south, east, west) with 4 vertices
/// and 6 indices each = 24 vertices and 36 indices total.
pub fn generateSlab(bx: u5, by: u5, bz: u5, tex: u16, light: u4, is_top: bool) SlabMesh {
    var result = SlabMesh{
        .vertices = undefined,
        .indices = undefined,
        .vertex_count = 0,
        .index_count = 0,
    };

    const y_lo: u5 = if (is_top) by +| SLAB_HEIGHT else by;
    const y_hi: u5 = if (is_top) by +| 16 else by +| SLAB_HEIGHT;

    // x/z extents: one full block width
    const x0 = bx;
    const x1 = bx +| 1;
    const z0 = bz;
    const z1 = bz +| 1;

    const ao: u2 = 0;

    // Bottom face (y = y_lo, facing -Y)
    emitQuad(&result, FACE_BOTTOM, tex, ao, light, .{
        .{ x0, y_lo, z1 },
        .{ x0, y_lo, z0 },
        .{ x1, y_lo, z0 },
        .{ x1, y_lo, z1 },
    });

    // Top face (y = y_hi, facing +Y)
    emitQuad(&result, FACE_TOP, tex, ao, light, .{
        .{ x0, y_hi, z0 },
        .{ x0, y_hi, z1 },
        .{ x1, y_hi, z1 },
        .{ x1, y_hi, z0 },
    });

    // North face (-Z, z = z0)
    emitQuad(&result, FACE_NORTH, tex, ao, light, .{
        .{ x1, y_lo, z0 },
        .{ x0, y_lo, z0 },
        .{ x0, y_hi, z0 },
        .{ x1, y_hi, z0 },
    });

    // South face (+Z, z = z1)
    emitQuad(&result, FACE_SOUTH, tex, ao, light, .{
        .{ x0, y_lo, z1 },
        .{ x1, y_lo, z1 },
        .{ x1, y_hi, z1 },
        .{ x0, y_hi, z1 },
    });

    // East face (+X, x = x1)
    emitQuad(&result, FACE_EAST, tex, ao, light, .{
        .{ x1, y_lo, z1 },
        .{ x1, y_lo, z0 },
        .{ x1, y_hi, z0 },
        .{ x1, y_hi, z1 },
    });

    // West face (-X, x = x0)
    emitQuad(&result, FACE_WEST, tex, ao, light, .{
        .{ x0, y_lo, z0 },
        .{ x0, y_lo, z1 },
        .{ x0, y_hi, z1 },
        .{ x0, y_hi, z0 },
    });

    return result;
}

/// Emit a single quad (4 vertices + 6 indices) into the SlabMesh.
fn emitQuad(
    mesh: *SlabMesh,
    face: u3,
    tex: u16,
    ao: u2,
    light: u4,
    corners: [4][3]u5,
) void {
    const base = mesh.vertex_count;

    for (0..4) |ci| {
        mesh.vertices[mesh.vertex_count] = makeVertex(
            corners[ci][0],
            corners[ci][1],
            corners[ci][2],
            face,
            @intCast(ci),
            ao,
            light,
            tex,
        );
        mesh.vertex_count += 1;
    }

    for (quad_indices) |offset| {
        mesh.indices[mesh.index_count] = base + offset;
        mesh.index_count += 1;
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "bottom slab vertex count is 24 (6 faces x 4 verts)" {
    const mesh = generateSlab(0, 0, 0, 42, 15, false);
    try std.testing.expectEqual(@as(u32, 24), mesh.vertex_count);
}

test "bottom slab index count is 36 (6 faces x 6 indices)" {
    const mesh = generateSlab(0, 0, 0, 42, 15, false);
    try std.testing.expectEqual(@as(u32, 36), mesh.index_count);
}

test "bottom slab y values range from by to by+8" {
    const by: u5 = 2;
    const mesh = generateSlab(0, by, 0, 10, 8, false);
    const y_lo = by;
    const y_hi = by + SLAB_HEIGHT;

    for (0..mesh.vertex_count) |i| {
        const y = extractY(mesh.vertices[i].pos_data);
        try std.testing.expect(y >= y_lo);
        try std.testing.expect(y <= y_hi);
    }
}

test "top slab y values range from by+8 to by+16" {
    const by: u5 = 0;
    const mesh = generateSlab(0, by, 0, 10, 8, true);
    const y_lo = by + SLAB_HEIGHT;
    const y_hi = by + 16;

    for (0..mesh.vertex_count) |i| {
        const y = extractY(mesh.vertices[i].pos_data);
        try std.testing.expect(y >= y_lo);
        try std.testing.expect(y <= y_hi);
    }
}

test "top vs bottom slab produce different y values" {
    const bottom = generateSlab(0, 0, 0, 10, 8, false);
    const top = generateSlab(0, 0, 0, 10, 8, true);

    // Collect unique y values from each slab
    var bottom_ys = [_]bool{false} ** 32;
    var top_ys = [_]bool{false} ** 32;

    for (0..bottom.vertex_count) |i| {
        bottom_ys[extractY(bottom.vertices[i].pos_data)] = true;
    }
    for (0..top.vertex_count) |i| {
        top_ys[extractY(top.vertices[i].pos_data)] = true;
    }

    // Bottom slab uses y=0 and y=8; top slab uses y=8 and y=16.
    // They share y=8 but differ on the extremes.
    try std.testing.expect(bottom_ys[0]);
    try std.testing.expect(bottom_ys[8]);
    try std.testing.expect(!bottom_ys[16]);

    try std.testing.expect(!top_ys[0]);
    try std.testing.expect(top_ys[8]);
    try std.testing.expect(top_ys[16]);
}

test "all indices reference valid vertices" {
    const mesh = generateSlab(4, 2, 6, 100, 12, false);
    for (0..mesh.index_count) |i| {
        try std.testing.expect(mesh.indices[i] < mesh.vertex_count);
    }
}

test "texture is preserved in tex_data" {
    const tex: u16 = 500;
    const mesh = generateSlab(0, 0, 0, tex, 0, false);
    for (0..mesh.vertex_count) |i| {
        try std.testing.expectEqual(@as(u32, tex), mesh.vertices[i].tex_data & 0xFFF);
    }
}

test "makeVertex packs and extracts correctly" {
    const v = makeVertex(5, 10, 15, 3, 2, 1, 7, 200);
    try std.testing.expectEqual(@as(u5, 5), extractX(v.pos_data));
    try std.testing.expectEqual(@as(u5, 10), extractY(v.pos_data));
    try std.testing.expectEqual(@as(u5, 15), extractZ(v.pos_data));
    try std.testing.expectEqual(@as(u3, 3), extractFace(v.pos_data));
    try std.testing.expectEqual(@as(u2, 2), extractCorner(v.pos_data));
    try std.testing.expectEqual(@as(u32, 200), v.tex_data & 0xFFF);
}

test "each face direction is present in slab mesh" {
    const mesh = generateSlab(0, 0, 0, 1, 0, false);
    var face_seen = [_]bool{false} ** 6;

    for (0..mesh.vertex_count) |i| {
        face_seen[extractFace(mesh.vertices[i].pos_data)] = true;
    }

    // All 6 faces must be present
    for (0..6) |f| {
        try std.testing.expect(face_seen[f]);
    }
}
