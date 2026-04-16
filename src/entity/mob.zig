/// MobManager: spawns, updates, and culls entities with their AI behaviors.
/// Owns parallel ArrayLists of Entity and AiBehavior kept in sync.
const std = @import("std");
const entity_mod = @import("entity.zig");
const ai_mod = @import("ai.zig");
const Entity = entity_mod.Entity;
const EntityType = entity_mod.EntityType;
const AiBehavior = ai_mod.AiBehavior;

pub const MobManager = struct {
    entities: std.ArrayList(Entity),
    behaviors: std.ArrayList(AiBehavior),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) MobManager {
        return .{
            .entities = .empty,
            .behaviors = .empty,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *MobManager) void {
        self.entities.deinit(self.allocator);
        self.behaviors.deinit(self.allocator);
    }

    /// Spawn a new mob at the given position.
    pub fn spawn(self: *MobManager, entity_type: EntityType, x: f32, y: f32, z: f32) !void {
        try self.entities.append(self.allocator, Entity.init(entity_type, x, y, z));
        errdefer _ = self.entities.pop();
        try self.behaviors.append(self.allocator, AiBehavior.init(entity_type));
    }

    /// Tick all mobs: run AI, then integrate position.
    pub fn update(
        self: *MobManager,
        player_x: f32,
        player_y: f32,
        player_z: f32,
        dt: f32,
    ) void {
        for (self.behaviors.items, self.entities.items) |*beh, *ent| {
            if (!ent.alive) continue;
            beh.update(ent, player_x, player_y, player_z, dt);
            ent.x += ent.vx * dt;
            ent.y += ent.vy * dt;
            ent.z += ent.vz * dt;
        }
    }

    /// Remove all dead entities, keeping alive ones packed.
    pub fn removeDeadEntities(self: *MobManager) void {
        var i: usize = 0;
        while (i < self.entities.items.len) {
            if (!self.entities.items[i].alive) {
                _ = self.entities.swapRemove(i);
                _ = self.behaviors.swapRemove(i);
            } else {
                i += 1;
            }
        }
    }

    /// Number of managed mobs.
    pub fn count(self: *const MobManager) usize {
        return self.entities.items.len;
    }
};

// -------------------------------------------------------------------------
// Tests
// -------------------------------------------------------------------------

test "spawn increases count" {
    var mgr = MobManager.init(std.testing.allocator);
    defer mgr.deinit();

    try mgr.spawn(.zombie, 0, 0, 0);
    try mgr.spawn(.pig, 5, 0, 5);

    try std.testing.expectEqual(@as(usize, 2), mgr.count());
}

test "update moves entities" {
    var mgr = MobManager.init(std.testing.allocator);
    defer mgr.deinit();

    try mgr.spawn(.zombie, 0, 0, 0);
    // Force the zombie into chase (player nearby).
    mgr.update(5, 0, 0, 1.0);

    // Zombie should have moved toward the player (positive x).
    try std.testing.expect(mgr.entities.items[0].x > 0);
}

test "removeDeadEntities cleans up" {
    var mgr = MobManager.init(std.testing.allocator);
    defer mgr.deinit();

    try mgr.spawn(.zombie, 0, 0, 0);
    try mgr.spawn(.pig, 5, 0, 5);
    try mgr.spawn(.chicken, 10, 0, 10);

    // Kill the pig.
    mgr.entities.items[1].takeDamage(100);

    mgr.removeDeadEntities();

    try std.testing.expectEqual(@as(usize, 2), mgr.count());
    // All remaining entities must be alive.
    for (mgr.entities.items) |ent| {
        try std.testing.expect(ent.alive);
    }
}

test "removeDeadEntities handles all dead" {
    var mgr = MobManager.init(std.testing.allocator);
    defer mgr.deinit();

    try mgr.spawn(.chicken, 0, 0, 0);
    try mgr.spawn(.chicken, 1, 0, 1);

    mgr.entities.items[0].takeDamage(100);
    mgr.entities.items[1].takeDamage(100);

    mgr.removeDeadEntities();

    try std.testing.expectEqual(@as(usize, 0), mgr.count());
}

test "removeDeadEntities handles none dead" {
    var mgr = MobManager.init(std.testing.allocator);
    defer mgr.deinit();

    try mgr.spawn(.pig, 0, 0, 0);
    try mgr.spawn(.cow, 1, 0, 1);

    mgr.removeDeadEntities();

    try std.testing.expectEqual(@as(usize, 2), mgr.count());
}

test "deinit on empty manager" {
    var mgr = MobManager.init(std.testing.allocator);
    mgr.deinit();
}
