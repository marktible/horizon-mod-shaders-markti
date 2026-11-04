// AMD FidelityFX Super Resolution 1 EASU, FP32 WGSL port.
// Copyright (c) 2021 Advanced Micro Devices, Inc. MIT; see the AMD MIT license in LICENSE.txt.
// Reference: GPUOpen-Effects/FidelityFX-FSR a21ffb8f6c13233ba336352bdff293894c706575.
// UV pixel centres replace FsrEasuCon's con0 mapping. The 12 taps, directional
// Lanczos kernel, AMD reciprocal approximations and 2x2 deringing are retained.

fn fsr_rcp_low(x: f32) -> f32 {
    return bitcast<f32>(0x7ef07ebbu - bitcast<u32>(x));
}

fn fsr_luma(c: vec3<f32>) -> f32 { return c.g + 0.5 * (c.r + c.b); }

fn fsr_edge(weight: f32, a: f32, b: f32, c: f32, d: f32, e: f32) -> vec3<f32> {
    let dx = d - b;
    let dy = e - a;
    let nx = clamp(abs(dx) * fsr_rcp_low(max(abs(d - c), abs(c - b))), 0.0, 1.0);
    let ny = clamp(abs(dy) * fsr_rcp_low(max(abs(e - c), abs(c - a))), 0.0, 1.0);
    return vec3<f32>(dx, dy, nx * nx + ny * ny) * weight;
}

fn fsr_load(p: vec2<i32>, size: vec2<i32>) -> vec3<f32> {
    return textureLoad(previous, clamp(p, vec2<i32>(0), size - 1), 0).rgb;
}

fn fsr_tap(offset: vec2<f32>, direction: vec2<f32>, anisotropy: vec2<f32>, lobe: f32, clip: f32, color: vec3<f32>) -> vec4<f32> {
    let rotated = vec2<f32>(dot(offset, direction), dot(offset, vec2<f32>(-direction.y, direction.x))) * anisotropy;
    let d2 = min(dot(rotated, rotated), clip);
    let base = 0.4 * d2 - 1.0;
    let window = lobe * d2 - 1.0;
    let weight = (1.5625 * base * base - 0.5625) * window * window;
    return vec4<f32>(color * weight, weight);
}

fn fsr_easu(uv: vec2<f32>) -> vec3<f32> {
    let size = vec2<i32>(textureDimensions(previous));
    let position = uv * vec2<f32>(size) - 0.5;
    let origin = vec2<i32>(floor(position));
    let p = fract(position);
    // Explicit taps keep drivers from spilling dynamically indexed arrays.
    let b = fsr_load(origin + vec2<i32>(0,-1), size);
    let c = fsr_load(origin + vec2<i32>(1,-1), size);
    let e = fsr_load(origin + vec2<i32>(-1,0), size);
    let f = fsr_load(origin + vec2<i32>(0,0), size);
    let g = fsr_load(origin + vec2<i32>(1,0), size);
    let h = fsr_load(origin + vec2<i32>(2,0), size);
    let i = fsr_load(origin + vec2<i32>(-1,1), size);
    let j = fsr_load(origin + vec2<i32>(0,1), size);
    let k = fsr_load(origin + vec2<i32>(1,1), size);
    let l = fsr_load(origin + vec2<i32>(2,1), size);
    let n = fsr_load(origin + vec2<i32>(0,2), size);
    let o = fsr_load(origin + vec2<i32>(1,2), size);
    let bL = fsr_luma(b);
    let cL = fsr_luma(c);
    let eL = fsr_luma(e);
    let fL = fsr_luma(f);
    let gL = fsr_luma(g);
    let hL = fsr_luma(h);
    let iL = fsr_luma(i);
    let jL = fsr_luma(j);
    let kL = fsr_luma(k);
    let lL = fsr_luma(l);
    let nL = fsr_luma(n);
    let oL = fsr_luma(o);
    let edge =
        fsr_edge((1.0-p.x)*(1.0-p.y), bL,eL,fL,gL,jL) +
        fsr_edge(p.x*(1.0-p.y), cL,fL,gL,hL,kL) +
        fsr_edge((1.0-p.x)*p.y, fL,iL,jL,kL,nL) +
        fsr_edge(p.x*p.y, gL,jL,kL,lL,oL);
    var direction = edge.xy;
    let squared = dot(direction, direction);
    let zero = squared < 1.0 / 32768.0;
    let reciprocal_length = select(bitcast<f32>(0x5f347d74u - (bitcast<u32>(squared) >> 1u)), 1.0, zero);
    direction.x = select(direction.x, 1.0, zero);
    direction *= reciprocal_length;
    let strength = edge.z * edge.z * 0.25;
    let stretch = dot(direction, direction) * fsr_rcp_low(max(abs(direction.x), abs(direction.y)));
    let anisotropy = vec2<f32>(1.0 + (stretch - 1.0) * strength, 1.0 - 0.5 * strength);
    let lobe = 0.5 + (0.21 - 0.5) * strength;
    let clip = fsr_rcp_low(lobe);
    let total =
        fsr_tap(vec2<f32>(0.0,-1.0)-p, direction, anisotropy, lobe, clip, b) +
        fsr_tap(vec2<f32>(1.0,-1.0)-p, direction, anisotropy, lobe, clip, c) +
        fsr_tap(vec2<f32>(-1.0,1.0)-p, direction, anisotropy, lobe, clip, i) +
        fsr_tap(vec2<f32>(0.0,1.0)-p, direction, anisotropy, lobe, clip, j) +
        fsr_tap(vec2<f32>(0.0,0.0)-p, direction, anisotropy, lobe, clip, f) +
        fsr_tap(vec2<f32>(-1.0,0.0)-p, direction, anisotropy, lobe, clip, e) +
        fsr_tap(vec2<f32>(1.0,1.0)-p, direction, anisotropy, lobe, clip, k) +
        fsr_tap(vec2<f32>(2.0,1.0)-p, direction, anisotropy, lobe, clip, l) +
        fsr_tap(vec2<f32>(2.0,0.0)-p, direction, anisotropy, lobe, clip, h) +
        fsr_tap(vec2<f32>(1.0,0.0)-p, direction, anisotropy, lobe, clip, g) +
        fsr_tap(vec2<f32>(1.0,2.0)-p, direction, anisotropy, lobe, clip, o) +
        fsr_tap(vec2<f32>(0.0,2.0)-p, direction, anisotropy, lobe, clip, n);
    let low = min(min(f, g), min(j, k));
    let high = max(max(f, g), max(j, k));
    return clamp(total.rgb / total.a, low, high);
}
