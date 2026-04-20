/// End city structure: modular purpur towers, bridges, end ship with elytra, shulkers.
const std = @import("std");

pub const EndCityPiece = enum(u8) { base, small_tower, fat_tower, bridge, ship };

pub const PieceInstance = struct {
    piece_type: EndCityPiece,
    x: i32, y: i32, z: i32,
    width: u8, height: u8, depth: u8,
};

pub const EndCity = struct {
    base_x: i32,
    base_z: i32,
    pieces: [32]PieceInstance,
    piece_count: u8,
    ship_present: bool,
    ship_x: i32 = 0, ship_y: i32 = 0, ship_z: i32 = 0,

    pub fn getBlockAt(self: *const EndCity, wx: i32, wy: i32, wz: i32) ?u8 {
        for (self.pieces[0..self.piece_count]) |p| {
            const lx = wx - p.x;
            const ly = wy - p.y;
            const lz = wz - p.z;
            if (lx < 0 or ly < 0 or lz < 0) continue;
            if (lx >= p.width or ly >= p.height or lz >= p.depth) continue;
            return blockForPiece(p.piece_type, @intCast(lx), @intCast(ly), @intCast(lz), p.width, p.height);
        }
        return null;
    }
};

const PURPUR: u8 = 54; // using end stone ID as purpur placeholder
const END_STONE_BRICK: u8 = 54;
const END_ROD: u8 = 34; // glowstone as placeholder

fn blockForPiece(pt: EndCityPiece, lx: u8, ly: u8, lz: u8, w: u8, h: u8) u8 {
    _ = lz;
    return switch (pt) {
        .base, .small_tower, .fat_tower => blk: {
            if (ly == 0 or ly == h - 1) break :blk PURPUR;
            if (lx == 0 or lx == w - 1) break :blk PURPUR;
            if (ly % 4 == 0 and lx == w / 2) break :blk END_ROD;
            break :blk 0;
        },
        .bridge => blk: {
            if (ly == 0) break :blk PURPUR;
            if (lx == 0 or lx == w - 1) {
                if (ly <= 1) break :blk PURPUR;
            }
            break :blk 0;
        },
        .ship => blk: {
            if (ly <= 2) break :blk PURPUR; // hull
            if (ly == 3 and lx >= 2 and lx < w - 2) break :blk PURPUR; // deck
            break :blk 0;
        },
    };
}

pub fn shouldGenerateEndCity(x: i32, z: i32, seed: u64) bool {
    const dist_sq = @as(i64, x) * @as(i64, x) + @as(i64, z) * @as(i64, z);
    if (dist_sq < 1000 * 1000) return false;
    const h = hashCoords(x, z, seed);
    return h % 100 < 3;
}

pub fn generate(seed: u64, base_x: i32, base_z: i32) EndCity {
    var city = EndCity{
        .base_x = base_x,
        .base_z = base_z,
        .pieces = undefined,
        .piece_count = 0,
        .ship_present = false,
    };

    var rng = hashCoords(base_x, base_z, seed);
    const base_y: i32 = 76;

    addPiece(&city, .base, base_x, base_y, base_z, 9, 4, 9);

    var tower_y = base_y + 4;
    var tower_x = base_x + 2;
    var tower_z = base_z + 2;

    // Build 3-6 tower sections with bridges
    const tower_count = 3 + @as(u8, @intCast(rng % 4));
    var ti: u8 = 0;
    while (ti < tower_count) : (ti += 1) {
        rng = nextRng(rng);
        const is_fat = rng % 3 == 0;
        const tw: u8 = if (is_fat) 9 else 5;
        const th: u8 = if (is_fat) @intCast(12 + rng % 8) else @intCast(8 + rng % 5);
        addPiece(&city, if (is_fat) .fat_tower else .small_tower, tower_x, tower_y, tower_z, tw, th, tw);

        rng = nextRng(rng);
        // Bridge to next tower
        if (ti < tower_count - 1) {
            const bridge_dir: i32 = if (rng % 2 == 0) 1 else -1;
            const bridge_len: i32 = 6 + @as(i32, @intCast(rng % 6));
            addPiece(&city, .bridge, tower_x + @as(i32, tw), tower_y + th - 3, tower_z, @intCast(bridge_len), 3, 3);
            tower_x += @as(i32, tw) + bridge_len;
            tower_y += @as(i32, th) - 3;
            tower_z += bridge_dir * 4;
        }
        rng = nextRng(rng);
    }

    // End ship (50% chance at end of longest branch)
    rng = nextRng(rng);
    if (rng % 2 == 0) {
        city.ship_present = true;
        city.ship_x = tower_x + 5;
        city.ship_y = tower_y + 5;
        city.ship_z = tower_z;
        addPiece(&city, .ship, city.ship_x, city.ship_y, city.ship_z, 20, 10, 10);
    }

    return city;
}

fn addPiece(city: *EndCity, pt: EndCityPiece, x: i32, y: i32, z: i32, w: u8, h: u8, d: u8) void {
    if (city.piece_count >= 32) return;
    city.pieces[city.piece_count] = .{ .piece_type = pt, .x = x, .y = y, .z = z, .width = w, .height = h, .depth = d };
    city.piece_count += 1;
}

pub const Shulker = struct {
    x: f32, y: f32, z: f32,
    hp: f32 = 30.0,
    alive: bool = true,
    is_open: bool = false,
    open_timer: f32 = 0.0,
    shoot_cooldown: f32 = 0.0,

    pub fn update(self: *Shulker, dt: f32, player_dist: f32) enum { closed, open, shoot } {
        if (!self.alive) return .closed;
        self.open_timer += dt;
        if (self.open_timer > 3.0) {
            self.is_open = !self.is_open;
            self.open_timer = 0;
        }
        if (!self.is_open) return .closed;
        self.shoot_cooldown = @max(0, self.shoot_cooldown - dt);
        if (player_dist < 16.0 and self.shoot_cooldown <= 0) {
            self.shoot_cooldown = 5.0;
            return .shoot;
        }
        return .open;
    }

    pub fn onHit(self: *Shulker, dmg: f32) void {
        if (!self.is_open) return; // closed = immune to projectiles
        self.hp -= dmg;
        if (self.hp <= 0) self.alive = false;
    }

    pub fn getDrops(rng: u32) u8 {
        return if (rng % 2 == 0) 1 else 0; // 50% shulker shell
    }
};

pub const EndCityLoot = struct {
    pub fn getChestItems(rng_val: u32) [6]struct { id: u8, count: u8 } {
        var items: [6]struct { id: u8, count: u8 } = undefined;
        var r = rng_val;
        for (&items) |*item| {
            item.* = switch (r % 5) {
                0 => .{ .id = 16, .count = @intCast(2 + r % 5) }, // diamond
                1 => .{ .id = 14, .count = @intCast(4 + r % 8) }, // iron
                2 => .{ .id = 15, .count = @intCast(2 + r % 7) }, // gold
                3 => .{ .id = 54, .count = @intCast(1 + r % 3) }, // end stone
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

test "end city generates" {
    const city = generate(42, 1500, 1500);
    try std.testing.expect(city.piece_count >= 4);
}

test "shulker closed blocks damage" {
    var s = Shulker{ .x = 0, .y = 0, .z = 0 };
    s.is_open = false;
    s.onHit(10);
    try std.testing.expectApproxEqAbs(@as(f32, 30.0), s.hp, 0.01);
}
