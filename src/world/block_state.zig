/// Block state system using a packed u32 representation.
/// Encodes block ID and properties (facing, powered, waterlogged, etc.)
/// into a single 32-bit value for compact storage.

const std = @import("std");

pub const Facing = enum(u3) {
    none = 0,
    north = 1,
    south = 2,
    east = 3,
    west = 4,
    up = 5,
    down = 6,
};

pub const BlockState = packed struct(u32) {
    block_id: u12 = 0,
    facing: u3 = 0,
    powered: u1 = 0,
    waterlogged: u1 = 0,
    half: u1 = 0,
    open: u1 = 0,
    lit: u1 = 0,
    age: u4 = 0,
    level: u4 = 0,
    axis: u2 = 0,
    variant: u2 = 0,
};

pub const BlockStateBuilder = struct {
    state: BlockState,

    pub fn init(block_id: u12) BlockStateBuilder {
        return .{ .state = .{ .block_id = block_id } };
    }

    pub fn withFacing(self: BlockStateBuilder, f: Facing) BlockStateBuilder {
        var s = self;
        s.state.facing = @intFromEnum(f);
        return s;
    }

    pub fn withPowered(self: BlockStateBuilder, v: bool) BlockStateBuilder {
        var s = self;
        s.state.powered = @intFromBool(v);
        return s;
    }

    pub fn withWaterlogged(self: BlockStateBuilder, v: bool) BlockStateBuilder {
        var s = self;
        s.state.waterlogged = @intFromBool(v);
        return s;
    }

    pub fn withHalf(self: BlockStateBuilder, v: u1) BlockStateBuilder {
        var s = self;
        s.state.half = v;
        return s;
    }

    pub fn withOpen(self: BlockStateBuilder, v: bool) BlockStateBuilder {
        var s = self;
        s.state.open = @intFromBool(v);
        return s;
    }

    pub fn withLit(self: BlockStateBuilder, v: bool) BlockStateBuilder {
        var s = self;
        s.state.lit = @intFromBool(v);
        return s;
    }

    pub fn withAge(self: BlockStateBuilder, v: u4) BlockStateBuilder {
        var s = self;
        s.state.age = v;
        return s;
    }

    pub fn withLevel(self: BlockStateBuilder, v: u4) BlockStateBuilder {
        var s = self;
        s.state.level = v;
        return s;
    }

    pub fn withAxis(self: BlockStateBuilder, v: u2) BlockStateBuilder {
        var s = self;
        s.state.axis = v;
        return s;
    }

    pub fn build(self: BlockStateBuilder) BlockState {
        return self.state;
    }
};

// --- Helper functions ---

pub fn getBlockId(state: BlockState) u12 {
    return state.block_id;
}

pub fn getFacing(state: BlockState) Facing {
    return @enumFromInt(state.facing);
}

pub fn isPowered(state: BlockState) bool {
    return state.powered != 0;
}

pub fn isWaterlogged(state: BlockState) bool {
    return state.waterlogged != 0;
}

pub fn isOpen(state: BlockState) bool {
    return state.open != 0;
}

pub fn isLit(state: BlockState) bool {
    return state.lit != 0;
}

pub fn getAge(state: BlockState) u4 {
    return state.age;
}

pub fn getLevel(state: BlockState) u4 {
    return state.level;
}

fn withRemappedFacing(state: BlockState, new_facing: Facing) BlockState {
    var result = state;
    result.facing = @intFromEnum(new_facing);
    return result;
}

/// Rotate facing clockwise: north -> east -> south -> west -> north.
/// Non-horizontal facings (none, up, down) are unchanged.
pub fn rotateCW(state: BlockState) BlockState {
    return withRemappedFacing(state, switch (getFacing(state)) {
        .north => .east,
        .east => .south,
        .south => .west,
        .west => .north,
        else => |f| f,
    });
}

/// Rotate facing counter-clockwise: north -> west -> south -> east -> north.
pub fn rotateCCW(state: BlockState) BlockState {
    return withRemappedFacing(state, switch (getFacing(state)) {
        .north => .west,
        .west => .south,
        .south => .east,
        .east => .north,
        else => |f| f,
    });
}

/// Mirror east <-> west. Other facings unchanged.
pub fn mirror(state: BlockState) BlockState {
    return withRemappedFacing(state, switch (getFacing(state)) {
        .east => .west,
        .west => .east,
        else => |f| f,
    });
}

/// Returns true if the given block ID requires state tracking
/// (doors, stairs, slabs, logs, crops, fluids, redstone components).
pub fn needsState(block_id: u12) bool {
    return switch (block_id) {
        // Doors and trapdoors
        40, 44 => true,
        // Logs (oak)
        8 => true,
        // Crops
        65, 66, 67 => true,
        // Fluids
        10, 32 => true,
        // Redstone components
        33, 34, 35, 38 => true,
        // Pistons
        37, 51, 52, 53 => true,
        // Furnace (lit state)
        39 => true,
        // Wood variant blocks: stairs (shape=2), slabs (shape=3),
        // logs (shape=1), doors (shape=6), trapdoors (shape=7)
        // IDs 111-170 cover all wood variants (6 types x 9 shapes)
        // and stone variants. Check specific shape offsets.
        111...170 => blk: {
            const offset = block_id - 111;
            if (offset < 54) {
                // Wood variant: shape = offset % 9
                const shape = offset % 9;
                // log=1, stairs=2, slab=3, fence_gate=5, door=6, trapdoor=7
                break :blk (shape == 1 or shape == 2 or shape == 3 or
                    shape == 5 or shape == 6 or shape == 7);
            }
            break :blk false;
        },
        else => false,
    };
}

// --- Tests ---

test "builder packs correctly" {
    const state = BlockStateBuilder.init(42)
        .withFacing(.south)
        .withPowered(true)
        .withAge(7)
        .build();
    try std.testing.expectEqual(@as(u12, 42), state.block_id);
    try std.testing.expectEqual(@as(u3, @intFromEnum(Facing.south)), state.facing);
    try std.testing.expectEqual(@as(u1, 1), state.powered);
    try std.testing.expectEqual(@as(u4, 7), state.age);
}

test "extract block id" {
    const state = BlockStateBuilder.init(2048).build();
    try std.testing.expectEqual(@as(u12, 2048), getBlockId(state));
}

test "extract facing" {
    const state = BlockStateBuilder.init(1).withFacing(.west).build();
    try std.testing.expectEqual(Facing.west, getFacing(state));
}

test "powered flag" {
    const off = BlockStateBuilder.init(34).build();
    const on = BlockStateBuilder.init(34).withPowered(true).build();
    try std.testing.expect(!isPowered(off));
    try std.testing.expect(isPowered(on));
}

test "waterlogged flag" {
    const dry = BlockStateBuilder.init(5).build();
    const wet = BlockStateBuilder.init(5).withWaterlogged(true).build();
    try std.testing.expect(!isWaterlogged(dry));
    try std.testing.expect(isWaterlogged(wet));
}

test "open flag" {
    const state = BlockStateBuilder.init(40).withOpen(true).build();
    try std.testing.expect(isOpen(state));
}

test "lit flag" {
    const state = BlockStateBuilder.init(39).withLit(true).build();
    try std.testing.expect(isLit(state));
}

test "age progression" {
    const s0 = BlockStateBuilder.init(65).withAge(0).build();
    const s7 = BlockStateBuilder.init(65).withAge(7).build();
    const s15 = BlockStateBuilder.init(65).withAge(15).build();
    try std.testing.expectEqual(@as(u4, 0), getAge(s0));
    try std.testing.expectEqual(@as(u4, 7), getAge(s7));
    try std.testing.expectEqual(@as(u4, 15), getAge(s15));
}

test "level values" {
    const s0 = BlockStateBuilder.init(10).withLevel(0).build();
    const s8 = BlockStateBuilder.init(10).withLevel(8).build();
    const s15 = BlockStateBuilder.init(10).withLevel(15).build();
    try std.testing.expectEqual(@as(u4, 0), getLevel(s0));
    try std.testing.expectEqual(@as(u4, 8), getLevel(s8));
    try std.testing.expectEqual(@as(u4, 15), getLevel(s15));
}

test "rotation clockwise" {
    const north = BlockStateBuilder.init(40).withFacing(.north).build();
    const east = rotateCW(north);
    const south = rotateCW(east);
    const west = rotateCW(south);
    const back = rotateCW(west);
    try std.testing.expectEqual(Facing.east, getFacing(east));
    try std.testing.expectEqual(Facing.south, getFacing(south));
    try std.testing.expectEqual(Facing.west, getFacing(west));
    try std.testing.expectEqual(Facing.north, getFacing(back));
}

test "rotation counter-clockwise" {
    const north = BlockStateBuilder.init(40).withFacing(.north).build();
    const west = rotateCCW(north);
    const south = rotateCCW(west);
    const east = rotateCCW(south);
    const back = rotateCCW(east);
    try std.testing.expectEqual(Facing.west, getFacing(west));
    try std.testing.expectEqual(Facing.south, getFacing(south));
    try std.testing.expectEqual(Facing.east, getFacing(east));
    try std.testing.expectEqual(Facing.north, getFacing(back));
}

test "mirror east west" {
    const east_state = BlockStateBuilder.init(1).withFacing(.east).build();
    const west_state = BlockStateBuilder.init(1).withFacing(.west).build();
    const north_state = BlockStateBuilder.init(1).withFacing(.north).build();
    try std.testing.expectEqual(Facing.west, getFacing(mirror(east_state)));
    try std.testing.expectEqual(Facing.east, getFacing(mirror(west_state)));
    try std.testing.expectEqual(Facing.north, getFacing(mirror(north_state)));
}

test "default zeros" {
    const state = BlockStateBuilder.init(0).build();
    try std.testing.expectEqual(@as(u12, 0), state.block_id);
    try std.testing.expectEqual(@as(u3, 0), state.facing);
    try std.testing.expectEqual(@as(u1, 0), state.powered);
    try std.testing.expectEqual(@as(u1, 0), state.waterlogged);
    try std.testing.expectEqual(@as(u1, 0), state.half);
    try std.testing.expectEqual(@as(u1, 0), state.open);
    try std.testing.expectEqual(@as(u1, 0), state.lit);
    try std.testing.expectEqual(@as(u4, 0), state.age);
    try std.testing.expectEqual(@as(u4, 0), state.level);
    try std.testing.expectEqual(@as(u2, 0), state.axis);
    try std.testing.expectEqual(@as(u2, 0), state.variant);
}

test "round-trip via u32 cast" {
    const state = BlockStateBuilder.init(100)
        .withFacing(.east)
        .withPowered(true)
        .withWaterlogged(true)
        .withAge(12)
        .withLevel(5)
        .withAxis(2)
        .build();
    const raw: u32 = @bitCast(state);
    const restored: BlockState = @bitCast(raw);
    try std.testing.expectEqual(getBlockId(state), getBlockId(restored));
    try std.testing.expectEqual(getFacing(state), getFacing(restored));
    try std.testing.expectEqual(isPowered(state), isPowered(restored));
    try std.testing.expectEqual(isWaterlogged(state), isWaterlogged(restored));
    try std.testing.expectEqual(getAge(state), getAge(restored));
    try std.testing.expectEqual(getLevel(state), getLevel(restored));
}

test "needsState for doors stairs logs" {
    // Doors
    try std.testing.expect(needsState(40));
    // Trapdoors
    try std.testing.expect(needsState(44));
    // Oak log
    try std.testing.expect(needsState(8));
    // Crops
    try std.testing.expect(needsState(65));
    // Water
    try std.testing.expect(needsState(10));
    // Redstone wire
    try std.testing.expect(needsState(33));
    // Birch stairs (111 + 0*9 + 2 = 113)
    try std.testing.expect(needsState(113));
    // Spruce slab (111 + 1*9 + 3 = 123)
    try std.testing.expect(needsState(123));
    // Birch log (111 + 0*9 + 1 = 112)
    try std.testing.expect(needsState(112));
    // Plain stone should not need state
    try std.testing.expect(!needsState(1));
    // Air should not need state
    try std.testing.expect(!needsState(0));
}
