const std = @import("std");
const vk = @import("vulkan");
const zglfw = @import("zglfw");

pub const Window = @import("window.zig");
pub const Renderer = @import("renderer.zig");
pub const Camera = @import("camera.zig");
pub const pipeline = @import("pipeline.zig");
pub const block = @import("world/block.zig");
pub const Chunk = @import("world/chunk.zig");
pub const mesh = @import("world/mesh.zig");
pub const terrain_gen = @import("world/terrain_gen.zig");
pub const noise = @import("world/noise.zig");
pub const chunk_map = @import("world/chunk_map.zig");

pub const subsystem_count: u32 = 3; // window + renderer + camera

pub const Engine = struct {
    allocator: std.mem.Allocator,
    window: Window,
    renderer: Renderer,
    camera: Camera,
    last_time: f64,
    last_cursor_x: f64,
    last_cursor_y: f64,
    first_mouse: bool,

    pub fn init(allocator: std.mem.Allocator) !Engine {
        const window = try Window.init(.{
            .width = 1280,
            .height = 720,
            .title = "zig-voxel-engine",
        });

        // Capture cursor for FPS camera
        try window.handle.setInputMode(.cursor, .disabled);

        var renderer = try Renderer.init(allocator, window.handle);

        const SEED: u64 = 42;
        var chunk = terrain_gen.generateChunk(SEED, 0, 0);

        var mesh_data = try mesh.generateMesh(allocator, &chunk);
        defer mesh_data.deinit();

        try renderer.uploadChunkMesh(mesh_data.vertices);

        const aspect = 1280.0 / 720.0;

        return .{
            .allocator = allocator,
            .window = window,
            .renderer = renderer,
            .camera = Camera.init(aspect),
            .last_time = zglfw.getTime(),
            .last_cursor_x = 0.0,
            .last_cursor_y = 0.0,
            .first_mouse = true,
        };
    }

    pub fn deinit(self: *Engine) void {
        self.renderer.deinit();
        self.window.deinit();
    }

    pub fn run(self: *Engine) void {
        while (!self.window.shouldClose()) {
            zglfw.pollEvents();

            const current_time = zglfw.getTime();
            const dt: f32 = @floatCast(current_time - self.last_time);
            self.last_time = current_time;

            // Mouse look
            const cursor = self.window.handle.getCursorPos();
            if (self.first_mouse) {
                self.last_cursor_x = cursor[0];
                self.last_cursor_y = cursor[1];
                self.first_mouse = false;
            }
            const dx = cursor[0] - self.last_cursor_x;
            const dy = cursor[1] - self.last_cursor_y;
            self.last_cursor_x = cursor[0];
            self.last_cursor_y = cursor[1];
            self.camera.processMouseDelta(dx, dy);

            // Keyboard movement
            var forward_input: f32 = 0;
            var right_input: f32 = 0;
            var up_input: f32 = 0;

            if (self.window.handle.getKey(.w) == .press) forward_input += 1;
            if (self.window.handle.getKey(.s) == .press) forward_input -= 1;
            if (self.window.handle.getKey(.d) == .press) right_input += 1;
            if (self.window.handle.getKey(.a) == .press) right_input -= 1;
            if (self.window.handle.getKey(.space) == .press) up_input += 1;
            if (self.window.handle.getKey(.left_shift) == .press) up_input -= 1;

            // Escape to close
            if (self.window.handle.getKey(.escape) == .press) {
                self.window.handle.setShouldClose(true);
            }

            self.camera.processMovement(dt, forward_input, right_input, up_input);

            // Compute MVP
            const vp = self.camera.vpMatrix();
            const mvp_arr = Camera.matToArray(vp);

            self.renderer.drawFrame(mvp_arr) catch |err| {
                std.debug.print("Render error: {}\n", .{err});
                return;
            };
        }

        self.renderer.waitIdle();
    }
};

test "subsystem count" {
    try std.testing.expectEqual(@as(u32, 3), subsystem_count);
}

test "block module" {
    _ = block;
}

test "chunk module" {
    _ = Chunk;
}

test "mesh module" {
    _ = mesh;
}

test "terrain_gen module" {
    _ = terrain_gen;
}

test "noise module" {
    _ = noise;
}

test "chunk_map module" {
    _ = chunk_map;
}
