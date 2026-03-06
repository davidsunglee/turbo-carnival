#include <metal_stdlib>
using namespace metal;

struct PostProcessVertexOut {
    float4 position [[position]];
    float2 texCoord;
};

// Fullscreen triangle — 3 vertices cover the entire screen, no vertex buffer needed
vertex PostProcessVertexOut postprocess_vertex(uint vertexID [[vertex_id]]) {
    constexpr float2 positions[3] = {
        float2(-1.0, -1.0),
        float2( 3.0, -1.0),
        float2(-1.0,  3.0)
    };
    constexpr float2 uvs[3] = {
        float2(0.0, 1.0),
        float2(2.0, 1.0),
        float2(0.0, -1.0)
    };

    PostProcessVertexOut out;
    out.position = float4(positions[vertexID], 0.0, 1.0);
    out.texCoord = uvs[vertexID];
    return out;
}

// Passthrough stub — attachment point for future bloom/CRT effects
fragment float4 postprocess_fragment(
    PostProcessVertexOut in [[stage_in]],
    texture2d<float> tex [[texture(0)]],
    sampler smp [[sampler(0)]]
) {
    return tex.sample(smp, in.texCoord);
}
