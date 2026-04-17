const std = @import("std");
const protocol = @import("protocol.zig");

pub const ConnectionState = enum {
    disconnected,
    connecting,
    connected,
};

pub const Client = struct {
    state: ConnectionState,
    player_id: u32,
    server_address: [256]u8,
    address_len: u8,
    server_port: u16,

    /// Create a client in the disconnected state.
    pub fn init() Client {
        return Client{
            .state = .disconnected,
            .player_id = 0,
            .server_address = [_]u8{0} ** 256,
            .address_len = 0,
            .server_port = 0,
        };
    }

    /// Begin a connection to the given address and port.
    /// This sets the state to `connecting` and stores the target address.
    /// Actual socket I/O is not implemented; call `completeConnection` to
    /// simulate the handshake completing.
    pub fn connect(self: *Client, address: []const u8, port: u16) !void {
        if (self.state != .disconnected) {
            return error.AlreadyConnected;
        }
        if (address.len == 0) {
            return error.InvalidAddress;
        }

        const len = @min(address.len, 256);
        var buf: [256]u8 = [_]u8{0} ** 256;
        @memcpy(buf[0..len], address[0..len]);
        self.server_address = buf;
        self.address_len = @intCast(len);
        self.server_port = port;
        self.state = .connecting;
    }

    /// Simulate the handshake completing successfully.
    pub fn completeConnection(self: *Client, player_id: u32) !void {
        if (self.state != .connecting) {
            return error.NotConnecting;
        }
        self.player_id = player_id;
        self.state = .connected;
    }

    /// Disconnect from the server.
    pub fn disconnect(self: *Client) void {
        self.state = .disconnected;
        self.player_id = 0;
    }

    /// Serialize a player-position packet.
    /// Caller owns the returned slice.
    pub fn sendPosition(
        self: *const Client,
        allocator: std.mem.Allocator,
        x: f32,
        y: f32,
        z: f32,
        yaw: f32,
        pitch: f32,
    ) ![]u8 {
        if (self.state != .connected) {
            return error.NotConnected;
        }
        const pos = protocol.PlayerPositionData{
            .x = x,
            .y = y,
            .z = z,
            .yaw = yaw,
            .pitch = pitch,
            .on_ground = 1,
        };
        const bytes = std.mem.asBytes(&pos);
        const packet = protocol.Packet{
            .packet_type = .player_position,
            .data = bytes,
        };
        return protocol.serialize(allocator, packet);
    }

    /// Whether the client has an active connection.
    pub fn isConnected(self: *const Client) bool {
        return self.state == .connected;
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "init creates disconnected client" {
    const client = Client.init();
    try std.testing.expectEqual(ConnectionState.disconnected, client.state);
    try std.testing.expect(!client.isConnected());
}

test "connect transitions to connecting" {
    var client = Client.init();
    try client.connect("127.0.0.1", 25565);
    try std.testing.expectEqual(ConnectionState.connecting, client.state);
}

test "connect stores address and port" {
    var client = Client.init();
    try client.connect("localhost", 8080);
    const addr = client.server_address[0..client.address_len];
    try std.testing.expectEqualSlices(u8, "localhost", addr);
    try std.testing.expectEqual(@as(u16, 8080), client.server_port);
}

test "connect rejects empty address" {
    var client = Client.init();
    try std.testing.expectError(error.InvalidAddress, client.connect("", 25565));
}

test "connect fails when already connecting" {
    var client = Client.init();
    try client.connect("127.0.0.1", 25565);
    try std.testing.expectError(error.AlreadyConnected, client.connect("other", 1234));
}

test "completeConnection transitions to connected" {
    var client = Client.init();
    try client.connect("127.0.0.1", 25565);
    try client.completeConnection(42);
    try std.testing.expectEqual(ConnectionState.connected, client.state);
    try std.testing.expect(client.isConnected());
    try std.testing.expectEqual(@as(u32, 42), client.player_id);
}

test "completeConnection fails from disconnected state" {
    var client = Client.init();
    try std.testing.expectError(error.NotConnecting, client.completeConnection(0));
}

test "disconnect resets to disconnected" {
    var client = Client.init();
    try client.connect("127.0.0.1", 25565);
    try client.completeConnection(1);
    client.disconnect();
    try std.testing.expectEqual(ConnectionState.disconnected, client.state);
    try std.testing.expect(!client.isConnected());
}

test "sendPosition fails when disconnected" {
    const allocator = std.testing.allocator;
    var client = Client.init();
    try std.testing.expectError(error.NotConnected, client.sendPosition(allocator, 0, 0, 0, 0, 0));
}

test "sendPosition produces valid packet when connected" {
    const allocator = std.testing.allocator;
    var client = Client.init();
    try client.connect("127.0.0.1", 25565);
    try client.completeConnection(7);

    const bytes = try client.sendPosition(allocator, 1.0, 2.0, 3.0, 90.0, 0.0);
    defer allocator.free(bytes);

    const pkt = try protocol.deserialize(bytes);
    try std.testing.expectEqual(protocol.PacketType.player_position, pkt.packet_type);
    try std.testing.expect(pkt.data.len > 0);
}

test "full connect-send-disconnect lifecycle" {
    const allocator = std.testing.allocator;
    var client = Client.init();

    // disconnected -> connecting -> connected
    try client.connect("game.example.com", 25565);
    try client.completeConnection(99);
    try std.testing.expect(client.isConnected());

    // send a position
    const bytes = try client.sendPosition(allocator, 10.0, 64.0, -5.0, 180.0, 45.0);
    defer allocator.free(bytes);

    // disconnect
    client.disconnect();
    try std.testing.expect(!client.isConnected());

    // can reconnect
    try client.connect("other.server.com", 9999);
    try std.testing.expectEqual(ConnectionState.connecting, client.state);
}
