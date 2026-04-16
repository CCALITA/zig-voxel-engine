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
pub const terrain_gen = @import("world/terrain_gen.zig");
pub const noise = @import("world/noise.zig");
pub const chunk_map = @import("world/chunk_map.zig");

const SEED: u64 = 42;
const RENDER_RADIUS: i32 = 6;

pub const Engine = struct {
    allocator: std.mem.Allocator,
    window: Window,
    renderer: Renderer,
    camera: Camera,
    last_time: f64,
    last_cursor_x: f64,
    last_cursor_y: f64,
    first_mouse: bool,

    // World chunks stored for collision
    chunks: std.AutoHashMap(ChunkKey, Chunk),

    // Player physics
    player_x: f32,
    player_y: f32,
    player_z: f32,
    player_vy: f32,
    on_ground: bool,

    const ChunkKey = struct { x: i32, z: i32 };

    pub fn init(allocator: std.mem.Allocator) !Engine {
        const window = try Window.init(.{
            .width = 1280,
            .height = 720,
            .title = "zig-voxel-engine",
        });

        try window.handle.setInputMode(.cursor, .disabled);

        var renderer = try Renderer.init(allocator, window.handle);

        // Generate all chunks first
        var chunks = std.AutoHashMap(ChunkKey, Chunk).init(allocator);
        var cx: i32 = -RENDER_RADIUS;
        while (cx <= RENDER_RADIUS) : (cx += 1) {
            var cz: i32 = -RENDER_RADIUS;
            while (cz <= RENDER_RADIUS) : (cz += 1) {
                const chunk = terrain_gen.generateChunk(allocator, SEED, cx, cz);
                try chunks.put(.{ .x = cx, .z = cz }, chunk);
            }
        }

        // Mesh each chunk with neighbor data for seamless borders
        cx = -RENDER_RADIUS;
        while (cx <= RENDER_RADIUS) : (cx += 1) {
            var cz: i32 = -RENDER_RADIUS;
            while (cz <= RENDER_RADIUS) : (cz += 1) {
                const chunk_ptr = chunks.getPtr(.{ .x = cx, .z = cz }).?;

                const neighbors = mesh_indexed.NeighborChunks{
                    .north = if (chunks.getPtr(.{ .x = cx, .z = cz - 1 })) |p| p else null,
                    .south = if (chunks.getPtr(.{ .x = cx, .z = cz + 1 })) |p| p else null,
                    .east = if (chunks.getPtr(.{ .x = cx + 1, .z = cz })) |p| p else null,
                    .west = if (chunks.getPtr(.{ .x = cx - 1, .z = cz })) |p| p else null,
                };

                var mesh_data = try mesh_indexed.generateMeshWithNeighbors(allocator, chunk_ptr, neighbors);
                defer mesh_data.deinit();

                const world_x = cx * @as(i32, Chunk.SIZE);
                const world_z = cz * @as(i32, Chunk.SIZE);
                try renderer.uploadChunk(mesh_data.vertices, mesh_data.indices, world_x, 0, world_z);
            }
        }

        // Find spawn height at world center
        const center_chunk = chunks.get(.{ .x = 0, .z = 0 }).?;
        var spawn_y: f32 = 15;
        while (spawn_y > 0) {
            const by: u4 = @intFromFloat(spawn_y);
            if (block.isSolid(center_chunk.getBlock(8, by, 8))) {
                spawn_y += 1;
                break;
            }
            spawn_y -= 1;
        }
        spawn_y += 0.5; // half-block above ground

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
            .chunks = chunks,
            .player_x = 8.0,
            .player_y = spawn_y,
            .player_z = 8.0,
            .player_vy = 0.0,
            .on_ground = false,
        };
    }

    pub fn deinit(self: *Engine) void {
        self.renderer.deinit();
        self.window.deinit();
        self.chunks.deinit();
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

            // Keyboard movement (horizontal only — physics handles vertical)
            var forward_input: f32 = 0;
            var right_input: f32 = 0;

            if (self.window.handle.getKey(.w) == .press) forward_input += 1;
            if (self.window.handle.getKey(.s) == .press) forward_input -= 1;
            if (self.window.handle.getKey(.d) == .press) right_input += 1;
            if (self.window.handle.getKey(.a) == .press) right_input -= 1;

            // Jump
            if (self.window.handle.getKey(.space) == .press and self.on_ground) {
                self.player_vy = 8.0; // jump impulse
                self.on_ground = false;
            }

            if (self.window.handle.getKey(.escape) == .press) {
                self.window.handle.setShouldClose(true);
            }

            // Horizontal movement based on camera direction
            const fwd = self.camera.forward();
            const rt = self.camera.right();
            const speed: f32 = 6.0;
            var move_x: f32 = 0;
            var move_z: f32 = 0;

            // Project forward/right onto XZ plane
            move_x += fwd[0] * forward_input * speed * dt;
            move_z += fwd[2] * forward_input * speed * dt;
            move_x += rt[0] * right_input * speed * dt;
            move_z += rt[2] * right_input * speed * dt;

            // Apply gravity
            const gravity: f32 = -20.0;
            self.player_vy += gravity * dt;

            // Attempt movement with simple AABB collision
            const player_width: f32 = 0.6;
            const player_height: f32 = 1.8;
            const half_w = player_width / 2.0;

            // Try Y movement first (gravity/jump)
            const new_y = self.player_y + self.player_vy * dt;
            if (!self.collidesAt(self.player_x, new_y, self.player_z, half_w, player_height)) {
                self.player_y = new_y;
                self.on_ground = false;
            } else {
                if (self.player_vy < 0) self.on_ground = true;
                self.player_vy = 0;
            }

            // Try X movement
            const new_x = self.player_x + move_x;
            if (!self.collidesAt(new_x, self.player_y, self.player_z, half_w, player_height)) {
                self.player_x = new_x;
            }

            // Try Z movement
            const new_z = self.player_z + move_z;
            if (!self.collidesAt(self.player_x, self.player_y, new_z, half_w, player_height)) {
                self.player_z = new_z;
            }

            // Update camera position from player (eye height = feet + 1.6)
            const zm = @import("zmath");
            self.camera.pos = zm.f32x4(self.player_x, self.player_y + 1.6, self.player_z, 1.0);

            // Compute VP matrix
            const vp = self.camera.vpMatrix();
            const vp_arr = Camera.matToArray(vp);

            self.renderer.drawFrame(vp_arr) catch |err| {
                std.debug.print("Render error: {}\n", .{err});
                return;
            };
        }

        self.renderer.waitIdle();
    }

    fn collidesAt(self: *Engine, px: f32, py: f32, pz: f32, half_w: f32, height: f32) bool {
        // Player AABB: centered on x/z, feet at py
        const min_x = px - half_w;
        const min_y = py;
        const min_z = pz - half_w;
        const max_x = px + half_w;
        const max_y = py + height;
        const max_z = pz + half_w;

        // Check all blocks the AABB overlaps
        const bx0 = @as(i32, @intFromFloat(@floor(min_x)));
        const by0 = @as(i32, @intFromFloat(@floor(min_y)));
        const bz0 = @as(i32, @intFromFloat(@floor(min_z)));
        const bx1 = @as(i32, @intFromFloat(@floor(max_x)));
        const by1 = @as(i32, @intFromFloat(@floor(max_y)));
        const bz1 = @as(i32, @intFromFloat(@floor(max_z)));

        var by: i32 = by0;
        while (by <= by1) : (by += 1) {
            var bz: i32 = bz0;
            while (bz <= bz1) : (bz += 1) {
                var bx: i32 = bx0;
                while (bx <= bx1) : (bx += 1) {
                    if (self.getWorldBlock(bx, by, bz)) |bid| {
                        if (block.isSolid(bid)) return true;
                    }
                }
            }
        }
        return false;
    }

    fn getWorldBlock(self: *Engine, wx: i32, wy: i32, wz: i32) ?block.BlockId {
        if (wy < 0 or wy >= Chunk.SIZE) return null;
        const cx = @divFloor(wx, @as(i32, Chunk.SIZE));
        const cz = @divFloor(wz, @as(i32, Chunk.SIZE));
        const chunk = self.chunks.get(.{ .x = cx, .z = cz }) orelse return null;
        const lx: u4 = @intCast(@mod(wx, @as(i32, Chunk.SIZE)));
        const ly: u4 = @intCast(@mod(wy, @as(i32, Chunk.SIZE)));
        const lz: u4 = @intCast(@mod(wz, @as(i32, Chunk.SIZE)));
        return chunk.getBlock(lx, ly, lz);
    }
};

test "subsystem count" {
    // Removed — no longer relevant with dynamic chunk count
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

test "terrain_gen module" {
    _ = terrain_gen;
}

test "noise module" {
    _ = noise;
}

test "chunk_map module" {
    _ = chunk_map;
}
