/// Entity definitions for all mobs in the voxel engine.
/// Each entity has a type, position, velocity, dimensions, and health.
const std = @import("std");

pub const EntityType = enum {
    player,
    zombie,
    skeleton,
    creeper,
    pig,
    cow,
    chicken,
    sheep,

    pub fn isHostile(self: EntityType) bool {
        return switch (self) {
            .zombie, .skeleton, .creeper => true,
            else => false,
        };
    }
};

pub const Entity = struct {
    entity_type: EntityType,
    x: f32,
    y: f32,
    z: f32,
    vx: f32,
    vy: f32,
    vz: f32,
    yaw: f32,
    width: f32,
    height: f32,
    health: f32,
    max_health: f32,
    alive: bool,
    on_ground: bool,

    /// Create a new entity with type-appropriate stats at the given position.
    pub fn init(entity_type: EntityType, x: f32, y: f32, z: f32) Entity {
        const stats = getTypeStats(entity_type);
        return .{
            .entity_type = entity_type,
            .x = x,
            .y = y,
            .z = z,
            .vx = 0,
            .vy = 0,
            .vz = 0,
            .yaw = 0,
            .width = stats.width,
            .height = stats.height,
            .health = stats.health,
            .max_health = stats.health,
            .alive = true,
            .on_ground = false,
        };
    }

    /// Reduce health by the given amount. Sets alive to false when health
    /// reaches zero.
    pub fn takeDamage(self: *Entity, amount: f32) void {
        self.health -= amount;
        if (self.health <= 0) {
            self.health = 0;
            self.alive = false;
        }
    }

    /// Restore health up to max_health.
    pub fn heal(self: *Entity, amount: f32) void {
        self.health = @min(self.health + amount, self.max_health);
    }

    /// Returns true when health has reached zero.
    pub fn isDead(self: *const Entity) bool {
        return !self.alive;
    }

    /// Euclidean distance to another entity.
    pub fn distanceTo(self: *const Entity, other: *const Entity) f32 {
        return self.distanceToPoint(other.x, other.y, other.z);
    }

    /// Euclidean distance to an arbitrary point.
    pub fn distanceToPoint(self: *const Entity, px: f32, py: f32, pz: f32) f32 {
        const dx = self.x - px;
        const dy = self.y - py;
        const dz = self.z - pz;
        return @sqrt(dx * dx + dy * dy + dz * dz);
    }
};

// -- Per-type base stats --------------------------------------------------

const TypeStats = struct {
    width: f32,
    height: f32,
    health: f32,
};

fn getTypeStats(entity_type: EntityType) TypeStats {
    return switch (entity_type) {
        .player => .{ .width = 0.6, .height = 1.8, .health = 20 },
        .zombie => .{ .width = 0.6, .height = 1.8, .health = 20 },
        .skeleton => .{ .width = 0.6, .height = 1.8, .health = 20 },
        .creeper => .{ .width = 0.6, .height = 1.7, .health = 20 },
        .pig => .{ .width = 0.9, .height = 1.4, .health = 10 },
        .cow => .{ .width = 0.9, .height = 1.4, .health = 10 },
        .chicken => .{ .width = 0.4, .height = 0.7, .health = 4 },
        .sheep => .{ .width = 0.9, .height = 1.3, .health = 8 },
    };
}

// -------------------------------------------------------------------------
// Tests
// -------------------------------------------------------------------------

test "zombie has correct stats" {
    const z = Entity.init(.zombie, 1, 2, 3);
    try std.testing.expectApproxEqAbs(@as(f32, 0.6), z.width, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.8), z.height, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 20), z.health, 0.001);
    try std.testing.expect(z.alive);
}

test "skeleton has correct stats" {
    const s = Entity.init(.skeleton, 0, 0, 0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.6), s.width, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.8), s.height, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 20), s.health, 0.001);
}

test "creeper has correct stats" {
    const c = Entity.init(.creeper, 0, 0, 0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.6), c.width, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.7), c.height, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 20), c.health, 0.001);
}

test "pig has correct stats" {
    const p = Entity.init(.pig, 0, 0, 0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.9), p.width, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.4), p.height, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 10), p.health, 0.001);
}

test "cow has correct stats" {
    const c = Entity.init(.cow, 0, 0, 0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.9), c.width, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.4), c.height, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 10), c.health, 0.001);
}

test "chicken has correct stats" {
    const c = Entity.init(.chicken, 0, 0, 0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.4), c.width, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.7), c.height, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 4), c.health, 0.001);
}

test "sheep has correct stats" {
    const s = Entity.init(.sheep, 0, 0, 0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.9), s.width, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.3), s.height, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 8), s.health, 0.001);
}

test "takeDamage reduces health" {
    var e = Entity.init(.zombie, 0, 0, 0);
    e.takeDamage(5);
    try std.testing.expectApproxEqAbs(@as(f32, 15), e.health, 0.001);
    try std.testing.expect(e.alive);
}

test "takeDamage kills at zero" {
    var e = Entity.init(.chicken, 0, 0, 0);
    e.takeDamage(4);
    try std.testing.expectApproxEqAbs(@as(f32, 0), e.health, 0.001);
    try std.testing.expect(!e.alive);
    try std.testing.expect(e.isDead());
}

test "takeDamage clamps to zero on overkill" {
    var e = Entity.init(.chicken, 0, 0, 0);
    e.takeDamage(100);
    try std.testing.expectApproxEqAbs(@as(f32, 0), e.health, 0.001);
    try std.testing.expect(e.isDead());
}

test "heal restores health up to max" {
    var e = Entity.init(.zombie, 0, 0, 0);
    e.takeDamage(10);
    e.heal(5);
    try std.testing.expectApproxEqAbs(@as(f32, 15), e.health, 0.001);
}

test "heal does not exceed max_health" {
    var e = Entity.init(.zombie, 0, 0, 0);
    e.takeDamage(5);
    e.heal(100);
    try std.testing.expectApproxEqAbs(@as(f32, 20), e.health, 0.001);
}

test "isDead returns false when alive" {
    const e = Entity.init(.pig, 0, 0, 0);
    try std.testing.expect(!e.isDead());
}

test "distanceTo between two entities" {
    const a = Entity.init(.zombie, 0, 0, 0);
    const b = Entity.init(.pig, 3, 4, 0);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), a.distanceTo(&b), 0.001);
}

test "distanceToPoint" {
    const e = Entity.init(.zombie, 1, 2, 3);
    try std.testing.expectApproxEqAbs(@as(f32, 0), e.distanceToPoint(1, 2, 3), 0.001);
    // distance to (4, 6, 3) => sqrt(9+16+0) = 5
    try std.testing.expectApproxEqAbs(@as(f32, 5), e.distanceToPoint(4, 6, 3), 0.001);
}

test "init sets position correctly" {
    const e = Entity.init(.creeper, 10, 20, 30);
    try std.testing.expectApproxEqAbs(@as(f32, 10), e.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 20), e.y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 30), e.z, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), e.vx, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), e.vy, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), e.vz, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), e.yaw, 0.001);
}
