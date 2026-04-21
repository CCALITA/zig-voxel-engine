/// Indexed mesh generator for chunk data.
/// Each exposed face produces 4 unique vertices and 6 indices (two triangles).
///
/// Vertex format (two u32 attributes):
///   pos_data: x(5) y(5) z(5) face(3) corner(2) ao(2) light(4) pad(6) = 32 bits
///   tex_data: tex(12) anim(4) tint(8) reserved(8) = 32 bits
const std = @import("std");
const block = @import("block.zig");
const Chunk = @import("chunk.zig");
const ao_mod = @import("ao.zig");
const light_mod = @import("light.zig");

pub const Vertex = extern struct {
    pos_data: u32,
    tex_data: u32,
};

pub fn makeVertex(x: u5, y: u5, z: u5, face: u3, corner: u2, ao: u2, light: u4, tex: u16) Vertex {
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
const face_vertices = [6][4][3]u1{
    .{ .{ 1, 0, 0 }, .{ 0, 0, 0 }, .{ 0, 1, 0 }, .{ 1, 1, 0 } },
    .{ .{ 0, 0, 1 }, .{ 1, 0, 1 }, .{ 1, 1, 1 }, .{ 0, 1, 1 } },
    .{ .{ 1, 0, 1 }, .{ 1, 0, 0 }, .{ 1, 1, 0 }, .{ 1, 1, 1 } },
    .{ .{ 0, 0, 0 }, .{ 0, 0, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 0 } },
    .{ .{ 0, 1, 0 }, .{ 0, 1, 1 }, .{ 1, 1, 1 }, .{ 1, 1, 0 } },
    .{ .{ 0, 0, 1 }, .{ 0, 0, 0 }, .{ 1, 0, 0 }, .{ 1, 0, 1 } },
};

pub const face_normals = [6][3]i32{
    .{ 0, 0, -1 },
    .{ 0, 0, 1 },
    .{ 1, 0, 0 },
    .{ -1, 0, 0 },
    .{ 0, 1, 0 },
    .{ 0, -1, 0 },
};

pub const quad_indices = [6]u2{ 0, 1, 2, 2, 3, 0 };

pub fn isNeighborSolid(chunk: *const Chunk, neighbors: NeighborChunks, nx: i32, ny: i32, nz: i32) bool {
    const size: i32 = Chunk.SIZE;
    if (nx >= 0 and nx < size and ny >= 0 and ny < size and nz >= 0 and nz < size) {
        return chunk.isNeighborSolid(nx, ny, nz);
    }
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
    return false;
}

pub const NeighborChunks = struct {
    north: ?*const Chunk = null,
    south: ?*const Chunk = null,
    east: ?*const Chunk = null,
    west: ?*const Chunk = null,
    top: ?*const Chunk = null,
    bottom: ?*const Chunk = null,
};

pub fn generateMesh(allocator: std.mem.Allocator, chunk: *const Chunk) !IndexedMeshData {
    return generateMeshWithNeighbors(allocator, chunk, .{});
}

pub fn generateMeshWithNeighbors(allocator: std.mem.Allocator, chunk: *const Chunk, neighbors: NeighborChunks) !IndexedMeshData {
    var vertices: std.ArrayList(Vertex) = .empty;
    errdefer vertices.deinit(allocator);

    var indices: std.ArrayList(u32) = .empty;
    errdefer indices.deinit(allocator);

    const light_map = light_mod.computeFullLighting(chunk);

    for (0..Chunk.SIZE) |yi| {
        for (0..Chunk.SIZE) |zi| {
            for (0..Chunk.SIZE) |xi| {
                const bx: u4 = @intCast(xi);
                const by: u4 = @intCast(yi);
                const bz: u4 = @intCast(zi);

                const id = chunk.getBlock(bx, by, bz);
                if (id == block.AIR) continue;

                const def = block.get(id);
                const light_level = light_map.getCombinedLight(bx, by, bz);

                for (0..6) |face_idx| {
                    const nx = @as(i32, bx) + face_normals[face_idx][0];
                    const ny = @as(i32, by) + face_normals[face_idx][1];
                    const nz = @as(i32, bz) + face_normals[face_idx][2];

                    if (isNeighborSolid(chunk, neighbors, nx, ny, nz)) continue;

                    const tex = def.tex[face_idx];
                    const corners = face_vertices[face_idx];
                    const base: u32 = @intCast(vertices.items.len);
                    const face_ao = ao_mod.computeFaceAO(chunk, bx, by, bz, @intCast(face_idx));

                    for (0..4) |ci| {
                        const corner = corners[ci];
                        try vertices.append(allocator, makeVertex(
                            @as(u5, bx) + corner[0],
                            @as(u5, by) + corner[1],
                            @as(u5, bz) + corner[2],
                            @intCast(face_idx),
                            @intCast(ci),
                            face_ao.corners[ci],
                            light_level,
                            tex,
                        ));
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
    try std.testing.expectEqual(@as(usize, 24), mesh.vertices.len);
    try std.testing.expectEqual(@as(usize, 36), mesh.indices.len);
}

test "two adjacent blocks have fewer vertices (shared face culled)" {
    var chunk = Chunk.init();
    chunk.setBlock(8, 8, 8, block.STONE);
    chunk.setBlock(9, 8, 8, block.STONE);
    var mesh = try generateMesh(std.testing.allocator, &chunk);
    defer mesh.deinit();
    try std.testing.expectEqual(@as(usize, 40), mesh.vertices.len);
    try std.testing.expectEqual(@as(usize, 60), mesh.indices.len);
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

test "vertex tex field preserves large indices" {
    const v = makeVertex(0, 0, 0, 0, 0, 0, 0, 500);
    try std.testing.expectEqual(@as(u32, 500), v.tex_data & 0xFFF);
}
