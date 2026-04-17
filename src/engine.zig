const std = @import("std");
const vk = @import("vulkan");
const zglfw = @import("zglfw");

pub const Window = @import("window.zig");
pub const Renderer = @import("renderer.zig");
pub const Camera = @import("camera.zig");
pub const pipeline = @import("pipeline.zig");
pub const block = @import("world/block.zig");
pub const Chunk = @import("world/chunk.zig");
pub const ChunkColumn = @import("world/chunk_column.zig");
pub const mesh_indexed = @import("world/mesh_indexed.zig");
pub const mesh_greedy = @import("world/mesh_greedy.zig");
pub const mesh = @import("world/mesh.zig");
pub const terrain_gen = @import("world/terrain_gen.zig");
pub const noise = @import("world/noise.zig");
pub const chunk_map = @import("world/chunk_map.zig");
pub const chunk_loader_mod = @import("world/chunk_loader.zig");
pub const persistence_mod = @import("world/persistence.zig");
pub const raycast = @import("gameplay/raycast.zig");
pub const inventory_mod = @import("gameplay/inventory.zig");
pub const time_mod = @import("world/time.zig");
pub const mob_mod = @import("entity/mob.zig");
pub const entity_mod = @import("entity/entity.zig");
pub const health_mod = @import("gameplay/health.zig");
pub const water_mod = @import("physics/water.zig");

const SEED: u64 = 42;
const RENDER_RADIUS: i32 = 6;

// Player dimensions (shared between collision and block placement)
const PLAYER_WIDTH: f32 = 0.6;
const PLAYER_HEIGHT: f32 = 1.8;
const PLAYER_HALF_W: f32 = PLAYER_WIDTH / 2.0;
const PLAYER_EYE_HEIGHT: f32 = 1.6;

pub const Engine = struct {
    allocator: std.mem.Allocator,
    window: Window,
    renderer: Renderer,
    camera: Camera,
    last_time: f64,
    last_cursor_x: f64,
    last_cursor_y: f64,
    first_mouse: bool,

    // World chunk columns stored for collision (256-block height per column)
    chunks: std.AutoHashMap(ChunkKey, ChunkColumn),
    chunk_loader: chunk_loader_mod.ChunkLoader,
    persistence: persistence_mod.WorldPersistence,

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

    // Day/night cycle
    game_time: time_mod.GameTime,

    // Entity/mob system
    mob_manager: mob_mod.MobManager,

    // Health and water physics
    player_stats: health_mod.PlayerStats,
    water_state: water_mod.WaterState,

    const ChunkKey = struct { x: i32, z: i32 };

    pub fn init(allocator: std.mem.Allocator) !Engine {
        const window = try Window.init(.{
            .width = 1280,
            .height = 720,
            .title = "zig-voxel-engine",
        });

        try window.handle.setInputMode(.cursor, .disabled);

        var renderer = try Renderer.init(allocator, window.handle);

        var chunks = std.AutoHashMap(ChunkKey, ChunkColumn).init(allocator);
        var chunk_loader = chunk_loader_mod.ChunkLoader.init(allocator, RENDER_RADIUS);
        var persistence = try persistence_mod.WorldPersistence.init(allocator, "default");

        // Generate a small initial set (3x3 around spawn) to avoid blank first frame
        const INIT_RADIUS: i32 = 1;
        var cx: i32 = -INIT_RADIUS;
        while (cx <= INIT_RADIUS) : (cx += 1) {
            var cz: i32 = -INIT_RADIUS;
            while (cz <= INIT_RADIUS) : (cz += 1) {
                const column = if (persistence.loadColumn(cx, cz) catch null) |saved|
                    saved
                else
                    terrain_gen.generateColumn(allocator, SEED, cx, cz);
                try chunks.put(.{ .x = cx, .z = cz }, column);
                try chunk_loader.markLoaded(.{ .x = cx, .z = cz });
            }
        }

        // Mesh each initial column's sections with neighbor data for seamless borders
        cx = -INIT_RADIUS;
        while (cx <= INIT_RADIUS) : (cx += 1) {
            var cz: i32 = -INIT_RADIUS;
            while (cz <= INIT_RADIUS) : (cz += 1) {
                const col_ptr = chunks.getPtr(.{ .x = cx, .z = cz }).?;
                const north_col = chunks.getPtr(.{ .x = cx, .z = cz - 1 });
                const south_col = chunks.getPtr(.{ .x = cx, .z = cz + 1 });
                const east_col = chunks.getPtr(.{ .x = cx + 1, .z = cz });
                const west_col = chunks.getPtr(.{ .x = cx - 1, .z = cz });

                const world_x = cx * @as(i32, Chunk.SIZE);
                const world_z = cz * @as(i32, Chunk.SIZE);

                try meshColumnSections(allocator, &renderer, col_ptr, north_col, south_col, east_col, west_col, world_x, world_z);
            }
        }

        // Find spawn height at world center using column height
        const center_column = chunks.getPtr(.{ .x = 0, .z = 0 }).?;
        const spawn_height = center_column.getHeight(8, 8);
        var spawn_y: f32 = @floatFromInt(spawn_height);
        spawn_y += 1.5; // stand above the highest block

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

        // Initialize mob manager and spawn initial mobs
        var mob_manager = mob_mod.MobManager.init(allocator);

        // Spawn some passive mobs near the player
        const spawn_types = [_]entity_mod.EntityType{ .pig, .cow, .sheep, .chicken };
        for (spawn_types) |mob_type| {
            try mob_manager.spawn(mob_type, 20.0, 70.0, 20.0);
            try mob_manager.spawn(mob_type, -10.0, 70.0, 15.0);
        }
        // Spawn a few hostile mobs further away
        try mob_manager.spawn(.zombie, 40.0, 70.0, 40.0);
        try mob_manager.spawn(.skeleton, -30.0, 70.0, -30.0);

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
            .chunk_loader = chunk_loader,
            .persistence = persistence,
            .player_x = 8.0,
            .player_y = spawn_y,
            .player_z = 8.0,
            .player_vy = 0.0,
            .on_ground = false,
            .selected_slot = 0,
            .last_left_click = false,
            .last_right_click = false,
            .inventory = inventory,
            .game_time = .{},
            .mob_manager = mob_manager,
            .player_stats = health_mod.PlayerStats.init(),
            .water_state = water_mod.WaterState.init(),
        };
    }

    pub fn deinit(self: *Engine) void {
        // Save all modified chunks to disk before cleanup
        _ = self.persistence.saveAllDirtyColumns(&self.chunks) catch |err| {
            std.debug.print("Failed to save dirty chunks on exit: {}\n", .{err});
        };
        self.persistence.deinit();
        self.mob_manager.deinit();
        self.renderer.deinit();
        self.window.deinit();
        self.chunks.deinit();
        self.chunk_loader.deinit();
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

            // Skip gameplay updates if dead
            if (self.player_stats.is_dead) {
                self.renderFrame(dt);
                continue;
            }

            // Update water contact before movement decisions
            WaterBridge.engine_ctx = self;
            self.water_state.updateWaterContact(
                self.player_x,
                self.player_y,
                self.player_z,
                self.player_y + PLAYER_EYE_HEIGHT,
                &WaterBridge.isWater,
            );
            WaterBridge.engine_ctx = null;

            // Jump / swim
            if (self.window.handle.getKey(.space) == .press) {
                if (self.water_state.in_water and !self.on_ground) {
                    self.player_vy = self.water_state.getSwimUpSpeed();
                } else if (self.on_ground) {
                    self.player_vy = 8.0; // jump impulse
                    self.on_ground = false;
                }
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
            const speed: f32 = 6.0 * self.water_state.getSpeedMultiplier();
            var move_x: f32 = 0;
            var move_z: f32 = 0;

            // Project forward/right onto XZ plane
            move_x += fwd[0] * forward_input * speed * dt;
            move_z += fwd[2] * forward_input * speed * dt;
            move_x += rt[0] * right_input * speed * dt;
            move_z += rt[2] * right_input * speed * dt;

            // Apply gravity (reduced in water)
            const gravity: f32 = self.water_state.getGravity();
            self.player_vy += gravity * dt;

            // Track pre-collision velocity for fall damage
            const pre_land_vy = self.player_vy;
            const was_on_ground = self.on_ground;

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

            // Fall damage: when landing (on_ground transitions false -> true)
            if (self.on_ground and !was_on_ground and pre_land_vy < -10.0) {
                self.player_stats.takeDamage(@abs(pre_land_vy) - 10.0);
            }

            // Update health/hunger
            self.player_stats.update(dt);

            // Update mob AI and remove dead entities
            self.mob_manager.update(self.player_x, self.player_y, self.player_z, dt);
            self.mob_manager.removeDeadEntities();

            // Drowning damage
            const drown_dmg = self.water_state.updateOxygen(dt);
            if (drown_dmg > 0) {
                self.player_stats.takeDamage(drown_dmg);
            }

            self.renderFrame(dt);
        }

        self.renderer.waitIdle();
    }

    /// Update camera, day/night cycle, chunk loading, and draw a frame.
    fn renderFrame(self: *Engine, dt: f32) void {
        const zm = @import("zmath");
        self.camera.pos = zm.f32x4(self.player_x, self.player_y + PLAYER_EYE_HEIGHT, self.player_z, 1.0);
        self.game_time.update(@as(f64, @floatCast(dt)));
        self.updateChunkLoading();
        const vp = self.camera.vpMatrix();
        const vp_arr = Camera.matToArray(vp);
        self.renderer.drawFrame(vp_arr, self.game_time.getSkyColor(), self.game_time.getFogColor()) catch |err| {
            std.debug.print("Render error: {}\n", .{err});
        };
    }

    fn updateChunkLoading(self: *Engine) void {
        const size_i32: i32 = @intCast(Chunk.SIZE);
        const player_cx = @divFloor(@as(i32, @intFromFloat(@floor(self.player_x))), size_i32);
        const player_cz = @divFloor(@as(i32, @intFromFloat(@floor(self.player_z))), size_i32);

        var load_result = self.chunk_loader.update(player_cx, player_cz) catch return;
        defer load_result.deinit();

        for (load_result.to_unload) |coord| {
            self.unloadChunk(coord.x, coord.z);
        }

        const load_count = @min(load_result.to_load.len, 2);
        for (load_result.to_load[0..load_count]) |coord| {
            self.loadChunk(coord.x, coord.z);
        }
    }

    fn loadChunk(self: *Engine, cx: i32, cz: i32) void {
        // Try loading saved chunk from disk; fall back to terrain generation
        const column = if (self.persistence.loadColumn(cx, cz) catch null) |saved|
            saved
        else
            terrain_gen.generateColumn(self.allocator, SEED, cx, cz);
        self.chunks.put(.{ .x = cx, .z = cz }, column) catch return;
        self.meshAndUploadColumn(cx, cz);
        self.chunk_loader.markLoaded(.{ .x = cx, .z = cz }) catch return;
    }

    fn unloadChunk(self: *Engine, cx: i32, cz: i32) void {
        const world_x = cx * @as(i32, Chunk.SIZE);
        const world_z = cz * @as(i32, Chunk.SIZE);
        // Remove all section renders for this column
        for (0..ChunkColumn.SECTIONS) |si| {
            const section_y: i32 = @as(i32, @intCast(si)) * @as(i32, Chunk.SIZE);
            self.removeChunkRender(world_x, section_y, world_z);
        }
        _ = self.chunks.remove(.{ .x = cx, .z = cz });
        self.chunk_loader.markUnloaded(.{ .x = cx, .z = cz });
    }

    /// Mesh all sections of the column at (cx, cz) using its neighbors and upload to the renderer.
    fn meshAndUploadColumn(self: *Engine, cx: i32, cz: i32) void {
        const col_ptr = self.chunks.getPtr(.{ .x = cx, .z = cz }) orelse return;
        const north_col = self.chunks.getPtr(.{ .x = cx, .z = cz - 1 });
        const south_col = self.chunks.getPtr(.{ .x = cx, .z = cz + 1 });
        const east_col = self.chunks.getPtr(.{ .x = cx + 1, .z = cz });
        const west_col = self.chunks.getPtr(.{ .x = cx - 1, .z = cz });

        const world_x = cx * @as(i32, Chunk.SIZE);
        const world_z = cz * @as(i32, Chunk.SIZE);

        meshColumnSections(self.allocator, &self.renderer, col_ptr, north_col, south_col, east_col, west_col, world_x, world_z) catch return;
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
        if (wy < 0 or wy >= ChunkColumn.HEIGHT) return null;
        const cx = @divFloor(wx, @as(i32, Chunk.SIZE));
        const cz = @divFloor(wz, @as(i32, Chunk.SIZE));
        const column = self.chunks.getPtr(.{ .x = cx, .z = cz }) orelse return null;
        const lx: u4 = @intCast(@mod(wx, @as(i32, Chunk.SIZE)));
        const lz: u4 = @intCast(@mod(wz, @as(i32, Chunk.SIZE)));
        return column.getBlock(lx, @intCast(wy), lz);
    }

    fn setWorldBlock(self: *Engine, wx: i32, wy: i32, wz: i32, id: block.BlockId) bool {
        if (wy < 0 or wy >= ChunkColumn.HEIGHT) return false;
        const cx = @divFloor(wx, @as(i32, Chunk.SIZE));
        const cz = @divFloor(wz, @as(i32, Chunk.SIZE));
        const col_ptr = self.chunks.getPtr(.{ .x = cx, .z = cz }) orelse return false;
        const lx: u4 = @intCast(@mod(wx, @as(i32, Chunk.SIZE)));
        const lz: u4 = @intCast(@mod(wz, @as(i32, Chunk.SIZE)));
        col_ptr.setBlock(lx, @intCast(wy), lz, id);
        self.persistence.markDirty(cx, cz) catch {};
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

    /// Water block check wrapper. Uses a static var to pass the Engine pointer
    /// into the function-pointer callback required by WaterState.updateWaterContact().
    const WaterBridge = struct {
        var engine_ctx: ?*Engine = null;

        fn isWater(x: i32, y: i32, z: i32) bool {
            const eng = engine_ctx orelse return false;
            const bid = eng.getWorldBlock(x, y, z) orelse return false;
            return bid == block.WATER;
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
        const col_ptr = self.chunks.getPtr(.{ .x = cx, .z = cz }) orelse return;

        const north_col = self.chunks.getPtr(.{ .x = cx, .z = cz - 1 });
        const south_col = self.chunks.getPtr(.{ .x = cx, .z = cz + 1 });
        const east_col = self.chunks.getPtr(.{ .x = cx + 1, .z = cz });
        const west_col = self.chunks.getPtr(.{ .x = cx - 1, .z = cz });

        const world_x = cx * @as(i32, Chunk.SIZE);
        const world_z = cz * @as(i32, Chunk.SIZE);

        // Remove all existing section renders for this column
        for (0..ChunkColumn.SECTIONS) |si| {
            const section_y: i32 = @as(i32, @intCast(si)) * @as(i32, Chunk.SIZE);
            self.removeChunkRender(world_x, section_y, world_z);
        }

        // Re-mesh all sections
        meshColumnSections(self.allocator, &self.renderer, col_ptr, north_col, south_col, east_col, west_col, world_x, world_z) catch return;
    }

    /// Remove a single chunk render entry matching (world_x, world_y, world_z).
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

/// Mesh all non-null sections of a column and upload them to the renderer.
/// Each section is meshed with its vertical and horizontal neighbors using
/// the greedy meshing algorithm for optimal vertex reduction.
fn meshColumnSections(
    allocator: std.mem.Allocator,
    renderer: *Renderer,
    col: *ChunkColumn,
    north_col: ?*ChunkColumn,
    south_col: ?*ChunkColumn,
    east_col: ?*ChunkColumn,
    west_col: ?*ChunkColumn,
    world_x: i32,
    world_z: i32,
) !void {
    for (0..ChunkColumn.SECTIONS) |si| {
        const section_idx: u4 = @intCast(si);
        const section_ptr = col.getSection(section_idx) orelse continue;

        // Vertical neighbors from the same column
        const top_section: ?*const Chunk = if (si < ChunkColumn.SECTIONS - 1)
            col.getSection(@intCast(si + 1))
        else
            null;
        const bottom_section: ?*const Chunk = if (si > 0)
            col.getSection(@intCast(si - 1))
        else
            null;

        // Horizontal neighbors: same section index from adjacent columns
        const north_section: ?*const Chunk = if (north_col) |nc| nc.getSection(section_idx) else null;
        const south_section: ?*const Chunk = if (south_col) |sc| sc.getSection(section_idx) else null;
        const east_section: ?*const Chunk = if (east_col) |ec| ec.getSection(section_idx) else null;
        const west_section: ?*const Chunk = if (west_col) |wc| wc.getSection(section_idx) else null;

        const neighbors = mesh_greedy.NeighborChunks{
            .north = north_section,
            .south = south_section,
            .east = east_section,
            .west = west_section,
            .top = top_section,
            .bottom = bottom_section,
        };

        var mesh_data = try mesh_greedy.generateMesh(allocator, section_ptr, neighbors);
        defer mesh_data.deinit();

        if (mesh_data.vertices.len == 0) continue;

        const section_y: i32 = @as(i32, @intCast(si)) * @as(i32, Chunk.SIZE);
        try renderer.uploadChunk(mesh_data.vertices, mesh_data.indices, world_x, section_y, world_z);
    }
}

test "subsystem count" {
    // Removed — no longer relevant with dynamic chunk count
}

test "block module" {
    _ = block;
}

test "chunk module" {
    _ = Chunk;
}

test "chunk_column module" {
    _ = ChunkColumn;
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

test "time module" {
    _ = time_mod;
}

test "chunk_loader module" {
    _ = chunk_loader_mod;
}

test "mob module" {
    _ = mob_mod;
}

test "entity module" {
    _ = entity_mod;
}

test "health module" {
    _ = health_mod;
}

test "water module" {
    _ = water_mod;
}

test "persistence module" {
    _ = persistence_mod;
}
