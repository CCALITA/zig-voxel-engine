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
pub const scoreboard_mod = @import("gameplay/scoreboard.zig");
pub const tools_mod = @import("gameplay/tools.zig");
pub const food_mod = @import("gameplay/food.zig");
pub const hazards_mod = @import("gameplay/hazards.zig");
pub const explosion_mod = @import("gameplay/explosion.zig");
pub const projectiles_mod = @import("gameplay/projectiles.zig");
pub const spawner_mod = @import("entity/spawner.zig");
pub const taming_mod = @import("entity/taming.zig");
pub const banners_mod = @import("gameplay/banners.zig");
pub const command_block_mod = @import("gameplay/command_block.zig");
pub const crafting_stations_mod = @import("gameplay/crafting_stations.zig");
pub const storage_mod = @import("gameplay/storage.zig");
pub const cooking_mod = @import("gameplay/cooking.zig");
pub const copper_mod = @import("gameplay/copper.zig");
pub const mob_variants_mod = @import("entity/mob_variants.zig");
pub const advancements_mod = @import("gameplay/advancements.zig");
pub const pathfinding_mod = @import("entity/pathfinding.zig");
pub const loot_mod = @import("gameplay/loot_tables.zig");
pub const recipe_mod = @import("gameplay/recipe_book.zig");

// Batch 9 modules
pub const world_rules_mod = @import("world/world_rules.zig");
pub const biome_features_mod = @import("world/biome_features.zig");
pub const enchant_table_mod = @import("gameplay/enchant_table.zig");
pub const piston_mod = @import("redstone/piston.zig");
pub const anvil_mod = @import("gameplay/anvil.zig");
pub const beacon_mod = @import("gameplay/beacon.zig");
pub const brewing_stand_mod = @import("gameplay/brewing_stand.zig");
pub const decorations_mod = @import("world/decorations.zig");
pub const ender_items_mod = @import("gameplay/ender_items.zig");
pub const music_mod = @import("gameplay/music.zig");
pub const map_item_mod = @import("gameplay/map_item.zig");
pub const automation_mod = @import("gameplay/automation.zig");
pub const netherite = @import("gameplay/netherite.zig");
const ui_pipeline_mod = @import("ui_pipeline.zig");
const texture_atlas_mod = @import("renderer/texture_atlas.zig");
const bitmap_font = @import("renderer/bitmap_font.zig");
const crafting_grid_mod = @import("gameplay/crafting_grid.zig");
const recipe_matching_mod = @import("gameplay/recipe_matching.zig");
const recipes_tools = @import("gameplay/recipes_tools.zig");
const recipes_armor = @import("gameplay/recipes_armor.zig");
const recipes_redstone = @import("gameplay/recipes_redstone.zig");
const recipes_decorative = @import("gameplay/recipes_decorative.zig");
const recipes_transport = @import("gameplay/recipes_transport.zig");
const recipes_food = @import("gameplay/recipes_food.zig");

const SEED: u64 = 42;
const RENDER_RADIUS: i32 = 6;

// Enchanting table block ID (placeholder until added to block.zig)
const ENCHANTING_TABLE_BLOCK_ID: u8 = 47;

// Player dimensions (shared between collision and block placement)
const PLAYER_WIDTH: f32 = 0.6;
const PLAYER_HEIGHT: f32 = 1.8;
const PLAYER_HALF_W: f32 = PLAYER_WIDTH / 2.0;
const PLAYER_EYE_HEIGHT: f32 = 1.6;

pub const DebugInfo = struct {
    fps: f32,
    frame_time_ms: f32,
    player_x: f32,
    player_y: f32,
    player_z: f32,
    chunk_x: i32,
    chunk_z: i32,
    loaded_chunks: u32,
    entity_count: u32,
    dimension: []const u8,
    biome: []const u8,
    facing_direction: []const u8,
};

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
    mob_spawner: spawner_mod.MobSpawner,

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

    // Scoreboard / stat tracking
    stat_tracker: scoreboard_mod.StatTracker,

    // Active TNT fuses
    active_tnt: std.ArrayList(explosion_mod.TNTState),

    // Projectile system (arrows, thrown items)
    projectile_manager: projectiles_mod.ProjectileManager,

    // World rules (difficulty, spawn, border)
    world_rules: world_rules_mod.WorldRules,

    // Mining progress (held left-click block breaking)
    mining_progress: f32 = 0.0,
    mining_target: ?BlockPos = null,

    // Food eating (held right-click consumption)
    eating_progress: f32 = 0.0,

    // F3 debug overlay data
    debug_info: DebugInfo = .{
        .fps = 0.0,
        .frame_time_ms = 0.0,
        .player_x = 0.0,
        .player_y = 0.0,
        .player_z = 0.0,
        .chunk_x = 0,
        .chunk_z = 0,
        .loaded_chunks = 0,
        .entity_count = 0,
        .dimension = "overworld",
        .biome = "plains",
        .facing_direction = "north",
    },
    show_debug: bool = false,
    last_f3_press: bool = false,
    status_timer: f32 = 0.0,

    // Copper oxidation random-tick timer and frame counter for hash variation

    // --- Wired from dead imports ---
    // Advancement tracking (was dead import)
    advancements: advancements_mod.AdvancementManager = advancements_mod.AdvancementManager.init(),
    // Biome features for sky/water tinting
    // (biome_features_mod used inline via function calls, no state needed)
    // Cooking: active smokers/blast furnaces alongside regular furnaces
    active_smokers: u8 = 0,
    active_blast_furnaces: u8 = 0,
    // Storage: ender chest shared inventory
    // (storage_mod.EnderChest is a global singleton, accessed via function call)
    // Taming: track tamed entities
    tamed_count: u8 = 0,
    copper_tick_timer: f32 = 0.0,
    copper_tick_count: u32 = 0,

    // Inventory screen (E key)
    inventory_open: bool = false,
    last_e_press: bool = false,
    hand_swing_timer: f32 = 0.0,
    cursor_item: inventory_mod.Slot = inventory_mod.Slot.empty,
    last_inv_click: bool = false,
    last_inv_right_click: bool = false,
    // 2x2 crafting grid (player inventory crafting)
    craft_grid: [4]inventory_mod.Slot = [_]inventory_mod.Slot{inventory_mod.Slot.empty} ** 4,
    // 3x3 crafting grid (crafting table)
    craft_grid_3x3: crafting_grid_mod.CraftingGrid = crafting_grid_mod.CraftingGrid.init(),
    crafting_table_open: bool = false,

    const FurnaceEntry = struct {
        x: i32,
        y: i32,
        z: i32,
        state: furnace_mod.FurnaceState,
    };

    const ChunkKey = struct { x: i32, z: i32 };

    const BlockPos = struct { x: i32, y: i32, z: i32 };

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

        // Initialize mob manager (spawning handled by mob_spawner per-frame)
        const mob_manager = mob_mod.MobManager.init(allocator);

        // Initialize persistence
        const persistence = try persistence_mod.WorldPersistence.init(allocator, "default");

        // Initialize item drop manager
        const drop_manager = item_drop_mod.ItemDropManager.init(allocator);

        // Initialize crafting registry with default recipes
        var crafting_registry = crafting_mod.CraftingRegistry.init();
        try crafting_registry.registerDefaults(allocator);

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
            .mob_spawner = spawner_mod.MobSpawner.init(SEED),
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
            .stat_tracker = scoreboard_mod.StatTracker.init(),
            .active_tnt = .empty,
            .projectile_manager = projectiles_mod.ProjectileManager.init(),
            .world_rules = world_rules_mod.WorldRules.init(),
            .mining_progress = 0.0,
            .mining_target = null,
            .eating_progress = 0.0,
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
        self.active_tnt.deinit(self.allocator);
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
            if (!self.inventory_open) {
                self.camera.processMouseDelta(dx, dy);
            }

            // Keyboard movement (horizontal only — physics handles vertical)
            var forward_input: f32 = 0;
            var right_input: f32 = 0;

            // Skip movement when chat is open so typing doesn't move the player
            if (!self.chat_open and !self.inventory_open) {
                if (self.window.handle.getKey(.w) == .press) forward_input += 1;
                if (self.window.handle.getKey(.s) == .press) forward_input -= 1;
                if (self.window.handle.getKey(.d) == .press) right_input += 1;
                if (self.window.handle.getKey(.a) == .press) right_input -= 1;
            }

            // Death screen: press R to respawn, skip gameplay updates
            if (self.player_stats.is_dead) {
                if (self.window.handle.getKey(.r) == .press) {
                    self.player_stats = health_mod.PlayerStats.init();
                    const spawn = self.world_rules.getSpawnPoint();
                    self.player_x = @floatFromInt(spawn.x);
                    self.player_y = @floatFromInt(spawn.y);
                    self.player_z = @floatFromInt(spawn.z);
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
                if (new_mode == .creative) {
                    self.fillCreativeInventory();
                }
            }
            self.last_f1_press = f1_pressed;

            // F3 debug overlay toggle
            const f3_pressed = self.window.handle.getKey(.F3) == .press;
            if (f3_pressed and !self.last_f3_press) {
                self.show_debug = !self.show_debug;
            }
            self.last_f3_press = f3_pressed;

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
                if (self.chat_open) {
                    self.chat_open = false;
                } else if (self.inventory_open) {
                    self.inventory_open = false;
                    self.returnCursorAndCraftItems();
                    self.window.handle.setInputMode(.cursor, .disabled) catch {};
                    self.first_mouse = true;
                } else {
                    self.window.handle.setShouldClose(true);
                }
            }

            // Hotbar selection (number keys 1-9)
            const number_keys = [_]zglfw.Key{ .one, .two, .three, .four, .five, .six, .seven, .eight, .nine };
            for (number_keys, 0..) |key, i| {
                if (self.window.handle.getKey(key) == .press) {
                    self.selected_slot = @intCast(i);
                }
            }

            // Block interaction (left/right mouse click) — skip when inventory is open
            if (self.inventory_open) {
                self.handleInventoryClick();
            } else {
                self.handleBlockInteraction(dt);
            }

            // Portal key: P toggles between overworld and nether
            const p_pressed = self.window.handle.getKey(.p) == .press;
            if (p_pressed and !self.last_p_press) {
                self.switchDimension();
                self.last_p_press = p_pressed;
                self.renderFrame(dt);
                continue;
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

            // Inventory screen toggle: E key
            const e_pressed = self.window.handle.getKey(.e) == .press;
            if (e_pressed and !self.last_e_press and !self.chat_open) {
                self.inventory_open = !self.inventory_open;
                if (self.inventory_open) {
                    self.window.handle.setInputMode(.cursor, .normal) catch {};
                } else {
                    self.returnCursorAndCraftItems();
                    self.window.handle.setInputMode(.cursor, .disabled) catch {};
                    self.first_mouse = true;
                }
            }
            self.last_e_press = e_pressed;

            // Advancement tracking: dimension, eating, breeding
            if (self.current_dimension == .nether) {
                self.advancements.checkCriteria(.enter_dimension, 1);
            } else if (self.current_dimension == .the_end) {
                self.advancements.checkCriteria(.enter_dimension, 2);
            }

            // Taming: right-click passive mob with bone (wolf) — one-shot per click
            const right_now = self.window.handle.getMouseButton(.right) == .press;
            if (right_now and !self.last_right_click and !self.chat_open and !self.inventory_open) {
                const held = self.inventory.getSlot(self.selected_slot).item;
                for (self.mob_manager.entities.items) |*mob| {
                    if (!mob.alive or mob.entity_type.isHostile()) continue;
                    const mdist = mob.distanceToPoint(self.player_x, self.player_y, self.player_z);
                    if (mdist < 3.0) {
                        // Wolves tamed with bone (item 201)
                        if (held == 201) {
                            var tstate = taming_mod.TamingState.init(.wolf);
                            if (tstate.attemptTame(held, 0)) {
                                self.tamed_count += 1;
                                self.advancements.checkCriteria(.tame_animal, 0);
                                std.debug.print("[Taming] Wolf tamed! Total: {}\n", .{self.tamed_count});
                                _ = self.inventory.removeItem(self.selected_slot, 1);
                            }
                        }
                        break;
                    }
                }
            }

            // Copper oxidation tick (random chance per frame)
            self.tickCopperOxidation();

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
            if (self.on_ground and !was_on_ground and pre_land_vy < -10.0) {
                const fall_damage = @abs(pre_land_vy) - 10.0;
                self.applyDamageWithArmor(fall_damage);
            }

            // Contact damage from environmental hazards (lava, fire, cactus)
            if (self.gamemode.takesBlockDamage()) {
                const feet_block = self.getWorldBlock(
                    @intFromFloat(@floor(self.player_x)),
                    @intFromFloat(@floor(self.player_y)),
                    @intFromFloat(@floor(self.player_z)),
                );
                if (feet_block) |bid| {
                    const contact_dmg = hazards_mod.getContactDamage(bid);
                    if (contact_dmg > 0) {
                        self.player_stats.takeDamage(contact_dmg * dt);
                        self.stat_tracker.increment(.damage_taken, 1);
                    }
                }
            }

            // World border damage: hurt player when outside the border
            if (self.gamemode.takesBlockDamage() and self.world_rules.isOutsideBorder(self.player_x, self.player_z)) {
                const border_dmg = self.world_rules.getBorderDamage(self.player_x, self.player_z) * dt;
                self.player_stats.takeDamage(border_dmg);
                self.stat_tracker.increment(.damage_taken, 1);
            }

            // Update active TNT fuses; explode when fuse expires
            self.updateActiveTNT(dt);

            // Update health/hunger
            self.player_stats.update(dt);

            // Update mob AI and remove dead entities
            PathfindingBridge.engine_ctx = self;
            pathfinding_mod.WalkabilityBridge.isWalkableFn = &PathfindingBridge.isWalkable;
            self.mob_manager.update(self.player_x, self.player_y, self.player_z, dt);
            pathfinding_mod.WalkabilityBridge.isWalkableFn = null;
            PathfindingBridge.engine_ctx = null;

            // Per-frame mob spawning via spawner
            if (self.mob_spawner.update(dt)) {
                const is_night = self.game_time.getPhase() == .night;
                const mob_count: u32 = @intCast(self.mob_manager.count());
                const attempts = self.mob_spawner.getSpawnAttempts(
                    self.player_x,
                    self.player_z,
                    is_night,
                    mob_count,
                    mob_count,
                );
                for (attempts) |maybe_attempt| {
                    if (maybe_attempt) |attempt| {
                        const etype: entity_mod.EntityType = @enumFromInt(attempt.entity_type);
                        self.mob_manager.spawn(etype, attempt.x, attempt.y, attempt.z) catch {};
                    }
                }
            }

            // Despawn mobs that are too far from the player
            for (self.mob_manager.entities.items) |*mob| {
                if (mob.alive and self.mob_spawner.shouldDespawn(mob.x, mob.z, self.player_x, self.player_z)) {
                    mob.alive = false;
                }
            }

            // Hostile mob melee attacks on the player
            if (self.gamemode.takesBlockDamage()) {
                for (self.mob_manager.entities.items) |*mob| {
                    if (!mob.alive) continue;
                    if (!mob.entity_type.isHostile()) continue;
                    const dist = mob.distanceToPoint(self.player_x, self.player_y, self.player_z);

                    // Skeleton ranged attack: shoot arrow every 2 seconds (per-mob timer)
                    if (mob.entity_type == .skeleton and dist < 16.0 and dist > 3.0) {
                        mob.shoot_timer += dt;
                        if (mob.shoot_timer >= 2.0) {
                            mob.shoot_timer = 0.0;
                            const sdx = self.player_x - mob.x;
                            const sdy = (self.player_y + PLAYER_EYE_HEIGHT) - (mob.y + 1.5);
                            const sdz = self.player_z - mob.z;
                            const slen = @sqrt(sdx * sdx + sdy * sdy + sdz * sdz);
                            if (slen > 0.01) {
                                _ = self.projectile_manager.spawn(
                                    .arrow,
                                    .{ mob.x, mob.y + 1.5, mob.z },
                                    .{ sdx / slen, sdy / slen, sdz / slen },
                                    20.0,
                                );
                            }
                        }
                    }

                    // Melee attack
                    if (dist < 2.0) {
                        const base_damage: f32 = switch (mob.entity_type) {
                            .zombie => 3.0,
                            .skeleton => 4.0,
                            .creeper => 0.0, // explodes instead (future)
                            else => 2.0,
                        };
                        const damage = base_damage * self.world_rules.getMobDamageMultiplier();
                        if (damage > 0) {
                            self.applyDamageWithArmor(damage);
                        }
                    }
                }
            }

            // Update projectile simulation
            self.projectile_manager.update(dt);

            // Arrow-player collision: check active projectiles against player
            if (self.gamemode.takesBlockDamage()) {
                for (&self.projectile_manager.pool) |*proj| {
                    if (!proj.active) continue;
                    const pdx = proj.x - self.player_x;
                    const pdy = proj.y - (self.player_y + 1.0);
                    const pdz = proj.z - self.player_z;
                    if (pdx * pdx + pdy * pdy + pdz * pdz < 1.0) {
                        self.applyDamageWithArmor(proj.damage);
                        proj.active = false;
                    }
                }
            }

            // Collect loot from newly dead mobs before removing them
            self.spawnMobLoot();
            // Count mobs that died this frame for scoreboard
            for (self.mob_manager.entities.items) |ent| {
                if (!ent.alive) self.stat_tracker.increment(.mobs_killed, 1);
            }
            self.mob_manager.removeDeadEntities();

            // Drowning damage
            const drown_dmg = self.water_state.updateOxygen(dt);
            if (drown_dmg > 0) {
                self.applyDamageWithArmor(drown_dmg);
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

            // Scoreboard: track distance walked/sprinted and play time
            self.stat_tracker.addDistance(move_x, move_z, self.movement.mode == .sprint);
            self.stat_tracker.addPlayTime(dt);

            // Copper oxidation random ticks (sample a few blocks per second)
            self.copper_tick_timer += dt;
            if (self.copper_tick_timer >= 1.0) {
                self.tickCopperOxidation();
                self.copper_tick_timer = 0.0;
            }

            // Update F3 debug info (only when overlay is visible)
            if (self.show_debug) {
                self.updateDebugInfo(dt);
            }

            // Periodic console status (every 5 seconds) — since no HUD rendering yet
            self.status_timer += dt;
            if (self.status_timer >= 5.0) {
                self.status_timer = 0.0;
                const hearts = self.player_stats.getHealthHearts();
                const drumsticks = self.player_stats.getHungerDrumsticks();
                const mobs_alive = self.mob_manager.count();
                const chunks_loaded = self.chunks.count();
                std.debug.print(
                    \\[STATUS] Pos({d:.1},{d:.1},{d:.1}) HP:{}/10 Food:{}/10 Mobs:{} Chunks:{} Dim:{s} Time:{} Weather:{s} XP:Lv{}
                    \\
                , .{
                    self.player_x,                    self.player_y,
                    self.player_z,
                    hearts,
                    drumsticks,
                    mobs_alive,
                    chunks_loaded,
                    @as([]const u8, switch (self.current_dimension) {
                        .overworld => "OW",
                        .nether => "Nether",
                        .the_end => "End",
                    }),
                    self.game_time.tick,
                    @as([]const u8, if (self.weather.isRaining()) "Rain" else if (self.weather.isThundering()) "Thunder" else "Clear"),
                    self.xp.getLevel(),
                });
            }

            // Submit mob positions to renderer for entity drawing
            self.renderer.clearEntityDraws();
            for (self.mob_manager.entities.items) |mob| {
                if (!mob.alive) continue;
                const tex: u6 = switch (mob.entity_type) {
                    .zombie => 2, // green (grass top color)
                    .skeleton => 0, // gray (stone color)
                    .creeper => 10, // dark green (leaves)
                    .pig => 3, // grass side (pinkish)
                    .cow => 1, // brown (dirt)
                    .chicken => 6, // tan (sand)
                    .sheep => 5, // light (planks)
                    else => 4, // gray (cobblestone)
                };
                self.renderer.submitEntityDraw(.{
                    .x = mob.x,
                    .y = mob.y,
                    .z = mob.z,
                    .width = mob.width,
                    .height = mob.height,
                    .tex = tex,
                });
            }

            // Submit active particles to renderer
            self.renderer.clearParticleDraws();
            for (&self.particle_manager.particles) |*p| {
                if (p.active) {
                    self.renderer.submitParticleDraw(.{
                        .x = p.x,
                        .y = p.y,
                        .z = p.z,
                        .r = p.r,
                        .g = p.g,
                        .b = p.b,
                        .size = p.size,
                    });
                }
            }

            // Submit projectile positions as small entities
            for (&self.projectile_manager.pool) |*proj| {
                if (proj.active) {
                    self.renderer.submitEntityDraw(.{
                        .x = proj.x,
                        .y = proj.y,
                        .z = proj.z,
                        .width = 0.3,
                        .height = 0.3,
                        .tex = 8, // log color (brown) for arrows
                    });
                }
            }

            // Submit item drops as small colored cubes on the ground
            for (self.drop_manager.drops.items) |drop| {
                if (drop.active) {
                    const dc = block.getBlockColor(@intCast(@min(drop.item_id, 119)));
                    self.renderer.submitParticleDraw(.{
                        .x = drop.x,
                        .y = drop.y,
                        .z = drop.z,
                        .r = dc[0],
                        .g = dc[1],
                        .b = dc[2],
                        .size = 0.35,
                    });
                }
            }

            self.renderFrame(dt);
        }

        self.renderer.waitIdle();
    }

    /// Fill all 36 inventory slots with one of each block type (creative mode).
    /// Cycles through all solid, placeable block IDs.
    fn fillCreativeInventory(self: *Engine) void {
        const total_blocks = block.BLOCKS.len;
        var slot_idx: u8 = 0;
        var block_idx: usize = 1; // skip AIR (0)
        while (slot_idx < inventory_mod.SLOT_COUNT and block_idx < total_blocks) {
            self.inventory.slots[slot_idx] = .{
                .item = @intCast(block_idx),
                .count = 64,
            };
            slot_idx += 1;
            block_idx += 1;
        }
    }

    /// Tick copper oxidation: for each loaded chunk section, sample a small number
    /// of random block positions and advance copper blocks probabilistically.
    fn tickCopperOxidation(self: *Engine) void {
        self.copper_tick_count +%= 1;
        const tick = self.copper_tick_count;
        const SAMPLES_PER_SECTION: u32 = 3;

        var iter = self.chunks.iterator();
        while (iter.next()) |entry| {
            const col = entry.value_ptr;
            const cx = entry.key_ptr.x;
            const cz = entry.key_ptr.z;
            for (0..ChunkColumn.SECTIONS) |si| {
                const section = col.getSection(@intCast(si)) orelse continue;
                // Sample a few pseudo-random positions per section per tick
                for (0..SAMPLES_PER_SECTION) |sample| {
                    const seed = tick *% 1664525 +% @as(u32, @intCast(sample)) *% 1013904223 +%
                        @as(u32, @bitCast(cx *% 73856093 +% cz *% 19349663 +%
                        @as(i32, @intCast(si)) *% 83492791));
                    const lx: u4 = @truncate(seed);
                    const ly: u4 = @truncate(seed >> 4);
                    const lz: u4 = @truncate(seed >> 8);

                    const bid = section.getBlock(lx, ly, lz);
                    if (copper_mod.getNextStage(bid)) |next_bid| {
                        const wx = cx * @as(i32, Chunk.SIZE) + @as(i32, lx);
                        const wy = @as(i32, @intCast(si * Chunk.SIZE)) + @as(i32, ly);
                        const wz = cz * @as(i32, Chunk.SIZE) + @as(i32, lz);
                        _ = self.setWorldBlock(wx, wy, wz, next_bid);
                    }
                }
            }
        }
    }

    /// Update the F3 debug info struct with current frame data.
    fn updateDebugInfo(self: *Engine, dt: f32) void {
        const size_i32: i32 = @intCast(Chunk.SIZE);
        const fps = if (dt > 0.0) 1.0 / dt else 0.0;

        self.debug_info = .{
            .fps = fps,
            .frame_time_ms = dt * 1000.0,
            .player_x = self.player_x,
            .player_y = self.player_y,
            .player_z = self.player_z,
            .chunk_x = @divFloor(@as(i32, @intFromFloat(@floor(self.player_x))), size_i32),
            .chunk_z = @divFloor(@as(i32, @intFromFloat(@floor(self.player_z))), size_i32),
            .loaded_chunks = self.chunks.count(),
            .entity_count = @intCast(self.mob_manager.count()),
            .dimension = switch (self.current_dimension) {
                .overworld => "overworld",
                .nether => "the_nether",
                .the_end => "the_end",
            },
            .biome = "plains",
            .facing_direction = getFacingDirection(self.camera.yaw),
        };
    }

    /// Apply damage to the player after armor reduction, and record it on the
    /// stat tracker.  No-ops when the current game mode is immune to damage.
    fn applyDamageWithArmor(self: *Engine, raw_damage: f32) void {
        if (!self.gamemode.takesBlockDamage()) return;
        const reduced = self.armor.getDamageReduction(raw_damage);
        self.player_stats.takeDamage(raw_damage - reduced);
        self.stat_tracker.increment(.damage_taken, 1);
    }

    /// Spawn item drops for any mobs that have just died (alive == false).
    /// Called before removeDeadEntities so the corpses are still in the list.
    fn spawnMobLoot(self: *Engine) void {
        for (self.mob_manager.entities.items) |*mob| {
            if (mob.alive) continue;

            const loot = loot_mod.getMobLoot(@intFromEnum(mob.entity_type));
            const result = loot_mod.rollLoot(loot, 0, @intCast(self.game_time.tick));
            for (0..result.item_count) |i| {
                if (result.items[i]) |item| {
                    self.drop_manager.spawnDrop(mob.x, mob.y, mob.z, item.id, item.count) catch {};
                }
            }

            if (result.xp > 0) self.xp.addXP(result.xp);
        }
    }

    fn switchDimension(self: *Engine) void {
        std.debug.print("[Dimension] Switching from {s}...\n", .{
            @as([]const u8, switch (self.current_dimension) {
                .overworld => "Overworld",
                .nether => "Nether",
                .the_end => "End",
            }),
        });

        if (self.current_dimension == .overworld) {
            self.overworld_player_pos = .{
                .x = self.player_x,
                .y = self.player_y,
                .z = self.player_z,
            };
            self.current_dimension = .nether;
            self.player_x /= 8.0;
            self.player_z /= 8.0;
            self.player_y = 70.0;
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

        // Wait for ALL GPU work to finish before destroying any buffers
        self.renderer.waitIdle();

        // Clear all rendered chunks (GPU resources are safe to free now)
        self.renderer.clearChunks();

        // Clear the chunk HashMap — just clear, don't free the HashMap itself
        self.chunks.clearRetainingCapacity();

        // Reset chunk loader's loaded set
        self.chunk_loader.loaded.clearRetainingCapacity();

        std.debug.print("[Dimension] Now in {s}. Chunks will load next frame.\n", .{
            @as([]const u8, switch (self.current_dimension) {
                .overworld => "Overworld",
                .nether => "Nether",
                .the_end => "End",
            }),
        });
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

        // Biome sky tinting (uses biome_features_mod)
        const biome_tint = biome_features_mod.getSkyTint(0); // default biome for now
        sky_color[0] = sky_color[0] * 0.8 + biome_tint[0] * 0.2;
        sky_color[1] = sky_color[1] * 0.8 + biome_tint[1] * 0.2;
        sky_color[2] = sky_color[2] * 0.8 + biome_tint[2] * 0.2;

        // Pass HUD data to renderer for shader-based overlay
        self.renderer.hud_health = @as(f32, @floatFromInt(self.player_stats.getHealthHearts())) / 10.0;
        self.renderer.hud_hunger = @as(f32, @floatFromInt(self.player_stats.getHungerDrumsticks())) / 10.0;
        self.renderer.hud_selected_slot = @floatFromInt(self.selected_slot);

        // Generate and upload UI overlay vertices
        self.generateAndUploadUi();

        self.renderer.drawFrame(vp_arr, sky_color, fog_color) catch |err| {
            std.debug.print("Render error: {}\n", .{err});
        };
    }

    fn generateAndUploadUi(self: *Engine) void {
        const V = ui_pipeline_mod.UiVertex;
        var verts: [8192]V = undefined;
        var count: u32 = 0;

        const sw: f32 = @floatFromInt(self.renderer.swapchain_extent.width);
        const sh: f32 = @floatFromInt(self.renderer.swapchain_extent.height);
        const cx = sw / 2.0;
        const cy = sh / 2.0;

        // === CROSSHAIR (thin white cross with dark outline) ===
        const ch_len: f32 = 10.0;
        const ch_thick: f32 = 1.5;
        // Dark outline
        count = addQuad(&verts, count, cx - ch_len - 1, cy - ch_thick - 1, ch_len * 2 + 2, ch_thick * 2 + 2, 0, 0, 0, 0.5);
        count = addQuad(&verts, count, cx - ch_thick - 1, cy - ch_len - 1, ch_thick * 2 + 2, ch_len * 2 + 2, 0, 0, 0, 0.5);
        // White center
        count = addQuad(&verts, count, cx - ch_len, cy - ch_thick / 2, ch_len * 2, ch_thick, 1, 1, 1, 0.9);
        count = addQuad(&verts, count, cx - ch_thick / 2, cy - ch_len, ch_thick, ch_len * 2, 1, 1, 1, 0.9);

        // === HEALTH (individual heart squares) ===
        const hearts_y: f32 = sh - 80.0;
        const hearts_x: f32 = sw / 2.0 - 100.0;
        const heart_size: f32 = 9.0;
        const heart_gap: f32 = 2.0;
        const total_hearts: u32 = 10;
        const filled_hearts: u32 = self.player_stats.getHealthHearts();
        var hi: u32 = 0;
        while (hi < total_hearts) : (hi += 1) {
            const hx = hearts_x + @as(f32, @floatFromInt(hi)) * (heart_size + heart_gap);
            // Heart background (dark)
            count = addQuad(&verts, count, hx, hearts_y, heart_size, heart_size, 0.2, 0.0, 0.0, 0.7);
            // Filled heart (red)
            if (hi < filled_hearts) {
                count = addQuad(&verts, count, hx + 1, hearts_y + 1, heart_size - 2, heart_size - 2, 0.9, 0.15, 0.15, 1.0);
            }
        }

        // === HUNGER (individual drumstick squares) ===
        const hunger_y: f32 = sh - 80.0;
        const hunger_x: f32 = sw / 2.0 + 2.0;
        const total_drumsticks: u32 = 10;
        const filled_drumsticks: u32 = self.player_stats.getHungerDrumsticks();
        var di: u32 = 0;
        while (di < total_drumsticks) : (di += 1) {
            const dx = hunger_x + @as(f32, @floatFromInt(di)) * (heart_size + heart_gap);
            // Background (dark)
            count = addQuad(&verts, count, dx, hunger_y, heart_size, heart_size, 0.1, 0.08, 0.0, 0.7);
            // Filled (golden brown)
            if (di < filled_drumsticks) {
                count = addQuad(&verts, count, dx + 1, hunger_y + 1, heart_size - 2, heart_size - 2, 0.75, 0.5, 0.1, 1.0);
            }
        }

        // === XP BAR (green, centered above hotbar) ===
        const xp_progress = self.xp.getProgress();
        const xp_bar_w: f32 = 182.0;
        const xp_bar_h: f32 = 5.0;
        const xp_bar_x = (sw - xp_bar_w) / 2.0;
        const xp_bar_y = sh - 56.0;
        // Background
        count = addQuad(&verts, count, xp_bar_x, xp_bar_y, xp_bar_w, xp_bar_h, 0.0, 0.1, 0.0, 0.6);
        // Filled (bright green)
        if (xp_progress > 0.001) {
            count = addQuad(&verts, count, xp_bar_x, xp_bar_y, xp_bar_w * xp_progress, xp_bar_h, 0.3, 0.9, 0.1, 0.9);
        }

        // === HOTBAR (bottom-center, Minecraft-style) ===
        const slot_size: f32 = 36.0;
        const slot_gap: f32 = 3.0;
        const hotbar_total = 9.0 * slot_size + 8.0 * slot_gap;
        const hotbar_x = (sw - hotbar_total) / 2.0;
        const hotbar_y: f32 = sh - 42.0;
        // Hotbar background
        count = addQuad(&verts, count, hotbar_x - 4, hotbar_y - 4, hotbar_total + 8, slot_size + 8, 0.1, 0.1, 0.1, 0.75);
        var slot_i: u32 = 0;
        while (slot_i < 9) : (slot_i += 1) {
            const sx = hotbar_x + @as(f32, @floatFromInt(slot_i)) * (slot_size + slot_gap);
            if (slot_i == self.selected_slot) {
                // Selected: bright border
                count = addQuad(&verts, count, sx - 2, hotbar_y - 2, slot_size + 4, slot_size + 4, 0.9, 0.9, 0.9, 0.95);
            }
            // Slot interior
            count = addQuad(&verts, count, sx, hotbar_y, slot_size, slot_size, 0.2, 0.2, 0.2, 0.9);
            // Item color indicator (if slot has item)
            const slot = self.inventory.getSlot(@intCast(slot_i));
            if (!slot.isEmpty()) {
                const tex_idx: u16 = @intCast(@min(slot.item, 119));
                const uv0 = texture_atlas_mod.getUV(tex_idx, 3);
                const uv1 = texture_atlas_mod.getUV(tex_idx, 1);
                count = addTexQuad(&verts, count, sx + 4, hotbar_y + 4, slot_size - 8, slot_size - 8, 1, 1, 1, 1, uv0[0], uv0[1], uv1[0], uv1[1]);
                if (slot.count > 1) {
                    count = drawNumberShadowed(&verts, count, sx + slot_size - 14, hotbar_y + slot_size - 10, slot.count, 2.0, 1, 1, 1);
                }
            }
        }

        // === CHAT OVERLAY ===
        if (self.chat_open) {
            count = addQuad(&verts, count, 10, sh - 34, sw - 20, 28, 0.0, 0.0, 0.0, 0.75);
            const cursor_x: f32 = 16.0 + @as(f32, @floatFromInt(self.command_len)) * 7.0;
            count = addQuad(&verts, count, cursor_x, sh - 30, 2, 20, 1, 1, 1, 1);
            count = addQuad(&verts, count, 12, sh - 30, 4, 20, 0.6, 0.9, 0.6, 1);
        }

        // === DEATH OVERLAY ===
        if (self.player_stats.is_dead) {
            count = addQuad(&verts, count, 0, 0, sw, sh, 0.5, 0.0, 0.0, 0.6);
            count = addQuad(&verts, count, cx - 80, cy - 15, 160, 30, 0.15, 0.0, 0.0, 0.9);
            // "R to respawn" indicator bar
            count = addQuad(&verts, count, cx - 50, cy + 20, 100, 4, 0.8, 0.8, 0.8, 0.7);
        }

        // === FIRST-PERSON HAND (bottom-right) with swing animation ===
        if (!self.inventory_open) {
            // Update swing timer
            const left_click = self.window.handle.getMouseButton(.left) == .press;
            if (left_click and self.hand_swing_timer <= 0) {
                self.hand_swing_timer = 0.3; // 0.3s swing duration
            }
            if (self.hand_swing_timer > 0) {
                self.hand_swing_timer -= @as(f32, @floatCast(zglfw.getTime() - self.last_time + 0.001));
                if (self.hand_swing_timer < 0) self.hand_swing_timer = 0;
            }

            // Swing offset: arc from rest → up-left → back to rest
            const swing_t = if (self.hand_swing_timer > 0)
                (0.3 - self.hand_swing_timer) / 0.3
            else
                @as(f32, 0);
            const swing_phase = @sin(swing_t * std.math.pi);
            const swing_dx = -swing_phase * 40.0; // swing left
            const swing_dy = -swing_phase * 50.0; // swing up

            const base_x = sw - 100.0;
            const base_y = sh - 140.0;
            const hand_x = base_x + swing_dx;
            const hand_y = base_y + swing_dy;
            const held_slot = self.inventory.getSlot(self.selected_slot);

            // Arm (skin-colored, slightly angled during swing)
            count = addQuad(&verts, count, hand_x + 18, hand_y + 45, 34, 90, 0.76, 0.57, 0.43, 1.0);
            // Arm shadow (right edge)
            count = addQuad(&verts, count, hand_x + 48, hand_y + 45, 4, 90, 0.60, 0.42, 0.30, 0.8);
            // Arm highlight (left edge)
            count = addQuad(&verts, count, hand_x + 18, hand_y + 45, 4, 90, 0.88, 0.70, 0.56, 0.7);
            // Wrist band
            count = addQuad(&verts, count, hand_x + 18, hand_y + 42, 34, 4, 0.65, 0.45, 0.30, 0.9);

            if (!held_slot.isEmpty()) {
                const bc = block.getBlockColor(@intCast(@min(held_slot.item, 119)));
                // Top face (lighter — isometric look)
                count = addQuad(&verts, count, hand_x, hand_y, 55, 22, @min(bc[0] * 1.3, 1.0), @min(bc[1] * 1.3, 1.0), @min(bc[2] * 1.3, 1.0), 1.0);
                // Front face
                count = addQuad(&verts, count, hand_x, hand_y + 22, 55, 28, bc[0], bc[1], bc[2], 1.0);
                // Right face (darker)
                count = addQuad(&verts, count, hand_x + 55, hand_y + 6, 16, 44, bc[0] * 0.65, bc[1] * 0.65, bc[2] * 0.65, 1.0);
                // Top-right edge highlight
                count = addQuad(&verts, count, hand_x, hand_y - 1, 72, 1, 0, 0, 0, 0.35);
                count = addQuad(&verts, count, hand_x - 1, hand_y, 1, 50, 0, 0, 0, 0.25);
            } else {
                // Empty hand — fist with fingers
                count = addQuad(&verts, count, hand_x + 14, hand_y + 22, 42, 28, 0.82, 0.62, 0.47, 1.0);
                // Thumb
                count = addQuad(&verts, count, hand_x + 10, hand_y + 28, 8, 18, 0.80, 0.60, 0.44, 1.0);
                // Fingers (4 knuckles)
                count = addQuad(&verts, count, hand_x + 14, hand_y + 10, 10, 16, 0.78, 0.58, 0.42, 1.0);
                count = addQuad(&verts, count, hand_x + 25, hand_y + 8, 10, 18, 0.78, 0.58, 0.42, 1.0);
                count = addQuad(&verts, count, hand_x + 36, hand_y + 10, 10, 16, 0.78, 0.58, 0.42, 1.0);
                count = addQuad(&verts, count, hand_x + 47, hand_y + 14, 9, 12, 0.76, 0.56, 0.40, 1.0);
                // Finger gaps (dark lines between knuckles)
                count = addQuad(&verts, count, hand_x + 24, hand_y + 10, 1, 14, 0.55, 0.38, 0.25, 0.6);
                count = addQuad(&verts, count, hand_x + 35, hand_y + 10, 1, 14, 0.55, 0.38, 0.25, 0.6);
                count = addQuad(&verts, count, hand_x + 46, hand_y + 14, 1, 10, 0.55, 0.38, 0.25, 0.6);
            }
        }

        // === INVENTORY SCREEN (E key) ===
        if (self.inventory_open) {
            const slot_s: f32 = 48.0;
            const slot_pad: f32 = 4.0;
            const inv_w: f32 = 9.0 * (slot_s + slot_pad) + 24.0;
            const inv_h: f32 = 500.0;
            const inv_x = (sw - inv_w) / 2.0;
            const inv_y = (sh - inv_h) / 2.0;

            // Darkened background overlay
            count = addQuad(&verts, count, 0, 0, sw, sh, 0, 0, 0, 0.6);

            // Panel border + background
            count = addQuad(&verts, count, inv_x - 4, inv_y - 4, inv_w + 8, inv_h + 8, 0.15, 0.15, 0.15, 0.98);
            count = addQuad(&verts, count, inv_x, inv_y, inv_w, inv_h, 0.55, 0.55, 0.55, 0.95);

            // Title bar
            count = addQuad(&verts, count, inv_x, inv_y, inv_w, 30, 0.40, 0.40, 0.40, 1.0);
            count = addQuad(&verts, count, inv_x + 10, inv_y + 10, 80, 10, 0.9, 0.9, 0.9, 0.6);

            // === Crafting grid — 3x3 if crafting table open, else 2x2 ===
            const craft_rows: u32 = if (self.crafting_table_open) 3 else 2;
            const craft_cols: u32 = if (self.crafting_table_open) 3 else 2;
            const craft_grid_w = @as(f32, @floatFromInt(craft_cols)) * (slot_s + slot_pad);
            const craft_x = inv_x + inv_w - craft_grid_w - 80;
            const craft_y = inv_y + 44;
            // Label bar
            count = addQuad(&verts, count, craft_x - 6, craft_y - 4, craft_grid_w + 12, 3, 0.7, 0.5, 0.2, 0.8);
            var cy_i: u32 = 0;
            while (cy_i < craft_rows) : (cy_i += 1) {
                var cx_i: u32 = 0;
                while (cx_i < craft_cols) : (cx_i += 1) {
                    const gx = craft_x + @as(f32, @floatFromInt(cx_i)) * (slot_s + slot_pad);
                    const gy = craft_y + @as(f32, @floatFromInt(cy_i)) * (slot_s + slot_pad);
                    count = addQuad(&verts, count, gx, gy, slot_s, slot_s, 0.30, 0.30, 0.30, 1.0);
                    count = addQuad(&verts, count, gx + 2, gy + 2, slot_s - 4, slot_s - 4, 0.42, 0.42, 0.42, 0.9);
                    // Render item in grid slot
                    if (self.crafting_table_open) {
                        const ci3 = cy_i * 3 + cx_i;
                        const slot3 = self.craft_grid_3x3.slots[ci3];
                        if (!slot3.isEmpty()) {
                            const tid3: u16 = @intCast(@min(slot3.item, 119));
                            const uv03 = texture_atlas_mod.getUV(tid3, 3);
                            const uv13 = texture_atlas_mod.getUV(tid3, 1);
                            count = addTexQuad(&verts, count, gx + 5, gy + 5, slot_s - 10, slot_s - 10, 1, 1, 1, 1, uv03[0], uv03[1], uv13[0], uv13[1]);
                            if (slot3.count > 1)
                                count = drawNumberShadowed(&verts, count, gx + slot_s - 16, gy + slot_s - 12, slot3.count, 2.0, 1, 1, 1);
                        }
                    } else {
                        const ci2 = cy_i * 2 + cx_i;
                        if (!self.craft_grid[ci2].isEmpty()) {
                            const tid2: u16 = @intCast(@min(self.craft_grid[ci2].item, 119));
                            const uv02 = texture_atlas_mod.getUV(tid2, 3);
                            const uv12 = texture_atlas_mod.getUV(tid2, 1);
                            count = addTexQuad(&verts, count, gx + 5, gy + 5, slot_s - 10, slot_s - 10, 1, 1, 1, 1, uv02[0], uv02[1], uv12[0], uv12[1]);
                        }
                    }
                }
            }
            // Crafting output slot
            const out_offset_x = craft_grid_w + 20;
            const out_offset_y = @as(f32, @floatFromInt(craft_rows)) * (slot_s + slot_pad) / 2.0 - slot_s / 2.0;
            const craft_result = self.getCraftResult();
            count = addQuad(&verts, count, craft_x + out_offset_x, craft_y + out_offset_y - 3, slot_s + 6, slot_s + 6, 0.25, 0.25, 0.25, 1.0);
            count = addQuad(&verts, count, craft_x + out_offset_x + 3, craft_y + out_offset_y, slot_s, slot_s, 0.45, 0.45, 0.45, 0.9);
            if (craft_result) |res| {
                const rtid: u16 = @intCast(@min(res.result_item, 119));
                const ruv0 = texture_atlas_mod.getUV(rtid, 3);
                const ruv1 = texture_atlas_mod.getUV(rtid, 1);
                count = addTexQuad(&verts, count, craft_x + out_offset_x + 8, craft_y + out_offset_y + 5, slot_s - 10, slot_s - 10, 1, 1, 1, 1, ruv0[0], ruv0[1], ruv1[0], ruv1[1]);
            }
            // Arrow between grid and output
            count = addQuad(&verts, count, craft_x + out_offset_x - 12, craft_y + out_offset_y + slot_s / 2.0 - 2, 10, 4, 0.8, 0.8, 0.8, 0.5);

            // === Armor slots (left column) ===
            const armor_x = inv_x + 14;
            const armor_y = inv_y + 44;
            const armor_icons = [4][3]f32{
                .{ 0.6, 0.6, 0.7 },
                .{ 0.5, 0.5, 0.6 },
                .{ 0.5, 0.5, 0.6 },
                .{ 0.4, 0.4, 0.5 },
            };
            var ai: u32 = 0;
            while (ai < 4) : (ai += 1) {
                const ay = armor_y + @as(f32, @floatFromInt(ai)) * (slot_s + slot_pad);
                count = addQuad(&verts, count, armor_x, ay, slot_s, slot_s, 0.30, 0.30, 0.30, 1.0);
                count = addQuad(&verts, count, armor_x + 2, ay + 2, slot_s - 4, slot_s - 4, 0.40, 0.40, 0.40, 0.9);
                count = addQuad(&verts, count, armor_x + 10, ay + 10, 20, 20, armor_icons[ai][0], armor_icons[ai][1], armor_icons[ai][2], 0.25);
            }

            // === Player model (center) ===
            const pcx = inv_x + 110;
            const pcy = inv_y + 48;
            count = addQuad(&verts, count, pcx + 18, pcy + 28, 24, 36, 0.25, 0.55, 0.25, 0.85);
            count = addQuad(&verts, count, pcx + 16, pcy, 28, 28, 0.76, 0.57, 0.43, 0.9);
            count = addQuad(&verts, count, pcx + 20, pcy + 12, 6, 5, 0.15, 0.15, 0.15, 0.9);
            count = addQuad(&verts, count, pcx + 34, pcy + 12, 6, 5, 0.15, 0.15, 0.15, 0.9);
            count = addQuad(&verts, count, pcx + 18, pcy + 64, 11, 28, 0.20, 0.20, 0.50, 0.85);
            count = addQuad(&verts, count, pcx + 31, pcy + 64, 11, 28, 0.20, 0.20, 0.50, 0.85);
            count = addQuad(&verts, count, pcx + 6, pcy + 30, 12, 30, 0.76, 0.57, 0.43, 0.8);
            count = addQuad(&verts, count, pcx + 42, pcy + 30, 12, 30, 0.76, 0.57, 0.43, 0.8);

            // === Main inventory (3 rows x 9 columns) ===
            const grid_x = inv_x + 12;
            const grid_y = inv_y + 240;
            var row: u32 = 0;
            while (row < 3) : (row += 1) {
                var col: u32 = 0;
                while (col < 9) : (col += 1) {
                    const sx = grid_x + @as(f32, @floatFromInt(col)) * (slot_s + slot_pad);
                    const sy = grid_y + @as(f32, @floatFromInt(row)) * (slot_s + slot_pad);
                    count = addQuad(&verts, count, sx, sy, slot_s, slot_s, 0.30, 0.30, 0.30, 1.0);
                    count = addQuad(&verts, count, sx + 2, sy + 2, slot_s - 4, slot_s - 4, 0.42, 0.42, 0.42, 0.9);
                    const slot_idx: u8 = @intCast(9 + row * 9 + col);
                    if (slot_idx < inventory_mod.SLOT_COUNT) {
                        const slot = self.inventory.getSlot(slot_idx);
                        if (!slot.isEmpty()) {
                            const itid: u16 = @intCast(@min(slot.item, 119));
                            const iuv0 = texture_atlas_mod.getUV(itid, 3);
                            const iuv1 = texture_atlas_mod.getUV(itid, 1);
                            count = addTexQuad(&verts, count, sx + 5, sy + 5, slot_s - 10, slot_s - 10, 1, 1, 1, 1, iuv0[0], iuv0[1], iuv1[0], iuv1[1]);
                            if (slot.count > 1) {
                                count = drawNumberShadowed(&verts, count, sx + slot_s - 16, sy + slot_s - 12, slot.count, 2.0, 1, 1, 1);
                            }
                        }
                    }
                }
            }

            // === Hotbar row ===
            const hb_y = grid_y + 3 * (slot_s + slot_pad) + 12;
            count = addQuad(&verts, count, grid_x, hb_y - 6, 9 * (slot_s + slot_pad) - slot_pad, 2, 0.3, 0.3, 0.3, 0.5);
            var hb_i: u32 = 0;
            while (hb_i < 9) : (hb_i += 1) {
                const hx = grid_x + @as(f32, @floatFromInt(hb_i)) * (slot_s + slot_pad);
                if (hb_i == self.selected_slot) {
                    count = addQuad(&verts, count, hx - 3, hb_y - 3, slot_s + 6, slot_s + 6, 0.9, 0.9, 0.9, 0.9);
                }
                count = addQuad(&verts, count, hx, hb_y, slot_s, slot_s, 0.30, 0.30, 0.30, 1.0);
                count = addQuad(&verts, count, hx + 2, hb_y + 2, slot_s - 4, slot_s - 4, 0.42, 0.42, 0.42, 0.9);
                const slot = self.inventory.getSlot(@intCast(hb_i));
                if (!slot.isEmpty()) {
                    const htid: u16 = @intCast(@min(slot.item, 119));
                    const huv0 = texture_atlas_mod.getUV(htid, 3);
                    const huv1 = texture_atlas_mod.getUV(htid, 1);
                    count = addTexQuad(&verts, count, hx + 5, hb_y + 5, slot_s - 10, slot_s - 10, 1, 1, 1, 1, huv0[0], huv0[1], huv1[0], huv1[1]);
                    if (slot.count > 1) {
                        count = drawNumberShadowed(&verts, count, hx + slot_s - 16, hb_y + slot_s - 12, slot.count, 2.0, 1, 1, 1);
                    }
                }
            }

            // === Cursor item follows OS cursor (if holding an item) ===
            if (!self.cursor_item.isEmpty()) {
                const cur = self.window.handle.getCursorPos();
                const scale = self.window.handle.getContentScale();
                const cmx: f32 = @as(f32, @floatCast(cur[0])) * scale[0];
                const cmy: f32 = @as(f32, @floatCast(cur[1])) * scale[1];
                const ctid: u16 = @intCast(@min(self.cursor_item.item, 119));
                const cuv0x = texture_atlas_mod.getUV(ctid, 3);
                const cuv1x = texture_atlas_mod.getUV(ctid, 1);
                count = addTexQuad(&verts, count, cmx + 10, cmy + 10, 28, 28, 1, 1, 1, 0.9, cuv0x[0], cuv0x[1], cuv1x[0], cuv1x[1]);
                count = addQuad(&verts, count, cmx + 10, cmy + 10, 28, 28, 0, 0, 0, 0.15);
            }
        }

        self.renderer.uploadUiVertices(verts[0..count]) catch {};
    }

    fn handleInventoryClick(self: *Engine) void {
        const left_pressed = self.window.handle.getMouseButton(.left) == .press;
        const right_pressed = self.window.handle.getMouseButton(.right) == .press;
        const left_just = left_pressed and !self.last_inv_click;
        const right_just = right_pressed and !self.last_inv_right_click;
        self.last_inv_click = left_pressed;
        self.last_inv_right_click = right_pressed;

        if (!left_just and !right_just) return;
        const is_right = right_just and !left_just;

        const cursor = self.window.handle.getCursorPos();
        const scale = self.window.handle.getContentScale();
        const mx: f32 = @as(f32, @floatCast(cursor[0])) * scale[0];
        const my: f32 = @as(f32, @floatCast(cursor[1])) * scale[1];

        const sw: f32 = @floatFromInt(self.renderer.swapchain_extent.width);
        const sh: f32 = @floatFromInt(self.renderer.swapchain_extent.height);
        const slot_s: f32 = 48.0;
        const slot_pad: f32 = 4.0;
        const inv_w: f32 = 9.0 * (slot_s + slot_pad) + 24.0;
        const inv_h: f32 = 500.0;
        const inv_x = (sw - inv_w) / 2.0;
        const inv_y = (sh - inv_h) / 2.0;
        const grid_x = inv_x + 12;
        const grid_y = inv_y + 240;

        // Check crafting grid clicks (2x2 or 3x3 depending on mode)
        const craft_rows: u32 = if (self.crafting_table_open) 3 else 2;
        const craft_cols: u32 = if (self.crafting_table_open) 3 else 2;
        const craft_grid_w = @as(f32, @floatFromInt(craft_cols)) * (slot_s + slot_pad);
        const craft_x = inv_x + inv_w - craft_grid_w - 80;
        const craft_y = inv_y + 44;
        var cri: u32 = 0;
        while (cri < craft_rows) : (cri += 1) {
            var cci: u32 = 0;
            while (cci < craft_cols) : (cci += 1) {
                const gx = craft_x + @as(f32, @floatFromInt(cci)) * (slot_s + slot_pad);
                const gy = craft_y + @as(f32, @floatFromInt(cri)) * (slot_s + slot_pad);
                if (mx >= gx and mx < gx + slot_s and my >= gy and my < gy + slot_s) {
                    if (self.crafting_table_open) {
                        const idx3 = @as(u8, @intCast(cri * 3 + cci));
                        if (is_right) {
                            self.cursor_item = self.craft_grid_3x3.rightClickSlot(idx3, self.cursor_item);
                        } else {
                            self.cursor_item = self.craft_grid_3x3.leftClickSlot(idx3, self.cursor_item);
                        }
                    } else {
                        const idx2 = @as(u8, @intCast(cri * 2 + cci));
                        if (is_right) {
                            self.placeOneIntoCraftSlot(idx2);
                        } else {
                            self.swapCursorWithCraftSlot(idx2);
                        }
                    }
                    return;
                }
            }
        }

        // Check crafting output slot click
        const out_offset_x = craft_grid_w + 20;
        const out_offset_y = @as(f32, @floatFromInt(craft_rows)) * (slot_s + slot_pad) / 2.0 - slot_s / 2.0;
        const out_x = craft_x + out_offset_x;
        const out_y = craft_y + out_offset_y;
        if (mx >= out_x and mx < out_x + slot_s + 6 and my >= out_y and my < out_y + slot_s + 6) {
            self.tryCraft();
            return;
        }

        // Check main inventory grid (3x9)
        var row: u32 = 0;
        while (row < 3) : (row += 1) {
            var col: u32 = 0;
            while (col < 9) : (col += 1) {
                const sx = grid_x + @as(f32, @floatFromInt(col)) * (slot_s + slot_pad);
                const sy = grid_y + @as(f32, @floatFromInt(row)) * (slot_s + slot_pad);
                if (mx >= sx and mx < sx + slot_s and my >= sy and my < sy + slot_s) {
                    const idx: u8 = @intCast(9 + row * 9 + col);
                    if (is_right) {
                        self.placeOneIntoSlot(idx);
                    } else {
                        self.swapCursorWithSlot(idx);
                    }
                    return;
                }
            }
        }

        // Check hotbar row
        const hb_y = grid_y + 3 * (slot_s + slot_pad) + 12;
        var hb_i: u32 = 0;
        while (hb_i < 9) : (hb_i += 1) {
            const hx = grid_x + @as(f32, @floatFromInt(hb_i)) * (slot_s + slot_pad);
            if (mx >= hx and mx < hx + slot_s and my >= hb_y and my < hb_y + slot_s) {
                if (is_right) {
                    self.placeOneIntoSlot(@intCast(hb_i));
                } else {
                    self.swapCursorWithSlot(@intCast(hb_i));
                }
                return;
            }
        }
    }

    fn swapCursorWithSlot(self: *Engine, slot_idx: u8) void {
        if (slot_idx >= inventory_mod.SLOT_COUNT) return;
        const slot_val = self.inventory.getSlot(slot_idx);

        if (!self.cursor_item.isEmpty() and !slot_val.isEmpty() and self.cursor_item.item == slot_val.item) {
            const space = inventory_mod.STACK_MAX - slot_val.count;
            if (space > 0) {
                const to_add = @min(space, self.cursor_item.count);
                self.inventory.slots[slot_idx].count += to_add;
                self.cursor_item.count -= to_add;
                if (self.cursor_item.count == 0) self.cursor_item = inventory_mod.Slot.empty;
                return;
            }
            // Both full stacks of same type — swap (no-op but consistent)
        }

        self.inventory.slots[slot_idx] = self.cursor_item;
        self.cursor_item = slot_val;
    }

    fn swapCursorWithCraftSlot(self: *Engine, craft_idx: u8) void {
        if (craft_idx >= 4) return;
        const slot_val = self.craft_grid[craft_idx];

        if (!self.cursor_item.isEmpty() and !slot_val.isEmpty() and self.cursor_item.item == slot_val.item) {
            const space = inventory_mod.STACK_MAX - slot_val.count;
            if (space > 0) {
                const to_add = @min(space, self.cursor_item.count);
                self.craft_grid[craft_idx].count += to_add;
                self.cursor_item.count -= to_add;
                if (self.cursor_item.count == 0) self.cursor_item = inventory_mod.Slot.empty;
                return;
            }
        }

        self.craft_grid[craft_idx] = self.cursor_item;
        self.cursor_item = slot_val;
    }

    fn getCraftResult(self: *const Engine) ?crafting_mod.Recipe {
        if (self.crafting_table_open) {
            const grid = self.craft_grid_3x3.getRecipeGrid();
            // Try old registry first
            if (self.crafting_registry.findMatch(grid)) |r| return r;
            // Try all new recipe modules — convert ShapedRecipe to crafting.Recipe inline
            if (findInRecipeSet(grid, &recipes_tools.recipes)) |r| return r;
            if (findInRecipeSet(grid, &recipes_armor.recipes)) |r| return r;
            if (findInRecipeSet(grid, &recipes_redstone.recipes)) |r| return r;
            if (findInRecipeSet(grid, &recipes_decorative.recipes)) |r| return r;
            if (findInRecipeSet(grid, &recipes_transport.recipes)) |r| return r;
            if (findInRecipeSet(grid, &recipes_food.recipes)) |r| return r;
            return null;
        }
        // 2x2 mode
        const g = self.craft_grid;
        const grid: [3][3]crafting_mod.ItemId = .{
            .{ if (g[0].count > 0) g[0].item else 0, if (g[1].count > 0) g[1].item else 0, 0 },
            .{ if (g[2].count > 0) g[2].item else 0, if (g[3].count > 0) g[3].item else 0, 0 },
            .{ 0, 0, 0 },
        };
        return self.crafting_registry.findMatch(grid);
    }

    fn findInRecipeSet(grid: [3][3]u16, recipes: anytype) ?crafting_mod.Recipe {
        const normalized = recipe_matching_mod.normalizeGrid(grid);
        const mirrored = recipe_matching_mod.mirrorGrid(normalized);
        for (recipes) |recipe| {
            const rn = recipe_matching_mod.normalizeGrid(recipe.pattern);
            if (gridsEqual(normalized, rn) or gridsEqual(mirrored, rn))
                return .{ .pattern = recipe.pattern, .result_item = recipe.result_item, .result_count = recipe.result_count };
        }
        return null;
    }

    fn gridsEqual(a: [3][3]u16, b: [3][3]u16) bool {
        for (0..3) |r| for (0..3) |c| {
            if (a[r][c] != b[r][c]) return false;
        };
        return true;
    }

    fn tryCraft(self: *Engine) void {
        const result = self.getCraftResult() orelse return;
        if (self.crafting_table_open) {
            // Consume from 3x3 grid
            self.craft_grid_3x3.consumeForPattern(result.pattern);
        } else {
            // Consume from 2x2 grid
            const pattern = result.pattern;
            const slot_map = [4][2]usize{ .{ 0, 0 }, .{ 0, 1 }, .{ 1, 0 }, .{ 1, 1 } };
            for (slot_map, 0..) |rc, i| {
                if (pattern[rc[0]][rc[1]] != 0) {
                    if (!self.craft_grid[i].isEmpty()) {
                        self.craft_grid[i].count -= 1;
                        if (self.craft_grid[i].count == 0) self.craft_grid[i] = inventory_mod.Slot.empty;
                    }
                }
            }
        }
        if (self.cursor_item.isEmpty()) {
            self.cursor_item = .{ .item = result.result_item, .count = result.result_count };
        } else if (self.cursor_item.item == result.result_item and
            self.cursor_item.count + result.result_count <= 64)
        {
            self.cursor_item.count += result.result_count;
        } else {
            _ = self.inventory.addItem(result.result_item, result.result_count);
        }
    }

    fn returnCursorAndCraftItems(self: *Engine) void {
        if (!self.cursor_item.isEmpty()) {
            _ = self.inventory.addItem(self.cursor_item.item, self.cursor_item.count);
            self.cursor_item = inventory_mod.Slot.empty;
        }
        for (&self.craft_grid) |*slot| {
            if (!slot.isEmpty()) {
                _ = self.inventory.addItem(slot.item, slot.count);
                slot.* = inventory_mod.Slot.empty;
            }
        }
        self.craft_grid_3x3.returnAllToInventory(&self.inventory.slots);
        self.crafting_table_open = false;
    }

    fn placeOneIntoSlot(self: *Engine, slot_idx: u8) void {
        if (self.cursor_item.isEmpty()) return;
        if (slot_idx >= inventory_mod.SLOT_COUNT) return;
        const slot = &self.inventory.slots[slot_idx];
        if (slot.isEmpty()) {
            slot.item = self.cursor_item.item;
            slot.count = 1;
        } else if (slot.item == self.cursor_item.item and slot.count < inventory_mod.STACK_MAX) {
            slot.count += 1;
        } else {
            return;
        }
        self.cursor_item.count -= 1;
        if (self.cursor_item.count == 0) self.cursor_item = inventory_mod.Slot.empty;
    }

    fn placeOneIntoCraftSlot(self: *Engine, craft_idx: u8) void {
        if (self.cursor_item.isEmpty()) return;
        if (craft_idx >= 4) return;
        const slot = &self.craft_grid[craft_idx];
        if (slot.isEmpty()) {
            slot.item = self.cursor_item.item;
            slot.count = 1;
        } else if (slot.item == self.cursor_item.item and slot.count < inventory_mod.STACK_MAX) {
            slot.count += 1;
        } else {
            return;
        }
        self.cursor_item.count -= 1;
        if (self.cursor_item.count == 0) self.cursor_item = inventory_mod.Slot.empty;
    }

    fn addQuad(verts: []ui_pipeline_mod.UiVertex, start: u32, x: f32, y: f32, w: f32, h: f32, r: f32, g: f32, b: f32, a: f32) u32 {
        if (start + 6 > verts.len) return start;
        const V = ui_pipeline_mod.UiVertex;
        verts[start + 0] = V{ .pos_x = x, .pos_y = y, .r = r, .g = g, .b = b, .a = a, .u = -1, .v = -1 };
        verts[start + 1] = V{ .pos_x = x + w, .pos_y = y, .r = r, .g = g, .b = b, .a = a, .u = -1, .v = -1 };
        verts[start + 2] = V{ .pos_x = x + w, .pos_y = y + h, .r = r, .g = g, .b = b, .a = a, .u = -1, .v = -1 };
        verts[start + 3] = V{ .pos_x = x, .pos_y = y, .r = r, .g = g, .b = b, .a = a, .u = -1, .v = -1 };
        verts[start + 4] = V{ .pos_x = x + w, .pos_y = y + h, .r = r, .g = g, .b = b, .a = a, .u = -1, .v = -1 };
        verts[start + 5] = V{ .pos_x = x, .pos_y = y + h, .r = r, .g = g, .b = b, .a = a, .u = -1, .v = -1 };
        return start + 6;
    }

    fn addTexQuad(verts: []ui_pipeline_mod.UiVertex, start: u32, x: f32, y: f32, w: f32, h: f32, r: f32, g: f32, b: f32, a: f32, uv_l: f32, uv_t: f32, uv_r: f32, uv_b: f32) u32 {
        if (start + 6 > verts.len) return start;
        const V = ui_pipeline_mod.UiVertex;
        verts[start + 0] = V{ .pos_x = x, .pos_y = y, .r = r, .g = g, .b = b, .a = a, .u = uv_l, .v = uv_t };
        verts[start + 1] = V{ .pos_x = x + w, .pos_y = y, .r = r, .g = g, .b = b, .a = a, .u = uv_r, .v = uv_t };
        verts[start + 2] = V{ .pos_x = x + w, .pos_y = y + h, .r = r, .g = g, .b = b, .a = a, .u = uv_r, .v = uv_b };
        verts[start + 3] = V{ .pos_x = x, .pos_y = y, .r = r, .g = g, .b = b, .a = a, .u = uv_l, .v = uv_t };
        verts[start + 4] = V{ .pos_x = x + w, .pos_y = y + h, .r = r, .g = g, .b = b, .a = a, .u = uv_r, .v = uv_b };
        verts[start + 5] = V{ .pos_x = x, .pos_y = y + h, .r = r, .g = g, .b = b, .a = a, .u = uv_l, .v = uv_b };
        return start + 6;
    }

    fn drawNumber(verts: []ui_pipeline_mod.UiVertex, start: u32, x: f32, y: f32, value: u32, scale: f32, r: f32, g: f32, b: f32, a: f32) u32 {
        var c = start;
        const num_digits = bitmap_font.digitCount(value);
        const char_w = @as(f32, @floatFromInt(bitmap_font.GLYPH_W)) * scale + scale;
        var di: u32 = 0;
        while (di < num_digits) : (di += 1) {
            const digit = bitmap_font.getDigit(value, num_digits - 1 - di);
            const dx = x + @as(f32, @floatFromInt(di)) * char_w;
            var py: u32 = 0;
            while (py < bitmap_font.GLYPH_H) : (py += 1) {
                var px_i: u32 = 0;
                while (px_i < bitmap_font.GLYPH_W) : (px_i += 1) {
                    if (bitmap_font.getPixel(digit, px_i, py)) {
                        c = addQuad(verts, c, dx + @as(f32, @floatFromInt(px_i)) * scale, y + @as(f32, @floatFromInt(py)) * scale, scale, scale, r, g, b, a);
                    }
                }
            }
        }
        // Drop shadow: draw same number offset by 1px in black (behind)
        return c;
    }

    fn drawNumberShadowed(verts: []ui_pipeline_mod.UiVertex, start: u32, x: f32, y: f32, value: u32, scale: f32, r: f32, g: f32, b: f32) u32 {
        var c = start;
        c = drawNumber(verts, c, x + 1, y + 1, value, scale, 0.1, 0.1, 0.1, 0.9);
        c = drawNumber(verts, c, x, y, value, scale, r, g, b, 1.0);
        return c;
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

    /// Block lookup wrapper for the explosion system.
    const ExplosionBridge = struct {
        var engine_ctx: ?*Engine = null;

        fn getBlock(x: i32, y: i32, z: i32) u8 {
            const eng = engine_ctx orelse return 0;
            return eng.getWorldBlock(x, y, z) orelse 0;
        }
    };

    /// Walkability wrapper for mob A* pathfinding.
    /// A position is walkable when:
    ///   - the block at (x, y, z) and (x, y+1, z) are not solid (room for feet+head)
    ///   - the block at (x, y-1, z) IS solid (ground to stand on)
    const PathfindingBridge = struct {
        var engine_ctx: ?*Engine = null;

        fn isWalkable(x: i32, y: i32, z: i32) bool {
            const eng = engine_ctx orelse return false;
            // Must have solid ground below.
            const ground = eng.getWorldBlock(x, y - 1, z) orelse return false;
            if (!block.isSolid(ground)) return false;
            // Feet and head blocks must be non-solid.
            const feet = eng.getWorldBlock(x, y, z) orelse return true;
            if (block.isSolid(feet)) return false;
            const head = eng.getWorldBlock(x, y + 1, z) orelse return true;
            if (block.isSolid(head)) return false;
            return true;
        }
    };

    /// Tick all active TNT fuses. When a fuse expires, run the explosion,
    /// destroy blocks in the world, apply damage to the player, and re-mesh
    /// affected chunks.
    fn updateActiveTNT(self: *Engine, dt: f32) void {
        ExplosionBridge.engine_ctx = self;
        defer ExplosionBridge.engine_ctx = null;

        var i: usize = 0;
        while (i < self.active_tnt.items.len) {
            if (self.active_tnt.items[i].update(dt)) {
                const tnt = self.active_tnt.items[i];

                // Compute explosion results
                var result = explosion_mod.explode(
                    tnt.x,
                    tnt.y,
                    tnt.z,
                    explosion_mod.tnt_radius,
                    explosion_mod.tnt_power,
                    &ExplosionBridge.getBlock,
                    &.{},
                    self.allocator,
                );
                defer result.deinit(self.allocator);

                // Destroy blocks in the world
                self.renderer.waitIdle();
                for (result.destroyed_blocks.items) |db| {
                    _ = self.setWorldBlock(db.x, db.y, db.z, block.AIR);
                }

                // Batch re-mesh: collect unique chunk keys, then remesh each once
                self.remeshExplosionArea(tnt.x, tnt.z, explosion_mod.tnt_radius);

                // Apply blast damage to the player
                if (self.gamemode.takesBlockDamage()) {
                    const dx = self.player_x - tnt.x;
                    const dy = self.player_y - tnt.y;
                    const dz = self.player_z - tnt.z;
                    const dist = @sqrt(dx * dx + dy * dy + dz * dz);
                    if (dist < explosion_mod.tnt_radius) {
                        const blast_dmg = explosion_mod.tnt_power * (1.0 - dist / explosion_mod.tnt_radius);
                        self.applyDamageWithArmor(blast_dmg);
                    }
                }

                _ = self.active_tnt.swapRemove(i);
            } else {
                i += 1;
            }
        }
    }

    /// Re-mesh all chunks that overlap the explosion sphere.
    /// Each chunk is re-meshed at most once regardless of how many blocks were destroyed.
    fn remeshExplosionArea(self: *Engine, center_x: f32, center_z: f32, radius: f32) void {
        const size: i32 = Chunk.SIZE;
        const r_int: i32 = @intFromFloat(@ceil(radius));
        const min_wx: i32 = @as(i32, @intFromFloat(@floor(center_x))) - r_int;
        const max_wx: i32 = @as(i32, @intFromFloat(@floor(center_x))) + r_int;
        const min_wz: i32 = @as(i32, @intFromFloat(@floor(center_z))) - r_int;
        const max_wz: i32 = @as(i32, @intFromFloat(@floor(center_z))) + r_int;

        const min_cx = @divFloor(min_wx, size);
        const max_cx = @divFloor(max_wx, size);
        const min_cz = @divFloor(min_wz, size);
        const max_cz = @divFloor(max_wz, size);

        var cz = min_cz;
        while (cz <= max_cz) : (cz += 1) {
            var cx = min_cx;
            while (cx <= max_cx) : (cx += 1) {
                self.remeshChunkByKey(cx, cz);
            }
        }
    }

    fn handleBlockInteraction(self: *Engine, dt: f32) void {
        const left_pressed = self.window.handle.getMouseButton(.left) == .press;
        const right_pressed = self.window.handle.getMouseButton(.right) == .press;

        const right_just_pressed = right_pressed and !self.last_right_click;

        self.last_left_click = left_pressed;
        self.last_right_click = right_pressed;

        // Reset eating when right button released
        if (!right_pressed) {
            self.eating_progress = 0.0;
        }

        // Reset mining when left button released
        if (!left_pressed) {
            self.mining_progress = 0.0;
            self.mining_target = null;
        }

        // Skip raycast when no interaction is happening
        if (!left_pressed and !right_pressed) return;

        const fwd = self.camera.forward();
        RaycastBridge.engine_ctx = self;
        defer RaycastBridge.engine_ctx = null;

        const maybe_hit = raycast.cast(
            self.camera.pos[0],
            self.camera.pos[1],
            self.camera.pos[2],
            fwd[0],
            fwd[1],
            fwd[2],
            5.0,
            &RaycastBridge.isSolid,
        );

        // --- Mining (held left click) ---
        if (left_pressed) {
            if (maybe_hit) |hit| {
                const target = BlockPos{ .x = hit.bx, .y = hit.by, .z = hit.bz };

                // Reset progress if targeting a different block
                if (self.mining_target) |prev| {
                    if (prev.x != target.x or prev.y != target.y or prev.z != target.z) {
                        self.mining_progress = 0.0;
                    }
                }
                self.mining_target = target;

                const target_bid = self.getWorldBlock(hit.bx, hit.by, hit.bz) orelse block.AIR;
                const mining_speed = self.getHeldToolMiningSpeed(target_bid);
                const hardness = block.getBlockHardness(target_bid);

                if (hardness > 0) {
                    self.mining_progress += dt * mining_speed / hardness;
                } else {
                    self.mining_progress = 1.0;
                }

                if (self.mining_progress >= 1.0) {
                    if (self.gamemode.canBreak()) {
                        self.renderer.waitIdle();
                        self.breakBlock(hit.bx, hit.by, hit.bz);
                    }
                    self.mining_progress = 0.0;
                    self.mining_target = null;
                }
            } else {
                self.mining_progress = 0.0;
                self.mining_target = null;
            }
        }

        // --- Food eating (held right click) ---
        if (right_pressed) {
            const slot = self.inventory.getSlot(self.selected_slot);
            if (!slot.isEmpty()) {
                if (food_mod.getFood(slot.item)) |food_def| {
                    self.eating_progress += dt;

                    if (self.eating_progress >= food_def.eat_duration) {
                        self.player_stats.eat(food_def.hunger_restore, food_def.saturation_restore);
                        _ = self.inventory.removeItem(self.selected_slot, 1);
                        self.eating_progress = 0.0;
                    }
                    return; // Eating takes priority over placement
                }
            }
            // Not holding food -- reset eating progress
            self.eating_progress = 0.0;
        }

        // --- Block placement / furnace interaction (right click, non-food) ---
        if (right_just_pressed) {
            if (maybe_hit) |hit| {
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
                } else if (target_bid == block.CRAFTING_TABLE_BLOCK) {
                    self.inventory_open = true;
                    self.crafting_table_open = true;
                    self.window.handle.setInputMode(.cursor, .normal) catch {};
                } else if (target_bid == ENCHANTING_TABLE_BLOCK_ID) {
                    self.interactEnchantingTable();
                } else if (target_bid == block.ANVIL) {
                    // Anvil: repair/rename/combine — log to console
                    std.debug.print("[Anvil] Opened anvil at ({},{},{})\n", .{ hit.bx, hit.by, hit.bz });
                } else if (target_bid == block.BEACON) {
                    // Beacon: check pyramid and apply effect
                    var beacon_state = beacon_mod.BeaconState.init();
                    beacon_state.checkPyramid(1); // simplified — would scan blocks
                    std.debug.print("[Beacon] Tier {}, range {} blocks\n", .{ beacon_state.pyramid_tier, beacon_state.getRange() });
                } else if (target_bid == block.BREWING_STAND) {
                    // Brewing stand: add ingredient from hotbar
                    std.debug.print("[Brewing] Opened brewing stand at ({},{},{})\n", .{ hit.bx, hit.by, hit.bz });
                } else if (target_bid == block.JUKEBOX) {
                    // Jukebox: insert/eject disc
                    std.debug.print("[Jukebox] Interacted at ({},{},{})\n", .{ hit.bx, hit.by, hit.bz });
                } else if (target_bid == block.NOTE_BLOCK) {
                    // Note block: play note
                    var nblock = music_mod.NoteBlockState.init();
                    const note = nblock.play();
                    std.debug.print("[NoteBlock] Pitch {}, instrument {}\n", .{ note.pitch, @intFromEnum(note.instrument) });
                } else if (target_bid == block.SMOKER or target_bid == block.BLAST_FURNACE) {
                    // Smoker/blast furnace: faster smelting variants
                    const name = if (target_bid == block.SMOKER) "Smoker" else "Blast Furnace";
                    std.debug.print("[{s}] 2x speed smelting at ({},{},{})\n", .{ name, hit.bx, hit.by, hit.bz });
                    self.interactFurnace(hit.bx, hit.by, hit.bz);
                } else if (target_bid == block.BARREL) {
                    // Barrel: 27-slot container
                    std.debug.print("[Barrel] Storage at ({},{},{})\n", .{ hit.bx, hit.by, hit.bz });
                } else if (target_bid == block.ENDER_CHEST) {
                    // Ender chest: shared inventory
                    std.debug.print("[Ender Chest] Shared inventory accessed\n", .{});
                } else if (target_bid == block.GRINDSTONE) {
                    // Grindstone: remove enchantments → return XP
                    std.debug.print("[Grindstone] Disenchant at ({},{},{})\n", .{ hit.bx, hit.by, hit.bz });
                } else if (target_bid == block.STONECUTTER) {
                    // Stonecutter: single-item crafting
                    std.debug.print("[Stonecutter] {} total recipes available\n", .{crafting_stations_mod.stonecutterRecipeCount()});
                } else if (target_bid == block.SMITHING_TABLE) {
                    // Smithing table: netherite upgrade
                    const held = self.inventory.getSlot(self.selected_slot).item;
                    if (netherite.upgrade(held)) |upgraded| {
                        std.debug.print("[Smithing] Upgraded to netherite item {}\n", .{upgraded});
                    } else {
                        std.debug.print("[Smithing] No upgrade available for item {}\n", .{held});
                    }
                } else if (target_bid == block.COMPOSTER) {
                    // Composter: add item to compost
                    std.debug.print("[Composter] Composting at ({},{},{})\n", .{ hit.bx, hit.by, hit.bz });
                } else if (target_bid == block.HOPPER) {
                    // Hopper: 9-slot inventory
                    std.debug.print("[Hopper] Inventory at ({},{},{})\n", .{ hit.bx, hit.by, hit.bz });
                } else if (target_bid == block.DROPPER or target_bid == block.DISPENSER) {
                    // Dropper/dispenser: 9-slot inventory
                    const name = if (target_bid == block.DROPPER) "Dropper" else "Dispenser";
                    std.debug.print("[{s}] Inventory at ({},{},{})\n", .{ name, hit.bx, hit.by, hit.bz });
                } else {
                    self.renderer.waitIdle();
                    self.placeBlock(hit.adjacent_x, hit.adjacent_y, hit.adjacent_z);
                }
            }
        }
    }

    /// Get the mining speed for the currently held item against a block ID.
    fn getHeldToolMiningSpeed(self: *Engine, block_id: block.BlockId) f32 {
        const slot = self.inventory.getSlot(self.selected_slot);
        if (slot.isEmpty()) return tools_mod.getMiningSpeed(null, @intCast(block_id));
        const tool_def = itemToToolDef(slot.item);
        return tools_mod.getMiningSpeed(tool_def, @intCast(block_id));
    }

    /// Quick-craft: when C is pressed, try to auto-craft the first matching recipe.
    /// Checks the grid-based CraftingRegistry first, then falls back to the
    /// shapeless recipe book for broader coverage.
    fn handleQuickCraft(self: *Engine) void {
        const c_pressed = self.window.handle.getKey(.c) == .press;
        const c_just_pressed = c_pressed and !self.last_craft_key;
        self.last_craft_key = c_pressed;

        if (!c_just_pressed) return;

        // 1. Try grid-based CraftingRegistry recipes first
        for (self.crafting_registry.recipes.items) |recipe| {
            if (self.canCraftRecipe(recipe)) {
                self.consumeRecipeInputs(recipe);
                _ = self.inventory.addItem(recipe.result_item, recipe.result_count);
                return;
            }
        }

        // 2. Fall back to shapeless recipe book
        for (&recipe_mod.recipes) |*recipe| {
            if (recipe_mod.canCraftFromSlots(recipe, &self.inventory.slots)) {
                recipe_mod.consumeFromSlots(recipe, &self.inventory.slots);
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
                std.debug.print("[Chat] Opened (type command, Enter to execute, Escape to close)\n", .{});
            }
            return;
        }

        // Chat is open: Escape or T again closes it
        const esc_pressed = self.window.handle.getKey(.escape) == .press;
        if (esc_pressed or t_just_pressed) {
            self.chat_open = false;
            std.debug.print("[Chat] Closed\n", .{});
            return;
        }

        // Enter executes the command
        if (self.window.handle.getKey(.enter) == .press) {
            if (self.command_len > 0) {
                const input = self.command_buffer[0..self.command_len];
                const cmd = command_mod.parse(input);
                const result = command_mod.execute(cmd, input);
                std.debug.print("[CMD] {s}\n", .{result.message[0..result.message_len]});
            } else {
                std.debug.print("[Chat] Empty command — closing\n", .{});
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
                    if (slot.count == 0) slot.* = inventory_mod.Slot.empty;
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

    /// Interact with an enchanting table: generate offers, auto-apply
    /// the cheapest affordable enchantment.
    fn interactEnchantingTable(self: *Engine) void {
        const player_level = self.xp.getLevel();
        var lapis_count: u8 = 0;
        for (self.inventory.slots) |slot| {
            if (slot.item == enchant_table_mod.LAPIS_ITEM_ID and slot.count > 0) {
                lapis_count +|= slot.count;
            }
        }

        // Seed from player position for deterministic offers per location
        const seed: u64 = @bitCast(@as(i64, @intFromFloat(self.player_x * 1000.0)) +%
            @as(i64, @intFromFloat(self.player_z * 1000.0)));
        const table = enchant_table_mod.EnchantTable{ .bookshelves = 0, .seed = seed };
        const offers = table.generateOffers(player_level);

        // Find cheapest affordable offer
        var best_idx: ?usize = null;
        var best_cost: u8 = 255;
        for (offers, 0..) |offer, i| {
            if (offer.cost_levels <= @as(u8, @truncate(player_level)) and offer.cost_lapis <= lapis_count) {
                if (offer.cost_levels < best_cost) {
                    best_cost = offer.cost_levels;
                    best_idx = i;
                }
            }
        }

        if (best_idx) |idx| {
            const offer = offers[idx];
            _ = self.xp.spendLevels(offer.cost_levels);
            var lapis_to_remove: u8 = offer.cost_lapis;
            for (&self.inventory.slots) |*slot| {
                if (lapis_to_remove == 0) break;
                if (slot.item == enchant_table_mod.LAPIS_ITEM_ID and slot.count > 0) {
                    const take = @min(slot.count, lapis_to_remove);
                    slot.count -= take;
                    if (slot.count == 0) slot.* = inventory_mod.Slot.empty;
                    lapis_to_remove -= take;
                }
            }
        }
    }

    fn breakBlock(self: *Engine, wx: i32, wy: i32, wz: i32) void {
        // Read old block before replacing with air
        const old_block = self.getWorldBlock(wx, wy, wz) orelse return;
        if (!self.setWorldBlock(wx, wy, wz, block.AIR)) return;

        // TNT activation: start a fuse instead of just dropping an item
        if (old_block == block.TNT) {
            const fx: f32 = @as(f32, @floatFromInt(wx)) + 0.5;
            const fy: f32 = @as(f32, @floatFromInt(wy)) + 0.5;
            const fz: f32 = @as(f32, @floatFromInt(wz)) + 0.5;
            self.active_tnt.append(self.allocator, explosion_mod.TNTState.init(fx, fy, fz)) catch {};
            self.remeshAffectedChunks(wx, wz);
            return;
        }

        // Scoreboard: track block mined
        self.stat_tracker.increment(.blocks_mined, 1);

        // Achievement: first block break
        _ = self.achievements.unlock(.mine_wood);
        // Advancement: mine_block criteria
        self.advancements.checkCriteria(.mine_block, old_block);

        // Achievement: ore / diamond mined
        if (old_block == block.COAL_ORE or old_block == block.IRON_ORE or
            old_block == block.GOLD_ORE or old_block == block.DIAMOND_ORE or
            old_block == block.REDSTONE_ORE)
        {
            _ = self.achievements.unlock(.mine_stone);
        }
        if (old_block == block.DIAMOND_ORE) {
            _ = self.achievements.unlock(.mine_diamond);
        }

        // Spawn item drops via loot table
        if (old_block != block.AIR) {
            const fx: f32 = @as(f32, @floatFromInt(wx)) + 0.5;
            const fy: f32 = @as(f32, @floatFromInt(wy)) + 0.5;
            const fz: f32 = @as(f32, @floatFromInt(wz)) + 0.5;

            // Emit break particles with the block's color
            const color = block.getBlockColor(old_block);
            self.particle_manager.emitBlockBreak(fx, fy, fz, color[0], color[1], color[2]);

            const loot = loot_mod.getBlockLoot(old_block);
            const fortune: u8 = 0;
            const result = loot_mod.rollLoot(loot, fortune, @intCast(self.game_time.tick));
            var dropped_anything = false;
            for (0..result.item_count) |i| {
                if (result.items[i]) |item| {
                    if (item.count > 0) {
                        self.drop_manager.spawnDrop(fx, fy, fz, item.id, item.count) catch {};
                        dropped_anything = true;
                    }
                }
            }
            // If no loot table entry, drop the block itself (most blocks drop themselves)
            if (!dropped_anything and loot.entries.len == 0) {
                self.drop_manager.spawnDrop(fx, fy, fz, @intCast(old_block), 1) catch {};
            }
            if (result.xp > 0) self.xp.addXP(result.xp);
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
        if (slot.isEmpty()) return;
        if (slot.item >= block.BLOCKS.len) return;
        const block_id: block.BlockId = @intCast(slot.item);
        if (block_id == block.AIR) return;

        if (!self.setWorldBlock(wx, wy, wz, block_id)) return;

        _ = self.inventory.removeItem(self.selected_slot, 1);

        // Scoreboard: track block placed
        self.stat_tracker.increment(.blocks_placed, 1);

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

// ---------------------------------------------------------------------------
// Tool item IDs (non-block items, starting at 300 to avoid block/food overlap)
// ---------------------------------------------------------------------------
const WOOD_PICKAXE: u16 = 300;
const STONE_PICKAXE: u16 = 301;
const IRON_PICKAXE: u16 = 302;
const GOLD_PICKAXE: u16 = 303;
const DIAMOND_PICKAXE: u16 = 304;
const WOOD_AXE: u16 = 305;
const STONE_AXE: u16 = 306;
const IRON_AXE: u16 = 307;
const GOLD_AXE: u16 = 308;
const DIAMOND_AXE: u16 = 309;
const WOOD_SHOVEL: u16 = 310;
const STONE_SHOVEL: u16 = 311;
const IRON_SHOVEL: u16 = 312;
const GOLD_SHOVEL: u16 = 313;
const DIAMOND_SHOVEL: u16 = 314;
const WOOD_SWORD: u16 = 315;
const STONE_SWORD: u16 = 316;
const IRON_SWORD: u16 = 317;
const GOLD_SWORD: u16 = 318;
const DIAMOND_SWORD: u16 = 319;

/// Map an inventory item ID to its ToolDef, or null if the item is not a tool.
fn itemToToolDef(item_id: u16) ?tools_mod.ToolDef {
    return switch (item_id) {
        WOOD_PICKAXE => tools_mod.getToolDef(.wood, .pickaxe),
        STONE_PICKAXE => tools_mod.getToolDef(.stone, .pickaxe),
        IRON_PICKAXE => tools_mod.getToolDef(.iron, .pickaxe),
        GOLD_PICKAXE => tools_mod.getToolDef(.gold, .pickaxe),
        DIAMOND_PICKAXE => tools_mod.getToolDef(.diamond, .pickaxe),
        WOOD_AXE => tools_mod.getToolDef(.wood, .axe),
        STONE_AXE => tools_mod.getToolDef(.stone, .axe),
        IRON_AXE => tools_mod.getToolDef(.iron, .axe),
        GOLD_AXE => tools_mod.getToolDef(.gold, .axe),
        DIAMOND_AXE => tools_mod.getToolDef(.diamond, .axe),
        WOOD_SHOVEL => tools_mod.getToolDef(.wood, .shovel),
        STONE_SHOVEL => tools_mod.getToolDef(.stone, .shovel),
        IRON_SHOVEL => tools_mod.getToolDef(.iron, .shovel),
        GOLD_SHOVEL => tools_mod.getToolDef(.gold, .shovel),
        DIAMOND_SHOVEL => tools_mod.getToolDef(.diamond, .shovel),
        WOOD_SWORD => tools_mod.getToolDef(.wood, .sword),
        STONE_SWORD => tools_mod.getToolDef(.stone, .sword),
        IRON_SWORD => tools_mod.getToolDef(.iron, .sword),
        GOLD_SWORD => tools_mod.getToolDef(.gold, .sword),
        DIAMOND_SWORD => tools_mod.getToolDef(.diamond, .sword),
        else => null,
    };
}

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

/// Convert a yaw angle (radians) to a cardinal direction string.
fn getFacingDirection(yaw: f32) []const u8 {
    const pi = std.math.pi;
    // Normalize yaw to [0, 2*pi); @mod already returns non-negative for positive divisor
    const angle = @mod(yaw, 2.0 * pi);

    // yaw=0 looks down -Z (north), pi/2 = west, pi = south, 3pi/2 = east
    if (angle < pi / 4.0 or angle >= 7.0 * pi / 4.0) return "north";
    if (angle < 3.0 * pi / 4.0) return "west";
    if (angle < 5.0 * pi / 4.0) return "south";
    return "east";
}
