const std = @import("std");

pub const AllayState = enum {
    idle,
    searching,
    collecting,
    delivering,
    dancing,
};

pub const DeliveryResult = struct {
    item: u16,
    count: u8,
};

pub const AllayEntity = struct {
    x: f32,
    y: f32,
    z: f32,
    health: f32 = 20.0,
    held_item: ?u16 = null,
    held_count: u8 = 0,
    target_item: u16 = 0,
    deliver_x: ?i32 = null,
    deliver_y: ?i32 = null,
    deliver_z: ?i32 = null,
    dancing: bool = false,
    dance_timer: f32 = 0.0,
    can_duplicate: bool = true,
    duplication_cooldown: f32 = 0.0,
    state: AllayState = .idle,

    const dance_duplication_threshold: f32 = 150.0; // 2.5 minutes in seconds
    const duplication_cooldown_duration: f32 = 300.0; // 5 minutes in seconds

    pub fn init(x: f32, y: f32, z: f32) AllayEntity {
        return AllayEntity{
            .x = x,
            .y = y,
            .z = z,
        };
    }

    pub fn giveItem(self: *AllayEntity, item_id: u16) void {
        self.target_item = item_id;
        if (self.state == .idle) {
            self.state = .searching;
        }
    }

    pub fn setDeliveryPoint(self: *AllayEntity, x: i32, y: i32, z: i32) void {
        self.deliver_x = x;
        self.deliver_y = y;
        self.deliver_z = z;
    }

    /// Only picks up items matching the current target_item.
    pub fn pickUp(self: *AllayEntity, item_id: u16, count: u8) bool {
        if (item_id != self.target_item) {
            return false;
        }
        if (self.held_item != null and self.held_item.? != item_id) {
            return false;
        }
        self.held_item = item_id;
        self.held_count +|= count;
        self.state = if (self.deliver_x != null) .delivering else .collecting;
        return true;
    }

    /// Returns held items and clears inventory, or null if nothing held.
    pub fn deliver(self: *AllayEntity) ?DeliveryResult {
        const item = self.held_item orelse return null;
        if (self.held_count == 0) {
            return null;
        }
        const result = DeliveryResult{
            .item = item,
            .count = self.held_count,
        };
        self.held_item = null;
        self.held_count = 0;
        self.state = .searching;
        return result;
    }

    /// Enters the dancing state; duplication triggers after 2.5 minutes
    /// if can_duplicate is true and cooldown has expired.
    pub fn startDancing(self: *AllayEntity) void {
        self.dancing = true;
        self.dance_timer = 0.0;
        self.state = .dancing;
    }

    pub fn update(self: *AllayEntity, dt: f32) void {
        if (self.duplication_cooldown > 0.0) {
            self.duplication_cooldown = @max(self.duplication_cooldown - dt, 0.0);
        }

        if (self.dancing) {
            self.dance_timer += dt;
            if (self.dance_timer >= dance_duplication_threshold and
                self.can_duplicate and
                self.duplication_cooldown <= 0.0)
            {
                self.can_duplicate = false;
                self.duplication_cooldown = duplication_cooldown_duration;
            }
        }
    }
};

test "item matching - pickUp only accepts matching target_item" {
    var allay = AllayEntity.init(0, 0, 0);
    allay.giveItem(42);

    // Non-matching item is rejected
    try std.testing.expect(!allay.pickUp(99, 1));
    try std.testing.expect(allay.held_item == null);
    try std.testing.expectEqual(@as(u8, 0), allay.held_count);

    // Matching item is accepted
    try std.testing.expect(allay.pickUp(42, 5));
    try std.testing.expectEqual(@as(?u16, 42), allay.held_item);
    try std.testing.expectEqual(@as(u8, 5), allay.held_count);
}

test "item matching - pickUp stacks matching items" {
    var allay = AllayEntity.init(0, 0, 0);
    allay.giveItem(10);

    try std.testing.expect(allay.pickUp(10, 3));
    try std.testing.expect(allay.pickUp(10, 7));
    try std.testing.expectEqual(@as(u8, 10), allay.held_count);
}

test "delivery - deliver returns held items and resets state" {
    var allay = AllayEntity.init(0, 0, 0);
    allay.giveItem(42);
    allay.setDeliveryPoint(10, 20, 30);
    _ = allay.pickUp(42, 8);

    const result = allay.deliver();
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(u16, 42), result.?.item);
    try std.testing.expectEqual(@as(u8, 8), result.?.count);

    // After delivery, held items are cleared
    try std.testing.expect(allay.held_item == null);
    try std.testing.expectEqual(@as(u8, 0), allay.held_count);
}

test "delivery - deliver returns null when nothing held" {
    var allay = AllayEntity.init(0, 0, 0);
    const result = allay.deliver();
    try std.testing.expect(result == null);
}

test "dancing duplication - triggers after 2.5 minutes" {
    var allay = AllayEntity.init(0, 0, 0);
    allay.startDancing();

    try std.testing.expect(allay.dancing);
    try std.testing.expect(allay.can_duplicate);

    // Advance time to just under 2.5 minutes
    allay.update(149.0);
    try std.testing.expect(allay.can_duplicate);

    // Cross the 2.5-minute threshold
    allay.update(2.0);
    try std.testing.expect(!allay.can_duplicate);
    try std.testing.expect(allay.duplication_cooldown > 0.0);
}

test "dancing duplication - respects cooldown" {
    var allay = AllayEntity.init(0, 0, 0);
    allay.can_duplicate = false;
    allay.duplication_cooldown = 100.0;
    allay.startDancing();

    // Even after enough dance time, duplication does not trigger during cooldown
    allay.update(200.0);
    try std.testing.expect(!allay.can_duplicate);
}

test "state transitions - idle to searching on giveItem" {
    var allay = AllayEntity.init(0, 0, 0);
    try std.testing.expectEqual(AllayState.idle, allay.state);

    allay.giveItem(5);
    try std.testing.expectEqual(AllayState.searching, allay.state);
}

test "state transitions - collecting to delivering when delivery point set" {
    var allay = AllayEntity.init(0, 0, 0);
    allay.giveItem(5);
    allay.setDeliveryPoint(1, 2, 3);

    _ = allay.pickUp(5, 1);
    try std.testing.expectEqual(AllayState.delivering, allay.state);
}

test "state transitions - collecting without delivery point" {
    var allay = AllayEntity.init(0, 0, 0);
    allay.giveItem(5);

    _ = allay.pickUp(5, 1);
    try std.testing.expectEqual(AllayState.collecting, allay.state);
}

test "state transitions - delivering to searching after deliver" {
    var allay = AllayEntity.init(0, 0, 0);
    allay.giveItem(5);
    allay.setDeliveryPoint(1, 2, 3);
    _ = allay.pickUp(5, 3);

    _ = allay.deliver();
    try std.testing.expectEqual(AllayState.searching, allay.state);
}

test "state transitions - dancing state on startDancing" {
    var allay = AllayEntity.init(0, 0, 0);
    allay.startDancing();
    try std.testing.expectEqual(AllayState.dancing, allay.state);
}

test "setDeliveryPoint stores coordinates" {
    var allay = AllayEntity.init(0, 0, 0);
    allay.setDeliveryPoint(100, -64, 200);

    try std.testing.expectEqual(@as(?i32, 100), allay.deliver_x);
    try std.testing.expectEqual(@as(?i32, -64), allay.deliver_y);
    try std.testing.expectEqual(@as(?i32, 200), allay.deliver_z);
}

test "default values are correct" {
    const allay = AllayEntity.init(1.0, 2.0, 3.0);
    try std.testing.expectEqual(@as(f32, 1.0), allay.x);
    try std.testing.expectEqual(@as(f32, 2.0), allay.y);
    try std.testing.expectEqual(@as(f32, 3.0), allay.z);
    try std.testing.expectEqual(@as(f32, 20.0), allay.health);
    try std.testing.expect(allay.held_item == null);
    try std.testing.expectEqual(@as(u8, 0), allay.held_count);
    try std.testing.expect(!allay.dancing);
    try std.testing.expect(allay.can_duplicate);
    try std.testing.expectEqual(AllayState.idle, allay.state);
}
