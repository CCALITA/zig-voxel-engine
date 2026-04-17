const std = @import("std");

pub const CommandResult = struct {
    success: bool,
    message: [256]u8,
    message_len: u8,

    fn make(success: bool, comptime fmt: []const u8, args: anytype) CommandResult {
        var result = CommandResult{
            .success = success,
            .message = [_]u8{0} ** 256,
            .message_len = 0,
        };
        const written = std.fmt.bufPrint(&result.message, fmt, args) catch |e| switch (e) {
            error.NoSpaceLeft => &result.message,
        };
        result.message_len = @intCast(written.len);
        return result;
    }

    pub fn ok(comptime fmt: []const u8, args: anytype) CommandResult {
        return make(true, fmt, args);
    }

    pub fn err(comptime fmt: []const u8, args: anytype) CommandResult {
        return make(false, fmt, args);
    }

    pub fn msg(self: *const CommandResult) []const u8 {
        return self.message[0..self.message_len];
    }
};

pub const CommandType = enum {
    gamemode,
    tp,
    give,
    time,
    weather,
    kill,
    seed,
    help,
    unknown,
};

const ParsedInput = struct {
    command: []const u8,
    args: []const u8,
};

/// Strips leading whitespace and '/', then splits into command name and args.
fn splitInput(input: []const u8) ParsedInput {
    const trimmed = std.mem.trimLeft(u8, input, " ");
    const stripped = if (trimmed.len > 0 and trimmed[0] == '/') trimmed[1..] else trimmed;
    const cmd_end = std.mem.indexOfScalar(u8, stripped, ' ') orelse stripped.len;
    return .{
        .command = stripped[0..cmd_end],
        .args = if (cmd_end < stripped.len) std.mem.trimLeft(u8, stripped[cmd_end + 1 ..], " ") else "",
    };
}

/// Parses a raw input string (with or without leading '/') and returns the CommandType.
pub fn parse(input: []const u8) CommandType {
    const parsed = splitInput(input);
    return matchCommand(parsed.command);
}

fn matchCommand(name: []const u8) CommandType {
    const commands = .{
        .{ "gamemode", CommandType.gamemode },
        .{ "tp", CommandType.tp },
        .{ "give", CommandType.give },
        .{ "time", CommandType.time },
        .{ "weather", CommandType.weather },
        .{ "kill", CommandType.kill },
        .{ "seed", CommandType.seed },
        .{ "help", CommandType.help },
    };
    inline for (commands) |entry| {
        if (std.mem.eql(u8, name, entry[0])) return entry[1];
    }
    return .unknown;
}

/// Executes a command given its type and the argument string.
pub fn execute(cmd_type: CommandType, args: []const u8) CommandResult {
    return switch (cmd_type) {
        .gamemode => cmdGamemode(args),
        .tp => cmdTp(args),
        .give => cmdGive(args),
        .time => cmdTime(args),
        .weather => cmdWeather(args),
        .kill => cmdKill(args),
        .seed => cmdSeed(args),
        .help => cmdHelp(args),
        .unknown => CommandResult.err("Unknown command. Type /help for a list of commands.", .{}),
    };
}

/// Convenience: parse + extract args + execute in one call.
pub fn run(input: []const u8) CommandResult {
    const parsed = splitInput(input);
    return execute(matchCommand(parsed.command), parsed.args);
}

// ---------------------------------------------------------------------------
// Individual command handlers
// ---------------------------------------------------------------------------

fn cmdGamemode(args: []const u8) CommandResult {
    if (args.len == 0) {
        return CommandResult.err("Usage: /gamemode <survival|creative|adventure|spectator>", .{});
    }
    const valid_modes = [_][]const u8{ "survival", "creative", "adventure", "spectator" };
    for (valid_modes) |v| {
        if (std.mem.eql(u8, args, v)) {
            return CommandResult.ok("Game mode set to {s}", .{v});
        }
    }
    return CommandResult.err("Unknown game mode: {s}", .{args});
}

fn cmdTp(args: []const u8) CommandResult {
    if (args.len == 0) {
        return CommandResult.err("Usage: /tp <x> <y> <z>", .{});
    }
    var it = std.mem.tokenizeScalar(u8, args, ' ');
    const x_str = it.next() orelse return CommandResult.err("Usage: /tp <x> <y> <z>", .{});
    const y_str = it.next() orelse return CommandResult.err("Usage: /tp <x> <y> <z>", .{});
    const z_str = it.next() orelse return CommandResult.err("Usage: /tp <x> <y> <z>", .{});
    const x = std.fmt.parseFloat(f64, x_str) catch return CommandResult.err("Invalid x coordinate: {s}", .{x_str});
    const y = std.fmt.parseFloat(f64, y_str) catch return CommandResult.err("Invalid y coordinate: {s}", .{y_str});
    const z = std.fmt.parseFloat(f64, z_str) catch return CommandResult.err("Invalid z coordinate: {s}", .{z_str});
    return CommandResult.ok("Teleported to ({d:.1}, {d:.1}, {d:.1})", .{ x, y, z });
}

fn cmdGive(args: []const u8) CommandResult {
    if (args.len == 0) {
        return CommandResult.err("Usage: /give <item_id> [count]", .{});
    }
    var it = std.mem.tokenizeScalar(u8, args, ' ');
    const item_id = it.next() orelse return CommandResult.err("Usage: /give <item_id> [count]", .{});
    const count_str = it.next() orelse "1";
    const count = std.fmt.parseInt(u32, count_str, 10) catch return CommandResult.err("Invalid count: {s}", .{count_str});
    if (count == 0) return CommandResult.err("Count must be at least 1", .{});
    return CommandResult.ok("Gave {d} x {s}", .{ count, item_id });
}

fn cmdTime(args: []const u8) CommandResult {
    if (args.len == 0) {
        return CommandResult.err("Usage: /time set <day|night|noon|midnight|ticks>", .{});
    }
    var it = std.mem.tokenizeScalar(u8, args, ' ');
    const sub = it.next() orelse return CommandResult.err("Usage: /time set <day|night|noon|midnight|ticks>", .{});
    if (!std.mem.eql(u8, sub, "set")) {
        return CommandResult.err("Usage: /time set <day|night|noon|midnight|ticks>", .{});
    }
    const value = it.next() orelse return CommandResult.err("Usage: /time set <day|night|noon|midnight|ticks>", .{});

    const named = .{
        .{ "day", @as(u64, 1000) },
        .{ "night", @as(u64, 13000) },
        .{ "noon", @as(u64, 6000) },
        .{ "midnight", @as(u64, 18000) },
    };
    inline for (named) |entry| {
        if (std.mem.eql(u8, value, entry[0])) {
            return CommandResult.ok("Time set to {s} ({d} ticks)", .{ entry[0], entry[1] });
        }
    }
    const ticks = std.fmt.parseInt(u64, value, 10) catch return CommandResult.err("Invalid time value: {s}", .{value});
    return CommandResult.ok("Time set to {d} ticks", .{ticks});
}

fn cmdWeather(args: []const u8) CommandResult {
    if (args.len == 0) {
        return CommandResult.err("Usage: /weather <clear|rain|thunder>", .{});
    }
    const valid = [_][]const u8{ "clear", "rain", "thunder" };
    for (valid) |v| {
        if (std.mem.eql(u8, args, v)) {
            return CommandResult.ok("Weather set to {s}", .{v});
        }
    }
    return CommandResult.err("Unknown weather type: {s}", .{args});
}

fn cmdKill(args: []const u8) CommandResult {
    _ = args;
    return CommandResult.ok("Killed player", .{});
}

fn cmdSeed(args: []const u8) CommandResult {
    _ = args;
    return CommandResult.ok("Seed: 42", .{});
}

fn cmdHelp(args: []const u8) CommandResult {
    _ = args;
    return CommandResult.ok(
        "Commands: /gamemode, /tp, /give, /time, /weather, /kill, /seed, /help",
        .{},
    );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "parse /gamemode creative returns .gamemode" {
    try std.testing.expectEqual(CommandType.gamemode, parse("/gamemode creative"));
}

test "parse without leading slash" {
    try std.testing.expectEqual(CommandType.tp, parse("tp 10 20 30"));
}

test "parse unknown command returns .unknown" {
    try std.testing.expectEqual(CommandType.unknown, parse("/fly"));
}

test "parse strips leading spaces" {
    try std.testing.expectEqual(CommandType.kill, parse("  /kill"));
}

test "execute gamemode creative" {
    const result = execute(.gamemode, "creative");
    try std.testing.expect(result.success);
    try std.testing.expectEqualStrings("Game mode set to creative", result.msg());
}

test "execute gamemode missing args" {
    const result = execute(.gamemode, "");
    try std.testing.expect(!result.success);
}

test "execute gamemode invalid mode" {
    const result = execute(.gamemode, "hardcore");
    try std.testing.expect(!result.success);
    try std.testing.expectEqualStrings("Unknown game mode: hardcore", result.msg());
}

test "execute unknown command" {
    const result = execute(.unknown, "");
    try std.testing.expect(!result.success);
    try std.testing.expectEqualStrings("Unknown command. Type /help for a list of commands.", result.msg());
}

test "help lists commands" {
    const result = execute(.help, "");
    try std.testing.expect(result.success);
    try std.testing.expect(std.mem.indexOf(u8, result.msg(), "/gamemode") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.msg(), "/tp") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.msg(), "/help") != null);
}

test "tp with valid coordinates" {
    const result = execute(.tp, "100 64 -200");
    try std.testing.expect(result.success);
    try std.testing.expectEqualStrings("Teleported to (100.0, 64.0, -200.0)", result.msg());
}

test "tp with missing coordinates" {
    const result = execute(.tp, "100 64");
    try std.testing.expect(!result.success);
}

test "tp with invalid coordinate" {
    const result = execute(.tp, "abc 64 100");
    try std.testing.expect(!result.success);
}

test "give item with default count" {
    const result = execute(.give, "diamond_sword");
    try std.testing.expect(result.success);
    try std.testing.expectEqualStrings("Gave 1 x diamond_sword", result.msg());
}

test "give item with count" {
    const result = execute(.give, "stone 64");
    try std.testing.expect(result.success);
    try std.testing.expectEqualStrings("Gave 64 x stone", result.msg());
}

test "give with zero count fails" {
    const result = execute(.give, "stone 0");
    try std.testing.expect(!result.success);
}

test "time set day" {
    const result = execute(.time, "set day");
    try std.testing.expect(result.success);
    try std.testing.expectEqualStrings("Time set to day (1000 ticks)", result.msg());
}

test "time set numeric ticks" {
    const result = execute(.time, "set 5000");
    try std.testing.expect(result.success);
    try std.testing.expectEqualStrings("Time set to 5000 ticks", result.msg());
}

test "time missing subcommand" {
    const result = execute(.time, "");
    try std.testing.expect(!result.success);
}

test "weather clear" {
    const result = execute(.weather, "clear");
    try std.testing.expect(result.success);
    try std.testing.expectEqualStrings("Weather set to clear", result.msg());
}

test "weather invalid type" {
    const result = execute(.weather, "snow");
    try std.testing.expect(!result.success);
}

test "kill command" {
    const result = execute(.kill, "");
    try std.testing.expect(result.success);
    try std.testing.expectEqualStrings("Killed player", result.msg());
}

test "seed command" {
    const result = execute(.seed, "");
    try std.testing.expect(result.success);
    try std.testing.expectEqualStrings("Seed: 42", result.msg());
}

test "run convenience function" {
    const result = run("/gamemode creative");
    try std.testing.expect(result.success);
    try std.testing.expectEqualStrings("Game mode set to creative", result.msg());
}

test "run with tp coordinates" {
    const result = run("/tp 10 20 30");
    try std.testing.expect(result.success);
    try std.testing.expectEqualStrings("Teleported to (10.0, 20.0, 30.0)", result.msg());
}

test "parse all command types" {
    try std.testing.expectEqual(CommandType.gamemode, parse("/gamemode"));
    try std.testing.expectEqual(CommandType.tp, parse("/tp"));
    try std.testing.expectEqual(CommandType.give, parse("/give"));
    try std.testing.expectEqual(CommandType.time, parse("/time"));
    try std.testing.expectEqual(CommandType.weather, parse("/weather"));
    try std.testing.expectEqual(CommandType.kill, parse("/kill"));
    try std.testing.expectEqual(CommandType.seed, parse("/seed"));
    try std.testing.expectEqual(CommandType.help, parse("/help"));
}
