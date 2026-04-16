/// Generates indexed mesh data from a chunk.
/// Each exposed face produces 4 vertices + 6 indices (two triangles) with packed vertex data.
///
/// Vertex format (packed u32):
///   bits [0..4]   = x position (0-15)
///   bits [5..9]   = y position (0-15)
///   bits [10..14] = z position (0-15)
///   bits [15..17] = face index (0-5)
///   bits [18..19] = corner index (0-3) for UV
///   bits [20..31] = texture layer index (0-4095)
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

// Face vertex offsets: 4 corners per face, each a (dx, dy, dz) offset
// Winding order is CCW when viewed from outside the block
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

// Face normal directions for neighbor checking
const face_normals = [6][3]i32{
    .{ 0, 0, -1 }, // North
    .{ 0, 0, 1 }, // South
    .{ 1, 0, 0 }, // East
    .{ -1, 0, 0 }, // West
    .{ 0, 1, 0 }, // Top
    .{ 0, -1, 0 }, // Bottom
};

// Two triangles per quad: indices into the 4 corners (0, 1, 2, 2, 3, 0)
const quad_indices = [6]u32{ 0, 1, 2, 2, 3, 0 };

pub fn generateMesh(allocator: std.mem.Allocator, chunk: *const Chunk) !IndexedMeshData {
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

                // Check each face
                for (0..6) |face_idx| {
                    const nx = @as(i32, bx) + face_normals[face_idx][0];
                    const ny = @as(i32, by) + face_normals[face_idx][1];
                    const nz = @as(i32, bz) + face_normals[face_idx][2];

                    // Only emit face if neighbor is not solid
                    if (chunk.isNeighborSolid(nx, ny, nz)) continue;

                    const tex = def.tex[face_idx];
                    const corners = face_vertices[face_idx];
                    const base_index: u32 = @intCast(vertices.items.len);

                    // Emit 4 vertices (quad corners)
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

                    // Emit 6 indices (two triangles)
                    for (quad_indices) |qi| {
                        try indices.append(allocator, base_index + qi);
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
    var mesh_data = try generateMesh(std.testing.allocator, &chunk);
    defer mesh_data.deinit();
    try std.testing.expectEqual(@as(usize, 0), mesh_data.vertices.len);
    try std.testing.expectEqual(@as(usize, 0), mesh_data.indices.len);
}

test "single block produces 24 vertices and 36 indices (6 faces)" {
    var chunk = Chunk.init();
    chunk.setBlock(8, 8, 8, block.STONE);
    var mesh_data = try generateMesh(std.testing.allocator, &chunk);
    defer mesh_data.deinit();
    // 6 faces * 4 vertices = 24
    try std.testing.expectEqual(@as(usize, 24), mesh_data.vertices.len);
    // 6 faces * 6 indices = 36
    try std.testing.expectEqual(@as(usize, 36), mesh_data.indices.len);
}

test "two adjacent blocks share a face (fewer vertices and indices)" {
    var chunk = Chunk.init();
    chunk.setBlock(8, 8, 8, block.STONE);
    chunk.setBlock(9, 8, 8, block.STONE);
    var mesh_data = try generateMesh(std.testing.allocator, &chunk);
    defer mesh_data.deinit();
    // 2 blocks * 24 verts - 2 shared faces * 4 verts = 40
    try std.testing.expectEqual(@as(usize, 40), mesh_data.vertices.len);
    // 2 blocks * 36 indices - 2 shared faces * 6 indices = 60
    try std.testing.expectEqual(@as(usize, 60), mesh_data.indices.len);
}
