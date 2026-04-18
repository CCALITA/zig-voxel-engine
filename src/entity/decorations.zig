/// Decoration entities: paintings, item frames, and signs.
/// These are non-mob entities that attach to blocks for aesthetic and
/// informational purposes. Each entity stores its grid position and the
/// facing direction encoded as a u2 (0=south, 1=west, 2=north, 3=east).
const std = @import("std");

// ---------------------------------------------------------------------------
// Painting
// ---------------------------------------------------------------------------

pub const PaintingType = enum {
    kebab,
    aztec,
    alban,
    aztec2,
    bomb,
    plant,
    wasteland,
    pool,
    courbet,
    sea,
    sunset,
    creebet,
    wanderer,
    graham,
    match,
    bust,
    stage,
    void_painting,
    skull_and_roses,
    wither,
    fighters,
    pointer,
    pigscene,
    burning_skull,
    skeleton,
    donkey_kong,
};

/// Width and height of a painting in blocks.
pub const PaintingSize = struct {
    width: u8,
    height: u8,
};

/// Return the block dimensions for a painting type.
pub fn getPaintingSize(painting_type: PaintingType) PaintingSize {
    return switch (painting_type) {
        // 1x1
        .kebab, .aztec, .alban, .aztec2, .bomb, .plant, .wasteland => .{ .width = 1, .height = 1 },
        // 2x1
        .pool, .courbet, .sea, .sunset, .creebet => .{ .width = 2, .height = 1 },
        // 1x2
        .wanderer, .graham => .{ .width = 1, .height = 2 },
        // 2x2
        .match, .bust, .stage, .void_painting, .skull_and_roses, .wither => .{ .width = 2, .height = 2 },
        // 4x2
        .fighters => .{ .width = 4, .height = 2 },
        // 4x3
        .skeleton, .donkey_kong => .{ .width = 4, .height = 3 },
        // 4x4
        .pointer, .pigscene, .burning_skull => .{ .width = 4, .height = 4 },
    };
}

pub const PaintingEntity = struct {
    painting_type: PaintingType,
    x: i32,
    y: i32,
    z: i32,
    facing: u2,

    pub fn init(painting_type: PaintingType, x: i32, y: i32, z: i32, facing: u2) PaintingEntity {
        return .{
            .painting_type = painting_type,
            .x = x,
            .y = y,
            .z = z,
            .facing = facing,
        };
    }

    /// Return the block dimensions for this painting.
    pub fn getSize(self: *const PaintingEntity) PaintingSize {
        return getPaintingSize(self.painting_type);
    }
};

// ---------------------------------------------------------------------------
// Item Frame
// ---------------------------------------------------------------------------

pub const ItemFrameEntity = struct {
    x: i32,
    y: i32,
    z: i32,
    facing: u2,
    item_id: u16,
    rotation: u3, // 0-7

    pub fn init(x: i32, y: i32, z: i32, facing: u2) ItemFrameEntity {
        return .{
            .x = x,
            .y = y,
            .z = z,
            .facing = facing,
            .item_id = 0,
            .rotation = 0,
        };
    }

    /// Place a frame at the given position and facing.
    pub fn placeFrame(x: i32, y: i32, z: i32, facing: u2) ItemFrameEntity {
        return ItemFrameEntity.init(x, y, z, facing);
    }

    /// Set the displayed item. Resets rotation to 0.
    pub fn setItem(self: *ItemFrameEntity, item_id: u16) void {
        self.item_id = item_id;
        self.rotation = 0;
    }

    /// Rotate the item by one 45-degree step (wraps at 8).
    pub fn rotateItem(self: *ItemFrameEntity) void {
        self.rotation +%= 1;
    }

    /// Return the currently displayed item id (0 means empty).
    pub fn getItem(self: *const ItemFrameEntity) u16 {
        return self.item_id;
    }
};

// ---------------------------------------------------------------------------
// Sign
// ---------------------------------------------------------------------------

pub const SignEntity = struct {
    x: i32,
    y: i32,
    z: i32,
    facing: u2,
    lines: [4][32]u8,
    line_lens: [4]u8,

    pub fn init(x: i32, y: i32, z: i32, facing: u2) SignEntity {
        return .{
            .x = x,
            .y = y,
            .z = z,
            .facing = facing,
            .lines = [_][32]u8{[_]u8{0} ** 32} ** 4,
            .line_lens = [_]u8{0} ** 4,
        };
    }

    /// Set the text of a line (0-3). Text longer than 32 bytes is truncated.
    pub fn setLine(self: *SignEntity, line: u2, text: []const u8) void {
        const len: u8 = @intCast(@min(text.len, 32));
        @memcpy(self.lines[line][0..len], text[0..len]);
        // Zero the remainder so stale bytes never leak.
        if (len < 32) {
            @memset(self.lines[line][len..32], 0);
        }
        self.line_lens[line] = len;
    }

    /// Read the text of a line (0-3).
    pub fn getLine(self: *const SignEntity, line: u2) []const u8 {
        const len = self.line_lens[line];
        return self.lines[line][0..len];
    }
};

// ---------------------------------------------------------------------------
// Placement Validator
// ---------------------------------------------------------------------------

pub const PlacementValidator = struct {
    /// Check whether a decoration can be placed at (x, y, z) with the given
    /// facing direction.
    ///
    /// Rules:
    ///   - y must be non-negative (above the void).
    ///   - Facing must be in range 0-3 (enforced by the u2 type).
    pub fn canPlace(x: i32, y: i32, z: i32, facing: u2, decoration_type: DecorationType) bool {
        _ = x;
        _ = z;
        _ = facing;
        _ = decoration_type;

        return y >= 0;
    }
};

pub const DecorationType = union(enum) {
    painting: PaintingType,
    item_frame,
    sign,
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "painting 1x1 sizes" {
    const one_by_one = [_]PaintingType{ .kebab, .aztec, .alban, .aztec2, .bomb, .plant, .wasteland };
    for (one_by_one) |pt| {
        const size = getPaintingSize(pt);
        try std.testing.expectEqual(@as(u8, 1), size.width);
        try std.testing.expectEqual(@as(u8, 1), size.height);
    }
}

test "painting 2x1 sizes" {
    const two_by_one = [_]PaintingType{ .pool, .courbet, .sea, .sunset, .creebet };
    for (two_by_one) |pt| {
        const size = getPaintingSize(pt);
        try std.testing.expectEqual(@as(u8, 2), size.width);
        try std.testing.expectEqual(@as(u8, 1), size.height);
    }
}

test "painting 1x2 sizes" {
    const one_by_two = [_]PaintingType{ .wanderer, .graham };
    for (one_by_two) |pt| {
        const size = getPaintingSize(pt);
        try std.testing.expectEqual(@as(u8, 1), size.width);
        try std.testing.expectEqual(@as(u8, 2), size.height);
    }
}

test "painting 2x2 sizes" {
    const two_by_two = [_]PaintingType{ .match, .bust, .stage, .void_painting, .skull_and_roses, .wither };
    for (two_by_two) |pt| {
        const size = getPaintingSize(pt);
        try std.testing.expectEqual(@as(u8, 2), size.width);
        try std.testing.expectEqual(@as(u8, 2), size.height);
    }
}

test "painting 4x2 fighters" {
    const size = getPaintingSize(.fighters);
    try std.testing.expectEqual(@as(u8, 4), size.width);
    try std.testing.expectEqual(@as(u8, 2), size.height);
}

test "painting 4x3 sizes" {
    const four_by_three = [_]PaintingType{ .skeleton, .donkey_kong };
    for (four_by_three) |pt| {
        const size = getPaintingSize(pt);
        try std.testing.expectEqual(@as(u8, 4), size.width);
        try std.testing.expectEqual(@as(u8, 3), size.height);
    }
}

test "painting 4x4 sizes" {
    const four_by_four = [_]PaintingType{ .pointer, .pigscene, .burning_skull };
    for (four_by_four) |pt| {
        const size = getPaintingSize(pt);
        try std.testing.expectEqual(@as(u8, 4), size.width);
        try std.testing.expectEqual(@as(u8, 4), size.height);
    }
}

test "painting entity getSize" {
    const p = PaintingEntity.init(.burning_skull, 5, 10, 3, 2);
    const size = p.getSize();
    try std.testing.expectEqual(@as(u8, 4), size.width);
    try std.testing.expectEqual(@as(u8, 4), size.height);
}

test "painting entity stores position and facing" {
    const p = PaintingEntity.init(.kebab, 1, 2, 3, 1);
    try std.testing.expectEqual(@as(i32, 1), p.x);
    try std.testing.expectEqual(@as(i32, 2), p.y);
    try std.testing.expectEqual(@as(i32, 3), p.z);
    try std.testing.expectEqual(@as(u2, 1), p.facing);
}

test "all 26 painting types exist" {
    const count = @typeInfo(PaintingType).@"enum".fields.len;
    try std.testing.expectEqual(@as(usize, 26), count);
}

test "item frame init defaults" {
    const f = ItemFrameEntity.init(4, 5, 6, 0);
    try std.testing.expectEqual(@as(i32, 4), f.x);
    try std.testing.expectEqual(@as(i32, 5), f.y);
    try std.testing.expectEqual(@as(i32, 6), f.z);
    try std.testing.expectEqual(@as(u2, 0), f.facing);
    try std.testing.expectEqual(@as(u16, 0), f.item_id);
    try std.testing.expectEqual(@as(u3, 0), f.rotation);
}

test "item frame placeFrame" {
    const f = ItemFrameEntity.placeFrame(1, 2, 3, 3);
    try std.testing.expectEqual(@as(i32, 1), f.x);
    try std.testing.expectEqual(@as(u2, 3), f.facing);
}

test "item frame setItem and getItem" {
    var f = ItemFrameEntity.init(0, 0, 0, 0);
    try std.testing.expectEqual(@as(u16, 0), f.getItem());

    f.setItem(256);
    try std.testing.expectEqual(@as(u16, 256), f.getItem());
}

test "item frame setItem resets rotation" {
    var f = ItemFrameEntity.init(0, 0, 0, 0);
    f.rotateItem();
    f.rotateItem();
    try std.testing.expectEqual(@as(u3, 2), f.rotation);

    f.setItem(100);
    try std.testing.expectEqual(@as(u3, 0), f.rotation);
}

test "item frame rotation wraps at 8" {
    var f = ItemFrameEntity.init(0, 0, 0, 0);
    for (0..7) |_| {
        f.rotateItem();
    }
    try std.testing.expectEqual(@as(u3, 7), f.rotation);

    f.rotateItem(); // 7 -> wraps to 0
    try std.testing.expectEqual(@as(u3, 0), f.rotation);
}

test "item frame rotation cycles through all 8 values" {
    var f = ItemFrameEntity.init(0, 0, 0, 0);
    for (0..8) |i| {
        try std.testing.expectEqual(@as(u3, @intCast(i)), f.rotation);
        f.rotateItem();
    }
    // After 8 rotations we are back to 0
    try std.testing.expectEqual(@as(u3, 0), f.rotation);
}

test "sign init defaults" {
    const s = SignEntity.init(7, 8, 9, 2);
    try std.testing.expectEqual(@as(i32, 7), s.x);
    try std.testing.expectEqual(@as(i32, 8), s.y);
    try std.testing.expectEqual(@as(i32, 9), s.z);
    try std.testing.expectEqual(@as(u2, 2), s.facing);
    for (0..4) |i| {
        try std.testing.expectEqual(@as(u8, 0), s.line_lens[i]);
    }
}

test "sign setLine and getLine" {
    var s = SignEntity.init(0, 0, 0, 0);
    s.setLine(0, "Hello");
    s.setLine(1, "World");

    try std.testing.expectEqualStrings("Hello", s.getLine(0));
    try std.testing.expectEqualStrings("World", s.getLine(1));
    try std.testing.expectEqualStrings("", s.getLine(2));
    try std.testing.expectEqualStrings("", s.getLine(3));
}

test "sign setLine overwrites previous text" {
    var s = SignEntity.init(0, 0, 0, 0);
    s.setLine(0, "AAAAAAAAAA");
    s.setLine(0, "BB");

    try std.testing.expectEqualStrings("BB", s.getLine(0));
    // Ensure old bytes were zeroed
    try std.testing.expectEqual(@as(u8, 0), s.lines[0][2]);
}

test "sign setLine truncates at 32 bytes" {
    var s = SignEntity.init(0, 0, 0, 0);
    const long_text = "ABCDEFGHIJKLMNOPQRSTUVWXYZ012345678";
    s.setLine(0, long_text);

    try std.testing.expectEqual(@as(u8, 32), s.line_lens[0]);
    try std.testing.expectEqualStrings(long_text[0..32], s.getLine(0));
}

test "sign setLine exactly 32 bytes" {
    var s = SignEntity.init(0, 0, 0, 0);
    const exact = "ABCDEFGHIJKLMNOPQRSTUVWXYZ012345";
    try std.testing.expectEqual(@as(usize, 32), exact.len);
    s.setLine(2, exact);
    try std.testing.expectEqualStrings(exact, s.getLine(2));
}

test "placement validator rejects negative y" {
    try std.testing.expect(!PlacementValidator.canPlace(0, -1, 0, 0, .item_frame));
    try std.testing.expect(!PlacementValidator.canPlace(0, -10, 0, 0, .sign));
    try std.testing.expect(!PlacementValidator.canPlace(0, -1, 0, 0, .{ .painting = .kebab }));
}

test "placement validator accepts valid positions" {
    try std.testing.expect(PlacementValidator.canPlace(5, 64, 5, 0, .item_frame));
    try std.testing.expect(PlacementValidator.canPlace(5, 64, 5, 1, .sign));
    try std.testing.expect(PlacementValidator.canPlace(5, 64, 5, 2, .{ .painting = .pointer }));
}

test "placement validator accepts y zero" {
    try std.testing.expect(PlacementValidator.canPlace(0, 0, 0, 0, .item_frame));
    try std.testing.expect(PlacementValidator.canPlace(0, 0, 0, 0, .sign));
    try std.testing.expect(PlacementValidator.canPlace(0, 0, 0, 0, .{ .painting = .kebab }));
}
