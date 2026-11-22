#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// A static film vignette + fine grain. Applied only to the lightbox backdrop,
// which is a gradient, so the cost is a single cheap full-screen pass and the
// photos themselves are never touched.
[[ stitchable ]] half4 filmVignette(float2 position, half4 color, float intensity, float2 size) {
    float2 safe = max(size, float2(1.0, 1.0));
    float2 uv = position / safe;

    // Elliptical falloff, slightly above centre.
    float2 centred = (uv - float2(0.5, 0.46)) * float2(1.0, 1.08);
    float d = length(centred);
    float vignette = smoothstep(0.92, 0.22, d);

    float grain = fract(sin(dot(position, float2(12.9898, 78.233))) * 43758.5453);

    float shade = mix(0.78, 1.0, vignette);
    half3 rgb = color.rgb * half(shade);
    rgb += half3(half((grain - 0.5) * 0.05) * half(intensity));
    return half4(rgb, color.a);
}
