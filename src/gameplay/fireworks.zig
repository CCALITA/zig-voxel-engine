const std = @import("std");

pub const FireworkShape = enum {
    small_ball,
    large_ball,
    star,
    creeper_face,
    burst,
};

pub const FireworkStar = struct {
    shape: FireworkShape,
    color: [3]u8,
    fade_color: ?[3]u8 = null,
    has_trail: bool = false,
    has_twinkle: bool = false,
};

pub const FireworkRocket = struct {
    flight_duration: u2 = 1,
    stars: [8]?FireworkStar = .{null} ** 8,
    star_count: u8 = 0,
};

/// Craft a firework rocket from paper, gunpowder, and optional stars.
/// Requires paper and 1-3 gunpowder. Gunpowder count determines flight duration.
pub fn craft(paper: bool, gunpowder_count: u8, stars: []const FireworkStar) ?FireworkRocket {
    if (!paper) return null;
    if (gunpowder_count < 1 or gunpowder_count > 3) return null;
    if (stars.len > 8) return null;

    var rocket = FireworkRocket{
        .flight_duration = @intCast(gunpowder_count),
    };

    for (stars, 0..) |s, i| {
        rocket.stars[i] = s;
    }
    rocket.star_count = @intCast(stars.len);

    return rocket;
}

fn durationToFloat(duration: u2) f32 {
    return @floatFromInt(@as(u32, duration));
}

/// Returns the approximate flight height in blocks for a given duration.
/// Formula: duration * 17 + 3
pub fn getFlightHeight(duration: u2) f32 {
    return durationToFloat(duration) * 17.0 + 3.0;
}

/// Returns the explosion radius for a given firework shape.
pub fn getExplosionRadius(shape: FireworkShape) f32 {
    return switch (shape) {
        .small_ball => 2.0,
        .large_ball => 3.0,
        .star => 3.0,
        .creeper_face => 3.0,
        .burst => 4.0,
    };
}

/// Returns damage at a given distance from the explosion center.
/// Max damage is 7, with linear falloff to 0 at the explosion radius.
pub fn getDamageAtDistance(dist: f32, radius: f32) f32 {
    if (dist >= radius) return 0.0;
    if (dist <= 0.0) return 7.0;
    return 7.0 * (1.0 - dist / radius);
}

/// Returns the elytra speed boost in m/s for a given flight duration.
pub fn boostElytra(duration: u2) f32 {
    return durationToFloat(duration) * 12.0;
}

// ── Tests ──────────────────────────────────────────────────────────────

test "craft with 1 gunpowder" {
    const rocket = craft(true, 1, &.{}).?;
    try std.testing.expectEqual(@as(u2, 1), rocket.flight_duration);
    try std.testing.expectEqual(@as(u8, 0), rocket.star_count);
}

test "craft with 2 gunpowder" {
    const rocket = craft(true, 2, &.{}).?;
    try std.testing.expectEqual(@as(u2, 2), rocket.flight_duration);
}

test "craft with 3 gunpowder and stars" {
    const star = FireworkStar{ .shape = .star, .color = .{ 255, 0, 0 } };
    const rocket = craft(true, 3, &.{ star, star }).?;
    try std.testing.expectEqual(@as(u2, 3), rocket.flight_duration);
    try std.testing.expectEqual(@as(u8, 2), rocket.star_count);
    try std.testing.expect(rocket.stars[0] != null);
    try std.testing.expect(rocket.stars[1] != null);
    try std.testing.expect(rocket.stars[2] == null);
}

test "craft fails without paper" {
    try std.testing.expect(craft(false, 1, &.{}) == null);
}

test "craft fails with 0 or 4 gunpowder" {
    try std.testing.expect(craft(true, 0, &.{}) == null);
    try std.testing.expect(craft(true, 4, &.{}) == null);
}

test "flight height" {
    try std.testing.expectEqual(@as(f32, 20.0), getFlightHeight(1));
    try std.testing.expectEqual(@as(f32, 37.0), getFlightHeight(2));
    try std.testing.expectEqual(@as(f32, 54.0), getFlightHeight(3));
}

test "explosion radius" {
    try std.testing.expectEqual(@as(f32, 2.0), getExplosionRadius(.small_ball));
    try std.testing.expectEqual(@as(f32, 3.0), getExplosionRadius(.large_ball));
    try std.testing.expectEqual(@as(f32, 3.0), getExplosionRadius(.star));
    try std.testing.expectEqual(@as(f32, 3.0), getExplosionRadius(.creeper_face));
    try std.testing.expectEqual(@as(f32, 4.0), getExplosionRadius(.burst));
}

test "elytra boost" {
    try std.testing.expectEqual(@as(f32, 12.0), boostElytra(1));
    try std.testing.expectEqual(@as(f32, 24.0), boostElytra(2));
    try std.testing.expectEqual(@as(f32, 36.0), boostElytra(3));
}

test "star colors and properties" {
    const star = FireworkStar{
        .shape = .creeper_face,
        .color = .{ 0, 255, 0 },
        .fade_color = .{ 128, 128, 128 },
        .has_trail = true,
        .has_twinkle = true,
    };
    try std.testing.expectEqual(FireworkShape.creeper_face, star.shape);
    try std.testing.expectEqual([3]u8{ 0, 255, 0 }, star.color);
    try std.testing.expectEqual([3]u8{ 128, 128, 128 }, star.fade_color.?);
    try std.testing.expect(star.has_trail);
    try std.testing.expect(star.has_twinkle);
}

test "damage at distance" {
    try std.testing.expectEqual(@as(f32, 7.0), getDamageAtDistance(0.0, 3.0));
    try std.testing.expectEqual(@as(f32, 0.0), getDamageAtDistance(3.0, 3.0));
    try std.testing.expectEqual(@as(f32, 0.0), getDamageAtDistance(5.0, 3.0));
    try std.testing.expectEqual(@as(f32, 3.5), getDamageAtDistance(1.5, 3.0));
}
