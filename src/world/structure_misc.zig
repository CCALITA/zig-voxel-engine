/// Misc structures: Pillager Outpost, Ruined Portal, Jungle Temple.
const std = @import("std");

pub const StructureType = enum(u8) { pillager_outpost, ruined_portal, jungle_temple };

// === PILLAGER OUTPOST ===

pub const PillagerOutpost = struct {
    x: i32, y: i32, z: i32,
    tower_height: u8,
    tent_count: u8,
    has_golem_cage: bool,

    pub fn getBlockAt(self: *const PillagerOutpost, wx: i32, wy: i32, wz: i32) ?u8 {
        const lx = wx - self.x;
        const ly = wy - self.y;
        const lz = wz - self.z;
        // Tower: 7x7 base centered at origin
        if (lx >= -3 and lx <= 3 and lz >= -3 and lz <= 3) {
            if (ly >= 0 and ly < self.tower_height) {
                if (ly == 0) return 4; // cobblestone floor
                if (lx == -3 or lx == 3 or lz == -3 or lz == 3) {
                    if (ly % 3 == 0) return 4; // cobblestone bands
                    return 8; // dark oak log (using log side)
                }
            }
        }
        return null;
    }

    pub fn getPillagerCount(_: *const PillagerOutpost) u8 {
        return 5;
    }
};

pub fn generateOutpost(seed: u64, x: i32, z: i32) PillagerOutpost {
    const h = hashCoords(x, z, seed);
    return .{
        .x = x, .y = 70, .z = z,
        .tower_height = @intCast(18 + h % 5),
        .tent_count = @intCast(4 + h % 3),
        .has_golem_cage = h % 3 == 0,
    };
}

// === RUINED PORTAL ===

pub const PortalSize = enum(u8) { small, medium, large };

pub const RuinedPortal = struct {
    x: i32, y: i32, z: i32,
    size: PortalSize,
    missing_blocks: u8,
    underground: bool,

    pub fn getBlockAt(self: *const RuinedPortal, wx: i32, wy: i32, wz: i32) ?u8 {
        const lx = wx - self.x;
        const ly = wy - self.y;
        const lz = wz - self.z;
        if (lz != 0) {
            // Platform: netherrack/magma
            if (lz >= -1 and lz <= 1 and ly == 0 and lx >= -1 and lx <= 4) {
                return if (@as(u32, @abs(lx + lz)) % 3 == 0) @as(u8, 37) else @as(u8, 35);
            }
            return null;
        }
        const frame_w: i32 = 4;
        const frame_h: i32 = switch (self.size) {
            .small => 5,
            .medium => 5,
            .large => 7,
        };
        if (lx < 0 or lx >= frame_w or ly < 0 or ly >= frame_h) return null;
        // Frame edges
        const is_frame = lx == 0 or lx == frame_w - 1 or ly == 0 or ly == frame_h - 1;
        if (is_frame) {
            const pos_hash = @as(u32, @abs(lx * 7 + ly * 13));
            if (pos_hash % @as(u32, self.missing_blocks + 1) == 0) return null; // missing block
            return if (pos_hash % 3 == 0) @as(u8, 20) else @as(u8, 20); // obsidian
        }
        return null; // portal interior (empty or partial portal)
    }

    pub fn hasChest(_: *const RuinedPortal) bool {
        return true;
    }
};

pub fn generateRuinedPortal(seed: u64, x: i32, z: i32) RuinedPortal {
    const h = hashCoords(x, z, seed);
    return .{
        .x = x, .y = @intCast(50 + h % 30),
        .z = z,
        .size = @enumFromInt(@as(u8, @intCast(h % 3))),
        .missing_blocks = @intCast(1 + h % 3),
        .underground = h % 4 == 0,
    };
}

// === JUNGLE TEMPLE ===

pub const JungleTemple = struct {
    x: i32, y: i32, z: i32,

    pub fn getBlockAt(self: *const JungleTemple, wx: i32, wy: i32, wz: i32) ?u8 {
        const lx = wx - self.x;
        const ly = wy - self.y;
        const lz = wz - self.z;
        // 15x12x15 structure
        if (lx < 0 or lx >= 15 or ly < 0 or ly >= 12 or lz < 0 or lz >= 15) return null;
        // Floor
        if (ly == 0) return 4; // cobblestone
        // Walls (shell)
        if (lx == 0 or lx == 14 or lz == 0 or lz == 14) {
            if (ly < 8) {
                return if ((lx + ly + lz) % 5 == 0) @as(u8, 24) else @as(u8, 4); // mossy/cobble mix
            }
        }
        // Ceiling
        if (ly == 7 or ly == 11) return 4;
        // Stairs between floors
        if (lx >= 1 and lx <= 3 and lz == 7 and ly <= 7) {
            if (ly == @as(i32, lx)) return 4; // steps
        }
        return null;
    }

    pub fn getTrapPositions(self: *const JungleTemple) [2][3]i32 {
        return .{
            .{ self.x + 7, self.y + 1, self.z + 3 }, // tripwire trap
            .{ self.x + 7, self.y + 1, self.z + 11 }, // lever puzzle
        };
    }
};

pub fn generateJungleTemple(seed: u64, x: i32, z: i32) JungleTemple {
    const h = hashCoords(x, z, seed);
    _ = h;
    return .{ .x = x, .y = 68, .z = z };
}

// === PLACEMENT CHECKS ===

pub fn shouldGenerateOutpost(chunk_x: i32, chunk_z: i32, seed: u64) bool {
    const h = hashCoords(chunk_x, chunk_z, seed +% 100);
    return h % 300 == 0;
}

pub fn shouldGenerateRuinedPortal(chunk_x: i32, chunk_z: i32, seed: u64) bool {
    const h = hashCoords(chunk_x, chunk_z, seed +% 200);
    return h % 400 == 0;
}

pub fn shouldGenerateJungleTemple(chunk_x: i32, chunk_z: i32, seed: u64) bool {
    const h = hashCoords(chunk_x, chunk_z, seed +% 300);
    return h % 500 == 0;
}

pub const StructureLoot = struct {
    pub fn getOutpostLoot(rng: u32) [6]struct { id: u8, count: u8 } {
        var items: [6]struct { id: u8, count: u8 } = undefined;
        var r = rng;
        for (&items) |*item| {
            item.* = switch (r % 5) {
                0 => .{ .id = 14, .count = @intCast(1 + r % 3) },
                1 => .{ .id = 8, .count = @intCast(2 + r % 4) }, // dark oak
                else => .{ .id = 0, .count = 0 },
            };
            r = nextRng(r);
        }
        return items;
    }

    pub fn getPortalLoot(rng: u32) [4]struct { id: u8, count: u8 } {
        var items: [4]struct { id: u8, count: u8 } = undefined;
        var r = rng;
        for (&items) |*item| {
            item.* = switch (r % 4) {
                0 => .{ .id = 15, .count = @intCast(2 + r % 8) }, // gold
                1 => .{ .id = 20, .count = @intCast(1 + r % 3) }, // obsidian
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

test "outpost generates" {
    const o = generateOutpost(42, 100, 100);
    try std.testing.expect(o.tower_height >= 18);
}

test "ruined portal has missing blocks" {
    const p = generateRuinedPortal(42, 50, 50);
    try std.testing.expect(p.missing_blocks >= 1);
}

test "jungle temple block lookup" {
    const t = generateJungleTemple(42, 0, 0);
    const b = t.getBlockAt(0, 0, 0);
    try std.testing.expectEqual(@as(?u8, 4), b); // cobblestone floor
}
