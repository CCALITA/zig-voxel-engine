#version 450

layout(location = 0) in vec2 frag_uv;
layout(location = 1) in flat uint frag_tex;
layout(location = 2) in float frag_shade;
layout(location = 3) in float frag_dist;

layout(push_constant) uniform PushConstants {
    mat4 mvp;
    vec3 fog_color;
    float fog_start;
    float fog_end;
    float health_fraction;
    float hunger_fraction;
    float selected_slot;
} pc;

layout(location = 0) out vec4 out_color;

// Block color palette (until we have a real texture atlas)
// Indexed by texture layer ID
const vec3 block_colors[120] = vec3[120](
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
    vec3(0.35, 0.28, 0.22), // 36: soul sand
    vec3(0.75, 0.25, 0.20), // 37: lava
    vec3(0.55, 0.10, 0.10), // 38: redstone wire
    vec3(0.60, 0.15, 0.10), // 39: redstone torch
    vec3(0.45, 0.40, 0.35), // 40: lever
    vec3(0.50, 0.45, 0.40), // 41: button
    vec3(0.55, 0.50, 0.35), // 42: piston side
    vec3(0.60, 0.55, 0.40), // 43: piston top
    vec3(0.50, 0.42, 0.38), // 44: repeater
    vec3(0.45, 0.45, 0.45), // 45: furnace side
    vec3(0.50, 0.50, 0.50), // 46: furnace top
    vec3(0.50, 0.35, 0.20), // 47: door
    vec3(0.60, 0.20, 0.20), // 48: bed head
    vec3(0.55, 0.25, 0.22), // 49: bed foot
    vec3(0.50, 0.40, 0.25), // 50: ladder
    vec3(0.55, 0.40, 0.20), // 51: chest side
    vec3(0.60, 0.45, 0.25), // 52: chest top
    vec3(0.50, 0.38, 0.22), // 53: trapdoor
    vec3(0.85, 0.85, 0.70), // 54: end stone
    vec3(0.35, 0.35, 0.35), // 55: anvil side
    vec3(0.30, 0.30, 0.30), // 56: anvil top
    vec3(0.55, 0.85, 0.85), // 57: beacon
    vec3(0.45, 0.40, 0.30), // 58: brewing stand
    vec3(0.50, 0.35, 0.20), // 59: jukebox side
    vec3(0.40, 0.30, 0.18), // 60: jukebox top
    vec3(0.50, 0.35, 0.20), // 61: note block
    vec3(0.55, 0.50, 0.35), // 62: piston base side
    vec3(0.60, 0.55, 0.40), // 63: piston base top
    vec3(0.50, 0.45, 0.30), // 64: piston base bottom
    vec3(0.50, 0.65, 0.35), // 65: sticky piston top
    vec3(0.65, 0.55, 0.40), // 66: piston head face
    vec3(0.55, 0.50, 0.35), // 67: piston head side
    vec3(0.35, 0.35, 0.35), // 68: hopper side
    vec3(0.30, 0.30, 0.30), // 69: hopper top
    vec3(0.45, 0.45, 0.45), // 70: dropper front
    vec3(0.50, 0.50, 0.50), // 71: dropper side
    vec3(0.45, 0.45, 0.45), // 72: dispenser front
    vec3(0.50, 0.50, 0.50), // 73: dispenser side
    vec3(0.30, 0.10, 0.10), // 74: enchanting table top
    vec3(0.25, 0.15, 0.15), // 75: enchanting table side
    vec3(0.20, 0.05, 0.05), // 76: enchanting table bottom
    vec3(0.70, 0.75, 0.55), // 77: end portal frame side
    vec3(0.60, 0.70, 0.50), // 78: end portal frame top
    vec3(0.05, 0.10, 0.15), // 79: end portal
    vec3(0.50, 0.45, 0.35), // 80: rail
    vec3(0.60, 0.50, 0.20), // 81: powered rail
    vec3(0.50, 0.40, 0.35), // 82: detector rail
    vec3(0.55, 0.30, 0.25), // 83: activator rail
    vec3(0.45, 0.30, 0.15), // 84: farmland top
    vec3(0.50, 0.35, 0.20), // 85: farmland side
    vec3(0.50, 0.65, 0.15), // 86: wheat
    vec3(0.45, 0.60, 0.20), // 87: carrots
    vec3(0.40, 0.55, 0.18), // 88: potatoes
    vec3(0.40, 0.60, 0.20), // 89: melon block side
    vec3(0.45, 0.55, 0.25), // 90: melon block top
    vec3(0.85, 0.55, 0.10), // 91: jack o lantern front
    vec3(0.80, 0.50, 0.10), // 92: jack o lantern side
    vec3(0.70, 0.55, 0.15), // 93: jack o lantern top
    vec3(0.75, 0.70, 0.20), // 94: hay bale side
    vec3(0.80, 0.75, 0.25), // 95: hay bale top
    vec3(0.95, 0.95, 0.95), // 96: white wool
    vec3(0.90, 0.55, 0.15), // 97: orange wool
    vec3(0.75, 0.30, 0.70), // 98: magenta wool
    vec3(0.45, 0.65, 0.85), // 99: light blue wool
    vec3(0.90, 0.85, 0.25), // 100: yellow wool
    vec3(0.45, 0.75, 0.20), // 101: lime wool
    vec3(0.90, 0.55, 0.65), // 102: pink wool
    vec3(0.35, 0.35, 0.35), // 103: gray wool
    vec3(0.60, 0.60, 0.60), // 104: light gray wool
    vec3(0.20, 0.50, 0.55), // 105: cyan wool
    vec3(0.50, 0.25, 0.70), // 106: purple wool
    vec3(0.20, 0.25, 0.65), // 107: blue wool
    vec3(0.45, 0.30, 0.18), // 108: brown wool
    vec3(0.30, 0.40, 0.15), // 109: green wool
    vec3(0.65, 0.20, 0.18), // 110: red wool
    vec3(0.12, 0.12, 0.14), // 111: black wool
    vec3(0.80, 0.75, 0.72), // 112: white terracotta
    vec3(0.70, 0.45, 0.25), // 113: orange terracotta
    vec3(0.65, 0.28, 0.25), // 114: red terracotta
    vec3(0.22, 0.15, 0.14), // 115: black terracotta
    vec3(0.95, 0.95, 0.95), // 116: white concrete
    vec3(0.90, 0.55, 0.10), // 117: orange concrete
    vec3(0.65, 0.15, 0.15), // 118: red concrete
    vec3(0.08, 0.08, 0.10)  // 119: black concrete
);

void main() {
    uint idx = min(frag_tex, 119u);
    vec3 color = block_colors[idx] * frag_shade;

    // Distance fog
    float fog_factor = clamp((frag_dist - pc.fog_start) / (pc.fog_end - pc.fog_start), 0.0, 1.0);
    color = mix(color, pc.fog_color, fog_factor);

    // Crosshair overlay: white + at screen center
    vec2 screen_center = vec2(640.0, 360.0); // approximate for 1280x720
    vec2 pixel = gl_FragCoord.xy;
    float dx = abs(pixel.x - screen_center.x);
    float dy = abs(pixel.y - screen_center.y);
    bool h_bar = (dx < 8.0 && dy < 1.5);
    bool v_bar = (dx < 1.5 && dy < 8.0);
    if (h_bar || v_bar) {
        color = vec3(1.0, 1.0, 1.0);
    }

    // Health bar: red bar at bottom-left of screen
    if (pixel.y > 18.0 && pixel.y < 28.0 && pixel.x > 20.0 && pixel.x < 220.0) {
        color = vec3(0.3, 0.05, 0.05);
        if (pixel.x < 20.0 + 200.0 * pc.health_fraction) {
            color = vec3(0.9, 0.1, 0.1);
        }
    }

    // Hunger bar: brown bar at bottom-right
    if (pixel.y > 18.0 && pixel.y < 28.0 && pixel.x > 1060.0 && pixel.x < 1260.0) {
        color = vec3(0.15, 0.1, 0.05);
        if (pixel.x < 1060.0 + 200.0 * pc.hunger_fraction) {
            color = vec3(0.7, 0.45, 0.1);
        }
    }

    // Hotbar indicator: show selected slot at bottom-center
    float hotbar_left = screen_center.x - 90.0;
    if (pixel.y > 5.0 && pixel.y < 18.0 && pixel.x > hotbar_left && pixel.x < hotbar_left + 180.0) {
        color = vec3(0.2, 0.2, 0.2);
        // Highlight selected slot
        float slot_x = hotbar_left + pc.selected_slot * 20.0;
        if (pixel.x > slot_x && pixel.x < slot_x + 20.0) {
            color = vec3(0.8, 0.8, 0.8);
        }
    }

    out_color = vec4(color, 1.0);
}
