/// Named Binary Tag (NBT) serialization for structured data.
///
/// Binary format:
///   Named tag: [tag_type:u8][name_length:u16 big][name:bytes][payload]
///   Compound:  sequence of named tags terminated by TAG_END (0x00)
///   List:      [element_type:u8][length:i32 big][elements...]
///
/// All multi-byte integers are big-endian (Java NBT convention).
const std = @import("std");

// ── Tag types ────────────────────────────────────────────────────────────

pub const TagType = enum(u8) {
    byte = 1,
    short = 2,
    int = 3,
    long = 4,
    float = 5,
    double = 6,
    byte_array = 7,
    string = 8,
    list = 9,
    compound = 10,
    int_array = 11,
    long_array = 12,
};

const TAG_END: u8 = 0;

// ── Core data structures ─────────────────────────────────────────────────

pub const Tag = union(TagType) {
    byte: i8,
    short: i16,
    int: i32,
    long: i64,
    float: f32,
    double: f64,
    byte_array: []const u8,
    string: []const u8,
    list: []const Tag,
    compound: Compound,
    int_array: []const i32,
    long_array: []const i64,
};

pub const NamedTag = struct {
    name: []const u8,
    tag: Tag,
};

pub const Compound = struct {
    entries: []const NamedTag,

    /// Look up a tag by name, returning null if not found.
    pub fn get(self: *const Compound, name: []const u8) ?Tag {
        for (self.entries) |entry| {
            if (std.mem.eql(u8, entry.name, name)) return entry.tag;
        }
        return null;
    }

    pub fn getByte(self: *const Compound, name: []const u8) ?i8 {
        const tag = self.get(name) orelse return null;
        return switch (tag) {
            .byte => |v| v,
            else => null,
        };
    }

    pub fn getInt(self: *const Compound, name: []const u8) ?i32 {
        const tag = self.get(name) orelse return null;
        return switch (tag) {
            .int => |v| v,
            else => null,
        };
    }

    pub fn getString(self: *const Compound, name: []const u8) ?[]const u8 {
        const tag = self.get(name) orelse return null;
        return switch (tag) {
            .string => |v| v,
            else => null,
        };
    }

    pub fn getCompound(self: *const Compound, name: []const u8) ?Compound {
        const tag = self.get(name) orelse return null;
        return switch (tag) {
            .compound => |v| v,
            else => null,
        };
    }
};

pub const NbtError = error{
    UnexpectedEndOfData,
    InvalidTagType,
    InvalidListType,
    MissingRootCompound,
};

// ── Serialization ────────────────────────────────────────────────────────

/// Serialize a root named tag to bytes (NBT binary format).
/// Caller owns the returned slice and must free with `allocator`.
pub fn serialize(allocator: std.mem.Allocator, root: NamedTag) ![]u8 {
    var buf = std.ArrayList(u8).empty;
    defer buf.deinit(allocator);
    try writeNamedTag(allocator, &buf, root);
    return buf.toOwnedSlice(allocator);
}

/// Deserialize bytes into a root named tag.
/// The returned tag references heap memory; call `freeTag` to release.
pub fn deserialize(allocator: std.mem.Allocator, data: []const u8) !NamedTag {
    var cursor: usize = 0;
    return readNamedTag(allocator, data, &cursor);
}

// ── Internal: generic int I/O ────────────────────────────────────────────

const WriteError = std.mem.Allocator.Error;
const ReadError = NbtError || std.mem.Allocator.Error;

fn bufWriteInt(comptime T: type, allocator: std.mem.Allocator, buf: *std.ArrayList(u8), val: T) WriteError!void {
    var bytes: [@divExact(@typeInfo(T).int.bits, 8)]u8 = undefined;
    std.mem.writeInt(T, &bytes, val, .big);
    try buf.appendSlice(allocator, &bytes);
}

fn bufReadInt(comptime T: type, data: []const u8, cursor: *usize) ReadError!T {
    const size = comptime @divExact(@typeInfo(T).int.bits, 8);
    if (cursor.* + size > data.len) return error.UnexpectedEndOfData;
    const val = std.mem.readInt(T, data[cursor.*..][0..size], .big);
    cursor.* += size;
    return val;
}

// ── Internal: writing ────────────────────────────────────────────────────

fn writeNamedTag(allocator: std.mem.Allocator, buf: *std.ArrayList(u8), nt: NamedTag) WriteError!void {
    try buf.append(allocator, @intFromEnum(std.meta.activeTag(nt.tag)));
    try bufWriteInt(u16, allocator, buf, @intCast(nt.name.len));
    try buf.appendSlice(allocator, nt.name);
    try writePayload(allocator, buf, nt.tag);
}

fn writePayload(allocator: std.mem.Allocator, buf: *std.ArrayList(u8), tag: Tag) WriteError!void {
    switch (tag) {
        .byte => |v| try buf.append(allocator, @bitCast(v)),
        .short => |v| try bufWriteInt(i16, allocator, buf, v),
        .int => |v| try bufWriteInt(i32, allocator, buf, v),
        .long => |v| try bufWriteInt(i64, allocator, buf, v),
        .float => |v| try bufWriteInt(u32, allocator, buf, @as(u32, @bitCast(v))),
        .double => |v| try bufWriteInt(u64, allocator, buf, @as(u64, @bitCast(v))),
        .byte_array => |v| {
            try bufWriteInt(i32, allocator, buf, @intCast(v.len));
            try buf.appendSlice(allocator, v);
        },
        .string => |v| {
            try bufWriteInt(u16, allocator, buf, @intCast(v.len));
            try buf.appendSlice(allocator, v);
        },
        .list => |v| {
            if (v.len == 0) {
                try buf.append(allocator, @intFromEnum(TagType.byte));
                try bufWriteInt(i32, allocator, buf, 0);
            } else {
                try buf.append(allocator, @intFromEnum(std.meta.activeTag(v[0])));
                try bufWriteInt(i32, allocator, buf, @intCast(v.len));
                for (v) |elem| {
                    try writePayload(allocator, buf, elem);
                }
            }
        },
        .compound => |v| {
            for (v.entries) |entry| {
                try writeNamedTag(allocator, buf, entry);
            }
            try buf.append(allocator, TAG_END);
        },
        .int_array => |v| {
            try bufWriteInt(i32, allocator, buf, @intCast(v.len));
            for (v) |elem| {
                try bufWriteInt(i32, allocator, buf, elem);
            }
        },
        .long_array => |v| {
            try bufWriteInt(i32, allocator, buf, @intCast(v.len));
            for (v) |elem| {
                try bufWriteInt(i64, allocator, buf, elem);
            }
        },
    }
}

// ── Internal: reading ────────────────────────────────────────────────────

fn readByte(data: []const u8, cursor: *usize) ReadError!u8 {
    if (cursor.* >= data.len) return error.UnexpectedEndOfData;
    const b = data[cursor.*];
    cursor.* += 1;
    return b;
}

fn readBytes(allocator: std.mem.Allocator, data: []const u8, cursor: *usize, len: usize) ReadError![]const u8 {
    if (cursor.* + len > data.len) return error.UnexpectedEndOfData;
    const slice = try allocator.alloc(u8, len);
    @memcpy(slice, data[cursor.*..][0..len]);
    cursor.* += len;
    return slice;
}

fn readNamedTag(allocator: std.mem.Allocator, data: []const u8, cursor: *usize) ReadError!NamedTag {
    const type_byte = try readByte(data, cursor);
    if (type_byte == TAG_END) return error.MissingRootCompound;

    const tag_type = std.meta.intToEnum(TagType, type_byte) catch return error.InvalidTagType;
    const name_len = try bufReadInt(u16, data, cursor);
    const name = try readBytes(allocator, data, cursor, name_len);
    const tag = readPayload(allocator, data, cursor, tag_type) catch |err| {
        allocator.free(name);
        return err;
    };
    return NamedTag{ .name = name, .tag = tag };
}

fn readPayload(allocator: std.mem.Allocator, data: []const u8, cursor: *usize, tag_type: TagType) ReadError!Tag {
    switch (tag_type) {
        .byte => return Tag{ .byte = @bitCast(try readByte(data, cursor)) },
        .short => return Tag{ .short = try bufReadInt(i16, data, cursor) },
        .int => return Tag{ .int = try bufReadInt(i32, data, cursor) },
        .long => return Tag{ .long = try bufReadInt(i64, data, cursor) },
        .float => return Tag{ .float = @bitCast(try bufReadInt(u32, data, cursor)) },
        .double => return Tag{ .double = @bitCast(try bufReadInt(u64, data, cursor)) },
        .byte_array => {
            const len: usize = @intCast(try bufReadInt(i32, data, cursor));
            return Tag{ .byte_array = try readBytes(allocator, data, cursor, len) };
        },
        .string => {
            const len = try bufReadInt(u16, data, cursor);
            return Tag{ .string = try readBytes(allocator, data, cursor, len) };
        },
        .list => {
            const elem_byte = try readByte(data, cursor);
            const count: usize = @intCast(try bufReadInt(i32, data, cursor));
            if (count == 0) return Tag{ .list = &.{} };
            const elem_type = std.meta.intToEnum(TagType, elem_byte) catch return error.InvalidListType;
            const items = try allocator.alloc(Tag, count);
            errdefer allocator.free(items);
            for (0..count) |i| {
                items[i] = readPayload(allocator, data, cursor, elem_type) catch |err| {
                    // Free already-parsed elements on failure
                    for (items[0..i]) |prev| freePayload(allocator, prev);
                    return err;
                };
            }
            return Tag{ .list = items };
        },
        .compound => {
            var entries = std.ArrayList(NamedTag).empty;
            errdefer {
                for (entries.items) |entry| {
                    allocator.free(entry.name);
                    freePayload(allocator, entry.tag);
                }
                entries.deinit(allocator);
            }
            while (true) {
                const peek = try readByte(data, cursor);
                if (peek == TAG_END) break;
                const entry_type = std.meta.intToEnum(TagType, peek) catch return error.InvalidTagType;
                const name_len = try bufReadInt(u16, data, cursor);
                const name = try readBytes(allocator, data, cursor, name_len);
                const payload = readPayload(allocator, data, cursor, entry_type) catch |err| {
                    allocator.free(name);
                    return err;
                };
                try entries.append(allocator, NamedTag{ .name = name, .tag = payload });
            }
            return Tag{ .compound = Compound{ .entries = try entries.toOwnedSlice(allocator) } };
        },
        .int_array => {
            const count: usize = @intCast(try bufReadInt(i32, data, cursor));
            const items = try allocator.alloc(i32, count);
            errdefer allocator.free(items);
            for (0..count) |i| {
                items[i] = try bufReadInt(i32, data, cursor);
            }
            return Tag{ .int_array = items };
        },
        .long_array => {
            const count: usize = @intCast(try bufReadInt(i32, data, cursor));
            const items = try allocator.alloc(i64, count);
            errdefer allocator.free(items);
            for (0..count) |i| {
                items[i] = try bufReadInt(i64, data, cursor);
            }
            return Tag{ .long_array = items };
        },
    }
}

// ── Free helper (deep free all allocations from deserialize) ─────────────

/// Recursively free all memory allocated during deserialization.
pub fn freeTag(allocator: std.mem.Allocator, nt: NamedTag) void {
    allocator.free(nt.name);
    freePayload(allocator, nt.tag);
}

fn freePayload(allocator: std.mem.Allocator, tag: Tag) void {
    switch (tag) {
        .byte, .short, .int, .long, .float, .double => {},
        .byte_array => |v| allocator.free(v),
        .string => |v| allocator.free(v),
        .list => |v| {
            for (v) |elem| freePayload(allocator, elem);
            if (v.len > 0) allocator.free(v);
        },
        .compound => |v| {
            for (v.entries) |entry| {
                allocator.free(entry.name);
                freePayload(allocator, entry.tag);
            }
            allocator.free(v.entries);
        },
        .int_array => |v| allocator.free(v),
        .long_array => |v| allocator.free(v),
    }
}

// ── Tests ────────────────────────────────────────────────────────────────

test "round-trip byte tag" {
    const allocator = std.testing.allocator;
    const original = NamedTag{ .name = "myByte", .tag = Tag{ .byte = -42 } };

    const bytes = try serialize(allocator, original);
    defer allocator.free(bytes);

    const restored = try deserialize(allocator, bytes);
    defer freeTag(allocator, restored);

    try std.testing.expectEqualSlices(u8, "myByte", restored.name);
    try std.testing.expectEqual(@as(i8, -42), restored.tag.byte);
}

test "round-trip int tag" {
    const allocator = std.testing.allocator;
    const original = NamedTag{ .name = "score", .tag = Tag{ .int = 123456 } };

    const bytes = try serialize(allocator, original);
    defer allocator.free(bytes);

    const restored = try deserialize(allocator, bytes);
    defer freeTag(allocator, restored);

    try std.testing.expectEqualSlices(u8, "score", restored.name);
    try std.testing.expectEqual(@as(i32, 123456), restored.tag.int);
}

test "round-trip string tag" {
    const allocator = std.testing.allocator;
    const original = NamedTag{ .name = "greeting", .tag = Tag{ .string = "Hello, NBT!" } };

    const bytes = try serialize(allocator, original);
    defer allocator.free(bytes);

    const restored = try deserialize(allocator, bytes);
    defer freeTag(allocator, restored);

    try std.testing.expectEqualSlices(u8, "greeting", restored.name);
    try std.testing.expectEqualSlices(u8, "Hello, NBT!", restored.tag.string);
}

test "round-trip compound with nested compound" {
    const allocator = std.testing.allocator;

    const inner_entries = [_]NamedTag{
        .{ .name = "x", .tag = Tag{ .int = 10 } },
        .{ .name = "y", .tag = Tag{ .int = 64 } },
        .{ .name = "z", .tag = Tag{ .int = -30 } },
    };

    const outer_entries = [_]NamedTag{
        .{ .name = "name", .tag = Tag{ .string = "Player1" } },
        .{ .name = "health", .tag = Tag{ .byte = 20 } },
        .{ .name = "pos", .tag = Tag{ .compound = Compound{ .entries = &inner_entries } } },
    };

    const root = NamedTag{
        .name = "PlayerData",
        .tag = Tag{ .compound = Compound{ .entries = &outer_entries } },
    };

    const bytes = try serialize(allocator, root);
    defer allocator.free(bytes);

    const restored = try deserialize(allocator, bytes);
    defer freeTag(allocator, restored);

    try std.testing.expectEqualSlices(u8, "PlayerData", restored.name);

    const outer = restored.tag.compound;
    try std.testing.expectEqualSlices(u8, "Player1", outer.getString("name").?);
    try std.testing.expectEqual(@as(i8, 20), outer.getByte("health").?);

    const pos = outer.getCompound("pos").?;
    try std.testing.expectEqual(@as(i32, 10), pos.getInt("x").?);
    try std.testing.expectEqual(@as(i32, 64), pos.getInt("y").?);
    try std.testing.expectEqual(@as(i32, -30), pos.getInt("z").?);
}

test "round-trip list of ints" {
    const allocator = std.testing.allocator;

    const items = [_]Tag{
        Tag{ .int = 100 },
        Tag{ .int = 200 },
        Tag{ .int = 300 },
    };

    const original = NamedTag{
        .name = "scores",
        .tag = Tag{ .list = &items },
    };

    const bytes = try serialize(allocator, original);
    defer allocator.free(bytes);

    const restored = try deserialize(allocator, bytes);
    defer freeTag(allocator, restored);

    try std.testing.expectEqualSlices(u8, "scores", restored.name);
    const list = restored.tag.list;
    try std.testing.expectEqual(@as(usize, 3), list.len);
    try std.testing.expectEqual(@as(i32, 100), list[0].int);
    try std.testing.expectEqual(@as(i32, 200), list[1].int);
    try std.testing.expectEqual(@as(i32, 300), list[2].int);
}

test "round-trip int_array" {
    const allocator = std.testing.allocator;

    const arr = [_]i32{ 1, -2, 3, -4 };
    const original = NamedTag{ .name = "data", .tag = Tag{ .int_array = &arr } };

    const bytes = try serialize(allocator, original);
    defer allocator.free(bytes);

    const restored = try deserialize(allocator, bytes);
    defer freeTag(allocator, restored);

    const restored_arr = restored.tag.int_array;
    try std.testing.expectEqual(@as(usize, 4), restored_arr.len);
    try std.testing.expectEqual(@as(i32, 1), restored_arr[0]);
    try std.testing.expectEqual(@as(i32, -2), restored_arr[1]);
    try std.testing.expectEqual(@as(i32, 3), restored_arr[2]);
    try std.testing.expectEqual(@as(i32, -4), restored_arr[3]);
}

test "round-trip all scalar types" {
    const allocator = std.testing.allocator;

    const entries = [_]NamedTag{
        .{ .name = "b", .tag = Tag{ .byte = 127 } },
        .{ .name = "s", .tag = Tag{ .short = -32000 } },
        .{ .name = "i", .tag = Tag{ .int = 2_000_000 } },
        .{ .name = "l", .tag = Tag{ .long = 9_000_000_000 } },
        .{ .name = "f", .tag = Tag{ .float = 3.14 } },
        .{ .name = "d", .tag = Tag{ .double = 2.718281828 } },
    };

    const root = NamedTag{
        .name = "scalars",
        .tag = Tag{ .compound = Compound{ .entries = &entries } },
    };

    const bytes = try serialize(allocator, root);
    defer allocator.free(bytes);

    const restored = try deserialize(allocator, bytes);
    defer freeTag(allocator, restored);

    const c = restored.tag.compound;
    try std.testing.expectEqual(@as(i8, 127), c.getByte("b").?);
    try std.testing.expectEqual(@as(i32, 2_000_000), c.getInt("i").?);

    const f_tag = c.get("f").?;
    try std.testing.expectApproxEqAbs(@as(f32, 3.14), f_tag.float, 0.001);

    const d_tag = c.get("d").?;
    try std.testing.expectApproxEqAbs(@as(f64, 2.718281828), d_tag.double, 0.000001);
}

test "compound get returns null for missing key" {
    const entries = [_]NamedTag{
        .{ .name = "a", .tag = Tag{ .int = 1 } },
    };
    const c = Compound{ .entries = &entries };

    try std.testing.expect(c.get("missing") == null);
    try std.testing.expect(c.getByte("a") == null);
    try std.testing.expect(c.getInt("missing") == null);
    try std.testing.expect(c.getString("a") == null);
    try std.testing.expect(c.getCompound("a") == null);
}

test "deserialize rejects truncated data" {
    const allocator = std.testing.allocator;
    const bad_data = [_]u8{ @intFromEnum(TagType.int), 0, 2, 'h', 'i' };
    try std.testing.expectError(error.UnexpectedEndOfData, deserialize(allocator, &bad_data));
}

test "deserialize rejects invalid tag type" {
    const allocator = std.testing.allocator;
    const bad_data = [_]u8{ 0xFF, 0, 1, 'x', 0 };
    try std.testing.expectError(error.InvalidTagType, deserialize(allocator, &bad_data));
}
