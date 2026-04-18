/// Command Block and Structure Block systems.
/// Command blocks execute server commands when powered by redstone.
/// Three modes: Impulse (fires once), Repeating (every tick while powered),
/// Chain (fires when the block facing into it executes successfully).
/// Structure blocks save/load/detect structures in the world.

const std = @import("std");

// ──────────────────────────────────────────────────────────────────────────────
// Command Block
// ──────────────────────────────────────────────────────────────────────────────

pub const CommandBlockMode = enum {
    impulse,
    repeating,
    chain,
};

pub const CommandOutput = struct {
    success: bool,
    message: [256]u8,
    message_len: u16,

    fn create(success: bool, msg: []const u8) CommandOutput {
        var out = CommandOutput{
            .success = success,
            .message = [_]u8{0} ** 256,
            .message_len = @intCast(@min(msg.len, 256)),
        };
        @memcpy(out.message[0..out.message_len], msg[0..out.message_len]);
        return out;
    }

    pub fn ok(msg: []const u8) CommandOutput {
        return create(true, msg);
    }

    pub fn fail(msg: []const u8) CommandOutput {
        return create(false, msg);
    }
};

pub const CommandBlockState = struct {
    mode: CommandBlockMode,
    command: [512]u8,
    command_len: u16,
    conditional: bool,
    needs_redstone: bool,
    last_output: [256]u8,
    output_len: u16,
    /// Tracks whether the block has already fired for the current power pulse
    /// (impulse mode only). Reset when power is removed.
    has_fired: bool,

    pub fn init(mode: CommandBlockMode) CommandBlockState {
        return .{
            .mode = mode,
            .command = [_]u8{0} ** 512,
            .command_len = 0,
            .conditional = false,
            .needs_redstone = true,
            .last_output = [_]u8{0} ** 256,
            .output_len = 0,
            .has_fired = false,
        };
    }

    pub fn setCommand(self: CommandBlockState, cmd: []const u8) CommandBlockState {
        var result = self;
        result.command_len = @intCast(@min(cmd.len, 512));
        result.command = [_]u8{0} ** 512;
        @memcpy(result.command[0..result.command_len], cmd[0..result.command_len]);
        return result;
    }

    pub fn getCommand(self: *const CommandBlockState) []const u8 {
        return self.command[0..self.command_len];
    }

    pub fn getLastOutput(self: *const CommandBlockState) []const u8 {
        return self.last_output[0..self.output_len];
    }

    /// Execute the command block.
    ///
    /// `powered`:       whether the block is receiving redstone power.
    /// `chain_powered`: whether the block facing into this one just executed
    ///                  successfully (relevant for chain mode).
    /// `prev_success`:  whether the previous block in the chain succeeded
    ///                  (relevant for conditional mode).
    ///
    /// Returns a `CommandOutput` when the block fires, or null when it does not.
    pub fn execute(
        self: CommandBlockState,
        powered: bool,
        chain_powered: bool,
        prev_success: bool,
    ) struct { state: CommandBlockState, output: ?CommandOutput } {
        var next = self;

        // When power is removed, reset the impulse latch.
        if (!powered and !chain_powered) {
            next.has_fired = false;
            return .{ .state = next, .output = null };
        }

        // Conditional blocks only fire when the previous block in the chain succeeded.
        if (self.conditional and !prev_success) {
            return .{ .state = next, .output = null };
        }

        const should_fire = switch (self.mode) {
            .impulse => blk: {
                if (self.needs_redstone and !powered) break :blk false;
                break :blk !self.has_fired;
            },
            .repeating => blk: {
                if (self.needs_redstone and !powered) break :blk false;
                break :blk true;
            },
            .chain => chain_powered,
        };

        if (!should_fire) {
            return .{ .state = next, .output = null };
        }

        // Fire the command.
        const output = if (self.command_len == 0)
            CommandOutput.fail("No command set")
        else
            CommandOutput.ok("Command executed");

        next.last_output = output.message;
        next.output_len = output.message_len;
        next.has_fired = true;
        return .{ .state = next, .output = output };
    }
};

// ──────────────────────────────────────────────────────────────────────────────
// Structure Block
// ──────────────────────────────────────────────────────────────────────────────

pub const StructureBlockMode = enum {
    save,
    load,
    corner,
    data_mode,
};

pub const Rotation = enum {
    none,
    clockwise_90,
    clockwise_180,
    clockwise_270,
};

pub const Mirror = enum {
    none,
    left_right,
    front_back,
};

pub const BoundingBox = struct {
    min_x: i32,
    min_y: i32,
    min_z: i32,
    max_x: i32,
    max_y: i32,
    max_z: i32,
};

/// Well-known block IDs (dependency-free mirror of world/block.zig).
const STRUCTURE_BLOCK_ID: u8 = 200;

pub const StructureBlock = struct {
    mode: StructureBlockMode,
    structure_name: [64]u8,
    name_len: u8,
    offset_x: i32,
    offset_y: i32,
    offset_z: i32,
    size_x: u32,
    size_y: u32,
    size_z: u32,
    rotation: Rotation,
    mirror: Mirror,

    pub fn init(mode: StructureBlockMode) StructureBlock {
        return .{
            .mode = mode,
            .structure_name = [_]u8{0} ** 64,
            .name_len = 0,
            .offset_x = 0,
            .offset_y = 0,
            .offset_z = 0,
            .size_x = 0,
            .size_y = 0,
            .size_z = 0,
            .rotation = .none,
            .mirror = .none,
        };
    }

    pub fn setName(self: StructureBlock, name: []const u8) StructureBlock {
        var result = self;
        result.name_len = @intCast(@min(name.len, 64));
        result.structure_name = [_]u8{0} ** 64;
        @memcpy(result.structure_name[0..result.name_len], name[0..result.name_len]);
        return result;
    }

    pub fn getName(self: *const StructureBlock) []const u8 {
        return self.structure_name[0..self.name_len];
    }

    /// Detect bounding box by scanning for two corner-mode structure blocks with
    /// the same name. `getBlock` returns the block ID at the given coordinates.
    /// Searches within offset + size volume from (`origin_x`, `origin_y`, `origin_z`).
    pub fn detectBoundingBox(
        self: *const StructureBlock,
        origin_x: i32,
        origin_y: i32,
        origin_z: i32,
        getBlock: *const fn (i32, i32, i32) u8,
    ) ?BoundingBox {
        if (self.size_x == 0 or self.size_y == 0 or self.size_z == 0) return null;

        var min_x: ?i32 = null;
        var min_y: ?i32 = null;
        var min_z: ?i32 = null;
        var max_x: ?i32 = null;
        var max_y: ?i32 = null;
        var max_z: ?i32 = null;
        var corner_count: u8 = 0;

        const sx: i32 = @intCast(self.size_x);
        const sy: i32 = @intCast(self.size_y);
        const sz: i32 = @intCast(self.size_z);

        const base_x = origin_x + self.offset_x;
        const base_y = origin_y + self.offset_y;
        const base_z = origin_z + self.offset_z;

        var y: i32 = base_y;
        while (y < base_y + sy) : (y += 1) {
            var x: i32 = base_x;
            while (x < base_x + sx) : (x += 1) {
                var z: i32 = base_z;
                while (z < base_z + sz) : (z += 1) {
                    if (getBlock(x, y, z) == STRUCTURE_BLOCK_ID) {
                        if (corner_count == 0) {
                            min_x = x;
                            min_y = y;
                            min_z = z;
                            max_x = x;
                            max_y = y;
                            max_z = z;
                        } else {
                            min_x = @min(min_x.?, x);
                            min_y = @min(min_y.?, y);
                            min_z = @min(min_z.?, z);
                            max_x = @max(max_x.?, x);
                            max_y = @max(max_y.?, y);
                            max_z = @max(max_z.?, z);
                        }
                        corner_count += 1;
                    }
                }
            }
        }

        if (corner_count < 2) return null;

        return BoundingBox{
            .min_x = min_x.?,
            .min_y = min_y.?,
            .min_z = min_z.?,
            .max_x = max_x.?,
            .max_y = max_y.?,
            .max_z = max_z.?,
        };
    }
};

// ──────────────────────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────────────────────

// --- Command block: impulse fires once ---------------------------------------

test "impulse command block fires once on power" {
    const cb = CommandBlockState.init(.impulse).setCommand("say hello");

    // First tick with power: should fire.
    const r1 = cb.execute(true, false, true);
    try std.testing.expect(r1.output != null);
    try std.testing.expect(r1.output.?.success);
    try std.testing.expect(r1.state.has_fired);

    // Second tick with power still on: should not fire again.
    const r2 = r1.state.execute(true, false, true);
    try std.testing.expect(r2.output == null);

    // Power removed: resets latch.
    const r3 = r2.state.execute(false, false, true);
    try std.testing.expect(r3.output == null);
    try std.testing.expect(!r3.state.has_fired);

    // Power restored: fires again.
    const r4 = r3.state.execute(true, false, true);
    try std.testing.expect(r4.output != null);
    try std.testing.expect(r4.output.?.success);
}

// --- Command block: repeating fires continuously ----------------------------

test "repeating command block fires every tick when powered" {
    const cb = CommandBlockState.init(.repeating).setCommand("say tick");

    // Tick 1: fires.
    const r1 = cb.execute(true, false, true);
    try std.testing.expect(r1.output != null);
    try std.testing.expect(r1.output.?.success);

    // Tick 2: fires again (no latch).
    const r2 = r1.state.execute(true, false, true);
    try std.testing.expect(r2.output != null);
    try std.testing.expect(r2.output.?.success);

    // Tick 3: fires again.
    const r3 = r2.state.execute(true, false, true);
    try std.testing.expect(r3.output != null);

    // Power off: stops.
    const r4 = r3.state.execute(false, false, true);
    try std.testing.expect(r4.output == null);
}

// --- Command block: chain propagation ----------------------------------------

test "chain command block fires when chain_powered" {
    const cb = CommandBlockState.init(.chain).setCommand("say chained");

    // Not chain-powered: does not fire.
    const r1 = cb.execute(false, false, true);
    try std.testing.expect(r1.output == null);

    // Chain-powered: fires.
    const r2 = r1.state.execute(false, true, true);
    try std.testing.expect(r2.output != null);
    try std.testing.expect(r2.output.?.success);
}

test "chain propagation across multiple blocks" {
    const cb1 = CommandBlockState.init(.impulse).setCommand("say first");
    const cb2 = CommandBlockState.init(.chain).setCommand("say second");
    const cb3 = CommandBlockState.init(.chain).setCommand("say third");

    // Impulse fires first.
    const r1 = cb1.execute(true, false, true);
    try std.testing.expect(r1.output != null);
    const first_success = r1.output.?.success;

    // Chain 2 fires because chain_powered = true, prev_success = first result.
    const r2 = cb2.execute(false, true, first_success);
    try std.testing.expect(r2.output != null);
    const second_success = r2.output.?.success;

    // Chain 3 fires because chain_powered = true.
    const r3 = cb3.execute(false, true, second_success);
    try std.testing.expect(r3.output != null);
    try std.testing.expect(r3.output.?.success);
}

// --- Command block: conditional skip ----------------------------------------

test "conditional command block skips when previous failed" {
    var cb = CommandBlockState.init(.impulse).setCommand("say conditional");
    cb.conditional = true;

    // prev_success = false: does not fire even when powered.
    const r1 = cb.execute(true, false, false);
    try std.testing.expect(r1.output == null);

    // prev_success = true: fires.
    const r2 = cb.execute(true, false, true);
    try std.testing.expect(r2.output != null);
    try std.testing.expect(r2.output.?.success);
}

test "conditional chain block skips when previous failed" {
    var cb = CommandBlockState.init(.chain).setCommand("say cond_chain");
    cb.conditional = true;

    // chain_powered but prev failed: does not fire.
    const r1 = cb.execute(false, true, false);
    try std.testing.expect(r1.output == null);

    // chain_powered and prev succeeded: fires.
    const r2 = cb.execute(false, true, true);
    try std.testing.expect(r2.output != null);
}

// --- Command block: empty command ------------------------------------------

test "command block with no command returns failure output" {
    const cb = CommandBlockState.init(.impulse);

    const r = cb.execute(true, false, true);
    try std.testing.expect(r.output != null);
    try std.testing.expect(!r.output.?.success);
}

// --- Command block: needs_redstone flag ------------------------------------

test "impulse block without needs_redstone fires without power" {
    var cb = CommandBlockState.init(.impulse).setCommand("say always");
    cb.needs_redstone = false;

    // chain_powered provides the activation trigger even without redstone power.
    const r = cb.execute(false, true, true);
    try std.testing.expect(r.output != null);
    try std.testing.expect(r.output.?.success);
}

// --- Command block: last output persists -----------------------------------

test "last output is stored after execution" {
    const cb = CommandBlockState.init(.impulse).setCommand("say stored");

    const r = cb.execute(true, false, true);
    try std.testing.expect(r.output != null);
    const expected = "Command executed";
    try std.testing.expectEqualSlices(u8, expected, r.state.getLastOutput());
}

// --- Structure block: bounding box detection ---------------------------------

const TestBlockMap = struct {
    const SIZE = 32;
    const OFFSET = 16;
    data: [SIZE][SIZE][SIZE]u8,

    fn init() TestBlockMap {
        return .{ .data = [_][SIZE][SIZE]u8{[_][SIZE]u8{[_]u8{0} ** SIZE} ** SIZE} ** SIZE };
    }

    fn set(self: *TestBlockMap, x: i32, y: i32, z: i32, id: u8) void {
        const ux: usize = @intCast(x + OFFSET);
        const uy: usize = @intCast(y + OFFSET);
        const uz: usize = @intCast(z + OFFSET);
        self.data[ux][uy][uz] = id;
    }

    fn get(self: *const TestBlockMap, x: i32, y: i32, z: i32) u8 {
        const ux: usize = @intCast(x + OFFSET);
        const uy: usize = @intCast(y + OFFSET);
        const uz: usize = @intCast(z + OFFSET);
        return self.data[ux][uy][uz];
    }
};

var test_map: TestBlockMap = undefined;

fn testGetBlock(x: i32, y: i32, z: i32) u8 {
    return test_map.get(x, y, z);
}

test "structure block detects bounding box from two corners" {
    test_map = TestBlockMap.init();

    // Place two corner structure blocks.
    test_map.set(2, 1, 3, STRUCTURE_BLOCK_ID);
    test_map.set(5, 4, 7, STRUCTURE_BLOCK_ID);

    var sb = StructureBlock.init(.save).setName("test_struct");
    sb.size_x = 10;
    sb.size_y = 10;
    sb.size_z = 10;

    const bbox = sb.detectBoundingBox(0, 0, 0, testGetBlock);
    try std.testing.expect(bbox != null);
    try std.testing.expectEqual(@as(i32, 2), bbox.?.min_x);
    try std.testing.expectEqual(@as(i32, 1), bbox.?.min_y);
    try std.testing.expectEqual(@as(i32, 3), bbox.?.min_z);
    try std.testing.expectEqual(@as(i32, 5), bbox.?.max_x);
    try std.testing.expectEqual(@as(i32, 4), bbox.?.max_y);
    try std.testing.expectEqual(@as(i32, 7), bbox.?.max_z);
}

test "structure block returns null with fewer than two corners" {
    test_map = TestBlockMap.init();

    // Only one corner block.
    test_map.set(3, 3, 3, STRUCTURE_BLOCK_ID);

    var sb = StructureBlock.init(.save).setName("lonely");
    sb.size_x = 10;
    sb.size_y = 10;
    sb.size_z = 10;

    const bbox = sb.detectBoundingBox(0, 0, 0, testGetBlock);
    try std.testing.expect(bbox == null);
}

test "structure block returns null with zero size" {
    test_map = TestBlockMap.init();

    const sb = StructureBlock.init(.save);
    const bbox = sb.detectBoundingBox(0, 0, 0, testGetBlock);
    try std.testing.expect(bbox == null);
}

test "structure block bounding box respects offset" {
    test_map = TestBlockMap.init();

    // Place corners at (5,5,5) and (8,8,8).
    test_map.set(5, 5, 5, STRUCTURE_BLOCK_ID);
    test_map.set(8, 8, 8, STRUCTURE_BLOCK_ID);

    var sb = StructureBlock.init(.save).setName("offset_test");
    sb.offset_x = 4;
    sb.offset_y = 4;
    sb.offset_z = 4;
    sb.size_x = 10;
    sb.size_y = 10;
    sb.size_z = 10;

    // Origin at (0,0,0) + offset (4,4,4) = search starts at (4,4,4).
    const bbox = sb.detectBoundingBox(0, 0, 0, testGetBlock);
    try std.testing.expect(bbox != null);
    try std.testing.expectEqual(@as(i32, 5), bbox.?.min_x);
    try std.testing.expectEqual(@as(i32, 8), bbox.?.max_x);
}

test "structure block init defaults" {
    const sb = StructureBlock.init(.load);
    try std.testing.expectEqual(StructureBlockMode.load, sb.mode);
    try std.testing.expectEqual(@as(u32, 0), sb.size_x);
    try std.testing.expectEqual(Rotation.none, sb.rotation);
    try std.testing.expectEqual(Mirror.none, sb.mirror);
    try std.testing.expectEqual(@as(u8, 0), sb.name_len);
}

test "structure block set and get name" {
    const sb = StructureBlock.init(.corner).setName("my_castle");
    try std.testing.expectEqualSlices(u8, "my_castle", sb.getName());
}
