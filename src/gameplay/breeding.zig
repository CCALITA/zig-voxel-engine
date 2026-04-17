/// BreedingManager: tracks breeding pairs with a cooldown timer.
/// When two compatible mobs are fed, a baby entity spawns after a short gestation.
const std = @import("std");

pub const EntityType = enum {
    pig,
    cow,
    chicken,
    sheep,
};

pub const BreedEntry = struct {
    entity_type: EntityType,
    spawn_x: f32,
    spawn_y: f32,
    spawn_z: f32,
    timer: f32,
};

const GESTATION_TIME: f32 = 5.0; // seconds until baby spawns

pub const BreedingManager = struct {
    pending: std.ArrayList(BreedEntry),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) BreedingManager {
        return .{
            .pending = .empty,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *BreedingManager) void {
        self.pending.deinit(self.allocator);
    }

    /// Returns true if the given entity type can breed (passive mob).
    pub fn canBreed(entity_type: EntityType) bool {
        return switch (entity_type) {
            .pig, .cow, .chicken, .sheep => true,
        };
    }

    /// Attempt to start breeding for two mobs of the same type at a position.
    /// Returns true if breeding was initiated, false if the type cannot breed.
    pub fn tryBreed(self: *BreedingManager, entity_type: EntityType, x: f32, y: f32, z: f32) bool {
        if (!canBreed(entity_type)) return false;

        self.pending.append(self.allocator, .{
            .entity_type = entity_type,
            .spawn_x = x,
            .spawn_y = y,
            .spawn_z = z,
            .timer = GESTATION_TIME,
        }) catch return false;

        return true;
    }

    /// Tick all pending breed entries. Returns a slice of entries whose timers
    /// have expired (ready to spawn). The caller must not store the returned
    /// slice past the next call to `update`.
    pub fn update(self: *BreedingManager, dt: f32) []const BreedEntry {
        var ready_count: usize = 0;
        var i: usize = 0;
        while (i < self.pending.items.len) {
            self.pending.items[i].timer -= dt;
            if (self.pending.items[i].timer <= 0) {
                if (i != ready_count) {
                    const tmp = self.pending.items[ready_count];
                    self.pending.items[ready_count] = self.pending.items[i];
                    self.pending.items[i] = tmp;
                }
                ready_count += 1;
            }
            i += 1;
        }

        const ready_slice = self.pending.items[0..ready_count];

        // Shift remaining entries down after removing ready ones.
        // The returned slice remains valid until the next append.
        if (ready_count > 0 and ready_count < self.pending.items.len) {
            const remaining = self.pending.items.len - ready_count;
            std.mem.copyForwards(
                BreedEntry,
                self.pending.items[0..remaining],
                self.pending.items[ready_count..self.pending.items.len],
            );
            self.pending.items.len = remaining;
        } else if (ready_count == self.pending.items.len) {
            self.pending.items.len = 0;
        }

        return ready_slice;
    }

    /// Number of pending breed entries.
    pub fn pendingCount(self: *const BreedingManager) usize {
        return self.pending.items.len;
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "init creates empty manager" {
    var mgr = BreedingManager.init(std.testing.allocator);
    defer mgr.deinit();

    try std.testing.expectEqual(@as(usize, 0), mgr.pendingCount());
}

test "canBreed returns true for passive mobs" {
    try std.testing.expect(BreedingManager.canBreed(.pig));
    try std.testing.expect(BreedingManager.canBreed(.cow));
    try std.testing.expect(BreedingManager.canBreed(.chicken));
    try std.testing.expect(BreedingManager.canBreed(.sheep));
}

test "tryBreed adds a pending entry" {
    var mgr = BreedingManager.init(std.testing.allocator);
    defer mgr.deinit();

    try std.testing.expect(mgr.tryBreed(.cow, 10.0, 65.0, 20.0));
    try std.testing.expectEqual(@as(usize, 1), mgr.pendingCount());
}

test "update ticks timers and returns ready entries" {
    var mgr = BreedingManager.init(std.testing.allocator);
    defer mgr.deinit();

    _ = mgr.tryBreed(.pig, 5.0, 70.0, 5.0);

    // Not ready yet after 2 seconds
    const ready1 = mgr.update(2.0);
    try std.testing.expectEqual(@as(usize, 0), ready1.len);
    try std.testing.expectEqual(@as(usize, 1), mgr.pendingCount());

    // Ready after 3 more seconds (total 5)
    const ready2 = mgr.update(3.5);
    try std.testing.expectEqual(@as(usize, 1), ready2.len);
    try std.testing.expectEqual(EntityType.pig, ready2[0].entity_type);
    try std.testing.expectEqual(@as(usize, 0), mgr.pendingCount());
}

test "update handles multiple entries at different stages" {
    var mgr = BreedingManager.init(std.testing.allocator);
    defer mgr.deinit();

    _ = mgr.tryBreed(.cow, 0, 0, 0);
    _ = mgr.tryBreed(.sheep, 10, 0, 10);

    // Advance 3 seconds
    _ = mgr.update(3.0);

    // Both still pending (need 5 seconds)
    try std.testing.expectEqual(@as(usize, 2), mgr.pendingCount());

    // Advance 2.5 more seconds - both should be ready
    const ready = mgr.update(2.5);
    try std.testing.expectEqual(@as(usize, 2), ready.len);
    try std.testing.expectEqual(@as(usize, 0), mgr.pendingCount());
}

test "deinit on empty manager" {
    var mgr = BreedingManager.init(std.testing.allocator);
    mgr.deinit();
}

test "tryBreed multiple same type" {
    var mgr = BreedingManager.init(std.testing.allocator);
    defer mgr.deinit();

    _ = mgr.tryBreed(.chicken, 0, 0, 0);
    _ = mgr.tryBreed(.chicken, 5, 0, 5);
    try std.testing.expectEqual(@as(usize, 2), mgr.pendingCount());
}
