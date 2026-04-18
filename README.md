# zig-voxel-engine

A Minecraft-inspired voxel engine written entirely in Zig 0.15 with a Vulkan 1.2 renderer. The project spans ~93 source files, ~27K lines of Zig, and over 100 PRs of iterative development across 10 feature batches.

## Features

### Rendering
- Vulkan 1.2 renderer with depth buffer, double-buffered swapchain, and dynamic viewport
- Greedy meshing algorithm (80-90% vertex reduction over naive per-face meshing)
- Per-vertex ambient occlusion and BFS flood-fill lighting (block light + sky light)
- Day/night cycle with smooth sky color, fog, and ambient light transitions
- Distance fog with per-dimension fog color
- Transparent block rendering with depth-sorted quads (water, glass, ice, leaves)
- Particle system for block break effects with fade and gravity
- Box-model vertex generation for mob entity rendering
- 2D HUD overlay with health, hunger, XP bar, hotbar, oxygen, and crosshair
- Non-cube block models: slabs, stairs, fences, glass panes, cross-mesh plants, torches
- FPS camera with mouse look and WASD+Space+Shift movement

### World
- 256-block world height via 16-section chunk columns
- 6 biomes (plains, desert, forest, mountains, ocean, tundra) with temperature/humidity noise
- Biome-aware terrain: surface blocks, tree density, grass/foliage/water colors, mob spawn tables
- 3D Perlin noise cave generation with multi-octave carving
- Oak tree generation with trunk and leaf canopy placement
- Ore vein generation (coal, iron, gold, diamond, redstone)
- Structure generation: village houses/churches/wells, dungeons, desert temples, mineshafts
- Vegetation: tall grass, ferns, flowers, mushrooms, sugar cane, vines, lily pads, dead bush
- Ocean water fill below sea level
- Dynamic chunk loading/unloading in spiral order around the player
- Nether dimension (netherrack, lava ocean, caverns, glowstone, soul sand)
- End dimension (main island, floating islands, obsidian pillars)
- Weather system with clear/rain/thunder transitions and lightning strikes
- RLE-compressed chunk serialization and world persistence to disk

### Blocks
- 95 block types (IDs 0-94): stone, ores, wood, glass, brick, wool (16 colors), terracotta (4 colors), concrete (4 colors), and more
- Non-cube shapes: slabs, stairs, fences, glass panes, cross-mesh vegetation, torches
- Interactive blocks: doors, beds, ladders, chests, trapdoors
- Tile entity system for blocks with state (chests, furnaces, signs, enchanting tables, brewing stands)
- Redstone components: wire, torch, lever, button, repeater
- Pistons (normal and sticky) with push/pull mechanics and immovable block rules
- Automation blocks: hopper, dropper, dispenser with 9-slot inventories

### Gameplay
- Health (20 HP) and hunger (20 points) with natural regeneration and starvation
- Food system with saturation values and eating state machine
- Tool and weapon system with mining speed tiers, durability, and damage values
- Armor system with defense rating, durability, and equip/unequip
- 18 enchantment types (sharpness, efficiency, protection, feather falling, etc.)
- Enchanting table with bookshelf detection and weighted offer generation
- 17 potion/status effect types with amplifier and duration ticking
- Brewing stand with fuel, ingredient, and recipe system
- Anvil for repairing, combining, renaming, and enchantment merging
- Beacon with 4-tier pyramid detection and area effects
- 3x3 crafting grid with recipe registry
- Furnace with smelting recipes and fuel management
- Crop farming: wheat, carrot, potato, beetroot with growth ticks, hydration, bone meal
- Fishing with cast/wait/bite/reel phases and weighted loot table
- Explosion system for TNT (4-block radius, 4s fuse) and creeper detonations
- Environmental hazards: lava/fire/cactus contact damage, fire spread to flammable blocks
- Sprinting, sneaking, and swimming movement modes with speed/hunger modifiers
- 4 game modes: survival, creative, adventure, spectator
- XP system with Minecraft-accurate level curve
- 16 achievements in a prerequisite tree (Taking Inventory through The End)
- Scoreboard tracking 13 stat types (blocks mined, mobs killed, distance walked, etc.)
- In-game command parser (/gamemode, /time, /tp, /give, /kill, /weather, /difficulty, /seed)
- Item drop and pickup system with gravity, despawn timer, and pickup delay
- DDA raycasting for block targeting (break/place)
- AABB physics with swept voxel collision
- 36-slot inventory with stack management

### Entities
- 8 base mob types: zombie, skeleton, creeper, pig, cow, chicken, sheep, player
- AI behaviors: hostile mobs chase player, passive mobs wander
- Mob spawner with day/night rules, population caps, and distance-based despawn
- Villagers with 6 professions, tiered trade offers, and XP leveling
- Ender Dragon boss with phase-based AI (circling, diving, perching) and 12000 XP drop
- Taming system: wolves (bone), cats (raw fish), horses (temper-based mounting)
- Animal breeding with species-specific feed items, cooldowns, and baby spawning
- Projectile system (256-slot pool): arrows, ender pearls, snowballs, eggs, fireballs
- Vehicles: minecart (rail physics, deceleration) and boat (steering, cruising speed)
- Decoration entities: paintings (20 types), item frames, signs
- Mob combat with death, loot drops, and player respawn

### Systems
- World rules: difficulty (peaceful/easy/normal/hard), world border, spawn points
- Respawn anchor with glowstone charges
- Dimension switching (overworld, nether, end) with per-dimension sky/fog/rules
- Multiplayer networking foundation: packet protocol, server (20 players), client state machine
- Ender Pearl teleportation, Eye of Ender stronghold locating, End Portal detection
- Map item system: 128x128 cartography with 5 scale levels
- Music disc and jukebox playback with disc duration tracking
- Note block with instrument selection by block-below and 25-pitch cycling

## Architecture

```
src/                  6 files    3.2K lines   Core engine, camera, window, pipeline, renderer
  entity/             9 files    2.8K lines   Mobs, AI, spawner, taming, vehicles, decorations
  gameplay/          30 files    8.6K lines   Combat, crafting, enchanting, potions, farming, ...
  network/            3 files      500 lines  Protocol, server, client
  physics/            4 files      770 lines  AABB, body, collision, water
  redstone/           2 files      960 lines  Piston mechanics, automation blocks
  renderer/           3 files      900 lines  Particles, transparent pass, mob renderer
  ui/                 1 file       300 lines  HUD vertex generation
  world/             30 files    8.4K lines   Blocks, chunks, biomes, lighting, meshing, terrain
    worldgen/         3 files      970 lines  Caves, trees, structures
```

Total: **93 source files, ~27K lines of Zig**

The engine uses a packed u32 vertex format encoding position (5+5+5 bits), face direction (3 bits), corner index (2 bits), and texture layer (12 bits) into a single 32-bit integer. The vertex shader unpacks this on the GPU. Rendering uses push constants for the MVP matrix (64 bytes per draw call).

## Prerequisites

- [Zig 0.15.2+](https://ziglang.org/download/)
- Vulkan-capable GPU with drivers installed
- **macOS**: [MoltenVK](https://github.com/KhronosGroup/MoltenVK) (via Homebrew: `brew install molten-vk`)

## Build and Run

```bash
# Build
zig build

# Run
zig build run
```

<!-- AUTO-GENERATED: commands -->
| Command | Description |
|---------|-------------|
| `zig build` | Build the `zig-voxel-engine` executable (output: `zig-out/bin/`) |
| `zig build run` | Build and run the voxel engine |
| `zig build test` | Run all test suites (~102 tests) |
| `zig build --fetch` | Fetch all remote dependencies for offline builds |
<!-- END AUTO-GENERATED -->

### macOS Setup

MoltenVK requires the Vulkan ICD to be pointed at the MoltenVK driver:

```bash
export VK_ICD_FILENAMES=/opt/homebrew/etc/vulkan/icd.d/MoltenVK_icd.json
zig build run
```

## Controls

| Key | Action |
|-----|--------|
| W/A/S/D | Move forward/left/backward/right |
| Space | Move up |
| Left Shift | Move down |
| Mouse | Look around |
| Escape | Quit |

## Dependencies

<!-- AUTO-GENERATED: deps -->
| Package | Source | Purpose |
|---------|--------|---------|
| [vulkan-zig](https://github.com/Snektron/vulkan-zig) | zig-0.15-compat branch | Vulkan bindings generated from vk.xml |
| [zmath](https://github.com/zig-gamedev/zmath) | v0.11.0-dev | SIMD math (vectors, matrices) |
| [zglfw](https://github.com/zig-gamedev/zglfw) | v0.10.0-dev | GLFW windowing and input |
<!-- END AUTO-GENERATED -->

## Testing

```bash
zig build test
```

Runs ~102 tests across the engine, physics, and gameplay modules.

## Feature Completeness

The following systems are **fully rendered** via Vulkan: terrain with greedy meshing and AO, transparent blocks (water, glass, ice, leaves), particles, mob box models, HUD overlay, day/night lighting, fog, and non-cube block shapes.

The following systems are **data/logic only** (simulated in the engine loop but not yet visually rendered): weather effects, projectile trajectories, vehicle movement, decoration entities, farming crop visuals, redstone wire/torch state visualization, enchantment glint, potion particles, and the map item display. These systems track state correctly and affect gameplay (e.g., weather changes sky light, projectiles deal damage, crops produce items) but lack dedicated render passes for their visual representation.
