const std = @import("std");
const vk = @import("vulkan");
const zglfw = @import("zglfw");

pub const Window = @import("window.zig");
pub const Renderer = @import("renderer.zig");
pub const Camera = @import("camera.zig");
pub const pipeline = @import("pipeline.zig");
pub const block = @import("world/block.zig");
pub const Chunk = @import("world/chunk.zig");
pub const mesh_indexed = @import("world/mesh_indexed.zig");
pub const mesh = @import("world/mesh.zig");

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

        // Generate a 3x3 grid of chunks around the origin
        const grid_radius = 1; // -1..1 => 3x3
        var cx: i32 = -grid_radius;
        while (cx <= grid_radius) : (cx += 1) {
            var cz: i32 = -grid_radius;
            while (cz <= grid_radius) : (cz += 1) {
                var chunk = Chunk.init();
                for (0..Chunk.SIZE) |xi| {
                    for (0..Chunk.SIZE) |zi| {
                        // Bedrock at y=0
                        chunk.setBlock(@intCast(xi), 0, @intCast(zi), block.BEDROCK);
                        // Stone layers y=1..5
                        for (1..6) |yi| {
                            chunk.setBlock(@intCast(xi), @intCast(yi), @intCast(zi), block.STONE);
                        }
                        // Dirt y=6..8
                        for (6..9) |yi| {
                            chunk.setBlock(@intCast(xi), @intCast(yi), @intCast(zi), block.DIRT);
                        }
                        // Grass on top y=9
                        chunk.setBlock(@intCast(xi), 9, @intCast(zi), block.GRASS);
                    }
                }

                // Place a tree at (8, 10, 8) only in the center chunk
                if (cx == 0 and cz == 0) {
                    for (10..14) |yi| {
                        chunk.setBlock(8, @intCast(yi), 8, block.OAK_LOG);
                    }
                    // Leaves canopy
                    for (12..15) |yi| {
                        for (6..11) |xi| {
                            for (6..11) |zi| {
                                const bx: u4 = @intCast(xi);
                                const by: u4 = @intCast(yi);
                                const bz: u4 = @intCast(zi);
                                if (chunk.getBlock(bx, by, bz) == block.AIR) {
                                    chunk.setBlock(bx, by, bz, block.OAK_LEAVES);
                                }
                            }
                        }
                    }
                }

                var mesh_data = try mesh_indexed.generateMesh(allocator, &chunk);
                defer mesh_data.deinit();

                const world_x = cx * @as(i32, Chunk.SIZE);
                const world_z = cz * @as(i32, Chunk.SIZE);
                try renderer.uploadChunk(mesh_data.vertices, mesh_data.indices, world_x, 0, world_z);
            }
        }

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

            // Compute VP matrix (per-chunk model applied in renderer)
            const vp = self.camera.vpMatrix();
            const vp_arr = Camera.matToArray(vp);

            self.renderer.drawFrame(vp_arr) catch |err| {
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

test "mesh_indexed module" {
    _ = mesh_indexed;
}
