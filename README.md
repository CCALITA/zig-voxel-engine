# zig-voxel-engine

A Minecraft-inspired voxel engine built with Zig 0.15 and Vulkan 1.2.

## Features

- Vulkan 1.2 renderer with depth buffer, double-buffered swapchain, and dynamic viewport
- Procedural terrain generation using Perlin noise with biome-aware block layers
- 5x5 multi-chunk rendering with per-chunk model matrices via push constants
- Indexed mesh generation (4 vertices + 6 indices per quad) with packed u32 vertex format
- FPS camera with mouse look and WASD+Space+Shift movement
- Per-vertex ambient occlusion computation
- BFS flood-fill lighting engine (block light + sky light)
- AABB physics with swept voxel collision
- DDA raycasting for block targeting (break/place)
- Inventory system with stack management and 3x3 crafting
- RLE-compressed chunk serialization
- Sparse chunk map with cross-chunk block queries

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

## Project Structure

<!-- AUTO-GENERATED: structure -->
```
src/
  main.zig              Entry point
  engine.zig            Engine struct, main loop, module re-exports
  window.zig            GLFW window wrapper
  camera.zig            FPS camera (zmath)
  renderer.zig          Vulkan renderer (935 lines)
  pipeline.zig          Graphics pipeline factory
  shaders/              Embedded SPIR-V binaries
  world/
    block.zig           12 block types with per-face textures
    chunk.zig           16x16x16 chunk storage
    mesh.zig            Non-indexed mesh generator
    mesh_indexed.zig    Indexed mesh generator (production)
    ao.zig              Per-vertex ambient occlusion
    chunk_map.zig       Sparse HashMap(ChunkCoord, *Chunk)
    chunk_serial.zig    RLE chunk serialization
    light.zig           BFS flood-fill lighting
    noise.zig           Seeded Perlin noise + fBm
    terrain_gen.zig     Procedural terrain heightmap
  physics/
    aabb.zig            AABB intersection/sweep
    body.zig            Physics body with gravity
    collision.zig       Swept AABB vs voxel collision
  gameplay/
    inventory.zig       36-slot inventory with stacking
    crafting.zig        3x3 recipe registry
    raycast.zig         DDA voxel traversal
assets/
  shaders/
    terrain.vert        GLSL 450 vertex shader
    terrain.frag        GLSL 450 fragment shader (color palette)
    *.spv               Pre-compiled SPIR-V
deps/
  vk.xml               Vulkan registry for binding generation
```
<!-- END AUTO-GENERATED -->

## Dependencies

<!-- AUTO-GENERATED: deps -->
| Package | Source | Purpose |
|---------|--------|---------|
| [vulkan-zig](https://github.com/Snektron/vulkan-zig) | zig-0.15-compat branch | Vulkan bindings generated from vk.xml |
| [zmath](https://github.com/zig-gamedev/zmath) | v0.11.0-dev | SIMD math (vectors, matrices) |
| [zglfw](https://github.com/zig-gamedev/zglfw) | v0.10.0-dev | GLFW windowing and input |
<!-- END AUTO-GENERATED -->

## Architecture

The engine uses a packed u32 vertex format encoding position (5+5+5 bits), face direction (3 bits), corner index (2 bits), and texture layer (12 bits) into a single 32-bit integer. The vertex shader unpacks this on the GPU.

Rendering uses push constants for the MVP matrix (64 bytes per draw call). Each chunk has its own vertex+index buffer and a model matrix translating it to world position.

The fragment shader currently uses a hardcoded 13-color block palette. A texture atlas is planned for a future phase.

## Testing

```bash
zig build test
```

Runs ~102 tests across three test suites:
- **Engine module tests**: block, chunk, mesh, noise, terrain, lighting, AO, chunk map, serialization
- **Executable module tests**: main entry point
- **Physics collision tests**: AABB, body, swept collision resolution
