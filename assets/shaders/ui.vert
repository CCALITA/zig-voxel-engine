#version 450

layout(location = 0) in vec2 in_pos;    // screen-space position (pixels, origin top-left)
layout(location = 1) in vec4 in_color;  // RGBA color

layout(push_constant) uniform PushConstants {
    vec2 screen_size;  // width, height in pixels
} pc;

layout(location = 0) out vec4 frag_color;

void main() {
    // Convert pixel coordinates to Vulkan NDC [-1, 1]
    // Vulkan NDC: (-1,-1) = top-left, (1,1) = bottom-right
    // Screen pixels: (0,0) = top-left, (width,height) = bottom-right
    // Direct mapping — no Y flip needed
    vec2 ndc = (in_pos / pc.screen_size) * 2.0 - 1.0;
    gl_Position = vec4(ndc, 0.0, 1.0);
    frag_color = in_color;
}
