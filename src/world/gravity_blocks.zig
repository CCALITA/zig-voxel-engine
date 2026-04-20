const std = @import("std");

const sand_id: u8 = 6;
const gravel_id: u8 = 7;

/// Concrete powder block IDs (14 colors).
const concrete_powder_id_min: u8 = 242;
const concrete_powder_id_max: u8 = 255;

/// Hardened concrete IDs share the same color offset.
const concrete_id_min: u8 = 226;

const gravity_accel: f32 = -20.0;
const max_anvil_damage: f32 = 40.0;
const anvil_damage_per_block: f32 = 2.0;

pub fn isGravityBlock(block_id: u8) bool {
    return block_id == sand_id or
        block_id == gravel_id or
        (block_id >= concrete_powder_id_min and block_id <= concrete_powder_id_max);
}

pub const FallingBlock = struct {
    x: f32,
    y: f32,
    z: f32,
    block_id: u8,
    vy: f32,

    pub fn update(self: *FallingBlock, dt: f32) void {
        self.vy += gravity_accel * dt;
        self.y += self.vy * dt;
    }

    pub fn hasLanded(self: FallingBlock, getBlock: *const fn (i32, i32, i32) u8) bool {
        const bx: i32 = @intFromFloat(@floor(self.x));
        const by: i32 = @intFromFloat(@floor(self.y - 0.01));
        const bz: i32 = @intFromFloat(@floor(self.z));
        const below = getBlock(bx, by, bz);
        return below != 0;
    }
};

pub fn getAnvilDamage(fall_distance: f32) f32 {
    if (fall_distance <= 0.0) return 0.0;
    const raw = anvil_damage_per_block * fall_distance;
    return @min(raw, max_anvil_damage);
}

pub fn concretePowderReaction(powder_id: u8, adjacent_water: bool) ?u8 {
    if (powder_id < concrete_powder_id_min or powder_id > concrete_powder_id_max) return null;
    if (!adjacent_water) return null;
    return powder_id - concrete_powder_id_min + concrete_id_min;
}

const max_falling_blocks: usize = 64;

pub const GravityManager = struct {
    falling: [max_falling_blocks]?FallingBlock,
    count: u8,

    pub fn init() GravityManager {
        return .{
            .falling = [_]?FallingBlock{null} ** max_falling_blocks,
            .count = 0,
        };
    }

    pub fn checkAndDrop(x: i32, y: i32, z: i32, block_id: u8, below_is_air: bool) ?FallingBlock {
        if (!isGravityBlock(block_id)) return null;
        if (!below_is_air) return null;
        return FallingBlock{
            .x = @as(f32, @floatFromInt(x)) + 0.5,
            .y = @floatFromInt(y),
            .z = @as(f32, @floatFromInt(z)) + 0.5,
            .block_id = block_id,
            .vy = 0.0,
        };
    }

    pub fn addFalling(self: *GravityManager, block: FallingBlock) bool {
        if (self.count >= max_falling_blocks) return false;
        for (&self.falling) |*slot| {
            if (slot.* == null) {
                slot.* = block;
                self.count += 1;
                return true;
            }
        }
        return false;
    }

    pub fn updateAll(self: *GravityManager, dt: f32) void {
        for (&self.falling) |*slot| {
            if (slot.*) |*block| {
                block.update(dt);
                if (block.y < -64.0) {
                    slot.* = null;
                    self.count -= 1;
                }
            }
        }
    }
};

fn testGetBlockAir(_: i32, _: i32, _: i32) u8 {
    return 0;
}

fn testGetBlockSolid(_: i32, _: i32, _: i32) u8 {
    return 1;
}

test "sand is a gravity block" {
    try std.testing.expect(isGravityBlock(sand_id));
}

test "gravel is a gravity block" {
    try std.testing.expect(isGravityBlock(gravel_id));
}

test "concrete powder is a gravity block" {
    try std.testing.expect(isGravityBlock(concrete_powder_id_min));
    try std.testing.expect(isGravityBlock(concrete_powder_id_max));
}

test "non-gravity block returns false" {
    try std.testing.expect(!isGravityBlock(1));
    try std.testing.expect(!isGravityBlock(0));
}

test "sand falls when updated" {
    var block = FallingBlock{
        .x = 5.0,
        .y = 64.0,
        .z = 5.0,
        .block_id = sand_id,
        .vy = 0.0,
    };
    const initial_y = block.y;
    block.update(0.05);
    try std.testing.expect(block.y < initial_y);
    try std.testing.expect(block.vy < 0.0);
}

test "falling block has not landed in air" {
    const block = FallingBlock{
        .x = 5.0,
        .y = 64.0,
        .z = 5.0,
        .block_id = sand_id,
        .vy = -5.0,
    };
    try std.testing.expect(!block.hasLanded(&testGetBlockAir));
}

test "falling block has landed on solid" {
    const block = FallingBlock{
        .x = 5.0,
        .y = 64.0,
        .z = 5.0,
        .block_id = sand_id,
        .vy = -5.0,
    };
    try std.testing.expect(block.hasLanded(&testGetBlockSolid));
}

test "anvil damage scales with distance" {
    try std.testing.expectEqual(@as(f32, 0.0), getAnvilDamage(0.0));
    try std.testing.expectEqual(@as(f32, 10.0), getAnvilDamage(5.0));
    try std.testing.expectEqual(@as(f32, 20.0), getAnvilDamage(10.0));
}

test "anvil damage caps at max" {
    try std.testing.expectEqual(@as(f32, 40.0), getAnvilDamage(25.0));
    try std.testing.expectEqual(@as(f32, 40.0), getAnvilDamage(100.0));
}

test "anvil damage negative distance returns zero" {
    try std.testing.expectEqual(@as(f32, 0.0), getAnvilDamage(-5.0));
}

test "concrete powder reacts with water" {
    const result = concretePowderReaction(concrete_powder_id_min, true);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(concrete_id_min, result.?);
}

test "concrete powder does not react without water" {
    const result = concretePowderReaction(concrete_powder_id_min, false);
    try std.testing.expect(result == null);
}

test "non-powder block returns null" {
    const result = concretePowderReaction(sand_id, true);
    try std.testing.expect(result == null);
}

test "manager checkAndDrop creates falling block for sand over air" {
    const fb = GravityManager.checkAndDrop(10, 64, 10, sand_id, true);
    try std.testing.expect(fb != null);
    try std.testing.expectEqual(sand_id, fb.?.block_id);
}

test "manager checkAndDrop returns null for non-gravity block" {
    const fb = GravityManager.checkAndDrop(10, 64, 10, 1, true);
    try std.testing.expect(fb == null);
}

test "manager checkAndDrop returns null when below is not air" {
    const fb = GravityManager.checkAndDrop(10, 64, 10, sand_id, false);
    try std.testing.expect(fb == null);
}

test "manager lifecycle: add, update, verify movement" {
    var mgr = GravityManager.init();
    try std.testing.expectEqual(@as(u8, 0), mgr.count);

    const fb = FallingBlock{
        .x = 5.5,
        .y = 64.0,
        .z = 5.5,
        .block_id = sand_id,
        .vy = 0.0,
    };
    const added = mgr.addFalling(fb);
    try std.testing.expect(added);
    try std.testing.expectEqual(@as(u8, 1), mgr.count);

    mgr.updateAll(0.05);

    var found = false;
    for (mgr.falling) |slot| {
        if (slot) |block| {
            try std.testing.expect(block.y < 64.0);
            try std.testing.expect(block.vy < 0.0);
            found = true;
        }
    }
    try std.testing.expect(found);
}
