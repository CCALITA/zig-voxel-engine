const std = @import("std");
const vk = @import("vulkan");
const zglfw = @import("zglfw");

pub const Window = @import("window.zig");
pub const Renderer = @import("renderer.zig");

pub const subsystem_count: u32 = 2; // window + renderer

pub const Engine = struct {
    allocator: std.mem.Allocator,
    window: Window,
    renderer: Renderer,

    pub fn init(allocator: std.mem.Allocator) !Engine {
        const window = try Window.init(.{
            .width = 1280,
            .height = 720,
            .title = "zig-voxel-engine",
        });

        const renderer = try Renderer.init(allocator, window.handle);

        return .{
            .allocator = allocator,
            .window = window,
            .renderer = renderer,
        };
    }

    pub fn deinit(self: *Engine) void {
        self.renderer.deinit();
        self.window.deinit();
    }

    pub fn run(self: *Engine) void {
        while (!self.window.shouldClose()) {
            zglfw.pollEvents();
            self.renderer.drawFrame() catch |err| {
                std.debug.print("Render error: {}\n", .{err});
                return;
            };
        }

        // Wait for GPU to finish before cleanup
        self.renderer.waitIdle();
    }
};

test "subsystem count" {
    try std.testing.expectEqual(@as(u32, 2), subsystem_count);
}
