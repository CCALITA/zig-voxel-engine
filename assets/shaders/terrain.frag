#version 450

layout(location = 0) in vec2 frag_uv;
layout(location = 1) in flat uint frag_tex;
layout(location = 2) in float frag_shade;

layout(location = 0) out vec4 out_color;

// Block color palette (until we have a real texture atlas)
// Indexed by texture layer ID
const vec3 block_colors[37] = vec3[37](
    vec3(0.50, 0.50, 0.50), // 0: stone
    vec3(0.55, 0.35, 0.20), // 1: dirt
    vec3(0.30, 0.65, 0.15), // 2: grass top
    vec3(0.45, 0.55, 0.25), // 3: grass side
    vec3(0.40, 0.40, 0.40), // 4: cobblestone
    vec3(0.70, 0.55, 0.30), // 5: planks
    vec3(0.85, 0.80, 0.55), // 6: sand
    vec3(0.55, 0.50, 0.45), // 7: gravel
    vec3(0.40, 0.30, 0.15), // 8: log side
    vec3(0.55, 0.45, 0.25), // 9: log top
    vec3(0.20, 0.50, 0.10), // 10: leaves
    vec3(0.20, 0.35, 0.80), // 11: water
    vec3(0.25, 0.25, 0.25), // 12: bedrock
    vec3(0.35, 0.35, 0.35), // 13: coal ore
    vec3(0.55, 0.50, 0.45), // 14: iron ore
    vec3(0.65, 0.60, 0.30), // 15: gold ore
    vec3(0.40, 0.65, 0.65), // 16: diamond ore
    vec3(0.55, 0.25, 0.20), // 17: redstone ore
    vec3(0.75, 0.85, 0.90), // 18: glass
    vec3(0.60, 0.30, 0.25), // 19: brick
    vec3(0.10, 0.05, 0.15), // 20: obsidian
    vec3(0.75, 0.30, 0.25), // 21: tnt side
    vec3(0.80, 0.75, 0.65), // 22: tnt top
    vec3(0.50, 0.35, 0.20), // 23: bookshelf
    vec3(0.35, 0.45, 0.30), // 24: mossy cobblestone
    vec3(0.65, 0.80, 0.95), // 25: ice
    vec3(0.90, 0.92, 0.95), // 26: snow
    vec3(0.65, 0.62, 0.58), // 27: clay
    vec3(0.20, 0.55, 0.15), // 28: cactus side
    vec3(0.25, 0.60, 0.20), // 29: cactus top
    vec3(0.80, 0.50, 0.10), // 30: pumpkin side
    vec3(0.70, 0.55, 0.15), // 31: pumpkin top
    vec3(0.40, 0.60, 0.20), // 32: melon side
    vec3(0.45, 0.55, 0.25), // 33: melon top
    vec3(0.85, 0.75, 0.40), // 34: glowstone
    vec3(0.45, 0.20, 0.20), // 35: netherrack
    vec3(0.35, 0.28, 0.22)  // 36: soul sand
);

void main() {
    uint idx = min(frag_tex, 36u);
    vec3 color = block_colors[idx] * frag_shade;
    out_color = vec4(color, 1.0);
}
