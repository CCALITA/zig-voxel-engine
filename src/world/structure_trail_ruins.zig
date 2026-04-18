const std = @import("std");

// Trail ruins are buried ancient structures found along paths, consisting of
// connected rooms partially buried underground. They contain suspicious gravel
// blocks that yield pottery sherds and other archaeological loot.

pub const TrailRuinsRoom = enum(u8) {
    tower = 0,
    hall = 1,
    courtyard = 2,
    road = 3,
};

pub const RuinsBlock = struct {
    dx: i8,
    dy: i8,
    dz: i8,
    block_id: u8,
    is_suspicious: bool,
};

pub const RoomEntry = struct {
    room: TrailRuinsRoom,
    x: i8,
    z: i8,
};

pub const TrailRuinsLayout = struct {
    rooms: [8]?RoomEntry,
    room_count: u8,
    buried_depth: u8,

    pub fn init() TrailRuinsLayout {
        return .{
            .rooms = .{ null, null, null, null, null, null, null, null },
            .room_count = 0,
            .buried_depth = 0,
        };
    }

    pub fn getRoomSlice(self: *const TrailRuinsLayout) []const ?RoomEntry {
        return self.rooms[0..self.room_count];
    }
};

// Loot table entry: item_id paired with a relative weight for weighted selection.
const LootEntry = struct {
    item_id: u16,
    weight: u16,
};

// Item IDs for suspicious block loot.
// Pottery sherds (600-series), gems/currency (100-series), dyes (700-series), seeds (800-series).
pub const SUSPICIOUS_LOOT_TABLE = [_]LootEntry{
    // Pottery sherds (higher weight = more common)
    .{ .item_id = 601, .weight = 12 }, // angler sherd
    .{ .item_id = 602, .weight = 12 }, // archer sherd
    .{ .item_id = 603, .weight = 12 }, // brewer sherd
    .{ .item_id = 604, .weight = 12 }, // explorer sherd
    .{ .item_id = 605, .weight = 12 }, // mourner sherd
    .{ .item_id = 606, .weight = 12 }, // wayfinder sherd
    // Emeralds
    .{ .item_id = 100, .weight = 8 }, // emerald
    // Dyes
    .{ .item_id = 701, .weight = 5 }, // blue dye
    .{ .item_id = 702, .weight = 5 }, // orange dye
    .{ .item_id = 703, .weight = 5 }, // yellow dye
    // Seeds
    .{ .item_id = 801, .weight = 4 }, // wheat seeds
    .{ .item_id = 802, .weight = 4 }, // beetroot seeds
};

const total_loot_weight: u16 = blk: {
    var sum: u16 = 0;
    for (SUSPICIOUS_LOOT_TABLE) |entry| {
        sum += entry.weight;
    }
    break :blk sum;
};

/// Simple splitmix64 PRNG step: returns a pseudo-random u64 derived from seed.
fn splitmix64(seed: u64) u64 {
    var s = seed +% 0x9e3779b97f4a7c15;
    s = (s ^ (s >> 30)) *% 0xbf58476d1ce4e5b9;
    s = (s ^ (s >> 27)) *% 0x94d049bb133111eb;
    return s ^ (s >> 31);
}

/// Generate a trail ruins layout from the given seed.
/// Produces 2-8 connected rooms arranged along a winding path.
pub fn generateLayout(seed: u64) TrailRuinsLayout {
    var layout = TrailRuinsLayout.init();

    var s = splitmix64(seed);
    const room_count_raw: u8 = @intCast((s >> 16) & 0x07); // 0-7
    layout.room_count = @max(room_count_raw, 2); // at least 2 rooms

    s = splitmix64(s);
    layout.buried_depth = @intCast(((s >> 8) & 0x03) + 3); // depth 3-6

    var cx: i8 = 0;
    var cz: i8 = 0;
    for (0..layout.room_count) |i| {
        s = splitmix64(s);
        const room_type: u8 = @intCast((s >> 12) & 0x03);
        layout.rooms[i] = .{
            .room = @enumFromInt(room_type),
            .x = cx,
            .z = cz,
        };

        // Advance position for the next room along a path
        s = splitmix64(s);
        const direction: u2 = @intCast((s >> 4) & 0x03);
        switch (direction) {
            0 => cx +%= 6,
            1 => cz +%= 6,
            2 => cx -%= 6,
            3 => cz -%= 6,
        }
    }

    return layout;
}

// Block IDs used in room generation.
const STONE_BRICKS: u8 = 50;
const GRAVEL: u8 = 13;
const SUSPICIOUS_GRAVEL: u8 = 14;
const COBBLESTONE: u8 = 4;
const TERRACOTTA: u8 = 55;

/// Generate blocks for a single trail ruins room.
/// Returns up to 128 block placements including walls, floor, and suspicious blocks.
pub fn generateRoom(room: TrailRuinsRoom, seed: u64) [128]?RuinsBlock {
    var blocks: [128]?RuinsBlock = .{null} ** 128;
    var idx: usize = 0;
    var s = splitmix64(seed);

    switch (room) {
        .tower => {
            // 5x8x5 vertical tower structure
            const size_x: i8 = 5;
            const size_y: i8 = 8;
            const size_z: i8 = 5;
            var dy: i8 = 0;
            while (dy < size_y) : (dy += 1) {
                var dx: i8 = 0;
                while (dx < size_x) : (dx += 1) {
                    var dz: i8 = 0;
                    while (dz < size_z) : (dz += 1) {
                        const is_wall = dx == 0 or dx == size_x - 1 or dz == 0 or dz == size_z - 1;
                        const is_floor = dy == 0;
                        if (is_wall or is_floor) {
                            if (idx >= blocks.len) break;
                            s = splitmix64(s);
                            const is_sus = is_floor and ((s >> 10) & 0x07) == 0;
                            blocks[idx] = .{
                                .dx = dx,
                                .dy = dy,
                                .dz = dz,
                                .block_id = if (is_sus) SUSPICIOUS_GRAVEL else STONE_BRICKS,
                                .is_suspicious = is_sus,
                            };
                            idx += 1;
                        }
                    }
                }
            }
        },
        .hall => {
            // 9x4x5 horizontal hall
            const size_x: i8 = 9;
            const size_y: i8 = 4;
            const size_z: i8 = 5;
            var dy: i8 = 0;
            while (dy < size_y) : (dy += 1) {
                var dx: i8 = 0;
                while (dx < size_x) : (dx += 1) {
                    var dz: i8 = 0;
                    while (dz < size_z) : (dz += 1) {
                        const is_wall = dz == 0 or dz == size_z - 1;
                        const is_floor = dy == 0;
                        const is_ceiling = dy == size_y - 1;
                        if (is_wall or is_floor or is_ceiling) {
                            if (idx >= blocks.len) break;
                            s = splitmix64(s);
                            const is_sus = is_floor and ((s >> 10) & 0x07) == 0;
                            blocks[idx] = .{
                                .dx = dx,
                                .dy = dy,
                                .dz = dz,
                                .block_id = if (is_sus) SUSPICIOUS_GRAVEL else if (is_floor) COBBLESTONE else TERRACOTTA,
                                .is_suspicious = is_sus,
                            };
                            idx += 1;
                        }
                    }
                }
            }
        },
        .courtyard => {
            // 7x3x7 open courtyard with scattered gravel floor
            const size_x: i8 = 7;
            const size_z: i8 = 7;
            // Floor layer only, with perimeter walls 3 blocks high
            var dx: i8 = 0;
            while (dx < size_x) : (dx += 1) {
                var dz: i8 = 0;
                while (dz < size_z) : (dz += 1) {
                    if (idx >= blocks.len) break;
                    s = splitmix64(s);
                    const is_edge = dx == 0 or dx == size_x - 1 or dz == 0 or dz == size_z - 1;
                    const is_sus = !is_edge and ((s >> 10) & 0x0F) == 0;
                    blocks[idx] = .{
                        .dx = dx,
                        .dy = 0,
                        .dz = dz,
                        .block_id = if (is_sus) SUSPICIOUS_GRAVEL else if (is_edge) STONE_BRICKS else GRAVEL,
                        .is_suspicious = is_sus,
                    };
                    idx += 1;
                }
            }
            // Perimeter walls (dy 1 and 2)
            var wy: i8 = 1;
            while (wy <= 2) : (wy += 1) {
                dx = 0;
                while (dx < size_x) : (dx += 1) {
                    var dz: i8 = 0;
                    while (dz < size_z) : (dz += 1) {
                        const is_edge = dx == 0 or dx == size_x - 1 or dz == 0 or dz == size_z - 1;
                        if (is_edge) {
                            if (idx >= blocks.len) break;
                            blocks[idx] = .{
                                .dx = dx,
                                .dy = wy,
                                .dz = dz,
                                .block_id = STONE_BRICKS,
                                .is_suspicious = false,
                            };
                            idx += 1;
                        }
                    }
                }
            }
        },
        .road => {
            // 11x2x3 road segment
            const size_x: i8 = 11;
            const size_z: i8 = 3;
            var dx: i8 = 0;
            while (dx < size_x) : (dx += 1) {
                var dz: i8 = 0;
                while (dz < size_z) : (dz += 1) {
                    if (idx >= blocks.len) break;
                    s = splitmix64(s);
                    const is_center = dz == 1;
                    const is_sus = is_center and ((s >> 10) & 0x0F) == 0;
                    blocks[idx] = .{
                        .dx = dx,
                        .dy = 0,
                        .dz = dz,
                        .block_id = if (is_sus) SUSPICIOUS_GRAVEL else COBBLESTONE,
                        .is_suspicious = is_sus,
                    };
                    idx += 1;

                    // Low walls on edges
                    if (dz == 0 or dz == 2) {
                        if (idx >= blocks.len) break;
                        blocks[idx] = .{
                            .dx = dx,
                            .dy = 1,
                            .dz = dz,
                            .block_id = STONE_BRICKS,
                            .is_suspicious = false,
                        };
                        idx += 1;
                    }
                }
            }
        },
    }

    return blocks;
}

/// Select a loot item from the suspicious block loot table using weighted random.
pub fn getSuspiciousBlockLoot(seed: u64) u16 {
    const s = splitmix64(seed);
    const roll: u16 = @intCast(s % total_loot_weight);

    var cumulative: u16 = 0;
    for (SUSPICIOUS_LOOT_TABLE) |entry| {
        cumulative += entry.weight;
        if (roll < cumulative) {
            return entry.item_id;
        }
    }
    // Fallback: return last entry (should not be reached with correct weights)
    return SUSPICIOUS_LOOT_TABLE[SUSPICIOUS_LOOT_TABLE.len - 1].item_id;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "generateLayout produces valid room count and depth" {
    const seeds = [_]u64{ 12345, 0, 999999, 0xDEADBEEF, 42 };
    for (seeds) |seed| {
        const layout = generateLayout(seed);
        try std.testing.expect(layout.room_count >= 2);
        try std.testing.expect(layout.room_count <= 8);
        try std.testing.expect(layout.buried_depth >= 3);
        try std.testing.expect(layout.buried_depth <= 6);

        // All room slots up to room_count should be populated
        for (0..layout.room_count) |i| {
            try std.testing.expect(layout.rooms[i] != null);
        }
        // Slots beyond room_count should be null
        for (layout.room_count..8) |i| {
            try std.testing.expect(layout.rooms[i] == null);
        }
    }
}

test "generateLayout deterministic for same seed" {
    const a = generateLayout(7777);
    const b = generateLayout(7777);
    try std.testing.expectEqual(a.room_count, b.room_count);
    try std.testing.expectEqual(a.buried_depth, b.buried_depth);
    for (0..8) |i| {
        if (a.rooms[i]) |ra| {
            const rb = b.rooms[i].?;
            try std.testing.expectEqual(ra.room, rb.room);
            try std.testing.expectEqual(ra.x, rb.x);
            try std.testing.expectEqual(ra.z, rb.z);
        } else {
            try std.testing.expect(b.rooms[i] == null);
        }
    }
}

test "generateLayout different seeds produce different layouts" {
    const a = generateLayout(1);
    const b = generateLayout(2);
    // Extremely unlikely two different seeds produce identical layouts
    var same = true;
    if (a.room_count != b.room_count or a.buried_depth != b.buried_depth) {
        same = false;
    } else {
        for (0..a.room_count) |i| {
            const ra = a.rooms[i].?;
            const rb = b.rooms[i].?;
            if (ra.room != rb.room or ra.x != rb.x or ra.z != rb.z) {
                same = false;
                break;
            }
        }
    }
    try std.testing.expect(!same);
}

test "generateRoom places suspicious blocks" {
    const room_types = [_]TrailRuinsRoom{ .tower, .hall, .courtyard, .road };
    for (room_types) |rt| {
        // Try several seeds to find at least one with a suspicious block
        var found_suspicious = false;
        for (0..20) |s| {
            const blocks = generateRoom(rt, @intCast(s * 31 + 7));
            for (blocks) |maybe_block| {
                if (maybe_block) |block| {
                    if (block.is_suspicious) {
                        try std.testing.expectEqual(block.block_id, SUSPICIOUS_GRAVEL);
                        found_suspicious = true;
                        break;
                    }
                }
            }
            if (found_suspicious) break;
        }
        try std.testing.expect(found_suspicious);
    }
}

test "generateRoom produces non-empty output for every room type" {
    const room_types = [_]TrailRuinsRoom{ .tower, .hall, .courtyard, .road };
    for (room_types) |rt| {
        const blocks = generateRoom(rt, 42);
        var count: usize = 0;
        for (blocks) |maybe_block| {
            if (maybe_block != null) count += 1;
        }
        try std.testing.expect(count > 0);
    }
}

test "generateRoom deterministic" {
    const a = generateRoom(.hall, 555);
    const b = generateRoom(.hall, 555);
    for (0..128) |i| {
        if (a[i]) |ba| {
            const bb = b[i].?;
            try std.testing.expectEqual(ba.dx, bb.dx);
            try std.testing.expectEqual(ba.dy, bb.dy);
            try std.testing.expectEqual(ba.dz, bb.dz);
            try std.testing.expectEqual(ba.block_id, bb.block_id);
            try std.testing.expectEqual(ba.is_suspicious, bb.is_suspicious);
        } else {
            try std.testing.expect(b[i] == null);
        }
    }
}

test "getSuspiciousBlockLoot returns valid item IDs" {
    for (0..100) |i| {
        const item = getSuspiciousBlockLoot(@intCast(i * 97 + 3));
        var found = false;
        for (SUSPICIOUS_LOOT_TABLE) |entry| {
            if (entry.item_id == item) {
                found = true;
                break;
            }
        }
        try std.testing.expect(found);
    }
}

test "getSuspiciousBlockLoot variety across seeds" {
    var seen = std.AutoHashMap(u16, void).init(std.testing.allocator);
    defer seen.deinit();
    for (0..200) |i| {
        const item = getSuspiciousBlockLoot(@intCast(i));
        try seen.put(item, {});
    }
    // We should see at least 4 distinct loot categories
    try std.testing.expect(seen.count() >= 4);
}

test "getSuspiciousBlockLoot deterministic" {
    const a = getSuspiciousBlockLoot(12345);
    const b = getSuspiciousBlockLoot(12345);
    try std.testing.expectEqual(a, b);
}

test "total_loot_weight is correct" {
    var sum: u16 = 0;
    for (SUSPICIOUS_LOOT_TABLE) |entry| {
        sum += entry.weight;
    }
    try std.testing.expectEqual(sum, total_loot_weight);
    try std.testing.expect(total_loot_weight > 0);
}
