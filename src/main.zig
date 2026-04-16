const std = @import("std");
const Engine = @import("engine").Engine;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("zig-voxel-engine v0.1.0\n", .{});

    var engine = try Engine.init(allocator);
    defer engine.deinit();

    std.debug.print("Vulkan initialized. Running...\n", .{});

    engine.run();

    std.debug.print("Shutdown complete.\n", .{});
}
