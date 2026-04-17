// Test entry point for vegetation generation.
// Rooted at src/world/ so that relative imports from vegetation.zig
// (e.g., block.zig, chunk.zig) resolve correctly within this module.
test {
    _ = @import("vegetation.zig");
}
