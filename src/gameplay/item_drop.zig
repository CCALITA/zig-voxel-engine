/// Item drop and pickup system.
/// Dropped items float in the world with simple physics (gravity + ground collision),
/// can be picked up by the player after a short delay, and despawn after a timeout.

const std = @import("std");

pub const DESPAWN_TIME: f32 = 300.0; // 5 minutes
pub const PICKUP_DELAY: f32 = 0.5; // can't pick up immediately after dropping
pub const PICKUP_RANGE: f32 = 1.5;

const GRAVITY: f32 = 20.0;
const SPAWN_SPEED: f32 = 2.0; // horizontal spread when spawned

pub const DroppedItem = struct {
    x: f32,
    y: f32,
    z: f32,
    vx: f32,
    vy: f32,
    vz: f32,
    item_id: u16,
    count: u8,
    lifetime: f32, // seconds since dropped
    pickup_delay: f32, // seconds remaining before pickup allowed
    active: bool,
};

pub const ItemDropManager = struct {
    drops: std.ArrayList(DroppedItem),

    pub fn init(allocator: std.mem.Allocator) ItemDropManager {
        return .{
            .drops = std.ArrayList(DroppedItem).init(allocator),
        };
    }

    pub fn deinit(self: *ItemDropManager) void {
        self.drops.deinit();
    }

    /// Spawn a dropped item at position with a small random velocity spread.
    /// Uses a simple deterministic pattern based on current drop count so behaviour
    /// is reproducible without requiring an external RNG.
    pub fn spawnDrop(self: *ItemDropManager, x: f32, y: f32, z: f32, item_id: u16, count: u8) !void {
        const seed: u32 = @truncate(self.drops.items.len);
        const angle = @as(f32, @floatFromInt(seed % 8)) * (std.math.pi / 4.0);
        const vx = @cos(angle) * SPAWN_SPEED;
        const vz = @sin(angle) * SPAWN_SPEED;

        try self.drops.append(.{
            .x = x,
            .y = y,
            .z = z,
            .vx = vx,
            .vy = 3.0, // small upward pop
            .vz = vz,
            .item_id = item_id,
            .count = count,
            .lifetime = 0.0,
            .pickup_delay = PICKUP_DELAY,
            .active = true,
        });
    }

    /// Update all drops: apply gravity, advance timers, check despawn and pickup.
    /// Returns a slice of items picked up this frame (caller owns the memory and
    /// should add them to the player inventory).
    pub fn update(
        self: *ItemDropManager,
        dt: f32,
        player_x: f32,
        player_y: f32,
        player_z: f32,
    ) ![]DroppedItem {
        var picked_up = std.ArrayList(DroppedItem).init(self.drops.allocator);
        errdefer picked_up.deinit();

        for (self.drops.items) |*drop| {
            if (!drop.active) continue;

            drop.lifetime += dt;
            drop.pickup_delay = @max(drop.pickup_delay - dt, 0.0);

            if (drop.lifetime >= DESPAWN_TIME) {
                drop.active = false;
                continue;
            }

            // Gravity.
            drop.vy -= GRAVITY * dt;

            // Integrate position.
            drop.x += drop.vx * dt;
            drop.y += drop.vy * dt;
            drop.z += drop.vz * dt;

            // Ground collision at the nearest integer Y.
            const ground = @floor(drop.y);
            if (drop.y <= ground) {
                drop.y = ground;
                drop.vy = 0.0;
                drop.vx = 0.0;
                drop.vz = 0.0;
            }

            // Pickup check.
            if (drop.pickup_delay <= 0.0) {
                const dx = drop.x - player_x;
                const dy = drop.y - player_y;
                const dz = drop.z - player_z;
                const dist_sq = dx * dx + dy * dy + dz * dz;
                if (dist_sq <= PICKUP_RANGE * PICKUP_RANGE) {
                    try picked_up.append(drop.*);
                    drop.active = false;
                }
            }
        }

        return picked_up.toOwnedSlice();
    }

    /// Remove inactive items from the list, preserving order of remaining items.
    pub fn cleanup(self: *ItemDropManager) void {
        var i: usize = 0;
        while (i < self.drops.items.len) {
            if (!self.drops.items[i].active) {
                _ = self.drops.orderedRemove(i);
            } else {
                i += 1;
            }
        }
    }

    pub fn activeCount(self: *const ItemDropManager) usize {
        var count: usize = 0;
        for (self.drops.items) |drop| {
            if (drop.active) count += 1;
        }
        return count;
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "spawn drop sets correct position and item" {
    var mgr = ItemDropManager.init(std.testing.allocator);
    defer mgr.deinit();

    try mgr.spawnDrop(1.0, 10.0, 3.0, 42, 5);

    try std.testing.expectEqual(@as(usize, 1), mgr.drops.items.len);
    const drop = mgr.drops.items[0];
    try std.testing.expectEqual(@as(f32, 1.0), drop.x);
    try std.testing.expectEqual(@as(f32, 10.0), drop.y);
    try std.testing.expectEqual(@as(f32, 3.0), drop.z);
    try std.testing.expectEqual(@as(u16, 42), drop.item_id);
    try std.testing.expectEqual(@as(u8, 5), drop.count);
    try std.testing.expect(drop.active);
}

test "update applies gravity so y decreases" {
    var mgr = ItemDropManager.init(std.testing.allocator);
    defer mgr.deinit();

    try mgr.spawnDrop(0.0, 100.0, 0.0, 1, 1);
    const initial_y = mgr.drops.items[0].y;

    const picked = try mgr.update(0.1, 999.0, 999.0, 999.0);
    defer std.testing.allocator.free(picked);

    try std.testing.expect(mgr.drops.items[0].y < initial_y);
}

test "pickup when close enough and delay elapsed" {
    var mgr = ItemDropManager.init(std.testing.allocator);
    defer mgr.deinit();

    try mgr.spawnDrop(0.0, 0.0, 0.0, 7, 3);

    // Force delay to zero so pickup is allowed.
    mgr.drops.items[0].pickup_delay = 0.0;
    // Zero out velocity so item stays at origin.
    mgr.drops.items[0].vx = 0.0;
    mgr.drops.items[0].vy = 0.0;
    mgr.drops.items[0].vz = 0.0;

    const picked = try mgr.update(0.01, 0.0, 0.0, 0.0);
    defer std.testing.allocator.free(picked);

    try std.testing.expectEqual(@as(usize, 1), picked.len);
    try std.testing.expectEqual(@as(u16, 7), picked[0].item_id);
    try std.testing.expectEqual(@as(u8, 3), picked[0].count);
    try std.testing.expect(!mgr.drops.items[0].active);
}

test "no pickup during delay period" {
    var mgr = ItemDropManager.init(std.testing.allocator);
    defer mgr.deinit();

    try mgr.spawnDrop(0.0, 0.0, 0.0, 7, 3);
    // Keep the default pickup_delay (0.5 s). Zero velocity so item stays put.
    mgr.drops.items[0].vx = 0.0;
    mgr.drops.items[0].vy = 0.0;
    mgr.drops.items[0].vz = 0.0;

    // Update with a tiny dt so delay has not expired.
    const picked = try mgr.update(0.01, 0.0, 0.0, 0.0);
    defer std.testing.allocator.free(picked);

    try std.testing.expectEqual(@as(usize, 0), picked.len);
    try std.testing.expect(mgr.drops.items[0].active);
}

test "despawn after lifetime exceeded" {
    var mgr = ItemDropManager.init(std.testing.allocator);
    defer mgr.deinit();

    try mgr.spawnDrop(0.0, 0.0, 0.0, 1, 1);
    // Push lifetime just past the threshold.
    mgr.drops.items[0].lifetime = DESPAWN_TIME - 0.01;

    const picked = try mgr.update(0.02, 999.0, 999.0, 999.0);
    defer std.testing.allocator.free(picked);

    try std.testing.expectEqual(@as(usize, 0), picked.len);
    try std.testing.expect(!mgr.drops.items[0].active);
}

test "activeCount reflects live drops" {
    var mgr = ItemDropManager.init(std.testing.allocator);
    defer mgr.deinit();

    try mgr.spawnDrop(0.0, 0.0, 0.0, 1, 1);
    try mgr.spawnDrop(0.0, 0.0, 0.0, 2, 1);
    try std.testing.expectEqual(@as(usize, 2), mgr.activeCount());

    // Deactivate one manually.
    mgr.drops.items[0].active = false;
    try std.testing.expectEqual(@as(usize, 1), mgr.activeCount());
}

test "cleanup removes inactive drops" {
    var mgr = ItemDropManager.init(std.testing.allocator);
    defer mgr.deinit();

    try mgr.spawnDrop(0.0, 0.0, 0.0, 1, 1);
    try mgr.spawnDrop(0.0, 0.0, 0.0, 2, 1);

    mgr.drops.items[0].active = false;
    mgr.cleanup();

    try std.testing.expectEqual(@as(usize, 1), mgr.drops.items.len);
    try std.testing.expectEqual(@as(u16, 2), mgr.drops.items[0].item_id);
}
