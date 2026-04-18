const std = @import("std");

pub const AxolotlColor = enum(u3) {
    lucy = 0,
    wild = 1,
    gold = 2,
    cyan = 3,
    blue = 4,
};

pub const MobType = struct {
    pub const guardian: u8 = 1;
    pub const drowned: u8 = 2;
    pub const elder_guardian: u8 = 3;
};

const max_health: f32 = 14.0;
const max_dry_time: f32 = 300.0;
const play_dead_duration: f32 = 10.0;
const play_dead_regen: f32 = 1.0;
const play_dead_threshold: f32 = max_health / 2.0;
const blue_chance: u32 = 1200;

pub const AxolotlEntity = struct {
    x: f32,
    y: f32,
    z: f32,
    health: f32 = max_health,
    color: AxolotlColor,
    playing_dead: bool = false,
    play_dead_timer: f32 = 0.0,
    in_water: bool = true,
    dry_timer: f32 = 0.0,

    pub fn init(x: f32, y: f32, z: f32, seed: u64) AxolotlEntity {
        var rng = std.Random.DefaultPrng.init(seed);
        const random = rng.random();

        const color: AxolotlColor = if (random.intRangeAtMost(u32, 1, blue_chance) == 1)
            .blue
        else blk: {
            const common_index = random.intRangeAtMost(u2, 0, 3);
            break :blk @enumFromInt(common_index);
        };

        return .{
            .x = x,
            .y = y,
            .z = z,
            .color = color,
        };
    }

    pub fn update(self: *AxolotlEntity, dt: f32, in_water: bool) void {
        self.in_water = in_water;

        if (self.playing_dead) {
            self.play_dead_timer -= dt;
            if (self.play_dead_timer <= 0.0) {
                self.playing_dead = false;
                self.play_dead_timer = 0.0;
            }
        }

        if (in_water) {
            self.dry_timer = 0.0;
        } else {
            self.dry_timer += dt;
            const damage = self.getDryDamage();
            if (damage > 0.0) {
                self.health = @max(0.0, self.health - damage * dt);
            }
        }
    }

    pub fn takeDamage(self: *AxolotlEntity, dmg: f32) void {
        self.health = @max(0.0, self.health - dmg);

        if (self.health > 0.0 and self.health < play_dead_threshold) {
            self.playing_dead = true;
            self.play_dead_timer = play_dead_duration;
            self.health += play_dead_regen;
        }
    }

    pub fn isPlayingDead(self: AxolotlEntity) bool {
        return self.playing_dead;
    }

    pub fn getDryDamage(self: AxolotlEntity) f32 {
        if (self.in_water) return 0.0;
        if (self.dry_timer >= max_dry_time) return max_health;
        return self.dry_timer / max_dry_time * max_health;
    }

    pub fn helpsInCombat(self: AxolotlEntity, target_type: u8) bool {
        _ = self;
        return target_type == MobType.guardian or
            target_type == MobType.drowned or
            target_type == MobType.elder_guardian;
    }
};

test "rare blue color from seed" {
    var blue_count: u32 = 0;
    const trials: u32 = 12000;

    for (0..trials) |i| {
        const axolotl = AxolotlEntity.init(0.0, 0.0, 0.0, @intCast(i));
        if (axolotl.color == .blue) {
            blue_count += 1;
        }
    }

    try std.testing.expect(blue_count > 0);
    try std.testing.expect(blue_count < trials / 10);
}

test "play dead triggers below 50 percent HP" {
    var axolotl = AxolotlEntity.init(1.0, 2.0, 3.0, 42);
    axolotl.health = 14.0;

    axolotl.takeDamage(6.0);
    try std.testing.expect(!axolotl.isPlayingDead());
    try std.testing.expectApproxEqAbs(@as(f32, 8.0), axolotl.health, 0.01);

    axolotl.takeDamage(2.0);
    try std.testing.expect(axolotl.isPlayingDead());
    try std.testing.expectApproxEqAbs(@as(f32, 7.0), axolotl.health, 0.01);
}

test "dry damage increases over time" {
    var axolotl = AxolotlEntity.init(0.0, 0.0, 0.0, 99);

    try std.testing.expectApproxEqAbs(@as(f32, 0.0), axolotl.getDryDamage(), 0.01);

    axolotl.in_water = false;
    axolotl.dry_timer = 150.0;
    const mid_damage = axolotl.getDryDamage();
    try std.testing.expect(mid_damage > 0.0);
    try std.testing.expect(mid_damage < 14.0);

    axolotl.dry_timer = 300.0;
    try std.testing.expectApproxEqAbs(max_health, axolotl.getDryDamage(), 0.01);
}

test "combat help targets" {
    const axolotl = AxolotlEntity.init(0.0, 0.0, 0.0, 1);

    try std.testing.expect(axolotl.helpsInCombat(MobType.guardian));
    try std.testing.expect(axolotl.helpsInCombat(MobType.drowned));
    try std.testing.expect(axolotl.helpsInCombat(MobType.elder_guardian));
    try std.testing.expect(!axolotl.helpsInCombat(0));
    try std.testing.expect(!axolotl.helpsInCombat(255));
}
