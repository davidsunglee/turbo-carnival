#include <metal_stdlib>
using namespace metal;

struct SpriteVertex {
    float2 position;
    float2 texCoord;
};

struct SpriteInstance {
    float2 position;
    float2 size;
    float4 uvRect;
    float4 color;
    float rotation;
    float _pad1;
    float _pad2;
    float _pad3;
};

struct Uniforms {
    float4x4 viewProjection;
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
    float4 color;
};

vertex VertexOut sprite_vertex(
    uint vertexID [[vertex_id]],
    uint instanceID [[instance_id]],
    constant SpriteVertex *vertices [[buffer(0)]],
    constant SpriteInstance *instances [[buffer(1)]],
    constant Uniforms &uniforms [[buffer(2)]]
) {
    SpriteVertex vert = vertices[vertexID];
    SpriteInstance inst = instances[instanceID];

    // Scale by instance size
    float2 scaled = vert.position * inst.size;

    // Rotate around center
    float c = cos(inst.rotation);
    float s = sin(inst.rotation);
    float2 rotated = float2(
        scaled.x * c - scaled.y * s,
        scaled.x * s + scaled.y * c
    );

    // Translate to world position
    float2 worldPos = rotated + inst.position;

    // Map UV from atlas rect
    float2 uv = inst.uvRect.xy + vert.texCoord * inst.uvRect.zw;

    VertexOut out;
    out.position = uniforms.viewProjection * float4(worldPos, 0.0, 1.0);
    out.texCoord = uv;
    out.color = inst.color;
    return out;
}

fragment float4 sprite_fragment(
    VertexOut in [[stage_in]],
    texture2d<float> tex [[texture(0)]],
    sampler smp [[sampler(0)]]
) {
    float4 texColor = tex.sample(smp, in.texCoord);
    return texColor * in.color;
}
