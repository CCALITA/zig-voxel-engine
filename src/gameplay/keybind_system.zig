const std = @import("std");

pub const Action = enum(u8) {
    move_forward,
    move_back,
    move_left,
    move_right,
    jump,
    sneak,
    sprint,
    inventory,
    chat,
    drop_item,
    hotbar_1,
    hotbar_2,
    hotbar_3,
    hotbar_4,
    hotbar_5,
    hotbar_6,
    hotbar_7,
    hotbar_8,
    hotbar_9,
    attack,
    use_item,
    pick_block,
};

pub const KeyCode = u16;

const action_count = @typeInfo(Action).@"enum".fields.len;

// Default key codes
const key_w: KeyCode = 87;
const key_a: KeyCode = 65;
const key_s: KeyCode = 83;
const key_d: KeyCode = 68;
const key_space: KeyCode = 32;
const key_shift: KeyCode = 340;
const key_ctrl: KeyCode = 341;
const key_e: KeyCode = 69;
const key_t: KeyCode = 84;
const key_q: KeyCode = 81;
const key_1: KeyCode = 49;
const key_2: KeyCode = 50;
const key_3: KeyCode = 51;
const key_4: KeyCode = 52;
const key_5: KeyCode = 53;
const key_6: KeyCode = 54;
const key_7: KeyCode = 55;
const key_8: KeyCode = 56;
const key_9: KeyCode = 57;
const mouse_left: KeyCode = 0;
const mouse_right: KeyCode = 1;
const mouse_middle: KeyCode = 2;

pub const Keybinds = struct {
    bindings: [action_count]KeyCode,

    pub fn init() Keybinds {
        return .{
            .bindings = .{
                key_w, // move_forward
                key_s, // move_back
                key_a, // move_left
                key_d, // move_right
                key_space, // jump
                key_shift, // sneak
                key_ctrl, // sprint
                key_e, // inventory
                key_t, // chat
                key_q, // drop_item
                key_1, // hotbar_1
                key_2, // hotbar_2
                key_3, // hotbar_3
                key_4, // hotbar_4
                key_5, // hotbar_5
                key_6, // hotbar_6
                key_7, // hotbar_7
                key_8, // hotbar_8
                key_9, // hotbar_9
                mouse_left, // attack
                mouse_right, // use_item
                mouse_middle, // pick_block
            },
        };
    }

    /// Get the key code bound to a given action.
    pub fn getKey(self: *const Keybinds, action: Action) KeyCode {
        return self.bindings[@intFromEnum(action)];
    }

    /// Set the key code for a given action, returning a new Keybinds.
    pub fn setKey(self: *const Keybinds, action: Action, key: KeyCode) Keybinds {
        var updated = self.*;
        updated.bindings[@intFromEnum(action)] = key;
        return updated;
    }

    /// Reverse lookup: find which action is bound to a given key code.
    /// Returns null if no action is bound to that key.
    pub fn getAction(self: *const Keybinds, key: KeyCode) ?Action {
        for (self.bindings, 0..) |bound_key, i| {
            if (bound_key == key) {
                return @enumFromInt(i);
            }
        }
        return null;
    }
};

// ─── Tests ───────────────────────────────────────────────────────────

test "init sets default WASD bindings" {
    const kb = Keybinds.init();
    try std.testing.expectEqual(@as(KeyCode, key_w), kb.getKey(.move_forward));
    try std.testing.expectEqual(@as(KeyCode, key_a), kb.getKey(.move_left));
    try std.testing.expectEqual(@as(KeyCode, key_s), kb.getKey(.move_back));
    try std.testing.expectEqual(@as(KeyCode, key_d), kb.getKey(.move_right));
}

test "init sets default jump and sneak" {
    const kb = Keybinds.init();
    try std.testing.expectEqual(@as(KeyCode, key_space), kb.getKey(.jump));
    try std.testing.expectEqual(@as(KeyCode, key_shift), kb.getKey(.sneak));
    try std.testing.expectEqual(@as(KeyCode, key_ctrl), kb.getKey(.sprint));
}

test "init sets default inventory chat drop" {
    const kb = Keybinds.init();
    try std.testing.expectEqual(@as(KeyCode, key_e), kb.getKey(.inventory));
    try std.testing.expectEqual(@as(KeyCode, key_t), kb.getKey(.chat));
    try std.testing.expectEqual(@as(KeyCode, key_q), kb.getKey(.drop_item));
}

test "init sets default hotbar keys 1-9" {
    const kb = Keybinds.init();
    try std.testing.expectEqual(@as(KeyCode, key_1), kb.getKey(.hotbar_1));
    try std.testing.expectEqual(@as(KeyCode, key_5), kb.getKey(.hotbar_5));
    try std.testing.expectEqual(@as(KeyCode, key_9), kb.getKey(.hotbar_9));
}

test "init sets default mouse buttons" {
    const kb = Keybinds.init();
    try std.testing.expectEqual(@as(KeyCode, mouse_left), kb.getKey(.attack));
    try std.testing.expectEqual(@as(KeyCode, mouse_right), kb.getKey(.use_item));
    try std.testing.expectEqual(@as(KeyCode, mouse_middle), kb.getKey(.pick_block));
}

test "setKey returns updated bindings without mutating original" {
    const original = Keybinds.init();
    const updated = original.setKey(.jump, 999);
    try std.testing.expectEqual(@as(KeyCode, 999), updated.getKey(.jump));
    // original is unchanged
    try std.testing.expectEqual(@as(KeyCode, key_space), original.getKey(.jump));
}

test "setKey preserves other bindings" {
    const original = Keybinds.init();
    const updated = original.setKey(.move_forward, 200);
    try std.testing.expectEqual(@as(KeyCode, 200), updated.getKey(.move_forward));
    try std.testing.expectEqual(@as(KeyCode, key_a), updated.getKey(.move_left));
    try std.testing.expectEqual(@as(KeyCode, key_s), updated.getKey(.move_back));
}

test "getAction returns correct action for bound key" {
    const kb = Keybinds.init();
    try std.testing.expectEqual(@as(?Action, .move_forward), kb.getAction(key_w));
    try std.testing.expectEqual(@as(?Action, .jump), kb.getAction(key_space));
    try std.testing.expectEqual(@as(?Action, .attack), kb.getAction(mouse_left));
}

test "getAction returns null for unbound key" {
    const kb = Keybinds.init();
    try std.testing.expectEqual(@as(?Action, null), kb.getAction(12345));
    try std.testing.expectEqual(@as(?Action, null), kb.getAction(999));
}

test "getAction reflects rebound keys" {
    const kb = Keybinds.init().setKey(.jump, 500);
    try std.testing.expectEqual(@as(?Action, .jump), kb.getAction(500));
    // Old jump key (space=32) now resolves to null since nothing else uses it
    try std.testing.expectEqual(@as(?Action, null), kb.getAction(key_space));
}

test "action enum count matches bindings array length" {
    try std.testing.expectEqual(@as(usize, 22), action_count);
    const kb = Keybinds.init();
    try std.testing.expectEqual(@as(usize, 22), kb.bindings.len);
}

test "all hotbar keys map sequentially from 49 to 57" {
    const kb = Keybinds.init();
    const hotbar_actions = [_]Action{
        .hotbar_1, .hotbar_2, .hotbar_3,
        .hotbar_4, .hotbar_5, .hotbar_6,
        .hotbar_7, .hotbar_8, .hotbar_9,
    };
    for (hotbar_actions, 0..) |action, i| {
        try std.testing.expectEqual(@as(KeyCode, @intCast(49 + i)), kb.getKey(action));
    }
}

test "chained setKey calls produce correct final state" {
    const kb = Keybinds.init()
        .setKey(.move_forward, 300)
        .setKey(.move_back, 301)
        .setKey(.attack, 302);
    try std.testing.expectEqual(@as(KeyCode, 300), kb.getKey(.move_forward));
    try std.testing.expectEqual(@as(KeyCode, 301), kb.getKey(.move_back));
    try std.testing.expectEqual(@as(KeyCode, 302), kb.getKey(.attack));
    // Unchanged binding
    try std.testing.expectEqual(@as(KeyCode, key_d), kb.getKey(.move_right));
}
