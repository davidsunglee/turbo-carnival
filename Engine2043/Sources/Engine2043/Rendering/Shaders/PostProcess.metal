#include <metal_stdlib>
using namespace metal;

struct PostProcessUniforms {
    float time;
    float bloomIntensity;
    float scanlineIntensity;
    float transitionProgress;
};

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

// Bloom extract — output only bright pixels above luminance threshold
fragment float4 bloom_extract_fragment(
    PostProcessVertexOut in [[stage_in]],
    texture2d<float> sceneTex [[texture(0)]],
    sampler smp [[sampler(0)]]
) {
    float4 color = sceneTex.sample(smp, in.texCoord);
    float luminance = dot(color.rgb, float3(0.2126, 0.7152, 0.0722));
    float threshold = 0.5;
    float contribution = max(luminance - threshold, 0.0) / max(1.0 - threshold, 0.001);
    return float4(color.rgb * contribution, 1.0);
}

// Final composite — chromatic aberration + bloom + CRT scanlines
fragment float4 postprocess_fragment(
    PostProcessVertexOut in [[stage_in]],
    texture2d<float> sceneTex [[texture(0)]],
    texture2d<float> bloomTex [[texture(1)]],
    sampler smp [[sampler(0)]],
    constant PostProcessUniforms &uniforms [[buffer(0)]]
) {
    float2 uv = in.texCoord;
    float2 resolution = float2(sceneTex.get_width(), sceneTex.get_height());

    // --- Chromatic aberration ---
    float2 center = float2(0.5, 0.5);
    float2 dir = uv - center;
    float offset = 0.004;
    float r = sceneTex.sample(smp, uv + dir * offset).r;
    float g = sceneTex.sample(smp, uv).g;
    float b = sceneTex.sample(smp, uv - dir * offset).b;
    float a = sceneTex.sample(smp, uv).a;
    float4 sceneColor = float4(r, g, b, a);

    // --- Additive bloom ---
    float4 bloom = bloomTex.sample(smp, uv);
    sceneColor.rgb += bloom.rgb * uniforms.bloomIntensity;

    // --- CRT scanlines ---
    float scanline = sin(uv.y * resolution.y * M_PI_F + uniforms.time * 2.0);
    float scanlineFactor = clamp(scanline * uniforms.scanlineIntensity + (1.0 - uniforms.scanlineIntensity), 0.65, 1.0);
    sceneColor.rgb *= scanlineFactor;

    // --- CRT static transition ---
    if (uniforms.transitionProgress > 0.0) {
        // Hash-based noise
        float2 noiseUV = uv * resolution;
        float noise = fract(sin(dot(noiseUV + uniforms.time * 100.0, float2(12.9898, 78.233))) * 43758.5453);
        float3 staticColor = float3(noise);
        sceneColor.rgb = mix(sceneColor.rgb, staticColor, uniforms.transitionProgress);
    }

    return sceneColor;
}
