override reflection_steps: i32 = 24;

// Shared by water and solid surfaces. Perspective-correct screen traversal
// keeps foreground entities attached to their reflection as the camera moves.
fn screen_reflection(origin: vec3<f32>, direction: vec3<f32>, normal: vec3<f32>,
    depth_texture: texture_depth_2d, color_texture: texture_2d<f32>, steps: i32) -> vec4<f32> {
    let start = origin + normal * 0.045;
    let a = frame.projection * frame.view * vec4<f32>(start, 1.0);
    let ray_clip = frame.projection * frame.view * vec4<f32>(direction, 0.0);
    if a.w <= 0.08 { return vec4<f32>(0.0); }
    var maximum = 48.0;
    if ray_clip.w < -0.00001 { maximum = min(maximum, (a.w - 0.08) / -ray_clip.w); }
    if maximum < 0.1 { return vec4<f32>(0.0); }
    let end = start + direction * maximum;
    let b = frame.projection * frame.view * vec4<f32>(end, 1.0);
    let uv_a = vec2<f32>(a.x, -a.y) / a.w * 0.5 + 0.5;
    let uv_b = vec2<f32>(b.x, -b.y) / b.w * 0.5 + 0.5;
    let span = uv_b - uv_a;
    var limit = 1.0;
    if span.x > 0.00001 { limit = min(limit, (0.998 - uv_a.x) / span.x); }
    if span.x < -0.00001 { limit = min(limit, (0.002 - uv_a.x) / span.x); }
    if span.y > 0.00001 { limit = min(limit, (0.998 - uv_a.y) / span.y); }
    if span.y < -0.00001 { limit = min(limit, (0.002 - uv_a.y) / span.y); }
    if limit <= 0.0 { return vec4<f32>(0.0); }
    let size = vec2<i32>(textureDimensions(depth_texture));
    let q_a = start / a.w;
    let q_b = end / b.w;
    var previous_t = 0.0;
    var previous_delta = -1.0;
    for (var i = 1; i <= steps; i++) {
        let progress = f32(i) / f32(steps);
        let t = limit * progress * progress;
        let uv = uv_a + span * t;
        let ray = mix(q_a, q_b, t) / mix(1.0 / a.w, 1.0 / b.w, t);
        let pixel = clamp(vec2<i32>(uv * vec2<f32>(size)), vec2<i32>(0), size - 1);
        let depth = textureLoad(depth_texture, pixel, 0);
        let point = reconstruct(uv, max(depth, 0.000001));
        let delta = (frame.view * vec4<f32>(point - ray, 0.0)).z;
        if depth > 0.0 && delta > 0.0 && previous_delta < 0.0 && delta < 3.0 + length(ray) * 0.10 {
            var low = previous_t;
            var high = t;
            for (var refine = 0; refine < 6; refine++) {
                let middle = (low + high) * 0.5;
                let test_uv = uv_a + span * middle;
                let test_ray = mix(q_a, q_b, middle) / mix(1.0 / a.w, 1.0 / b.w, middle);
                let test_pixel = clamp(vec2<i32>(test_uv * vec2<f32>(size)), vec2<i32>(0), size - 1);
                let test_depth = textureLoad(depth_texture, test_pixel, 0);
                let test_point = reconstruct(test_uv, max(test_depth, 0.000001));
                if test_depth > 0.0 && (frame.view * vec4<f32>(test_point - test_ray, 0.0)).z > 0.0 { high = middle; }
                else { low = middle; }
            }
            let hit_t = (low + high) * 0.5;
            let hit_uv = uv_a + span * hit_t;
            let hit_ray = mix(q_a, q_b, hit_t) / mix(1.0 / a.w, 1.0 / b.w, hit_t);
            let hit_pixel = clamp(vec2<i32>(hit_uv * vec2<f32>(size)), vec2<i32>(0), size - 1);
            let hit_point = reconstruct(hit_uv, max(textureLoad(depth_texture, hit_pixel, 0), 0.000001));
            let travel = length(hit_ray - start);
            let error = abs((frame.view * vec4<f32>(hit_point - hit_ray, 0.0)).z);
            if error < 0.12 + travel * 0.008 && dot(hit_point - origin, normal) > 0.015 && travel > 0.10 {
                let edge = min(min(hit_uv.x, hit_uv.y), min(1.0 - hit_uv.x, 1.0 - hit_uv.y));
                let confidence = smoothstep(0.0, 0.055, edge) * (1.0 - smoothstep(35.0, 48.0, travel));
                // opaque_color is deliberately non-filterable in Horizon's native API.
                // Four explicit loads provide a bilinear footprint for either input.
                let color_size = vec2<i32>(textureDimensions(color_texture));
                let at = hit_uv * vec2<f32>(color_size) - 0.5;
                let base = vec2<i32>(floor(at));
                let phase = fract(at);
                let c00 = textureLoad(color_texture, clamp(base, vec2<i32>(0), color_size - 1), 0).rgb;
                let c10 = textureLoad(color_texture, clamp(base + vec2<i32>(1, 0), vec2<i32>(0), color_size - 1), 0).rgb;
                let c01 = textureLoad(color_texture, clamp(base + vec2<i32>(0, 1), vec2<i32>(0), color_size - 1), 0).rgb;
                let c11 = textureLoad(color_texture, clamp(base + vec2<i32>(1, 1), vec2<i32>(0), color_size - 1), 0).rgb;
                let color = mix(mix(c00, c10, phase.x), mix(c01, c11, phase.x), phase.y);
                return vec4<f32>(color, confidence);
            }
        }
        previous_t = t;
        previous_delta = select(-1.0, delta, depth > 0.0);
    }
    return vec4<f32>(0.0);
}
