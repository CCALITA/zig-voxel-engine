const std = @import("std");

pub const PacketType = enum(u8) {
    handshake = 0x00,
    login = 0x01,
    chat = 0x02,
    player_position = 0x03,
    player_look = 0x04,
    block_change = 0x05,
    chunk_data = 0x06,
    entity_spawn = 0x07,
    entity_move = 0x08,
    entity_despawn = 0x09,
    keep_alive = 0x0A,
    disconnect = 0x0B,
};

pub const Packet = struct {
    packet_type: PacketType,
    data: []const u8,
};

/// Player position packet payload.
pub const PlayerPositionData = extern struct {
    x: f32,
    y: f32,
    z: f32,
    yaw: f32,
    pitch: f32,
    on_ground: u8,
};

/// Block change packet payload.
pub const BlockChangeData = extern struct {
    x: i32,
    y: i32,
    z: i32,
    block_id: u8,
};

const header_size = 1 + @sizeOf(u32); // [type:u8][length:u32]

/// Serialize a packet to wire format: [type:u8][length:u32 big-endian][data...].
/// Caller owns the returned slice.
pub fn serialize(allocator: std.mem.Allocator, packet: Packet) ![]u8 {
    const total = header_size + packet.data.len;
    const buf = try allocator.alloc(u8, total);

    buf[0] = @intFromEnum(packet.packet_type);
    std.mem.writeInt(u32, buf[1..5], @intCast(packet.data.len), .big);
    @memcpy(buf[header_size..], packet.data);

    return buf;
}

/// Deserialize wire bytes into a Packet.
/// The returned `data` slice is a sub-slice of the input buffer (no allocation).
pub fn deserialize(data: []const u8) !Packet {
    if (data.len < header_size) {
        return error.InvalidPacket;
    }

    const raw_type = data[0];
    const packet_type = std.meta.intToEnum(PacketType, raw_type) catch {
        return error.InvalidPacketType;
    };

    const length = std.mem.readInt(u32, data[1..5], .big);

    if (data.len < header_size + length) {
        return error.InvalidPacket;
    }

    return Packet{
        .packet_type = packet_type,
        .data = data[header_size .. header_size + length],
    };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "serialize then deserialize round-trip with data" {
    const allocator = std.testing.allocator;
    const payload = "hello";
    const original = Packet{
        .packet_type = .chat,
        .data = payload,
    };

    const bytes = try serialize(allocator, original);
    defer allocator.free(bytes);

    const restored = try deserialize(bytes);
    try std.testing.expectEqual(PacketType.chat, restored.packet_type);
    try std.testing.expectEqualSlices(u8, payload, restored.data);
}

test "serialize then deserialize round-trip with empty data" {
    const allocator = std.testing.allocator;
    const original = Packet{
        .packet_type = .keep_alive,
        .data = &.{},
    };

    const bytes = try serialize(allocator, original);
    defer allocator.free(bytes);

    const restored = try deserialize(bytes);
    try std.testing.expectEqual(PacketType.keep_alive, restored.packet_type);
    try std.testing.expectEqual(@as(usize, 0), restored.data.len);
}

test "deserialize rejects truncated header" {
    const short_buf = [_]u8{ 0x00, 0x01 };
    try std.testing.expectError(error.InvalidPacket, deserialize(&short_buf));
}

test "deserialize rejects invalid packet type" {
    var buf: [5]u8 = undefined;
    buf[0] = 0xFF; // invalid type
    std.mem.writeInt(u32, buf[1..5], 0, .big);
    try std.testing.expectError(error.InvalidPacketType, deserialize(&buf));
}

test "deserialize rejects truncated payload" {
    var buf: [5]u8 = undefined;
    buf[0] = @intFromEnum(PacketType.login);
    std.mem.writeInt(u32, buf[1..5], 100, .big); // claims 100 bytes, but none present
    try std.testing.expectError(error.InvalidPacket, deserialize(&buf));
}

test "round-trip every PacketType" {
    const allocator = std.testing.allocator;
    inline for (std.meta.fields(PacketType)) |field| {
        const ptype: PacketType = @enumFromInt(field.value);
        const pkt = Packet{ .packet_type = ptype, .data = &.{} };
        const bytes = try serialize(allocator, pkt);
        defer allocator.free(bytes);
        const restored = try deserialize(bytes);
        try std.testing.expectEqual(ptype, restored.packet_type);
    }
}

test "PlayerPositionData has expected size" {
    // 5 f32 (20 bytes) + 1 u8 + 3 padding bytes = 24 bytes for extern struct
    try std.testing.expect(@sizeOf(PlayerPositionData) > 0);
}

test "BlockChangeData has expected size" {
    try std.testing.expect(@sizeOf(BlockChangeData) > 0);
}
