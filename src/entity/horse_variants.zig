const std = @import("std");

// ── Stat range constants ─────────────────────────────────────────────

const min_speed: f32 = 0.1125;
const max_speed: f32 = 0.3375;
const min_jump: f32 = 0.4;
const max_jump: f32 = 1.0;
const min_health: f32 = 15.0;
const max_health: f32 = 30.0;

// ── Horse Color & Marking ────────────────────────────────────────────

pub const HorseColor = enum(u3) {
    white,
    creamy,
    chestnut,
    brown,
    black,
    gray,
    dark_brown,
};

pub const HorseMarking = enum(u3) {
    none,
    white,
    white_field,
    white_dots,
    black_dots,
};

// ── Horse Entity ─────────────────────────────────────────────────────

pub const HorseEntity = struct {
    color: HorseColor,
    marking: HorseMarking,
    speed: f32,
    jump_strength: f32,
    health: f32,
    tamed: bool,
    saddled: bool,
    chest: bool,

    const color_count: u8 = 7;
    const marking_count: u8 = 5;
    pub const variant_count: u8 = color_count * marking_count;

    pub fn init(seed: u64) HorseEntity {
        var prng = std.Random.DefaultPrng.init(seed);
        const rand = prng.random();
        return .{
            .color = @enumFromInt(@as(u3, @intCast(rand.intRangeAtMost(u8, 0, color_count - 1)))),
            .marking = @enumFromInt(@as(u3, @intCast(rand.intRangeAtMost(u8, 0, marking_count - 1)))),
            .speed = lerp(min_speed, max_speed, rand.float(f32)),
            .jump_strength = lerp(min_jump, max_jump, rand.float(f32)),
            .health = lerp(min_health, max_health, rand.float(f32)),
            .tamed = false,
            .saddled = false,
            .chest = false,
        };
    }

    pub fn getVariantId(self: HorseEntity) u8 {
        return @as(u8, @intFromEnum(self.color)) * marking_count + @as(u8, @intFromEnum(self.marking));
    }
};

// ── Pack Entity (Donkey / Mule) ──────────────────────────────────────

pub const PackEntity = struct {
    health: f32,
    chest: bool,
    inventory_size: u8,

    pub fn init(seed: u64) PackEntity {
        var prng = std.Random.DefaultPrng.init(seed);
        const rand = prng.random();
        return .{
            .health = lerp(min_health, max_health, rand.float(f32)),
            .chest = false,
            .inventory_size = 15,
        };
    }
};

pub const DonkeyEntity = PackEntity;
pub const MuleEntity = PackEntity;

// ── Breeding ─────────────────────────────────────────────────────────

pub fn breedHorses(parent_a: HorseEntity, parent_b: HorseEntity, seed: u64) HorseEntity {
    var prng = std.Random.DefaultPrng.init(seed);
    const rand = prng.random();

    const avg_speed = (parent_a.speed + parent_b.speed) / 2.0;
    const avg_jump = (parent_a.jump_strength + parent_b.jump_strength) / 2.0;
    const avg_health = (parent_a.health + parent_b.health) / 2.0;

    const speed_var = (rand.float(f32) - 0.5) * 0.05;
    const jump_var = (rand.float(f32) - 0.5) * 0.1;
    const health_var = (rand.float(f32) - 0.5) * 2.0;

    return .{
        .color = if (rand.boolean()) parent_a.color else parent_b.color,
        .marking = if (rand.boolean()) parent_a.marking else parent_b.marking,
        .speed = std.math.clamp(avg_speed + speed_var, min_speed, max_speed),
        .jump_strength = std.math.clamp(avg_jump + jump_var, min_jump, max_jump),
        .health = std.math.clamp(avg_health + health_var, min_health, max_health),
        .tamed = false,
        .saddled = false,
        .chest = false,
    };
}

// ── Llama Entity ─────────────────────────────────────────────────────

pub const LlamaEntity = struct {
    strength: u3,
    carpet_color: ?u4,
    spit_cooldown: f32,

    pub fn init(seed: u64) LlamaEntity {
        var prng = std.Random.DefaultPrng.init(seed);
        const rand = prng.random();
        return .{
            .strength = @intCast(rand.intRangeAtMost(u8, 1, 5)),
            .carpet_color = null,
            .spit_cooldown = 0.0,
        };
    }

    pub fn getCaravanLength(self: LlamaEntity) u8 {
        return @as(u8, self.strength) * 3;
    }
};

// ── Helpers ──────────────────────────────────────────────────────────

fn lerp(a: f32, b: f32, t: f32) f32 {
    return a + (b - a) * t;
}

// ── Tests ────────────────────────────────────────────────────────────

test "35 unique variant ids" {
    var seen = [_]bool{false} ** HorseEntity.variant_count;
    for (0..7) |c| {
        for (0..5) |m| {
            const horse = HorseEntity{
                .color = @enumFromInt(@as(u3, @intCast(c))),
                .marking = @enumFromInt(@as(u3, @intCast(m))),
                .speed = 0.2,
                .jump_strength = 0.7,
                .health = 20.0,
                .tamed = false,
                .saddled = false,
                .chest = false,
            };
            const id = horse.getVariantId();
            try std.testing.expect(id < HorseEntity.variant_count);
            try std.testing.expect(!seen[id]);
            seen[id] = true;
        }
    }
    for (seen) |s| {
        try std.testing.expect(s);
    }
}

test "init stat ranges" {
    var i: u64 = 0;
    while (i < 100) : (i += 1) {
        const h = HorseEntity.init(i);
        try std.testing.expect(h.speed >= min_speed and h.speed <= max_speed);
        try std.testing.expect(h.jump_strength >= min_jump and h.jump_strength <= max_jump);
        try std.testing.expect(h.health >= min_health and h.health <= max_health);
        try std.testing.expect(!h.tamed);
    }
}

test "breeding averages stay in range" {
    const a = HorseEntity.init(42);
    const b = HorseEntity.init(99);
    var i: u64 = 0;
    while (i < 100) : (i += 1) {
        const child = breedHorses(a, b, i);
        try std.testing.expect(child.speed >= min_speed and child.speed <= max_speed);
        try std.testing.expect(child.jump_strength >= min_jump and child.jump_strength <= max_jump);
        try std.testing.expect(child.health >= min_health and child.health <= max_health);
    }
}

test "llama caravan length" {
    for (1..6) |s| {
        const llama = LlamaEntity{
            .strength = @intCast(s),
            .carpet_color = null,
            .spit_cooldown = 0.0,
        };
        try std.testing.expectEqual(@as(u8, @intCast(s)) * 3, llama.getCaravanLength());
    }
}

test "donkey and mule defaults" {
    const donkey = DonkeyEntity.init(7);
    try std.testing.expectEqual(@as(u8, 15), donkey.inventory_size);
    try std.testing.expect(donkey.health >= min_health and donkey.health <= max_health);
    try std.testing.expect(!donkey.chest);

    const mule = MuleEntity.init(7);
    try std.testing.expectEqual(@as(u8, 15), mule.inventory_size);
    try std.testing.expect(mule.health >= min_health and mule.health <= max_health);
    try std.testing.expect(!mule.chest);
}
