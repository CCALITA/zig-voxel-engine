// Test entry point for structure generation.
// Rooted at src/world/ so that relative imports from worldgen/structures.zig
// (e.g., ../chunk.zig) resolve correctly within this module.
test {
    _ = @import("worldgen/structures.zig");
}
