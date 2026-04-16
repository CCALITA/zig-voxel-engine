#version 450

layout(location = 0) in vec2 frag_uv;
layout(location = 1) in flat uint frag_tex;
layout(location = 2) in float frag_shade;

layout(location = 0) out vec4 out_color;

// Block color palette (until we have a real texture atlas)
// Indexed by texture layer ID
const vec3 block_colors[13] = vec3[13](
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
    vec3(0.25, 0.25, 0.25)  // 12: bedrock
);

void main() {
    uint idx = min(frag_tex, 12u);
    vec3 color = block_colors[idx] * frag_shade;
    out_color = vec4(color, 1.0);
}
