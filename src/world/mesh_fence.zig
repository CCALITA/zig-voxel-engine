/// Fence and wall mesh generator.
///
/// Produces geometry for fence posts with optional connecting horizontal bars
/// to adjacent fences (N/S/E/W), and wall posts with thinner wall segments.
///
/// Coordinate space: 16 sub-block units per block. Positions are encoded as
/// pixel offsets from the chunk origin (block_pos * 16 + sub_offset).
///
/// Vertex format (two u32 attributes):
///   pos_data: x(9) y(9) z(9) face(3) corner(2) = 32 bits
///   tex_data: tex(12) light(4) pad(16) = 32 bits
const std = @import("std");

pub const Vertex = extern struct {
    pos_data: u32,
    tex_data: u32,
};

/// Pack a vertex from sub-block pixel coordinates and face metadata.
pub fn makeVertex(x: u16, y: u16, z: u16, face: u3, corner: u2, tex: u16, light: u4) Vertex {
    const pos: u32 = (x & 0x1FF) |
        (@as(u32, y & 0x1FF) << 9) |
        (@as(u32, z & 0x1FF) << 18) |
        (@as(u32, face) << 27) |
        (@as(u32, corner) << 30);
    const td: u32 = (tex & 0xFFF) | (@as(u32, light) << 12);
    return .{ .pos_data = pos, .tex_data = td };
}

/// Extract the x pixel coordinate from a vertex.
fn vertexX(v: Vertex) u16 {
    return @intCast(v.pos_data & 0x1FF);
}

/// Extract the y pixel coordinate from a vertex.
fn vertexY(v: Vertex) u16 {
    return @intCast((v.pos_data >> 9) & 0x1FF);
}

/// Extract the z pixel coordinate from a vertex.
fn vertexZ(v: Vertex) u16 {
    return @intCast((v.pos_data >> 18) & 0x1FF);
}

/// Extract the face index from a vertex.
fn vertexFace(v: Vertex) u3 {
    return @intCast((v.pos_data >> 27) & 0x7);
}

/// Extract the texture index from a vertex.
fn vertexTex(v: Vertex) u16 {
    return @intCast(v.tex_data & 0xFFF);
}

/// Extract the light level from a vertex.
fn vertexLight(v: Vertex) u4 {
    return @intCast((v.tex_data >> 12) & 0xF);
}

pub const Connections = packed struct {
    north: bool = false,
    south: bool = false,
    east: bool = false,
    west: bool = false,
};

// Fence post: 4x16x4 pixels centered in a 16x16x16 block.
const FENCE_POST_MIN_XZ = 6;
const FENCE_POST_MAX_XZ = 10;
const FENCE_POST_MIN_Y = 0;
const FENCE_POST_MAX_Y = 16;

// Fence bar dimensions: 2 pixels wide (centered in xz), two bars at y=7..9 and y=12..14.
const FENCE_BAR_WIDTH = 2;
const FENCE_BAR_MIN_XZ = 7;
const FENCE_BAR_MAX_XZ = 9;

const FenceBar = struct { y_min: u16, y_max: u16 };
const FENCE_BARS = [2]FenceBar{
    .{ .y_min = 6, .y_max = 9 },
    .{ .y_min = 12, .y_max = 15 },
};

// Wall post: 8x16x8 pixels centered.
const WALL_POST_MIN_XZ = 4;
const WALL_POST_MAX_XZ = 12;

// Wall segment: 8 pixels wide (centered), 14 tall.
const WALL_SEG_MIN_XZ = 5;
const WALL_SEG_MAX_XZ = 11;
const WALL_SEG_HEIGHT = 14;

/// Maximum vertices for a fence: post (24) + 4 directions * 2 bars * 24 = 216.
const MAX_FENCE_VERTS = 24 + 4 * 2 * 24;
/// Maximum vertices for a wall: post (24) + 4 directions * 24 = 120.
const MAX_WALL_VERTS = 24 + 4 * 24;

pub const FenceMesh = struct {
    verts: [MAX_FENCE_VERTS]Vertex,
    len: usize,
};

pub const WallMesh = struct {
    verts: [MAX_WALL_VERTS]Vertex,
    len: usize,
};

/// Emit 6 faces (24 vertices) for an axis-aligned box defined by min/max pixel
/// coordinates. Returns the number of vertices written (always 24).
fn emitBox(
    buf: []Vertex,
    bx: u16,
    by: u16,
    bz: u16,
    x0: u16,
    y0: u16,
    z0: u16,
    x1: u16,
    y1: u16,
    z1: u16,
    tex: u16,
    light: u4,
) usize {
    // Absolute pixel positions.
    const ax0 = bx + x0;
    const ax1 = bx + x1;
    const ay0 = by + y0;
    const ay1 = by + y1;
    const az0 = bz + z0;
    const az1 = bz + z1;

    // 6 faces, 4 verts each.  Face order matches mesh_indexed:
    // 0=North(-Z) 1=South(+Z) 2=East(+X) 3=West(-X) 4=Top(+Y) 5=Bottom(-Y)
    const faces = [6][4][3]u16{
        // North (-Z): z = az0
        .{ .{ ax1, ay0, az0 }, .{ ax0, ay0, az0 }, .{ ax0, ay1, az0 }, .{ ax1, ay1, az0 } },
        // South (+Z): z = az1
        .{ .{ ax0, ay0, az1 }, .{ ax1, ay0, az1 }, .{ ax1, ay1, az1 }, .{ ax0, ay1, az1 } },
        // East (+X): x = ax1
        .{ .{ ax1, ay0, az1 }, .{ ax1, ay0, az0 }, .{ ax1, ay1, az0 }, .{ ax1, ay1, az1 } },
        // West (-X): x = ax0
        .{ .{ ax0, ay0, az0 }, .{ ax0, ay0, az1 }, .{ ax0, ay1, az1 }, .{ ax0, ay1, az0 } },
        // Top (+Y): y = ay1
        .{ .{ ax0, ay1, az0 }, .{ ax0, ay1, az1 }, .{ ax1, ay1, az1 }, .{ ax1, ay1, az0 } },
        // Bottom (-Y): y = ay0
        .{ .{ ax0, ay0, az1 }, .{ ax0, ay0, az0 }, .{ ax1, ay0, az0 }, .{ ax1, ay0, az1 } },
    };

    var n: usize = 0;
    for (0..6) |fi| {
        for (0..4) |ci| {
            const c = faces[fi][ci];
            buf[n] = makeVertex(c[0], c[1], c[2], @intCast(fi), @intCast(ci), tex, light);
            n += 1;
        }
    }
    return n;
}

/// Generate fence mesh: center post plus optional horizontal bars to each connected neighbor.
pub fn generateFence(bx: u5, by: u5, bz: u5, tex: u16, light: u4, conn: Connections) FenceMesh {
    var mesh = FenceMesh{ .verts = undefined, .len = 0 };
    const px: u16 = @as(u16, bx) * 16;
    const py: u16 = @as(u16, by) * 16;
    const pz: u16 = @as(u16, bz) * 16;

    // Center post: 4x16x4 centered (pixels 6..10 in x and z, 0..16 in y).
    mesh.len += emitBox(
        mesh.verts[mesh.len..],
        px,
        py,
        pz,
        FENCE_POST_MIN_XZ,
        FENCE_POST_MIN_Y,
        FENCE_POST_MIN_XZ,
        FENCE_POST_MAX_XZ,
        FENCE_POST_MAX_Y,
        FENCE_POST_MAX_XZ,
        tex,
        light,
    );

    // Horizontal bars for each connection.
    const dirs = [4]struct { dx: i8, dz: i8, conn_flag: bool }{
        .{ .dx = 0, .dz = -1, .conn_flag = conn.north },
        .{ .dx = 0, .dz = 1, .conn_flag = conn.south },
        .{ .dx = 1, .dz = 0, .conn_flag = conn.east },
        .{ .dx = -1, .dz = 0, .conn_flag = conn.west },
    };

    for (dirs) |dir| {
        if (!dir.conn_flag) continue;

        for (FENCE_BARS) |bar| {
            // Bar extends from post edge to block boundary in the connection direction.
            var x0: u16 = FENCE_BAR_MIN_XZ;
            var x1: u16 = FENCE_BAR_MAX_XZ;
            var z0: u16 = FENCE_BAR_MIN_XZ;
            var z1: u16 = FENCE_BAR_MAX_XZ;

            if (dir.dx < 0) {
                x0 = 0;
                x1 = FENCE_BAR_MAX_XZ;
            } else if (dir.dx > 0) {
                x0 = FENCE_BAR_MIN_XZ;
                x1 = 16;
            }

            if (dir.dz < 0) {
                z0 = 0;
                z1 = FENCE_BAR_MAX_XZ;
            } else if (dir.dz > 0) {
                z0 = FENCE_BAR_MIN_XZ;
                z1 = 16;
            }

            mesh.len += emitBox(
                mesh.verts[mesh.len..],
                px,
                py,
                pz,
                x0,
                bar.y_min,
                z0,
                x1,
                bar.y_max,
                z1,
                tex,
                light,
            );
        }
    }

    return mesh;
}

/// Generate wall mesh: wider center post plus optional wall segments to connected neighbors.
pub fn generateWall(bx: u5, by: u5, bz: u5, tex: u16, light: u4, conn: Connections) WallMesh {
    var mesh = WallMesh{ .verts = undefined, .len = 0 };
    const px: u16 = @as(u16, bx) * 16;
    const py: u16 = @as(u16, by) * 16;
    const pz: u16 = @as(u16, bz) * 16;

    // Center post: 8x16x8 centered (pixels 4..12).
    mesh.len += emitBox(
        mesh.verts[mesh.len..],
        px,
        py,
        pz,
        WALL_POST_MIN_XZ,
        0,
        WALL_POST_MIN_XZ,
        WALL_POST_MAX_XZ,
        16,
        WALL_POST_MAX_XZ,
        tex,
        light,
    );

    // Wall segments.
    const dirs = [4]struct { dx: i8, dz: i8, conn_flag: bool }{
        .{ .dx = 0, .dz = -1, .conn_flag = conn.north },
        .{ .dx = 0, .dz = 1, .conn_flag = conn.south },
        .{ .dx = 1, .dz = 0, .conn_flag = conn.east },
        .{ .dx = -1, .dz = 0, .conn_flag = conn.west },
    };

    for (dirs) |dir| {
        if (!dir.conn_flag) continue;

        var x0: u16 = WALL_SEG_MIN_XZ;
        var x1: u16 = WALL_SEG_MAX_XZ;
        var z0: u16 = WALL_SEG_MIN_XZ;
        var z1: u16 = WALL_SEG_MAX_XZ;

        if (dir.dx < 0) {
            x0 = 0;
            x1 = WALL_SEG_MAX_XZ;
        } else if (dir.dx > 0) {
            x0 = WALL_SEG_MIN_XZ;
            x1 = 16;
        }

        if (dir.dz < 0) {
            z0 = 0;
            z1 = WALL_SEG_MAX_XZ;
        } else if (dir.dz > 0) {
            z0 = WALL_SEG_MIN_XZ;
            z1 = 16;
        }

        mesh.len += emitBox(
            mesh.verts[mesh.len..],
            px,
            py,
            pz,
            x0,
            0,
            z0,
            x1,
            WALL_SEG_HEIGHT,
            z1,
            tex,
            light,
        );
    }

    return mesh;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "fence post only produces 24 vertices" {
    const mesh = generateFence(0, 0, 0, 10, 15, .{});
    try std.testing.expectEqual(@as(usize, 24), mesh.len);
}

test "fence with all connections produces post + 8 bars" {
    const mesh = generateFence(1, 2, 3, 5, 12, .{
        .north = true,
        .south = true,
        .east = true,
        .west = true,
    });
    // post (24) + 4 directions * 2 bars * 24 verts = 216
    try std.testing.expectEqual(@as(usize, 24 + 4 * 2 * 24), mesh.len);
}

test "fence single connection produces post + 2 bars" {
    const mesh = generateFence(5, 5, 5, 0, 8, .{ .north = true });
    // post (24) + 1 dir * 2 bars * 24 = 72
    try std.testing.expectEqual(@as(usize, 72), mesh.len);
}

test "makeVertex round-trips all fields" {
    const v = makeVertex(300, 200, 100, 5, 3, 4000, 14);
    try std.testing.expectEqual(@as(u16, 300), vertexX(v));
    try std.testing.expectEqual(@as(u16, 200), vertexY(v));
    try std.testing.expectEqual(@as(u16, 100), vertexZ(v));
    try std.testing.expectEqual(@as(u3, 5), vertexFace(v));
    try std.testing.expectEqual(@as(u16, 4000 & 0xFFF), vertexTex(v));
    try std.testing.expectEqual(@as(u4, 14), vertexLight(v));
}

test "wall post only produces 24 vertices" {
    const mesh = generateWall(0, 0, 0, 10, 15, .{});
    try std.testing.expectEqual(@as(usize, 24), mesh.len);
}

test "wall with all connections produces post + 4 segments" {
    const mesh = generateWall(2, 3, 4, 7, 10, .{
        .north = true,
        .south = true,
        .east = true,
        .west = true,
    });
    // post (24) + 4 segments * 24 = 120
    try std.testing.expectEqual(@as(usize, 120), mesh.len);
}

test "fence vertex positions are within block pixel bounds" {
    const bx: u5 = 5;
    const by: u5 = 3;
    const bz: u5 = 7;
    const mesh = generateFence(bx, by, bz, 0, 15, .{
        .north = true,
        .south = true,
        .east = true,
        .west = true,
    });
    const px_min: u16 = @as(u16, bx) * 16;
    const py_min: u16 = @as(u16, by) * 16;
    const pz_min: u16 = @as(u16, bz) * 16;
    const px_max: u16 = px_min + 16;
    const py_max: u16 = py_min + 16;
    const pz_max: u16 = pz_min + 16;

    for (mesh.verts[0..mesh.len]) |v| {
        const x = vertexX(v);
        const y = vertexY(v);
        const z = vertexZ(v);
        try std.testing.expect(x >= px_min and x <= px_max);
        try std.testing.expect(y >= py_min and y <= py_max);
        try std.testing.expect(z >= pz_min and z <= pz_max);
    }
}

test "fence texture and light propagate to all vertices" {
    const tex: u16 = 42;
    const light: u4 = 11;
    const mesh = generateFence(0, 0, 0, tex, light, .{ .east = true });
    for (mesh.verts[0..mesh.len]) |v| {
        try std.testing.expectEqual(tex, vertexTex(v));
        try std.testing.expectEqual(light, vertexLight(v));
    }
}

test "connections packed struct bit layout" {
    const c = Connections{ .north = true, .south = false, .east = true, .west = false };
    const bits: u4 = @bitCast(c);
    // north=bit0=1, south=bit1=0, east=bit2=1, west=bit3=0 => 0b0101 = 5
    try std.testing.expectEqual(@as(u4, 5), bits);
}
