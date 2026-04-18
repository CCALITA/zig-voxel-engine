/// Command block types and execution logic.
const std = @import("std");

pub const CommandBlockMode = enum {
    impulse,
    chain,
    repeating,
};

pub const CommandBlock = struct {
    mode: CommandBlockMode,
    command: [256]u8,
    command_len: u8,
    conditional: bool,
    needs_redstone: bool,
    last_output: [256]u8,
    output_len: u8,

    pub fn init(mode: CommandBlockMode) CommandBlock {
        return .{
            .mode = mode,
            .command = [_]u8{0} ** 256,
            .command_len = 0,
            .conditional = false,
            .needs_redstone = true,
            .last_output = [_]u8{0} ** 256,
            .output_len = 0,
        };
    }

    pub fn setCommand(self: *CommandBlock, cmd: []const u8) void {
        const len: u8 = @intCast(@min(cmd.len, 255));
        @memcpy(self.command[0..len], cmd[0..len]);
        self.command_len = len;
    }

    pub fn getCommand(self: *const CommandBlock) []const u8 {
        return self.command[0..self.command_len];
    }

    pub fn shouldExecute(self: *const CommandBlock, powered: bool) bool {
        if (self.needs_redstone and !powered) return false;
        return self.command_len > 0;
    }
};

test "command block init" {
    const cb = CommandBlock.init(.impulse);
    try std.testing.expectEqual(CommandBlockMode.impulse, cb.mode);
    try std.testing.expectEqual(@as(u8, 0), cb.command_len);
    try std.testing.expect(cb.needs_redstone);
}

test "command block set command" {
    var cb = CommandBlock.init(.repeating);
    cb.setCommand("/say hello");
    try std.testing.expectEqualStrings("/say hello", cb.getCommand());
}

test "command block requires power" {
    var cb = CommandBlock.init(.impulse);
    cb.setCommand("/tp @p 0 64 0");
    try std.testing.expect(!cb.shouldExecute(false));
    try std.testing.expect(cb.shouldExecute(true));
}
