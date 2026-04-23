/// Chat display overlay that renders recent chat messages in the bottom-left
/// corner of the screen, just above the hotbar. Messages fade out after 10
/// seconds. Each line has a dark semi-transparent background. All quads use
/// u=-1, v=-1 (untextured flat colour).
const std = @import("std");

// ── Public types ────────────────────────────────────────────────────

pub const UiVertex = extern struct {
    pos_x: f32,
    pos_y: f32,
    r: f32,
    g: f32,
    b: f32,
    a: f32,
    u: f32,
    v: f32,
};

pub const ChatMessage = struct {
    text_len: u8 = 0,
    age: f32 = 0,
    color_r: f32 = 1,
    color_g: f32 = 1,
    color_b: f32 = 1,
};

pub const ChatHistory = struct {
    messages: [max_messages]ChatMessage = [_]ChatMessage{.{}} ** max_messages,
    count: u8 = 0,

    /// Push a new message with the given text length onto the history.
    /// Oldest message is discarded when the buffer is full.
    pub fn addMessage(self: *ChatHistory, len: u8) void {
        if (self.count < max_messages) {
            self.messages[self.count] = .{ .text_len = len };
            self.count += 1;
        } else {
            // Shift all messages down by one, dropping the oldest.
            var i: u8 = 0;
            while (i < max_messages - 1) : (i += 1) {
                self.messages[i] = self.messages[i + 1];
            }
            self.messages[max_messages - 1] = .{ .text_len = len };
        }
    }

    /// Advance the age of every message by `dt` seconds.
    pub fn update(self: *ChatHistory, dt: f32) void {
        var i: u8 = 0;
        while (i < self.count) : (i += 1) {
            self.messages[i].age += dt;
        }
    }

    /// Emit quads for visible (non-expired) messages into `verts` starting at
    /// `start`. Messages are positioned bottom-left, stacking upward from just
    /// above the hotbar. Returns the next free vertex index.
    pub fn render(self: *const ChatHistory, verts: []UiVertex, start: u32, sw: f32, sh: f32) u32 {
        _ = sw;
        var idx = start;

        // Count visible (non-expired) messages.
        var visible_count: u8 = 0;
        var vi: u8 = 0;
        while (vi < self.count) : (vi += 1) {
            if (self.messages[vi].age < fade_end) {
                visible_count += 1;
            }
        }
        if (visible_count == 0) return idx;

        // Render visible messages bottom-up, newest at the bottom.
        // base_y is the bottom edge of the lowest chat row.
        const base_y = sh - hotbar_offset;
        var row: u8 = 0;
        var mi: u8 = 0;
        while (mi < self.count) : (mi += 1) {
            const msg = self.messages[mi];
            if (msg.age >= fade_end) continue;

            const alpha = messageAlpha(msg.age);
            // Position: newest message at bottom, older ones stack upward.
            // row 0 is the topmost visible row.
            const row_y = base_y - @as(f32, @floatFromInt(visible_count - row)) * row_height;

            // Dark background for this line.
            const line_w = margin_left + @as(f32, @floatFromInt(msg.text_len)) * char_width;
            idx = addQuad(verts, idx, margin_left, row_y, line_w, row_height, .{
                bg_color[0],
                bg_color[1],
                bg_color[2],
                bg_color[3] * alpha,
            });

            // Text placeholder bar (represents text glyphs).
            const text_y = row_y + text_pad_y;
            const text_w = @as(f32, @floatFromInt(msg.text_len)) * char_width;
            idx = addQuad(verts, idx, margin_left + text_pad_x, text_y, text_w, text_height, .{
                msg.color_r,
                msg.color_g,
                msg.color_b,
                alpha,
            });

            row += 1;
        }

        return idx;
    }
};

// ── Constants ───────────────────────────────────────────────────────

const max_messages: u8 = 10;

/// Messages fully visible for this long (seconds), then start fading.
const fade_start: f32 = 10.0;
/// Fade-out duration after fade_start.
const fade_duration: f32 = 1.0;
/// Total lifetime before a message is considered expired.
const fade_end: f32 = fade_start + fade_duration;

const row_height: f32 = 12.0;
const margin_left: f32 = 4.0;
const hotbar_offset: f32 = 52.0;
const text_pad_x: f32 = 2.0;
const text_pad_y: f32 = 2.0;
const text_height: f32 = 8.0;
const char_width: f32 = 6.0;

const bg_color = [4]f32{ 0.0, 0.0, 0.0, 0.4 };

// ── Quad helper ─────────────────────────────────────────────────────

/// Emit a solid-colour quad (2 triangles, 6 vertices). UV = -1 (untextured).
fn addQuad(verts: []UiVertex, start: u32, x: f32, y: f32, w: f32, h: f32, col: [4]f32) u32 {
    if (start + 6 > verts.len) return start;
    const x1 = x + w;
    const y1 = y + h;
    const r = col[0];
    const g = col[1];
    const b = col[2];
    const a = col[3];

    verts[start + 0] = .{ .pos_x = x, .pos_y = y, .r = r, .g = g, .b = b, .a = a, .u = -1, .v = -1 };
    verts[start + 1] = .{ .pos_x = x1, .pos_y = y, .r = r, .g = g, .b = b, .a = a, .u = -1, .v = -1 };
    verts[start + 2] = .{ .pos_x = x1, .pos_y = y1, .r = r, .g = g, .b = b, .a = a, .u = -1, .v = -1 };
    verts[start + 3] = .{ .pos_x = x, .pos_y = y, .r = r, .g = g, .b = b, .a = a, .u = -1, .v = -1 };
    verts[start + 4] = .{ .pos_x = x1, .pos_y = y1, .r = r, .g = g, .b = b, .a = a, .u = -1, .v = -1 };
    verts[start + 5] = .{ .pos_x = x, .pos_y = y1, .r = r, .g = g, .b = b, .a = a, .u = -1, .v = -1 };

    return start + 6;
}

// ── Fade logic ──────────────────────────────────────────────────────

/// Compute the alpha multiplier for a message based on its age.
fn messageAlpha(age: f32) f32 {
    if (age < fade_start) return 1.0;
    if (age >= fade_end) return 0.0;
    return 1.0 - (age - fade_start) / fade_duration;
}

// ── Tests ───────────────────────────────────────────────────────────

const testing = std.testing;

test "addMessage increments count" {
    var chat = ChatHistory{};
    try testing.expectEqual(@as(u8, 0), chat.count);
    chat.addMessage(5);
    try testing.expectEqual(@as(u8, 1), chat.count);
    try testing.expectEqual(@as(u8, 5), chat.messages[0].text_len);
    try testing.expectEqual(@as(f32, 0), chat.messages[0].age);
}

test "addMessage wraps when full" {
    var chat = ChatHistory{};
    var i: u8 = 0;
    while (i < max_messages) : (i += 1) {
        chat.addMessage(i + 1);
    }
    try testing.expectEqual(max_messages, chat.count);
    // Buffer full; add one more to evict the oldest.
    chat.addMessage(99);
    try testing.expectEqual(max_messages, chat.count);
    // First message should now be what was second (text_len = 2).
    try testing.expectEqual(@as(u8, 2), chat.messages[0].text_len);
    // Last message should be the new one.
    try testing.expectEqual(@as(u8, 99), chat.messages[max_messages - 1].text_len);
}

test "update advances message ages" {
    var chat = ChatHistory{};
    chat.addMessage(3);
    chat.addMessage(7);
    chat.update(2.5);
    try testing.expectApproxEqAbs(@as(f32, 2.5), chat.messages[0].age, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 2.5), chat.messages[1].age, 0.001);
}

test "messageAlpha returns 1 before fade_start" {
    try testing.expectEqual(@as(f32, 1.0), messageAlpha(0.0));
    try testing.expectEqual(@as(f32, 1.0), messageAlpha(5.0));
    try testing.expectEqual(@as(f32, 1.0), messageAlpha(9.99));
}

test "messageAlpha fades between fade_start and fade_end" {
    const mid = fade_start + fade_duration * 0.5;
    const a = messageAlpha(mid);
    try testing.expect(a > 0.0);
    try testing.expect(a < 1.0);
    try testing.expectApproxEqAbs(@as(f32, 0.5), a, 0.01);
}

test "messageAlpha returns 0 at and beyond fade_end" {
    try testing.expectEqual(@as(f32, 0.0), messageAlpha(fade_end));
    try testing.expectEqual(@as(f32, 0.0), messageAlpha(fade_end + 5.0));
}

test "render returns start when no messages" {
    const chat = ChatHistory{};
    var buf: [256]UiVertex = undefined;
    const c = chat.render(&buf, 0, 800.0, 600.0);
    try testing.expectEqual(@as(u32, 0), c);
}

test "render produces quads for visible messages" {
    var chat = ChatHistory{};
    chat.addMessage(10);
    var buf: [256]UiVertex = undefined;
    const c = chat.render(&buf, 0, 800.0, 600.0);
    // Each message produces 2 quads (background + text bar) = 12 verts.
    try testing.expect(c > 0);
    try testing.expect(c % 6 == 0);
    try testing.expectEqual(@as(u32, 12), c);
}

test "render skips expired messages" {
    var chat = ChatHistory{};
    chat.addMessage(10);
    chat.update(fade_end + 1.0); // expire the message
    var buf: [256]UiVertex = undefined;
    const c = chat.render(&buf, 0, 800.0, 600.0);
    try testing.expectEqual(@as(u32, 0), c);
}

test "render positions messages above hotbar" {
    var chat = ChatHistory{};
    chat.addMessage(5);
    const sh: f32 = 600.0;
    var buf: [256]UiVertex = undefined;
    _ = chat.render(&buf, 0, 800.0, sh);
    // The background quad top-left Y should be near the bottom of screen.
    const msg_y = buf[0].pos_y;
    try testing.expect(msg_y > sh * 0.5);
    try testing.expect(msg_y < sh);
}

test "all rendered vertices have u=-1 and v=-1" {
    var chat = ChatHistory{};
    chat.addMessage(8);
    var buf: [256]UiVertex = undefined;
    const c = chat.render(&buf, 0, 1920.0, 1080.0);
    var i: u32 = 0;
    while (i < c) : (i += 1) {
        try testing.expectApproxEqAbs(@as(f32, -1.0), buf[i].u, 0.001);
        try testing.expectApproxEqAbs(@as(f32, -1.0), buf[i].v, 0.001);
    }
}

test "render respects start offset" {
    var chat = ChatHistory{};
    chat.addMessage(4);
    var buf: [256]UiVertex = undefined;
    const offset: u32 = 18;
    const c = chat.render(&buf, offset, 800.0, 600.0);
    try testing.expect(c >= offset);
    try testing.expect((c - offset) % 6 == 0);
}

test "fading message has reduced alpha" {
    var chat = ChatHistory{};
    chat.addMessage(5);
    chat.update(fade_start + fade_duration * 0.5); // halfway through fade
    var buf: [256]UiVertex = undefined;
    const c = chat.render(&buf, 0, 800.0, 600.0);
    try testing.expect(c > 0);
    // The text bar quad starts at vertex 6; check its alpha.
    try testing.expect(buf[6].a > 0.0);
    try testing.expect(buf[6].a < 1.0);
}

test "buffer overflow protection" {
    var chat = ChatHistory{};
    chat.addMessage(20);
    var small: [6]UiVertex = undefined;
    const c = chat.render(&small, 0, 800.0, 600.0);
    // Only room for 1 quad (bg), text bar won't fit.
    try testing.expect(c <= 6);
}

test "multiple messages produce more vertices" {
    var chat1 = ChatHistory{};
    chat1.addMessage(5);
    var buf1: [512]UiVertex = undefined;
    const c1 = chat1.render(&buf1, 0, 800.0, 600.0);

    var chat2 = ChatHistory{};
    chat2.addMessage(5);
    chat2.addMessage(8);
    chat2.addMessage(3);
    var buf2: [512]UiVertex = undefined;
    const c2 = chat2.render(&buf2, 0, 800.0, 600.0);

    try testing.expect(c2 > c1);
}
