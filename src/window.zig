const std = @import("std");
const zglfw = @import("zglfw");

pub const WindowConfig = struct {
    width: u32 = 1280,
    height: u32 = 720,
    title: [:0]const u8 = "zig-voxel-engine",
};

handle: *zglfw.Window,
width: u32,
height: u32,

const Self = @This();

pub fn init(config: WindowConfig) !Self {
    try zglfw.init();

    zglfw.windowHint(.client_api, .no_api);
    zglfw.windowHint(.resizable, true);

    const window = try zglfw.createWindow(
        @intCast(config.width),
        @intCast(config.height),
        config.title,
        null,
        null,
    );

    return .{
        .handle = window,
        .width = config.width,
        .height = config.height,
    };
}

pub fn deinit(self: Self) void {
    zglfw.destroyWindow(self.handle);
    zglfw.terminate();
}

pub fn shouldClose(self: Self) bool {
    return self.handle.shouldClose();
}

pub fn getFramebufferSize(self: Self) [2]u32 {
    const size = self.handle.getFramebufferSize();
    return .{ @intCast(size[0]), @intCast(size[1]) };
}
