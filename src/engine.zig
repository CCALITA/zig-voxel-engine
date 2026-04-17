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
pub const dimension_mod = @import("world/dimension.zig");
pub const nether_gen = @import("world/nether_gen.zig");
pub const noise = @import("world/noise.zig");
pub const chunk_map = @import("world/chunk_map.zig");
pub const chunk_loader_mod = @import("world/chunk_loader.zig");
pub const raycast = @import("gameplay/raycast.zig");
pub const inventory_mod = @import("gameplay/inventory.zig");
pub const time_mod = @import("world/time.zig");
pub const mob_mod = @import("entity/mob.zig");
pub const entity_mod = @import("entity/entity.zig");
pub const health_mod = @import("gameplay/health.zig");
pub const water_mod = @import("physics/water.zig");
pub const persistence_mod = @import("world/persistence.zig");
pub const item_drop_mod = @import("gameplay/item_drop.zig");
pub const crafting_mod = @import("gameplay/crafting.zig");
pub const furnace_mod = @import("gameplay/furnace.zig");
pub const particles_mod = @import("renderer/particles.zig");
pub const xp_mod = @import("gameplay/experience.zig");
pub const achievement_mod = @import("gameplay/achievements.zig");
pub const armor_mod = @import("gameplay/armor.zig");
pub const weather_mod = @import("world/weather.zig");
pub const movement_mod = @import("gameplay/movement.zig");
pub const gamemode_mod = @import("gameplay/gamemode.zig");
pub const breeding_mod = @import("gameplay/breeding.zig");
pub const fishing_mod = @import("gameplay/fishing.zig");
pub const command_mod = @import("gameplay/commands.zig");
pub const block_interact = @import("world/block_interact.zig");

const SEED: u64 = 42;
const RENDER_RADIUS: i32 = 6;

// Loot item IDs for mob drops (above the BlockId range to avoid conflicts)
const ITEM_ROTTEN_FLESH: u16 = 200;
const ITEM_BONE: u16 = 201;
const ITEM_ARROW: u16 = 202;
const ITEM_GUNPOWDER: u16 = 203;
const ITEM_RAW_PORK: u16 = 204;
const ITEM_RAW_BEEF: u16 = 205;
const ITEM_RAW_CHICKEN: u16 = 206;
const ITEM_FEATHER: u16 = 207;
const ITEM_WOOL: u16 = 208;
const ITEM_RAW_MUTTON: u16 = 209;

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

    // Persistence (save/load)
    persistence: persistence_mod.WorldPersistence,

    // Item drops
    drop_manager: item_drop_mod.ItemDropManager,

    // Dimension switching
    current_dimension: dimension_mod.DimensionType,
    overworld_player_pos: ?struct { x: f32, y: f32, z: f32 },
    last_p_press: bool,

    // Crafting and furnace systems
    crafting_registry: crafting_mod.CraftingRegistry,
    active_furnaces: std.ArrayList(FurnaceEntry),
    last_craft_key: bool,

    // Particle system
    particle_manager: particles_mod.ParticleManager,

    // Experience, achievements, and armor
    xp: xp_mod.ExperienceTracker,
    achievements: achievement_mod.AchievementTracker,
    armor: armor_mod.ArmorInventory,

    // Weather system
    weather: weather_mod.WeatherState,

    // Movement (sprint/sneak) system
    movement: movement_mod.MovementState,

    // Game mode system
    gamemode: gamemode_mod.GameModeManager,
    last_f1_press: bool,
    last_space_press_time: f64,
    last_space_press: bool,

    // Breeding, fishing, and command systems
    breeding: breeding_mod.BreedingManager,
    fishing: fishing_mod.FishingState,
    command_buffer: [256]u8,
    command_len: u8,
    chat_open: bool,
    last_f_press: bool,
    last_t_press: bool,

    const FurnaceEntry = struct {
        x: i32,
        y: i32,
        z: i32,
        state: furnace_mod.FurnaceState,
    };

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

        // Generate a small initial set (3x3 around spawn) to avoid blank first frame
        const INIT_RADIUS: i32 = 1;
        var cx: i32 = -INIT_RADIUS;
        while (cx <= INIT_RADIUS) : (cx += 1) {
            var cz: i32 = -INIT_RADIUS;
            while (cz <= INIT_RADIUS) : (cz += 1) {
                const column = terrain_gen.generateColumn(allocator, SEED, cx, cz);
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

        // Initialize persistence
        const persistence = try persistence_mod.WorldPersistence.init(allocator, "default");

        // Initialize item drop manager
        const drop_manager = item_drop_mod.ItemDropManager.init(allocator);

        // Initialize crafting registry with default recipes
        var crafting_registry = crafting_mod.CraftingRegistry.init();
        try crafting_registry.registerDefaults(allocator);

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
            .persistence = persistence,
            .drop_manager = drop_manager,
            .current_dimension = .overworld,
            .overworld_player_pos = null,
            .last_p_press = false,
            .crafting_registry = crafting_registry,
            .active_furnaces = .empty,
            .last_craft_key = false,
            .particle_manager = particles_mod.ParticleManager.init(),
            .xp = xp_mod.ExperienceTracker.init(),
            .achievements = achievement_mod.AchievementTracker.init(),
            .armor = armor_mod.ArmorInventory.init(),
            .weather = weather_mod.WeatherState.init(),
            .movement = movement_mod.MovementState.init(),
            .gamemode = gamemode_mod.GameModeManager.init(.survival),
            .last_f1_press = false,
            .last_space_press_time = 0.0,
            .last_space_press = false,
            .breeding = breeding_mod.BreedingManager.init(),
            .fishing = fishing_mod.FishingState.init(),
            .command_buffer = [_]u8{0} ** 256,
            .command_len = 0,
            .chat_open = false,
            .last_f_press = false,
            .last_t_press = false,
        };
    }

    pub fn deinit(self: *Engine) void {
        _ = self.persistence.saveAllDirtyColumns(&self.chunks) catch 0;
        self.persistence.deinit();
        self.drop_manager.deinit();
        self.mob_manager.deinit();
        self.breeding.deinit(self.allocator);
        self.crafting_registry.deinit(self.allocator);
        self.active_furnaces.deinit(self.allocator);
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

            // Death screen: press R to respawn, skip gameplay updates
            if (self.player_stats.is_dead) {
                if (self.window.handle.getKey(.r) == .press) {
                    self.player_stats = health_mod.PlayerStats.init();
                    self.player_x = 8.0;
                    self.player_y = 70.0;
                    self.player_z = 8.0;
                    self.player_vy = 0.0;
                    self.on_ground = false;
                }
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

            // Update weather simulation
            self.weather.update(dt);

            // Update movement mode (sprint/sneak)
            const ctrl_held = self.window.handle.getKey(.left_control) == .press or
                self.window.handle.getKey(.right_control) == .press;
            const shift_held = self.window.handle.getKey(.left_shift) == .press or
                self.window.handle.getKey(.right_shift) == .press;
            self.movement.updateInput(ctrl_held, shift_held, forward_input > 0, current_time, self.water_state.in_water);

            // Game mode toggle: F1 switches between survival and creative
            const f1_pressed = self.window.handle.getKey(.F1) == .press;
            if (f1_pressed and !self.last_f1_press) {
                const new_mode: gamemode_mod.GameMode = if (self.gamemode.current == .survival) .creative else .survival;
                self.gamemode.setMode(new_mode);
            }
            self.last_f1_press = f1_pressed;

            // Double-space toggles flight in creative mode
            const space_pressed = self.window.handle.getKey(.space) == .press;
            if (space_pressed and !self.last_space_press) {
                const elapsed = current_time - self.last_space_press_time;
                if (elapsed <= 0.3 and elapsed > 0.0) {
                    self.gamemode.toggleFlight();
                }
                self.last_space_press_time = current_time;
            }
            self.last_space_press = space_pressed;

            // Jump / swim / fly
            if (self.gamemode.is_flying) {
                self.player_vy = 0.0;
                if (space_pressed) {
                    self.player_vy = 6.0;
                } else if (shift_held) {
                    self.player_vy = -6.0;
                }
            } else if (space_pressed) {
                if (self.water_state.in_water and !self.on_ground) {
                    self.player_vy = self.water_state.getSwimUpSpeed();
                } else if (self.on_ground) {
                    self.player_vy = 8.0; // jump impulse
                    self.on_ground = false;
                }
            }

            // Ladder climbing: check if player's feet overlap a ladder block
            const feet_bx = @as(i32, @intFromFloat(@floor(self.player_x)));
            const feet_by = @as(i32, @intFromFloat(@floor(self.player_y)));
            const feet_bz = @as(i32, @intFromFloat(@floor(self.player_z)));
            if (self.getWorldBlock(feet_bx, feet_by, feet_bz)) |feet_block| {
                if (feet_block == block.LADDER) {
                    const is_sneaking = self.movement.mode == .sneak;
                    self.player_vy = block_interact.getLadderClimbSpeed(forward_input > 0, is_sneaking);
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

            // Portal key: P toggles between overworld and nether
            const p_pressed = self.window.handle.getKey(.p) == .press;
            if (p_pressed and !self.last_p_press) {
                self.renderer.waitIdle();
                self.switchDimension();
            }
            self.last_p_press = p_pressed;

            // Quick-craft (C key)
            self.handleQuickCraft();

            // Update all active furnaces
            for (self.active_furnaces.items) |*entry| {
                entry.state.update(dt);
            }

            // Breeding: tick pending entries and spawn babies
            const breed_ready = self.breeding.update(self.allocator, dt) catch &[_]breeding_mod.BreedingEntry{};
            for (breed_ready) |entry| {
                const etype: entity_mod.EntityType = @enumFromInt(entry.entity_type);
                self.mob_manager.spawn(etype, entry.spawn_x, entry.spawn_y, entry.spawn_z) catch {};
            }

            // Fishing: F key casts/reels fishing rod
            const f_pressed = self.window.handle.getKey(.f) == .press;
            if (f_pressed and !self.last_f_press and !self.chat_open) {
                if (self.fishing.phase == .idle) {
                    self.fishing.cast(self.player_x, self.player_y, self.player_z);
                } else {
                    if (self.fishing.reel()) |catch_result| {
                        _ = self.inventory.addItem(catch_result.item_id, catch_result.count);
                        self.xp.addXP(catch_result.xp);
                    }
                }
            }
            self.last_f_press = f_pressed;
            self.fishing.update(dt);

            // Chat/commands: T opens chat, Escape closes, Enter executes
            self.handleChatInput();

            // Horizontal movement based on camera direction
            const fwd = self.camera.forward();
            const rt = self.camera.right();
            const speed: f32 = 6.0 * self.water_state.getSpeedMultiplier() * self.movement.getSpeedMultiplier();
            var move_x: f32 = 0;
            var move_z: f32 = 0;

            // Project forward/right onto XZ plane
            move_x += fwd[0] * forward_input * speed * dt;
            move_z += fwd[2] * forward_input * speed * dt;
            move_x += rt[0] * right_input * speed * dt;
            move_z += rt[2] * right_input * speed * dt;

            // Apply gravity (reduced in water, disabled when flying)
            if (!self.gamemode.is_flying) {
                const gravity: f32 = self.water_state.getGravity();
                self.player_vy += gravity * dt;
            }

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
            // Only in game modes that take damage
            if (self.gamemode.takesBlockDamage() and self.on_ground and !was_on_ground and pre_land_vy < -10.0) {
                const fall_damage = @abs(pre_land_vy) - 10.0;
                const reduced = self.armor.getDamageReduction(fall_damage);
                self.player_stats.takeDamage(fall_damage - reduced);
            }

            // Update health/hunger
            self.player_stats.update(dt);

            // Update mob AI and remove dead entities
            self.mob_manager.update(self.player_x, self.player_y, self.player_z, dt);

            // Hostile mob melee attacks on the player
            if (self.gamemode.takesBlockDamage()) {
                for (self.mob_manager.entities.items) |*mob| {
                    if (!mob.alive) continue;
                    if (!mob.entity_type.isHostile()) continue;
                    const dist = mob.distanceToPoint(self.player_x, self.player_y, self.player_z);
                    if (dist < 2.0) {
                        const damage: f32 = switch (mob.entity_type) {
                            .zombie => 3.0,
                            .skeleton => 4.0,
                            .creeper => 0.0, // explodes instead (future)
                            else => 2.0,
                        };
                        if (damage > 0) {
                            const reduced = self.armor.getDamageReduction(damage);
                            self.player_stats.takeDamage(damage - reduced);
                        }
                    }
                }
            }

            // Collect loot from newly dead mobs before removing them
            self.spawnMobLoot();
            self.mob_manager.removeDeadEntities();

            // Drowning damage
            const drown_dmg = self.water_state.updateOxygen(dt);
            if (drown_dmg > 0) {
                const drown_reduced = self.armor.getDamageReduction(drown_dmg);
                self.player_stats.takeDamage(drown_dmg - drown_reduced);
            }

            // Update item drops (physics, pickup, despawn)
            if (self.drop_manager.update(dt, self.player_x, self.player_y, self.player_z)) |picked_up| {
                defer self.allocator.free(picked_up);
                for (picked_up) |drop| {
                    _ = self.inventory.addItem(drop.item_id, drop.count);
                }
            } else |_| {}
            self.drop_manager.cleanup();

            // Update particle simulation
            self.particle_manager.update(dt);

            self.renderFrame(dt);
        }

        self.renderer.waitIdle();
    }

    /// Spawn item drops for any mobs that have just died (alive == false).
    /// Called before removeDeadEntities so the corpses are still in the list.
    fn spawnMobLoot(self: *Engine) void {
        for (self.mob_manager.entities.items) |*mob| {
            if (mob.alive) continue;

            const drops: []const struct { id: u16, count: u8 } = switch (mob.entity_type) {
                .zombie => &.{.{ .id = ITEM_ROTTEN_FLESH, .count = 1 }},
                .skeleton => &.{
                    .{ .id = ITEM_BONE, .count = 1 },
                    .{ .id = ITEM_ARROW, .count = 2 },
                },
                .creeper => &.{.{ .id = ITEM_GUNPOWDER, .count = 1 }},
                .pig => &.{.{ .id = ITEM_RAW_PORK, .count = 2 }},
                .cow => &.{.{ .id = ITEM_RAW_BEEF, .count = 2 }},
                .chicken => &.{
                    .{ .id = ITEM_RAW_CHICKEN, .count = 1 },
                    .{ .id = ITEM_FEATHER, .count = 2 },
                },
                .sheep => &.{
                    .{ .id = ITEM_WOOL, .count = 1 },
                    .{ .id = ITEM_RAW_MUTTON, .count = 1 },
                },
                else => &.{},
            };

            for (drops) |d| {
                self.drop_manager.spawnDrop(mob.x, mob.y + 0.5, mob.z, d.id, d.count) catch {};
            }

            const mob_xp: u32 = switch (mob.entity_type) {
                .zombie, .skeleton, .creeper => 5,
                else => 1,
            };
            self.xp.addXP(mob_xp);
        }
    }

    fn switchDimension(self: *Engine) void {
        if (self.current_dimension == .overworld) {
            self.overworld_player_pos = .{
                .x = self.player_x,
                .y = self.player_y,
                .z = self.player_z,
            };
            self.current_dimension = .nether;
            // Nether coords = overworld / 8
            self.player_x /= 8.0;
            self.player_z /= 8.0;
            self.player_y = 70.0; // spawn height in nether
        } else {
            self.current_dimension = .overworld;
            if (self.overworld_player_pos) |pos| {
                self.player_x = pos.x;
                self.player_y = pos.y;
                self.player_z = pos.z;
            }
        }
        self.player_vy = 0.0;
        self.on_ground = false;

        // Unload all chunks and reload for new dimension
        self.renderer.clearChunks();
        self.chunks.clearAndFree();
        self.chunk_loader.deinit();
        self.chunk_loader = chunk_loader_mod.ChunkLoader.init(self.allocator, RENDER_RADIUS);
        // Chunks will load via dynamic loader next frame
    }

    /// Update camera, day/night cycle, chunk loading, and draw a frame.
    fn renderFrame(self: *Engine, dt: f32) void {
        const zm = @import("zmath");
        const cam_y = self.player_y + PLAYER_EYE_HEIGHT + self.movement.getCameraYOffset();
        self.camera.pos = zm.f32x4(self.player_x, cam_y, self.player_z, 1.0);
        self.game_time.update(@as(f64, @floatCast(dt)));
        self.updateChunkLoading();
        const vp = self.camera.vpMatrix();
        const vp_arr = Camera.matToArray(vp);

        // Non-natural dimensions (nether, end) use fixed sky/fog instead of day/night cycle
        const dim_def = dimension_mod.getDef(self.current_dimension);
        var sky_color = if (dim_def.natural) self.game_time.getSkyColor() else dim_def.sky_color;
        const fog_color = if (dim_def.natural) self.game_time.getFogColor() else dim_def.fog_color;

        // Weather darkening: reduce sky brightness during rain/thunder
        const weather_factor = 1.0 - self.weather.getSkyDarkening();
        sky_color[0] *= weather_factor;
        sky_color[1] *= weather_factor;
        sky_color[2] *= weather_factor;

        self.renderer.drawFrame(vp_arr, sky_color, fog_color) catch |err| {
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
        // Try loading from disk first; fall back to terrain generation
        const column = if (self.persistence.loadColumn(cx, cz) catch null) |saved_col|
            saved_col
        else if (self.current_dimension == .nether)
            nether_gen.generateChunk(SEED, cx, cz)
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
            if (!self.gamemode.canBreak()) return;
            self.renderer.waitIdle();
            self.breakBlock(hit.bx, hit.by, hit.bz);
        } else if (right_just_pressed) {
            if (!self.gamemode.canPlace()) return;
            const target_bid = self.getWorldBlock(hit.bx, hit.by, hit.bz) orelse block.AIR;

            const interaction = block_interact.getInteraction(target_bid);
            if (interaction != .none) {
                const is_night = self.game_time.getPhase() == .night;
                const result = block_interact.interact(target_bid, is_night);
                if (result.set_time) |t| self.game_time.tick = t;
                if (result.climb_speed) |spd| self.player_vy = spd;
                return;
            }

            if (target_bid == block.FURNACE) {
                self.interactFurnace(hit.bx, hit.by, hit.bz);
            } else {
                self.renderer.waitIdle();
                self.placeBlock(hit.adjacent_x, hit.adjacent_y, hit.adjacent_z);
            }
        }
    }

    /// Quick-craft: when C is pressed, try to auto-craft the first matching recipe
    /// from materials in the inventory.
    fn handleQuickCraft(self: *Engine) void {
        const c_pressed = self.window.handle.getKey(.c) == .press;
        const c_just_pressed = c_pressed and !self.last_craft_key;
        self.last_craft_key = c_pressed;

        if (!c_just_pressed) return;

        for (self.crafting_registry.recipes.items) |recipe| {
            if (self.canCraftRecipe(recipe)) {
                self.consumeRecipeInputs(recipe);
                _ = self.inventory.addItem(recipe.result_item, recipe.result_count);
                return;
            }
        }
    }

    /// Handle chat mode toggling (T to open, Escape to close, Enter to execute).
    fn handleChatInput(self: *Engine) void {
        const t_pressed = self.window.handle.getKey(.t) == .press;
        const t_just_pressed = t_pressed and !self.last_t_press;
        self.last_t_press = t_pressed;

        if (!self.chat_open) {
            if (t_just_pressed) {
                self.chat_open = true;
                self.command_len = 0;
            }
            return;
        }

        // Chat is open: Escape closes it
        if (self.window.handle.getKey(.escape) == .press) {
            self.chat_open = false;
            return;
        }

        // Enter executes the command
        if (self.window.handle.getKey(.enter) == .press) {
            if (self.command_len > 0) {
                const input = self.command_buffer[0..self.command_len];
                const cmd = command_mod.parse(input);
                const result = command_mod.execute(cmd, input);
                std.debug.print("[CMD] {s}\n", .{result.message});
            }
            self.chat_open = false;
            return;
        }

        // Buffer typed characters (printable ASCII keys)
        self.bufferTypedKeys();
    }

    /// Poll printable key presses and append to command_buffer.
    fn bufferTypedKeys(self: *Engine) void {
        const printable_keys = [_]struct { key: zglfw.Key, char: u8, shifted: u8 }{
            .{ .key = .a, .char = 'a', .shifted = 'A' },
            .{ .key = .b, .char = 'b', .shifted = 'B' },
            .{ .key = .c, .char = 'c', .shifted = 'C' },
            .{ .key = .d, .char = 'd', .shifted = 'D' },
            .{ .key = .e, .char = 'e', .shifted = 'E' },
            .{ .key = .f, .char = 'f', .shifted = 'F' },
            .{ .key = .g, .char = 'g', .shifted = 'G' },
            .{ .key = .h, .char = 'h', .shifted = 'H' },
            .{ .key = .i, .char = 'i', .shifted = 'I' },
            .{ .key = .j, .char = 'j', .shifted = 'J' },
            .{ .key = .k, .char = 'k', .shifted = 'K' },
            .{ .key = .l, .char = 'l', .shifted = 'L' },
            .{ .key = .m, .char = 'm', .shifted = 'M' },
            .{ .key = .n, .char = 'n', .shifted = 'N' },
            .{ .key = .o, .char = 'o', .shifted = 'O' },
            .{ .key = .p, .char = 'p', .shifted = 'P' },
            .{ .key = .q, .char = 'q', .shifted = 'Q' },
            .{ .key = .r, .char = 'r', .shifted = 'R' },
            .{ .key = .s, .char = 's', .shifted = 'S' },
            .{ .key = .t, .char = 't', .shifted = 'T' },
            .{ .key = .u, .char = 'u', .shifted = 'U' },
            .{ .key = .v, .char = 'v', .shifted = 'V' },
            .{ .key = .w, .char = 'w', .shifted = 'W' },
            .{ .key = .x, .char = 'x', .shifted = 'X' },
            .{ .key = .y, .char = 'y', .shifted = 'Y' },
            .{ .key = .z, .char = 'z', .shifted = 'Z' },
            .{ .key = .zero, .char = '0', .shifted = ')' },
            .{ .key = .one, .char = '1', .shifted = '!' },
            .{ .key = .two, .char = '2', .shifted = '@' },
            .{ .key = .three, .char = '3', .shifted = '#' },
            .{ .key = .four, .char = '4', .shifted = '$' },
            .{ .key = .five, .char = '5', .shifted = '%' },
            .{ .key = .six, .char = '6', .shifted = '^' },
            .{ .key = .seven, .char = '7', .shifted = '&' },
            .{ .key = .eight, .char = '8', .shifted = '*' },
            .{ .key = .nine, .char = '9', .shifted = '(' },
            .{ .key = .space, .char = ' ', .shifted = ' ' },
            .{ .key = .slash, .char = '/', .shifted = '?' },
            .{ .key = .period, .char = '.', .shifted = '>' },
            .{ .key = .minus, .char = '-', .shifted = '_' },
        };

        const shift_held = (self.window.handle.getKey(.left_shift) == .press) or
            (self.window.handle.getKey(.right_shift) == .press);

        for (printable_keys) |pk| {
            if (self.window.handle.getKey(pk.key) == .press) {
                if (self.command_len < 255) {
                    const ch = if (shift_held) pk.shifted else pk.char;
                    self.command_buffer[self.command_len] = ch;
                    self.command_len += 1;
                }
            }
        }

        // Backspace
        if (self.window.handle.getKey(.backspace) == .press and self.command_len > 0) {
            self.command_len -= 1;
            self.command_buffer[self.command_len] = 0;
        }
    }

    /// Tally distinct item requirements from a 3x3 recipe pattern.
    /// A recipe grid has at most 9 cells, so at most 9 distinct item types.
    const MAX_TALLY = 9;
    const ItemTally = struct {
        item: inventory_mod.ItemId,
        count: u16,
    };

    fn tallyPattern(pattern: [3][3]inventory_mod.ItemId) struct { entries: [MAX_TALLY]ItemTally, len: usize } {
        var entries: [MAX_TALLY]ItemTally = undefined;
        var len: usize = 0;
        for (pattern) |row| {
            for (row) |cell| {
                if (cell == 0) continue;
                var found = false;
                for (entries[0..len]) |*e| {
                    if (e.item == cell) {
                        e.count += 1;
                        found = true;
                        break;
                    }
                }
                if (!found) {
                    entries[len] = .{ .item = cell, .count = 1 };
                    len += 1;
                }
            }
        }
        return .{ .entries = entries, .len = len };
    }

    fn canCraftRecipe(self: *const Engine, recipe: crafting_mod.Recipe) bool {
        const tally = tallyPattern(recipe.pattern);
        for (tally.entries[0..tally.len]) |req| {
            var have: u16 = 0;
            for (self.inventory.slots) |slot| {
                if (slot.item == req.item and slot.count > 0) {
                    have += slot.count;
                }
            }
            if (have < req.count) return false;
        }
        return true;
    }

    fn consumeRecipeInputs(self: *Engine, recipe: crafting_mod.Recipe) void {
        const tally = tallyPattern(recipe.pattern);
        for (tally.entries[0..tally.len]) |req| {
            var remaining = req.count;
            for (&self.inventory.slots) |*slot| {
                if (remaining == 0) break;
                if (slot.item == req.item and slot.count > 0) {
                    const take = @min(slot.count, @as(u8, @intCast(remaining)));
                    slot.count -= take;
                    if (slot.count == 0) slot.item = 0;
                    remaining -= take;
                }
            }
        }
    }

    /// Interact with a furnace block: find or create the furnace state,
    /// then add the held item as fuel/input, or collect output if empty-handed.
    fn interactFurnace(self: *Engine, wx: i32, wy: i32, wz: i32) void {
        const fs = self.getOrCreateFurnace(wx, wy, wz) orelse return;

        const slot = self.inventory.getSlot(self.selected_slot);
        if (slot.isEmpty()) {
            const output = fs.takeOutput();
            if (output.count > 0) {
                _ = self.inventory.addItem(output.item, output.count);
            }
            return;
        }

        const item_id = slot.item;
        const accepted = if (furnace_mod.getFuelValue(item_id) != null)
            fs.addFuel(item_id, 1) == 0
        else if (furnace_mod.findRecipe(item_id) != null)
            fs.addInput(item_id, 1) == 0
        else
            false;

        if (accepted) {
            _ = self.inventory.removeItem(self.selected_slot, 1);
        }
    }

    fn getOrCreateFurnace(self: *Engine, wx: i32, wy: i32, wz: i32) ?*furnace_mod.FurnaceState {
        for (self.active_furnaces.items) |*entry| {
            if (entry.x == wx and entry.y == wy and entry.z == wz) {
                return &entry.state;
            }
        }
        self.active_furnaces.append(self.allocator, .{
            .x = wx,
            .y = wy,
            .z = wz,
            .state = furnace_mod.FurnaceState.init(),
        }) catch return null;
        return &self.active_furnaces.items[self.active_furnaces.items.len - 1].state;
    }

    fn breakBlock(self: *Engine, wx: i32, wy: i32, wz: i32) void {
        // Read old block before replacing with air
        const old_block = self.getWorldBlock(wx, wy, wz) orelse return;
        if (!self.setWorldBlock(wx, wy, wz, block.AIR)) return;

        // Achievement: first block break
        _ = self.achievements.unlock(.mine_wood);

        // XP reward for ore mining
        const xp_reward: u32 = switch (old_block) {
            block.COAL_ORE => xp_mod.XP_COAL_ORE,
            block.IRON_ORE => xp_mod.XP_IRON_ORE,
            block.GOLD_ORE => xp_mod.XP_GOLD_ORE,
            block.DIAMOND_ORE => xp_mod.XP_DIAMOND_ORE,
            block.REDSTONE_ORE => xp_mod.XP_REDSTONE_ORE,
            else => 0,
        };
        if (xp_reward > 0) {
            self.xp.addXP(xp_reward);
            // Achievement: first ore mined
            _ = self.achievements.unlock(.mine_stone);
        }

        // Achievement: diamond ore mined
        if (old_block == block.DIAMOND_ORE) {
            _ = self.achievements.unlock(.mine_diamond);
        }

        // Spawn an item drop if the block was not air
        if (old_block != block.AIR) {
            const fx: f32 = @as(f32, @floatFromInt(wx)) + 0.5;
            const fy: f32 = @as(f32, @floatFromInt(wy)) + 0.5;
            const fz: f32 = @as(f32, @floatFromInt(wz)) + 0.5;

            // Emit break particles with the block's color
            const color = getBlockColor(old_block);
            self.particle_manager.emitBlockBreak(fx, fy, fz, color[0], color[1], color[2]);

            self.drop_manager.spawnDrop(fx, fy, fz, @as(u16, old_block), 1) catch {};
        }

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

/// Approximate block colors matching the terrain.frag palette.
/// Maps a block ID to an RGB color for particle effects.
fn getBlockColor(block_id: block.BlockId) [3]f32 {
    return switch (block_id) {
        block.STONE => .{ 0.50, 0.50, 0.50 },
        block.DIRT => .{ 0.55, 0.35, 0.20 },
        block.GRASS => .{ 0.30, 0.65, 0.15 },
        block.COBBLESTONE => .{ 0.40, 0.40, 0.40 },
        block.OAK_PLANKS => .{ 0.70, 0.55, 0.30 },
        block.SAND => .{ 0.85, 0.80, 0.55 },
        block.GRAVEL => .{ 0.55, 0.50, 0.45 },
        block.OAK_LOG => .{ 0.40, 0.30, 0.15 },
        block.OAK_LEAVES => .{ 0.20, 0.50, 0.10 },
        block.WATER => .{ 0.20, 0.35, 0.80 },
        block.BEDROCK => .{ 0.25, 0.25, 0.25 },
        block.COAL_ORE => .{ 0.35, 0.35, 0.35 },
        block.IRON_ORE => .{ 0.55, 0.50, 0.45 },
        block.GOLD_ORE => .{ 0.65, 0.60, 0.30 },
        block.DIAMOND_ORE => .{ 0.40, 0.65, 0.65 },
        block.REDSTONE_ORE => .{ 0.55, 0.25, 0.20 },
        block.GLASS => .{ 0.75, 0.85, 0.90 },
        block.BRICK => .{ 0.60, 0.30, 0.25 },
        block.OBSIDIAN => .{ 0.10, 0.05, 0.15 },
        block.TNT => .{ 0.75, 0.30, 0.25 },
        block.BOOKSHELF => .{ 0.50, 0.35, 0.20 },
        block.MOSSY_COBBLESTONE => .{ 0.35, 0.45, 0.30 },
        block.ICE => .{ 0.65, 0.80, 0.95 },
        block.SNOW => .{ 0.90, 0.92, 0.95 },
        block.CLAY => .{ 0.65, 0.62, 0.58 },
        block.CACTUS => .{ 0.20, 0.55, 0.15 },
        block.PUMPKIN => .{ 0.80, 0.50, 0.10 },
        block.MELON => .{ 0.40, 0.60, 0.20 },
        block.GLOWSTONE => .{ 0.85, 0.75, 0.40 },
        block.NETHERRACK => .{ 0.45, 0.20, 0.20 },
        block.SOUL_SAND => .{ 0.35, 0.28, 0.22 },
        block.LAVA => .{ 0.90, 0.40, 0.10 },
        block.FURNACE => .{ 0.50, 0.50, 0.50 },
        block.DOOR => .{ 0.55, 0.40, 0.25 },
        block.BED => .{ 0.60, 0.20, 0.20 },
        block.LADDER => .{ 0.55, 0.40, 0.25 },
        block.CHEST => .{ 0.55, 0.40, 0.20 },
        block.TRAPDOOR => .{ 0.50, 0.38, 0.22 },
        else => .{ 0.50, 0.50, 0.50 },
    };
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

test "item_drop module" {
    _ = item_drop_mod;
}

test "dimension module" {
    _ = dimension_mod;
}

test "nether_gen module" {
    _ = nether_gen;
}

test "crafting module" {
    _ = crafting_mod;
}

test "furnace module" {
    _ = furnace_mod;
}

test "particles module" {
    _ = particles_mod;
}

test "experience module" {
    _ = xp_mod;
}

test "achievement module" {
    _ = achievement_mod;
}

test "armor module" {
    _ = armor_mod;
}

test "weather module" {
    _ = weather_mod;
}

test "movement module" {
    _ = movement_mod;
}

test "gamemode module" {
    _ = gamemode_mod;
}

test "breeding module" {
    _ = breeding_mod;
}

test "fishing module" {
    _ = fishing_mod;
}

test "command module" {
    _ = command_mod;
}

test "block_interact module" {
    _ = block_interact;
}
