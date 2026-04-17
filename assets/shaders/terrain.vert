#version 450

// Single packed u32 vertex attribute
// bits [0..4]   = x (0-16)
// bits [5..9]   = y (0-16)
// bits [10..14] = z (0-16)
// bits [15..17] = face (0-5)
// bits [18..19] = corner (0-3)
// bits [20..21] = ao (0-3)
// bits [22..25] = light (0-15)
// bits [26..31] = tex (0-63)

layout(location = 0) in uint packed_vertex;

layout(push_constant) uniform PushConstants {
    mat4 mvp;
} pc;

layout(location = 0) out vec2 frag_uv;
layout(location = 1) out flat uint frag_tex;
layout(location = 2) out float frag_shade;

// Face shading (simple directional light)
const float face_shade[6] = float[6](
    0.6,  // north  (-Z)
    0.6,  // south  (+Z)
    0.8,  // east   (+X)
    0.8,  // west   (-X)
    1.0,  // top    (+Y)
    0.4   // bottom (-Y)
);

// UV coordinates for each corner
const vec2 corner_uvs[4] = vec2[4](
    vec2(0.0, 1.0),
    vec2(1.0, 1.0),
    vec2(1.0, 0.0),
    vec2(0.0, 0.0)
);

void main() {
    uint x      = (packed_vertex >>  0) & 0x1Fu;
    uint y      = (packed_vertex >>  5) & 0x1Fu;
    uint z      = (packed_vertex >> 10) & 0x1Fu;
    uint face   = (packed_vertex >> 15) & 0x07u;
    uint corner = (packed_vertex >> 18) & 0x03u;
    uint ao_val = (packed_vertex >> 20) & 0x03u;
    uint light  = (packed_vertex >> 22) & 0x0Fu;
    uint tex    = (packed_vertex >> 26) & 0x3Fu;

    vec3 pos = vec3(float(x), float(y), float(z));
    gl_Position = pc.mvp * vec4(pos, 1.0);

    frag_uv = corner_uvs[corner];
    frag_tex = tex;

    // AO darkening: 1.0, 0.75, 0.5, 0.25
    float ao_factor = 1.0 - float(ao_val) * 0.25;
    // Light level: 0.1 (dark) to 1.0 (full light)
    float light_factor = 0.1 + float(light) / 15.0 * 0.9;

    frag_shade = face_shade[min(face, 5u)] * ao_factor * light_factor;
}
