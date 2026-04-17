/// Tile entity system for interactive blocks (chests, furnaces, signs, etc.).
/// Each tile entity is associated with a world position and carries type-specific data.
const std = @import("std");

pub const TileEntityType = enum {
    chest,
    furnace,
    sign,
    enchanting_table,
    brewing_stand,
};

/// Mirrors gameplay/inventory.Slot so this module stays dependency-free.
pub const Slot = struct {
    item: u16 = 0,
    count: u8 = 0,

    pub const empty = Slot{ .item = 0, .count = 0 };

    pub fn isEmpty(self: Slot) bool {
        return self.count == 0;
    }
};

pub const ChestData = struct {
    slots: [27]Slot,

    pub fn init() ChestData {
        return .{ .slots = .{Slot.empty} ** 27 };
    }
};

pub const SignData = struct {
    lines: [4][32]u8,
    line_lengths: [4]u8,

    pub fn init() SignData {
        return .{
            .lines = .{.{0} ** 32} ** 4,
            .line_lengths = .{0} ** 4,
        };
    }

    pub fn setLine(self: *SignData, line: u2, text: []const u8) void {
        const len: u8 = @intCast(@min(text.len, 32));
        @memcpy(self.lines[line][0..len], text[0..len]);
        self.line_lengths[line] = len;
    }

    pub fn getLine(self: *const SignData, line: u2) []const u8 {
        const len = self.line_lengths[line];
        return self.lines[line][0..len];
    }
};

pub const TileEntityData = union(TileEntityType) {
    chest: ChestData,
    furnace: void,
    sign: SignData,
    enchanting_table: void,
    brewing_stand: void,
};

pub const TileEntity = struct {
    x: i32,
    y: i32,
    z: i32,
    data: TileEntityData,
};

pub const TileEntityManager = struct {
    entities: std.ArrayList(TileEntity),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) TileEntityManager {
        return .{
            .entities = .empty,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *TileEntityManager) void {
        self.entities.deinit(self.allocator);
    }

    pub fn add(self: *TileEntityManager, te: TileEntity) !void {
        try self.entities.append(self.allocator, te);
    }

    pub fn remove(self: *TileEntityManager, x: i32, y: i32, z: i32) ?TileEntity {
        for (self.entities.items, 0..) |te, i| {
            if (te.x == x and te.y == y and te.z == z) {
                return self.entities.orderedRemove(i);
            }
        }
        return null;
    }

    pub fn get(self: *TileEntityManager, x: i32, y: i32, z: i32) ?*TileEntity {
        for (self.entities.items) |*te| {
            if (te.x == x and te.y == y and te.z == z) {
                return te;
            }
        }
        return null;
    }

    pub fn count(self: *const TileEntityManager) usize {
        return self.entities.items.len;
    }
};

// --- Tests ---

test "add and get tile entity" {
    var mgr = TileEntityManager.init(std.testing.allocator);
    defer mgr.deinit();

    try mgr.add(.{ .x = 1, .y = 2, .z = 3, .data = .{ .furnace = {} } });
    const te = mgr.get(1, 2, 3);
    try std.testing.expect(te != null);
    try std.testing.expectEqual(@as(i32, 1), te.?.x);
    try std.testing.expectEqual(@as(i32, 2), te.?.y);
    try std.testing.expectEqual(@as(i32, 3), te.?.z);
}

test "get returns null for missing entity" {
    var mgr = TileEntityManager.init(std.testing.allocator);
    defer mgr.deinit();

    try std.testing.expectEqual(@as(?*TileEntity, null), mgr.get(0, 0, 0));
}

test "remove tile entity" {
    var mgr = TileEntityManager.init(std.testing.allocator);
    defer mgr.deinit();

    try mgr.add(.{ .x = 5, .y = 6, .z = 7, .data = .{ .brewing_stand = {} } });
    try std.testing.expectEqual(@as(usize, 1), mgr.count());

    const removed = mgr.remove(5, 6, 7);
    try std.testing.expect(removed != null);
    try std.testing.expectEqual(@as(usize, 0), mgr.count());
}

test "remove returns null for missing entity" {
    var mgr = TileEntityManager.init(std.testing.allocator);
    defer mgr.deinit();

    try std.testing.expectEqual(@as(?TileEntity, null), mgr.remove(0, 0, 0));
}

test "manager count" {
    var mgr = TileEntityManager.init(std.testing.allocator);
    defer mgr.deinit();

    try std.testing.expectEqual(@as(usize, 0), mgr.count());
    try mgr.add(.{ .x = 0, .y = 0, .z = 0, .data = .{ .enchanting_table = {} } });
    try std.testing.expectEqual(@as(usize, 1), mgr.count());
    try mgr.add(.{ .x = 1, .y = 0, .z = 0, .data = .{ .furnace = {} } });
    try std.testing.expectEqual(@as(usize, 2), mgr.count());
}

test "chest inventory" {
    var mgr = TileEntityManager.init(std.testing.allocator);
    defer mgr.deinit();

    try mgr.add(.{ .x = 10, .y = 20, .z = 30, .data = .{ .chest = ChestData.init() } });
    const te = mgr.get(10, 20, 30).?;
    var chest = &te.data.chest;

    // Initially all slots are empty
    try std.testing.expect(chest.slots[0].isEmpty());

    // Place an item in a slot
    chest.slots[0] = .{ .item = 42, .count = 16 };
    try std.testing.expectEqual(@as(u16, 42), chest.slots[0].item);
    try std.testing.expectEqual(@as(u8, 16), chest.slots[0].count);

    // Other slots remain empty
    try std.testing.expect(chest.slots[26].isEmpty());
}

test "sign text" {
    var sign = SignData.init();

    // Initially all lines are empty
    try std.testing.expectEqual(@as(usize, 0), sign.getLine(0).len);

    // Set and read lines
    sign.setLine(0, "Hello");
    sign.setLine(1, "World");
    try std.testing.expectEqualStrings("Hello", sign.getLine(0));
    try std.testing.expectEqualStrings("World", sign.getLine(1));
    try std.testing.expectEqual(@as(usize, 0), sign.getLine(2).len);

    // Overwrite a line
    sign.setLine(0, "Hi");
    try std.testing.expectEqualStrings("Hi", sign.getLine(0));
}

test "sign text truncation" {
    var sign = SignData.init();

    // Text longer than 32 chars should be truncated
    const long_text = "ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890";
    sign.setLine(0, long_text);
    try std.testing.expectEqual(@as(usize, 32), sign.getLine(0).len);
    try std.testing.expectEqualStrings("ABCDEFGHIJKLMNOPQRSTUVWXYZ123456", sign.getLine(0));
}
