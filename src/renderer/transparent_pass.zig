/// Depth-sorted transparent face collection for water, glass, ice, and leaves.
/// Collects visible transparent quads from a chunk and sorts them back-to-front
/// relative to the camera for correct alpha-blended rendering.
const std = @import("std");
const block = @import("block");
const Chunk = @import("chunk");

pub const TransparentQuad = struct {
    x: f32,
    y: f32,
    z: f32,
    face: u3,
    tex: u6,
    alpha: f32,
    dist_sq: f32,
};

pub const TransparentMesh = struct {
    quads: []TransparentQuad,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *TransparentMesh) void {
        self.allocator.free(self.quads);
    }
};

/// Check if a block should use transparent rendering.
pub fn isTransparentBlock(block_id: u8) bool {
    return switch (block_id) {
        block.WATER, block.GLASS, block.ICE, block.OAK_LEAVES => true,
        else => false,
    };
}

/// Get alpha value for a transparent block.
pub fn getAlpha(block_id: u8) f32 {
    return switch (block_id) {
        block.WATER => 0.6,
        block.GLASS => 0.3,
        block.ICE => 0.8,
        block.OAK_LEAVES => 0.9,
        else => 1.0,
    };
}

/// Order matches block.Face: north(-Z), south(+Z), east(+X), west(-X), top(+Y), bottom(-Y).
const face_normals = [6][3]i32{
    .{ 0, 0, -1 },
    .{ 0, 0, 1 },
    .{ 1, 0, 0 },
    .{ -1, 0, 0 },
    .{ 0, 1, 0 },
    .{ 0, -1, 0 },
};

/// A face is emitted only between a transparent block and a non-transparent neighbor.
fn shouldEmitFace(chunk: *const Chunk, bx: i32, by: i32, bz: i32, face: u3) bool {
    const normal = face_normals[face];
    const nx = bx + normal[0];
    const ny = by + normal[1];
    const nz = bz + normal[2];

    if (nx < 0 or nx >= Chunk.SIZE or ny < 0 or ny >= Chunk.SIZE or nz < 0 or nz >= Chunk.SIZE) {
        return true;
    }

    const neighbor_id = chunk.getBlock(@intCast(nx), @intCast(ny), @intCast(nz));
    return !isTransparentBlock(neighbor_id);
}

/// Collect transparent faces from a chunk, sorted back-to-front relative to camera.
pub fn collectTransparent(
    allocator: std.mem.Allocator,
    chunk: *const Chunk,
    chunk_wx: i32,
    chunk_wy: i32,
    chunk_wz: i32,
    cam_x: f32,
    cam_y: f32,
    cam_z: f32,
) !TransparentMesh {
    var list: std.ArrayList(TransparentQuad) = .empty;
    errdefer list.deinit(allocator);

    for (0..Chunk.SIZE) |yi| {
        for (0..Chunk.SIZE) |zi| {
            for (0..Chunk.SIZE) |xi| {
                const bx: u4 = @intCast(xi);
                const by: u4 = @intCast(yi);
                const bz: u4 = @intCast(zi);

                const bid = chunk.getBlock(bx, by, bz);
                if (!isTransparentBlock(bid)) continue;

                const wx = @as(f32, @floatFromInt(chunk_wx)) + @as(f32, @floatFromInt(bx)) + 0.5;
                const wy = @as(f32, @floatFromInt(chunk_wy)) + @as(f32, @floatFromInt(by)) + 0.5;
                const wz = @as(f32, @floatFromInt(chunk_wz)) + @as(f32, @floatFromInt(bz)) + 0.5;
                const dx = wx - cam_x;
                const dy = wy - cam_y;
                const dz = wz - cam_z;
                const dist_sq = dx * dx + dy * dy + dz * dz;

                const def = block.get(bid);
                const alpha = getAlpha(bid);

                for (0..6) |face_idx| {
                    const face: u3 = @intCast(face_idx);
                    if (shouldEmitFace(chunk, @as(i32, bx), @as(i32, by), @as(i32, bz), face)) {
                        try list.append(allocator, .{
                            .x = wx,
                            .y = wy,
                            .z = wz,
                            .face = face,
                            .tex = @intCast(def.tex[face_idx]),
                            .alpha = alpha,
                            .dist_sq = dist_sq,
                        });
                    }
                }
            }
        }
    }

    // Insertion sort descending by dist_sq (back-to-front for alpha blending).
    const quads = try list.toOwnedSlice(allocator);
    if (quads.len > 1) {
        for (1..quads.len) |i| {
            const key = quads[i];
            var j: usize = i;
            while (j > 0 and quads[j - 1].dist_sq < key.dist_sq) {
                quads[j] = quads[j - 1];
                j -= 1;
            }
            quads[j] = key;
        }
    }

    return .{
        .quads = quads,
        .allocator = allocator,
    };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "water block produces transparent quads" {
    var chunk = Chunk.init();
    chunk.setBlock(8, 8, 8, block.WATER);

    var mesh = try collectTransparent(std.testing.allocator, &chunk, 0, 0, 0, 0.0, 0.0, 0.0);
    defer mesh.deinit();

    try std.testing.expectEqual(@as(usize, 6), mesh.quads.len);

    for (mesh.quads) |q| {
        try std.testing.expectApproxEqAbs(@as(f32, 0.6), q.alpha, 0.001);
    }
}

test "glass has lower alpha than water" {
    try std.testing.expect(getAlpha(block.GLASS) < getAlpha(block.WATER));
}

test "quads sorted by distance descending (back-to-front)" {
    var chunk = Chunk.init();
    chunk.setBlock(1, 0, 0, block.WATER);
    chunk.setBlock(14, 0, 0, block.WATER);

    var mesh = try collectTransparent(std.testing.allocator, &chunk, 0, 0, 0, 0.0, 0.0, 0.0);
    defer mesh.deinit();

    try std.testing.expect(mesh.quads.len > 0);
    for (1..mesh.quads.len) |i| {
        try std.testing.expect(mesh.quads[i - 1].dist_sq >= mesh.quads[i].dist_sq);
    }
}

test "opaque blocks produce no quads" {
    var chunk = Chunk.init();
    chunk.setBlock(5, 5, 5, block.STONE);
    chunk.setBlock(10, 10, 10, block.DIRT);

    var mesh = try collectTransparent(std.testing.allocator, &chunk, 0, 0, 0, 0.0, 0.0, 0.0);
    defer mesh.deinit();

    try std.testing.expectEqual(@as(usize, 0), mesh.quads.len);
}

test "isTransparentBlock returns true for water glass ice leaves" {
    try std.testing.expect(isTransparentBlock(block.WATER));
    try std.testing.expect(isTransparentBlock(block.GLASS));
    try std.testing.expect(isTransparentBlock(block.ICE));
    try std.testing.expect(isTransparentBlock(block.OAK_LEAVES));
}

test "isTransparentBlock returns false for opaque blocks" {
    try std.testing.expect(!isTransparentBlock(block.STONE));
    try std.testing.expect(!isTransparentBlock(block.DIRT));
    try std.testing.expect(!isTransparentBlock(block.AIR));
}

test "getAlpha returns correct values" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.6), getAlpha(block.WATER), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.3), getAlpha(block.GLASS), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.8), getAlpha(block.ICE), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.9), getAlpha(block.OAK_LEAVES), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), getAlpha(block.STONE), 0.001);
}

test "adjacent transparent blocks suppress shared face" {
    var chunk = Chunk.init();
    chunk.setBlock(5, 5, 5, block.WATER);
    chunk.setBlock(6, 5, 5, block.WATER);

    var mesh = try collectTransparent(std.testing.allocator, &chunk, 0, 0, 0, 0.0, 0.0, 0.0);
    defer mesh.deinit();

    // Two isolated blocks = 12 faces, minus 2 shared internal faces = 10.
    try std.testing.expectEqual(@as(usize, 10), mesh.quads.len);
}

test "empty chunk produces no quads" {
    const chunk = Chunk.init();

    var mesh = try collectTransparent(std.testing.allocator, &chunk, 0, 0, 0, 0.0, 0.0, 0.0);
    defer mesh.deinit();

    try std.testing.expectEqual(@as(usize, 0), mesh.quads.len);
}

