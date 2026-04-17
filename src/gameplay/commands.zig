/// Commands: parses and executes slash-style chat commands.
/// Supports /time, /tp, /give, /gamemode, /help.
const std = @import("std");

pub const CommandType = enum {
    time,
    tp,
    give,
    gamemode,
    help,
    unknown,
};

pub const Command = struct {
    cmd_type: CommandType,
    raw: []const u8,
};

pub const ExecuteResult = struct {
    success: bool,
    message: []const u8,
};

/// Parse a raw input string (e.g. "/time set day") into a Command.
/// The input may or may not start with '/'.
pub fn parse(input: []const u8) Command {
    const trimmed = std.mem.trim(u8, input, " \t\r\n");
    if (trimmed.len == 0) {
        return .{ .cmd_type = .unknown, .raw = trimmed };
    }

    // Strip leading '/' if present
    const body = if (trimmed[0] == '/') trimmed[1..] else trimmed;

    if (body.len == 0) {
        return .{ .cmd_type = .unknown, .raw = trimmed };
    }

    const cmd_type = identifyCommand(body);
    return .{ .cmd_type = cmd_type, .raw = body };
}

/// Execute a parsed command. Returns a result with a human-readable message.
pub fn execute(cmd: Command) ExecuteResult {
    return switch (cmd.cmd_type) {
        .time => executeTime(cmd.raw),
        .tp => executeTp(cmd.raw),
        .give => executeGive(cmd.raw),
        .gamemode => executeGamemode(cmd.raw),
        .help => .{ .success = true, .message = "Commands: /time, /tp, /give, /gamemode, /help" },
        .unknown => .{ .success = false, .message = "Unknown command. Type /help for a list." },
    };
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

fn identifyCommand(body: []const u8) CommandType {
    // Find the first word
    const word_end = std.mem.indexOfScalar(u8, body, ' ') orelse body.len;
    const word = body[0..word_end];

    if (std.mem.eql(u8, word, "time")) return .time;
    if (std.mem.eql(u8, word, "tp")) return .tp;
    if (std.mem.eql(u8, word, "give")) return .give;
    if (std.mem.eql(u8, word, "gamemode")) return .gamemode;
    if (std.mem.eql(u8, word, "help")) return .help;
    return .unknown;
}

fn executeTime(raw: []const u8) ExecuteResult {
    // Expected: "time set day|night|noon" or "time set <number>"
    const args_start = std.mem.indexOfScalar(u8, raw, ' ');
    if (args_start == null) {
        return .{ .success = false, .message = "Usage: /time set <day|night|noon>" };
    }

    const args = std.mem.trim(u8, raw[args_start.?..], " ");
    if (std.mem.startsWith(u8, args, "set ")) {
        const value = std.mem.trim(u8, args[4..], " ");
        if (std.mem.eql(u8, value, "day") or
            std.mem.eql(u8, value, "night") or
            std.mem.eql(u8, value, "noon"))
        {
            return .{ .success = true, .message = "Time updated." };
        }
        // Try numeric
        _ = std.fmt.parseInt(u32, value, 10) catch {
            return .{ .success = false, .message = "Invalid time value." };
        };
        return .{ .success = true, .message = "Time updated." };
    }

    return .{ .success = false, .message = "Usage: /time set <day|night|noon>" };
}

fn executeTp(raw: []const u8) ExecuteResult {
    // Expected: "tp <x> <y> <z>"
    const args_start = std.mem.indexOfScalar(u8, raw, ' ') orelse {
        return .{ .success = false, .message = "Usage: /tp <x> <y> <z>" };
    };

    const args = std.mem.trim(u8, raw[args_start..], " ");
    var it = std.mem.splitScalar(u8, args, ' ');
    const x_str = it.next() orelse return .{ .success = false, .message = "Usage: /tp <x> <y> <z>" };
    const y_str = it.next() orelse return .{ .success = false, .message = "Usage: /tp <x> <y> <z>" };
    const z_str = it.next() orelse return .{ .success = false, .message = "Usage: /tp <x> <y> <z>" };

    _ = std.fmt.parseFloat(f32, x_str) catch return .{ .success = false, .message = "Invalid coordinates." };
    _ = std.fmt.parseFloat(f32, y_str) catch return .{ .success = false, .message = "Invalid coordinates." };
    _ = std.fmt.parseFloat(f32, z_str) catch return .{ .success = false, .message = "Invalid coordinates." };

    return .{ .success = true, .message = "Teleported." };
}

fn executeGive(raw: []const u8) ExecuteResult {
    // Expected: "give <item_id> [count]"
    const args_start = std.mem.indexOfScalar(u8, raw, ' ') orelse {
        return .{ .success = false, .message = "Usage: /give <item_id> [count]" };
    };

    const args = std.mem.trim(u8, raw[args_start..], " ");
    var it = std.mem.splitScalar(u8, args, ' ');
    const id_str = it.next() orelse return .{ .success = false, .message = "Usage: /give <item_id> [count]" };

    _ = std.fmt.parseInt(u16, id_str, 10) catch return .{ .success = false, .message = "Invalid item ID." };

    // Optional count
    if (it.next()) |count_str| {
        _ = std.fmt.parseInt(u8, count_str, 10) catch return .{ .success = false, .message = "Invalid count." };
    }

    return .{ .success = true, .message = "Item given." };
}

fn executeGamemode(raw: []const u8) ExecuteResult {
    // Expected: "gamemode <survival|creative|adventure|spectator>"
    const args_start = std.mem.indexOfScalar(u8, raw, ' ') orelse {
        return .{ .success = false, .message = "Usage: /gamemode <survival|creative|adventure|spectator>" };
    };

    const mode = std.mem.trim(u8, raw[args_start..], " ");
    if (std.mem.eql(u8, mode, "survival") or
        std.mem.eql(u8, mode, "creative") or
        std.mem.eql(u8, mode, "adventure") or
        std.mem.eql(u8, mode, "spectator"))
    {
        return .{ .success = true, .message = "Game mode updated." };
    }

    return .{ .success = false, .message = "Unknown game mode." };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "parse recognizes /time command" {
    const cmd = parse("/time set day");
    try std.testing.expectEqual(CommandType.time, cmd.cmd_type);
}

test "parse recognizes /tp command" {
    const cmd = parse("/tp 10 65 20");
    try std.testing.expectEqual(CommandType.tp, cmd.cmd_type);
}

test "parse recognizes /give command" {
    const cmd = parse("/give 1 64");
    try std.testing.expectEqual(CommandType.give, cmd.cmd_type);
}

test "parse recognizes /gamemode command" {
    const cmd = parse("/gamemode creative");
    try std.testing.expectEqual(CommandType.gamemode, cmd.cmd_type);
}

test "parse recognizes /help command" {
    const cmd = parse("/help");
    try std.testing.expectEqual(CommandType.help, cmd.cmd_type);
}

test "parse returns unknown for invalid command" {
    const cmd = parse("/foobar");
    try std.testing.expectEqual(CommandType.unknown, cmd.cmd_type);
}

test "parse handles empty input" {
    const cmd = parse("");
    try std.testing.expectEqual(CommandType.unknown, cmd.cmd_type);
}

test "parse handles input without slash" {
    const cmd = parse("help");
    try std.testing.expectEqual(CommandType.help, cmd.cmd_type);
}

test "parse trims whitespace" {
    const cmd = parse("  /time set day  ");
    try std.testing.expectEqual(CommandType.time, cmd.cmd_type);
}

test "execute time set day succeeds" {
    const cmd = parse("/time set day");
    const result = execute(cmd);
    try std.testing.expect(result.success);
}

test "execute time set night succeeds" {
    const cmd = parse("/time set night");
    const result = execute(cmd);
    try std.testing.expect(result.success);
}

test "execute time set noon succeeds" {
    const cmd = parse("/time set noon");
    const result = execute(cmd);
    try std.testing.expect(result.success);
}

test "execute time set numeric succeeds" {
    const cmd = parse("/time set 6000");
    const result = execute(cmd);
    try std.testing.expect(result.success);
}

test "execute time without args fails" {
    const cmd = parse("/time");
    const result = execute(cmd);
    try std.testing.expect(!result.success);
}

test "execute time set invalid value fails" {
    const cmd = parse("/time set xyz");
    const result = execute(cmd);
    try std.testing.expect(!result.success);
}

test "execute tp with valid coords succeeds" {
    const cmd = parse("/tp 10.5 65.0 -20.3");
    const result = execute(cmd);
    try std.testing.expect(result.success);
}

test "execute tp without enough args fails" {
    const cmd = parse("/tp 10");
    const result = execute(cmd);
    try std.testing.expect(!result.success);
}

test "execute tp with invalid coords fails" {
    const cmd = parse("/tp abc 65 20");
    const result = execute(cmd);
    try std.testing.expect(!result.success);
}

test "execute give with item id succeeds" {
    const cmd = parse("/give 1");
    const result = execute(cmd);
    try std.testing.expect(result.success);
}

test "execute give with item id and count succeeds" {
    const cmd = parse("/give 1 64");
    const result = execute(cmd);
    try std.testing.expect(result.success);
}

test "execute give without args fails" {
    const cmd = parse("/give");
    const result = execute(cmd);
    try std.testing.expect(!result.success);
}

test "execute gamemode creative succeeds" {
    const cmd = parse("/gamemode creative");
    const result = execute(cmd);
    try std.testing.expect(result.success);
}

test "execute gamemode invalid fails" {
    const cmd = parse("/gamemode hardcore");
    const result = execute(cmd);
    try std.testing.expect(!result.success);
}

test "execute help succeeds" {
    const cmd = parse("/help");
    const result = execute(cmd);
    try std.testing.expect(result.success);
    try std.testing.expect(result.message.len > 0);
}

test "execute unknown command fails" {
    const cmd = parse("/foobar");
    const result = execute(cmd);
    try std.testing.expect(!result.success);
}
