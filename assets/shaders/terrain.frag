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

layout(set = 0, binding = 0) uniform sampler2D atlas_tex;

layout(location = 0) out vec4 out_color;

void main() {
    // Atlas layout: 64 tiles per row, each tile is 16x16 pixels in a 1024x1024 atlas
    uint col = frag_tex % 64u;
    uint row = frag_tex / 64u;
    vec2 tile_base = vec2(float(col), float(row)) / 64.0;
    vec2 tile_uv = tile_base + frag_uv / 64.0;

    vec4 tex_color = texture(atlas_tex, tile_uv);
    vec3 color = tex_color.rgb * frag_shade;

    // Distance fog
    float fog_factor = clamp((frag_dist - pc.fog_start) / (pc.fog_end - pc.fog_start), 0.0, 1.0);
    color = mix(color, pc.fog_color, fog_factor);

    out_color = vec4(color, tex_color.a);
}
