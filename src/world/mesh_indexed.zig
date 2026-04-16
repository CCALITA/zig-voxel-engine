/// Indexed mesh generator for chunk data.
/// Each exposed face produces 4 unique vertices and 6 indices (two triangles),
/// reducing vertex count compared to the naive 6-vertices-per-quad approach.
///
/// Vertex format is identical to mesh.zig (packed u32).
const std = @import("std");
const block = @import("block.zig");
const Chunk = @import("chunk.zig");

pub const Vertex = packed struct(u32) {
    x: u5,
    y: u5,
    z: u5,
    face: u3,
    corner: u2,
    tex: u12,
};

pub const IndexedMeshData = struct {
    vertices: []Vertex,
    indices: []u32,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *IndexedMeshData) void {
        self.allocator.free(self.vertices);
        self.allocator.free(self.indices);
    }
};

// Face vertex offsets: 4 corners per face, each a (dx, dy, dz) offset.
// Winding order is CCW when viewed from outside the block.
const face_vertices = [6][4][3]u1{
    // North (-Z): x goes right-to-left when looking at the face
    .{ .{ 1, 0, 0 }, .{ 0, 0, 0 }, .{ 0, 1, 0 }, .{ 1, 1, 0 } },
    // South (+Z)
    .{ .{ 0, 0, 1 }, .{ 1, 0, 1 }, .{ 1, 1, 1 }, .{ 0, 1, 1 } },
    // East (+X)
    .{ .{ 1, 0, 1 }, .{ 1, 0, 0 }, .{ 1, 1, 0 }, .{ 1, 1, 1 } },
    // West (-X)
    .{ .{ 0, 0, 0 }, .{ 0, 0, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 0 } },
    // Top (+Y)
    .{ .{ 0, 1, 0 }, .{ 0, 1, 1 }, .{ 1, 1, 1 }, .{ 1, 1, 0 } },
    // Bottom (-Y)
    .{ .{ 0, 0, 1 }, .{ 0, 0, 0 }, .{ 1, 0, 0 }, .{ 1, 0, 1 } },
};

// Face normal directions for neighbor checking.
pub const face_normals = [6][3]i32{
    .{ 0, 0, -1 }, // North
    .{ 0, 0, 1 }, // South
    .{ 1, 0, 0 }, // East
    .{ -1, 0, 0 }, // West
    .{ 0, 1, 0 }, // Top
    .{ 0, -1, 0 }, // Bottom
};

// Two triangles per quad: indices into the 4 corners (0,1,2 and 2,3,0).
pub const quad_indices = [6]u2{ 0, 1, 2, 2, 3, 0 };

pub fn isNeighborSolid(chunk: *const Chunk, neighbors: NeighborChunks, nx: i32, ny: i32, nz: i32) bool {
    const size: i32 = Chunk.SIZE;
    // Within this chunk
    if (nx >= 0 and nx < size and ny >= 0 and ny < size and nz >= 0 and nz < size) {
        return chunk.isNeighborSolid(nx, ny, nz);
    }
    // Check neighbor chunks
    const neighbor_chunk: ?*const Chunk = if (nx < 0) neighbors.west
        else if (nx >= size) neighbors.east
        else if (ny < 0) neighbors.bottom
        else if (ny >= size) neighbors.top
        else if (nz < 0) neighbors.north
        else if (nz >= size) neighbors.south
        else null;

    if (neighbor_chunk) |nc| {
        const lx: u4 = @intCast(@mod(nx, size));
        const ly: u4 = @intCast(@mod(ny, size));
        const lz: u4 = @intCast(@mod(nz, size));
        return block.isSolid(nc.getBlock(lx, ly, lz));
    }
    // No neighbor chunk loaded — treat as air (emit the face)
    return false;
}

pub const NeighborChunks = struct {
    north: ?*const Chunk = null, // -Z
    south: ?*const Chunk = null, // +Z
    east: ?*const Chunk = null, // +X
    west: ?*const Chunk = null, // -X
    top: ?*const Chunk = null, // +Y
    bottom: ?*const Chunk = null, // -Y
};

pub fn generateMesh(allocator: std.mem.Allocator, chunk: *const Chunk) !IndexedMeshData {
    return generateMeshWithNeighbors(allocator, chunk, .{});
}

pub fn generateMeshWithNeighbors(allocator: std.mem.Allocator, chunk: *const Chunk, neighbors: NeighborChunks) !IndexedMeshData {
    var vertices: std.ArrayList(Vertex) = .empty;
    errdefer vertices.deinit(allocator);

    var indices: std.ArrayList(u32) = .empty;
    errdefer indices.deinit(allocator);

    for (0..Chunk.SIZE) |yi| {
        for (0..Chunk.SIZE) |zi| {
            for (0..Chunk.SIZE) |xi| {
                const bx: u4 = @intCast(xi);
                const by: u4 = @intCast(yi);
                const bz: u4 = @intCast(zi);

                const id = chunk.getBlock(bx, by, bz);
                if (id == block.AIR) continue;

                const def = block.get(id);

                for (0..6) |face_idx| {
                    const nx = @as(i32, bx) + face_normals[face_idx][0];
                    const ny = @as(i32, by) + face_normals[face_idx][1];
                    const nz = @as(i32, bz) + face_normals[face_idx][2];

                    if (isNeighborSolid(chunk, neighbors, nx, ny, nz)) continue;

                    const tex = def.tex[face_idx];
                    const corners = face_vertices[face_idx];
                    const base: u32 = @intCast(vertices.items.len);

                    for (0..4) |ci| {
                        const corner = corners[ci];
                        try vertices.append(allocator, .{
                            .x = @as(u5, bx) + corner[0],
                            .y = @as(u5, by) + corner[1],
                            .z = @as(u5, bz) + corner[2],
                            .face = @intCast(face_idx),
                            .corner = @intCast(ci),
                            .tex = @intCast(tex),
                        });
                    }

                    for (quad_indices) |ci| {
                        try indices.append(allocator, base + ci);
                    }
                }
            }
        }
    }

    return .{
        .vertices = try vertices.toOwnedSlice(allocator),
        .indices = try indices.toOwnedSlice(allocator),
        .allocator = allocator,
    };
}

test "empty chunk produces no mesh" {
    const chunk = Chunk.init();
    var mesh = try generateMesh(std.testing.allocator, &chunk);
    defer mesh.deinit();
    try std.testing.expectEqual(@as(usize, 0), mesh.vertices.len);
    try std.testing.expectEqual(@as(usize, 0), mesh.indices.len);
}

test "single block produces 24 vertices and 36 indices" {
    var chunk = Chunk.init();
    chunk.setBlock(8, 8, 8, block.STONE);
    var mesh = try generateMesh(std.testing.allocator, &chunk);
    defer mesh.deinit();
    // 6 faces * 4 vertices = 24
    try std.testing.expectEqual(@as(usize, 24), mesh.vertices.len);
    // 6 faces * 6 indices = 36
    try std.testing.expectEqual(@as(usize, 36), mesh.indices.len);
}

test "two adjacent blocks have fewer vertices (shared face culled)" {
    var chunk = Chunk.init();
    chunk.setBlock(8, 8, 8, block.STONE);
    chunk.setBlock(9, 8, 8, block.STONE);
    var mesh = try generateMesh(std.testing.allocator, &chunk);
    defer mesh.deinit();
    // 2 blocks * 24 verts - 2 culled faces * 4 verts = 40
    try std.testing.expectEqual(@as(usize, 40), mesh.vertices.len);
    // 2 blocks * 36 indices - 2 culled faces * 6 indices = 60
    try std.testing.expectEqual(@as(usize, 60), mesh.indices.len);
    // Fewer than two isolated blocks would produce
    try std.testing.expect(mesh.vertices.len < 48);
}

test "all indices are valid (less than vertex count)" {
    var chunk = Chunk.init();
    chunk.setBlock(8, 8, 8, block.STONE);
    chunk.setBlock(9, 8, 8, block.STONE);
    var mesh = try generateMesh(std.testing.allocator, &chunk);
    defer mesh.deinit();
    for (mesh.indices) |idx| {
        try std.testing.expect(idx < mesh.vertices.len);
    }
}
