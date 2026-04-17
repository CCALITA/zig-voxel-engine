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
pub const mesh_greedy = @import("world/mesh_greedy.zig");
pub const mesh = @import("world/mesh.zig");
pub const terrain_gen = @import("world/terrain_gen.zig");
pub const noise = @import("world/noise.zig");
pub const chunk_map = @import("world/chunk_map.zig");
pub const raycast = @import("gameplay/raycast.zig");
pub const inventory_mod = @import("gameplay/inventory.zig");

const SEED: u64 = 42;
const RENDER_RADIUS: i32 = 6;

// Player dimensions (shared between collision and block placement)
const PLAYER_WIDTH: f32 = 0.6;
const PLAYER_HEIGHT: f32 = 1.8;
const PLAYER_HALF_W: f32 = PLAYER_WIDTH / 2.0;

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

    // Interaction state
    selected_slot: u8,
    last_left_click: bool,
    last_right_click: bool,
    inventory: inventory_mod.Inventory,

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

                const neighbors = mesh_greedy.NeighborChunks{
                    .north = if (chunks.getPtr(.{ .x = cx, .z = cz - 1 })) |p| p else null,
                    .south = if (chunks.getPtr(.{ .x = cx, .z = cz + 1 })) |p| p else null,
                    .east = if (chunks.getPtr(.{ .x = cx + 1, .z = cz })) |p| p else null,
                    .west = if (chunks.getPtr(.{ .x = cx - 1, .z = cz })) |p| p else null,
                };

                var mesh_data = try mesh_greedy.generateMesh(allocator, chunk_ptr, neighbors);
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

        // Initialize inventory with default hotbar blocks
        var inventory = inventory_mod.Inventory.init();
        const hotbar_blocks = [_]block.BlockId{
            block.STONE,
            block.DIRT,
            block.GRASS,
            block.COBBLESTONE,
            block.OAK_PLANKS,
            block.SAND,
            block.OAK_LOG,
            block.OAK_LEAVES,
            block.BEDROCK,
        };
        for (hotbar_blocks) |bid| {
            _ = inventory.addItem(@as(inventory_mod.ItemId, bid), 64);
        }

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
            .selected_slot = 0,
            .last_left_click = false,
            .last_right_click = false,
            .inventory = inventory,
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

            // Hotbar selection (number keys 1-9)
            const number_keys = [_]zglfw.Key{ .one, .two, .three, .four, .five, .six, .seven, .eight, .nine };
            for (number_keys, 0..) |key, i| {
                if (self.window.handle.getKey(key) == .press) {
                    self.selected_slot = @intCast(i);
                }
            }

            // Block interaction (left/right mouse click)
            self.handleBlockInteraction();

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
            // Try Y movement first (gravity/jump)
            const new_y = self.player_y + self.player_vy * dt;
            if (!self.collidesAt(self.player_x, new_y, self.player_z, PLAYER_HALF_W, PLAYER_HEIGHT)) {
                self.player_y = new_y;
                self.on_ground = false;
            } else {
                if (self.player_vy < 0) self.on_ground = true;
                self.player_vy = 0;
            }

            // Try X movement
            const new_x = self.player_x + move_x;
            if (!self.collidesAt(new_x, self.player_y, self.player_z, PLAYER_HALF_W, PLAYER_HEIGHT)) {
                self.player_x = new_x;
            }

            // Try Z movement
            const new_z = self.player_z + move_z;
            if (!self.collidesAt(self.player_x, self.player_y, new_z, PLAYER_HALF_W, PLAYER_HEIGHT)) {
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

    fn setWorldBlock(self: *Engine, wx: i32, wy: i32, wz: i32, id: block.BlockId) bool {
        if (wy < 0 or wy >= Chunk.SIZE) return false;
        const cx = @divFloor(wx, @as(i32, Chunk.SIZE));
        const cz = @divFloor(wz, @as(i32, Chunk.SIZE));
        const chunk_ptr = self.chunks.getPtr(.{ .x = cx, .z = cz }) orelse return false;
        const lx: u4 = @intCast(@mod(wx, @as(i32, Chunk.SIZE)));
        const ly: u4 = @intCast(@mod(wy, @as(i32, Chunk.SIZE)));
        const lz: u4 = @intCast(@mod(wz, @as(i32, Chunk.SIZE)));
        chunk_ptr.setBlock(lx, ly, lz, id);
        return true;
    }

    /// Raycast solidity wrapper. Uses a static var to pass the Engine pointer
    /// into the function-pointer callback required by raycast.cast().
    const RaycastBridge = struct {
        var engine_ctx: ?*Engine = null;

        fn isSolid(x: i32, y: i32, z: i32) bool {
            const eng = engine_ctx orelse return false;
            const bid = eng.getWorldBlock(x, y, z) orelse return false;
            return block.isSolid(bid);
        }
    };

    fn handleBlockInteraction(self: *Engine) void {
        const left_pressed = self.window.handle.getMouseButton(.left) == .press;
        const right_pressed = self.window.handle.getMouseButton(.right) == .press;

        const left_just_pressed = left_pressed and !self.last_left_click;
        const right_just_pressed = right_pressed and !self.last_right_click;

        self.last_left_click = left_pressed;
        self.last_right_click = right_pressed;

        if (!left_just_pressed and !right_just_pressed) return;

        // Cast ray from camera
        const fwd = self.camera.forward();
        RaycastBridge.engine_ctx = self;
        defer RaycastBridge.engine_ctx = null;

        const hit = raycast.cast(
            self.camera.pos[0],
            self.camera.pos[1],
            self.camera.pos[2],
            fwd[0],
            fwd[1],
            fwd[2],
            5.0,
            &RaycastBridge.isSolid,
        ) orelse return;

        if (left_just_pressed) {
            self.renderer.waitIdle();
            self.breakBlock(hit.bx, hit.by, hit.bz);
        } else if (right_just_pressed) {
            self.renderer.waitIdle();
            self.placeBlock(hit.adjacent_x, hit.adjacent_y, hit.adjacent_z);
        }
    }

    fn breakBlock(self: *Engine, wx: i32, wy: i32, wz: i32) void {
        if (!self.setWorldBlock(wx, wy, wz, block.AIR)) return;
        self.remeshAffectedChunks(wx, wz);
    }

    fn placeBlock(self: *Engine, wx: i32, wy: i32, wz: i32) void {
        const bx_f: f32 = @floatFromInt(wx);
        const by_f: f32 = @floatFromInt(wy);
        const bz_f: f32 = @floatFromInt(wz);

        // Player AABB
        const p_min_x = self.player_x - PLAYER_HALF_W;
        const p_min_y = self.player_y;
        const p_min_z = self.player_z - PLAYER_HALF_W;
        const p_max_x = self.player_x + PLAYER_HALF_W;
        const p_max_y = self.player_y + PLAYER_HEIGHT;
        const p_max_z = self.player_z + PLAYER_HALF_W;

        // Reject if block would overlap player
        if (p_max_x > bx_f and p_min_x < bx_f + 1.0 and
            p_max_y > by_f and p_min_y < by_f + 1.0 and
            p_max_z > bz_f and p_min_z < bz_f + 1.0)
        {
            return;
        }

        const slot = self.inventory.getSlot(self.selected_slot);
        const block_id: block.BlockId = if (!slot.isEmpty())
            @intCast(slot.item)
        else
            block.STONE;

        if (!self.setWorldBlock(wx, wy, wz, block_id)) return;
        self.remeshAffectedChunks(wx, wz);
    }

    /// Re-mesh the chunk containing (wx, wz) and any neighbor chunks
    /// if the block is on a chunk border.
    fn remeshAffectedChunks(self: *Engine, wx: i32, wz: i32) void {
        const size: i32 = Chunk.SIZE;
        const cx = @divFloor(wx, size);
        const cz = @divFloor(wz, size);
        const lx = @mod(wx, size);
        const lz = @mod(wz, size);

        self.remeshChunkByKey(cx, cz);

        if (lx == 0) self.remeshChunkByKey(cx - 1, cz);
        if (lx == size - 1) self.remeshChunkByKey(cx + 1, cz);
        if (lz == 0) self.remeshChunkByKey(cx, cz - 1);
        if (lz == size - 1) self.remeshChunkByKey(cx, cz + 1);
    }

    fn remeshChunkByKey(self: *Engine, cx: i32, cz: i32) void {
        const chunk_ptr = self.chunks.getPtr(.{ .x = cx, .z = cz }) orelse return;

        const neighbors = mesh_greedy.NeighborChunks{
            .north = if (self.chunks.getPtr(.{ .x = cx, .z = cz - 1 })) |p| p else null,
            .south = if (self.chunks.getPtr(.{ .x = cx, .z = cz + 1 })) |p| p else null,
            .east = if (self.chunks.getPtr(.{ .x = cx + 1, .z = cz })) |p| p else null,
            .west = if (self.chunks.getPtr(.{ .x = cx - 1, .z = cz })) |p| p else null,
        };

        var mesh_data = mesh_greedy.generateMesh(self.allocator, chunk_ptr, neighbors) catch return;
        defer mesh_data.deinit();

        const world_x = cx * @as(i32, Chunk.SIZE);
        const world_z = cz * @as(i32, Chunk.SIZE);

        // Remove old chunk render data for this chunk
        self.removeChunkRender(world_x, 0, world_z);

        // Upload new mesh (skip if empty -- chunk is now all air)
        self.renderer.uploadChunk(mesh_data.vertices, mesh_data.indices, world_x, 0, world_z) catch return;
    }

    fn removeChunkRender(self: *Engine, world_x: i32, world_y: i32, world_z: i32) void {
        var i: usize = 0;
        while (i < self.renderer.chunk_renders.items.len) {
            const cr = self.renderer.chunk_renders.items[i];
            if (cr.world_x == world_x and cr.world_y == world_y and cr.world_z == world_z) {
                // Destroy GPU resources
                self.renderer.vkd.destroyBuffer(self.renderer.device, cr.vertex_buffer, null);
                self.renderer.vkd.freeMemory(self.renderer.device, cr.vertex_buffer_memory, null);
                self.renderer.vkd.destroyBuffer(self.renderer.device, cr.index_buffer, null);
                self.renderer.vkd.freeMemory(self.renderer.device, cr.index_buffer_memory, null);
                _ = self.renderer.chunk_renders.swapRemove(i);
                return;
            }
            i += 1;
        }
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

test "mesh_greedy module" {
    _ = mesh_greedy;
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

test "raycast module" {
    _ = raycast;
}

test "inventory module" {
    _ = inventory_mod;
}
