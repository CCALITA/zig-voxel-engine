/// Greedy mesh generator for chunk data.
/// Merges adjacent coplanar faces with the same texture into larger quads,
/// drastically reducing vertex/index count for homogeneous regions.
const std = @import("std");
const block = @import("block.zig");
const Chunk = @import("chunk.zig");
const mesh_indexed = @import("mesh_indexed.zig");

pub const Vertex = mesh_indexed.Vertex;

pub const GreedyMeshData = struct {
    vertices: []Vertex,
    indices: []u32,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *GreedyMeshData) void {
        self.allocator.free(self.vertices);
        self.allocator.free(self.indices);
    }
};

pub const NeighborChunks = mesh_indexed.NeighborChunks;

const SIZE = Chunk.SIZE;

/// Texture ID stored in the mask, or 0 meaning "no face here".
/// We add 1 to real texture IDs so that 0 is unambiguously "empty",
/// since texture index 0 is a valid texture.
const MaskEntry = u16;
const MASK_EMPTY: MaskEntry = 0;

fn maskEntry(tex: u16) MaskEntry {
    return tex +| 1;
}

const quad_indices = mesh_indexed.quad_indices;
const face_normals = mesh_indexed.face_normals;
const isNeighborSolid = mesh_indexed.isNeighborSolid;

/// Per-face axis mapping.
/// For each face direction we define which world axes correspond to the
/// "slice" axis (perpendicular to the face), the "u" axis (width), and
/// the "v" axis (height) of the 2D mask.
const AxisMap = struct {
    slice_axis: u2,
    u_axis: u2,
    v_axis: u2,
};

const axis_maps = [6]AxisMap{
    .{ .slice_axis = 2, .u_axis = 0, .v_axis = 1 }, // North (-Z)
    .{ .slice_axis = 2, .u_axis = 0, .v_axis = 1 }, // South (+Z)
    .{ .slice_axis = 0, .u_axis = 2, .v_axis = 1 }, // East  (+X)
    .{ .slice_axis = 0, .u_axis = 2, .v_axis = 1 }, // West  (-X)
    .{ .slice_axis = 1, .u_axis = 0, .v_axis = 2 }, // Top   (+Y)
    .{ .slice_axis = 1, .u_axis = 0, .v_axis = 2 }, // Bottom(-Y)
};

/// Face vertex offsets for merged quads.
/// For each face, 4 corner offsets expressed in (u_offset, v_offset, slice_offset)
/// relative to the quad origin. The u/v offsets are multiplied by the quad dimensions.
/// Winding order is CCW when viewed from outside.
const FaceCorner = struct {
    du: u1, // 0 or 1 (multiply by width)
    dv: u1, // 0 or 1 (multiply by height)
    ds: u1, // 0 or 1 (offset along slice normal)
};

const face_corners = [6][4]FaceCorner{
    // North (-Z): looking at -Z face, face is at z=slice. Corners in u(x), v(y) space.
    // Winding: (1,0),(0,0),(0,1),(1,1) in (x,y) matches mesh_indexed
    .{ .{ .du = 1, .dv = 0, .ds = 0 }, .{ .du = 0, .dv = 0, .ds = 0 }, .{ .du = 0, .dv = 1, .ds = 0 }, .{ .du = 1, .dv = 1, .ds = 0 } },
    // South (+Z): face is at z=slice+1
    .{ .{ .du = 0, .dv = 0, .ds = 1 }, .{ .du = 1, .dv = 0, .ds = 1 }, .{ .du = 1, .dv = 1, .ds = 1 }, .{ .du = 0, .dv = 1, .ds = 1 } },
    // East (+X): u=z, v=y, face at x=slice+1
    .{ .{ .du = 1, .dv = 0, .ds = 1 }, .{ .du = 0, .dv = 0, .ds = 1 }, .{ .du = 0, .dv = 1, .ds = 1 }, .{ .du = 1, .dv = 1, .ds = 1 } },
    // West (-X): u=z, v=y, face at x=slice
    .{ .{ .du = 0, .dv = 0, .ds = 0 }, .{ .du = 1, .dv = 0, .ds = 0 }, .{ .du = 1, .dv = 1, .ds = 0 }, .{ .du = 0, .dv = 1, .ds = 0 } },
    // Top (+Y): u=x, v=z, face at y=slice+1
    .{ .{ .du = 0, .dv = 0, .ds = 1 }, .{ .du = 0, .dv = 1, .ds = 1 }, .{ .du = 1, .dv = 1, .ds = 1 }, .{ .du = 1, .dv = 0, .ds = 1 } },
    // Bottom (-Y): u=x, v=z, face at y=slice
    .{ .{ .du = 0, .dv = 1, .ds = 0 }, .{ .du = 0, .dv = 0, .ds = 0 }, .{ .du = 1, .dv = 0, .ds = 0 }, .{ .du = 1, .dv = 1, .ds = 0 } },
};

fn buildPos(axis_map: AxisMap, u_val: u5, v_val: u5, s_val: u5) [3]u5 {
    var pos: [3]u5 = undefined;
    pos[axis_map.u_axis] = u_val;
    pos[axis_map.v_axis] = v_val;
    pos[axis_map.slice_axis] = s_val;
    return pos;
}

pub fn generateMesh(allocator: std.mem.Allocator, chunk: *const Chunk, neighbors: NeighborChunks) !GreedyMeshData {
    var vertices: std.ArrayList(Vertex) = .empty;
    errdefer vertices.deinit(allocator);

    var indices: std.ArrayList(u32) = .empty;
    errdefer indices.deinit(allocator);

    var mask: [SIZE][SIZE]MaskEntry = undefined;

    for (0..6) |face_idx| {
        const am = axis_maps[face_idx];
        const normal = face_normals[face_idx];

        for (0..SIZE) |slice| {
            // Build the 16x16 mask for this slice and face direction.
            for (0..SIZE) |vi| {
                for (0..SIZE) |ui| {
                    var coords: [3]i32 = undefined;
                    coords[am.u_axis] = @intCast(ui);
                    coords[am.v_axis] = @intCast(vi);
                    coords[am.slice_axis] = @intCast(slice);

                    const bx: u4 = @intCast(coords[0]);
                    const by: u4 = @intCast(coords[1]);
                    const bz: u4 = @intCast(coords[2]);

                    const id = chunk.getBlock(bx, by, bz);
                    if (id == block.AIR) {
                        mask[vi][ui] = MASK_EMPTY;
                        continue;
                    }

                    const nx = coords[0] + normal[0];
                    const ny = coords[1] + normal[1];
                    const nz = coords[2] + normal[2];

                    if (isNeighborSolid(chunk, neighbors, nx, ny, nz)) {
                        mask[vi][ui] = MASK_EMPTY;
                        continue;
                    }

                    const def = block.get(id);
                    mask[vi][ui] = maskEntry(def.tex[face_idx]);
                }
            }

            // Greedy merge the mask.
            for (0..SIZE) |vi| {
                var ui: usize = 0;
                while (ui < SIZE) {
                    const entry = mask[vi][ui];
                    if (entry == MASK_EMPTY) {
                        ui += 1;
                        continue;
                    }

                    // Extend width (u direction).
                    var w: usize = 1;
                    while (ui + w < SIZE and mask[vi][ui + w] == entry) : (w += 1) {}

                    // Extend height (v direction).
                    var h: usize = 1;
                    height_loop: while (vi + h < SIZE) : (h += 1) {
                        for (0..w) |du| {
                            if (mask[vi + h][ui + du] != entry) break :height_loop;
                        }
                    }

                    // Clear merged cells.
                    for (0..h) |dv| {
                        for (0..w) |du| {
                            mask[vi + dv][ui + du] = MASK_EMPTY;
                        }
                    }

                    // Emit quad.
                    const tex: u12 = @intCast(entry - 1); // undo the +1
                    const base: u32 = @intCast(vertices.items.len);
                    const corners = face_corners[face_idx];
                    const s_base: u5 = @intCast(slice);

                    for (0..4) |ci| {
                        const c = corners[ci];
                        const u_val: u5 = @intCast(ui + @as(usize, c.du) * w);
                        const v_val: u5 = @intCast(vi + @as(usize, c.dv) * h);
                        const s_val: u5 = s_base + c.ds;
                        const pos = buildPos(am, u_val, v_val, s_val);

                        try vertices.append(allocator, .{
                            .x = pos[0],
                            .y = pos[1],
                            .z = pos[2],
                            .face = @intCast(face_idx),
                            .corner = @intCast(ci),
                            .tex = tex,
                        });
                    }

                    for (quad_indices) |ci| {
                        try indices.append(allocator, base + ci);
                    }

                    ui += w;
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

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "empty chunk produces no mesh" {
    const chunk = Chunk.init();
    var mesh = try generateMesh(std.testing.allocator, &chunk, .{});
    defer mesh.deinit();
    try std.testing.expectEqual(@as(usize, 0), mesh.vertices.len);
    try std.testing.expectEqual(@as(usize, 0), mesh.indices.len);
}

test "single block produces 24 vertices and 36 indices" {
    var chunk = Chunk.init();
    chunk.setBlock(8, 8, 8, block.STONE);
    var mesh = try generateMesh(std.testing.allocator, &chunk, .{});
    defer mesh.deinit();
    try std.testing.expectEqual(@as(usize, 24), mesh.vertices.len);
    try std.testing.expectEqual(@as(usize, 36), mesh.indices.len);
}

test "flat grass layer: top face produces 1 quad" {
    // Fill the bottom layer (y=0) with grass.
    var chunk = Chunk.init();
    for (0..SIZE) |zi| {
        for (0..SIZE) |xi| {
            chunk.setBlock(@intCast(xi), 0, @intCast(zi), block.GRASS);
        }
    }
    var mesh = try generateMesh(std.testing.allocator, &chunk, .{});
    defer mesh.deinit();

    // Count quads per face direction.
    var face_quads = [_]usize{0} ** 6;
    var i: usize = 0;
    while (i < mesh.vertices.len) : (i += 4) {
        face_quads[@as(usize, mesh.vertices[i].face)] += 1;
    }
    // Top (+Y, face=4): one single merged quad.
    try std.testing.expectEqual(@as(usize, 1), face_quads[4]);
    // Bottom (-Y, face=5): one single merged quad (uniform bottom texture).
    try std.testing.expectEqual(@as(usize, 1), face_quads[5]);
}

test "two different textures side by side are not merged" {
    var chunk = Chunk.init();
    // Stone at (0,0,0), Dirt at (1,0,0)
    chunk.setBlock(0, 0, 0, block.STONE);
    chunk.setBlock(1, 0, 0, block.DIRT);
    var mesh = try generateMesh(std.testing.allocator, &chunk, .{});
    defer mesh.deinit();

    // The top face for stone and dirt have different textures, so they must
    // not be merged. Each block should have its own top quad.
    var top_quads: usize = 0;
    var i: usize = 0;
    while (i < mesh.vertices.len) : (i += 4) {
        if (@as(usize, mesh.vertices[i].face) == 4) top_quads += 1;
    }
    try std.testing.expectEqual(@as(usize, 2), top_quads);
}

test "mixed chunk has fewer vertices than naive mesher" {
    var chunk = Chunk.init();
    // Fill a 4x4x4 region with stone.
    for (0..4) |yi| {
        for (0..4) |zi| {
            for (0..4) |xi| {
                chunk.setBlock(@intCast(xi), @intCast(yi), @intCast(zi), block.STONE);
            }
        }
    }
    var greedy = try generateMesh(std.testing.allocator, &chunk, .{});
    defer greedy.deinit();

    var naive = try mesh_indexed.generateMesh(std.testing.allocator, &chunk);
    defer naive.deinit();

    // Greedy must produce strictly fewer vertices.
    try std.testing.expect(greedy.vertices.len < naive.vertices.len);
    try std.testing.expect(greedy.indices.len < naive.indices.len);
}

test "all indices are valid" {
    var chunk = Chunk.init();
    for (0..4) |yi| {
        for (0..4) |zi| {
            for (0..4) |xi| {
                chunk.setBlock(@intCast(xi), @intCast(yi), @intCast(zi), block.STONE);
            }
        }
    }
    var mesh = try generateMesh(std.testing.allocator, &chunk, .{});
    defer mesh.deinit();
    for (mesh.indices) |idx| {
        try std.testing.expect(idx < mesh.vertices.len);
    }
}

test "vertex positions are within bounds" {
    var chunk = Chunk.init();
    for (0..SIZE) |zi| {
        for (0..SIZE) |xi| {
            chunk.setBlock(@intCast(xi), 0, @intCast(zi), block.STONE);
        }
    }
    var mesh = try generateMesh(std.testing.allocator, &chunk, .{});
    defer mesh.deinit();
    for (mesh.vertices) |v| {
        try std.testing.expect(v.x <= SIZE);
        try std.testing.expect(v.y <= SIZE);
        try std.testing.expect(v.z <= SIZE);
    }
}
