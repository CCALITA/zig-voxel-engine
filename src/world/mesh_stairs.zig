/// Stair mesh generator.
/// Produces an L-shaped cross-section: the bottom half is full width,
/// the top half covers only the back half (like a step).
///
/// Coordinates use half-block resolution: each block spans 2 units
/// so that the step midpoint can be represented as an integer.
/// The caller passes the block origin (bx, by, bz) in this doubled
/// coordinate space.  Vertex positions range from base to base+2.
///
/// Uses the same packed vertex format as mesh_indexed:
///   pos_data: x(5) y(5) z(5) face(3) corner(2) ao(2) light(4) pad(6)
///   tex_data: tex(12) anim(4) tint(8) reserved(8)
const std = @import("std");

pub const Vertex = extern struct {
    pos_data: u32,
    tex_data: u32,
};

pub const Facing = enum(u2) { north, east, south, west };

pub const StairMesh = struct {
    vertices: [64]Vertex,
    indices: [96]u32,
    vertex_count: u32,
    index_count: u32,
};

/// Pack a vertex identical to mesh_indexed.makeVertex.
fn makeVertex(x: u5, y: u5, z: u5, face: u3, corner: u2, ao: u2, light: u4, tex: u16) Vertex {
    const pos: u32 = @as(u32, x) |
        (@as(u32, y) << 5) |
        (@as(u32, z) << 10) |
        (@as(u32, face) << 15) |
        (@as(u32, corner) << 18) |
        (@as(u32, ao) << 20) |
        (@as(u32, light) << 22);
    const td: u32 = @as(u32, tex) & 0xFFF;
    return .{ .pos_data = pos, .tex_data = td };
}

// -----------------------------------------------------------------------
// Helpers to decode packed fields for testing.
// -----------------------------------------------------------------------
fn decodeX(v: Vertex) u5 {
    return @truncate(v.pos_data);
}
fn decodeY(v: Vertex) u5 {
    return @truncate(v.pos_data >> 5);
}
fn decodeZ(v: Vertex) u5 {
    return @truncate(v.pos_data >> 10);
}
fn decodeTex(v: Vertex) u16 {
    return @truncate(v.tex_data & 0xFFF);
}
fn decodeLight(v: Vertex) u4 {
    return @truncate(v.pos_data >> 22);
}

// -----------------------------------------------------------------------
// Quad builder
// -----------------------------------------------------------------------

/// Append one quad (4 vertices, 6 indices) and advance counts.
fn addQuad(
    mesh: *StairMesh,
    face: u3,
    light: u4,
    tex: u16,
    p0: [3]u5,
    p1: [3]u5,
    p2: [3]u5,
    p3: [3]u5,
) void {
    const base = mesh.vertex_count;
    const corners = [4][3]u5{ p0, p1, p2, p3 };

    for (corners, 0..) |c, ci| {
        mesh.vertices[base + ci] = makeVertex(
            c[0],
            c[1],
            c[2],
            face,
            @intCast(ci),
            0, // ao
            light,
            tex,
        );
    }
    mesh.vertex_count += 4;

    const idx = [6]u32{ base, base + 1, base + 2, base + 2, base + 3, base };
    for (idx, 0..) |id, i| {
        mesh.indices[mesh.index_count + i] = id;
    }
    mesh.index_count += 6;
}

// -----------------------------------------------------------------------
// Facing rotation
// -----------------------------------------------------------------------

/// Rotate a point (px, pz) relative to (ox, oz) according to facing.
/// North is identity; east rotates 90-deg CW looking down; etc.
/// The block spans [ox .. ox+2] x [oz .. oz+2].
fn rotatePt(facing: Facing, ox: u5, oz: u5, px: u5, pz: u5) [2]u5 {
    const dx: i8 = @as(i8, px) - @as(i8, ox) - 1;
    const dz: i8 = @as(i8, pz) - @as(i8, oz) - 1;

    const rotated = switch (facing) {
        .north => .{ dx, dz },
        .south => .{ -dx, -dz },
        .east => .{ -dz, dx },
        .west => .{ dz, -dx },
    };

    return .{
        @intCast(rotated[0] + @as(i8, ox) + 1),
        @intCast(rotated[1] + @as(i8, oz) + 1),
    };
}

/// Rotate face index for the four horizontal faces (0-3).
/// Vertical faces (4=top, 5=bottom) are unchanged.
fn rotateFace(facing: Facing, face: u3) u3 {
    // Horizontal face ordering: 0=north(-Z) 1=south(+Z) 2=east(+X) 3=west(-X)
    if (face >= 4) return face; // top / bottom

    // Map face to an angular index (0=N,1=E,2=S,3=W), rotate, map back.
    const angle_map = [4]u2{ 0, 2, 1, 3 }; // face -> angle
    const face_map = [4]u3{ 0, 2, 1, 3 }; // angle -> face

    const base_angle = angle_map[face];
    const rot: u2 = @intFromEnum(facing);
    const new_angle = base_angle +% rot;
    return face_map[new_angle];
}

// -----------------------------------------------------------------------
// Core stair mesh generator
// -----------------------------------------------------------------------

/// Build the 8-quad stair mesh.
///
/// The canonical (north-facing) stair in doubled coordinates:
///
/// ```text
///  Side view (X-Z cross-section at any X):
///
///        back (Z=bz)          front (Z=bz+2)
///       +---------+
///       |  upper  |
///  by+2 +---------+---------+ by+2
///       |      bottom       |
///  by   +-------------------+ by
///       bz       bz+1      bz+2
/// ```
///
/// "back" = low-Z side for north-facing.  Rotation is applied for other
/// facings via `rotatePt` and `rotateFace`.
pub fn generateStair(bx: u5, by: u5, bz: u5, tex: u16, light: u4, facing: Facing) StairMesh {
    var mesh = StairMesh{
        .vertices = undefined,
        .indices = undefined,
        .vertex_count = 0,
        .index_count = 0,
    };

    // Convenience aliases for the 6 key coordinates.
    const x0 = bx;
    const x1: u5 = bx +% 2;
    const y0 = by;
    const y1: u5 = by +% 1; // step mid-height
    const y2: u5 = by +% 2;
    const z0 = bz;
    const z1: u5 = bz +% 1; // step depth boundary
    const z2: u5 = bz +% 2;

    const Rot = struct {
        /// Rotate an (x, z) pair around the block origin and return [x, y, z].
        fn pt(f: Facing, ox: u5, oz: u5, px: u5, py: u5, pz: u5) [3]u5 {
            const rp = rotatePt(f, ox, oz, px, pz);
            return .{ rp[0], py, rp[1] };
        }
    };

    // --- 1. Bottom face (full, y = y0, face = bottom / 5) ---
    addQuad(&mesh, rotateFace(facing, 5), light, tex, R.pt(facing, x0, z0, x0, y0, z2), R.pt(facing, x0, z0, x0, y0, z0), R.pt(facing, x0, z0, x1, y0, z0), R.pt(facing, x0, z0, x1, y0, z2));

    // --- 2. Top-back face (half, y = y2, z in [z0..z1], face = top / 4) ---
    addQuad(&mesh, rotateFace(facing, 4), light, tex, R.pt(facing, x0, z0, x0, y2, z0), R.pt(facing, x0, z0, x0, y2, z1), R.pt(facing, x0, z0, x1, y2, z1), R.pt(facing, x0, z0, x1, y2, z0));

    // --- 3. Top-step face (half, y = y1, z in [z1..z2], face = top / 4) ---
    addQuad(&mesh, rotateFace(facing, 4), light, tex, R.pt(facing, x0, z0, x0, y1, z1), R.pt(facing, x0, z0, x0, y1, z2), R.pt(facing, x0, z0, x1, y1, z2), R.pt(facing, x0, z0, x1, y1, z1));

    // --- 4. Front-bottom face (half height, y in [y0..y1], z = z2, face = south / 1) ---
    addQuad(&mesh, rotateFace(facing, 1), light, tex, R.pt(facing, x0, z0, x0, y0, z2), R.pt(facing, x0, z0, x1, y0, z2), R.pt(facing, x0, z0, x1, y1, z2), R.pt(facing, x0, z0, x0, y1, z2));

    // --- 5. Front-top face (half height, set back, y in [y1..y2], z = z1, face = south / 1) ---
    addQuad(&mesh, rotateFace(facing, 1), light, tex, R.pt(facing, x0, z0, x0, y1, z1), R.pt(facing, x0, z0, x1, y1, z1), R.pt(facing, x0, z0, x1, y2, z1), R.pt(facing, x0, z0, x0, y2, z1));

    // --- 6. Back face (full, y in [y0..y2], z = z0, face = north / 0) ---
    addQuad(&mesh, rotateFace(facing, 0), light, tex, R.pt(facing, x0, z0, x1, y0, z0), R.pt(facing, x0, z0, x0, y0, z0), R.pt(facing, x0, z0, x0, y2, z0), R.pt(facing, x0, z0, x1, y2, z0));

    // --- 7. Left face (L-shape, x = x0, face = west / 3) ---
    //   Lower portion: y0..y1 across full depth z0..z2
    addQuad(&mesh, rotateFace(facing, 3), light, tex, R.pt(facing, x0, z0, x0, y0, z0), R.pt(facing, x0, z0, x0, y0, z2), R.pt(facing, x0, z0, x0, y1, z2), R.pt(facing, x0, z0, x0, y1, z0));

    // --- 8. Left upper portion (y1..y2, z0..z1) ---
    addQuad(&mesh, rotateFace(facing, 3), light, tex, R.pt(facing, x0, z0, x0, y1, z0), R.pt(facing, x0, z0, x0, y1, z1), R.pt(facing, x0, z0, x0, y2, z1), R.pt(facing, x0, z0, x0, y2, z0));

    // --- 9. Right face lower portion (y0..y1, z0..z2, x = x1, face = east / 2) ---
    addQuad(&mesh, rotateFace(facing, 2), light, tex, R.pt(facing, x0, z0, x1, y0, z2), R.pt(facing, x0, z0, x1, y0, z0), R.pt(facing, x0, z0, x1, y1, z0), R.pt(facing, x0, z0, x1, y1, z2));

    // --- 10. Right face upper portion (y1..y2, z0..z1) ---
    addQuad(&mesh, rotateFace(facing, 2), light, tex, R.pt(facing, x0, z0, x1, y1, z1), R.pt(facing, x0, z0, x1, y1, z0), R.pt(facing, x0, z0, x1, y2, z0), R.pt(facing, x0, z0, x1, y2, z1));

    return mesh;
}

// -----------------------------------------------------------------------
// Tests
// -----------------------------------------------------------------------

test "stair mesh produces 10 quads (40 vertices, 60 indices)" {
    const mesh = generateStair(0, 0, 0, 42, 8, .north);
    try std.testing.expectEqual(@as(u32, 40), mesh.vertex_count);
    try std.testing.expectEqual(@as(u32, 60), mesh.index_count);
}

test "all indices reference valid vertices" {
    const mesh = generateStair(2, 4, 6, 100, 15, .east);
    for (0..mesh.index_count) |i| {
        try std.testing.expect(mesh.indices[i] < mesh.vertex_count);
    }
}

test "texture is preserved in every vertex" {
    const tex: u16 = 500;
    const mesh = generateStair(0, 0, 0, tex, 0, .south);
    for (0..mesh.vertex_count) |i| {
        try std.testing.expectEqual(tex, decodeTex(mesh.vertices[i]));
    }
}

test "light value is preserved in every vertex" {
    const light: u4 = 12;
    const mesh = generateStair(0, 0, 0, 1, light, .west);
    for (0..mesh.vertex_count) |i| {
        try std.testing.expectEqual(light, decodeLight(mesh.vertices[i]));
    }
}

test "vertex positions stay within block bounds" {
    const bx: u5 = 4;
    const by: u5 = 6;
    const bz: u5 = 8;
    const mesh = generateStair(bx, by, bz, 0, 0, .north);
    for (0..mesh.vertex_count) |i| {
        const v = mesh.vertices[i];
        try std.testing.expect(decodeX(v) >= bx and decodeX(v) <= bx + 2);
        try std.testing.expect(decodeY(v) >= by and decodeY(v) <= by + 2);
        try std.testing.expect(decodeZ(v) >= bz and decodeZ(v) <= bz + 2);
    }
}

test "north and south facings produce different vertex positions" {
    const north = generateStair(4, 4, 4, 0, 0, .north);
    const south = generateStair(4, 4, 4, 0, 0, .south);

    // At least one vertex position must differ.
    var differ = false;
    for (0..north.vertex_count) |i| {
        if (north.vertices[i].pos_data != south.vertices[i].pos_data) {
            differ = true;
            break;
        }
    }
    try std.testing.expect(differ);
}

test "all four facings produce the same vertex and index counts" {
    const facings = [_]Facing{ .north, .east, .south, .west };
    for (facings) |f| {
        const mesh = generateStair(2, 2, 2, 10, 5, f);
        try std.testing.expectEqual(@as(u32, 40), mesh.vertex_count);
        try std.testing.expectEqual(@as(u32, 60), mesh.index_count);
    }
}
