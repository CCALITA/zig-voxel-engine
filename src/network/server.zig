const std = @import("std");
const protocol = @import("protocol.zig");

pub const MAX_PLAYERS = 20;

pub const ConnectedPlayer = struct {
    id: u32,
    username: [32]u8,
    username_len: u8,
    x: f32,
    y: f32,
    z: f32,
    connected: bool,
};

pub const Server = struct {
    players: [MAX_PLAYERS]ConnectedPlayer,
    player_count: u32,
    tick_rate: u32, // ticks per second (default 20)

    /// Create a server with default settings.
    pub fn init() Server {
        return Server{
            .players = [_]ConnectedPlayer{std.mem.zeroes(ConnectedPlayer)} ** MAX_PLAYERS,
            .player_count = 0,
            .tick_rate = 20,
        };
    }

    /// Add a player and return their slot ID, or null if the server is full.
    pub fn addPlayer(self: *Server, username: []const u8) ?u32 {
        for (0..MAX_PLAYERS) |i| {
            if (!self.players[i].connected) {
                var name_buf: [32]u8 = [_]u8{0} ** 32;
                const len = @min(username.len, 32);
                @memcpy(name_buf[0..len], username[0..len]);

                self.players[i] = ConnectedPlayer{
                    .id = @intCast(i),
                    .username = name_buf,
                    .username_len = @intCast(len),
                    .x = 0,
                    .y = 0,
                    .z = 0,
                    .connected = true,
                };
                self.player_count += 1;
                return @intCast(i);
            }
        }
        return null; // server full
    }

    /// Remove a player by ID.
    pub fn removePlayer(self: *Server, id: u32) void {
        if (id >= MAX_PLAYERS) return;
        if (self.players[id].connected) {
            self.players[id].connected = false;
            self.player_count -= 1;
        }
    }

    /// Prepare a block-change broadcast packet (returns serialized bytes).
    /// Caller owns the returned slice.
    pub fn broadcastBlockChange(
        self: *const Server,
        allocator: std.mem.Allocator,
        x: i32,
        y: i32,
        z: i32,
        block_id: u8,
    ) ![]u8 {
        _ = self;
        const change = protocol.BlockChangeData{
            .x = x,
            .y = y,
            .z = z,
            .block_id = block_id,
        };
        const bytes = std.mem.asBytes(&change);
        const packet = protocol.Packet{
            .packet_type = .block_change,
            .data = bytes,
        };
        return protocol.serialize(allocator, packet);
    }

    /// Number of currently connected players.
    pub fn getPlayerCount(self: *const Server) u32 {
        return self.player_count;
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "init creates empty server" {
    const server = Server.init();
    try std.testing.expectEqual(@as(u32, 0), server.getPlayerCount());
    try std.testing.expectEqual(@as(u32, 20), server.tick_rate);
}

test "addPlayer assigns sequential IDs" {
    var server = Server.init();
    const id0 = server.addPlayer("Alice");
    const id1 = server.addPlayer("Bob");
    try std.testing.expectEqual(@as(?u32, 0), id0);
    try std.testing.expectEqual(@as(?u32, 1), id1);
    try std.testing.expectEqual(@as(u32, 2), server.getPlayerCount());
}

test "addPlayer stores username" {
    var server = Server.init();
    _ = server.addPlayer("Charlie");
    const name = server.players[0].username[0..server.players[0].username_len];
    try std.testing.expectEqualSlices(u8, "Charlie", name);
}

test "removePlayer decrements count" {
    var server = Server.init();
    _ = server.addPlayer("Dave");
    _ = server.addPlayer("Eve");
    try std.testing.expectEqual(@as(u32, 2), server.getPlayerCount());
    server.removePlayer(0);
    try std.testing.expectEqual(@as(u32, 1), server.getPlayerCount());
}

test "removePlayer is idempotent" {
    var server = Server.init();
    _ = server.addPlayer("Frank");
    server.removePlayer(0);
    server.removePlayer(0); // second removal should be a no-op
    try std.testing.expectEqual(@as(u32, 0), server.getPlayerCount());
}

test "addPlayer reuses freed slot" {
    var server = Server.init();
    _ = server.addPlayer("Grace");
    server.removePlayer(0);
    const id = server.addPlayer("Heidi");
    try std.testing.expectEqual(@as(?u32, 0), id);
}

test "addPlayer returns null when full" {
    var server = Server.init();
    for (0..MAX_PLAYERS) |_| {
        _ = server.addPlayer("x");
    }
    try std.testing.expectEqual(@as(?u32, null), server.addPlayer("overflow"));
}

test "removePlayer ignores out-of-range id" {
    var server = Server.init();
    server.removePlayer(999); // should not crash
    try std.testing.expectEqual(@as(u32, 0), server.getPlayerCount());
}

test "broadcastBlockChange produces valid packet" {
    const allocator = std.testing.allocator;
    const server = Server.init();
    const bytes = try server.broadcastBlockChange(allocator, 10, 20, 30, 5);
    defer allocator.free(bytes);

    const pkt = try protocol.deserialize(bytes);
    try std.testing.expectEqual(protocol.PacketType.block_change, pkt.packet_type);
    try std.testing.expect(pkt.data.len > 0);
}
