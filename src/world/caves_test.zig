// Test entry point for cave generation.
// Rooted at src/world/ so that relative imports from worldgen/caves.zig
// (e.g., ../chunk.zig) resolve correctly within this module.
test {
    _ = @import("worldgen/caves.zig");
}
