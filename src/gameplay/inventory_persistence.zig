/// Inventory persistence: serialize and deserialize 36 inventory + 4 armor slots
/// to a compact 120-byte binary format (3 bytes per slot: 2 LE for item u16, 1 for count u8).

const std = @import("std");

pub const Slot = struct {
    item: u16,
    count: u8,

    pub const empty = Slot{ .item = 0, .count = 0 };

    pub fn eql(a: Slot, b: Slot) bool {
        return a.item == b.item and a.count == b.count;
    }
};

const bytes_per_slot = 3;
const inv_len = 36;
const armor_len = 4;
const total_slots = inv_len + armor_len;
pub const serialized_len = total_slots * bytes_per_slot; // 120

pub const InventoryData = struct {
    inv: [inv_len]Slot,
    armor: [armor_len]Slot,
};

fn writeSlots(buf: []u8, slots: []const Slot) void {
    for (slots, 0..) |slot, i| {
        const off = i * bytes_per_slot;
        std.mem.writeInt(u16, buf[off..][0..2], slot.item, .little);
        buf[off + 2] = slot.count;
    }
}

fn readSlots(bytes: []const u8, comptime n: usize) [n]Slot {
    var slots: [n]Slot = undefined;
    for (0..n) |i| {
        const off = i * bytes_per_slot;
        slots[i] = .{
            .item = std.mem.readInt(u16, bytes[off..][0..2], .little),
            .count = bytes[off + 2],
        };
    }
    return slots;
}

pub fn serializeInventory(inv: [inv_len]Slot, armor: [armor_len]Slot) [serialized_len]u8 {
    var buf: [serialized_len]u8 = undefined;
    writeSlots(&buf, &inv);
    writeSlots(buf[inv_len * bytes_per_slot ..], &armor);
    return buf;
}

pub fn deserializeInventory(bytes: [serialized_len]u8) InventoryData {
    return .{
        .inv = readSlots(&bytes, inv_len),
        .armor = readSlots(bytes[inv_len * bytes_per_slot ..], armor_len),
    };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

fn makeSlot(item: u16, count: u8) Slot {
    return .{ .item = item, .count = count };
}

fn emptyInv() [inv_len]Slot {
    return [_]Slot{Slot.empty} ** inv_len;
}

fn emptyArmor() [armor_len]Slot {
    return [_]Slot{Slot.empty} ** armor_len;
}

test "round-trip all empty slots" {
    const inv = emptyInv();
    const armor = emptyArmor();
    const bytes = serializeInventory(inv, armor);
    const result = deserializeInventory(bytes);
    for (0..inv_len) |i| {
        try std.testing.expect(result.inv[i].eql(Slot.empty));
    }
    for (0..armor_len) |i| {
        try std.testing.expect(result.armor[i].eql(Slot.empty));
    }
}

test "round-trip single inventory slot" {
    var inv = emptyInv();
    inv[0] = makeSlot(42, 64);
    const armor = emptyArmor();
    const result = deserializeInventory(serializeInventory(inv, armor));
    try std.testing.expect(result.inv[0].eql(makeSlot(42, 64)));
    try std.testing.expect(result.inv[1].eql(Slot.empty));
}

test "round-trip single armor slot" {
    const inv = emptyInv();
    var armor = emptyArmor();
    armor[2] = makeSlot(310, 1);
    const result = deserializeInventory(serializeInventory(inv, armor));
    try std.testing.expect(result.armor[2].eql(makeSlot(310, 1)));
    try std.testing.expect(result.armor[0].eql(Slot.empty));
}

test "round-trip all slots populated" {
    var inv: [inv_len]Slot = undefined;
    for (0..inv_len) |i| {
        inv[i] = makeSlot(@intCast(i + 1), @intCast(i + 10));
    }
    var armor: [armor_len]Slot = undefined;
    for (0..armor_len) |i| {
        armor[i] = makeSlot(@intCast(300 + i), @intCast(i + 1));
    }
    const result = deserializeInventory(serializeInventory(inv, armor));
    for (0..inv_len) |i| {
        try std.testing.expect(result.inv[i].eql(inv[i]));
    }
    for (0..armor_len) |i| {
        try std.testing.expect(result.armor[i].eql(armor[i]));
    }
}

test "serialized length is 120 bytes" {
    try std.testing.expectEqual(@as(usize, 120), serialized_len);
}

test "item u16 max value round-trips" {
    var inv = emptyInv();
    inv[35] = makeSlot(0xFFFF, 255);
    const armor = emptyArmor();
    const result = deserializeInventory(serializeInventory(inv, armor));
    try std.testing.expectEqual(@as(u16, 0xFFFF), result.inv[35].item);
    try std.testing.expectEqual(@as(u8, 255), result.inv[35].count);
}

test "count u8 max value round-trips" {
    var inv = emptyInv();
    inv[0] = makeSlot(1, 255);
    const result = deserializeInventory(serializeInventory(inv, emptyArmor()));
    try std.testing.expectEqual(@as(u8, 255), result.inv[0].count);
}

test "little-endian byte order" {
    var inv = emptyInv();
    inv[0] = makeSlot(0x0102, 5);
    const bytes = serializeInventory(inv, emptyArmor());
    // LE: low byte first
    try std.testing.expectEqual(@as(u8, 0x02), bytes[0]);
    try std.testing.expectEqual(@as(u8, 0x01), bytes[1]);
    try std.testing.expectEqual(@as(u8, 5), bytes[2]);
}

test "armor starts at byte offset 108" {
    const inv = emptyInv();
    var armor = emptyArmor();
    armor[0] = makeSlot(0xABCD, 3);
    const bytes = serializeInventory(inv, armor);
    const offset = inv_len * bytes_per_slot; // 108
    try std.testing.expectEqual(@as(u8, 0xCD), bytes[offset]);
    try std.testing.expectEqual(@as(u8, 0xAB), bytes[offset + 1]);
    try std.testing.expectEqual(@as(u8, 3), bytes[offset + 2]);
}

test "all-zero bytes deserialize to empty slots" {
    const bytes = [_]u8{0} ** serialized_len;
    const result = deserializeInventory(bytes);
    for (0..inv_len) |i| {
        try std.testing.expect(result.inv[i].eql(Slot.empty));
    }
    for (0..armor_len) |i| {
        try std.testing.expect(result.armor[i].eql(Slot.empty));
    }
}

test "Slot.empty has zero item and count" {
    try std.testing.expectEqual(@as(u16, 0), Slot.empty.item);
    try std.testing.expectEqual(@as(u8, 0), Slot.empty.count);
}

test "slot equality" {
    const a = makeSlot(10, 5);
    const b = makeSlot(10, 5);
    const c = makeSlot(10, 6);
    try std.testing.expect(a.eql(b));
    try std.testing.expect(!a.eql(c));
}

test "mixed inventory with sparse population round-trips" {
    var inv = emptyInv();
    inv[0] = makeSlot(256, 32);
    inv[17] = makeSlot(512, 1);
    inv[35] = makeSlot(1000, 64);
    var armor = emptyArmor();
    armor[1] = makeSlot(311, 1);
    armor[3] = makeSlot(313, 1);
    const result = deserializeInventory(serializeInventory(inv, armor));
    try std.testing.expect(result.inv[0].eql(makeSlot(256, 32)));
    try std.testing.expect(result.inv[17].eql(makeSlot(512, 1)));
    try std.testing.expect(result.inv[35].eql(makeSlot(1000, 64)));
    try std.testing.expect(result.inv[1].eql(Slot.empty));
    try std.testing.expect(result.armor[1].eql(makeSlot(311, 1)));
    try std.testing.expect(result.armor[3].eql(makeSlot(313, 1)));
    try std.testing.expect(result.armor[0].eql(Slot.empty));
}
