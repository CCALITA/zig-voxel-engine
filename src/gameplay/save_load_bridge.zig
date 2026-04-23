/// Save/Load Bridge: combines world_save_system (player data) and
/// inventory_persistence (inventory + armor) into a single 248-byte
/// save format.  First 128 bytes = player data, next 120 bytes = inventory.
const std = @import("std");
const ws = @import("world_save_system.zig");
const ip = @import("inventory_persistence.zig");

pub const Slot = struct {
    item: u16 = 0,
    count: u8 = 0,

    pub const empty = Slot{};

    pub fn isEmpty(s: Slot) bool {
        return s.count == 0;
    }
};

const player_region = 128;
const inv_region = ip.serialized_len; // 120
pub const save_size = player_region + inv_region; // 248

pub const LoadResult = struct {
    player: ws.PlayerSaveData,
    inv: [36]Slot,
    armor: [4]Slot,
};

fn toBridgeSlot(s: ip.Slot) Slot {
    return .{ .item = s.item, .count = s.count };
}

fn toIpSlot(s: Slot) ip.Slot {
    return .{ .item = s.item, .count = s.count };
}

fn toBridgeSlots(comptime n: usize, src: [n]ip.Slot) [n]Slot {
    var dst: [n]Slot = undefined;
    for (0..n) |i| {
        dst[i] = toBridgeSlot(src[i]);
    }
    return dst;
}

fn toIpSlots(comptime n: usize, src: [n]Slot) [n]ip.Slot {
    var dst: [n]ip.Slot = undefined;
    for (0..n) |i| {
        dst[i] = toIpSlot(src[i]);
    }
    return dst;
}

/// Serialize player data + inventory into a single 248-byte buffer.
pub fn saveGame(data: ws.PlayerSaveData, inv: [36]Slot, armor: [4]Slot) [save_size]u8 {
    const player_bytes = ws.serialize(data);
    const inv_bytes = ip.serializeInventory(toIpSlots(36, inv), toIpSlots(4, armor));

    var buf: [save_size]u8 = undefined;
    @memcpy(buf[0..player_region], &player_bytes);
    @memcpy(buf[player_region..], &inv_bytes);
    return buf;
}

/// Deserialize a 248-byte buffer back into player data + inventory.
pub fn loadGame(bytes: [save_size]u8) LoadResult {
    const player = ws.deserialize(bytes[0..player_region].*);
    const inv_data = ip.deserializeInventory(bytes[player_region..].*);

    return .{
        .player = player,
        .inv = toBridgeSlots(36, inv_data.inv),
        .armor = toBridgeSlots(4, inv_data.armor),
    };
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

fn emptyInv() [36]Slot {
    return [_]Slot{Slot.empty} ** 36;
}

fn emptyArmor() [4]Slot {
    return [_]Slot{Slot.empty} ** 4;
}

fn makeSlot(item: u16, count: u8) Slot {
    return .{ .item = item, .count = count };
}

fn defaultPlayer() ws.PlayerSaveData {
    return .{ .x = 0, .y = 0, .z = 0 };
}

// ---------------------------------------------------------------------------
// Tests (10+)
// ---------------------------------------------------------------------------

test "save_size is 248 bytes" {
    try std.testing.expectEqual(@as(usize, 248), save_size);
}

test "round-trip default player with empty inventory" {
    const player = defaultPlayer();
    const inv = emptyInv();
    const armor = emptyArmor();
    const result = loadGame(saveGame(player, inv, armor));
    try std.testing.expectEqual(player, result.player);
    for (0..36) |i| {
        try std.testing.expect(result.inv[i].isEmpty());
    }
    for (0..4) |i| {
        try std.testing.expect(result.armor[i].isEmpty());
    }
}

test "round-trip player with custom position and health" {
    const player = ws.PlayerSaveData{
        .x = -100.5,
        .y = 64.0,
        .z = 200.75,
        .health = 10,
        .hunger = 5,
    };
    const result = loadGame(saveGame(player, emptyInv(), emptyArmor()));
    try std.testing.expectEqual(player.x, result.player.x);
    try std.testing.expectEqual(player.y, result.player.y);
    try std.testing.expectEqual(player.z, result.player.z);
    try std.testing.expectEqual(@as(u8, 10), result.player.health);
    try std.testing.expectEqual(@as(u8, 5), result.player.hunger);
}

test "round-trip fully populated player data" {
    const player = ws.PlayerSaveData{
        .x = -100.25,
        .y = 64.0,
        .z = 200.75,
        .health = 10,
        .hunger = 5,
        .xp = 12345,
        .xp_level = 30,
        .dimension = 1,
        .game_time = 1_000_000,
        .difficulty = 3,
        .spawn_x = -50,
        .spawn_y = 70,
        .spawn_z = 100,
    };
    const result = loadGame(saveGame(player, emptyInv(), emptyArmor()));
    try std.testing.expectEqual(player, result.player);
}

test "round-trip single inventory slot" {
    var inv = emptyInv();
    inv[0] = makeSlot(42, 64);
    const result = loadGame(saveGame(defaultPlayer(), inv, emptyArmor()));
    try std.testing.expectEqual(@as(u16, 42), result.inv[0].item);
    try std.testing.expectEqual(@as(u8, 64), result.inv[0].count);
    try std.testing.expect(result.inv[1].isEmpty());
}

test "round-trip single armor slot" {
    var armor = emptyArmor();
    armor[2] = makeSlot(310, 1);
    const result = loadGame(saveGame(defaultPlayer(), emptyInv(), armor));
    try std.testing.expectEqual(@as(u16, 310), result.armor[2].item);
    try std.testing.expectEqual(@as(u8, 1), result.armor[2].count);
    try std.testing.expect(result.armor[0].isEmpty());
}

test "round-trip all 36 inventory slots populated" {
    var inv: [36]Slot = undefined;
    for (0..36) |i| {
        inv[i] = makeSlot(@intCast(i + 1), @intCast(i + 10));
    }
    const result = loadGame(saveGame(defaultPlayer(), inv, emptyArmor()));
    for (0..36) |i| {
        try std.testing.expectEqual(inv[i].item, result.inv[i].item);
        try std.testing.expectEqual(inv[i].count, result.inv[i].count);
    }
}

test "round-trip all 4 armor slots populated" {
    var armor: [4]Slot = undefined;
    for (0..4) |i| {
        armor[i] = makeSlot(@intCast(300 + i), @intCast(i + 1));
    }
    const result = loadGame(saveGame(defaultPlayer(), emptyInv(), armor));
    for (0..4) |i| {
        try std.testing.expectEqual(armor[i].item, result.armor[i].item);
        try std.testing.expectEqual(armor[i].count, result.armor[i].count);
    }
}

test "round-trip combined player, inventory, and armor" {
    const player = ws.PlayerSaveData{
        .x = 1.5,
        .y = -42.0,
        .z = 999.125,
        .health = 15,
        .hunger = 18,
        .xp = 500,
        .xp_level = 10,
        .dimension = 2,
        .game_time = 72000,
        .difficulty = 1,
        .spawn_x = 100,
        .spawn_y = 80,
        .spawn_z = -200,
    };
    var inv = emptyInv();
    inv[0] = makeSlot(256, 32);
    inv[17] = makeSlot(512, 1);
    inv[35] = makeSlot(1000, 64);
    var armor = emptyArmor();
    armor[0] = makeSlot(310, 1);
    armor[1] = makeSlot(311, 1);
    armor[2] = makeSlot(312, 1);
    armor[3] = makeSlot(313, 1);

    const result = loadGame(saveGame(player, inv, armor));
    try std.testing.expectEqual(player, result.player);
    try std.testing.expectEqual(@as(u16, 256), result.inv[0].item);
    try std.testing.expectEqual(@as(u16, 512), result.inv[17].item);
    try std.testing.expectEqual(@as(u16, 1000), result.inv[35].item);
    try std.testing.expect(result.inv[1].isEmpty());
    for (0..4) |i| {
        try std.testing.expect(!result.armor[i].isEmpty());
    }
}

test "round-trip max-value inventory slot" {
    var inv = emptyInv();
    inv[0] = makeSlot(0xFFFF, 255);
    const result = loadGame(saveGame(defaultPlayer(), inv, emptyArmor()));
    try std.testing.expectEqual(@as(u16, 0xFFFF), result.inv[0].item);
    try std.testing.expectEqual(@as(u8, 255), result.inv[0].count);
}

test "Slot.isEmpty returns true for empty, false for occupied" {
    try std.testing.expect(Slot.empty.isEmpty());
    try std.testing.expect(!makeSlot(1, 1).isEmpty());
    // A slot with item ID but zero count is still considered empty
    const zero_count = Slot{ .item = 42, .count = 0 };
    try std.testing.expect(zero_count.isEmpty());
}

test "player region bytes are independent of inventory region" {
    const player = ws.PlayerSaveData{
        .x = 1.0,
        .y = 2.0,
        .z = 3.0,
        .health = 20,
        .hunger = 20,
    };
    const buf_empty = saveGame(player, emptyInv(), emptyArmor());
    var inv = emptyInv();
    inv[0] = makeSlot(999, 64);
    const buf_with_inv = saveGame(player, inv, emptyArmor());

    // First 128 bytes (player region) should be identical
    for (0..player_region) |i| {
        try std.testing.expectEqual(buf_empty[i], buf_with_inv[i]);
    }
    // Inventory region should differ
    var differs = false;
    for (player_region..save_size) |i| {
        if (buf_empty[i] != buf_with_inv[i]) {
            differs = true;
            break;
        }
    }
    try std.testing.expect(differs);
}

test "all-zero bytes deserialize to defaults" {
    const bytes = [_]u8{0} ** save_size;
    const result = loadGame(bytes);
    try std.testing.expectEqual(@as(f32, 0), result.player.x);
    try std.testing.expectEqual(@as(f32, 0), result.player.y);
    try std.testing.expectEqual(@as(f32, 0), result.player.z);
    for (0..36) |i| {
        try std.testing.expect(result.inv[i].isEmpty());
    }
    for (0..4) |i| {
        try std.testing.expect(result.armor[i].isEmpty());
    }
}
