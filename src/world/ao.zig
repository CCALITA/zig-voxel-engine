/// Per-vertex ambient occlusion for voxel faces.
///
/// Minecraft-style AO checks 3 neighbor blocks around each vertex of a face:
/// the 2 edge neighbors and 1 corner (diagonal) neighbor in the plane
/// perpendicular to the face normal. The AO value (0-3) counts how many of
/// those neighbors are solid. A special rule applies: if both edge neighbors
/// are solid the corner is forced to 3 regardless of the diagonal, preventing
/// light leaking through inside corners.
///
/// Vertex format packing note:
///   Current:  x(5) y(5) z(5) face(3) corner(2) tex(12)        = 32 bits
///   With AO:  x(5) y(5) z(5) face(3) corner(2) ao(2) tex(10)  = 32 bits
///   Stealing 2 bits from tex still leaves 1024 texture slots, which is plenty.

const Chunk = @import("chunk.zig");

pub const FaceAO = struct {
    /// AO values for the 4 corners of a face (0 = no occlusion, 3 = max).
    corners: [4]u2,
};

/// For each face and each of its 4 corners, the offsets (relative to the
/// block position offset by the face normal) to the two edge neighbors and
/// one diagonal neighbor.
///
/// Layout: [face][corner] -> .{ edge0[3], edge1[3], diag[3] }
/// where each element is an i32 offset added to (bx + nx, by + ny, bz + nz).
///
/// The offsets are derived from the face vertex positions in mesh.zig.
/// For a vertex at (vx, vy, vz) on a face with tangent axes (t0, t1),
/// the two edge neighbors lie along t0 and t1, and the diagonal lies
/// along t0 + t1, with direction signs determined by the vertex's position
/// within the face quad.
const ao_neighbor_offsets = computeAONeighborOffsets();

/// Packed neighbor offset triple for one corner.
const NeighborOffsets = struct {
    edge0: [3]i32,
    edge1: [3]i32,
    diag: [3]i32,
};

/// Compute the AO neighbor lookup table at comptime from face geometry.
///
/// For each face with normal N:
///   1. Pick two tangent axis indices (the axes where N is zero).
///   2. For each of the 4 corner vertices, determine the sign along each
///      tangent axis: the vertex offset is 0 or 1, so the sign is
///      (2 * offset - 1), giving -1 or +1.
///   3. The edge neighbors are one step along each tangent axis in the
///      vertex's direction; the diagonal is one step along both.
fn computeAONeighborOffsets() [6][4]NeighborOffsets {
    // Face vertex offsets copied from mesh.zig (face_vertices).
    const face_vertices = [6][4][3]u1{
        // North (-Z)
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

    const face_normals = [6][3]i32{
        .{ 0, 0, -1 }, // North
        .{ 0, 0, 1 },  // South
        .{ 1, 0, 0 },  // East
        .{ -1, 0, 0 }, // West
        .{ 0, 1, 0 },  // Top
        .{ 0, -1, 0 }, // Bottom
    };

    // Tangent axis pairs for each face. These are the two coordinate
    // indices where the face normal is zero.
    const tangent_axes = [6][2]usize{
        .{ 0, 1 }, // North  (normal along Z) -> tangents X, Y
        .{ 0, 1 }, // South  (normal along Z) -> tangents X, Y
        .{ 2, 1 }, // East   (normal along X) -> tangents Z, Y
        .{ 2, 1 }, // West   (normal along X) -> tangents Z, Y
        .{ 0, 2 }, // Top    (normal along Y) -> tangents X, Z
        .{ 0, 2 }, // Bottom (normal along Y) -> tangents X, Z
    };

    var result: [6][4]NeighborOffsets = undefined;

    for (0..6) |face| {
        const t0_axis = tangent_axes[face][0];
        const t1_axis = tangent_axes[face][1];
        const n = face_normals[face];

        for (0..4) |corner| {
            const v = face_vertices[face][corner];

            // Direction along each tangent: vertex offset is 0 or 1,
            // map to -1 or +1.
            const s0: i32 = @as(i32, v[t0_axis]) * 2 - 1;
            const s1: i32 = @as(i32, v[t1_axis]) * 2 - 1;

            // Build the three offset vectors.
            // All are relative to the block position (not the face center),
            // so include the face normal to sample in the neighbor plane.
            var e0 = [3]i32{ n[0], n[1], n[2] };
            e0[t0_axis] += s0;

            var e1 = [3]i32{ n[0], n[1], n[2] };
            e1[t1_axis] += s1;

            var d = [3]i32{ n[0], n[1], n[2] };
            d[t0_axis] += s0;
            d[t1_axis] += s1;

            result[face][corner] = .{
                .edge0 = e0,
                .edge1 = e1,
                .diag = d,
            };
        }
    }

    return result;
}

/// Compute AO for a single face of a block at the given position.
/// `bx`, `by`, `bz` are signed to allow the caller to pass any coordinates;
/// `chunk.isNeighborSolid` already handles out-of-bounds gracefully.
pub fn computeFaceAO(chunk: *const Chunk, bx: i32, by: i32, bz: i32, face: u3) FaceAO {
    var result: FaceAO = .{ .corners = .{ 0, 0, 0, 0 } };

    for (0..4) |corner| {
        const offsets = ao_neighbor_offsets[face][corner];

        const side0: u2 = if (chunk.isNeighborSolid(
            bx + offsets.edge0[0],
            by + offsets.edge0[1],
            bz + offsets.edge0[2],
        )) 1 else 0;

        const side1: u2 = if (chunk.isNeighborSolid(
            bx + offsets.edge1[0],
            by + offsets.edge1[1],
            bz + offsets.edge1[2],
        )) 1 else 0;

        // If both edges are solid, AO = 3 regardless of diagonal.
        if (side0 == 1 and side1 == 1) {
            result.corners[corner] = 3;
        } else {
            const diag: u2 = if (chunk.isNeighborSolid(
                bx + offsets.diag[0],
                by + offsets.diag[1],
                bz + offsets.diag[2],
            )) 1 else 0;
            result.corners[corner] = side0 + side1 + diag;
        }
    }

    return result;
}

/// Compute AO for all 6 faces of a block.
pub fn computeBlockAO(chunk: *const Chunk, bx: u4, by: u4, bz: u4) [6]FaceAO {
    var result: [6]FaceAO = undefined;
    for (0..6) |face| {
        result[face] = computeFaceAO(chunk, @as(i32, bx), @as(i32, by), @as(i32, bz), @intCast(face));
    }
    return result;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

const std = @import("std");

test "block surrounded by air has all AO corners zero" {
    const block = @import("block.zig");
    var chunk = Chunk.init();
    chunk.setBlock(8, 8, 8, block.STONE);

    const ao = computeBlockAO(&chunk, 8, 8, 8);
    for (0..6) |face| {
        for (0..4) |corner| {
            try std.testing.expectEqual(@as(u2, 0), ao[face].corners[corner]);
        }
    }
}

test "single solid neighbor affects only adjacent face corners" {
    const block = @import("block.zig");
    var chunk = Chunk.init();
    // Place target block at (8,8,8) and one neighbor above-east at (9,9,8).
    chunk.setBlock(8, 8, 8, block.STONE);
    chunk.setBlock(9, 9, 8, block.STONE);

    const ao = computeBlockAO(&chunk, 8, 8, 8);

    // The top face (+Y, face 4) should have some corners affected.
    // Vertex offsets for Top face (from face_vertices):
    //   corner 0: (0,1,0)  corner 1: (0,1,1)  corner 2: (1,1,1)  corner 3: (1,1,0)
    // The neighbor at (9,9,8) is in the +X direction from the top face.
    // For the top face, tangent axes are X and Z.
    // Corner 3 has vertex (1,1,0), so s_x = +1, s_z = -1.
    //   edge0 offset along X: normal (0,1,0) + (+1,0,0) = (1,1,0) -> checks (9,9,8) = solid
    //   edge1 offset along Z: normal (0,1,0) + (0,0,-1) = (0,1,-1) -> checks (8,9,7) = air
    //   So corner 3 AO = 1.
    try std.testing.expectEqual(@as(u2, 1), ao[4].corners[3]);

    // Corner 2 has vertex (1,1,1), so s_x = +1, s_z = +1.
    //   edge0 along X: (1,1,0) -> checks (9,9,8) = solid
    //   edge1 along Z: (0,1,1) -> checks (8,9,9) = air
    //   So corner 2 AO = 1.
    try std.testing.expectEqual(@as(u2, 1), ao[4].corners[2]);

    // Corners 0 and 1 have s_x = -1, so their edge0 checks (7,9,8) = air.
    try std.testing.expectEqual(@as(u2, 0), ao[4].corners[0]);
    try std.testing.expectEqual(@as(u2, 0), ao[4].corners[1]);
}

test "concave corner: vertex surrounded by 3 solid neighbors has AO 3" {
    const block = @import("block.zig");
    var chunk = Chunk.init();
    chunk.setBlock(8, 8, 8, block.STONE);

    // Top face, corner 3: vertex at (1,1,0) relative to block, i.e. world (9,9,8).
    // Tangent axes for top face: X and Z.  Corner 3: s_x = +1, s_z = -1.
    //   edge0: (bx+1, by+1, bz)   = (9, 9, 8)
    //   edge1: (bx,   by+1, bz-1) = (8, 9, 7)
    //   diag:  (bx+1, by+1, bz-1) = (9, 9, 7)
    chunk.setBlock(9, 9, 8, block.STONE); // edge0
    chunk.setBlock(8, 9, 7, block.STONE); // edge1
    chunk.setBlock(9, 9, 7, block.STONE); // diagonal

    const ao = computeBlockAO(&chunk, 8, 8, 8);
    try std.testing.expectEqual(@as(u2, 3), ao[4].corners[3]);
}

test "both edge neighbors solid forces AO 3 even if diagonal is air" {
    const block = @import("block.zig");
    var chunk = Chunk.init();
    chunk.setBlock(8, 8, 8, block.STONE);

    // Top face, corner 3 again.
    chunk.setBlock(9, 9, 8, block.STONE); // edge0
    chunk.setBlock(8, 9, 7, block.STONE); // edge1
    // Diagonal (9, 9, 7) is AIR.

    const ao = computeBlockAO(&chunk, 8, 8, 8);
    try std.testing.expectEqual(@as(u2, 3), ao[4].corners[3]);
}

test "chunk edge block has zero AO (out of bounds treated as air)" {
    const block = @import("block.zig");
    var chunk = Chunk.init();
    chunk.setBlock(0, 0, 0, block.STONE);

    const ao = computeBlockAO(&chunk, 0, 0, 0);
    for (0..6) |face| {
        for (0..4) |corner| {
            try std.testing.expectEqual(@as(u2, 0), ao[face].corners[corner]);
        }
    }
}

test "computeFaceAO matches computeBlockAO for each face" {
    const block = @import("block.zig");
    var chunk = Chunk.init();
    chunk.setBlock(8, 8, 8, block.STONE);
    chunk.setBlock(9, 9, 8, block.STONE);
    chunk.setBlock(8, 9, 7, block.STONE);

    const block_ao = computeBlockAO(&chunk, 8, 8, 8);
    for (0..6) |face| {
        const face_ao = computeFaceAO(&chunk, 8, 8, 8, @intCast(face));
        for (0..4) |corner| {
            try std.testing.expectEqual(block_ao[face].corners[corner], face_ao.corners[corner]);
        }
    }
}
