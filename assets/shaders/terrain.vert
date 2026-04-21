#version 450

// Two-attribute vertex format:
// pos_data: x(5) y(5) z(5) face(3) corner(2) ao(2) light(4) pad(6)
// tex_data: tex(12) anim(4) tint(8) reserved(8)

layout(location = 0) in uint pos_data;
layout(location = 1) in uint tex_data;

layout(push_constant) uniform PushConstants {
    mat4 mvp;
} pc;

layout(location = 0) out vec2 frag_uv;
layout(location = 1) out flat uint frag_tex;
layout(location = 2) out float frag_shade;
layout(location = 3) out float frag_dist;

const float face_shade[6] = float[6](
    0.6,  // north  (-Z)
    0.6,  // south  (+Z)
    0.8,  // east   (+X)
    0.8,  // west   (-X)
    1.0,  // top    (+Y)
    0.4   // bottom (-Y)
);

const vec2 corner_uvs[4] = vec2[4](
    vec2(0.0, 1.0),
    vec2(1.0, 1.0),
    vec2(1.0, 0.0),
    vec2(0.0, 0.0)
);

void main() {
    uint x      = (pos_data >>  0) & 0x1Fu;
    uint y      = (pos_data >>  5) & 0x1Fu;
    uint z      = (pos_data >> 10) & 0x1Fu;
    uint face   = (pos_data >> 15) & 0x07u;
    uint corner = (pos_data >> 18) & 0x03u;
    uint ao_val = (pos_data >> 20) & 0x03u;
    uint light  = (pos_data >> 22) & 0x0Fu;

    uint tex    = tex_data & 0xFFFu;

    vec3 pos = vec3(float(x), float(y), float(z));
    gl_Position = pc.mvp * vec4(pos, 1.0);

    frag_dist = gl_Position.w;
    frag_uv = corner_uvs[corner];
    frag_tex = tex;

    float ao_factor = 1.0 - float(ao_val) * 0.25;
    float light_factor = 0.1 + float(light) / 15.0 * 0.9;

    frag_shade = face_shade[min(face, 5u)] * ao_factor * light_factor;
}
