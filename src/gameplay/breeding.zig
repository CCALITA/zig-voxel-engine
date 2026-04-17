/// Animal breeding system.
/// Pairs of animals can be bred using specific feed items. After feeding,
/// a breeding timer counts down (default 300 s = 5 min) before a baby spawns.
/// Bred animals enter a cooldown period (also 300 s) during which they cannot
/// breed again.

const std = @import("std");

pub const BreedPair = struct {
    entity_type: u8,
    feed_item: u16,
};

pub const BREED_PAIRS = [_]BreedPair{
    .{ .entity_type = 4, .feed_item = 100 }, // cow + wheat
    .{ .entity_type = 7, .feed_item = 100 }, // sheep + wheat
    .{ .entity_type = 3, .feed_item = 101 }, // pig + carrot
    .{ .entity_type = 6, .feed_item = 102 }, // chicken + seeds
};

const BREED_TIMER: f32 = 300.0;
const COOLDOWN_TIMER: f32 = 300.0;

pub const BreedingEntry = struct {
    entity_a_id: u32,
    entity_b_id: u32,
    entity_type: u8,
    timer: f32,
    spawn_x: f32,
    spawn_y: f32,
    spawn_z: f32,
};

pub const BreedingManager = struct {
    entries: std.ArrayList(BreedingEntry),
    cooldowns: std.AutoHashMapUnmanaged(u32, f32),

    pub fn init() BreedingManager {
        return .{
            .entries = .empty,
            .cooldowns = .empty,
        };
    }

    pub fn deinit(self: *BreedingManager, allocator: std.mem.Allocator) void {
        self.entries.deinit(allocator);
        self.cooldowns.deinit(allocator);
    }

    /// Check whether a given entity type can breed using the supplied item.
    pub fn canBreed(entity_type: u8, item_id: u16) bool {
        for (BREED_PAIRS) |pair| {
            if (pair.entity_type == entity_type and pair.feed_item == item_id) {
                return true;
            }
        }
        return false;
    }

    fn isBreedable(entity_type: u8) bool {
        for (BREED_PAIRS) |pair| {
            if (pair.entity_type == entity_type) return true;
        }
        return false;
    }

    /// Returns true if the entity is currently on breeding cooldown.
    pub fn isOnCooldown(self: *const BreedingManager, entity_id: u32) bool {
        return self.cooldowns.get(entity_id) != null;
    }

    /// Attempt to start a breeding session between two entities.
    /// Returns true if breeding started, false if either entity is on cooldown
    /// or the entity type has no matching breed pair.
    pub fn tryBreed(
        self: *BreedingManager,
        allocator: std.mem.Allocator,
        entity_a: u32,
        entity_b: u32,
        entity_type: u8,
        x: f32,
        y: f32,
        z: f32,
    ) !bool {
        if (!isBreedable(entity_type)) return false;
        if (self.cooldowns.get(entity_a) != null) return false;
        if (self.cooldowns.get(entity_b) != null) return false;

        try self.entries.append(allocator, .{
            .entity_a_id = entity_a,
            .entity_b_id = entity_b,
            .entity_type = entity_type,
            .timer = BREED_TIMER,
            .spawn_x = x,
            .spawn_y = y,
            .spawn_z = z,
        });

        // Put both parents on cooldown.
        try self.cooldowns.put(allocator, entity_a, COOLDOWN_TIMER);
        try self.cooldowns.put(allocator, entity_b, COOLDOWN_TIMER);

        return true;
    }

    /// Advance all breeding timers and cooldowns by `dt` seconds.
    /// Returns a slice of entries whose timers have expired (ready to spawn).
    /// The caller must free the returned slice with `allocator.free`.
    pub fn update(self: *BreedingManager, allocator: std.mem.Allocator, dt: f32) ![]BreedingEntry {
        // Tick cooldowns and collect expired keys.
        var expired_keys = std.ArrayList(u32).empty;
        defer expired_keys.deinit(allocator);

        var cooldown_iter = self.cooldowns.iterator();
        while (cooldown_iter.next()) |entry| {
            entry.value_ptr.* -= dt;
            if (entry.value_ptr.* <= 0) {
                try expired_keys.append(allocator, entry.key_ptr.*);
            }
        }
        for (expired_keys.items) |key| {
            _ = self.cooldowns.remove(key);
        }

        // Tick breeding entries and collect spawns.
        var spawns = std.ArrayList(BreedingEntry).empty;
        errdefer spawns.deinit(allocator);

        var i: usize = 0;
        while (i < self.entries.items.len) {
            self.entries.items[i].timer -= dt;
            if (self.entries.items[i].timer <= 0) {
                try spawns.append(allocator, self.entries.orderedRemove(i));
            } else {
                i += 1;
            }
        }

        // Return owned slice; caller frees via allocator.free.
        return spawns.toOwnedSlice(allocator);
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "canBreed returns true for correct item" {
    try std.testing.expect(BreedingManager.canBreed(4, 100)); // cow + wheat
    try std.testing.expect(BreedingManager.canBreed(7, 100)); // sheep + wheat
    try std.testing.expect(BreedingManager.canBreed(3, 101)); // pig + carrot
    try std.testing.expect(BreedingManager.canBreed(6, 102)); // chicken + seeds
}

test "canBreed returns false for wrong item" {
    try std.testing.expect(!BreedingManager.canBreed(4, 101)); // cow + carrot
    try std.testing.expect(!BreedingManager.canBreed(99, 100)); // unknown entity
}

test "tryBreed starts timer and sets cooldown" {
    const allocator = std.testing.allocator;
    var bm = BreedingManager.init();
    defer bm.deinit(allocator);

    const ok = try bm.tryBreed(allocator, 1, 2, 4, 10.0, 64.0, 20.0);
    try std.testing.expect(ok);
    try std.testing.expectEqual(@as(usize, 1), bm.entries.items.len);
    try std.testing.expectEqual(@as(f32, 300.0), bm.entries.items[0].timer);

    // Both parents should be on cooldown.
    try std.testing.expect(bm.isOnCooldown(1));
    try std.testing.expect(bm.isOnCooldown(2));
}

test "cooldown prevents re-breed" {
    const allocator = std.testing.allocator;
    var bm = BreedingManager.init();
    defer bm.deinit(allocator);

    _ = try bm.tryBreed(allocator, 1, 2, 4, 0, 0, 0);
    const second = try bm.tryBreed(allocator, 1, 3, 4, 0, 0, 0);
    try std.testing.expect(!second);
}

test "tryBreed rejects unknown entity type" {
    const allocator = std.testing.allocator;
    var bm = BreedingManager.init();
    defer bm.deinit(allocator);

    const ok = try bm.tryBreed(allocator, 1, 2, 99, 0, 0, 0);
    try std.testing.expect(!ok);
}

test "update produces spawn after timer expires" {
    const allocator = std.testing.allocator;
    var bm = BreedingManager.init();
    defer bm.deinit(allocator);

    _ = try bm.tryBreed(allocator, 1, 2, 4, 5.0, 64.0, 10.0);

    // Advance past the full breed timer.
    const spawns = try bm.update(allocator, 301.0);
    defer allocator.free(spawns);

    try std.testing.expectEqual(@as(usize, 1), spawns.len);
    try std.testing.expectEqual(@as(u8, 4), spawns[0].entity_type);
    try std.testing.expectEqual(@as(f32, 5.0), spawns[0].spawn_x);
    try std.testing.expectEqual(@as(f32, 64.0), spawns[0].spawn_y);
    try std.testing.expectEqual(@as(f32, 10.0), spawns[0].spawn_z);

    // Entry should be removed from active list.
    try std.testing.expectEqual(@as(usize, 0), bm.entries.items.len);
}

test "update does not spawn before timer expires" {
    const allocator = std.testing.allocator;
    var bm = BreedingManager.init();
    defer bm.deinit(allocator);

    _ = try bm.tryBreed(allocator, 1, 2, 4, 0, 0, 0);

    const spawns = try bm.update(allocator, 100.0);
    defer allocator.free(spawns);

    try std.testing.expectEqual(@as(usize, 0), spawns.len);
    try std.testing.expectEqual(@as(usize, 1), bm.entries.items.len);
}

test "cooldown expires after timer" {
    const allocator = std.testing.allocator;
    var bm = BreedingManager.init();
    defer bm.deinit(allocator);

    _ = try bm.tryBreed(allocator, 1, 2, 4, 0, 0, 0);
    try std.testing.expect(bm.isOnCooldown(1));

    const spawns = try bm.update(allocator, 301.0);
    defer allocator.free(spawns);

    // Cooldown should have expired.
    try std.testing.expect(!bm.isOnCooldown(1));
    try std.testing.expect(!bm.isOnCooldown(2));
}
