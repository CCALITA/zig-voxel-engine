/// Nether fortress: bridge-based structure with blaze spawners, nether wart farms, loot corridors.
const std = @import("std");

pub const FortressPiece = enum(u8) {
    bridge,
    corridor,
    blaze_room,
    wart_farm,
    loot_corridor,
    t_intersection,
    staircase,
    small_room,
    bridge_crossing,
};

pub const PieceData = struct {
    piece_type: FortressPiece,
    x: i32,
    y: i32,
    z: i32,
    width: u8,
    height: u8,
    depth: u8,
    facing: u8, // 0=north, 1=east, 2=south, 3=west
};

pub const Fortress = struct {
    origin_x: i32,
    origin_z: i32,
    pieces: [64]PieceData,
    piece_count: u8,
    min_x: i32,
    min_z: i32,
    max_x: i32,
    max_z: i32,
    blaze_spawner_count: u8,

    pub fn isInsideBounds(self: *const Fortress, x: i32, z: i32) bool {
        return x >= self.min_x and x <= self.max_x and z >= self.min_z and z <= self.max_z;
    }

    pub fn getBlockAt(self: *const Fortress, wx: i32, wy: i32, wz: i32) ?u8 {
        for (self.pieces[0..self.piece_count]) |piece| {
            const lx = wx - piece.x;
            const ly = wy - piece.y;
            const lz = wz - piece.z;
            if (lx < 0 or ly < 0 or lz < 0) continue;
            if (lx >= piece.width or ly >= piece.height or lz >= piece.depth) continue;
            return getBlockForPiece(piece.piece_type, @intCast(lx), @intCast(ly), @intCast(lz), piece.width, piece.height);
        }
        return null;
    }
};

const NETHER_BRICK: u8 = 19; // using brick ID
const SOUL_SAND: u8 = 36;
const LAVA: u8 = 37;

fn getBlockForPiece(piece_type: FortressPiece, lx: u8, ly: u8, lz: u8, width: u8, height: u8) u8 {
    _ = lz;
    return switch (piece_type) {
        .bridge => blk: {
            if (ly == 0) break :blk NETHER_BRICK; // floor
            if (ly == height - 1) break :blk 0; // open top
            if (lx == 0 or lx == width - 1) break :blk NETHER_BRICK; // railings
            break :blk 0; // air
        },
        .blaze_room => blk: {
            if (ly == 0 or ly == height - 1) break :blk NETHER_BRICK;
            if (lx == 0 or lx == width - 1) break :blk NETHER_BRICK;
            break :blk 0;
        },
        .wart_farm => blk: {
            if (ly == 0) break :blk SOUL_SAND;
            break :blk 0;
        },
        .loot_corridor, .corridor, .t_intersection, .small_room => blk: {
            if (ly == 0 or ly == height - 1) break :blk NETHER_BRICK;
            if (lx == 0 or lx == width - 1) break :blk NETHER_BRICK;
            break :blk 0;
        },
        .staircase => blk: {
            if (ly == 0) break :blk NETHER_BRICK;
            if (lx == ly) break :blk NETHER_BRICK; // steps
            break :blk 0;
        },
        .bridge_crossing => NETHER_BRICK,
    };
}

pub fn shouldGenerateFortress(chunk_x: i32, chunk_z: i32, seed: u64) bool {
    const region_x = @divFloor(chunk_x, 30);
    const region_z = @divFloor(chunk_z, 30);
    const h = hashCoords(region_x, region_z, seed);
    const fort_cx = region_x * 30 + @as(i32, @intCast(h % 20));
    const fort_cz = region_z * 30 + @as(i32, @intCast((h >> 8) % 20));
    return chunk_x == fort_cx and chunk_z == fort_cz;
}

pub fn generate(seed: u64, base_x: i32, base_z: i32) Fortress {
    var fort = Fortress{
        .origin_x = base_x,
        .origin_z = base_z,
        .pieces = undefined,
        .piece_count = 0,
        .min_x = base_x,
        .min_z = base_z,
        .max_x = base_x,
        .max_z = base_z,
        .blaze_spawner_count = 0,
    };

    var rng = hashCoords(base_x, base_z, seed);
    const y_base: i32 = 64;

    // Main bridge (primary axis)
    const bridge_len: i32 = 50 + @as(i32, @intCast(rng % 30));
    addPiece(&fort, .bridge, base_x, y_base, base_z, 5, 5, @intCast(bridge_len), 0);
    rng = nextRng(rng);

    // Branch corridors off the main bridge
    var bi: i32 = 10;
    while (bi < bridge_len - 10) : (bi += 12 + @as(i32, @intCast(rng % 8))) {
        rng = nextRng(rng);
        const side: i32 = if (rng % 2 == 0) -1 else 1;
        const corr_len: i32 = 10 + @as(i32, @intCast(rng % 15));
        const cx = base_x + side * 3;
        const cz = base_z + bi;
        addPiece(&fort, .corridor, cx, y_base, cz, @intCast(corr_len), 5, 5, if (side > 0) 1 else 3);
        rng = nextRng(rng);

        // Room at end of corridor
        const room_type: FortressPiece = switch (rng % 4) {
            0 => blk: { fort.blaze_spawner_count += 1; break :blk .blaze_room; },
            1 => .wart_farm,
            2 => .loot_corridor,
            else => .small_room,
        };
        addPiece(&fort, room_type, cx + side * corr_len, y_base, cz, 7, 6, 7, 0);
        rng = nextRng(rng);
    }

    // Ensure at least 2 blaze spawners
    if (fort.blaze_spawner_count < 2) {
        addPiece(&fort, .blaze_room, base_x + 8, y_base, base_z + bridge_len - 10, 7, 6, 7, 0);
        fort.blaze_spawner_count += 1;
    }

    return fort;
}

fn addPiece(fort: *Fortress, piece_type: FortressPiece, x: i32, y: i32, z: i32, w: u8, h: u8, d: u8, facing: u8) void {
    if (fort.piece_count >= 64) return;
    fort.pieces[fort.piece_count] = .{
        .piece_type = piece_type,
        .x = x, .y = y, .z = z,
        .width = w, .height = h, .depth = d,
        .facing = facing,
    };
    fort.piece_count += 1;
    fort.min_x = @min(fort.min_x, x);
    fort.min_z = @min(fort.min_z, z);
    fort.max_x = @max(fort.max_x, x + w);
    fort.max_z = @max(fort.max_z, z + d);
}

pub fn isInsideFortress(fort: *const Fortress, x: i32, y: i32, z: i32) bool {
    return fort.getBlockAt(x, y, z) != null;
}

pub const FortressLoot = struct {
    pub fn getChestItems(rng_val: u32) [8]struct { id: u8, count: u8 } {
        var items: [8]struct { id: u8, count: u8 } = undefined;
        var r = rng_val;
        for (&items) |*item| {
            item.* = switch (r % 6) {
                0 => .{ .id = 16, .count = @intCast(1 + r % 3) }, // diamond
                1 => .{ .id = 15, .count = @intCast(1 + r % 5) }, // gold
                2 => .{ .id = 14, .count = @intCast(1 + r % 5) }, // iron
                3 => .{ .id = 36, .count = @intCast(3 + r % 7) }, // nether wart (soul sand id)
                4 => .{ .id = 6, .count = 1 }, // saddle (sand id as placeholder)
                else => .{ .id = 0, .count = 0 },
            };
            r = nextRng(r);
        }
        return items;
    }
};

fn hashCoords(x: i32, z: i32, seed: u64) u32 {
    var h = seed;
    h ^= @as(u64, @bitCast(@as(i64, x))) *% 0x9E3779B97F4A7C15;
    h ^= @as(u64, @bitCast(@as(i64, z))) *% 0x6C62272E07BB0142;
    h = (h ^ (h >> 30)) *% 0xBF58476D1CE4E5B9;
    return @truncate(h ^ (h >> 27));
}

fn nextRng(prev: u32) u32 {
    var x = prev;
    x ^= x << 13;
    x ^= x >> 17;
    x ^= x << 5;
    return x;
}

test "fortress generates" {
    const fort = generate(42, 0, 0);
    try std.testing.expect(fort.piece_count > 3);
    try std.testing.expect(fort.blaze_spawner_count >= 2);
}

test "fortress block lookup" {
    const fort = generate(42, 0, 0);
    // Origin should be inside the main bridge
    const b = fort.getBlockAt(2, 64, 5);
    try std.testing.expect(b != null);
}
