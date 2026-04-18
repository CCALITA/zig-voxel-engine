/// AI behavior for mobs: idle, wander, chase, and flee states.
/// Passive mobs only idle and wander; hostile mobs chase the player.
/// Uses A* pathfinding to navigate around obstacles.
const std = @import("std");
const entity_mod = @import("entity.zig");
const EntityType = entity_mod.EntityType;
const Entity = entity_mod.Entity;
const pathfinding = @import("pathfinding.zig");
const PathNode = pathfinding.PathNode;

pub const AiState = enum {
    idle,
    wander,
    chase,
    flee,
};

pub const AiBehavior = struct {
    state: AiState,
    state_timer: f32,
    target_x: f32,
    target_z: f32,
    wander_radius: f32,
    chase_range: f32,
    attack_range: f32,

    /// Cached A* path for obstacle-aware navigation.
    path: [64]PathNode,
    path_length: u8,
    path_index: u8,
    path_timer: f32,

    /// Create AI behavior with type-appropriate defaults.
    pub fn init(entity_type: EntityType) AiBehavior {
        const params = getAiParams(entity_type);
        return .{
            .state = .idle,
            .state_timer = 3.0,
            .target_x = 0,
            .target_z = 0,
            .wander_radius = params.wander_radius,
            .chase_range = params.chase_range,
            .attack_range = params.attack_range,
            .path = undefined,
            .path_length = 0,
            .path_index = 0,
            .path_timer = 0,
        };
    }

    /// Advance the AI by dt seconds.  Updates entity velocity and yaw
    /// based on the current state and player position.
    pub fn update(
        self: *AiBehavior,
        entity: *Entity,
        player_x: f32,
        player_y: f32,
        player_z: f32,
        dt: f32,
    ) void {
        self.state_timer -= dt;
        self.path_timer -= dt;

        const is_hostile = isHostile(entity.entity_type);
        const dist_to_player = entity.distanceToPoint(player_x, player_y, player_z);

        // Hostile mobs switch to chase when player is in range.
        if (is_hostile and dist_to_player <= self.chase_range and self.state != .chase) {
            self.state = .chase;
            self.state_timer = 0;
            self.path_timer = 0; // force immediate pathfind
        }

        // Hostile mobs leave chase when player exits range.
        if (is_hostile and self.state == .chase and dist_to_player > self.chase_range) {
            self.state = .idle;
            self.state_timer = 3.0;
            self.clearPath();
        }

        switch (self.state) {
            .idle => {
                entity.vx = 0;
                entity.vz = 0;
                if (self.state_timer <= 0) {
                    self.state = .wander;
                    self.target_x = entity.x + randomOffset(self.wander_radius);
                    self.target_z = entity.z + randomOffset(self.wander_radius);
                    self.state_timer = 3.0;
                    self.computePath(entity);
                }
            },
            .wander => {
                self.followPath(entity, walk_speed * 0.5);

                const dx = self.target_x - entity.x;
                const dz = self.target_z - entity.z;
                const dist_sq = dx * dx + dz * dz;
                if (dist_sq < 0.5 or self.state_timer <= 0 or self.isPathComplete()) {
                    self.state = .idle;
                    self.state_timer = 2.0 + randomOffset(1.5);
                    entity.vx = 0;
                    entity.vz = 0;
                    self.clearPath();
                }
            },
            .chase => {
                // Recalculate path every 2 seconds to track the player.
                if (self.path_timer <= 0) {
                    self.target_x = player_x;
                    self.target_z = player_z;
                    self.computePath(entity);
                    self.path_timer = path_recalc_interval;
                }

                self.followPath(entity, walk_speed);
            },
            .flee => {
                // Move away from the player by targeting the mirror point.
                const flee_x = entity.x + (entity.x - player_x);
                const flee_z = entity.z + (entity.z - player_z);
                moveToward(entity, flee_x, flee_z, 2.5);
                if (self.state_timer <= 0) {
                    self.state = .idle;
                    self.state_timer = 3.0;
                    self.clearPath();
                }
            },
        }
    }

    /// Compute a path from the entity to the current target using A*.
    fn computePath(self: *AiBehavior, entity: *const Entity) void {
        const sx = @as(i32, @intFromFloat(@floor(entity.x)));
        const sy = @as(i32, @intFromFloat(@floor(entity.y)));
        const sz = @as(i32, @intFromFloat(@floor(entity.z)));
        const gx = @as(i32, @intFromFloat(@floor(self.target_x)));
        const gz = @as(i32, @intFromFloat(@floor(self.target_z)));

        const result = pathfinding.findPath(sx, sy, sz, gx, sy, gz);
        self.path = result.nodes;
        self.path_length = result.length;
        self.path_index = 0;
    }

    /// Walk toward the next node in the cached path. When a node is
    /// reached, advance to the following one.
    fn followPath(self: *AiBehavior, entity: *Entity, speed: f32) void {
        if (self.path_index >= self.path_length) {
            // Path exhausted; fall back to direct movement toward target.
            moveToward(entity, self.target_x, self.target_z, speed);
            return;
        }

        const node = self.path[self.path_index];
        // Target the center of the block.
        const nx: f32 = @as(f32, @floatFromInt(node.x)) + 0.5;
        const nz: f32 = @as(f32, @floatFromInt(node.z)) + 0.5;

        moveToward(entity, nx, nz, speed);

        // Check if the entity reached this node.
        const dx = nx - entity.x;
        const dz = nz - entity.z;
        if (dx * dx + dz * dz < 0.64) {
            self.path_index += 1;
        }
    }

    /// Returns true when the entire cached path has been walked.
    fn isPathComplete(self: *const AiBehavior) bool {
        return self.path_length == 0 or self.path_index >= self.path_length;
    }

    /// Reset the cached path to empty.
    fn clearPath(self: *AiBehavior) void {
        self.path_length = 0;
        self.path_index = 0;
        self.path_timer = 0;
    }
};

// -- Helpers --------------------------------------------------------------

const walk_speed: f32 = 2.0;
const path_recalc_interval: f32 = 2.0;

fn isHostile(entity_type: EntityType) bool {
    return switch (entity_type) {
        .zombie, .skeleton, .creeper => true,
        else => false,
    };
}

fn moveToward(entity: *Entity, tx: f32, tz: f32, speed: f32) void {
    const dx = tx - entity.x;
    const dz = tz - entity.z;
    const dist = @sqrt(dx * dx + dz * dz);
    if (dist > 0.001) {
        entity.vx = (dx / dist) * speed;
        entity.vz = (dz / dist) * speed;
        entity.yaw = std.math.atan2(dz, dx);
    }
}

/// Simple counter-based pseudo-random offset for wander targets.
/// Not cryptographically secure; sufficient for mob wandering variation.
var random_counter: u32 = 0;

fn randomOffset(radius: f32) f32 {
    random_counter +%= 7919;
    const t: f32 = @as(f32, @floatFromInt(random_counter % 1000)) / 1000.0;
    return (t - 0.5) * 2.0 * radius;
}

const AiParams = struct {
    wander_radius: f32,
    chase_range: f32,
    attack_range: f32,
};

fn getAiParams(entity_type: EntityType) AiParams {
    return switch (entity_type) {
        .zombie => .{ .wander_radius = 5, .chase_range = 16, .attack_range = 1.5 },
        .skeleton => .{ .wander_radius = 5, .chase_range = 16, .attack_range = 15 },
        .creeper => .{ .wander_radius = 4, .chase_range = 16, .attack_range = 3 },
        .pig, .cow, .sheep => .{ .wander_radius = 6, .chase_range = 0, .attack_range = 0 },
        .chicken => .{ .wander_radius = 4, .chase_range = 0, .attack_range = 0 },
        .player => .{ .wander_radius = 0, .chase_range = 0, .attack_range = 0 },
    };
}

// -------------------------------------------------------------------------
// Tests
// -------------------------------------------------------------------------

test "passive mob never chases" {
    var pig = Entity.init(.pig, 0, 0, 0);
    var ai = AiBehavior.init(.pig);

    // Player right next to the pig -- should never enter chase.
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        ai.update(&pig, 1, 0, 1, 0.1);
        try std.testing.expect(ai.state != .chase);
    }
}

test "hostile mob chases player in range" {
    var zombie = Entity.init(.zombie, 0, 0, 0);
    var ai = AiBehavior.init(.zombie);

    // Player at distance 5 (within chase_range of 16).
    ai.update(&zombie, 5, 0, 0, 0.1);
    try std.testing.expect(ai.state == .chase);
    // Velocity should be toward the player (positive vx).
    try std.testing.expect(zombie.vx > 0);
}

test "hostile mob stops chasing when player out of range" {
    var zombie = Entity.init(.zombie, 0, 0, 0);
    var ai = AiBehavior.init(.zombie);

    // Enter chase.
    ai.update(&zombie, 5, 0, 0, 0.1);
    try std.testing.expect(ai.state == .chase);

    // Move player far away.
    ai.update(&zombie, 100, 0, 100, 0.1);
    try std.testing.expect(ai.state != .chase);
}

test "wander changes entity velocity" {
    var cow = Entity.init(.cow, 0, 0, 0);
    var ai = AiBehavior.init(.cow);

    // Place directly into wander with a known far-away target and a path.
    ai.state = .wander;
    ai.state_timer = 5.0;
    ai.target_x = 10.0;
    ai.target_z = 10.0;
    ai.path[0] = .{ .x = 10, .y = 0, .z = 10 };
    ai.path_length = 1;
    ai.path_index = 0;

    ai.update(&cow, 100, 0, 100, 0.1);

    try std.testing.expect(ai.state == .wander);
    const speed_sq = cow.vx * cow.vx + cow.vz * cow.vz;
    try std.testing.expect(speed_sq > 0.001);
}

test "idle sets velocity to zero" {
    var pig = Entity.init(.pig, 0, 0, 0);
    var ai = AiBehavior.init(.pig);

    // Ensure we are in idle with time remaining.
    ai.state = .idle;
    ai.state_timer = 5.0;
    pig.vx = 3.0;
    pig.vz = 2.0;

    ai.update(&pig, 100, 0, 100, 0.1);

    try std.testing.expectApproxEqAbs(@as(f32, 0), pig.vx, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), pig.vz, 0.001);
}

test "ai init sets correct chase_range for hostile" {
    const ai = AiBehavior.init(.zombie);
    try std.testing.expectApproxEqAbs(@as(f32, 16), ai.chase_range, 0.001);
}

test "ai init sets zero chase_range for passive" {
    const ai = AiBehavior.init(.pig);
    try std.testing.expectApproxEqAbs(@as(f32, 0), ai.chase_range, 0.001);
}
