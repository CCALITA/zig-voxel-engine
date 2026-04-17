// Test entry point for tree generation.
// Rooted at src/world/ so that relative imports from worldgen/trees.zig
// (e.g., ../chunk.zig) resolve correctly within this module.
test {
    _ = @import("worldgen/trees.zig");
}
