// AMD FidelityFX Super Resolution 1 RCAS, FP32 WGSL port.
// Copyright (c) 2021 Advanced Micro Devices, Inc. MIT; see the AMD MIT license in LICENSE.txt.
// The five-tap limiter and medium reciprocal follow ffx_fsr1.h / ffx_a.h.
@group(0) @binding(0) var source: texture_2d<f32>;
@group(0) @binding(1) var<uniform> settings: vec4<f32>;

@vertex fn vertex(@builtin(vertex_index) index: u32) -> @builtin(position) vec4<f32> {
    let positions = array<vec2<f32>, 3>(vec2<f32>(-1,-1), vec2<f32>(3,-1), vec2<f32>(-1,3));
    return vec4<f32>(positions[index], 0.0, 1.0);
}

fn load(p: vec2<i32>) -> vec3<f32> {
    return textureLoad(source, clamp(p, vec2<i32>(0), vec2<i32>(textureDimensions(source)) - 1), 0).rgb;
}

@fragment fn fragment(@builtin(position) position: vec4<f32>) -> @location(0) vec4<f32> {
    let p = vec2<i32>(position.xy);
    let b = load(p + vec2<i32>(0,-1));
    let d = load(p + vec2<i32>(-1,0));
    let e = load(p);
    let f = load(p + vec2<i32>(1,0));
    let h = load(p + vec2<i32>(0,1));
    let low = min(min(b,d), min(f,h));
    let high = max(max(b,d), max(f,h));
    if all(low == high) && all(e == low) { return vec4<f32>(e, 1.0); }
    // Exact reciprocal limiters, with guards for solid black/white channels.
    let hit_min = min(low,e) / max(4.0 * high, vec3<f32>(0.000001));
    let hit_max = (1.0 - max(high,e)) / min(4.0 * low - 4.0, vec3<f32>(-0.000001));
    let lobes = max(-hit_min, hit_max);
    let lobe = max(-0.1875, min(max(max(lobes.r, lobes.g), lobes.b), 0.0)) * settings.x;
    let denominator = 4.0 * lobe + 1.0;
    let estimate = bitcast<f32>(0x7ef19fffu - bitcast<u32>(denominator));
    let reciprocal = estimate * (2.0 - estimate * denominator);
    return vec4<f32>(clamp((lobe * (b + d + f + h) + e) * reciprocal, vec3<f32>(0.0), vec3<f32>(1.0)), 1.0);
}
