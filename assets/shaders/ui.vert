#version 450

layout(location = 0) in vec2 in_pos;    // screen-space position (pixels)
layout(location = 1) in vec4 in_color;  // RGBA color

layout(push_constant) uniform PushConstants {
    vec2 screen_size;  // width, height for NDC conversion
} pc;

layout(location = 0) out vec4 frag_color;

void main() {
    // Convert pixel coordinates to NDC [-1, 1]
    vec2 ndc = (in_pos / pc.screen_size) * 2.0 - 1.0;
    // Flip Y for Vulkan (top-left origin in screen space → bottom-left in NDC)
    ndc.y = -ndc.y;
    gl_Position = vec4(ndc, 0.0, 1.0);
    frag_color = in_color;
}
