/// Door mesh generator.
///
/// A door is a thin slab 3/16 of a block thick. It has:
///   - 4 facing directions (north, east, south, west)
///   - open/closed states (open = rotated 90 degrees around the hinge edge)
///   - hinge on the left or right side
///   - upper or lower half (geometry is identical; flag preserved for callers)
///
/// Vertex format (two u32 attributes, packed using 1/16-block precision):
///   pos_data: x_q16(9) y_q16(9) z_q16(9) face(3) corner(2) = 32 bits
///   tex_data: tex(12) light(4) reserved(16) = 32 bits
const std = @import("std");

pub const Vertex = extern struct {
    pos_data: u32,
    tex_data: u32,
};

pub const DoorState = struct {
    facing: enum(u2) { north, east, south, west },
    is_open: bool,
    hinge_right: bool,
    is_top_half: bool,
};

pub const DoorMesh = struct {
    vertices: [24]Vertex,
    indices: [36]u32,
    vertex_count: u32,
    index_count: u32,
};

/// Door panel thickness in 1/16-block units.
pub const DOOR_THICKNESS: u8 = 3;

/// Axis-aligned bounding box in 1/16-block units (0..16 inclusive).
const AABB = struct {
    x0: u8,
    x1: u8,
    y0: u8,
    y1: u8,
    z0: u8,
    z1: u8,
};

/// Compute the door panel AABB inside a single block, in 1/16ths.
///
/// Closed: the panel sits flush against the face indicated by `facing`.
/// Open:   the panel is rotated 90 degrees around the vertical hinge edge,
///         landing flush against an adjacent face.
fn doorAABB(state: DoorState) AABB {
    const t = DOOR_THICKNESS;

    if (!state.is_open) {
        return switch (state.facing) {
            .north => slabZ(0, t),
            .south => slabZ(16 - t, 16),
            .east => slabX(16 - t, 16),
            .west => slabX(0, t),
        };
    }

    // Open: 90 degree rotation around the hinge edge. The hinge edge is the
    // vertical edge of the closed panel on the side specified by hinge_right
    // (right when looking at the closed door from outside, i.e. from `facing`).
    return switch (state.facing) {
        .north => if (state.hinge_right) slabX(16 - t, 16) else slabX(0, t),
        .south => if (state.hinge_right) slabX(0, t) else slabX(16 - t, 16),
        .east => if (state.hinge_right) slabZ(16 - t, 16) else slabZ(0, t),
        .west => if (state.hinge_right) slabZ(0, t) else slabZ(16 - t, 16),
    };
}

/// Full-height panel thin along X (full Z range).
fn slabX(x0: u8, x1: u8) AABB {
    return .{ .x0 = x0, .x1 = x1, .y0 = 0, .y1 = 16, .z0 = 0, .z1 = 16 };
}

/// Full-height panel thin along Z (full X range).
fn slabZ(z0: u8, z1: u8) AABB {
    return .{ .x0 = 0, .x1 = 16, .y0 = 0, .y1 = 16, .z0 = z0, .z1 = z1 };
}

/// Pack a vertex. Position is given in 1/16-block units within the chunk.
pub fn makeVertex(x_q16: u9, y_q16: u9, z_q16: u9, face: u3, corner: u2, light: u4, tex: u16) Vertex {
    const pos: u32 = @as(u32, x_q16) |
        (@as(u32, y_q16) << 9) |
        (@as(u32, z_q16) << 18) |
        (@as(u32, face) << 27) |
        (@as(u32, corner) << 30);
    const td: u32 = (@as(u32, tex) & 0xFFF) | (@as(u32, light) << 12);
    return .{ .pos_data = pos, .tex_data = td };
}

// 4 corners per face, ordered CCW when viewed from outside.
// Each corner picks (x0|x1, y0|y1, z0|z1) of the AABB.
const face_corners = [6][4][3]u1{
    .{ .{ 1, 0, 0 }, .{ 0, 0, 0 }, .{ 0, 1, 0 }, .{ 1, 1, 0 } }, // -Z (face 0)
    .{ .{ 0, 0, 1 }, .{ 1, 0, 1 }, .{ 1, 1, 1 }, .{ 0, 1, 1 } }, // +Z (face 1)
    .{ .{ 1, 0, 1 }, .{ 1, 0, 0 }, .{ 1, 1, 0 }, .{ 1, 1, 1 } }, // +X (face 2)
    .{ .{ 0, 0, 0 }, .{ 0, 0, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 0 } }, // -X (face 3)
    .{ .{ 0, 1, 0 }, .{ 0, 1, 1 }, .{ 1, 1, 1 }, .{ 1, 1, 0 } }, // +Y (face 4)
    .{ .{ 0, 0, 1 }, .{ 0, 0, 0 }, .{ 1, 0, 0 }, .{ 1, 0, 1 } }, // -Y (face 5)
};

const quad_indices = [6]u2{ 0, 1, 2, 2, 3, 0 };

/// Generate a door mesh for the block at (bx, by, bz) inside a chunk.
/// All 6 faces of the panel are emitted (no neighbor culling here — callers
/// handle culling at the chunk level if desired).
pub fn generateDoor(bx: u5, by: u5, bz: u5, tex: u16, light: u4, state: DoorState) DoorMesh {
    const aabb = doorAABB(state);

    const base_x: u16 = @as(u16, bx) * 16;
    const base_y: u16 = @as(u16, by) * 16;
    const base_z: u16 = @as(u16, bz) * 16;

    var mesh: DoorMesh = .{
        .vertices = undefined,
        .indices = undefined,
        .vertex_count = 0,
        .index_count = 0,
    };

    var v_idx: u32 = 0;
    var i_idx: u32 = 0;

    for (face_corners, 0..) |corners, face_idx| {
        const base: u32 = v_idx;
        for (corners, 0..) |c, ci| {
            const sx: u8 = if (c[0] == 0) aabb.x0 else aabb.x1;
            const sy: u8 = if (c[1] == 0) aabb.y0 else aabb.y1;
            const sz: u8 = if (c[2] == 0) aabb.z0 else aabb.z1;
            mesh.vertices[v_idx] = makeVertex(
                @intCast(base_x + sx),
                @intCast(base_y + sy),
                @intCast(base_z + sz),
                @intCast(face_idx),
                @intCast(ci),
                light,
                tex,
            );
            v_idx += 1;
        }
        for (quad_indices) |qi| {
            mesh.indices[i_idx] = base + qi;
            i_idx += 1;
        }
    }

    mesh.vertex_count = v_idx;
    mesh.index_count = i_idx;
    return mesh;
}

// -----------------------------------------------------------------------------
// Tests
// -----------------------------------------------------------------------------

const testing = std.testing;

fn defaultState() DoorState {
    return .{ .facing = .north, .is_open = false, .hinge_right = false, .is_top_half = false };
}

test "generateDoor produces 24 vertices and 36 indices" {
    const mesh = generateDoor(0, 0, 0, 100, 15, defaultState());
    try testing.expectEqual(@as(u32, 24), mesh.vertex_count);
    try testing.expectEqual(@as(u32, 36), mesh.index_count);
}

test "all indices reference valid vertices" {
    const mesh = generateDoor(1, 2, 3, 100, 15, defaultState());
    for (mesh.indices) |idx| {
        try testing.expect(idx < mesh.vertex_count);
    }
}

test "closed door facing north is a thin slab against -Z face" {
    const aabb = doorAABB(.{ .facing = .north, .is_open = false, .hinge_right = false, .is_top_half = false });
    try testing.expectEqual(@as(u8, 0), aabb.z0);
    try testing.expectEqual(DOOR_THICKNESS, aabb.z1);
    try testing.expectEqual(@as(u8, 0), aabb.x0);
    try testing.expectEqual(@as(u8, 16), aabb.x1);
    try testing.expectEqual(@as(u8, 16), aabb.y1);
}

test "closed door facing east is a thin slab against +X face" {
    const aabb = doorAABB(.{ .facing = .east, .is_open = false, .hinge_right = false, .is_top_half = false });
    try testing.expectEqual(@as(u8, 16 - DOOR_THICKNESS), aabb.x0);
    try testing.expectEqual(@as(u8, 16), aabb.x1);
}

test "open door rotates 90 degrees onto adjacent face" {
    // facing north + hinge_right: open panel sits along +X face.
    const open = doorAABB(.{ .facing = .north, .is_open = true, .hinge_right = true, .is_top_half = false });
    try testing.expectEqual(@as(u8, 16 - DOOR_THICKNESS), open.x0);
    try testing.expectEqual(@as(u8, 16), open.x1);
    try testing.expectEqual(@as(u8, 0), open.z0);
    try testing.expectEqual(@as(u8, 16), open.z1);

    // facing north + hinge_left: open panel sits along -X face.
    const open_left = doorAABB(.{ .facing = .north, .is_open = true, .hinge_right = false, .is_top_half = false });
    try testing.expectEqual(@as(u8, 0), open_left.x0);
    try testing.expectEqual(DOOR_THICKNESS, open_left.x1);
}

test "all four facings produce a 3/16-thick slab when closed" {
    const facings = [_]@TypeOf(defaultState().facing){ .north, .east, .south, .west };
    for (facings) |f| {
        const aabb = doorAABB(.{ .facing = f, .is_open = false, .hinge_right = false, .is_top_half = false });
        const dx: u8 = aabb.x1 - aabb.x0;
        const dy: u8 = aabb.y1 - aabb.y0;
        const dz: u8 = aabb.z1 - aabb.z0;
        try testing.expectEqual(@as(u8, 16), dy);
        // exactly one of dx/dz is the thickness, the other is 16.
        const thin_x = dx == DOOR_THICKNESS and dz == 16;
        const thin_z = dz == DOOR_THICKNESS and dx == 16;
        try testing.expect(thin_x or thin_z);
    }
}

test "makeVertex packs and unpacks position, face, light, tex" {
    const v = makeVertex(7, 100, 256, 4, 2, 15, 0xABC);
    try testing.expectEqual(@as(u32, 7), v.pos_data & 0x1FF);
    try testing.expectEqual(@as(u32, 100), (v.pos_data >> 9) & 0x1FF);
    try testing.expectEqual(@as(u32, 256), (v.pos_data >> 18) & 0x1FF);
    try testing.expectEqual(@as(u32, 4), (v.pos_data >> 27) & 0x7);
    try testing.expectEqual(@as(u32, 2), (v.pos_data >> 30) & 0x3);
    try testing.expectEqual(@as(u32, 0xABC), v.tex_data & 0xFFF);
    try testing.expectEqual(@as(u32, 15), (v.tex_data >> 12) & 0xF);
}

test "vertex positions are translated by block coordinates" {
    const mesh = generateDoor(2, 0, 0, 0, 0, defaultState());
    // Block (2,0,0) starts at x_q16 = 32. Closed-north door has x range [0,16],
    // so x_q16 should be either 32 or 48.
    for (mesh.vertices[0..mesh.vertex_count]) |v| {
        const x_q16 = v.pos_data & 0x1FF;
        try testing.expect(x_q16 == 32 or x_q16 == 48);
    }
}

test "is_top_half does not change geometry" {
    const bottom = generateDoor(0, 0, 0, 5, 10, .{ .facing = .south, .is_open = true, .hinge_right = true, .is_top_half = false });
    const top = generateDoor(0, 0, 0, 5, 10, .{ .facing = .south, .is_open = true, .hinge_right = true, .is_top_half = true });
    for (0..bottom.vertex_count) |i| {
        try testing.expectEqual(bottom.vertices[i].pos_data, top.vertices[i].pos_data);
        try testing.expectEqual(bottom.vertices[i].tex_data, top.vertices[i].tex_data);
    }
}
