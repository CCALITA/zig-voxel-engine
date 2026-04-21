#version 450

layout(location = 0) in vec4 frag_color;
layout(location = 1) in vec2 frag_uv;

layout(set = 0, binding = 0) uniform sampler2D ui_atlas;

layout(location = 0) out vec4 out_color;

void main() {
    if (frag_uv.x >= 0.0) {
        out_color = texture(ui_atlas, frag_uv) * frag_color;
    } else {
        out_color = frag_color;
    }
}
