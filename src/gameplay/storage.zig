/// Storage containers: chests, barrels, shulker boxes, ender chests.
const std = @import("std");

pub const ContainerType = enum {
    chest,
    double_chest,
    barrel,
    shulker_box,
    ender_chest,
};

pub const CHEST_SLOTS: u8 = 27;
pub const DOUBLE_CHEST_SLOTS: u8 = 54;
pub const BARREL_SLOTS: u8 = 27;
pub const SHULKER_SLOTS: u8 = 27;
pub const ENDER_CHEST_SLOTS: u8 = 27;

pub fn getSlotCount(container: ContainerType) u8 {
    return switch (container) {
        .chest => CHEST_SLOTS,
        .double_chest => DOUBLE_CHEST_SLOTS,
        .barrel => BARREL_SLOTS,
        .shulker_box => SHULKER_SLOTS,
        .ender_chest => ENDER_CHEST_SLOTS,
    };
}

pub const ContainerState = struct {
    container_type: ContainerType,
    is_open: bool,

    pub fn init(ctype: ContainerType) ContainerState {
        return .{
            .container_type = ctype,
            .is_open = false,
        };
    }

    pub fn open(self: *ContainerState) void {
        self.is_open = true;
    }

    pub fn close(self: *ContainerState) void {
        self.is_open = false;
    }
};

test "chest has 27 slots" {
    try std.testing.expectEqual(@as(u8, 27), getSlotCount(.chest));
}

test "double chest has 54 slots" {
    try std.testing.expectEqual(@as(u8, 54), getSlotCount(.double_chest));
}

test "container open close" {
    var c = ContainerState.init(.barrel);
    try std.testing.expect(!c.is_open);
    c.open();
    try std.testing.expect(c.is_open);
    c.close();
    try std.testing.expect(!c.is_open);
}
